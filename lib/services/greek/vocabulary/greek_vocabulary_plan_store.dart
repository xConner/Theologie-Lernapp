import '../../../models/greek/vocabulary/greek_vocabulary_plan.dart';
import '../../local_learning_store.dart';
import '../../quiz_documents.dart';

/// Gespeicherter Stand des Griechisch-Lernplans.
class GreekVocabularyPlanData {
  /// `null`: Es wurde (noch) kein Plan begonnen oder er wurde beendet.
  GreekVocabularyPlan? plan;

  /// Vokabel-ID → Zeitpunkt der Einführung im Lernplan. Je Vokabel nur ein
  /// Eintrag; eine spätere Einführung derselben Vokabel ändert ihn nicht.
  final Map<int, DateTime> introduced;

  GreekVocabularyPlanData({this.plan, Map<int, DateTime>? introduced})
    : introduced = introduced ?? {};

  /// Liest die beiden Dokumente; ungültige Einträge werden übergangen.
  factory GreekVocabularyPlanData.fromDocuments({
    Map<String, dynamic>? plan,
    Map<String, dynamic>? progress,
  }) {
    final raw = progress?["introduced"];

    return GreekVocabularyPlanData(
      plan: GreekVocabularyPlan.fromJson(plan?["plan"]),
      introduced: {
        if (raw is Map)
          for (final entry in raw.entries)
            if (int.tryParse(entry.key.toString()) != null &&
                entry.value is num &&
                (entry.value as num).isFinite)
              int.parse(
                entry.key.toString(),
              ): DateTime.fromMillisecondsSinceEpoch(
                (entry.value as num).toInt(),
              ),
      },
    );
  }
}

/// Speicherort des Griechisch-Lernplans.
///
/// Kein neues Speichersystem: angemeldete Nutzer speichern unter
/// `users/{uid}/quiz_settings/` (wie Lernpläne in „Bücher systematisch
/// lernen“), Gäste lokal über den [LocalLearningStore]:
///
/// ```text
/// greek_vocabulary_plan:          plan:       {dailyNew, targetDate, paused, createdAt, disabledSteps}
/// greek_vocabulary_plan_progress: introduced: {vokabelId: ms}
/// ```
///
/// Der Lernstand je Vokabel ist die Karte des Vokabeltrainers (Collection
/// `vocabulary`, über `LearningService`); Plan und Trainer teilen ihn.
/// Zurückgesetzt werden mit `ProgressArea.greekVocabulary` die Karten und
/// die Einführungen; der Plan selbst bleibt.
class GreekVocabularyPlanStore {
  final QuizDocuments documents;

  GreekVocabularyPlanStore(this.documents);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory GreekVocabularyPlanStore.forUser(String? uid) => uid == null
      ? LocalGreekVocabularyPlanStore()
      : GreekVocabularyPlanStore(FirestoreQuizDocuments(uid));

  static const String _planDoc = LocalLearningStore.greekVocabularyPlan;
  static const String _progressDoc =
      LocalLearningStore.greekVocabularyPlanProgress;

  Future<GreekVocabularyPlanData> load() async {
    final results = await Future.wait([
      documents.load(_planDoc),
      documents.load(_progressDoc),
    ]);

    return GreekVocabularyPlanData.fromDocuments(
      plan: results[0],
      progress: results[1],
    );
  }

  /// `null` beendet den Plan; die Einführungen bleiben erhalten. Der Plan
  /// wird als Ganzes gespeichert (abgewählte Lernschritte sind eine Liste,
  /// `targetDate: null` entfernt das Zieldatum).
  Future<void> savePlan(GreekVocabularyPlan? plan) {
    if (plan == null) return documents.remove(_planDoc);

    return documents.replaceField(_planDoc, "plan", plan.toJson());
  }

  /// Ergänzt Einführungen (Merge, je Vokabel ein Eintrag).
  Future<void> saveIntroduced(Map<int, DateTime> introduced) {
    return documents.mergeEntries(_progressDoc, "introduced", {
      for (final entry in introduced.entries)
        "${entry.key}": entry.value.millisecondsSinceEpoch,
    });
  }
}

/// Gastmodus (lokale Speicherung).
class LocalGreekVocabularyPlanStore extends GreekVocabularyPlanStore {
  LocalGreekVocabularyPlanStore() : super(LocalQuizDocuments());
}
