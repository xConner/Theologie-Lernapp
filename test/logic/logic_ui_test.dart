import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/models/logic/logic_course.dart';
import 'package:theologie_lernapp/screens/philosophy/logic/logic_course_screen.dart';
import 'package:theologie_lernapp/screens/philosophy/philosophy_home_screen.dart';
import 'package:theologie_lernapp/services/logic/logic_course_loader.dart';
import 'package:theologie_lernapp/services/logic/logic_progress_store.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import '../test_asset_bundle.dart';

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

  Future<void> pumpCourse(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets("Philosophie listet den Lernbereich", (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PhilosophyHomeScreen(uid: null)),
    );
    expect(find.text("Einführung in die Logik"), findsOneWidget);
  });

  testWidgets("Übersicht zeigt alle Lektionen mit Status", (tester) async {
    await pumpCourse(tester);
    expect(find.text("Syntax der Aussagenlogik"), findsWidgets);
    await tester.scrollUntilVisible(key("logic-lesson-l9"), 200);
    expect(key("logic-lesson-l9"), findsOneWidget);
    expect(find.text("offen"), findsWidgets);
  });

  /// Die Streak-Karte steht über den Lektionen; die Lektion erst sichtbar
  /// machen.
  Future<void> showLesson(WidgetTester tester, String id) async {
    await tester.scrollUntilVisible(key("logic-lesson-$id"), 200);
    await tester.ensureVisible(key("logic-lesson-$id"));
    await tester.pumpAndSettle();
  }

  testWidgets("Lehrtext öffnen, Übung lösen, Fortschritt wird gespeichert", (tester) async {
    await pumpCourse(tester);

    await showLesson(tester, "l1");
    await tester.tap(key("logic-lesson-l1"));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    // Lehrtext mit Definition 1.2.
    expect(find.textContaining("Definition 1.2"), findsWidgets);

    await tester.tap(key("tab-exercises"));
    await tester.pumpAndSettle();

    // (¬(q ∨ s)) ist kein Satz.
    await tester.tap(key("exercise-l1.k1.iii"));
    await tester.pumpAndSettle();
    await tester.tap(key("answer-no-sentence"));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(key("logic-outcome"), findsOneWidget);
    expect(find.textContaining("ist kein Satz"), findsWidgets);

    final p = await tester.runAsync(store.load);
    expect(p!.task("l1.k1.iii").lastCorrect, isTrue);
    expect(p.lesson("l1").isStarted, isTrue);
  });

  testWidgets("Beweiseditor prüft einen Beweis", (tester) async {
    await pumpCourse(tester);
    await tester.scrollUntilVisible(key("logic-lesson-l4"), 200);
    await tester.ensureVisible(key("logic-lesson-l4"));
    await tester.pumpAndSettle();
    await tester.tap(key("logic-lesson-l4"));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await tester.tap(key("tab-exercises"));
    await tester.pumpAndSettle();

    // ¬¬q → r, ¬r ⊢ ¬q
    await tester.scrollUntilVisible(
      key("exercise-l4.k2.i"),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.ensureVisible(key("exercise-l4.k2.i"));
    await tester.pumpAndSettle();
    await tester.tap(key("exercise-l4.k2.i"));
    await tester.pumpAndSettle();

    await tester.enterText(key("proof-formula-0"), "¬¬q → r");

    Future<void> addLine(String which) async {
      await tester.ensureVisible(key(which));
      await tester.tap(key(which));
      await tester.pumpAndSettle();
    }

    Future<void> chooseRule(int line, String symbol) async {
      await tester.ensureVisible(key("proof-rule-$line"));
      await tester.tap(key("proof-rule-$line"));
      await tester.pumpAndSettle();
      await tester.tap(find.text(symbol).last);
      await tester.pumpAndSettle();
    }

    await addLine("proof-add-line");
    await tester.enterText(key("proof-formula-1"), "¬q ∨ r");
    await chooseRule(1, "+A");
    await tester.enterText(key("proof-refs-1"), "α");

    await addLine("proof-add-assumption");
    await tester.enterText(key("proof-formula-2"), "¬r");

    await addLine("proof-add-line");
    await tester.enterText(key("proof-formula-3"), "¬q");
    await chooseRule(3, "-A");
    await tester.enterText(key("proof-refs-3"), "1, β");

    await tester.ensureVisible(key("proof-check"));
    await tester.tap(key("proof-check"));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.textContaining("Der Beweis ist vollständig"), findsOneWidget);
    final p = await tester.runAsync(store.load);
    expect(p!.task("l4.k2.i").lastCorrect, isTrue);
  });

  testWidgets("Regelübersicht und Übungsklausur", (tester) async {
    await pumpCourse(tester);
    await tester.tap(key("logic-rules"));
    await tester.pumpAndSettle();
    expect(find.textContaining("Argumente 6.1"), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(key("logic-exam"));
    await tester.pumpAndSettle();
    expect(find.text("Aufgabe 7"), findsNothing); // weiter unten
    await tester.scrollUntilVisible(find.text("Aufgabe 7"), 200);
    expect(find.text("Aufgabe 7"), findsOneWidget);
  });

  testWidgets("Kleine Bildschirme: Lehrtexte ohne Überlauf", (tester) async {
    await pumpCourse(tester, size: const Size(320, 640));
    for (final id in ["l2", "l6", "l9"]) {
      await tester.scrollUntilVisible(key("logic-lesson-$id"), 200);
      await tester.ensureVisible(key("logic-lesson-$id"));
      await tester.pumpAndSettle();
      await tester.tap(key("logic-lesson-$id"));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      // Bis zum Ende scrollen; Überläufe würden als Fehler gemeldet.
      for (var i = 0; i < 40; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }
  });
}
