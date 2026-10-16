import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/services/logic/exercise_evaluation.dart';
import 'package:theologie_lernapp/services/logic/formula.dart';
import 'package:theologie_lernapp/services/logic/formula_parser.dart';
import 'package:theologie_lernapp/services/logic/proof_checker.dart';
import 'package:theologie_lernapp/services/logic/proof_rules.dart';
import 'package:theologie_lernapp/services/logic/semantics.dart';

ProofLineInput line(String label, String formula, String rule, [String refs = "", String? deps]) {
  final r = ProofLabels.parseList(refs);
  return ProofLineInput(
    label: label,
    formula: formula,
    rule: rule == "A" ? ProofRule.assumption : ProofRule.parse(rule, refCount: r.length),
    refs: r,
    dependencies: deps == null ? null : ProofLabels.parseList(deps),
  );
}

ProofCheckResult check(ProofSystem s, String theorem, List<ProofLineInput> lines) =>
    ProofChecker(s, Theorem.parse(theorem)).check(lines);

void main() {
  group("Syntax (Definition 1.2, Konvention 1.1)", () {
    bool sentence(String s) => FormulaParser.parse(s).ok;

    test("Klammerersparnis nur für die äußersten Klammern zweistelliger Sätze", () {
      expect(sentence("q ∧ r"), isTrue);
      expect(sentence("(q ∧ r)"), isTrue);
      expect(sentence("q ∧ r ∨ s"), isFalse);
      expect(sentence("(q ∧ r) ∨ s"), isTrue);
      expect(sentence("((q ∧ r))"), isFalse);
    });

    test("Keine Klammern um Negationen oder elementare Sätze", () {
      expect(sentence("¬(q ∨ r)"), isTrue);
      expect(sentence("(¬(q ∨ r))"), isFalse);
      expect(sentence("(¬q) → r"), isFalse);
      expect(sentence("(q)"), isFalse);
      expect(sentence("¬¬q"), isTrue);
    });

    test("Eingabehilfen werden übersetzt", () {
      expect(parseFormula("~q -> (r & s)"), parseFormula("¬q → (r ∧ s)"));
      expect(parseFormula("(q v r) <-> s"), parseFormula("(q ∨ r) ↔ s"));
      expect(FormulaParser.parse("q v r <-> s").ok, isFalse);
    });

    test("Begründungen nennen den Fehler", () {
      expect(FormulaParser.parse("(¬(q ∨ r))").error, contains("Klammern"));
      expect(FormulaParser.parse("q ∧ r ∨ s").error, contains("Hauptoperator"));
      expect(FormulaParser.parse("q ∧ x").error, contains("Alphabet"));
    });

    test("Ausgabe in Kursschreibweise", () {
      final f = parseFormula("((q → r) ∧ ¬q)");
      expect(f.show(), "(q → r) ∧ ¬q");
      expect(f.full, "((q → r) ∧ ¬q)");
    });

    test("Prädikatenlogik: Satz, Satzfunktion, Bereich", () {
      final pl = LogicLanguage.predicate;
      expect(FormulaParser.parse("∀x(Gx ∧ ∃yHyx)", language: pl).formula!.freeVariables, isEmpty);
      expect(FormulaParser.parse("∀xGx ∧ ∃yHyx", language: pl).formula!.freeVariables, {"x"});
      expect(FormulaParser.parse("∀x(Gx)", language: pl).ok, isFalse);
      expect(FormulaParser.parse("Gabc", language: pl).ok, isFalse);
      expect(FormulaParser.parse("p ∧ Fa", language: pl).ok, isFalse);
      expect(parseFormula("∀xGx"), parseFormula("∀yGy"), reason: "gebundene Variablen sind austauschbar");
    });
  });

  group("Semantik (Definition 2.2–2.4)", () {
    test("Wahrheitstafeln der Operatoren in Kursreihenfolge", () {
      List<bool> column(String f) => TruthTable.of(parseFormula(f)).mainColumn;
      expect(column("p ∧ q"), [true, false, false, false]);
      expect(column("p ∨ q"), [true, true, true, false]);
      expect(column("p → q"), [true, false, true, true]);
      expect(column("p ↔ q"), [true, false, false, true]);
      expect(column("¬p"), [false, true]);
    });

    test("Einordnung", () {
      expect(LogicSemantics.classify(parseFormula("q ∨ ¬q")), Classification.logicallyTrue);
      expect(LogicSemantics.classify(parseFormula("q ↔ ¬q")), Classification.logicallyFalse);
      expect(LogicSemantics.classify(parseFormula("q → (p ∧ q)")), Classification.contingent);
      expect(LogicSemantics.classify(parseFormula("(p → q) ↔ (¬p ∨ q)")), Classification.logicallyTrue);
    });

    test("Folgerung und Folgerungstheorem", () {
      final premises = [parseFormula("q ∨ r"), parseFormula("¬r")];
      expect(LogicSemantics.entails(premises, parseFormula("q")), isTrue);
      expect(LogicSemantics.entails([parseFormula("q ∨ r")], parseFormula("q")), isFalse);
      final t = LogicSemantics.theoremSentence(
        [parseFormula("p"), parseFormula("q"), parseFormula("r")],
        parseFormula("s"),
      );
      expect(t.full, "((p ∧ (q ∧ r)) → s)");
    });
  });

  group("Antwortbewertung", () {
    test("Formalisierung: äquivalente Schreibweise wird akzeptiert, falsche nicht", () {
      final expected = parseFormula("(p ∨ q) ∧ ¬(p ∧ q)");
      expect(ExerciseEvaluation.formalize("¬(p ↔ q)", expected).correct, isTrue);
      expect(ExerciseEvaluation.formalize("p ∨ q", expected).correct, isFalse);
      expect(ExerciseEvaluation.formalize("p ∨", expected).invalidInput, isTrue);
      expect(ExerciseEvaluation.formalize("p ∨ r", expected).correct, isFalse);
    });

    test("Gegenbeispiel zu einer Folgerung muss alle Voraussetzungen wahr machen", () {
      final p = [parseFormula("q ∨ r")];
      final t = parseFormula("r");
      expect(ExerciseEvaluation.entailment(p, t, false, counterexample: {"q": true, "r": false}).correct, isTrue);
      expect(ExerciseEvaluation.entailment(p, t, false, counterexample: {"q": false, "r": false}).correct, isFalse);
      expect(ExerciseEvaluation.entailment(p, t, true).correct, isFalse);
    });

    test("Voraussetzungen finden: verschieden, gültig, keine überflüssig", () {
      final t = parseFormula("¬(q ∨ r)");
      expect(ExerciseEvaluation.findPremises(["¬q", "¬r"], t).correct, isTrue);
      expect(ExerciseEvaluation.findPremises(["¬q ∧ ¬r", "s"], t).correct, isFalse);
      expect(ExerciseEvaluation.findPremises(["¬q", "¬q"], t).correct, isFalse);
      expect(ExerciseEvaluation.findPremises(["¬q", "r"], t).correct, isFalse);
    });

    test("Wahrheitstafel: falsche Zelle wird mit Begründung benannt", () {
      final table = TruthTable.of(parseFormula("q → r"));
      final cells = [for (final row in table.values) [...row.map<bool?>((v) => v)]];
      cells[2][0] = false;
      final c = ExerciseEvaluation.truthTable(table, cells, classification: Classification.contingent);
      expect(c.correct, isFalse);
      expect(c.wrongCells, {(2, 0)});
      expect(c.details.first, contains("Prämisse"));
    });

    test("Satz oder Satzfunktion", () {
      expect(ExerciseEvaluation.freeVariables("∃yGy ∧ Hy", false, {"y"}).correct, isTrue);
      expect(ExerciseEvaluation.freeVariables("∃yGy ∧ Hy", true, {}).correct, isFalse);
      expect(ExerciseEvaluation.freeVariables("∀x(Gx → Hx)", true, {}).correct, isTrue);
    });
  });

  group("Beweisprüfer", () {
    test("Korrekter Beweis mit +I und Abhängigkeiten", () {
      final r = check(ProofSystem.lesson5, "q → r, r → s ⊢ q → s", [
        line("α", "q → r", "A"),
        line("β", "r → s", "A"),
        line("γ", "q", "A"),
        line("1", "r", "-I", "α, γ", "α, γ"),
        line("2", "s", "-I", "β, 1", "α, β, γ"),
        line("3", "q → s", "+I", "γ, 2", "α, β"),
      ]);
      expect(r.complete, isTrue, reason: r.messages.join());
    });

    test("These hängt noch von einer zusätzlichen Annahme ab", () {
      final r = check(ProofSystem.lesson5, "q → r ⊢ r", [
        line("α", "q → r", "A"),
        line("β", "q", "A"),
        line("1", "r", "-I", "α, β"),
      ]);
      expect(r.complete, isFalse);
      expect(r.messages.join(), contains("β"));
    });

    test("Vertauschte Prämissen sind ein leichter Fehler", () {
      final r = check(ProofSystem.lesson4, "q, s ⊢ q ∧ s", [
        line("α", "q", "A"),
        line("β", "s", "A"),
        line("1", "q ∧ s", "+K", "β, α"),
      ]);
      expect(r.lines.last.issues.single.kind, ProofIssueKind.light);
      expect(r.lines.last.issues.single.message, contains("+K(α, β)"));
    });

    test("Schluss von A → B und B auf A ist ein semantischer Fehler", () {
      final r = check(ProofSystem.lesson4, "q → r, r ⊢ q", [
        line("α", "q → r", "A"),
        line("β", "r", "A"),
        line("1", "q", "-I", "α, β"),
      ]);
      final issue = r.lines.last.issues.single;
      expect(issue.kind, ProofIssueKind.semantic);
      expect(issue.message, contains("zurückgeschlossen"));
    });

    test("Ohne doppelte Negation in Lektion 4 ein schwerer Fehler, ab Lektion 6 erlaubt", () {
      List<ProofLineInput> lines() => [
        line("α", "r", "A"),
        line("β", "¬r ∨ s", "A"),
        line("1", "s", "-A", "β, α"),
      ];
      expect(check(ProofSystem.lesson4, "r, ¬r ∨ s ⊢ s", lines()).lines.last.issues.single.kind, ProofIssueKind.heavy);
      expect(check(ProofSystem.lesson6, "r, ¬r ∨ s ⊢ s", lines()).complete, isTrue);
    });

    test("Argumente späterer Lektionen sind gesperrt", () {
      final r = check(ProofSystem.lesson4, "¬q ⊢ q → r", [
        line("α", "¬q", "A"),
        line("1", "q → r", "EFQ", "α"),
      ]);
      expect(r.lines.last.issues.single.kind, ProofIssueKind.unavailable);
    });

    test("Falsche Abhängigkeiten werden gemeldet", () {
      final r = check(ProofSystem.lesson4, "q ∧ s ⊢ s", [
        line("α", "q ∧ s", "A", "", "α"),
        line("1", "s", "-K", "α", ""),
      ]);
      expect(r.lines.last.issues.single.message, contains("richtig wäre α"));
    });

    test("+∀ nur für allgemeine Individuen", () {
      final r = check(ProofSystem.full, "Ga ⊢ ∀xGx", [
        line("α", "Ga", "A"),
        line("1", "∀xGx", "+∀", "α"),
      ]);
      expect(r.complete, isFalse);
      expect(r.lines.last.issues.single.message, contains("nicht allgemein"));
    });

    test("-∃: das Individuum darf in B nicht vorkommen", () {
      final r = check(ProofSystem.full, "∃xGx ⊢ Ga", [
        line("α", "∃xGx", "A"),
        line("β", "Ga", "A"),
        line("1", "Ga", "-∃", "α, β, β"),
      ]);
      expect(r.lines.last.issues.single.message, contains("B darf"));
    });

    test("Verschachtelte Quantoren: (ii) beweisbar", () {
      final r = check(ProofSystem.full, "∃y∀xHxy ⊢ ∀x∃yHxy", [
        line("α", "∃y∀xHxy", "A"),
        line("β", "∀xHxa", "A"),
        line("1", "Hba", "-∀", "β"),
        line("2", "∃yHby", "+∃", "1"),
        line("3", "∀x∃yHxy", "+∀", "2"),
        line("4", "∀x∃yHxy", "-∃", "α, β, 3", "α"),
      ]);
      expect(r.complete, isTrue, reason: r.messages.join());
    });

    test("Begründungsspalte wird gelesen", () {
      expect(ProofRule.parse("+Ä", refCount: 2), ProofRule.iffIntro);
      expect(ProofRule.parse("-A", refCount: 3), ProofRule.orElimCases);
      expect(ProofRule.parse("+EFQ", refCount: 1), ProofRule.efq);
      expect(ProofLabels.parseList("a, b, 3"), ["α", "β", "3"]);
    });
  });

  test("Doppelte Negationen: Normalform", () {
    expect(equalModuloDoubleNegation(parseFormula("¬¬q → r"), parseFormula("q → ¬¬r")), isTrue);
    expect(equalModuloDoubleNegation(parseFormula("¬q → r"), parseFormula("q → r")), isFalse);
  });
}
