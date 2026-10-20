import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../theme/app_theme.dart';
import 'church_history_widgets.dart';
import 'epochs_screen.dart';
import 'lecture_detail_screen.dart';
import 'themes_screen.dart';

/// Ein Eintrag mit allem, was ihn mit dem übrigen Stoff verbindet: was die
/// Vorlesung sagt, Erläuterung, Anmerkungen, verknüpfte Einträge, Epochen
/// und Themen.
class EntryDetailScreen extends StatelessWidget {
  final ChurchHistoryData data;
  final String entryId;

  const EntryDetailScreen({
    super.key,
    required this.data,
    required this.entryId,
  });

  @override
  Widget build(BuildContext context) {
    final entry = data.entry(entryId);

    if (entry == null) {
      return const ChurchHistoryPage(
        title: "Eintrag",
        children: [EmptyHint("Dieser Eintrag ist nicht (mehr) vorhanden.")],
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final mentions = data.mentionsOf(entry.id);
    final related = data.relatedOf(entry.id);
    final dating = entry.dating;

    return ChurchHistoryPage(
      title: entry.type.label,
      children: [
        Text(entry.name, style: textTheme.headlineSmall),
        if (entry.aliases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              "auch: ${entry.aliases.join(", ")}",
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Tag(entry.type.label, icon: entryIcon(entry.type)),
            if (entry.category != null) Tag(entry.category!),
            ProvenanceTag(data: data, entryId: entry.id),
          ],
        ),

        if (dating != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(child: DatingText(dating, style: textTheme.titleMedium)),
            ],
          ),
          if (dating.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                dating.note!,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
        ],

        if (mentions.isNotEmpty) ...[
          const SectionTitle("In der Vorlesung"),
          for (final m in mentions)
            LectureQuote(
              text: m.text,
              source:
                  "${data.lecture(m.lectureId)!.label}, ${slidesLabel(m.slides)}",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LectureDetailScreen(
                    data: data,
                    lectureId: m.lectureId,
                    initialSlide: m.slides.first,
                  ),
                ),
              ),
            ),
        ],

        const SectionTitle("Erläuterung"),
        SupplementBox(
          "${entry.summary}\n\n${entry.significance}",
          label: mentions.isEmpty
              ? "Ergänzung – kein Stoff der bisherigen Vorlesungen"
              : "Ergänzung zur Vorlesung",
        ),

        for (final note in entry.notes)
          SupplementBox(note.text, label: note.kind.label),

        if (related.isNotEmpty) ...[
          const SectionTitle("Verknüpft"),
          for (final type in EntryType.values)
            if (related.any((r) => r.type == type)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(type.plural, style: textTheme.titleSmall),
              ),
              for (final r in related.where((r) => r.type == type))
                EntryTile(data: data, entry: r),
            ],
        ],

        if (entry.epochIds.isNotEmpty || entry.themeIds.isNotEmpty) ...[
          const SectionTitle("Einordnung"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in entry.epochIds)
                if (data.epoch(id) != null)
                  ActionChip(
                    avatar: const Icon(Icons.timeline_rounded, size: 18),
                    label: Text(data.epoch(id)!.title),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EpochDetailScreen(data: data, epochId: id),
                      ),
                    ),
                  ),
              for (final id in entry.themeIds)
                if (data.theme(id) != null)
                  ActionChip(
                    avatar: const Icon(Icons.hub_outlined, size: 18),
                    label: Text(data.theme(id)!.title),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ThemeDetailScreen(data: data, themeId: id),
                      ),
                    ),
                  ),
            ],
          ),
        ],

        if (entry.references.isNotEmpty) ...[
          const SectionTitle("Quellen und Literatur"),
          for (final r in entry.references)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text("• $r"),
            ),
        ],
      ],
    );
  }
}
