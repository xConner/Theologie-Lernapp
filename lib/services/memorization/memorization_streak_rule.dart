import 'hint_generator.dart';
import 'text_evaluator.dart';

/// Streak-Regel von „Texte auswendig lernen“: Der Tag zählt, sobald heute
/// zehn Antworten wortgetreu richtig eingegeben wurden – bei beliebigen
/// Texten (Tagesziel des Tracks `memorization`).
///
/// Was und wie viel ansteht, bestimmt weiterhin allein der Tagesplan
/// (`MemorizationScheduler.planFor`); er ist kein Streak-Ziel.
///
/// Es zählt nur eine tatsächlich abgegebene Eingabe (getippt oder
/// gesprochen), die der Wortvergleich des `MemorizationTextEvaluator` als
/// wortgetreu richtig bewertet ([RecallOutcome.correct]) – mit Lücken,
/// Anfangsbuchstaben, minimaler Hilfe oder frei, ob Abschnitt, Verbindung
/// oder ganzer Text. Jede Auswertung zählt genau einmal.
///
/// Nicht zählen: die Selbsteinschätzung „Im Kopf“ (auch „Gewusst“), eine
/// Eingabe mit Abweichungen („Fast“, „Nicht gewusst“), eine leere Eingabe,
/// Öffnen, Ansehen, Mitlesen („Gelesen – weiter“), Überspringen und eine
/// ohne Auswertung verlassene Übung.
class MemorizationStreakRule {
  MemorizationStreakRule._();

  /// Zählt die Übung auf Stufe [practiced] für die Streak? [result] ist der
  /// Wortvergleich (getippt/gesprochen), null bei Mitlesen und
  /// Selbsteinschätzung.
  static bool counts({required HintLevel practiced, EvaluationResult? result}) {
    if (practiced == HintLevel.read || result == null) return false;

    return result.outcome == RecallOutcome.correct;
  }
}
