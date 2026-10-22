import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/algorithms/review_state.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/models/latin/vocabulary/latin_vocabulary_entry.dart';
import 'package:theologie_lernapp/models/latin/vocabulary/latin_vocabulary_plan.dart';
import 'package:theologie_lernapp/screens/latin/latin_vocabulary_answer_view.dart';
import 'package:theologie_lernapp/screens/latin/plan/latin_vocabulary_plan_screen.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_plan_service.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_plan_state.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_plan_store.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/self_assessment.dart';

/// Drei Lektionen mit je vier Vokabeln (IDs 1–12).
List<LatinVocabularyEntry> _entries({int lessons = 3, int perLesson = 4}) {
  return [
    for (var l = 1; l <= lessons; l++)
      for (var i = 0; i < perLesson; i++)
        LatinVocabularyEntry(
          id: (l - 1) * perLesson + i + 1,
          lesson: l,
          type: "adverb",
          lemma: "verbum${(l - 1) * perLesson + i + 1}",
          translations: ["wort${(l - 1) * perLesson + i + 1}"],
        ),
  ];
}

final DateTime _day = DateTime(2026, 10, 22, 9);

LatinVocabularyPlan _plan({
  int daily = 3,
  DateTime? target,
  bool paused = false,
  Set<int> disabled = const {},
}) {
  return LatinVocabularyPlan(
    dailyNew: daily,
    createdAt: _day,
    targetDate: target,
    paused: paused,
    disabledLessons: disabled,
  );
}

