import 'dart:math' as math;

/// Tagesrechnung der Lernpläne („Bücher systematisch lernen“, Latein-
/// Lernplan): wie viele neue Inhalte am Tag eingeführt werden, optional bis
/// zu einem Zieldatum. Der Plan schlägt nur vor; die Auswahl selbst folgt
/// dem Wiederholungsverfahren der App.
mixin DailyNewPlan {
  /// Gewünschte neue Inhalte pro Tag.
  int get dailyNew;

  /// Bis wann alle Inhalte eingeführt sein sollen (Datum ohne Uhrzeit).
  DateTime? get targetDate;

  static DateTime dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Verbleibende Lerntage bis einschließlich Zieldatum (mindestens 1).
  int? daysLeft(DateTime now) {
    final target = targetDate;

    if (target == null) return null;

    final days = dayOf(target).difference(dayOf(now)).inDays + 1;

    return math.max(1, days);
  }

  /// Neue Inhalte pro Tag, die für das Zieldatum nötig wären.
  int? requiredPerDay(int remainingNew, DateTime now) {
    final days = daysLeft(now);

    if (days == null) return null;

    return (remainingNew / days).ceil();
  }

  /// Wie viele neue Inhalte heute vorgeschlagen werden: die gewünschte
  /// Menge, mit Zieldatum mindestens die dafür nötige.
  int dailyTarget(int remainingNew, DateTime now) {
    final required = requiredPerDay(remainingNew, now) ?? 0;

    return math.max(dailyNew, required);
  }
}
