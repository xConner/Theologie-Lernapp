import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/bible/bible_reading.dart';
import '../../models/bible/reading_plan.dart';
import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bible/bible_reading_widgets.dart';
import '../../widgets/info_report.dart';
import '../../widgets/streak_widgets.dart';
import 'bible_reader_screen.dart';
import 'reading_plan_detail_screen.dart';
import 'reading_plans_screen.dart';

/// Startseite des Bereichs „Bibel“: Reader, Bibellese-Streak, die heutigen
/// Lesungen der laufenden Lesepläne und der Leseverlauf.
class BibleHomeScreen extends StatefulWidget {
  /// null = Gast.
  final String? uid;

  // Nur für Tests ersetzbar.
  final BibleReadingService? service;
  final BibleRepository? repository;

  const BibleHomeScreen({
    super.key,
    required this.uid,
    this.service,
    this.repository,
  });

  @override
  State<BibleHomeScreen> createState() => _BibleHomeScreenState();
}

class _BibleHomeScreenState extends State<BibleHomeScreen> {
  late final BibleReadingService service =
      widget.service ?? BibleReadingService.instance;

  String? get uid => widget.uid;

  @override
  void initState() {
    super.initState();

    // Fortschritte anderer Geräte übernehmen.
    service.load(uid, refresh: true);
  }

  void _openReader() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          uid: uid,
          trackReading: true,
          readingService: service,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _openPlans() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPlansScreen(
          uid: uid,
          service: service,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _openPlan(ReadingPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPlanDetailScreen(
          uid: uid,
          planId: plan.id,
          service: service,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bibel"),
        actions: const [InfoButton(module: AppModules.bible)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: service,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StreakDetailCard(
                  uid: uid,
                  track: StreakTrack.bible,
                  todayHint:
                      "Der Tag zählt, sobald du eine Lesung als gelesen "
                      "markiert hast – frei gewählt oder aus einem Leseplan.",
                ),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  key: const ValueKey("bible-open-reader"),
                  onPressed: _openReader,
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: const Text("Bibel lesen"),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  key: const ValueKey("bible-confirm-reading"),
                  onPressed: () =>
                      confirmBibleReading(context, uid: uid, service: service),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text("Lesung als gelesen markieren"),
                ),

                const SizedBox(height: 28),

                ..._plans(context),

                const SizedBox(height: 28),

                ..._history(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _plans(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final started = service.startedPlans(uid);

    return [
      Text("Lesepläne", style: textTheme.titleLarge),

      const SizedBox(height: 8),

      if (!service.isLoaded(uid))
        _note(
          context,
          "Lesepläne und Leseverlauf konnten nicht geladen werden. Deine "
          "Streak zählt trotzdem.",
        )
      else if (started.isEmpty)
        _note(
          context,
          "Du folgst noch keinem Leseplan. Lesen und die Streak "
          "funktionieren auch ohne Plan.",
        ),

      if (service.saveFailed)
        _note(
          context,
          "Eine Änderung konnte nicht gespeichert werden. Bitte prüfe deine "
          "Verbindung.",
        ),

      for (final (plan, progress) in started)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _planCard(context, plan, progress),
        ),

      const SizedBox(height: 4),

      OutlinedButton.icon(
        key: const ValueKey("bible-open-plans"),
        onPressed: _openPlans,
        icon: const Icon(Icons.event_note_rounded),
        label: Text(started.isEmpty ? "Leseplan auswählen" : "Alle Lesepläne"),
      ),
    ];
  }

  Widget _planCard(
    BuildContext context,
    ReadingPlan plan,
    ReadingPlanProgress progress,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final day = progress.currentDay(plan);

    final status = progress.paused
        ? "Pausiert"
        : day == null
        ? "Abgeschlossen"
        : "Tag $day von ${plan.dayCount}";

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: textTheme.titleMedium),
                      Text(
                        status,
                        style: textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openPlan(plan),
                  child: const Text("Plan öffnen"),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(right: 8, top: 6, bottom: 4),
              child: PlanProgressBar(plan: plan, progress: progress),
            ),

            if (day != null && !progress.paused)
              PlanDayReadings(
                uid: uid,
                plan: plan,
                day: day,
                service: service,
                repository: widget.repository,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _history(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );

    final days = service.recentDays(uid);
    final count = service.readingDayCount(uid);

    return [
      Text("Leseverlauf", style: textTheme.titleLarge),

      const SizedBox(height: 8),

      Text(
        count == 0
            ? "Noch keine bestätigte Lesung."
            : count == 1
            ? "Bisher 1 Lesetag."
            : "Bisher $count Lesetage.",
        key: const ValueKey("bible-reading-days"),
        style: secondary,
      ),

      for (final (date, entries) in days)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(formatReadingDate(date, service.today)),
              ),
              Expanded(child: Text(_entriesText(entries), style: secondary)),
            ],
          ),
        ),
    ];
  }

  static String _entriesText(List<BibleReadingEntry> entries) {
    final texts = [
      for (final entry in entries)
        if (entry.text.isNotEmpty) entry.text,
    ];

    return texts.isEmpty ? "Gelesen (ohne Angabe)" : texts.join(" · ");
  }

  Widget _note(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// `2026-10-10` → „Heute“ bzw. „10.10.2026“.
String formatReadingDate(String date, String today) {
  if (date == today) return "Heute";

  final parts = date.split("-");

  return parts.length == 3 ? "${parts[2]}.${parts[1]}.${parts[0]}" : date;
}
