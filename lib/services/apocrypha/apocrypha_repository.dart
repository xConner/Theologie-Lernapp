import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/apocrypha/apocrypha.dart';
import '../../models/bible/bible_text.dart';
import '../bible/bible_text_source.dart';

/// Filter der Übersicht. Leere Werte filtern nicht.
class ApocryphaFilter {
  final String? category;
  final Tradition? tradition;
  final ApocryphaEpoch? epoch;

  /// Sprache einer Fassung mit Text in der App.
  final String? language;

  /// Nur Werke mit Text in der App.
  final bool textOnly;

  /// Nur Werke mit Text in der Originalsprache (bzw. der ältesten
  /// erhaltenen Sprache).
  final bool originalOnly;

  /// Mindestzahl neuzeitlicher Übersetzungen mit Text.
  final int minTranslations;

  /// Nur Werke, die vollständig erhalten sind und vollständig in einer
  /// Fassung vorliegen.
  final bool completeOnly;

  /// Nur Werke, die nur fragmentarisch erhalten sind.
  final bool fragmentaryOnly;

  const ApocryphaFilter({
    this.category,
    this.tradition,
    this.epoch,
    this.language,
    this.textOnly = false,
    this.originalOnly = false,
    this.minTranslations = 0,
    this.completeOnly = false,
    this.fragmentaryOnly = false,
  });

  bool get isEmpty =>
      category == null &&
      tradition == null &&
      epoch == null &&
      language == null &&
      !textOnly &&
      !originalOnly &&
      minTranslations == 0 &&
      !completeOnly &&
      !fragmentaryOnly;

  /// Filter ohne Kategorie (die Übersicht zeigt Kategorien eigens).
  bool get isEmptyBesidesCategory => ApocryphaFilter(
    tradition: tradition,
    epoch: epoch,
    language: language,
    textOnly: textOnly,
    originalOnly: originalOnly,
    minTranslations: minTranslations,
    completeOnly: completeOnly,
    fragmentaryOnly: fragmentaryOnly,
  ).isEmpty;

  bool matches(ApocryphaWork w) =>
      (category == null || w.categories.contains(category)) &&
      (tradition == null || w.tradition == tradition) &&
      (epoch == null || epoch!.overlaps(w.dating)) &&
      (language == null || w.textLanguages.contains(language)) &&
      (!textOnly || w.hasText) &&
      (!originalOnly || w.hasOriginalText) &&
      w.translationCount >= minTranslations &&
      (!completeOnly ||
          (w.preservation == Preservation.complete && w.hasCompleteText)) &&
      (!fragmentaryOnly ||
          w.preservation == Preservation.fragmentary ||
          w.preservation == Preservation.lost);

  ApocryphaFilter copyWith({
    Object? category = _keep,
    Object? tradition = _keep,
    Object? epoch = _keep,
    Object? language = _keep,
    bool? textOnly,
    bool? originalOnly,
    int? minTranslations,
    bool? completeOnly,
    bool? fragmentaryOnly,
  }) => ApocryphaFilter(
    category: identical(category, _keep) ? this.category : category as String?,
    tradition: identical(tradition, _keep)
        ? this.tradition
        : tradition as Tradition?,
    epoch: identical(epoch, _keep) ? this.epoch : epoch as ApocryphaEpoch?,
    language: identical(language, _keep) ? this.language : language as String?,
    textOnly: textOnly ?? this.textOnly,
    originalOnly: originalOnly ?? this.originalOnly,
    minTranslations: minTranslations ?? this.minTranslations,
    completeOnly: completeOnly ?? this.completeOnly,
    fragmentaryOnly: fragmentaryOnly ?? this.fragmentaryOnly,
  );

  static const Object _keep = Object();
}

/// Suche im Katalog: Titel, andere Titel, Zuschreibung, Gattung, Übersetzer
/// und Herausgeber der Fassungen.
class ApocryphaSearch {
  ApocryphaSearch._();

