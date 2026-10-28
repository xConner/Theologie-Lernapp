import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/greek/exam/greek_morph_analysis.dart';
import '../../models/philosophy/reading_text.dart';
import '../greek/exam/corpus_codec.dart';
import '../greek/exam/greek_form_key.dart';
import '../greek/exam/vocabulary_help.dart';
import 'reading_repository.dart';

/// Mögliche Bestimmung eines Worts mit Bedeutungen der Grundform.
class WordCandidate {
  final String lemma;
  final List<GreekMorphAnalysis> analyses;

  /// Deutsche Bedeutungen aus dem Lexikon der App (mit Quelle).
  final LexiconEntry? lexicon;

  const WordCandidate(this.lemma, this.analyses, this.lexicon);
}

/// Ergebnis der Wortanalyse. Die Bestimmungen stammen aus einem
/// Formenindex (NT/LXX) und sind nie im Kontext der Physik geprüft: Sie
/// sind „möglich“, nicht „sicher“. Eindeutig ist nur, ob genau eine
/// Grundform in Frage kommt.
class WordAnalysis {
  final String surface;
  final String form;
  final List<WordCandidate> candidates;

  /// Glossareinträge der Ausgabe, deren Stichwort zur Form oder zu einer
  /// möglichen Grundform passt.
  final List<GlossaryEntry> glossary;

  const WordAnalysis({
    required this.surface,
    required this.form,
    required this.candidates,
    required this.glossary,
  });

  bool get isAnalyzed => candidates.isNotEmpty;

  String? get certainLemma =>
      candidates.length == 1 ? candidates.first.lemma : null;

  bool get ambiguous =>
      candidates.length > 1 ||
      (candidates.length == 1 && candidates.first.analyses.length > 1);
}

/// Wortanalyse für den Lesebereich: Formenindex des Werks
/// (`forms.json`), deutsches Lexikon des Klausurerstellers
/// (`assets/greek_corpus/lexicon.json`) und das Glossar der Ausgabe.
class GreekWordAnalyzer {
  final Map<String, String> forms;
  final List<String> lemmas;
  final List<String> codes;
  final GreekLexicon _lexicon;
  final List<GlossaryEntry> glossary;
  final Map<String, List<GlossaryEntry>> _glossaryByKey = {};

  GreekWordAnalyzer({
    required this.forms,
    required this.lemmas,
    required this.codes,
    GreekLexicon? lexicon,
    this.glossary = const [],
  }) : _lexicon = lexicon ?? GreekLexicon.empty {
    for (final g in glossary) {
      _glossaryByKey.putIfAbsent(glossaryKey(g.term), () => []).add(g);
    }
  }

  static const String lexiconAsset = "assets/greek_corpus/lexicon.json";

  static Future<GreekWordAnalyzer> load(
    ReadingRepository repository,
    ReadingText text, {
    AssetBundle? bundle,
  }) async {
    final forms = await repository.forms(text.work);
    GreekLexicon? lexicon;
    try {
      lexicon = GreekLexicon.fromJson(
        jsonDecode(
              await (bundle ?? rootBundle).loadString(lexiconAsset, cache: false),
            )
            as Map<String, dynamic>,
      );
    } on FlutterError {
      lexicon = null;
    }
    return GreekWordAnalyzer(
      forms: {
        for (final e in ((forms?["forms"] as Map?) ?? const {}).entries)
          e.key as String: e.value as String,
      },
      lemmas: List<String>.from((forms?["lemmas"] as List?) ?? const []),
      codes: List<String>.from((forms?["codes"] as List?) ?? const []),
      lexicon: lexicon,
      glossary: text.front.glossary,
    );
  }

  /// Wörter eines Satzes in Lesereihenfolge (mit Satzzeichen).
  static List<String> words(String sentence) => splitGreekWords(sentence);

