import '../../models/logic/logic_exercise.dart';
import 'logic_progress_store.dart';

/// Welche Übungen „Wiederholen“ in der Kursübersicht anbietet.
///
/// Zwei Gründe, ohne neues Speicherformat (nur `TaskProgress.lastCorrect`,
/// `correct` und `at`):
///
/// 1. Zuletzt falsch gelöst – sofort.
/// 2. Zuletzt richtig gelöst, aber länger nicht geübt. Der Abstand wächst
///    mit der Zahl richtiger Lösungen: 3, 7, 14, 30, danach 60 Tage nach
///    der letzten Antwort (lokale Kalendertage).
///
/// Nicht geübte Übungen kommen nicht hinein; neuer Stoff steht in den
/// Lektionen. Erzeugte Übungen haben keine stabile ID und fehlen ebenfalls.
class LogicReview {
  LogicReview._();

  static const List<int> intervalsInDays = [3, 7, 14, 30, 60];

  /// Abstand in Tagen nach [correct] richtigen Lösungen (mindestens eine).
  static int intervalFor(int correct) {
    final index = (correct - 1).clamp(0, intervalsInDays.length - 1);
    return intervalsInDays[index];
  }

  /// Ist die zuletzt richtig gelöste Übung mit Stand [task] am Tag [now]
  /// wieder fällig?
  static bool isDueAgain(TaskProgress task, DateTime now) {
    final at = task.at;
    if (task.lastCorrect != true || at == null) return false;

    final last = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      last.year,
      last.month,
      last.day + intervalFor(task.correct),
    );
    return !today.isBefore(due);
  }

  /// Übungen zum Wiederholen: erst die falsch gelösten, dann die wieder
  /// fälligen, jeweils am längsten nicht geübte zuerst. Die Reihenfolge des
  /// Kurses entscheidet bei gleichem Zeitpunkt.
  static List<LogicExercise> select(
    Iterable<LogicExercise> exercises,
    LogicProgress progress,
    DateTime now,
  ) {
    final wrong = <LogicExercise>[];
    final due = <LogicExercise>[];

    for (final e in exercises) {
      final id = e.id;
      if (id == null) continue;
      final task = progress.task(id);
      if (task.lastCorrect == false) {
        wrong.add(e);
      } else if (isDueAgain(task, now)) {
        due.add(e);
      }
    }

    int byTime(LogicExercise a, LogicExercise b) {
      final ta = progress.task(a.id!).at;
      final tb = progress.task(b.id!).at;
      if (ta == null || tb == null) return 0;
      return ta.compareTo(tb);
    }

    return [..._stableSorted(wrong, byTime), ..._stableSorted(due, byTime)];
  }

  /// Stabile Sortierung (List.sort ist nicht stabil).
  static List<T> _stableSorted<T>(List<T> list, int Function(T, T) compare) {
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }
}
