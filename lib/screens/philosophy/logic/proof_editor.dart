import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/logic/lesson_text.dart';
import '../../../services/logic/logic_progress_store.dart';
import '../../../services/logic/proof_checker.dart';
import '../../../services/logic/proof_draft.dart';
import '../../../services/logic/proof_rules.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/logic/logic_text.dart';
import '../../../widgets/logic/logic_views.dart';
import '../../../widgets/logic/symbol_keyboard.dart';

class _EditLine {
  /// Stabile Identität; die Position bestimmt nur den Bezeichner.
  final String id;
  ProofRule? rule;
  final TextEditingController formula = TextEditingController();
  final TextEditingController refs = TextEditingController();
  final TextEditingController deps = TextEditingController();
  final TextEditingController comment = TextEditingController();

  _EditLine(this.rule) : id = ProofDraft.newLineId();

  _EditLine.from(ProofDraftLine line) : id = line.id, rule = line.rule {
    formula.text = line.formula;
    refs.text = line.refs;
    deps.text = line.deps;
    comment.text = line.comment;
  }

  bool get isAssumption => rule == ProofRule.assumption;

  ({String id, bool assumption}) get key => (id: id, assumption: isAssumption);

  ProofDraftLine toDraft() => ProofDraftLine(
    id: id,
    rule: rule,
    formula: formula.text,
    refs: refs.text,
    deps: deps.text,
    comment: comment.text,
  );

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
///
/// Zeilen lassen sich nachträglich verschieben (Griff, Pfeile oder Menü)
/// und an beliebiger Stelle einfügen. Weil sich dabei die Bezeichner
/// ändern, werden Verweise und Abhängigkeiten über die stabilen Zeilen-IDs
/// mitgeführt. Mit [store] und [draftKey] wird der Beweis samt Reihenfolge
/// gespeichert und beim nächsten Öffnen wiederhergestellt.
class ProofEditor extends StatefulWidget {
  final Theorem theorem;
  final String theoremText;
  final ProofSystem system;
  final List<ProofRow> solution;
  final String? plan;
  final ValueChanged<bool>? onFinished;
  final LogicProgressStore? store;
  final String? draftKey;

  const ProofEditor({
    super.key,
    required this.theorem,
    required this.theoremText,
    required this.system,
    required this.solution,
    this.plan,
    this.onFinished,
    this.store,
    this.draftKey,
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

  /// Hat man schon etwas geändert, bevor der gespeicherte Beweis geladen
  /// war, wird er nicht mehr darüber gelegt.
  bool _edited = false;
  bool _hadDraft = false;
  Timer? _saveTimer;

  bool get _persists => widget.store != null && widget.draftKey != null;

  @override
  void initState() {
    super.initState();
    _lines.add(_EditLine(ProofRule.assumption));
    _focused = _lines.first.formula;
    if (_persists) _loadDraft();
  }

  Future<void> _loadDraft() async {
    ProofDraft? draft;
    try {
      draft = (await widget.store!.load()).proof(widget.draftKey!);
    } catch (_) {
      return;
    }
    if (!mounted || draft == null || _edited) return;
    setState(() {
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..addAll(draft!.lines.map(_EditLine.from));
      _hadDraft = true;
      _focused = null;
      _result = null;
    });
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  /// Nach jeder Änderung: Prüfergebnis verwerfen, (verzögert) speichern.
  void _changed() {
    _result = null;
    _edited = true;
    if (!_persists) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (!_persists) return;
    final draft = ProofDraft(lines: [for (final l in _lines) l.toDraft()]);
    // Ein leerer Beweis wird nicht gespeichert (ein früherer entfernt).
    if (draft.isEmpty && !_hadDraft) return;
    try {
      await widget.store!.saveProof(widget.draftKey!, draft.isEmpty ? null : draft);
      _hadDraft = !draft.isEmpty;
    } catch (_) {
      // Speichern ist Komfort; der Beweis bleibt auf dem Bildschirm.
    }
  }

  /// Führt eine Änderung der Zeilenfolge aus und schreibt danach Verweise
  /// und Abhängigkeiten auf die neuen Bezeichner um.
  void _restructure(VoidCallback change) {
    final before = [for (final l in _lines) l.key];
    change();
    final after = [for (final l in _lines) l.key];
    final map = ProofLineOrder.relabel(before, after);
    if (ProofLineOrder.changes(map)) {
      for (final l in _lines) {
        final refs = ProofLineOrder.rewrite(l.refs.text, map);
        if (refs != l.refs.text) l.refs.text = refs;
        final deps = ProofLineOrder.rewrite(l.deps.text, map);
        if (deps != l.deps.text) l.deps.text = deps;
      }
    }
    _changed();
  }

  /// Neue Zeile am Ende oder (mit [at]) an der Position [at].
  void _addLine(ProofRule? rule, {int? at}) {
    _restructure(() {
      final line = _EditLine(rule);
      _lines.insert(at ?? _lines.length, line);
      _focused = line.formula;
    });
  }

  void _move(int from, int to) {
    if (from == to || to < 0 || to >= _lines.length) return;
    setState(
      () => _restructure(() {
        final moved = ProofLineOrder.moved(_lines, from, to);
        _lines
          ..clear()
          ..addAll(moved);
      }),
    );
  }

  void _remove(int index) {
    if (_lines.length <= 1) return;
    setState(
      () => _restructure(() {
        final line = _lines.removeAt(index);
        if (identical(_focused, line.formula) ||
            identical(_focused, line.refs) ||
            identical(_focused, line.deps) ||
            identical(_focused, line.comment)) {
          _focused = null;
        }
        // Erst nach dem Neuaufbau freigeben, das Textfeld hängt noch daran.
        WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
      }),
    );
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Beweis leeren?"),
        content: const Text("Alle Zeilen dieses Beweises werden entfernt."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            key: const ValueKey("proof-clear-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leeren"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      final old = [..._lines];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final l in old) {
          l.dispose();
        }
      });
      _lines
        ..clear()
        ..add(_EditLine(ProofRule.assumption));
      _focused = _lines.first.formula;
      _changed();
    });
  }

