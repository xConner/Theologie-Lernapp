import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/fathers/fathers.dart';
import 'package:theologie_lernapp/screens/fathers/fathers_home_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/versification_map.dart';
import 'package:theologie_lernapp/services/fathers/fathers_repository.dart';

import '../test_asset_bundle.dart';
import 'fathers_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixtureBundle bundle;
  late FathersRepository repo;

  setUp(() {
    bundle = FixtureBundle();
    repo = FathersRepository(bundle: bundle);
  });

  group("Laden und Zwischenspeicher", () {
    test("Katalog wird einmal geladen, ohne Texte", () async {
      final a = await repo.library();
      final b = await repo.library();

      expect(identical(a, b), isTrue);
      expect(bundle.requests, ["$root/library.json"]);
    });

    test("Zuordnungen eines Buchs werden einmal geladen", () async {
      await repo.linksForVerse("JHN", 1, 1);
      await repo.linksForVerse("JHN", 1, 2);
      await repo.linksForVerse("JHN", 3, 16);

      expect(
        bundle.requests.where((r) => r == "$root/links/JHN.json").length,
        1,
      );
    });

    test("Bücher ohne Daten laden keine Datei", () async {
      expect(await repo.linksForVerse("GEN", 1, 1), isEmpty);
      expect(await repo.crossReferences("GEN", 1, 1), isEmpty);

      expect(bundle.requests, ["$root/manifest.json"]);
    });

    test("ein Abschnitt lädt nur die Datei, die ihn enthält", () async {
      final s = await repo.section("werk_a.de", 3);

      expect(s!.paragraphs.single, contains("Leuchte"));
      expect(bundle.requests, contains("$root/texts/werk_a.de.1.json"));
      expect(bundle.requests, isNot(contains("$root/texts/werk_a.de.0.json")));
    });

    test("nach einem Ladefehler wird erneut versucht", () async {
      bundle.failing.add("$root/links/JHN.json");

      await expectLater(repo.linksForBook("JHN"), throwsA(anything));

      bundle.failing.clear();

      expect(await repo.linksForBook("JHN"), hasLength(3));
    });

    test("Textdateien werden nur begrenzt im Speicher gehalten", () async {
      final files = Map<String, Object>.from(fixtureFiles);
      final sections = <Map<String, Object>>[];

      for (int i = 0; i < 20; i++) {
        sections.add({"n": i, "t": "A$i", "c": i});
        files["$root/texts/viel.$i.json"] = {
          "sections": [
            {
              "n": i,
              "p": ["Text $i"],
            },
          ],
        };
      }
      files["$root/texts/viel.toc.json"] = {"sections": sections};

      final big = FixtureBundle(files);
      final r = FathersRepository(bundle: big);

      for (int i = 0; i < 20; i++) {
        await r.section("viel", i);
      }
      await r.section("viel", 0);

      // Abschnitt 0 war aus dem Speicher verdrängt und wird neu geladen.
      expect(
        big.requests.where((p) => p == "$root/texts/viel.0.json").length,
        2,
      );
      // Der zuletzt gelesene bleibt im Speicher.
      await r.section("viel", 19);
      expect(
        big.requests.where((p) => p == "$root/texts/viel.19.json").length,
        1,
      );
    });
  });

  group("Zuordnungen", () {
    test("Vers, Abschnitt und Perikope", () async {
      final verse = await repo.linksForVerse("JHN", 1, 1);
      expect(verse.map((l) => l.id), unorderedEquals(["l1", "l2"]));

      // Ein Kommentar zu Joh 1,1–5 gilt für Vers 3, das Zitat von 1,1 nicht.
      final inner = await repo.linksForVerse("JHN", 1, 3);
      expect(inner.map((l) => l.id), ["l1"]);
      expect(inner.single.kind, LinkKind.sectionCommentary);

      final range = await repo.linksForRange(
        const BibleReference(bookId: "JHN", chapter: 3, verse: 1, endVerse: 21),
      );
      expect(range.map((l) => l.id), ["l3"]);
    });

    test("ohne belegte Zuordnung kein Kommentar", () async {
      expect(await repo.linksForVerse("JHN", 2, 1), isEmpty);
    });

    test("Zuordnungen einer Fassung (Werk → Bibelstellen)", () async {
      final links = await repo.linksOfVersion("werk_a.de");

      expect(links.map((l) => l.reference.toString()), [
        "JHN 1,1–5",
        "JHN 3,16",
      ]);
    });

    test("Querverweise nach Bewertung", () async {
      final refs = await repo.crossReferences("JHN", 1, 1);

      expect(refs.map((r) => r.target.toString()), ["GEN 1,1", "JHN 1,14"]);
      expect(refs.first.votes, 59);
      expect(refs.first.kind, CrossRefKind.related);
    });
  });

  group("Rechte und Kennzeichnung", () {
    test("Text nur bei gemeinfreien Fassungen", () async {
      final library = await repo.library();

      expect(library.work("werk_a")!.readableVersion!.hasText, isTrue);
      expect(library.work("werk_a")!.availability, Availability.full);

      final b = library.work("werk_b")!;
      expect(b.readableVersion, isNull);
      expect(b.availability, Availability.external);
      expect(b.versions.single.rights, RightsStatus.unclear);

      final c = library.work("werk_c")!;
      expect(c.versions.single.hasText, isFalse);
      expect(c.versions.single.appLink, "confession:kleiner_katechismus");
    });

    test("Kategorien trennen Kirchenväter und Reformatoren", () async {
      final library = await repo.library();

      expect(library.author("reformator")!.category, AuthorCategory.reformer);
      expect(library.author("reformator")!.epoch, Epoch.reformation);
      expect(library.author("autor_a")!.epoch, Epoch.fourthFifth);
    });
  });

  group("Suche", () {
    test("nach Autor, Werk, Clavis und Alias", () async {
      final library = await repo.library();
      const none = FathersFilter();

      expect(FathersSearch.works(library, "johannes", none).length, 2);
      expect(FathersSearch.works(library, "CPL 0000", none).map((w) => w.id), [
        "werk_a",
      ]);
      expect(FathersSearch.authors(library, "auctor", none).map((a) => a.id), [
        "autor_a",
      ]);
      expect(FathersSearch.works(library, "gibt es nicht", none), isEmpty);
    });

    test("Filter nach Kategorie, Sprache und Volltext", () async {
      final library = await repo.library();

      expect(
        FathersSearch.works(
          library,
          "",
          const FathersFilter(category: AuthorCategory.reformer),
        ).map((w) => w.id),
        ["werk_c"],
      );
      expect(
        FathersSearch.works(
          library,
          "",
          const FathersFilter(language: "grc"),
        ).map((w) => w.id),
        ["werk_b"],
      );
      expect(
        FathersSearch.works(
          library,
          "",
          const FathersFilter(readableOnly: true),
        ).map((w) => w.id),
        ["werk_a"],
      );
    });

    test("Bibelstellen werden erkannt, Namen nicht", () {
      expect(FathersSearch.bibleReference("Joh 3,16").toString(), "JHN 3,16");
      expect(FathersSearch.bibleReference("Augustinus"), isNull);
      expect(FathersSearch.bibleReference("CPL 278"), isNull);
    });

    test("Volltextsuche findet Text in allen Dateien eines Werks", () async {
      final hits = await repo.searchVersion("werk_a.de", "leuchte");

      expect(hits.single.section, 3);
      expect(await repo.searchVersion("werk_a.de", "xy"), isEmpty);
      expect(await repo.searchVersion("werk_a.de", "nirgends"), isEmpty);
    });
  });

  group("Zählung", () {
    late List<BibleTranslation> translations;

    setUpAll(() async {
      translations = await AssetBibleTextSource(
        bundle: FileAssetBundle(),
      ).loadTranslations();
    });

    BibleTranslation t(String id) => translations.firstWhere((x) => x.id == id);

    ({int chapter, int verse})? toList(String t_, String b, int c, int v) =>
        ListVersification.toList(
          translation: t(t_),
          translations: translations,
          bookId: b,
          chapter: c,
          verse: v,
        );

    test("englisch gezählte Ausgaben → deutsche Zählung", () {
      expect(toList("deu1912", "GEN", 31, 55), (chapter: 32, verse: 1));
      expect(toList("deu1912", "GEN", 32, 1), (chapter: 32, verse: 2));
      expect(toList("deu1912", "MAL", 4, 5), (chapter: 3, verse: 23));
      expect(toList("engwebp", "JOL", 2, 28), (chapter: 3, verse: 1));
      expect(toList("deu1912", "MAT", 5, 3), (chapter: 5, verse: 3));
      expect(toList("deutkw", "GEN", 32, 1), (chapter: 32, verse: 1));
    });

    test("Umkehrung passt zu locate", () {
      for (final id in ["deu1912", "engwebp", "deutkw"]) {
        final edition = t(id);

        for (final book in ["GEN", "EXO", "NUM", "1KI", "JOL", "MAL"]) {
          final info = edition.book(book)!;

          for (int c = 1; c <= info.chapterCount; c++) {
            for (int v = 1; v <= info.verseCount(c); v++) {
              final german = toList(id, book, c, v);

              if (german == null) continue;

              expect(
                ListVersification.locate(
                  translation: edition,
                  translations: translations,
                  bookId: book,
                  chapter: german.chapter,
                  verse: german.verse,
                ),
                (chapter: c, verse: v),
                reason: "$id $book $c,$v",
              );
            }
          }
        }
      }
    });
  });
}
