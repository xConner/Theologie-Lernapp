import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/fathers/fathers.dart';

/// Katalog der Bibliothek: Autoren und Werke mit ihren Fassungen, ohne Text.
class FathersLibrary {
  final List<FathersAuthor> authors;
  final List<FathersWork> works;

  late final Map<String, FathersAuthor> _authors = {
    for (final a in authors) a.id: a,
  };

  late final Map<String, FathersWork> _works = {for (final w in works) w.id: w};

  late final Map<String, ({FathersWork work, WorkVersion version})> _versions =
      {
        for (final w in works)
          for (final v in w.versions) v.id: (work: w, version: v),
      };

  FathersLibrary({required this.authors, required this.works});

  FathersAuthor? author(String id) => _authors[id];

  FathersWork? work(String id) => _works[id];

  ({FathersWork work, WorkVersion version})? version(String id) =>
      _versions[id];

  List<FathersWork> worksOf(String authorId) => [
    for (final w in works)
      if (w.authorId == authorId) w,
  ];

  factory FathersLibrary.fromJson(Map<String, dynamic> json) {
    return FathersLibrary(
      authors: [
        for (final a in json["authors"] as List)
          FathersAuthor.fromJson(Map<String, dynamic>.from(a as Map)),
      ],
      works: [
        for (final w in json["works"] as List)
          FathersWork.fromJson(Map<String, dynamic>.from(w as Map)),
      ],
    );
  }
}

/// Zugriff auf die Daten unter `assets/fathers/` (siehe
/// `docs/church-fathers.md`).
///
/// Alles wird erst geladen, wenn es gebraucht wird, und danach im
/// Arbeitsspeicher gehalten: der Katalog beim Öffnen der Bibliothek, die
/// Zuordnungen eines Bibelbuchs beim ersten angetippten Vers dieses Buchs,
/// der Text eines Werks abschnittsweise beim Lesen. Schlägt ein Laden fehl,
/// wird es beim nächsten Aufruf erneut versucht.
class FathersRepository {
  static const String root = "assets/fathers";

  static final FathersRepository instance = FathersRepository();

  /// Nur für Tests ersetzbar; standardmäßig das Bundle der App.
  final AssetBundle? bundle;

  FathersRepository({this.bundle});

  AssetBundle get _assets => bundle ?? rootBundle;

  // Geladene Dateien in Ladereihenfolge (LinkedHashMap).
  final Map<String, Future<Object?>> _cache = {};

  /// So viele Textdateien bleiben im Speicher.
  static const int cachedChunks = 12;

  static bool _isChunk(String path) =>
      path.contains("/texts/") && RegExp(r"\.\d+\.json$").hasMatch(path);

  /// Geladene Dateien in Ladereihenfolge (für Tests und Diagnose).
  final List<String> loadedAssets = [];

  /// Liest [path] einmal. Welche Dateien es gibt, steht im Manifest; ein
  /// Fehler beim Laden ist deshalb immer ein Fehler (und wird beim nächsten
  /// Aufruf erneut versucht).
  Future<Object?> _json(String path) {
    final cached = _cache[path];

    if (cached != null) return cached;

    final future = () async {
      // Nicht im Asset-Cache halten: Geparst liegt es hier ohnehin vor.
      final data = await _assets.loadString(path, cache: false);

      loadedAssets.add(path);

      return jsonDecode(data);
    }();

    _cache[path] = future;

    // Textdateien sind groß: nur die zuletzt gelesenen behalten.
    if (_isChunk(path)) {
      final chunks = _cache.keys.where(_isChunk).toList();

      for (final old in chunks.take(
        (chunks.length - cachedChunks).clamp(0, chunks.length),
      )) {
        _cache.remove(old);
      }
    }

    future.catchError((Object _) {
      if (identical(_cache[path], future)) _cache.remove(path);

      return null;
    });

    return future;
  }

  Future<Map<String, dynamic>> manifest() async =>
      Map<String, dynamic>.from(await _json("$root/manifest.json") as Map);

  /// Bücher, für die es eine Datei unter [folder] gibt (laut Manifest).
  Future<bool> _hasFile(String folder, String bookId) async {
    final files = Map<String, dynamic>.from(
      (await manifest())["files"] as Map? ?? const {},
    );

    return (files[folder] as List? ?? const []).contains(bookId);
  }

  Future<FathersLibrary>? _library;

  Future<FathersLibrary> library() {
    return _library ??= _json("$root/library.json")
        .then(
          (data) =>
              FathersLibrary.fromJson(Map<String, dynamic>.from(data as Map)),
        )
        .catchError((Object error) {
          _library = null;
          throw error;
        });
  }

  final Map<String, Future<List<PassageLink>>> _links = {};

  /// Alle Zuordnungen zu Stellen in Buch [bookId] (deutsche Zählung).
  Future<List<PassageLink>> linksForBook(String bookId) {
    return _links[bookId] ??=
        () async {
          if (!await _hasFile("links", bookId)) return const <PassageLink>[];

          final data = await _json("$root/links/$bookId.json");

          return [
            for (final l in (data as Map)["links"] as List)
              PassageLink.fromJson(bookId, Map<String, dynamic>.from(l as Map)),
          ];
        }().catchError((Object error) {
          _links.remove(bookId);
          throw error;
        });
  }

