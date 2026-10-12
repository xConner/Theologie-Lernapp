import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'greek_form_key.dart';

/// Bedeutungen aus Wörterbüchern für Grundformen außerhalb der Vokabelliste
/// (`assets/greek_corpus/lexicon.json`, erzeugt beim Import).
class GreekLexicon {
  final Map<String, LexiconEntry> _entries;

  GreekLexicon(Map<String, LexiconEntry> entries)
    : _entries = {for (final e in entries.entries) greekFormKey(e.key): e.value};

  static final GreekLexicon empty = GreekLexicon(const {});

  factory GreekLexicon.fromJson(Map<String, dynamic> json) {
    final raw = (json["entries"] as Map?) ?? const {};

    return GreekLexicon({
      for (final e in raw.entries)
        e.key as String: LexiconEntry.fromJson(e.value as Map<String, dynamic>),
    });
  }

  LexiconEntry? operator [](String lemma) => _entries[greekFormKey(lemma)];
}

class LexiconEntry {
  /// Deutsche Bedeutungen (deutsches Wiktionary).
  final List<String> german;

  /// Englische Bedeutungen (englisches Wiktionary).
  final List<String> english;

  /// Deklinationsklasse eines Nomens (1–3), sonst `null`.
  final int? declension;

  const LexiconEntry({
    this.german = const [],
    this.english = const [],
    this.declension,
  });

  factory LexiconEntry.fromJson(Map<String, dynamic> json) {
    return LexiconEntry(
      german: List<String>.from((json["de"] as List?) ?? const []),
      english: List<String>.from((json["en"] as List?) ?? const []),
      declension: (json["decl"] as num?)?.toInt(),
    );
  }
}

/// Zuordnung von Grundformen der Texte zu Einträgen der Vokabelliste.
///
/// Verglichen wird über [greekFormKey] (Akzente bleiben, ἤ ≠ ἥ). Zusätzlich
/// gelten feste, prüfbare Schreibregeln:
///
/// * Einträge mit Alternativen oder Zusätzen werden zerlegt
///   ("οὐ / οὐκ / οὐχ", "ἐκ/ἐξ", "ἀμφί + Gen.", "εἷς, μία, ἕν");
///   mehrteilige Wendungen ("οὐ μόνον … ἀλλὰ καί") bleiben unberücksichtigt;
/// * attische und Koine-Schreibung gelten als gleich (γίγνομαι = γίνομαι,
///   θάλαττα = θάλασσα);
/// * eine mediale bzw. passive Form eines Verbs auf -ω findet auch den
///   Eintrag auf -ομαι (ἤρξατο zu ἄρχω → „ἄρχομαι: anfangen“).
class VocabularyMatcher {
  final Map<String, List<GreekVocabularyEntry>> _byKey = {};

  VocabularyMatcher(Iterable<GreekVocabularyEntry> entries) {
    for (final entry in entries) {
      for (final key in lemmaKeysOf(entry.lemma)) {
        _byKey.putIfAbsent(key, () => []).add(entry);
      }
    }
  }

  /// Vergleichsschlüssel eines Vokabeleintrags (siehe Klassenbeschreibung).
  static Set<String> lemmaKeysOf(String lemma) {
    final keys = <String>{};

    final withoutAdditions = lemma.replaceAll(RegExp(r'\s*\+.*$'), '');

    for (final part in withoutAdditions.split(RegExp(r'\s*[/,]\s*'))) {
      final trimmed = part.trim();

      // Wendungen aus mehreren Wörtern sind keine Grundform.
      if (trimmed.isEmpty || trimmed.contains(' ') || trimmed.contains('…')) {
        continue;
      }

      final key = greekFormKey(trimmed);
      if (key.isNotEmpty) keys.addAll(spellingVariants(key));
    }

    return keys;
  }

