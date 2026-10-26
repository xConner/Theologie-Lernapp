import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_loader.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lecture_materials_gate.dart';
import '../../widgets/content_page.dart';
import 'entry_detail_screen.dart';

export '../../widgets/content_page.dart';

/// Gemeinsame Bausteine der Kirchengeschichte-Ansichten.

/// Lädt die Inhalte und zeigt Lade- und Fehlerzustand; [builder] erhält die
/// geladenen Daten.
class ChurchHistoryDataBuilder extends StatefulWidget {
  final String title;
  final Widget Function(BuildContext context, ChurchHistoryData data) builder;

  /// Nur für Tests: Daten ohne Laden aus den Assets.
  final ChurchHistoryData? data;

  const ChurchHistoryDataBuilder({
    super.key,
    required this.title,
    required this.builder,
    this.data,
  });

  @override
  State<ChurchHistoryDataBuilder> createState() =>
      _ChurchHistoryDataBuilderState();
}

class _ChurchHistoryDataBuilderState extends State<ChurchHistoryDataBuilder> {
  late Future<ChurchHistoryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ChurchHistoryData> _load() {
    final data = widget.data;
    return data != null ? Future.value(data) : ChurchHistoryLoader.load();
  }

  @override
  Widget build(BuildContext context) {
    return LectureMaterialsGate(
      enabled: widget.data == null,
      child: FutureBuilder<ChurchHistoryData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;

          if (data != null) return widget.builder(context, data);

          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Die Inhalte zur Kirchengeschichte konnten nicht "
                            "geladen werden.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(() => _future = _load()),
                            child: const Text("Erneut versuchen"),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

IconData entryIcon(EntryType type) => switch (type) {
  EntryType.person => Icons.person_outline_rounded,
  EntryType.event => Icons.event_note_rounded,
  EntryType.term => Icons.label_outline_rounded,
  EntryType.source => Icons.description_outlined,
};

/// Herkunft eines Eintrags: Vorlesung, Proseminar oder beide (mit den
/// Vorlesungen bzw. Sitzungen), sonst „Ergänzung“.
class ProvenanceTag extends StatelessWidget {
  final ChurchHistoryData data;
  final String entryId;

  const ProvenanceTag({super.key, required this.data, required this.entryId});

  @override
  Widget build(BuildContext context) {
    final course = data.contextOf(entryId);

    if (course == null) {
      return const Tag("Ergänzung", icon: Icons.add_circle_outline_rounded);
    }

    final lectures = data.lecturesOf(entryId);

    String units(CourseKind kind) {
      final numbers = [
        for (final l in lectures)
          if (l.kind == kind) l.number,
      ];
      return "${kind.unitShort} ${numbers.join(", ")}";
    }

    return Tag(
      [
        course.label,
        for (final kind in CourseKind.values)
          if (course.includes(kind)) units(kind),
      ].join(" · "),
      color: context.colors.primary,
      icon: Icons.school_outlined,
    );
  }
}

/// Datierung mit Kennzeichnung ungefährer und umstrittener Angaben.
class DatingText extends StatelessWidget {
  final HistoricalDating dating;
  final TextStyle? style;

  const DatingText(this.dating, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final hint = dating.precisionHint;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: dating.label),
          if (hint != null)
            TextSpan(
              text: " ($hint)",
              style: TextStyle(
                color: dating.disputed
                    ? context.colors.accent
                    : context.colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      style: style,
    );
  }
}

/// Listeneintrag, der den Eintrag öffnet.
class EntryTile extends StatelessWidget {
  final ChurchHistoryData data;
  final HistoryEntry entry;

  /// Optionaler Zusatz (z. B. was die Vorlesung über den Eintrag sagt).
  final String? detail;

  const EntryTile({
    super.key,
    required this.data,
    required this.entry,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);

    final subtitle = [?entry.dating?.label, ?entry.category].join(" · ");

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: ValueKey("entry-${entry.id}"),
        leading: Icon(entryIcon(entry.type), color: context.colors.primary),
        title: Text(entry.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle, style: secondary),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  "„$detail“",
                  style: secondary?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Tag(entry.type.label),
                ProvenanceTag(data: data, entryId: entry.id),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => openEntry(context, data, entry.id),
      ),
    );
  }
}

void openEntry(BuildContext context, ChurchHistoryData data, String id) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EntryDetailScreen(data: data, entryId: id),
    ),
  );
}

/// Kennzeichnung einer Ergänzung passend zur Veranstaltung.
String supplementLabelFor(CourseKind kind) => kind == CourseKind.lecture
    ? "Ergänzung – nicht von den Folien"
    : "Ergänzung – nicht aus dem Seminarmaterial";
