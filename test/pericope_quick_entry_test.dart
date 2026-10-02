import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/bible_structure.dart';
import 'package:theologie_lernapp/quiz/pericope_reference.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quick_entry_panel.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_settings_sheet.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/settings/quiz_settings.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/utils/bible_reference_validator.dart';

List<Perikope> loadAssetPerikopen() {
  final List decoded = jsonDecode(
    File('assets/perikopen.json').readAsStringSync(),
  );

  return decoded.map((e) => Perikope.fromJson(e)).toList();
}

Perikope perikope(
  String id,
  String book,
  int startChapter,
  int startVerse,
  int endChapter,
  int endVerse, {
  bool required = true,
  String precision = "chapter",
}) {
  return Perikope(
    id: id,
    title: "Titel $id",
    book: book,
    startChapter: startChapter,
    startVerse: startVerse,
    endChapter: endChapter,
    endVerse: endVerse,
    required: required,
    precision: precision,
  );
}

/// Schreibweise der erwarteten Antwort, wie sie das Quiz vor Einführung der
/// Schnelleingabe gebildet hat. Dient als Vergleich, damit die gemeinsame
/// Formatierung die Quizregeln nicht verändert.
String legacyAnswer(Perikope p) {
  String reference() {
    if (p.precision == "chapter") {
      if (p.startChapter == p.endChapter) {
        return "${p.startChapter}";
      }

      return "${p.startChapter}-${p.endChapter}";
    }

    if (p.startChapter == p.endChapter) {
      if (p.startVerse == p.endVerse) {
        return "${p.startChapter},${p.startVerse}";
      }

      return "${p.startChapter},${p.startVerse}-${p.endVerse}";
    }

    return "${p.startChapter},${p.startVerse}-${p.endChapter},${p.endVerse}";
  }

  return "${p.book} ${reference()}";
}

class FakeSettingsService implements SettingsService {
  Set<String> books;

  FakeSettingsService(this.books);

  @override
  Future<Set<String>> loadBooks(String? uid) async => {...books};

