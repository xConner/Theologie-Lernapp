import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/latin/vocabulary/latin_vocabulary_plan.dart';
import '../../local_learning_store.dart';

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
abstract class LatinVocabularyPlanStore {
  Future<LatinVocabularyPlanData> load();

  /// `null` beendet den Plan; die Einführungen bleiben erhalten.
  Future<void> savePlan(LatinVocabularyPlan? plan);

  /// Ergänzt Einführungen (Merge, je Vokabel ein Eintrag).
  Future<void> saveIntroduced(Map<int, DateTime> introduced);

  factory LatinVocabularyPlanStore.forUser(String? uid) => uid == null
      ? LocalLatinVocabularyPlanStore()
      : FirestoreLatinVocabularyPlanStore(uid);
}

class LocalLatinVocabularyPlanStore implements LatinVocabularyPlanStore {
  LocalLearningStore get _store => LocalLearningStore.instance;

  static const String _planDoc = LocalLearningStore.latinVocabularyPlan;
  static const String _progressDoc =
      LocalLearningStore.latinVocabularyPlanProgress;

  @override
  Future<LatinVocabularyPlanData> load() async {
    return LatinVocabularyPlanData.fromDocuments(
      plan: await _store.loadQuizDocument(_planDoc),
      progress: await _store.loadQuizDocument(_progressDoc),
    );
  }

  @override
  Future<void> savePlan(LatinVocabularyPlan? plan) {
    if (plan == null) return _store.removeQuizDocument(_planDoc);

    // Jedes Feld wird ersetzt; `targetDate: null` entfernt das Zieldatum.
    return _store.mergeQuizDocument(_planDoc, "plan", plan.toJson());
  }

  @override
  Future<void> saveIntroduced(Map<int, DateTime> introduced) {
    if (introduced.isEmpty) return Future.value();

    return _store.mergeQuizDocument(_progressDoc, "introduced", {
      for (final entry in introduced.entries)
        "${entry.key}": entry.value.millisecondsSinceEpoch,
    });
  }
}

class FirestoreLatinVocabularyPlanStore implements LatinVocabularyPlanStore {
  final String uid;

  FirestoreLatinVocabularyPlanStore(this.uid);

  DocumentReference<Map<String, dynamic>> _doc(String name) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("quiz_settings")
        .doc(name);
  }

  @override
  Future<LatinVocabularyPlanData> load() async {
    final results = await Future.wait([
      _doc(LocalLearningStore.latinVocabularyPlan).get(),
      _doc(LocalLearningStore.latinVocabularyPlanProgress).get(),
    ]);

    return LatinVocabularyPlanData.fromDocuments(
      plan: results[0].data(),
      progress: results[1].data(),
    );
  }

  @override
  Future<void> savePlan(LatinVocabularyPlan? plan) {
    final doc = _doc(LocalLearningStore.latinVocabularyPlan);

    // Ganzer Plan statt Merge: abgewählte Lektionen sind eine Liste, die
    // sonst nicht verkleinert werden könnte.
    return plan == null ? doc.delete() : doc.set({"plan": plan.toJson()});
  }

  @override
  Future<void> saveIntroduced(Map<int, DateTime> introduced) {
    if (introduced.isEmpty) return Future.value();

    // Gleiches Format wie lokal, damit die Übernahme von Gastdaten das
    // Dokument unverändert kopiert.
    return _doc(LocalLearningStore.latinVocabularyPlanProgress).set({
      "introduced": {
        for (final entry in introduced.entries)
          "${entry.key}": entry.value.millisecondsSinceEpoch,
      },
    }, SetOptions(merge: true));
  }
}
