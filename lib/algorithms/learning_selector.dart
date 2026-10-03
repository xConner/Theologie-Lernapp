import 'dart:math';

import '../models/greek/vocabulary/learning_card.dart';
import 'spaced_repetition.dart';

/// Gewichtete Zufallsauswahl: Ein Element mit doppeltem Gewicht wird doppelt
/// so oft gewählt. Sind alle Gewichte 0, wird gleichverteilt gewählt.
T pickWeighted<T>(List<T> items, double Function(T) weightOf, Random random) {
  final weights = [for (final item in items) max(0.0, weightOf(item))];

  final total = weights.fold(0.0, (sum, weight) => sum + weight);

  if (total <= 0) {
    return items[random.nextInt(items.length)];
  }

  var remaining = random.nextDouble() * total;

  for (var i = 0; i < items.length; i++) {
    remaining -= weights[i];

    if (remaining <= 0) {
      return items[i];
    }
  }

  return items.last;
}

/// Wählt die nächste Frage aus einem bereits gefilterten Kandidatenpool.
///
/// Reihenfolge: Die Aufrufer wenden zuerst ihre Einstellungen/Filter an, erst
/// danach wird hier gewichtet – eine deaktivierte Frage kann also nie gewählt
/// werden.
///
///   1. Mindestabstand: Die zuletzt gestellten Fragen dieser Sitzung sind
///      vorübergehend gesperrt (höchstens der halbe Pool).
///   2. Jede Karte erhält `Grundgewicht × Lernbedarf × Fälligkeit`
///      (siehe [SpacedRepetition]).
///   3. Neue Karten zählen zusammen höchstens so viel wie [newCardBudget]
///      fällige Karten, damit ein großer Vorrat neuer Inhalte fällige
///      Wiederholungen nicht verdrängt.
///   4. Gewichtete Zufallsauswahl.
class LearningSelector {
  final SpacedRepetition algorithm;

  final int cooldown;

  final int newCardBudget;

  final Random _random;

  // Sitzungsgedächtnis, wird nicht gespeichert.
  final List<String> _recent = [];

  LearningSelector({
    SpacedRepetition? algorithm,
    this.cooldown = 5,
    this.newCardBudget = 8,
    Random? random,
  }) : algorithm = algorithm ?? SpacedRepetition(),
       _random = random ?? Random();

  T? select<T>({
    required List<T> candidates,
    required String Function(T) idOf,
    required Map<String, LearningCard> cards,
    double Function(T)? baseWeightOf,
  }) {
    if (candidates.isEmpty) {
      return null;
    }

    final blocked = _blockedIds(candidates.length);

    final pool = blocked.isEmpty
        ? candidates
        : candidates.where((item) => !blocked.contains(idOf(item))).toList();

    LearningCard cardOf(T item) {
      final id = idOf(item);

      return cards[id] ?? LearningCard(id: id);
    }

    final newCount = pool.where((item) => algorithm.isNew(cardOf(item))).length;

    final noveltyScale = newCount > newCardBudget
        ? newCardBudget / newCount
        : 1.0;

    final next = pickWeighted(pool, (item) {
      final card = cardOf(item);

      final score = algorithm.selectionScore(
        card,
        baseWeight: baseWeightOf?.call(item) ?? 1.0,
      );

      return algorithm.isNew(card) ? score * noveltyScale : score;
    }, _random);

    markAsked(idOf(next));

    return next;
  }

  void markAsked(String id) {
    _recent
      ..remove(id)
      ..add(id);

    if (_recent.length > cooldown) {
      _recent.removeAt(0);
    }
  }

  Set<String> _blockedIds(int poolSize) {
    final count = min(_recent.length, poolSize ~/ 2);

    return _recent.sublist(_recent.length - count).toSet();
  }
}