  @override
  Future<void> saveBooks(String? uid, Set<String> books) async {
    this.books = {...books};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLearningService implements LearningService {
  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {};

  @override
  Future<void> savePerikopeCard(String? uid, LearningCard card) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder key(String value) => find.byKey(ValueKey(value));

Future<void> tapKey(WidgetTester tester, String value) async {
  await tester.ensureVisible(key(value));
  await tester.pump();
  await tester.tap(key(value));
  await tester.pump();
}

/// Bettet das Panel so ein wie das Quiz: Die Auswahl steht als Text in einem
/// Feld, das Panel zeigt dessen Inhalt an.
class PanelHost extends StatefulWidget {
  final BibleStructure structure;
  final String precision;
  final List<String> books;

  const PanelHost({
    super.key,
    required this.structure,
    required this.precision,
    required this.books,
  });

  @override
  State<PanelHost> createState() => PanelHostState();
}

class PanelHostState extends State<PanelHost> {
  String text = "";

  late List<String> books = widget.books;

  void setBooks(List<String> value) => setState(() => books = value);

  void setText(String value) => setState(() => text = value);

  @override
  Widget build(BuildContext context) {
    final parsed = PericopeReference.parse(text);

    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: QuickEntryPanel(
          books: books,
          structure: widget.structure,
          precision: widget.precision,
          value: parsed != null && widget.structure.allows(parsed, books)
              ? parsed
              : PericopeReference.empty,
          onChanged: (reference) => setText(reference.text),
        ),
      ),
    );
  }
}

void main() {
  final assetPerikopen = loadAssetPerikopen();
  final assetStructure = BibleStructure.fromPerikopen(assetPerikopen);

  group("Stellenformat", () {
    test("Erwartete Antworten aller Perikopen bleiben unverändert und "
        "bestehen die vorhandene Validierung", () {
      for (final p in assetPerikopen) {
        final text = PericopeReference.of(p).text;

        expect(text, legacyAnswer(p));

        // Bücher außerhalb der Quiz-Einstellungen werden nie gefragt.
        if (!QuizSettings.allBooks.contains(p.book)) continue;

        expect(PericopeReference.parse(text)!.text, text);
        expect(BibleReferenceValidator.validateBook(text), isNull);
        expect(BibleReferenceValidator.isValid(text, p.precision), isTrue);
        expect(BibleReferenceValidator.matchesPerikope(text, p), isTrue);
      }
    });

    test("Versgenaue Schreibweisen entsprechen dem bisherigen Format", () {
      final cases = [
        perikope("a", "Mk", 1, 9, 1, 11, precision: "verse"),
        perikope("b", "Mk", 1, 9, 1, 9, precision: "verse"),
        perikope("c", "Gen", 1, 1, 2, 4, precision: "verse"),
      ];

      expect(cases.map((p) => PericopeReference.of(p).text), [
        "Mk 1,9-11",
        "Mk 1,9",
        "Gen 1,1-2,4",
      ]);

      for (final p in cases) {
        final text = PericopeReference.of(p).text;

        expect(text, legacyAnswer(p));
        expect(PericopeReference.parse(text)!.text, text);
        expect(BibleReferenceValidator.isValid(text, "verse"), isTrue);
        expect(BibleReferenceValidator.matchesPerikope(text, p), isTrue);
      }
    });

    test("Formatprüfung: Versbereiche mit und ohne Endkapitel", () {
      bool valid(String text) => BibleReferenceValidator.isValid(text, "verse");

      expect(valid("Mk 1,9"), isTrue);
      expect(valid("Mk 1,9-11"), isTrue);
      expect(valid("Mk 1,9-2,4"), isTrue);

      expect(valid("Mk 1"), isFalse);
      expect(valid("Mk 1-9"), isFalse);
      expect(valid("Mk 1,9-"), isFalse);
      expect(valid("Mk 1,9-11-12"), isFalse);
      expect(valid("Mk 1,9-2,"), isFalse);

      final p = perikope("a", "Mk", 1, 9, 1, 11, precision: "verse");

      expect(BibleReferenceValidator.matchesPerikope("Mk 1,9-12", p), isFalse);
      expect(
        BibleReferenceValidator.matchesPerikope("Mk 1,9-2,11", p),
        isFalse,
      );
    });

    test("Keine Perikope endet vor ihrem Anfang", () {
      for (final p in assetPerikopen) {
        final ordered =
            p.endChapter > p.startChapter ||
            (p.endChapter == p.startChapter && p.endVerse >= p.startVerse);

        expect(ordered, isTrue, reason: p.id);
      }
    });

    test("Eingaben werden gelesen, auch unvollständig", () {
      expect(PericopeReference.parse("Mk")!.text, "Mk");
      expect(PericopeReference.parse("  Mk   8-10 ")!.text, "Mk 8-10");
      expect(PericopeReference.parse("1Kön 3,5-9")!.endVerse, 9);
      expect(PericopeReference.parse("Gen 1,1-2,4")!.endChapter, 2);

      expect(PericopeReference.parse(""), isNull);
      expect(PericopeReference.parse("Mk 8-10,3"), isNull);
      expect(PericopeReference.parse("Mk acht"), isNull);
    });
  });

  group("Grenzen aus den Perikopen", () {
    test("Kapitelzahl je Buch", () {
      expect(assetStructure.chapterCount("Mk"), 16);
      expect(assetStructure.chapterCount("Ps"), 150);
      expect(assetStructure.chapterCount("Phlm"), 1);
      expect(assetStructure.chapterCount("Unbekannt"), 0);

      for (final book in QuizSettings.allBooks) {
        expect(assetStructure.chapterCount(book), greaterThan(0), reason: book);
      }
    });

    test("Verszahl je Kapitel", () {
      expect(assetStructure.verseCount("Mk", 10), 52);
      expect(assetStructure.verseCount("Ps", 119), 176);
      expect(assetStructure.verseCount("Mk", 17), 0);
    });

    test("Nur Stellen innerhalb der Grenzen und erlaubten Bücher", () {
      bool allows(String text, [List<String> books = const ["Mk", "Lk"]]) {
        return assetStructure.allows(PericopeReference.parse(text)!, books);
      }

      expect(allows("Mk 16"), isTrue);
      expect(allows("Mk 17"), isFalse);
      expect(allows("Mk 8-10"), isTrue);
      expect(allows("Mk 10-8"), isFalse);
      expect(allows("Mk 10,52"), isTrue);
      expect(allows("Mk 10,53"), isFalse);
      expect(allows("Mk 10,12-1"), isFalse);
      expect(allows("Mk 9,2-10,5"), isTrue);
      expect(allows("Mt 5"), isFalse);
      expect(allows("Mt 5", ["Mt"]), isTrue);
    });
  });

  group("Panel", () {
    Future<PanelHostState> pumpPanel(
      WidgetTester tester, {
      String precision = "chapter",
      List<String> books = const ["Mt", "Mk", "Lk", "Phlm"],
    }) async {
      await tester.pumpWidget(
        PanelHost(
          structure: assetStructure,
          precision: precision,
          books: books,
        ),
      );

      return tester.state<PanelHostState>(find.byType(PanelHost));
    }

    testWidgets("Nur erlaubte Bücher, Änderungen wirken sofort", (
      tester,
    ) async {
      final host = await pumpPanel(tester, books: ["Mk", "Lk"]);

      expect(key("quick-book-Mk"), findsOneWidget);
      expect(key("quick-book-Lk"), findsOneWidget);
      expect(key("quick-book-Mt"), findsNothing);
      expect(key("quick-book-Gen"), findsNothing);

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-8");
      expect(host.text, "Mk 8");

      // Mk wird abgewählt: Die Auswahl gilt nicht mehr, Mk fehlt.
      host.setBooks(["Lk", "Mt"]);
      await tester.pump();

      expect(key("quick-book-Mk"), findsNothing);
      expect(key("quick-book-Mt"), findsOneWidget);
      expect(key("quick-chapter-8"), findsNothing);
    });

    testWidgets("Nur vorhandene Kapitel", (tester) async {
      await pumpPanel(tester);

      await tapKey(tester, "quick-book-Mk");

      expect(key("quick-chapter-1"), findsOneWidget);
      expect(key("quick-chapter-16"), findsOneWidget);
      expect(key("quick-chapter-17"), findsNothing);
    });

    testWidgets("Kapitelbereich: Anfang nie hinter dem Ende", (tester) async {
      final host = await pumpPanel(tester);

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-8");
      await tapKey(tester, "quick-chapter-10");
      expect(host.text, "Mk 8-10");

      // Nach einem fertigen Bereich beginnt ein Tipp neu.
      await tapKey(tester, "quick-chapter-12");
      expect(host.text, "Mk 12");

      // Früheres Kapitel wird neuer Anfang statt „12-3“.
      await tapKey(tester, "quick-chapter-3");
      expect(host.text, "Mk 3");

      // Erneuter Tipp hebt die Auswahl auf.
      await tapKey(tester, "quick-chapter-3");
      expect(host.text, "Mk");
    });

    testWidgets("Buchwechsel setzt Kapitel zurück, Bücher mit einem Kapitel "
        "sind sofort vollständig", (tester) async {
      final host = await pumpPanel(tester);

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-8");
      await tapKey(tester, "quick-chapter-10");

      await tapKey(tester, "quick-step-book");
      await tapKey(tester, "quick-book-Lk");

      expect(host.text, "Lk");
      expect(key("quick-chapter-24"), findsOneWidget);
      expect(key("quick-chapter-25"), findsNothing);

      await tapKey(tester, "quick-step-book");
      await tapKey(tester, "quick-book-Phlm");

      expect(host.text, "Phlm 1");
    });

    testWidgets("Nur vorhandene Verse, Versbereich", (tester) async {
      final host = await pumpPanel(tester, precision: "verse");

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-10");
      expect(host.text, "Mk 10");

      expect(key("quick-verse-52"), findsOneWidget);
      expect(key("quick-verse-53"), findsNothing);

      await tapKey(tester, "quick-verse-12");
      expect(host.text, "Mk 10,12");

      // Früherer Vers wird neuer Anfang statt „12-1“.
      await tapKey(tester, "quick-verse-1");
      expect(host.text, "Mk 10,1");

      await tapKey(tester, "quick-verse-12");
      expect(host.text, "Mk 10,1-12");
    });

    testWidgets("Kapitelwechsel verwirft die Verse", (tester) async {
      final host = await pumpPanel(tester, precision: "verse");

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-10");
      await tapKey(tester, "quick-verse-50");

      await tapKey(tester, "quick-step-chapter");
      await tapKey(tester, "quick-chapter-16");

      expect(host.text, "Mk 16");
      expect(
        key("quick-verse-${assetStructure.verseCount("Mk", 16)}"),
        findsOneWidget,
      );
      expect(key("quick-verse-50"), findsNothing);
    });

    testWidgets("Versbereich über Kapitelgrenze", (tester) async {
      final host = await pumpPanel(tester, precision: "verse");

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-9");
      await tapKey(tester, "quick-verse-2");
      await tapKey(tester, "quick-end-chapter");

      // Nur spätere Kapitel kommen als Ende in Frage.
      expect(key("quick-chapter-9"), findsNothing);
      expect(key("quick-chapter-10"), findsOneWidget);

      await tapKey(tester, "quick-chapter-10");
      expect(key("quick-verse-53"), findsNothing);

      await tapKey(tester, "quick-verse-5");
      expect(host.text, "Mk 9,2-10,5");
    });

    testWidgets("Zurücksetzen und von außen geänderter Text", (tester) async {
      final host = await pumpPanel(tester);

      // Getippter Text wird übernommen.
      host.setText("Lk 9");
      await tester.pump();

      expect(key("quick-chapter-24"), findsOneWidget);

      await tester.tap(key("quick-reset"));
      await tester.pump();

      expect(host.text, "");
      expect(key("quick-book-Lk"), findsOneWidget);

      // Nicht auswählbarer Text zählt als leer.
      host.setText("Lk 99");
      await tester.pump();

      expect(key("quick-book-Lk"), findsOneWidget);
      expect(key("quick-chapter-1"), findsNothing);
    });

    testWidgets("Alle Bücher und 150 Kapitel ohne Overflow auf kleinem "
        "Display", (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPanel(tester, books: QuizSettings.allBooks);
      expect(tester.takeException(), isNull);

      await tapKey(tester, "quick-book-Ps");
      expect(tester.takeException(), isNull);

      await tapKey(tester, "quick-chapter-150");
      expect(tester.takeException(), isNull);
    });
  });

  group("Quiz", () {
    // Eine einzige Frage mit zwei erwarteten Stellen. Die übrigen Einträge
    // werden nie gefragt und legen nur den Umfang der Bücher fest.
    final perikopen = [
      perikope("frage", "Mk", 8, 27, 10, 52),
      perikope("frage", "Lk", 9, 18, 9, 27),
      perikope("mk_ende", "Mk", 16, 1, 16, 20, required: false),
      perikope("lk_ende", "Lk", 24, 1, 24, 53, required: false),
      perikope("mt_ende", "Mt", 28, 1, 28, 20, required: false),
      perikope("gen_ende", "Gen", 50, 1, 50, 26, required: false),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GeneralSettingsView.currentUser = () => null;

      // Antwort-Sounds haben im Test kein Audio-Backend.
      for (final name in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
      }
    });

    Future<FakeSettingsService> pumpQuiz(
      WidgetTester tester, {
      List<Perikope>? items,
      Set<String> books = const {"Mt", "Mk", "Lk"},
      Size size = const Size(1000, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final settings = FakeSettingsService({...books});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuizScreen(
            perikopen: items ?? perikopen,
            uid: null,
            settingsService: settings,
            learningService: FakeLearningService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return settings;
    }

    List<String> inputs(WidgetTester tester) {
      return tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!.text)
          .toList();
    }

    testWidgets("Bisherige Eingabe per Textfeld funktioniert unverändert, "
        "die Schnelleingabe ist zunächst ausgeblendet", (tester) async {
      await pumpQuiz(tester);

      expect(find.byType(QuickEntryPanel), findsNothing);
      expect(key("quick-entry-toggle"), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, "Mk 8-10");
      await tester.tap(find.text("Weitere Eingabe"));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), "Lk 9");
      await tester.pump();

      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔ Richtig"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Mehrere Stellen per Schnelleingabe werden von der "
        "bestehenden Prüfung als richtig gewertet", (tester) async {
      await pumpQuiz(tester);

      await tester.tap(key("quick-entry-toggle"));
      await tester.pump();

      expect(find.byType(QuickEntryPanel), findsOneWidget);

      // Nur die aktivierten Bücher.
      expect(key("quick-book-Mt"), findsOneWidget);
      expect(key("quick-book-Mk"), findsOneWidget);
      expect(key("quick-book-Lk"), findsOneWidget);
      expect(key("quick-book-Gen"), findsNothing);

      await tapKey(tester, "quick-book-Mk");
      expect(key("quick-chapter-17"), findsNothing);

      await tapKey(tester, "quick-chapter-8");
      await tapKey(tester, "quick-chapter-10");
      expect(inputs(tester), ["Mk 8-10"]);

      await tester.tap(find.text("Weitere Eingabe"));
      await tester.pump();

      expect(find.textContaining("Stelle 2 von 2"), findsOneWidget);

      await tapKey(tester, "quick-book-Lk");
      await tapKey(tester, "quick-chapter-9");
      expect(inputs(tester), ["Mk 8-10", "Lk 9"]);

      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔ Richtig"), findsOneWidget);
      expect(find.byType(QuickEntryPanel), findsNothing);

      // Nächste Frage: Felder leer, Schnelleingabe wieder am Anfang.
      await tester.tap(find.text("Weiter"));
      await tester.pumpAndSettle();

      expect(inputs(tester), ["", ""]);
      expect(find.textContaining("Stelle 1 von 2"), findsOneWidget);
      expect(key("quick-book-Mk"), findsOneWidget);
    });

    testWidgets("Unvollständige oder falsche Schnelleingabe ist falsch", (
      tester,
    ) async {
      await pumpQuiz(tester);

      await tester.tap(key("quick-entry-toggle"));
      await tester.pump();

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-8");
      await tapKey(tester, "quick-chapter-10");

      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✘ Falsch"), findsOneWidget);
      expect(find.textContaining("• Lk 9"), findsOneWidget);
    });

    testWidgets("Stelle entfernen und andere Stelle bearbeiten", (
      tester,
    ) async {
      await pumpQuiz(tester);

      await tester.tap(key("quick-entry-toggle"));
      await tester.pump();

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-8");

      await tester.tap(find.text("Weitere Eingabe"));
      await tester.pump();
      await tapKey(tester, "quick-book-Mt");
      await tapKey(tester, "quick-chapter-5");
      expect(inputs(tester), ["Mk 8", "Mt 5"]);

      // Erstes Feld antippen: Die Schnelleingabe bearbeitet nun dieses.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      expect(find.textContaining("Stelle 1 von 2"), findsOneWidget);

      await tapKey(tester, "quick-chapter-10");
      expect(inputs(tester), ["Mk 8-10", "Mt 5"]);

      // Zweite Stelle entfernen.
      await tester.tap(find.byIcon(Icons.remove_circle).at(1));
      await tester.pump();

      expect(inputs(tester), ["Mk 8-10"]);
      expect(tester.takeException(), isNull);

      await tapKey(tester, "quick-chapter-9");
      expect(inputs(tester), ["Mk 9"]);
    });

    testWidgets("Geänderte Quiz-Einstellungen wirken auf die Schnelleingabe", (
      tester,
    ) async {
      final settings = await pumpQuiz(tester);

      await tester.tap(key("quick-entry-toggle"));
      await tester.pump();

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-8");
      expect(inputs(tester), ["Mk 8"]);

      Future<void> toggleBook(String book) async {
        final row = find
            .ancestor(
              of: find.descendant(
                of: find.byType(QuizSettingsSheet),
                matching: find.text(book),
              ),
              matching: find.byType(Row),
            )
            .first;

        await tester.tap(
          find.descendant(of: row, matching: find.byType(Checkbox)),
        );
        await tester.pump();
      }

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await toggleBook("Mk");
      await toggleBook("Gen");

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(settings.books, {"Mt", "Lk", "Gen"});

      // Die Stelle aus dem abgewählten Buch ist weg, Mk nicht mehr wählbar.
      expect(inputs(tester), [""]);
      expect(key("quick-book-Mk"), findsNothing);
      expect(key("quick-chapter-8"), findsNothing);
      expect(key("quick-book-Gen"), findsOneWidget);
      expect(key("quick-book-Lk"), findsOneWidget);

      // Die laufende Frage erwartet sofort nur noch die Stelle aus Lk.
      await tapKey(tester, "quick-book-Lk");
      await tapKey(tester, "quick-chapter-9");

      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔ Richtig"), findsOneWidget);
    });

    testWidgets("Getippter Versbereich ergibt keinen Formatfehler", (
      tester,
    ) async {
      await pumpQuiz(
        tester,
        books: {"Mk"},
        items: [perikope("frage", "Mk", 10, 1, 10, 12, precision: "verse")],
      );

      await tester.enterText(find.byType(TextField).first, "Mk 10,1-12");
      await tester.pump();

      expect(find.text("✘ Ungültiges Format"), findsNothing);

      await tester.enterText(find.byType(TextField).first, "Mk 10-12");
      await tester.pump();

      expect(find.text("✘ Ungültiges Format"), findsOneWidget);
    });

    testWidgets("Kleines Display: Auswertung mit mehreren Stellen ohne "
        "Overflow", (tester) async {
      await pumpQuiz(tester, size: const Size(360, 640));

      await tester.enterText(find.byType(TextField).first, "Mk 8-10");
      await tester.tap(find.text("Weitere Eingabe"));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), "Mt 5");
      await tester.pump();

      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✘ Falsch"), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text("Weiter"));
      await tester.tap(find.text("Weiter"));
      await tester.pumpAndSettle();

      expect(inputs(tester), ["", ""]);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Versgenaue Frage per Schnelleingabe", (tester) async {
      await pumpQuiz(
        tester,
        books: {"Mk"},
        items: [
          perikope("frage", "Mk", 10, 1, 10, 12, precision: "verse"),
          perikope("mk_10", "Mk", 10, 46, 10, 52, required: false),
        ],
      );

      await tester.tap(key("quick-entry-toggle"));
      await tester.pump();

      await tapKey(tester, "quick-book-Mk");
      await tapKey(tester, "quick-chapter-10");

      expect(key("quick-verse-52"), findsOneWidget);
      expect(key("quick-verse-53"), findsNothing);

      await tapKey(tester, "quick-verse-1");
      await tapKey(tester, "quick-verse-12");
      expect(inputs(tester), ["Mk 10,1-12"]);

      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔ Richtig"), findsOneWidget);
    });

    testWidgets("Ein-/Ausblenden wird gemerkt, kleines Display ohne "
        "Overflow", (tester) async {
      SharedPreferences.setMockInitialValues({
        'pericope_quiz_quick_entry': true,
      });

      await pumpQuiz(
        tester,
        books: {...QuizSettings.allBooks},
        items: [...perikopen, ...assetPerikopen.map(_optional)],
        size: const Size(320, 568),
      );

      expect(find.byType(QuickEntryPanel), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapKey(tester, "quick-book-Ps");
      await tapKey(tester, "quick-chapter-150");
      expect(inputs(tester), ["Ps 150"]);
      expect(tester.takeException(), isNull);

      await tester.tap(key("quick-entry-toggle"));
      await tester.pump();

      expect(find.byType(QuickEntryPanel), findsNothing);
      expect(inputs(tester), ["Ps 150"]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pericope_quiz_quick_entry'), isFalse);
    });
  });
}

/// Dieselbe Perikope, aber nie gefragt: liefert nur Kapitel-/Versumfang.
Perikope _optional(Perikope p) {
  return perikope(
    "${p.id}_umfang",
    p.book,
    p.startChapter,
    p.startVerse,
    p.endChapter,
    p.endVerse,
    required: false,
  );
}
