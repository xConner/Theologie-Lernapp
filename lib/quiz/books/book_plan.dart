import '../../algorithms/daily_new_plan.dart';

/// Lernplan für ein Buch: wie viele neue Perikopen am Tag, optional bis zu
/// einem Zieldatum. Der Plan schlägt nur vor; jede Perikope bleibt frei
/// wählbar, und das Endlos-Quiz ist davon unberührt.
class BookPlan with DailyNewPlan {
  final String book;

  /// Gewünschte neue Perikopen pro Tag (1–50).
  @override
  final int dailyNew;

  /// Bis wann alle Perikopen eingeführt sein sollen (Datum ohne Uhrzeit).
  @override
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

  static DateTime dayOf(DateTime time) => DailyNewPlan.dayOf(time);
}
