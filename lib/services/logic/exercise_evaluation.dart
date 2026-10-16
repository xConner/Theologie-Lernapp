import 'formula.dart';
import 'formula_parser.dart';
import 'semantics.dart';

/// Ergebnis einer Antwort. [correct] ist nur true, wenn die Antwort
/// algorithmisch als richtig bestätigt wurde.
class ExerciseOutcome {
  final bool correct;
  final String headline;
  final List<String> details;

  /// Die Eingabe ließ sich nicht lesen (zählt nicht als Versuch).
  final bool invalidInput;

  const ExerciseOutcome({
    required this.correct,
    required this.headline,
    this.details = const [],
    this.invalidInput = false,
  });

  const ExerciseOutcome.invalid(String message, {this.details = const []})
    : correct = false,
      headline = message,
      invalidInput = true;
}

String _b(bool v) => v ? "1" : "0";

/// Bewertung der Aufgabentypen, ohne Oberfläche.
class ExerciseEvaluation {
  ExerciseEvaluation._();

  // ---------------------------------------------------------------- Syntax

  /// Erklärung, warum ein Ausdruck (k)ein Satz ist.
  static List<String> sentenceExplanation(ParseResult r, {String? original}) {
    final f = r.formula;
    if (f == null) return [r.error ?? "Kein Satz."];

    final lines = <String>[];
    if (r.outerParenthesesOmitted) {
      lines.add(
        "Hier sind nach der Klammerersparnisregel die äußersten Klammern "
        "weggelassen; vollständig lautet der Satz ${f.full}.",
      );
    }
    lines.addAll(decomposition(f));
    return lines;
  }

  /// Zerlegung nach Definition 1.2 (bzw. 7.4), von außen nach innen.
  static List<String> decomposition(Formula f) {
    final lines = <String>[];

    void visit(Formula g) {
      switch (g) {
        case Letter():
          return;
        case Predication():
          return;
        case Negation(operand: final a):
          lines.add("${g.show(top: false)} ist eine Negation ¬A mit A = ${a.show(top: false)}.");
          visit(a);
        case Binary(op: final op, left: final a, right: final b):
          lines.add(
            "${g.full} ist eine ${op.sentenceName} (A ${op.symbol} B) mit "
            "A = ${a.show(top: false)} und B = ${b.show(top: false)}.",
          );
          visit(a);
          visit(b);
        case Quantified(quantifier: final q, variable: final v, body: final b):
          lines.add(
            "${g.show(top: false)} ist ein ${q.sentenceName}; gebunden ist "
            "$v, der Bereich ist ${b.show(top: false)}.",
          );
          visit(b);
      }
    }

    visit(f);
    final atoms = f.isPredicateLogic ? "elementare Sätze bzw. Satzfunktionen" : "elementare Sätze";
    lines.add("Ganz unten stehen nur noch $atoms – die Zerlegung ist vollständig.");
    return lines;
  }

  static ExerciseOutcome wellFormed(
    String expression,
    bool answerIsSentence, {
    LogicLanguage language = LogicLanguage.propositional,
  }) {
    final r = FormulaParser.parse(expression, language: language);
    final isSentence = r.ok &&
        (language == LogicLanguage.propositional || r.formula!.freeVariables.isEmpty);
    final correct = answerIsSentence == isSentence;

    final details = <String>[];
    if (r.ok && language == LogicLanguage.predicate && r.formula!.freeVariables.isNotEmpty) {
      details.add(
        "Der Ausdruck ist wohlgeformt, enthält aber die freie Variable "
        "${r.formula!.freeVariables.join(", ")} – er ist eine Satzfunktion, "
        "kein Satz.",
      );
    } else {
      details.addAll(sentenceExplanation(r));
    }

    return ExerciseOutcome(
      correct: correct,
      headline: isSentence
          ? "„$expression“ ist ein Satz."
          : "„$expression“ ist kein Satz.",
      details: details,
    );
  }

  // ---------------------------------------------------------------- Werte

  /// Schrittweise Auswertung unter einer Interpretation.
  static List<String> evaluationSteps(Formula f, Interpretation v) => [
    for (final s in f.subformulas)
      if (!s.isElementary) "${s.show()} = ${_b(LogicSemantics.evaluate(s, v))}",
  ];

