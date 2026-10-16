import 'package:flutter/material.dart';

import '../../../models/logic/lesson_text.dart';
import '../../../services/logic/proof_checker.dart';
import '../../../services/logic/proof_rules.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/logic/logic_text.dart';
import '../../../widgets/logic/logic_views.dart';
import '../../../widgets/logic/symbol_keyboard.dart';

class _EditLine {
  ProofRule? rule;
  final TextEditingController formula = TextEditingController();
  final TextEditingController refs = TextEditingController();
  final TextEditingController deps = TextEditingController();
  final TextEditingController comment = TextEditingController();

  _EditLine(this.rule);

  bool get isAssumption => rule == ProofRule.assumption;

  void dispose() {
    formula.dispose();
    refs.dispose();
    deps.dispose();
    comment.dispose();
  }
}

/// Eingabe und Prüfung eines Beweises. Bezeichner werden automatisch
/// vergeben: Annahmen α, β, γ, …, alle anderen Zeilen 1, 2, 3, ….
///
/// [onFinished] meldet einmal das Ergebnis: true, sobald der Beweis
/// vollständig und fehlerfrei ist; false, wenn vorher die Lösung angezeigt
/// wurde.
class ProofEditor extends StatefulWidget {
  final Theorem theorem;
  final String theoremText;
  final ProofSystem system;
  final List<ProofRow> solution;
  final String? plan;
  final ValueChanged<bool>? onFinished;

  const ProofEditor({
    super.key,
    required this.theorem,
    required this.theoremText,
    required this.system,
    required this.solution,
    this.plan,
    this.onFinished,
  });

  @override
  State<ProofEditor> createState() => _ProofEditorState();
}

class _ProofEditorState extends State<ProofEditor> {
  final List<_EditLine> _lines = [];
  TextEditingController? _focused;
  ProofCheckResult? _result;
  bool _showSolution = false;
  bool _showPlan = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _addLine(ProofRule.assumption);
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine(ProofRule? rule) {
    final line = _EditLine(rule);
    _lines.add(line);
    _focused = line.formula;
    _result = null;
  }

  List<String> get _labels {
    var greek = 0;
    var number = 0;
    return [
      for (final l in _lines)
        l.isAssumption
            ? ProofLabels.greek[(greek++) % ProofLabels.greek.length]
            : "${++number}",
    ];
  }

  void _check() {
    final labels = _labels;
    final inputs = [
      for (var i = 0; i < _lines.length; i++)
        ProofLineInput(
          label: labels[i],
          formula: _lines[i].formula.text,
          rule: _lines[i].rule,
          refs: _lines[i].isAssumption
              ? const []
              : ProofLabels.parseList(_lines[i].refs.text),
          dependencies: _lines[i].deps.text.trim().isEmpty
              ? null
              : ProofLabels.parseList(_lines[i].deps.text),
          comment: _lines[i].comment.text.trim(),
        ),
    ];

    // -A mit drei Verweisen ist die Fallunterscheidung.
    final adjusted = [
      for (final input in inputs)
        if (input.rule == ProofRule.orElim && input.refs.length == 3 ||
            input.rule == ProofRule.orElimCases && input.refs.length == 2)
          ProofLineInput(
            label: input.label,
            formula: input.formula,
            rule: input.refs.length == 3 ? ProofRule.orElimCases : ProofRule.orElim,
            refs: input.refs,
            dependencies: input.dependencies,
            comment: input.comment,
          )
        else
          input,
    ];

    final result = ProofChecker(widget.system, widget.theorem).check(adjusted);
    setState(() => _result = result);

    if (result.complete && !_reported) {
      _reported = true;
      widget.onFinished?.call(!_showSolution);
    }
  }