  static String fold(String s) => s
      .toLowerCase()
      .replaceAll("ä", "a")
      .replaceAll("ö", "o")
      .replaceAll("ü", "u")
      .replaceAll("ß", "ss")
      .replaceAll(RegExp(r"[^\p{L}\p{N} ]", unicode: true), " ")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();

  static String _haystack(ApocryphaWork w) => [
    w.title,
    ...w.altTitles,
    w.genre,
    w.attribution?.name ?? "",
    for (final v in w.versions) ...[
      v.label,
      v.translator ?? "",
      v.editor ?? "",
    ],
  ].join(" ");

  static List<ApocryphaWork> works(
    ApocryphaCatalog catalog,
    String query,
    ApocryphaFilter filter,
  ) {
    final words = fold(query).split(" ").where((w) => w.isNotEmpty).toList();
    final found = <ApocryphaWork>[];

    for (final w in catalog.works) {
      if (!filter.matches(w)) continue;
      if (words.isNotEmpty) {
        final text = fold(_haystack(w));
        if (!words.every(text.contains)) continue;
      }
      found.add(w);
    }

    // Treffer im Titel zuerst, sonst Reihenfolge des Katalogs (nach
    // Gruppen und Entstehungszeit).
    if (words.isNotEmpty) {
      int score(ApocryphaWork w) {
        final title = fold([w.title, ...w.altTitles].join(" "));
        return words.every(title.contains) ? 0 : 1;
      }

      final order = {for (var i = 0; i < found.length; i++) found[i]: i};
      found.sort((a, b) {
        final s = score(a).compareTo(score(b));
        return s != 0 ? s : order[a]!.compareTo(order[b]!);
      });
    }

    return found;
  }
}

/// Treffer der Volltextsuche.
class FullTextHit {
  final ApocryphaWork work;
  final ApocryphaVersion version;
  final TocUnit unit;
  final TextBlock block;

  const FullTextHit(this.work, this.version, this.unit, this.block);
}

/// Zugriff auf `assets/apocrypha/` (siehe `docs/apocrypha.md`).
///
/// Geladen wird erst, was gebraucht wird: der Katalog beim Öffnen des
/// Bereichs, das Inhaltsverzeichnis einer Fassung beim Lesen und der Text
/// dateiweise. Textdateien werden nur begrenzt im Speicher gehalten.
/// Fassungen aus dem Bibelbereich lesen ihren Text über
/// [AssetBibleTextSource] aus `assets/bible/`.
class ApocryphaRepository {
  static const String root = "assets/apocrypha";

  static final ApocryphaRepository instance = ApocryphaRepository();

  /// Nur für Tests ersetzbar; standardmäßig das Bundle der App.
  final AssetBundle? bundle;

  ApocryphaRepository({this.bundle});

  AssetBundle get _assets => bundle ?? rootBundle;

  late final AssetBibleTextSource _bible = AssetBibleTextSource(bundle: bundle);

  final Map<String, Future<Object?>> _cache = {};

  /// So viele Text- bzw. Bibeldateien bleiben im Speicher.
  static const int cachedChunks = 12;

  /// Geladene Dateien in Ladereihenfolge (für Tests).
  final List<String> loadedAssets = [];

  static bool _isLarge(String key) =>
      RegExp(r"\.\d+\.json$").hasMatch(key) || key.startsWith("bible:");

  Future<Object?> _cached(String key, Future<Object?> Function() load) {
    final cached = _cache[key];
    if (cached != null) return cached;

    final future = load();
    _cache[key] = future;

    if (_isLarge(key)) {
      final large = _cache.keys.where(_isLarge).toList();
      for (final old in large.take(
        (large.length - cachedChunks).clamp(0, large.length),
      )) {
        _cache.remove(old);
      }
    }

    // Fehler nicht behalten: beim nächsten Aufruf erneut versuchen.
    future.catchError((Object _) {
      if (identical(_cache[key], future)) _cache.remove(key);
      return null;
    });

    return future;
  }

