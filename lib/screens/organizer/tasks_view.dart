import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import 'organizer_widgets.dart';
import 'task_widgets.dart';

/// Zentrale Aufgabenliste: Heute, Demnächst, Überfällig, alle offenen,
/// erledigte; Filter nach Zuordnung bzw. Studium/Privat.
class TasksView extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;
  final TaskView initialView;

  const TasksView({
    super.key,
    required this.controller,
    required this.uid,
    this.initialView = TaskView.today,
  });

  @override
  State<TasksView> createState() => TasksViewState();
}

class TasksViewState extends State<TasksView> {
  late TaskView view = widget.initialView;
  OrgFilter filter = OrgFilter.none;

  OrganizerController get c => widget.controller;

  void show(TaskView v) => setState(() => view = v);

  String _filterLabel() {
    if (filter.areaId != null) return c.area(filter.areaId)?.name ?? "Bereich";
    if (filter.group != null) return filter.group!.label;
    return "Alle Bereiche";
  }

  Future<void> _pickFilter() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text("Alle Bereiche"),
              onTap: () => Navigator.pop(sheet, "all"),
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text("Nur Studium"),
              onTap: () => Navigator.pop(sheet, "group:study"),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text("Nur Privat"),
              onTap: () => Navigator.pop(sheet, "group:private"),
            ),
            const Divider(),
            for (final a in c.areas)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.circle,
                  size: 14,
                  color: areaColor(sheet, a),
                ),
                title: Text(a.name),
                onTap: () => Navigator.pop(sheet, "area:${a.id}"),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    setState(() {
      filter = switch (choice) {
        "group:study" => const OrgFilter(group: OrgGroup.study),
        "group:private" => const OrgFilter(group: OrgGroup.private),
        "all" => OrgFilter.none,
        _ => OrgFilter(areaId: choice.substring(5)),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tasks = c.tasksFor(view, filter: filter);
        final reading =
            view == TaskView.today &&
                (filter.isEmpty ||
                    filter.group == OrgGroup.study ||
                    filter.areaId == "area_bibelkunde")
            ? c.readingTasks.where((t) => !t.overdue).toList()
            : const [];
        final readingOverdue =
            (view == TaskView.overdue || view == TaskView.today) &&
                filter.isEmpty
            ? c.readingTasks.where((t) => t.overdue).toList()
            : const [];
        final overdueCount = c.countFor(TaskView.overdue, filter: filter);

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (final v in TaskView.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: ValueKey("task-view-${v.name}"),
                        label: Text(_label(v)),
                        selected: view == v,
                        onSelected: (_) => show(v),
                      ),
                    ),
                  ActionChip(
                    key: const ValueKey("task-filter"),
                    avatar: Icon(
                      filter.isEmpty
                          ? Icons.filter_list_rounded
                          : Icons.filter_alt_rounded,
                      size: 18,
                    ),
                    label: Text(_filterLabel()),
                    onPressed: _pickFilter,
                  ),
                ],
              ),
            ),
            if (view != TaskView.done)
              QuickTaskField(
                controller: c,
                areaId: filter.areaId,
                defaultDue: view == TaskView.open ? null : c.today,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  if (view == TaskView.today && overdueCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: Icon(
                            Icons.warning_amber_rounded,
                            color: context.colors.error,
                            size: 18,
                          ),
                          label: Text(
                            overdueCount == 1
                                ? "1 überfällige Aufgabe"
                                : "$overdueCount überfällige Aufgaben",
                          ),
                          onPressed: () => show(TaskView.overdue),
                        ),
                      ),
                    ),
                  for (final r in readingOverdue)
                    if (!r.done) ReadingTaskTile(task: r, uid: widget.uid),
                  for (final r in reading)
                    ReadingTaskTile(task: r, uid: widget.uid),
                  ..._grouped(context, tasks),
                  if (tasks.isEmpty &&
                      reading.isEmpty &&
                      readingOverdue.isEmpty)
                    OrgEmpty(
                      icon: view == TaskView.done
                          ? Icons.inventory_2_outlined
                          : Icons.task_alt_rounded,
                      text: switch (view) {
                        TaskView.today => "Für heute ist nichts fällig.",
                        TaskView.upcoming =>
                          "In den nächsten zwei Wochen ist nichts fällig.",
                        TaskView.overdue => "Nichts überfällig.",
                        TaskView.open => "Keine offenen Aufgaben.",
                        TaskView.done => "Noch nichts erledigt.",
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _label(TaskView v) {
    if (v == TaskView.done || v == TaskView.open) return v.label;
    final n =
        c.countFor(v, filter: filter) +
        (v == TaskView.today
            ? c.readingTasks.where((t) => !t.overdue && !t.done).length
            : 0);
    return n == 0 ? v.label : "${v.label} ($n)";
  }

  List<Widget> _grouped(BuildContext context, List<OrgTask> tasks) {
    Widget tile(OrgTask t) => TaskTile(
      controller: c,
      task: t,
      uid: widget.uid,
      showArea: filter.areaId == null,
    );
    final today = c.today;
    switch (view) {
      case TaskView.today || TaskView.overdue:
        return [for (final t in tasks) tile(t)];
      case TaskView.done:
        final widgets = <Widget>[];
        OrgDate? last;
        for (final t in tasks) {
          final day = t.doneAt == null
              ? null
              : OrgDate.of(DateTime.fromMillisecondsSinceEpoch(t.doneAt!));
          if (day != last && day != null) {
            widgets.add(
              OrgSectionTitle("Erledigt ${day.relativeLabel(today)}"),
            );
            last = day;
          }
          widgets.add(tile(t));
        }
        return widgets;
      case TaskView.upcoming:
        final widgets = <Widget>[];
        OrgDate? last;
        for (final t in tasks) {
          if (t.due != last) {
            widgets.add(OrgSectionTitle(t.due!.relativeLabel(today)));
            last = t.due;
          }
          widgets.add(tile(t));
        }
        return widgets;
      case TaskView.open:
        final groups = <String, List<OrgTask>>{
          "Überfällig": [],
          "Heute": [],
          "Diese und nächste Woche": [],
          "Später": [],
          "Ohne Datum": [],
        };
        for (final t in tasks) {
          final due = t.due;
          final key = due == null
              ? "Ohne Datum"
              : due.isBefore(today)
              ? "Überfällig"
              : due == today
              ? "Heute"
              : today.daysUntil(due) <= OrganizerController.upcomingDays
              ? "Diese und nächste Woche"
              : "Später";
          groups[key]!.add(t);
        }
        return [
          for (final e in groups.entries)
            if (e.value.isNotEmpty) ...[
              OrgSectionTitle(
                e.key,
                color: e.key == "Überfällig" ? context.colors.error : null,
              ),
              for (final t in e.value) tile(t),
            ],
        ];
    }
  }
}
