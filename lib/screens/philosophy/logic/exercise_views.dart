import 'package:flutter/material.dart';

import '../../../models/logic/logic_exercise.dart';
import '../../../services/logic/exercise_evaluation.dart';
import '../../../services/logic/formula.dart';
import '../../../services/logic/formula_parser.dart';
import '../../../services/logic/logic_progress_store.dart';
import '../../../services/logic/proof_checker.dart';
import '../../../services/logic/proof_rules.dart';
import '../../../services/logic/semantics.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/logic/logic_text.dart';
import '../../../widgets/logic/logic_views.dart';
import '../../../widgets/logic/symbol_keyboard.dart';
import 'proof_editor.dart';

/// Eine Übung samt Eingabe, Prüfung und Rückmeldung. [onResult] wird je
/// Übung höchstens einmal aufgerufen (erste abschließende Antwort).
class LogicExerciseView extends StatelessWidget {
  final LogicExercise exercise;
  final ValueChanged<bool> onResult;

  /// Speichert angefangene Beweise (samt Reihenfolge der Zeilen); ohne
  /// Speicher bleiben sie nur auf dem Bildschirm.
  final LogicProgressStore? store;

  const LogicExerciseView({
    super.key,
    required this.exercise,
    required this.onResult,
    this.store,
  });

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final body = switch (e) {
      WellFormedExercise() => _WellFormedView(e, onResult),
      TruthTableExercise() => _TruthTableView(e, onResult),
      EvaluateExercise() => _EvaluateView(e, onResult),
      EntailmentExercise() => _EntailmentView(e, onResult),
      FindPremisesExercise() => _FindPremisesView(e, onResult),
      ProofExercise() => _ProofView(e, onResult, store),
      ChoiceExercise() => _ChoiceView(e, onResult),
      OpenExercise() => _OpenView(e, onResult),
      FormalizeExercise() => _FormalizeView(e, onResult),
      FreeVariablesExercise() => _FreeVariablesView(e, onResult),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _OriginPill(origin: e.origin),
            if (e.group.isNotEmpty)
              Text(
                e.group,
                style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (e.note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LogicText(e.note!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        body,
      ],
    );
  }
}

class _OriginPill extends StatelessWidget {
  final ExerciseOrigin origin;

  const _OriginPill({required this.origin});

  @override
  Widget build(BuildContext context) {
    final color = switch (origin) {
      ExerciseOrigin.course => context.colors.primary,
      ExerciseOrigin.extra => context.colors.accent,
      ExerciseOrigin.generated => context.colors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        origin.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Rückmeldung nach einer Antwort.
class OutcomePanel extends StatelessWidget {
  final ExerciseOutcome outcome;

  const OutcomePanel({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final neutral = outcome.invalidInput;
    final color = neutral
        ? colors.textSecondary
        : (outcome.correct ? colors.success : colors.error);
    final background = neutral
        ? colors.surfaceMuted
        : (outcome.correct ? colors.successBackground : colors.errorBackground);

    return Container(
      key: const ValueKey("logic-outcome"),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                neutral
                    ? Icons.edit_outlined
                    : (outcome.correct ? Icons.check_circle_rounded : Icons.cancel_rounded),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LogicText(
                  outcome.headline,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15.5),
                ),
              ),
            ],
          ),
          for (final d in outcome.details)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FormulaText(d, fontSize: 14.5),
            ),
        ],
      ),
    );
  }
}

mixin _Reporting<T extends StatefulWidget> on State<T> {
  bool _reported = false;

  void report(ValueChanged<bool> onResult, bool correct) {
    if (_reported) return;
    _reported = true;
    onResult(correct);
  }
}

Widget _question(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: LogicText(text, style: Theme.of(context).textTheme.titleMedium),
);

Widget _formula(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: HorizontalOverflow(child: Center(child: FormulaText(text, fontSize: 19))),
);

// ---------------------------------------------------------------- Satz?

class _WellFormedView extends StatefulWidget {
  final WellFormedExercise e;
  final ValueChanged<bool> onResult;

  const _WellFormedView(this.e, this.onResult);

  @override
  State<_WellFormedView> createState() => _WellFormedViewState();
}

class _WellFormedViewState extends State<_WellFormedView> with _Reporting {
  ExerciseOutcome? _outcome;

  LogicLanguage get _lang =>
      widget.e.predicateLogic ? LogicLanguage.predicate : LogicLanguage.propositional;

