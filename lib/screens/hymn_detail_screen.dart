import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hymn.dart';
import '../models/hymn_score.dart';
import '../models/hymnal.dart';
import '../services/hymn_settings.dart';
import '../services/hymnal_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hymn_score_view.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';

class HymnDetailScreen extends StatefulWidget {
  final Hymn hymn;

  /// Alle Sammlungen, für Sammlungsangabe und weitere Fassungen; ohne sie
  /// zeigt die Ansicht nur das Lied selbst.
  final HymnalLibrary? library;

  const HymnDetailScreen({super.key, required this.hymn, this.library});

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  HymnSettings? settings;

  Hymn get hymn => widget.hymn;

  Hymnal? get hymnal => widget.library?.hymnalOf(hymn);

  bool get showScores => settings?.showScores ?? false;

  @override
  void initState() {
    super.initState();

    HymnSettings.load().then((loaded) {
      if (mounted) setState(() => settings = loaded);
    });
  }

  void setShowScores(bool value) {
    setState(() => settings?.showScores = value);

    settings?.saveShowScores(value);
  }

  @override
  Widget build(BuildContext context) {
    final headingStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    final metadataStyle = const TextStyle(fontSize: 16);

    final lyricStyle = const TextStyle(fontSize: 18, height: 1.5);

    final scoresShown = showScores && hymn.scores.isNotEmpty;

    final versions = widget.library?.versionsOf(hymn) ?? const <Hymn>[];

    // Wie im Gesangbuch steht die erste Strophe unter den Noten und wird
    // darunter nicht wiederholt; die übrigen folgen nummeriert.
    final underlaid = scoresShown
        ? hymn.scores
              .where((score) => score.hasUnderlay)
              .map((score) => score.underlayStanza.toString())
              .toSet()
        : const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(hymn.title),
        actions: [
          InfoButton(
            module: AppModules.hymns,
            reportDetails: () => {
              "Lied": "${hymn.displayNumber} – ${hymn.title}",
              if (hymnal != null) "Sammlung": hymnal!.title,
            },
          ),
          const SettingsButton(),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              hymn.displayNumber,

              style: Theme.of(context).textTheme.titleLarge,
            ),

            // Außerhalb des Stammteils: aus welcher Sammlung das Lied stammt.
            if (hymnal != null && hymnal!.part != HymnalPart.core)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  hymnal!.title,
                  key: const Key("hymn_collection"),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            Text(hymn.title, style: Theme.of(context).textTheme.headlineSmall),

            const SizedBox(height: 16),

            if (hymn.author.isNotEmpty || hymn.collectionId == 'eg')
              Text("Text: ${hymn.author}", style: metadataStyle),

            if (hymn.melody.isNotEmpty || hymn.collectionId == 'eg')
              Text("Melodie: ${hymn.melody}", style: metadataStyle),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,

              children: hymn.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),

            // Die Umschaltung erscheint nur, wenn es Noten zu zeigen gibt.
            if (hymn.scores.isNotEmpty) ...[
              const SizedBox(height: 16),

              SegmentedButton<bool>(
                key: const Key("hymn_view_mode"),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.notes_rounded),
                    label: Text("Nur Text"),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.music_note_rounded),
                    label: Text("Text und Noten"),
                  ),
                ],
                selected: {showScores},
                onSelectionChanged: settings == null
                    ? null
                    : (selection) => setShowScores(selection.first),
              ),
            ],

            const Divider(height: 32),

            if (scoresShown) ...[
              HymnScoreView(
                // Je Lied ein eigener Zustand: nie die Noten des vorigen.
                key: ValueKey("hymn_scores_${hymn.key}"),
                scores: hymn.scores,
                hasLyrics: hymn.lyrics.isNotEmpty,
              ),

              const SizedBox(height: 8),
            ],

            if (hymn.lyrics.isEmpty)
              Text(
                widget.library?.lyricsNoteOf(hymn) ??
                    (hymn.lyricsNote.isNotEmpty
                        ? hymn.lyricsNote
                        : HymnalLibrary.defaultLyricsNote),
                key: const Key("hymn_lyrics_note"),
                style: lyricStyle,
              )
            else if (underlaid.isNotEmpty)
              // Buchsatz: weitere Strophen nummeriert in der Notenschrift.
              ...hymn.lyrics
                  .where(
                    (verse) => !underlaid.contains(verse.stanza.toString()),
                  )
                  .map(
                    (verse) => Padding(
                      key: ValueKey("hymn_book_stanza_${verse.stanza}"),
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              verse.stanza.toString() == "Ref"
                                  ? "R."
                                  : "${verse.stanza}.",
                              style: lyricStyle.copyWith(
                                fontFamily: scoreTextFont,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              verse.text,
                              style: lyricStyle.copyWith(
                                fontFamily: scoreTextFont,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
            else
              ...hymn.lyrics.map(
                (verse) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        verse.stanza.toString() == "Ref"
                            ? "Refrain"
                            : "Strophe ${verse.stanza}",

                        style: headingStyle,
                      ),

                      const SizedBox(height: 6),

                      Text(verse.text, style: lyricStyle),
                    ],
                  ),
                ),
              ),

            if (hymn.source != null) _HymnSourceLine(hymn.source!),

            if (versions.isNotEmpty) ...[
              const Divider(height: 32),

              Text("Auch enthalten in", style: headingStyle),

              for (final other in versions)
                ListTile(
                  key: ValueKey("hymn_version_${other.key}"),
                  contentPadding: EdgeInsets.zero,
                  title: Text("${other.displayNumber} · ${other.title}"),
                  subtitle: Text(
                    widget.library?.hymnalOf(other)?.title ??
                        other.collectionId,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HymnDetailScreen(
                        hymn: other,
                        library: widget.library,
                      ),
                    ),
                  ),
                ),
            ],

            if (hymn.bibleReferences.isNotEmpty) ...[
              const Divider(),

              Text("Bibelstellen", style: headingStyle),

              Text(hymn.bibleReferences.join(", ")),
            ],

            if (hymn.explanation.isNotEmpty) ...[
              const Divider(height: 32),

              Text("Erklärung", style: headingStyle),

              const SizedBox(height: 8),

              Text(hymn.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

/// Herkunft der Angaben zu einem Lied außerhalb des Stammteils, mit dem
/// Wortlaut der Quelle.
class _HymnSourceLine extends StatelessWidget {
  final HymnScoreSource source;

  const _HymnSourceLine(this.source);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );
    final parts = [
      if (source.name.isNotEmpty) "Quelle: ${source.name}",
      if (source.statement.isNotEmpty) "„${source.statement}“",
      if (source.license.isNotEmpty) "Lizenz der Datei: ${source.license}",
    ];
    final text = Text(
      parts.join(" · "),
      key: const Key("hymn_source"),
      style: style,
    );
    final uri = Uri.tryParse(source.url);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: source.url.isEmpty || uri == null
          ? text
          : InkWell(
              onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
              child: text,
            ),
    );
  }
}
