import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/exam/greek_morph_analysis.dart';
import 'greek_form_key.dart';

/// Dateiformat der Klausurkorpora unter `assets/greek_corpus/` (erzeugt von
/// `tool/greek_exam_corpus`, gelesen von der App). Ohne Flutter-Abhängigkeit,
/// damit Import und App denselben Code verwenden.
///
/// `<korpus>/index.json` – je Vers Wortzahl, Satzgrenzen, erkannte Phänomene
/// und Grundformen; damit sucht die App passende Abschnitte, ohne die Texte
/// zu laden:
///
/// ```json
/// {"version": 1, "phenomena": ["verb.mood.indicative", …],
///  "lemmas": ["ἀρχή", …],
///  "books": [{"id": "JHN", "chapters": [[
///    ["1", 12, 1, "<sicher>", "<möglich>", 0, "<Grundformen>"], …]]}]}
/// ```
///
/// Verseintrag: Versbezeichnung, Wortzahl, Flags (1 = Absatzbeginn, 2 = Vers
/// endet mit Satzende), sicher und möglicherweise belegte Phänomene (Bitmenge
/// zur Reihenfolge von `phenomena`, siehe [PhenomenonSet]; `null` = wie
/// sicher), Zahl der unbestimmten Wörter, Grundformen der bestimmten Wörter
/// ([encodeLemmaGroups]).
///
/// `<korpus>/<BUCH>.json` – Text und Bestimmungen:
///
/// ```json
/// {"id": "JHN", "codes": ["V-3IAI-S--", …], "sets": ["!0:2", "4:1 4:3", "~", ""],
///  "chapters": [[{"v": "1", "t": "Ἐν ἀρχῇ ἦν ὁ λόγος, …", "a": "0.1.2"}]]}
/// ```
///
/// `t` ist der Verstext, `a` je Wort (`splitGreekWords`) die Nummer einer
/// Bestimmungsmenge aus `sets`: Paare `Grundform:Code` (Grundform als Nummer
/// in `lemmas` des Index, Code als Nummer in `codes`), mit `!` davor, wenn
/// die erste Bestimmung im Kontext gesichert ist; `~` = vermutlich Eigenname;
/// leer = unbestimmt. Alle Zahlen zur Basis 36.
class CorpusCodec {
  CorpusCodec._();

  static const int formatVersion = 1;

  static const int flagParagraph = 1;
  static const int flagSentenceEnd = 2;

  /// Bestimmung einer vermutlich als Eigenname erkannten Form.
  static const String properNameCode = "N---------";

  static String encodeInt(int value) => value.toRadixString(36);

  static int decodeInt(String value) => int.parse(value, radix: 36);

  static String encodeInts(Iterable<int> values) =>
      values.map(encodeInt).join(".");

  static List<int> decodeInts(String value) {
    if (value.isEmpty) return const [];
    return [for (final part in value.split(".")) decodeInt(part)];
  }

  // ---------------------------------------------------------------------------
  // BESTIMMUNGSMENGEN
  // ---------------------------------------------------------------------------

  /// [pairs]: (Grundform-Nummer, Code-Nummer).
  static String encodeSet(
    AnalysisReliability reliability,
    List<(int, int)> pairs,
  ) {
    switch (reliability) {
      case AnalysisReliability.unanalyzed:
        return "";
      case AnalysisReliability.properNameGuess:
        return "~";
      case AnalysisReliability.contextual:
      case AnalysisReliability.formal:
        final body = pairs
            .map((p) => "${encodeInt(p.$1)}:${encodeInt(p.$2)}")
            .join(" ");
        return reliability == AnalysisReliability.contextual
            ? "!$body"
            : body;
    }
  }

