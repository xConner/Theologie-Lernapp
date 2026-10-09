import 'package:flutter/material.dart';

import '../../models/bible/bible_reading.dart';
import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import '../../models/bible/reading_plan.dart';
import '../../screens/bible/bible_reader_screen.dart';
import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../streak_widgets.dart';

/// Rückmeldung nach einer bestätigten Lesung: die Streak-Meldung, wenn der
/// Tag damit zählt, sonst eine kurze Bestätigung.
void showReadingFeedback(
  ScaffoldMessengerState? messenger,
  BibleReadingResult? result, {
  String confirmation = "Lesung eingetragen.",
}) {
  if (messenger == null || result == null) return;

  final streak = result.streak;

  messenger.hideCurrentSnackBar();

  if (streak != null && streak.goalReachedNow) {
    messenger.showSnackBar(streakSnackBar(StreakTrack.bible, streak));
  } else if (result.logged) {
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(confirmation),
      ),
    );
  } else {
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          "Die Lesung konnte nicht im Leseverlauf gespeichert werden.",
        ),
      ),
    );
  }
}

/// Fragt die (optionale) Stellenangabe ab und trägt die Lesung nach
/// ausdrücklicher Bestätigung für heute ein. [suggestion] ist z. B. das
/// aufgeschlagene Kapitel.
Future<void> confirmBibleReading(
  BuildContext context, {
  required String? uid,
  required BibleReadingService service,
  String? suggestion,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  final text = await showDialog<String>(
    context: context,
    builder: (_) => _ConfirmReadingDialog(suggestion: suggestion),
  );

  if (text == null) return;

  final result = await service.confirmReading(uid: uid, text: text);

  showReadingFeedback(messenger, result);
}

class _ConfirmReadingDialog extends StatefulWidget {
  final String? suggestion;

  const _ConfirmReadingDialog({this.suggestion});

  @override
  State<_ConfirmReadingDialog> createState() => _ConfirmReadingDialogState();
}

class _ConfirmReadingDialogState extends State<_ConfirmReadingDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.suggestion,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop(context, _text.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Als gelesen markieren"),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bestätige, dass du heute in der Bibel gelesen hast. Der Tag "
              "zählt dann für deine Bibellese-Streak.",
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey("bible-reading-text"),
              controller: _text,
              maxLength: BibleReadingEntry.maxTextLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirm(),
              decoration: const InputDecoration(
                labelText: "Gelesene Stelle (optional)",
                hintText: "z. B. Mk 4 oder Ps 23",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        FilledButton(
          key: const ValueKey("bible-reading-confirm"),
          onPressed: _confirm,
          child: const Text("Gelesen"),
        ),
      ],
    );
  }
}

/// Öffnet die Lesungen von Tag [day] im Reader, beginnend bei [reading].
Future<void> openPlanReading(
  BuildContext context, {
  required String? uid,
  required ReadingPlan plan,
  required int day,
  required int reading,
  BibleReadingService? service,
  BibleRepository? repository,
}) {
  final readings = plan.readingsOn(day);

  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BibleReaderScreen(
        uid: uid,
        readingService: service,
        repository: repository,
        passages: [
          for (final r in readings)
            BiblePassage(label: r.label, reference: r.reference),
        ],
        passageTitle: "${plan.name} · Tag $day",
        initialPassage: reading,
        planDay: (planId: plan.id, day: day),
      ),
    ),
  );
}

/// Die Lesungen eines Plantags: abhaken und im Reader öffnen – in
/// beliebiger Reihenfolge.
class PlanDayReadings extends StatelessWidget {
  final String? uid;
  final ReadingPlan plan;
  final int day;
  final BibleReadingService service;

  // Nur für Tests ersetzbar.
  final BibleRepository? repository;

