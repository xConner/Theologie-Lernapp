import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/bible_text.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';
import 'package:theologie_lernapp/services/bible/bible_reader_settings.dart';
import 'package:theologie_lernapp/services/bible/bible_reference_parser.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_search.dart';
import 'package:theologie_lernapp/services/bible/bible_search_folding.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';

import 'test_asset_bundle.dart';

/// Zählt, wie oft Bücher von der Quelle gelesen werden.
class CountingSource implements BibleTextSource {
  final BibleTextSource inner;

  int loads = 0;

  CountingSource(this.inner);

  @override
  Future<List<BibleTranslation>> loadTranslations() => inner.loadTranslations();

  @override
  Future<BibleBookText> loadBook(String translationId, String bookId) {
    loads++;

    return inner.loadBook(translationId, bookId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = AssetBibleTextSource(bundle: FileAssetBundle());

  late List<BibleTranslation> translations;

  BibleTranslation byId(String id) =>
      translations.firstWhere((t) => t.id == id);

  setUpAll(() async {
    translations = await source.loadTranslations();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("Textbestand", () {
    test("Die vorgesehenen Ausgaben sind vorhanden und nach Sprache "
        "gruppierbar", () {
      expect(
        translations.map((t) => t.id),
        containsAll(["deu1912", "deu1951", "deuelbbk", "grcsbl", "latVUC"]),
      );

      // Standard ist die Lutherbibel 1912.
      expect(translations.first.id, "deu1912");

      final groups = BibleLanguages.group(translations);

      expect(groups.keys.toList(), ["de", "en", "grc", "la"]);
      expect(groups["en"]!.length, 2);
    });

    test("Jede Ausgabe nennt Edition, Quelle, Lizenz und Copyright", () {
      for (final t in translations) {
        expect(t.edition, isNotEmpty, reason: t.id);
        expect(t.sourceUrl, startsWith("https://"), reason: t.id);
        expect(t.licenseType, isNotEmpty, reason: t.id);
        expect(t.licenseNotice, isNotEmpty, reason: t.id);
        expect(t.copyright, isNotEmpty, reason: t.id);

        // Der Lizenzhinweis der Quelle liegt im Projekt.
        expect(
          File("docs/bible-sources/${t.id}-copr.htm").existsSync(),
          isTrue,
          reason: t.id,
        );
      }

      final elb = byId("deuelbbk");

      expect(elb.licenseType, "CC BY-NC-ND 4.0");
      expect(elb.restrictions.join(" "), contains("nichtkommerzielle"));
      expect(elb.restrictions.join(" "), contains("Keine Bearbeitungen"));
    });

    test("pubspec.yaml liefert jede Ausgabe des Verzeichnisses aus", () {
      final pubspec = File("pubspec.yaml").readAsStringSync();

      expect(pubspec, contains("- assets/bible/translations.json"));

      for (final t in translations) {
        expect(pubspec, contains("- assets/bible/${t.id}/"), reason: t.id);
      }
    });

    test("Alle Bücher sind vollständig: Kapitel und Verse wie im "
        "Verzeichnis, Reihenfolge kanonisch", () async {
      for (final t in translations) {
        int verses = 0;
        int previous = -1;

        for (final info in t.books) {
          expect(BibleBooks.byId(info.id), isNotNull, reason: info.id);

          final order = BibleBooks.order(info.id);

          expect(order, greaterThan(previous), reason: "${t.id} ${info.id}");
          previous = order;

          final book = await source.loadBook(t.id, info.id);

          expect(book.bookId, info.id);
          expect(
            book.chapters.length,
            info.chapterCount,
            reason: "${t.id} ${info.id}",
          );

          for (final chapter in book.chapters) {
            final where = "${t.id} ${info.id} ${chapter.number}";

            int highest = 0;

            for (final verse in chapter.verses) {
              if (verse.number > highest) highest = verse.number;

              expect(verse.number, greaterThan(0), reason: where);
              expect(verse.text.contains("\\"), isFalse, reason: where);

              for (final note in verse.notes) {
                expect(note.offset, inInclusiveRange(0, verse.text.length));
                expect(note.text, isNotEmpty);
              }

              if (!verse.continuation) verses++;
            }

            expect(highest, info.verseCount(chapter.number), reason: where);
          }
        }

        // 66 Bücher haben über 31 000 Verse, das NT allein knapp 8 000.
        expect(
          verses,
          greaterThan(t.books.length >= 66 ? 31000 : 7900),
          reason: t.id,
        );
      }
    });

    test("Protestantischer Kanon: 66 Bücher mit 1189 Kapiteln", () {
      for (final id in [
        "deu1912",
        "deu1951",
        "deuelbbk",
        "deutkw",
        "engwebp",
        "eng-asv",
      ]) {
        final t = byId(id);

        expect(t.books.length, 66, reason: id);
        expect(
          t.books.fold<int>(0, (sum, b) => sum + b.chapterCount),
          1189,
          reason: id,
        );
        expect(t.books.first.id, "GEN");
        expect(t.books.last.id, "REV");
      }

      // Der Tippfehler „Chonik“ im Buchtitel der Quelldatei ist berichtigt
      // und als Abweichung ausgewiesen.
      expect(byId("deu1912").book("1CH")!.name, "1. Chronik");
      expect(byId("deu1912").deviations.join(" "), contains("Chonik"));
      expect(byId("latVUC").deviations.join(" "), contains("Glossa"));

      expect(byId("grcsbl").books.length, 27);
      expect(byId("grcsbl").books.first.id, "MAT");
      expect(byId("latVUC").hasBook("SIR"), isTrue);
      expect(byId("grcbrent").hasBook("MAT"), isFalse);
    });

    test("Wortlaut, Zeichensetzung und griechische Zeichen bleiben "
        "erhalten", () async {
      Future<String> verse(String t, String book, int chapter, int v) async {
        final text = await source.loadBook(t, book);

        return text
            .chapter(chapter)!
            .verses
            .firstWhere((x) => x.number == v)
            .text;
      }

      expect(
        await verse("deu1912", "JHN", 3, 16),
        "Also hat Gott die Welt geliebt, daß er seinen eingeborenen Sohn "
        "gab, auf daß alle, die an ihn glauben, nicht verloren werden, "
        "sondern das ewige Leben haben.",
      );
      expect(
        await verse("deu1951", "GEN", 1, 1),
        "Im Anfang schuf Gott den Himmel und die Erde.",
      );
      expect(
        await verse("deuelbbk", "GEN", 1, 14),
        contains("zu Zeichen und zur Bestimmung von Zeiten"),
      );
      expect(
        await verse("engwebp", "JHN", 1, 1),
        "In the beginning was the Word, and the Word was with God, and the "
        "Word was God.",
      );
      expect(
        await verse("grcsbl", "JHN", 1, 1),
        "Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν, καὶ θεὸς ἦν ὁ "
        "λόγος.",
      );
      expect(
        await verse("grcbrent", "GEN", 1, 1),
        "ἘΝ ἀρχῇ ἐποίησεν ὁ Θεὸς τὸν οὐρανὸν καὶ τὴν γῆν.",
      );
      expect(
        await verse("latVUC", "GEN", 1, 1),
        "In principio creavit Deus cælum et terram.",
      );
    });

    test("Fußnoten, Überschriften und Zeilenumbrüche der Quelle", () async {
      final elb = (await source.loadBook("deuelbbk", "GEN")).chapter(1)!;

      final first = elb.verses.first;

      expect(first.breakBefore, BibleBreak.paragraph);
      expect(first.notes.single.text, contains("Mehrzahl"));
      expect(
        first.text.substring(0, first.notes.single.offset),
        endsWith("Himmel"),
      );

      final tkw = (await source.loadBook("deutkw", "GEN")).chapter(1)!;

      expect(tkw.items.first, isA<BibleHeading>());

      final psalm = (await source.loadBook("engwebp", "PSA")).chapter(3)!;

      expect(psalm.items.first, isA<BibleDescription>());
      expect(psalm.verses.first.text, contains("\n\t"));

      // Die Glossa ordinaria der Vulgata-Quelle wird nicht übernommen.
      final vulgate = (await source.loadBook("latVUC", "GEN")).chapter(1)!;

      expect(vulgate.verses.every((v) => v.notes.isEmpty), isTrue);
    });
  });

  group("Stellenangaben", () {
    BibleReference? parse(String input, [BibleTranslation? t]) =>
        BibleReferenceParser.parse(input, translation: t);

    test("Deutsche Schreibweisen", () {
      expect(
        parse("Mk 4,35–41"),
        const BibleReference(
          bookId: "MRK",
          chapter: 4,
          verse: 35,
          endVerse: 41,
        ),
      );
      expect(parse("Mk 4,35-41"), parse("Mk 4,35–41"));
      expect(parse("  mk  4 , 35 - 41 "), parse("Mk 4,35–41"));
      expect(
        parse("Joh 3,16"),
        const BibleReference(bookId: "JHN", chapter: 3, verse: 16),
      );
      expect(parse("Ps 23"), const BibleReference.chapter("PSA", 23));
      expect(
        parse("Gen 1-3"),
        const BibleReference(bookId: "GEN", chapter: 1, endChapter: 3),
      );
      expect(
        parse("1. Mose 1,1–2,4"),
        const BibleReference(
          bookId: "GEN",
          chapter: 1,
          verse: 1,
          endChapter: 2,
          endVerse: 4,
        ),
      );
      expect(parse("1Kön 8"), const BibleReference.chapter("1KI", 8));
      expect(parse("1 Kor 13"), const BibleReference.chapter("1CO", 13));
      expect(parse("Röm 8,28")!.bookId, "ROM");
      expect(parse("Offenbarung 21")!.bookId, "REV");
      expect(parse("Matthäus")!.chapter, 1);
      expect(parse("Mk 4,35f")!.endVerse, 36);
      expect(parse("Mk 4,35ff")!.openEnd, isTrue);
    });

    test("Englische, lateinische und griechische Buchnamen", () {
      expect(
        parse("John 3:16"),
        const BibleReference(bookId: "JHN", chapter: 3, verse: 16),
      );
      expect(parse("1 Corinthians 13")!.bookId, "1CO");
      expect(parse("Revelation 1")!.bookId, "REV");
      expect(parse("Apocalypsis 1")!.bookId, "REV");
      expect(parse("Psalmi 22")!.bookId, "PSA");
      expect(parse("ΚΑΤΑ ΜΑΡΚΟΝ 4,35", byId("grcsbl"))!.bookId, "MRK");
      expect(parse("Μᾶρκον 4,35", byId("grcsbl"))!.bookId, "MRK");
      expect(parse("μαρκον 4", byId("grcsbl"))!.bookId, "MRK");
      expect(parse("Γένεσις 1", byId("grcbrent"))!.bookId, "GEN");
      expect(parse("ΨΑΛΜΟΙ 22", byId("grcbrent"))!.bookId, "PSA");
      expect(parse("Genesis 1", byId("latVUC"))!.bookId, "GEN");
    });

    test("Unklare und fehlerhafte Eingaben ergeben keine Stelle", () {
      expect(parse(""), isNull);
      expect(parse("Jo 3"), isNull, reason: "Joh, Joel, Jona, Josua");
      expect(parse("Liebe"), isNull);
      expect(parse("Mk 4,41-35"), isNull);
      expect(parse("Mk 0"), isNull);
      expect(parse("Mk 4,"), isNull);
      expect(parse("Xyz 3"), isNull);
    });

    test("Zugehörigkeit von Versen", () {
      const ref = BibleReference(
        bookId: "GEN",
        chapter: 1,
        verse: 26,
        endChapter: 2,
        endVerse: 4,
      );

      expect(ref.containsVerse(1, 25), isFalse);
      expect(ref.containsVerse(1, 26), isTrue);
      expect(ref.containsVerse(1, 31), isTrue);
      expect(ref.containsVerse(2, 4), isTrue);
      expect(ref.containsVerse(2, 5), isFalse);
      expect(ref.containsVerse(3, 1), isFalse);
      expect(ref.rangeText, "1,26–2,4");
      expect(BibleReferenceParser.format(ref), "Gen 1,26–2,4");
    });

    test("Jedes Buch der Perikopenliste ist bekannt, jede Perikope ergibt "
        "eine Stelle", () {
      final list = jsonDecode(File("assets/perikopen.json").readAsStringSync());

      for (final entry in list as List) {
        final p = Perikope.fromJson(Map<String, dynamic>.from(entry));

        final passage = BibleReferenceParser.passageOf(p);

        expect(passage, isNotNull, reason: "${p.id} (${p.book})");
        expect(passage!.reference.chapter, p.startChapter);
        expect(passage.reference.endChapter, p.endChapter);
        expect(passage.label, startsWith("${p.book} "));
      }
    });

    test("Die Bücher des Quiz stehen in den deutschen Ausgaben", () {
      const quizBooks =
          "Gen Ex Lev Num Dtn Jos Ri Rut 1Sam 2Sam 1Kön 2Kön 1Chr 2Chr Esr "
          "Neh Est Ijob Ps Spr Koh Hld Jes Jer Klgl Ez Dan Hos Joel Am Obd "
          "Jona Mi Nah Hab Zef Hag Sach Mal Mt Mk Lk Joh Apg Röm 1Kor 2Kor "
          "Gal Eph Phil Kol 1Thess 2Thess 1Tim 2Tim Tit Phlm Hebr Jak 1Petr "
          "2Petr 1Joh 2Joh 3Joh Jud Offb";

      for (final abbreviation in quizBooks.split(" ")) {
        final book = BibleBooks.byAbbreviation(abbreviation);

        expect(book, isNotNull, reason: abbreviation);

        for (final id in ["deu1912", "deu1951", "deuelbbk", "deutkw"]) {
          expect(byId(id).hasBook(book!.id), isTrue, reason: abbreviation);
        }

        // Die Abkürzung selbst ist auch als Eingabe gültig.
        expect(
          parse("$abbreviation 1")!.bookId,
          book!.id,
          reason: abbreviation,
        );
      }
    });

    test("Daniel und Ester der Septuaginta stehen unter der griechischen "
        "Fassung", () {
      expect(BibleBooks.resolveIn(byId("grcbrent"), "DAN"), "DAG");
      expect(BibleBooks.resolveIn(byId("grcbrent"), "EST"), "ESG");
      expect(BibleBooks.resolveIn(byId("deu1912"), "SIR"), isNull);
      expect(BibleBooks.resolveIn(byId("grcsbl"), "GEN"), isNull);
    });
  });

  group("Suche", () {
    test("Vergleichsform: Akzente, Spiritus, Schlusssigma, Zerlegung", () {
      String fold(String s) => foldForSearch(s, keepUmlauts: false);

      expect(fold("Ἐν ἀρχῇ ἦν ὁ λόγος,"), "εν αρχη ην ο λογοσ");
      // Zusammengesetzt, zerlegt und mit Tonos statt Oxia: dieselbe Form.
      expect(fold("ἀγάπη"), "αγαπη");
      expect(fold("ἀγάπη"), "αγαπη");
      expect(fold("αγάπη"), "αγαπη");
      expect(fold("ΑΓΑΠΗ"), "αγαπη");
      // Textkritische Zeichen und Apostroph zählen nicht.
      expect(fold("ἄλλα ⸀πλοῖα ἦν μετʼ αὐτοῦ."), "αλλα πλοια ην μετ αυτου");
      expect(fold("cælum et  terram."), "caelum et terram");
      expect(fold("Israël"), "israel");

      expect(foldForSearch("Väter, daß", keepUmlauts: true), "väter dass");
      expect(foldForSearch("Väter", keepUmlauts: false), "vater");
    });

    test("Die Zuordnung zum Original markiert den Treffer im "
        "unveränderten Text", () {
      final index = BibleSearchIndex(byId("grcsbl"));

      const text = "Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος";

      final ranges = index.matchRanges(text, index.parse("λογος"));

      expect(ranges.map((r) => text.substring(r.start, r.end)), [
        "λόγος",
        "λόγος",
      ]);
    });

    test("Anfrage: Wörter einzeln, Ausdruck in Anführungszeichen ganz", () {
      final query = BibleSearchQuery.parse(
        'Gott „der Herr“ Welt',
        keepUmlauts: true,
      );

      expect(query.terms, unorderedEquals(["gott", "der herr", "welt"]));
    });

    test("Deutsch, Englisch, Griechisch und Latein über den ganzen Text; "
        "der Index wird je Ausgabe nur einmal aufgebaut", () async {
      final counting = CountingSource(source);

      final repository = BibleRepository(source: counting);

      int total(BibleSearchIndex index, String input, [BibleSearchScope? s]) {
        return index
            .search(index.parse(input), scope: s ?? BibleSearchScope.all)
            .total;
      }

      String first(BibleSearchIndex index, String input) {
        return index.search(index.parse(input)).hits.first.reference.toString();
      }

      // Deutsch: ß und ss, Groß-/Kleinschreibung, mehrere Wörter.
      final luther = await repository.searchIndex(byId("deu1912"));

      expect(luther.verseCount, 31102);
      expect(total(luther, "also hat gott die welt geliebt"), 1);
      expect(first(luther, "also hat gott die welt geliebt"), "JHN 3,16");
      expect(total(luther, '"dass er seinen eingeborenen"'), 1);
      expect(first(luther, "Hirte mangeln"), "PSA 23,1");
      expect(total(luther, "xyzxyz"), 0);

      // Einschränkung auf Testament und Buch.
      final all = total(luther, "Barmherzigkeit");

      expect(all, greaterThan(0));
      expect(
        total(luther, "Barmherzigkeit", BibleSearchScope.oldTestament) +
            total(luther, "Barmherzigkeit", BibleSearchScope.newTestament),
        all,
      );
      expect(
        luther
            .search(
              luther.parse("Barmherzigkeit"),
              scope: BibleSearchScope.book,
              bookId: "PSA",
            )
            .hits
            .every((h) => h.bookId == "PSA"),
        isTrue,
      );

      // Weitere Eingaben lesen nichts erneut ein.
      expect(counting.loads, 66);

      await repository.searchIndex(byId("deu1912"));
      total(luther, "Gnade");

      expect(counting.loads, 66);

      // Englisch.
      final web = await repository.searchIndex(byId("engwebp"));

      expect(first(web, "in the beginning was the word"), "JHN 1,1");

      // Griechisch: ohne Akzente, mit Akzenten und in Großbuchstaben.
      final sbl = await repository.searchIndex(byId("grcsbl"));

      for (final input in [
        "εν αρχη ην ο λογος",
        "Ἐν ἀρχῇ ἦν ὁ λόγος",
        "ΕΝ ΑΡΧΗ ΗΝ Ο ΛΟΓΟΣ",
      ]) {
        expect(first(sbl, input), "JHN 1,1", reason: input);
      }

      expect(total(sbl, "αγαπη"), greaterThan(50));
      expect(total(sbl, "ἀγάπη"), total(sbl, "αγαπη"));

      // Latein.
      final vulgate = await repository.searchIndex(byId("latVUC"));

      expect(first(vulgate, "in principio creavit deus caelum"), "GEN 1,1");
    });
  });

  group("Lesestand", () {
    test("Stelle wird gespeichert und wieder gelesen", () async {
      final settings = await BibleReaderSettings.load();

      expect(settings.position, isNull);
      expect(settings.translationId, isNull);

      await settings.saveTranslation("grcsbl");
      await settings.savePosition(
        const BibleReference(bookId: "MRK", chapter: 4, verse: 35),
      );

      final loaded = await BibleReaderSettings.load();

      expect(loaded.translationId, "grcsbl");
      expect(
        loaded.position,
        const BibleReference(bookId: "MRK", chapter: 4, verse: 35),
      );
    });

    test("Unlesbare Werte ergeben keinen Lesestand", () {
      expect(BibleReaderSettings.parsePosition(null), isNull);
      expect(BibleReaderSettings.parsePosition("MRK"), isNull);
      expect(BibleReaderSettings.parsePosition("MRK|x|1"), isNull);
      expect(BibleReaderSettings.parsePosition("MRK|4|0")!.verse, isNull);
    });
  });
}
