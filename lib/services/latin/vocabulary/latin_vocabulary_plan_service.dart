import 'package:flutter/foundation.dart';

import '../../../models/greek/vocabulary/learning_card.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_plan.dart';
import '../../learning_service.dart';
import 'latin_vocabulary_loader.dart';
import 'latin_vocabulary_plan_state.dart';
import 'latin_vocabulary_plan_store.dart';

/// Laden und Speichern des Latein-Lernplans für einen Nutzer (uid == null:
/// Gastmodus). Die Screens halten nur Darstellung und Ablauf.
///
/// Gespeichert wird nur, was sich geändert hat: eine Karte je Antwort (wie
/// im Vokabeltrainer), eine Einführung je neuer Vokabel, der Plan bei
/// Änderung. Mehrfaches Öffnen oder Speichern erzeugt keine Doppel, weil
/// alles nach Vokabel-ID geschlüsselt ist.
class LatinVocabularyPlanService {
  final String? uid;

  final LatinVocabularyPlanStore store;

  final LearningService learning;

  final Future<List<LatinVocabularyEntry>> Function() _loadEntries;

  final DateTime Function()? clock;

  LatinVocabularyPlanService({
    required this.uid,
    LatinVocabularyPlanStore? store,
    LearningService? learning,
    Future<List<LatinVocabularyEntry>> Function()? loadEntries,
    this.clock,
  }) : store = store ?? LatinVocabularyPlanStore.forUser(uid),
       learning = learning ?? LearningService(),
       _loadEntries = loadEntries ?? LatinVocabularyLoader.load;

  Future<LatinVocabularyPlanState> load() async {
    final results = await Future.wait<Object>([
      _loadEntries(),
      learning.loadLatinCards(uid),
      store.load(),
    ]);

    return LatinVocabularyPlanState(
      entries: results[0] as List<LatinVocabularyEntry>,
      cards: results[1] as Map<String, LearningCard>,
      data: results[2] as LatinVocabularyPlanData,
      clock: clock,
    );
  }

  /// Merkt die Einführung vor und speichert sie (nur beim ersten Mal).
  /// Ein Speicherfehler hält die Lerneinheit nicht auf.
  Future<void> introduce(
    LatinVocabularyPlanState state,
    LatinVocabularyEntry entry,
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
    learning.saveLatinCard(uid, card).catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });
  }

  /// Speichert den Plan (`null` beendet ihn); Einführungen und Lernstände
  /// bleiben unverändert.
  Future<void> savePlan(
    LatinVocabularyPlanState state,
    LatinVocabularyPlan? plan,
  ) async {
    await store.savePlan(plan);

    state.data.plan = plan;
  }
}
