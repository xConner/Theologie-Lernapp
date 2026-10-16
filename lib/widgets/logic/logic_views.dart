import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/logic/lesson_text.dart';
import '../../services/logic/formula.dart';
import '../../services/logic/schema_formula.dart';
import '../../services/logic/semantics.dart';
import '../../theme/app_theme.dart';
import 'logic_text.dart';

/// Argument in Schreibweise mit Herleitungsstrich: Prämissen, Strich,
/// Konklusion, rechts der Name.
class RuleView extends StatelessWidget {
  final String name;
  final List<String> premises;
  final String conclusion;

  const RuleView({
    super.key,
    required this.name,
    required this.premises,
    required this.conclusion,
  });

  @override
  Widget build(BuildContext context) {
    final style = formulaStyle(context, fontSize: 15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: HorizontalOverflow(
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        premises.isEmpty ? " " : premises.join("      "),
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                    Container(height: 1.2, color: context.colors.textPrimary),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(conclusion, textAlign: TextAlign.center, style: style),
                    ),
                  ],
                ),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text("($name)", style: style.copyWith(fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Wahrheitstafel mit einer Spalte je zusammengesetztem Teilsatz. Mit
/// [stepwise] lässt sie sich Spalte für Spalte aufbauen.
class TruthTableView extends StatefulWidget {
  final String formula;
  final bool stepwise;

  const TruthTableView({super.key, required this.formula, this.stepwise = false});

  @override
  State<TruthTableView> createState() => _TruthTableViewState();
}

class _TruthTableViewState extends State<TruthTableView> {
  int? _shown;

  @override
  Widget build(BuildContext context) {
    final schema = SchemaFormula.parse(widget.formula);
    if (schema == null) return FormulaText(widget.formula);

    final table = TruthTable.of(schema.formula);
    final shown = widget.stepwise ? (_shown ?? 0) : table.columns.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TruthTableGrid(
          table: table,
          schema: schema,
          visibleColumns: shown,
        ),
        if (widget.stepwise && table.columns.length > 1)
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: shown < table.columns.length
                    ? () => setState(() => _shown = shown + 1)
                    : null,
                icon: const Icon(Icons.navigate_next_rounded),
                label: Text(
                  shown < table.columns.length
                      ? "Nächste Spalte: ${schema.show(table.columns[shown])}"
                      : "Tafel vollständig",
                ),
              ),
              if (shown > 0)
                TextButton(
                  onPressed: () => setState(() => _shown = 0),
                  child: const Text("Von vorn"),
                ),
            ],
          ),
      ],
    );
  }
}

/// Tabelle einer Wahrheitstafel. [cellBuilder] erlaubt eingabefähige
/// Zellen (Übungen); sonst werden die berechneten Werte gezeigt.
class TruthTableGrid extends StatelessWidget {
  final TruthTable table;
  final SchemaFormula? schema;
  final int? visibleColumns;
  final Widget Function(int row, int column)? cellBuilder;
  final Widget Function(int row)? rowTrailing;
  final String? trailingHeader;

