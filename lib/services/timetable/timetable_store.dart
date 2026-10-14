import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/timetable/timetable_entry.dart';

/// Persönlicher Stundenplan. Angemeldet → Firestore
/// (`users/{uid}/timetable/{id}`, live über `snapshots()`, dadurch
/// geräteübergreifend synchron), Gast → lokal.
///
/// Liegt bewusst getrennt vom Veranstaltungskatalog: Hier stehen nur die
/// Einträge des Nutzers, nie Katalogdaten.
abstract class TimetableStore {
  /// Aktuelle Einträge, danach jede Änderung (auch von anderen Geräten).
  Stream<List<TimetableEntry>> watch();

  /// Speichert bzw. ersetzt einen Eintrag (samt Import und Anpassungen).
  /// [legacyFallback]: Lehnt der Server die neuen Felder ab (Firestore-Regeln
  /// noch nicht aktualisiert), den Eintrag in der alten Form speichern – nur
  /// sinnvoll für Veranstaltungen des Fakultätskatalogs, die sich ohne Import
  /// auflösen lassen.
  Future<void> add(TimetableEntry entry, {bool legacyFallback = false});

  Future<void> remove(String courseId);

  factory TimetableStore.forUser(String? uid) {
    if (uid == null) return BackendTimetableStore(LocalTimetableBackend());
    return BackendTimetableStore(FirestoreTimetableBackend(uid));
  }
}

/// Speicherort der Einträge als Dokumente `{id: Daten}`.
abstract class TimetableBackend {
  Stream<Map<String, Map<String, dynamic>>> watch();

  /// Einmal lesen. [confirmed]: nur vom Server bestätigte Daten (Firestore:
  /// nicht aus dem lokalen Cache) – für die Prüfung nach einer Übernahme.
  Future<Map<String, Map<String, dynamic>>> read({bool confirmed = false});

  Future<void> put(String id, Map<String, dynamic> data);

  Future<void> delete(String id);
}

/// Dokumentkennung zu einer Veranstaltung: Katalogkennungen enthalten `:`
/// und `.` und könnten künftig `/` enthalten – Base64URL ist für Firestore
/// und lokal immer gültig und eindeutig umkehrbar.
String timetableDocId(String courseId) =>
    base64Url.encode(utf8.encode(courseId)).replaceAll("=", "");

/// Gemeinsame Logik für Firestore und lokal.
class BackendTimetableStore implements TimetableStore {
  final TimetableBackend backend;

  BackendTimetableStore(this.backend);

  @override
  Stream<List<TimetableEntry>> watch() => backend.watch().map((docs) {
    final entries = [
      for (final data in docs.values) ?TimetableEntry.tryFromMap(data),
    ];
    // Doppelte Dokumente zur selben Veranstaltung (sollte nicht vorkommen)
    // nur einmal zeigen.
    final byCourse = <String, TimetableEntry>{
      for (final e in entries) e.courseId: e,
    };
    return byCourse.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  });

  @override
  Future<void> add(TimetableEntry entry, {bool legacyFallback = false}) async {
    final id = timetableDocId(entry.courseId);
    try {
      await backend.put(id, entry.toMap());
    } catch (e) {
      if (!legacyFallback ||
          !isPermissionDenied(e) ||
          !entry.overrides.isEmpty) {
        rethrow;
      }
      await backend.put(id, entry.toMap(legacy: true));
    }
  }

  @override
  Future<void> remove(String courseId) =>
      backend.delete(timetableDocId(courseId));
}

/// Vom Server wegen fehlender Berechtigung abgelehnt (Firestore-Regeln).
bool isPermissionDenied(Object e) =>
    (e is FirebaseException && e.code == "permission-denied") ||
    e is TimetablePermissionDenied;

/// Für Tests und lokale Speicher: wie `permission-denied` von Firestore.
class TimetablePermissionDenied implements Exception {
  const TimetablePermissionDenied();
}

/// `users/{uid}/timetable/{id}`.
class FirestoreTimetableBackend implements TimetableBackend {
  static const String collection = "timetable";

  final String uid;

  FirestoreTimetableBackend(this.uid);

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
  Future<Map<String, Map<String, dynamic>>> read({
    bool confirmed = false,
  }) async {
    final snapshot = await _collection.get(
      confirmed ? const GetOptions(source: Source.server) : null,
    );
    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  @override
  Future<void> put(String id, Map<String, dynamic> data) => _collection
      .doc(id)
      .set({...data, "addedAt": FieldValue.serverTimestamp()});

  @override
  Future<void> delete(String id) => _collection.doc(id).delete();
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage). Mehrere
/// Instanzen (z. B. Suche und Wochenansicht) sehen Änderungen sofort.
class LocalTimetableBackend implements TimetableBackend {
  static const String storageKey = "guest.v1.timetable";

  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  // Schreibvorgänge nacheinander, damit sich zwei (Lesen → Ändern →
  // Schreiben) nicht überholen.
  static Future<void> _pending = Future.value();

  @override
  Future<Map<String, Map<String, dynamic>>> read({bool confirmed = false}) =>
      _read();

  Future<Map<String, Map<String, dynamic>>> _read() async {
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
      // Defekte lokale Daten werden ignoriert.
      return {};
    }
  }

  Future<void> _change(
    void Function(Map<String, Map<String, dynamic>>) change,
  ) {
    final result = _pending.then((_) async {
      final all = await _read();
      change(all);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(all));
      _changes.add(null);
    });
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> watch() {
    StreamSubscription<void>? changes;
    late final StreamController<Map<String, Map<String, dynamic>>> controller;
    Future<void> emit() async {
      final data = await _read();
      if (!controller.isClosed) controller.add(data);
    }

    controller = StreamController(
      // Erst abonnieren, dann lesen: keine Änderung geht dazwischen verloren.
      onListen: () {
        changes = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> put(String id, Map<String, dynamic> data) => _change(
    (all) =>
        all[id] = {...data, "addedAt": DateTime.now().millisecondsSinceEpoch},
  );

  @override
  Future<void> delete(String id) => _change((all) => all.remove(id));
}
