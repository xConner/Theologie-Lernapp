import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';

/// Notizen: zuletzt bearbeitete zuerst, Suche, Filter nach Zuordnung und
/// Schlagwort, Archiv.
class NotesView extends StatefulWidget {
  final OrganizerController controller;
  final String? uid;

  const NotesView({super.key, required this.controller, required this.uid});

  @override
  State<NotesView> createState() => NotesViewState();
}

class NotesViewState extends State<NotesView> {
  OrganizerController get c => widget.controller;

  final TextEditingController _search = TextEditingController();
  String? areaId;
  String? _tag;
  bool _archived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final notes = c.notesFor(
          query: _search.text,
          filter: OrgFilter(areaId: areaId),
          archived: _archived,
          tag: _tag,
        );
        final usedAreas = <String>{
          for (final n in c.notesFor(archived: _archived))
            if (n.areaId != null) n.areaId!,
        };
        final tags = c.allTags;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                key: const ValueKey("note-search"),
                controller: _search,
                decoration: InputDecoration(
                  hintText: "Notizen durchsuchen",
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: "Suche leeren",
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text("Archiv"),
                    avatar: const Icon(Icons.archive_outlined, size: 18),
                    selected: _archived,
                    onSelected: (v) => setState(() => _archived = v),
                  ),
                  const SizedBox(width: 6),
                  for (final a in c.areas)
                    if (usedAreas.contains(a.id) || areaId == a.id)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          avatar: Icon(
                            Icons.circle,
                            size: 12,
                            color: areaColor(context, a),
                          ),
                          label: Text(a.name),
                          selected: areaId == a.id,
                          onSelected: (v) =>
                              setState(() => areaId = v ? a.id : null),
                        ),
                      ),
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text("#$t"),
                        selected: _tag == t,
                        onSelected: (v) => setState(() => _tag = v ? t : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: notes.isEmpty
                  ? OrgEmpty(
                      icon: Icons.sticky_note_2_outlined,
                      text: _search.text.isNotEmpty
                          ? "Keine Notiz gefunden."
                          : _archived
                          ? "Das Archiv ist leer."
                          : "Noch keine Notizen. Mit + legst du eine an.",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: notes.length,
                      itemBuilder: (context, i) => NoteTile(
                        controller: c,
                        note: notes[i],
                        uid: widget.uid,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Eine Notiz in Listen: Titel, Anfang des Textes, Zuordnung, Stand.
class NoteTile extends StatelessWidget {
  final OrganizerController controller;
  final OrgNote note;
  final String? uid;

  const NoteTile({
    super.key,
    required this.controller,
    required this.note,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final preview = note.body
        .split("\n")
        .map((l) => l.replaceAll(RegExp(r"^\s*(#+|-|\*|\[[ xX]\])\s*"), ""))
        .where((l) => l.trim().isNotEmpty && l.trim() != note.displayTitle)
        .take(2)
        .join(" · ")
        .replaceAll("**", "");
    final updated = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
    final day = OrgDate.of(updated);
    final today = controller.today;
    final when = day == today
        ? "${updated.hour.toString().padLeft(2, "0")}:${updated.minute.toString().padLeft(2, "0")}"
        : day.relativeLabel(today);
    return ListTile(
      key: ValueKey("note-${note.id}"),
      leading: Icon(
        note.pinned ? Icons.push_pin_rounded : Icons.sticky_note_2_outlined,
        color: areaColor(context, controller.area(note.areaId)),
      ),
      title: Text(
        note.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.isNotEmpty)
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
          Wrap(
            spacing: 8,
            children: [
              Text(
                when,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
              AreaLabel(area: controller.area(note.areaId)),
              for (final t in note.tags.take(3))
                Text(
                  "#$t",
                  style: TextStyle(fontSize: 12, color: context.colors.accent),
                ),
              if (note.links.isNotEmpty)
                Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: context.colors.textSecondary,
                ),
            ],
          ),
        ],
      ),
      onTap: () => openNoteEditor(context, controller, uid: uid, note: note),
    );
  }
}
