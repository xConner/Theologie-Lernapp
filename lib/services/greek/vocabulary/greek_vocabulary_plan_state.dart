import '../../../algorithms/vocabulary_plan.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_plan.dart';
import 'greek_vocabulary_plan_store.dart';

/// Stand des Griechisch-Lernplans: Einheiten sind die Lernschritte der
/// Vokabelliste (1–8). Logik und Lerneinheit wie im Latein-Lernplan
/// ([VocabularyPlanState], [VocabularyPlanSession]); der Lernstand je
/// Vokabel ist die Karte des Vokabeltrainers.
class GreekVocabularyPlanState
    extends VocabularyPlanState<GreekVocabularyEntry> {
  final GreekVocabularyPlanData data;

  GreekVocabularyPlanState({
    required super.entries,
    required super.cards,
    required this.data,
    super.clock,
  });

  GreekVocabularyPlan? get plan => data.plan;

  @override
  VocabularyPlanRules? get rules => data.plan;

  @override
  Map<int, DateTime> get introduced => data.introduced;

  @override
  int unitOf(GreekVocabularyEntry entry) => entry.step;

  @override
  int entryIdOf(GreekVocabularyEntry entry) => entry.id;

  @override
  double weightOf(GreekVocabularyEntry entry) => entry.weight;
}
