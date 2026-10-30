import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../services/organizer/recurrence.dart';
import '../../theme/app_theme.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';
import 'task_widgets.dart';

/// Erinnerungen in Minuten vor Beginn.
const List<(int?, String)> reminderChoices = [
  (null, "Keine"),
  (0, "Zu Beginn"),
  (15, "15 Minuten vorher"),
  (60, "1 Stunde vorher"),
  (24 * 60, "1 Tag vorher"),
  (3 * 24 * 60, "3 Tage vorher"),
  (7 * 24 * 60, "1 Woche vorher"),
];

/// Termin anlegen oder bearbeiten. Pflicht ist nur der Titel; alles andere
/// hat sinnvolle Vorgaben (heute, ganztägig, keine Wiederholung).
class EventEditorScreen extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;
  final OrgEvent? event;

  /// Vorgabe für einen neuen Termin.
  final OrgDate? date;

  /// Bei wiederkehrenden Terminen: das angetippte Vorkommen.
  final OrgDate? occurrence;
  final String? areaId;
  final String? typeId;

  const EventEditorScreen({
    super.key,
    required this.controller,
    required this.uid,
    this.event,
    this.date,
    this.occurrence,
    this.areaId,
    this.typeId,
  });

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  OrganizerController get c => widget.controller;
  OrgEvent? get e => widget.event;

  late final TextEditingController _title = TextEditingController(
    text: e?.title ?? "",
  );
  late final TextEditingController _location = TextEditingController(
    text: e?.location ?? "",
  );
  late final TextEditingController _description = TextEditingController(
    text: e?.description ?? "",
  );
  late OrgDate _date = widget.occurrence ?? e?.date ?? widget.date ?? c.today;
  late OrgDate? _endDate = e?.endDate == null
      ? null
      : _date.addDays(e!.spanDays);
  late bool _allDay = e?.allDay ?? true;
  late OrgTime? _start = e?.start;
  late OrgTime? _end = e?.end;
  late String _type = e?.typeId ?? widget.typeId ?? OrgEventType.other.id;
  late String? _area = e?.areaId ?? widget.areaId;
  late int? _reminder = e?.reminderMinutes;
  late Recurrence? _recurrence = e?.recurrence;
  late List<OrgLink> _links = [...?e?.links];

  bool get _isNew => e == null;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  OrgEvent _build(OrgEvent base) => base.copyWith(
    title: _title.text.trim(),
    date: _date,
    endDate: _allDay ? _endDate : null,
    clearEndDate: !_allDay || _endDate == null || !_endDate!.isAfter(_date),
    allDay: _allDay || _start == null,
    start: _start,
    end: _end,
    clearTimes: _allDay || _start == null,
    location: _location.text.trim(),
    description: _description.text,
    typeId: _type,
    areaId: _area,
    clearArea: _area == null,
    reminderMinutes: _reminder,
    clearReminder: _reminder == null,
    recurrence: _recurrence,
    clearRecurrence: _recurrence == null,
    links: _links,
  );

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bitte einen Titel eingeben.")),
      );
      return;
    }
    final navigator = Navigator.of(context);
    if (_isNew) {
      c.newEvent(
        title: _title.text,
        date: _date,
        endDate: _allDay && _endDate != null && _endDate!.isAfter(_date)
            ? _endDate
            : null,
        start: _allDay ? null : _start,
        end: _allDay ? null : _end,
        location: _location.text.trim(),
        description: _description.text,
        typeId: _type,
        areaId: _area,
        reminderMinutes: _reminder,
        recurrence: _recurrence,
        links: _links,
      );
      navigator.pop();
      return;
    }
    final current = c.event(e!.id) ?? e!;
    final occ = widget.occurrence;
    if (current.recurrence != null && occ != null) {
      final scope = await _askScope("Änderung übernehmen für");
      if (scope == null) return;
      if (scope == "one") {
        final single = c.detachOccurrence(current, occ);
        await c.saveEvent(
          _build(single).copyWith(clearRecurrence: true, date: _date),
        );
        navigator.pop();
        return;
      }
      // Alle: Verschiebung des Vorkommens auf die Serie übertragen.
      final shift = occ.daysUntil(_date);
      await c.saveEvent(
        _build(current).copyWith(date: current.date.addDays(shift)),
      );
      navigator.pop();
      return;
    }
    await c.saveEvent(_build(current));
    navigator.pop();
  }

  Future<String?> _askScope(String title, {bool following = false}) {
    return showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(title),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, "one"),
            child: const Text("Nur diesen Termin"),
          ),
          if (following)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, "following"),
              child: const Text("Diesen und alle folgenden"),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, "all"),
            child: const Text("Alle Termine der Serie"),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final current = c.event(e!.id) ?? e!;
    final navigator = Navigator.of(context);
    final occ = widget.occurrence ?? current.date;
    if (current.recurrence != null) {
      final scope = await _askScope("Löschen", following: true);
      if (scope == null) return;
      switch (scope) {
        case "one":
          await c.skipOccurrence(current, occ);
        case "following":
          await c.endSeriesBefore(current, occ);
        default:
          await c.deleteEvent(current);
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text("Termin löschen?"),
          content: Text(
            c.tasksOfEvent(current.id).isEmpty
                ? "„${current.title}“ wird gelöscht."
                : "„${current.title}“ wird gelöscht. Die zugehörigen Aufgaben "
                      "bleiben erhalten.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text("Abbrechen"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text("Löschen"),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await c.deleteEvent(current);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = c.today;
    final types = c.config.types;
    final area = c.area(_area);
    final type = c.config.type(_type);
    final tasks = _isNew ? const <OrgTask>[] : c.tasksOfEvent(e!.id);
    final notes = _isNew
        ? const <OrgNote>[]
        : c.notesLinkedTo("event", e!.id, own: _links);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? "Neuer Termin" : "Termin"),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: "Löschen",
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              key: const ValueKey("event-save"),
              onPressed: _save,
              child: const Text("Speichern"),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (e?.source != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      e!.source!.edited
                          ? "Aus einem Seminarplan übernommen, von dir bearbeitet."
                          : "Aus einem Seminarplan übernommen.",
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                TextField(
                  key: const ValueKey("event-title"),
                  controller: _title,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: "Titel"),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final t in types)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t.id,
                        avatar: t.important && _type != t.id
                            ? Icon(
                                Icons.priority_high_rounded,
                                size: 16,
                                color: context.colors.error,
                              )
                            : null,
                        onSelected: (_) => setState(() => _type = t.id),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("Eigene Art"),
                      onPressed: _addType,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_outline_rounded),
                  title: Text(area?.name ?? "Zuordnung wählen"),
                  subtitle: const Text("Lehrveranstaltung oder Bereich"),
                  onTap: () async {
                    final id = await pickArea(context, c, current: _area);
                    if (id != null) {
                      setState(() => _area = id.isEmpty ? null : id);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Ganztägig"),
                  value: _allDay,
                  onChanged: (v) => setState(() {
                    _allDay = v;
                    if (!v && _start == null) {
                      _start = OrgTime.hm(10, 15);
                      _end = OrgTime.hm(11, 45);
                    }
                  }),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey("event-date"),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(_date.label(year: true)),
                      onPressed: () async {
                        final d = await pickDate(
                          context,
                          initial: _date,
                          today: today,
                        );
                        if (d != null) {
                          setState(() {
                            final span = _endDate == null
                                ? null
                                : _date.daysUntil(_endDate!);
                            _date = d;
                            if (span != null) _endDate = d.addDays(span);
                          });
                        }
                      },
                    ),
                    if (_allDay)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(
                          _endDate == null
                              ? "Mehrtägig …"
                              : "bis ${_endDate!.label(year: true)}",
                        ),
                        onPressed: () async {
                          final d = await pickDate(
                            context,
                            initial: _endDate ?? _date.addDays(1),
                            today: today,
                          );
                          if (d != null) {
                            setState(
                              () => _endDate = d.isAfter(_date) ? d : null,
                            );
                          }
                        },
                      ),
                    if (!_allDay) ...[
                      OutlinedButton(
                        key: const ValueKey("event-start"),
                        onPressed: () async {
                          final t = await pickTime(
                            context,
                            initial: _start,
                            title: "Beginn",
                          );
                          if (t != null) {
                            setState(() {
                              final len = _start != null && _end != null
                                  ? _end!.minutes - _start!.minutes
                                  : 90;
                              _start = t;
                              final endMin = t.minutes + len;
                              _end = endMin < 24 * 60 ? OrgTime(endMin) : null;
                            });
                          }
                        },
                        child: Text("Beginn ${_start?.key ?? "–"}"),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final t = await pickTime(
                            context,
                            initial: _end,
                            title: "Ende",
                          );
                          if (t != null &&
                              (_start == null || t.minutes > _start!.minutes)) {
                            setState(() => _end = t);
                          }
                        },
                        child: Text("Ende ${_end?.key ?? "–"}"),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _RecurrenceField(
                  value: _recurrence,
                  start: _date,
                  today: today,
                  onChanged: (r) => setState(() => _recurrence = r),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: "Ort",
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: "Beschreibung"),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: reminderChoices.any((r) => r.$1 == _reminder)
                      ? _reminder
                      : null,
                  decoration: const InputDecoration(
                    labelText: "Erinnerung (in der App)",
                    prefixIcon: Icon(Icons.notifications_none_rounded),
                  ),
                  items: [
                    for (final (m, label) in reminderChoices)
                      DropdownMenuItem(value: m, child: Text(label)),
                  ],
                  onChanged: (v) => setState(() => _reminder = v),
                ),
                if (_reminder != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Die Erinnerung erscheint in der Übersicht der "
                      "Studiumsorganisation (keine Push-Nachricht).",
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                if (!_isNew) ...[
                  OrgSectionTitle(
                    type.important ? "Vorbereitung" : "Aufgaben zum Termin",
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Aufgabe"),
                      onPressed: () => openTaskEditor(
                        context,
                        c,
                        uid: widget.uid,
                        eventId: e!.id,
                        areaId: _area,
                        due: _date.isBefore(today) ? today : _date.addDays(-1),
                      ),
                    ),
                  ),
                  if (type.important)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey("plan-study"),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text("Lernaufgaben planen"),
                        onPressed: () =>
                            planStudyTasks(context, c, c.event(e!.id) ?? e!),
                      ),
                    ),
                  for (final t in tasks)
                    TaskTile(controller: c, task: t, uid: widget.uid),
                ],
                OrgSectionTitle(
                  "Verknüpfungen",
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text("Verknüpfen"),
                    onPressed: () async {
                      final l = await pickLink(context, c, excludeId: e?.id);
                      if (l != null && !_links.any(l.sameTarget)) {
                        setState(() => _links = [..._links, l]);
                      }
                    },
                  ),
                ),
                LinkChips(
                  links: [
                    ..._links,
                    for (final n in notes)
                      if (!_links.any(
                        (l) => l.type == "note" && l.target == n.id,
                      ))
                        OrgLink(
                          type: "note",
                          target: n.id,
                          label: n.displayTitle,
                        ),
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
                      label: const Text("Notiz zum Termin"),
                      onPressed: () => openNoteEditor(
                        context,
                        c,
                        uid: widget.uid,
                        areaId: _area,
                        links: [
                          OrgLink(
                            type: "event",
                            target: e!.id,
                            label: "${e!.title} (${e!.date.label()})",
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addType() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text("Eigene Terminart"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "z. B. Sprechstunde"),
          onSubmitted: (v) => Navigator.pop(dialog, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text("Anlegen"),
          ),
        ],
      ),
    );
    if (label == null || label.trim().isEmpty) return;
    final type = c.addEventType(label);
    setState(() => _type = type.id);
  }
}

