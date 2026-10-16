import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/logic/lesson_text.dart';
import 'package:theologie_lernapp/models/logic/logic_course.dart';
import 'package:theologie_lernapp/models/logic/logic_exercise.dart';
import 'package:theologie_lernapp/services/logic/exercise_evaluation.dart';
import 'package:theologie_lernapp/services/logic/exercise_generator.dart';
import 'package:theologie_lernapp/services/logic/formula.dart';
import 'package:theologie_lernapp/services/logic/formula_parser.dart';
import 'package:theologie_lernapp/services/logic/logic_course_loader.dart';
import 'package:theologie_lernapp/services/logic/proof_checker.dart';
import 'package:theologie_lernapp/services/logic/proof_rows.dart';
import 'package:theologie_lernapp/services/logic/proof_rules.dart';
import 'package:theologie_lernapp/services/logic/schema_formula.dart';
import 'package:theologie_lernapp/services/logic/semantics.dart';

import '../test_asset_bundle.dart';

/// Prüft den gesamten Inhalt des Lernbereichs: jede Formel im Lehrtext,
/// jeden Beweis, jede Musterlösung und jede Aufgabe mit fester Lösung.
void main() {
  late LogicCourse course;

  setUpAll(() async {
    course = await LogicCourseLoader.load(bundle: FileAssetBundle());
  });

  Iterable<LessonBlock> allBlocks(List<LessonSection> sections) sync* {
    Iterable<LessonBlock> walk(List<LessonBlock> blocks) sync* {
      for (final b in blocks) {
        yield b;
        if (b is BoxBlock) yield* walk(b.children);
      }
    }

    for (final s in sections) {
      yield* walk(s.blocks);
    }
  }

  String describe(ProofCheckResult r) => [
    for (final l in r.lines)
      if (!l.ok) "${l.input.label}: ${l.issues.join("; ")}",
    ...r.messages,
  ].join("\n");

  test("Aufbau: neun Lektionen in der Reihenfolge des Kurses", () {
    expect(course.lessons.map((l) => l.number), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(course.lessons.map((l) => l.chapter), [
      "Syntax der Aussagenlogik",
      "Semantik der Aussagenlogik",
      "Logische Folgerungen",
      "Aussagenlogische Beweise I",
      "Aussagenlogische Beweise II",
      "Aussagenlogische Beweise III",
      "Prädikatenlogik I",
      "Prädikatenlogik II",
      "Prädikatenlogik III",
    ]);
    for (final l in course.lessons) {
      expect(l.sections, isNotEmpty, reason: l.id);
      expect(l.goals, isNotEmpty, reason: l.id);
      for (final p in l.prerequisites) {
        final other = course.lesson(p);
        expect(other, isNotNull, reason: "${l.id} → $p");
        expect(other!.number, lessThan(l.number), reason: "${l.id} → $p");
      }
    }
    expect(course.exam!.tasks, hasLength(7));
  });

  test("Übungs-IDs sind eindeutig", () {
    final ids = [for (final e in course.allExercises) e.id];
    expect(ids.every((id) => id != null), isTrue);
    expect(ids.toSet().length, ids.length);
  });

  test("Formeln, Wahrheitstafeln und Syntaxbäume im Lehrtext sind Sätze", () {
    for (final lesson in course.lessons) {
      for (final b in allBlocks(lesson.sections)) {
        switch (b) {
          case FormulaBlock(formula: final f):
            expect(FormulaParser.parse(f, language: FormulaParser.guessLanguage(f)).ok, isTrue, reason: "${lesson.id}: $f");
          case TruthTableBlock(formula: final f):
            final r = SchemaFormula.parse(f);
            expect(r, isNotNull, reason: "${lesson.id}: $f");
            TruthTable.of(r!.formula);
          case TreeBlock(formula: final f):
            expect(FormulaParser.parse(f, language: FormulaParser.guessLanguage(f)).ok, isTrue, reason: "${lesson.id}: $f");
          default:
        }
      }
    }
  });

  test("Beweise im Lehrtext: vollständige sind korrekt, Teilbeweise ohne Fehler", () {
    var count = 0;
    for (final lesson in course.lessons) {
      for (final b in allBlocks(lesson.sections).whereType<ProofBlock>()) {
        count++;
        final result = ProofRows.check(b.system, b.theorem, b.rows);
        if (b.complete) {
          expect(result.complete, isTrue, reason: "${lesson.id} ${b.theorem}\n${describe(result)}");
        } else {
          for (var i = 0; i < b.rows.length; i++) {
            if (b.rows[i].justification.isEmpty) continue;
            expect(result.lines[i].ok, isTrue, reason: "${lesson.id} ${b.theorem} Zeile ${b.rows[i].label}: ${result.lines[i].issues}");
          }
          expect(result.complete, isFalse, reason: "${lesson.id} ${b.theorem} soll unvollständig sein");
        }
      }
    }
    expect(count, greaterThan(25));
  });

  test("Alle Musterbeweise (Übungen und Übungsklausur) sind vollständig und korrekt", () {
    var count = 0;
    for (final e in course.allExercises.whereType<ProofExercise>()) {
      count++;
      final result = ProofRows.check(e.system, e.theorem, e.solution);
      expect(result.complete, isTrue, reason: "${e.id} ${e.theorem}\n${describe(result)}");
      // Jedes bewiesene Theorem ist auch semantisch gültig (AL).
      final t = Theorem.parse(e.theorem);
      if (!t.isPredicateLogic) {
        expect(LogicSemantics.entails(t.premises, t.thesis), isTrue, reason: e.id);
      }
    }
    expect(count, greaterThan(50));
  });

  test("Aufgaben mit fester Lösung sind wohldefiniert", () {
    for (final e in course.allExercises) {
      switch (e) {
        case WellFormedExercise(expression: final x):
          // Jede Antwort hat eine Begründung.
          final r = ExerciseEvaluation.wellFormed(x, true, language: e.predicateLogic ? LogicLanguage.predicate : LogicLanguage.propositional);
          expect(r.details, isNotEmpty, reason: e.id);
        case TruthTableExercise(formula: final f):
          expect(FormulaParser.parse(f).ok, isTrue, reason: e.id);
        case EvaluateExercise(formula: final f, interpretation: final v):
          final p = FormulaParser.parse(f).formula!;
          expect(v.keys.toSet().containsAll(p.letters), isTrue, reason: e.id);
        case EntailmentExercise(theorem: final t, argument: final a):
          final th = Theorem.parse(t);
          if (a != null) {
            expect(LogicSemantics.entails(th.premises, th.thesis), isTrue, reason: "${e.id}: Begründung nur für gültige Theoreme");
          }
        case FindPremisesExercise(thesis: final t, sample: final s):
          final r = ExerciseEvaluation.findPremises(s, parseFormula(t));
          expect(r.correct, isTrue, reason: "${e.id}: ${r.headline} ${r.details}");
        case FormalizeExercise(expected: final x, key: final key):
          final f = parseFormula(x);
          expect(key.keys.toSet().containsAll(f.letters), isTrue, reason: e.id);
          expect(ExerciseEvaluation.formalize(x, f).correct, isTrue);
        case ChoiceExercise(options: final o, tree: final tree):
          expect(o.where((x) => x.correct), isNotEmpty, reason: e.id);
          if (tree != null) {
            expect(FormulaParser.parse(tree, language: FormulaParser.guessLanguage(tree)).ok, isTrue, reason: e.id);
          }
        case FreeVariablesExercise(expression: final x):
          expect(FormulaParser.parse(x, language: LogicLanguage.predicate).ok, isTrue, reason: e.id);
        case ProofExercise() || OpenExercise():
      }
    }
  });

  test("Kursübung Lektion 1: Satz-Eigenschaft wie begründet", () {
    final expected = {
      "(q ∨ r)": true,
      "q ↔ q": true,
      "(¬(q ∨ s))": false,
      "¬(q ∨ s)": true,
      "¬q ∨ s": true,
      "((q ∧ r) → p ↔ s)": false,
      "¬(q ↔ q) ∧ ¬p": true,
      "¬(r ∧ r)": true,
      "((r → s) ∨ s)": true,
      "¬(r ∧ s) ↔ s": true,
      "(¬(r ∧ s)) ↔ s": false,
      "(¬(r ∧ s) ↔ s)": true,
      "(¬(q ∨ q))": false,
      "¬(q ∨ q) → r ∧ p": false,
    };
    for (final e in course.lesson("l1")!.exercises.whereType<WellFormedExercise>()) {
      expect(FormulaParser.parse(e.expression).ok, expected[e.expression], reason: e.expression);
    }
  });

  test("Kursübung Lektion 3: Gültigkeit der Theoreme", () {
    final expected = {
      "q, p → q ⊢ p": false,
      "r, q ⊢ q": true,
      "r, q ⊢ r": true,
      "q ∨ r ⊢ r": false,
      "q ∨ r ⊢ q": false,
      "q ∨ r, ¬r ⊢ q": true,
      "q ∨ r, ¬q ⊢ r": true,
    };
    for (final e in course.lesson("l3")!.exercises.whereType<EntailmentExercise>()) {
      final t = Theorem.parse(e.theorem);
      expect(LogicSemantics.entails(t.premises, t.thesis), expected[e.theorem], reason: e.theorem);
    }
  });

  test("Kursübung Lektion 4, Übung 2: alle vier Theoreme sind gültig", () {
    for (final t in ["¬¬q → r, ¬r ⊢ ¬q", "q → r, ¬r ⊢ ¬q", "q ↔ ¬¬r, ¬q ⊢ ¬r", "¬(q ∨ r) ↔ r, ¬r ⊢ q"]) {
      final th = Theorem.parse(t);
      expect(LogicSemantics.entails(th.premises, th.thesis), isTrue, reason: t);
    }
  });

  test("Erzeugte Übungen bestehen ihre eigene Prüfung", () {
    final generator = ExerciseGenerator(Random(7));
    for (final lesson in course.lessons) {
      final pool = lesson.exercises.whereType<ProofExercise>().toList();
      for (final kind in lesson.generators) {
        for (var i = 0; i < 15; i++) {
          final e = generator.generate(kind, proofPool: pool);
          if (e == null) continue;
          switch (e) {
            case ProofExercise():
              expect(ProofRows.check(e.system, e.theorem, e.solution).complete, isTrue, reason: e.theorem);
            case EntailmentExercise():
              Theorem.parse(e.theorem);
            case FindPremisesExercise():
              expect(ExerciseEvaluation.findPremises(e.sample, parseFormula(e.thesis)).correct, isTrue);
            case FreeVariablesExercise():
              expect(FormulaParser.parse(e.expression, language: LogicLanguage.predicate).ok, isTrue, reason: e.expression);
            case TruthTableExercise():
              expect(LogicSemantics.lettersOf([parseFormula(e.formula)]).length, greaterThanOrEqualTo(2));
            default:
          }
        }
      }
    }
  });

  test("Regelsysteme: jede Lektion mit Beweisen nennt ein bekanntes System", () {
    for (final l in course.lessons) {
      if (l.proofSystem != null) {
        expect(ProofSystem.all.map((s) => s.id), contains(l.proofSystem));
      }
    }
    for (final e in course.allExercises.whereType<ProofExercise>()) {
      expect(ProofSystem.all.map((s) => s.id), contains(e.system), reason: e.id);
    }
  });

  test("Keine doppelten Negationen in Aufgaben, die DN verbieten würden", () {
    // Lektion 4/5 arbeitet ohne stillschweigende doppelte Negation: Die
    // Musterlösungen müssen dort jeden DN-Schritt ausdrücklich enthalten.
    for (final e in course.allExercises.whereType<ProofExercise>()) {
      if (ProofSystem.byId(e.system).implicitDoubleNegation) continue;
      final result = ProofRows.check(e.system, e.theorem, e.solution);
      for (final l in result.lines) {
        expect(l.issues.where((i) => i.kind.isError), isEmpty, reason: e.id);
      }
    }
    expect(stripDoubleNegations(parseFormula("¬¬(p ∧ ¬¬q)")), parseFormula("p ∧ q"));
  });
}
