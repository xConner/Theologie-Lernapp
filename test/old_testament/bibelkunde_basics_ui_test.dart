import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/screens/old_testament/glossary_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_home_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_progress_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_quiz_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/unit_detail_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/bibelkunde_screen.dart';
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
    skipWithoutLectureMaterials("Grundlagen der Bibelkunde (Oberfläche)");
    return;
  }

  final all = loadOldTestament();
  final bk = all.forCourse(OtCourseId.bibelkunde);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets("Bibelkunde öffnet die Grundlagen", (tester) async {
    // Mit Freigabe der Vorlesungsunterlagen (ohne Dateien: geprüft wird nur
    // der Weg in den Bereich, nicht dessen Startseite).
    await tester.runAsync(
      () => useLectureMaterials(FakeLectureMaterialsSource({})),
    );
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(const BibelkundeScreen(perikopen: [], uid: null)),
    );
    await tester.pumpAndSettle();

    // Bestehende Zugänge bleiben.
    expect(find.text("Perikopenquiz"), findsOneWidget);
    expect(find.text("Bücher systematisch lernen"), findsOneWidget);
    expect(find.text("Grundlagen der Bibelkunde"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("bibelkunde-basics")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final home = tester.widget<OldTestamentHomeScreen>(
      find.byType(OldTestamentHomeScreen),
    );
    expect(home.course, OtCourseId.bibelkunde);
  });

  testWidgets("Startseite zeigt Sitzungen der Übung, nicht die Vorlesung", (
    tester,
  ) async {
    _largeView(tester);

    await tester.pumpWidget(
      _app(
        OldTestamentHomeScreen(
          course: OtCourseId.bibelkunde,
          data: all,
          store: LocalOldTestamentStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Grundlagen der Bibelkunde"), findsOneWidget);
    expect(find.text("Sitzungen der Übung"), findsOneWidget);
    expect(find.byKey(const ValueKey("unit-bk.01")), findsOneWidget);
    expect(find.byKey(const ValueKey("unit-unit.01")), findsNothing);
    expect(find.byKey(const ValueKey("old-testament-learn")), findsOneWidget);
    expect(
      find.byKey(const ValueKey("old-testament-glossary")),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey("unit-bk.01")));
    await tester.pumpAndSettle();

    expect(find.text("Kernpunkte"), findsOneWidget);
    expect(find.text("Gemeinsame Inhalte"), findsOneWidget);
    expect(find.byKey(const ValueKey("shared-q.u01.luther")), findsOneWidget);
    expect(find.textContaining("Vorlesung AT · Einheit 1"), findsWidgets);
    expect(find.textContaining("Nicht eindeutig"), findsWidgets);
    expect(find.text("Sitzung lernen"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Vorlesung verweist auf die Sitzung der Übung", (tester) async {
    _largeView(tester);

    await tester.pumpWidget(
      _app(UnitDetailScreen(data: all, unitId: "unit.01")),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text("Verwandte Einheiten"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining("Bibelkunde AT · Sitzung 1"), findsOneWidget);
    // Die Vorlesung zeigt keine „gemeinsamen Inhalte“ – sie ist die Herkunft.
    expect(find.text("Gemeinsame Inhalte"), findsNothing);
  });

  testWidgets("Glossar der Übung: eigene und gemeinsame Begriffe", (
    tester,
  ) async {
    _largeView(tester);

    await tester.pumpWidget(_app(GlossaryScreen(data: bk)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey("glossary-filter")),
      "Kanon",
    );
    await tester.pumpAndSettle();
    // Ein Begriff, zwei Fundstellen.
    expect(
      find.byKey(const ValueKey("term-source-term.kanon-unit.01")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("term-source-term.kanon-bk.01")),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey("glossary-filter")),
      "Festrollen",
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("term-term.megillot")), findsOneWidget);
  });

  testWidgets(
    "Lernmodus: geteilte Frage, eigener Umfang, eigene Einstellungen",
    (tester) async {
      _largeView(tester);
      final store = LocalOldTestamentStore();
      await tester.runAsync(
        () => store.saveSettings(
          OldTestamentSettings(
            disabledKinds: OtQuizKind.values.toSet()
              ..remove(OtQuizKind.lecture),
          ),
          course: OtCourseId.bibelkunde,
        ),
      );

      await tester.pumpWidget(
        _app(OldTestamentQuizScreen(data: bk, store: store, random: Random(5))),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Alle Sitzungen · Wissensfragen"),
        findsOneWidget,
      );

      final prompt = tester
          .widget<Text>(find.byKey(const ValueKey("quiz-prompt")))
          .data!;
      final session = bk.unit("bk.01")!;
      final question = [
        ...session.questions,
        for (final id in session.sharedIds) ?bk.question(id),
      ].firstWhere((q) => q.prompt == prompt);

      await tester.tap(find.text(question.answer));
      await tester.pumpAndSettle();

      expect(find.text("Richtig"), findsOneWidget);
      expect(find.byKey(const ValueKey("quiz-explanation")), findsOneWidget);

      final cards = await tester.runAsync(store.loadCards);
      expect(cards!.keys, contains("${question.id}|lecture"));

      // Die Einstellungen der Vorlesung sind unberührt.
      final lecture = await tester.runAsync(store.loadSettings);
      expect(lecture!.kinds, OtQuizKind.values.toSet());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("Alles zurücksetzen in der Vorlesung lässt die Übung stehen", (
    tester,
  ) async {
    _largeView(tester);
    final store = LocalOldTestamentStore();
    await tester.runAsync(
      () => store.saveCards([
        LearningCard(id: "q.bk01.ziel|lecture"),
        LearningCard(id: "q.u01.samaritaner|lecture"),
        LearningCard(id: "term.kanon|term"),
      ]),
    );

    await tester.pumpWidget(
      _app(OldTestamentProgressScreen(data: all, store: store)),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey("progress-all")),
        matching: find.byIcon(Icons.restart_alt_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("Grundlagen der Bibelkunde"), findsOneWidget);
    await tester.tap(find.text("Zurücksetzen"));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final cards = await tester.runAsync(store.loadCards);
    expect(cards!.keys, ["q.bk01.ziel|lecture"]);
  });

  testWidgets("Handybreite: keine Überläufe", (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(UnitDetailScreen(data: bk, unitId: "bk.01")));
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
