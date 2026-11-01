import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/pericope_id_migration.dart';
import 'package:theologie_lernapp/quiz/pericope_merges.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';

import 'perikopen_validator.dart';
import 'test_asset_bundle.dart';

/// Pflichtlektüre des Bibelleseplans zur Übung Bibelkunde AT
/// (`course-bibelkunde-at-wise-2026`, Sitzungen 2–4 mit
/// `readingSource: slides`) als Kapitel/Vers-Bereiche; 999 = Kapitelende.
const _required = {
  "Gen": [
    [1, 1, 999, 999],
  ],
  "Ex": [
    [1, 1, 5, 999],
    [7, 1, 24, 999],
    [32, 1, 34, 999],
  ],
  "Lev": [
    [16, 1, 16, 999],
  ],
  "Num": [
    [6, 22, 6, 26],
    [10, 11, 10, 12],
    [10, 33, 10, 36],
    [11, 1, 14, 999],
    [20, 1, 25, 999],
    [27, 12, 27, 23],
  ],
  "Dtn": [
    [1, 1, 1, 999],
    [4, 1, 8, 999],
    [12, 1, 18, 999],
    [26, 1, 26, 999],
    [30, 1, 34, 999],
  ],
};

bool _touchesRequired(Perikope p) {
  final start = p.startChapter * 1000 + p.startVerse;
  final end = p.endChapter * 1000 + p.endVerse;
  for (final r in _required[p.book] ?? const <List<int>>[]) {
    if (start <= r[2] * 1000 + r[3] && r[0] * 1000 + r[1] <= end) return true;
  }
  return false;
}

