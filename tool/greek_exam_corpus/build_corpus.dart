// Erzeugt die Korpora des Klausurerstellers unter assets/greek_corpus/ aus
// MorphGNT, den Bibeltexten der App (assets/bible/grcsbl, grcbrent) und den
// Wiktionary-Auszügen. Vorher: dart run tool/greek_exam_corpus/fetch_sources.dart
//
//   dart run tool/greek_exam_corpus/build_corpus.dart
//
// Die Erkennung der Phänomene verwendet denselben Code wie die App
// (lib/services/greek/exam/). Näheres: README.md, docs/greek-exam-sources.md.
import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/greek/exam/corpus_token.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_morph_analysis.dart';
import 'package:theologie_lernapp/services/greek/exam/corpus_codec.dart';
import 'package:theologie_lernapp/services/greek/exam/grammar_phenomena.dart';
import 'package:theologie_lernapp/services/greek/exam/greek_form_key.dart';
import 'package:theologie_lernapp/services/greek/exam/phenomenon_detection.dart';
import 'package:theologie_lernapp/utils/greek_normalization.dart';

const String outputRoot = 'assets/greek_corpus';

typedef Pair = (String lemma, String code);

Future<void> main(List<String> args) async {
  final sources =
      jsonDecode(File('tool/greek_exam_corpus/sources.json').readAsStringSync())
          as Map<String, dynamic>;
  final cache = sources['cacheDir'] as String;

  stdout.writeln('Lese Wiktionary …');
  final wiktionary = Wiktionary.load(
    english: File(
      '$cache/${(sources['wiktionaryEnglish'] as Map)['file']}',
    ),
    german: File('$cache/${(sources['wiktionaryGerman'] as Map)['file']}'),
  );
  stdout.writeln(
    '  ${wiktionary.analyses.length} Formschlüssel, '
    '${wiktionary.declension.length} Nomen mit Deklinationsklasse, '
    '${wiktionary.german.length} deutsche Einträge',
  );

  stdout.writeln('Lese MorphGNT …');
  final morphgnt = sources['morphgnt'] as Map<String, dynamic>;
  final nt = MorphGnt.load(
    Directory('$cache/morphgnt-${morphgnt['commit']}'),
    Map<String, String>.from(morphgnt['files'] as Map),
  );
  stdout.writeln('  ${nt.index.length} Formschlüssel');

  final analyzer = FormAnalyzer(nt.index, wiktionary);

  final context = DetectionContext(declensionOf: wiktionary.declensionOf);

  final usedLemmas = <String>{};

  final ntStats = buildCorpus(
    id: 'nt',
    books: nt.books,
    paragraphs: paragraphStarts('grcsbl'),
    context: context,
    tokenize: (book, verse) => [
      for (final token in verse.tokens) analyzer.withAlternatives(token),
    ],
    usedLemmas: usedLemmas,
  );

  final lxxBooks = loadBibleBooks('grcbrent');
  final lxxStats = buildCorpus(
    id: 'lxx',
    books: lxxBooks,
    paragraphs: paragraphStarts('grcbrent'),
    context: context,
    tokenize: (book, verse) => analyzer.analyzeVerse(verse.text),
    usedLemmas: usedLemmas,
  );

  writeLexicon(usedLemmas, wiktionary);
  writeCorpora(sources, ntStats, lxxStats);

  stdout.writeln('NT:  $ntStats');
  stdout.writeln('LXX: $lxxStats');
}

// -----------------------------------------------------------------------------
// QUELLTEXTE
// -----------------------------------------------------------------------------

class SourceVerse {
  final String label;
  final String text;

  /// Bei MorphGNT bereits bestimmt; sonst leer.
  final List<CorpusToken> tokens;

  SourceVerse(this.label, this.text, [this.tokens = const []]);
}

class SourceBook {
  final String id;
  final List<List<SourceVerse>> chapters;

  SourceBook(this.id, this.chapters);
}

/// Bibelbuch-IDs in der Reihenfolge der Ausgabe (assets/bible/translations.json).
List<String> bookOrder(String translation) {
  final json =
      jsonDecode(File('assets/bible/translations.json').readAsStringSync())
          as Map<String, dynamic>;

  for (final t in json['translations'] as List) {
    if (t['id'] == translation) {
      return [for (final b in t['books'] as List) b['id'] as String];
    }
  }

  throw StateError('Ausgabe $translation fehlt in translations.json');
}

