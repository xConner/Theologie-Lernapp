import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/church_history/church_history_home_screen.dart';
import 'package:theologie_lernapp/screens/church_history/church_history_quiz_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_home_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_quiz_screen.dart';
import 'package:theologie_lernapp/services/church_history/church_history_quiz.dart';
import 'package:theologie_lernapp/services/church_history/church_history_store.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/quiz_option_button.dart';
import 'package:theologie_lernapp/widgets/streak_widgets.dart';

import 'church_history/church_history_test_data.dart';
import 'old_testament/old_testament_test_data.dart';
import 'lecture_materials_test_support.dart';

/// Streak-Erfassung in Kirchengeschichte und Altem Testament über die
/// Oberfläche: Erst eine richtig bewertete Antwort zählt (über
/// `reportTrainerAnswer`), Öffnen und falsche Antworten nicht, und die
/// Anzeige auf der Startseite des Bereichs liest denselben Stand.

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void main() {
  // Echte Inhalte: geschützte Vorlesungsunterlagen, nicht im Repository.
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials(
      "Streaks in Kirchengeschichte und Altem Testament",
    );
    return;
  }

  final churchHistory = loadChurchHistory();
  final oldTestament = loadOldTestament();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakService.instance.resetForTesting();
    // Kein Audio-Plugin im Test: Antwort-Sounds der Trainer (auch die
    // Ereigniskanäle je Player) bestätigen, ohne etwas abzuspielen.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.allMessagesHandler = (channel, handler, message) {
      if (channel.startsWith("xyz.luan/audioplayers")) {
        return Future.value(
          const StandardMethodCodec().encodeSuccessEnvelope(null),
        );
      }
      return handler?.call(message);
    };
    addTearDown(() => messenger.allMessagesHandler = null);
  });

  StreakSnapshot snap(StreakTrack track) =>
      StreakService.instance.snapshotFor(null, track);

  Future<Map<String, StreakState>> stored(WidgetTester tester) async =>
      (await tester.runAsync(LocalStreakRepository().loadAll))!;

  Future<void> start(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(
      () => StreakService.instance.load(null, refresh: true),
    );
    await tester.pumpWidget(_app(screen));
    await settle(tester);
  }

  group("Kirchengeschichte", () {
    Future<LocalChurchHistoryStore> storeWith(
      WidgetTester tester,
      ChurchHistorySettings settings,
    ) async {
      final store = LocalChurchHistoryStore();
      await tester.runAsync(() => store.saveSettings(settings));
      return store;
    }

    testWidgets("Wissensquiz: richtige Antwort zählt, Öffnen nicht", (
      tester,
    ) async {
      final store = await storeWith(
        tester,
        ChurchHistorySettings(
          scope: "lecture:lecture.02",
          kinds: {QuizKind.lecture},
        ),
      );

      await start(
        tester,
        ChurchHistoryQuizScreen(
          data: churchHistory,
          mode: QuizMode.knowledge,
          store: store,
          random: Random(2),
        ),
      );

      expect(snap(StreakTrack.churchHistory).todayCorrectAnswers, 0);
      expect(await stored(tester), isEmpty);

      final prompt = tester
          .widget<Text>(find.byKey(const ValueKey("quiz-prompt")))
          .data!;
      final question = churchHistory
          .lecture("lecture.02")!
          .questions
          .firstWhere((q) => q.prompt == prompt);

      await tester.tap(find.text(question.answer));
      await settle(tester);

      final s = snap(StreakTrack.churchHistory);
      expect(s.todayCorrectAnswers, 1);
      expect(s.todaySources, {StreakSource.knowledgeQuiz: 1});
      expect((await stored(tester))["church_history"]!.todayCorrectAnswers, 1);
      expect(snap(StreakTrack.oldTestament).todayCorrectAnswers, 0);
    });

    testWidgets("Chronologietrainer: nur richtige Antworten zählen", (
      tester,
    ) async {
      final store = await storeWith(
        tester,
        ChurchHistorySettings(kinds: {QuizKind.date, QuizKind.epoch}),
      );

      await start(
        tester,
        ChurchHistoryQuizScreen(
          data: churchHistory,
          mode: QuizMode.chronology,
          store: store,
          random: Random(5),
        ),
      );

      // Immer die erste Möglichkeit wählen und je nach Bewertung prüfen,
      // bis beide Fälle vorkamen.
      var right = 0;
      var wrong = 0;
      for (var i = 0; i < 30 && (right == 0 || wrong == 0); i++) {
        await tester.tap(find.byKey(const ValueKey("option-0")));
        await settle(tester);

        final ok =
            tester
                .widget<QuizOptionButton>(
                  find.byKey(const ValueKey("option-0")),
                )
                .state ==
            true;
        if (ok) {
          right++;
        } else {
          wrong++;
        }

        expect(
          snap(
                StreakTrack.churchHistory,
              ).todaySources[StreakSource.chronology] ??
              0,
          right,
          reason: "nach $right richtigen und $wrong falschen Antworten",
        );

        await tester.tap(find.byKey(const ValueKey("quiz-next")));
        await settle(tester);
      }

      expect(right, greaterThan(0));
      expect(wrong, greaterThan(0));
    });

    testWidgets("Startseite zeigt die Streak des Bereichs", (tester) async {
      await tester.runAsync(() async {
        await StreakService.instance.load(null, refresh: true);
        for (var i = 0; i < 10; i++) {
          await StreakService.instance.recordCorrectAnswer(
            uid: null,
            track: StreakTrack.churchHistory,
            source: StreakSource.knowledgeQuiz,
          );
        }
      });

      await start(
        tester,
        ChurchHistoryHomeScreen(
          data: churchHistory,
          store: LocalChurchHistoryStore(),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is StreakDetailCard && w.track == StreakTrack.churchHistory,
        ),
        findsOneWidget,
      );
      expect(find.text("1 Tag Streak"), findsOneWidget);
      expect(find.text("Tagesziel erreicht"), findsOneWidget);
    });
  });

  group("Altes Testament", () {
    Future<LocalOldTestamentStore> lectureOnly(WidgetTester tester) async {
      final store = LocalOldTestamentStore();
      await tester.runAsync(
        () => store.saveSettings(
          OldTestamentSettings(
            disabledKinds: OtQuizKind.values.toSet()
              ..remove(OtQuizKind.lecture),
          ),
        ),
      );
      return store;
    }

    Future<String> currentAnswer(WidgetTester tester) async {
      final prompt = tester
          .widget<Text>(find.byKey(const ValueKey("quiz-prompt")))
          .data!;
      return oldTestament
          .unit("unit.01")!
          .questions
          .firstWhere((q) => q.prompt == prompt)
          .answer;
    }

    testWidgets("richtige Antwort zählt, falsche und Öffnen nicht", (
      tester,
    ) async {
      final store = await lectureOnly(tester);

      await start(
        tester,
        OldTestamentQuizScreen(
          data: oldTestament,
          scope: const OtScope.unit("unit.01"),
          store: store,
          random: Random(3),
        ),
      );

      expect(snap(StreakTrack.oldTestament).todayCorrectAnswers, 0);
      expect(await stored(tester), isEmpty);

      // Falsche Antwort: eine andere Möglichkeit als die richtige.
      final answer = await currentAnswer(tester);
      final options = tester
          .widgetList<QuizOptionButton>(find.byType(QuizOptionButton))
          .map((b) => b.text)
          .where((t) => t != answer);
      await tester.tap(find.text(options.first));
      await settle(tester);

      expect(snap(StreakTrack.oldTestament).todayCorrectAnswers, 0);
      expect(await stored(tester), isEmpty);

      await tester.tap(find.byKey(const ValueKey("quiz-next")));
      await settle(tester);

      await tester.tap(find.text(await currentAnswer(tester)));
      await settle(tester);

      final s = snap(StreakTrack.oldTestament);
      expect(s.todayCorrectAnswers, 1);
      expect(s.todaySources, {StreakSource.oldTestamentQuiz: 1});
      expect((await stored(tester))["old_testament"]!.todayCorrectAnswers, 1);
      expect(snap(StreakTrack.churchHistory).todayCorrectAnswers, 0);
    });

    testWidgets("Startseite zeigt die Streak des Bereichs", (tester) async {
      await start(
        tester,
        OldTestamentHomeScreen(
          data: oldTestament,
          store: LocalOldTestamentStore(),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is StreakDetailCard && w.track == StreakTrack.oldTestament,
        ),
        findsOneWidget,
      );
      expect(find.text("Noch keine aktive Streak"), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}
