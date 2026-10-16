import 'formula.dart';
import 'formula_parser.dart';
import 'proof_rules.dart';
import 'semantics.dart';

/// Eine Zeile eines Beweises, wie sie eingegeben wurde.
class ProofLineInput {
  /// Griechischer Buchstabe bei Annahmen, sonst eine Zahl.
  final String label;

  final String formula;

  /// `null` = kein Argument angegeben.
  final ProofRule? rule;

  final List<String> refs;

  /// Eingetragene Abhängigkeiten; `null` = nicht ausgefüllt (dann trägt die
  /// Prüfung die berechneten ein).
  final List<String>? dependencies;

  /// Kommentar in eckigen Klammern, z. B. „V“, „+I“, „RAA“ – nicht Teil des
  /// formalen Beweises.
  final String? comment;

  const ProofLineInput({
    required this.label,
    required this.formula,
    required this.rule,
    this.refs = const [],
    this.dependencies,
    this.comment,
  });

  /// Begründungsspalte, z. B. „A[V]“ oder „-I(α, 1)“.
  String get justification {
    final r = rule;
    if (r == null) return "";
    if (r == ProofRule.assumption) {
      return comment == null || comment!.isEmpty ? "A" : "A[$comment]";
    }
    return r.format(refs);
  }
}

/// Einordnung eines Fehlers – angelehnt an die Bewertungshinweise des Kurses.
enum ProofIssueKind {
  /// Eingabe nicht lesbar (kein Satz, Argument fehlt …).
  input("Eingabe"),

  /// Argument steht an dieser Stelle des Kurses noch nicht zur Verfügung.
  unavailable("Argument nicht verfügbar"),

  /// Leichter syntaktischer Fehler: falsche Zeilenangabe, falsche
  /// Reihenfolge der Prämissen, falsche Abhängigkeiten.
  light("Leichter Fehler"),

  /// Schwerer syntaktischer Fehler: Argument sinnentstellend angewendet,
  /// der Satz folgt aber inhaltlich aus den Annahmen.
  heavy("Schwerer Fehler"),

  /// Semantischer Fehler: der Satz folgt nicht aus den Annahmen.
  semantic("Semantischer Fehler"),

  /// Argument falsch angewendet (Prädikatenlogik; ohne Einordnung, ob der
  /// Satz inhaltlich folgt).
  rule("Fehler im Argument"),

  /// Hinweis ohne Fehler.
  note("Hinweis");

  final String label;

  const ProofIssueKind(this.label);

  bool get isError => this != note;
}

class ProofIssue {
  final ProofIssueKind kind;
  final String message;

  const ProofIssue(this.kind, this.message);

  @override
  String toString() => "${kind.label}: $message";
}

class ProofLineResult {
  final ProofLineInput input;
  final Formula? formula;

  /// Berechnete Abhängigkeiten (Annahmen, von denen die Zeile abhängt).
  final List<String> dependencies;

  final List<ProofIssue> issues;

  const ProofLineResult(this.input, this.formula, this.dependencies, this.issues);

  bool get ok => issues.every((i) => !i.kind.isError);
}

class ProofCheckResult {
  final List<ProofLineResult> lines;

  /// Zeile, in der die These nur unter Voraussetzungen hergeleitet ist.
  final int? thesisLine;

  /// Der Beweis ist vollständig und fehlerfrei.
  final bool complete;

  final List<String> messages;

  const ProofCheckResult(this.lines, this.thesisLine, this.complete, this.messages);

  bool get hasErrors => lines.any((l) => !l.ok);
}

/// Ein Theorem V1, …, Vn ⊢ T.
class Theorem {
  final List<Formula> premises;
  final Formula thesis;

  const Theorem(this.premises, this.thesis);

  factory Theorem.parse(String text) {
    final parts = text.split("⊢");
    if (parts.length != 2) {
      throw FormatException("Theorem ohne ⊢: $text");
    }
    final left = parts[0].trim();
    return Theorem(
      left.isEmpty ? const [] : _splitPremises(left).map(parseFormula).toList(),
      parseFormula(parts[1].trim()),
    );
  }

  static List<String> _splitPremises(String text) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == "(") depth++;
      if (c == ")") depth--;
      if (c == "," && depth == 0) {
        result.add(text.substring(start, i).trim());
        start = i + 1;
      }
    }
    result.add(text.substring(start).trim());
    return result;
  }

  bool get isPredicateLogic =>
      [...premises, thesis].any((f) => f.isPredicateLogic);

  LogicLanguage get language => isPredicateLogic
      ? LogicLanguage.predicate
      : LogicLanguage.propositional;

  @override
  String toString() =>
      "${premises.isEmpty ? "" : "${premises.map((p) => p.show()).join(", ")} "}⊢ ${thesis.show()}";
}

class _Line {
  final String label;
  final Formula? formula;
  final List<String> deps;
  final bool isAssumption;

