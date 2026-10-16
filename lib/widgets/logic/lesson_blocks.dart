import 'package:flutter/material.dart';

import '../../models/logic/lesson_text.dart';
import '../../services/logic/formula_parser.dart';
import '../../theme/app_theme.dart';
import 'logic_text.dart';
import 'logic_views.dart';

/// Stellt die Blöcke eines Lehrtext-Abschnitts dar.
class LessonBlocksView extends StatelessWidget {
  final List<LessonBlock> blocks;

  const LessonBlocksView({super.key, required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _block(context, b),
          ),
      ],
    );
  }

  Widget _block(BuildContext context, LessonBlock block) {
    final body = Theme.of(context).textTheme.bodyLarge!;

    switch (block) {
      case ParagraphBlock(text: final t):
        return LogicText(t, style: body);

      case SubheadingBlock(text: final t):
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(t, style: Theme.of(context).textTheme.titleMedium),
        );

      case ListBlock(items: final items, ordered: final ordered):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: ordered ? 26 : 18,
                      child: Text(ordered ? "${i + 1}." : "•", style: body),
                    ),
                    Expanded(child: LogicText(items[i], style: body)),
                  ],
                ),
              ),
          ],
        );

      case BoxBlock(kind: final kind, title: final title, children: final children):
        return LessonBox(kind: kind, title: title, children: children);

      case FormulaBlock(formula: final f):
        return HorizontalOverflow(
          child: Center(child: FormulaText(f, fontSize: 17)),
        );

      case DisplayTextBlock(text: final t):
        return HorizontalOverflow(
          child: Center(child: FormulaText(t, fontSize: 16)),
        );

      case TruthTableBlock(formula: final f):
        return Align(
          alignment: Alignment.centerLeft,
          child: TruthTableView(formula: f, stepwise: _isStepwise(f)),
        );

      case TreeBlock(formula: final f, names: final names):
        final parsed = FormulaParser.parse(
          f,
          language: FormulaParser.guessLanguage(f),
        ).formula;
        if (parsed == null) return FormulaText(f);
        return SyntaxTreeView(formula: parsed, names: names);

      case RuleBlock(name: final n, premises: final p, conclusion: final c):
        return RuleView(name: n, premises: p, conclusion: c);

      case ProofBlock(theorem: final t, rows: final rows, complete: final complete):
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.divider),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProofTableView(theorem: t, rows: rows),
              if (!complete)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Ausschnitt bzw. unvollständiger Beweis",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
    }
  }

  /// Längere Tafeln lassen sich Spalte für Spalte aufbauen.
  static bool _isStepwise(String formula) {
    final f = FormulaParser.parse(formula).formula;
    return f != null && f.size >= 4;
  }
}

/// Kasten für Definitionen, Konventionen, Sätze, Argumente, Hinweise,
/// Beispiele und ergänzende Erläuterungen.
class LessonBox extends StatelessWidget {
  final BoxKind kind;
  final String title;
  final List<LessonBlock> children;

  const LessonBox({
    super.key,
    required this.kind,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (Color accent, Color background, IconData icon) = switch (kind) {
      BoxKind.definition ||
      BoxKind.convention ||
      BoxKind.theorem ||
      BoxKind.rules => (colors.primary, colors.primary.withValues(alpha: 0.05), Icons.bookmark_outline_rounded),
      BoxKind.warning => (colors.error, colors.errorBackground, Icons.priority_high_rounded),
      BoxKind.explanation => (colors.accent, colors.accent.withValues(alpha: 0.08), Icons.lightbulb_outline_rounded),
      BoxKind.example => (colors.textSecondary, colors.surfaceMuted, Icons.edit_note_rounded),
      BoxKind.note => (colors.textSecondary, colors.surfaceMuted, Icons.info_outline_rounded),
    };

    final label = kind == BoxKind.explanation
        ? "Erläuterung (ergänzend)"
        : (title.isEmpty ? kind.label : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (label != null)
                        TextSpan(
                          text: label + (kind == BoxKind.explanation && title.isNotEmpty ? ": " : ""),
                          style: TextStyle(color: accent),
                        ),
                      if (title.isNotEmpty && (label == null || kind == BoxKind.explanation))
                        TextSpan(text: title),
                    ],
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LessonBlocksView(blocks: children),
        ],
      ),
    );
  }
}