  const PlanDayReadings({
    super.key,
    required this.uid,
    required this.plan,
    required this.day,
    required this.service,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final progress = service.progressOf(uid, plan.id);
    final readings = plan.readingsOn(day);

    // Abhaken nur in einem laufenden Plan.
    final editable = progress != null && !progress.paused;

    return Column(
      children: [
        for (var i = 0; i < readings.length; i++)
          Row(
            children: [
              Checkbox(
                key: ValueKey("plan-reading-${plan.id}-$day-$i"),
                value: progress?.isDone(day, i) ?? false,
                onChanged: !editable
                    ? null
                    : (value) async {
                        final messenger = ScaffoldMessenger.maybeOf(context);

                        final result = await service.setPlanReading(
                          uid: uid,
                          planId: plan.id,
                          day: day,
                          reading: i,
                          done: value ?? false,
                        );

                        if (value == true) {
                          showReadingFeedback(
                            messenger,
                            result,
                            confirmation: "Lesung erledigt.",
                          );
                        }
                      },
              ),
              Expanded(
                child: Text(
                  readings[i].label,
                  style: (progress?.isDone(day, i) ?? false)
                      ? TextStyle(color: context.colors.textSecondary)
                      : null,
                ),
              ),
              TextButton(
                onPressed: () => openPlanReading(
                  context,
                  uid: uid,
                  plan: plan,
                  day: day,
                  reading: i,
                  service: service,
                  repository: repository,
                ),
                child: const Text("Lesen"),
              ),
            ],
          ),
      ],
    );
  }
}

/// Fortschrittsbalken mit Beschriftung, z. B. „12 von 365 Tagen“.
class PlanProgressBar extends StatelessWidget {
  final ReadingPlan plan;
  final ReadingPlanProgress progress;

  const PlanProgressBar({
    super.key,
    required this.plan,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final complete = progress.isComplete(plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.fraction(plan),
            minHeight: 8,
            backgroundColor: context.colors.surfaceMuted,
            color: complete ? context.colors.success : context.colors.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${progress.completedDays(plan)} von ${plan.dayCount} Tagen · "
          "${progress.doneReadings(plan)} von ${plan.readingCount} Lesungen",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// Dauer, Umfang und Einstufung eines Plans in einer Zeile bzw. als
/// Warnhinweis bei sehr intensiven Plänen.
class PlanFacts extends StatelessWidget {
  final ReadingPlan plan;
  final List<BibleTranslation> translations;

  /// Warnhinweis ausführlich zeigen (Detailansicht).
  final bool detailed;

  const PlanFacts({
    super.key,
    required this.plan,
    required this.translations,
    this.detailed = false,
  });

  static String daysText(int days) => days == 1 ? "1 Tag" : "$days Tage";

  @override
  Widget build(BuildContext context) {
    final extent = plan.extentIn(translations);
    final difficulty = plan.difficulty;

    final intensive =
        extent.isIntensive ||
        difficulty == ReadingPlanDifficulty.intensive ||
        difficulty == ReadingPlanDifficulty.extreme;

    final extreme =
        extent.isExtreme || difficulty == ReadingPlanDifficulty.extreme;

    final label = extreme
        ? ReadingPlanDifficulty.extreme.label
        : intensive
        ? ReadingPlanDifficulty.intensive.label
        : difficulty?.label;

    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            daysText(plan.dayCount),
            if (translations.isNotEmpty) extent.summary,
            ?plan.categoryLabel,
          ].join(" · "),
          style: secondary,
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: intensive
                  ? context.colors.errorBackground
                  : context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: intensive
                    ? context.colors.error
                    : context.colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (detailed && intensive && translations.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey("plan-intensity-warning"),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              intensityWarning(extent, extreme: extreme),
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ],
    );
  }

  static String intensityWarning(
    ReadingPlanExtent extent, {
    required bool extreme,
  }) {
    return "${extreme ? "Extremer" : "Sehr intensiver"} Plan: täglich rund "
        "${extent.chaptersPerDayText} Kapitel, also "
        "${ReadingPlanExtent.formatMinutes(extent.minutesPerDay)} Lesezeit "
        "(am umfangreichsten Tag "
        "${ReadingPlanExtent.formatMinutes(extent.maxMinutesPerDay)}).";
  }
}