  _Line(this.label, this.formula, this.deps, this.isAssumption);
}

class _Outcome {
  final List<String>? deps;
  final String? error;

  const _Outcome.ok(this.deps) : error = null;
  const _Outcome.fail(this.error) : deps = null;

  bool get ok => deps != null;
}

/// Prüft Beweise nach den Argumenten des Kurses.
///
/// Jede Zeile wird einzeln geprüft: Passt der Satz zur Form der Konklusion
/// des angegebenen Arguments, stehen in den angegebenen Zeilen Sätze der
/// Form der Prämissen (in dieser Reihenfolge), und von welchen Annahmen
/// hängt die Zeile ab? Fehler werden – soweit möglich – so eingeordnet wie
/// in den Bewertungshinweisen des Kurses.
class ProofChecker {
  final ProofSystem system;
  final Theorem theorem;

  ProofChecker(this.system, this.theorem);

  bool _eq(Formula a, Formula b) =>
      system.implicitDoubleNegation ? equalModuloDoubleNegation(a, b) : a == b;

  Formula _view(Formula f) =>
      system.implicitDoubleNegation ? stripDoubleNegations(f) : f;

  ProofCheckResult check(List<ProofLineInput> inputs) {
    final lines = <_Line>[];
    _current = lines;
    final results = <ProofLineResult>[];
    final seen = <String>{};

    for (final input in inputs) {
      final issues = <ProofIssue>[];
      final label = input.label.trim();
      final rule = input.rule;

      if (label.isEmpty || seen.contains(label)) {
        issues.add(
          ProofIssue(
            ProofIssueKind.input,
            label.isEmpty
                ? "Die Zeile hat keinen Bezeichner."
                : "Der Bezeichner $label kommt doppelt vor.",
          ),
        );
      }
      seen.add(label);

      final parsed = FormulaParser.parse(
        input.formula,
        language: theorem.language,
      );
      final formula = parsed.formula;

      if (formula == null) {
        issues.add(
          ProofIssue(
            ProofIssueKind.input,
            "„${input.formula}“ ist kein Satz: ${parsed.error}",
          ),
        );
      } else if (formula.freeVariables.isNotEmpty) {
        issues.add(
          ProofIssue(
            ProofIssueKind.input,
            "„${formula.show()}“ ist eine Satzfunktion (frei: "
            "${formula.freeVariables.join(", ")}), kein Satz. In Beweisen "
            "stehen nur Sätze.",
          ),
        );
      }

      final isAssumption = rule == ProofRule.assumption;

      if (rule != null &&
          isAssumption != ProofLabels.isAssumptionLabel(label) &&
          label.isNotEmpty) {
        issues.add(
          ProofIssue(
            ProofIssueKind.light,
            isAssumption
                ? "Annahmen werden mit griechischen Buchstaben bezeichnet."
                : "Nur Annahmen werden mit griechischen Buchstaben "
                      "bezeichnet; hergeleitete Zeilen werden nummeriert.",
          ),
        );
      }

      List<String> deps = const [];

      if (rule == null) {
        issues.add(
          const ProofIssue(ProofIssueKind.input, "Es fehlt das Argument."),
        );
      } else if (!system.rules.contains(rule)) {
        issues.add(
          ProofIssue(
            ProofIssueKind.unavailable,
            "${rule.symbol} (${rule.title}) steht hier noch nicht zur "
            "Verfügung (${system.title}).",
          ),
        );
      }

      final refs = <_Line>[];
      var refsOk = true;

      for (final ref in input.refs) {
        final target = lines.where((l) => l.label == ref).firstOrNull;
        if (target == null) {
          refsOk = false;
          issues.add(
            ProofIssue(
              ProofIssueKind.light,
              "Eine Zeile „$ref“ gibt es vor dieser Zeile nicht.",
            ),
          );
        } else {
          refs.add(target);
        }
      }

      if (rule != null && formula != null && issues.every((i) => i.kind != ProofIssueKind.input)) {
        if (rule == ProofRule.assumption) {
          deps = [label];
          if (input.refs.isNotEmpty) {
            issues.add(
              const ProofIssue(
                ProofIssueKind.light,
                "Eine Annahme verweist auf keine anderen Zeilen.",
              ),
            );
          }
        } else if (refsOk && refs.every((r) => r.formula != null)) {
          final outcome = _apply(rule, refs, formula, label);

          if (outcome.ok) {
            deps = outcome.deps!;
          } else {
            final repair = _findRepair(rule, refs, formula, lines, label);
            if (repair != null) {
              issues.add(ProofIssue(ProofIssueKind.light, repair.$1));
              deps = repair.$2;
            } else {
              deps = _guessDeps(rule, refs);
              issues.add(_classifyFailure(outcome.error!, formula, deps, lines));
            }
          }
        } else {
          deps = _guessDeps(rule, refs);
        }
      }

      final entered = input.dependencies;
      if (entered != null && issues.every((i) => !i.kind.isError)) {
        final a = entered.toSet();
        final b = deps.toSet();
        if (a.length != b.length || !a.containsAll(b)) {
          issues.add(
            ProofIssue(
              ProofIssueKind.light,
              "Abhängigkeiten: eingetragen ${_fmt(entered)}, richtig wäre "
              "${_fmt(deps)}.",
            ),
          );
        }
      }

      lines.add(_Line(label, formula, deps, isAssumption));
      results.add(ProofLineResult(input, formula, deps, issues));
    }

    return _finish(results, lines);
  }