  void _revealSolution() {
    setState(() => _showSolution = true);
    if (!_reported) {
      _reported = true;
      widget.onFinished?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labels = _labels;
    final result = _result;
    final pl = widget.theorem.isPredicateLogic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Argumente: ${widget.system.title}",
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _lines.length; i++)
          _lineCard(context, i, labels[i], result?.lines.elementAtOrNull(i)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey("proof-add-assumption"),
              onPressed: () => setState(() => _addLine(ProofRule.assumption)),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Annahme"),
            ),
            OutlinedButton.icon(
              key: const ValueKey("proof-add-line"),
              onPressed: () => setState(() => _addLine(null)),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Zeile"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SymbolKeyboard(
          controller: _focused,
          predicateLogic: pl,
          extra: const ["α", "β", "γ", "δ", "ε", ","],
          onChanged: () => setState(() => _result = null),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          key: const ValueKey("proof-check"),
          onPressed: _check,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text("Beweis prüfen"),
        ),
        if (result != null) ...[
          const SizedBox(height: 12),
          _summary(context, result),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (widget.plan != null)
              TextButton.icon(
                onPressed: () => setState(() => _showPlan = !_showPlan),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(_showPlan ? "Beweisidee ausblenden" : "Beweisidee"),
              ),
            TextButton.icon(
              key: const ValueKey("proof-solution"),
              onPressed: _showSolution ? null : _revealSolution,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text("Musterlösung zeigen"),
            ),
          ],
        ),
        if (_showPlan && widget.plan != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LogicText(widget.plan!),
          ),
        if (_showSolution) ...[
          const SizedBox(height: 8),
          Text(
            "Musterlösung (geprüft; andere Beweise können ebenso richtig sein)",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          ProofTableView(rows: widget.solution),
        ],
      ],
    );
  }

  Widget _summary(BuildContext context, ProofCheckResult result) {
    final colors = context.colors;
    final ok = result.complete;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? colors.successBackground : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in result.messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                m,
                style: TextStyle(
                  color: ok ? colors.success : colors.textPrimary,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lineCard(BuildContext context, int index, String label, ProofLineResult? result) {
    final colors = context.colors;
    final line = _lines[index];
    final issues = result?.issues ?? const [];
    final hasError = issues.any((i) => i.kind.isError);
    final style = formulaStyle(context, fontSize: 15);

    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    final rules = widget.system.selectableRules;

    return Card(
      key: ValueKey("proof-line-$index"),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        side: BorderSide(
          color: hasError
              ? colors.error
              : (result != null ? colors.success.withValues(alpha: 0.6) : colors.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(label, style: style.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Focus(
                    onFocusChange: (f) {
                      if (f) setState(() => _focused = line.formula);
                    },
                    child: TextField(
                      key: ValueKey("proof-formula-$index"),
                      controller: line.formula,
                      style: style,
                      decoration: deco("Satz"),
                      onChanged: (_) => setState(() => _result = null),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Zeile löschen",
                  visualDensity: VisualDensity.compact,
                  onPressed: _lines.length <= 1
                      ? null
                      : () => setState(() {
                          _lines.removeAt(index).dispose();
                          _focused = null;
                          _result = null;
                        }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 30),
                DropdownButton<ProofRule>(
                  key: ValueKey("proof-rule-$index"),
                  value: line.rule,
                  hint: const Text("Argument"),
                  isDense: true,
                  items: [
                    for (final r in rules)
                      DropdownMenuItem(
                        value: r,
                        child: Text(
                          r == ProofRule.orElimCases ? "-A (Fälle)" : r.symbol,
                          style: formulaStyle(context, fontSize: 14),
                        ),
                      ),
                  ],
                  onChanged: (r) => setState(() {
                    line.rule = r;
                    _result = null;
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    onFocusChange: (f) {
                      if (f) {
                        setState(() => _focused = line.isAssumption ? line.comment : line.refs);
                      }
                    },
                    child: TextField(
                      key: ValueKey("proof-refs-$index"),
                      controller: line.isAssumption ? line.comment : line.refs,
                      style: style.copyWith(fontSize: 14),
                      decoration: deco(line.isAssumption ? "Kommentar, z. B. V" : "Zeilen, z. B. α, 1"),
                      onChanged: (_) => setState(() => _result = null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Focus(
                    onFocusChange: (f) {
                      if (f) setState(() => _focused = line.deps);
                    },
                    child: TextField(
                      key: ValueKey("proof-deps-$index"),
                      controller: line.deps,
                      style: style.copyWith(fontSize: 14),
                      decoration: deco(
                        result != null && line.deps.text.isEmpty
                            ? (result.dependencies.isEmpty ? "–" : result.dependencies.join(", "))
                            : "Abh.",
                      ),
                      onChanged: (_) => setState(() => _result = null),
                    ),
                  ),
                ),
              ],
            ),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 30),
                child: Text(
                  "${issue.kind.label}: ${issue.message}",
                  style: TextStyle(
                    fontSize: 13,
                    color: issue.kind.isError ? colors.error : colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
