import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speicher der Studiumsorganisation: Dokumente `{id: Felder}`.
///
/// Angemeldet → Firestore `users/{uid}/organizer/{id}`, live über
/// `snapshots()` und damit zwischen Web und Android synchron. Firestore
/// hält Änderungen ohne Verbindung zurück und zeigt sie sofort an (Android
/// dauerhaft, im Web bis zum Schließen des Tabs) und schreibt sie nach,
/// sobald wieder eine Verbindung besteht. Gast → lokal.
///
/// Getrennt von allen Lernständen: Zurücksetzen eines Lernbereichs berührt
/// diese Sammlung nie.
abstract class OrganizerBackend {
  /// Aktueller Stand, danach jede Änderung (auch von anderen Geräten).
  Stream<Map<String, Map<String, dynamic>>> watch();

  /// Einmal lesen (z. B. für die Übernahme der Gastdaten).
  Future<Map<String, Map<String, dynamic>>> read();

  /// Schreibt nur die genannten Felder (übrige bleiben, `null` leert ein
  /// Feld). Ein neues Dokument entsteht mit genau diesen Feldern.
  Future<void> patch(String id, Map<String, dynamic> fields);

  Future<void> delete(String id);

  factory OrganizerBackend.forUser(String? uid) =>
      uid == null ? LocalOrganizerBackend() : FirestoreOrganizerBackend(uid);
}

class FirestoreOrganizerBackend implements OrganizerBackend {
  static const String collection = "organizer";

  final String uid;

  FirestoreOrganizerBackend(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection("users")
      .doc(uid)
      .collection(collection);

  @override
  Stream<Map<String, Map<String, dynamic>>> watch() => _collection
      .snapshots()
      .map((s) => {for (final doc in s.docs) doc.id: doc.data()});

  @override
  Future<Map<String, Map<String, dynamic>>> read() async {
    final snapshot = await _collection.get();
    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  @override
  Future<void> patch(String id, Map<String, dynamic> fields) =>
      _collection.doc(id).set(fields, SetOptions(merge: true));

  @override
  Future<void> delete(String id) => _collection.doc(id).delete();
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage). Mehrere
/// Instanzen sehen Änderungen sofort.
class LocalOrganizerBackend implements OrganizerBackend {
  static const String storageKey = "guest.v1.organizer";

  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  // Schreibvorgänge nacheinander (Lesen → Ändern → Schreiben).
  static Future<void> _pending = Future.value();

  @override
  Future<Map<String, Map<String, dynamic>>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is Map)
            e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      // Defekte lokale Daten werden ignoriert, nie überschrieben gelesen.
      return {};
    }
  }

  Future<void> _change(void Function(Map<String, Map<String, dynamic>>) f) {
    final result = _pending.then((_) async {
      final all = await read();
      f(all);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(all));
      _changes.add(null);
    });
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Entfernt alle lokalen Daten (nach der Übernahme ins Konto).
  Future<void> clear() => _change((all) => all.clear());

  @override
  Stream<Map<String, Map<String, dynamic>>> watch() {
    StreamSubscription<void>? changes;
    late final StreamController<Map<String, Map<String, dynamic>>> controller;
    Future<void> emit() async {
      final data = await read();
      if (!controller.isClosed) controller.add(data);
    }

    controller = StreamController(
      onListen: () {
        changes = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> patch(String id, Map<String, dynamic> fields) =>
      _change((all) => all[id] = {...?all[id], ...fields});

  @override
  Future<void> delete(String id) => _change((all) => all.remove(id));
}

/// Übernimmt lokal gespeicherte Gastdaten ins Konto: nur Dokumente, die es
/// dort noch nicht gibt (nichts wird überschrieben); lokal gelöscht wird
/// erst, wenn alles geschrieben ist.
class OrganizerGuestMigration {
  final LocalOrganizerBackend local;
  final OrganizerBackend account;

  OrganizerGuestMigration({required this.local, required this.account});

  factory OrganizerGuestMigration.forUser(String uid) =>
      OrganizerGuestMigration(
        local: LocalOrganizerBackend(),
        account: FirestoreOrganizerBackend(uid),
      );

  /// Anzahl übernommener Einträge (ohne Einstellungen).
  Future<int> run() async {
    final guest = await local.read();
    if (guest.isEmpty) return 0;
    final existing = await account.read();
    var copied = 0;
    for (final entry in guest.entries) {
      if (existing.containsKey(entry.key)) continue;
      await account.patch(entry.key, entry.value);
      if (entry.value["kind"] != "config" && entry.value["kind"] != "area") {
        copied++;
      }
    }
    await local.clear();
    return copied;
  }
}
