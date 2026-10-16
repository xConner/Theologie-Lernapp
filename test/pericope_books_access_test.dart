import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_status.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/quiz/books/verse_precision.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/books/books_overview_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

/// Liest die Karten des Endlos-Quiz aus dem lokalen Speicher (wie im Gast-
/// modus), damit ein Zurücksetzen auch im Startwert sichtbar wird.
class LocalLearningService extends LearningService {}

class FakeSettingsService implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Mk"};

  @override
  Future<void> saveBooks(String? uid, Set<String> books) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 1, 8);

  late List<Perikope> markus;
  late BookCatalog catalog;
  late BookOutlines outlines;

  final store = LocalLearningStore.instance;

  setUpAll(() {
    markus = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ].where((p) => p.book == "Mk").toList();

    catalog = BookCatalog.fromPerikopen(markus);

    outlines = BookOutlines.fromJson(
      jsonDecode(File(BookOutlines.asset).readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;
    GeneralSettingsView.loadPerikopen = () async => markus;

    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  final learnedAt = now.subtract(const Duration(days: 3));

  /// Gelernte Perikopen (Buchlernen und Endlos-Quiz) und andere Bereiche.
  Future<void> seed() async {
    final books = LocalBookLearningStorage();

    await books.saveCards([
      for (final p in catalog.pericopesOf("Mk").take(5))
        BookCard(
          id: p.key,
          stability: 200,
          lastReviewed: learnedAt,
          spacedStreak: 2,
          correctCount: 3,
        ),
    ]);

    await store.saveCard(
      LocalLearningStore.perikopen,
      LearningCard(id: "speisung5000", stability: 90, lastReviewed: learnedAt),
    );
    await store.saveCard(
      LocalLearningStore.memorization,
      LearningCard(id: "vaterunser-1", stability: 40, lastReviewed: learnedAt),
    );
    await store.saveCard(
      LocalLearningStore.latinVocabulary,
      LearningCard(id: "amo", stability: 30, lastReviewed: learnedAt),
    );
  }

  /// Zustand des lokalen Speichers als vergleichbarer Text.
  Future<String> snapshot() async {
    final data = await LocalBookLearningStorage().load();

    return jsonEncode({
      "books": {for (final e in data.cards.entries) e.key: e.value.toJson()},
      "quiz": {
        for (final e in (await store.loadCards(
          LocalLearningStore.perikopen,
        )).entries)
          e.key: e.value.toJson(),
      },
      "memorization": (await store.loadCards(
        LocalLearningStore.memorization,
      )).keys.toList(),
      "latin": (await store.loadCards(
        LocalLearningStore.latinVocabulary,
      )).keys.toList(),
    });
  }

  Future<void> pumpOverview(
    WidgetTester tester, {
    Size size = const Size(1000, 1600),
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
          learningService: LocalLearningService(),
          settingsService: FakeSettingsService(),
          bibleRepository: BibleRepository(
            source: AssetBibleTextSource(bundle: FileAssetBundle()),
          ),
          outlines: outlines,
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

  /// Zahnrad → Tab „Allgemein“ → Perikopenkenntnisse aller Bücher.
  Future<void> resetPericopesViaSettings(WidgetTester tester) async {
    await tester.tap(key("book-settings").last);
    await tester.pumpAndSettle();

    // Getrennt: allgemeine und funktionsspezifische Einstellungen.
    expect(find.widgetWithText(Tab, "Allgemein"), findsOneWidget);
    expect(find.widgetWithText(Tab, "Bücher lernen"), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, "Allgemein"));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      key("reset-area"),
      200,
      scrollable: find
          .descendant(
            of: find.byType(GeneralSettingsView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(tester.widget<ListTile>(key("reset-area")).enabled, isTrue);

    await tester.tap(key("reset-area"));
    await tester.pumpAndSettle();
    await tester.tap(key("reset-area-pericopes"));
    await tester.pumpAndSettle();
    await tester.tap(key("pericope-scope-all"));
    await tester.pumpAndSettle();
    await tester.tap(key("pericope-scope-next"));
    await tester.pumpAndSettle();

    // Eindeutige Bestätigung, die nur die Perikopen nennt.
    expect(find.text("Perikopenkenntnisse zurücksetzen?"), findsOneWidget);

    await tester.tap(key("reset-confirm"));
    await tester.pumpAndSettle();

    expect(
      find.text("Perikopenkenntnisse wurden zurückgesetzt."),
      findsOneWidget,
    );

    await tester.tap(key("book-settings-close"));
    await tester.pumpAndSettle();
  }

  group("Einstellungen in allen Ansichten", () {
    testWidgets("Zahnrad in Übersicht, Buch, Wiederholungen und Einheit", (
      tester,
    ) async {
      await pumpOverview(tester);

      expect(key("book-settings"), findsOneWidget);

      await tester.tap(key("open-reviews"));
      await tester.pumpAndSettle();
      expect(key("book-settings"), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openMarkus(tester);
      expect(key("book-settings"), findsWidgets);

      await tester.tap(key("learn-book"));
      await tester.pumpAndSettle();
      expect(key("book-settings"), findsWidgets);

      // Modul-Tab: wenige eigene Optionen, kein zweites Zurücksetzen.
      await tester.tap(key("book-settings").last);
      await tester.pumpAndSettle();

      expect(key("book-settings-quick-entry"), findsOneWidget);
      expect(key("reset-area"), findsNothing);

      await tester.tap(find.widgetWithText(Tab, "Allgemein"));
      await tester.pumpAndSettle();

      expect(find.byType(GeneralSettingsView), findsOneWidget);
    });

    testWidgets("Zurücksetzen aus der Buchansicht: nur Perikopen", (
      tester,
    ) async {
      await tester.runAsync(seed);

      await pumpOverview(tester);
      await openMarkus(tester);

      expect(find.textContaining("Sicher"), findsWidgets);

      await resetPericopesViaSettings(tester);

      final data = await tester.runAsync(
        () => LocalBookLearningStorage().load(),
      );
      final memorization = await tester.runAsync(
        () => store.loadCards(LocalLearningStore.memorization),
      );
      final latin = await tester.runAsync(
        () => store.loadCards(LocalLearningStore.latinVocabulary),
      );

      expect(data!.cards, isEmpty);
      // Andere Lernbereiche, insbesondere Texte auswendig lernen, bleiben.
      expect(memorization!["vaterunser-1"]!.stability, 40);
      expect(latin!["amo"]!.stability, 30);

      // Die offene Ansicht zeigt sofort den neuen Stand.
      expect(
        tester.widget<Text>(key("plan-today")).data,
        startsWith("Heute: 0 fällige"),
      );
    });

    testWidgets("Zurücksetzen während einer Lerneinheit schreibt nichts "
        "Altes zurück", (tester) async {
      await tester.runAsync(seed);

      await pumpOverview(tester);
      await openMarkus(tester);

      await tester.tap(key("section-learn-mk-beispiel-1"));
      await tester.pumpAndSettle();

      await resetPericopesViaSettings(tester);

      // Weiterarbeiten: Nach der nächsten Antwort steht nur der neue Stand.
      while (key("intro-continue").evaluate().isNotEmpty) {
        await tester.tap(key("intro-continue"));
        await tester.pumpAndSettle();
      }

      if (key("recall-input").evaluate().isNotEmpty) {
        await tester.enterText(key("recall-input"), "1");
        await tester.pump();
        await tester.tap(key("recall-submit"));
        await tester.pumpAndSettle();
      }

      final data = await tester.runAsync(
        () => LocalBookLearningStorage().load(),
      );

      for (final card in data!.cards.values) {
        expect(card.correctCount, lessThanOrEqualTo(1));
        expect(card.lastReviewed, isNot(learnedAt));
      }
    });

    testWidgets("Gleiches Ergebnis wie über die Einstellungen der Startseite", (
      tester,
    ) async {
      // Weg 1: Startseite (GeneralSettingsView ohne geöffneten Lernbereich).
      await tester.runAsync(seed);

      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: GeneralSettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        key("reset-area"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(key("reset-area"));
      await tester.pumpAndSettle();
      await tester.tap(key("reset-area-pericopes"));
      await tester.pumpAndSettle();
      await tester.tap(key("pericope-scope-all"));
      await tester.pumpAndSettle();
      await tester.tap(key("pericope-scope-next"));
      await tester.pumpAndSettle();
      await tester.tap(key("reset-confirm"));
      await tester.pumpAndSettle();

      final viaHome = await tester.runAsync(snapshot);

      // Weg 2: Buchansicht.
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await seed();
      });

      await pumpOverview(tester);
      await openMarkus(tester);
      await resetPericopesViaSettings(tester);

      final viaBook = await tester.runAsync(snapshot);

      expect(viaBook, viaHome);
      expect(viaBook, contains("vaterunser-1"));
      expect(viaBook, contains("amo"));
    });

    testWidgets("Perikopenquiz: Zurücksetzen jetzt auch dort erreichbar", (
      tester,
    ) async {
      await tester.runAsync(seed);

      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuizScreen(
            perikopen: markus,
            uid: null,
            settingsService: FakeSettingsService(),
            learningService: LocalLearningService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, "Allgemein"));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        key("reset-area"),
        200,
        scrollable: find
            .descendant(
              of: find.byType(GeneralSettingsView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(tester.widget<ListTile>(key("reset-area")).enabled, isTrue);

      await tester.tap(key("reset-area"));
      await tester.pumpAndSettle();
      await tester.tap(key("reset-area-pericopes"));
      await tester.pumpAndSettle();
      await tester.tap(key("pericope-scope-all"));
      await tester.pumpAndSettle();
      await tester.tap(key("pericope-scope-next"));
      await tester.pumpAndSettle();
      await tester.tap(key("reset-confirm"));
      await tester.pumpAndSettle();

      expect(
        find.text("Perikopenkenntnisse wurden zurückgesetzt."),
        findsOneWidget,
      );

      final quiz = await tester.runAsync(
        () => store.loadCards(LocalLearningStore.perikopen),
      );
      final memorization = await tester.runAsync(
        () => store.loadCards(LocalLearningStore.memorization),
      );

      expect(quiz, isEmpty);
      expect(memorization!.keys, ["vaterunser-1"]);
    });
  });

  group("Bibelstelle öffnen", () {
    testWidgets("während der Einführung lesen und zur Einheit zurück", (
      tester,
    ) async {
      await pumpOverview(tester);
      await openMarkus(tester);

      await tester.tap(key("section-learn-mk-beispiel-1"));
      await tester.pumpAndSettle();

      final reference = tester.widget<SelectableText>(key("intro-reference"));
      final progress = tester.widget<Text>(key("study-progress")).data;

      await tester.tap(key("intro-read"));
      await tester.pumpAndSettle();

      expect(find.byType(BibleReaderScreen), findsOneWidget);
      expect(find.text("Markus 1"), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Dieselbe Aufgabe, nichts verloren.
      expect(find.byType(BibleReaderScreen), findsNothing);
      expect(
        tester.widget<SelectableText>(key("intro-reference")).data,
        reference.data,
      );
      expect(tester.widget<Text>(key("study-progress")).data, progress);
    });

    testWidgets("nach der Antwort, im Abschnitt, im Buch", (tester) async {
      await pumpOverview(tester);
      await openMarkus(tester);

      // Buch.
      await tester.tap(key("book-read"));
      await tester.pumpAndSettle();
      expect(find.byType(BibleReaderScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Abschnitt.
      await tester.tap(key("section-mk-beispiel-2"));
      await tester.pumpAndSettle();
      await tester.tap(key("section-sheet-read"));
      await tester.pumpAndSettle();
      expect(find.byType(BibleReaderScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Einzelne Perikope.
      final p = catalog.pericopesOf("Mk")[3];

      await tester.tap(key("section-mk-beispiel-2"));
      await tester.pumpAndSettle();
      await tester.tap(key("section-sheet-pericopes"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key("section-pericope-${p.key}"));
      await tester.tap(key("section-pericope-${p.key}"));
      await tester.pumpAndSettle();
      await tester.tap(key("sheet-read"));
      await tester.pumpAndSettle();

      expect(find.byType(BibleReaderScreen), findsOneWidget);
      expect(find.text(p.title), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Nach einer Antwort in der Lerneinheit.
      await tester.tap(key("section-learn-mk-beispiel-1"));
      await tester.pumpAndSettle();

      while (key("intro-continue").evaluate().isNotEmpty) {
        await tester.tap(key("intro-continue"));
        await tester.pumpAndSettle();
      }

      await tester.enterText(key("recall-input"), "1");
      await tester.pump();
      await tester.tap(key("recall-submit"));
      await tester.pumpAndSettle();

      await tester.ensureVisible(key("recall-read"));
      await tester.tap(key("recall-read"));
      await tester.pumpAndSettle();
      expect(find.byType(BibleReaderScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Rückmeldung und „Weiter“ sind noch da.
      expect(find.textContaining("✔"), findsOneWidget);
      expect(find.text("Weiter"), findsOneWidget);
    });

    testWidgets("verspräzisierte Stelle wird so geöffnet", (tester) async {
      final p = catalog.pericopesOf("Mk")[4];

      await tester.runAsync(
        () => LocalBookLearningStorage().savePrecision(
          p.key,
          // Mk 1,16-20 → persönlich 1,14-20.
          const VersePrecision(
            startChapter: 1,
            startVerse: 14,
            endChapter: 1,
            endVerse: 20,
          ),
        ),
      );

      await pumpOverview(tester);
      await openMarkus(tester);

      await tester.tap(key("section-mk-beispiel-2"));
      await tester.pumpAndSettle();
      await tester.tap(key("section-sheet-pericopes"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key("section-pericope-${p.key}"));
      await tester.tap(key("section-pericope-${p.key}"));
      await tester.pumpAndSettle();
      await tester.tap(key("sheet-read"));
      await tester.pumpAndSettle();

      expect(find.text("Mk 1,14-20"), findsWidgets);
    });
  });
}