  /// Zuordnungen, die Vers [verse] in Kapitel [chapter] berühren.
  Future<List<PassageLink>> linksForVerse(
    String bookId,
    int chapter,
    int verse,
  ) async {
    final links = await linksForBook(bookId);

    return [
      for (final l in links)
        if (l.touches(chapter, verse)) l,
    ];
  }

  /// Zuordnungen, die sich mit [range] überschneiden (z. B. eine Perikope).
  Future<List<PassageLink>> linksForRange(BibleReference range) async {
    final links = await linksForBook(range.bookId);

    return [
      for (final l in links)
        if (l.overlaps(range)) l,
    ];
  }

  /// Alle Zuordnungen einer Fassung, z. B. für „Bibelstellen im Werk“.
  Future<List<PassageLink>> linksOfVersion(String versionId) async {
    final data = await _json("$root/texts/$versionId.links.json");

    return [
      for (final l in (data as Map)["links"] as List)
        PassageLink.fromJson(
          (l as Map)["b"] as String,
          Map<String, dynamic>.from(l),
        ),
    ];
  }

  Future<WorkTableOfContents> tableOfContents(String versionId) async {
    final data = await _json("$root/texts/$versionId.toc.json");

    return WorkTableOfContents.fromJson(
      versionId,
      Map<String, dynamic>.from(data as Map),
    );
  }

  /// Der Text von Abschnitt [number]; lädt nur die Datei, die ihn enthält.
  Future<WorkSection?> section(String versionId, int number) async {
    final toc = await tableOfContents(versionId);

    final entry = toc.entry(number);

    if (entry == null) return null;

    final data = await _json("$root/texts/$versionId.${entry.chunk}.json");

    for (final s in (data as Map)["sections"] as List) {
      final section = Map<String, dynamic>.from(s as Map);

      if ((section["n"] as num).toInt() == number) {
        return WorkSection.fromJson(section);
      }
    }

    return null;
  }

  /// Durchsucht den Text einer Fassung nach [query] (ohne Groß- und
  /// Kleinschreibung). Lädt dazu alle Textdateien der Fassung; [limit]
  /// begrenzt die Zahl der Treffer.
  Future<List<TextHit>> searchVersion(
    String versionId,
    String query, {
    int limit = 200,
  }) async {
    final needle = foldForSearch(query.trim());

    if (needle.length < 3) return const [];

    final toc = await tableOfContents(versionId);

    final hits = <TextHit>[];

    final chunks = {for (final s in toc.sections) s.chunk}.toList()..sort();

    for (final chunk in chunks) {
      final data = await _json("$root/texts/$versionId.$chunk.json");

      for (final s in (data as Map)["sections"] as List) {
        final section = WorkSection.fromJson(
          Map<String, dynamic>.from(s as Map),
        );

        for (int i = 0; i < section.paragraphs.length; i++) {
          final text = section.paragraphs[i];
          final at = foldForSearch(text).indexOf(needle);

          if (at < 0) continue;

          hits.add(
            TextHit(
              versionId: versionId,
              section: section.number,
              paragraph: i,
              snippet: _snippet(text, at, needle.length),
            ),
          );

          if (hits.length >= limit) return hits;
        }
      }
    }

    return hits;
  }

  /// Querverweise von OpenBible.info für Buch [bookId]: „Kapitel:Vers“ →
  /// Ziele `[Buchindex, Kapitel, Vers, Endkapitel, Endvers, Stimmen]`.
  Future<({List<String> books, Map<String, List<List<int>>> refs})>
  _crossRefData(String bookId) async {
    if (!await _hasFile("xrefs", bookId)) {
      return (books: const <String>[], refs: const <String, List<List<int>>>{});
    }

    final data = await _json("$root/xrefs/$bookId.json");

    final map = Map<String, dynamic>.from(data as Map);

    return (
      books: (map["books"] as List).cast<String>(),
      refs: {
        for (final e in Map<String, dynamic>.from(map["refs"] as Map).entries)
          e.key: [
            for (final t in e.value as List)
              (t as List).cast<num>().map((n) => n.toInt()).toList(),
          ],
      },
    );
  }

  /// Verwandte Stellen zu einem Vers (deutsche Zählung), nach Bewertung
  /// sortiert.
  Future<List<CrossReference>> crossReferences(
    String bookId,
    int chapter,
    int verse,
  ) async {
    final data = await _crossRefData(bookId);

    final targets = data.refs["$chapter:$verse"] ?? const <List<int>>[];

    return [
      for (final t in targets)
        CrossReference(
          target: BibleReference(
            bookId: data.books[t[0]],
            chapter: t[1],
            verse: t[2],
            endChapter: t[3],
            endVerse: t[4] == t[2] && t[3] == t[1] ? null : t[4],
          ),
          kind: CrossRefKind.related,
          votes: t[5],
          source: "OpenBible.info",
        ),
    ];
  }

  static String _snippet(String text, int at, int length) {
    final start = (at - 60).clamp(0, text.length);
    final end = (at + length + 80).clamp(0, text.length);

    return "${start > 0 ? "…" : ""}${text.substring(start, end).trim()}"
        "${end < text.length ? "…" : ""}";
  }

  /// Vergleichsform für die Suche: nur Kleinschreibung, damit die
  /// Positionen im Text gleich bleiben.
  static String foldForSearch(String text) => text.toLowerCase();
}

class TextHit {
  final String versionId;
  final int section;
  final int paragraph;
  final String snippet;

  const TextHit({
    required this.versionId,
    required this.section,
    required this.paragraph,
    required this.snippet,
  });
}
