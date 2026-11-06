import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/algorithms/trainer_introductions.dart';
import 'package:theologie_lernapp/algorithms/vocabulary_plan.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/models/latin/vocabulary/latin_vocabulary_entry.dart';
import 'package:theologie_lernapp/screens/greek/vocabulary_trainer_screen.dart';
import 'package:theologie_lernapp/screens/latin/latin_vocabulary_trainer_screen.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/greek_vocabulary_plan_service.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/greek_vocabulary_plan_state.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/greek_vocabulary_plan_store.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_plan_service.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_plan_store.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/self_assessment.dart';

/// Endlosmodus der Vokabeltrainer: Vokabeln, die noch nie drankamen, werden
/// wie im Lernplan zuerst vorgestellt und erst später abgefragt.

GreekVocabularyEntry _greek(int id) => GreekVocabularyEntry(
  id: id,
  step: 1,
  type: "adverb",
  lemma: "λόγος$id",
  translations: ["wort$id"],
);

LatinVocabularyEntry _latin(int id) => LatinVocabularyEntry(
  id: id,
  lesson: 1,
  type: "adverb",
  lemma: "verbum$id",
  translations: ["wort$id"],
);

LearningCard _seen(int id) =>
    LearningCard(id: "$id")..lastReviewed = DateTime(2026, 11, 1);

GreekVocabularyPlanState _state(
  List<GreekVocabularyEntry> entries, {
  Map<String, LearningCard>? cards,
  Map<int, DateTime>? introduced,
}) => GreekVocabularyPlanState(
  entries: entries,
  cards: cards ?? {},
  data: GreekVocabularyPlanData(introduced: introduced),
);

