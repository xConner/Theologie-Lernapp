import 'dart:math';

import '../models/greek/vocabulary/learning_card.dart';
import 'learning_selector.dart';

/// Lernlogik des Grammatiktrainers.
///
/// Gelernt wird nicht „ein Wort = eine Karte“, sondern je grammatischer
/// Bestimmung: Für jeden Wert einer Dimension (z. B. Tempus = Aorist,
/// Kasus = Dativ, Person = 2. Sg) und für jede Grundform gibt es eine Karte.
/// Ein Fehler beim Tempus erhöht so gezielt den Lernbedarf dieses Tempus –
/// bei allen Verben, nicht nur bei der einen Form.
///
/// Die Karten verwenden [LearningCard] (`difficulty`, `lastReviewed`):
///   * falsch: Schwierigkeit + [difficultyUp]
///   * richtig: Schwierigkeit − [difficultyDown]
///   * sichere Werte (Schwierigkeit < 5) nähern sich ohne Abfrage mit der
///     Halbwertszeit [forgettingHalfLifeDays] wieder dem Neutralwert.
///
/// Der Lernbedarf (0,5 … 2,0) gewichtet nur die Auswahl innerhalb der bereits
/// gefilterten Kandidaten; Filter, Blacklist und die Verb-Ausnahmen des
/// Trainers bleiben vorgeschaltet.
class GrammarLearning {
  final Map<String, LearningCard> cards;

  final double difficultyUp;
  final double difficultyDown;
  final double forgettingHalfLifeDays;

  final Random _random;
  final DateTime Function() _clock;

  GrammarLearning({
    Map<String, LearningCard>? cards,
    this.difficultyUp = 1.0,
    this.difficultyDown = 0.25,
    this.forgettingHalfLifeDays = 14,
    Random? random,
    DateTime Function()? clock,
  }) : cards = cards ?? {},
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  /// Karten-ID eines Dimensionswerts, z. B. `dim.verb.tense.Aorist`.
  /// Sprachspezifisch wird erst die Collection (aktuell nur Griechisch).
  static String dimensionId(String type, String dimension, String value) {
    final key = value.replaceAll('.', '').replaceAll(RegExp(r'[/\s]+'), '-');

    return "dim.$type.$dimension.$key";
  }

  static String lemmaId(int id) => "lemma.$id";

  /// Lernbedarf einer Karte: 1 = neutral bzw. noch nie gefragt.
  double need(String id) {
    final card = cards[id];

    if (card == null) {
      return 1;
    }

    var difficulty = card.difficulty;

    final last = card.lastReviewed;

    if (difficulty < 5 && last != null) {
      final days = max(0, _clock().difference(last).inMinutes) / (60 * 24);

      difficulty =
          5 -
          (5 - difficulty) * pow(0.5, days / forgettingHalfLifeDays).toDouble();
    }

    return (difficulty / 5).clamp(0.5, 2.0);
  }

  /// Wählt einen Wert einer Dimension; schwache Werte kommen häufiger.
  String pickValue(String type, String dimension, List<String> values) {
    return pickWeighted(
      values,
      (value) => need(dimensionId(type, dimension, value)),
      _random,
    );
  }

  /// Wählt eine Grundform aus mehreren Gruppen. Jede Gruppe hat dasselbe
  /// Grundgewicht (die inhaltliche Priorität des Trainers), multipliziert
  /// mit dem mittleren Lernbedarf ihrer Wörter; innerhalb der Gruppe
  /// entscheidet der Lernbedarf des einzelnen Worts.
  T pickFromGroups<T>(List<List<T>> groups, String Function(T) idOf) {
    final group = pickWeighted(groups, (group) {
      final total = group.fold(0.0, (sum, item) => sum + need(idOf(item)));

      return total / group.length;
    }, _random);

    return pickWeighted(group, (item) => need(idOf(item)), _random);
  }

  /// Verbucht die Einzelergebnisse einer Frage (Karten-ID → richtig?) und
  /// liefert die geänderten Karten zum Speichern.
  List<LearningCard> record(Map<String, bool> results) {
    final changed = <LearningCard>[];

    for (final result in results.entries) {
      final card = cards.putIfAbsent(
        result.key,
        () => LearningCard(id: result.key),
      );

      card.difficulty += result.value ? -difficultyDown : difficultyUp;

      card.difficulty = card.difficulty.clamp(1, 10);

      card.lastReviewed = _clock();

      changed.add(card);
    }

    return changed;
  }
}
