import 'dart:math';

/// Gespeicherter Streak-Stand eines Tracks (Firestore-Dokument
/// `users/{uid}/streaks/{trackId}` bzw. lokal im Gastmodus).
///
/// Datumsangaben sind lokale Kalendertage im Format `yyyy-MM-dd`.
/// [currentStreak] gilt für [lastCompletedDate]; ob die Streak heute noch
/// aktiv ist, berechnet [StreakCalculator.snapshot].
class StreakState {
  final String trackId;

  final int currentStreak;
  final int longestStreak;

  /// Kalendertag, auf den sich [todayCorrectAnswers] und [todaySources]
  /// beziehen (letzter Tag mit einer gezählten richtigen Antwort).
  final String? lastActivityDate;

  /// Letzter Kalendertag, an dem das Tagesziel erreicht wurde.
  final String? lastCompletedDate;

  final int todayCorrectAnswers;

  /// Richtige Antworten am [lastActivityDate] je [StreakSource].
  final Map<String, int> todaySources;

  /// Tagesziel am [lastActivityDate] erreicht.
  final bool streakCompletedToday;

  const StreakState({
    required this.trackId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.lastCompletedDate,
    this.todayCorrectAnswers = 0,
    this.todaySources = const {},
    this.streakCompletedToday = false,
  });

  Map<String, dynamic> toMap() {
    return {
      "trackId": trackId,
      "currentStreak": currentStreak,
      "longestStreak": longestStreak,
      "lastActivityDate": lastActivityDate,
      "lastCompletedDate": lastCompletedDate,
      "todayCorrectAnswers": todayCorrectAnswers,
      "todaySources": todaySources,
      "streakCompletedToday": streakCompletedToday,
    };
  }

  /// Liest gespeicherte Daten; ungültige Werte werden durch Defaults ersetzt.
  factory StreakState.fromMap(String trackId, Map<dynamic, dynamic> data) {
    final sources = <String, int>{};

    final rawSources = data["todaySources"];

    if (rawSources is Map) {
      for (final entry in rawSources.entries) {
        final value = _int(entry.value);

        if (value > 0) {
          sources[entry.key.toString()] = value;
        }
      }
    }

    return StreakState(
      trackId: trackId,
      currentStreak: _int(data["currentStreak"]),
      longestStreak: _int(data["longestStreak"]),
      lastActivityDate: _date(data["lastActivityDate"]),
      lastCompletedDate: _date(data["lastCompletedDate"]),
      todayCorrectAnswers: _int(data["todayCorrectAnswers"]),
      todaySources: sources,
      streakCompletedToday: data["streakCompletedToday"] == true,
    );
  }

  static int _int(Object? value) {
    return value is num && value >= 0 ? value.toInt() : 0;
  }

  static final RegExp _datePattern = RegExp(r"^\d{4}-\d{2}-\d{2}$");

  static String? _date(Object? value) {
    return value is String && _datePattern.hasMatch(value) ? value : null;
  }
}

/// Auf den heutigen Kalendertag bezogene Sicht auf einen [StreakState]
/// (für die Anzeige).
class StreakSnapshot {
  /// Aktive Streak: 0, wenn weder heute noch gestern das Ziel erreicht wurde.
  final int currentStreak;
  final int longestStreak;
  final int todayCorrectAnswers;
  final Map<String, int> todaySources;
  final bool completedToday;
  final int dailyGoal;

  const StreakSnapshot({
    required this.currentStreak,
    required this.longestStreak,
    required this.todayCorrectAnswers,
    required this.todaySources,
    required this.completedToday,
    required this.dailyGoal,
  });

  double get todayProgress =>
      dailyGoal <= 0 ? 1 : min(todayCorrectAnswers / dailyGoal, 1).toDouble();
}

/// Ergebnis von [StreakCalculator.record].
class StreakUpdate {
  final StreakState state;

  /// Wurde der Stand verändert (und muss gespeichert werden)?
  final bool changed;

  /// Wurde das Tagesziel genau mit dieser Antwort erreicht?
  final bool goalReachedNow;

  const StreakUpdate({
    required this.state,
    required this.changed,
    required this.goalReachedNow,
  });

  /// Streak nach dieser Antwort (nur aussagekräftig bei [goalReachedNow]).
  int get currentStreak => state.currentStreak;

  /// Erster Tag einer neuen Streak.
  bool get streakStarted => goalReachedNow && state.currentStreak == 1;
}

/// Reine, kalenderbasierte Streak-Berechnung ohne Speicherzugriff.
class StreakCalculator {
  StreakCalculator._();

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");

    return "$y-$m-$d";
  }

  /// Vorheriger Kalendertag (unabhängig von Sommerzeit-Umstellungen).
  static String previousDateKey(DateTime date) {
    return dateKey(DateTime(date.year, date.month, date.day - 1));
  }

  static StreakSnapshot snapshot(
    StreakState state,
    DateTime now, {
    int dailyGoal = 10,
  }) {
    final today = dateKey(now);
    final yesterday = previousDateKey(now);

    final isToday = state.lastActivityDate == today;

    final active =
        state.lastCompletedDate == today ||
        state.lastCompletedDate == yesterday;

    return StreakSnapshot(
      currentStreak: active ? state.currentStreak : 0,
      longestStreak: state.longestStreak,
      todayCorrectAnswers: isToday ? state.todayCorrectAnswers : 0,
      todaySources: isToday ? state.todaySources : const {},
      completedToday: state.lastCompletedDate == today,
      dailyGoal: dailyGoal,
    );
  }

  /// Zählt eine richtige Antwort. Ist das Tagesziel heute bereits erreicht,
  /// bleibt der Stand unverändert (keine zweite Erhöhung am selben Tag).
  static StreakUpdate record(
    StreakState state,
    DateTime now, {
    required String source,
    int dailyGoal = 10,
  }) {
    final today = dateKey(now);

    if (state.lastCompletedDate == today ||
        (state.lastActivityDate == today && state.streakCompletedToday)) {
      return StreakUpdate(state: state, changed: false, goalReachedNow: false);
    }

    final sameDay = state.lastActivityDate == today;

    final count = (sameDay ? state.todayCorrectAnswers : 0) + 1;

    final sources = <String, int>{if (sameDay) ...state.todaySources};
    sources[source] = (sources[source] ?? 0) + 1;

    if (count < dailyGoal) {
      return StreakUpdate(
        state: StreakState(
          trackId: state.trackId,
          currentStreak: state.currentStreak,
          longestStreak: state.longestStreak,
          lastActivityDate: today,
          lastCompletedDate: state.lastCompletedDate,
          todayCorrectAnswers: count,
          todaySources: sources,
          streakCompletedToday: false,
        ),
        changed: true,
        goalReachedNow: false,
      );
    }

    final continues = state.lastCompletedDate == previousDateKey(now);

    final streak = continues ? state.currentStreak + 1 : 1;

    return StreakUpdate(
      state: StreakState(
        trackId: state.trackId,
        currentStreak: streak,
        longestStreak: max(state.longestStreak, streak),
        lastActivityDate: today,
        lastCompletedDate: today,
        todayCorrectAnswers: count,
        todaySources: sources,
        streakCompletedToday: true,
      ),
      changed: true,
      goalReachedNow: true,
    );
  }
}