  static ExerciseOutcome evaluate(Formula f, Interpretation v, bool answer) {
    final value = LogicSemantics.evaluate(f, v);
    return ExerciseOutcome(
      correct: answer == value,
      headline: "Unter dieser Interpretation ist der Satz "
          "${value ? "wahr (1)" : "falsch (0)"}.",
      details: [
        "Von innen nach außen:",
        ...evaluationSteps(f, v),
      ],
    );
  }

  // ---------------------------------------------------------------- Tafeln

  /// Prüft eine ausgefüllte Wahrheitstafel. [cells] hat dieselbe Form wie
  /// [TruthTable.values]; `null` = leer.
  static TruthTableCheck truthTable(
    TruthTable table,
    List<List<bool?>> cells, {
    Classification? classification,
    Set<int>? models,
  }) {
    final wrong = <(int, int)>{};
    var empty = 0;

    for (var r = 0; r < table.rows.length; r++) {
      for (var c = 0; c < table.columns.length; c++) {
        final given = cells[r][c];
        if (given == null) {
          empty++;
        } else if (given != table.values[r][c]) {
          wrong.add((r, c));
        }
      }
    }

    final details = <String>[];

    // Den ersten Fehler genau erklären.
    if (wrong.isNotEmpty) {
      final (r, c) = wrong.first;
      final col = table.columns[c];
      final v = table.rows[r];
      details.add(
        "Zeile ${r + 1} (${LogicSemantics.formatInterpretation(v, table.letters)}), "
        "Spalte ${col.show()}: richtig ist ${_b(table.values[r][c])}. "
        "${_reason(col, v)}",
      );
    }

    final actual = LogicSemantics.classify(table.formula);
    final classOk = classification == null || classification == actual;
    if (classification != null && !classOk) {
      details.add("Der Satz ist ${actual.label}.");
    }

    final modelRows = {
      for (var r = 0; r < table.rows.length; r++)
        if (table.mainColumn[r]) r,
    };
    final modelsOk = models == null ||
        (models.length == modelRows.length && models.containsAll(modelRows));
    if (models != null && !modelsOk) {
      details.add(
        modelRows.isEmpty
            ? "Es gibt kein Modell: Der Satz ist unter jeder Interpretation falsch."
            : "Modelle sind genau die Zeilen ${modelRows.map((r) => r + 1).join(", ")} "
                  "– dort steht in der Spalte des ganzen Satzes eine 1.",
      );
    }

    return TruthTableCheck(
      wrongCells: wrong,
      emptyCells: empty,
      classificationCorrect: classOk,
      modelsCorrect: modelsOk,
      details: details,
    );
  }

  /// Begründung des Wahrheitswerts eines Teilsatzes aus seinen Operanden.
  static String _reason(Formula f, Interpretation v) {
    String val(Formula g) => "${g.show()} = ${_b(LogicSemantics.evaluate(g, v))}";
    switch (f) {
      case Negation(operand: final a):
        return "Die Negation kehrt den Wert um: ${val(a)}.";
      case Binary(op: final op, left: final a, right: final b):
        final rule = switch (op) {
          BinaryOperator.and => "Eine Konjunktion ist nur wahr, wenn beide Operanden wahr sind",
          BinaryOperator.or => "Eine Adjunktion ist nur falsch, wenn beide Operanden falsch sind",
          BinaryOperator.implies => "Eine Implikation ist nur falsch, wenn die Prämisse wahr und die Konklusion falsch ist",
          BinaryOperator.iff => "Eine Äquivalenz ist wahr, wenn beide Seiten denselben Wert haben",
        };
        return "$rule: ${val(a)}, ${val(b)}.";
      default:
        return "";
    }
  }

  // ---------------------------------------------------------------- Folgerung

