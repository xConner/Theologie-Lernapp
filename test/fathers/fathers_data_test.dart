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
            expect(v.sourceUrl, isNotNull, reason: v.id);
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
}
