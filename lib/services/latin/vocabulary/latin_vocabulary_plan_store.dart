import '../../../models/latin/vocabulary/latin_vocabulary_plan.dart';
import '../../local_learning_store.dart';
import '../../quiz_documents.dart';

/// Gespeicherter Stand des Latein-Lernplans.
class LatinVocabularyPlanData {
  /// `null`: Es wurde (noch) kein Plan begonnen oder er wurde beendet.
  LatinVocabularyPlan? plan;

  /// Vokabel-ID → Zeitpunkt der Einführung im Lernplan. Je Vokabel nur ein
  /// Eintrag; eine spätere Einführung derselben Vokabel ändert ihn nicht.
  final Map<int, DateTime> introduced;

  LatinVocabularyPlanData({this.plan, Map<int, DateTime>? introduced})
    : introduced = introduced ?? {};

  /// Liest die beiden Dokumente; ungültige Einträge werden übergangen.
  factory LatinVocabularyPlanData.fromDocuments({
    Map<String, dynamic>? plan,
    Map<String, dynamic>? progress,
  }) {
    final raw = progress?["introduced"];

    return LatinVocabularyPlanData(
      plan: LatinVocabularyPlan.fromJson(plan?["plan"]),
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

/// Speicherort des Latein-Lernplans.
///
/// Kein neues Speichersystem: angemeldete Nutzer speichern unter
/// `users/{uid}/quiz_settings/` (wie Lernpläne in „Bücher systematisch
/// lernen“), Gäste lokal über den [LocalLearningStore]:
///
/// ```text
/// latin_vocabulary_plan:          plan:       {dailyNew, targetDate, paused, createdAt, disabledLessons}
/// latin_vocabulary_plan_progress: introduced: {vokabelId: ms}
/// ```
///
/// Der Lernstand je Vokabel ist die Karte des Vokabeltrainers (Collection
/// `latin_vocabulary`, über `LearningService`); Plan und Trainer teilen ihn.
/// Zurückgesetzt werden mit `ProgressArea.latinVocabulary` die Karten und
/// die Einführungen; der Plan selbst bleibt.
class LatinVocabularyPlanStore {
  final QuizDocuments documents;

  LatinVocabularyPlanStore(this.documents);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory LatinVocabularyPlanStore.forUser(String? uid) => uid == null
      ? LocalLatinVocabularyPlanStore()
      : LatinVocabularyPlanStore(FirestoreQuizDocuments(uid));

  static const String _planDoc = LocalLearningStore.latinVocabularyPlan;
  static const String _progressDoc =
      LocalLearningStore.latinVocabularyPlanProgress;

  Future<LatinVocabularyPlanData> load() async {
    final results = await Future.wait([
      documents.load(_planDoc),
      documents.load(_progressDoc),
    ]);

    return LatinVocabularyPlanData.fromDocuments(
      plan: results[0],
      progress: results[1],
    );
  }

  /// `null` beendet den Plan; die Einführungen bleiben erhalten. Der Plan
  /// wird als Ganzes gespeichert (abgewählte Lektionen sind eine Liste,
  /// `targetDate: null` entfernt das Zieldatum).
  Future<void> savePlan(LatinVocabularyPlan? plan) {
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
class LocalLatinVocabularyPlanStore extends LatinVocabularyPlanStore {
  LocalLatinVocabularyPlanStore() : super(LocalQuizDocuments());
}
