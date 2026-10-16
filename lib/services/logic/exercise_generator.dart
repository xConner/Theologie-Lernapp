import 'dart:math';

import '../../models/logic/lesson_text.dart';
import '../../models/logic/logic_exercise.dart';
import 'formula.dart';
import 'formula_parser.dart';
import 'proof_rows.dart';
import 'semantics.dart';

/// Erzeugt zusätzliche Übungen zu einer Lektion. Jede erzeugte Übung wird
/// vor der Ausgabe geprüft (Satz-Eigenschaft, Wahrheitswerte, Gültigkeit,
/// Beweis mit dem Beweisprüfer); was die Prüfung nicht besteht, wird
/// verworfen.
class ExerciseGenerator {
  final Random random;

  /// Schlüssel bereits erzeugter Aufgaben (keine Wiederholungen je Sitzung).
  final Set<String> _seen = {};

  ExerciseGenerator([Random? random]) : random = random ?? Random();

  static const Map<String, String> titles = {
    "wellFormed": "Satz oder nicht?",
    "wellFormedPL": "Satz oder nicht? (PL)",
    "truthTable": "Wahrheitstafeln",
    "evaluate": "Wahrheitswerte bestimmen",
    "entailment": "Folgerungen prüfen",
    "findPremises": "Voraussetzungen finden",
    "freeVariables": "Satz oder Satzfunktion?",
    "proof": "Beweise",
  };

  T _pick<T>(List<T> items) => items[random.nextInt(items.length)];

  /// Erzeugt eine Übung der Art [kind]; [proofPool] sind die Beweisübungen
  /// der Lektion (Vorlagen für neue Beweisaufgaben).
  LogicExercise? generate(
    String kind, {
    List<ProofExercise> proofPool = const [],
  }) {
    for (var attempt = 0; attempt < 60; attempt++) {
      final e = switch (kind) {
        "wellFormed" => _wellFormed(false),
        "wellFormedPL" => _wellFormed(true),
        "truthTable" => _truthTable(),
        "evaluate" => _evaluate(),
        "entailment" => _entailment(),
        "findPremises" => _findPremises(),
        "freeVariables" => _freeVariables(),
        "proof" => _proof(proofPool),
        _ => null,
      };
      if (e == null) continue;
      final key = "$kind:${e.summary}";
      if (_seen.add(key)) return e;
    }
    return null;
  }

  // ---------------------------------------------------------------- AL-Formeln

  Formula randomFormula(List<String> letters, int operators) {
    if (operators == 0) return Letter(_pick(letters));
    if (random.nextInt(5) == 0) {
      return Negation(randomFormula(letters, operators - 1));
    }
    final leftOps = random.nextInt(operators);
    return Binary(
      _pick(BinaryOperator.values),
      randomFormula(letters, leftOps),
      randomFormula(letters, operators - 1 - leftOps),
    );
  }

  /// Ein Satz mit genau den Buchstaben [letters] und [operators] Operatoren,
  /// ohne doppelte Negationen.
  Formula _formulaUsing(List<String> letters, int operators) {
    for (var i = 0; i < 200; i++) {
      final f = randomFormula(letters, operators);
      if (f.letters.length == letters.length && !f.key.contains("¬¬")) return f;
    }
    return randomFormula(letters, operators);
  }

  // ---------------------------------------------------------------- Syntax

  LogicExercise? _wellFormed(bool pl) {
    final f = pl
        ? _plSentence()
        : _formulaUsing(
            _pick([["p", "q"], ["q", "r", "s"], ["p", "q", "r"]]),
            2 + random.nextInt(2),
          );
    var text = f is Binary && random.nextBool() ? f.full : f.show();

    // Mit Wahrscheinlichkeit 2/3 einen typischen Fehler einbauen. Die
    // Antwort ergibt sich in jedem Fall aus dem Parser – auch wenn eine
    // Änderung zufällig wieder einen Satz ergibt.
    if (random.nextInt(3) > 0) {
      final mutated = _mutate(text, pl);
      if (mutated != null) text = mutated;
    }

    return WellFormedExercise(
      id: null,
      origin: ExerciseOrigin.generated,
      group: "Erzeugte Übungen",
      expression: text,
      predicateLogic: pl,
    );
  }

