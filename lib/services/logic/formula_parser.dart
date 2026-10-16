import 'formula.dart';

/// Welche Sprache eingelesen wird.
enum LogicLanguage {
  /// Aussagenlogik: Satzbuchstaben p, q, r, s (…), keine Quantoren.
  propositional,

  /// Prädikatenlogik: Prädikate, Individuen, Variablen, Quantoren.
  predicate,
}

/// Ergebnis des Einlesens eines Ausdrucks.
class ParseResult {
  final Formula? formula;

  /// Wurden die äußersten Klammern nach der Klammerersparnisregel
  /// weggelassen?
  final bool outerParenthesesOmitted;

  /// Begründung, warum der Ausdruck kein Satz (bzw. keine Formel) ist.
  final String? error;

  const ParseResult._(this.formula, this.outerParenthesesOmitted, this.error);

  bool get ok => formula != null;
}

class _Token {
  final String value;

  /// Position in der normalisierten Zeichenfolge.
  final int position;

  const _Token(this.value, this.position);
}

class _ParseError implements Exception {
  final String message;
  final int position;

  _ParseError(this.message, this.position);
}

/// Liest Ausdrücke nach der Grammatik des Kurses ein.
///
/// Zweistellige Verknüpfungen stehen immer in Klammern; nur die äußersten
/// Klammern eines Satzes der Form (A ∧ B), (A ∨ B), (A → B), (A ↔ B) dürfen
/// fehlen (Klammerersparnisregel). Um eine Negation, einen elementaren Satz
/// oder einen quantifizierten Satz stehen keine Klammern.
///
/// Neben den Zeichen des Alphabets werden zur bequemen Eingabe akzeptiert:
/// `~ ! -` für ¬, `& ^` für ∧, `v |` für ∨, `->` `=>` für →, `<->` `<=>`
/// für ↔.
class FormulaParser {
  FormulaParser._();

  static const Map<String, String> _aliases = {
    "<->": "↔",
    "<=>": "↔",
    "<>": "↔",
    "⇔": "↔",
    "->": "→",
    "=>": "→",
    "⇒": "→",
    "⊃": "→",
    "~": "¬",
    "∼": "¬",
    "!": "¬",
    "-": "¬",
    "&": "∧",
    "^": "∧",
    "|": "∨",
    "v": "∨",
  };

  static const String _binarySymbols = "∧∨→↔";

  /// Ersetzt die Eingabehilfen durch die Zeichen des Alphabets und entfernt
  /// Leerzeichen.
  static String normalize(String input) {
    final buffer = StringBuffer();
    var i = 0;

    outer:
    while (i < input.length) {
      final c = input[i];

      if (c.trim().isEmpty) {
        i++;
        continue;
      }

      for (final alias in _aliases.entries) {
        if (input.startsWith(alias.key, i)) {
          buffer.write(alias.value);
          i += alias.key.length;
          continue outer;
        }
      }

      buffer.write(c);
      i++;
    }

    return buffer.toString();
  }

  /// Ist [input] ein Satz bzw. eine Formel (PL: auch Satzfunktionen)?
  /// Wendet die Klammerersparnisregel an.
  static ParseResult parse(
    String input, {
    LogicLanguage language = LogicLanguage.propositional,
  }) {
    final text = normalize(input);

    if (text.isEmpty) {
      return const ParseResult._(null, false, "Es wurde nichts eingegeben.");
    }

    final alphabetError = _checkAlphabet(text, language);
    if (alphabetError != null) {
      return ParseResult._(null, false, alphabetError);
    }

    final strict = _tryStrict(text, language);
    if (strict.formula != null) {
      return ParseResult._(strict.formula, false, null);
    }

    // Klammerersparnisregel: äußerste Klammern eines zweistelligen Satzes.
    final wrapped = _tryStrict("($text)", language);
    if (wrapped.formula is Binary) {
      return ParseResult._(wrapped.formula, true, null);
    }

    return ParseResult._(null, false, _diagnose(text, language, strict));
  }

  /// Liest einen Satz ein und wirft bei einem Fehler (für Inhalte, die als
  /// korrekt bekannt sind).
  static Formula parseOrThrow(
    String input, {
    LogicLanguage? language,
  }) {
    final lang = language ?? guessLanguage(input);
    final result = parse(input, language: lang);
    if (result.formula == null) {
      throw FormatException("Kein Satz: $input (${result.error})");
    }
    return result.formula!;
  }

  /// PL, sobald ein Großbuchstabe oder Quantor vorkommt.
  static LogicLanguage guessLanguage(String input) {
    final text = normalize(input);
    final pl = text.split("").any(
      (c) => c == "∀" || c == "∃" || LogicAlphabet.isPredicate(c),
    );
    return pl ? LogicLanguage.predicate : LogicLanguage.propositional;
  }

