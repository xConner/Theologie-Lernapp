import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streak_state.dart';

/// Speicher für Streak-Stände. Angemeldet → Firestore, Gast → lokal.
abstract class StreakRepository {
  /// Alle gespeicherten Stände, nach Track-ID. Wirft bei Lesefehlern, damit
  /// vorhandene Daten nicht mit leeren Ständen überschrieben werden.
  Future<Map<String, StreakState>> loadAll();

  Future<void> save(StreakState state);

  /// Angemeldet → Firestore, uid == null (Gast) → lokaler Speicher.
  factory StreakRepository.forUser(String? uid) {
    if (uid == null) {
      return LocalStreakRepository();
    }

    return FirestoreStreakRepository(uid);
  }
}

/// `users/{uid}/streaks/{trackId}` – eigene Subcollection, bestehende
/// Dokumente bleiben unberührt.
class FirestoreStreakRepository implements StreakRepository {
  final String uid;

  FirestoreStreakRepository(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("streaks");
  }

  @override
  Future<Map<String, StreakState>> loadAll() async {
    final snapshot = await _collection.get();

    return {
      for (final doc in snapshot.docs)
        doc.id: StreakState.fromMap(doc.id, doc.data()),
    };
  }

  @override
  Future<void> save(StreakState state) {
    return _collection.doc(state.trackId).set({
      ...state.toMap(),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage). Wird nie an
/// Firestore gesendet.
class LocalStreakRepository implements StreakRepository {
  static const String storageKey = "guest.v1.streaks";

  @override
  Future<Map<String, StreakState>> loadAll() async {
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
            entry.key.toString(): StreakState.fromMap(
              entry.key.toString(),
              entry.value as Map,
            ),
      };
    } catch (_) {
      // Defekte lokale Daten werden ignoriert.
      return {};
    }
  }

  // Speichervorgänge nacheinander ausführen, damit sich zwei Schreibvorgänge
  // (Lesen → Ändern → Schreiben der gesamten Map) nicht überholen.
  static Future<void> _pending = Future.value();

  @override
  Future<void> save(StreakState state) {
    final result = _pending.then((_) => _write(state));

    _pending = result.then((_) {}, onError: (_) {});

    return result;
  }

  Future<void> _write(StreakState state) async {
    final all = await loadAll();

    all[state.trackId] = state;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      storageKey,
      jsonEncode(all.map((id, s) => MapEntry(id, s.toMap()))),
    );
  }
}