  static String _fmt(List<String> deps) =>
      deps.isEmpty ? "keine" : deps.join(", ");

  List<String> _union(Iterable<List<String>> sets) => [
    for (final d in {for (final s in sets) ...s}) d,
  ];

  List<String> _guessDeps(ProofRule rule, List<_Line> refs) {
    final all = _union(refs.map((r) => r.deps));
    final discharged = switch (rule) {
      ProofRule.impIntro || ProofRule.raa => refs.isEmpty ? null : refs.first.label,
      ProofRule.existsElim => refs.length > 1 ? refs[1].label : null,
      _ => null,
    };
    return [for (final d in all) if (d != discharged) d];
  }

  /// Andere Reihenfolge oder andere Zeilen, mit denen das Argument passt.
  (String, List<String>)? _findRepair(
    ProofRule rule,
    List<_Line> refs,
    Formula formula,
    List<_Line> lines,
    String label,
  ) {
    if (refs.length >= 2) {
      for (final perm in _permutations(refs)) {
        final outcome = _apply(rule, perm, formula, label);
        if (outcome.ok) {
          return (
            "Falsche Reihenfolge der Prämissen: richtig wäre "
                "${rule.format(perm.map((l) => l.label).toList())}.",
            outcome.deps!,
          );
        }
      }
    }

    final candidates = lines.where((l) => l.formula != null).toList();
    final arity = rule == ProofRule.tautology ? refs.length : rule.arity;
    if (arity == 0 || candidates.length > 40) return null;

    for (final combo in _tuples(candidates, arity)) {
      final outcome = _apply(rule, combo, formula, label);
      if (outcome.ok) {
        return (
          "Falsche Zeilenangabe: Mit "
              "${rule.format(combo.map((l) => l.label).toList())} wäre "
              "das Argument korrekt angewendet.",
          outcome.deps!,
        );
      }
    }

    return null;
  }

  Iterable<List<_Line>> _permutations(List<_Line> items) sync* {
    if (items.length <= 1) {
      yield items;
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final rest = [...items]..removeAt(i);
      for (final p in _permutations(rest)) {
        final candidate = [items[i], ...p];
        if (!_sameOrder(candidate, items)) yield candidate;
      }
    }
  }

