import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/screens/old_testament/glossary_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_home_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_progress_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_quiz_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/unit_detail_screen.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'old_testament_test_data.dart';
import '../lecture_materials_test_support.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  // Echte Inhalte: geschützte Vorlesungsunterlagen, nicht im Repository.
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials("Altes Testament (Oberfläche)");
    return;
  }

  final data = loadOldTestament();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets("Start → Einheit mit Überblick, Begriffen und Folien", (
    tester,
  ) async {
    _largeView(tester);

    await tester.pumpWidget(
      _app(OldTestamentHomeScreen(data: data, store: LocalOldTestamentStore())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("old-testament-learn")), findsOneWidget);
    expect(
      find.byKey(const ValueKey("old-testament-progress")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("old-testament-glossary")),
      findsOneWidget,
    );
    expect(find.text("Vorlesungseinheiten"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("unit-unit.01")));
    await tester.pumpAndSettle();

    expect(find.text("Kernpunkte"), findsOneWidget);
    expect(find.text("Gliederung"), findsOneWidget);
    expect(find.textContaining("Nicht eindeutig"), findsWidgets);
    expect(find.text("Ergänzung – nicht von den Folien"), findsWidgets);
    expect(find.byKey(const ValueKey("unit-learn")), findsOneWidget);

    await tester.tap(find.text("Begriffe und Stellen"));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("term-term.tanak")), findsOneWidget);
    expect(
      find.byKey(const ValueKey("open-passage.u01.2kor_3_14")),
      findsOneWidget,
    );

    await tester.tap(find.text("Originalfolien"));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);
    expect(find.byKey(const ValueKey("slide-text-1")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Folienangabe springt zu den Originalfolien", (tester) async {
    _largeView(tester);

    await tester.pumpWidget(
      _app(UnitDetailScreen(data: data, unitId: "unit.01", initialSlide: 16)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Folie 16 · Textentstehung und Textüberlieferung"),
      findsOneWidget,
    );
  });

  testWidgets("Glossar filtert", (tester) async {
    _largeView(tester);

    await tester.pumpWidget(_app(GlossaryScreen(data: data)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey("glossary-filter")),
      "Masoret",
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("term-term.masoreten")), findsOneWidget);
    expect(find.byKey(const ValueKey("term-term.tanak")), findsNothing);
  });

  testWidgets("Lernmodus: Antwort wird bewertet, erklärt und gespeichert", (
    tester,
  ) async {
    _largeView(tester);
    final store = LocalOldTestamentStore();
    await tester.runAsync(
      () => store.saveSettings(
        OldTestamentSettings(
          disabledKinds: OtQuizKind.values.toSet()..remove(OtQuizKind.lecture),
        ),
      ),
    );

    await tester.pumpWidget(
      _app(
        OldTestamentQuizScreen(
          data: data,
          scope: const OtScope.unit("unit.01"),
          store: store,
          random: Random(3),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final prompt = tester
        .widget<Text>(find.byKey(const ValueKey("quiz-prompt")))
        .data!;
    final question = data
        .unit("unit.01")!
        .questions
        .firstWhere((q) => q.prompt == prompt);

    // Richtige Antwort wählen.
    await tester.tap(find.text(question.answer));
    await tester.pumpAndSettle();

    expect(find.text("Richtig"), findsOneWidget);
    expect(find.byKey(const ValueKey("quiz-explanation")), findsOneWidget);
    expect(find.byKey(const ValueKey("quiz-source")), findsOneWidget);

    final cards = await tester.runAsync(store.loadCards);
    expect(cards!.keys, contains("${question.id}|lecture"));
    expect(tester.takeException(), isNull);
  });

  testWidgets("nur schwierige Inhalte ohne Fehler: Hinweis statt Frage", (
    tester,
  ) async {
    final store = LocalOldTestamentStore();
    await tester.runAsync(
      () => store.saveSettings(const OldTestamentSettings(onlyDifficult: true)),
    );

    await tester.pumpWidget(
      _app(OldTestamentQuizScreen(data: data, store: store)),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("quiz-empty")), findsOneWidget);
  });

  testWidgets("Fortschritt zeigt Einheit und Aufgabenarten", (tester) async {
    _largeView(tester);

    await tester.pumpWidget(
      _app(
        OldTestamentProgressScreen(data: data, store: LocalOldTestamentStore()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("progress-all")), findsOneWidget);
    expect(find.byKey(const ValueKey("progress-unit.01")), findsOneWidget);
    expect(find.text("Fachbegriffe"), findsOneWidget);
    expect(find.textContaining("Noch nicht geübt"), findsWidgets);
  });

  testWidgets("leerer Bestand: Hinweis statt Kategorien", (tester) async {
    final json = oldTestamentJson();
    final empty = parseOldTestament((
      course: {...json.course, "units": <String>[]},
      terms: {"terms": <Object>[]},
      units: const [],
    ));

    await tester.pumpWidget(
      _app(
        OldTestamentHomeScreen(data: empty, store: LocalOldTestamentStore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("old-testament-learn")), findsNothing);
    expect(find.byKey(const ValueKey("old-testament-glossary")), findsNothing);
    expect(find.textContaining("Noch keine Vorlesungseinheit"), findsOneWidget);
  });

  testWidgets("Handybreite: keine Überläufe", (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(UnitDetailScreen(data: data, unitId: "unit.01")),
    );
    await tester.pumpAndSettle();
    for (final tab in ["Begriffe und Stellen", "Originalfolien"]) {
      await tester.ensureVisible(find.text(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
