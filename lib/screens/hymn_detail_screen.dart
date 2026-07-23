import 'package:flutter/material.dart';

import '../models/hymn.dart';

class HymnDetailScreen extends StatelessWidget {
  final Hymn hymn;

  const HymnDetailScreen({super.key, required this.hymn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleStyle = theme.textTheme.headlineSmall;

    final headingStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    final metadataStyle = const TextStyle(fontSize: 16);

    final lyricStyle = const TextStyle(fontSize: 18, height: 1.5);

    return Scaffold(
      appBar: AppBar(title: Text(hymn.title)),

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

            const Divider(height: 32),

            if (hymn.lyrics.isEmpty)
              Text(
                "Liedtext aus urheberrechtlichen Gründen nicht verfügbar.",
                style: lyricStyle,
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
