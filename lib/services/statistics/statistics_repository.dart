import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_statistics.dart';

/// Speicher für die Tagesstatistik der Trainer. Angemeldet → Firestore,
/// Gast → lokal. Es werden nur Tagessummen je Trainer gespeichert, keine
/// einzelnen Antworten.
abstract class StatisticsRepository {
  /// Alle gespeicherten Tage, nach Trainer-ID. Wirft bei Lesefehlern.
  Future<Map<String, TrainerDays>> loadAll();

  /// Zählt eine bewertete Antwort am Kalendertag [date] (`yyyy-MM-dd`).
  Future<void> recordAnswer(String trainerId, String date, bool correct);

  /// Angemeldet → Firestore, uid == null (Gast) → lokaler Speicher.
  factory StatisticsRepository.forUser(String? uid) {
    if (uid == null) {
      return LocalStatisticsRepository();
    }

    return FirestoreStatisticsRepository(uid);
  }

  /// Liest `{date: {answered, correct, wrong}}`; ungültige Einträge werden
  /// ignoriert.
  static TrainerDays parseDays(Object? raw) {
    if (raw is! Map) {
      return {};
    }

    return {
      for (final entry in raw.entries)
        if (entry.value is Map &&
            StatisticsCalculator.isDateKey(entry.key.toString()))
          entry.key.toString(): DailyStatistics.fromMap(
            entry.key.toString(),
            entry.value as Map,
          ),
    };
  }
}

/// `users/{uid}/statistics/{trainerId}` mit dem Feld
/// `days: {yyyy-MM-dd: {answered, correct, wrong}}`.
///
/// Gezählt wird mit `FieldValue.increment`, damit Antworten von mehreren
/// Geräten bzw. offline gesammelte Antworten sich nicht überschreiben.
class FirestoreStatisticsRepository implements StatisticsRepository {
  final String uid;

  FirestoreStatisticsRepository(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("statistics");
  }

  @override
  Future<Map<String, TrainerDays>> loadAll() async {
    final snapshot = await _collection.get();

    return {
      for (final doc in snapshot.docs)
        doc.id: StatisticsRepository.parseDays(doc.data()["days"]),
    };
  }

  @override
  Future<void> recordAnswer(String trainerId, String date, bool correct) {
    return _collection.doc(trainerId).set({
      "days": {
        date: {
          "answered": FieldValue.increment(1),
          correct ? "correct" : "wrong": FieldValue.increment(1),
        },
      },
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage). Wird nie an
/// Firestore gesendet.
class LocalStatisticsRepository implements StatisticsRepository {
  static const String storageKey = "guest.v1.statistics";

  @override
  Future<Map<String, TrainerDays>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(storageKey);

    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return {};
      }

      return {
        for (final entry in decoded.entries)
          entry.key.toString(): StatisticsRepository.parseDays(entry.value),
      };
    } catch (_) {
      // Defekte lokale Daten werden ignoriert.
      return {};
    }
  }

  // Speichervorgänge nacheinander ausführen, damit sich zwei Schreibvorgänge
  // (Lesen → Ändern → Schreiben der gesamten Map) nicht überholen.
  static Future<void> _pending = Future.value();

  /// Abgeschlossen, sobald alle bisher angestoßenen Schreibvorgänge fertig
  /// sind.
  static Future<void> get pendingWrites => _pending;

  @override
  Future<void> recordAnswer(String trainerId, String date, bool correct) {
    final result = _pending.then((_) => _write(trainerId, date, correct));

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }

  Future<void> _write(String trainerId, String date, bool correct) async {
    final all = await loadAll();

    final days = all.putIfAbsent(trainerId, () => {});

    days[date] = (days[date] ?? DailyStatistics(date: date)).withAnswer(
      correct: correct,
    );

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      storageKey,
      jsonEncode(
        all.map(
          (id, days) =>
              MapEntry(id, days.map((d, s) => MapEntry(d, s.toMap()))),
        ),
      ),
    );
  }
}