class _RecurrenceField extends StatelessWidget {
  final Recurrence? value;
  final OrgDate start;
  final OrgDate today;
  final ValueChanged<Recurrence?> onChanged;

  const _RecurrenceField({
    required this.value,
    required this.start,
    required this.today,
    required this.onChanged,
  });

  static const List<(String, RecurrenceFreq?, int)> _choices = [
    ("Einmalig", null, 1),
    ("Täglich", RecurrenceFreq.daily, 1),
    ("Wöchentlich", RecurrenceFreq.weekly, 1),
    ("14-täglich", RecurrenceFreq.weekly, 2),
    ("Monatlich", RecurrenceFreq.monthly, 1),
    ("Jährlich", RecurrenceFreq.yearly, 1),
  ];

  @override
  Widget build(BuildContext context) {
    final r = value;
    var index = 0;
    for (final (i, (_, f, n)) in _choices.indexed) {
      if (r?.freq == f && (r?.interval ?? 1) == n) index = i;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: index,
          decoration: const InputDecoration(
            labelText: "Wiederholung",
            prefixIcon: Icon(Icons.repeat_rounded),
          ),
          items: [
            for (final (i, (label, _, _)) in _choices.indexed)
              DropdownMenuItem(value: i, child: Text(label)),
          ],
          onChanged: (i) {
            final (_, freq, n) = _choices[i ?? 0];
            onChanged(
              freq == null
                  ? null
                  : Recurrence(
                      freq: freq,
                      interval: n,
                      until: r?.until,
                      exceptions: r?.exceptions ?? const {},
                    ),
            );
          },
        ),
        if (r != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_busy_outlined),
                  label: Text(
                    r.until == null
                        ? "Ohne Ende"
                        : "bis ${r.until!.label(year: true)}",
                  ),
                  onPressed: () async {
                    final d = await pickDate(
                      context,
                      initial: r.until ?? start.addMonths(3),
                      today: today,
                    );
                    if (d != null) onChanged(r.copyWith(until: d));
                  },
                ),
                if (r.until != null)
                  TextButton(
                    onPressed: () => onChanged(r.copyWith(clearUntil: true)),
                    child: const Text("Ende entfernen"),
                  ),
                if (r.exceptions.isNotEmpty)
                  Text(
                    "${r.exceptions.length} ausgelassen",
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lernplanung zu einer Prüfung oder Abgabe: Vorschläge, die man vor dem
/// Anlegen abwählen, umbenennen und datieren kann.
Future<void> planStudyTasks(
  BuildContext context,
  OrganizerController c,
  OrgEvent event,
) async {
  final today = c.today;
  final deadline = event.typeId == OrgEventType.deadline.id;
  final area = c.area(event.areaId);
  final language =
      area?.appLink == "/greek" ||
      area?.appLink == "/latin" ||
      RegExp(
        r"griech|latein",
        caseSensitive: false,
      ).hasMatch("${event.title} ${area?.name ?? ""}");
  final suggestions = <(String, int)>[
    if (deadline) ...[
      ("Gliederung erstellen", 21),
      ("Literatur sichten", 14),
      ("Rohfassung schreiben", 7),
      ("Korrektur lesen und formatieren", 2),
    ] else ...[
      ("Stoff zusammenfassen", 14),
      if (language) ("Vokabeln wiederholen", 10),
      if (language) ("Grammatik wiederholen", 7),
      ("Probeklausur bearbeiten", 3),
      ("Offene Fragen klären", 2),
    ],
  ];
  OrgDate dueFor(int days) {
    final d = event.date.addDays(-days);
    return d.isBefore(today) ? today : d;
  }

  final titles = [
    for (final (t, _) in suggestions) TextEditingController(text: t),
  ];
  final selected = List<bool>.filled(suggestions.length, true);
  final dues = [for (final (_, days) in suggestions) dueFor(days)];

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(deadline ? "Abgabe vorbereiten" : "Lernplanung"),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Aufgaben bis ${event.date.label(year: true)} – "
                  "verknüpft mit „${event.title}“.",
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < suggestions.length; i++)
                  Row(
                    children: [
                      Checkbox(
                        value: selected[i],
                        onChanged: (v) =>
                            setState(() => selected[i] = v ?? false),
                      ),
                      Expanded(
                        child: TextField(
                          controller: titles[i],
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await pickDate(
                            dialog,
                            initial: dues[i],
                            today: today,
                          );
                          if (d != null) setState(() => dues[i] = d);
                        },
                        child: Text(dues[i].label()),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text("Anlegen"),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    for (var i = 0; i < suggestions.length; i++) {
      if (!selected[i] || titles[i].text.trim().isEmpty) continue;
      c.newTask(
        title: titles[i].text,
        due: dues[i],
        areaId: event.areaId,
        eventId: event.id,
        priority: i == suggestions.length - 1
            ? OrgPriority.high
            : OrgPriority.normal,
      );
    }
  }
}