/// Liest eine Ausgabe der App: Verse mit Bezeichnung, Fortsetzungen nach
/// Zwischenüberschriften werden an ihren Vers angehängt.
List<SourceBook> loadBibleBooks(String translation) {
  return [
    for (final id in bookOrder(translation))
      SourceBook(id, [
        for (final chapter in _bibleChapters(translation, id))
          [
            for (final verse in chapter)
              SourceVerse(verse.label, verse.text),
          ],
      ]),
  ];
}

typedef _BibleVerse = ({String label, String text, bool paragraph});

List<List<_BibleVerse>> _bibleChapters(String translation, String book) {
  final json =
      jsonDecode(
            File('assets/bible/$translation/$book.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  return [
    for (final chapter in json['chapters'] as List)
      () {
        final verses = <_BibleVerse>[];

        for (final item in chapter as List) {
          if (item is! Map || !item.containsKey('v')) continue;

          final label = (item['l'] as String?) ?? '${item['v']}';
          final text = (item['t'] as String).replaceAll(RegExp(r'\s+'), ' ');

          if (item['c'] == 1 && verses.isNotEmpty && verses.last.label == label) {
            final last = verses.removeLast();
            verses.add((
              label: label,
              text: '${last.text} $text',
              paragraph: last.paragraph,
            ));
          } else {
            verses.add((label: label, text: text, paragraph: item['b'] == 1));
          }
        }

        return verses;
      }(),
  ];
}

/// Absatzanfänge je Buch/Kapitel/Vers aus der Ausgabe der App.
Map<String, bool> paragraphStarts(String translation) {
  final result = <String, bool>{};

  for (final id in bookOrder(translation)) {
    for (final (c, chapter) in _bibleChapters(translation, id).indexed) {
      for (final verse in chapter) {
        if (verse.paragraph) result['$id ${c + 1} ${verse.label}'] = true;
      }
    }
  }

  return result;
}

// -----------------------------------------------------------------------------
// MORPHGNT
// -----------------------------------------------------------------------------

class MorphGnt {
  final List<SourceBook> books;

  /// Formschlüssel → alle im NT belegten Bestimmungen der Form.
  final Map<String, Set<Pair>> index;

  MorphGnt(this.books, this.index);

  factory MorphGnt.load(Directory dir, Map<String, String> files) {
    final index = <String, Set<Pair>>{};
    final books = <SourceBook>[];

    for (final MapEntry(key: id, value: file) in files.entries) {
      final chapters = <List<SourceVerse>>[];
      final words = <String, List<(String, Pair)>>{};
      final order = <String>[];

      for (final line in File('${dir.path}/$file').readAsLinesSync()) {
        final parts = line.split(' ');
        if (parts.length != 7) continue;

        final ref = parts[0];
        final code = parts[1] + parts[2];
        final lemma = parts[6];

        if (code.length != 10) {
          throw FormatException('Unerwarteter Code $code in $file: $line');
        }

        index.putIfAbsent(greekFormKey(parts[4]), () => {}).add((lemma, code));

        if (!words.containsKey(ref)) order.add(ref);
        words
            .putIfAbsent(ref, () => [])
            .add((stripCriticalSigns(parts[3]), (lemma, code)));
      }

      for (final ref in order) {
        final chapter = int.parse(ref.substring(2, 4));
        final verse = int.parse(ref.substring(4, 6));

        while (chapters.length < chapter) {
          chapters.add([]);
        }

        final entries = words[ref]!;

        chapters[chapter - 1].add(
          SourceVerse(
            '$verse',
            entries.map((e) => e.$1).join(' '),
            [
              for (final (surface, (lemma, code)) in entries)
                CorpusToken(surface, [
                  LemmaAnalysis(lemma, GreekMorphAnalysis(code)),
                ], AnalysisReliability.contextual),
            ],
          ),
        );
      }

      books.add(SourceBook(id, chapters));
    }

    return MorphGnt(books, index);
  }
}

// -----------------------------------------------------------------------------
// WIKTIONARY
// -----------------------------------------------------------------------------

class Wiktionary {
  /// Formschlüssel → Bestimmungen aus Flexionstabellen.
  final Map<String, Set<Pair>> analyses = {};

  /// Schlüssel der Grundform → Deklinationsklasse (1–3).
  final Map<String, int> declension = {};

  /// Schlüssel der Grundform → deutsche Bedeutungen (de.wiktionary).
  final Map<String, List<String>> german = {};

  /// Schlüssel der Grundform → englische Bedeutungen (en.wiktionary).
  final Map<String, List<String>> english = {};

  int? declensionOf(String lemma) => declension[greekFormKey(lemma)];

  static Wiktionary load({required File english, required File german}) {
    final w = Wiktionary();

    for (final line in english.readAsLinesSync()) {
      if (line.isEmpty) continue;
      w._readEnglish(jsonDecode(line) as Map<String, dynamic>);
    }

    for (final line in german.readAsLinesSync()) {
      if (line.isEmpty) continue;
      w._readGerman(jsonDecode(line) as Map<String, dynamic>);
    }

    return w;
  }

  static String _lemmaOf(String word) =>
      composeGreek(normalizeGreekForDisplay(word))
          .replaceAll(RegExp('[̄̆]'), '');

  static const Map<String, String> _tenses = {
    'present': 'P',
    'imperfect': 'I',
    'future': 'F',
    'aorist': 'A',
    'perfect': 'X',
    'pluperfect': 'Y',
  };

  /// Tempus einer Tabellenüberschrift ("present", "Attic aorist",
  /// "contracted imperfect"); `null` bei anderen Dialekten oder unbekannten
  /// Tabellen (Futur II u. a.).
  static String? _tenseOfHeader(String header) {
    var h = header.trim();

    for (final prefix in ['Attic ', 'Koine ']) {
      if (h.startsWith(prefix)) h = h.substring(prefix.length);
    }

    if (h.startsWith('contracted ')) h = h.substring('contracted '.length);
    if (h.isEmpty || h[0] != h[0].toLowerCase()) return null;

    return _tenses[h];
  }

  /// Deklinationsklasse einer Tabellenüberschrift ("Attic declension-2").
  static int? _declensionOfHeader(String header) {
    var h = header.trim();

    for (final prefix in ['Attic ', 'Koine ', 'Attic contracted ']) {
      if (h.startsWith(prefix)) h = h.substring(prefix.length);
    }

    if (h.startsWith('contracted ')) h = h.substring('contracted '.length);

    final match = RegExp(r'^declension-([123])$').firstMatch(h);
    return match == null ? null : int.parse(match[1]!);
  }

  static bool _acceptedHeader(String header) {
    var h = header.trim();

    for (final prefix in ['Attic ', 'Koine ']) {
      if (h.startsWith(prefix)) return true;
    }

    return h.isNotEmpty && h[0] == h[0].toLowerCase();
  }

  static const Map<String, String> _cases = {
    'nominative': 'N',
    'genitive': 'G',
    'dative': 'D',
    'accusative': 'A',
    'vocative': 'V',
  };

  static const Map<String, String> _numbers = {
    'singular': 'S',
    'plural': 'P',
  };

  static const Map<String, String> _genders = {
    'masculine': 'M',
    'feminine': 'F',
    'neuter': 'N',
  };

  static const Map<String, String> _moods = {
    'indicative': 'I',
    'subjunctive': 'S',
    'optative': 'O',
    'imperative': 'D',
    'infinitive': 'N',
    'participle': 'P',
  };

  static const Map<String, String> _persons = {
    'first-person': '1',
    'second-person': '2',
    'third-person': '3',
  };

  static String? _pick(Set<String> tags, Map<String, String> table) {
    final hits = [
      for (final e in table.entries)
        if (tags.contains(e.key)) e.value,
    ];
    return hits.length == 1 ? hits.single : null;
  }

  /// Genera Verbi der Tags; Medium und Passiv ungeschieden → beide.
  /// Alle Werte der Tags aus [table] (zweiendige Adjektive tragen
  /// "masculine" und "feminine").
  static List<String> _all(Set<String> tags, Map<String, String> table) => [
    for (final e in table.entries)
      if (tags.contains(e.key)) e.value,
  ];

  static List<String> _voices(Set<String> tags) {
    if (tags.contains('mediopassive') ||
        (tags.contains('middle') && tags.contains('passive'))) {
      return ['M', 'P'];
    }

    if (tags.contains('active')) return ['A'];
    if (tags.contains('middle')) return ['M'];
    if (tags.contains('passive')) return ['P'];
    return const [];
  }

  /// Einzelformen einer Tabellenzelle ("λύουσι(ν)", "a / b", "a, b").
  static Iterable<String> _cellForms(String cell) sync* {
    for (final part in cell.split(RegExp(r'\s*[,/;]\s*|\s+'))) {
      if (part.isEmpty) continue;

      if (part.contains('(') && part.contains(')')) {
        yield part.replaceAll(RegExp(r'[()]'), '');
        yield part.replaceAll(RegExp(r'\([^)]*\)'), '');
      } else {
        yield part;
      }
    }
  }

  void _add(String form, String lemma, String code) {
    for (final f in _cellForms(form)) {
      final key = greekFormKey(f);
      if (key.length < 2) continue;
      analyses.putIfAbsent(key, () => {}).add((lemma, code));
    }
  }

  static final RegExp _participleGloss = RegExp(
    r'^(present|imperfect|future|aorist|perfect|pluperfect) '
    r'(active|middle|passive|mediopassive|middle-passive|middle/passive) '
    r'participle of (\S+)',
  );

  void _readEnglish(Map<String, dynamic> entry) {
    final word = entry['word'] as String?;
    final pos = entry['pos'] as String?;
    if (word == null || pos == null) return;

    final lemma = _lemmaOf(word);
    final senses = (entry['senses'] as List?) ?? const [];
    final forms = (entry['forms'] as List?) ?? const [];

    final isFormOf = senses.isNotEmpty &&
        senses.every((s) {
          final tags = ((s as Map)['tags'] as List?) ?? const [];
          return tags.contains('form-of') || tags.contains('alt-of');
        });

    // Englische Bedeutungen nur von Grundform-Einträgen.
    if (!isFormOf) {
      final glosses = [
        for (final s in senses)
          for (final g in ((s as Map)['glosses'] as List?) ?? const [])
            if (!(((s['tags'] as List?) ?? const []).contains('form-of')))
              (g as String).trim(),
      ].where((g) => g.isNotEmpty).toList();

      if (glosses.isNotEmpty) {
        english.putIfAbsent(greekFormKey(lemma), () => []).addAll(glosses);
      }
    }

    // Partizipien als eigene Einträge mit vollständiger Deklination.
    String? participleCode;
    String? participleLemma;

    final headName = (((entry['head_templates'] as List?) ?? const [])
            .firstOrNull as Map?)?['name']
        as String?;

    if (pos == 'verb' && (headName?.startsWith('grc-part') ?? false)) {
      for (final s in senses) {
        for (final g in ((s as Map)['glosses'] as List?) ?? const []) {
          final m = _participleGloss.firstMatch(g as String);
          if (m == null) continue;

          final voices = switch (m[2]!) {
            'active' => const ['A'],
            'middle' => const ['M'],
            'passive' => const ['P'],
            _ => const ['M', 'P'],
          };

          final formOf = ((s['form_of'] as List?)?.firstOrNull as Map?)?['word'];
          participleLemma = _lemmaOf((formOf as String?) ?? m[3]!);
          participleCode = '${_tenses[m[1]!]}${voices.join()}';
        }
      }
    }

    String? header;
    String? nounGender;

    final expansion = (((entry['head_templates'] as List?) ?? const [])
            .firstOrNull as Map?)?['expansion']
        as String?;

    if (pos == 'noun' && expansion != null) {
      final g = RegExp(r'\)\s+(m|f|n)\b').firstMatch(expansion);
      if (g != null) nounGender = g[1]!.toUpperCase();
    }

    for (final raw in forms) {
      final f = raw as Map;
      final form = f['form'] as String?;
      final source = f['source'] as String?;
      final tags = {...((f['tags'] as List?) ?? const []).cast<String>()};

      if (form == null || (source != 'conjugation' && source != 'declension')) {
        continue;
      }

      if (tags.contains('table-tags')) {
        header = form;

        if (source == 'declension' && pos == 'noun' && _acceptedHeader(form)) {
          final d = _declensionOfHeader(form);
          if (d != null) declension.putIfAbsent(greekFormKey(lemma), () => d);
        }
        continue;
      }

      if (header == null || !_acceptedHeader(header)) continue;
      if (tags.contains('dual') || tags.contains('inflection-template')) {
        continue;
      }

      if (source == 'conjugation' && pos == 'verb' && participleCode == null) {
        final tense = _tenseOfHeader(header);
        final mood = _pick(tags, _moods);
        if (tense == null || mood == null) continue;

        for (final voice in _voices(tags)) {
          if (mood == 'N') {
            _add(form, lemma, 'V--$tense${voice}N----');
          } else if (mood == 'P') {
            for (final gender in _all(tags, _genders)) {
              _add(form, lemma, 'V--$tense${voice}PNS$gender-');
            }
          } else {
            final person = _pick(tags, _persons);
            final number = _pick(tags, _numbers);
            if (person == null || number == null) continue;
            _add(form, lemma, 'V-$person$tense$voice$mood-$number--');
          }
        }
      } else if (source == 'declension') {
        final grammaticalCase = _pick(tags, _cases);
        final number = _pick(tags, _numbers);
        if (grammaticalCase == null || number == null) continue;

        if (participleCode != null && participleLemma != null) {
          for (final gender in _all(tags, _genders)) {
            for (final voice in participleCode.substring(1).split('')) {
              _add(
                form,
                participleLemma,
                'V--${participleCode[0]}${voice}P$grammaticalCase$number$gender-',
              );
            }
          }
        } else if (pos == 'noun') {
          _add(form, lemma, 'N-----$grammaticalCase$number${nounGender ?? '-'}-');
        } else if (pos == 'adj') {
          // Zweiendige Adjektive: eine Form für Maskulinum und Femininum.
          for (final gender in _all(tags, _genders)) {
            _add(form, lemma, 'A-----$grammaticalCase$number$gender-');
          }
        }
      }
    }
  }

  void _readGerman(Map<String, dynamic> entry) {
    final word = entry['word'] as String?;
    if (word == null) return;
    if (entry['pos'] == 'character') return;

    final glosses = <String>[
      for (final s in (entry['senses'] as List?) ?? const [])
        for (final g in ((s as Map)['glosses'] as List?) ?? const [])
          (g as String).trim(),
    ].where((g) => g.isNotEmpty).toList();

    if (glosses.isNotEmpty) {
      german
          .putIfAbsent(greekFormKey(_lemmaOf(word)), () => [])
          .addAll(glosses);
    }
  }
}

// -----------------------------------------------------------------------------
// FORMANALYSE (SEPTUAGINTA)
// -----------------------------------------------------------------------------

/// Bestimmt Formen ohne Kontext über die Formenindizes: zuerst die im NT
/// belegten Bestimmungen (ergänzt um weitere Bestimmungen derselben
/// Grundform aus Wiktionary-Tabellen), sonst die Wiktionary-Tabellen allein.
/// Bleibt eine Form unbekannt, werden geregelte Schreibvarianten versucht
/// (bewegliches ν, Krasis mit ᾀ). Nichts davon rät eine Grundform.
class FormAnalyzer {
  final Map<String, Set<Pair>> nt;
  final Wiktionary wiktionary;

  FormAnalyzer(this.nt, this.wiktionary);

  Set<Pair>? lookup(String key) {
    final fromNt = nt[key];
    final fromWk = wiktionary.analyses[key];

    if (fromNt != null) {
      // Schreibung der Grundform wie im NT.
      final ntLemma = {for (final p in fromNt) greekFormKey(p.$1): p.$1};

      return {
        ...fromNt,
        if (fromWk != null)
          for (final (lemma, code) in fromWk)
            if (ntLemma[greekFormKey(lemma)] case final spelling?)
              (spelling, code),
      };
    }

    return fromWk;
  }

  /// Hängt an eine im Kontext bestimmte Form (MorphGNT) alle weiteren
  /// formal möglichen Bestimmungen derselben Form an.
  CorpusToken withAlternatives(CorpusToken token) {
    final context = token.analyses.first;
    final others = lookup(greekFormKey(token.surface)) ?? const <Pair>{};

    return CorpusToken(token.surface, [
      context,
      for (final (lemma, code) in others)
        if (lemma != context.lemma || code != context.analysis.code)
          LemmaAnalysis(lemma, GreekMorphAnalysis(code)),
    ], AnalysisReliability.contextual);
  }

  Set<Pair>? lookupWithVariants(String key) {
    final direct = lookup(key);
    if (direct != null) return direct;

    final variants = <String>[
      // Bewegliches ν: ἐλάλησε = ἐλάλησεν, ἐστί = ἐστίν
      if (key.endsWith('ε') || key.endsWith('ι') || key.endsWith('ί') ||
          key.endsWith('έ'))
        '$keyν',
      if (key.endsWith('ν')) key.substring(0, key.length - 1),
      // Krasis mit Iota subscriptum (κᾀγώ = κἀγώ)
      if (key.contains('ᾀ')) key.replaceAll('ᾀ', 'ἀ'),
      if (key.contains('ᾄ')) key.replaceAll('ᾄ', 'ἄ'),
    ];

    for (final variant in variants) {
      final found = lookup(variant);
      if (found != null) return found;
    }

    return null;
  }

  List<CorpusToken> analyzeVerse(String text) {
    final words = splitGreekWords(text);
    final tokens = <CorpusToken>[];

    for (var i = 0; i < words.length; i++) {
      final surface = words[i];
      final key = greekFormKey(surface);
      final found = lookupWithVariants(key);

      if (found != null && found.isNotEmpty) {
        tokens.add(
          CorpusToken(surface, [
            for (final (lemma, code) in found)
              LemmaAnalysis(lemma, GreekMorphAnalysis(code)),
          ], AnalysisReliability.formal),
        );
        continue;
      }

      final capitalized = RegExp(r'^\p{Lu}', unicode: true)
          .hasMatch(CorpusToken(surface, const [], AnalysisReliability.unanalyzed).word);
      final sentenceStart = i == 0 || endsGreekSentence(words[i - 1]);

      tokens.add(
        capitalized && !sentenceStart
            ? CorpusToken(surface, [
                LemmaAnalysis(
                  CorpusToken(surface, const [], AnalysisReliability.unanalyzed).word,
                  const GreekMorphAnalysis(CorpusCodec.properNameCode),
                ),
              ], AnalysisReliability.properNameGuess)
            : CorpusToken(surface, const [], AnalysisReliability.unanalyzed),
      );
    }

    return tokens;
  }
}

// -----------------------------------------------------------------------------
// KORPUS SCHREIBEN
// -----------------------------------------------------------------------------

class CorpusStats {
  int verses = 0;
  int words = 0;
  int contextual = 0;
  int formal = 0;
  int ambiguous = 0;
  int properNames = 0;
  int unanalyzed = 0;
  int fullyAnalyzedVerses = 0;
  List<String> books = [];

  String percent(int n) =>
      words == 0 ? '0' : (100 * n / words).toStringAsFixed(1);

  Map<String, dynamic> toJson() => {
    'verses': verses,
    'words': words,
    'contextual': contextual,
    'formal': formal,
    'formalAmbiguous': ambiguous,
    'properNameGuesses': properNames,
    'unanalyzed': unanalyzed,
    'fullyAnalyzedVerses': fullyAnalyzedVerses,
  };

  @override
  String toString() =>
      '$verses Verse, $words Wörter; im Kontext bestimmt ${percent(contextual)} %, '
      'formal ${percent(formal)} % (davon mehrdeutig ${percent(ambiguous)} %), '
      'vermutete Eigennamen ${percent(properNames)} %, unbestimmt '
      '${percent(unanalyzed)} %; vollständig bestimmte Verse '
      '$fullyAnalyzedVerses';
}

CorpusStats buildCorpus({
  required String id,
  required List<SourceBook> books,
  required Map<String, bool> paragraphs,
  required DetectionContext context,
  required List<CorpusToken> Function(String book, SourceVerse verse) tokenize,
  required Set<String> usedLemmas,
}) {
  final stats = CorpusStats();
  final dir = Directory('$outputRoot/$id');

  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  final phenomena = GrammarPhenomena.detectable.toList();
  final lemmas = <String>[];
  final lemmaIds = <String, int>{};

  int lemmaId(String lemma) => lemmaIds.putIfAbsent(lemma, () {
    lemmas.add(lemma);
    return lemmas.length - 1;
  });

  final indexBooks = <Map<String, dynamic>>[];

  for (final book in books) {
    final codes = <String>[];
    final codeIds = <String, int>{};
    final sets = <String>[];
    final setIds = <String, int>{};

    int codeId(String code) => codeIds.putIfAbsent(code, () {
      codes.add(code);
      return codes.length - 1;
    });

    int setId(String set) => setIds.putIfAbsent(set, () {
      sets.add(set);
      return sets.length - 1;
    });

    final textChapters = <List<Map<String, dynamic>>>[];
    final indexChapters = <List<dynamic>>[];

    for (final (c, chapter) in book.chapters.indexed) {
      final textVerses = <Map<String, dynamic>>[];
      final indexVerses = <dynamic>[];

      for (final verse in chapter) {
        final tokens = tokenize(book.id, verse);
        final words = splitGreekWords(verse.text);

        if (tokens.length != words.length) {
          throw StateError(
            '${book.id} ${c + 1},${verse.label}: ${words.length} Wörter, '
            '${tokens.length} Bestimmungen',
          );
        }

        if (words.isEmpty) continue;

        final setNumbers = <int>[];
        final lemmaGroups = <List<int>>[];
        var unanalyzed = 0;

        for (final token in tokens) {
          final pairs = [
            for (final a in token.analyses)
              (lemmaId(a.lemma), codeId(a.analysis.code)),
          ];

          setNumbers.add(setId(CorpusCodec.encodeSet(token.reliability, pairs)));

          switch (token.reliability) {
            case AnalysisReliability.contextual:
              stats.contextual++;
            case AnalysisReliability.formal:
              stats.formal++;
              if (token.candidateLemmas.length > 1 ||
                  token.analyses.length > 1) {
                stats.ambiguous++;
              }
            case AnalysisReliability.properNameGuess:
              stats.properNames++;
            case AnalysisReliability.unanalyzed:
              stats.unanalyzed++;
              unanalyzed++;
          }

          if (token.isAnalyzed &&
              token.reliability != AnalysisReliability.properNameGuess) {
            final group = [for (final l in token.candidateLemmas) lemmaId(l)];
            lemmaGroups.add(group);
            usedLemmas.addAll(token.candidateLemmas);
          }
        }

        final certain = <int>[];
        final possible = <int>[];

        final certainView = DetectionView(
          tokens,
          DetectionMode.certain,
          context: context,
        );
        final possibleView = DetectionView(
          tokens,
          DetectionMode.possible,
          context: context,
        );

        for (final (bit, phenomenon) in phenomena.indexed) {
          final detector = phenomenon.detector!;
          if (detector.detect(certainView).isNotEmpty) certain.add(bit);
          if (detector.detect(possibleView).isNotEmpty) possible.add(bit);
        }

        stats.verses++;
        stats.words += words.length;
        if (unanalyzed == 0) stats.fullyAnalyzedVerses++;

        textVerses.add({
          'v': verse.label,
          't': verse.text,
          'a': CorpusCodec.encodeInts(setNumbers),
        });

        indexVerses.add(
          VerseInfo(
            label: verse.label,
            wordCount: words.length,
            paragraphStart:
                paragraphs['${book.id} ${c + 1} ${verse.label}'] ?? false,
            endsSentence: endsGreekSentence(words.last),
            certain: PhenomenonSet.of(certain),
            possible: PhenomenonSet.of(possible),
            unanalyzed: unanalyzed,
            lemmaGroups: lemmaGroups,
          ).toJson(),
        );
      }

      textChapters.add(textVerses);
      indexChapters.add(indexVerses);
    }

    File('${dir.path}/${book.id}.json').writeAsStringSync(
      jsonEncode({
        'id': book.id,
        'codes': codes,
        'sets': sets,
        'chapters': textChapters,
      }),
    );

    indexBooks.add({'id': book.id, 'chapters': indexChapters});
    stats.books.add(book.id);
  }

  File('${dir.path}/index.json').writeAsStringSync(
    jsonEncode({
      'version': CorpusCodec.formatVersion,
      'phenomena': [for (final p in phenomena) p.id],
      'lemmas': lemmas,
      'books': indexBooks,
    }),
  );

  return stats;
}

/// Bedeutungen und Deklinationsklassen der verwendeten Grundformen.
void writeLexicon(Set<String> lemmas, Wiktionary wiktionary) {
  final entries = <String, dynamic>{};

  List<String> trimmed(List<String>? glosses, int max) {
    if (glosses == null) return const [];

    final seen = <String>{};
    return [
      for (final g in glosses)
        if (seen.add(g)) g.length > 160 ? '${g.substring(0, 157)}…' : g,
    ].take(max).toList();
  }

  var withGerman = 0;
  var withEnglish = 0;

  for (final lemma in lemmas.toList()..sort()) {
    final key = greekFormKey(lemma);
    final de = trimmed(wiktionary.german[key], 4);
    final en = trimmed(wiktionary.english[key], 3);
    final decl = wiktionary.declension[key];

    if (de.isEmpty && en.isEmpty && decl == null) continue;
    if (de.isNotEmpty) withGerman++;
    if (en.isNotEmpty) withEnglish++;

    entries[lemma] = {
      if (de.isNotEmpty) 'de': de,
      if (en.isNotEmpty) 'en': en,
      'decl': ?decl,
    };
  }

  File('$outputRoot/lexicon.json').writeAsStringSync(
    jsonEncode({'version': 1, 'entries': entries}),
  );

  stdout.writeln(
    'Lexikon: ${lemmas.length} Grundformen, davon $withGerman mit deutscher '
    'und $withEnglish mit englischer Bedeutung aus Wiktionary',
  );
}

void writeCorpora(
  Map<String, dynamic> sources,
  CorpusStats nt,
  CorpusStats lxx,
) {
  final morphgnt = sources['morphgnt'] as Map<String, dynamic>;
  final en = sources['wiktionaryEnglish'] as Map<String, dynamic>;
  final de = sources['wiktionaryGerman'] as Map<String, dynamic>;
  final today = DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> source(Map<String, dynamic> s) => {
    'name': s['name'],
    'url': s['homepage'],
    'license': s['license'],
    'licenseUrl': s['licenseUrl'],
    'copyright': s['copyright'],
  };

  File('$outputRoot/corpora.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': CorpusCodec.formatVersion,
      'generated': today,
      'corpora': [
        {
          'id': 'nt',
          'name': 'Neues Testament',
          'shortName': 'NT',
          'edition': 'SBL Greek New Testament (2010), Wortlaut nach MorphGNT',
          'bibleTranslation': 'grcsbl',
          'analysis': 'contextual',
          'analysisNote':
              'Jede Wortform ist im Kontext bestimmt (MorphGNT). Weitere '
              'formal mögliche Bestimmungen derselben Form stammen aus den '
              'übrigen Belegen im NT und aus Wiktionary-Tabellen.',
          'text': {
            'name': 'SBL Greek New Testament',
            'url': 'https://sblgnt.com/',
            'license': 'CC BY 4.0',
            'copyright':
                '© 2010 Society of Biblical Literature und Logos Bible Software',
          },
          'sources': [source(morphgnt), source(en)],
          'books': nt.books,
          'stats': nt.toJson(),
        },
        {
          'id': 'lxx',
          'name': 'Altes Testament (Septuaginta)',
          'shortName': 'LXX',
          'edition':
              'Septuaginta nach Brenton (1851), Text der App (eBible.org, '
              'grcbrent)',
          'bibleTranslation': 'grcbrent',
          'analysis': 'formal',
          'analysisNote':
              'Für die Septuaginta gibt es keine frei weitergebbare '
              'morphologische Analyse. Formen werden über einen Formenindex '
              'bestimmt (alle im NT belegten Bestimmungen der Form, ergänzt '
              'um Wiktionary-Tabellen), ohne Prüfung im Kontext. Mehrdeutige '
              'Formen behalten alle Bestimmungen; unbekannte Formen bleiben '
              'unbestimmt.',
          'text': {
            'name': 'Septuaginta nach Brenton (1851)',
            'url': 'https://ebible.org/details.php?id=grcbrent',
            'license': 'Gemeinfrei',
            'copyright': 'Gemeinfrei. Digitale Textfassung: eBible.org.',
          },
          'sources': [source(morphgnt), source(en)],
          'books': lxx.books,
          'stats': lxx.toJson(),
        },
      ],
      'lexicon': {
        'note':
            'Deutsche Bedeutungen außerhalb der Vokabelliste aus dem '
            'deutschen Wiktionary; fehlt dort ein Eintrag, englische '
            'Bedeutungen aus dem englischen Wiktionary (so gekennzeichnet).',
        'sources': [source(de), source(en)],
      },
    }),
  );
}

/// Textkritische Zeichen des SBLGNT (⸀ ⸁ ⸂ ⸃ ⸄ ⸅) gehören zum Apparat, der
/// hier nicht wiedergegeben wird; sie würden Anzeige und Auswahl stören.
String stripCriticalSigns(String text) =>
    text.replaceAll(RegExp('[⸀-⸅]'), '');
