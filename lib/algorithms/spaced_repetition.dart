import 'dart:math' as Math;

import 'package:theologie_lernapp/models/learning_card.dart';

class SpacedRepetition {
  final double goodMultiplier;
  final double badMultiplier;
  final double difficultyUp;
  final double difficultyDown;

  SpacedRepetition({
    this.goodMultiplier = 1.5,
    this.badMultiplier = 0.8,
    this.difficultyUp = 1.0,
    this.difficultyDown = 0.5,
  });

  double timeFactor(LearningCard card) {
    if (card.lastReviewed == null) {
      return 1;
    }

    final hours = DateTime.now().difference(card.lastReviewed!).inMinutes / 60;

    return hours / card.stability;
  }

  void answer(LearningCard card, bool correct) {
    final tf = timeFactor(card);

    final difficultyFactor = (11 - card.difficulty) / 10;

    if (correct) {
      final impact = 1 - Math.exp(-tf);

      card.stability *= 1 + goodMultiplier * impact * difficultyFactor;

      card.difficulty -= difficultyDown * impact;
    } else {
      final impact = Math.exp(-tf);

      final loss = badMultiplier * impact * difficultyFactor;

      card.stability *= (1 - loss);

      card.difficulty += difficultyUp * impact;
    }

    card.difficulty = card.difficulty.clamp(1, 10);

    card.lastReviewed = DateTime.now();
  }

  // Wert für die Kartenauswahl
  double selectionScore(LearningCard card) {
    final tf = timeFactor(card);

    // Schwierigkeit leicht berücksichtigen
    final difficultyFactor = card.difficulty / 5;

    // Verhindert, dass neue Karten mit tf=0 verschwinden
    final urgency = Math.pow(tf.clamp(0.01, double.infinity), 1.2).toDouble();

    return urgency * (0.5 + 0.5 * difficultyFactor);
  }
}
