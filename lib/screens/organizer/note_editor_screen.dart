import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';

/// Notiz bearbeiten. Gespeichert wird automatisch (kurz nach dem Tippen und
/// beim Verlassen); eine leere neue Notiz wird nicht angelegt.
///
/// Ändert ein anderes Gerät die Notiz, während sie hier offen ist, wird die
/// fremde Fassung nur übernommen, solange hier nichts ungespeichert ist –
/// eigene Eingaben werden nie überschrieben.
class NoteEditorScreen extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;
  final OrgNote? note;
  final String? areaId;
  final List<OrgLink> links;

  /// Verzögerung des automatischen Speicherns (Tests: kürzer).
  final Duration autosaveDelay;

  const NoteEditorScreen({
    super.key,
    required this.controller,
    required this.uid,
    this.note,
    this.areaId,
    this.links = const [],
    this.autosaveDelay = const Duration(milliseconds: 700),
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  OrganizerController get c => widget.controller;

  late OrgNote _note =
      widget.note ?? c.newNote(areaId: widget.areaId, links: widget.links);
  late final TextEditingController _title = TextEditingController(
    text: _note.title,
  );
  late final TextEditingController _body = TextEditingController(
    text: _note.body,
  );
  final FocusNode _bodyFocus = FocusNode();
  Timer? _timer;
  bool _dirty = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_remoteChanged);
  }

  @override
  void dispose() {
    c.removeListener(_remoteChanged);
    _timer?.cancel();
    _flush();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _remoteChanged() {
    final remote = c.note(_note.id);
    if (remote == null || _dirty) return;
    if (remote.title != _title.text || remote.body != _body.text) {
      _title.text = remote.title;
      _body.text = remote.body;
    }
    if (mounted) setState(() => _note = remote);
  }

  void _changed() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(widget.autosaveDelay, _flush);
    setState(() {});
  }

  void _flush() {
    _timer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    final base = c.note(_note.id) ?? _note;
    _note = base.copyWith(title: _title.text, body: _body.text);
    c.saveNote(_note);
  }

  /// Sofort speichern (Einordnung, Tags, Verknüpfungen).
  void _update(OrgNote Function(OrgNote) change) {
    final base = c.note(_note.id) ?? _note;
    setState(() {
      _note = change(base.copyWith(title: _title.text, body: _body.text));
    });
    _dirty = false;
    _timer?.cancel();
    c.saveNote(_note);
  }

  /// Formatierung am Zeilenanfang bzw. um die Auswahl.
  void _format(String kind) {
    final text = _body.text;
    final sel = _body.selection.isValid
        ? _body.selection
        : TextSelection.collapsed(offset: text.length);
    if (kind == "bold") {
      final selected = sel.textInside(text);
      final insert = "**${selected.isEmpty ? "fett" : selected}**";
      _body.value = TextEditingValue(
        text: sel.textBefore(text) + insert + sel.textAfter(text),
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      );
    } else {
      final prefix = switch (kind) {
        "heading" => "# ",
        "list" => "- ",
        _ => "[ ] ",
      };
      final lineStart = text.lastIndexOf("\n", sel.start - 1) + 1;
      final line = text.substring(lineStart);
      final has = line.startsWith(prefix);
      final newText = has
          ? text.replaceRange(lineStart, lineStart + prefix.length, "")
          : text.replaceRange(lineStart, lineStart, prefix);
      final delta = has ? -prefix.length : prefix.length;
      _body.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (sel.start + delta).clamp(0, newText.length),
        ),
      );
    }
    _bodyFocus.requestFocus();
    _changed();
  }

  /// „[ ] Punkt“ in der Vorschau abhaken.
  void _toggleCheckbox(int lineIndex) {
    final lines = _body.text.split("\n");
    final line = lines[lineIndex];
    lines[lineIndex] = line.startsWith("[ ]")
        ? line.replaceFirst("[ ]", "[x]")
        : line.replaceFirst(RegExp(r"^\[[xX]\]"), "[ ]");
    _body.text = lines.join("\n");
    _changed();
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final existing = c.allTags;
    final tag = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text("Schlagwort"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: "z. B. Referat"),
              onSubmitted: (v) => Navigator.pop(dialog, v),
            ),
            if (existing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in existing.take(12))
                    ActionChip(
                      label: Text(t),
                      onPressed: () => Navigator.pop(dialog, t),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text("Hinzufügen"),
          ),
        ],
      ),
    );
    final t = tag?.trim().replaceAll("#", "");
    if (t == null || t.isEmpty || _note.tags.contains(t)) return;
    _update((n) => n.copyWith(tags: [...n.tags, t]));
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text("Notiz löschen?"),
        content: const Text(
          "Gelöschte Notizen lassen sich nicht wiederherstellen. Zum "
          "Aufbewahren ohne Anzeige: archivieren.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text("Löschen"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _dirty = false;
    _timer?.cancel();
    await c.deleteNote(_note);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final area = c.area(_note.areaId);
    final back = c.backlinks("note", _note.id);
    final links = [
      ..._note.links,
      for (final item in back)
        if (!_note.links.any((l) => l.target == item.id))
          OrgLink(
            type: item.kind,
            target: item.id,
            label: switch (item) {
              OrgTask() => item.title,
              OrgEvent() => item.title,
              OrgNote() => item.displayTitle,
              _ => "",
            },
          ),
    ];
    return PopScope(
      onPopInvokedWithResult: (_, _) => _flush(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_note.archived ? "Notiz (archiviert)" : "Notiz"),
          actions: [
            IconButton(
              tooltip: _preview ? "Bearbeiten" : "Vorschau",
              icon: Icon(
                _preview ? Icons.edit_rounded : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _preview = !_preview),
            ),
            IconButton(
              tooltip: _note.pinned ? "Nicht mehr anheften" : "Anheften",
              icon: Icon(
                _note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
              onPressed: () => _update((n) => n.copyWith(pinned: !n.pinned)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case "archive":
                    _update((n) => n.copyWith(archived: !n.archived));
                    if (_note.archived) Navigator.pop(context);
                  case "delete":
                    _delete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: "archive",
                  child: Text(_note.archived ? "Zurückholen" : "Archivieren"),
                ),
                const PopupMenuItem(value: "delete", child: Text("Löschen")),
              ],
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                SaveFailedBanner(controller: c),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    key: const ValueKey("note-title"),
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: const InputDecoration(
                      hintText: "Titel",
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _changed(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: Icon(
                          Icons.circle,
                          size: 12,
                          color: areaColor(context, area),
                        ),
                        label: Text(area?.name ?? "Zuordnung"),
                        onPressed: () async {
                          final id = await pickArea(
                            context,
                            c,
                            current: _note.areaId,
                          );
                          if (id == null) return;
                          _update(
                            (n) => id.isEmpty
                                ? n.copyWith(clearArea: true)
                                : n.copyWith(areaId: id),
                          );
                        },
                      ),
                      for (final t in _note.tags)
                        InputChip(
                          label: Text("#$t"),
                          onDeleted: () => _update(
                            (n) => n.copyWith(
                              tags: [
                                for (final x in n.tags)
                                  if (x != t) x,
                              ],
                            ),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.tag_rounded, size: 16),
                        label: const Text("Schlagwort"),
                        onPressed: _addTag,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_link_rounded, size: 16),
                        label: const Text("Verknüpfen"),
                        onPressed: () async {
                          final l = await pickLink(
                            context,
                            c,
                            excludeId: _note.id,
                          );
                          if (l == null || _note.links.any(l.sameTarget)) {
                            return;
                          }
                          _update((n) => n.copyWith(links: [...n.links, l]));
                        },
                      ),
                    ],
                  ),
                ),
                if (links.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LinkChips(
                        links: links,
                        onOpen: (l) =>
                            openLink(context, c, uid: widget.uid, link: l),
                        onRemove: (l) {
                          if (!_note.links.any(l.sameTarget)) return;
                          _update(
                            (n) => n.copyWith(
                              links: [
                                for (final x in n.links)
                                  if (!x.sameTarget(l)) x,
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (!_preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: "Überschrift",
                          icon: const Icon(Icons.title_rounded),
                          onPressed: () => _format("heading"),
                        ),
                        IconButton(
                          tooltip: "Liste",
                          icon: const Icon(Icons.format_list_bulleted_rounded),
                          onPressed: () => _format("list"),
                        ),
                        IconButton(
                          tooltip: "Checkliste",
                          icon: const Icon(Icons.checklist_rounded),
                          onPressed: () => _format("check"),
                        ),
                        IconButton(
                          tooltip: "Fett",
                          icon: const Icon(Icons.format_bold_rounded),
                          onPressed: () => _format("bold"),
                        ),
                        const Spacer(),
                        Text(
                          _dirty ? "Speichert …" : "Gespeichert",
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: _preview
                      ? NoteBodyView(
                          body: _body.text,
                          onToggle: _toggleCheckbox,
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            key: const ValueKey("note-body"),
                            controller: _body,
                            focusNode: _bodyFocus,
                            autofocus: widget.note == null,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText:
                                  "Notiz … (# Überschrift, - Liste, [ ] Aufgabe, "
                                  "**fett**)",
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => _changed(),
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
}

/// Darstellung des einfach strukturierten Notiztexts.
class NoteBodyView extends StatelessWidget {
  final String body;
  final void Function(int line)? onToggle;

  const NoteBodyView({super.key, required this.body, this.onToggle});

  static List<InlineSpan> _inline(String text, TextStyle? style) {
    final spans = <InlineSpan>[];
    final bold = RegExp(r"\*\*(.+?)\*\*");
    var last = 0;
    for (final m in bold.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final lines = body.split("\n");
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (i, line) in lines.indexed)
          Builder(
            builder: (context) {
              final heading = RegExp(r"^(#{1,3})\s+(.*)$").firstMatch(line);
              if (heading != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    heading.group(2)!,
                    style: heading.group(1)!.length == 1
                        ? theme.titleLarge
                        : theme.titleMedium,
                  ),
                );
              }
              final check = RegExp(r"^\[([ xX])\]\s?(.*)$").firstMatch(line);
              if (check != null) {
                final done = check.group(1) != " ";
                return InkWell(
                  onTap: onToggle == null ? null : () => onToggle!(i),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        done
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color: done
                            ? context.colors.success
                            : context.colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: _inline(check.group(2)!, null)),
                          style: done
                              ? TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: context.colors.textSecondary,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final bullet = RegExp(r"^\s*[-*]\s+(.*)$").firstMatch(line);
              if (bullet != null) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("•  "),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: _inline(bullet.group(1)!, null)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text.rich(TextSpan(children: _inline(line, null))),
              );
            },
          ),
      ],
    );
  }
}
