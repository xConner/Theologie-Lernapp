import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/algorithms/review_state.dart';
import 'package:theologie_lernapp/algorithms/vocabulary_plan.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_plan.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/screens/greek/plan/greek_vocabulary_plan_screen.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/greek_vocabulary_plan_service.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/greek_vocabulary_plan_state.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/greek_vocabulary_plan_store.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

/// Griechisch-Lernplan: dieselbe Planlogik wie Latein (gemeinsamer Kern
/// `algorithms/vocabulary_plan.dart`), Einheiten sind die Lernschritte.

/// Drei Lernschritte mit je vier Vokabeln (IDs 1–12), absichtlich nicht
/// nach Schritt sortiert.
List<GreekVocabularyEntry> _entries() => [
  for (final step in [3, 1, 2])
    for (var i = 0; i < 4; i++)
      GreekVocabularyEntry(
        id: (step - 1) * 4 + i + 1,
        step: step,
        type: "adverb",
        lemma: "λόγος${(step - 1) * 4 + i + 1}",
        translations: ["wort${(step - 1) * 4 + i + 1}"],
      ),
];

final DateTime _day = DateTime(2026, 10, 22, 9);

GreekVocabularyPlan _plan({int daily = 3, Set<int> disabled = const {}}) =>
    GreekVocabularyPlan(
      dailyNew: daily,
      createdAt: _day,
      disabledSteps: disabled,
    );

GreekVocabularyPlanState _state({
  GreekVocabularyPlan? plan,
  Map<String, LearningCard>? cards,
}) => GreekVocabularyPlanState(
  entries: _entries(),
  cards: cards ?? {},
  data: GreekVocabularyPlanData(plan: plan),
  clock: () => _day,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Plan und Planlogik", () {
    test("Plan übersteht Speichern und Laden", () {
      final plan = _plan(daily: 7, disabled: {8, 2}).copyWith(paused: true);
      final loaded = GreekVocabularyPlan.fromJson(plan.toJson())!;

      expect(loaded.dailyNew, 7);
      expect(loaded.paused, isTrue);
      expect(loaded.disabledSteps, {2, 8});
      expect(loaded.includesStep(2), isFalse);
      expect(loaded.includesUnit(3), isTrue);
      expect(plan.toJson()["disabledSteps"], [2, 8]);
    });

    test("neue Vokabeln Schritt für Schritt, abgewählte Schritte fehlen", () {
      var state = _state(plan: _plan(daily: 6));
      expect(state.units, [1, 2, 3]);
      expect(state.newToday.map((e) => e.id), [1, 2, 3, 4, 5, 6]);
      expect(state.currentUnit, 1);

      state = _state(plan: _plan(daily: 6, disabled: {1}));
      expect(state.planUnits, [2, 3]);
      expect(state.newToday.map((e) => e.id), [5, 6, 7, 8, 9, 10]);
    });

    test("Lernstand aus dem Vokabeltrainer gilt als eingeführt", () {
      final state = _state(
        plan: _plan(daily: 2),
        cards: {"1": LearningCard(id: "1", lastReviewed: _day)},
      );

      expect(state.statusOf(state.entries.first), isNot(ReviewState.fresh));
      expect(state.newToday.map((e) => e.id), [2, 3]);
    });

    test("Lerneinheit: vorgestellt, später abgefragt", () {
      final state = _state(plan: _plan(daily: 2));
      final session = VocabularyPlanSession(state: state, random: Random(1));

      final tasks = <PlanTask<GreekVocabularyEntry>>[];
      for (var task = session.next(); task != null; task = session.next()) {
        tasks.add(task);
        if (task is IntroduceTask<GreekVocabularyEntry>) {
          state.markIntroduced(task.entry);
        } else {
          session.answer(task.entry, true);
        }
      }

      final intros = tasks.whereType<IntroduceTask<GreekVocabularyEntry>>();
      final recalls = tasks.whereType<RecallTask<GreekVocabularyEntry>>();
      expect(intros.map((t) => t.entry.id), unorderedEquals([1, 2]));
      expect(recalls.map((t) => t.entry.id), unorderedEquals([1, 2]));
      expect(recalls.every((t) => t.afterIntroduction), isTrue);
      expect(state.cards.keys.toSet(), {"1", "2"});
    });
  });

  group("Speichern", () {
    test("Einführungen und Plan; Zurücksetzen behält den Plan", () async {
      final service = GreekVocabularyPlanService(
        uid: null,
        loadEntries: () async => _entries(),
        clock: () => _day,
      );

      var state = await service.load();
      await service.savePlan(state, _plan(daily: 2));
      await service.introduce(state, state.entries.first);
      await LearningService().saveCard(
        null,
        LearningCard(id: "1", lastReviewed: _day),
      );

      state = await service.load();
      expect(state.plan!.dailyNew, 2);
      expect(state.data.introduced, {1: _day});

      await ProgressDataService().resetArea(null, ProgressArea.greekVocabulary);

      final data = await LocalGreekVocabularyPlanStore().load();
      expect(data.plan!.dailyNew, 2);
      expect(data.introduced, isEmpty);
      expect(await LearningService().loadCards(null), isEmpty);
    });

    test("Gastdaten des Plans werden erkannt und übernommen", () async {
      expect(
        LocalLearningStore.quizDocuments,
        containsAll([
          LocalLearningStore.greekVocabularyPlan,
          LocalLearningStore.greekVocabularyPlanProgress,
        ]),
      );
      expect(
        LocalLearningStore.progressDocuments,
        contains(LocalLearningStore.greekVocabularyPlanProgress),
      );

      await LocalGreekVocabularyPlanStore().savePlan(_plan());
      expect(await LocalLearningStore.instance.hasGuestData(), isTrue);
    });
  });

  testWidgets("Oberfläche: Plan beginnen und Lerneinheit durchspielen", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    StreakService.instance.resetForTesting();

    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    GreekVocabularyPlanService service() => GreekVocabularyPlanService(
      uid: null,
      loadEntries: () async => _entries(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GreekVocabularyPlanScreen(service: service()),
      ),
    );
    await settle();

    await tester.tap(find.byKey(const ValueKey("greek-plan-start")));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const ValueKey("greek-plan-daily-minus")));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey("greek-plan-save")));
    await settle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey("greek-plan-new-today")))
          .data,
      "Neue Vokabeln: 2",
    );
    expect(find.text("Schritt 1 · aktuell"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("greek-plan-session")));
    await settle();

    for (var i = 0; i < 20; i++) {
      if (find
          .byKey(const ValueKey("greek-plan-session-summary"))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      final intro = find.byKey(const ValueKey("greek-plan-intro-next"));
      if (intro.evaluate().isNotEmpty) {
        await tester.tap(intro);
      } else {
        await tester.tap(find.text("Lösung anzeigen"));
        await tester.pumpAndSettle();
        await tester.tap(find.text("Gewusst"));
      }
      await settle();
    }

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey("greek-plan-session-summary")),
          )
          .data,
      "2 Antworten, davon 2 gewusst. 2 neue Vokabeln eingeführt.",
    );

    final cards = await tester.runAsync(
      () => LearningService().loadCards(null),
    );
    expect(cards!.keys.toSet(), {"1", "2"});
    expect(tester.takeException(), isNull);
  });
}