  WordAnalysis analyze(String surface) {
    final form = greekFormKey(surface);
    final set = forms[form];
    final candidates = <WordCandidate>[];
    if (set != null && set.isNotEmpty) {
      final token = CorpusCodec.decodeToken(surface, set, lemmas, codes);
      final byLemma = <String, List<GreekMorphAnalysis>>{};
      for (final a in token.analyses) {
        byLemma.putIfAbsent(a.lemma, () => []).add(a.analysis);
      }
      for (final e in byLemma.entries) {
        candidates.add(WordCandidate(e.key, e.value, _lexicon[e.key]));
      }
    }
    final matches = <GlossaryEntry>[];
    final seen = <String>{};
    for (final key in {
      glossaryKey(transliterate(form)),
      for (final c in candidates) glossaryKey(transliterate(c.lemma)),
    }) {
      for (final g in _glossaryByKey[key] ?? const <GlossaryEntry>[]) {
        if (seen.add(g.id)) matches.add(g);
      }
    }
    return WordAnalysis(
      surface: surface,
      form: form,
      candidates: candidates,
      glossary: matches,
    );
  }

  /// Grundformen, die für eine Form in Frage kommen.
  Set<String> lemmasOf(String surface) {
    final set = forms[greekFormKey(surface)];
    if (set == null || set.isEmpty) return const {};
    return CorpusCodec.decodeToken(
      surface,
      set,
      lemmas,
      codes,
    ).candidateLemmas;
  }