  const TruthTableGrid({
    super.key,
    required this.table,
    this.schema,
    this.visibleColumns,
    this.cellBuilder,
    this.rowTrailing,
    this.trailingHeader,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = formulaStyle(context, fontSize: 14.5);
    final head = style.copyWith(fontWeight: FontWeight.w700);
    final visible = visibleColumns ?? table.columns.length;
    String show(Formula f) => schema?.show(f) ?? f.show();

    Widget cell(Widget child, {Color? background}) => Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      child: child,
    );

    final last = table.columns.length - 1;

    return HorizontalOverflow(
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: colors.divider),
          verticalInside: BorderSide(color: colors.divider),
          top: BorderSide(color: colors.divider),
          bottom: BorderSide(color: colors.divider),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(color: colors.surfaceMuted),
            children: [
              for (final l in table.letters) cell(Text(schema?.name(l) ?? l, style: head)),
              for (var c = 0; c < table.columns.length; c++)
                cell(
                  Text(show(table.columns[c]), style: head),
                  background: c == last ? colors.primary.withValues(alpha: 0.10) : null,
                ),
              if (rowTrailing != null) cell(Text(trailingHeader ?? "", style: head)),
            ],
          ),
          for (var r = 0; r < table.rows.length; r++)
            TableRow(
              children: [
                for (final l in table.letters)
                  cell(Text(table.rows[r][l]! ? "1" : "0", style: style)),
                for (var c = 0; c < table.columns.length; c++)
                  cell(
                    cellBuilder != null
                        ? cellBuilder!(r, c)
                        : Text(
                            c < visible ? (table.values[r][c] ? "1" : "0") : "",
                            style: c == last ? head : style,
                          ),
                    background: c == last ? colors.primary.withValues(alpha: 0.06) : null,
                  ),
                if (rowTrailing != null) cell(rowTrailing!(r)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Syntaxbaum: Wurzel oben, Blätter unten.
class SyntaxTreeView extends StatelessWidget {
  final Formula formula;

  /// Satztypen statt Operatoren an den Knoten.
  final bool names;

  const SyntaxTreeView({super.key, required this.formula, this.names = false});

  String _label(Formula f) {
    switch (f) {
      case Letter(name: final n):
        return n;
      case Predication():
        return f.show();
      case Negation():
        return names ? "Negation" : "¬";
      case Binary(op: final op):
        return names ? op.sentenceName : op.symbol;
      case Quantified(quantifier: final q, variable: final v):
        return names ? "${q.title} $v" : "${q.symbol}$v";
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = <_TreeNode>[];
    var leafIndex = 0;
    final spacing = names ? 104.0 : 46.0;
    const levelHeight = 52.0;

    _TreeNode layout(Formula f, int depth) {
      final children = [for (final c in f.children) layout(c, depth + 1)];
      final x = children.isEmpty
          ? (leafIndex++) * spacing + spacing / 2
          : children.map((c) => c.x).reduce((a, b) => a + b) / children.length;
      final node = _TreeNode(_label(f), x, depth * levelHeight + 16, children);
      nodes.add(node);
      return node;
    }

    layout(formula, 0);
    final width = max(leafIndex * spacing, spacing);
    final height = (formula.depth + 1) * levelHeight;
    final style = formulaStyle(context, fontSize: names ? 13 : 16);

    return HorizontalOverflow(
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _TreePainter(nodes, context.colors.textSecondary),
            child: Stack(
              children: [
                for (final n in nodes)
                  Positioned(
                    left: n.x - spacing / 2,
                    top: n.y - 12,
                    width: spacing,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Text(n.label, style: style, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeNode {
  final String label;
  final double x;
  final double y;
  final List<_TreeNode> children;

  _TreeNode(this.label, this.x, this.y, this.children);
}

class _TreePainter extends CustomPainter {
  final List<_TreeNode> nodes;
  final Color color;

  _TreePainter(this.nodes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (final n in nodes) {
      for (final c in n.children) {
        canvas.drawLine(Offset(n.x, n.y + 12), Offset(c.x, c.y - 12), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) => old.nodes != nodes;
}

/// Beweis als Tabelle: Bezeichner | Satz | Argument | Abhängigkeiten.
class ProofTableView extends StatelessWidget {
  final String? theorem;
  final List<ProofRow> rows;

  /// Zeilen mit Fehler (Index → Hinweis), z. B. aus der Prüfung.
  final Map<int, String> errors;

  const ProofTableView({
    super.key,
    this.theorem,
    required this.rows,
    this.errors = const {},
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = formulaStyle(context, fontSize: 14.5);
    final small = style.copyWith(fontSize: 13.5, color: colors.textSecondary);

    Widget cell(String text, TextStyle s) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(text, style: s),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (theorem != null && theorem!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FormulaText(theorem!, weight: FontWeight.w600),
          ),
        HorizontalOverflow(
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration: errors.containsKey(i)
                      ? BoxDecoration(color: colors.errorBackground)
                      : null,
                  children: [
                    cell(rows[i].label, style),
                    cell(rows[i].formula, style),
                    cell(rows[i].justification, small),
                    cell(rows[i].dependencies, small),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
