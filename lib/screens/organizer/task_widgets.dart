import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/learning_signals.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../services/organizer/reading_tasks.dart';
import '../../theme/app_theme.dart';
import '../bible/course_reading_plan_screen.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';

/// Eine Aufgabe in einer Liste: ein Tipp auf den Kreis hakt ab, ein Tipp
/// auf den Text öffnet sie, das Menü verschiebt.
class TaskTile extends StatelessWidget {
  final OrganizerController controller;
  final OrgTask task;
  final String? uid;

  /// Zuordnung nicht anzeigen (z. B. auf der Seite der Zuordnung selbst).
  final bool showArea;

  const TaskTile({
    super.key,
    required this.controller,
    required this.task,
    required this.uid,
    this.showArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = controller.today;
    final done = controller.isDone(task);
    final auto = done && !task.done;
    final overdue = !done && task.isOverdue(today);
    final event = task.eventId == null ? null : controller.event(task.eventId!);
    final area = controller.area(task.areaId);
    final meta = <Widget>[
      if (task.due != null)
        Text(
          [task.due!.relativeLabel(today), ?task.dueTime?.key].join(", "),
          style: TextStyle(
            fontSize: 12,
            color: overdue ? colors.error : colors.textSecondary,
            fontWeight: overdue ? FontWeight.w600 : null,
          ),
        ),
      if (showArea && area != null) AreaLabel(area: area),
      if (event != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded, size: 13, color: colors.textSecondary),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                event.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ),
          ],
        ),
      if (task.repeat != null)
        Icon(Icons.repeat_rounded, size: 14, color: colors.textSecondary),
      if (task.links.isNotEmpty ||
          controller.notesLinkedTo("task", task.id).isNotEmpty)
        Icon(Icons.link_rounded, size: 14, color: colors.textSecondary),
      if (auto)
        Text(
          "Tagesziel in ${StreakLearningSignals.track(task.trackId!)?.label ?? "Lernbereich"} erreicht",
          style: TextStyle(fontSize: 12, color: colors.success),
        ),
    ];
    return ListTile(
      key: ValueKey("task-${task.id}"),
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      leading: IconButton(
        key: ValueKey("toggle-${task.id}"),
        tooltip: done ? "Als offen markieren" : "Abhaken",
        icon: Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done
              ? colors.success
              : task.priority == OrgPriority.high
              ? colors.error
              : colors.primary,
        ),
        onPressed: auto ? null : () => controller.toggleTask(task),
      ),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? colors.textSecondary : null,
        ),
      ),
      subtitle: meta.isEmpty
          ? null
          : Wrap(
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: meta,
            ),
      onTap: () => openTaskEditor(context, controller, uid: uid, task: task),
      trailing: PopupMenuButton<String>(
        tooltip: "Verschieben oder löschen",
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (v) async {
          switch (v) {
            case "today":
              controller.moveTask(task, today);
            case "tomorrow":
              controller.moveTask(task, today.addDays(1));
            case "week":
              controller.moveTask(task, today.startOfWeek.addDays(7));
            case "none":
              controller.moveTask(task, null);
            case "pick":
              final d = await pickDate(
                context,
                initial: task.due,
                today: today,
              );
              if (d != null) controller.moveTask(task, d);
            case "delete":
              await deleteTaskWithUndo(context, controller, task);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: "today", child: Text("Auf heute")),
          PopupMenuItem(value: "tomorrow", child: Text("Auf morgen")),
          PopupMenuItem(value: "week", child: Text("Auf nächsten Montag")),
          PopupMenuItem(value: "pick", child: Text("Datum wählen …")),
          PopupMenuItem(value: "none", child: Text("Ohne Datum")),
          PopupMenuItem(value: "delete", child: Text("Löschen")),
        ],
      ),
    );
  }
}

