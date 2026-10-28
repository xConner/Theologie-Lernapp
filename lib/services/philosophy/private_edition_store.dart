import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'private_edition_local.dart';

/// Speicher für privat importierte, urheberrechtlich geschützte Ausgaben
/// (z. B. Heinemanns Physik-Ausgabe). Sie gehören nicht zur App: Der Nutzer
/// erzeugt die Datei aus seiner eigenen Kopie und importiert sie.
///
/// * Konto: `users/{uid}/private_texts/{edition}__{teil}` – nur der Nutzer
///   selbst darf lesen und schreiben (firestore.rules); dazu eine lokale
///   Kopie auf dem Gerät.
/// * Gast: nur lokal (Datei bzw. im Browser `localStorage`, soweit der
///   Platz reicht; sonst nur für die laufende Sitzung).
///
/// Jeder Teil (Vorrede, Bücher) ist ein eigenes Dokument, damit die
/// Firestore-Grenze von 1 MiB je Dokument nicht erreicht wird.
class PrivateEditionStore {
  final String? uid;
  final PrivateEditionBackend? remote;
  final PrivateEditionBackend local;

  PrivateEditionStore({
    required this.uid,
    PrivateEditionBackend? remote,
    PrivateEditionBackend? local,
  }) : remote =
           remote ?? (uid == null ? null : FirestorePrivateEditionBackend(uid)),
       local = local ?? createLocalPrivateEditionBackend();

  static const String format = "theologie.app/philosophy-edition";

  /// Im Speicher gehaltene Ausgaben dieser Sitzung (auch wenn der lokale
  /// Speicher zu klein war).
  static final Map<String, Map<String, dynamic>> _session = {};

  /// Benachrichtigt Ansichten nach Import oder Entfernen.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  @visibleForTesting
  static void clearSession() => _session.clear();

  /// Prüft eine Importdatei und liefert sie zerlegt; wirft
  /// [FormatException] mit verständlicher Meldung.
  static Map<String, dynamic> validate(
    String raw, {
    required String workId,
    required String editionId,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException("Die Datei ist kein gültiges JSON.");
    }
    if (decoded is! Map<String, dynamic> || decoded["format"] != format) {
      throw const FormatException(
        "Das ist keine Lesedatei der App (Format "
        "„theologie.app/philosophy-edition“).",
      );
    }
    if (decoded["work"] != workId || decoded["edition"] != editionId) {
      throw FormatException(
        "Die Datei gehört zu einem anderen Werk oder einer anderen Ausgabe "
        "(${decoded["work"]}, ${decoded["edition"]}).",
      );
    }
    final books = decoded["books"];
    if (books is! List || books.isEmpty) {
      throw const FormatException("Die Datei enthält keinen Text.");
    }
    return decoded;
  }

  /// Zerlegt eine Ausgabe in speicherbare Teile.
  static Map<String, String> split(Map<String, dynamic> edition) {
    final meta = Map<String, dynamic>.from(edition)
      ..remove("books")
      ..remove("intro")
      ..remove("introCitations")
      ..remove("glossary")
      ..remove("sigla")
      ..remove("bibliography");
    final front = {
      for (final key in const [
        "intro",
        "introCitations",
        "glossary",
        "sigla",
        "bibliography",
      ])
        if (edition.containsKey(key)) key: edition[key],
    };
    return {
      "meta": jsonEncode(meta),
      "front": jsonEncode(front),
      for (final b in edition["books"] as List)
        "book-${(b as Map)["n"]}": jsonEncode(b),
    };
  }

  static Map<String, dynamic> join(Map<String, String> parts) {
    final meta = jsonDecode(parts["meta"]!) as Map<String, dynamic>;
    final front = parts["front"] == null
        ? const <String, dynamic>{}
        : jsonDecode(parts["front"]!) as Map<String, dynamic>;
    final bookKeys =
        parts.keys.where((k) => k.startsWith("book-")).toList()
          ..sort((a, b) => int.parse(a.substring(5)) - int.parse(b.substring(5)));
    return {
      ...meta,
      ...front,
      "books": [for (final k in bookKeys) jsonDecode(parts[k]!)],
    };
  }

