import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/fathers/fathers.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';
import 'package:theologie_lernapp/services/fathers/fathers_repository.dart';

import '../test_asset_bundle.dart';

/// Prüft die echten Daten unter `assets/fathers/` (erzeugt von
/// `tool/fathers/import_bkv.py` und `tool/fathers/crossrefs.py`).
const String root = FathersRepository.root;

Object? readJson(String path) => jsonDecode(File(path).readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = FathersRepository(bundle: FileAssetBundle());
  final manifest = readJson("$root/manifest.json") as Map<String, dynamic>;
  final files = manifest["files"] as Map<String, dynamic>;

  test("Abkürzungen der Ausgaben zeigen auf Bücher der App", () {
    final aliases =
        (readJson("tool/fathers/book_aliases.json")
                as Map<String, dynamic>)["aliases"]
            as Map<String, dynamic>;

    for (final MapEntry(:key, :value) in aliases.entries) {
      final id = value as String;

      if (id.startsWith("?KINGS")) continue;

      expect(BibleBooks.byId(id), isNotNull, reason: "$key → $id");
    }
  });

  test("Manifest nennt genau die vorhandenen Dateien", () {
    for (final folder in ["links", "xrefs"]) {
      final listed = (files[folder] as List).cast<String>().toSet();
      final present = Directory("$root/$folder")
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith(".json"))
          .map((n) => n.substring(0, n.length - 5))
          .toSet();

      expect(present, listed, reason: folder);

      for (final book in listed) {
        expect(BibleBooks.byId(book), isNotNull, reason: "$folder/$book");
      }
    }
  });

  test(
    "Katalog: eindeutige Kennungen, Autoren vorhanden, Rechte stimmig",
    () async {
      final library = await repo.library();
      final ids = <String>{};

      for (final a in library.authors) {
        expect(ids.add(a.id), isTrue, reason: "doppelt: ${a.id}");
      }

      for (final w in library.works) {
        expect(ids.add(w.id), isTrue, reason: "doppelt: ${w.id}");
        expect(library.author(w.authorId), isNotNull, reason: w.id);
        expect(w.versions, isNotEmpty, reason: w.id);

        for (final v in w.versions) {
          expect(ids.add(v.id), isTrue, reason: "doppelt: ${v.id}");

          final toc = File("$root/texts/${v.id}.toc.json");

          // Volltext nur bei gemeinfreien Fassungen – und dann vollständig.
          if (v.hasText) {
            expect(toc.existsSync(), isTrue, reason: v.id);
            expect(v.rightsNote, isNotNull, reason: v.id);
            expect(v.sourceUrl ?? v.sourceName, isNotNull, reason: v.id);

            // Texte ohne Übersetzer und Vorlage sagen das ausdrücklich.
            if (v.kind == TextKind.unknownTranslation) {
              expect(v.rightsNote, contains("nicht genannt"), reason: v.id);
            }
          } else {
            expect(toc.existsSync(), isFalse, reason: v.id);
          }

          if (v.appLink != null) {
            expect(v.appLink, startsWith("confession:"));
          }
        }
      }

      // Keine Textdatei ohne freigegebene Fassung.
      final readable = {
        for (final w in library.works)
          for (final v in w.versions)
            if (v.hasText) v.id,
      };

      for (final f in Directory("$root/texts").listSync()) {
        final name = f.uri.pathSegments.last;

        if (!name.endsWith(".json")) continue;
        final id = name.replaceFirst(RegExp(r"\.(toc|links|\d+)\.json$"), "");

        expect(readable, contains(id), reason: name);
      }
    },
  );

  test("App-Verweise führen auf vorhandene Bekenntnisse", () async {
    final confessions = (readJson("assets/confessions.json") as List)
        .map((c) => (c as Map<String, dynamic>)["id"])
        .toSet();
    final library = await repo.library();

    for (final w in library.works) {
      for (final v in w.versions) {
        final link = v.appLink;

        if (link == null) continue;

        expect(confessions, contains(link.substring("confession:".length)));
      }
    }
  });

  test("Jede Zuordnung zeigt auf einen vorhandenen Absatz", () async {
    final library = await repo.library();
    final linkIds = <String>{};

    for (final book in (files["links"] as List).cast<String>()) {
      for (final link in await repo.linksForBook(book)) {
        expect(linkIds.add(link.id), isTrue, reason: "doppelt: ${link.id}");
        expect(link.reference.bookId, book);

        final version = library.version(link.versionId);

        expect(version?.version.hasText, isTrue, reason: link.id);

        final section = await repo.section(link.versionId, link.section);

        expect(section, isNotNull, reason: link.id);
        expect(link.lastParagraph, lessThan(section!.paragraphs.length));
        expect(link.firstParagraph, lessThanOrEqualTo(link.lastParagraph));
      }
    }
  });

  test("Verwandte Stellen: gültige Bücher und Verse", () {
    for (final book in (files["xrefs"] as List).cast<String>()) {
      final data = readJson("$root/xrefs/$book.json") as Map<String, dynamic>;
      final books = (data["books"] as List).cast<String>();

      for (final b in books) {
        expect(BibleBooks.byId(b), isNotNull, reason: "$book: $b");
      }

      for (final MapEntry(:key, :value) in (data["refs"] as Map).entries) {
        expect(key, matches(RegExp(r"^\d+:\d+$")));

        for (final r in value as List) {
          final row = (r as List).cast<int>();

          expect(row[0], lessThan(books.length));
          expect(row.length, 6);
        }
      }
    }
  });

  test("Einordnung der Autoren getrennt nach Gruppen", () async {
    final library = await repo.library();
    final byCategory = <AuthorCategory, int>{};

    for (final a in library.authors) {
      byCategory[a.category] = (byCategory[a.category] ?? 0) + 1;
    }

    expect(byCategory[AuthorCategory.reformer], greaterThan(0));
    expect(byCategory[AuthorCategory.lutheran], greaterThan(0));
    expect(byCategory[AuthorCategory.medieval], greaterThan(0));
  });

  test("Gen 1,1: Auslegung aus dem Exameron des Ambrosius", () async {
    final links = await repo.linksForVerse("GEN", 1, 1);
    final library = await repo.library();

    expect(
      links.where(
        (l) =>
            l.kind == LinkKind.sectionCommentary &&
            library.author(l.authorId)?.name == "Ambrosius von Mailand",
      ),
      isNotEmpty,
    );

    // Texte mit Erlaubnis statt Gemeinfreiheit nennen den Grund.
    for (final w in library.works) {
      for (final v in w.versions) {
        if (v.rights == RightsStatus.permission) {
          expect(v.rightsNote, contains("Nutzungserlaubnis"), reason: v.id);
        }
      }
    }
  });

  group("Freie Textsammlungen (tool/fathers/curation/open_texts.json)", () {
    final curated =
        readJson("tool/fathers/curation/open_texts.json")
            as Map<String, dynamic>;
    final texts = (curated["texts"] as List).cast<Map<String, dynamic>>();

    test(
      "jede kuratierte Fassung ist mit Text, Quelle und Rechten da",
      () async {
        final library = await repo.library();
        final versions = {
          for (final w in library.works)
            for (final v in w.versions) v.id: (work: w, version: v),
        };

        for (final t in texts) {
          final id = (t["version"] as Map<String, dynamic>)["id"] as String;
          final found = versions[id];

          expect(found, isNotNull, reason: id);
          final v = found!.version;

          expect(v.hasText, isTrue, reason: id);
          expect(v.sourceUrl, startsWith("https://github.com/"), reason: id);
          expect(v.rightsNote, isNotEmpty, reason: id);
          expect(fathersLanguageNames.keys, contains(v.language), reason: id);
          expect(
            found.work.id,
            (t["work"] as Map<String, dynamic>)["id"],
            reason: id,
          );

          if (v.rights == RightsStatus.openLicense) {
            expect(v.rightsNote, contains("Creative Commons"), reason: id);
            expect(v.kind, TextKind.original, reason: id);
          } else {
            expect(v.rights, RightsStatus.publicDomain, reason: id);
          }

          // Inhaltsverzeichnis und Textdateien vollständig und in Reihenfolge.
          final toc =
              (readJson("$root/texts/$id.toc.json")
                      as Map<String, dynamic>)["sections"]
                  as List;
          expect(toc.length, v.sectionCount, reason: id);

          final numbers = [for (final e in toc) (e as Map)["n"] as int];
          expect(numbers, [
            for (var i = 1; i <= toc.length; i++) i,
          ], reason: id);

          final chunks = {for (final e in toc) (e as Map)["c"] as int};
          for (final c in chunks) {
            final sections =
                (readJson("$root/texts/$id.$c.json")
                        as Map<String, dynamic>)["sections"]
                    as List;
            for (final s in sections) {
              final p = ((s as Map)["p"] as List).cast<String>();
              expect(p, isNotEmpty, reason: "$id §${s["n"]}");

              final notes = (s["notes"] as List?)?.length ?? 0;
              for (final text in p) {
                for (final m in RegExp(r"\[(\d+)\]").allMatches(text)) {
                  expect(
                    int.parse(m[1]!),
                    inInclusiveRange(1, notes),
                    reason: "$id §${s["n"]}: Anmerkung ${m[0]}",
                  );
                }
              }
            }
          }
        }
      },
    );

    test("keine maschinellen Übertragungen in den Texten", () {
      for (final f in Directory("$root/texts").listSync()) {
        final text = File(f.path).readAsStringSync();
        expect(
          RegExp("ChatGPT|using GPT", caseSensitive: false).hasMatch(text),
          isFalse,
          reason: f.path,
        );
      }
    });

    test("Homilienreihen vollständig (Zahl der Homilien wie in NPNF)", () {
      const expected = {
        "npnf.chrysostomus.hom_mt": 90,
        "npnf.chrysostomus.hom_jo": 88,
        "npnf.chrysostomus.hom_act": 55,
        "npnf.chrysostomus.hom_rom": 32,
        "npnf.chrysostomus.hom_1co": 44,
        "npnf.chrysostomus.hom_2co": 30,
        "npnf.chrysostomus.hom_eph": 24,
        "npnf.chrysostomus.hom_phil": 15,
        "npnf.chrysostomus.hom_col": 12,
        "npnf.chrysostomus.hom_1th": 11,
        "npnf.chrysostomus.hom_2th": 5,
        "npnf.chrysostomus.hom_1tim": 18,
        "npnf.chrysostomus.hom_2tim": 10,
        "npnf.chrysostomus.hom_tit": 6,
        "npnf.chrysostomus.hom_phlm": 3,
        "npnf.chrysostomus.hom_heb": 34,
        "npnf.chrysostomus.de_statuis": 21,
        "npnf.basilius.hexaemeron": 9,
      };

      for (final MapEntry(:key, :value) in expected.entries) {
        final toc =
            (readJson("$root/texts/$key.toc.json")
                    as Map<String, dynamic>)["sections"]
                as List;
        expect(toc.length, value, reason: key);
      }
    });

    test("keine doppelten Werke eines Autors", () async {
      final library = await repo.library();
      final seen = <String>{};

      String key(String? text) =>
          (text ?? "").toLowerCase().replaceAll(RegExp(r"[^a-zäöüß0-9]"), "");

      for (final w in library.works) {
        for (final title in {w.title, ?w.originalTitle}) {
          if (key(title).isEmpty || title == "Briefe") continue;
          expect(
            seen.add("${w.authorId}|${key(title)}"),
            isTrue,
            reason: "${w.id}: $title",
          );
        }
      }
    });

    test("Werke mit mehreren Sprachen öffnen die deutsche Fassung", () async {
      final library = await repo.library();
      final exameron = library.works.firstWhere((w) => w.id == "bkv.cpl-123");

      expect(exameron.textLanguages, containsAll(["de", "la"]));
      expect(exameron.readableVersion?.language, "de");
      expect(exameron.versions.first.language, "de");
    });
  });
}