  /// Attische und Koine-Schreibungen derselben Grundform.
  static Set<String> spellingVariants(String key) {
    return {
      key,
      key.replaceAll('γιγν', 'γιν').replaceAll('γίγν', 'γίν'),
      key.replaceAll('ττ', 'σσ'),
      key.replaceAll('ρρ', 'ρσ'),
    };
  }

  /// Einträge zur Grundform [lemma]; mit [analysis] auch der mediale
  /// Eintrag eines Verbs auf -ω.
  List<GreekVocabularyEntry> entriesFor(String lemma, [LemmaAnalysis? analysis]) {
    final result = <GreekVocabularyEntry>[];
    final key = greekFormKey(lemma);

    for (final variant in spellingVariants(key)) {
      for (final entry in _byKey[variant] ?? const <GreekVocabularyEntry>[]) {
        if (!result.contains(entry)) result.add(entry);
      }
    }

    final a = analysis?.analysis;
    final mediopassive =
        a != null &&
        a.isVerb &&
        (a.voice == "M" || (a.voice == "P" && a.tense != "A"));

    if (mediopassive && key.endsWith('ω')) {
      final middleKey = '${key.substring(0, key.length - 1)}ομαι';

      for (final variant in spellingVariants(middleKey)) {
        for (final entry in _byKey[variant] ?? const <GreekVocabularyEntry>[]) {
          // Der mediale Eintrag zuerst: er trifft die Bedeutung der Form.
          if (!result.contains(entry)) result.insert(0, entry);
        }
      }
    }

    return result;
  }
}

/// Welche Grundformen als bekannt gelten: alle Einträge der gewählten
/// Lernschritte der Vokabelliste.
class VocabularyKnowledge {
  final VocabularyMatcher matcher;
  final Set<int> knownSteps;

  VocabularyKnowledge(this.matcher, Iterable<int> steps)
    : knownSteps = steps.toSet();

  bool isKnown(String lemma, [LemmaAnalysis? analysis]) {
    return matcher
        .entriesFor(lemma, analysis)
        .any((e) => knownSteps.contains(e.step));
  }

  /// Ob eine Form ohne Hilfe verstanden werden kann: eine ihrer möglichen
  /// Grundformen ist bekannt. Unbestimmte Formen und Eigennamen gelten als
  /// unbekannt.
  bool knowsToken(CorpusToken token) {
    if (!token.isAnalyzed ||
        token.reliability == AnalysisReliability.properNameGuess) {
      return false;
    }

    return token.readings.any((r) => isKnown(r.lemma, r));
  }
}

/// Herkunft einer Bedeutung.
enum MeaningSource {
  /// Vokabelliste der App (Lernschritt in [HintLemma.step]).
  vocabulary,

  /// Deutsches Wiktionary.
  wiktionaryGerman,

  /// Englisches Wiktionary (keine deutsche Bedeutung vorhanden).
  wiktionaryEnglish,

  /// Keine Bedeutung in den Datenquellen.
  none,
}

/// Eine mögliche Grundform einer Vokabelhilfe.
class HintLemma {
  final String lemma;

  /// Grundform mit Genitiv und Artikel aus der Vokabelliste ("ἀρχή, -ῆς, ἡ").
  final String headword;

  final List<String> meanings;
  final MeaningSource source;
  final int? step;
  final bool properName;

  const HintLemma({
    required this.lemma,
    required this.headword,
    required this.meanings,
    required this.source,
    this.step,
    this.properName = false,
  });
}

/// Vokabelhilfe zu einer oder mehreren Formen des Textes.
class VocabularyHint {
  /// Formen im Text, wie sie dort stehen (ohne Satzzeichen).
  final List<String> forms;

  /// Mögliche Grundformen; mehrere bei mehrdeutigen Formen.
  final List<HintLemma> lemmas;

  /// Form ohne Bestimmung.
  final bool unanalyzed;

  /// Vermutlich ein Eigenname (unbekannte, großgeschriebene Form).
  final bool properNameGuess;