  bool _sameOrder(List<_Line> a, List<_Line> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) return false;
    }
    return true;
  }

  Iterable<List<_Line>> _tuples(List<_Line> items, int n) sync* {
    if (n == 0) {
      yield [];
      return;
    }
    for (final item in items) {
      for (final rest in _tuples(items, n - 1)) {
        yield [item, ...rest];
      }
    }
  }

  ProofIssue _classifyFailure(
    String error,
    Formula formula,
    List<String> deps,
    List<_Line> lines,
  ) {
    if (theorem.isPredicateLogic) {
      return ProofIssue(ProofIssueKind.rule, error);
    }

    final assumptions = [
      for (final l in lines)
        if (deps.contains(l.label) && l.formula != null) l.formula!,
    ];

    final follows = LogicSemantics.entails(assumptions, formula);

    if (follows) {
      return ProofIssue(
        ProofIssueKind.heavy,
        "$error Inhaltlich folgt der Satz zwar aus den Annahmen "
        "(${_fmt(deps)}), aber nicht mit diesem Argument.",
      );
    }

    final counter = LogicSemantics.counterexamples(assumptions, formula).first;
    final letters = LogicSemantics.lettersOf([...assumptions, formula]);
    return ProofIssue(
      ProofIssueKind.semantic,
      "$error Der Satz folgt auch inhaltlich nicht aus den Annahmen "
      "(${_fmt(deps)}): Unter ${LogicSemantics.formatInterpretation(counter, letters)} "
      "sind sie wahr, „${formula.show()}“ aber falsch.",
    );
  }

  String _s(Formula f) => "„${f.show()}“";

  _Outcome _apply(
    ProofRule rule,
    List<_Line> refs,
    Formula f,
    String label,
  ) {
    final expected = rule == ProofRule.tautology ? null : rule.arity;
    if (expected != null && refs.length != expected) {
      return _Outcome.fail(
        "${rule.symbol} verweist auf $expected Zeile${expected == 1 ? "" : "n"}, "
        "angegeben ${refs.length == 1 ? "ist eine" : "sind ${refs.length}"}.",
      );
    }

    List<String> d(Iterable<_Line> ls) => _union(ls.map((l) => l.deps));
    Formula fr(int i) => refs[i].formula!;

    switch (rule) {
      case ProofRule.assumption:
        return _Outcome.ok([label]);

      case ProofRule.tautology:
        if (refs.isEmpty) {
          final v = _view(f);
          if (v is Binary && v.op == BinaryOperator.implies && _eq(v.left, v.right)) {
            return const _Outcome.ok([]);
          }
          return _Outcome.fail(
            "Mit T lässt sich nur ein Satz der Form A → A aufnehmen; "
            "${_s(f)} hat diese Form nicht.",
          );
        }
        if (refs.length == 1 && system.implicitDoubleNegation) {
          if (_eq(f, fr(0))) return _Outcome.ok(refs[0].deps);
          return _Outcome.fail(
            "T(${refs[0].label}) wiederholt den Satz aus Zeile "
            "${refs[0].label}; ${_s(f)} ist ein anderer Satz.",
          );
        }
        return const _Outcome.fail("T steht ohne Verweis auf andere Zeilen.");

      case ProofRule.andIntro:
        final v = _view(f);
        if (v is! Binary || v.op != BinaryOperator.and) {
          return _Outcome.fail("+K liefert eine Konjunktion; ${_s(f)} ist keine.");
        }
        if (!_eq(v.left, fr(0))) {
          return _Outcome.fail(
            "+K(${refs[0].label}, ${refs[1].label}): In Zeile ${refs[0].label} "
            "müsste der linke Operand ${_s(v.left)} stehen.",
          );
        }
        if (!_eq(v.right, fr(1))) {
          return _Outcome.fail(
            "+K(${refs[0].label}, ${refs[1].label}): In Zeile ${refs[1].label} "
            "müsste der rechte Operand ${_s(v.right)} stehen.",
          );
        }
        return _Outcome.ok(d(refs));

      case ProofRule.andElim:
        final p = _view(fr(0));
        if (p is! Binary || p.op != BinaryOperator.and) {
          return _Outcome.fail(
            "-K braucht eine Konjunktion; in Zeile ${refs[0].label} steht "
            "${_s(fr(0))}.",
          );
        }
        if (_eq(f, p.left) || _eq(f, p.right)) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "Mit -K erhält man aus ${_s(fr(0))} nur ${_s(p.left)} oder "
          "${_s(p.right)}.",
        );

      case ProofRule.orIntro:
        final v = _view(f);
        if (v is! Binary || v.op != BinaryOperator.or) {
          return _Outcome.fail("+A liefert eine Adjunktion; ${_s(f)} ist keine.");
        }
        final need = imp(neg(v.left), v.right);
        if (_eq(fr(0), need)) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "Für ${_s(f)} mit +A müsste in Zeile ${refs[0].label} "
          "${_s(need)} stehen (Form ¬A → B).",
        );

      case ProofRule.orElim:
        final p = _view(fr(0));
        if (p is! Binary || p.op != BinaryOperator.or) {
          return _Outcome.fail(
            "-A braucht in der ersten angegebenen Zeile eine Adjunktion; in "
            "Zeile ${refs[0].label} steht ${_s(fr(0))}.",
          );
        }
        if (_eq(fr(1), neg(p.left)) && _eq(f, p.right)) return _Outcome.ok(d(refs));
        if (_eq(fr(1), neg(p.right)) && _eq(f, p.left)) return _Outcome.ok(d(refs));
        if (_eq(f, p.left) || _eq(f, p.right)) {
          final other = _eq(f, p.right) ? p.left : p.right;
          return _Outcome.fail(
            "Um aus ${_s(fr(0))} auf ${_s(f)} zu schließen, braucht -A als "
            "zweite Prämisse die Negation des anderen Operanden: "
            "${_s(neg(other))}. In Zeile ${refs[1].label} steht "
            "${_s(fr(1))}.",
          );
        }
        return _Outcome.fail(
          "-A liefert einen der beiden Operanden von ${_s(fr(0))}; ${_s(f)} "
          "ist keiner davon.",
        );

      case ProofRule.impElim:
        final p = _view(fr(0));
        if (p is! Binary || p.op != BinaryOperator.implies) {
          return _Outcome.fail(
            "-I braucht in der ersten angegebenen Zeile eine Implikation; in "
            "Zeile ${refs[0].label} steht ${_s(fr(0))}.",
          );
        }
        if (!_eq(fr(1), p.left)) {
          if (_eq(fr(1), p.right) && _eq(f, p.left)) {
            return _Outcome.fail(
              "Hier wird von der Konklusion ${_s(p.right)} auf die Prämisse "
              "${_s(p.left)} zurückgeschlossen. Das erlaubt -I nicht: Aus "
              "A → B und B folgt A nicht.",
            );
          }
          return _Outcome.fail(
            "-I braucht als zweite Prämisse die Prämisse der Implikation, "
            "${_s(p.left)}; in Zeile ${refs[1].label} steht ${_s(fr(1))}.",
          );
        }
        if (!_eq(f, p.right)) {
          return _Outcome.fail(
            "Mit -I erhält man die Konklusion ${_s(p.right)}, nicht ${_s(f)}.",
          );
        }
        return _Outcome.ok(d(refs));

      case ProofRule.impIntro:
        final a = refs[0];
        if (!a.isAssumption) {
          return _Outcome.fail(
            "+I nennt zuerst die Annahme, die beseitigt wird; Zeile "
            "${a.label} ist keine Annahme.",
          );
        }
        final v = _view(f);
        if (v is! Binary || v.op != BinaryOperator.implies) {
          return _Outcome.fail("+I liefert eine Implikation; ${_s(f)} ist keine.");
        }
        if (!_eq(v.left, a.formula!)) {
          return _Outcome.fail(
            "Die Prämisse der hergeleiteten Implikation muss die Annahme "
            "${_s(a.formula!)} aus Zeile ${a.label} sein, nicht ${_s(v.left)}.",
          );
        }
        if (!_eq(v.right, fr(1))) {
          return _Outcome.fail(
            "Die Konklusion der Implikation muss der Satz aus Zeile "
            "${refs[1].label} sein (${_s(fr(1))}), nicht ${_s(v.right)}.",
          );
        }
        return _Outcome.ok([for (final x in refs[1].deps) if (x != a.label) x]);

      case ProofRule.iffIntro:
        final v = _view(f);
        if (v is! Binary || v.op != BinaryOperator.iff) {
          return _Outcome.fail("+Ä liefert eine Äquivalenz; ${_s(f)} ist keine.");
        }
        final first = imp(v.left, v.right);
        final second = imp(v.right, v.left);
        if (_eq(fr(0), first) && _eq(fr(1), second)) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "Für ${_s(f)} braucht +Ä zuerst ${_s(first)} und dann "
          "${_s(second)}.",
        );

      case ProofRule.iffElim:
        final p = _view(fr(0));
        if (p is! Binary || p.op != BinaryOperator.iff) {
          return _Outcome.fail(
            "-Ä braucht eine Äquivalenz; in Zeile ${refs[0].label} steht "
            "${_s(fr(0))}.",
          );
        }
        if (_eq(f, imp(p.left, p.right)) || _eq(f, imp(p.right, p.left))) {
          return _Outcome.ok(d(refs));
        }
        return _Outcome.fail(
          "Aus ${_s(fr(0))} erhält man mit -Ä nur "
          "${_s(imp(p.left, p.right))} oder ${_s(imp(p.right, p.left))}.",
        );

      case ProofRule.dnIntro:
        final ok = system.implicitDoubleNegation
            ? _eq(f, fr(0))
            : f == neg(neg(fr(0)));
        if (ok) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "+DN setzt ¬¬ vor den Satz aus Zeile ${refs[0].label}: das ergäbe "
          "${_s(neg(neg(fr(0))))}.",
        );

      case ProofRule.dnElim:
        final ok = system.implicitDoubleNegation
            ? _eq(f, fr(0))
            : neg(neg(f)) == fr(0);
        if (ok) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "-DN streicht eine doppelte Negation ganz vorne; in Zeile "
          "${refs[0].label} steht ${_s(fr(0))}.",
        );

      case ProofRule.raa:
        final a = refs[0];
        if (!a.isAssumption) {
          return _Outcome.fail(
            "RAA nennt zuerst die Annahme, die widerlegt wird; Zeile "
            "${a.label} ist keine Annahme.",
          );
        }
        final b = fr(1);
        final notB = fr(2);
        final contradiction = system.implicitDoubleNegation
            ? _eq(notB, neg(b))
            : notB == neg(b);
        if (!contradiction) {
          return _Outcome.fail(
            "Für RAA müssen die Zeilen ${refs[1].label} und ${refs[2].label} "
            "einen Widerspruch bilden: erst ein Satz B, dann ¬B. Hier stehen "
            "${_s(b)} und ${_s(notB)}.",
          );
        }
        final result = system.implicitDoubleNegation
            ? _eq(f, neg(a.formula!))
            : f == neg(a.formula!);
        if (!result) {
          return _Outcome.fail(
            "RAA liefert die Negation der Annahme aus Zeile ${a.label}: "
            "${_s(neg(a.formula!))}.",
          );
        }
        return _Outcome.ok([
          for (final x in d([refs[1], refs[2]])) if (x != a.label) x,
        ]);

      case ProofRule.efq:
        final v = _view(f);
        if (v is! Binary || v.op != BinaryOperator.implies) {
          return _Outcome.fail("EFQ liefert eine Implikation; ${_s(f)} ist keine.");
        }
        if (_eq(fr(0), neg(v.left))) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "EFQ: Aus ¬A folgt A → B. Für ${_s(f)} müsste in Zeile "
          "${refs[0].label} ${_s(neg(v.left))} stehen.",
        );

      case ProofRule.veq:
        final v = _view(f);
        if (v is! Binary || v.op != BinaryOperator.implies) {
          return _Outcome.fail("VEQ liefert eine Implikation; ${_s(f)} ist keine.");
        }
        if (_eq(fr(0), v.right)) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "VEQ: Aus A folgt B → A. Für ${_s(f)} müsste in Zeile "
          "${refs[0].label} ${_s(v.right)} stehen.",
        );

      case ProofRule.orElimCases:
        final p = _view(fr(0));
        if (p is! Binary || p.op != BinaryOperator.or) {
          return _Outcome.fail(
            "-A (Fallunterscheidung) braucht zuerst eine Adjunktion; in "
            "Zeile ${refs[0].label} steht ${_s(fr(0))}.",
          );
        }
        if (!_eq(fr(1), f) || !_eq(fr(2), f)) {
          return _Outcome.fail(
            "Bei der Fallunterscheidung muss in beiden Fällen (Zeilen "
            "${refs[1].label} und ${refs[2].label}) derselbe Satz ${_s(f)} "
            "hergeleitet sein.",
          );
        }
        bool isCase(String dep, Formula c) {
          final line = _byLabel(dep);
          return line != null && line.isAssumption && _eq(line.formula!, c);
        }
        return _Outcome.ok(
          _union([
            refs[0].deps,
            [for (final x in refs[1].deps) if (!isCase(x, p.left)) x],
            [for (final x in refs[2].deps) if (!isCase(x, p.right)) x],
          ]),
        );

      case ProofRule.contraposition:
        final p = _view(fr(0));
        if (p is! Binary || p.op != BinaryOperator.implies) {
          return _Outcome.fail(
            "KP braucht eine Implikation; in Zeile ${refs[0].label} steht "
            "${_s(fr(0))}.",
          );
        }
        final need = imp(neg(p.right), neg(p.left));
        if (_eq(f, need)) return _Outcome.ok(d(refs));
        return _Outcome.fail("KP liefert aus ${_s(fr(0))} den Satz ${_s(need)}.");

      case ProofRule.transitivity:
        final p = _view(fr(0));
        final q = _view(fr(1));
        if (p is! Binary ||
            p.op != BinaryOperator.implies ||
            q is! Binary ||
            q.op != BinaryOperator.implies) {
          return const _Outcome.fail("TI verbindet zwei Implikationen.");
        }
        if (!_eq(p.right, q.left)) {
          return _Outcome.fail(
            "TI: Die Konklusion von ${_s(fr(0))} muss die Prämisse von "
            "${_s(fr(1))} sein.",
          );
        }
        final need = imp(p.left, q.right);
        if (_eq(f, need)) return _Outcome.ok(d(refs));
        return _Outcome.fail("TI liefert hier ${_s(need)}.");

      case ProofRule.nkIntro:
      case ProofRule.naIntro:
        final andForm = rule == ProofRule.nkIntro;
        final v = _view(f);
        final inner = v is Negation ? _view(v.operand) : null;
        final op = andForm ? BinaryOperator.and : BinaryOperator.or;
        if (inner is! Binary || inner.op != op) {
          return _Outcome.fail(
            "${rule.symbol} liefert einen Satz der Form "
            "${andForm ? "¬(A ∧ B)" : "¬(A ∨ B)"}; ${_s(f)} hat sie nicht.",
          );
        }
        final need = andForm
            ? or(neg(inner.left), neg(inner.right))
            : and(neg(inner.left), neg(inner.right));
        if (_eq(fr(0), need)) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "Für ${_s(f)} müsste in Zeile ${refs[0].label} ${_s(need)} stehen.",
        );

      case ProofRule.nkElim:
      case ProofRule.naElim:
        final andForm = rule == ProofRule.nkElim;
        final p = _view(fr(0));
        final inner = p is Negation ? _view(p.operand) : null;
        final op = andForm ? BinaryOperator.and : BinaryOperator.or;
        if (inner is! Binary || inner.op != op) {
          return _Outcome.fail(
            "${rule.symbol} braucht einen Satz der Form "
            "${andForm ? "¬(A ∧ B)" : "¬(A ∨ B)"}; in Zeile "
            "${refs[0].label} steht ${_s(fr(0))}.",
          );
        }
        final need = andForm
            ? or(neg(inner.left), neg(inner.right))
            : and(neg(inner.left), neg(inner.right));
        if (_eq(f, need)) return _Outcome.ok(d(refs));
        return _Outcome.fail("${rule.symbol} liefert hier ${_s(need)}.");

      case ProofRule.allElim:
        final p = _view(fr(0));
        if (p is! Quantified || p.quantifier != Quantifier.all) {
          return _Outcome.fail(
            "-∀ braucht einen allquantifizierten Satz; in Zeile "
            "${refs[0].label} steht ${_s(fr(0))}.",
          );
        }
        for (final i in {...f.individuals, ...LogicAlphabet.individuals.split("")}) {
          if (_eq(f, p.instantiate(i))) return _Outcome.ok(d(refs));
        }
        return _Outcome.fail(
          "-∀ setzt für alle Vorkommen von ${p.variable} im Bereich "
          "${_s(p.body)} dasselbe Individuum ein; ${_s(f)} entsteht so "
          "nicht.",
        );

      case ProofRule.existsIntro:
        final v = _view(f);
        if (v is! Quantified || v.quantifier != Quantifier.exists) {
          return _Outcome.fail(
            "+∃ liefert einen existenzquantifizierten Satz; ${_s(f)} ist "
            "keiner.",
          );
        }
        for (final i in fr(0).individuals) {
          if (_eq(v.instantiate(i), fr(0))) return _Outcome.ok(d(refs));
        }
        return _Outcome.fail(
          "Für ${_s(f)} mit +∃ müsste in Zeile ${refs[0].label} ein Satz "
          "Ai stehen, der aus ${_s(v.body)} entsteht, wenn man für "
          "${v.variable} ein Individuum einsetzt.",
        );

      case ProofRule.allIntro:
        final v = _view(f);
        if (v is! Quantified || v.quantifier != Quantifier.all) {
          return _Outcome.fail(
            "+∀ liefert einen allquantifizierten Satz; ${_s(f)} ist keiner.",
          );
        }
        for (final i in fr(0).individuals) {
          if (!_eq(v.instantiate(i), fr(0))) continue;
          if (f.individuals.contains(i)) {
            return _Outcome.fail(
              "Bei +∀ muss das Individuum $i überall durch die Variable "
              "${v.variable} ersetzt werden; in ${_s(f)} kommt $i noch vor.",
            );
          }
          final burdened = _assumptionsMentioning(refs[0].deps, i);
          if (burdened.isNotEmpty) {
            return _Outcome.fail(
              "$i ist nicht allgemein: Es kommt in der Annahme "
              "${burdened.join(", ")} vor, von der Zeile ${refs[0].label} "
              "abhängt. +∀ verlangt X[$i̸] – $i darf in den Annahmen "
              "nicht vorkommen.",
            );
          }
          return _Outcome.ok(d(refs));
        }
        return _Outcome.fail(
          "Für ${_s(f)} mit +∀ müsste in Zeile ${refs[0].label} ein Satz Ai "
          "stehen, der aus ${_s(v.body)} entsteht, wenn man für "
          "${v.variable} ein Individuum einsetzt.",
        );

      case ProofRule.existsElim:
        final p = _view(fr(0));
        final a = refs[1];
        if (p is! Quantified || p.quantifier != Quantifier.exists) {
          return _Outcome.fail(
            "-∃ nennt zuerst einen existenzquantifizierten Satz; in Zeile "
            "${refs[0].label} steht ${_s(fr(0))}.",
          );
        }
        if (!a.isAssumption) {
          return _Outcome.fail(
            "-∃ nennt als Zweites die Annahme Ai; Zeile ${a.label} ist keine "
            "Annahme.",
          );
        }
        if (!_eq(f, fr(2))) {
          return _Outcome.fail(
            "-∃ wiederholt den Satz B aus Zeile ${refs[2].label} "
            "(${_s(fr(2))}); hier steht ${_s(f)}.",
          );
        }
        for (final i in a.formula!.individuals) {
          if (!_eq(p.instantiate(i), a.formula!)) continue;
          if (fr(0).individuals.contains(i)) {
            return _Outcome.fail(
              "Das Individuum $i kommt schon in ${_s(fr(0))} vor.",
            );
          }
          if (f.individuals.contains(i)) {
            return _Outcome.fail(
              "Der Satz B darf das Individuum $i nicht enthalten "
              "(B[$i̸]); ${_s(f)} enthält es.",
            );
          }
          final xBurdened = _assumptionsMentioning(refs[0].deps, i);
          final rest = [for (final x in refs[2].deps) if (x != a.label) x];
          final yBurdened = _assumptionsMentioning(rest, i);
          final burdened = [...xBurdened, ...yBurdened];
          if (burdened.isNotEmpty) {
            return _Outcome.fail(
              "Das Individuum $i kommt in der Annahme ${burdened.join(", ")} "
              "vor, von der die Herleitung abhängt. -∃ verlangt, dass $i "
              "außer in der Annahme ${a.label} nirgends vorkommt.",
            );
          }
          return _Outcome.ok(_union([refs[0].deps, rest]));
        }
        return _Outcome.fail(
          "Die Annahme in Zeile ${a.label} (${_s(a.formula!)}) hat nicht die "
          "Form Ai zu ${_s(fr(0))}.",
        );

      case ProofRule.nAllIntro:
      case ProofRule.nExistsIntro:
        final fromAll = rule == ProofRule.nExistsIntro;
        final p = _view(fr(0));
        final q = fromAll ? Quantifier.all : Quantifier.exists;
        if (p is! Quantified || p.quantifier != q) {
          return _Outcome.fail(
            "${rule.symbol} braucht einen Satz der Form "
            "${fromAll ? "∀xAx" : "∃xAx"}; in Zeile ${refs[0].label} steht "
            "${_s(fr(0))}.",
          );
        }
        final need = neg(
          Quantified(
            fromAll ? Quantifier.exists : Quantifier.all,
            p.variable,
            neg(p.body),
          ),
        );
        if (_eq(f, need)) return _Outcome.ok(d(refs));
        return _Outcome.fail("${rule.symbol} liefert hier ${_s(need)}.");

      case ProofRule.nAllElim:
      case ProofRule.nExistsElim:
        final toAll = rule == ProofRule.nExistsElim;
        final v = _view(f);
        final q = toAll ? Quantifier.all : Quantifier.exists;
        if (v is! Quantified || v.quantifier != q) {
          return _Outcome.fail(
            "${rule.symbol} liefert einen Satz der Form "
            "${toAll ? "∀xAx" : "∃xAx"}; ${_s(f)} hat sie nicht.",
          );
        }
        final need = neg(
          Quantified(
            toAll ? Quantifier.exists : Quantifier.all,
            v.variable,
            neg(v.body),
          ),
        );
        if (_eq(fr(0), need)) return _Outcome.ok(d(refs));
        return _Outcome.fail(
          "Für ${_s(f)} mit ${rule.symbol} müsste in Zeile "
          "${refs[0].label} ${_s(need)} stehen.",
        );
    }
  }

  List<_Line> _current = const [];

  _Line? _byLabel(String label) =>
      _current.where((l) => l.label == label).firstOrNull;

  List<String> _assumptionsMentioning(List<String> deps, String individual) => [
    for (final dep in deps)
      if (_byLabel(dep)?.formula?.individuals.contains(individual) ?? false) dep,
  ];

  ProofCheckResult _finish(List<ProofLineResult> results, List<_Line> lines) {
    final messages = <String>[];

    final premiseLabels = <String>{
      for (final l in lines)
        if (l.isAssumption &&
            l.formula != null &&
            theorem.premises.any((p) => _eq(p, l.formula!)))
          l.label,
    };

    int? thesisLine;
    var thesisWithExtraDeps = -1;

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.formula == null || !_eq(l.formula!, theorem.thesis)) continue;
      if (premiseLabels.containsAll(l.deps)) {
        thesisLine = i;
        break;
      }
      thesisWithExtraDeps = i;
    }

    final errors = [
      for (final r in results)
        if (!r.ok) r.input.label,
    ];

    if (thesisLine == null) {
      if (thesisWithExtraDeps >= 0) {
        final l = lines[thesisWithExtraDeps];
        final extra = l.deps.where((d) => !premiseLabels.contains(d)).toList();
        messages.add(
          "Die These steht in Zeile ${l.label}, hängt dort aber noch von "
          "${extra.join(", ")} ab – keine Voraussetzung des Theorems. Diese "
          "Annahme muss noch beseitigt werden (z. B. mit +I, RAA oder -∃).",
        );
      } else {
        messages.add("Die These ${theorem.thesis.show()} ist noch nicht hergeleitet.");
      }
    } else {
      final used = lines[thesisLine].deps.toSet();
      final unused = [
        for (final p in theorem.premises)
          if (!lines.any(
            (l) =>
                used.contains(l.label) &&
                l.formula != null &&
                _eq(l.formula!, p),
          ))
            p.show(),
      ];
      if (unused.isNotEmpty && errors.isEmpty) {
        messages.add(
          "Die Voraussetzung ${unused.join(", ")} wird nicht gebraucht – "
          "sie ist für dieses Theorem überflüssig.",
        );
      }
    }

    if (errors.isNotEmpty) {
      messages.insert(0, "Fehler in Zeile ${errors.join(", ")}.");
    }

    final complete = thesisLine != null && errors.isEmpty;
    if (complete) {
      messages.insert(
        0,
        "Der Beweis ist vollständig: Die These ist in Zeile "
        "${lines[thesisLine].label} hergeleitet und hängt nur von "
        "Voraussetzungen ab.",
      );
    }

    return ProofCheckResult(results, thesisLine, complete, messages);
  }
}
