import 'package:flutter/material.dart';

import '../../../models/philosophy/reading_text.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/hymn_score_view.dart' show scoreTextFont;

/// Schrift für polytonisches Griechisch (Tinos deckt „Greek Extended“ ab).
TextStyle greekStyle(BuildContext context, {double scale = 1, Color? color}) =>
    TextStyle(
      fontFamily: scoreTextFont,
      fontSize: 19 * scale,
      height: 1.55,
      color: color ?? context.colors.textPrimary,
    );

TextStyle germanStyle(BuildContext context, {double scale = 1, Color? color}) =>
    TextStyle(
      fontSize: 15.5 * scale,
      height: 1.5,
      color: color ?? context.colors.textPrimary,
    );

/// Kleine Stellenangabe am Rand eines Abschnitts.
class RefLabel extends StatelessWidget {
  final String text;

  const RefLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: context.colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Hinweis, dass Original und Übersetzung nur abschnittsweise
/// zugeordnet sind.
class ApproxHint extends StatelessWidget {
  final ReadingUnit unit;

  const ApproxHint(this.unit, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = unit.exact
        ? "Übersetzung gilt dem Abschnitt ${unit.range.label}"
        : "Zuordnung ungefähr (Abschnitt ${unit.range.label})";
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontStyle: FontStyle.italic,
        color: context.colors.textSecondary,
      ),
    );
  }
}

/// Eine Anmerkung der Ausgabe mit Art, Stelle und Seite.
class EditionNoteCard extends StatelessWidget {
  final EditionNote note;
  final void Function(String section)? onIntro;
  final void Function(BekkerRef ref)? onNoteRef;
  final VoidCallback? onJump;

  const EditionNoteCard(
    this.note, {
    super.key,
    this.onIntro,
    this.onNoteRef,
    this.onJump,
  });

  Color _color(BuildContext context) => switch (note.kind) {
    EditionNoteKind.textCritical => context.colors.accent,
    EditionNoteKind.editor => context.colors.primary,
    EditionNoteKind.translator => context.colors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final page = note.page == null ? "" : " · S. ${note.page}";
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(left: BorderSide(color: color, width: 3)),
        color: color.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${note.kind.label} ${note.refLabel}$page",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (!note.exact)
                Tooltip(
                  message: "Stelle aus der Seitenzählung erschlossen",
                  child: Text(
                    "Stelle ungefähr",
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              if (onJump != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: "Zur Stelle im Text",
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onPressed: onJump,
                ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(note.text, style: const TextStyle(height: 1.45)),
          if (note.introSections.isNotEmpty || note.noteRefs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final s in note.introSections)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.menu_book_outlined, size: 15),
                    label: Text("Einl. $s"),
                    onPressed: onIntro == null ? null : () => onIntro!(s),
                  ),
                for (final r in note.noteRefs)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.notes_outlined, size: 15),
                    label: Text("Anm. zu $r"),
                    onPressed: onNoteRef == null ? null : () => onNoteRef!(r),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Glossareintrag der Ausgabe.
class GlossaryCard extends StatelessWidget {
  final GlossaryEntry entry;
  final void Function(String section)? onIntro;
  final void Function(BekkerRef ref)? onNoteRef;

  const GlossaryCard(
    this.entry, {
    super.key,
    this.onIntro,
    this.onNoteRef,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: entry.term,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (entry.grammar != null) TextSpan(text: " (${entry.grammar})"),
                if (entry.technical)
                  TextSpan(
                    text: "  t. t.",
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (entry.renderings.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.renderings.join("; "),
              style: TextStyle(color: context.colors.primary),
            ),
          ],
          if (entry.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(entry.text, style: const TextStyle(height: 1.4)),
          ],
          if (entry.introSections.isNotEmpty || entry.noteRefs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in entry.introSections)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text("Einl. $s"),
                      onPressed: onIntro == null ? null : () => onIntro!(s),
                    ),
                  for (final r in entry.noteRefs)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text("Anm. zu $r"),
                      onPressed: onNoteRef == null ? null : () => onNoteRef!(r),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "Glossar der Ausgabe",
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Überschrift eines Abschnitts im Detail.
class DetailHeading extends StatelessWidget {
  final String text;

  const DetailHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: context.colors.textSecondary,
      ),
    ),
  );
}
