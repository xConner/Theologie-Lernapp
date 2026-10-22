import 'package:flutter/foundation.dart';

import '../../../models/greek/vocabulary/learning_card.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_plan.dart';
import '../../learning_service.dart';
import 'greek_vocabulary_loader.dart';
import 'greek_vocabulary_plan_state.dart';
import 'greek_vocabulary_plan_store.dart';

/// Laden und Speichern des Griechisch-Lernplans für einen Nutzer (uid == null:
/// Gastmodus). Die Screens halten nur Darstellung und Ablauf.
///
/// Gespeichert wird nur, was sich geändert hat: eine Karte je Antwort (wie
/// im Vokabeltrainer), eine Einführung je neuer Vokabel, der Plan bei
/// Änderung. Mehrfaches Öffnen oder Speichern erzeugt keine Doppel, weil
/// alles nach Vokabel-ID geschlüsselt ist.
class GreekVocabularyPlanService {
  final String? uid;

  final GreekVocabularyPlanStore store;

  final LearningService learning;

  final Future<List<GreekVocabularyEntry>> Function() _loadEntries;

  final DateTime Function()? clock;

  GreekVocabularyPlanService({
    required this.uid,
    GreekVocabularyPlanStore? store,
    LearningService? learning,
    Future<List<GreekVocabularyEntry>> Function()? loadEntries,
    this.clock,
  }) : store = store ?? GreekVocabularyPlanStore.forUser(uid),
       learning = learning ?? LearningService(),
       _loadEntries = loadEntries ?? GreekVocabularyLoader.load;

  Future<GreekVocabularyPlanState> load() async {
    final results = await Future.wait<Object>([
      _loadEntries(),
      learning.loadCards(uid),
      store.load(),
    ]);

    return GreekVocabularyPlanState(
      entries: results[0] as List<GreekVocabularyEntry>,
      cards: results[1] as Map<String, LearningCard>,
      data: results[2] as GreekVocabularyPlanData,
      clock: clock,
    );
  }

  /// Merkt die Einführung vor und speichert sie (nur beim ersten Mal).
  /// Ein Speicherfehler hält die Lerneinheit nicht auf.
  Future<void> introduce(
    GreekVocabularyPlanState state,
    GreekVocabularyEntry entry,
  ) async {
    if (!state.markIntroduced(entry)) return;

    try {
      await store.saveIntroduced({entry.id: state.data.introduced[entry.id]!});
    } catch (e) {
      debugPrint("Einführung konnte nicht gespeichert werden: $e");
    }
  }

  /// Speichert eine Karte, ohne die Oberfläche warten zu lassen: Firestore
  /// bestätigt offline erst später.
  void saveCard(LearningCard card) {
    learning.saveCard(uid, card).catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });
  }

  /// Speichert den Plan (`null` beendet ihn); Einführungen und Lernstände
  /// bleiben unverändert.
  Future<void> savePlan(
    GreekVocabularyPlanState state,
    GreekVocabularyPlan? plan,
  ) async {
    await store.savePlan(plan);

    state.data.plan = plan;
  }
}
