import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../theme/app_theme.dart';
import 'church_history_widgets.dart';

/// Senkrechte Zeitleiste: auf schmalen Bildschirmen gut lesbar, im Web
/// in begrenzter Breite. Einträge sind nach Jahrhunderten gruppiert;
/// ungefähre Datierungen haben einen offenen, umstrittene einen
/// gestrichelten Punkt.
class TimelineView extends StatefulWidget {
  final ChurchHistoryData data;

  /// Optional nur die Einträge einer Vorlesung, Epoche oder eines Themas.
  final String? lectureId;
  final String? epochId;
  final String? themeId;

  const TimelineView({
    super.key,
    required this.data,
    this.lectureId,
    this.epochId,
    this.themeId,
  });

  /// „1. Jh.“, „4. Jh. v. Chr.“ für ein Jahr.
  static String centuryOf(int year) {
    if (year <= 0) return "${(-year) ~/ 100 + 1}. Jh. v. Chr.";
    return "${(year - 1) ~/ 100 + 1}. Jh.";
  }

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  Set<EntryType> types = {EntryType.event, EntryType.source};

  List<HistoryEntry> _entries() {
    final data = widget.data;

    Set<String>? only;
    if (widget.lectureId != null) {
      only = data.entriesOfLecture(widget.lectureId!).map((e) => e.id).toSet();
    } else if (widget.epochId != null) {
      only = data.entriesOfEpoch(widget.epochId!).map((e) => e.id).toSet();
    } else if (widget.themeId != null) {
      only = data.entriesOfTheme(widget.themeId!).map((e) => e.id).toSet();
    }

    return [
      for (final e in data.timeline)
        if (types.contains(e.type) && (only == null || only.contains(e.id))) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();

    final children = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final type in EntryType.values)
            FilterChip(
              key: ValueKey("timeline-filter-${type.name}"),
              label: Text(type.plural),
              selected: types.contains(type),
              onSelected: (on) => setState(() {
                types = {...types};
                on ? types.add(type) : types.remove(type);
              }),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        "○ ungefähre Datierung   ◌ umstrittene Datierung",
        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
      ),
      const SizedBox(height: 8),
    ];

    if (entries.isEmpty) {
      children.add(
        const EmptyHint("Keine datierten Einträge für diese Auswahl."),
      );
    }

    String? century;
    for (final e in entries) {
      final c = TimelineView.centuryOf(e.dating!.from);
      if (c != century) {
        century = c;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
            child: Text(c, style: Theme.of(context).textTheme.titleMedium),
          ),
        );
      }
      children.add(_TimelineItem(data: widget.data, entry: e));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final ChurchHistoryData data;
  final HistoryEntry entry;

  const _TimelineItem({required this.data, required this.entry});

  @override
  Widget build(BuildContext context) {
    final dating = entry.dating!;
    final colors = context.colors;

    final dot = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dating.approx || dating.disputed
            ? colors.surface
            : colors.primary,
        border: Border.all(
          color: dating.disputed ? colors.accent : colors.primary,
          width: dating.disputed ? 3 : 2,
        ),
      ),
    );

    return InkWell(
      key: ValueKey("timeline-${entry.id}"),
      onTap: () => openEntry(context, data, entry.id),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 96,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Text(
                  dating.label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 20,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(width: 2, color: colors.divider),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 12), child: dot),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Tag(entry.type.label),
                        if (dating.precisionHint != null)
                          Tag(dating.precisionHint!),
                        ProvenanceTag(data: data, entryId: entry.id),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