  static CorpusToken decodeToken(
    String surface,
    String set,
    List<String> lemmas,
    List<String> codes,
  ) {
    if (set.isEmpty) {
      return CorpusToken(surface, const [], AnalysisReliability.unanalyzed);
    }

    if (set == "~") {
      final word = CorpusToken(surface, const [], AnalysisReliability.unanalyzed)
          .word;

      return CorpusToken(surface, [
        LemmaAnalysis(word, const GreekMorphAnalysis(properNameCode)),
      ], AnalysisReliability.properNameGuess);
    }

    final contextual = set.startsWith("!");
    final body = contextual ? set.substring(1) : set;

    final analyses = <LemmaAnalysis>[
      for (final pair in body.split(" "))
        if (pair.contains(":"))
          LemmaAnalysis(
            lemmas[decodeInt(pair.split(":")[0])],
            GreekMorphAnalysis(codes[decodeInt(pair.split(":")[1])]),
          ),
    ];

    return CorpusToken(
      surface,
      analyses,
      contextual ? AnalysisReliability.contextual : AnalysisReliability.formal,
    );
  }

  // ---------------------------------------------------------------------------
  // GRUNDFORMEN EINES VERSES
  // ---------------------------------------------------------------------------

  /// Je bestimmtem Wort die möglichen Grundformen (Nummern), ohne
  /// Wiederholung gleicher Gruppen: `3.17|4|9` = Wort mit Grundform 3 oder
  /// 17, Wort mit 4, Wort mit 9.
  static String encodeLemmaGroups(Iterable<List<int>> groups) {
    final seen = <String>{};

    for (final group in groups) {
      if (group.isEmpty) continue;
      seen.add(encodeInts(group.toSet().toList()..sort()));
    }

    return seen.join("|");
  }

  static List<List<int>> decodeLemmaGroups(String value) {
    if (value.isEmpty) return const [];
    return [for (final group in value.split("|")) decodeInts(group)];
  }
}

/// Menge von Phänomenen als Bitfeld in Blöcken zu 30 Bit (auch im Web,
/// wo Bitoperationen auf 32 Bit beschränkt sind, sicher).
class PhenomenonSet {
  static const int _bits = 30;

  final List<int> chunks;

  const PhenomenonSet(this.chunks);

  static const PhenomenonSet empty = PhenomenonSet([]);

  factory PhenomenonSet.of(Iterable<int> indices) {
    final chunks = <int>[];

    for (final index in indices) {
      final chunk = index ~/ _bits;

      while (chunks.length <= chunk) {
        chunks.add(0);
      }

      chunks[chunk] |= 1 << (index % _bits);
    }

    return PhenomenonSet(chunks);
  }

  bool contains(int index) {
    final chunk = index ~/ _bits;
    return chunk < chunks.length && (chunks[chunk] & (1 << (index % _bits))) != 0;
  }

  bool get isEmpty => chunks.every((c) => c == 0);

  PhenomenonSet union(PhenomenonSet other) {
    final length = chunks.length > other.chunks.length
        ? chunks.length
        : other.chunks.length;

    return PhenomenonSet([
      for (var i = 0; i < length; i++)
        (i < chunks.length ? chunks[i] : 0) |
            (i < other.chunks.length ? other.chunks[i] : 0),
    ]);
  }

  Iterable<int> get indices sync* {
    for (var c = 0; c < chunks.length; c++) {
      for (var b = 0; b < _bits; b++) {
        if ((chunks[c] & (1 << b)) != 0) yield c * _bits + b;
      }
    }
  }

  String encode() {
    var end = chunks.length;
    while (end > 0 && chunks[end - 1] == 0) {
      end--;
    }
    return CorpusCodec.encodeInts(chunks.take(end));
  }

  static PhenomenonSet decode(String value) =>
      PhenomenonSet(CorpusCodec.decodeInts(value));

  @override
  bool operator ==(Object other) =>
      other is PhenomenonSet && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Indexeintrag eines Verses.
class VerseInfo {
  final String label;
  final int wordCount;
  final bool paragraphStart;
  final bool endsSentence;
  final PhenomenonSet certain;
  final PhenomenonSet possible;
  final int unanalyzed;
  final List<List<int>> lemmaGroups;

  const VerseInfo({
    required this.label,
    required this.wordCount,
    required this.paragraphStart,
    required this.endsSentence,
    required this.certain,
    required this.possible,
    required this.unanalyzed,
    required this.lemmaGroups,
  });

