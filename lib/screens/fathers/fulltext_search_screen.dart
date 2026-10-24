import 'package:flutter/material.dart';

import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import 'work_screen.dart';

/// Suche in allen Volltexten der App. Die Texte werden erst hier und Werk
/// für Werk geladen; die Suche lässt sich jederzeit verlassen.
class FullTextSearchScreen extends StatefulWidget {
  final String query;
  final FathersRepository? repository;

  const FullTextSearchScreen({super.key, required this.query, this.repository});

  @override
  State<FullTextSearchScreen> createState() => _FullTextSearchScreenState();
}

class _FullTextSearchScreenState extends State<FullTextSearchScreen> {
  late final FathersRepository repo =
      widget.repository ?? FathersRepository.instance;

  final List<({String title, TextHit hit})> hits = [];

  int searched = 0;
  int total = 0;
  bool done = false;
  bool failed = false;

  static const int maxHits = 300;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final library = await repo.library();

      final versions = [
        for (final w in library.works)
          for (final v in w.versions)
            if (v.hasText) (work: w, version: v),
      ];

      if (!mounted) return;
      setState(() => total = versions.length);

      for (final entry in versions) {
        if (!mounted || hits.length >= maxHits) break;

        final found = await repo.searchVersion(
          entry.version.id,
          widget.query,
          limit: maxHits - hits.length,
        );

        if (!mounted) return;

        final author = library.author(entry.work.authorId)?.name ?? "";

        setState(() {
          searched++;
          hits.addAll([
            for (final h in found)
              (title: "$author: ${entry.work.title}", hit: h),
          ]);
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }

    if (mounted) setState(() => done = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text("Volltextsuche: ${widget.query}")),
      body: Column(
        children: [
          if (!done)
            LinearProgressIndicator(
              value: total == 0 ? null : searched / total,
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              failed
                  ? "Die Suche wurde wegen eines Ladefehlers abgebrochen."
                  : done
                  ? "${hits.length}${hits.length >= maxHits ? "+" : ""} Treffer in $searched Werken."
                  : "Durchsucht: $searched von $total Werken …",
              style: TextStyle(
                color: failed ? colors.error : colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: done && hits.isEmpty
                ? const EmptyHint("Keine Treffer in den Volltexten.")
                : ListView.builder(
                    itemCount: hits.length,
                    itemBuilder: (context, i) {
                      final h = hits[i];

                      return ListTile(
                        title: Text(h.title),
                        subtitle: Text(h.hit.snippet),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SectionReaderScreen(
                              versionId: h.hit.versionId,
                              section: h.hit.section,
                              highlight: (h.hit.paragraph, h.hit.paragraph),
                              repository: repo,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
