import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'assumed_vocabulary.dart';
import 'gloss_shortener.dart';
import 'greek_form_key.dart';

/// Herkunft einer Bedeutung.
enum MeaningSource {
  /// Vokabelliste der App (Lernschritt in [HintLemma.step]).
  vocabulary,

  /// Redaktionelle Ergänzung des Imports
  /// (`tool/greek_exam_corpus/german_glosses.json`).
  editorial,

  /// Deutsches Wiktionary.
  wiktionary,

  /// Pape, Griechisch-deutsches Handwörterbuch (1914).
  pape,

  /// Keine gesicherte deutsche Bedeutung in den Datenquellen (ungelöst).
  none,
}

/// Deutsche Bedeutungen für Grundformen außerhalb der Vokabelliste
/// (`assets/greek_corpus/lexicon.json`, erzeugt beim Import). Das Lexikon
/// enthält ausschließlich deutsche Angaben, bereits auf Vokabelhilfen
/// gekürzt; eine Grundform ohne deutsche Quelle hat keinen Eintrag und
/// bleibt ungelöst.
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
  /// Deutsche Bedeutungen (kurz, höchstens [maxGlossesPerHint]).
  final List<String> german;

  /// Quelle von [german].
  final MeaningSource source;

  /// Deklinationsklasse eines Nomens (1–3), sonst `null`.
  final int? declension;

  const LexiconEntry({
    this.german = const [],
    this.source = MeaningSource.none,
    this.declension,
  });

  static const Map<String, MeaningSource> sourceCodes = {
    "e": MeaningSource.editorial,
    "w": MeaningSource.wiktionary,
    "p": MeaningSource.pape,
  };

  /// Liest einen Eintrag. Andere Sprachen als Deutsch (Feld `en` früherer
  /// Fassungen) werden nicht gelesen.
  factory LexiconEntry.fromJson(Map<String, dynamic> json) {
    final german = List<String>.from((json["de"] as List?) ?? const []);

    return LexiconEntry(
      german: german,
      source: german.isEmpty
          ? MeaningSource.none
          : sourceCodes[json["src"]] ?? MeaningSource.wiktionary,
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

/// Welche Grundformen als bekannt gelten:
///
/// 1. der Artikel – immer;
/// 2. Wörter der Vokabelliste – wenn ihr Lernschritt gewählt ist (das gilt
///    auch für Pronomen und Namen, die die Liste einem Schritt zuordnet);
/// 3. elementare Funktionswörter und gängige biblische Eigennamen, die in
///    der Vokabelliste fehlen ([ElementaryWords], [BiblicalNames]).
class VocabularyKnowledge {
  final VocabularyMatcher matcher;
  final Set<int> knownSteps;

  VocabularyKnowledge(this.matcher, Iterable<int> steps)
    : knownSteps = steps.toSet();

  bool isKnown(String lemma, [LemmaAnalysis? analysis]) {
    if (ElementaryWords.isArticle(lemma)) return true;

    final entries = matcher.entriesFor(lemma, analysis);

    if (entries.isNotEmpty) {
      return entries.any((e) => knownSteps.contains(e.step));
    }

    return ElementaryWords.contains(lemma) ||
        BiblicalNames.containsLemma(lemma);
  }

  /// Ob eine Form ohne Hilfe verstanden werden kann: eine ihrer möglichen
  /// Grundformen ist bekannt. Unbestimmte Formen gelten als unbekannt; eine
  /// als Eigenname vermutete Form nur dann als bekannt, wenn sie zu einem
  /// Namen der Liste gehört.
  bool knowsToken(CorpusToken token) {
    if (token.reliability == AnalysisReliability.properNameGuess) {
      return BiblicalNames.containsForm(token.word);
    }

    if (!token.isAnalyzed) return false;

    return token.readings.any((r) => isKnown(r.lemma, r));
  }
}

/// Eine mögliche Grundform einer Vokabelhilfe.
class HintLemma {
  final String lemma;

  /// Grundform, bei Nomen mit Genitiv und Artikel ("ἀρχή, ἀρχῆς, ἡ").
  final String headword;

  /// Kurze deutsche Bedeutungen (höchstens [maxGlossesPerHint]); leer, wenn
  /// die Grundform ungelöst oder ein Eigenname ist.
  final List<String> meanings;
  final MeaningSource source;
  final int? step;

  /// Eigenname außerhalb von [BiblicalNames].
  final bool properName;

  const HintLemma({
    required this.lemma,
    required this.headword,
    required this.meanings,
    required this.source,
    this.step,
    this.properName = false,
  });

  /// Keine gesicherte deutsche Bedeutung vorhanden.
  bool get unresolved => meanings.isEmpty && !properName;
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

  /// Ohne deutsche Bedeutung: unbestimmte Form oder ungelöste Grundform.
  bool get unresolved => unanalyzed || lemmas.any((l) => l.unresolved);
}

/// Erstellt die Vokabelhilfen eines Textes:
///
/// 1. Grundform(en) jeder Form aus der Bestimmung (im NT die des Kontexts);
/// 2. bekannt nach [VocabularyKnowledge] → keine Hilfe;
/// 3. sonst eine Hilfe je Grundform (nicht je Form) mit kurzer deutscher
///    Bedeutung: Vokabelliste, sonst Lexikon; ohne deutsche Quelle bleibt
///    die Grundform ungelöst ([HintLemma.unresolved]).
class VocabularyHelpBuilder {
  final VocabularyKnowledge knowledge;
  final GreekLexicon lexicon;

  const VocabularyHelpBuilder(this.knowledge, this.lexicon);

  /// Großgeschriebene Grundform. Das allein macht ein Wort weder bekannt
  /// noch zum Eigennamen (Ἰουδαϊκός, Ἑβραϊστί); siehe [_isProperName].
  static bool isCapitalized(String lemma) =>
      RegExp(r'^\p{Lu}', unicode: true).hasMatch(lemma);

  static bool _isProperName(String lemma, LemmaAnalysis? analysis) =>
      isCapitalized(lemma) &&
      (analysis == null || analysis.analysis.pos == "N-");

  static const Map<String, String> _articles = {"M": "ὁ", "F": "ἡ", "N": "τό"};

  HintLemma _lemma(String lemma, LemmaAnalysis? analysis) {
    final entries = knowledge.matcher.entriesFor(lemma, analysis);

    if (entries.isNotEmpty) {
      final first = entries.first;

      return HintLemma(
        lemma: lemma,
        headword: [first.lemma, ?first.genitive, ?first.article].join(", "),
        meanings: shortGlosses([for (final e in entries) ...e.translations]),
        source: MeaningSource.vocabulary,
        step: entries.map((e) => e.step).reduce((a, b) => a < b ? a : b),
      );
    }

    final entry = lexicon[lemma];
    final a = analysis?.analysis;
    final article = a != null && a.pos == "N-" ? _articles[a.gender] : null;
    final headword = [lemma, ?article].join(", ");

    if (entry != null && entry.german.isNotEmpty) {
      return HintLemma(
        lemma: lemma,
        headword: headword,
        // Beim Import bereits gekürzt.
        meanings: entry.german.take(maxGlossesPerHint).toList(),
        source: entry.source,
      );
    }

    return HintLemma(
      lemma: lemma,
      headword: headword,
      meanings: const [],
      source: MeaningSource.none,
      properName: _isProperName(lemma, analysis),
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

        key = (byLemma.keys.map(greekFormKey).toList()..sort()).join("|");
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
