import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../models/greek/exam/text_corpus.dart';
import 'corpus_codec.dart';
import 'vocabulary_help.dart';

/// Zugriff auf die Klausurkorpora. Die ausgelieferten Daten liegen unter
/// `assets/greek_corpus/` ([AssetExamCorpusSource]); eine weitere Quelle
/// (z. B. selbst importierte Texte) implementiert diese Schnittstelle.
abstract class ExamCorpusSource {
  Future<List<TextCorpus>> loadCorpora();

  Future<CorpusIndex> loadIndex(String corpusId);

  Future<CorpusBook> loadBook(String corpusId, String bookId);

  Future<GreekLexicon> loadLexicon();
}

/// Liest `assets/greek_corpus/`. Verzeichnis, Indizes und Lexikon werden je
/// Sitzung einmal geladen, Bücher bis zu einer kleinen Anzahl
/// zwischengespeichert.
class AssetExamCorpusSource implements ExamCorpusSource {
  static const String root = "assets/greek_corpus";

  final AssetBundle? bundle;

  AssetExamCorpusSource({this.bundle});

  AssetBundle get _assets => bundle ?? rootBundle;

  static const int _cachedBooks = 4;

  Future<List<TextCorpus>>? _corpora;
  final Map<String, Future<CorpusIndex>> _indexes = {};
  final Map<String, Future<CorpusBook>> _books = {};
  Future<GreekLexicon>? _lexicon;

  Future<Map<String, dynamic>> _json(String path) async {
    final text = await _assets.loadString(path, cache: false);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  @override
  Future<List<TextCorpus>> loadCorpora() {
    return _corpora ??= _json("$root/corpora.json").then(
      (json) => [
        for (final c in json["corpora"] as List)
          TextCorpus.fromJson(c as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<CorpusIndex> loadIndex(String corpusId) {
    return _indexes.putIfAbsent(
      corpusId,
      () => _json(
        "$root/$corpusId/index.json",
      ).then((json) => CorpusIndex.fromJson(corpusId, json)),
    );
  }

  @override
  Future<CorpusBook> loadBook(String corpusId, String bookId) {
    final key = "$corpusId/$bookId";
    final cached = _books.remove(key);

    if (cached != null) {
      _books[key] = cached;
      return cached;
    }

    final future = () async {
      final index = await loadIndex(corpusId);
      final json = await _json("$root/$corpusId/$bookId.json");
      return CorpusBook.fromJson(json, index.lemmas);
    }();

    _books[key] = future;

    while (_books.length > _cachedBooks) {
      _books.remove(_books.keys.first);
    }

    return future;
  }

  @override
  Future<GreekLexicon> loadLexicon() {
    return _lexicon ??= _json("$root/lexicon.json").then(GreekLexicon.fromJson);
  }
}
