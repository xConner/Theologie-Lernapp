import 'dart:math' as math;

/// Lernplan für ein Buch: wie viele neue Perikopen am Tag, optional bis zu
/// einem Zieldatum. Der Plan schlägt nur vor; jede Perikope bleibt frei
/// wählbar, und das Endlos-Quiz ist davon unberührt.
class BookPlan {
  final String book;

  /// Gewünschte neue Perikopen pro Tag (1–50).
  final int dailyNew;

  /// Bis wann alle Perikopen eingeführt sein sollen (Datum ohne Uhrzeit).
  final DateTime? targetDate;

  final bool paused;

  final DateTime createdAt;

  static const int defaultDailyNew = 3;
  static const int maxDailyNew = 50;

  const BookPlan({
    required this.book,
    required this.dailyNew,
    required this.createdAt,
    this.targetDate,
    this.paused = false,
  });

  BookPlan copyWith({
    int? dailyNew,
    DateTime? targetDate,
    bool clearTargetDate = false,
    bool? paused,
  }) {
    return BookPlan(
      book: book,
      dailyNew: dailyNew ?? this.dailyNew,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      paused: paused ?? this.paused,
      createdAt: createdAt,
    );
  }

  static BookPlan? fromJson(String book, Object? raw) {
    if (raw is! Map) return null;

    final daily = raw["dailyNew"];
    final created = raw["createdAt"];
    final target = raw["targetDate"];
    final paused = raw["paused"];

    if (daily is! num || !daily.isFinite) return null;

    return BookPlan(
      book: book,
      dailyNew: daily.toInt().clamp(1, maxDailyNew),
      createdAt: created is num && created.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : DateTime.fromMillisecondsSinceEpoch(0),
      targetDate: target is num && target.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(target.toInt())
          : null,
      paused: paused == true,
    );
  }

  Map<String, dynamic> toJson() => {
    "dailyNew": dailyNew,
    "createdAt": createdAt.millisecondsSinceEpoch,
    "targetDate": targetDate?.millisecondsSinceEpoch,
    "paused": paused,
  };

  static DateTime dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Verbleibende Lerntage bis einschließlich Zieldatum (mindestens 1).
  int? daysLeft(DateTime now) {
    final target = targetDate;

    if (target == null) return null;

    final days = dayOf(target).difference(dayOf(now)).inDays + 1;

    return math.max(1, days);
  }

  /// Neue Perikopen pro Tag, die für das Zieldatum nötig wären.
  int? requiredPerDay(int remainingNew, DateTime now) {
    final days = daysLeft(now);

    if (days == null) return null;

    return (remainingNew / days).ceil();
  }

  /// Wie viele neue Perikopen heute vorgeschlagen werden: die gewünschte
  /// Menge, mit Zieldatum mindestens die dafür nötige.
  int dailyTarget(int remainingNew, DateTime now) {
    final required = requiredPerDay(remainingNew, now) ?? 0;

    return math.max(dailyNew, required);
  }
}