  Future<Object?> _json(String path) => _cached(path, () async {
    final data = await _assets.loadString(path, cache: false);
    loadedAssets.add(path);
    return jsonDecode(data);
  });

  Future<ApocryphaCatalog>? _catalog;

  Future<ApocryphaCatalog> catalog() {
    final future = _catalog ??= _json("$root/catalog.json").then(
      (json) =>
          ApocryphaCatalog.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    future.catchError((Object _) {
      if (identical(_catalog, future)) _catalog = null;
      return ApocryphaCatalog(categories: [], sources: {}, works: []);
    });
    return future;
  }

  Future<List<TocUnit>> toc(String versionId) async {
    final json = await _json("$root/texts/$versionId.toc.json") as Map;
    return [
      for (final u in json["units"] as List)
        TocUnit.fromJson(Map<String, dynamic>.from(u as Map)),
    ];
  }

  /// Text einer Einheit.
  Future<UnitText> unit(String versionId, TocUnit unit) async {
    final bible = unit.bible;
    if (bible != null) return _bibleUnit(unit.id, bible);

    final json =
        await _json("$root/texts/$versionId.${unit.chunk}.json") as Map;
    for (final u in json["units"] as List) {
      if ((u as Map)["id"] == unit.id) {
        return UnitText.fromJson(Map<String, dynamic>.from(u));
      }
    }
    throw StateError("Einheit ${unit.id} fehlt in $versionId");
  }

  Future<UnitText> _bibleUnit(String id, BibleSpan span) async {
    final book =
        await _cached(
              "bible:${span.translation}/${span.book}",
              () => _bible.loadBook(span.translation, span.book),
            )
            as BibleBookText;
    final chapter = book.chapter(span.chapter);
    final blocks = <TextBlock>[];
    if (chapter != null) {
      for (final v in chapter.verses) {
        if (v.number < span.firstVerse || v.number > span.lastVerse) continue;
        // Nach einer Zwischenüberschrift fortgesetzte Verse zusammenfügen.
        if (v.continuation &&
            blocks.isNotEmpty &&
            blocks.last.number == v.displayNumber) {
          final last = blocks.removeLast();
          blocks.add(TextBlock(last.number, "${last.text} ${v.text}"));
          continue;
        }
        blocks.add(TextBlock(v.displayNumber, v.text));
      }
    }
    return UnitText(id, blocks);
  }

  /// Sucht [query] im Wortlaut der Fassungen mit eigenem Text (nicht in den
  /// Septuaginta- und Vulgatafassungen, die die Bibelsuche abdeckt). Lädt
  /// die Textdateien nacheinander und liefert höchstens [limit] Treffer.
  Stream<FullTextHit> fullText(
    String query, {
    String? language,
    Iterable<ApocryphaWork>? works,
    int limit = 200,
  }) async* {
    final needle = ApocryphaSearch.fold(query);
    if (needle.length < 3) return;

    final catalog = await this.catalog();
    var count = 0;

    for (final w in works ?? catalog.works) {
      for (final v in w.versions) {
        if (!v.hasText || v.fromBible) continue;
        if (language != null && v.language != language) continue;

        final units = await toc(v.id);
        final chunks = {for (final u in units) ?u.chunk};
        for (final c in chunks) {
          final json = await _json("$root/texts/${v.id}.$c.json") as Map;
          for (final raw in json["units"] as List) {
            final text = UnitText.fromJson(
              Map<String, dynamic>.from(raw as Map),
            );
            final unit = units.firstWhere((u) => u.id == text.id);
            for (final b in text.blocks) {
              if (ApocryphaSearch.fold(b.text).contains(needle)) {
                yield FullTextHit(w, v, unit, b);
                if (++count >= limit) return;
              }
            }
          }
        }
      }
    }
  }
}
