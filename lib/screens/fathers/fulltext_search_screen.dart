import 'package:flutter/material.dart';

import '../../models/fathers/fathers.dart';
import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import 'work_screen.dart';

/// Suche in allen Volltexten der App. Die Texte werden erst hier und Werk
/// für Werk geladen; die Suche lässt sich jederzeit verlassen. Gesucht wird
/// in den Fassungen einer Sprache (zuerst Deutsch) oder in allen.
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

  /// Sprache der durchsuchten Fassungen; null = alle.
  String? language = "de";
  List<String> languages = const [];
  int run = 0;

  static const int maxHits = 300;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _setLanguage(String? value) {
    setState(() {
      language = value;
      hits.clear();
      searched = 0;
      total = 0;
      done = false;
      failed = false;
    });
    _run();
  }

  Future<void> _run() async {
    final current = ++run;

    try {
      final library = await repo.library();

      final available = {
        for (final w in library.works)
          for (final v in w.versions)
            if (v.hasText) v.language,
      };

      final versions = [
        for (final w in library.works)
          for (final v in w.versions)
            if (v.hasText && (language == null || v.language == language))
              (work: w, version: v),
      ];

      if (!mounted || current != run) return;
      setState(() {
        languages = [
          for (final code in fathersLanguageNames.keys)
            if (available.contains(code)) code,
        ];
        total = versions.length;
      });

      for (final entry in versions) {
        if (!mounted || current != run || hits.length >= maxHits) break;

        final found = await repo.searchVersion(
          entry.version.id,
          widget.query,
          limit: maxHits - hits.length,
        );

        if (!mounted || current != run) return;

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
      if (mounted && current == run) setState(() => failed = true);
    }

    if (mounted && current == run) setState(() => done = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text("Volltextsuche: ${widget.query}")),
      body: Column(
        children: [
          if (languages.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final code in [...languages, null])
                    ChoiceChip(
                      key: ValueKey("search-language-${code ?? "alle"}"),
                      label: Text(
                        code == null ? "Alle Sprachen" : languageName(code),
                      ),
                      selected: language == code,
                      onSelected: (_) => _setLanguage(code),
                    ),
                ],
              ),
            ),
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