  factory VerseInfo.fromJson(List<dynamic> json) {
    final flags = json[2] as int;
    final certain = PhenomenonSet.decode(json[3] as String);
    final possible = json[4];

    return VerseInfo(
      label: json[0] as String,
      wordCount: json[1] as int,
      paragraphStart: flags & CorpusCodec.flagParagraph != 0,
      endsSentence: flags & CorpusCodec.flagSentenceEnd != 0,
      certain: certain,
      possible: possible is String ? PhenomenonSet.decode(possible) : certain,
      unanalyzed: json[5] as int,
      lemmaGroups: CorpusCodec.decodeLemmaGroups(json[6] as String),
    );
  }

  List<dynamic> toJson() {
    final certainCode = certain.encode();
    final possibleCode = possible.encode();

    return [
      label,
      wordCount,
      (paragraphStart ? CorpusCodec.flagParagraph : 0) |
          (endsSentence ? CorpusCodec.flagSentenceEnd : 0),
      certainCode,
      possibleCode == certainCode ? null : possibleCode,
      unanalyzed,
      CorpusCodec.encodeLemmaGroups(lemmaGroups),
    ];
  }
}

class ChapterInfo {
  final int number;
  final List<VerseInfo> verses;

  const ChapterInfo(this.number, this.verses);
}

class BookInfo {
  final String id;
  final List<ChapterInfo> chapters;

  const BookInfo(this.id, this.chapters);
}

/// Der Suchindex eines Korpus.
class CorpusIndex {
  final String corpusId;

  /// Phänomen-IDs in der Reihenfolge der Bits.
  final List<String> phenomena;
  final List<String> lemmas;
  final List<BookInfo> books;

  CorpusIndex({
    required this.corpusId,
    required this.phenomena,
    required this.lemmas,
    required this.books,
  }) : _bitOf = {for (var i = 0; i < phenomena.length; i++) phenomena[i]: i};

  final Map<String, int> _bitOf;

  /// Bit des Phänomens; `null`, wenn der Index es (noch) nicht erfasst.
  int? bitOf(String phenomenonId) => _bitOf[phenomenonId];

  BookInfo? book(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  factory CorpusIndex.fromJson(String corpusId, Map<String, dynamic> json) {
    return CorpusIndex(
      corpusId: corpusId,
      phenomena: List<String>.from(json["phenomena"] as List),
      lemmas: List<String>.from(json["lemmas"] as List),
      books: [
        for (final book in json["books"] as List)
          BookInfo(book["id"] as String, [
            for (final (i, chapter) in (book["chapters"] as List).indexed)
              ChapterInfo(i + 1, [
                for (final verse in chapter as List)
                  VerseInfo.fromJson(verse as List),
              ]),
          ]),
      ],
    );
  }
}

/// Ein Vers mit seinen Wortformen.
class CorpusVerse {
  final String label;
  final String text;
  final List<CorpusToken> tokens;

  const CorpusVerse(this.label, this.text, this.tokens);
}

/// Text und Bestimmungen eines Buchs.
class CorpusBook {
  final String id;

  /// Kapitel ab 1 (Index 0 = Kapitel 1).
  final List<List<CorpusVerse>> chapters;

  const CorpusBook(this.id, this.chapters);

  factory CorpusBook.fromJson(Map<String, dynamic> json, List<String> lemmas) {
    final codes = List<String>.from(json["codes"] as List);
    final sets = List<String>.from(json["sets"] as List);

    return CorpusBook(json["id"] as String, [
      for (final chapter in json["chapters"] as List)
        [
          for (final verse in chapter as List)
            _verse(verse as Map<String, dynamic>, sets, lemmas, codes),
        ],
    ]);
  }

  static CorpusVerse _verse(
    Map<String, dynamic> json,
    List<String> sets,
    List<String> lemmas,
    List<String> codes,
  ) {
    final text = json["t"] as String;
    final words = splitGreekWords(text);
    final ids = CorpusCodec.decodeInts(json["a"] as String);

    if (ids.length != words.length) {
      throw FormatException(
        "Vers ${json["v"]}: ${words.length} Wörter, ${ids.length} Bestimmungen",
      );
    }

    return CorpusVerse(json["v"] as String, text, [
      for (var i = 0; i < words.length; i++)
        CorpusCodec.decodeToken(words[i], sets[ids[i]], lemmas, codes),
    ]);
  }
}
