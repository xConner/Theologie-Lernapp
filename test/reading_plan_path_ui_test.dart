import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/course_reading_plan.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/books/book_study_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/books/books_overview_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/course_reading_schedule.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'pericope_books_ui_test.dart'
    show FakeLearningService, FakeSettingsService, key;
import 'reading_plan_path_test.dart' show TestExtent, plan;
import 'test_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 30, 9);

  late List<Perikope> perikopen;
  late BookOutlines outlines;

  final weekly = plan([
    ("w.01", "2026-11-05", ["EXO 1-20"]),
    ("w.02", "2026-11-12", ["EXO 21-40"]),
    ("w.03", "2026-11-19", ["LEV"]),
  ]);

  setUpAll(() {
    perikopen = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        if (const {"Ex", "Lev"}.contains(entry["book"]))
          Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];

    outlines = BookOutlines.fromJson(
      jsonDecode(File(BookOutlines.asset).readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;

    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  Future<CourseSchedule?> schedule(String? uid, DateTime today) async {
    return CourseSchedule.compute(
      plan: weekly,
      progress: const CourseReadingProgress(
        planId: "test-plan",
        startedOn: "2026-10-29",
      ),
      today: today,
      extent: const TestExtent(),
    );
  }

  Future<void> pump(WidgetTester tester, {bool available = true}) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BooksOverviewScreen(
          perikopen: perikopen,
          uid: null,
          learningService: FakeLearningService(),
          settingsService: FakeSettingsService(),
          bibleRepository: BibleRepository(
            source: AssetBibleTextSource(bundle: FileAssetBundle()),
          ),
          outlines: outlines,
          clock: () => now,
          readingPathSchedule: available
              ? schedule
              : (uid, today) async => null,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets("Einzelne Bücher bleiben der Standard, Bibelleseplan daneben", (
    tester,
  ) async {
    await pump(tester);

    expect(key("learning-path-mode"), findsOneWidget);
    expect(key("book-Ex"), findsOneWidget);
    expect(key("open-reviews"), findsOneWidget);

    await tester.tap(find.text("Nach Bibelleseplan"));
    await tester.pumpAndSettle();

    expect(key("book-Ex"), findsNothing);
    expect(key("path-begin"), findsOneWidget);
    expect(key("path-week-w.01"), findsOneWidget);
    expect(key("path-week-w.03"), findsOneWidget);

    await tester.tap(key("path-begin"));
    await tester.pumpAndSettle();

    expect(key("path-today"), findsOneWidget);
    expect(
      find.descendant(
        of: key("path-today"),
        matching: find.text("Woche 1: w.01"),
      ),
      findsOneWidget,
    );
    expect(find.textContaining("Heute neu:"), findsOneWidget);

    // Gespeichert neben den Buchplänen.
    final data = await LocalBookLearningStorage().load();
    expect(
      data.readingPaths["course-bibelkunde-at-wise-2026"]!.startedOn,
      "2026-10-30",
    );

    await tester.tap(key("path-start"));
    await tester.pumpAndSettle();

    expect(find.byType(BookStudyScreen), findsOneWidget);
    expect(find.text("Nach Bibelleseplan"), findsOneWidget);

    // Zurück zu den einzelnen Büchern: unverändert da.
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text("Einzelne Bücher"));
    await tester.pumpAndSettle();

    expect(key("book-Ex"), findsOneWidget);
    expect(key("book-Lev"), findsOneWidget);
  });

  testWidgets("Ohne verfügbaren Leseplan nur die einzelnen Bücher", (
    tester,
  ) async {
    await pump(tester, available: false);

    expect(key("learning-path-mode"), findsNothing);
    expect(key("book-Ex"), findsOneWidget);
  });

  testWidgets("Eine Woche öffnen und gezielt lernen", (tester) async {
    await pump(tester);

    await tester.tap(find.text("Nach Bibelleseplan"));
    await tester.pumpAndSettle();

    await tester.tap(key("path-week-w.03"));
    await tester.pumpAndSettle();

    expect(key("path-week-learn"), findsOneWidget);

    await tester.tap(key("path-week-learn"));
    await tester.pumpAndSettle();

    expect(find.byType(BookStudyScreen), findsOneWidget);
    expect(find.text("Woche 3"), findsOneWidget);
  });
}
