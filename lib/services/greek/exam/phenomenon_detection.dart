import '../../../models/greek/exam/corpus_token.dart';
import '../../../utils/greek_normalization.dart';
import 'greek_form_key.dart';

/// Erkennung grammatischer Phänomene in einer Folge von Wortformen.
///
/// Jede Regel läuft in zwei Modi ([DetectionMode]):
///
/// * **sicher** – das Phänomen liegt nach allen bekannten Bestimmungen vor
///   (bei im Kontext bestimmten Formen: nach der Kontextbestimmung);
/// * **möglich** – mindestens eine bekannte Bestimmung erlaubt es.
///
/// Ein geforderter Filter verlangt einen sicheren Treffer, ein Ausschluss
/// verlangt, dass nicht einmal ein möglicher vorliegt. So bleibt die
/// Mehrdeutigkeit einer Form erhalten, statt geraten zu werden.
enum DetectionMode { certain, possible }

typedef AnalysisTest = bool Function(LemmaAnalysis analysis);

/// Zusatzwissen der Regeln, das nicht an der einzelnen Form hängt.
class DetectionContext {
  /// Deklinationsklasse (1–3) eines Nomens laut Wörterbuch; `null`, wenn
  /// unbekannt.
  final int? Function(String lemma) declensionOf;

  const DetectionContext({this.declensionOf = _unknownDeclension});

  static int? _unknownDeclension(String lemma) => null;
}

/// Sicht der Regeln auf die Wortformen in einem Modus.
class DetectionView {
  final List<CorpusToken> tokens;
  final DetectionMode mode;
  final DetectionContext context;

  const DetectionView(
    this.tokens,
    this.mode, {
    this.context = const DetectionContext(),
  });

  int get length => tokens.length;

  bool _isCertainly(int i, AnalysisTest test) {
    final token = tokens[i];
    final readings = token.readings;
    return token.isAnalyzed && readings.isNotEmpty && readings.every(test);
  }

  bool _isPossibly(int i, AnalysisTest test) {
    final token = tokens[i];
    return token.isAnalyzed && token.readings.any(test);
  }

  /// Ob die Form [i] den Test im aktuellen Modus erfüllt.
  bool holds(int i, AnalysisTest test) {
    if (i < 0 || i >= tokens.length) return false;

    return mode == DetectionMode.certain
        ? _isCertainly(i, test)
        : _isPossibly(i, test);
  }

  /// Ob die Form [i] den Test im aktuellen Modus *nicht* erfüllt. Sicher
  /// heißt: keine bekannte Bestimmung erfüllt ihn (und die Form ist
  /// bestimmt); möglich heißt: nicht alle erfüllen ihn. Außerhalb des Textes
  /// gilt jeder Test als nicht erfüllt.
  bool holdsNot(int i, AnalysisTest test) {
    if (i < 0 || i >= tokens.length) return true;

    return mode == DetectionMode.certain
        ? tokens[i].isAnalyzed && !_isPossibly(i, test)
        : !_isCertainly(i, test);
  }

  /// Satzgrenze nach der Form [i] (Punkt, Hochpunkt, Fragezeichen).
  bool endsSentence(int i) => endsGreekSentence(tokens[i].surface);

  /// Satzteilgrenze nach der Form [i] (zusätzlich Komma).
  bool endsClause(int i) {
    final surface = tokens[i].surface.trimRight();
    return endsSentence(i) || surface.endsWith(',');
  }

  /// Bereich des Satzes, in dem die Form [i] steht (einschließlich).
  (int, int) sentenceOf(int i) {
    var start = i;
    while (start > 0 && !endsSentence(start - 1)) {
      start--;
    }

    var end = i;
    while (end < tokens.length - 1 && !endsSentence(end)) {
      end++;
    }

    return (start, end);
  }

  /// Bereich des Satzteils (bis Komma/Satzzeichen), in dem [i] steht.
  (int, int) clauseOf(int i) {
    var start = i;
    while (start > 0 && !endsClause(start - 1)) {
      start--;
    }

    var end = i;
    while (end < tokens.length - 1 && !endsClause(end)) {
      end++;
    }

    return (start, end);
  }
}

// -----------------------------------------------------------------------------
// MUSTER FÜR BESTIMMUNGEN
// -----------------------------------------------------------------------------

/// Ein Muster über die Felder einer Bestimmung: je Feld die zulässigen
/// Codes (siehe `GreekMorphAnalysis`); `null` = beliebig.
class MorphPattern {
  final Set<String>? pos;
  final String? person;
  final String? tense;
  final String? voice;
  final String? mood;
  final String? grammaticalCase;
  final String? number;
  final String? gender;
  final String? degree;

  const MorphPattern({
    this.pos,
    this.person,
    this.tense,
    this.voice,
    this.mood,
    this.grammaticalCase,
    this.number,
    this.gender,
    this.degree,
  });

  static const MorphPattern verb = MorphPattern(pos: {"V-"});
  static const MorphPattern finiteVerb = MorphPattern(
    pos: {"V-"},
    mood: "ISOD",
  );
  static const MorphPattern participle = MorphPattern(pos: {"V-"}, mood: "P");
  static const MorphPattern infinitive = MorphPattern(pos: {"V-"}, mood: "N");
  static const MorphPattern article = MorphPattern(pos: {"RA"});
  static const MorphPattern preposition = MorphPattern(pos: {"P-"});

  /// Nominale Wortarten, die als Bezugswort in Frage kommen (Nomen,
  /// Adjektiv, Pronomen außer dem Relativpronomen).
  static const MorphPattern nominal = MorphPattern(
    pos: {"N-", "A-", "RP", "RD", "RI"},
  );

