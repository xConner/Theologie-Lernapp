import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/apocrypha/apocrypha.dart';

/// Prüft die ausgelieferten Daten unter `assets/apocrypha/` (erzeugt von
/// `tool/apocrypha/build_apocrypha.py`).
void main() {
  const root = "assets/apocrypha";
  Object? read(String path) => jsonDecode(File(path).readAsStringSync());

  final catalog = ApocryphaCatalog.fromJson(
    read("$root/catalog.json") as Map<String, dynamic>,
  );

  test("Werke und Fassungen haben eindeutige, stabile Kennungen", () {
    final ids = catalog.works.map((w) => w.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id, matches(RegExp(r"^[a-z0-9_]+$")));
    }
    final versions = [
      for (final w in catalog.works) ...w.versions.map((v) => v.id),
    ];
    expect(versions.toSet().length, versions.length);
    for (final w in catalog.works) {
      for (final v in w.versions) {
        expect(v.workId, w.id);
        expect(v.id.startsWith("${w.id}."), isTrue, reason: v.id);
      }
    }
    expect(catalog.works.length, greaterThanOrEqualTo(60));
  });

  test("jedes Werk ist eingeordnet und hat mindestens eine Fassung", () {
    final categories = catalog.categories.map((c) => c.id).toSet();
    for (final w in catalog.works) {
      expect(w.versions, isNotEmpty, reason: w.id);
      expect(w.categories, isNotEmpty, reason: w.id);
      expect(categories.containsAll(w.categories), isTrue, reason: w.id);
      expect(w.summary.trim(), isNotEmpty, reason: w.id);
      expect(w.assessments, isNotEmpty, reason: w.id);
      expect(w.dating.from <= w.dating.to, isTrue, reason: w.id);
      if (!w.hasText) {
        expect(w.noTextReason, isNotNull, reason: "${w.id}: Grund fehlt");
      }
    }
    // Jede Kategorie ist belegt; ein Werk kann in mehreren stehen.
    for (final c in categories) {
      expect(catalog.worksIn(c), isNotEmpty, reason: c);
    }
  });

  test("Text nur mit geklärten Rechten, Verweise mit Link", () {
    for (final w in catalog.works) {
      for (final v in w.versions) {
        if (v.hasText) {
          expect(v.rights.allowsText, isTrue, reason: v.id);
          expect(v.license, isNotNull, reason: v.id);
          expect(v.edition, isNotNull, reason: v.id);
          expect(v.source, isNotNull, reason: v.id);
          if (v.source != "app") {
            expect(catalog.sources.containsKey(v.source), isTrue, reason: v.id);
          }
        } else {
          expect(v.coverage, Coverage.external, reason: v.id);
          expect(v.url, startsWith("https://"), reason: v.id);
        }
      }
    }
  });

  test("fragmentarische Werke sind nicht als vollständig gekennzeichnet", () {
    for (final w in catalog.works) {
      if (w.preservation == Preservation.fragmentary ||
          w.preservation == Preservation.lost) {
        for (final v in w.readableVersions) {
          expect(v.coverage, isNot(Coverage.full), reason: v.id);
        }
      }
      for (final v in w.versions) {
        if (v.coverage == Coverage.partial) {
          expect(v.coverageNote, isNotNull, reason: "${v.id}: Umfang fehlt");
        }
      }
    }
  });

  test("Kanonstatus der Deuterokanonen je Kirche, nie pauschal apokryph", () {
    for (final w in catalog.worksIn("deuterokanonisch")) {
      final byTradition = {for (final c in w.canon) c.tradition: c.status};
      expect(
        byTradition.keys,
        containsAll(["lutherisch", "katholisch", "orthodox"]),
        reason: w.id,
      );
      for (final c in w.canon) {
        expect(canonTraditions.containsKey(c.tradition), isTrue);
        expect(canonStatuses.containsKey(c.status), isTrue);
      }
    }
    final tobit = catalog.work("tobit")!;
    final status = {for (final c in tobit.canon) c.tradition: c.status};
    expect(status["katholisch"], "deuterokanonisch");
    expect(status["lutherisch"], "apokryph");
  });

  test("Pseudepigraphen nennen den Namen nicht als Verfasser", () {
    final enoch = catalog.work("henoch1")!;
    expect(enoch.attribution?.kind, AttributionKind.pseudepigraph);
    for (final w in catalog.works) {
      final a = w.attribution;
      if (a != null) expect(a.name, isNotEmpty, reason: w.id);
    }
  });

  test("Inhaltsverzeichnisse und Textdateien passen zum Katalog", () {
    for (final w in catalog.works) {
      for (final v in w.readableVersions) {
        final toc =
            (read("$root/texts/${v.id}.toc.json") as Map)["units"] as List;
        final units = [
          for (final u in toc)
            TocUnit.fromJson(Map<String, dynamic>.from(u as Map)),
        ];
        expect(units.length, v.units, reason: v.id);
        expect(units.map((u) => u.id).toSet().length, units.length);
        expect(units.every((u) => u.bible != null), v.fromBible);

        final chunks = <int, Set<String>>{};
        for (final u in units) {
          if (u.bible != null) continue;
          chunks.putIfAbsent(u.chunk!, () {
            final data = read("$root/texts/${v.id}.${u.chunk}.json") as Map;
            return {for (final t in data["units"] as List) (t as Map)["id"]};
          });
          expect(chunks[u.chunk]!.contains(u.id), isTrue, reason: v.id);
        }
      }
    }
  });

  test("Fassungen aus dem Bibelbereich verweisen auf vorhandene Verse", () {
    final books = <String, Map>{};
    for (final w in catalog.works) {
      for (final v in w.readableVersions.where((v) => v.fromBible)) {
        final toc =
            (read("$root/texts/${v.id}.toc.json") as Map)["units"] as List;
        for (final raw in toc) {
          final span = TocUnit.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ).bible!;
          final book = books.putIfAbsent(
            "${span.translation}/${span.book}",
            () =>
                read("assets/bible/${span.translation}/${span.book}.json")
                    as Map,
          );
          final chapters = book["chapters"] as List;
          expect(span.chapter <= chapters.length, isTrue, reason: v.id);
          final verses = {
            for (final i in chapters[span.chapter - 1] as List)
              if ((i as Map).containsKey("v")) i["v"],
          };
          expect(verses.contains(span.firstVerse), isTrue, reason: v.id);
          expect(verses.contains(span.lastVerse), isTrue, reason: v.id);
        }
      }
    }
  });

  test("keine maschinellen Übersetzungen im Text", () {
    for (final f in Directory("$root/texts").listSync()) {
      final text = File(f.path).readAsStringSync();
      expect(text.contains("ChatGPT"), isFalse, reason: f.path);
    }
  });

  test("Assets und Schriften sind in pubspec.yaml eingetragen", () {
    final pubspec = File("pubspec.yaml").readAsStringSync();
    expect(pubspec, contains("- assets/apocrypha/\n"));
    expect(pubspec, contains("- assets/apocrypha/texts/\n"));
    expect(pubspec, contains("assets/fonts/NotoSansCoptic-Regular.ttf"));
    expect(pubspec, contains("assets/fonts/NotoSansEthiopic-Regular.ttf"));
  });
}
