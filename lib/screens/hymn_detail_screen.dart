import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../services/hymn_settings.dart';
import '../widgets/hymn_score_view.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';

class HymnDetailScreen extends StatefulWidget {
  final Hymn hymn;

  const HymnDetailScreen({super.key, required this.hymn});

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  HymnSettings? settings;

  Hymn get hymn => widget.hymn;

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
            reportDetails: () => {"Lied": "EG ${hymn.id} – ${hymn.title}"},
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
              "EG ${hymn.id}",

              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            Text(hymn.title, style: Theme.of(context).textTheme.headlineSmall),

            const SizedBox(height: 16),

            Text("Text: ${hymn.author}", style: metadataStyle),

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
                key: ValueKey("hymn_scores_${hymn.id}"),
                scores: hymn.scores,
                hasLyrics: hymn.lyrics.isNotEmpty,
              ),

              const SizedBox(height: 8),
            ],

            if (hymn.lyrics.isEmpty)
              Text(
                "Liedtext aus urheberrechtlichen Gründen nicht verfügbar.",
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
