import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_search.dart';
import '../../theme/app_theme.dart';
import 'church_history_widgets.dart';
import 'epochs_screen.dart';
import 'lecture_detail_screen.dart';

/// Suche über Personen, Ereignisse, Jahreszahlen, Begriffe, Quellen,
/// Epochen, Vorlesungen und den Text der Folien.
class ChurchHistorySearchScreen extends StatefulWidget {
  final ChurchHistoryData data;

  const ChurchHistorySearchScreen({super.key, required this.data});

  @override
  State<ChurchHistorySearchScreen> createState() =>
      _ChurchHistorySearchScreenState();
}

class _ChurchHistorySearchScreenState extends State<ChurchHistorySearchScreen> {
  String query = "";

  void _open(SearchHit hit) {
    final data = widget.data;

    final Widget screen;
    switch (hit.kind) {
      case SearchHitKind.epoch:
        screen = EpochDetailScreen(data: data, epochId: hit.targetId);
      case SearchHitKind.lecture || SearchHitKind.slide:
        screen = LectureDetailScreen(
          data: data,
          lectureId: hit.targetId,
          initialSlide: hit.slide,
        );
      default:
        openEntry(context, data, hit.targetId);
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  IconData _icon(SearchHitKind kind) => switch (kind) {
    SearchHitKind.person => entryIcon(EntryType.person),
    SearchHitKind.event => entryIcon(EntryType.event),
    SearchHitKind.term => entryIcon(EntryType.term),
    SearchHitKind.source => entryIcon(EntryType.source),
    SearchHitKind.epoch => Icons.timeline_rounded,
    SearchHitKind.lecture => Icons.school_outlined,
    SearchHitKind.slide => Icons.slideshow_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final hits = ChurchHistorySearch(widget.data).search(query);

    return ChurchHistoryPage(
      title: "Suche",
      children: [
        TextField(
          key: const ValueKey("church-history-search"),
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: "Name, Begriff, Jahreszahl …",
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 8),
        if (query.trim().isEmpty)
          const EmptyHint(
            "Sucht in Personen, Ereignissen, Begriffen, Quellen, Epochen, "
            "Vorlesungen und im Text der Folien. Eine Jahreszahl findet "
            "alles, was in dieses Jahr fällt.",
          )
        else if (hits.isEmpty)
          const EmptyHint("Keine Treffer.")
        else ...[
          Text(
            hits.length == 1 ? "1 Treffer" : "${hits.length} Treffer",
            style: TextStyle(color: context.colors.textSecondary),
          ),
          for (final hit in hits)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(_icon(hit.kind), color: context.colors.primary),
                title: Text(hit.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hit.subtitle.isNotEmpty) Text(hit.subtitle),
                    const SizedBox(height: 4),
                    Tag(hit.kind.label),
                  ],
                ),
                onTap: () => _open(hit),
              ),
            ),
        ],
      ],
    );
  }
}
