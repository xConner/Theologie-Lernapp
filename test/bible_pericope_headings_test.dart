import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/bible_text.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/pericope_headings.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/bible/bible_chapter_view.dart';

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

Perikope perikope(
  String title,
  String book,
  int chapter,
  int from,
  int to, {
  String? id,
  int? endChapter,
}) {
  return Perikope(
    id: id ?? title,
    title: title,
    book: book,
    startChapter: chapter,
    startVerse: from,
    endChapter: endChapter ?? chapter,
    endVerse: to,
    required: true,
    precision: "chapter",
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = AssetBibleTextSource(bundle: FileAssetBundle());

  late List<BibleTranslation> translations;
  late PericopeHeadings headings;
  late List<Perikope> list;

  BibleTranslation byId(String id) =>
      translations.firstWhere((t) => t.id == id);

  Map<int, List<String>> of(String translation, String book, int chapter) {
    return headings.forChapter(
      translation: byId(translation),
      translations: translations,
      bookId: book,
      chapter: chapter,
    );
  }

  setUpAll(() async {
    translations = await source.loadTranslations();
    headings = await PericopeHeadings.load(bundle: FileAssetBundle());

    list = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;
  });

  group("Zuordnung", () {
    test("Jede Perikope steht mit ihrem Titel an ihrem Anfangsvers", () {
      expect(of("deuelbbk", "MRK", 4), {
        1: ["Das Gleichnis vom Sämann"],
        10: ["Sinn und Zweck der Gleichnisse"],
        13: ["Die Deutung des Gleichnisses vom Sämann"],
        21: ["Vom rechten Hören"],
        26: ["Das Gleichnis vom Wachsen der Saat"],
        30: ["Das Gleichnis vom Senfkorn"],
        33: ["Schlussbemerkung zu den Gleichnissen"],
        35: ["Der Sturm auf dem See"],
      });
    });

    test("Die ganze Liste: Titel, Buch und Anfangsvers jeder Perikope "
        "stimmen mit der JSON überein", () {
      final reference = RegExp(r'^\S+ \d+(-\d+)?$');

      int headingsFound = 0;

      for (final p in list) {
        final book = BibleBooks.byAbbreviation(p.book)!;

        // Deutsch gezählte Ausgabe, soweit sie das Buch enthält.
        final info = byId("deuelbbk").book(book.id);

        if (info == null) continue;

        // Stellen, die es nur in Ausgaben mit Zusätzen gibt (siehe unten).
        if (p.startVerse > info.verseCount(p.startChapter)) continue;

        final titles =
            of("deuelbbk", book.id, p.startChapter)[p.startVerse] ?? const [];

        if (reference.hasMatch(p.title)) {
          // Kapitelfragen wie „Ex 3“ sind keine Überschriften.
          expect(titles, isNot(contains(p.title)), reason: p.id);
        } else {
          expect(titles, contains(p.title), reason: "${p.id} ${p.book}");
          headingsFound++;
        }
      }

      // Ohne die Apokryphen, die keine deutsche Ausgabe enthält.
      expect(headingsFound, greaterThan(2400));
    });

    test(
      "Perikopen, deren Anfang es in den deutschen Ausgaben nicht gibt, "
      "bleiben ohne Überschrift statt an falscher Stelle zu stehen",
      () async {
        // Die Liste führt auch die Zusätze zu Ester und Daniel und zählt
        // Num 25/26 anders; diese Stellen fehlen in den integrierten
        // deutschen Ausgaben.
        for (final id in ["deuelbbk", "deutkw"]) {
          final missing = <String>{};

          final books = <String, BibleBookText>{};

          for (final p in list) {
            final book = BibleBooks.byAbbreviation(p.book)!;

            if (!byId(id).hasBook(book.id)) continue;

            final text = books[book.id] ??= await source.loadBook(id, book.id);

            if (!(text.chapter(p.startChapter)?.hasVerse(p.startVerse) ??
                false)) {
              missing.add(p.book);

              expect(
                of(id, book.id, p.startChapter)[p.startVerse],
                anyOf(isNull, isNot(isEmpty)),
              );
            }
          }

          expect(missing, {"Num", "Est", "Dan"}, reason: id);
        }
      },
    );

    test("Mehrere Stellen, gleiche und verschiedene Titel am selben Vers, "
        "Überschneidungen", () {
      final own = PericopeHeadings.fromPerikopen([
        // Eine Perikope mit zwei Stellen: Titel an beiden.
        perikope("Die Nachkommen Abrahams", "Gen", 25, 1, 18, id: "a"),
        perikope("Die Nachkommen Abrahams", "1Chr", 1, 28, 34, id: "a"),
        // Derselbe Titel doppelt am selben Vers: nur einmal.
        perikope("Die Nachkommen Abrahams", "Gen", 25, 1, 6, id: "b"),
        // Ein anderer Titel am selben Vers: beide, in Listenreihenfolge.
        perikope("Abrahams Tod", "Gen", 25, 1, 11, id: "c"),
        // Überschneidung: beginnt mitten in der ersten Perikope.
        perikope("Ismaels Nachkommen", "Gen", 25, 12, 18, id: "d"),
        // Über die Kapitelgrenze: nur am Anfang.
        perikope("Jakob und Esau", "Gen", 25, 19, 5, id: "e", endChapter: 26),
        // Kapitelfrage und unbekanntes Buch: keine Überschrift.
        perikope("Gen 25", "Gen", 25, 1, 34, id: "f"),
        perikope("Fremd", "Evangelium", 1, 1, 2, id: "g"),
      ]);

      Map<int, List<String>> at(String book, int chapter) => own.forChapter(
        translation: byId("deuelbbk"),
        translations: translations,
        bookId: book,
        chapter: chapter,
      );

      expect(at("GEN", 25), {
        1: ["Die Nachkommen Abrahams", "Abrahams Tod"],
        12: ["Ismaels Nachkommen"],
        19: ["Jakob und Esau"],
      });
      expect(at("GEN", 26), isEmpty);
      expect(at("1CH", 1), {
        28: ["Die Nachkommen Abrahams"],
      });
    });

    test("Die JSON bleibt unverändert die einzige Quelle", () {
      // Überschriften der Ausgaben fließen nicht ein: Die Textbibel hat
      // eigene Zwischenüberschriften, die Zuordnung ist trotzdem dieselbe.
      expect(of("deutkw", "MRK", 4), of("deuelbbk", "MRK", 4));
      expect(of("grcsbl", "MRK", 4), of("deuelbbk", "MRK", 4));
      expect(of("latVUC", "MRK", 4), of("deuelbbk", "MRK", 4));
    });
  });

  group("Abweichende Zählung", () {
    test("Neues Testament: in jeder Ausgabe dieselben Überschriften", () {
      for (final t in translations) {
        if (!t.hasBook("JHN")) continue;

        expect(of(t.id, "JHN", 3), of("deuelbbk", "JHN", 3), reason: t.id);
        expect(of(t.id, "JHN", 3), isNotEmpty);
      }
    });

    test("Gleich gezählte Kapitel des Alten Testaments werden "
        "übernommen", () {
      for (final id in ["deu1912", "deu1951", "engwebp", "eng-asv", "latVUC"]) {
        expect(of(id, "GEN", 1), of("deuelbbk", "GEN", 1), reason: id);
        expect(of(id, "GEN", 1), isNotEmpty);
      }
    });

    test("Anders gezählte Kapitel erhalten keine Überschriften", () {
      // Joel: 4 Kapitel in deutscher, 3 in englischer Zählung.
      expect(of("deuelbbk", "JOL", 3), isNotEmpty);
      expect(of("deu1912", "JOL", 3), isEmpty);
      expect(of("deu1912", "JOL", 1), isEmpty);
      expect(headings.hasAny("JOL", 3), isTrue);

      // Maleachi: 3 bzw. 4 Kapitel.
      expect(of("engwebp", "MAL", 3), isEmpty);

      // Septuaginta und Vulgata zählen die Psalmen durchgehend anders.
      expect(of("grcbrent", "PSA", 23), isEmpty);
      expect(of("latVUC", "PSA", 23), isEmpty);
      expect(of("grcbrent", "JER", 31), isEmpty);

      // Ohne deutsch gezählte Vergleichsausgabe (Apokryphen): nichts.
      expect(headings.hasAny("SIR", 1), isTrue);
      expect(of("latVUC", "SIR", 1), isEmpty);

      // Buch fehlt in der Ausgabe.
      expect(of("grcsbl", "GEN", 1), isEmpty);
    });

    test("Englisch gezählte Psalmen: nur der Psalmanfang ist sicher", () {
      // Psalm 51: 21 Verse deutsch, 19 englisch (Überschrift in Vers 1).
      expect(of("deuelbbk", "PSA", 51).keys, [1]);
      expect(of("deu1912", "PSA", 51), of("deuelbbk", "PSA", 51));

      // Psalm 23 ist gleich gezählt.
      expect(of("deu1912", "PSA", 23), of("deuelbbk", "PSA", 23));
    });

    test("Die Standardausgabe zeigt die Überschriften in fast allen "
        "Kapiteln des Quiz", () {
      int shown = 0;
      int total = 0;

      for (final p in list) {
        final book = BibleBooks.byAbbreviation(p.book)!;

        if (!byId("deu1912").hasBook(book.id)) continue;
        if (of("deuelbbk", book.id, p.startChapter)[p.startVerse] == null) {
          continue;
        }

        total++;

        if (of("deu1912", book.id, p.startChapter)[p.startVerse] != null) {
          shown++;
        }
      }

      expect(shown / total, greaterThan(0.9), reason: "$shown von $total");
    });
  });

  group("Darstellung", () {
    Future<void> pumpReader(
      WidgetTester tester, {
      List<BiblePassage> passages = const [],
      String? title,
      PericopeHeadings? own,
      Size size = const Size(420, 3000),
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
            repository: BibleRepository(source: source),
            pericopeHeadings: own ?? headings,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Der dargestellte Text aller Absätze des Kapitels.
    String chapterText(WidgetTester tester) {
      return tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(BibleChapterView),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.textSpan?.toPlainText() ?? t.data ?? "")
          .join("\n");
    }

    testWidgets("Mehrere Perikopen eines Kapitels: jede Überschrift einmal, "
        "gekennzeichnet und vor ihrem Abschnitt", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "MRK|4|0"});

      await pumpReader(tester);

      expect(find.text(PericopeHeadings.label), findsNWidgets(8));

      for (final title in of("deu1912", "MRK", 4).values.expand((t) => t)) {
        expect(find.text(title), findsOneWidget, reason: title);
      }

      // Reihenfolge: Überschrift, dann der Vers, mit dem die Perikope
      // beginnt; der Vers davor steht darüber.
      final heading = tester.getTopLeft(find.text("Der Sturm auf dem See")).dy;
      final before = tester
          .getTopLeft(find.textContaining("Und ohne Gleichnis redete er"))
          .dy;
      final first = tester
          .getTopLeft(find.textContaining("Laßt uns hinüberfahren"))
          .dy;

      expect(before, lessThan(heading));
      expect(heading, lessThan(first));

      // Der Vers, mit dem die Perikope beginnt, eröffnet einen Absatz.
      final paragraph = tester.widget<Text>(
        find.textContaining("Laßt uns hinüberfahren"),
      );

      expect(paragraph.textSpan!.toPlainText(), startsWith("35 "));

      expect(
        tester.widget<Text>(key("bible-pericope-note")).data,
        PericopeHeadings.explanation,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("Der Bibeltext bleibt unverändert", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "MRK|4|0"});

      await pumpReader(tester, own: PericopeHeadings.empty);

      final without = chapterText(tester);

      expect(find.text(PericopeHeadings.label), findsNothing);
      expect(key("bible-pericope-note"), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pumpReader(tester);

      final withHeadings = chapterText(tester);

      // Dieselben Wörter in derselben Reihenfolge, wenn man Überschriften
      // und Beschriftung wieder herausnimmt.
      String words(String text) => text.replaceAll(RegExp(r'\s+'), " ").trim();

      String stripped = withHeadings;

      for (final title in [
        PericopeHeadings.label,
        ...of("deu1912", "MRK", 4).values.expand((t) => t),
      ]) {
        stripped = stripped.replaceAll(title, " ");
      }

      expect(words(stripped), words(without));

      // Jeder Vers der Ausgabe steht wörtlich da.
      final chapter = (await source.loadBook("deu1912", "MRK")).chapter(4)!;

      for (final verse in chapter.verses) {
        expect(
          withHeadings,
          contains(verse.text),
          reason: "V. ${verse.number}",
        );
      }
    });

    testWidgets("Gleiche Überschriften in jeder Ausgabe, auch ohne eigene "
        "Zwischenüberschriften der Ausgabe", (tester) async {
      for (final t in translations) {
        if (!t.hasBook("MRK")) continue;

        SharedPreferences.setMockInitialValues({
          "bible_translation": t.id,
          "bible_position": "MRK|4|0",
        });

        await pumpReader(tester);

        expect(
          find.text("Der Sturm auf dem See"),
          findsOneWidget,
          reason: t.id,
        );
        expect(
          find.text(PericopeHeadings.label),
          findsNWidgets(8),
          reason: t.id,
        );
        expect(tester.takeException(), isNull, reason: t.id);

        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets("Mehrere Titel am selben Vers: eine Kennzeichnung, kein "
        "doppelter Titel", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "GEN|25|0"});

      await pumpReader(
        tester,
        own: PericopeHeadings.fromPerikopen([
          perikope("Die Nachkommen Abrahams", "Gen", 25, 1, 18, id: "a"),
          perikope("Die Nachkommen Abrahams", "Gen", 25, 1, 6, id: "b"),
          perikope("Abrahams Tod", "Gen", 25, 1, 11, id: "c"),
          perikope("Ismaels Nachkommen", "Gen", 25, 12, 18, id: "d"),
        ]),
      );

      expect(find.text("Die Nachkommen Abrahams"), findsOneWidget);
      expect(find.text("Abrahams Tod"), findsOneWidget);
      expect(find.text("Ismaels Nachkommen"), findsOneWidget);
      expect(find.text(PericopeHeadings.label), findsNWidgets(2));
    });

    testWidgets("Anders gezähltes Kapitel: keine Überschrift, aber ein "
        "Hinweis", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "JOL|3|0"});

      await pumpReader(tester);

      expect(find.text(PericopeHeadings.label), findsNothing);
      expect(
        tester.widget<Text>(key("bible-pericope-note")).data,
        contains("nicht angezeigt"),
      );

      // Dieselbe Stelle in deutscher Zählung zeigt die Überschrift.
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({
        "bible_translation": "deuelbbk",
        "bible_position": "JOL|3|0",
      });
      await pumpReader(tester);

      expect(find.text("Die Ausgießung des Geistes"), findsOneWidget);
    });

    testWidgets("Hervorhebung, Sprung zum Vers und Blättern bleiben "
        "erhalten", (tester) async {
      await pumpReader(
        tester,
        size: const Size(420, 700),
        title: "Der Sturm auf dem See",
        passages: const [
          BiblePassage(
            label: "Mk 4,35-41",
            reference: BibleReference(
              bookId: "MRK",
              chapter: 4,
              verse: 35,
              endVerse: 41,
            ),
          ),
        ],
      );

      // Die Perikope steht oben im Fenster, ihre Überschrift im Text
      // unmittelbar davor – zusätzlich zur Leiste des Quiz.
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );

      expect(scroll.position.pixels, greaterThan(500));

      final verse = tester.getTopLeft(
        find.textContaining("Laßt uns hinüberfahren"),
      );

      expect(verse.dy, inInclusiveRange(0, 700));

      bool highlighted = false;

      tester
          .widget<Text>(find.textContaining("Laßt uns hinüberfahren"))
          .textSpan!
          .visitChildren((span) {
            if (span is TextSpan &&
                (span.text ?? "").contains("Laßt uns") &&
                span.style?.backgroundColor != null) {
              highlighted = true;
            }

            return true;
          });

      expect(highlighted, isTrue);

      await tester.tap(key("bible-next-chapter"));
      await tester.pumpAndSettle();

      expect(find.text("Markus 5"), findsOneWidget);
      expect(find.text("Die Heilung des Besessenen von Gerasa"), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Schmales Display: lange Überschrift ohne Overflow", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"bible_position": "MRK|4|0"});

      await pumpReader(tester, size: const Size(320, 3000));

      expect(tester.takeException(), isNull);
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

    testWidgets("Aus dem Quiz geöffnet steht die Überschrift der Perikope "
        "im Text vor ihren Versen", (tester) async {
      tester.view.physicalSize = const Size(420, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuizScreen(
            perikopen: [perikope("Der Sturm auf dem See", "Mk", 4, 35, 41)],
            uid: null,
            settingsService: FakeSettingsService(),
            learningService: FakeLearningService(),
            bibleRepository: BibleRepository(source: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, "Mk 4");
      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      await tester.ensureVisible(key("read-passage"));
      await tester.tap(key("read-passage"));
      await tester.pumpAndSettle();

      expect(find.byType(BibleReaderScreen), findsOneWidget);

      // Im Text (gekennzeichnet) und in der Leiste des Quiz.
      final inText = find.descendant(
        of: find.byType(BibleChapterView),
        matching: find.text("Der Sturm auf dem See"),
      );

      expect(inText, findsOneWidget);
      expect(find.text(PericopeHeadings.label), findsOneWidget);
      expect(
        tester.getTopLeft(inText).dy,
        lessThan(
          tester.getTopLeft(find.textContaining("Laßt uns hinüberfahren")).dy,
        ),
      );
    });
  });
}
