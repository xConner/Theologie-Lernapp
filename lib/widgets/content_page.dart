import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Seitenbausteine der Wissensbereiche (Kirchengeschichte, Altes Testament):
/// Seitengerüst mit begrenzter Breite, Überschriften, Kennzeichnungen,
/// Ergänzungskasten, Zitat und Leerzustand. Ohne Fachlogik, damit die
/// Bereiche gleich aussehen, ohne voneinander abzuhängen.

/// Seitengerüst mit begrenzter Breite (lesbar im Web, voll auf dem Handy).
class ContentPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ContentPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.floatingActionButton,
  });

  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: ContentBody(children: children)),
    );
  }
}

/// Scrollbarer Inhalt mit begrenzter Breite (auch innerhalb von Tabs).
class ContentBody extends StatelessWidget {
  final List<Widget> children;

  const ContentBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentPage.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class ContentSectionTitle extends StatelessWidget {
  final String text;

  const ContentSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Kleine Kennzeichnung (Typ, Herkunft, Genauigkeit).
class Tag extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const Tag(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          // Lange Kennzeichnungen brechen um, statt überzulaufen.
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kasten für Inhalte, die nicht aus der Vorlesung bzw. dem Material des
/// Proseminars stammen.
class SupplementBox extends StatelessWidget {
  final String text;
  final String label;

  const SupplementBox(
    this.text, {
    super.key,
    this.label = "Ergänzung – nicht von den Folien",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: context.colors.textSecondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }
}

/// Wortlaut der Vorlesung bzw. des Seminarmaterials mit Fundstelle.
class LectureQuote extends StatelessWidget {
  final String text;
  final String source;
  final VoidCallback? onTap;

  const LectureQuote({
    super.key,
    required this.text,
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border(
            left: BorderSide(color: context.colors.primary, width: 3),
          ),
          color: context.colors.primary.withValues(alpha: 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 14,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    source,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: context.colors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(text),
          ],
        ),
      ),
    );
  }
}

/// Leerer Zustand mit Erklärung.
class EmptyHint extends StatelessWidget {
  final String text;

  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textSecondary),
      ),
    );
  }
}
