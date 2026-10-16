import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/verse_precision.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/books/books_overview_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

class FakeSettingsService implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Mk"};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLearningService implements LearningService {
  final Map<String, LearningCard> cards;

  FakeLearningService([this.cards = const {}]);

  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {
    ...cards,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 1, 8);

  late List<Perikope> markus;

  setUpAll(() {
    markus = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ].where((p) => p.book == "Mk").toList();
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

  Future<void> pumpOverview(
    WidgetTester tester, {
    Size size = const Size(1000, 1600),
    Map<String, LearningCard> legacy = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BooksOverviewScreen(
          perikopen: markus,
          uid: null,
          learningService: FakeLearningService(legacy),
          settingsService: FakeSettingsService(),
          bibleRepository: BibleRepository(
            source: AssetBibleTextSource(bundle: FileAssetBundle()),
          ),
          clock: () => now,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openMarkus(WidgetTester tester) async {
    await tester.tap(key("book-Mk"));
    await tester.pumpAndSettle();
  }

  BookPericope callOf(int occurrence) {
    return BookCatalog.fromPerikopen(markus)
        .pericopesOf("Mk")
        .where((p) => p.id == "berufungjuenger")
        .elementAt(occurrence);
  }

  testWidgets("Übersicht zeigt das Buch mit allen Perikopen", (tester) async {
    await pumpOverview(tester);

    expect(find.text("Bücher systematisch lernen"), findsOneWidget);
    expect(key("book-Mk"), findsOneWidget);
    expect(
      find.textContaining("${markus.length} Perikopen · 0 sicher"),
      findsOneWidget,
    );

    await openMarkus(tester);

    expect(find.text("Kapitel 1"), findsOneWidget);
    expect(find.text("Johannes der Täufer"), findsWidgets);
    expect(find.text("Neu"), findsWidgets);
  });

  testWidgets("Lernstand aus dem Endlos-Quiz wird angezeigt", (tester) async {
    await pumpOverview(
      tester,
      legacy: {
        "johannestaeufer": LearningCard(
          id: "johannestaeufer",
          stability: 200,
          lastReviewed: now.subtract(const Duration(days: 1)),
        ),
      },
    );

    expect(find.textContaining("· 1 sicher"), findsOneWidget);
  });

  testWidgets("Verspräzisierung festlegen, anzeigen und zurücksetzen", (
    tester,
  ) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    final p = callOf(1);

    await tester.tap(key("pericope-${p.key}"));
    await tester.pumpAndSettle();

    expect(key("sheet-reference"), findsOneWidget);
    expect(tester.widget<Text>(key("sheet-reference")).data, "Mk 1");

    await tester.tap(key("sheet-precision"));
    await tester.pumpAndSettle();

    // Bisherige Angabe und Vorschlag aus der Liste sind sichtbar.
    expect(find.textContaining("Perikopenliste: Mk 1"), findsOneWidget);

    await tester.tap(key("precision-enabled"));
    await tester.pumpAndSettle();

    await tester.enterText(key("precision-start-verse"), "14");
    await tester.enterText(key("precision-end-verse"), "99");
    await tester.tap(key("precision-save"));
    await tester.pumpAndSettle();

    // Mk 1 hat 45 Verse.
    expect(find.text("Kapitel 1 hat nur 45 Verse."), findsOneWidget);

    await tester.enterText(key("precision-end-verse"), "20");
    await tester.tap(key("precision-save"));
    await tester.pumpAndSettle();

    expect(find.text("Mk 1,14-20"), findsOneWidget);
    expect(find.text("versgenau"), findsOneWidget);

    // Dauerhaft gespeichert.
    final stored = await LocalBookLearningStorage().load();

    expect(
      stored.precisions[p.key],
      const VersePrecision(
        startChapter: 1,
        startVerse: 14,
        endChapter: 1,
        endVerse: 20,
      ),
    );

    // Zurücksetzen: wieder kapitelgenau.
    await tester.tap(key("pericope-${p.key}"));
    await tester.pumpAndSettle();
    await tester.tap(key("sheet-reset"));
    await tester.pumpAndSettle();

    expect(find.text("Mk 1,14-20"), findsNothing);
    expect(find.text("versgenau"), findsNothing);
    expect((await LocalBookLearningStorage().load()).precisions, isEmpty);
  });

  testWidgets("Lerneinheit: Einführung, Abfrage und Ergebnis", (tester) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    await tester.tap(key("learn-book"));
    await tester.pumpAndSettle();

    // Drei neue Perikopen (Standardmenge), jeweils eingeführt und abgefragt.
    expect(find.text("Neue Perikope"), findsOneWidget);
    expect(find.text("Aufgabe 1 von 6"), findsOneWidget);
    expect(tester.widget<SelectableText>(key("intro-reference")).data, "Mk 1");

    int answered = 0;

    for (int step = 0; step < 6; step++) {
      if (find.text("Neue Perikope").evaluate().isNotEmpty) {
        await tester.tap(key("intro-continue"));
        await tester.pumpAndSettle();
        continue;
      }

      // Kapitelgenau mit vorgegebenem Buch: nur das Kapitel tippen.
      await tester.enterText(key("recall-input"), "1");
      await tester.pump();
      await tester.tap(key("recall-submit"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔"), findsOneWidget);
      answered++;

      await tester.tap(key("recall-submit"));
      await tester.pumpAndSettle();
    }

    expect(answered, 3);
    expect(tester.widget<Text>(key("study-result")).data, "3 von 3 richtig");

    await tester.tap(key("study-done"));
    await tester.pumpAndSettle();

    // Drei Perikopen sind jetzt in Bearbeitung – noch nicht sicher.
    expect(find.text("In Bearbeitung"), findsWidgets);
    expect(find.text("Sicher gelernt"), findsNothing);

    final stored = await LocalBookLearningStorage().load();

    expect(stored.cards.values.where((c) => c.introducedAt != null).length, 3);
  });

  testWidgets("Lernplan anlegen und pausieren", (tester) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    await tester.tap(key("plan-edit"));
    await tester.pumpAndSettle();

    await tester.tap(key("plan-daily-plus"));
    await tester.pump();
    await tester.enterText(key("plan-target"), "31.12.2026");
    await tester.tap(key("plan-save"));
    await tester.pumpAndSettle();

    expect(find.textContaining("4 neue Perikopen pro Tag"), findsOneWidget);
    expect(find.textContaining("Ziel: 31.12.2026"), findsOneWidget);

    await tester.tap(key("plan-pause"));
    await tester.pumpAndSettle();

    expect(find.textContaining("Pausiert"), findsOneWidget);
    expect(
      tester.widget<Text>(key("plan-today")).data,
      "Heute: 0 fällige Wiederholungen, 0 neue Perikopen",
    );

    final stored = await LocalBookLearningStorage().load();

    expect(stored.plans["Mk"]!.paused, isTrue);
    expect(stored.plans["Mk"]!.dailyNew, 4);
  });

  testWidgets("Prüfung ohne Lösungshinweise, Fehler am Ende", (tester) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    await tester.tap(key("mode-exam"));
    await tester.pumpAndSettle();
    await tester.tap(key("exam-chapters"));
    await tester.pumpAndSettle();
    await tester.tap(key("range-start"));
    await tester.pumpAndSettle();

    final count = BookCatalog.fromPerikopen(
      markus,
    ).inChapters("Mk", 1, 1).length;

    expect(
      find.text("Aufgabe 1 von $count · Prüfung ohne Lösungshinweise"),
      findsOneWidget,
    );

    for (int i = 0; i < count; i++) {
      await tester.enterText(key("recall-input"), "Mk 2");
      await tester.pump();
      await tester.tap(key("recall-submit"));
      await tester.pumpAndSettle();

      // Keine Rückmeldung während der Prüfung.
      expect(key("study-feedback"), findsNothing);
    }

    expect(
      tester.widget<Text>(key("study-result")).data,
      "0 von $count richtig",
    );
    expect(find.text("Fehler"), findsOneWidget);
    expect(find.textContaining("Richtig: Mk 1"), findsWidgets);
  });

  testWidgets("Wiederholungsübersicht ist erreichbar", (tester) async {
    await pumpOverview(tester);

    await tester.tap(key("open-reviews"));
    await tester.pumpAndSettle();

    expect(find.text("Gerade ist nichts fällig."), findsOneWidget);
    expect(key("review-section-overdue"), findsOneWidget);
    expect(key("review-section-today"), findsOneWidget);
    expect(key("review-section-wrong"), findsOneWidget);

    await tester.tap(key("review-show-soon"));
    await tester.pumpAndSettle();

    expect(key("review-section-soon"), findsOneWidget);
  });

  testWidgets("Reihenfolge lernen auf Smartphone-Breite", (tester) async {
    await pumpOverview(tester, size: const Size(360, 640));
    await openMarkus(tester);

    await tester.scrollUntilVisible(
      key("mode-order"),
      200,
      scrollable: find.descendant(
        of: key("book-detail-list"),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(key("mode-order"));
    await tester.pumpAndSettle();
    await tester.tap(key("mode-order"));
    await tester.pumpAndSettle();
    await tester.tap(key("range-whole-book"));
    await tester.pumpAndSettle();

    expect(find.text("Reihenfolge lernen"), findsOneWidget);

    // Jede Aufgabe beantworten, egal welcher Art.
    for (int i = 0; i < 10; i++) {
      if (key("option-0").evaluate().isNotEmpty) {
        await tester.ensureVisible(key("option-0"));
        await tester.tap(key("option-0"));
        await tester.pumpAndSettle();
        await tester.ensureVisible(key("choice-next"));
        await tester.tap(key("choice-next"));
      } else {
        for (int j = 0; j < 4; j++) {
          final item = key("arrange-$j");
          if (item.evaluate().isEmpty) continue;
          await tester.ensureVisible(item);
          await tester.tap(item);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(key("arrange-check"));
        await tester.tap(key("arrange-check"));
        await tester.pumpAndSettle();
        await tester.ensureVisible(key("arrange-next"));
        await tester.tap(key("arrange-next"));
      }

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }

    expect(key("study-result"), findsOneWidget);

    // Reihenfolge-Fehler werden nicht als Stellenabfrage wiederholt.
    expect(key("retry-mistakes"), findsNothing);

    // Reihenfolge-Aufgaben ändern den Lernstatus nicht.
    await tester.tap(key("study-done"));
    await tester.pumpAndSettle();

    expect(key("book-detail-list"), findsOneWidget);

    final stored = await LocalBookLearningStorage().load();

    expect(stored.cards, isNotEmpty);
    expect(stored.cards.values.every((c) => c.lastReviewed == null), isTrue);
    expect(
      stored.cards.values.every((c) => c.orderCorrect + c.orderWrong > 0),
      isTrue,
    );
  });

  testWidgets("Kleiner Bildschirm ohne Überlauf", (tester) async {
    await pumpOverview(tester, size: const Size(320, 568));

    expect(tester.takeException(), isNull);

    await openMarkus(tester);

    expect(tester.takeException(), isNull);

    await tester.tap(key("plan-edit"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text("Abbrechen"));
    await tester.pumpAndSettle();

    await tester.ensureVisible(key("learn-book"));
    await tester.pumpAndSettle();
    await tester.tap(key("learn-book"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.ensureVisible(key("intro-continue"));
    await tester.tap(key("intro-continue"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