  const VocabularyHint({
    required this.forms,
    required this.lemmas,
    this.unanalyzed = false,
    this.properNameGuess = false,
  });

  bool get ambiguous => lemmas.length > 1;
}

/// Erstellt die Vokabelhilfen eines Textes.
class VocabularyHelpBuilder {
  final VocabularyKnowledge knowledge;
  final GreekLexicon lexicon;

  const VocabularyHelpBuilder(this.knowledge, this.lexicon);

  static bool isProperNameLemma(String lemma) =>
      RegExp(r'^\p{Lu}', unicode: true).hasMatch(lemma);

  HintLemma _lemma(String lemma, LemmaAnalysis? analysis) {
    final entries = knowledge.matcher.entriesFor(lemma, analysis);
    final properName = isProperNameLemma(lemma);

    if (entries.isNotEmpty) {
      final first = entries.first;
      final headword = [
        first.lemma,
        if (first.genitive != null) first.genitive!,
        if (first.article != null) first.article!,
      ].join(", ");

      final meanings = <String>[
        for (final e in entries)
          for (final t in e.translations)
            if (t.trim().isNotEmpty) t.trim(),
      ];

      return HintLemma(
        lemma: lemma,
        headword: headword,
        meanings: meanings.toSet().toList(),
        source: MeaningSource.vocabulary,
        step: entries.map((e) => e.step).reduce((a, b) => a < b ? a : b),
        properName: properName,
      );
    }

    final entry = lexicon[lemma];

    if (entry != null && entry.german.isNotEmpty) {
      return HintLemma(
        lemma: lemma,
        headword: lemma,
        meanings: entry.german,
        source: MeaningSource.wiktionaryGerman,
        properName: properName,
      );
    }

    if (entry != null && entry.english.isNotEmpty) {
      return HintLemma(
        lemma: lemma,
        headword: lemma,
        meanings: entry.english,
        source: MeaningSource.wiktionaryEnglish,
        properName: properName,
      );
    }

    return HintLemma(
      lemma: lemma,
      headword: lemma,
      meanings: const [],
      source: MeaningSource.none,
      properName: properName,
    );
  }

  /// Hilfen in der Reihenfolge des ersten Vorkommens; Formen derselben
  /// Grundform(en) werden zusammengefasst. Bekannte Wörter erhalten keine
  /// Hilfe.
  List<VocabularyHint> build(List<CorpusToken> tokens) {
    final order = <String>[];
    final forms = <String, List<String>>{};
    final hints = <String, VocabularyHint Function(List<String>)>{};

    for (final token in tokens) {
      if (knowledge.knowsToken(token)) continue;

      final String key;
      final VocabularyHint Function(List<String>) make;

      if (token.reliability == AnalysisReliability.unanalyzed) {
        key = "?${greekFormKey(token.surface)}";
        make = (f) => VocabularyHint(forms: f, lemmas: const [], unanalyzed: true);
      } else if (token.reliability == AnalysisReliability.properNameGuess) {
        key = "~${greekFormKey(token.surface)}";
        make = (f) => VocabularyHint(
          forms: f,
          lemmas: const [],
          properNameGuess: true,
        );
      } else {
        final byLemma = <String, LemmaAnalysis>{};
        for (final r in token.readings) {
          byLemma.putIfAbsent(r.lemma, () => r);
        }

        key = (byLemma.keys.toList()..sort()).join("|");
        make = (f) => VocabularyHint(
          forms: f,
          lemmas: [
            for (final MapEntry(key: lemma, value: reading) in byLemma.entries)
              _lemma(lemma, reading),
          ],
        );
      }

      if (!forms.containsKey(key)) {
        order.add(key);
        hints[key] = make;
      }

      final list = forms.putIfAbsent(key, () => []);
      final word = token.word;
      if (!list.contains(word)) list.add(word);
    }

    return [for (final key in order) hints[key]!(forms[key]!)];
  }
}
