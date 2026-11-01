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
import 'package:theologie_lernapp/screens/pericope_quiz/bibelkunde_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/books/books_overview_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quick_entry_panel.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'fine_mk_fixture.dart';
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

  late List<Perikope> all;
  late List<Perikope> markus;
  late BookOutlines outlines;

  setUpAll(() {
    // Die Oberfläche wird an der feinen Markus-Gliederung geprüft.
    all = withFineMarkus([
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ]);

    markus = all.where((p) => p.book == "Mk").toList();

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

  Future<void> pumpOverview(
    WidgetTester tester, {
    Size size = const Size(1000, 1600),
    Map<String, LearningCard> legacy = const {},
    List<Perikope>? perikopen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BooksOverviewScreen(
          perikopen: perikopen ?? markus,
          uid: null,
          learningService: FakeLearningService(legacy),
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

  /// Bringt ein Element der (lazy gebauten) Buchansicht ins Bild.
  Future<void> scrollTo(WidgetTester tester, String name) async {
    await tester.scrollUntilVisible(
      key(name),
      200,
      scrollable: find.descendant(
        of: key("book-detail-list"),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(key(name));
    await tester.pumpAndSettle();
  }

  BookPericope callOf(int occurrence) {
    return BookCatalog.fromPerikopen(markus)
        .pericopesOf("Mk")
        .where((p) => p.id == "berufungjuenger")
        .elementAt(occurrence);
  }

  String instruction(WidgetTester tester) =>
      tester.widget<Text>(key("recall-instruction")).data!;

  /// Kapitel der gerade abgefragten Markus-Perikope (aus dem Titel).
  String askedChapter(WidgetTester tester) {
    final chapters = {for (final p in markus) p.title: p.startChapter};

    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final chapter = chapters[t.data];
      if (chapter != null) return "$chapter";
    }

    throw StateError("Keine Perikope angezeigt");
  }

  testWidgets("Buchansicht ohne Perikopenliste, mit Abschnitten", (
    tester,
  ) async {
    await pumpOverview(tester);

    expect(find.text("Bücher systematisch lernen"), findsOneWidget);
    expect(
      find.textContaining("${markus.length} Perikopen · 0 sicher"),
      findsOneWidget,
    );

    await openMarkus(tester);

    // Keine endlose Liste einzelner Perikopen mehr.
    expect(find.text("Johannes der Täufer"), findsNothing);
    expect(find.text("Die Berufung der ersten Jünger"), findsNothing);

    // Gliederung: vorläufig gekennzeichnet, aktueller Abschnitt markiert.
    expect(key("outline-provisional"), findsOneWidget);
    expect(
      find.textContaining("Vorläufige Beispielgliederung"),
      findsOneWidget,
    );
    expect(key("section-mk-beispiel-1"), findsOneWidget);
    expect(find.text("Hier weiter"), findsOneWidget);

    await scrollTo(tester, "chapter-16");

    expect(key("chapter-1"), findsOneWidget);
  });

  testWidgets("Buch ohne hinterlegte Gliederung: automatische Abschnitte", (
    tester,
  ) async {
    await pumpOverview(
      tester,
      perikopen: all.where((p) => p.book == "Rut").toList(),
    );

    await tester.tap(key("book-Rut"));
    await tester.pumpAndSettle();

    expect(key("outline-provisional"), findsNothing);
    expect(
      tester.widget<Text>(key("outline-note")).data,
      contains("automatisch nach Kapiteln"),
    );
    expect(find.textContaining("Kapitel 1"), findsWidgets);
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

  testWidgets("Einzelne Perikope über den Abschnitt: versgenau festlegen", (
    tester,
  ) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    final p = callOf(1);

    await tester.tap(key("section-mk-beispiel-2"));
    await tester.pumpAndSettle();

    await tester.tap(key("section-sheet-pericopes"));
    await tester.pumpAndSettle();

    await tester.ensureVisible(key("section-pericope-${p.key}"));
    await tester.tap(key("section-pericope-${p.key}"));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(key("sheet-reference")).data, "Mk 1");

    await tester.tap(key("sheet-precision"));
    await tester.pumpAndSettle();

    expect(find.textContaining("Perikopenliste: Mk 1"), findsOneWidget);

    await tester.tap(key("precision-enabled"));
    await tester.pumpAndSettle();

    await tester.enterText(key("precision-start-verse"), "14");
    await tester.enterText(key("precision-end-verse"), "99");
    await tester.tap(key("precision-save"));
    await tester.pumpAndSettle();

    expect(find.text("Kapitel 1 hat nur 45 Verse."), findsOneWidget);

    await tester.enterText(key("precision-end-verse"), "20");
    await tester.tap(key("precision-save"));
    await tester.pumpAndSettle();

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

    // Im Abschnitt als versgenau erkennbar, zurücksetzen möglich.
    await tester.tap(key("section-mk-beispiel-2"));
    await tester.pumpAndSettle();
    await tester.tap(key("section-sheet-pericopes"));
    await tester.pumpAndSettle();

    expect(find.text("Mk 1,14-20 · versgenau"), findsOneWidget);

    await tester.ensureVisible(key("section-pericope-${p.key}"));
    await tester.tap(key("section-pericope-${p.key}"));
    await tester.pumpAndSettle();
    await tester.tap(key("sheet-reset"));
    await tester.pumpAndSettle();

    expect((await LocalBookLearningStorage().load()).precisions, isEmpty);
  });

  testWidgets("Ein Buch: nur die Kapitelzahl eingeben, Fehler vorab", (
    tester,
  ) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    await tester.tap(key("learn-book"));
    await tester.pumpAndSettle();

    expect(find.text("Neue Perikope"), findsOneWidget);
    expect(
      tester.widget<Text>(key("study-progress")).data,
      "Einführung · 0 von 3 Abfragen erledigt",
    );

    int answered = 0;

    for (int step = 0; step < 6; step++) {
      if (find.text("Neue Perikope").evaluate().isNotEmpty) {
        await tester.tap(key("intro-continue"));
        await tester.pumpAndSettle();
        continue;
      }

      // Einheitlich: Das Buch steht vor dem Feld, die Anleitung sagt es.
      expect(instruction(tester), "Buch: Markus – gib nur das Kapitel ein.");
      expect(find.text("Mk "), findsOneWidget);

      // Kapitel ohne Perikopen: Hinweis, keine Bewertung.
      await tester.enterText(key("recall-input"), "17");
      await tester.pump();

      expect(
        find.text("In Mk gibt es Perikopen nur bis Kapitel 16."),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(key("recall-submit")).onPressed,
        isNull,
      );

      // Mit Buch getippt geht auch – nicht nur durch Ausprobieren.
      final chapter = askedChapter(tester);

      await tester.enterText(
        key("recall-input"),
        answered == 0 ? "Mk $chapter" : chapter,
      );
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

    final stored = await LocalBookLearningStorage().load();

    // Nur die Perikopen der Testliste; die Übernahme in die gröbere
    // Gliederung (PericopeMerges) legt dazu Kopien unter neuen Schlüsseln an.
    final keys = markus.map(BookPericope.keyOf).toSet();
    expect(
      stored.cards.entries
          .where((e) => keys.contains(e.key) && e.value.introducedAt != null)
          .length,
      3,
    );
    // Ungültige Eingaben wurden nicht als Fehler verbucht.
    expect(stored.cards.values.every((c) => c.wrongCount == 0), isTrue);
  });

  testWidgets("Schnelleingabe aus dem Perikopenquiz mit Buchkontext", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      QuickEntryPanel.preferenceKey: true,
    });

    await pumpOverview(tester);
    await openMarkus(tester);

    await tester.tap(key("learn-book"));
    await tester.pumpAndSettle();
    await tester.tap(key("intro-continue"));
    await tester.pumpAndSettle();
    await tester.tap(key("intro-continue"));
    await tester.pumpAndSettle();
    await tester.tap(key("intro-continue"));
    await tester.pumpAndSettle();

    // Das Buch ist gesetzt; die Schnelleingabe beginnt bei den Kapiteln.
    expect(key("book-quick-entry"), findsOneWidget);

    final chapter = askedChapter(tester);

    final panel = find.descendant(
      of: key("book-quick-entry"),
      matching: find.text(chapter),
    );

    await tester.tap(panel.first);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(key("recall-input")).controller!.text,
      chapter,
    );

    await tester.tap(key("recall-submit"));
    await tester.pumpAndSettle();

    expect(find.textContaining("✔"), findsOneWidget);
  });

  testWidgets("Mehrere Bücher: Buch angeben, Schnelleingabe mit Büchern", (
    tester,
  ) async {
    final catalog = BookCatalog.fromPerikopen(all);

    final gen = catalog.pericopesOf("Gen").first;
    final mk = catalog.pericopesOf("Mk").first;

    await LocalBookLearningStorage().saveCards([
      for (final p in [gen, mk])
        BookCard(
          id: p.key,
          lastReviewed: now.subtract(const Duration(days: 5)),
        ),
    ]);

    await pumpOverview(
      tester,
      perikopen: all.where((p) => p.book == "Gen" || p.book == "Mk").toList(),
    );

    await tester.tap(key("open-reviews"));
    await tester.pumpAndSettle();

    expect(find.text("2 Wiederholungen jetzt fällig"), findsOneWidget);

    await tester.tap(key("review-start-all"));
    await tester.pumpAndSettle();

    expect(instruction(tester), "Mehrere Bücher – gib Buch und Kapitel ein.");
    expect(find.text("Mk "), findsNothing);

    await tester.enterText(key("recall-input"), "1");
    await tester.pump();

    expect(
      find.text("Bitte auch das Buch angeben, z. B. Gen 5."),
      findsOneWidget,
    );

    await tester.enterText(key("recall-input"), "Xyz 1");
    await tester.pump();

    expect(find.text("„Xyz“ ist kein bekanntes Bibelbuch."), findsOneWidget);

    // Schnelleingabe des Perikopenquiz: Buch wählen, dann Kapitel.
    await tester.enterText(key("recall-input"), "");
    await tester.tap(key("book-quick-entry-toggle"));
    await tester.pumpAndSettle();

    final panel = key("book-quick-entry");

    expect(
      find.descendant(of: panel, matching: find.text("Gen")),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text("Mk")),
      findsOneWidget,
    );

    final title = find.textContaining(
      RegExp("^(${RegExp.escape(gen.title)}|${RegExp.escape(mk.title)})\$"),
    );

    final isGen = tester.widget<Text>(title.first).data == gen.title;

    await tester.tap(
      find.descendant(of: panel, matching: find.text(isGen ? "Gen" : "Mk")),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: panel, matching: find.text("1")).first,
    );
    await tester.pumpAndSettle();

    final text = tester.widget<TextField>(key("recall-input")).controller!.text;

    expect(text, isGen ? "Gen 1" : "Mk 1");
  });

  testWidgets("Abschnitt lernen und zum nächsten Abschnitt", (tester) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    await tester.tap(key("section-learn-mk-beispiel-1"));
    await tester.pumpAndSettle();

    // Abschnitt 1 hat drei Perikopen: je Einführung und Abfrage.
    for (int step = 0; step < 6; step++) {
      if (find.text("Neue Perikope").evaluate().isNotEmpty) {
        await tester.tap(key("intro-continue"));
      } else {
        await tester.enterText(key("recall-input"), "1");
        await tester.pump();
        await tester.tap(key("recall-submit"));
        await tester.pumpAndSettle();
        await tester.tap(key("recall-submit"));
      }
      await tester.pumpAndSettle();
    }

    expect(key("study-result"), findsOneWidget);
    expect(find.text("Weiter: Erstes Wirken in Galiläa"), findsOneWidget);

    await tester.tap(key("follow-up-0"));
    await tester.pumpAndSettle();

    expect(find.text("Erstes Wirken in Galiläa"), findsOneWidget);
    expect(find.text("Neue Perikope"), findsOneWidget);
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

  testWidgets("Prüfung eines Kapitels ohne Lösungshinweise", (tester) async {
    await pumpOverview(tester);
    await openMarkus(tester);

    await scrollTo(tester, "mode-exam");
    await tester.tap(key("mode-exam"));
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
      await tester.enterText(key("recall-input"), "2");
      await tester.pump();
      await tester.tap(key("recall-submit"));
      await tester.pumpAndSettle();

      expect(key("study-feedback"), findsNothing);
    }

    expect(
      tester.widget<Text>(key("study-result")).data,
      "0 von $count richtig",
    );
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

    await scrollTo(tester, "mode-order");
    await tester.tap(key("mode-order"));
    await tester.pumpAndSettle();
    await tester.tap(key("range-whole-book"));
    await tester.pumpAndSettle();

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
    expect(key("retry-mistakes"), findsNothing);

    await tester.tap(key("study-done"));
    await tester.pumpAndSettle();

    final stored = await LocalBookLearningStorage().load();

    expect(stored.cards, isNotEmpty);
    expect(stored.cards.values.every((c) => c.lastReviewed == null), isTrue);
  });

  testWidgets("Kleiner Bildschirm ohne Überlauf", (tester) async {
    SharedPreferences.setMockInitialValues({
      QuickEntryPanel.preferenceKey: true,
    });

    await pumpOverview(tester, size: const Size(320, 568));

    expect(tester.takeException(), isNull);

    await openMarkus(tester);

    expect(tester.takeException(), isNull);

    await scrollTo(tester, "section-mk-beispiel-2");
    await tester.tap(key("section-mk-beispiel-2"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.ensureVisible(key("section-sheet-learn"));
    await tester.tap(key("section-sheet-learn"));
    await tester.pumpAndSettle();

    while (key("intro-continue").evaluate().isNotEmpty) {
      await tester.ensureVisible(key("intro-continue"));
      await tester.tap(key("intro-continue"));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }

    // Abfrage mit geöffneter Schnelleingabe.
    expect(key("book-quick-entry"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group("Bibelkunde", () {
    Future<void> pumpHub(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibelkundeScreen(perikopen: markus, uid: null),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("bündelt Perikopenquiz und Bücher-Lernen", (tester) async {
      await pumpHub(tester);

      expect(find.text("Bibelkunde"), findsOneWidget);
      expect(find.text("Perikopenquiz"), findsOneWidget);
      expect(find.text("Bücher systematisch lernen"), findsOneWidget);

      await tester.tap(key("bibelkunde-books"));
      await tester.pumpAndSettle();

      expect(find.byType(BooksOverviewScreen), findsOneWidget);
      expect(key("book-Mk"), findsOneWidget);
    });

    testWidgets("öffnet das bestehende Perikopenquiz", (tester) async {
      await pumpHub(tester);

      await tester.tap(key("bibelkunde-quiz"));
      await tester.pumpAndSettle();

      expect(find.byType(QuizScreen), findsOneWidget);
    });
  });
}
