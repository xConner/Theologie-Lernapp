/// Formeln der Aussagenlogik (AL) und Prädikatenlogik (PL) im Lernbereich
/// „Einführung in die Logik“.
///
/// Die Klassen bilden genau die Satzformen des Kurses ab:
///
///   * elementare Sätze: Satzbuchstaben (AL) bzw. `Pi`, `Pij` (PL)
///   * `¬A`, `(A ∧ B)`, `(A ∨ B)`, `(A → B)`, `(A ↔ B)`
///   * `∀xAx`, `∃xAx` (PL)
///
/// Gleichheit ist strukturell; gebundene Variablen werden dabei nicht nach
/// ihrem Namen, sondern nach ihrer Bindung verglichen (`∀xFx` = `∀yFy`).
library;

/// Zweistellige Operatoren.
enum BinaryOperator {
  and("∧", "Konjunktion"),
  or("∨", "Adjunktion"),
  implies("→", "Implikation"),
  iff("↔", "Äquivalenz");

  final String symbol;

  /// Bezeichnung eines Satzes mit diesem Hauptoperator.
  final String sentenceName;

  const BinaryOperator(this.symbol, this.sentenceName);
}

enum Quantifier {
  all("∀", "Allquantor", "allquantifizierter Satz"),
  exists("∃", "Existenzquantor", "existenzquantifizierter Satz");

  final String symbol;
  final String title;
  final String sentenceName;

  const Quantifier(this.symbol, this.title, this.sentenceName);
}

/// Zeichen des Alphabets.
class LogicAlphabet {
  LogicAlphabet._();

  /// Satzbuchstaben von AL (im Kurs p, q, r, s; erweiterbar).
  static const String sentenceLetters = "pqrstu";

  /// Individuenkonstanten von PL.
  static const String individuals = "abcde";

  /// Variablen von PL.
  static const String variables = "xyzw";

  /// Prädikate von PL (Großbuchstaben).
  static const String predicates = "FGHIJKLMNOPQRSTUW";

  static bool isSentenceLetter(String c) => sentenceLetters.contains(c);
  static bool isIndividual(String c) => individuals.contains(c);
  static bool isVariable(String c) => variables.contains(c);
  static bool isPredicate(String c) => predicates.contains(c);
}

sealed class Formula {
  const Formula();

  /// Ausgabe in der Schreibweise des Kurses; [top] = äußerste Ebene, dort
  /// werden die äußeren Klammern nach der Klammerersparnisregel weggelassen.
  String show({bool top = true});

  /// Vollständige Schreibweise ohne Klammerersparnis.
  String get full => show(top: false);

  @override
  String toString() => show();

  /// Kanonischer Schlüssel für Gleichheit (gebundene Variablen als Index).
  String get key => _key(const []);

  String _key(List<String> bound);

  @override
  bool operator ==(Object other) => other is Formula && other.key == key;

  @override
  int get hashCode => key.hashCode;

  /// Name des Satztyps (für Syntaxbäume und Erklärungen).
  String get typeName;

  /// Unmittelbare Teilsätze bzw. Teilformeln.
  List<Formula> get children;

  /// Frei vorkommende Variablen.
  Set<String> get freeVariables;

  /// Vorkommende Individuenkonstanten.
  Set<String> get individuals;

  /// Vorkommende Satzbuchstaben (nur AL).
  Set<String> get letters;

  /// Prädikate (nur PL).
  Set<String> get predicates;

  /// Ersetzt alle freien Vorkommen der Variablen [variable] durch [term].
  Formula substitute(String variable, String term);

  /// Ersetzt alle Vorkommen der Individuenkonstante [individual] durch
  /// [term].
  Formula replaceIndividual(String individual, String term);

  /// Ersetzt Satzbuchstaben gleichzeitig durch Formeln.
  Formula substituteLetters(Map<String, Formula> map);

  bool get isElementary => this is Letter || this is Predication;

  /// Enthält die Formel Prädikate oder Quantoren?
  bool get isPredicateLogic => predicates.isNotEmpty;