void main() {
  late List<Perikope> perikopen;
  late Set<String> keys;
  late Set<String> ids;
  late List<BibleTranslation> translations;

  setUpAll(() async {
    perikopen = [
      for (final e
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(e)),
    ];
    keys = perikopen.map(BookPericope.keyOf).toSet();
    ids = perikopen.map((p) => p.id).toSet();
    translations = await AssetBibleTextSource(
      bundle: FileAssetBundle(),
    ).loadTranslations();
  });

  group("Gröbere Gliederung der optionalen Perikopen", () {
    test(
      "Umfang: Pflichtperikopen bleiben, optionale sind zusammengefasst",
      () {
        expect(perikopen, hasLength(1263));
        expect(perikopen.where(_touchesRequired), hasLength(230));
        int count(String book) => perikopen.where((p) => p.book == book).length;
        expect(count("Gen"), 78);
        expect(count("Lev"), 20);
        expect(count("Mt"), 43);
        expect(count("Ps"), 126);
      },
    );

    test("keine zusammengelegte Perikope berührt die Pflichtlektüre", () {
      for (final key in PericopeMerges.keys.keys) {
        final p = perikopen.singleWhere((p) => BookPericope.keyOf(p) == key);
        expect(_touchesRequired(p), isFalse, reason: key);
      }
      for (final key in PericopeMerges.widened.keys) {
        final p = perikopen.singleWhere((p) => BookPericope.keyOf(p) == key);
        expect(_touchesRequired(p), isFalse, reason: key);
      }
    });

    test("Lücken gibt es nur noch zwischen Pflichtperikopen im Dtn", () {
      final gaps = PericopeValidator(translations: translations).gaps([
        for (final e
            in jsonDecode(File("assets/perikopen.json").readAsStringSync())
                as List)
          e,
      ]);
      expect(gaps.keys, ["Dtn"]);
      expect(gaps["Dtn"], [
        "5,1–5,22",
        "12,1–12,3",
        "13,1",
        "14,28–14,29",
        "16,16–16,17",
        "16,21–17,1",
        "26,16–26,19",
      ]);
    });

    test("optionale Perikopen überschneiden sich nicht", () {
      final byBook = <String, List<Perikope>>{};
      for (final p in perikopen) {
        byBook.putIfAbsent(p.book, () => []).add(p);
      }
      for (final list in byBook.values) {
        final optional = list.where((p) => !_touchesRequired(p)).toList();
        for (var i = 1; i < optional.length; i++) {
          final a = optional[i - 1];
          final b = optional[i];
          final end = a.endChapter * 1000 + a.endVerse;
          final start = b.startChapter * 1000 + b.startVerse;
          // Höchstens ein geteilter Vers (Grenze im Vers, z. B. Mt 27,31a/b).
          expect(start >= end, isTrue, reason: "${a.title} / ${b.title}");
        }
      }
    });
  });

  group("Lernstand der zusammengelegten Perikopen", () {
    test("Ziele stehen in der Liste, Quellen nicht mehr", () {
      for (final e in PericopeMerges.ids.entries) {
        expect(ids, contains(e.key));
        for (final from in e.value) {
          expect(ids, isNot(contains(from)), reason: from);
        }
      }
      for (final e in PericopeMerges.keys.entries) {
        expect(keys, contains(e.key));
        for (final from in e.value) {
          expect(keys, isNot(contains(from)), reason: from);
        }
      }
      for (final key in PericopeMerges.widened.keys) {
        expect(keys, contains(key));
      }
    });

    test("Endlos-Quiz: die neue Perikope übernimmt eine frühere Karte", () {
      // Ex 6,2-27: Der Stammbaum (6,14-27) ist in der erneuten Berufung
      // aufgegangen; ohne eigene Karte gilt die des früheren Teils.
      final entry = PericopeMerges.ids.entries.first;
      expect(entry.key, "die_erneute_berufung_des_mose");
      final cards = {
        entry.value.first: LearningCard(id: entry.value.first, stability: 6),
      };
      PericopeIdMigration.perikopeCards(cards);
      expect(cards[entry.key]?.stability, 6);
      expect(cards[entry.value.first]?.stability, 6);
    });

    test("Endlos-Quiz: eine bestehende Karte bleibt unverändert", () {
      final entry = PericopeMerges.ids.entries.first;
      final cards = {
        entry.key: LearningCard(id: entry.key, stability: 2),
        entry.value.first: LearningCard(id: entry.value.first, stability: 9),
      };
      PericopeIdMigration.perikopeCards(cards);
      expect(cards[entry.key]!.stability, 2);
    });

    test("Bücher lernen: Karte ja, Präzisierung eines Teils nein", () {
      // Ex 25,1–40 enthält jetzt auch Lade, Tisch und Leuchter.
      const kept = "Ex|das_heiligtum_und_seine_geraete|25,1";
      final merged = PericopeMerges.keys[kept];
      expect(merged, isNotNull);
      expect(PericopeMerges.widened[kept], [25, 1, 25, 9]);
      final data = BookLearningData.fromDocuments(
        books: {
          "cards": {
            merged!.first: {
              "s": 5.0,
              "d": 4.0,
              "r": DateTime(2026, 10, 20).millisecondsSinceEpoch,
              "n": 1,
            },
          },
        },
        precision: {
          "items": {
            kept: {
              "startChapter": 25,
              "startVerse": 1,
              "endChapter": 25,
              "endVerse": 9,
            },
          },
        },
      );
      expect(data.cards[kept], isNotNull);
      expect(data.cards[kept]!.toJson(), data.cards[merged.first]!.toJson());
      expect(data.precisions.containsKey(kept), isFalse);
    });

    test("Bücher lernen: eigene Karte des ersten Teils bleibt", () {
      const kept = "Ex|das_heiligtum_und_seine_geraete|25,1";
      final from = PericopeMerges.keys[kept]!.first;
      final data = BookLearningData.fromDocuments(
        books: {
          "cards": {
            kept: {"s": 1.0, "d": 5.0, "n": 0},
            from: {"s": 9.0, "d": 3.0, "n": 3},
          },
        },
      );
      expect(data.cards[kept]!.stability, 1.0);
    });
  });
}