  static String? _checkAlphabet(String text, LogicLanguage language) {
    for (var i = 0; i < text.length; i++) {
      final c = text[i];

      if ("¬()".contains(c) || _binarySymbols.contains(c)) continue;

      if (language == LogicLanguage.propositional) {
        if (LogicAlphabet.isSentenceLetter(c)) continue;
        if (c == "∀" || c == "∃" || LogicAlphabet.isPredicate(c)) {
          return "„$c“ gehört zur Prädikatenlogik, nicht zum Alphabet der "
              "Aussagenlogik.";
        }
        return "Das Zeichen „$c“ gehört nicht zum Alphabet der Aussagenlogik "
            "(Satzbuchstaben ${LogicAlphabet.sentenceLetters.split("").join(", ")}, "
            "Operatoren ¬ ∧ ∨ → ↔ und Klammern).";
      }

      if (c == "∀" ||
          c == "∃" ||
          LogicAlphabet.isPredicate(c) ||
          LogicAlphabet.isIndividual(c) ||
          LogicAlphabet.isVariable(c)) {
        continue;
      }

      if (LogicAlphabet.isSentenceLetter(c)) {
        return "Satzbuchstaben wie „$c“ kommen in der Sprache PL nicht vor. "
            "Elementare Sätze haben die Form Pi oder Pij.";
      }

      return "Das Zeichen „$c“ gehört nicht zum Alphabet der Prädikatenlogik.";
    }

    return null;
  }

  static ({Formula? formula, _ParseError? error}) _tryStrict(
    String text,
    LogicLanguage language,
  ) {
    final tokens = [
      for (var i = 0; i < text.length; i++) _Token(text[i], i),
    ];

    final parser = _StrictParser(tokens, language);

    try {
      final f = parser.parseFormula();
      if (parser.index != tokens.length) {
        throw _ParseError(
          "Nach dem vollständigen Satz „${f.show(top: false)}“ folgen noch "
          "weitere Zeichen.",
          parser.index,
        );
      }
      return (formula: f, error: null);
    } on _ParseError catch (e) {
      return (formula: null, error: e);
    }
  }

  /// Sucht eine verständliche Begründung, warum kein Satz vorliegt.
  static String _diagnose(
    String text,
    LogicLanguage language,
    ({Formula? formula, _ParseError? error}) strict,
  ) {
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == "(") depth++;
      if (text[i] == ")") depth--;
      if (depth < 0) {
        return "An Stelle ${i + 1} wird eine Klammer geschlossen, die nie "
            "geöffnet wurde.";
      }
    }
    if (depth > 0) {
      return "Es werden mehr Klammern geöffnet als geschlossen.";
    }

    // Klammerpaare untersuchen: Jedes Paar muss genau einen zweistelligen
    // Operator auf seiner eigenen Ebene umschließen.
    final groups = _groups(text);

    for (final g in groups) {
      final inner = text.substring(g.$1 + 1, g.$2);
      final ops = _topLevelOperators(inner);

      if (inner.isEmpty) {
        return "Ein leeres Klammerpaar „()“ ist in keiner Satzform "
            "vorgesehen.";
      }

      if (ops.isEmpty) {
        final piece = _tryStrict(inner, language).formula;
        if (piece != null) {
          return "Um „${piece.show()}“ stehen Klammern. Klammern gehören "
              "nach der Definition nur zu den zweistelligen Verknüpfungen "
              "(A ∧ B), (A ∨ B), (A → B), (A ↔ B) – nicht um "
              "${_article(piece)}. Die Klammerersparnisregel erlaubt nur, "
              "Klammern wegzulassen, nicht, welche hinzuzufügen.";
        }
      }

      if (ops.length > 1) {
        return "In „(${_pretty(inner)})“ stehen ${ops.length} zweistellige Operatoren "
            "(${ops.join(", ")}) auf derselben Klammerebene. Jede "
            "zweistellige Verknüpfung braucht ein eigenes Klammerpaar; die "
            "Klammerersparnisregel gilt nur für die äußersten Klammern "
            "eines ganzen Satzes.";
      }
    }

    final topOps = _topLevelOperators(text);
    if (topOps.length > 1) {
      return "Auf der obersten Ebene stehen ${topOps.length} zweistellige "
          "Operatoren (${topOps.join(", ")}) ohne trennende Klammern. Man "
          "kann nicht entscheiden, welcher der Hauptoperator ist – nach der "
          "Definition ist das kein Satz. Die Klammerersparnisregel erlaubt "
          "nur, das äußerste Klammerpaar wegzulassen.";
    }

    final e = strict.error;
    if (e != null) return e.message;

    return "Der Ausdruck entspricht keiner der Satzformen der Definition.";
  }

  /// Leerzeichen um zweistellige Operatoren, wie in der Kursschreibweise.
  static String _pretty(String text) {
    final buffer = StringBuffer();
    for (final c in text.split("")) {
      buffer.write(_binarySymbols.contains(c) ? " $c " : c);
    }
    return buffer.toString();
  }

  static String _article(Formula f) {
    switch (f) {
      case Negation():
        return "eine Negation";
      case Quantified():
        return "einen quantifizierten Ausdruck";
      default:
        return "einen elementaren Satz";
    }
  }

  /// Klammerpaare (Öffnen, Schließen) in Leserichtung.
  static List<(int, int)> _groups(String text) {
    final stack = <int>[];
    final result = <(int, int)>[];

    for (var i = 0; i < text.length; i++) {
      if (text[i] == "(") stack.add(i);
      if (text[i] == ")" && stack.isNotEmpty) {
        result.add((stack.removeLast(), i));
      }
    }

    result.sort((a, b) => a.$1.compareTo(b.$1));
    return result;
  }

  static List<String> _topLevelOperators(String text) {
    final ops = <String>[];
    var depth = 0;

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == "(") depth++;
      if (c == ")") depth--;
      if (depth == 0 && _binarySymbols.contains(c)) ops.add(c);
    }

    return ops;
  }
}

