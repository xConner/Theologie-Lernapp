import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/bible/bible_search_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_reference_parser.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/greek_keyboard.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

class FakeSettingsService implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Gen", "Mk", "Ps"};

  @override
  Future<void> saveBooks(String? uid, Set<String> books) async {}

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

/// Ob [text] im Kapitel hinterlegt (hervorgehoben) dargestellt wird.
bool isHighlighted(WidgetTester tester, String text) {
  bool found = false;

  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    widget.text.visitChildren((span) {
      if (span is TextSpan &&
          (span.text ?? "").contains(text) &&
          span.style?.backgroundColor != null) {
        found = true;
      }

      return true;
    });
  }

  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = AssetBibleTextSource(bundle: FileAssetBundle());

  late List<BibleTranslation> translations;

  BibleTranslation byId(String id) =>
      translations.firstWhere((t) => t.id == id);

  BibleRepository repository() => BibleRepository(source: source);

  setUpAll(() async {
    translations = await source.loadTranslations();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;
  });

  Future<void> pumpReader(
    WidgetTester tester, {
    List<BiblePassage> passages = const [],
    String? title,
    Size size = const Size(420, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BibleReaderScreen(
          passages: passages,
          passageTitle: title,
          repository: repository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const storm = BiblePassage(
    label: "Mk 4,35-41",
    reference: BibleReference(
      bookId: "MRK",
      chapter: 4,
      verse: 35,
      endVerse: 41,
    ),
  );

  group("Reader", () {
    testWidgets("Öffnet beim ersten Mal 1. Mose 1 in der Standardausgabe", (
      tester,
    ) async {
      await pumpReader(tester);

      expect(find.text("1. Mose 1"), findsOneWidget);
      expect(find.text("LUT 1912"), findsOneWidget);
      expect(find.textContaining("Am Anfang schuf Gott"), findsOneWidget);
      expect(find.text("Kapitel 1 von 50"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Blättern und Lesestand", (tester) async {
      await pumpReader(tester);

      // Am Anfang der Bibel gibt es kein vorheriges Kapitel.
      expect(
        tester.widget<IconButton>(key("bible-previous-chapter")).onPressed,
        isNull,
      );

      await tester.tap(key("bible-next-chapter"));
      await tester.pumpAndSettle();

      expect(find.text("1. Mose 2"), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString("bible_position"), startsWith("GEN|2|"));

      // Neu geöffnet: wieder an derselben Stelle.
      await tester.pumpWidget(const SizedBox());
      await pumpReader(tester);

      expect(find.text("1. Mose 2"), findsOneWidget);
    });

    testWidgets("Blättern über die Buchgrenze", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "MAL|4|0"});

      await pumpReader(tester);

      expect(find.text("Maleachi 4"), findsOneWidget);

      await tester.tap(key("bible-next-chapter"));
      await tester.pumpAndSettle();

      expect(find.text("Matthäus 1"), findsOneWidget);

      await tester.tap(key("bible-previous-chapter"));
      await tester.pumpAndSettle();

      expect(find.text("Maleachi 4"), findsOneWidget);
    });

    testWidgets("Der gemerkte Vers steht nach dem Öffnen wieder oben", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"bible_position": "PSA|119|150"});

      await pumpReader(tester);

      expect(find.text("Psalmen 119"), findsOneWidget);

      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );

      expect(scroll.position.pixels, greaterThan(1000));

      // Nach dem Scrollen merkt sich der Reader den obersten Vers.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();

      final verse = int.parse(prefs.getString("bible_position")!.split("|")[2]);

      expect(verse, inExclusiveRange(100, 150));
    });

    testWidgets("Stelleneingabe springt zur Stelle und hebt die Verse "
        "hervor", (tester) async {
      await pumpReader(tester);

      await tester.tap(key("bible-reference-button"));
      await tester.pumpAndSettle();

      // Ungültige Eingabe: Hinweis statt Sprung.
      await tester.enterText(key("bible-reference-input"), "Unsinn 3");
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.textContaining("Keine Stelle erkannt"), findsOneWidget);

      await tester.enterText(key("bible-reference-input"), "Mk 4,35–41");
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.text("Markus 4"), findsOneWidget);
      expect(isHighlighted(tester, "Laßt uns hinüberfahren"), isTrue);
      expect(isHighlighted(tester, "Höret zu!"), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Buch und Kapitel wählen", (tester) async {
      await pumpReader(tester, size: const Size(900, 1400));

      await tester.tap(key("bible-reference-button"));
      await tester.pumpAndSettle();

      expect(find.text("Altes Testament"), findsOneWidget);
      expect(find.text("Neues Testament"), findsOneWidget);

      await tester.ensureVisible(key("bible-book-JHN"));
      await tester.tap(key("bible-book-JHN"));
      await tester.pumpAndSettle();

      await tester.ensureVisible(key("bible-chapter-3"));
      await tester.tap(key("bible-chapter-3"));
      await tester.pumpAndSettle();

      expect(find.text("Johannes 3"), findsOneWidget);
      expect(find.textContaining("Also hat Gott die Welt"), findsOneWidget);
    });

    testWidgets("Übersetzung wechseln: Auswahl nach Sprache, Stelle bleibt, "
        "Wahl wird gemerkt", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "JHN|1|0"});

      await pumpReader(tester, size: const Size(600, 2400));

      await tester.tap(key("bible-translation-button"));
      await tester.pumpAndSettle();

      for (final language in ["Deutsch", "Englisch", "Griechisch", "Latein"]) {
        expect(find.text(language), findsOneWidget);
      }

      // Jede verfügbare Ausgabe steht mit ihrem vollen Namen zur Wahl.
      for (final t in translations) {
        expect(find.text(t.name), findsOneWidget, reason: t.id);
      }

      await tester.tap(key("bible-translation-grcsbl"));
      await tester.pumpAndSettle();

      expect(find.text("SBLGNT"), findsOneWidget);
      expect(find.text("ΚΑΤΑ ΙΩΑΝΝΗΝ 1"), findsOneWidget);
      expect(find.textContaining("Ἐν ἀρχῇ ἦν ὁ λόγος"), findsOneWidget);

      // Quellenangabe beim Text.
      expect(
        find.textContaining("Society of Biblical Literature"),
        findsOneWidget,
      );

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString("bible_translation"), "grcsbl");
    });

    testWidgets("Quelle und Lizenz jeder Ausgabe sind einsehbar", (
      tester,
    ) async {
      await pumpReader(tester, size: const Size(600, 2400));

      await tester.tap(key("bible-translation-button"));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: key("bible-translation-deuelbbk"),
          matching: find.byIcon(Icons.info_outline),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("CC BY-NC-ND 4.0"), findsWidgets);
      expect(
        find.textContaining("Verbreitung des christlichen Glaubens"),
        findsWidgets,
      );
      expect(find.textContaining("Nur nichtkommerzielle"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Fehlt ein Buch in der Ausgabe, werden passende Ausgaben "
        "angeboten", (tester) async {
      SharedPreferences.setMockInitialValues({
        "bible_translation": "grcsbl",
        "bible_position": "GEN|1|0",
      });

      await pumpReader(tester);

      expect(find.textContaining("nicht enthalten"), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, "LXX Brenton"));
      await tester.pumpAndSettle();

      expect(find.textContaining("ἐποίησεν ὁ Θεὸς"), findsWidgets);
    });

    testWidgets("Unbekannte gespeicherte Ausgabe fällt auf den Standard "
        "zurück", (tester) async {
      SharedPreferences.setMockInitialValues({
        "bible_translation": "gibtsnicht",
      });

      await pumpReader(tester);

      expect(find.text("LUT 1912"), findsOneWidget);
    });

    testWidgets("Schmales und breites Fenster ohne Overflow", (tester) async {
      for (final size in const [Size(320, 560), Size(1600, 900)]) {
        await pumpReader(tester, size: size, passages: const [storm]);

        expect(tester.takeException(), isNull, reason: "$size");

        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group("Perikope im Reader", () {
    testWidgets("Verse hervorgehoben, Kapitelzusammenhang lesbar, "
        "Lesestand unberührt", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "PSA|23|0"});

      await pumpReader(
        tester,
        title: "Die Stillung des Sturms",
        passages: const [storm],
      );

      expect(find.text("Die Stillung des Sturms"), findsOneWidget);
      expect(find.text("Mk 4,35-41"), findsOneWidget);
      expect(find.text("Markus 4"), findsOneWidget);

      // Das ganze Kapitel steht da, hervorgehoben ist nur die Perikope.
      expect(find.textContaining("Höret zu!"), findsOneWidget);
      expect(isHighlighted(tester, "Laßt uns hinüberfahren"), isTrue);
      expect(isHighlighted(tester, "Höret zu!"), isFalse);

      // Die Perikope steht im sichtbaren Bereich, nicht der Kapitelanfang.
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );

      expect(scroll.position.pixels, greaterThan(0));

      // Neues Testament: kein Hinweis zur Zählung.
      expect(key("bible-passage-hint"), findsNothing);

      // Im Zusammenhang weiterlesen; die Perikope bleibt erreichbar.
      await tester.tap(key("bible-next-chapter"));
      await tester.pumpAndSettle();

      expect(find.text("Markus 5"), findsOneWidget);

      await tester.tap(key("bible-passage-0"));
      await tester.pumpAndSettle();

      expect(find.text("Markus 4"), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString("bible_position"), "PSA|23|0");
      expect(tester.takeException(), isNull);
    });

    testWidgets("Die Perikope wird in jeder Ausgabe geöffnet, die das Buch "
        "enthält", (tester) async {
      for (final t in translations) {
        SharedPreferences.setMockInitialValues({"bible_translation": t.id});

        await pumpReader(tester, passages: const [storm]);

        if (t.hasBook("MRK")) {
          expect(find.text("${t.book("MRK")!.name} 4"), findsOneWidget);
          expect(find.textContaining("nicht enthalten"), findsNothing);
        } else {
          expect(find.textContaining("nicht enthalten"), findsOneWidget);
        }

        expect(tester.takeException(), isNull, reason: t.id);

        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets("Mehrere Stellen einer Perikope sind alle erreichbar", (
      tester,
    ) async {
      await pumpReader(
        tester,
        title: "Die Nachkommen Abrahams",
        passages: const [
          BiblePassage(
            label: "Gen 25,1-18",
            reference: BibleReference(
              bookId: "GEN",
              chapter: 25,
              verse: 1,
              endVerse: 18,
            ),
          ),
          BiblePassage(
            label: "1Chr 1,28-34",
            reference: BibleReference(
              bookId: "1CH",
              chapter: 1,
              verse: 28,
              endVerse: 34,
            ),
          ),
        ],
      );

      expect(find.text("1. Mose 25"), findsOneWidget);

      await tester.tap(key("bible-passage-1"));
      await tester.pumpAndSettle();

      expect(find.text("1. Chronik 1"), findsOneWidget);
      expect(isHighlighted(tester, "Isaak"), isTrue);
    });

    testWidgets("Abweichende Zählung wird benannt statt umgerechnet", (
      tester,
    ) async {
      const psalm = [
        BiblePassage(
          label: "Ps 51,1-21",
          reference: BibleReference(
            bookId: "PSA",
            chapter: 51,
            verse: 1,
            endVerse: 21,
          ),
        ),
      ];

      // Die Lutherbibel 1912 der Quelle zählt die Überschrift nicht
      // eigens: Psalm 51 hat dort 19 Verse.
      await pumpReader(tester, passages: psalm);

      expect(
        tester.widget<Text>(key("bible-passage-hint")).data,
        contains("lässt sich nicht genau zuordnen"),
      );

      // Deutsche Zählung: kein Hinweis.
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({"bible_translation": "deuelbbk"});
      await pumpReader(tester, passages: psalm);

      expect(key("bible-passage-hint"), findsNothing);

      // Vulgata: andere Psalmenzählung.
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({"bible_translation": "latVUC"});
      await pumpReader(
        tester,
        passages: const [
          BiblePassage(
            label: "Ps 23,1-6",
            reference: BibleReference(
              bookId: "PSA",
              chapter: 23,
              verse: 1,
              endVerse: 6,
            ),
          ),
        ],
      );

      expect(
        tester.widget<Text>(key("bible-passage-hint")).data,
        contains("zählt die Psalmen anders"),
      );
    });
  });

  group("Suche im Reader", () {
    testWidgets("Stelle öffnen und Textsuche mit Treffer", (tester) async {
      await pumpReader(tester);

      await tester.tap(key("bible-search-button"));
      await tester.pumpAndSettle();

      await tester.enterText(key("bible-search-input"), "Joh 3,16");
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(key("bible-open-reference"), findsOneWidget);
      expect(find.text("Johannes 3,16"), findsOneWidget);

      await tester.enterText(
        key("bible-search-input"),
        "also hat gott die welt geliebt",
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text("1 Vers gefunden"), findsOneWidget);

      await tester.tap(find.text("Johannes 3,16"));
      await tester.pumpAndSettle();

      expect(find.text("Johannes 3"), findsOneWidget);
      expect(isHighlighted(tester, "Also hat Gott die Welt geliebt"), isTrue);
    });

    testWidgets("Griechische Suche nutzt die vorhandene Tastatur", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleSearchScreen(
            repository: repository(),
            translation: byId("grcsbl"),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GreekKeyboard), findsNothing);

      await tester.tap(key("bible-greek-keyboard"));
      await tester.pumpAndSettle();

      expect(find.byType(GreekKeyboard), findsOneWidget);

      for (final letter in ["λ", "ο", "γ", "ο", "σ"]) {
        await tester.tap(find.widgetWithText(ElevatedButton, letter));
        await tester.pump();
      }

      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.textContaining("Verse gefunden"), findsOneWidget);
      expect(find.textContaining("ΚΑΤΑ ΜΑΘΘΑΙΟΝ"), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Deutsche Ausgaben bieten keine griechische Tastatur an", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleSearchScreen(
            repository: repository(),
            translation: byId("deu1912"),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(key("bible-greek-keyboard"), findsNothing);
    });
  });

  group("Perikopenquiz", () {
    setUp(() {
      // Antwort-Sounds haben im Test kein Audio-Backend.
      for (final name in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
      }
    });

    Perikope perikope(String book, int chapter, int from, int to) {
      return Perikope(
        id: "sturm",
        title: "Die Stillung des Sturms",
        book: book,
        startChapter: chapter,
        startVerse: from,
        endChapter: chapter,
        endVerse: to,
        required: true,
        precision: "chapter",
      );
    }

    Future<void> pumpQuiz(WidgetTester tester, List<Perikope> perikopen) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuizScreen(
            perikopen: perikopen,
            uid: null,
            settingsService: FakeSettingsService(),
            learningService: FakeLearningService(),
            bibleRepository: repository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("Nach dem Prüfen führt „Bibelstelle lesen“ zur "
        "hervorgehobenen Perikope und zurück ins unveränderte Quiz", (
      tester,
    ) async {
      await pumpQuiz(tester, [perikope("Mk", 4, 35, 41)]);

      // Vor der Antwort verrät das Quiz die Stelle nicht.
      expect(key("read-passage"), findsNothing);

      await tester.enterText(find.byType(TextField).first, "Mk 4");
      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔ Richtig"), findsOneWidget);
      expect(find.text("Bibelstelle lesen"), findsOneWidget);

      await tester.ensureVisible(key("read-passage"));
      await tester.tap(key("read-passage"));
      await tester.pumpAndSettle();

      expect(find.byType(BibleReaderScreen), findsOneWidget);
      expect(find.text("Die Stillung des Sturms"), findsOneWidget);
      expect(find.text("Mk 4,35-41"), findsOneWidget);
      expect(find.text("Markus 4"), findsOneWidget);
      expect(isHighlighted(tester, "Laßt uns hinüberfahren"), isTrue);

      // Zurück: Das Quiz steht noch beim Ergebnis derselben Frage.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(BibleReaderScreen), findsNothing);
      expect(find.textContaining("✔ Richtig"), findsOneWidget);
      expect(find.text("Weiter"), findsOneWidget);
    });

    testWidgets("Im Kopf: Der Reader ist nach dem Aufdecken erreichbar; "
        "mehrere Stellen werden gemeinsam übergeben", (tester) async {
      await pumpQuiz(tester, [
        perikope("Mk", 4, 35, 41),
        perikope("Ps", 23, 1, 6),
      ]);

      await tester.tap(find.text("Im Kopf"));
      await tester.pumpAndSettle();

      expect(key("read-passage"), findsNothing);

      await tester.tap(find.byKey(const Key("self_assessment_reveal")));
      await tester.pumpAndSettle();

      expect(find.text("Bibelstellen lesen"), findsOneWidget);

      await tester.ensureVisible(key("read-passage"));
      await tester.tap(key("read-passage"));
      await tester.pumpAndSettle();

      expect(key("bible-passage-0"), findsOneWidget);
      expect(key("bible-passage-1"), findsOneWidget);
      expect(find.text("Ps 23,1-6"), findsOneWidget);
    });

    test("Eigene Perikope mit unbekanntem Buch ergibt keine Stelle", () {
      expect(
        BibleReferenceParser.passageOf(perikope("Evangelium", 4, 35, 41)),
        isNull,
      );
    });
  });
}
