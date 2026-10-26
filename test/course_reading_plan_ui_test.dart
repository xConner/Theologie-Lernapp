import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/bible/course_reading_plan_screen.dart';
import 'package:theologie_lernapp/screens/bible/reading_plans_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/bibelkunde_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
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

  testWidgets("Einstieg im Bereich Bibelkunde", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BibelkundeScreen(perikopen: [], uid: null)),
    );
    await tester.pump();

    expect(key("bibelkunde-reading-plan"), findsOneWidget);
    expect(BibelkundeScreen.readingPlanId, planId);
  });
}
