import 'package:flutter/material.dart';

import '../../models/timetable/course_catalog.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/plan_conflicts.dart';
import '../../services/timetable/plan_schedule.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';
import 'course_detail_screen.dart';

/// „90 Min.“ bzw. „2 Std. 15 Min.“
String formatDuration(Duration d) {
  final h = d.inMinutes ~/ 60;
  final m = d.inMinutes % 60;
  if (h == 0) return "$m Min.";
  return m == 0 ? "$h Std." : "$h Std. $m Min.";
}

/// „1 Überschneidung (2 Veranstaltungen)“
String conflictSummaryText(ConflictSummary s, {String suffix = ""}) {
  final spots = s.spots == 1
      ? "1 Überschneidung"
      : "${s.spots} Überschneidungen";
  return "$spots$suffix – ${s.courses} Veranstaltungen betroffen";
}

String _title(
  TimetableController controller,
  String entryId, {
  String? candidateTitle,
}) {
  final plan = controller.planCourse(entryId);
  return plan?.title ?? candidateTitle ?? "Neue Veranstaltung";
}

String _occurrenceTime(PlanOccurrence o) => o.spansDays
    ? "${weekdayName(weekdayOf(o.start.date), short: true)} ${formatDate(o.start.date, withYear: false)} ${o.start.time} bis "
          "${weekdayName(weekdayOf(o.end.date), short: true)} ${formatDate(o.end.date, withYear: false)} ${o.end.time}"
    : "${timeRange(o.start.time, o.end.time)} (${formatDuration(o.duration)})";

/// Eine Überschneidungsstelle: wann, wie lange, wer.
class ConflictSpotCard extends StatelessWidget {
  final TimetableController controller;
  final ConflictSpot spot;

  /// Weitere Daten derselben Stelle (Gruppe über das Semester).
  final List<String> dates;
  final String? candidateTitle;

  const ConflictSpotCard({
    super.key,
    required this.controller,
    required this.spot,
    this.dates = const [],
    this.candidateTitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final when = spot.start.date == spot.end.date
        ? "${weekdayName(spot.weekday)}, ${timeRange(spot.start.time, spot.end.time)}"
        : "${weekdayName(spot.weekday)} ${spot.start.time} bis "
              "${weekdayName(weekdayOf(spot.end.date))} ${spot.end.time}";
    final dateText = dates.length > 1
        ? "an ${dates.length} Terminen (${formatDate(dates.first, withYear: false)}–${formatDate(dates.last)})"
        : "am ${formatDate(spot.date)}";
    final byEntry = <String, List<PlanOccurrence>>{};
    for (final o in spot.occurrences) {
      (byEntry[o.entryId] ??= []).add(o);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$when · ${formatDuration(spot.duration)} gleichzeitig",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2, bottom: 8),
              child: Text(
                dateText,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            for (final e in byEntry.entries)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: controller.planCourse(e.key) == null
                    ? null
                    : () {
                        final plan = controller.planCourse(e.key)!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen.forPlan(
                              controller: controller,
                              plan: plan,
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(
                          controller,
                          e.key,
                          candidateTitle: candidateTitle,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      for (final o in e.value)
                        Text(
                          [_occurrenceTime(o), ?o.room].join(" · "),
                          style: TextStyle(color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Liste der Überschneidungen als Blatt (Woche oder ganzes Semester).
Future<void> showConflictSheet(
  BuildContext context, {
  required TimetableController controller,
  required List<ConflictSpot> spots,
  required String title,
  bool grouped = false,
  String? candidateTitle,
}) {
  final groups = grouped ? groupConflicts(spots) : null;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text(
            "Gezählt wird jede Stelle, an der sich Veranstaltungen zeitlich "
            "überschneiden – auch wenn mehr als zwei beteiligt sind. "
            "Direkt aufeinanderfolgende Termine sind keine Überschneidung.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (groups != null)
            for (final g in groups)
              ConflictSpotCard(
                controller: controller,
                spot: g.first,
                dates: g.dates,
                candidateTitle: candidateTitle,
              )
          else
            for (final s in spots)
              ConflictSpotCard(
                controller: controller,
                spot: s,
                candidateTitle: candidateTitle,
              ),
        ],
      ),
    ),
  );
}

/// Hinweis vor dem Hinzufügen: Überschneidungen mit dem bestehenden Plan.
class ConflictNotice extends StatelessWidget {
  final TimetableController controller;
  final List<ConflictSpot> spots;
  final String candidateTitle;

  const ConflictNotice({
    super.key,
    required this.controller,
    required this.spots,
    required this.candidateTitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final groups = groupConflicts(spots);
    final others = {
      for (final s in spots)
        for (final id in s.entryIds)
          if (controller.planCourse(id) != null)
            controller.planCourse(id)!.title,
    };
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey("conflict-notice"),
        borderRadius: BorderRadius.circular(8),
        onTap: () => showConflictSheet(
          context,
          controller: controller,
          spots: spots,
          grouped: true,
          title: "Überschneidungen mit deinem Stundenplan",
          candidateTitle: candidateTitle,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.errorBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.error),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${groups.length == 1 ? "1 Überschneidungsstelle" : "${groups.length} Überschneidungsstellen"} "
                  "mit ${others.join(", ")}. Antippen für Wochentag, Uhrzeit und Dauer.",
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.error),
            ],
          ),
        ),
      ),
    );
  }
}