  /// Anzahl der Operatoren und Quantoren.
  int get size => (isElementary ? 0 : 1) + children.fold(0, (s, c) => s + c.size);

  /// Tiefe des Syntaxbaums (elementar = 0).
  int get depth => isElementary
      ? 0
      : 1 + children.map((c) => c.depth).fold(0, (a, b) => a > b ? a : b);

  /// Alle Teilformeln in Auswertungsreihenfolge (innen vor außen, links vor
  /// rechts), jede nur einmal.
  List<Formula> get subformulas {
    final result = <Formula>[];

    void visit(Formula f) {
      for (final c in f.children) {
        visit(c);
      }
      if (!result.contains(f)) result.add(f);
    }

    visit(this);
    return result;
  }
}

/// Satzbuchstabe (elementarer Satz in AL).
class Letter extends Formula {
  final String name;

  const Letter(this.name);

  @override
  String show({bool top = true}) => name;

  @override
  String _key(List<String> bound) => name;

  @override
  String get typeName => "elementarer Satz";

  @override
  List<Formula> get children => const [];

  @override
  Set<String> get freeVariables => const {};

  @override
  Set<String> get individuals => const {};

  @override
  Set<String> get letters => {name};

  @override
  Set<String> get predicates => const {};

  @override
  Formula substitute(String variable, String term) => this;

  @override
  Formula replaceIndividual(String individual, String term) => this;

  @override
  Formula substituteLetters(Map<String, Formula> map) => map[name] ?? this;
}

/// Elementarer Satz bzw. elementare Satzfunktion in PL: `Fa`, `Fab`, `Fx`.
class Predication extends Formula {
  final String predicate;

  /// Individuenkonstanten oder Variablen (je ein Buchstabe).
  final List<String> terms;

  const Predication(this.predicate, this.terms);

  @override
  String show({bool top = true}) => "$predicate${terms.join()}";

  @override
  String _key(List<String> bound) {
    final args = terms.map((t) {
      final index = bound.lastIndexOf(t);
      return index >= 0 ? "#${bound.length - index}" : t;
    });
    return "$predicate(${args.join(",")})";
  }

  @override
  String get typeName => "elementarer Satz";

  @override
  List<Formula> get children => const [];

  @override
  Set<String> get freeVariables => terms.where(LogicAlphabet.isVariable).toSet();

  @override
  Set<String> get individuals =>
      terms.where(LogicAlphabet.isIndividual).toSet();

  @override
  Set<String> get letters => const {};

  @override
  Set<String> get predicates => {predicate};

  @override
  Formula substitute(String variable, String term) => Predication(
    predicate,
    [for (final t in terms) t == variable ? term : t],
  );

  @override
  Formula replaceIndividual(String individual, String term) => Predication(
    predicate,
    [for (final t in terms) t == individual ? term : t],
  );

  @override
  Formula substituteLetters(Map<String, Formula> map) => this;
}

class Negation extends Formula {
  final Formula operand;

  const Negation(this.operand);

  @override
  String show({bool top = true}) => "¬${operand.show(top: false)}";

  @override
  String _key(List<String> bound) => "¬${operand._key(bound)}";

  @override
  String get typeName => "Negation";

  @override
  List<Formula> get children => [operand];

  @override
  Set<String> get freeVariables => operand.freeVariables;

  @override
  Set<String> get individuals => operand.individuals;

  @override
  Set<String> get letters => operand.letters;

  @override
  Set<String> get predicates => operand.predicates;

  @override
  Formula substitute(String variable, String term) =>
      Negation(operand.substitute(variable, term));

  @override
  Formula replaceIndividual(String individual, String term) =>
      Negation(operand.replaceIndividual(individual, term));

  @override
  Formula substituteLetters(Map<String, Formula> map) =>
      Negation(operand.substituteLetters(map));
}

class Binary extends Formula {
  final BinaryOperator op;
  final Formula left;
  final Formula right;

  const Binary(this.op, this.left, this.right);