/// Wählt der Reihe nach die Vokabeln mit den angegebenen IDs.
GreekVocabularyEntry Function(List<GreekVocabularyEntry>) _script(
  List<int> ids,
) {
  var i = 0;

  return (pool) {
    final id = ids[i++];

    return pool.firstWhere((e) => e.id == id);
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Auswahl", () {
    test("Nie drangekommene Vokabel wird vorgestellt, nicht abgefragt", () {
      final entries = [_greek(1)];
      final queue = TrainerIntroductions(_state(entries));

      final task = queue.next(pool: entries, select: (p) => p.first);

      expect(task, isA<IntroduceTask<GreekVocabularyEntry>>());
      expect(task!.entry.id, 1);
    });

    test("Schon beantwortete oder im Plan eingeführte Vokabel wird "
        "direkt abgefragt", () {
      final entries = [_greek(1), _greek(2)];
      final queue = TrainerIntroductions(
        _state(
          entries,
          cards: {"1": _seen(1)},
          introduced: {2: DateTime(2026, 11, 1)},
        ),
      );

      for (final id in [1, 2]) {
        final task = queue.next(pool: entries, select: _script([id]));

        expect(task, isA<RecallTask<GreekVocabularyEntry>>());
        expect((task as RecallTask).afterIntroduction, isFalse);
      }
    });

    test("Vorgestellte Vokabel wird nach introGap anderen Fragen "
        "abgefragt", () {
      final entries = [_greek(1), _greek(2), _greek(3)];
      final state = _state(entries, cards: {"2": _seen(2), "3": _seen(3)});
      final queue = TrainerIntroductions(state);
      final select = _script([1, 2, 3]);

      final intro = queue.next(pool: entries, select: select);
      expect(intro, isA<IntroduceTask<GreekVocabularyEntry>>());
      state.markIntroduced(intro!.entry);
      expect(queue.pending.map((e) => e.id), [1]);

      expect(VocabularyPlanSession.introGap, 2);
      expect(queue.next(pool: entries, select: select)!.entry.id, 2);
      expect(queue.next(pool: entries, select: select)!.entry.id, 3);

      final recall = queue.next(
        pool: entries,
        select: (_) => fail("Fällige Abfrage braucht keine Auswahl"),
      );
      expect(recall, isA<RecallTask<GreekVocabularyEntry>>());
      expect(recall!.entry.id, 1);
      expect((recall as RecallTask).afterIntroduction, isTrue);
      expect(queue.pending, isEmpty);
    });

    test("Wird die vorgestellte Vokabel früher gewählt, wird sie abgefragt "
        "und nicht erneut vorgestellt", () {
      final entries = [_greek(1)];
      final state = _state(entries);
      final queue = TrainerIntroductions(state);

      expect(
        queue.next(pool: entries, select: (p) => p.first),
        isA<IntroduceTask<GreekVocabularyEntry>>(),
      );

      // Auch ohne gespeicherte Einführung (Speicherfehler) keine zweite.
      final again = queue.next(pool: entries, select: (p) => p.first);
      expect(again, isA<RecallTask<GreekVocabularyEntry>>());
      expect((again as RecallTask).afterIntroduction, isTrue);
      expect(queue.pending, isEmpty);
    });

    test("Durch Filter ausgeschlossene Vokabeln werden nicht nachgeholt", () {
      final entries = [_greek(1), _greek(2)];
      final queue = TrainerIntroductions(
        _state(entries, cards: {"2": _seen(2)}),
      );

      queue.next(pool: entries, select: _script([1]));
      expect(queue.pending, hasLength(1));

      final pool = [entries[1]];
      for (var i = 0; i < 4; i++) {
        expect(queue.next(pool: pool, select: (p) => p.first)!.entry.id, 2);
      }
      expect(queue.pending, isEmpty);
    });

    test("Leerer Pool: keine Aufgabe", () {
      final queue = TrainerIntroductions(_state([_greek(1)]));

      expect(queue.next(pool: const [], select: (p) => p.first), isNull);
    });
  });

  group("Oberfläche", () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    }

    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      StreakService.instance.resetForTesting();
    }

    testWidgets("Griechisch: neue Vokabel wird wie im Lernplan eingeführt", (
      tester,
    ) async {
      bigView(tester);

      await tester.runAsync(
        () => AnswerMethodPreference.save(
          AnswerMethodPreference.greekVocabulary,
          AnswerMethod.recall,
        ),
      );

      Widget app() => MaterialApp(
        theme: AppTheme.light,
        home: VocabularyTrainerScreen(
          planService: GreekVocabularyPlanService(
            uid: null,
            loadEntries: () async => [_greek(1)],
          ),
        ),
      );

      await tester.pumpWidget(app());
      await settle(tester);

      // Einführung: Lösung sichtbar, keine Abfrage und keine Bewertung.
      expect(find.byKey(const ValueKey("greek-plan-intro-next")), findsOne);
      expect(find.text("Neue Vokabel · Schritt 1"), findsOne);
      expect(find.text("wort1"), findsOne);
      expect(find.text("Lösung anzeigen"), findsNothing);
      expect(find.text("Prüfen"), findsNothing);
      expect(find.text("Gewusst"), findsNothing);

      final introduced = await tester.runAsync(
        () => LocalGreekVocabularyPlanStore().load(),
      );
      expect(introduced!.introduced.keys, [1]);
      expect(
        await tester.runAsync(() => LearningService().loadCards(null)),
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey("greek-plan-intro-next")));
      await settle(tester);

      // Danach die Abfrage der neuen Vokabel.
      expect(find.text("Neue Vokabel abfragen"), findsOne);
      expect(find.byKey(const ValueKey("greek-plan-intro-next")), findsNothing);

      await tester.tap(find.text("Lösung anzeigen"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Gewusst"));
      await settle(tester);

      final cards = await tester.runAsync(
        () => LearningService().loadCards(null),
      );
      expect(cards!.keys, ["1"]);

      // Einmal drangekommen: beim nächsten Öffnen keine Einführung mehr.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.byKey(const ValueKey("greek-plan-intro-next")), findsNothing);
      expect(find.text("Neue Vokabel abfragen"), findsNothing);
      expect(find.text("Lösung anzeigen"), findsOne);
    });

    testWidgets("Latein: neue Vokabel wird wie im Lernplan eingeführt", (
      tester,
    ) async {
      bigView(tester);

      await tester.runAsync(
        () => AnswerMethodPreference.save(
          AnswerMethodPreference.latinVocabulary,
          AnswerMethod.recall,
        ),
      );

      Widget app() => MaterialApp(
        theme: AppTheme.light,
        home: LatinVocabularyTrainerScreen(
          planService: LatinVocabularyPlanService(
            uid: null,
            loadEntries: () async => [_latin(1)],
          ),
        ),
      );

      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.byKey(const ValueKey("latin-plan-intro-next")), findsOne);
      expect(find.text("Neue Vokabel · Lektion 1"), findsOne);
      expect(
        find.byKey(const ValueKey("latin-plan-intro-translation")),
        findsOne,
      );
      expect(find.text("Lösung anzeigen"), findsNothing);
      expect(find.text("Gewusst"), findsNothing);

      final introduced = await tester.runAsync(
        () => LocalLatinVocabularyPlanStore().load(),
      );
      expect(introduced!.introduced.keys, [1]);

      await tester.tap(find.byKey(const ValueKey("latin-plan-intro-next")));
      await settle(tester);

      expect(find.text("Neue Vokabel abfragen"), findsOne);

      await tester.tap(find.text("Lösung anzeigen"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Gewusst"));
      await settle(tester);

      final cards = await tester.runAsync(
        () => LearningService().loadLatinCards(null),
      );
      expect(cards!.keys, ["1"]);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.byKey(const ValueKey("latin-plan-intro-next")), findsNothing);
      expect(find.text("Lösung anzeigen"), findsOne);
    });
  });
}
