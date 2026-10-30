import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/reading_plan.dart';
import 'package:theologie_lernapp/screens/bible/bible_home_screen.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/bible/course_reading_plan_screen.dart';
import 'package:theologie_lernapp/screens/bible/reading_plans_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/bibelkunde_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/pericope_headings.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'course_reading_plan_test.dart'
    show MemoryReadingRepository, MemoryStreakRepository, planId;
import 'test_asset_bundle.dart';
import 'lecture_materials_test_support.dart';

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  // Echte Inhalte: geschützte Vorlesungsunterlagen, nicht im Repository.
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials(
      "Leseplan zur Übung Bibelkunde AT (Oberfläche)",
    );
    return;
  }

  // Der Leseplan kommt aus den freigegebenen Vorlesungsunterlagen.
  setUp(() => useLectureMaterials(directoryLectureMaterialsSource()));

  TestWidgetsFlutterBinding.ensureInitialized();

  final bundle = FileAssetBundle();

  late BibleRepository bibles;
  late MemoryReadingRepository storage;
  late BibleReadingService service;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    now = DateTime(2026, 10, 23, 18); // Freitag

    bibles = BibleRepository(source: AssetBibleTextSource(bundle: bundle));
    storage = MemoryReadingRepository();

    service = BibleReadingService(
      repositoryFor: (_) => storage,
      clock: () => now,
      streaks: StreakService(
        repositoryFor: (_) => MemoryStreakRepository(),
        clock: () => now,
      ),
      bundle: bundle,
      translations: bibles.translations,
    );
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  /// Die Liste baut nur, was sichtbar ist: von oben suchen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;

    final list = find.byType(Scrollable).first;

    await tester.drag(list, const Offset(0, 5000));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(finder, 300, scrollable: list);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  /// Wartet, bis der Reader das Kapitel [title] zeigt.
  Future<void> waitForChapter(WidgetTester tester, String title) async {
    for (var i = 0; i < 400; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));

      if (find.text(title).evaluate().isNotEmpty &&
          (key("bible-course-mark-read").evaluate().isNotEmpty ||
              key("bible-course-reading-done").evaluate().isNotEmpty ||
              key("bible-plan-outside").evaluate().isNotEmpty)) {
        break;
      }
    }

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(title), findsOneWidget);
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(480, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CourseReadingPlanScreen(
          uid: "u1",
          planId: planId,
          service: service,
          repository: bibles,
        ),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  testWidgets("Plan beginnen: heutiges Pensum und nächste Sitzung", (
    tester,
  ) async {
    await open(tester);

    expect(find.text("Lesen zur Übung Bibelkunde AT"), findsOneWidget);
    expect(find.textContaining("Do, 29.10.2026 · Genesis"), findsOneWidget);
    expect(find.text("Vorläufig"), findsWidgets);

    await tapVisible(tester, key("course-plan-start"));

    expect(storage.data["course_$planId"]!["startedOn"], "2026-10-23");

    expect(find.text("Heute · Fr, 23.10."), findsOneWidget);
    expect(find.text("Nächste Sitzung: Genesis"), findsOneWidget);
    expect(find.text("Do, 29.10.2026"), findsOneWidget);
    expect(key("course-pace-onTrack"), findsOneWidget);
    expect(
      find.textContaining("Bis Mi, 28.10. (Vorabend) lesen: Gen 1–50"),
      findsOneWidget,
    );
    expect(find.textContaining("Noch 6 Lesetage"), findsOneWidget);
    expect(key("course-piece-bk.02-GEN 1"), findsOneWidget);
    expect(key("course-today-summary"), findsOneWidget);
    expect(find.textContaining("Gen 1–"), findsWidgets);

    // Abhaken speichert sofort.
    await tapVisible(tester, key("course-piece-bk.02-GEN 1"));

    expect(
      (storage.data["course_$planId"]!["done"] as Map).keys,
      contains("GEN 1"),
    );
    expect(find.textContaining("1 von 50 Lesestücken"), findsOneWidget);

    // Vorabend aus: bis zum Sitzungstag.
    await tapVisible(tester, key("course-finish-eve"));
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await settle(tester);

    expect(
      find.textContaining("Bis Do, 29.10. (Sitzungstag) lesen"),
      findsOneWidget,
    );
    expect(find.textContaining("Noch 7 Lesetage"), findsOneWidget);
  });

  testWidgets("Lesen im Reader und dort als gelesen markieren", (tester) async {
    await tester.runAsync(() => service.startCoursePlan("u1", planId));

    await open(tester);

    await tester.tap(key("course-today-read"));
    await tester.pump();

    for (
      var i = 0;
      i < 100 && key("bible-course-mark-read").evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(BibleReaderScreen), findsOneWidget);
    expect(find.text("1. Mose 1"), findsOneWidget);

    await tapVisible(tester, key("bible-course-mark-read"));

    expect(key("bible-course-reading-done"), findsOneWidget);
    expect(service.courseProgressOf("u1", planId)!.done.keys, ["GEN 1"]);
  });

  testWidgets("Sitzung anpassen: eigener Termin, Empfehlung bleibt sichtbar", (
    tester,
  ) async {
    await tester.runAsync(() => service.startCoursePlan("u1", planId));

    await open(tester);

    await tapVisible(tester, key("course-session-bk.03"));

    expect(find.text("Nach den Folien"), findsWidgets);
    expect(find.text("Ex 1–5"), findsOneWidget);
    expect(key("course-piece-bk.03-LEV 16"), findsOneWidget);

    await tapVisible(tester, key("course-session-edit-bk.03"));

    expect(
      tester.widget<TextField>(key("course-edit-readings")).controller!.text,
      "Ex 1–5; Ex 7–24; Ex 32–34; Lev 16",
    );

    await tester.enterText(key("course-edit-date"), "31.02.2026");
    await tapVisible(tester, key("course-edit-save"));

    expect(key("course-edit-error"), findsOneWidget);

    await tester.enterText(key("course-edit-date"), "06.11.2026");
    await tester.enterText(key("course-edit-readings"), "Ex 1-5; Lev 16");
    await tapVisible(tester, key("course-edit-save"));
    await reveal(tester, find.text("Eigener Termin"));

    expect(find.text("Eigener Termin"), findsOneWidget);
    expect(find.text("Eigene Stellen"), findsOneWidget);
    expect(find.textContaining("Empfehlung: Do, 05.11.2026"), findsWidgets);

    final override =
        (storage.data["course_$planId"]!["overrides"] as Map)["bk.03"] as Map;

    expect(override["date"], "2026-11-06");
    expect(override["readings"], ["EXO 1-5", "LEV 16"]);

    // Zurück zur Empfehlung.
    await tapVisible(tester, key("course-session-edit-bk.03"));
    await tapVisible(tester, key("course-edit-reset"));

    expect(find.text("Eigener Termin"), findsNothing);
    expect((storage.data["course_$planId"]!["overrides"] as Map), isEmpty);
  });

  testWidgets("Handybreite ohne Überlauf", (tester) async {
    await tester.runAsync(() => service.startCoursePlan("u1", planId));

    await open(tester, size: const Size(360, 780));

    await tapVisible(tester, key("course-session-bk.04"));

    expect(tester.takeException(), isNull);
    expect(key("course-piece-bk.04-NUM 6:22-26"), findsOneWidget);
  });

  testWidgets("Einstieg in der Leseplanübersicht", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ReadingPlansScreen(
          uid: "u1",
          service: service,
          repository: bibles,
        ),
      ),
    );
    await settle(tester);

    await reveal(tester, key("course-plan-$planId"));

    expect(find.text("Zu Lehrveranstaltungen"), findsOneWidget);
    expect(key("course-plan-$planId"), findsOneWidget);

    await tapVisible(tester, key("course-plan-$planId"));

    expect(find.byType(CourseReadingPlanScreen), findsOneWidget);
  });

  testWidgets("begonnen: auf der Startseite der Bibel mit Tagespensum", (
    tester,
  ) async {
    await tester.runAsync(() => service.startCoursePlan("u1", planId));

    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BibleHomeScreen(uid: "u1", service: service, repository: bibles),
      ),
    );
    await settle(tester);
    await settle(tester);

    await reveal(tester, key("course-plan-card-$planId"));

    expect(key("course-plan-card-$planId"), findsOneWidget);
    expect(
      find.textContaining("Nächste Sitzung Do, 29.10.: Genesis"),
      findsOneWidget,
    );
    expect(find.textContaining("nur vorgesehene Kapitel"), findsOneWidget);
    expect(key("course-plan-today-$planId"), findsOneWidget);
    expect(
      find.text(
        "Du folgst noch keinem Leseplan. Lesen und die Streak "
        "funktionieren auch ohne Plan.",
      ),
      findsNothing,
    );

    // Abhaken direkt auf der Startseite.
    await tapVisible(tester, key("course-piece-bk.02-GEN 1"));

    expect(service.courseProgressOf("u1", planId)!.done.keys, ["GEN 1"]);

    // Pausiert: kein Tagespensum, Plan bleibt sichtbar.
    await tester.runAsync(() => service.setCoursePaused("u1", planId, true));
    await settle(tester);

    expect(key("course-plan-today-$planId"), findsNothing);
    expect(find.text("Pausiert"), findsOneWidget);

    await tapVisible(tester, key("course-plan-open-$planId"));

    expect(find.byType(CourseReadingPlanScreen), findsOneWidget);
  });

  testWidgets("begonnen: unter „Meine Pläne“ statt bei den verfügbaren", (
    tester,
  ) async {
    await tester.runAsync(() => service.startCoursePlan("u1", planId));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ReadingPlansScreen(
          uid: "u1",
          service: service,
          repository: bibles,
        ),
      ),
    );
    await settle(tester);

    expect(find.text("Meine Pläne"), findsOneWidget);
    expect(key("course-plan-card-$planId"), findsOneWidget);
    expect(key("course-plan-$planId"), findsNothing);
    expect(find.text("Zu Lehrveranstaltungen"), findsNothing);
  });

  testWidgets("Umfang „ganze Bücher“ ein- und ausschalten", (tester) async {
    await tester.runAsync(() => service.startCoursePlan("u1", planId));

    await open(tester);

    await tapVisible(tester, key("course-whole-books"));

    expect(service.courseProgressOf("u1", planId)!.wholeBooks, isTrue);
    expect(key("course-scope-changed"), findsOneWidget);
    expect(find.textContaining("Kapitel ergänzt"), findsOneWidget);

    await tapVisible(tester, key("course-session-bk.03"));

    expect(find.textContaining("ergänzend"), findsWidgets);
    expect(key("course-piece-bk.03-EXO 6"), findsOneWidget);
    expect(key("course-piece-bk.03-LEV 1"), findsOneWidget);

    await tapVisible(tester, key("course-whole-books"));

    expect(service.courseProgressOf("u1", planId)!.wholeBooks, isFalse);
    expect(key("course-piece-bk.03-EXO 6"), findsNothing);
  });

  testWidgets("Einstieg im Bereich Bibelkunde", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BibelkundeScreen(perikopen: [], uid: null)),
    );
    await tester.pump();

    expect(key("bibelkunde-reading-plan"), findsOneWidget);
    expect(BibelkundeScreen.readingPlanId, planId);
  });
  group("Abschlussstatus beim Kapitelwechsel im Reader", () {
    final pieces = [
      for (var c = 1; c <= 3; c++) PlanReading(bookId: "GEN", chapter: c),
    ];

    Future<void> openReader(
      WidgetTester tester,
      BibleReadingService reading,
    ) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleReaderScreen(
            uid: "u1",
            readingService: reading,
            repository: bibles,
            passages: [
              for (final p in pieces)
                BiblePassage(label: p.label, reference: p.reference),
            ],
            passageTitle: "Leseplan · Heute",
            // Die Überschriften lädt ein früherer Test schon in seiner
            // Zone; hier ohne sie, damit nichts auf ihn wartet.
            pericopeHeadings: PericopeHeadings.empty,
            coursePlan: (planId: planId, pieces: pieces),
          ),
        ),
      );
      await waitForChapter(tester, "1. Mose 1");
    }

    Future<void> step(WidgetTester tester, String direction, String title) {
      return tester
          .tap(key("bible-$direction-chapter"))
          .then((_) => waitForChapter(tester, title));
    }

    /// Unter dem Kapitel: erledigt (true) oder Knopf zum Abhaken (false).
    void expectDone(String label, bool done) {
      expect(
        key("bible-course-reading-done"),
        done ? findsOneWidget : findsNothing,
      );
      expect(
        key("bible-course-mark-read"),
        done ? findsNothing : findsOneWidget,
      );
      expect(
        find.textContaining(done ? "„$label“ gelesen" : "„$label“ als gelesen"),
        findsOneWidget,
      );
    }

    testWidgets("A abschließen, vor, zurück, B abschließen, neu öffnen", (
      tester,
    ) async {
      await tester.runAsync(() => service.startCoursePlan("u1", planId));

      await openReader(tester, service);

      // Kapitel A abschließen.
      expectDone("Gen 1", false);
      await tapVisible(tester, key("bible-course-mark-read"));
      expectDone("Gen 1", true);

      // Zu Kapitel B: nicht abgeschlossen (früher: „Gen 1 gelesen“).
      await step(tester, "next", "1. Mose 2");
      expectDone("Gen 2", false);
      expect(find.textContaining("„Gen 1“"), findsNothing);

      // Zurück zu A: weiterhin abgeschlossen.
      await step(tester, "previous", "1. Mose 1");
      expectDone("Gen 1", true);

      // B abschließen – gespeichert wird Gen 2, nicht Gen 1 erneut.
      await step(tester, "next", "1. Mose 2");
      await tapVisible(tester, key("bible-course-mark-read"));
      expectDone("Gen 2", true);
      expect(
        service.courseProgressOf("u1", planId)!.done.keys,
        unorderedEquals(["GEN 1", "GEN 2"]),
      );

      // Mehrfach vor und zurück.
      await step(tester, "next", "1. Mose 3");
      expectDone("Gen 3", false);
      await step(tester, "previous", "1. Mose 2");
      expectDone("Gen 2", true);
      await step(tester, "previous", "1. Mose 1");
      expectDone("Gen 1", true);
      await step(tester, "next", "1. Mose 2");
      await step(tester, "next", "1. Mose 3");
      expectDone("Gen 3", false);

      // Über die Lesungen hinaus: kein Abhaken für den Plan.
      await step(tester, "next", "1. Mose 4");
      expect(key("bible-plan-outside"), findsOneWidget);
      expect(key("bible-course-reading-done"), findsNothing);
      expect(key("bible-course-mark-read"), findsNothing);

      // Die Leiste folgt dem Kapitel.
      await step(tester, "previous", "1. Mose 3");
      expect(
        tester.widget<ChoiceChip>(key("bible-passage-2")).selected,
        isTrue,
      );

      // Leseplan verlassen und erneut öffnen.
      await tester.pumpWidget(const SizedBox());
      await openReader(tester, service);
      expectDone("Gen 1", true);
      await step(tester, "next", "1. Mose 2");
      expectDone("Gen 2", true);
      await step(tester, "next", "1. Mose 3");
      expectDone("Gen 3", false);

      // Neu laden (wie nach einem App-Neustart): neuer Dienst, gleicher
      // Speicher.
      final reloaded = BibleReadingService(
        repositoryFor: (_) => storage,
        clock: () => now,
        streaks: StreakService(
          repositoryFor: (_) => MemoryStreakRepository(),
          clock: () => now,
        ),
        bundle: bundle,
        translations: bibles.translations,
      );

      await tester.pumpWidget(const SizedBox());
      await openReader(tester, reloaded);
      expectDone("Gen 1", true);
      await step(tester, "next", "1. Mose 2");
      expectDone("Gen 2", true);
      await step(tester, "next", "1. Mose 3");
      expectDone("Gen 3", false);
    });
  });
}
