import 'package:cloud_firestore/cloud_firestore.dart';

class GrammarProgressService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<Map<String, Map<String, dynamic>>> loadProgress(String uid) async {
    final snapshot = await firestore
        .collection("users")
        .doc(uid)
        .collection("grammar")
        .get();

    final Map<String, Map<String, dynamic>> progress = {};

    for (final doc in snapshot.docs) {
      progress[doc.id] = doc.data();
    }

    return progress;
  }

  Future<void> saveAnswer({
    required String uid,

    required String grammarId,

    required bool correct,
  }) async {
    final ref = firestore
        .collection("users")
        .doc(uid)
        .collection("grammar")
        .doc(grammarId);

    final snapshot = await ref.get();

    double stability = 1.0;

    double difficulty = 1.0;

    if (snapshot.exists) {
      final data = snapshot.data()!;

      stability = (data["stability"] ?? 1.0).toDouble();

      difficulty = (data["difficulty"] ?? 1.0).toDouble();
    }

    if (correct) {
      stability += 1.0;

      difficulty -= 0.3;
    } else {
      stability -= 1.0;

      difficulty += 0.5;
    }

    stability = stability.clamp(0.1, 100.0);

    difficulty = difficulty.clamp(0.1, 10.0);

    await ref.set({
      "stability": stability,

      "difficulty": difficulty,

      "lastAnswered": DateTime.now().toIso8601String(),
    });
  }
}
