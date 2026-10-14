import 'package:flutter/material.dart';

import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/course_snapshot.dart';
import '../../models/timetable/timetable_entry.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';
import 'catalog_status.dart';
import 'conflict_views.dart';

/// Öffnet Vorschau und Korrektur vor dem Speichern (neu) bzw. das
/// Bearbeiten eines bestehenden Eintrags.
Future<void> openCourseEditor(
  BuildContext context, {
  required TimetableController controller,
  required CourseSnapshot snapshot,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) =>
        CourseEditorScreen(controller: controller, snapshot: snapshot),
  ),
);

/// Übernommene Angaben prüfen und bei Bedarf korrigieren. Korrekturen werden
/// getrennt von den importierten Daten gespeichert ([EntryOverrides]); ein
/// späterer Abgleich mit der Quelle überschreibt sie nicht.
class CourseEditorScreen extends StatefulWidget {
  final TimetableController controller;
  final CourseSnapshot snapshot;

  const CourseEditorScreen({
    super.key,
    required this.controller,
    required this.snapshot,
  });

  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _RuleDraft {
  final SnapshotRule source;
  bool shown;
  int? weekday;
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController room;

  _RuleDraft(this.source, RuleOverride? o)
    : shown = !(o?.removed ?? false),
      weekday = o?.weekday,
      start = TextEditingController(
        text: o?.startTime ?? source.rule.startTime ?? "",
      ),
      end = TextEditingController(
        text: o?.endTime ?? source.rule.endTime ?? "",
      ),
      room = TextEditingController(text: o?.room ?? source.room ?? "");

  void dispose() {
    start.dispose();
    end.dispose();
    room.dispose();
  }

  bool get weekly => source.rule.kind == RepeatKind.weekly;

  RuleOverride toOverride() {
    String? changed(String value, String? original) {
      final v = value.trim();
      return v.isEmpty || v == (original ?? "") ? null : v;
    }

    final originalDay = source.rule.weekdays.length == 1
        ? source.rule.weekdays.first
        : null;
    return RuleOverride(
      removed: !shown,
      weekday: weekly && weekday != null && weekday != originalDay
          ? weekday
          : null,
      startTime: changed(start.text, source.rule.startTime),
      endTime: changed(end.text, source.rule.endTime),
      room: changed(room.text, source.room),
    );
  }
}

class _ExtraDraft {
  final String id;
  int weekday;
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController room;

  _ExtraDraft(this.id, {this.weekday = 1, String? s, String? e, String? r})
    : start = TextEditingController(text: s ?? ""),
      end = TextEditingController(text: e ?? ""),
      room = TextEditingController(text: r ?? "");

  void dispose() {
    start.dispose();
    end.dispose();
    room.dispose();
  }
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TimetableEntry? _existing = widget.controller.entryFor(
    widget.snapshot.courseId,
    widget.snapshot.sources,
  );
  late final EntryOverrides _initial =
      _existing?.overrides ?? EntryOverrides.none;
  late final TextEditingController _title = TextEditingController(
    text: _initial.title ?? widget.snapshot.title,
  );
  late final TextEditingController _lecturers = TextEditingController(
    text: _initial.lecturers ?? widget.snapshot.lecturers.join(", "),
  );
  late final TextEditingController _note = TextEditingController(
    text: _initial.note ?? "",
  );
  late final List<_RuleDraft> _rules = [
    for (final r in widget.snapshot.rules) _RuleDraft(r, _initial.rules[r.id]),
  ];
  late final List<_ExtraDraft> _extras = [
    for (final x in _initial.extraSessions)
      _ExtraDraft(
        x.id,
        weekday: x.weekday,
        s: x.startTime,
        e: x.endTime,
        r: x.room,
      ),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _lecturers.dispose();
    _note.dispose();
    for (final r in _rules) {
      r.dispose();
    }
    for (final x in _extras) {
      x.dispose();
    }
    super.dispose();
  }

