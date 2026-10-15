import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/timetable/course_catalog.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/plan_conflicts.dart';
import '../../services/timetable/plan_schedule.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../services/timetable/timetable_schedule.dart';
import '../../services/timetable/week_layout.dart';
import '../../theme/app_theme.dart';
import 'conflict_views.dart';
import 'course_detail_screen.dart';

/// Wochenübersicht wie ein gedruckter Stundenplan: Wochentage als Spalten,
/// Zeit von oben nach unten, Termine als Blöcke der konkreten Woche
/// (inklusive Block- und Einzelterminen, Ausfällen und unterrichtsfreier
/// Zeit). Gleichzeitige Termine stehen nebeneinander.
class TimetableWeekView extends StatefulWidget {
  final TimetableController controller;

  /// Wechsel zur Suche (leerer Plan).
  final VoidCallback? onSearch;

  const TimetableWeekView({super.key, required this.controller, this.onSearch});

  /// Mindestbreite einer Tagesspalte; darunter wird waagerecht gescrollt.
  static const double minDayWidth = 120;
  static const double timeColumnWidth = 48;

  @override
  State<TimetableWeekView> createState() => _TimetableWeekViewState();
}

class _TimetableWeekViewState extends State<TimetableWeekView>
    with AutomaticKeepAliveClientMixin {
  String? _monday;
  String? _semesterId;

  @override
  bool get wantKeepAlive => true;

  TimetableController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (controller.entriesError != null) {
      return _Message(
        icon: Icons.sync_problem_rounded,
        text: "Dein Stundenplan konnte nicht geladen werden.",
        action: FilledButton.icon(
          onPressed: controller.retryEntries,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text("Erneut versuchen"),
        ),
      );
    }
    final semester = controller.semesterInfo;
    if (!controller.entriesLoaded || semester == null) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: "Stundenplan wird geladen",
        ),
      );
    }
    if (_semesterId != semester.id || _monday == null) {
      _semesterId = semester.id;
      _monday = initialWeek(semester, controller.now());
    }
    final monday = _monday!;

    final others = controller.entriesOfOtherSemesters;
    final otherSemesterNotes = [
      for (final e in others.entries)
        _Banner(
          icon: Icons.swap_horiz_rounded,
          text: e.value.length == 1
              ? "1 Veranstaltung im ${controller.semesterLabel(e.key)}"
              : "${e.value.length} Veranstaltungen im ${controller.semesterLabel(e.key)}",
          action: controller.semesters.any((s) => s.id == e.key)
              ? TextButton(
                  onPressed: () => controller.selectSemester(e.key),
                  child: const Text("Anzeigen"),
                )
              : null,
        ),
    ];

    if (controller.entriesOfSemester.isEmpty) {
      return _Message(
        icon: Icons.event_note_rounded,
        text:
            "Dein Stundenplan für das ${semester.label} ist noch leer. "
            "Füge Veranstaltungen über die Suche hinzu.",
        notes: otherSemesterNotes,
        action: FilledButton.icon(
          onPressed: widget.onSearch,
          icon: const Icon(Icons.search_rounded),
          label: const Text("Veranstaltungen suchen"),
        ),
      );
    }

    final weeks = semesterWeeks(semester);
    final index = weeks.indexOf(monday);
    final sunday = addDays(monday, 6);
    final visible = controller.visibleOccurrences;
    final layout = layoutWeek(visible, monday);
    final semesterSpots = controller.conflicts;
    final weekSpots = [
      for (final s in semesterSpots)
        if (s.end.date.compareTo(monday) >= 0 &&
            s.start.date.compareTo(sunday) <= 0)
          s,
    ];
    final conflictIds = conflictingOccurrenceIds(semesterSpots);
    final weekSummary = ConflictSummary.of(weekSpots);
    final semesterGroups = groupConflicts(semesterSpots);
    final withoutDates = [
      for (final p in controller.plan)
        if (p.occurrences.isEmpty) p,
    ];
    final problems = [
      for (final p in controller.plan)
        if (p.source == PlanSource.missing || p.sourceChanged) p,
    ];
    final filterHidesAll =
        layout.isEmpty &&
        controller.filter != SessionKindFilter.all &&
        controller.plan.any((p) => p.occurrences.isNotEmpty);

    return ListView(
      key: const ValueKey("week-list"),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _WeekNavigation(
          monday: monday,
          canGoBack: index > 0,
          canGoForward: index >= 0 && index < weeks.length - 1,
          onChange: (delta) =>
              setState(() => _monday = addDays(monday, 7 * delta)),
          onToday: () =>
              setState(() => _monday = initialWeek(semester, controller.now())),
        ),
        _FilterChips(controller: controller),
        for (final b in breaksInWeek(semester, monday))
          _Banner(
            icon: Icons.beach_access_rounded,
            text: b.start == b.end
                ? "${b.label} am ${formatDate(b.start, withYear: false)}"
                : "${b.label}: ${formatDate(b.start, withYear: false)}–${formatDate(b.end)}",
          ),
        if (!weekSummary.isEmpty)
          _Banner(
            key: const ValueKey("week-conflicts"),
            icon: Icons.warning_amber_rounded,
            error: true,
            text: conflictSummaryText(weekSummary, suffix: " in dieser Woche"),
            onTap: () => showConflictSheet(
              context,
              controller: controller,
              spots: weekSpots,
              title: "Überschneidungen in dieser Woche",
            ),
          ),
        if (semesterGroups.isNotEmpty)
          _Banner(
            key: const ValueKey("semester-conflicts"),
            icon: Icons.event_busy_rounded,
            text:
                "Im ganzen Semester: ${semesterGroups.length == 1 ? "1 Überschneidungsstelle" : "${semesterGroups.length} Überschneidungsstellen"} "
                "(${semesterSpots.length == 1 ? "1 Termin" : "${semesterSpots.length} Termine"})",
            onTap: () => showConflictSheet(
              context,
              controller: controller,
              spots: semesterSpots,
              grouped: true,
              title: "Überschneidungen im ${semester.label}",
            ),
          ),
        for (final p in problems) _PlanProblem(controller: controller, plan: p),
        ...otherSemesterNotes,
        const SizedBox(height: 8),
        WeekGrid(
          layout: layout,
          monday: monday,
          controller: controller,
          conflictIds: conflictIds,
          spots: semesterSpots,
          today: _iso(controller.now()),
        ),
        if (layout.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              filterHidesAll
                  ? "In dieser Woche gibt es keine Termine zum gewählten Filter "
                        "„${controller.filter.label}“."
                  : "In dieser Woche hast du keine Termine.",
              key: const ValueKey("week-empty"),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        if (withoutDates.isNotEmpty) ...[
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              "Ohne feste Termine",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final p in withoutDates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_note_outlined),
              title: Text(p.title),
              subtitle: const Text(
                "Termine fehlen in der Quelle – über „Bearbeiten“ ergänzen.",
              ),
              onTap: () => _openDetails(context, controller, p),
            ),
        ],
      ],
    );
  }
}

