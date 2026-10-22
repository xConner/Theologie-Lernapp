import '../models/greek/vocabulary/learning_card.dart';
import 'spaced_repetition.dart';

/// Ab dieser Schwierigkeit gilt ein Inhalt als „schwierig“ (mehr Fehler als
/// sichere Antworten in letzter Zeit). Eine einzelne falsche Antwort hebt sie
/// von 5 auf 6; richtige Antworten senken sie wieder. Gemeinsam für die
/// Wissensbereiche (Kirchengeschichte, Altes Testament).
const double difficultThreshold = 5.5;

bool isDifficultCard(LearningCard? card) =>
    card != null && card.difficulty >= difficultThreshold;

/// Stand einer Lernkarte, bewusst ohne Behauptung über „Beherrschung“:
/// Er sagt nur, wann der Inhalt zuletzt wie beantwortet wurde.
enum ReviewState {
  fresh("Noch nicht geübt"),
  due("Zum Wiederholen"),
  stable("Zuletzt sicher");

  final String label;

  const ReviewState(this.label);

  /// * noch keine Antwort → [fresh]
  /// * Lernbedarf erhöht (mehr Fehler als sichere Antworten) oder
  ///   Wiederholungsabstand abgelaufen → [due]
  /// * sonst → [stable]; eine richtige Antwort nach einem Fehler senkt den
  ///   Lernbedarf wieder, ein Fehler allein macht nichts dauerhaft „schwer“.
  static ReviewState of(LearningCard? card, SpacedRepetition algorithm) {
    if (card == null || card.lastReviewed == null) return fresh;

    if (card.difficulty >= difficultThreshold || algorithm.due(card) >= 1) {
      return due;
    }

    return stable;
  }
}

class ProgressSummary {
  final int fresh;
  final int due;
  final int stable;

  const ProgressSummary({this.fresh = 0, this.due = 0, this.stable = 0});

  int get total => fresh + due + stable;

  bool get isEmpty => total == 0;

  int count(ReviewState state) => switch (state) {
    ReviewState.fresh => fresh,
    ReviewState.due => due,
    ReviewState.stable => stable,
  };

  static ProgressSummary of(
    Iterable<String> cardIds,
    Map<String, LearningCard> cards,
    SpacedRepetition algorithm,
  ) {
    return ofStates([
      for (final id in cardIds.toSet()) ReviewState.of(cards[id], algorithm),
    ]);
  }

  /// Zählt bereits ermittelte Stände (z. B. im Latein-Lernplan, der noch
  /// nicht eingeführte Inhalte selbst erkennt).
  static ProgressSummary ofStates(Iterable<ReviewState> states) {
    var fresh = 0, due = 0, stable = 0;

    for (final state in states) {
      switch (state) {
        case ReviewState.fresh:
          fresh++;
        case ReviewState.due:
          due++;
        case ReviewState.stable:
          stable++;
      }
    }

    return ProgressSummary(fresh: fresh, due: due, stable: stable);
  }
}
