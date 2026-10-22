import '../../../algorithms/vocabulary_plan.dart';

/// Lernplan für die griechischen Vokabeln: wie viele neue Vokabeln am Tag,
/// optional bis zu einem Zieldatum, und welche Lernschritte dazugehören.
///
/// Der Plan bestimmt nur, wie viele neue Vokabeln eine Lerneinheit
/// einführen darf; Wiederholungen wählt das Verfahren des Vokabeltrainers
/// (`LearningSelector`) nach Lernbedarf und Fälligkeit. Der freie
/// Vokabeltrainer bleibt davon unberührt.
class GreekVocabularyPlan extends VocabularyPlanRules {
  @override
  final int dailyNew;

  @override
  final DateTime? targetDate;

  @override
  final bool paused;

  final DateTime createdAt;

  /// Abgewählte Lernschritte. Gespeichert wird die Abwahl, damit später
  /// ergänzte Lernschritte ohne weiteres Zutun zum Plan gehören (wie im
  /// Vokabeltrainer).
  final Set<int> disabledSteps;

  static const int defaultDailyNew = 10;
  static const int maxDailyNew = 50;

  const GreekVocabularyPlan({
    required this.dailyNew,
    required this.createdAt,
    this.targetDate,
    this.paused = false,
    this.disabledSteps = const {},
  });

  bool includesStep(int step) => !disabledSteps.contains(step);

  @override
  bool includesUnit(int unit) => includesStep(unit);

  GreekVocabularyPlan copyWith({
    int? dailyNew,
    DateTime? targetDate,
    bool clearTargetDate = false,
    bool? paused,
    Set<int>? disabledSteps,
  }) {
    return GreekVocabularyPlan(
      dailyNew: dailyNew ?? this.dailyNew,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      paused: paused ?? this.paused,
      createdAt: createdAt,
      disabledSteps: disabledSteps ?? this.disabledSteps,
    );
  }

  /// `null` bei fehlendem oder unbrauchbarem Plan; einzelne ungültige
  /// Felder fallen auf die Vorgaben zurück.
  static GreekVocabularyPlan? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final daily = raw["dailyNew"];
    final created = raw["createdAt"];
    final target = raw["targetDate"];
    final disabled = raw["disabledSteps"];

    if (daily is! num || !daily.isFinite) return null;

    return GreekVocabularyPlan(
      dailyNew: daily.toInt().clamp(1, maxDailyNew),
      createdAt: created is num && created.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : DateTime.fromMillisecondsSinceEpoch(0),
      targetDate: target is num && target.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(target.toInt())
          : null,
      paused: raw["paused"] == true,
      disabledSteps: {
        if (disabled is List)
          for (final step in disabled)
            if (step is num && step.isFinite) step.toInt(),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    "dailyNew": dailyNew,
    "createdAt": createdAt.millisecondsSinceEpoch,
    "targetDate": targetDate?.millisecondsSinceEpoch,
    "paused": paused,
    "disabledSteps": disabledSteps.toList()..sort(),
  };
}
