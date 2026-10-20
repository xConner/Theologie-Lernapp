import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_search.dart';
import 'church_history_widgets.dart';

/// Nachschlagen: Personen, Ereignisse, Begriffe und Quellen mit Filter.
class EntriesScreen extends StatefulWidget {
  final ChurchHistoryData data;
  final EntryType? initialType;

  const EntriesScreen({super.key, required this.data, this.initialType});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  EntryType? type;
  bool onlyLecture = false;
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
            (!onlyLecture || data.isFromLecture(e.id)) &&
            (query.isEmpty ||
                ChurchHistorySearch.normalize(
                  [e.name, ...e.aliases, e.category ?? ""].join(" "),
                ).contains(query)))
          e,
    ];

    return ChurchHistoryPage(
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
            FilterChip(
              key: const ValueKey("entries-only-lecture"),
              label: const Text("Nur aus Vorlesungen"),
              selected: onlyLecture,
              onSelected: (v) => setState(() => onlyLecture = v),
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
