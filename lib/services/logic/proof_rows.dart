import '../../models/logic/lesson_text.dart';
import 'formula_parser.dart';
import 'proof_checker.dart';
import 'proof_rules.dart';

/// Wandelt Beweiszeilen in der Schreibweise des Kurses (Argumentspalte wie
/// „A[V]“ oder „-I(α, 1)“) in Eingaben für den [ProofChecker] um.
class ProofRows {
  ProofRows._();

  static final RegExp _justification = RegExp(
    r"^\s*([^\s(\[]+)\s*(?:\[([^\]]*)\])?\s*(?:\(([^)]*)\))?\s*$",
  );

  /// Zerlegt die Argumentspalte. Leere Spalte → kein Argument.
  static ({ProofRule? rule, List<String> refs, String? comment}) parseJustification(
    String text,
  ) {
    final t = text.trim();
    if (t.isEmpty) return (rule: null, refs: const [], comment: null);

    final m = _justification.firstMatch(t);
    if (m == null) return (rule: null, refs: const [], comment: null);

    final refs = m.group(3) == null ? <String>[] : ProofLabels.parseList(m.group(3)!);
    final rule = ProofRule.parse(m.group(1)!, refCount: refs.length);

    return (rule: rule, refs: refs, comment: m.group(2));
  }

  static ProofLineInput toInput(ProofRow row, {bool withDependencies = true}) {
    final j = parseJustification(row.justification);
    return ProofLineInput(
      label: row.label,
      formula: row.formula,
      rule: j.rule,
      refs: j.refs,
      comment: j.comment,
      // Eine leere Spalte gilt als nicht ausgefüllt (in den ersten Beweisen
      // von Lektion 4 gibt es die Abhängigkeitsspalte noch nicht).
      dependencies: withDependencies && row.dependencies.trim().isNotEmpty
          ? ProofLabels.parseList(row.dependencies)
          : null,
    );
  }

  static ProofCheckResult check(
    String system,
    String theorem,
    List<ProofRow> rows,
  ) {
    // Ohne Theorem (Ausschnitte im Lehrtext) wird nur Zeile für Zeile
    // geprüft; als These dient dann der letzte Satz.
    final t = theorem.trim().isEmpty
        ? Theorem(const [], parseFormula(rows.last.formula))
        : Theorem.parse(theorem);
    return ProofChecker(
      ProofSystem.byId(system),
      t,
    ).check([for (final r in rows) toInput(r)]);
  }
}
