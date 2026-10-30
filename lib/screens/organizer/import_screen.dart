import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/import_sources.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../services/organizer/seminar_import.dart';
import '../../theme/app_theme.dart';
import 'organizer_widgets.dart';

/// Seminarpläne übernehmen: bekannte Pläne der App und eingefügte Texte.
class ImportScreen extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;

  /// Für Tests: feste Quellen statt [ImportSources.load].
  final Future<List<ImportSource>> Function()? sources;

  const ImportScreen({
    super.key,
    required this.controller,
    required this.uid,
    this.sources,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  OrganizerController get c => widget.controller;
  List<ImportSource>? _sources;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list =
        await (widget.sources?.call() ??
            ImportSources.load(c, uid: widget.uid));
    if (mounted) setState(() => _sources = list);
  }

  Future<void> _open(ImportSource source) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportPreviewScreen(controller: c, source: source),
      ),
    );
    _reload();
  }

  Future<void> _paste() async {
    final id = OrgIds.create("text", now: c.now);
    final source = ImportSources.textSource(
      id,
      const ImportSettings(),
      c.today,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImportPreviewScreen(controller: c, source: source, editText: true),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;
    return Scaffold(
      appBar: AppBar(title: const Text("Seminarpläne übernehmen")),
      body: sources == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: c,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Aus einem Seminarplan werden Sitzungstermine, "
                      "Vorbereitungsaufgaben, Abgaben und Prüfungen erkannt – "
                      "nicht der ganze Text. Du siehst alles vorher und "
                      "entscheidest, was übernommen wird. Ein erneuter "
                      "Abgleich legt nichts doppelt an und überschreibt weder "
                      "Erledigtes noch selbst Bearbeitetes.",
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                  for (final s in sources) _tile(context, s),
                  ListTile(
                    key: const ValueKey("paste-plan"),
                    leading: const Icon(Icons.content_paste_rounded),
                    title: const Text("Seminarplan einfügen"),
                    subtitle: const Text(
                      "Text aus einem PDF oder einer E-Mail kopieren",
                    ),
                    onTap: _paste,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, ImportSource source) {
    final settings = ImportSettings.fromMap(c.importSettings(source.sourceId));
    final diff = SeminarImporter.diff(
      source.build(settings),
      tasks: c.rawTasks,
      events: c.rawEvents,
      today: c.today,
    );
    final imported =
        diff.count(ImportStatus.unchanged) +
        diff.count(ImportStatus.changed) +
        diff.count(ImportStatus.conflict);
    final news = diff.changes
        .where((x) => x.suggested && x.status != ImportStatus.unchanged)
        .length;
    final auto = c.config.autoImports.contains(source.sourceId);
    return ListTile(
      key: ValueKey("source-${source.sourceId}"),
      leading: Icon(
        source.isText ? Icons.description_outlined : Icons.school_outlined,
      ),
      title: Text(source.title),
      subtitle: Text(
        [
          if (source.subtitle.isNotEmpty) source.subtitle,
          imported == 0 ? "noch nicht übernommen" : "$imported übernommen",
          if (news > 0) "$news Vorschläge",
          if (auto) "automatisch",
        ].join(" · "),
      ),
      trailing: news > 0
          ? Badge(label: Text("$news"), child: const Icon(Icons.chevron_right))
          : const Icon(Icons.chevron_right),
      onTap: () => _open(source),
    );
  }
}

/// Vorschau einer Übernahme: erkannte Einträge mit Status, abwählbar und
/// vor dem Übernehmen bearbeitbar.
class ImportPreviewScreen extends StatefulWidget {
  final OrganizerController controller;
  final ImportSource source;

  /// Eingefügter Plan: Textfeld zeigen.
  final bool editText;

  const ImportPreviewScreen({
    super.key,
    required this.controller,
    required this.source,
    this.editText = false,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  OrganizerController get c => widget.controller;
  ImportSource get source => widget.source;

  late ImportSettings _settings = ImportSettings.fromMap(
    c.importSettings(source.sourceId),
  );
  late final TextEditingController _text = TextEditingController(
    text: _settings.text ?? "",
  );
  late final TextEditingController _title = TextEditingController(
    text: _settings.title ?? "",
  );
  late bool _auto = c.config.autoImports.contains(source.sourceId);
  late bool _showText = widget.editText || (_settings.text ?? "").isEmpty;

  Set<String>? _selected;
  final Map<String, ImportCandidate> _edited = {};

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  ImportSettings get _effective => source.isText
      ? _settings.copyWith(
          text: _text.text,
          title: _title.text.trim().isEmpty
              ? "Seminarplan"
              : _title.text.trim(),
        )
      : _settings;

  ImportDiff _diff() => SeminarImporter.diff(
    source.build(_effective),
    tasks: c.rawTasks,
    events: c.rawEvents,
    today: c.today,
  );

  String _areaId(ImportDiff diff) => _settings.areaId ?? diff.plan.areaId;

  Future<void> _apply(ImportDiff diff, Set<String> selected) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final settings = _effective.copyWith(areaId: _areaId(diff));
    if (source.isText && c.area(settings.areaId) == null) {
      c.newArea(name: settings.title ?? "Seminar", id: settings.areaId);
    }
    final n = await SeminarImporter.apply(
      c,
      diff,
      selected: selected,
      edited: _edited,
      areaId: settings.areaId,
    );
    await c.saveImportSettings(source.sourceId, settings.toMap());
    final autos = {...c.config.autoImports};
    _auto ? autos.add(source.sourceId) : autos.remove(source.sourceId);
    if (autos.length != c.config.autoImports.length) {
      await c.saveConfig(c.config.copyWith(autoImports: autos));
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n == 1 ? "1 Eintrag übernommen." : "$n Einträge übernommen.",
        ),
      ),
    );
    navigator.pop();
  }

  Future<void> _editCandidate(String key, ImportCandidate candidate) async {
    final title = TextEditingController(text: candidate.title);
    var date = candidate.date;
    final result = await showDialog<ImportCandidate>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          title: const Text("Vor dem Übernehmen ändern"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(labelText: "Titel"),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(date?.label(year: true) ?? "Ohne Datum"),
                    onPressed: () async {
                      final d = await pickDate(
                        dialog,
                        initial: date,
                        today: c.today,
                      );
                      if (d != null) setState(() => date = d);
                    },
                  ),
                  if (date != null && candidate.kind == ImportKind.task)
                    TextButton(
                      onPressed: () => setState(() => date = null),
                      child: const Text("Ohne"),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text("Abbrechen"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialog,
                candidate.copyWith(
                  title: title.text.trim().isEmpty ? null : title.text.trim(),
                  date: date,
                  clearDate: date == null,
                ),
              ),
              child: const Text("Übernehmen"),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _edited[key] = result);
  }

  @override
  Widget build(BuildContext context) {
    final diff = _diff();
    final selected = _selected ??= {
      for (final ch in diff.changes)
        if (ch.suggested) SeminarImporter.selectionKey(ch),
    };
    final area = c.area(_areaId(diff));
    final groups = <String, List<ImportChange>>{};
    for (final ch in diff.changes) {
      final g = ch.candidate?.group ?? "Nicht mehr im Plan";
      (groups[g] ??= []).add(ch);
    }
    final count = diff.changes
        .where(
          (ch) =>
              selected.contains(SeminarImporter.selectionKey(ch)) &&
              ch.status != ImportStatus.unchanged,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(source.title),
        actions: [
          if (source.isText && c.importSettings(source.sourceId) != null)
            IconButton(
              tooltip: "Plan entfernen",
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await c.deleteImportSettings(source.sourceId);
                navigator.pop();
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            key: const ValueKey("import-apply"),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: Text(
              count == 0 ? "Einstellungen speichern" : "$count übernehmen",
            ),
            onPressed: () => _apply(diff, selected),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (source.isText) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                key: const ValueKey("plan-title"),
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "Lehrveranstaltung",
                  hintText: "z. B. Seminar „Gottes Wort in deinem Ohr“",
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ExpansionTile(
              initiallyExpanded: _showText,
              title: const Text("Text des Seminarplans"),
              onExpansionChanged: (v) => _showText = v,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    key: const ValueKey("plan-text"),
                    controller: _text,
                    minLines: 6,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      hintText:
                          "Sitzung 1 (21.10.): Einführung\n"
                          "Sitzung 2: Text von Ebeling lesen\n"
                          "Abgabe der Hausarbeit bis 15.03.",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _selected = null),
                  ),
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: Text(
                _settings.firstSession == null
                    ? "Erste Sitzung: aus dem Text"
                    : "Erste Sitzung: ${_settings.firstSession!.label(year: true)}",
              ),
              subtitle: Text(
                _settings.intervalDays == 14 ? "14-täglich" : "wöchentlich",
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: "Rhythmus wechseln",
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: () => setState(() {
                      _settings = _settings.copyWith(
                        intervalDays: _settings.intervalDays == 7 ? 14 : 7,
                      );
                      _selected = null;
                    }),
                  ),
                ],
              ),
              onTap: () async {
                final d = await pickDate(
                  context,
                  initial: _settings.firstSession,
                  today: c.today,
                );
                if (d != null) {
                  setState(() {
                    _settings = _settings.copyWith(firstSession: d);
                    _selected = null;
                  });
                }
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.label_outline_rounded),
            title: Text(area?.name ?? diff.plan.areaName),
            subtitle: Text(
              area == null
                  ? "Zuordnung wird beim Übernehmen angelegt"
                  : "Zuordnung",
            ),
            onTap: () async {
              final id = await pickArea(context, c, current: area?.id);
              if (id != null && id.isNotEmpty) {
                setState(() => _settings = _settings.copyWith(areaId: id));
              }
            },
          ),
          SwitchListTile(
            title: const Text("Sitzungstermine in den Kalender"),
            subtitle: const Text(
              "Aus, wenn die Veranstaltung schon im Stundenplan steht.",
            ),
            value: _settings.sessions,
            onChanged: (v) => setState(() {
              _settings = _settings.copyWith(sessions: v);
              _selected = null;
            }),
          ),
          if (_settings.sessions)
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: Text(
                _settings.start == null
                    ? "Sitzungen ohne Uhrzeit (ganztägig)"
                    : "Sitzungen ${_settings.start!.key}–${_settings.end?.key ?? ""}",
              ),
              trailing: _settings.start == null
                  ? null
                  : IconButton(
                      tooltip: "Uhrzeit entfernen",
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _settings = _settings.copyWith(clearTimes: true);
                        _selected = null;
                      }),
                    ),
              onTap: () async {
                final start = await pickTime(
                  context,
                  initial: _settings.start,
                  title: "Beginn der Sitzungen",
                );
                if (start == null || !mounted) return;
                final endMin = start.minutes + 90;
                setState(() {
                  _settings = _settings.copyWith(
                    start: start,
                    end: endMin < 24 * 60 ? OrgTime(endMin) : null,
                  );
                  _selected = null;
                });
              },
            ),
          SwitchListTile(
            key: const ValueKey("import-auto"),
            title: const Text("Künftig automatisch übernehmen"),
            subtitle: const Text(
              "Neues und Änderungen unberührter Einträge; nie Löschungen, "
              "nie Erledigtes oder selbst Bearbeitetes.",
            ),
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
          ),
          const Divider(),
          if (diff.changes.isEmpty)
            const OrgEmpty(
              icon: Icons.search_off_rounded,
              text:
                  "Keine Sitzungen, Aufgaben, Abgaben oder Prüfungen erkannt.",
            ),
          for (final g in groups.entries) ...[
            OrgSectionTitle(g.key),
            for (final ch in g.value) _changeTile(context, ch, selected),
          ],
        ],
      ),
    );
  }

  Widget _changeTile(
    BuildContext context,
    ImportChange ch,
    Set<String> selected,
  ) {
    final key = SeminarImporter.selectionKey(ch);
    final candidate = _edited[key] ?? ch.candidate;
    final existing = ch.existing;
    final title =
        candidate?.title ??
        switch (existing) {
          OrgTask() => existing.title,
          OrgEvent() => existing.title,
          _ => "",
        };
    final date =
        candidate?.date ??
        switch (existing) {
          OrgTask() => existing.due,
          OrgEvent() => existing.date,
          _ => null,
        };
    final old = switch (existing) {
      OrgTask() => existing.due,
      OrgEvent() => existing.date,
      _ => null,
    };
    final isEvent = ch.kind == ImportKind.event;
    final type = c.config.type(candidate?.typeId ?? "other");
    final status = ch.status;
    final color = switch (status) {
      ImportStatus.added => context.colors.success,
      ImportStatus.changed => context.colors.accent,
      ImportStatus.conflict || ImportStatus.removed => context.colors.error,
      _ => context.colors.textSecondary,
    };
    final editable =
        candidate != null &&
        (status == ImportStatus.added ||
            status == ImportStatus.changed ||
            status == ImportStatus.dismissed);
    return CheckboxListTile(
      key: ValueKey("import-$key"),
      value: status == ImportStatus.unchanged ? true : selected.contains(key),
      onChanged: status == ImportStatus.unchanged
          ? null
          : (v) => setState(() {
              v == true ? selected.add(key) : selected.remove(key);
            }),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: editable
          ? IconButton(
              tooltip: "Vor dem Übernehmen ändern",
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editCandidate(key, candidate),
            )
          : null,
      title: Row(
        children: [
          Icon(
            isEvent
                ? (type.important
                      ? Icons.priority_high_rounded
                      : Icons.event_rounded)
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: type.important ? context.colors.error : null,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(title, maxLines: 3)),
        ],
      ),
      subtitle: Text(
        [
          status.label,
          if (date != null)
            (status == ImportStatus.changed ||
                        status == ImportStatus.conflict) &&
                    old != null &&
                    old != date
                ? "${old.label()} → ${date.label()}"
                : date.label(year: true),
          if (date == null && !isEvent) "ohne Datum",
          if (ch.past && status == ImportStatus.added) "liegt zurück",
          if (_edited.containsKey(key)) "geändert",
        ].join(" · "),
        style: TextStyle(color: color),
      ),
    );
  }
}