  /// Speichert eine geprüfte Ausgabe. Liefert, wo sie liegt.
  Future<PrivateEditionLocation> save(
    String editionId,
    Map<String, dynamic> edition,
  ) async {
    final parts = split(edition);
    _session[editionId] = edition;
    var remoteSaved = false;
    if (remote != null) {
      await remote!.write(editionId, parts);
      remoteSaved = true;
    }
    final localSaved = await local.tryWrite(editionId, parts);
    changes.value++;
    return PrivateEditionLocation(account: remoteSaved, device: localSaved);
  }

  /// Lädt die Ausgabe: aus der Sitzung, vom Gerät oder aus dem Konto.
  Future<Map<String, dynamic>?> load(String editionId) async {
    final cached = _session[editionId];
    if (cached != null) return cached;
    final localParts = await local.read(editionId);
    if (localParts != null) {
      return _session[editionId] = join(localParts);
    }
    if (remote != null) {
      final parts = await remote!.read(editionId);
      if (parts != null) {
        await local.tryWrite(editionId, parts);
        return _session[editionId] = join(parts);
      }
    }
    return null;
  }

  Future<bool> has(String editionId) async =>
      _session.containsKey(editionId) ||
      await local.has(editionId) ||
      (remote != null && await remote!.has(editionId));

  /// Entfernt die Ausgabe aus Konto, Gerät und Sitzung.
  Future<void> remove(String editionId) async {
    _session.remove(editionId);
    await local.delete(editionId);
    if (remote != null) await remote!.delete(editionId);
    changes.value++;
  }
}

class PrivateEditionLocation {
  final bool account;
  final bool device;

  const PrivateEditionLocation({required this.account, required this.device});
}

/// Ablage der Teile einer Ausgabe.
abstract class PrivateEditionBackend {
  Future<Map<String, String>?> read(String editionId);
  Future<void> write(String editionId, Map<String, String> parts);
  Future<void> delete(String editionId);
  Future<bool> has(String editionId);

  /// Wie [write], aber ohne Fehler, wenn der Platz nicht reicht.
  Future<bool> tryWrite(String editionId, Map<String, String> parts) async {
    try {
      await write(editionId, parts);
      return true;
    } catch (e) {
      debugPrint("Private Ausgabe nicht lokal gespeichert: $e");
      return false;
    }
  }
}

/// Für Tests und als Rückfall: nur im Speicher.
class MemoryPrivateEditionBackend extends PrivateEditionBackend {
  final Map<String, Map<String, String>> data = {};

  @override
  Future<Map<String, String>?> read(String editionId) async =>
      data[editionId] == null ? null : Map.of(data[editionId]!);

  @override
  Future<void> write(String editionId, Map<String, String> parts) async {
    data[editionId] = Map.of(parts);
  }

  @override
  Future<void> delete(String editionId) async {
    data.remove(editionId);
  }

  @override
  Future<bool> has(String editionId) async => data.containsKey(editionId);
}

class FirestorePrivateEditionBackend extends PrivateEditionBackend {
  final String uid;

  FirestorePrivateEditionBackend(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection("users")
      .doc(uid)
      .collection("private_texts");

  static String _docId(String editionId, String part) => "${editionId}__$part";

  @override
  Future<Map<String, String>?> read(String editionId) async {
    final snapshot = await _collection
        .where("edition", isEqualTo: editionId)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final parts = <String, String>{
      for (final doc in snapshot.docs)
        if (doc.data()["json"] is String)
          doc.data()["part"] as String: doc.data()["json"] as String,
    };
    return parts.containsKey("meta") ? parts : null;
  }

  @override
  Future<void> write(String editionId, Map<String, String> parts) async {
    await delete(editionId);
    for (final entry in parts.entries) {
      await _collection.doc(_docId(editionId, entry.key)).set({
        "edition": editionId,
        "part": entry.key,
        "json": entry.value,
        "updated": FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> delete(String editionId) async {
    final snapshot = await _collection
        .where("edition", isEqualTo: editionId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<bool> has(String editionId) async {
    final doc = await _collection.doc(_docId(editionId, "meta")).get();
    return doc.exists;
  }
}
