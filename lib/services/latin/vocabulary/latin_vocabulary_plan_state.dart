import '../../../algorithms/vocabulary_plan.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_plan.dart';
import 'latin_vocabulary_plan_store.dart';

/// Stand des Latein-Lernplans: Einheiten sind die Lektionen des Lehrbuchs.
/// Logik und Lerneinheit teilt er mit dem Griechisch-Lernplan
/// ([VocabularyPlanState], [VocabularyPlanSession]).
class LatinVocabularyPlanState
    extends VocabularyPlanState<LatinVocabularyEntry> {
  final LatinVocabularyPlanData data;

  LatinVocabularyPlanState({
    required super.entries,
    required super.cards,
    required this.data,
    super.clock,
  });

  LatinVocabularyPlan? get plan => data.plan;

  @override
  VocabularyPlanRules? get rules => data.plan;

  @override
  Map<int, DateTime> get introduced => data.introduced;

  @override
  int unitOf(LatinVocabularyEntry entry) => entry.lesson;

  @override
  int entryIdOf(LatinVocabularyEntry entry) => entry.id;

  @override
  double weightOf(LatinVocabularyEntry entry) => entry.weight;

  static String idOf(LatinVocabularyEntry entry) => entry.id.toString();

  /// Alle Lektionen der Vokabelliste (aufsteigend).
  List<int> get lessons => units;

  /// Lektionen des Plans (ohne Plan: alle).
  List<int> get planLessons => planUnits;

  List<LatinVocabularyEntry> entriesOfLesson(int lesson) =>
      entriesOfUnit(lesson);

  /// Die Lektion, an der der Plan gerade arbeitet.
  int? get currentLesson => currentUnit;
}

typedef LatinPlanTask = PlanTask<LatinVocabularyEntry>;
typedef LatinIntroduceTask = IntroduceTask<LatinVocabularyEntry>;
typedef LatinRecallTask = RecallTask<LatinVocabularyEntry>;

/// Lerneinheit des Latein-Lernplans (siehe [VocabularyPlanSession]).
class LatinPlanSession extends VocabularyPlanSession<LatinVocabularyEntry> {
  LatinPlanSession({
    required LatinVocabularyPlanState super.state,
    super.questions,
    super.random,
  });
}
