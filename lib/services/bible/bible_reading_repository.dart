import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speicher für das Bibellesen: Leseverlauf, Fortschritt der Lesepläne und
/// eigene Pläne. Angemeldet → Firestore, Gast → lokal.
///
/// Die Dokumente (Aufbau siehe `BibleReadingService`):
///   `log_<Jahr>`      bestätigte Lesungen je Kalendertag
///   `plan_<Plan>`     Fortschritt eines begonnenen Plans
///   `custom_<Plan>`   ein eigener bzw. importierter Plan
///
/// Die Streak selbst liegt beim `StreakService` (Track `bible`).
abstract class BibleReadingRepository {
  /// Alle Dokumente nach ID. Wirft bei Lesefehlern, damit vorhandene Daten
  /// nicht mit leeren Ständen überschrieben werden.
  Future<Map<String, Map<String, dynamic>>> loadAll();

  /// Schreibt ein Dokument. Mit [merge] bleiben nicht genannte Felder
  /// erhalten; geschachtelte Maps werden zusammengeführt.
  Future<void> save(String id, Map<String, dynamic> data, {bool merge = false});

  Future<void> delete(String id);

  /// Angemeldet → Firestore, uid == null (Gast) → lokaler Speicher.
  factory BibleReadingRepository.forUser(String? uid) {
    if (uid == null) {
      return LocalBibleReadingRepository();
    }

    return FirestoreBibleReadingRepository(uid);
  }
}

/// `users/{uid}/bible_reading/{id}`.
class FirestoreBibleReadingRepository implements BibleReadingRepository {
  static const String collection = "bible_reading";

  final String uid;

  FirestoreBibleReadingRepository(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection(collection);
  }

  @override
  Future<Map<String, Map<String, dynamic>>> loadAll() async {
    final snapshot = await _collection.get();

    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  @override
  Future<void> save(
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return _collection.doc(id).set({
      ...data,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: merge));
  }

  @override
  Future<void> delete(String id) => _collection.doc(id).delete();
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage). Wird nie an
/// Firestore gesendet.
class LocalBibleReadingRepository implements BibleReadingRepository {
  static const String storageKey = "guest.v1.bible_reading";

  @override
  Future<Map<String, Map<String, dynamic>>> loadAll() async {
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
          if (entry.value is Map)
            entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (_) {
      // Defekte lokale Daten werden ignoriert.
      return {};
    }
  }

  // Schreibvorgänge nacheinander ausführen, damit sich zwei (Lesen → Ändern
  // → Schreiben der gesamten Map) nicht überholen.
  static Future<void> _pending = Future.value();

  Future<void> _change(
    void Function(Map<String, Map<String, dynamic>> all) change,
  ) {
    final result = _pending.then((_) async {
      final all = await loadAll();

      change(all);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(storageKey, jsonEncode(all));
    });

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }

  @override
  Future<void> save(
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return _change((all) {
      final existing = all[id];

      all[id] = merge && existing != null ? _merged(existing, data) : data;
    });
  }

  @override
  Future<void> delete(String id) => _change((all) => all.remove(id));

  static Map<String, dynamic> _merged(
    Map<String, dynamic> target,
    Map<String, dynamic> changes,
  ) {
    final result = {...target};

    for (final entry in changes.entries) {
      final before = result[entry.key];
      final value = entry.value;

      result[entry.key] = before is Map && value is Map
          ? _merged(
              Map<String, dynamic>.from(before),
              Map<String, dynamic>.from(value),
            )
          : value;
    }

    return result;
  }
}
