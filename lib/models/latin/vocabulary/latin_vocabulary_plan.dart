import '../../../algorithms/vocabulary_plan.dart';

/// Lernplan für die lateinischen Vokabeln: wie viele neue Vokabeln am Tag,
/// optional bis zu einem Zieldatum, und welche Lektionen dazugehören.
///
/// Der Plan bestimmt nur, wie viele neue Vokabeln eine Lerneinheit
/// einführen darf; Wiederholungen wählt das Verfahren des Vokabeltrainers
/// (`LearningSelector`) nach Lernbedarf und Fälligkeit. Der freie
/// Vokabeltrainer bleibt davon unberührt.
class LatinVocabularyPlan extends VocabularyPlanRules {
  @override
  final int dailyNew;

  @override
  final DateTime? targetDate;

  @override
  final bool paused;

  final DateTime createdAt;

  /// Abgewählte Lektionen. Gespeichert wird die Abwahl, damit später
  /// ergänzte Lektionen ohne weiteres Zutun zum Plan gehören (wie im
  /// Vokabeltrainer).
  final Set<int> disabledLessons;

  static const int defaultDailyNew = 10;
  static const int maxDailyNew = 50;

  const LatinVocabularyPlan({
    required this.dailyNew,
    required this.createdAt,
    this.targetDate,
    this.paused = false,
    this.disabledLessons = const {},
  });

  bool includesLesson(int lesson) => !disabledLessons.contains(lesson);

  @override
  bool includesUnit(int unit) => includesLesson(unit);

  LatinVocabularyPlan copyWith({
    int? dailyNew,
    DateTime? targetDate,
    bool clearTargetDate = false,
    bool? paused,
    Set<int>? disabledLessons,
  }) {
    return LatinVocabularyPlan(
      dailyNew: dailyNew ?? this.dailyNew,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      paused: paused ?? this.paused,
      createdAt: createdAt,
      disabledLessons: disabledLessons ?? this.disabledLessons,
    );
  }

  /// `null` bei fehlendem oder unbrauchbarem Plan; einzelne ungültige
  /// Felder fallen auf die Vorgaben zurück.
  static LatinVocabularyPlan? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final daily = raw["dailyNew"];
    final created = raw["createdAt"];
    final target = raw["targetDate"];
    final disabled = raw["disabledLessons"];

    if (daily is! num || !daily.isFinite) return null;

    return LatinVocabularyPlan(
      dailyNew: daily.toInt().clamp(1, maxDailyNew),
      createdAt: created is num && created.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : DateTime.fromMillisecondsSinceEpoch(0),
      targetDate: target is num && target.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(target.toInt())
          : null,
      paused: raw["paused"] == true,
      disabledLessons: {
        if (disabled is List)
          for (final lesson in disabled)
            if (lesson is num && lesson.isFinite) lesson.toInt(),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    "dailyNew": dailyNew,
    "createdAt": createdAt.millisecondsSinceEpoch,
    "targetDate": targetDate?.millisecondsSinceEpoch,
    "paused": paused,
    "disabledLessons": disabledLessons.toList()..sort(),
  };
}