  static ExerciseOutcome entailment(
    List<Formula> premises,
    Formula thesis,
    bool answerValid, {
    Interpretation? counterexample,
  }) {
    final counters = LogicSemantics.counterexamples(premises, thesis);
    final valid = counters.isEmpty;
    final letters = LogicSemantics.lettersOf([...premises, thesis]);

    if (answerValid != valid) {
      return ExerciseOutcome(
        correct: false,
        headline: valid ? "Das Theorem ist gültig." : "Das Theorem ist nicht gültig.",
        details: [
          if (valid)
            "Unter keiner Interpretation sind alle Voraussetzungen wahr und "
                "die These falsch."
          else
            "Gegenbeispiel: ${LogicSemantics.formatInterpretation(counters.first, letters)} – "
                "alle Voraussetzungen sind wahr, die These ist falsch.",
        ],
      );
    }

    if (valid) {
      return const ExerciseOutcome(
        correct: true,
        headline: "Richtig – das Theorem ist gültig.",
        details: [
          "Unter keiner Interpretation sind alle Voraussetzungen wahr und die "
              "These falsch.",
        ],
      );
    }

    if (counterexample == null) {
      return const ExerciseOutcome(
        correct: false,
        headline: "Richtig erkannt: nicht gültig. Es fehlt noch ein Gegenbeispiel.",
      );
    }

    final premisesTrue = premises.every((p) => LogicSemantics.evaluate(p, counterexample));
    final thesisFalse = !LogicSemantics.evaluate(thesis, counterexample);
    if (premisesTrue && thesisFalse) {
      return ExerciseOutcome(
        correct: true,
        headline: "Richtig – nicht gültig, und das Gegenbeispiel stimmt.",
        details: [
          "Unter ${LogicSemantics.formatInterpretation(counterexample, letters)} sind "
              "alle Voraussetzungen wahr und die These ist falsch.",
        ],
      );
    }

    return ExerciseOutcome(
      correct: false,
      headline: "Nicht gültig – aber die gewählte Interpretation ist kein Gegenbeispiel.",
      details: [
        if (!premisesTrue)
          "Unter ihr ist die Voraussetzung "
              "${premises.firstWhere((p) => !LogicSemantics.evaluate(p, counterexample)).show()} "
              "falsch. Bei einem Gegenbeispiel müssen alle Voraussetzungen wahr sein.",
        if (!thesisFalse) "Unter ihr ist die These wahr; sie muss falsch sein.",
        "Ein Gegenbeispiel ist z. B. "
            "${LogicSemantics.formatInterpretation(counters.first, letters)}.",
      ],
    );
  }

  // ---------------------------------------------------------------- Voraussetzungen finden

  static ExerciseOutcome findPremises(List<String> inputs, Formula thesis) {
    final premises = <Formula>[];
    for (var i = 0; i < inputs.length; i++) {
      final r = FormulaParser.parse(inputs[i]);
      if (!r.ok) {
        return ExerciseOutcome.invalid("P${i + 1} ist kein Satz: ${r.error}");
      }
      premises.add(r.formula!);
    }

    for (var i = 0; i < premises.length; i++) {
      for (var j = i + 1; j < premises.length; j++) {
        if (premises[i] == premises[j]) {
          return ExerciseOutcome(
            correct: false,
            headline: "P${i + 1} und P${j + 1} sind gleich.",
            details: const ["Alle Voraussetzungen müssen verschieden sein."],
          );
        }
      }
    }

    final letters = LogicSemantics.lettersOf([...premises, thesis]);
    final counters = LogicSemantics.counterexamples(premises, thesis);
    if (counters.isNotEmpty) {
      return ExerciseOutcome(
        correct: false,
        headline: "Das Theorem ist so nicht gültig.",
        details: [
          "Gegenbeispiel: ${LogicSemantics.formatInterpretation(counters.first, letters)} – "
              "alle Voraussetzungen wahr, die These ${thesis.show()} falsch.",
        ],
      );
    }

    for (var i = 0; i < premises.length; i++) {
      final rest = [...premises]..removeAt(i);
      if (LogicSemantics.entails(rest, thesis)) {
        return ExerciseOutcome(
          correct: false,
          headline: "Gültig, aber P${i + 1} ist überflüssig.",
          details: [
            "Auch ohne P${i + 1} = ${premises[i].show()} folgt die These. "
                "Jede Voraussetzung muss gebraucht werden.",
          ],
        );
      }
    }

    return ExerciseOutcome(
      correct: true,
      headline: "Richtig – gültig, alle Voraussetzungen verschieden und keine überflüssig.",
      details: [
        "${premises.map((p) => p.show()).join(", ")} ⊢ ${thesis.show()}",
      ],
    );
  }

