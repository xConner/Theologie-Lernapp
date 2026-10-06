import 'hint_generator.dart';
import 'text_evaluator.dart';

/// Streak-Regel von „Texte auswendig lernen“: Der Tag ist erledigt, sobald
/// heute eine einzige Übung aus dem Gedächtnis abgeschlossen wurde – bei
/// einem beliebigen Text.
///
/// Die Streak fragt nur „Hast du heute aktiv auswendig geübt?“. Was und wie
/// viel ansteht, bestimmt weiterhin allein der Tagesplan
/// (`MemorizationScheduler.planFor`); er ist kein Streak-Ziel. Die Regel
/// hängt deshalb weder von der Zahl der Texte noch von fälligen
/// Wiederholungen ab.
///
/// Es zählt jede ausgewertete Übung mit Lücken, Anfangsbuchstaben,
/// minimaler Hilfe oder frei – getippt, gesprochen oder im Kopf mit
/// Selbsteinschätzung, ob Abschnitt, Verbindung oder ganzer Text, gelungen
/// oder nicht.
///
/// Nicht zählen: Öffnen, Ansehen, Mitlesen („Gelesen – weiter“),
/// Überspringen, eine ohne Auswertung verlassene Übung und eine leere
/// Eingabe.
class MemorizationStreakRule {
  MemorizationStreakRule._();

  /// Zählt die Übung auf Stufe [practiced] für die Streak? [result] ist der
  /// Wortvergleich (getippt/gesprochen), null bei Selbsteinschätzung.
  static bool counts({required HintLevel practiced, EvaluationResult? result}) {
    if (practiced == HintLevel.read) return false;

    return !(result?.isEmptyInput ?? false);
  }
}