  String? _mutate(String text, bool pl) {
    final language = pl ? LogicLanguage.predicate : LogicLanguage.propositional;
    final options = <String Function()>[
      // Klammern um eine Negation setzen.
      () {
        final starts = [for (var i = 0; i < text.length; i++) if (text[i] == "¬") i];
        if (starts.isEmpty) return text;
        final i = _pick(starts);
        for (var end = i + 2; end <= text.length; end++) {
          final p = FormulaParser.parse(text.substring(i, end), language: language);
          if (p.ok && !p.outerParenthesesOmitted) {
            return "${text.substring(0, i)}(${text.substring(i, end)})${text.substring(end)}";
          }
        }
        return text;
      },
      // Ein inneres Klammerpaar entfernen.
      () {
        final open = [for (var i = 1; i < text.length; i++) if (text[i] == "(") i];
        if (open.isEmpty) return text;
        final i = _pick(open);
        var depth = 0;
        for (var j = i; j < text.length; j++) {
          if (text[j] == "(") depth++;
          if (text[j] == ")") depth--;
          if (depth == 0) {
            return text.substring(0, i) +
                text.substring(i + 1, j) +
                text.substring(j + 1);
          }
        }
        return text;
      },
      // Den ganzen Satz zusätzlich einklammern.
      () => "($text)",
    ];
    final result = _pick(options)();
    return result == text ? null : result;
  }

  // ---------------------------------------------------------------- Semantik

  LogicExercise _truthTable() {
    final letters = random.nextInt(3) == 0 ? ["p", "q", "r"] : ["p", "q"];
    final f = _formulaUsing(letters, letters.length == 3 ? 2 + random.nextInt(2) : 2 + random.nextInt(2));
    return TruthTableExercise(
      id: null,
      origin: ExerciseOrigin.generated,
      group: "Erzeugte Übungen",
      formula: f.show(),
    );
  }

  LogicExercise _evaluate() {
    final letters = ["p", "q", "r"];
    final f = _formulaUsing(letters, 3 + random.nextInt(2));
    return EvaluateExercise(
      id: null,
      origin: ExerciseOrigin.generated,
      group: "Erzeugte Übungen",
      formula: f.show(),
      interpretation: {for (final l in letters) l: random.nextBool()},
    );
  }

  LogicExercise? _entailment() {
    final wantValid = random.nextBool();
    final letters = random.nextBool() ? ["p", "q"] : ["p", "q", "r"];
    for (var i = 0; i < 300; i++) {
      final n = 1 + random.nextInt(2);
      final premises = [for (var k = 0; k < n; k++) _formulaUsing(letters.sublist(0, 2), 1 + random.nextInt(2))];
      final thesis = randomFormula(letters, random.nextInt(2));
      final all = [...premises, thesis];
      if (LogicSemantics.lettersOf(all).length < 2) continue;
      if (LogicSemantics.classify(thesis) != Classification.contingent) continue;
      if (premises.any((p) => LogicSemantics.classify(p) != Classification.contingent)) continue;
      if (premises.contains(thesis)) continue;
      if (LogicSemantics.entails(premises, thesis) != wantValid) continue;
      return EntailmentExercise(
        id: null,
        origin: ExerciseOrigin.generated,
        group: "Erzeugte Übungen",
        theorem: "${premises.map((p) => p.show()).join(", ")} ⊢ ${thesis.show()}",
      );
    }
    return null;
  }

  LogicExercise? _findPremises() {
    final thesis = _formulaUsing(_pick([["q"], ["q", "r"]]), random.nextInt(2) + (random.nextBool() ? 0 : 1));
    if (LogicSemantics.classify(thesis) != Classification.contingent) return null;
    const fresh = "s";
    final sample = [fresh, "$fresh → ${thesis.show(top: false)}"];
    // Musterlösung prüfen, bevor die Aufgabe ausgegeben wird.
    final premises = sample.map(parseFormula).toList();
    if (!LogicSemantics.entails(premises, thesis)) return null;
    for (var i = 0; i < premises.length; i++) {
      if (LogicSemantics.entails([...premises]..removeAt(i), thesis)) return null;
    }
    return FindPremisesExercise(
      id: null,
      origin: ExerciseOrigin.generated,
      group: "Erzeugte Übungen",
      thesis: thesis.show(),
      count: 2,
      sample: sample,
      note: "Alle Voraussetzungen verschieden, keine überflüssig.",
    );
  }

  // ---------------------------------------------------------------- PL

