import 'package:flutter/material.dart';

import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';
import 'task_widgets.dart';

enum CalendarMode {
  month("Monat"),
  week("Woche"),
  day("Tag"),
  list("Liste");

  final String label;

  const CalendarMode(this.label);
}

/// Kalender: Monat, Woche, Tag und eine Liste der nächsten Termine. Eigene
/// Termine, Sitzungen des Stundenplans und fällige Aufgaben an einem Ort.
class CalendarView extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;

  /// Öffnet den Stundenplan (Termine aus dem Stundenplan).
  final VoidCallback? onOpenTimetable;

  const CalendarView({
    super.key,
    required this.controller,
    required this.uid,
    this.onOpenTimetable,
  });

  @override
  State<CalendarView> createState() => CalendarViewState();
}

class CalendarViewState extends State<CalendarView> {
  OrganizerController get c => widget.controller;

  CalendarMode mode = CalendarMode.month;
  late OrgDate selected = c.today;

  void _move(int direction) {
    setState(() {
      selected = switch (mode) {
        CalendarMode.month => selected.addMonths(direction),
        CalendarMode.week => selected.addDays(7 * direction),
        CalendarMode.day => selected.addDays(direction),
        CalendarMode.list => selected.addDays(30 * direction),
      };
    });
  }

  String _title() {
    final s = selected;
    return switch (mode) {
      CalendarMode.month => "${OrgDate.monthNames[s.month - 1]} ${s.year}",
      CalendarMode.week =>
        "${s.startOfWeek.label(weekday: false)} – "
            "${s.startOfWeek.addDays(6).label(weekday: false)}${s.startOfWeek.addDays(6).year}",
      CalendarMode.day =>
        "${OrgDate.weekdayLong[s.weekday - 1]}, ${s.label(weekday: false, year: true)}",
      CalendarMode.list => "Ab ${s.label(year: true)}",
    };
  }

  Color _itemColor(BuildContext context, CalendarItem item) {
    if (item.important) return context.colors.error;
    final area = c.area(item.areaId);
    if (area != null) return areaColor(context, area);
    return item.fromTimetable
        ? context.colors.primaryLight
        : context.colors.accent;
  }

