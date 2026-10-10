import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/bible_text.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';
import 'package:theologie_lernapp/services/bible/bible_reference_parser.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/pericope_headings.dart';
import 'package:theologie_lernapp/services/bible/versification_map.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/bible/bible_chapter_view.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

const List<String> englishEditions = [
  "deu1912",
  "deu1951",
  "engwebp",
  "eng-asv",
];

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

  ({int chapter, int verse})? locate(
    String translation,
    String book,
    int chapter,
    int verse,
  ) {
    return ListVersification.locate(
      translation: byId(translation),
      translations: translations,
      bookId: book,
      chapter: chapter,
      verse: verse,
    );
  }

  BibleReference? convert(String translation, BibleReference reference) {
    return ListVersification.convert(
      reference,
      translation: byId(translation),
      translations: translations,
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

  group("Tabelle der englischen Zählung", () {
    test("Stimmt mit den Angaben überein, die die Lutherbibel 1912 selbst "
        "im Text führt", () async {
      // Die Quelle stellt Versen, die sie anders zählt, die deutsche
      // Zählung voran: „[32:1] Des Morgens aber …“ steht bei 31,55.
      final marker = RegExp(r'^\[(\d+):(\d+)\]');

      // Abweichungen der Quelle selbst: drei offensichtliche Schreibfehler
      // und der Dekalog, den Luther in 5. Mose 5 mit 30 statt 33 Versen
      // zählt (keine verschobene Kapitelgrenze).
      const deviations = {"GEN 32:32", "EXO 8:32", "JOB 41:9"};

      int checked = 0;

      for (final info in byId("deu1912").books) {
        final book = BibleBooks.byId(info.id)!;

        if (book.testament != BibleTestament.old || info.id == "PSA") continue;

        final text = await source.loadBook("deu1912", info.id);

        for (final chapter in text.chapters) {
          for (final verse in chapter.verses) {
            final match = marker.firstMatch(verse.text);

            final place = "${info.id} ${chapter.number}:${verse.number}";

            if (match == null ||
                deviations.contains(place) ||
                (info.id == "DEU" && chapter.number == 5)) {
              continue;
            }

            expect(
              ListVersification.germanToEnglish(
                info.id,
                int.parse(match.group(1)!),
                int.parse(match.group(2)!),
              ),
              (chapter: chapter.number, verse: verse.number),
              reason: "$place ${match.group(0)}",
            );

            checked++;
          }
        }
      }

      expect(checked, greaterThan(330));
    });

    test("Jeder Vers der deutschen Zählung findet in den englisch "
        "gezählten Ausgaben seinen Platz", () {
      final german = byId("deuelbbk");

      for (final id in englishEditions) {
        final edition = byId(id);

        final unsure = <String>{};

        for (final info in german.books) {
          if (BibleBooks.byId(info.id)!.testament != BibleTestament.old ||
              info.id == "PSA") {
            continue;
          }

          final reached = <(int, int)>{};

          for (int c = 1; c <= info.chapterCount; c++) {
            for (int v = 1; v <= info.verseCount(c); v++) {
              final target = locate(id, info.id, c, v);

              if (target == null) {
                unsure.add("${info.id} $c");
                continue;
              }

              expect(
                target.verse,
                inInclusiveRange(
                  1,
                  edition.book(info.id)!.verseCount(target.chapter),
                ),
                reason: "$id ${info.id} $c,$v",
              );

              reached.add((target.chapter, target.verse));
            }
          }

          // Umgekehrt ist jeder Vers der Ausgabe erreicht – bis auf Jes
          // 64,1, die zweite Hälfte von Jes 63,19 der deutschen Zählung.
          final book = edition.book(info.id)!;

          for (int c = 1; c <= book.chapterCount; c++) {
            if (unsure.contains("${info.id} $c")) continue;

            for (int v = 1; v <= book.verseCount(c); v++) {
              if (info.id == "ISA" && c == 64 && v == 1) continue;

              expect(reached, contains((c, v)), reason: "$id ${info.id} $c:$v");
            }
          }
        }

        // Neh 7 zählen die Ausgaben selbst verschieden (72 bzw. 73 Verse):
        // nicht sicher übertragbar, also keine Zuordnung.
        expect(unsure, {"NEH 7"}, reason: id);
      }
    });

    test("Stellen: verschobene Kapitelgrenzen, deutsche Ausgaben, Neues "
        "Testament, Psalmen", () {
      const kampf = BibleReference(
        bookId: "GEN",
        chapter: 32,
        verse: 23,
        endVerse: 33,
      );

      expect(
        convert("deu1912", kampf),
        const BibleReference(
          bookId: "GEN",
          chapter: 32,
          verse: 22,
          endVerse: 32,
        ),
      );

      // Deutsche Zählung und Neues Testament: unverändert.
      expect(convert("deuelbbk", kampf), same(kampf));
      expect(convert("deutkw", kampf), same(kampf));

      const sturm = BibleReference(
        bookId: "MRK",
        chapter: 4,
        verse: 35,
        endVerse: 41,
      );

      for (final t in translations) {
        if (t.hasBook("MRK")) expect(convert(t.id, sturm), same(sturm));
      }

      // Über die Kapitelgrenze: 31,1–32,1 ist englisch das ganze Kapitel 31.
      expect(
        convert(
          "deu1951",
          const BibleReference(
            bookId: "GEN",
            chapter: 31,
            verse: 1,
            endChapter: 32,
            endVerse: 1,
          ),
        ),
        const BibleReference(
          bookId: "GEN",
          chapter: 31,
          verse: 1,
          endVerse: 55,
        ),
      );

      // Joel 3 der deutschen Zählung steht englisch in Kapitel 2.
      expect(
        convert(
          "engwebp",
          const BibleReference(
            bookId: "JOL",
            chapter: 3,
            verse: 1,
            endVerse: 5,
          ),
        ),
        const BibleReference(
          bookId: "JOL",
          chapter: 2,
          verse: 28,
          endVerse: 32,
        ),
      );

      // Nicht sicher übertragbar: Psalmverse, Septuaginta, Kapitelangaben.
      expect(
        convert(
          "deu1912",
          const BibleReference(
            bookId: "PSA",
            chapter: 51,
            verse: 3,
            endVerse: 21,
          ),
        ),
        isNull,
      );
      expect(
        convert(
          "grcbrent",
          const BibleReference(
            bookId: "JER",
            chapter: 31,
            verse: 31,
            endVerse: 34,
          ),
        ),
        isNull,
      );
      expect(
        convert("deu1912", const BibleReference.chapter("JOL", 3)),
        isNull,
      );
    });
  });

  group("Perikopenüberschriften in englisch gezählten Ausgaben", () {
    test("1. Mose 31–32: an denselben Versen wie in deutscher Zählung", () {
      expect(of("deuelbbk", "GEN", 32), {
        1: ["Die Boten und Geschenke für Esau"],
        23: ["Jakobs Kampf mit Gott"],
      });

      for (final id in englishEditions) {
        // 32,1 der Liste ist dort der letzte Vers von Kapitel 31.
        expect(of(id, "GEN", 31)[55], [
          "Die Boten und Geschenke für Esau",
        ], reason: id);
        expect(of(id, "GEN", 31).keys, [1, 55], reason: id);

        expect(of(id, "GEN", 32), {
          22: ["Jakobs Kampf mit Gott"],
        }, reason: id);
      }
    });

    test("Joel und Maleachi: andere Kapitelzahl", () {
      for (final id in englishEditions) {
        expect(of(id, "JOL", 2)[28], ["Die Ausgießung des Geistes"]);
        expect(of(id, "JOL", 3), {
          1: ["Das Gericht über die Völker"],
        });
        expect(of(id, "JOL", 1), of("deuelbbk", "JOL", 1));

        // Mal 3,23 der Liste ist Mal 4,5.
        expect(of(id, "MAL", 4), {
          5: ["Der Wegbereiter"],
        });
        expect(of(id, "MAL", 3).keys, [13]);
      }
    });

    test("Keine Perikope des Alten Testaments geht außerhalb der Psalmen "
        "verloren", () {
      for (final id in englishEditions) {
        final lost = <String>{};

        for (final p in list) {
          final book = BibleBooks.byAbbreviation(p.book)!;

          if (book.testament != BibleTestament.old || book.id == "PSA") {
            continue;
          }

          final titles = of("deuelbbk", book.id, p.startChapter)[p.startVerse];

          // In deutscher Zählung keine Überschrift (Kapitelfrage, Zusätze).
          if (titles == null || !titles.contains(p.title)) continue;

          final target = locate(id, book.id, p.startChapter, p.startVerse);

          if (target == null ||
              !(of(id, book.id, target.chapter)[target.verse] ?? const [])
                  .contains(p.title)) {
            lost.add("${p.book} ${p.startChapter}");
          }
        }

        // Neh 7 zählen die Ausgaben verschieden (siehe oben).
        expect(lost, {"Neh 7"}, reason: id);
      }
    });

    test("Zusätze zu Daniel stehen nicht an gleich nummerierten Versen "
        "eines anderen Textes", () {
      // Dan 3,24–50 der Liste ist das Gebet des Asarja; in Ausgaben ohne
      // die Zusätze ist 3,24 das Erstaunen Nebukadnezzars.
      for (final id in ["deuelbbk", "deutkw", "deu1912"]) {
        expect(
          of(id, "DAN", 3).values.expand((t) => t),
          isNot(contains("Das Gebet des Asarja")),
          reason: id,
        );
        expect(of(id, "DAN", 3)[1], isNotNull, reason: id);
      }
    });
  });

  group("Reader", () {
    Future<void> pumpReader(
      WidgetTester tester, {
      required List<BiblePassage> passages,
      String? title,
    }) async {
      tester.view.physicalSize = const Size(600, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleReaderScreen(
            passages: passages,
            passageTitle: title,
            repository: BibleRepository(source: source),
            pericopeHeadings: headings,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<String> verseText(
      String translation,
      String book,
      int chapter,
      int verse,
    ) async {
      final text = await source.loadBook(translation, book);

      return text
          .chapter(chapter)!
          .verses
          .firstWhere((v) => v.number == verse)
          .text;
    }

    /// Senkrechte Lage des Absatzes, der [text] enthält.
    double topOf(WidgetTester tester, String text) =>
        tester.getTopLeft(find.textContaining(text)).dy;

    final kampf = BiblePassage(
      label: "Gen 32,23-33",
      reference: BibleReferenceParser.parse("Gen 32,23-33")!,
    );

    testWidgets("Lutherbibel 1912: Die Perikope ist an ihren Versen "
        "hervorgehoben, die Überschrift steht davor, die Versnummern sind "
        "die der Ausgabe", (tester) async {
      // Verse der Ausgabe: 32,21 gehört noch zur vorigen Perikope, 32,22
      // (deutsch 32,23) eröffnet „Jakobs Kampf mit Gott“.
      final before = await tester.runAsync(
        () => verseText("deu1912", "GEN", 32, 21),
      );
      final first = await tester.runAsync(
        () => verseText("deu1912", "GEN", 32, 22),
      );
      final last = await tester.runAsync(
        () => verseText("deu1912", "GEN", 32, 32),
      );

      await pumpReader(tester, passages: [kampf], title: "Jakobs Kampf");

      expect(find.text("1. Mose 32"), findsOneWidget);

      expect(isHighlighted(tester, first!), isTrue);
      expect(isHighlighted(tester, last!), isTrue);
      expect(isHighlighted(tester, before!), isFalse);

      // Die Überschrift steht im Text zwischen Vers 21 und 22.
      final heading = find.descendant(
        of: find.byType(BibleChapterView),
        matching: find.text("Jakobs Kampf mit Gott"),
      );

      expect(heading, findsOneWidget);
      expect(topOf(tester, before), lessThan(tester.getTopLeft(heading).dy));
      expect(tester.getTopLeft(heading).dy, lessThan(topOf(tester, first)));

      // Die Versnummer bleibt die der Ausgabe (dahinter ein geschütztes
      // Leerzeichen); der Wortlaut samt der Angabe der Quelle zur deutschen
      // Zählung ist unverändert.
      final paragraph = tester
          .widget<Text>(find.textContaining(first))
          .textSpan!
          .toPlainText();

      expect(paragraph, startsWith("22 [32:23] "));

      // Die Leiste nennt die Stelle der Liste und sagt, wo sie hier steht.
      expect(find.text("Gen 32,23-33"), findsOneWidget);
      expect(
        tester.widget<Text>(key("bible-passage-hint")).data,
        contains("Gen 32,22–32"),
      );

      // Überschriften werden gezeigt, nicht als „anders gezählt“ weggelassen.
      expect(
        tester.widget<Text>(key("bible-pericope-note")).data,
        PericopeHeadings.explanation,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("Deutsch gezählte Ausgabe: unverändert, ohne Hinweis", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"bible_translation": "deuelbbk"});

      final before = await tester.runAsync(
        () => verseText("deuelbbk", "GEN", 32, 22),
      );
      final first = await tester.runAsync(
        () => verseText("deuelbbk", "GEN", 32, 23),
      );

      await pumpReader(tester, passages: [kampf]);

      expect(isHighlighted(tester, first!), isTrue);
      expect(isHighlighted(tester, before!), isFalse);
      expect(key("bible-passage-hint"), findsNothing);

      expect(
        tester.widget<Text>(find.textContaining(first)).textSpan!.toPlainText(),
        startsWith("23 "),
      );
    });

    testWidgets("Der frühere Fehlerfall 1. Mose 31/32: Der Vers an der "
        "Kapitelgrenze fehlt nicht, die Überschriften stehen in beiden "
        "Kapiteln", (tester) async {
      // Deutsch 31,1–54 und 32,1–22; in der Lutherbibel 1912 ist 32,1 der
      // Vers 31,55. Früher blieben beide Kapitel ohne Überschriften.
      final laban = BibleReferenceParser.passageOf(
        list.firstWhere((p) => p.id == "jakobs_trennung_von_laban"),
      )!;
      final boten = BibleReferenceParser.passageOf(
        list.firstWhere((p) => p.id == "die_boten_und_geschenke_fuer_esau"),
      )!;

      final lastOfLaban = await tester.runAsync(
        () => verseText("deu1912", "GEN", 31, 54),
      );
      final boundary = await tester.runAsync(
        () => verseText("deu1912", "GEN", 31, 55),
      );

      await pumpReader(tester, passages: [laban, boten]);

      expect(find.text("1. Mose 31"), findsOneWidget);
      expect(find.text(PericopeHeadings.label), findsNWidgets(2));
      expect(isHighlighted(tester, lastOfLaban!), isTrue);
      expect(isHighlighted(tester, boundary!), isFalse);
      expect(key("bible-passage-hint"), findsNothing);

      // Die nächste Perikope beginnt mit dem Vers an der Kapitelgrenze.
      await tester.tap(key("bible-passage-1"));
      await tester.pumpAndSettle();

      expect(find.text("1. Mose 31"), findsOneWidget);
      expect(isHighlighted(tester, boundary), isTrue);
      expect(isHighlighted(tester, lastOfLaban), isFalse);

      final heading = find.descendant(
        of: find.byType(BibleChapterView),
        matching: find.text("Die Boten und Geschenke für Esau"),
      );

      expect(heading, findsOneWidget);
      expect(
        topOf(tester, lastOfLaban),
        lessThan(tester.getTopLeft(heading).dy),
      );
      expect(tester.getTopLeft(heading).dy, lessThan(topOf(tester, boundary)));

      // … und setzt sich im nächsten Kapitel fort.
      await tester.tap(key("bible-next-chapter"));
      await tester.pumpAndSettle();

      expect(find.text("1. Mose 32"), findsOneWidget);
      expect(find.text("Jakobs Kampf mit Gott"), findsOneWidget);
      expect(
        isHighlighted(
          tester,
          (await tester.runAsync(() => verseText("deu1912", "GEN", 32, 21)))!,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("Wechsel der Ausgabe schlägt die Perikope in der neuen "
        "Zählung auf", (tester) async {
      final english = await tester.runAsync(
        () => verseText("deu1912", "JOL", 2, 28),
      );
      final german = await tester.runAsync(
        () => verseText("deuelbbk", "JOL", 3, 1),
      );

      await pumpReader(
        tester,
        passages: [
          BiblePassage(
            label: "Joel 3,1-5",
            reference: BibleReferenceParser.parse("Joel 3,1-5")!,
          ),
        ],
      );

      expect(find.text("Joel 2"), findsOneWidget);
      expect(isHighlighted(tester, english!), isTrue);
      expect(find.text("Die Ausgießung des Geistes"), findsOneWidget);

      await tester.tap(key("bible-translation-button"));
      await tester.pumpAndSettle();
      await tester.tap(key("bible-translation-deuelbbk"));
      await tester.pumpAndSettle();

      expect(find.text("Joel 3"), findsOneWidget);
      expect(isHighlighted(tester, german!), isTrue);
      expect(find.text("Die Ausgießung des Geistes"), findsOneWidget);
      expect(key("bible-passage-hint"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Eine Perikope mit ungültiger Stelle beschädigt das Kapitel "
        "nicht", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "GEN|31|0"});

      tester.view.physicalSize = const Size(600, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Perikope p(String title, int from, int to) => Perikope(
        id: title,
        title: title,
        book: "Gen",
        startChapter: 31,
        startVerse: from,
        endChapter: 31,
        endVerse: to,
        required: true,
        precision: "chapter",
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleReaderScreen(
            repository: BibleRepository(source: source),
            pericopeHeadings: PericopeHeadings.fromPerikopen([
              p("Gültig", 1, 21),
              // Endet hinter dem Kapitel bzw. beginnt dahinter.
              p("Zu lang", 22, 99),
              p("Außerhalb", 80, 90),
              p("Danach", 43, 54),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Gültig"), findsOneWidget);
      expect(find.text("Danach"), findsOneWidget);
      expect(find.text("Zu lang"), findsNothing);
      expect(find.text("Außerhalb"), findsNothing);

      // Alle Verse des Kapitels stehen in ihrer Reihenfolge da.
      final chapter = await tester.runAsync(
        () async => (await source.loadBook("deu1912", "GEN")).chapter(31)!,
      );

      final shown = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(BibleChapterView),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.textSpan?.toPlainText() ?? "")
          .join("\n");

      int position = -1;

      for (final BibleVerse verse in chapter!.verses) {
        final next = shown.indexOf("${verse.number} ${verse.text}");

        expect(next, greaterThan(position), reason: "V. ${verse.number}");

        position = next;
      }

      expect(tester.takeException(), isNull);
    });
  });
}
