import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import 'calendar_view.dart';
import 'notes_view.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';
import 'task_widgets.dart';

/// Seite einer Lehrveranstaltung bzw. eines Bereichs: Termine, offene
/// Aufgaben und Notizen auf einen Blick.
class AreaScreen extends StatelessWidget {
  final OrganizerController controller;
  final String? uid;
  final String areaId;

  const AreaScreen({
    super.key,
    required this.controller,
    required this.uid,
    required this.areaId,
  });

  OrganizerController get c => controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final area = c.area(areaId);
        if (area == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const OrgEmpty(
              icon: Icons.label_off_outlined,
              text: "Diese Zuordnung gibt es nicht mehr.",
            ),
          );
        }
        final filter = OrgFilter(areaId: areaId);
        final events = c.upcomingItems(days: 120, filter: filter, limit: 8);
        final tasks = c.tasksFor(TaskView.open, filter: filter);
        final done = c.tasksFor(TaskView.done, filter: filter).take(5);
        final notes = c.notesFor(filter: filter);
        final reading = areaId == "area_bibelkunde" ? c.readingTasks : const [];
        return Scaffold(
          appBar: AppBar(
            title: Text(area.name),
            actions: [
              IconButton(
                tooltip: "Bearbeiten",
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => editAreaDialog(context, c, area: area),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: "Neu",
            onPressed: () => _newItem(context),
            child: const Icon(Icons.add_rounded),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: Icon(
                            area.group == OrgGroup.private
                                ? Icons.home_outlined
                                : Icons.school_outlined,
                            size: 18,
                          ),
                          label: Text(area.group.label),
                        ),
                        if (area.timetableCourseId != null)
                          const Chip(
                            avatar: Icon(Icons.view_week_rounded, size: 18),
                            label: Text("Im Stundenplan"),
                          ),
                        if (area.appLink != null)
                          ActionChip(
                            avatar: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            label: Text(OrgAppTargets.label(area.appLink!)),
                            onPressed: () => openOrgTarget(
                              context,
                              uid: uid,
                              type: "app",
                              target: area.appLink!,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const OrgSectionTitle("Nächste Termine"),
                  if (events.isEmpty)
                    _none(context, "Keine anstehenden Termine."),
                  for (final i in events)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        i.important
                            ? Icons.priority_high_rounded
                            : Icons.event_rounded,
                        color: i.important
                            ? context.colors.error
                            : areaColor(context, area),
                      ),
                      title: Text(i.title),
                      subtitle: Text(
                        "${i.date.relativeLabel(c.today)} · ${i.timeLabel}"
                        "${i.location.isEmpty ? "" : " · ${i.location}"}",
                      ),
                      onTap: () =>
                          openCalendarEntry(context, c, uid: uid, item: i),
                    ),
                  const OrgSectionTitle("Aufgaben"),
                  QuickTaskField(controller: c, areaId: areaId),
                  for (final r in reading) ReadingTaskTile(task: r, uid: uid),
                  for (final t in tasks)
                    TaskTile(controller: c, task: t, uid: uid, showArea: false),
                  if (tasks.isEmpty) _none(context, "Keine offenen Aufgaben."),
                  if (done.isNotEmpty) ...[
                    const OrgSectionTitle("Zuletzt erledigt"),
                    for (final t in done)
                      TaskTile(
                        controller: c,
                        task: t,
                        uid: uid,
                        showArea: false,
                      ),
                  ],
                  OrgSectionTitle(
                    "Notizen",
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text("Notiz"),
                      onPressed: () =>
                          openNoteEditor(context, c, uid: uid, areaId: areaId),
                    ),
                  ),
                  if (notes.isEmpty) _none(context, "Noch keine Notizen."),
                  for (final n in notes)
                    NoteTile(controller: c, note: n, uid: uid),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _none(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Text(text, style: TextStyle(color: context.colors.textSecondary)),
  );

  void _newItem(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_task_rounded),
            title: const Text("Aufgabe"),
            onTap: () {
              Navigator.pop(sheet);
              openTaskEditor(context, c, uid: uid, areaId: areaId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: const Text("Termin"),
            onTap: () {
              Navigator.pop(sheet);
              openEventEditor(context, c, uid: uid, areaId: areaId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text("Notiz"),
            onTap: () {
              Navigator.pop(sheet);
              openNoteEditor(context, c, uid: uid, areaId: areaId);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Einstellungen: Zuordnungen (auch aus dem Stundenplan), eigene
/// Terminarten, Leseplan und Stundenplan im Kalender.
class OrganizerSettingsScreen extends StatelessWidget {
  final OrganizerController controller;

  const OrganizerSettingsScreen({super.key, required this.controller});

  OrganizerController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Studiumsorganisation einrichten")),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final linked = {
            for (final a in c.allAreas)
              if (a.timetableCourseId != null && !a.archived)
                a.timetableCourseId!,
          };
          final fromTimetable = [
            for (final p in c.timetableCourses)
              if (!linked.contains(p.id)) p,
          ];
          final archived = [
            for (final a in c.allAreas)
              if (a.archived) a,
          ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  SwitchListTile(
                    key: const ValueKey("setting-reading-tasks"),
                    title: const Text("Leseplan als Aufgabe"),
                    subtitle: const Text(
                      "Das heutige Pensum begonnener Lesepläne zu "
                      "Lehrveranstaltungen (z. B. Bibelkunde) erscheint unter "
                      "„Heute“ – erledigt, sobald du die Kapitel liest.",
                    ),
                    value: c.config.readingTasks,
                    onChanged: (v) =>
                        c.saveConfig(c.config.copyWith(readingTasks: v)),
                  ),
                  SwitchListTile(
                    title: const Text("Stundenplan im Kalender"),
                    subtitle: const Text(
                      "Sitzungen deines Stundenplans erscheinen im Kalender, "
                      "ohne sie doppelt einzutragen.",
                    ),
                    value: c.config.showTimetable,
                    onChanged: (v) =>
                        c.saveConfig(c.config.copyWith(showTimetable: v)),
                  ),
                  OrgSectionTitle(
                    "Lehrveranstaltungen und Bereiche",
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Neu"),
                      onPressed: () => editAreaDialog(context, c),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Eine gemeinsame Liste für Aufgaben, Termine und Notizen.",
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                  for (final a in c.areas)
                    ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 14,
                        color: areaColor(context, a),
                      ),
                      title: Text(a.name),
                      subtitle: Text(
                        [
                          a.group.label,
                          if (a.timetableCourseId != null) "Stundenplan",
                          if (a.appLink != null)
                            OrgAppTargets.label(a.appLink!),
                        ].join(" · "),
                      ),
                      onTap: () => editAreaDialog(context, c, area: a),
                      trailing: IconButton(
                        tooltip: "Archivieren",
                        icon: const Icon(Icons.archive_outlined),
                        onPressed: () => c.saveArea(a.copyWith(archived: true)),
                      ),
                    ),
                  if (fromTimetable.isNotEmpty) ...[
                    const OrgSectionTitle("Aus dem Stundenplan übernehmen"),
                    for (final p in fromTimetable)
                      ListTile(
                        leading: const Icon(Icons.view_week_rounded),
                        title: Text(p.title),
                        trailing: const Icon(Icons.add_rounded),
                        onTap: () => c.areaForTimetable(p.id, p.title),
                      ),
                  ],
                  if (archived.isNotEmpty) ...[
                    const OrgSectionTitle("Archiviert"),
                    for (final a in archived)
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(a.name),
                        trailing: TextButton(
                          onPressed: () =>
                              c.saveArea(a.copyWith(archived: false)),
                          child: const Text("Zurückholen"),
                        ),
                      ),
                  ],
                  const OrgSectionTitle("Eigene Terminarten"),
                  if (c.config.customTypes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Neue Arten legst du direkt beim Termin an.",
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                  for (final t in c.config.customTypes)
                    ListTile(
                      title: Text(t.label),
                      trailing: IconButton(
                        tooltip: "Entfernen",
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => c.saveConfig(
                          c.config.copyWith(
                            customTypes: [
                              for (final x in c.config.customTypes)
                                if (x.id != t.id) x,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
