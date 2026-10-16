import 'formula.dart';

/// Eine Interpretation (Belegung, Bewertung): Satzbuchstabe → Wahrheitswert.
typedef Interpretation = Map<String, bool>;

/// Semantik der Aussagenlogik nach Definition 2.2.
class LogicSemantics {
  LogicSemantics._();

  /// Wahrheitswert von [f] unter [v]. Wirft bei PL-Formeln.
  static bool evaluate(Formula f, Interpretation v) {
    switch (f) {
      case Letter(name: final n):
        final value = v[n];
        if (value == null) {
          throw ArgumentError("Die Interpretation legt $n nicht fest.");
        }
        return value;
      case Negation(operand: final a):
        return !evaluate(a, v);
      case Binary(op: final op, left: final a, right: final b):
        final x = evaluate(a, v);
        final y = evaluate(b, v);
        switch (op) {
          case BinaryOperator.and:
            return x && y;
          case BinaryOperator.or:
            return x || y;
          case BinaryOperator.implies:
            return !x || y;
          case BinaryOperator.iff:
            return x == y;
        }
      case Predication() || Quantified():
        throw ArgumentError(
          "Wahrheitstafeln gibt es im Kurs nur für die Aussagenlogik.",
        );
    }
  }

  /// Satzbuchstaben in der Reihenfolge des Alphabets (p, q, r, s, …).
  static List<String> lettersOf(Iterable<Formula> formulas) {
    final all = {for (final f in formulas) ...f.letters};
    return LogicAlphabet.sentenceLetters
        .split("")
        .where(all.contains)
        .toList();
  }

  /// Alle Interpretationen der [letters] in der Reihenfolge des Kurses:
  /// erste Zeile alles wahr, letzte Zeile alles falsch (1 1, 1 0, 0 1, 0 0).
  static List<Interpretation> interpretations(List<String> letters) {
    final count = 1 << letters.length;
    return [
      for (var row = 0; row < count; row++)
        {
          for (var i = 0; i < letters.length; i++)
            letters[i]: (row >> (letters.length - 1 - i)) & 1 == 0,
        },
    ];
  }

  static String formatInterpretation(Interpretation v, List<String> letters) =>
      letters.map((l) => "$l = ${v[l]! ? 1 : 0}").join(", ");

  static Classification classify(Formula f) {
    final rows = interpretations(lettersOf([f]));
    final values = rows.map((v) => evaluate(f, v)).toList();
    if (values.every((x) => x)) return Classification.logicallyTrue;
    if (values.every((x) => !x)) return Classification.logicallyFalse;
    return Classification.contingent;
  }

  /// Gegenbeispiele zu V1, …, Vn ⊢ T: Interpretationen, unter denen alle
  /// Voraussetzungen wahr sind und die These falsch ist. Leer = gültig.
  static List<Interpretation> counterexamples(
    List<Formula> premises,
    Formula thesis,
  ) {
    final letters = lettersOf([...premises, thesis]);
    return [
      for (final v in interpretations(letters))
        if (premises.every((p) => evaluate(p, v)) && !evaluate(thesis, v)) v,
    ];
  }

  static bool entails(List<Formula> premises, Formula thesis) =>
      counterexamples(premises, thesis).isEmpty;

  static bool equivalent(Formula a, Formula b) =>
      entails([a], b) && entails([b], a);

  /// Der Satz aus dem Folgerungstheorem (Satz 3.1):
  /// ((V1 ∧ (V2 ∧ … (Vn−1 ∧ Vn)…)) → T).
  static Formula theoremSentence(List<Formula> premises, Formula thesis) {
    if (premises.isEmpty) return thesis;
    var conjunction = premises.last;
    for (var i = premises.length - 2; i >= 0; i--) {
      conjunction = and(premises[i], conjunction);
    }
    return imp(conjunction, thesis);
  }
}

enum Classification {
  logicallyTrue("logisch wahr (Tautologie)"),
  logicallyFalse("logisch falsch (Kontradiktion)"),
  contingent("kontingent");

  final String label;

  const Classification(this.label);
}

/// Eine vollständig berechnete Wahrheitstafel.
class TruthTable {
  final Formula formula;
  final List<String> letters;
  final List<Interpretation> rows;

  /// Spalten: alle zusammengesetzten Teilsätze, innen vor außen; die letzte
  /// Spalte ist der ganze Satz.
  final List<Formula> columns;

  /// values[row][column]
  final List<List<bool>> values;

  TruthTable._(this.formula, this.letters, this.rows, this.columns, this.values);

  factory TruthTable.of(Formula f) {
    final letters = LogicSemantics.lettersOf([f]);
    final rows = LogicSemantics.interpretations(letters);
    final columns = f.subformulas.where((s) => !s.isElementary).toList();
    if (columns.isEmpty) columns.add(f);

    return TruthTable._(f, letters, rows, columns, [
      for (final v in rows) [for (final c in columns) LogicSemantics.evaluate(c, v)],
    ]);
  }

  List<bool> get mainColumn => [for (final r in values) r.last];
}