String _iso(DateTime d) =>
    "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";

void _openDetails(
  BuildContext context,
  TimetableController controller,
  PlanCourse plan,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          CourseDetailScreen.forPlan(controller: controller, plan: plan),
    ),
  );
}

class _FilterChips extends StatelessWidget {
  final TimetableController controller;

  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final f in SessionKindFilter.values)
            ChoiceChip(
              key: ValueKey("kind-filter-${f.name}"),
              label: Text(f.label),
              selected: controller.filter == f,
              onSelected: (_) => controller.setFilter(f),
            ),
        ],
      ),
    );
  }
}

/// Das Raster einer Woche.
class WeekGrid extends StatelessWidget {
  final WeekLayout layout;
  final String monday;
  final TimetableController controller;
  final Set<String> conflictIds;
  final List<ConflictSpot> spots;
  final String today;

  const WeekGrid({
    super.key,
    required this.layout,
    required this.monday,
    required this.controller,
    required this.conflictIds,
    required this.spots,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final hourHeight = 64.0 * textScale;
    final days = layout.visibleWeekdays;
    final hours = (layout.lastMinute - layout.firstMinute) / 60;
    final bodyHeight = hours * hourHeight;
    final headerHeight = 44.0 * textScale;
    const timeWidth = TimetableWeekView.timeColumnWidth;
    final plans = {for (final p in controller.plan) p.id: p};

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - timeWidth;
        final dayWidth = math.max(
          TimetableWeekView.minDayWidth * math.min(textScale, 1.3),
          available / days.length,
        );
        final totalWidth = timeWidth + dayWidth * days.length;
        final scrolls = totalWidth > constraints.maxWidth + 0.5;

        double top(int minute) =>
            (minute - layout.firstMinute) / 60 * hourHeight;

        final grid = SizedBox(
          width: totalWidth,
          height: headerHeight + bodyHeight,
          child: Stack(
            children: [
              // Kopfzeile mit Wochentagen.
              for (final (i, d) in days.indexed)
                Positioned(
                  left: timeWidth + i * dayWidth,
                  top: 0,
                  width: dayWidth,
                  height: headerHeight,
                  child: _DayHeader(
                    date: addDays(monday, d - 1),
                    weekday: d,
                    today: addDays(monday, d - 1) == today,
                  ),
                ),
              // Stundenlinien und Zeitskala.
              for (var h = 0; h <= hours; h++) ...[
                Positioned(
                  left: timeWidth,
                  right: 0,
                  top: headerHeight + h * hourHeight,
                  child: Container(height: 1, color: colors.divider),
                ),
                if (h < hours)
                  Positioned(
                    left: 0,
                    width: timeWidth - 6,
                    top: headerHeight + h * hourHeight - 7,
                    child: Text(
                      "${(layout.firstMinute ~/ 60 + h).toString().padLeft(2, "0")}:00",
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
              // Tagesspalten (Trennlinien, heute hervorgehoben).
              for (final (i, d) in days.indexed)
                Positioned(
                  left: timeWidth + i * dayWidth,
                  top: headerHeight,
                  width: dayWidth,
                  height: bodyHeight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: addDays(monday, d - 1) == today
                            ? colors.primary.withValues(alpha: 0.05)
                            : null,
                        border: Border(left: BorderSide(color: colors.divider)),
                      ),
                    ),
                  ),
                ),
              // Termine.
              for (final (i, d) in days.indexed)
                for (final block in layout.days[d] ?? const <DayBlock>[])
                  if (plans[block.occurrence.entryId] case final plan?)
                    Positioned(
                      left:
                          timeWidth +
                          i * dayWidth +
                          block.lane * (dayWidth / block.lanes) +
                          2,
                      width: dayWidth / block.lanes - 4,
                      top: headerHeight + top(block.startMinute) + 1,
                      height: math.max(
                        (block.endMinute - block.startMinute) /
                                60 *
                                hourHeight -
                            2,
                        24,
                      ),
                      child: _GridBlock(
                        block: block,
                        plan: plan,
                        conflict: conflictIds.contains(block.occurrence.id),
                        onTap: () => showOccurrenceSheet(
                          context,
                          controller: controller,
                          plan: plan,
                          occurrence: block.occurrence,
                          spots: spots,
                        ),
                      ),
                    ),
            ],
          ),
        );

        if (!scrolls) return grid;
        return Scrollbar(
          child: SingleChildScrollView(
            key: const ValueKey("week-grid-scroll"),
            scrollDirection: Axis.horizontal,
            child: grid,
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String date;
  final int weekday;
  final bool today;

  const _DayHeader({
    required this.date,
    required this.weekday,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: today ? colors.primary : null,
      fontWeight: today ? FontWeight.w700 : null,
    );
    return Semantics(
      header: true,
      label:
          "${weekdayName(weekday)}, ${formatDate(date)}${today ? ", heute" : ""}",
      excludeSemantics: true,
      child: Center(
        child: Text(
          "${weekdayName(weekday, short: true)} ${formatDate(date, withYear: false)}",
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _GridBlock extends StatelessWidget {
  final DayBlock block;
  final PlanCourse plan;
  final bool conflict;
  final VoidCallback onTap;

  const _GridBlock({
    required this.block,
    required this.plan,
    required this.conflict,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final o = block.occurrence;
    final special = !o.regular;
    final tentative = o.tentative;
    // Rhythmus nur bei regelmäßigen, nicht wöchentlichen Terminen.
    final rhythm = o.regular ? rhythmLabel(o) : null;
    final base = special ? colors.accent : colors.primary;
    final cancelled = o.cancelled;
    final range = o.spansDays
        ? (block.continuesBefore && block.continuesAfter
              ? "ganztägig"
              : block.continuesAfter
              ? "ab ${o.start.time}"
              : "bis ${o.end.time}")
        : timeRange(o.start.time, o.end.time);
    final time = rhythm == null ? range : "$range · $rhythm";
    final lecturers = plan.lecturers.join(", ");
    final semantics = [
      time,
      plan.title,
      ?o.room,
      if (lecturers.isNotEmpty) lecturers,
      if (special) "Block- bzw. Einzeltermin",
      if (tentative) "nicht sicher, ob in dieser Woche",
      if (cancelled) "fällt aus",
      if (conflict) "Überschneidung",
    ].join(", ");
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: cancelled || tentative ? colors.textSecondary : colors.textPrimary,
      decoration: cancelled ? TextDecoration.lineThrough : null,
      fontStyle: tentative ? FontStyle.italic : null,
      height: 1.15,
    );

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        key: ValueKey("block-${o.id}"),
        color: cancelled
            ? colors.surfaceMuted
            : base.withValues(
                alpha: conflict
                    ? 0.22
                    : tentative
                    ? 0.06
                    : 0.16,
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: conflict
                ? colors.error
                : base.withValues(alpha: tentative ? 0.4 : 0.7),
            width: conflict ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: LayoutBuilder(
              builder: (context, c) {
                final lineHeight = (textStyle?.fontSize ?? 12) * 1.25;
                final lines = math.max(1, (c.maxHeight / lineHeight).floor());
                if (lines <= 1) {
                  return Text(
                    rhythm == null
                        ? "${o.start.time} ${plan.title}"
                        : "${o.start.time} ($rhythm) ${plan.title}",
                    style: textStyle?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }
                final extra = [
                  time,
                  ?o.room,
                  if (lecturers.isNotEmpty) lecturers,
                ];
                final titleLines = math.max(
                  1,
                  math.min(3, lines - extra.length),
                );
                final rest = lines - titleLines;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (conflict)
                          Padding(
                            padding: const EdgeInsets.only(right: 2, top: 1),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: colors.error,
                            ),
                          ),
                        if (special)
                          Padding(
                            padding: const EdgeInsets.only(right: 2, top: 1),
                            child: Icon(
                              Icons.event_rounded,
                              size: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            plan.title,
                            style: textStyle?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: titleLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    for (final line in extra.take(rest))
                      Text(
                        line,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Alle Angaben zu einem Termin (Antippen eines Blocks).
Future<void> showOccurrenceSheet(
  BuildContext context, {
  required TimetableController controller,
  required PlanCourse plan,
  required PlanOccurrence occurrence,
  required List<ConflictSpot> spots,
}) {
  final o = occurrence;
  final here = [
    for (final s in spots)
      if (s.occurrences.any((x) => x.id == o.id)) s,
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = sheetContext.colors;
      final facts = <(String, String)>[
        (
          "Wann",
          o.spansDays
              ? "${weekdayName(weekdayOf(o.start.date))}, ${formatDate(o.start.date)} ${o.start.time} bis "
                    "${weekdayName(weekdayOf(o.end.date))}, ${formatDate(o.end.date)} ${o.end.time}"
              : "${weekdayName(weekdayOf(o.date))}, ${formatDate(o.date)}, ${timeRange(o.start.time, o.end.time)}",
        ),
        ("Dauer", formatDuration(o.duration)),
        ("Raum", o.room ?? "nicht angegeben"),
        (
          "Dozent",
          plan.lecturers.isEmpty
              ? "nicht angegeben"
              : plan.lecturers.join(", "),
        ),
        ("Art", sessionKindDescription(o)),
        if (plan.number != null) ("Nummer", plan.number!),
        if (plan.faculty != null) ("Fakultät", plan.faculty!),
      ];
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  plan.title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (o.cancelled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Dieser Termin fällt aus.",
                    style: TextStyle(color: colors.error),
                  ),
                ),
              if (o.tentative)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Die Quelle nennt Wochentag, Uhrzeit und Rhythmus, aber "
                    "nicht, in welchen Wochen der Termin stattfindet. Er "
                    "steht deshalb in jeder Vorlesungswoche – ob er in dieser "
                    "Woche stattfindet, steht nicht fest.",
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              if (o.adjusted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Von dir angepasster Termin.",
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              for (final (label, value) in facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: MergeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            label,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                        Expanded(child: Text(value)),
                      ],
                    ),
                  ),
                ),
              for (final s in here)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ConflictSpotCard(controller: controller, spot: s),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openDetails(context, controller, plan);
                  },
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text("Alle Angaben"),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WeekNavigation extends StatelessWidget {
  final String monday;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onChange;
  final VoidCallback onToday;

  const _WeekNavigation({
    required this.monday,
    required this.canGoBack,
    required this.canGoForward,
    required this.onChange,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        "${formatDate(monday, withYear: false)}–${formatDate(addDays(monday, 6))}";
    return Row(
      children: [
        IconButton(
          tooltip: "Vorherige Woche",
          onPressed: canGoBack ? () => onChange(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label:
                "Woche vom ${formatDate(monday)} bis ${formatDate(addDays(monday, 6))}",
            excludeSemantics: true,
            child: Text(
              "Woche $label",
              key: const ValueKey("week-label"),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          tooltip: "Nächste Woche",
          onPressed: canGoForward ? () => onChange(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(onPressed: onToday, child: const Text("Heute")),
      ],
    );
  }
}

class _PlanProblem extends StatelessWidget {
  final TimetableController controller;
  final PlanCourse plan;

  const _PlanProblem({required this.controller, required this.plan});

  @override
  Widget build(BuildContext context) {
    final missing = plan.source == PlanSource.missing;
    return _Banner(
      icon: missing ? Icons.info_outline_rounded : Icons.update_rounded,
      text: missing
          ? "„${plan.title}“ ist im Verzeichnis nicht mehr vorhanden."
          : plan.hasOverrides
          ? "„${plan.title}“: UnivIS hat Termine oder Räume geändert. Deine Anpassungen gelten weiter."
          : "„${plan.title}“: Termine oder Raum haben sich geändert.",
      action: missing
          ? TextButton(
              onPressed: () => controller.remove(plan.id),
              child: const Text("Entfernen"),
            )
          : TextButton(
              onPressed: () => _openDetails(context, controller, plan),
              child: const Text("Ansehen"),
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;
  final Widget? action;
  final VoidCallback? onTap;

  const _Banner({
    super.key,
    required this.icon,
    required this.text,
    this.error = false,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: error ? colors.errorBackground : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: error ? colors.error : colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          ?action,
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget action;
  final List<Widget> notes;

  const _Message({
    required this.icon,
    required this.text,
    required this.action,
    this.notes = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
            ...notes,
          ],
        ),
      ),
    );
  }
}