Future<void> deleteTaskWithUndo(
  BuildContext context,
  OrganizerController controller,
  OrgTask task,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await controller.deleteTask(task);
  messenger.showSnackBar(
    SnackBar(
      content: Text("„${task.title}“ gelöscht"),
      action: SnackBarAction(
        label: "Rückgängig",
        onPressed: () => controller.task(task.id) == null
            ? controller.restoreTask(task)
            : null,
      ),
    ),
  );
}

/// Heutiges Pensum eines Leseplans: abgehakt wird nur über den
/// Lesefortschritt (Reader bzw. Leseplan), nie hier.
class ReadingTaskTile extends StatelessWidget {
  final ReadingTask task;
  final String? uid;

  const ReadingTaskTile({super.key, required this.task, required this.uid});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = task.done;
    final open = [
      for (final p in task.pieces)
        if (!p.done) p,
    ];
    return ListTile(
      key: ValueKey("reading-${task.key}"),
      contentPadding: const EdgeInsets.only(left: 4, right: 8),
      leading: IconButton(
        tooltip: done
            ? "Gelesen (aus dem Leseplan)"
            : "Wird erledigt, sobald die Kapitel im Leseplan gelesen sind",
        icon: Icon(
          done ? Icons.check_circle_rounded : Icons.menu_book_rounded,
          color: done
              ? colors.success
              : task.overdue
              ? colors.error
              : colors.primary,
        ),
        onPressed: () => _explain(context),
      ),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? colors.textSecondary : null,
        ),
      ),
      subtitle: Text(
        [
          task.planName,
          ?task.session,
          "${task.doneCount} von ${task.pieces.length} gelesen",
        ].join(" · "),
        style: TextStyle(
          fontSize: 12,
          color: task.overdue && !done ? colors.error : colors.textSecondary,
        ),
      ),
      trailing: done
          ? null
          : TextButton(
              onPressed: () => openCourseReading(
                context,
                uid: uid,
                planId: task.planId,
                pieces: open,
                title: task.overdue ? "Nachholen" : "Heute",
              ),
              child: const Text("Lesen"),
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CourseReadingPlanScreen(uid: uid, planId: task.planId),
        ),
      ),
    );
  }

  void _explain(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              "Diese Aufgabe kommt aus deinem Leseplan. Sie ist erledigt, "
              "sobald du die Kapitel im Reader oder im Leseplan als gelesen "
              "markierst. Hier lässt sie sich nicht abhaken, damit kein "
              "Kapitel als gelesen gilt, das du noch nicht gelesen hast.",
            ),
            const SizedBox(height: 12),
            for (final p in task.pieces)
              Row(
                children: [
                  Icon(
                    p.done ? Icons.check_rounded : Icons.circle_outlined,
                    size: 16,
                    color: p.done
                        ? sheet.colors.success
                        : sheet.colors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(p.label),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!task.done)
                  FilledButton.icon(
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text("Jetzt lesen"),
                    onPressed: () {
                      Navigator.pop(sheet);
                      openCourseReading(
                        context,
                        uid: uid,
                        planId: task.planId,
                        pieces: [
                          for (final p in task.pieces)
                            if (!p.done) p,
                        ],
                        title: task.overdue ? "Nachholen" : "Heute",
                      );
                    },
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CourseReadingPlanScreen(
                          uid: uid,
                          planId: task.planId,
                        ),
                      ),
                    );
                  },
                  child: const Text("Leseplan öffnen"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Schnell eintragen: Titel, Enter – fällig heute, morgen oder ohne Datum.
class QuickTaskField extends StatefulWidget {
  final OrganizerController controller;
  final String? areaId;
  final OrgDate? defaultDue;

  const QuickTaskField({
    super.key,
    required this.controller,
    this.areaId,
    this.defaultDue,
  });

  @override
  State<QuickTaskField> createState() => _QuickTaskFieldState();
}

class _QuickTaskFieldState extends State<QuickTaskField> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  late int _when = widget.defaultDue == null ? 2 : 0;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final title = _text.text.trim();
    if (title.isEmpty) return;
    final today = widget.controller.today;
    widget.controller.newTask(
      title: title,
      due: switch (_when) {
        0 => widget.defaultDue ?? today,
        1 => today.addDays(1),
        _ => null,
      },
      areaId: widget.areaId,
    );
    _text.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final todayLabel =
        widget.defaultDue == null ||
            widget.defaultDue == widget.controller.today
        ? "Heute"
        : widget.defaultDue!.label();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey("quick-task"),
            controller: _text,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "Neue Aufgabe …",
              prefixIcon: const Icon(Icons.add_task_rounded),
              suffixIcon: IconButton(
                tooltip: "Hinzufügen",
                icon: const Icon(Icons.send_rounded),
                onPressed: _add,
              ),
              isDense: true,
            ),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final (i, label) in [
                todayLabel,
                "Morgen",
                "Ohne Datum",
              ].indexed)
                ChoiceChip(
                  label: Text(label),
                  selected: _when == i,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _when = i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aufgabe bearbeiten bzw. neu anlegen.
class TaskEditorSheet extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;
  final OrgTask? task;
  final OrgDate? due;
  final String? areaId;
  final String? eventId;

  const TaskEditorSheet({
    super.key,
    required this.controller,
    required this.uid,
    this.task,
    this.due,
    this.areaId,
    this.eventId,
  });

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  OrganizerController get c => widget.controller;
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? "",
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.task?.notes ?? "",
  );
  late OrgDate? _due = widget.task?.due ?? widget.due;
  late OrgTime? _time = widget.task?.dueTime;
  late String? _area = widget.task?.areaId ?? widget.areaId;
  late OrgPriority _priority = widget.task?.priority ?? OrgPriority.normal;
  late TaskRepeat? _repeat = widget.task?.repeat;
  late String? _track = widget.task?.trackId;
  late String? _event = widget.task?.eventId ?? widget.eventId;
  late List<OrgLink> _links = [...?widget.task?.links];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isNew => widget.task == null;

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_isNew) {
      c.newTask(
        title: title,
        notes: _notes.text,
        due: _due,
        dueTime: _time,
        areaId: _area,
        priority: _priority,
        eventId: _event,
        links: _links,
        repeat: _repeat,
        trackId: _track,
      );
    } else {
      final t = c.task(widget.task!.id) ?? widget.task!;
      c.saveTask(
        t.copyWith(
          title: title,
          notes: _notes.text,
          due: _due,
          clearDue: _due == null,
          dueTime: _time,
          clearDueTime: _time == null,
          areaId: _area,
          clearArea: _area == null,
          priority: _priority,
          eventId: _event,
          clearEvent: _event == null,
          links: _links,
          repeat: _repeat,
          clearRepeat: _repeat == null,
          trackId: _track,
          clearTrack: _track == null,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final today = c.today;
    final area = c.area(_area);
    final events = [
      for (final i in c.upcomingItems(days: 365))
        if (i.event != null) i.event!,
    ];
    final eventIds = <String>{};
    final eventChoices = [
      for (final e in events)
        if (eventIds.add(e.id)) e,
      if (_event != null &&
          !eventIds.contains(_event) &&
          c.event(_event!) != null)
        c.event(_event!)!,
    ];
    final notes = widget.task == null
        ? const <OrgNote>[]
        : c.notesLinkedTo("task", widget.task!.id, own: _links);
    final source = widget.task?.source;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isNew ? "Neue Aufgabe" : "Aufgabe",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!_isNew)
                  IconButton(
                    tooltip: "Löschen",
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      Navigator.pop(context);
                      deleteTaskWithUndo(context, c, widget.task!);
                    },
                  ),
                FilledButton(
                  key: const ValueKey("task-save"),
                  onPressed: _save,
                  child: const Text("Speichern"),
                ),
              ],
            ),
            if (source != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  source.edited
                      ? "Aus einem Seminarplan übernommen, von dir bearbeitet – "
                            "ein erneuter Abgleich überschreibt nichts."
                      : "Aus einem Seminarplan übernommen.",
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            TextField(
              key: const ValueKey("task-title"),
              controller: _title,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: "Titel"),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Beschreibung (optional)",
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.event_available_rounded, size: 20),
                ChoiceChip(
                  label: const Text("Ohne Datum"),
                  selected: _due == null,
                  onSelected: (_) => setState(() {
                    _due = null;
                    _time = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text("Heute"),
                  selected: _due == today,
                  onSelected: (_) => setState(() => _due = today),
                ),
                ChoiceChip(
                  label: const Text("Morgen"),
                  selected: _due == today.addDays(1),
                  onSelected: (_) => setState(() => _due = today.addDays(1)),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(
                    _due != null && _due != today && _due != today.addDays(1)
                        ? _due!.label(year: _due!.year != today.year)
                        : "Datum …",
                  ),
                  onPressed: () async {
                    final d = await pickDate(
                      context,
                      initial: _due,
                      today: today,
                    );
                    if (d != null) setState(() => _due = d);
                  },
                ),
                if (_due != null)
                  ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_time?.key ?? "Uhrzeit"),
                    onPressed: () async {
                      final t = await pickTime(context, initial: _time);
                      setState(() => _time = t);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.label_outline_rounded),
              title: Text(area?.name ?? "Zuordnung wählen"),
              subtitle: const Text("Lehrveranstaltung oder Bereich"),
              onTap: () async {
                final id = await pickArea(context, c, current: _area);
                if (id != null) setState(() => _area = id.isEmpty ? null : id);
              },
            ),
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<OrgPriority>(
                    showSelectedIcon: false,
                    segments: [
                      for (final p in OrgPriority.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (s) =>
                        setState(() => _priority = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text("Mehr: Wiederholung, Lernbereich, Termin"),
              initiallyExpanded:
                  _repeat != null || _track != null || _event != null,
              children: [
                DropdownButtonFormField<TaskRepeat?>(
                  initialValue: _repeat,
                  decoration: const InputDecoration(
                    labelText: "Wiederholen",
                    prefixIcon: Icon(Icons.repeat_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Nicht")),
                    for (final r in TaskRepeat.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                  onChanged: (v) => setState(() {
                    _repeat = v;
                    if (v != null && _due == null) _due = today;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _track,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Lernbereich (erledigt mit dem Tagesziel)",
                    prefixIcon: Icon(Icons.local_fire_department_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Keiner")),
                    for (final t in StreakLearningSignals.tracks)
                      DropdownMenuItem(value: t.id, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() {
                    _track = v;
                    if (v != null && _due == null) _due = today;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _event,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Gehört zu Termin",
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Keinem")),
                    for (final e in eventChoices)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          "${e.title} (${e.date.label()})",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _event = v),
                ),
                const SizedBox(height: 8),
              ],
            ),
            Row(
              children: [
                Text(
                  "Verknüpfungen",
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text("Verknüpfen"),
                  onPressed: () async {
                    final l = await pickLink(
                      context,
                      c,
                      excludeId: widget.task?.id,
                    );
                    if (l != null && !_links.any(l.sameTarget)) {
                      setState(() => _links = [..._links, l]);
                    }
                  },
                ),
              ],
            ),
            LinkChips(
              links: [
                ..._links,
                for (final n in notes)
                  if (!_links.any((l) => l.type == "note" && l.target == n.id))
                    OrgLink(type: "note", target: n.id, label: n.displayTitle),
              ],
              onOpen: (l) => openLink(context, c, uid: widget.uid, link: l),
              onRemove: (l) => setState(
                () => _links = [
                  for (final x in _links)
                    if (!x.sameTarget(l)) x,
                ],
              ),
            ),
            if (!_isNew)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text("Notiz zur Aufgabe"),
                  onPressed: () {
                    final t = widget.task!;
                    Navigator.pop(context);
                    openNoteEditor(
                      context,
                      c,
                      uid: widget.uid,
                      areaId: _area,
                      links: [
                        OrgLink(type: "task", target: t.id, label: t.title),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