  void openCalendarItem(BuildContext context, CalendarItem item) =>
      openCalendarEntry(
        context,
        c,
        uid: widget.uid,
        item: item,
        onOpenTimetable: widget.onOpenTimetable,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SegmentedButton<CalendarMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in CalendarMode.values)
                  ButtonSegment(
                    value: m,
                    label: Text(m.label, key: ValueKey("cal-${m.name}")),
                  ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setState(() => mode = s.first),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: "Zurück",
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _move(-1),
              ),
              Expanded(
                child: Text(
                  _title(),
                  key: const ValueKey("calendar-title"),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: "Weiter",
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _move(1),
              ),
              TextButton(
                onPressed: () => setState(() => selected = c.today),
                child: const Text("Heute"),
              ),
            ],
          ),
          Expanded(
            child: switch (mode) {
              CalendarMode.month => _month(context),
              CalendarMode.week => _week(context),
              CalendarMode.day => ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: _dayAgenda(context, selected, full: true),
              ),
              CalendarMode.list => _list(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _month(BuildContext context) {
    final first = selected.startOfMonth.startOfWeek;
    final last = selected.startOfMonth
        .addDays(selected.daysInMonth - 1)
        .startOfWeek
        .addDays(6);
    final items = c.itemsBetween(first, last);
    final marks = <OrgDate, List<Color>>{};
    final important = <OrgDate>{};
    for (final i in items) {
      if (i.cancelled) continue;
      for (var d = i.date; !d.isAfter(i.endDate); d = d.addDays(1)) {
        (marks[d] ??= []).add(_itemColor(context, i));
        if (i.important) important.add(d);
      }
    }
    for (final t in c.tasksFor(TaskView.open)) {
      final due = t.due;
      if (due != null && !due.isBefore(first) && !due.isAfter(last)) {
        (marks[due] ??= []).add(context.colors.textSecondary);
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: MonthGrid(
            month: selected,
            today: c.today,
            selected: selected,
            marks: marks,
            important: important,
            onTap: (d) => setState(() => selected = d),
          ),
        ),
        const Divider(),
        ..._dayAgenda(context, selected),
      ],
    );
  }

  Widget _week(BuildContext context) {
    final start = selected.startOfWeek;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (var i = 0; i < 7; i++) ...[
          InkWell(
            onTap: () => setState(() {
              selected = start.addDays(i);
              mode = CalendarMode.day;
            }),
            child: OrgSectionTitle(
              "${OrgDate.weekdayLong[i]}, ${start.addDays(i).label(weekday: false)}",
              color: start.addDays(i) == c.today ? context.colors.accent : null,
            ),
          ),
          ..._compactDay(context, start.addDays(i)),
        ],
      ],
    );
  }

  List<Widget> _compactDay(BuildContext context, OrgDate day) {
    final items = c.itemsOn(day);
    final tasks = [
      for (final t in c.tasksDueOn(day))
        if (!c.isDone(t)) t,
    ];
    if (items.isEmpty && tasks.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            "–",
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      ];
    }
    return [
      for (final i in items) _itemTile(context, i, dense: true),
      for (final t in tasks) TaskTile(controller: c, task: t, uid: widget.uid),
    ];
  }

  Widget _itemTile(
    BuildContext context,
    CalendarItem item, {
    bool dense = false,
  }) {
    final color = _itemColor(context, item);
    final type = c.config.type(item.typeId);
    final area = c.area(item.areaId);
    return ListTile(
      key: ValueKey("cal-item-${item.key}"),
      dense: dense,
      leading: Container(
        width: 4,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      minLeadingWidth: 4,
      title: Row(
        children: [
          if (item.important)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.priority_high_rounded,
                size: 16,
                color: context.colors.error,
              ),
            ),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: item.cancelled ? TextDecoration.lineThrough : null,
                fontWeight: item.important ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (item.event?.recurrence != null)
            Icon(
              Icons.repeat_rounded,
              size: 14,
              color: context.colors.textSecondary,
            ),
        ],
      ),
      subtitle: Text(
        [
          item.timeLabel,
          if (item.important || item.fromTimetable) type.label,
          if (item.fromTimetable) "Stundenplan",
          if (item.location.isNotEmpty) item.location,
          if (area != null && !item.fromTimetable) area.name,
          if (item.cancelled) "fällt aus",
        ].join(" · "),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openCalendarItem(context, item),
    );
  }

  List<Widget> _dayAgenda(
    BuildContext context,
    OrgDate day, {
    bool full = false,
  }) {
    final items = c.itemsOn(day);
    final tasks = c.tasksDueOn(day);
    final reading = day == c.today ? c.readingTasks : const [];
    return [
      if (!full)
        OrgSectionTitle(
          day.relativeLabel(c.today) ==
                  day.label(year: day.year != c.today.year)
              ? "${OrgDate.weekdayLong[day.weekday - 1]}, ${day.label(weekday: false)}"
              : "${day.relativeLabel(c.today)}, ${day.label(weekday: false)}",
          trailing: IconButton(
            tooltip: "Termin an diesem Tag",
            icon: const Icon(Icons.add_rounded),
            onPressed: () =>
                openEventEditor(context, c, uid: widget.uid, date: day),
          ),
        ),
      if (items.isEmpty && tasks.isEmpty && reading.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "Keine Termine.",
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      for (final i in items) _itemTile(context, i),
      if (tasks.isNotEmpty || reading.isNotEmpty)
        const OrgSectionTitle("Fällige Aufgaben"),
      for (final r in reading) ReadingTaskTile(task: r, uid: widget.uid),
      for (final t in tasks) TaskTile(controller: c, task: t, uid: widget.uid),
    ];
  }

  Widget _list(BuildContext context) {
    final from = selected.isBefore(c.today) ? selected : c.today;
    final start = selected == c.today ? c.today : selected;
    final items = start == c.today
        ? c.upcomingItems(days: 60)
        : c.itemsBetween(from, from.addDays(60));
    if (items.isEmpty) {
      return const OrgEmpty(
        icon: Icons.event_available_outlined,
        text: "Keine Termine in den nächsten 60 Tagen.",
      );
    }
    final widgets = <Widget>[];
    OrgDate? last;
    for (final i in items) {
      final day = i.date.isBefore(start) ? start : i.date;
      if (day != last) {
        widgets.add(OrgSectionTitle(day.relativeLabel(c.today)));
        last = day;
      }
      widgets.add(_itemTile(context, i));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: widgets,
    );
  }
}

/// Öffnet einen Kalendereintrag: eigener Termin → Bearbeiten, Termin des
/// Stundenplans → Kurzinfo mit Aufgabe/Notiz zur Sitzung.
void openCalendarEntry(
  BuildContext context,
  OrganizerController c, {
  required String? uid,
  required CalendarItem item,
  VoidCallback? onOpenTimetable,
}) {
  final event = item.event;
  if (event != null) {
    openEventEditor(context, c, uid: uid, event: event, occurrence: item.date);
    return;
  }
  _timetableSheet(context, c, uid, item, onOpenTimetable);
}

void _timetableSheet(
  BuildContext context,
  OrganizerController c,
  String? uid,
  CalendarItem item,
  VoidCallback? onOpenTimetable,
) {
  final courseId = item.timetableCourseId!;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final area = c.area(item.areaId);
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              [
                item.date.label(year: true),
                item.timeLabel,
                if (item.location.isNotEmpty) item.location,
                if (item.cancelled) "fällt aus",
              ].join(" · "),
            ),
            const SizedBox(height: 4),
            Text(
              "Aus deinem Stundenplan. Termine änderst du dort.",
              style: TextStyle(color: sheet.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text("Aufgabe zur Sitzung"),
                  onPressed: () {
                    Navigator.pop(sheet);
                    final a = area ?? c.areaForTimetable(courseId, item.title);
                    openTaskEditor(
                      context,
                      c,
                      uid: uid,
                      due: item.date,
                      areaId: a.id,
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text("Notiz zur Sitzung"),
                  onPressed: () {
                    Navigator.pop(sheet);
                    final a = area ?? c.areaForTimetable(courseId, item.title);
                    openNoteEditor(
                      context,
                      c,
                      uid: uid,
                      areaId: a.id,
                      links: const [],
                    );
                  },
                ),
                if (onOpenTimetable != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      onOpenTimetable();
                    },
                    child: const Text("Stundenplan öffnen"),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
