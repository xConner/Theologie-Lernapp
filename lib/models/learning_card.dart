import 'package:cloud_firestore/cloud_firestore.dart';

class LearningCard {
  final String id;

  double stability;

  double difficulty;

  DateTime? lastReviewed;

  LearningCard({
    required this.id,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.lastReviewed,
  });

  factory LearningCard.fromFirestore(String id, Map<String, dynamic> data) {
    return LearningCard(
      id: id,

      stability: (data["stability"] ?? 1.0).toDouble(),

      difficulty: (data["difficulty"] ?? 5.0).toDouble(),

      lastReviewed: data["lastReviewed"] != null
          ? (data["lastReviewed"] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "stability": stability,

      "difficulty": difficulty,

      "lastReviewed": lastReviewed == null
          ? null
          : Timestamp.fromDate(lastReviewed!),
    };
  }
}
