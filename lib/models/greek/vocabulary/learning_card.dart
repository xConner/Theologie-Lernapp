import 'package:cloud_firestore/cloud_firestore.dart';

class LearningCard {
  final String id;

  double stability;
  double difficulty;

  DateTime? lastReviewed;

  String? mnemonic;

  LearningCard({
    required this.id,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.lastReviewed,
    this.mnemonic,
  });

  factory LearningCard.fromFirestore(String id, Map<String, dynamic> data) {
    return LearningCard(
      id: id,

      stability: (data["stability"] ?? 1.0).toDouble(),

      difficulty: (data["difficulty"] ?? 5.0).toDouble(),

      lastReviewed: data["lastReviewed"] != null
          ? (data["lastReviewed"] as Timestamp).toDate()
          : null,

      mnemonic: data["mnemonic"],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "stability": stability,

      "difficulty": difficulty,

      "lastReviewed": lastReviewed == null
          ? null
          : Timestamp.fromDate(lastReviewed!),

      if (mnemonic != null) "mnemonic": mnemonic,
    };
  }

  // Lokale Speicherung im Gastmodus: dieselben Felder wie in Firestore, der
  // Zeitstempel als Millisekunden. Ungültige Werte fallen auf die normalen
  // Defaults des Konstruktors zurück, damit defekte lokale Daten nicht zum
  // Absturz führen.
  factory LearningCard.fromJson(String id, Map<String, dynamic> data) {
    final card = LearningCard(id: id);

    final stability = data["stability"];
    final difficulty = data["difficulty"];
    final lastReviewed = data["lastReviewed"];
    final mnemonic = data["mnemonic"];

    if (stability is num && stability.isFinite && stability > 0) {
      card.stability = stability.toDouble();
    }

    if (difficulty is num && difficulty.isFinite) {
      card.difficulty = difficulty.toDouble();
    }

    if (lastReviewed is num && lastReviewed.isFinite) {
      card.lastReviewed = DateTime.fromMillisecondsSinceEpoch(
        lastReviewed.toInt(),
      );
    }

    if (mnemonic is String) {
      card.mnemonic = mnemonic;
    }

    return card;
  }

  Map<String, dynamic> toJson() {
    return {
      "stability": stability,

      "difficulty": difficulty,

      "lastReviewed": lastReviewed?.millisecondsSinceEpoch,

      if (mnemonic != null) "mnemonic": mnemonic,
    };
  }
}
