import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/greek/exam/exam_config.dart';
import '../../../models/greek/exam/passage_ref.dart';

/// Speicher des Klausurerstellers: Konfiguration und als bearbeitet
/// markierte Abschnitte. Angemeldet → Firestore
/// (`users/{uid}/greek_exam/settings` und `…/progress`), Gast → lokal.
///
/// Bearbeitet ist ein Abschnitt nur nach ausdrücklicher Markierung; die
/// Speicherung kennt keinen anderen Weg.
abstract class ExamStore {
  Future<ExamConfig> loadConfig();

  Future<void> saveConfig(ExamConfig config);

  /// Bearbeitete Abschnitte mit Zeitpunkt der Markierung.
  Future<Map<PassageRef, DateTime>> loadDone();

  Future<void> markDone(PassageRef passage);

  Future<void> unmarkDone(PassageRef passage);

  factory ExamStore.forUser(String? uid) {
    if (uid == null) return LocalExamStore();
    return FirestoreExamStore(uid);
  }

  /// Liest das gespeicherte Format der bearbeiteten Abschnitte
  /// (`{"<Passage-ID>": <Millisekunden>}`); Ungültiges wird übergangen.
  static Map<PassageRef, DateTime> parseDone(Object? raw) {
    final result = <PassageRef, DateTime>{};

    if (raw is! Map) return result;

    for (final entry in raw.entries) {
      final ref = PassageRef.tryParse(entry.key.toString());
      final value = entry.value;

      final DateTime? at = switch (value) {
        num() => DateTime.fromMillisecondsSinceEpoch(value.toInt()),
        Timestamp() => value.toDate(),
        _ => null,
      };

      if (ref != null && at != null) result[ref] = at;
    }

    return result;
  }

  static Map<String, int> encodeDone(Map<PassageRef, DateTime> done) => {
    for (final e in done.entries) e.key.id: e.value.millisecondsSinceEpoch,
  };
}

/// `users/{uid}/greek_exam/{settings|progress}`.
class FirestoreExamStore implements ExamStore {
  static const String collection = "greek_exam";

  final String uid;

  FirestoreExamStore(this.uid);

  DocumentReference<Map<String, dynamic>> _doc(String id) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection(collection)
        .doc(id);
  }

  @override
  Future<ExamConfig> loadConfig() async {
    final data = (await _doc("settings").get()).data();
    return ExamConfig.fromMap(data?["config"]);
  }

  @override
  Future<void> saveConfig(ExamConfig config) {
    return _doc("settings").set({
      "config": config.toMap(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Map<PassageRef, DateTime>> loadDone() async {
    final data = (await _doc("progress").get()).data();
    return ExamStore.parseDone(data?["done"]);
  }

  // Lesen → ändern → ganzes Dokument schreiben: Passage-IDs enthalten
  // Punkte, die Feldpfade von update() missverstehen würden.
  Future<void> _change(void Function(Map<PassageRef, DateTime>) change) async {
    final done = await loadDone();
    change(done);

    await _doc("progress").set({
      "done": ExamStore.encodeDone(done),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markDone(PassageRef passage) =>
      _change((done) => done[passage] = DateTime.now());

  @override
  Future<void> unmarkDone(PassageRef passage) =>
      _change((done) => done.remove(passage));
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage).
class LocalExamStore implements ExamStore {
  static const String storageKey = "guest.v1.greek_exam";

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);

    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      // Defekte lokale Daten werden ignoriert.
      return {};
    }
  }

  // Schreibvorgänge nacheinander, damit sich zwei (Lesen → Ändern →
  // Schreiben) nicht überholen. Klausurersteller und Klausur teilen sich
  // eine Instanz.
  Future<void> _pending = Future.value();

  Future<void> _change(void Function(Map<String, dynamic>) change) {
    final result = _pending.then((_) async {
      final data = await _read();
      change(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(data));
    });

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }

  @override
  Future<ExamConfig> loadConfig() async =>
      ExamConfig.fromMap((await _read())["config"]);

  @override
  Future<void> saveConfig(ExamConfig config) =>
      _change((data) => data["config"] = config.toMap());

  @override
  Future<Map<PassageRef, DateTime>> loadDone() async =>
      ExamStore.parseDone((await _read())["done"]);

  @override
  Future<void> markDone(PassageRef passage) => _change((data) {
    final done = ExamStore.parseDone(data["done"]);
    done[passage] = DateTime.now();
    data["done"] = ExamStore.encodeDone(done);
  });

  @override
  Future<void> unmarkDone(PassageRef passage) => _change((data) {
    final done = ExamStore.parseDone(data["done"]);
    done.remove(passage);
    data["done"] = ExamStore.encodeDone(done);
  });
}