class _StrictParser {
  final List<_Token> tokens;
  final LogicLanguage language;
  int index = 0;

  _StrictParser(this.tokens, this.language);

  String? get _peek => index < tokens.length ? tokens[index].value : null;

  int get _pos => index < tokens.length ? tokens[index].position : -1;

  Never _fail(String message) => throw _ParseError(message, _pos);

  Formula parseFormula() {
    final c = _peek;

    if (c == null) {
      _fail("Der Ausdruck endet, wo noch ein Satz folgen müsste.");
    }

    if (c == "¬") {
      index++;
      return Negation(parseFormula());
    }

    if (c == "(") {
      index++;
      final left = parseFormula();
      final op = _peek;

      if (op == null || !FormulaParser._binarySymbols.contains(op)) {
        _fail(
          "Nach „(${left.show(top: false)}“ müsste ein zweistelliger "
          "Operator (∧, ∨, →, ↔) folgen. Klammern stehen nur um "
          "zweistellige Verknüpfungen.",
        );
      }

      index++;
      final right = parseFormula();

      if (_peek != ")") {
        _fail(
          "Nach „(${left.show(top: false)} $op ${right.show(top: false)}“ "
          "fehlt die schließende Klammer.",
        );
      }

      index++;

      return Binary(
        BinaryOperator.values.firstWhere((o) => o.symbol == op),
        left,
        right,
      );
    }

    if (c == "∀" || c == "∃") {
      index++;
      final v = _peek;

      if (v == null || !LogicAlphabet.isVariable(v)) {
        _fail("Auf einen Quantor muss eine Variable (x, y, z) folgen.");
      }

      index++;

      return Quantified(
        c == "∀" ? Quantifier.all : Quantifier.exists,
        v,
        parseFormula(),
      );
    }

    if (language == LogicLanguage.propositional) {
      if (LogicAlphabet.isSentenceLetter(c)) {
        index++;
        return Letter(c);
      }

      if (c == ")") _fail("Hier steht eine schließende Klammer zu viel.");

      _fail("An dieser Stelle müsste ein Satz beginnen.");
    }

    if (LogicAlphabet.isPredicate(c)) {
      index++;
      final terms = <String>[];

      while (_peek != null &&
          (LogicAlphabet.isIndividual(_peek!) ||
              LogicAlphabet.isVariable(_peek!))) {
        terms.add(_peek!);
        index++;
      }

      if (terms.isEmpty) {
        _fail(
          "Auf das Prädikat $c muss ein Individuum oder eine Variable "
          "folgen.",
        );
      }

      if (terms.length > 2) {
        _fail(
          "Im Kurs gibt es nur ein- und zweistellige Prädikate; $c hat "
          "hier ${terms.length} Stellen.",
        );
      }

      return Predication(c, terms);
    }

    if (LogicAlphabet.isIndividual(c) || LogicAlphabet.isVariable(c)) {
      _fail(
        "„$c“ steht ohne Prädikat. Elementare Sätze haben die Form Pi oder "
        "Pij.",
      );
    }

    if (c == ")") _fail("Hier steht eine schließende Klammer zu viel.");

    _fail("An dieser Stelle müsste ein Satz beginnen.");
  }
}

/// Bequemer Zugriff in Tests und Inhalten.
Formula parseFormula(String input) => FormulaParser.parseOrThrow(input);
