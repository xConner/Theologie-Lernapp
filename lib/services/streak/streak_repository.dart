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

/// Gespeicherte Streaks sind gerade nicht verfügbar (z. B. offline ohne
/// Cache). Kein Hinweis darauf, dass keine Streaks existieren.
class StreakDataUnavailable implements Exception {
  const StreakDataUnavailable();

  @override
  String toString() => "Streak-Daten nicht verfügbar (offline, kein Cache)";
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

    return statesFromDocuments({
      for (final doc in snapshot.docs) doc.id: doc.data(),
    }, fromCache: snapshot.metadata.isFromCache);
  }

  /// Wandelt gelesene Dokumente in Stände um. Ohne Serververbindung liefert
  /// Firestore den lokalen Cache – im Web nach jedem Neuladen leer. Ein
  /// leerer Cache beweist nicht, dass es keine Streaks gibt; er wird daher
  /// als Ladefehler behandelt, damit keine Streak mit 1 neu beginnt und den
  /// Serverstand später überschreibt.
  static Map<String, StreakState> statesFromDocuments(
    Map<String, Map<String, dynamic>> documents, {
    required bool fromCache,
  }) {
    if (fromCache && documents.isEmpty) {
      throw const StreakDataUnavailable();
    }

    return {
      for (final entry in documents.entries)
        entry.key: StreakState.fromMap(entry.key, entry.value),
    };
  }

  /// Ersetzt das Dokument vollständig: Mit `merge` würden Quellen eines
  /// früheren Tages in `todaySources` erhalten bleiben.
  @override
  Future<void> save(StreakState state) {
    return _collection.doc(state.trackId).set({
      ...state.toMap(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }
}

/// Gastmodus: lokal über shared_preferences (Web: localStorage). Wird nie an
/// Firestore gesendet.
class LocalStreakRepository implements StreakRepository {
  static const String storageKey = "guest.v1.streaks";

  /// Wartet auf laufende Speichervorgänge, damit nie ein älterer Stand
  /// gelesen wird.
  @override
  Future<Map<String, StreakState>> loadAll() async {
    if (_writes > 0) await _pending;

    return _read();
  }

  Future<Map<String, StreakState>> _read() async {
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
  static int _writes = 0;

  @override
  Future<void> save(StreakState state) {
    _writes++;

    final result = _pending.then((_) => _write(state));

    _pending = result.then<void>(
      (_) => _writes--,
      onError: (Object _) => _writes--,
    );

    return result;
  }

  Future<void> _write(StreakState state) async {
    final all = await _read();

    all[state.trackId] = state;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      storageKey,
      jsonEncode(all.map((id, s) => MapEntry(id, s.toMap()))),
    );
  }
}
