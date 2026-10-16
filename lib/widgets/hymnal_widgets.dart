import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hymn.dart';
import '../models/hymnal.dart';
import '../services/hymn_search.dart';
import '../theme/app_theme.dart';

/// Kennzeichnung, wie weit eine Sammlung integriert ist.
class HymnalStatusChip extends StatelessWidget {
  final HymnalStatus status;

  const HymnalStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (status) {
      HymnalStatus.complete => (colors.successBackground, colors.success),
      HymnalStatus.partial => (colors.surfaceMuted, colors.textPrimary),
      HymnalStatus.notIntegrated => (colors.surfaceMuted, colors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// Was von einer Sammlung in der App steht, z. B. „535 Lieder · 446 mit
/// Text · 336 mit Noten“.
String hymnalContentSummary(Hymnal hymnal, List<Hymn> hymns) {
  if (hymns.isEmpty) return "Noch keine Lieder in der App";

  final withText = hymns.where((h) => h.lyrics.isNotEmpty).length;
  final withScores = hymns.where((h) => h.scores.isNotEmpty).length;
  final expected = hymnal.expectedCount;

  final count = expected != null && expected != hymns.length
      ? "${hymns.length} von $expected Liedern"
      : "${hymns.length} ${hymns.length == 1 ? 'Lied' : 'Lieder'}";

  if (withText == 0 && withScores == 0) return "$count · nur Nummer und Titel";

  return [
    count,
    "$withText mit Text",
    if (withScores > 0) "$withScores mit Noten",
  ].join(" · ");
}

/// Eintrag einer Sammlung in der Übersicht.
class HymnalTile extends StatelessWidget {
  final Hymnal hymnal;
  final List<Hymn> hymns;
  final bool failed;
  final VoidCallback onTap;

  const HymnalTile({
    super.key,
    required this.hymnal,
    required this.hymns,
    required this.onTap,
    this.failed = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (hymnal.year.isNotEmpty) hymnal.year,
      failed
          ? "Konnte nicht geladen werden"
          : hymnalContentSummary(hymnal, hymns),
    ].join(" · ");

    return ListTile(
      key: ValueKey("hymnal-${hymnal.id}"),
      leading: Icon(switch (hymnal.part) {
        HymnalPart.core => Icons.library_music_rounded,
        HymnalPart.regional => Icons.place_outlined,
        HymnalPart.supplement => Icons.library_add_outlined,
        HymnalPart.collection => Icons.history_edu_outlined,
      }),
      title: Text(hymnal.title),
      subtitle: Text(details),
      trailing: HymnalStatusChip(hymnal.status),
      onTap: onTap,
    );
  }
}

/// Ein Lied in Suchergebnissen und Listen: Nummer, Titel, Sammlung und bei
/// Treffern im Text die Fundstelle.
class HymnTile extends StatelessWidget {
  final Hymn hymn;

  /// Sammlung, falls sie angezeigt werden soll (globale Suche).
  final Hymnal? hymnal;

  /// Fundstelle im Liedtext (siehe [HymnSearchHit.snippet]).
  final String? snippet;

  final VoidCallback onTap;

  const HymnTile({
    super.key,
    required this.hymn,
    required this.onTap,
    this.hymnal,
    this.snippet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    final lines = [
      if (hymnal != null) hymnal!.label,
      if (snippet != null)
        snippet!
      else if (hymn.author.isNotEmpty)
        hymn.author,
    ];

    return ListTile(
      key: ValueKey("hymn-tile-${hymn.key}"),
      leading: CircleAvatar(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(hymn.number),
          ),
        ),
      ),
      title: Text(
        hymnal == null ? hymn.title : "${hymn.displayNumber} · ${hymn.title}",
      ),
      subtitle: lines.isEmpty
          ? null
          : Text(
              lines.join("\n"),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: _Availability(hymn: hymn, style: secondary),
      onTap: onTap,
    );
  }
}

class _Availability extends StatelessWidget {
  final Hymn hymn;
  final TextStyle? style;

  const _Availability({required this.hymn, this.style});

  @override
  Widget build(BuildContext context) {
    final color = style?.color;
    final hasText = hymn.lyrics.isNotEmpty;
    final hasScores = hymn.scores.isNotEmpty;

    if (!hasText && !hasScores) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasText)
          Tooltip(
            message: "Liedtext",
            child: Icon(Icons.notes_rounded, size: 18, color: color),
          ),
        if (hasScores)
          Tooltip(
            message: "Noten",
            child: Icon(Icons.music_note_rounded, size: 18, color: color),
          ),
      ],
    );
  }
}

/// Angaben zu einer Sammlung: Stand der Integration, Quellen und Lizenzen.
class HymnalInfoCard extends StatelessWidget {
  final Hymnal hymnal;
  final List<Hymn> hymns;

  const HymnalInfoCard({super.key, required this.hymnal, required this.hymns});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    return Card(
      key: ValueKey("hymnal-info-${hymnal.id}"),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hymnal.fullTitle.isNotEmpty
                        ? hymnal.fullTitle
                        : hymnal.title,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                HymnalStatusChip(hymnal.status),
              ],
            ),
            for (final line in [
              hymnal.region,
              hymnal.edition,
              hymnalContentSummary(hymnal, hymns),
            ])
              if (line.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line, style: secondary),
                ),
            if (hymnal.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(hymnal.description),
            ],
            if (hymnal.statusNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(hymnal.statusNote, style: secondary),
            ],
            if (hymnal.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Quellen", style: theme.textTheme.labelLarge),
              for (final source in hymnal.sources)
                HymnalSourceLink(source: source, style: secondary),
            ],
          ],
        ),
      ),
    );
  }
}

class HymnalSourceLink extends StatelessWidget {
  final HymnalSource source;
  final TextStyle? style;

  const HymnalSourceLink({super.key, required this.source, this.style});

  @override
  Widget build(BuildContext context) {
    final text = [
      source.title,
      source.license,
    ].where((part) => part.isNotEmpty).join(" · ");
    final uri = Uri.tryParse(source.url);

    if (source.url.isEmpty || uri == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: style),
      );
    }

    return InkWell(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                text,
                style: style?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