  /// Sätze des Texts, in denen eine Form mit derselben (möglichen)
  /// Grundform bzw. – ohne Grundform – dieselbe Form vorkommt.
  List<GreekSentence> occurrences(
    ReadingText text, {
    String? lemma,
    required String form,
    int limit = 200,
  }) {
    final result = <GreekSentence>[];
    for (final chapter in text.chapters) {
      for (final s in chapter.sentences) {
        for (final w in words(s.text)) {
          final match = lemma != null
              ? lemmasOf(w).contains(lemma)
              : greekFormKey(w) == form;
          if (match) {
            result.add(s);
            break;
          }
        }
        if (result.length >= limit) return result;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Umschrift (wie in Heinemanns Glossar: archê, hylê, entelecheia, têi)
  // ---------------------------------------------------------------------------

  /// Vergleichsschlüssel eines Glossar-Stichworts: Kleinschreibung, ohne
  /// Artikel am Anfang.
  static String glossaryKey(String term) {
    var t = term.toLowerCase().trim();
    t = t.replaceFirst(RegExp(r'^(to|ta|tôi|tês|hê|hoi|hai|ho) '), '');
    return t.replaceAll("’", "'");
  }

  static const Map<String, String> _letters = {
    "α": "a", "β": "b", "γ": "g", "δ": "d", "ε": "e", "ζ": "z", "η": "ê",
    "θ": "th", "ι": "i", "κ": "k", "λ": "l", "μ": "m", "ν": "n", "ξ": "x",
    "ο": "o", "π": "p", "ρ": "r", "σ": "s", "ς": "s", "τ": "t", "υ": "y",
    "φ": "ph", "χ": "ch", "ψ": "ps", "ω": "ô",
  };

  /// Umschrift einer griechischen Form in der Schreibweise der Ausgabe.
  static String transliterate(String greek) {
    // Zerlegen: Grundbuchstabe + kombinierende Zeichen.
    final decomposed = _decompose(greekFormKey(greek));
    final out = StringBuffer();
    String? previousVowel;
    for (var i = 0; i < decomposed.length; i++) {
      final (letter, rough, iota) = decomposed[i];
      var latin = _letters[letter];
      if (latin == null) {
        if (letter == "'") out.write("’");
        continue;
      }
      // Diphthonge mit υ: au, eu, êu, ou.
      if (letter == "υ" && const {"α", "ε", "η", "ο"}.contains(previousVowel)) {
        latin = "u";
      }
      // γ vor γ, κ, ξ, χ: Nasal.
      if (letter == "γ" && i + 1 < decomposed.length) {
        final next = decomposed[i + 1].$1;
        if (const {"γ", "κ", "ξ", "χ"}.contains(next)) latin = "n";
      }
      if (rough) {
        if (letter == "ρ") {
          latin = "rh";
        } else if (i == 0 || out.isEmpty) {
          latin = "h$latin";
        } else {
          // Spiritus auf dem zweiten Vokal eines Diphthongs (αὑτό).
          final s = out.toString();
          out
            ..clear()
            ..write("h$s");
        }
      }
      if (iota) {
        latin = {"a": "âi", "ê": "êi", "ô": "ôi"}[latin] ?? "${latin}i";
      }
      out.write(latin);
      previousVowel = const {"α", "ε", "η", "ο", "ι", "υ", "ω"}.contains(letter)
          ? letter
          : null;
    }
    return out.toString();
  }

  /// Liefert je Buchstabe (Grundbuchstabe, Spiritus asper, Iota
  /// subscriptum); Akzente fallen weg.
  static List<(String, bool, bool)> _decompose(String key) {
    final result = <(String, bool, bool)>[];
    for (final rune in key.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == "'" || ch == "’") {
        result.add(("'", false, false));
        continue;
      }
      final info = _baseOf(rune);
      if (info != null) result.add(info);
    }
    return result;
  }

  static (String, bool, bool)? _baseOf(int rune) {
    const simple = "αβγδεζηθικλμνξοπρσςτυφχψω";
    final ch = String.fromCharCode(rune);
    if (simple.contains(ch)) return (ch, false, false);
    const tonos = {
      0x03AC: "α", 0x03AD: "ε", 0x03AE: "η", 0x03AF: "ι", 0x03CC: "ο",
      0x03CD: "υ", 0x03CE: "ω", 0x0390: "ι", 0x03B0: "υ", 0x03CA: "ι",
      0x03CB: "υ",
    };
    if (tonos.containsKey(rune)) return (tonos[rune]!, false, false);
    if (rune >= 0x1F00 && rune <= 0x1F6F) {
      const bases = ["α", "ε", "η", "ι", "ο", "υ", "ω"];
      const starts = [0x1F00, 0x1F10, 0x1F20, 0x1F30, 0x1F40, 0x1F50, 0x1F60];
      for (var i = starts.length - 1; i >= 0; i--) {
        if (rune >= starts[i]) {
          final offset = (rune - starts[i]) & 0x7;
          return (bases[i], offset.isOdd, false);
        }
      }
    }
    if (rune >= 0x1F80 && rune <= 0x1FAF) {
      const bases = ["α", "η", "ω"];
      final group = (rune - 0x1F80) ~/ 16;
      final offset = (rune - 0x1F80) & 0x7;
      return (bases[group], offset.isOdd, true);
    }
    const iotaSub = {
      0x1FB3: "α", 0x1FB4: "α", 0x1FB2: "α", 0x1FB7: "α",
      0x1FC3: "η", 0x1FC4: "η", 0x1FC2: "η", 0x1FC7: "η",
      0x1FF3: "ω", 0x1FF4: "ω", 0x1FF2: "ω", 0x1FF7: "ω",
    };
    if (iotaSub.containsKey(rune)) return (iotaSub[rune]!, false, true);
    const other = {
      0x1FB6: "α", 0x1FC6: "η", 0x1FD6: "ι", 0x1FE6: "υ", 0x1FF6: "ω",
      0x1FD2: "ι", 0x1FD3: "ι", 0x1FD7: "ι", 0x1FE2: "υ", 0x1FE3: "υ",
      0x1FE7: "υ", 0x1F70: "α", 0x1F72: "ε", 0x1F74: "η", 0x1F76: "ι",
      0x1F78: "ο", 0x1F7A: "υ", 0x1F7C: "ω", 0x1FE4: "ρ",
    };
    if (other.containsKey(rune)) return (other[rune]!, false, false);
    if (rune == 0x1FE5) return ("ρ", true, false);
    return null;
  }
}