  static bool _field(String? allowed, String value) {
    return allowed == null || allowed.contains(value);
  }

  bool matches(LemmaAnalysis a) {
    final m = a.analysis;

    return (pos == null || pos!.contains(m.pos)) &&
        _field(person, m.person) &&
        _field(tense, m.tense) &&
        _field(voice, m.voice) &&
        _field(mood, m.mood) &&
        _field(grammaticalCase, m.grammaticalCase) &&
        _field(number, m.number) &&
        _field(gender, m.gender) &&
        _field(degree, m.degree);
  }
}

/// Vergleichsform einer Grundform: ohne Akzente und Spiritus, damit
/// Komposita über die Endung erkannt werden (ἀπέρχομαι → απερχομαι).
String lemmaComparisonKey(String lemma) {
  return normalizeGreekForComparison(lemma);
}

/// Grundformen als Menge, unabhängig von Akzentsetzung und Schreibung
/// (ς/σ) verglichen.
class LemmaSet {
  final Set<String> _keys;

  LemmaSet(Iterable<String> lemmas)
    : _keys = {for (final lemma in lemmas) greekFormKey(lemma)};

  bool contains(String lemma) => _keys.contains(greekFormKey(lemma));
}

// -----------------------------------------------------------------------------
// REGELN
// -----------------------------------------------------------------------------

/// Eine Erkennungsregel. Liefert die Positionen der Belegformen (leer = kein
/// Treffer). Regeln haben keinen Zustand und sind einzeln testbar.
abstract class PhenomenonDetector {
  const PhenomenonDetector();

  List<int> detect(DetectionView view);
}

/// Treffer an jeder Form, deren Bestimmung zum Muster passt.
class MorphDetector extends PhenomenonDetector {
  final MorphPattern pattern;

  const MorphDetector(this.pattern);

  @override
  List<int> detect(DetectionView view) {
    return [
      for (var i = 0; i < view.length; i++)
        if (view.holds(i, pattern.matches)) i,
    ];
  }
}

/// Treffer an jeder Form einer der Grundformen [lemmas] (optional mit
/// Muster). Mit [compounds] zählen auch Komposita, erkannt an der Endung der
/// Grundform (ohne Akzente: ἐκβάλλω endet auf βαλλω).
class LemmaDetector extends PhenomenonDetector {
  final List<String> lemmas;
  final MorphPattern? pattern;
  final bool compounds;

  const LemmaDetector(this.lemmas, {this.pattern, this.compounds = false});

  bool _lemmaMatches(String lemma) {
    if (!compounds) {
      final key = greekFormKey(lemma);
      return lemmas.any((l) => greekFormKey(l) == key);
    }

    final key = lemmaComparisonKey(lemma);
    return lemmas.any((l) => key.endsWith(lemmaComparisonKey(l)));
  }

  bool test(LemmaAnalysis a) {
    return _lemmaMatches(a.lemma) && (pattern?.matches(a) ?? true);
  }

  @override
  List<int> detect(DetectionView view) {
    return [
      for (var i = 0; i < view.length; i++)
        if (view.holds(i, test)) i,
    ];
  }
}

/// Treffer an Formen, deren Grundform auf eine der [suffixes] endet
/// (ohne Akzente verglichen), außer den Grundformen in [except].
class LemmaSuffixDetector extends PhenomenonDetector {
  final List<String> suffixes;
  final List<String> except;
  final MorphPattern? pattern;

  const LemmaSuffixDetector(
    this.suffixes, {
    this.except = const [],
    this.pattern,
  });

  bool test(LemmaAnalysis a) {
    final key = lemmaComparisonKey(a.lemma);

    return suffixes.any((s) => key.endsWith(lemmaComparisonKey(s))) &&
        !except.any((e) => key.endsWith(lemmaComparisonKey(e))) &&
        (pattern?.matches(a) ?? true);
  }

  @override
  List<int> detect(DetectionView view) {
    return [
      for (var i = 0; i < view.length; i++)
        if (view.holds(i, test)) i,
    ];
  }
}

/// Nomen einer Deklinationsklasse laut Wörterbuch ([DetectionContext]).
class DeclensionDetector extends PhenomenonDetector {
  final int declension;

  const DeclensionDetector(this.declension);

  @override
  List<int> detect(DetectionView view) {
    bool test(LemmaAnalysis a) =>
        a.analysis.pos == "N-" &&
        view.context.declensionOf(a.lemma) == declension;

    return [
      for (var i = 0; i < view.length; i++)
        if (view.holds(i, test)) i,
    ];
  }
}

/// Regel, die ihre Logik als Funktion mitbringt (Satzkonstruktionen). Die
/// Funktionen stehen in `syntax_rules.dart` und sind dort einzeln getestet.
class RuleDetector extends PhenomenonDetector {
  final List<int> Function(DetectionView view) rule;

  const RuleDetector(this.rule);

  @override
  List<int> detect(DetectionView view) => rule(view);
}

/// Treffer, wenn die Grundformen [first] und [second] unmittelbar
/// aufeinander folgen (οὐ μή).
class AdjacentLemmaDetector extends PhenomenonDetector {
  final String first;
  final String second;

  const AdjacentLemmaDetector(this.first, this.second);

  @override
  List<int> detect(DetectionView view) {
    final a = greekFormKey(first);
    final b = greekFormKey(second);

    return [
      for (var i = 0; i + 1 < view.length; i++)
        if (view.holds(i, (x) => greekFormKey(x.lemma) == a) &&
            view.holds(i + 1, (x) => greekFormKey(x.lemma) == b))
          i,
    ];
  }
}