  @override
  String show({bool top = true}) {
    final inner =
        "${left.show(top: false)} ${op.symbol} ${right.show(top: false)}";
    return top ? inner : "($inner)";
  }

  @override
  String _key(List<String> bound) =>
      "(${left._key(bound)}${op.symbol}${right._key(bound)})";

  @override
  String get typeName => op.sentenceName;

  @override
  List<Formula> get children => [left, right];

  @override
  Set<String> get freeVariables => {...left.freeVariables, ...right.freeVariables};

  @override
  Set<String> get individuals => {...left.individuals, ...right.individuals};

  @override
  Set<String> get letters => {...left.letters, ...right.letters};

  @override
  Set<String> get predicates => {...left.predicates, ...right.predicates};

  @override
  Formula substitute(String variable, String term) => Binary(
    op,
    left.substitute(variable, term),
    right.substitute(variable, term),
  );

  @override
  Formula replaceIndividual(String individual, String term) => Binary(
    op,
    left.replaceIndividual(individual, term),
    right.replaceIndividual(individual, term),
  );

  @override
  Formula substituteLetters(Map<String, Formula> map) =>
      Binary(op, left.substituteLetters(map), right.substituteLetters(map));
}

class Quantified extends Formula {
  final Quantifier quantifier;
  final String variable;

  /// Bereich des Quantors.
  final Formula body;

  const Quantified(this.quantifier, this.variable, this.body);

  @override
  String show({bool top = true}) =>
      "${quantifier.symbol}$variable${body.show(top: false)}";

  @override
  String _key(List<String> bound) =>
      "${quantifier.symbol}.${body._key([...bound, variable])}";

  @override
  String get typeName => quantifier.sentenceName;

  @override
  List<Formula> get children => [body];

  @override
  Set<String> get freeVariables => body.freeVariables.difference({variable});

  @override
  Set<String> get individuals => body.individuals;

  @override
  Set<String> get letters => body.letters;

  @override
  Set<String> get predicates => body.predicates;

  @override
  Formula substitute(String v, String term) => v == variable
      ? this
      : Quantified(quantifier, variable, body.substitute(v, term));

  @override
  Formula replaceIndividual(String individual, String term) =>
      Quantified(quantifier, variable, body.replaceIndividual(individual, term));

  @override
  Formula substituteLetters(Map<String, Formula> map) => this;

  /// `Ai`: der Bereich mit [individual] statt der gebundenen Variablen.
  Formula instantiate(String individual) => body.substitute(variable, individual);
}

// Kurze Konstruktoren für Tests und Generatoren.
Formula neg(Formula a) => Negation(a);
Formula and(Formula a, Formula b) => Binary(BinaryOperator.and, a, b);
Formula or(Formula a, Formula b) => Binary(BinaryOperator.or, a, b);
Formula imp(Formula a, Formula b) => Binary(BinaryOperator.implies, a, b);
Formula iff(Formula a, Formula b) => Binary(BinaryOperator.iff, a, b);

/// Entfernt alle doppelten Negationen an jeder Stelle (Argumente 6.2):
/// Zwei Sätze lassen sich durch Hinzufügen/Streichen doppelter Negationen
/// ineinander überführen genau dann, wenn ihre Normalformen gleich sind.
Formula stripDoubleNegations(Formula f) {
  switch (f) {
    case Negation(operand: Negation(operand: final inner)):
      return stripDoubleNegations(inner);
    case Negation(operand: final o):
      final s = stripDoubleNegations(o);
      return s is Negation ? s.operand : Negation(s);
    case Binary(op: final op, left: final l, right: final r):
      return Binary(op, stripDoubleNegations(l), stripDoubleNegations(r));
    case Quantified(quantifier: final q, variable: final v, body: final b):
      return Quantified(q, v, stripDoubleNegations(b));
    case Letter() || Predication():
      return f;
  }
}

/// Gleich bis auf doppelte Negationen.
bool equalModuloDoubleNegation(Formula a, Formula b) =>
    stripDoubleNegations(a) == stripDoubleNegations(b);
