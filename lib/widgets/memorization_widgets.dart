import 'package:flutter/material.dart';

import '../models/memorization/memorization_card.dart';
import '../models/memorization/memorization_text.dart';
import '../screens/memorization/memorization_text_screen.dart';
import '../services/memorization/hint_generator.dart';
import '../services/memorization/memorization_scheduler.dart';
import '../services/memorization/text_evaluator.dart';
import '../theme/app_theme.dart';

/// Einstieg in „Texte auswendig lernen“ aus einer bestehenden Detailansicht
/// (Gebet, Bekenntnis). Die Schaltfläche bezieht sich auf den einen
/// angezeigten Text und heißt deshalb nur „Auswendig lernen“. Öffnet den
/// Text in der gewählten Sprache als Lerntext; die Detailansicht selbst
/// bleibt unverändert.
class MemorizeButton extends StatelessWidget {
  /// Wird erst beim Antippen gebildet (Zerlegung in Abschnitte).
  final MemorizationWork Function() work;

  final String languageCode;

  const MemorizeButton({
    super.key,
    required this.work,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.psychology_alt_rounded),
      label: const Text("Auswendig lernen"),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemorizationTextScreen(
              work: work(),
              languageCode: languageCode,
            ),
          ),
        );
      },
    );
  }
}

/// Symbol für den Lernstand eines Abschnitts (mit Beschriftung für
/// Screenreader).
class SegmentStatusIcon extends StatelessWidget {
  final SegmentStatus status;

  const SegmentStatusIcon(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      SegmentStatus.fresh => (
        Icons.radio_button_unchecked_rounded,
        context.colors.textSecondary,
      ),
      SegmentStatus.learning => (
        Icons.timelapse_rounded,
        context.colors.primary,
      ),
      SegmentStatus.shaky => (
        Icons.error_outline_rounded,
        context.colors.accent,
      ),
      SegmentStatus.recent => (
        Icons.check_circle_outline_rounded,
        context.colors.success,
      ),
      SegmentStatus.stable => (
        Icons.check_circle_rounded,
        context.colors.success,
      ),
      SegmentStatus.secure => (Icons.verified_rounded, context.colors.success),
    };

    return Icon(icon, color: color, size: 22, semanticLabel: status.label);
  }
}

/// Lernstand eines Abschnitts in einer Zeile: die Stufe und was als
/// Nächstes ansteht („Unsicher · noch 2× fehlerfrei aufsagen“,
/// „Frisch gelernt · Wiederholung morgen“).
String segmentStatusLine(
  MemorizationScheduler scheduler,
  MemorizationCard? card,
) {
  final status = scheduler.status(card);

  switch (status) {
    case SegmentStatus.fresh:
    case SegmentStatus.learning:
      return status.label;

    case SegmentStatus.shaky:
      if (card!.level < MemorizationCard.maxLevel) {
        return "${status.label} · erst mit Hilfe, dann frei aufsagen";
      }

      return "${status.label} · noch ${card.relearn}× fehlerfrei aufsagen";

    case SegmentStatus.recent:
    case SegmentStatus.stable:
    case SegmentStatus.secure:
      final due = scheduler.dueAt(card!);

      if (due == null) return status.label;

      return "${status.label} · Wiederholung "
          "${relativeDue(due, scheduler.clock())}";
  }
}

/// „heute“, „morgen“, „in 4 Tagen“ – bezogen auf Kalendertage.
String relativeDue(DateTime date, DateTime now) {
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  if (days <= 0) return "heute";
  if (days == 1) return "morgen";

  return "in $days Tagen";
}

/// „heute“, „gestern“, „vor 4 Tagen“ – bezogen auf Kalendertage.
String relativeDay(DateTime date, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;

  if (days <= 0) return "heute";
  if (days == 1) return "gestern";

  return "vor $days Tagen";
}

/// „1 Abschnitt“ / „3 Abschnitte“.
String segmentCountLabel(int count) {
  return count == 1 ? "1 Abschnitt" : "$count Abschnitte";
}

/// Zeigt den Zieltext mit markierten Abweichungen der Wiedergabe:
/// fehlende Wörter unterstrichen, falsche mit dem durchgestrichenen
/// eingegebenen Wort, zusätzliche durchgestrichen.
///
/// [asked] ordnet die Positionen des Vergleichs den Wörtern in [prompt] zu
/// (bei Lückenaufgaben nur die ausgeblendeten Wörter).
class AlignmentView extends StatelessWidget {
  final HintPrompt prompt;
  final EvaluationResult result;
  final List<int> asked;

  const AlignmentView({
    super.key,
    required this.prompt,
    required this.result,
    required this.asked,
  });

  @override
  Widget build(BuildContext context) {
    final struck = TextStyle(
      color: context.colors.textSecondary,
      decoration: TextDecoration.lineThrough,
    );

    final byWord = <int, WordAlignment>{};
    final extrasAfter = <int, List<String>>{};

    for (final a in result.alignment) {
      if (a.type == AlignmentType.extra) {
        final anchor = a.targetIndex < 0 ? -1 : asked[a.targetIndex];
        extrasAfter.putIfAbsent(anchor, () => []).add(a.actual!);
      } else {
        byWord[asked[a.targetIndex]] = a;
      }
    }

    final spans = <InlineSpan>[];

    void addExtras(int anchor) {
      for (final word in extrasAfter[anchor] ?? const <String>[]) {
        spans.add(TextSpan(text: "$word ", style: struck));
      }
    }

    addExtras(-1);

    for (var i = 0; i < prompt.words.length; i++) {
      final token = prompt.words[i];
      final a = byWord[i];

      if (a == null) {
        spans.add(TextSpan(text: token.raw));
      } else {
        switch (a.type) {
          case AlignmentType.match:
            spans.add(
              TextSpan(
                text: token.raw,
                style: TextStyle(color: context.colors.success),
              ),
            );

          case AlignmentType.missing:
            spans.add(
              TextSpan(
                text: token.raw,
                style: TextStyle(
                  color: context.colors.error,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            );

          case AlignmentType.substitution:
            spans
              ..add(TextSpan(text: "${a.actual} ", style: struck))
              ..add(
                TextSpan(
                  text: token.raw,
                  style: TextStyle(
                    color: a.minor
                        ? context.colors.accent
                        : context.colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );

          case AlignmentType.extra:
            break;
        }
      }

      final last = i == prompt.words.length - 1;
      final newLine =
          token.breakAfter ||
          (!last && prompt.words[i + 1].segment != token.segment);

      if (!last) {
        spans.add(TextSpan(text: newLine ? "\n" : " "));
      }

      // Zusätzliche Wörter stehen hinter dem Wort, nach dem sie kamen.
      if (extrasAfter.containsKey(i)) {
        if (last) spans.add(const TextSpan(text: " "));
        addExtras(i);
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 18, height: 1.6),
    );
  }
}
