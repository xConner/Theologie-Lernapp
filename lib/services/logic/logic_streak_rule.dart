import '../../models/logic/logic_exercise.dart';

/// Streak-Regel der „Einführung in die Logik“: Der Tag zählt, sobald heute
/// fünf Übungen richtig gelöst wurden (Tagesziel des Tracks `logic`) –
/// Kurs-, Zusatz-, Klausur- oder neu erzeugte Übungen.
///
/// Es zählt nur eine Übung, die die App selbst geprüft und als richtig
/// bewertet hat, und jede nur einmal je Bearbeitung (`_Reporting` in den
/// Übungsansichten meldet ein Ergebnis genau einmal).
///
/// Nicht zählen: offene Aufgaben (nur Selbsteinschätzung an der
/// Musterantwort), falsche Lösungen, das Öffnen oder Lesen einer Lektion,
/// „Lektion als bearbeitet markieren“ und das Erzeugen neuer Übungen.
class LogicStreakRule {
  LogicStreakRule._();

  /// Statistik (richtig/falsch je Tag): jede von der App geprüfte Übung,
  /// auch falsch gelöste; offene Aufgaben nicht, weil dort keine Bewertung
  /// der App vorliegt.
  static bool countsForStatistics(LogicExercise exercise) {
    return exercise is! OpenExercise;
  }

  static bool counts(LogicExercise exercise, {required bool correct}) {
    return correct && exercise is! OpenExercise;
  }
}
