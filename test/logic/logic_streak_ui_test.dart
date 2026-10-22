import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/models/logic/logic_course.dart';
import 'package:theologie_lernapp/screens/philosophy/logic/logic_course_screen.dart';
import 'package:theologie_lernapp/services/logic/logic_course_loader.dart';
import 'package:theologie_lernapp/services/logic/logic_progress_store.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/streak_widgets.dart';

import '../test_asset_bundle.dart';

/// Streak der „Einführung in die Logik“ in der Oberfläche. Eigene Datei:
/// Der gemeinsame [StreakService] und der Gast-Speicher dürfen keine
/// offenen Vorgänge aus anderen Widget-Tests übernehmen.

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LogicCourse course;
  final store = LocalLogicProgressStore();

  setUpAll(() async {
    course = await LogicCourseLoader.load(bundle: FileAssetBundle());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakService.instance.resetForTesting();
  });

  Future<void> pumpCourse(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LogicCourseScreen(
          uid: null,
          loadCourse: () async => course,
          store: store,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showLesson(WidgetTester tester, String id) async {
    await tester.scrollUntilVisible(key("logic-lesson-$id"), 200);
    await tester.ensureVisible(key("logic-lesson-$id"));
    await tester.pumpAndSettle();
  }

  group("Streak", () {
    int todayLogic() => StreakService.instance
        .snapshotFor(null, StreakTrack.logic)
        .todayCorrectAnswers;

    Future<bool> stored() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(LocalStreakRepository.storageKey);
      return raw != null && raw.contains("\"logic\"");
    }

    /// Wie in den übrigen Streak-UI-Tests: den gemeinsamen Service vor dem
    /// Test außerhalb der Fake-Zeit laden.
    Future<void> loadStreaks(WidgetTester tester) =>
        tester.runAsync(() => StreakService.instance.load(null, refresh: true));

    Future<void> openExercise(WidgetTester tester) async {
      await tester.tap(key("logic-lesson-l1"));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      await tester.tap(key("tab-exercises"));
      await tester.pumpAndSettle();
      // (¬(q ∨ s)) ist kein Satz.
      await tester.tap(key("exercise-l1.k1.iii"));
      await tester.pumpAndSettle();
    }

    Future<void> answer(WidgetTester tester, String which) async {
      await tester.tap(key(which));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("Übersicht zeigt die Logik-Streak mit Tagesziel", (
      tester,
    ) async {
      await pumpCourse(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is StreakDetailCard && w.track == StreakTrack.logic,
        ),
        findsOneWidget,
      );
      expect(find.text("0 von 5 richtig gelösten Übungen"), findsOneWidget);
    });

    testWidgets("Öffnen zählt nicht, eine richtig gelöste Übung zählt einmal", (
      tester,
    ) async {
      await loadStreaks(tester);
      await pumpCourse(tester);
      await showLesson(tester, "l1");
      await openExercise(tester);

      expect(todayLogic(), 0);
      expect(await tester.runAsync(stored), isFalse);

      await answer(tester, "answer-no-sentence");
      expect(todayLogic(), 1);
      expect(await tester.runAsync(stored), isTrue);

      // Dieselbe Bearbeitung meldet kein zweites Ergebnis.
      await tester.tap(key("answer-sentence"), warnIfMissed: false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(todayLogic(), 1);
    });

    testWidgets("„Zurück“ und erneut lösen zählt nicht noch einmal", (
      tester,
    ) async {
      await loadStreaks(tester);
      await pumpCourse(tester);
      await showLesson(tester, "l1");
      await openExercise(tester);

      await answer(tester, "answer-no-sentence");
      expect(todayLogic(), 1);

      await tester.tap(key("exercise-next"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Zurück"));
      await tester.pumpAndSettle();

      await answer(tester, "answer-no-sentence");
      expect(key("logic-outcome"), findsOneWidget);
      expect(todayLogic(), 1);
    });

    testWidgets("falsche Lösung zählt nicht", (tester) async {
      await loadStreaks(tester);
      await pumpCourse(tester);
      await showLesson(tester, "l1");
      await openExercise(tester);

      await answer(tester, "answer-sentence");
      expect(todayLogic(), 0);
      expect(await tester.runAsync(stored), isFalse);

      final p = await tester.runAsync(store.load);
      expect(p!.task("l1.k1.iii").lastCorrect, isFalse);
    });

    testWidgets("Lektion als bearbeitet markieren zählt nicht", (tester) async {
      await loadStreaks(tester);
      await pumpCourse(tester);
      await showLesson(tester, "l1");
      await tester.tap(key("logic-lesson-l1"));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      final done = find.text("Lektion als bearbeitet markieren");
      await tester.dragUntilVisible(
        done,
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      final p = await tester.runAsync(store.load);
      expect(p!.lesson("l1").isDone, isTrue);
      expect(todayLogic(), 0);
      expect(await tester.runAsync(stored), isFalse);
    });
  });
}