  EntryOverrides _overrides() {
    String? changed(String value, String original) {
      final v = value.trim();
      return v.isEmpty || v == original ? null : v;
    }

    return EntryOverrides(
      title: changed(_title.text, widget.snapshot.title),
      lecturers: changed(_lecturers.text, widget.snapshot.lecturers.join(", ")),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      rules: {
        for (final r in _rules)
          if (!r.toOverride().isEmpty) r.source.id: r.toOverride(),
      },
      extraSessions: [
        for (final x in _extras)
          if (validTime(x.start.text) != null && validTime(x.end.text) != null)
            ExtraSession(
              id: x.id,
              weekday: x.weekday,
              startTime: x.start.text.trim(),
              endTime: x.end.text.trim(),
              room: x.room.text.trim().isEmpty ? null : x.room.text.trim(),
            ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await widget.controller.addSnapshot(
        widget.snapshot,
        overrides: _overrides(),
      );
      if (!mounted) return;
      showSaveFeedback(
        context,
        _existing == null
            ? "Zum Stundenplan hinzugefügt."
            : "Änderungen gespeichert.",
      );
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSaveFeedback(context, saveFailedMessage);
    }
  }

  String? _validateTime(String? value, {bool required = false}) {
    final v = value?.trim() ?? "";
    if (v.isEmpty) return required ? "Uhrzeit angeben (HH:MM)" : null;
    return validTime(v) == null ? "Format HH:MM, z. B. 10:15" : null;
  }

  String? _validateRange(TextEditingController start, String? end) {
    final s = validTime(start.text);
    final e = validTime(end);
    if (s != null && e != null && s.compareTo(e) >= 0) {
      return "Ende muss nach dem Beginn liegen";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final colors = context.colors;
    final editing = _existing != null;
    final conflicts = widget.controller.conflictsFor(
      s,
      overrides: _overrides(),
    );
    final missingTimes = [
      for (final r in s.rules)
        if (r.rule.kind != RepeatKind.unknown &&
            (r.rule.startTime == null || r.rule.endTime == null))
          r,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? "Angaben bearbeiten" : "Vorschau und Korrektur"),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (editing && !_existing.overrides.isEmpty)
                _Info(
                  icon: Icons.edit_note_rounded,
                  text:
                      "Deine bisherigen Anpassungen sind eingetragen. Die "
                      "importierten Angaben bleiben unverändert gespeichert.",
                ),
              if (editing && _existing.overrides.isEmpty)
                _Info(
                  icon: Icons.check_circle_outline_rounded,
                  text:
                      "Diese Veranstaltung ist bereits in deinem Stundenplan.",
                ),
              _SourceSummary(snapshot: s),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey("edit-title"),
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "Titel",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? "Titel angeben" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey("edit-lecturers"),
                controller: _lecturers,
                decoration: InputDecoration(
                  labelText: "Dozent(en)",
                  helperText: s.lecturers.isEmpty
                      ? "In der Quelle nicht angegeben"
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  "Termine",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              if (s.rules.isEmpty)
                _Info(
                  icon: Icons.warning_amber_rounded,
                  warning: true,
                  text:
                      "Die Quelle nennt keine Termine. Du kannst unten einen "
                      "wöchentlichen Termin ergänzen.",
                ),
              if (missingTimes.isNotEmpty)
                _Info(
                  icon: Icons.warning_amber_rounded,
                  warning: true,
                  text:
                      "Bei ${missingTimes.length == 1 ? "einem Termin" : "${missingTimes.length} Terminen"} "
                      "fehlt in der Quelle die Uhrzeit – bitte ergänzen.",
                ),
              for (final (i, r) in _rules.indexed)
                _RuleCard(
                  key: ValueKey("rule-$i"),
                  draft: r,
                  occurrences: s.occurrences
                      .where((o) => o.ruleId == r.source.id)
                      .length,
                  validateTime: _validateTime,
                  validateRange: _validateRange,
                  onChanged: () => setState(() {}),
                ),
              for (final (i, x) in _extras.indexed)
                _ExtraCard(
                  key: ValueKey("extra-$i"),
                  draft: x,
                  validateTime: _validateTime,
                  validateRange: _validateRange,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() {
                    _extras.remove(x);
                    x.dispose();
                  }),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey("add-extra-session"),
                  onPressed: () => setState(
                    () => _extras.add(
                      _ExtraDraft("x${DateTime.now().microsecondsSinceEpoch}"),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Wöchentlichen Termin ergänzen"),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: "Eigene Notiz (optional)",
                  hintText: "z. B. Modul, für das du die Veranstaltung belegst",
                  border: OutlineInputBorder(),
                ),
              ),
              if (conflicts.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConflictNotice(
                  controller: widget.controller,
                  spots: conflicts,
                  candidateTitle: _title.text.trim().isEmpty
                      ? s.title
                      : _title.text.trim(),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                "Korrekturen gelten nur für deinen Stundenplan. Die Daten der "
                "Quelle bleiben unverändert gespeichert; ändert die Quelle "
                "später Termine, wirst du darauf hingewiesen.",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey("editor-save"),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(editing ? Icons.save_rounded : Icons.add_rounded),
            label: Text(
              editing ? "Änderungen speichern" : "Zum Stundenplan hinzufügen",
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceSummary extends StatelessWidget {
  final CourseSnapshot snapshot;

  const _SourceSummary({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final colors = context.colors;
    final facts = <(String, String)>[
      ("Titel", s.title),
      ("Nummer", s.number ?? "nicht angegeben"),
      ("Typ", courseTypeLabel(s.type)),
      ("Fakultät", s.faculty ?? "nicht angegeben"),
      if (s.institute != null) ("Einrichtung", s.institute!),
      (
        "Dozent",
        s.lecturers.isEmpty ? "nicht angegeben" : s.lecturers.join(", "),
      ),
      ("Semester", s.semester?.label ?? s.semesterId),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Übernommen aus UnivIS",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        label,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: value == "nicht angegeben"
                            ? TextStyle(
                                color: colors.textSecondary,
                                fontStyle: FontStyle.italic,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final _RuleDraft draft;
  final int occurrences;
  final String? Function(String?, {bool required}) validateTime;
  final String? Function(TextEditingController, String?) validateRange;
  final VoidCallback onChanged;

  const _RuleCard({
    super.key,
    required this.draft,
    required this.occurrences,
    required this.validateTime,
    required this.validateRange,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = draft.source.rule;
    final needsTime = r.startTime == null || r.endTime == null;
    final editable = r.kind != RepeatKind.unknown;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.shown,
              onChanged: (v) {
                draft.shown = v;
                onChanged();
              },
              title: Text(
                r.kind == RepeatKind.weekly
                    ? "Regelmäßiger Termin"
                    : "Block- bzw. Einzeltermin",
              ),
              subtitle: Text(
                "Laut Quelle: ${describeSessionRule(draft.source.rule)}"
                "${draft.source.room == null ? "" : " · ${draft.source.room}"}"
                "${occurrences > 0 ? " · $occurrences Termine" : ""}",
              ),
            ),
            if (draft.shown && editable) ...[
              if (r.kind == RepeatKind.weekly && r.weekdays.length <= 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        draft.weekday ??
                        (r.weekdays.isEmpty ? null : r.weekdays.first),
                    decoration: const InputDecoration(
                      labelText: "Wochentag",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(value: d, child: Text(weekdayName(d))),
                    ],
                    validator: (v) => v == null ? "Wochentag wählen" : null,
                    onChanged: (v) {
                      draft.weekday = v;
                      onChanged();
                    },
                  ),
                ),
              _TimeRow(
                start: draft.start,
                end: draft.end,
                required: needsTime,
                validateTime: validateTime,
                validateRange: validateRange,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.room,
                decoration: const InputDecoration(
                  labelText: "Raum",
                  border: OutlineInputBorder(),
                ),
              ),
              if ((r.intervalWeeks ?? 1) > 1 && occurrences == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Bei 14-täglichen Terminen ohne Startwoche können keine "
                    "Daten berechnet werden – bitte in UnivIS prüfen.",
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExtraCard extends StatelessWidget {
  final _ExtraDraft draft;
  final String? Function(String?, {bool required}) validateTime;
  final String? Function(TextEditingController, String?) validateRange;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ExtraCard({
    super.key,
    required this.draft,
    required this.validateTime,
    required this.validateRange,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Eigener wöchentlicher Termin",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: "Termin entfernen",
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onRemove,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: draft.weekday,
                    decoration: const InputDecoration(
                      labelText: "Wochentag",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(value: d, child: Text(weekdayName(d))),
                    ],
                    onChanged: (v) {
                      if (v != null) draft.weekday = v;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  _TimeRow(
                    start: draft.start,
                    end: draft.end,
                    required: true,
                    validateTime: validateTime,
                    validateRange: validateRange,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: draft.room,
                    decoration: const InputDecoration(
                      labelText: "Raum (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final TextEditingController start;
  final TextEditingController end;
  final bool required;
  final String? Function(String?, {bool required}) validateTime;
  final String? Function(TextEditingController, String?) validateRange;

  const _TimeRow({
    required this.start,
    required this.end,
    required this.required,
    required this.validateTime,
    required this.validateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 140,
          child: TextFormField(
            controller: start,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: "Beginn",
              hintText: "10:15",
              border: OutlineInputBorder(),
            ),
            validator: (v) => validateTime(v, required: required),
          ),
        ),
        SizedBox(
          width: 140,
          child: TextFormField(
            controller: end,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: "Ende",
              hintText: "11:45",
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                validateTime(v, required: required) ?? validateRange(start, v),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;

  const _Info({required this.icon, required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? colors.errorBackground : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: warning ? colors.error : colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