  /// Zufällige PL-Formel; [free] erlaubt freie Variablen.
  Formula _plFormula(int operators, List<String> bound, {required bool free}) {
    if (operators == 0) {
      final pred = _pick(["F", "G", "H"]);
      final candidates = [
        ...bound,
        if (free || bound.isEmpty) ...["a", "b"],
        if (free) ...["x", "y"],
      ];
      return Predication(pred, [_pick(candidates)]);
    }
    final roll = random.nextInt(6);
    if (roll == 0) {
      return Negation(_plFormula(operators - 1, bound, free: free));
    }
    if (roll <= 2) {
      final v = ["x", "y"].firstWhere((v) => !bound.contains(v), orElse: () => "");
      if (v.isNotEmpty) {
        final body = _plFormula(operators - 1, [...bound, v], free: free);
        if (body.freeVariables.contains(v)) {
          return Quantified(_pick(Quantifier.values), v, body);
        }
        return body;
      }
    }
    final leftOps = random.nextInt(operators);
    return Binary(
      _pick(BinaryOperator.values),
      _plFormula(leftOps, bound, free: free),
      _plFormula(operators - 1 - leftOps, bound, free: free),
    );
  }

  Formula _plSentence() {
    for (var i = 0; i < 200; i++) {
      final f = _plFormula(2 + random.nextInt(2), const [], free: false);
      final quantified = f.key.contains("∀") || f.key.contains("∃");
      if (quantified &&
          f.freeVariables.isEmpty &&
          _noVacuousOrRebinding(f, const [])) {
        return f;
      }
    }
    return parseFormula("∀x(Fx → Gx)");
  }

  LogicExercise? _freeVariables() {
    final f = _plFormula(2 + random.nextInt(2), const [], free: true);
    if (!(f.key.contains("∀") || f.key.contains("∃"))) return null;
    if (!_noVacuousOrRebinding(f, const [])) return null;
    return FreeVariablesExercise(
      id: null,
      origin: ExerciseOrigin.generated,
      group: "Erzeugte Übungen",
      expression: f.show(),
    );
  }

  bool _noVacuousOrRebinding(Formula f, List<String> bound) {
    if (f is Quantified) {
      if (bound.contains(f.variable)) return false;
      if (!f.body.freeVariables.contains(f.variable)) return false;
      return _noVacuousOrRebinding(f.body, [...bound, f.variable]);
    }
    return f.children.every((c) => _noVacuousOrRebinding(c, bound));
  }

  // ---------------------------------------------------------------- Beweise

  LogicExercise? _proof(List<ProofExercise> pool) {
    if (pool.isEmpty) return null;
    final template = _pick(pool);
    final theorem = template.theorem;
    final pl = FormulaParser.guessLanguage(theorem) == LogicLanguage.predicate;

    String Function(String) rename;

    if (pl) {
      final preds = ["F", "G", "H"]..shuffle(random);
      final predMap = {"F": preds[0], "G": preds[1], "H": preds[2]};
      final indiv = random.nextBool() ? {"a": "c", "b": "d"} : {"a": "b", "b": "a"};
      rename = (s) => s.split("").map((c) => predMap[c] ?? indiv[c] ?? c).join();
    } else {
      final letters = LogicSemantics.lettersOf(
        [for (final r in template.solution) FormulaParser.parse(r.formula).formula ?? const Letter("p")],
      );
      final targets = ["p", "q", "r", "s", "t"]..shuffle(random);
      final map = <String, Formula>{};
      for (var i = 0; i < letters.length; i++) {
        final t = Letter(targets[i]);
        // Gelegentlich einen Buchstaben durch eine Negation ersetzen.
        map[letters[i]] = random.nextInt(4) == 0 ? Negation(t) : t;
      }
      rename = (s) {
        final r = FormulaParser.parse(s);
        if (!r.ok) return s;
        return r.formula!.substituteLetters(map).show();
      };
    }

    String renameTheorem(String t) {
      final parts = t.split("⊢");
      final left = parts[0].trim();
      final premises = left.isEmpty ? <String>[] : _splitTop(left).map(rename).toList();
      return "${premises.join(", ")}${premises.isEmpty ? "" : " "}⊢ ${rename(parts[1].trim())}";
    }

    final newTheorem = renameTheorem(theorem);
    if (newTheorem == theorem) return null;

    final solution = [
      for (final r in template.solution)
        ProofRow(r.label, rename(r.formula), r.justification, r.dependencies),
    ];

    final check = ProofRows.check(template.system, newTheorem, solution);
    if (!check.complete) return null;

    return ProofExercise(
      id: null,
      origin: ExerciseOrigin.generated,
      group: "Erzeugte Übungen",
      theorem: newTheorem,
      system: template.system,
      solution: solution,
      plan: template.plan,
      note: template.note,
    );
  }

  static List<String> _splitTop(String text) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == "(") depth++;
      if (text[i] == ")") depth--;
      if (text[i] == "," && depth == 0) {
        result.add(text.substring(start, i).trim());
        start = i + 1;
      }
    }
    result.add(text.substring(start).trim());
    return result;
  }
}
