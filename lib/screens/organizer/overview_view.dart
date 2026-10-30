import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import 'area_screen.dart';
import 'calendar_view.dart';
import 'notes_view.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';
import 'task_widgets.dart';

/// Übersicht: was heute ansteht, was bald wichtig wird, die letzten Notizen
/// und Schnellzugriffe – bewusst knapp.
class OverviewView extends StatelessWidget {
  final OrganizerController controller;
  final String? uid;
  final void Function(TaskView view) onShowTasks;
  final VoidCallback onShowCalendar;
  final VoidCallback onShowNotes;
  final VoidCallback onOpenImport;

  /// Hinweis auf Neues in einem Seminarplan (null = nichts).
  final String? importHint;

  const OverviewView({
    super.key,
    required this.controller,
    required this.uid,
    required this.onShowTasks,
    required this.onShowCalendar,
    required this.onShowNotes,
    required this.onOpenImport,
    this.importHint,
  });

  OrganizerController get c => controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final today = c.today;
        final reminders = c.dueReminders;
        final todayItems = [
          for (final i in c.upcomingItems(days: 0))
            if (!i.important || i.date == today) i,
        ];
        final todayTasks = c.tasksFor(TaskView.today);
        final reading = c.readingTasks;
        final overdue = c.countFor(TaskView.overdue);
        final important = c.upcomingItems(days: 60, importantOnly: true);
        final upcoming = [
          for (final i in c.upcomingItems(days: 14))
            if (!i.important && i.date != today) i,
        ].take(5).toList();
        final notes = c.recentNotes();

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey("quick-new-task"),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text("Aufgabe"),
                    onPressed: () =>
                        openTaskEditor(context, c, uid: uid, due: today),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey("quick-new-event"),
                    icon: const Icon(Icons.event_rounded),
                    label: const Text("Termin"),
                    onPressed: () => openEventEditor(context, c, uid: uid),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey("quick-new-note"),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text("Notiz"),
                    onPressed: () => openNoteEditor(context, c, uid: uid),
                  ),
                ],
              ),
            ),
            if (importHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.playlist_add_check_rounded),
                    title: Text(importHint!),
                    subtitle: const Text("Vorschau ansehen und übernehmen"),
                    onTap: onOpenImport,
                  ),
                ),
              ),
            for (final r in reminders)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Card(
                  color: context.colors.surfaceMuted,
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: context.colors.accent,
                    ),
                    title: Text(r.item.title),
                    subtitle: Text(
                      "${r.item.date.relativeLabel(today)} · ${r.item.timeLabel}",
                    ),
                    onTap: () =>
                        openCalendarEntry(context, c, uid: uid, item: r.item),
                    trailing: IconButton(
                      tooltip: "Erinnerung ausblenden",
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => c.dismissReminder(r.key),
                    ),
                  ),
                ),
              ),
            OrgSectionTitle(
              "Heute · ${today.label()}",
              trailing: TextButton(
                onPressed: onShowCalendar,
                child: const Text("Kalender"),
              ),
            ),
            if (todayItems.isEmpty &&
                todayTasks.isEmpty &&
                reading.isEmpty &&
                overdue == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Heute stehen keine Termine und Aufgaben an.",
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            for (final i in todayItems)
              ListTile(
                dense: true,
                leading: Icon(
                  i.fromTimetable ? Icons.school_outlined : Icons.event_rounded,
                  color: areaColor(context, c.area(i.areaId)),
                ),
                title: Text(i.title),
                subtitle: Text(
                  [
                    i.timeLabel,
                    if (i.location.isNotEmpty) i.location,
                  ].join(" · "),
                ),
                onTap: () => openCalendarEntry(context, c, uid: uid, item: i),
              ),
            for (final r in reading)
              if (!r.overdue || !r.done) ReadingTaskTile(task: r, uid: uid),
            for (final t in todayTasks)
              TaskTile(controller: c, task: t, uid: uid),
            if (overdue > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    key: const ValueKey("overview-overdue"),
                    avatar: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: context.colors.error,
                    ),
                    label: Text(
                      overdue == 1
                          ? "1 Aufgabe überfällig"
                          : "$overdue Aufgaben überfällig",
                    ),
                    onPressed: () => onShowTasks(TaskView.overdue),
                  ),
                ),
              ),
            if (important.isNotEmpty) ...[
              OrgSectionTitle(
                "Prüfungen und Abgaben",
                color: context.colors.error,
              ),
              for (final i in important.take(5)) _important(context, i),
            ],
            if (upcoming.isNotEmpty) ...[
              const OrgSectionTitle("Nächste Termine"),
              for (final i in upcoming)
                ListTile(
                  dense: true,
                  leading: Icon(
                    i.fromTimetable
                        ? Icons.school_outlined
                        : Icons.event_rounded,
                    color: areaColor(context, c.area(i.areaId)),
                  ),
                  title: Text(i.title),
                  subtitle: Text(
                    "${i.date.relativeLabel(today)} · ${i.timeLabel}",
                  ),
                  onTap: () => openCalendarEntry(context, c, uid: uid, item: i),
                ),
            ],
            OrgSectionTitle(
              "Zuletzt bearbeitete Notizen",
              trailing: TextButton(
                onPressed: onShowNotes,
                child: const Text("Alle"),
              ),
            ),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Noch keine Notizen.",
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            for (final n in notes) NoteTile(controller: c, note: n, uid: uid),
            const OrgSectionTitle("Lehrveranstaltungen und Bereiche"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final a in c.areas)
                    ActionChip(
                      avatar: Icon(
                        Icons.circle,
                        size: 12,
                        color: areaColor(context, a),
                      ),
                      label: Text(a.name),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AreaScreen(controller: c, uid: uid, areaId: a.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _important(BuildContext context, CalendarItem i) {
    final today = c.today;
    final days = today.daysUntil(i.date);
    final running = days <= 0;
    final tasks = i.event == null
        ? const <OrgTask>[]
        : c.tasksOfEvent(i.event!.id);
    final done = tasks.where(c.isDone).length;
    return ListTile(
      key: ValueKey("important-${i.key}"),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: context.colors.errorBackground,
        child: Text(
          running ? "!" : "$days",
          style: TextStyle(
            color: context.colors.error,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          running
              ? (i.endDate == i.date
                    ? "heute"
                    : "läuft bis ${i.endDate.label()}")
              : days == 1
              ? "morgen"
              : "in $days Tagen · ${i.date.label()}",
          c.config.type(i.typeId).label,
          if (tasks.isNotEmpty) "Vorbereitung $done/${tasks.length}",
        ].join(" · "),
      ),
      onTap: () => openCalendarEntry(context, c, uid: uid, item: i),
    );
  }
}