  List<String> get _labels => ProofLineOrder.labels(_lines.map((l) => l.isAssumption));

  void _check() {
    final labels = _labels;
    final inputs = [
      for (var i = 0; i < _lines.length; i++)
        ProofLineInput(
          label: labels[i],
          formula: _lines[i].formula.text,
          rule: _lines[i].rule,
          refs: _lines[i].isAssumption ? const [] : ProofLabels.parseList(_lines[i].refs.text),
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
        ReorderableListView.builder(
          key: const ValueKey("proof-lines"),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          // Beim Ziehen die Tastatur schließen; das fokussierte Textfeld
          // würde sonst mit in die gezogene Kopie wandern.
          onReorderStart: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          itemCount: _lines.length,
          onReorderItem: _move,
          proxyDecorator: (child, index, animation) => AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Material(
              elevation: 6 * animation.value,
              color: Colors.transparent,
              shadowColor: colors.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: child,
            ),
            child: child,
          ),
          itemBuilder: (context, i) =>
              _lineCard(context, i, labels[i], result?.lines.elementAtOrNull(i)),
        ),
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
            TextButton.icon(
              key: const ValueKey("proof-clear"),
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text("Leeren"),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            "Zeilen lassen sich am Griff ⠿ ziehen oder mit den Pfeilen "
            "verschieben; Verweise und Abhängigkeiten passen sich an.",
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        SymbolKeyboard(
          controller: _focused,
          predicateLogic: pl,
          extra: const ["α", "β", "γ", "δ", "ε", ","],
          onChanged: () => setState(_changed),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          key: const ValueKey("proof-check"),
          onPressed: _check,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text("Beweis prüfen"),
        ),
        if (result != null) ...[const SizedBox(height: 12), _summary(context, result)],
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
          Padding(padding: const EdgeInsets.only(top: 4), child: LogicText(widget.plan!)),
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

    final last = _lines.length - 1;

    return Card(
      key: ValueKey("proof-line-${line.id}"),
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
        padding: const EdgeInsets.fromLTRB(2, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _moveGutter(context, index, last),
            const SizedBox(width: 4),
            Expanded(
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
                            onChanged: (_) => setState(_changed),
                          ),
                        ),
                      ),
                      _lineMenu(context, index, last),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 300;
                      final rule = DropdownButton<ProofRule>(
                        isExpanded: narrow,
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
                          // Wird eine Zeile zur Annahme (oder umgekehrt), ändern
                          // sich Bezeichner; Verweise ziehen mit.
                          _restructure(() => line.rule = r);
                        }),
                      );
                      final refsField = Focus(
                        onFocusChange: (f) {
                          if (f) {
                            setState(() => _focused = line.isAssumption ? line.comment : line.refs);
                          }
                        },
                        child: TextField(
                          key: ValueKey("proof-refs-$index"),
                          controller: line.isAssumption ? line.comment : line.refs,
                          style: style.copyWith(fontSize: 14),
                          decoration: deco(
                            line.isAssumption ? "Kommentar, z. B. V" : "Zeilen, z. B. α, 1",
                          ),
                          onChanged: (_) => setState(_changed),
                        ),
                      );
                      final depsField = SizedBox(
                        width: 84,
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
                                  ? (result.dependencies.isEmpty
                                        ? "–"
                                        : result.dependencies.join(", "))
                                  : "Abh.",
                            ),
                            onChanged: (_) => setState(_changed),
                          ),
                        ),
                      );
                      // Schmale Bildschirme: Verweise in eigener Zeile.
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: rule),
                                const SizedBox(width: 8),
                                depsField,
                              ],
                            ),
                            const SizedBox(height: 6),
                            refsField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          const SizedBox(width: 18),
                          rule,
                          const SizedBox(width: 8),
                          Expanded(child: refsField),
                          const SizedBox(width: 8),
                          depsField,
                        ],
                      );
                    },
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
          ],
        ),
      ),
    );
  }

  /// Griff zum Ziehen und Pfeile zum Verschieben (auch ohne Drag-and-drop
  /// bedienbar, etwa mit Bildschirmleser oder wenn Ziehen unzuverlässig ist).
  Widget _moveGutter(BuildContext context, int index, int last) {
    final colors = context.colors;
    const size = BoxConstraints.tightFor(width: 34, height: 30);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey("proof-up-$index"),
          tooltip: "Nach oben",
          constraints: size,
          padding: EdgeInsets.zero,
          iconSize: 20,
          onPressed: index == 0 ? null : () => _move(index, index - 1),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        ReorderableDragStartListener(
          key: ValueKey("proof-handle-$index"),
          index: index,
          enabled: last > 0,
          child: MouseRegion(
            cursor: last > 0 ? SystemMouseCursors.grab : MouseCursor.defer,
            child: Tooltip(
              message: "Zum Verschieben ziehen",
              child: SizedBox.fromSize(
                size: const Size(34, 30),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 22,
                  color: last > 0 ? colors.textSecondary : colors.divider,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: ValueKey("proof-down-$index"),
          tooltip: "Nach unten",
          constraints: size,
          padding: EdgeInsets.zero,
          iconSize: 20,
          onPressed: index >= last ? null : () => _move(index, index + 1),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }

  Widget _lineMenu(BuildContext context, int index, int last) {
    return PopupMenuButton<String>(
      key: ValueKey("proof-menu-$index"),
      tooltip: "Weitere Aktionen",
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onSelected: (action) {
        switch (action) {
          case "assumption-above":
            setState(() => _addLine(ProofRule.assumption, at: index));
          case "line-above":
            setState(() => _addLine(null, at: index));
          case "assumption-below":
            setState(() => _addLine(ProofRule.assumption, at: index + 1));
          case "line-below":
            setState(() => _addLine(null, at: index + 1));
          case "top":
            _move(index, 0);
          case "bottom":
            _move(index, last);
          case "delete":
            _remove(index);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: "assumption-above", child: Text("Annahme darüber einfügen")),
        const PopupMenuItem(value: "line-above", child: Text("Zeile darüber einfügen")),
        const PopupMenuItem(value: "assumption-below", child: Text("Annahme darunter einfügen")),
        const PopupMenuItem(value: "line-below", child: Text("Zeile darunter einfügen")),
        const PopupMenuDivider(),
        PopupMenuItem(value: "top", enabled: index > 0, child: const Text("An den Anfang")),
        PopupMenuItem(value: "bottom", enabled: index < last, child: const Text("Ans Ende")),
        const PopupMenuDivider(),
        PopupMenuItem(value: "delete", enabled: last > 0, child: const Text("Zeile löschen")),
      ],
    );
  }
}
