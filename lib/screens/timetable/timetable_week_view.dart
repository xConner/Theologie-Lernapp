import 'package:flutter/material.dart';

import '../../models/timetable/timetable_entry.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../services/timetable/timetable_schedule.dart';
import '../../theme/app_theme.dart';
import 'course_detail_screen.dart';

/// Wochenansicht des persönlichen Stundenplans mit konkreten Terminen der
/// gewählten Woche (inkl. Einzel- und Blockterminen, Ausfällen und
/// unterrichtsfreier Zeit) und markierten Überschneidungen.
class TimetableWeekView extends StatefulWidget {
  final TimetableController controller;

  const TimetableWeekView({super.key, required this.controller});

  /// Ab dieser Breite stehen die Wochentage nebeneinander.
  static const double columnsBreakpoint = 840;

  @override
  State<TimetableWeekView> createState() => _TimetableWeekViewState();
}

class _TimetableWeekViewState extends State<TimetableWeekView>
    with AutomaticKeepAliveClientMixin {
  late String _monday = initialWeek(
    widget.controller.catalog!.semester,
    widget.controller.now(),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final catalog = controller.catalog!;

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
    if (!controller.entriesLoaded) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: "Stundenplan wird geladen",
        ),
      );
    }
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
            "Dein Stundenplan für das ${catalog.semester.label} ist noch leer. "
            "Füge Veranstaltungen über die Suche hinzu.",
        notes: otherSemesterNotes,
        action: FilledButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(1),
          icon: const Icon(Icons.search_rounded),
          label: const Text("Veranstaltungen suchen"),
        ),
      );
    }

    final weeks = semesterWeeks(catalog.semester);
    final index = weeks.indexOf(_monday);
    final days = weekSchedule(catalog, controller.plannedIds, _monday);
    final weekConflicts = {
      for (final list in days.values)
        for (final item in list)
          if (item.hasConflict) item.occurrence.id,
    }.length;
    final visibleDays = [
      for (var d = 1; d <= 7; d++)
        if (d <= 5 || days[d]!.isNotEmpty) d,
    ];
    final problems = [
      for (final e in controller.entriesOfSemester)
        if (controller.stateFor(e) case final state?
            when state != TimetableEntryState.current)
          (e, state),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _WeekNavigation(
          monday: _monday,
          canGoBack: index > 0,
          canGoForward: index >= 0 && index < weeks.length - 1,
          onChange: (delta) =>
              setState(() => _monday = addDays(_monday, 7 * delta)),
          onToday: () => setState(
            () => _monday = initialWeek(
              catalog.semester,
              widget.controller.now(),
            ),
          ),
        ),
        for (final b in breaksInWeek(catalog.semester, _monday))
          _Banner(
            icon: Icons.beach_access_rounded,
            text: b.start == b.end
                ? "${b.label} am ${formatDate(b.start, withYear: false)}"
                : "${b.label}: ${formatDate(b.start, withYear: false)}–${formatDate(b.end)}",
          ),
        if (weekConflicts > 0)
          _Banner(
            icon: Icons.warning_amber_rounded,
            error: true,
            text: weekConflicts == 1
                ? "1 Termin in dieser Woche überschneidet sich."
                : "$weekConflicts Termine in dieser Woche überschneiden sich.",
          ),
        for (final (entry, state) in problems)
          _EntryProblem(controller: controller, entry: entry, state: state),
        ...otherSemesterNotes,
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= TimetableWeekView.columnsBreakpoint;
            final dayWidgets = [
              for (final d in visibleDays)
                _DayColumn(
                  date: addDays(_monday, d - 1),
                  weekday: d,
                  items: days[d]!,
                  controller: controller,
                ),
            ];
            if (!columns) return Column(children: dayWidgets);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in dayWidgets)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: w,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
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

class _DayColumn extends StatelessWidget {
  final String date;
  final int weekday;
  final List<WeekItem> items;
  final TimetableController controller;

  const _DayColumn({
    required this.date,
    required this.weekday,
    required this.items,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              "${weekdayName(weekday)}, ${formatDate(date, withYear: false)}",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text("Keine Termine", style: TextStyle(color: colors.textSecondary))
          else
            for (final item in items)
              _OccurrenceCard(item: item, date: date, controller: controller),
        ],
      ),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  final WeekItem item;
  final String date;
  final TimetableController controller;

  const _OccurrenceCard({
    required this.item,
    required this.date,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog!;
    final colors = context.colors;
    final o = item.occurrence;
    final cancelled = o.cancelled;
    final time = o.spansDays
        ? (date == o.start.date
              ? "ab ${o.start.time}"
              : date == o.end.date
              ? "bis ${o.end.time}"
              : "ganztägig")
        : timeRange(o.start.time, o.end.time);
    final room = o.roomId == null ? null : catalog.rooms[o.roomId]?.label;
    final conflictText = item.hasConflict
        ? "Überschneidung mit ${item.conflictsWith.map((c) => c.title).join(", ")}"
        : null;

    final semantics = [
      time,
      item.course.title,
      ?room,
      if (cancelled) "fällt aus",
      ?conflictText,
    ].join(", ");

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: item.hasConflict ? colors.error : colors.divider,
          width: item.hasConflict ? 2 : 1,
        ),
      ),
      color: item.hasConflict ? colors.errorBackground : null,
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(
                controller: controller,
                courseId: item.course.id,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.course.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                    color: cancelled ? colors.textSecondary : null,
                  ),
                ),
                if (room != null)
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                if (cancelled)
                  Text("fällt aus", style: TextStyle(color: colors.error)),
                if (conflictText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: colors.error,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conflictText,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ],
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

class _EntryProblem extends StatelessWidget {
  final TimetableController controller;
  final TimetableEntry entry;
  final TimetableEntryState state;

  const _EntryProblem({
    required this.controller,
    required this.entry,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      TimetableEntryState.changed =>
        "„${entry.title}“: Termine oder Raum haben sich geändert.",
      TimetableEntryState.missing =>
        "„${entry.title}“ ist im Katalog nicht mehr vorhanden.",
      TimetableEntryState.otherSemester =>
        "„${entry.title}“ gehört zu einem anderen Semester.",
      TimetableEntryState.current => "",
    };
    return _Banner(
      icon: Icons.info_outline_rounded,
      text: text,
      action: state == TimetableEntryState.changed
          ? null
          : TextButton(
              onPressed: () => controller.remove(entry.courseId),
              child: const Text("Entfernen"),
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;
  final Widget? action;

  const _Banner({
    required this.icon,
    required this.text,
    this.error = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
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
        ],
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
