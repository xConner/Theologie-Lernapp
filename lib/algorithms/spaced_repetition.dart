import 'dart:math' as math;

import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';

/// Lernlogik der Vokabeltrainer und des Perikopenquiz.
///
/// Die Auswahlwahrscheinlichkeit einer Karte ergibt sich aus drei getrennt
/// nachvollziehbaren Faktoren:
///
///   Auswahlwert = Grundgewicht × Lernbedarf × Fälligkeit
///
///   * Grundgewicht: inhaltliche Priorität aus den Daten (Standard 1). Wird
///     vom Lernverlauf nie verändert.
///   * Lernbedarf ([need]): aus `difficulty`. Fehler erhöhen ihn, richtige
///     Antworten senken ihn (0,5 … 2,0).
///   * Fälligkeit ([due]): Zeit seit der letzten Abfrage im Verhältnis zum
///     Wiederholungsabstand `stability` (in Stunden), begrenzt auf [maxDue].
///
/// Noch nie gefragte Karten haben Lernbedarf und Fälligkeit 1; die Auswahl
/// (siehe LearningSelector) begrenzt zusätzlich ihren gemeinsamen Anteil.
class SpacedRepetition {
  final double goodMultiplier;
  final double difficultyUp;
  final double difficultyDown;

  /// Wiederholungsabstand nach einem Fehler (Stunden): Die Karte ist nach
  /// wenigen Minuten wieder fällig, aber nicht sofort.
  final double lapseStability;

  /// Wer eine Karte nach einer Pause noch weiß, bekommt mindestens diesen
  /// Anteil der Pause als neuen Wiederholungsabstand.
  final double retainedShare;

  final double minStability;

  /// Obergrenze des Abstands (Stunden): Auch sichere Karten kommen wieder.
  final double maxStability;

  /// Obergrenze der Fälligkeit: Lange nicht gefragte Karten zählen höchstens
  /// so viel wie [maxDue] gerade fällige.
  final double maxDue;

  final DateTime Function() _clock;

  SpacedRepetition({
    this.goodMultiplier = 1.5,
    this.difficultyUp = 1.0,
    this.difficultyDown = 0.5,
    this.lapseStability = 0.05,
    this.retainedShare = 0.5,
    this.minStability = 0.05,
    this.maxStability = 24 * 60,
    this.maxDue = 2.0,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  bool isNew(LearningCard card) => card.lastReviewed == null;

  double _elapsedHours(LearningCard card) {
    final minutes = _clock().difference(card.lastReviewed!).inMinutes;

    // Geräte mit abweichender Uhr können einen Zeitpunkt in der Zukunft
    // gespeichert haben.
    return math.max(0, minutes) / 60;
  }

  double timeFactor(LearningCard card) {
    if (card.lastReviewed == null) {
      return 1;
    }

    return _elapsedHours(card) / card.stability;
  }

  void answer(LearningCard card, bool correct) {
    final tf = timeFactor(card);

    if (correct) {
      // Eine richtige Antwort kurz nach der letzten Abfrage sagt wenig aus.
      final impact = 1 - math.exp(-tf);

      final difficultyFactor = (11 - card.difficulty) / 10;

      var stability =
          card.stability * (1 + goodMultiplier * impact * difficultyFactor);

      if (card.lastReviewed != null) {
        stability = math.max(stability, _elapsedHours(card) * retainedShare);
      }

      card.stability = stability;

      card.difficulty -= difficultyDown * impact;
    } else {
      // Ein Fehler zählt immer voll – unabhängig davon, wie lange die Karte
      // nicht gefragt wurde.
      card.stability = lapseStability;

      card.difficulty += difficultyUp;
    }

    card.stability = card.stability.clamp(minStability, maxStability);

    card.difficulty = card.difficulty.clamp(1, 10);

    card.lastReviewed = _clock();
  }

  /// Lernbedarf: 1 = neutral, bis 2 nach wiederholten Fehlern, bis 0,5 nach
  /// vielen richtigen Antworten.
  double need(LearningCard card) {
    return (card.difficulty / 5).clamp(0.5, 2.0);
  }

  /// Fälligkeit: 0 direkt nach der Abfrage, 1 wenn der Wiederholungsabstand
  /// erreicht ist, danach weiter steigend bis [maxDue]. Vor der Fälligkeit
  /// steigt der Wert bewusst flach an, damit viele sichere Karten zusammen
  /// die wenigen fälligen nicht verdrängen.
  double due(LearningCard card) {
    if (isNew(card)) {
      return 1;
    }

    final tf = timeFactor(card).clamp(0.01, maxDue).toDouble();

    return tf < 1 ? tf * tf * tf : tf;
  }

  // Wert für die Kartenauswahl
  double selectionScore(LearningCard card, {double baseWeight = 1.0}) {
    return baseWeight * need(card) * due(card);
  }

  /// Kurze Begründung der Auswahlfaktoren (für Fehlersuche und Tests).
  String explain(LearningCard card, {double baseWeight = 1.0}) {
    final base = "Grundgewicht ${baseWeight.toStringAsFixed(1)}";

    if (isNew(card)) {
      return "$base · noch nie gefragt";
    }

    final n = need(card);
    final d = due(card);

    final needText = n > 1.05
        ? "erhöht (Fehler)"
        : n < 0.95
        ? "gesenkt (sicher)"
        : "neutral";

    final dueText = d >= maxDue
        ? "lange nicht gefragt"
        : d >= 1
        ? "fällig"
        : "noch nicht fällig";

    return "$base · Lernbedarf ${n.toStringAsFixed(2)} $needText · "
        "Fälligkeit ${d.toStringAsFixed(2)} $dueText";
  }
}
