import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:theologie_lernapp/services/fathers/fathers_repository.dart';

import '../test_asset_bundle.dart';

/// Kleine, erfundene Testdaten im Format von `assets/fathers/` (siehe
/// `tool/fathers/README.md`). Sie prüfen nur die Technik; die echten Daten
/// prüft `fathers_data_test.dart`.
const String root = FathersRepository.root;

final Map<String, Object> fixtureFiles = {
  "$root/manifest.json": {
    "files": {
      "links": ["JHN"],
      "xrefs": ["JHN"],
    },
  },
  "$root/library.json": {
    "authors": [
      {
        "id": "autor_a",
        "name": "Testautor A",
        "aliases": ["Auctor A"],
        "category": "churchFather",
        "lifeDates": "354–430",
        "deathYear": 430,
        "languages": ["la"],
      },
      {
        "id": "autor_b",
        "name": "Testautor B",
        "category": "churchFather",
        "lifeDates": "um 349–407",
        "deathYear": 407,
        "languages": ["grc"],
      },
      {
        "id": "reformator",
        "name": "Testreformator",
        "category": "reformer",
        "deathYear": 1546,
        "languages": ["de"],
      },
    ],
    "works": [
      {
        "id": "werk_a",
        "author": "autor_a",
        "title": "Vorträge über Johannes",
        "clavis": "CPL 0000",
        "genre": "Homilien",
        "originalLanguage": "la",
        "versions": [
          {
            "id": "werk_a.de",
            "title": "Vorträge über Johannes (Testausgabe)",
            "translator": "Ü. Bersetzer",
            "series": "Testreihe, Band 1",
            "year": "1913",
            "sourceName": "Testquelle",
            "sourceUrl": "https://example.org/werk_a",
            "rights": "publicDomain",
            "rightsNote": "Übersetzer † 1918",
            "availability": "full",
            "sections": 3,
            "links": 3,
            "books": ["JHN"],
          },
        ],
      },
      {
        "id": "werk_b",
        "author": "autor_b",
        "title": "Homilien über Johannes",
        "genre": "Homilien",
        "originalLanguage": "grc",
        "versions": [
          {
            "id": "werk_b.de",
            "title": "Homilien (geschützte Übersetzung)",
            "translator": "Spät Verstorben",
            "rights": "unclear",
            "rightsNote": "Übersetzer † 1962",
            "availability": "external",
            "sourceUrl": "https://example.org/werk_b",
          },
        ],
      },
      {
        "id": "werk_c",
        "author": "reformator",
        "title": "Katechismus",
        "genre": "Katechismus",
        "versions": [
          {
            "id": "werk_c.app",
            "title": "Katechismus",
            "appLink": "confession:kleiner_katechismus",
          },
        ],
      },
    ],
  },
  "$root/links/JHN.json": {
    "links": [
      {
        "id": "l1",
        "v": "werk_a.de",
        "w": "werk_a",
        "a": "autor_a",
        "s": 1,
        "p": [0, 1],
        "r": [1, 1, 1, 5],
        "k": "sectionCommentary",
        "m": "editionHeading",
        "c": "high",
        "cited": "Joh. 1, 1–5",
      },
      {
        "id": "l2",
        "v": "werk_a.de",
        "w": "werk_a",
        "a": "autor_a",
        "s": 1,
        "p": [1, 1],
        "r": [1, 1],
        "k": "quotation",
        "m": "editionCitation",
        "c": "high",
        "cited": "Joh. 1, 1",
      },
      {
        "id": "l3",
        "v": "werk_a.de",
        "w": "werk_a",
        "a": "autor_a",
        "s": 2,
        "p": [0, 0],
        "r": [3, 16],
        "k": "quotation",
        "m": "editionCitation",
        "c": "medium",
        "cited": "Joh. 3, 16",
      },
    ],
  },
  "$root/xrefs/JHN.json": {
    "books": ["GEN", "JHN"],
    "refs": {
      "1:1": [
        [0, 1, 1, 1, 1, 59],
        [1, 1, 14, 1, 14, 20],
      ],
    },
  },
  "$root/texts/werk_a.de.toc.json": {
    "sections": [
      {"n": 1, "t": "1. Vortrag", "c": 0, "ref": "Joh. 1, 1–5"},
      {"n": 2, "t": "2. Vortrag", "c": 0},
      {"n": 3, "t": "3. Vortrag", "c": 1},
    ],
  },
  "$root/texts/werk_a.de.0.json": {
    "sections": [
      {
        "n": 1,
        "p": [
          "Erster Absatz über das Wort.",
          "Im Anfang war das Wort, sagt der Evangelist.",
          "Dritter Absatz.",
        ],
        "notes": ["Joh. 1, 1."],
      },
      {
        "n": 2,
        "p": ["Also hat Gott die Welt geliebt."],
      },
    ],
  },
  "$root/texts/werk_a.de.1.json": {
    "sections": [
      {
        "n": 3,
        "p": ["Ein Absatz in einer zweiten Datei mit dem Suchwort Leuchte."],
      },
    ],
  },
  "$root/texts/werk_a.de.links.json": {
    "links": [
      {
        "id": "l1",
        "b": "JHN",
        "v": "werk_a.de",
        "w": "werk_a",
        "a": "autor_a",
        "s": 1,
        "p": [0, 1],
        "r": [1, 1, 1, 5],
        "k": "sectionCommentary",
        "m": "editionHeading",
        "c": "high",
      },
      {
        "id": "l3",
        "b": "JHN",
        "v": "werk_a.de",
        "w": "werk_a",
        "a": "autor_a",
        "s": 2,
        "p": [0, 0],
        "r": [3, 16],
        "k": "quotation",
        "m": "editionCitation",
        "c": "medium",
      },
    ],
  },
};

/// Liefert [fixtureFiles] für `assets/fathers/`, alles andere (Bibeltexte,
/// Perikopen) von der Platte. Zählt Ladevorgänge und kann Fehler vortäuschen.
class FixtureBundle extends FileAssetBundle {
  final Map<String, Object> files;

  /// Diese Pfade schlagen fehl, solange sie hier stehen.
  final Set<String> failing = {};

  final List<String> requests = [];

  FixtureBundle([Map<String, Object>? files]) : files = files ?? fixtureFiles;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (!key.startsWith(root)) return super.loadString(key, cache: cache);

    requests.add(key);

    if (failing.contains(key)) throw FlutterError("Ladefehler: $key");

    final data = files[key];

    if (data == null) throw FlutterError("Asset fehlt: $key");

    return jsonEncode(data);
  }
}