  // ---------------------------------------------------------------- Formalisieren

  static ExerciseOutcome formalize(String input, Formula expected) {
    final r = FormulaParser.parse(input);
    if (!r.ok) {
      return ExerciseOutcome.invalid("Kein Satz: ${r.error}");
    }

    final f = r.formula!;
    final unknown = f.letters.difference(expected.letters);
    if (unknown.isNotEmpty) {
      return ExerciseOutcome(
        correct: false,
        headline: "Der Satzbuchstabe ${unknown.join(", ")} ist nicht vereinbart.",
        details: [
          "Verwende nur ${LogicSemantics.lettersOf([expected]).join(", ")}.",
        ],
      );
    }

    if (f == expected) {
      return const ExerciseOutcome(correct: true, headline: "Richtig formalisiert.");
    }

    if (LogicSemantics.equivalent(f, expected)) {
      return ExerciseOutcome(
        correct: true,
        headline: "Richtig – logisch gleichwertig mit der Musterlösung.",
        details: [
          "Deine Formalisierung ist unter jeder Interpretation gleich wahr wie "
              "${expected.show()}.",
        ],
      );
    }

    final letters = LogicSemantics.lettersOf([f, expected]);
    final v = LogicSemantics.interpretations(letters).firstWhere(
      (v) => LogicSemantics.evaluate(f, v) != LogicSemantics.evaluate(expected, v),
    );
    final mine = LogicSemantics.evaluate(f, v);
    return ExerciseOutcome(
      correct: false,
      headline: "Nicht gleichwertig mit dem Satz.",
      details: [
        "Unter ${LogicSemantics.formatInterpretation(v, letters)} ist deine "
            "Formalisierung ${mine ? "wahr" : "falsch"}, der Satz aber "
            "${mine ? "falsch" : "wahr"}.",
        "Eine passende Formalisierung: ${expected.show()}",
      ],
    );
  }

  // ---------------------------------------------------------------- PL

  static ExerciseOutcome freeVariables(
    String expression,
    bool answerIsSentence,
    Set<String> answerFree,
  ) {
    final r = FormulaParser.parse(expression, language: LogicLanguage.predicate);
    if (!r.ok) {
      return ExerciseOutcome(
        correct: !answerIsSentence && answerFree.isEmpty,
        headline: "Der Ausdruck ist weder Satz noch Satzfunktion.",
        details: [r.error ?? ""],
      );
    }

    final free = r.formula!.freeVariables;
    final isSentence = free.isEmpty;
    final correct = answerIsSentence == isSentence &&
        answerFree.length == free.length &&
        answerFree.containsAll(free);

    final details = <String>[
      if (r.outerParenthesesOmitted)
        "Vollständig geklammert: ${r.formula!.full}.",
      ..._bindings(r.formula!),
    ];

    return ExerciseOutcome(
      correct: correct,
      headline: isSentence
          ? "Ein Satz – alle Variablen sind gebunden."
          : "Eine Satzfunktion – frei: ${free.join(", ")}.",
      details: details,
    );
  }

  /// Erklärt für jeden Quantor seinen Bereich.
  static List<String> _bindings(Formula f) {
    final lines = <String>[];

    void visit(Formula g) {
      if (g is Quantified) {
        lines.add(
          "${g.quantifier.symbol}${g.variable} bindet ${g.variable} im "
          "Bereich ${g.body.show(top: false)}.",
        );
      }
      for (final c in g.children) {
        visit(c);
      }
    }

    visit(f);
    if (lines.isEmpty) lines.add("Der Ausdruck enthält keinen Quantor.");
    return lines;
  }
}

class TruthTableCheck {
  final Set<(int, int)> wrongCells;
  final int emptyCells;
  final bool classificationCorrect;
  final bool modelsCorrect;
  final List<String> details;

  const TruthTableCheck({
    required this.wrongCells,
    required this.emptyCells,
    required this.classificationCorrect,
    required this.modelsCorrect,
    required this.details,
  });

  bool get complete => emptyCells == 0;

  bool get correct =>
      complete && wrongCells.isEmpty && classificationCorrect && modelsCorrect;
}
