import 'package:flutter/material.dart';

import '../../../quiz/books/book_learning_status.dart';
import '../../../theme/app_theme.dart';

/// Farbe einer Lernstufe; die Stufe steht immer zusätzlich als Text da.
Color levelColor(BuildContext context, LearningLevel level) {
  switch (level) {
    case LearningLevel.fresh:
      return context.colors.textSecondary;
    case LearningLevel.learning:
      return context.colors.primary;
    case LearningLevel.secure:
      return context.colors.success;
  }
}

IconData levelIcon(LearningLevel level) {
  switch (level) {
    case LearningLevel.fresh:
      return Icons.radio_button_unchecked;
    case LearningLevel.learning:
      return Icons.timelapse_rounded;
    case LearningLevel.secure:
      return Icons.check_circle_rounded;
  }
}

/// Kleine Beschriftung mit Rahmen, z. B. „Sicher gelernt“ oder „fällig“.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stufe und ggf. Fälligkeit einer Perikope.
class PericopeStatusPills extends StatelessWidget {
  final PericopeStatus status;
  final bool precise;

  const PericopeStatusPills({
    super.key,
    required this.status,
    this.precise = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        StatusPill(
          label: status.level.label,
          color: levelColor(context, status.level),
          icon: levelIcon(status.level),
        ),
        if (status.due)
          StatusPill(
            label: "Wiederholung fällig",
            color: context.colors.accent,
            icon: Icons.schedule_rounded,
          ),
        if (precise)
          StatusPill(
            label: "versgenau",
            color: context.colors.textPrimary,
            icon: Icons.straighten_rounded,
          ),
      ],
    );
  }
}

/// Gestapelter Balken: sicher | in Bearbeitung | neu.
class LearningProgressBar extends StatelessWidget {
  final LearningProgress progress;
  final double height;

  const LearningProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final total = progress.total;

    return Semantics(
      label:
          "${progress.secure} von $total sicher gelernt, "
          "${progress.learning} in Bearbeitung",
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: total == 0
              ? ColoredBox(color: context.colors.surfaceMuted)
              : Row(
                  children: [
                    if (progress.secure > 0)
                      Expanded(
                        flex: progress.secure,
                        child: ColoredBox(color: context.colors.success),
                      ),
                    if (progress.learning > 0)
                      Expanded(
                        flex: progress.learning,
                        child: ColoredBox(
                          color: context.colors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    if (progress.fresh > 0)
                      Expanded(
                        flex: progress.fresh,
                        child: ColoredBox(color: context.colors.surfaceMuted),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Zahlen eines Buchs oder Kapitels mit Balken.
class LearningProgressSummary extends StatelessWidget {
  final LearningProgress progress;

  const LearningProgressSummary({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    Widget figure(String label, int value, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$value",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 12,
          runSpacing: 8,
          children: [
            figure("Perikopen", progress.total, context.colors.textPrimary),
            figure("Sicher", progress.secure, context.colors.success),
            figure("In Bearbeitung", progress.learning, context.colors.primary),
            figure("Neu", progress.fresh, context.colors.textSecondary),
            figure("Fällig", progress.due, context.colors.accent),
          ],
        ),
        const SizedBox(height: 10),
        LearningProgressBar(progress: progress),
      ],
    );
  }
}

/// Erklärung der Statusregeln (siehe [BookLearningRules]).
Future<void> showStatusRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Wie der Lernstatus entsteht"),
      content: const SingleChildScrollView(
        child: Text(
          "Neu: noch nicht eingeführt und noch nie abgefragt.\n\n"
          "In Bearbeitung: eingeführt oder schon abgefragt, aber noch nicht "
          "zweimal mit zeitlichem Abstand richtig abgerufen.\n\n"
          "Sicher gelernt: zweimal in Folge richtig abgerufen, jeweils "
          "mindestens 12 Stunden nach der vorigen Abfrage. Eine richtige "
          "Antwort direkt nach dem Zeigen der Lösung zählt nicht. Ein Fehler "
          "setzt die Zählung zurück.\n\n"
          "Wiederholung fällig: der Wiederholungsabstand (wie im Endlos-Quiz "
          "berechnet) ist abgelaufen. Das gilt auch für sicher gelernte "
          "Perikopen.\n\n"
          "Lernstand aus dem Endlos-Quiz: Wer eine Perikope dort schon "
          "gelernt hat, beginnt nicht von vorn. Hat das Endlos-Quiz einen "
          "Wiederholungsabstand von mindestens 3 Tagen ermittelt, gilt sie "
          "als sicher gelernt. Das Endlos-Quiz selbst bleibt unverändert.\n\n"
          "Reihenfolge-Aufgaben werden getrennt gezählt und ändern den Status "
          "nicht.",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

/// Abschnittsüberschrift der Übersichten.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