LatinVocabularyPlanState _state({
  LatinVocabularyPlan? plan,
  Map<String, LearningCard>? cards,
  Map<int, DateTime>? introduced,
  List<LatinVocabularyEntry>? entries,
  DateTime? now,
}) {
  return LatinVocabularyPlanState(
    entries: entries ?? _entries(),
    cards: cards ?? {},
    data: LatinVocabularyPlanData(plan: plan, introduced: introduced),
    clock: () => now ?? _day,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Plan und gespeichertes Format", () {
    test("Plan übersteht Speichern und Laden", () {
      final plan = _plan(
        daily: 7,
        target: DateTime(2026, 12, 1),
        paused: true,
        disabled: {3, 1},
      );

      final read = LatinVocabularyPlan.fromJson(plan.toJson())!;

      expect(read.dailyNew, 7);
      expect(read.targetDate, DateTime(2026, 12, 1));
      expect(read.paused, isTrue);
      expect(read.disabledLessons, {1, 3});
      expect(read.createdAt, _day);
      expect(plan.toJson()["disabledLessons"], [1, 3]);
    });

    test("ungültige Pläne und Einträge werden übergangen", () {
      expect(LatinVocabularyPlan.fromJson(null), isNull);
      expect(LatinVocabularyPlan.fromJson({"dailyNew": "x"}), isNull);
      expect(LatinVocabularyPlan.fromJson({"dailyNew": 500})!.dailyNew, 50);
      expect(LatinVocabularyPlan.fromJson({"dailyNew": 0})!.dailyNew, 1);

      final data = LatinVocabularyPlanData.fromDocuments(
        plan: {"plan": "kaputt"},
        progress: {
          "introduced": {"4": 1000, "x": 1000, "5": "gestern", "6": null},
        },
      );

      expect(data.plan, isNull);
      expect(data.introduced.keys, [4]);
    });
  });

  group("Planlogik", () {
    test("ohne Plan keine neuen Vokabeln, Umfang alle Lektionen", () {
      final state = _state();

      expect(state.newQuotaToday, 0);
      expect(state.newToday, isEmpty);
      expect(state.scope, hasLength(12));
      expect(state.planLessons, [1, 2, 3]);
    });

    test("neue Vokabeln des Tages in Lehrbuchreihenfolge", () {
      final state = _state(plan: _plan(daily: 3));

      expect(state.newToday.map((e) => e.id), [1, 2, 3]);
      expect(state.currentLesson, 1);
    });

    test("abgewählte Lektionen gehören nicht zum Plan", () {
      final state = _state(plan: _plan(daily: 5, disabled: {1}));

      expect(state.planLessons, [2, 3]);
      expect(state.newToday.map((e) => e.id), [5, 6, 7, 8, 9]);
      expect(state.progressOf(state.scope).total, 8);
    });

    test("Lernstände aus dem Vokabeltrainer werden übernommen", () {
      final reviewed = LearningCard(
        id: "1",
        stability: 48,
        lastReviewed: _day.subtract(const Duration(hours: 1)),
      );

      // Nur eine Eselsbrücke, nie beantwortet: weiter neu.
      final mnemonicOnly = LearningCard(id: "2", mnemonic: "Merkhilfe");

      final state = _state(
        plan: _plan(daily: 2),
        cards: {"1": reviewed, "2": mnemonicOnly},
      );

      expect(state.isIntroduced(state.entries[0]), isTrue);
      expect(state.statusOf(state.entries[0]), ReviewState.stable);
      expect(state.statusOf(state.entries[1]), ReviewState.fresh);
      expect(state.newToday.map((e) => e.id), [2, 3]);
    });

    test("heute Eingeführtes zählt auf das Tagesziel", () {
      final state = _state(
        plan: _plan(daily: 3),
        introduced: {1: _day, 2: _day.subtract(const Duration(days: 1))},
      );

      // Vokabel 2 stammt von gestern, Vokabel 1 von heute.
      expect(state.introducedOn(_day).map((e) => e.id), [1]);
      expect(state.newQuotaToday, 2);
      expect(state.newToday.map((e) => e.id), [3, 4]);

      // Eingeführt, aber noch nie abgefragt: zum Wiederholen.
      expect(state.statusOf(state.entries[0]), ReviewState.due);
      expect(state.dueReviews.map((e) => e.id), containsAll([1, 2]));
    });

    test("am nächsten Tag gibt es wieder neue Vokabeln", () {
      final introduced = {1: _day, 2: _day, 3: _day};

      expect(
        _state(plan: _plan(daily: 3), introduced: introduced).newQuotaToday,
        0,
      );

      final tomorrow = _state(
        plan: _plan(daily: 3),
        introduced: introduced,
        now: _day.add(const Duration(days: 1)),
      );

      expect(tomorrow.newToday.map((e) => e.id), [4, 5, 6]);
    });

    test("pausierter Plan führt nichts Neues ein", () {
      final state = _state(plan: _plan(paused: true));

      expect(state.newToday, isEmpty);
      expect(state.expectedCompletion, isNull);
    });

    test("Zieldatum erhöht die Tagesmenge", () {
      // 12 Vokabeln in 2 Tagen (heute und morgen) → 6 pro Tag.
      final state = _state(
        plan: _plan(daily: 2, target: DateTime(2026, 10, 23)),
      );

      expect(state.newQuotaToday, 6);
      expect(state.expectedCompletion, DateTime(2026, 10, 23));
    });

    test("voraussichtliches Ende nach Tagesmenge", () {
      final state = _state(plan: _plan(daily: 5));

      // 12 Vokabeln: heute 5, morgen 5, übermorgen 2.
      expect(state.expectedCompletion, DateTime(2026, 10, 24));
    });

    test("Einführung wird nur einmal vermerkt", () {
      final state = _state(plan: _plan());

      expect(state.markIntroduced(state.entries[0]), isTrue);

      final first = state.data.introduced[1];

      expect(state.markIntroduced(state.entries[0]), isFalse);
      expect(state.data.introduced[1], first);
    });
  });

  group("Lerneinheit", () {
    /// Spielt eine Einheit durch; [answer] entscheidet je Abfrage.
    List<LatinPlanTask> play(
      LatinVocabularyPlanState state,
      LatinPlanSession session, {
      bool Function(LatinVocabularyEntry)? answer,
    }) {
      final tasks = <LatinPlanTask>[];

      for (var i = 0; i < 200; i++) {
        final task = session.next();

        if (task == null) break;

        tasks.add(task);

        if (task is LatinIntroduceTask) {
          state.markIntroduced(task.entry);
        } else {
          session.answer(task.entry, answer?.call(task.entry) ?? true);
        }
      }

      return tasks;
    }

    test("ohne Plan und ohne Lernstand nichts zu tun", () {
      final state = _state();

      expect(LatinPlanSession(state: state).next(), isNull);
    });

    test("neue Vokabeln: vorgestellt, später abgefragt, keine Doppel", () {
      final state = _state(plan: _plan(daily: 4));
      final session = LatinPlanSession(state: state, random: Random(1));

      final tasks = play(state, session);

      final intros = tasks.whereType<LatinIntroduceTask>().toList();
      final recalls = tasks.whereType<LatinRecallTask>().toList();

      expect(intros.map((t) => t.entry.id).toSet(), {1, 2, 3, 4});
      expect(intros, hasLength(4));

      // Jede Vokabel genau einmal abgefragt (alles richtig).
      expect(recalls.map((t) => t.entry.id).toList()..sort(), [1, 2, 3, 4]);

      for (final intro in intros) {
        final introAt = tasks.indexOf(intro);
        final askAt = tasks.indexWhere(
          (t) => t is LatinRecallTask && t.entry.id == intro.entry.id,
        );

        // Nach der Einführung; zum Ende der Einheit auch direkt danach.
        expect(askAt, greaterThan(introAt));
      }

      expect(state.newToday, isEmpty);
      expect(session.introduced, 4);
      expect(session.answered, 4);
    });

    test("nach einem Fehler genau eine weitere Abfrage", () {
      final state = _state(plan: _plan(daily: 4));
      final session = LatinPlanSession(state: state, random: Random(2));

      final tasks = play(state, session, answer: (e) => e.id != 2);

      final asks = tasks
          .whereType<LatinRecallTask>()
          .where((t) => t.entry.id == 2)
          .length;

      expect(asks, 2);
      expect(session.asked, 4);
    });

    test("Wiederholungen: höchstens die geplante Zahl an Abfragen", () {
      final long = _day.subtract(const Duration(days: 30));

      final cards = {
        for (var id = 1; id <= 12; id++)
          "$id": LearningCard(id: "$id", stability: 24, lastReviewed: long),
      };

      final state = _state(plan: _plan(paused: true), cards: cards);
      final session = LatinPlanSession(
        state: state,
        questions: 5,
        random: Random(3),
      );

      final tasks = play(state, session);

      expect(tasks.whereType<LatinIntroduceTask>(), isEmpty);
      expect(tasks, hasLength(5));
      expect(tasks.map((t) => t.entry.id).toSet(), hasLength(5));

      // Gemeinsamer Lernstand: die Karten des Trainers wurden verbucht.
      final answered = tasks.map((t) => "${t.entry.id}").toSet();

      for (final id in answered) {
        expect(cards[id]!.lastReviewed, _day);
      }
    });
  });

  group("Speichern", () {
    test("Einführungen und Plan bleiben getrennt erhalten", () async {
      final service = LatinVocabularyPlanService(
        uid: null,
        loadEntries: () async => _entries(),
        clock: () => _day,
      );

      var state = await service.load();

      await service.savePlan(state, _plan(daily: 2));
      await service.introduce(state, state.entries[0]);
      // Doppeltes Einführen (z. B. erneutes Öffnen) ändert nichts.
      await service.introduce(state, state.entries[0]);

      state = await service.load();

      expect(state.plan!.dailyNew, 2);
      expect(state.data.introduced, {1: _day});

      // Plan ändern: Einführungen und Karten bleiben.
      await LearningService().saveLatinCard(
        null,
        LearningCard(id: "1", lastReviewed: _day),
      );
      await service.savePlan(
        state,
        state.plan!.copyWith(dailyNew: 9, disabledLessons: {2}),
      );

      state = await service.load();

      expect(state.plan!.dailyNew, 9);
      expect(state.plan!.disabledLessons, {2});
      expect(state.data.introduced.keys, [1]);
      expect(state.cardOf(state.entries[0])!.lastReviewed, _day);

      // Zieldatum und Abwahl lassen sich wieder entfernen.
      await service.savePlan(
        state,
        state.plan!.copyWith(
          targetDate: DateTime(2027),
          disabledLessons: const {},
        ),
      );
      await service.savePlan(
        state,
        state.plan!.copyWith(clearTargetDate: true),
      );

      state = await service.load();

      expect(state.plan!.targetDate, isNull);
      expect(state.plan!.disabledLessons, isEmpty);

      // Plan beenden: Einführungen bleiben, ein neuer Plan setzt fort.
      await service.savePlan(state, null);

      state = await service.load();

      expect(state.plan, isNull);
      expect(state.isIntroduced(state.entries[0]), isTrue);
    });

    test(
      "Zurücksetzen löscht Lernstand und Einführungen, nicht den Plan",
      () async {
        final store = LocalLatinVocabularyPlanStore();

        await store.savePlan(_plan(daily: 4));
        await store.saveIntroduced({3: _day});
        await LearningService().saveLatinCard(
          null,
          LearningCard(id: "3", lastReviewed: _day),
        );

        await ProgressDataService().resetArea(
          null,
          ProgressArea.latinVocabulary,
        );

        var data = await store.load();

        expect(data.plan!.dailyNew, 4);
        expect(data.introduced, isEmpty);
        expect(await LearningService().loadLatinCards(null), isEmpty);

        await store.saveIntroduced({5: _day});
        await ProgressDataService().resetProgress(null);

        data = await store.load();

        expect(data.plan, isNotNull);
        expect(data.introduced, isEmpty);
      },
    );

    test("Gastdaten des Plans werden erkannt und übernommen", () async {
      expect(
        LocalLearningStore.quizDocuments,
        containsAll([
          LocalLearningStore.latinVocabularyPlan,
          LocalLearningStore.latinVocabularyPlanProgress,
        ]),
      );

      await LocalLatinVocabularyPlanStore().savePlan(_plan());

      expect(await LocalLearningStore.instance.hasGuestData(), isTrue);
    });
  });

  group("Oberfläche", () {
    Widget app(LatinVocabularyPlanService service) {
      return MaterialApp(
        theme: AppTheme.light,
        home: LatinVocabularyPlanScreen(service: service),
      );
    }

    void largeView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    setUp(() => StreakService.instance.resetForTesting());

    testWidgets("ohne Vokabeln erscheint ein Leerzustand", (tester) async {
      await tester.pumpWidget(
        app(LatinVocabularyPlanService(uid: null, loadEntries: () async => [])),
      );
      await settle(tester);

      expect(find.textContaining("Noch keine Vokabeln vorhanden"), findsOne);
    });

    testWidgets("Plan beginnen, Lerneinheit, Fortsetzen nach Neustart", (
      tester,
    ) async {
      largeView(tester);

      LatinVocabularyPlanService service() => LatinVocabularyPlanService(
        uid: null,
        loadEntries: () async => _entries(),
      );

      // Im Kopf beantworten: unabhängig von den Eingabefeldern.
      await tester.runAsync(
        () => AnswerMethodPreference.save(
          AnswerMethodPreference.latinVocabulary,
          AnswerMethod.recall,
        ),
      );

      await tester.pumpWidget(app(service()));
      await settle(tester);

      expect(find.byKey(const ValueKey("latin-plan-start")), findsOne);

      await tester.tap(find.byKey(const ValueKey("latin-plan-start")));
      await tester.pumpAndSettle();

      // 10 → 2 neue pro Tag.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(const ValueKey("latin-plan-daily-minus")));
        await tester.pump();
      }

      await tester.tap(find.byKey(const ValueKey("latin-plan-save")));
      await settle(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey("latin-plan-new-today")))
            .data,
        "Neue Vokabeln: 2",
      );

      await tester.tap(find.byKey(const ValueKey("latin-plan-session")));
      await settle(tester);

      // Einheit durchspielen: Einführungen weiter, Abfragen „gewusst“.
      for (var i = 0; i < 20; i++) {
        if (find
            .byKey(const ValueKey("latin-plan-session-summary"))
            .evaluate()
            .isNotEmpty) {
          break;
        }

        final intro = find.byKey(const ValueKey("latin-plan-intro-next"));

        if (intro.evaluate().isNotEmpty) {
          await tester.tap(intro);
        } else {
          await tester.tap(find.text("Lösung anzeigen"));
          await tester.pumpAndSettle();
          await tester.tap(find.text("Gewusst"));
        }

        await settle(tester);
      }

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey("latin-plan-session-summary")),
            )
            .data,
        "2 Antworten, davon 2 richtig. 2 neue Vokabeln eingeführt.",
      );

      // Neustart: neuer Screen, alles aus dem Speicher.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await settle(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey("latin-plan-new-today")))
            .data,
        "Neue Vokabeln: 0 (schon eingeführt: 2)",
      );

      final data = await tester.runAsync(
        () => LocalLatinVocabularyPlanStore().load(),
      );

      expect(data!.introduced.keys.toSet(), {1, 2});

      final cards = await tester.runAsync(
        () => LearningService().loadLatinCards(null),
      );

      expect(cards!.keys.toSet(), {"1", "2"});
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets("Handybreite: Übersicht ohne Überläufe", (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final store = LocalLatinVocabularyPlanStore();
      await store.savePlan(_plan(daily: 3, target: DateTime(2030)));
      await store.saveIntroduced({1: DateTime.now()});
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LatinVocabularyPlanScreen(
          service: LatinVocabularyPlanService(
            uid: null,
            loadEntries: () async => _entries(),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("latin-plan-description")), findsOne);

    await tester.tap(find.byKey(const ValueKey("latin-plan-edit")));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("latin-plan-paused")), findsOne);
    expect(tester.takeException(), isNull);
  });

  group("Abfrage-Baustein", () {
    testWidgets("Eingabe wird einmal bewertet, Enter führt weiter", (
      tester,
    ) async {
      final evaluations = <(bool, bool)>[];
      var next = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LatinVocabularyAnswerView(
                entry: _entries().first,
                settings: const LatinVocabularySettings(),
                method: AnswerMethod.typing,
                onMethodChanged: (_) {},
                onEvaluated: (correct, {required firstEvaluation}) =>
                    evaluations.add((correct, firstEvaluation)),
                onNext: () => next++,
                mnemonic: null,
                onSaveMnemonic: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "wort1");
      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.text("Richtig"), findsOne);
      expect(evaluations, [(true, true)]);

      await tester.tap(find.text("Weiter"));
      await tester.pump();

      expect(next, 1);
      expect(evaluations, hasLength(1));
    });
  });
}