  void _answer(bool sentence) {
    final o = ExerciseEvaluation.wellFormed(widget.e.expression, sentence, language: _lang);
    setState(() => _outcome = o);
    report(widget.onResult, o.correct);
  }

  @override
  Widget build(BuildContext context) {
    final o = _outcome;
    final parsed = FormulaParser.parse(widget.e.expression, language: _lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(
          context,
          widget.e.predicateLogic
              ? "Ist dieser Ausdruck ein Satz in PL (Definition 7.4, Klammerersparnisregel)?"
              : "Ist dieser Ausdruck ein Satz in AL (Definition 1.2, Klammerersparnisregel)?",
        ),
        _formula(widget.e.expression),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const ValueKey("answer-sentence"),
                onPressed: o == null ? () => _answer(true) : null,
                child: const Text("Satz"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const ValueKey("answer-no-sentence"),
                onPressed: o == null ? () => _answer(false) : null,
                child: const Text("Kein Satz"),
              ),
            ),
          ],
        ),
        if (o != null) ...[
          OutcomePanel(outcome: o),
          if (parsed.ok) ...[
            const SizedBox(height: 10),
            Text("Syntaxbaum", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SyntaxTreeView(formula: parsed.formula!),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Wahrheitstafel

class _TruthTableView extends StatefulWidget {
  final TruthTableExercise e;
  final ValueChanged<bool> onResult;

  const _TruthTableView(this.e, this.onResult);

  @override
  State<_TruthTableView> createState() => _TruthTableViewState();
}

class _TruthTableViewState extends State<_TruthTableView> with _Reporting {
  late final TruthTable table = TruthTable.of(parseFormula(widget.e.formula));
  late final List<List<bool?>> cells = [
    for (final _ in table.rows) List<bool?>.filled(table.columns.length, null),
  ];
  Classification? classification;
  final Set<int> models = {};
  TruthTableCheck? check;

  void _evaluate() {
    final c = ExerciseEvaluation.truthTable(
      table,
      cells,
      classification: widget.e.classify ? classification : null,
      models: widget.e.models ? models : null,
    );
    setState(() => check = c);
    if (c.complete && (classification != null || !widget.e.classify)) {
      report(widget.onResult, c.correct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = check;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Stelle die Wahrheitstafel auf. Tippe auf ein Feld: leer → 1 → 0."),
        _formula(widget.e.formula),
        TruthTableGrid(
          table: table,
          trailingHeader: widget.e.models ? "Modell?" : null,
          rowTrailing: widget.e.models
              ? (r) => Checkbox(
                  value: models.contains(r),
                  onChanged: (v) => setState(() {
                    v == true ? models.add(r) : models.remove(r);
                    check = null;
                  }),
                )
              : null,
          cellBuilder: (r, col) {
            final v = cells[r][col];
            final wrong = c?.wrongCells.contains((r, col)) ?? false;
            return InkWell(
              key: ValueKey("tt-$r-$col"),
              onTap: () => setState(() {
                cells[r][col] = v == null ? true : (v ? false : null);
                check = null;
              }),
              child: Container(
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: wrong ? colors.error : colors.divider),
                  borderRadius: BorderRadius.circular(6),
                  color: wrong ? colors.errorBackground : null,
                ),
                child: Text(
                  v == null ? "" : (v ? "1" : "0"),
                  style: formulaStyle(context, fontSize: 15, weight: FontWeight.w600),
                ),
              ),
            );
          },
        ),
        if (widget.e.classify) ...[
          const SizedBox(height: 12),
          Text("Der Satz ist …", style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<Classification>(
            groupValue: classification,
            onChanged: (v) => setState(() {
              classification = v;
              check = null;
            }),
            child: Column(
              children: [
                for (final k in Classification.values)
                  RadioListTile<Classification>(
                    value: k,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(k.label),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        ElevatedButton(
          key: const ValueKey("tt-check"),
          onPressed: _evaluate,
          child: const Text("Prüfen"),
        ),
        if (c != null)
          OutcomePanel(
            outcome: ExerciseOutcome(
              correct: c.correct,
              invalidInput: !c.complete,
              headline: !c.complete
                  ? "Es sind noch ${c.emptyCells} Felder leer."
                  : c.correct
                  ? "Alles richtig."
                  : c.wrongCells.isEmpty
                  ? "Die Tafel stimmt – aber nicht alles andere."
                  : "${c.wrongCells.length} Feld(er) falsch (rot markiert).",
              details: [
                ...c.details,
                if (widget.e.classify && classification == null) "Wähle noch eine Einordnung.",
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Wahrheitswert

class _EvaluateView extends StatefulWidget {
  final EvaluateExercise e;
  final ValueChanged<bool> onResult;

  const _EvaluateView(this.e, this.onResult);

  @override
  State<_EvaluateView> createState() => _EvaluateViewState();
}

class _EvaluateViewState extends State<_EvaluateView> with _Reporting {
  ExerciseOutcome? _outcome;

  @override
  Widget build(BuildContext context) {
    final f = parseFormula(widget.e.formula);
    final letters = LogicSemantics.lettersOf([f]);
    final o = _outcome;

    void answer(bool v) {
      final r = ExerciseEvaluation.evaluate(f, widget.e.interpretation, v);
      setState(() => _outcome = r);
      report(widget.onResult, r.correct);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Welchen Wahrheitswert hat der Satz unter der Interpretation V?"),
        _formula(widget.e.formula),
        Center(
          child: FormulaText(
            letters.map((l) => "V($l) = ${widget.e.interpretation[l]! ? 1 : 0}").join(",  "),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const ValueKey("answer-true"),
                onPressed: o == null ? () => answer(true) : null,
                child: const Text("wahr (1)"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const ValueKey("answer-false"),
                onPressed: o == null ? () => answer(false) : null,
                child: const Text("falsch (0)"),
              ),
            ),
          ],
        ),
        if (o != null) OutcomePanel(outcome: o),
      ],
    );
  }
}

// ---------------------------------------------------------------- Folgerung

class _EntailmentView extends StatefulWidget {
  final EntailmentExercise e;
  final ValueChanged<bool> onResult;

  const _EntailmentView(this.e, this.onResult);

  @override
  State<_EntailmentView> createState() => _EntailmentViewState();
}

class _EntailmentViewState extends State<_EntailmentView> with _Reporting {
  late final Theorem theorem = Theorem.parse(widget.e.theorem);
  bool? _valid;
  int? _row;
  ExerciseOutcome? _outcome;

  List<String> get _letters => LogicSemantics.lettersOf([...theorem.premises, theorem.thesis]);

  void _submit() {
    final rows = LogicSemantics.interpretations(_letters);
    final o = ExerciseEvaluation.entailment(
      theorem.premises,
      theorem.thesis,
      _valid!,
      counterexample: _row == null ? null : rows[_row!],
    );
    setState(() => _outcome = o);
    final needsCounter = _valid == false &&
        LogicSemantics.counterexamples(theorem.premises, theorem.thesis).isNotEmpty;
    if (!needsCounter || _row != null) report(widget.onResult, o.correct);
  }

  @override
  Widget build(BuildContext context) {
    final rows = LogicSemantics.interpretations(_letters);
    final o = _outcome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Ist das Theorem gültig? Falls nicht: Wähle ein Gegenbeispiel."),
        _formula(widget.e.theorem),
        RadioGroup<bool>(
          groupValue: _valid,
          onChanged: (v) => setState(() {
            _valid = v;
            _outcome = null;
          }),
          child: const Row(
            children: [
              Expanded(child: RadioListTile<bool>(value: true, title: Text("gültig"), contentPadding: EdgeInsets.zero)),
              Expanded(child: RadioListTile<bool>(value: false, title: Text("nicht gültig"), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ),
        if (_valid == false) ...[
          Text("Gegenbeispiel (Interpretation):", style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<int>(
            groupValue: _row,
            onChanged: (v) => setState(() {
              _row = v;
              _outcome = null;
            }),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  RadioListTile<int>(
                    value: i,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: FormulaText(LogicSemantics.formatInterpretation(rows[i], _letters)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        ElevatedButton(
          key: const ValueKey("entailment-check"),
          onPressed: _valid == null ? null : _submit,
          child: const Text("Prüfen"),
        ),
        if (o != null) ...[
          OutcomePanel(outcome: o),
          if (o.correct && widget.e.argument != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LogicText("**Alltagssprachliche Begründung:** ${widget.e.argument!}"),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Formeleingabe

class _FormulaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFocus;

  const _FormulaField({
    required this.controller,
    required this.label,
    this.onChanged,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) {
        if (f) onFocus?.call();
      },
      child: TextField(
        controller: controller,
        style: formulaStyle(context, fontSize: 17),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }
}

class _FindPremisesView extends StatefulWidget {
  final FindPremisesExercise e;
  final ValueChanged<bool> onResult;

  const _FindPremisesView(this.e, this.onResult);

  @override
  State<_FindPremisesView> createState() => _FindPremisesViewState();
}

class _FindPremisesViewState extends State<_FindPremisesView> with _Reporting {
  late final List<TextEditingController> fields = [
    for (var i = 0; i < widget.e.count; i++) TextEditingController(),
  ];
  late TextEditingController focused = fields.first;
  ExerciseOutcome? _outcome;
  bool _sample = false;

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _check() {
    final o = ExerciseEvaluation.findPremises(
      [for (final f in fields) f.text],
      parseFormula(widget.e.thesis),
    );
    setState(() => _outcome = o);
    if (!o.invalidInput) report(widget.onResult, o.correct && !_sample);
  }

  @override
  Widget build(BuildContext context) {
    final o = _outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Setze aussagenlogische Sätze ein, sodass ein gültiges Theorem entsteht."),
        _formula(widget.e.summary),
        for (var i = 0; i < fields.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FormulaField(
              controller: fields[i],
              label: "P${i + 1}",
              onFocus: () => setState(() => focused = fields[i]),
              onChanged: (_) => setState(() => _outcome = null),
            ),
          ),
        SymbolKeyboard(controller: focused, extra: const ["p", "q", "r", "s"]),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _check, child: const Text("Prüfen")),
        if (o != null) OutcomePanel(outcome: o),
        TextButton(
          onPressed: () {
            setState(() => _sample = true);
            report(widget.onResult, false);
          },
          child: const Text("Mögliche Lösung zeigen"),
        ),
        if (_sample)
          FormulaText("${widget.e.sample.join(", ")} ⊢ ${widget.e.thesis}"),
      ],
    );
  }
}

class _FormalizeView extends StatefulWidget {
  final FormalizeExercise e;
  final ValueChanged<bool> onResult;

  const _FormalizeView(this.e, this.onResult);

  @override
  State<_FormalizeView> createState() => _FormalizeViewState();
}

class _FormalizeViewState extends State<_FormalizeView> with _Reporting {
  final TextEditingController controller = TextEditingController();
  ExerciseOutcome? _outcome;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = _outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Formalisiere den Satz aussagenlogisch."),
        LogicText("»${widget.e.sentence}«", style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        for (final k in widget.e.key.entries)
          FormulaText("${k.key}: ${k.value}", fontSize: 14.5),
        const SizedBox(height: 10),
        _FormulaField(controller: controller, label: "Formalisierung", onChanged: (_) => setState(() => _outcome = null)),
        const SizedBox(height: 8),
        SymbolKeyboard(controller: controller, extra: widget.e.key.keys.toList()),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            final r = ExerciseEvaluation.formalize(controller.text, parseFormula(widget.e.expected));
            setState(() => _outcome = r);
            if (!r.invalidInput) report(widget.onResult, r.correct);
          },
          child: const Text("Prüfen"),
        ),
        if (o != null) ...[
          OutcomePanel(outcome: o),
          if (widget.e.explanation != null && !o.invalidInput)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LogicText(widget.e.explanation!),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Beweis

class _ProofView extends StatelessWidget {
  final ProofExercise e;
  final ValueChanged<bool> onResult;
  final LogicProgressStore? store;

  const _ProofView(this.e, this.onResult, this.store);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Beweise das Theorem."),
        _formula(e.theorem),
        ProofEditor(
          theorem: Theorem.parse(e.theorem),
          theoremText: e.theorem,
          system: ProofSystem.byId(e.system),
          solution: e.solution,
          plan: e.plan,
          onFinished: onResult,
          store: store,
          // Erzeugte Übungen (ohne ID) werden nicht gespeichert.
          draftKey: e.id,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Auswahl

class _ChoiceView extends StatefulWidget {
  final ChoiceExercise e;
  final ValueChanged<bool> onResult;

  const _ChoiceView(this.e, this.onResult);

  @override
  State<_ChoiceView> createState() => _ChoiceViewState();
}

class _ChoiceViewState extends State<_ChoiceView> with _Reporting {
  final Set<int> selected = {};
  bool _done = false;

  bool get _correct {
    for (var i = 0; i < widget.e.options.length; i++) {
      if (widget.e.options[i].correct != selected.contains(i)) return false;
    }
    return true;
  }

  void _submit() {
    setState(() => _done = true);
    report(widget.onResult, _correct);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final colors = context.colors;
    final tree = e.tree == null
        ? null
        : FormulaParser.parse(e.tree!, language: FormulaParser.guessLanguage(e.tree!)).formula;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, e.question),
        if (e.multiple)
          Text("Mehrere Antworten können richtig sein.", style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
        for (var i = 0; i < e.options.length; i++)
          Card(
            key: ValueKey("choice-$i"),
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              side: BorderSide(
                color: !_done
                    ? (selected.contains(i) ? colors.primary : colors.divider)
                    : (e.options[i].correct
                          ? colors.success
                          : (selected.contains(i) ? colors.error : colors.divider)),
                width: selected.contains(i) || (_done && e.options[i].correct) ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: _done
                  ? null
                  : () => setState(() {
                      if (e.multiple) {
                        selected.contains(i) ? selected.remove(i) : selected.add(i);
                      } else {
                        selected
                          ..clear()
                          ..add(i);
                      }
                    }),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LogicText(e.options[i].text),
                    if (_done && e.options[i].feedback != null && (selected.contains(i) || e.options[i].correct))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LogicText(
                          e.options[i].feedback!,
                          style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        ElevatedButton(
          key: const ValueKey("choice-check"),
          onPressed: selected.isEmpty || _done ? null : _submit,
          child: const Text("Prüfen"),
        ),
        if (_done) ...[
          OutcomePanel(
            outcome: ExerciseOutcome(
              correct: _correct,
              headline: _correct ? "Richtig." : "Nicht ganz – die richtige Antwort ist grün markiert.",
              details: [if (e.explanation != null) e.explanation!],
            ),
          ),
          if (tree != null) ...[
            const SizedBox(height: 8),
            SyntaxTreeView(formula: tree),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Offen

class _OpenView extends StatefulWidget {
  final OpenExercise e;
  final ValueChanged<bool> onResult;

  const _OpenView(this.e, this.onResult);

  @override
  State<_OpenView> createState() => _OpenViewState();
}

class _OpenViewState extends State<_OpenView> with _Reporting {
  final TextEditingController controller = TextEditingController();
  bool _shown = false;
  bool? _self;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, widget.e.question),
        Text(
          "Offene Aufgabe: Deine Antwort wird nicht automatisch bewertet. "
          "Vergleiche sie mit der Musterantwort und schätze dich selbst ein.",
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(hintText: "Deine Antwort (wird nicht gespeichert)"),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _shown ? null : () => setState(() => _shown = true),
          child: const Text("Musterantwort zeigen"),
        ),
        if (_shown) ...[
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: LogicText(widget.e.sample),
          ),
          const SizedBox(height: 10),
          Text("Selbsteinschätzung", style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _self != null
                      ? null
                      : () {
                          setState(() => _self = true);
                          report(widget.onResult, true);
                        },
                  child: const Text("Im Wesentlichen getroffen"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _self != null
                      ? null
                      : () {
                          setState(() => _self = false);
                          report(widget.onResult, false);
                        },
                  child: const Text("Noch unsicher"),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- PL: freie Variablen

class _FreeVariablesView extends StatefulWidget {
  final FreeVariablesExercise e;
  final ValueChanged<bool> onResult;

  const _FreeVariablesView(this.e, this.onResult);

  @override
  State<_FreeVariablesView> createState() => _FreeVariablesViewState();
}

class _FreeVariablesViewState extends State<_FreeVariablesView> with _Reporting {
  final Set<String> free = {};
  ExerciseOutcome? _outcome;

  @override
  Widget build(BuildContext context) {
    final parsed = FormulaParser.parse(widget.e.expression, language: LogicLanguage.predicate);
    final variables = LogicAlphabet.variables
        .split("")
        .where(FormulaParser.normalize(widget.e.expression).contains)
        .toList();
    final o = _outcome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _question(context, "Satz oder Satzfunktion? Markiere alle Variablen, die frei vorkommen."),
        _formula(widget.e.expression),
        Wrap(
          spacing: 8,
          children: [
            for (final v in variables)
              FilterChip(
                label: FormulaText(v),
                selected: free.contains(v),
                onSelected: o != null
                    ? null
                    : (s) => setState(() => s ? free.add(v) : free.remove(v)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Keine Variable markiert = alle gebunden (Satz).",
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: o != null
              ? null
              : () {
                  final r = ExerciseEvaluation.freeVariables(widget.e.expression, free.isEmpty, free);
                  setState(() => _outcome = r);
                  report(widget.onResult, r.correct);
                },
          child: Text(free.isEmpty ? "Prüfen: Satz" : "Prüfen: Satzfunktion"),
        ),
        if (o != null) ...[
          OutcomePanel(outcome: o),
          if (parsed.ok) ...[
            const SizedBox(height: 8),
            SyntaxTreeView(formula: parsed.formula!),
          ],
        ],
      ],
    );
  }
}
