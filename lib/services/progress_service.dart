import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    return user.uid;
  }

  /// Initialisiert fehlende Progress-Daten
  Future<void> initIfMissing(List<String> perikopeIds) async {
    final batch = _db.batch();

    for (final id in perikopeIds) {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(id);

      batch.set(ref, {
        "weight": 5,
        "streak": 0,
        "wrongStreak": 0,
        "correctCount": 0,
        "wrongCount": 0,
        "lastAnswered": null,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> syncWithPerikopen(List<String> validIds) async {
    final ref = _db.collection('users').doc(uid).collection('progress');

    final snapshot = await ref.get();

    final batch = _db.batch();

    // ❌ alte Einträge löschen
    for (final doc in snapshot.docs) {
      if (!validIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  /// Lädt alle Progress-Daten
  Future<Map<String, dynamic>> loadAllProgress() async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .get();

    final Map<String, dynamic> result = {};

    for (final doc in snapshot.docs) {
      result[doc.id] = doc.data();
    }

    return result;
  }

  /// Update nach Antwort
  Future<void> updateProgress(String perikopeId, bool correct) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(perikopeId);

    final doc = await ref.get();
    final data = doc.data() ?? {};

    int weight = data["weight"] ?? 5;
    int streak = data["streak"] ?? 0;
    int wrongStreak = data["wrongStreak"] ?? 0;
    int correctCount = data["correctCount"] ?? 0;
    int wrongCount = data["wrongCount"] ?? 0;

    if (correct) {
      correctCount++;
      streak++;
      wrongStreak = 0;

      weight -= (1 + (streak ~/ 2));
    } else {
      wrongCount++;
      wrongStreak++;
      streak = 0;

      weight += (2 + wrongStreak);
    }

    if (weight < 1) weight = 1;
    if (weight > 20) weight = 20;

    await ref.set({
      "weight": weight,
      "streak": streak,
      "wrongStreak": wrongStreak,
      "correctCount": correctCount,
      "wrongCount": wrongCount,
      "lastAnswered": Timestamp.now(),
    }, SetOptions(merge: true));
  }
}
