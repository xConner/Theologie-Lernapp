import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_loader.dart';
import '../../theme/app_theme.dart';
import 'entry_detail_screen.dart';

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
    return FutureBuilder<ChurchHistoryData>(
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
    );
  }
}

/// Seitengerüst mit begrenzter Breite (lesbar im Web, voll auf dem Handy).
class ChurchHistoryPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ChurchHistoryPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.floatingActionButton,
  });

  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Kleine Kennzeichnung (Typ, Herkunft, Genauigkeit).
class Tag extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const Tag(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

/// Herkunft eines Eintrags: aus welcher Vorlesung, sonst „Ergänzung“.
class ProvenanceTag extends StatelessWidget {
  final ChurchHistoryData data;
  final String entryId;

  const ProvenanceTag({super.key, required this.data, required this.entryId});

  @override
  Widget build(BuildContext context) {
    final lectures = data.lecturesOf(entryId);

    if (lectures.isEmpty) {
      return const Tag("Ergänzung", icon: Icons.add_circle_outline_rounded);
    }

    return Tag(
      lectures.map((l) => "VL ${l.number}").join(", "),
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

/// Kasten für Inhalte, die nicht aus der Vorlesung stammen.
class SupplementBox extends StatelessWidget {
  final String text;
  final String label;

  const SupplementBox(
    this.text, {
    super.key,
    this.label = "Ergänzung – nicht von den Folien",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: context.colors.textSecondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }
}

/// Wortlaut der Vorlesung mit Fundstelle.
class LectureQuote extends StatelessWidget {
  final String text;
  final String source;
  final VoidCallback? onTap;

  const LectureQuote({
    super.key,
    required this.text,
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border(
            left: BorderSide(color: context.colors.primary, width: 3),
          ),
          color: context.colors.primary.withValues(alpha: 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 14,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    source,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: context.colors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(text),
          ],
        ),
      ),
    );
  }
}

String slidesLabel(List<int> slides) {
  if (slides.isEmpty) return "";
  return slides.length == 1
      ? "Folie ${slides.single}"
      : "Folien ${slides.join(", ")}";
}

/// Leerer Zustand mit Erklärung.
class EmptyHint extends StatelessWidget {
  final String text;

  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textSecondary),
      ),
    );
  }
}
