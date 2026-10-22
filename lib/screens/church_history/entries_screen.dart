import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_search.dart';
import 'church_history_widgets.dart';

/// Nachschlagen: Personen, Ereignisse, Begriffe und Quellen mit Filter nach
/// Typ und Veranstaltung.
class EntriesScreen extends StatefulWidget {
  final ChurchHistoryData data;
  final EntryType? initialType;

  const EntriesScreen({super.key, required this.data, this.initialType});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  EntryType? type;

  /// Filter nach Veranstaltung; null: alle Einträge.
  EntryOrigin? origin;
  String filter = "";

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final query = ChurchHistorySearch.normalize(filter);

    final entries = [
      for (final e in [...data.entries]..sort(ChurchHistoryData.compareEntries))
        if ((type == null || e.type == type) &&
            (origin == null || origin!.matches(data.contextOf(e.id))) &&
            (query.isEmpty ||
                ChurchHistorySearch.normalize(
                  [e.name, ...e.aliases, e.category ?? ""].join(" "),
                ).contains(query)))
          e,
    ];

    return ContentPage(
      title: "Personen, Ereignisse, Begriffe",
      children: [
        TextField(
          key: const ValueKey("entries-filter"),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.filter_list_rounded),
            hintText: "Nach Namen filtern",
          ),
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text("Alle"),
              selected: type == null,
              onSelected: (_) => setState(() => type = null),
            ),
            for (final t in EntryType.values)
              ChoiceChip(
                key: ValueKey("entries-type-${t.name}"),
                label: Text(t.plural),
                selected: type == t,
                onSelected: (_) => setState(() => type = t),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in EntryOrigin.values)
              if (data.seminar != null || !o.needsSeminar)
                FilterChip(
                  key: ValueKey("entries-origin-${o.name}"),
                  label: Text(o.label),
                  selected: origin == o,
                  onSelected: (v) => setState(() => origin = v ? o : null),
                ),
          ],
        ),
        const SizedBox(height: 8),
        Text("${entries.length} Einträge"),
        if (entries.isEmpty)
          const EmptyHint("Keine Einträge für diese Auswahl."),
        for (final e in entries) EntryTile(data: data, entry: e),
      ],
    );
  }
}

/// Filter nach Veranstaltung. „Vorlesung“ und „Proseminar“ schließen
/// gemeinsam behandelte Einträge ein.
enum EntryOrigin {
  lecture("Vorlesung"),
  seminar("Proseminar"),
  both("Gemeinsam"),
  supplement("Nur Ergänzung");

  final String label;

  const EntryOrigin(this.label);

  bool get needsSeminar => this == seminar || this == both;

  bool matches(CourseContext? context) => switch (this) {
    lecture => context?.includes(CourseKind.lecture) ?? false,
    seminar => context?.includes(CourseKind.seminar) ?? false,
    both => context == CourseContext.both,
    supplement => context == null,
  };
}
