import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/fathers/fathers.dart';
import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/info_report.dart';
import 'fathers_home_screen.dart';
import 'work_screen.dart';

/// Ein Autor mit seinen Werken und allen Bibelstellen, die in den Texten
/// seiner Werke in der App erschlossen sind.
class AuthorScreen extends StatefulWidget {
  final String authorId;
  final FathersRepository? repository;

  const AuthorScreen({super.key, required this.authorId, this.repository});

  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
  late final FathersRepository repo =
      widget.repository ?? FathersRepository.instance;

  late final Future<FathersLibrary> _library = repo.library();

  Future<List<PassageLink>>? _links;

  Future<List<PassageLink>> _loadLinks(FathersLibrary library) async {
    final all = <PassageLink>[];

    for (final w in library.worksOf(widget.authorId)) {
      for (final v in w.versions) {
        if (v.hasText && v.linkCount > 0) {
          all.addAll(await repo.linksOfVersion(v.id));
        }
      }
    }

    return all;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FathersLibrary>(
      future: _library,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final library = snapshot.data;
        final author = library?.author(widget.authorId);

        if (library == null || author == null) {
          return const ContentPage(
            title: "Autor",
            children: [EmptyHint("Der Autor konnte nicht geladen werden.")],
          );
        }

        return _page(context, library, author);
      },
    );
  }

  Widget _page(
    BuildContext context,
    FathersLibrary library,
    FathersAuthor author,
  ) {
    final colors = context.colors;
    final works = library.worksOf(author.id)
      ..sort((a, b) {
        final r = (b.readableVersion != null ? 1 : 0).compareTo(
          a.readableVersion != null ? 1 : 0,
        );

        return r != 0 ? r : a.title.compareTo(b.title);
      });

    final linked = works.fold(0, (sum, w) => sum + w.linkCount);

    return ContentPage(
      title: author.name,
      actions: [InfoButton(module: AppModules.fathers)],
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Tag(author.category.label, color: colors.primary),
            if (author.lifeDates != null) Tag(author.lifeDates!),
            if (author.tradition != null) Tag(author.tradition!),
            for (final l in author.languages) Tag(fathersLanguages[l] ?? l),
          ],
        ),
        if (author.aliases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Auch: ${author.aliases.join(", ")}",
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        if (author.note != null)
          SupplementBox(author.note!, label: "Einordnung (theologie.app)"),
        const ContentSectionTitle("Werke"),
        for (final w in works)
          ListTile(
            key: ValueKey("author-work-${w.id}"),
            contentPadding: EdgeInsets.zero,
            title: Text(w.title),
            subtitle: Text(
              [
                w.genre,
                if (w.clavis != null) w.clavis!,
                w.availability.label,
              ].join(" · "),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkScreen(workId: w.id, repository: repo),
              ),
            ),
          ),
        const ContentSectionTitle("Bibelstellen in seinen Werken"),
        if (linked == 0)
          const EmptyHint(
            "In den Texten dieses Autors sind noch keine Bibelstellen "
            "erschlossen.",
          )
        else if (_links == null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey("author-load-refs"),
              onPressed: () => setState(() {
                _links = _loadLinks(library);
              }),
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text("$linked Stellen anzeigen"),
            ),
          )
        else
          FutureBuilder<List<PassageLink>>(
            future: _links,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(() {
                    _links = _loadLinks(library);
                  }),
                  child: const Text("Erneut laden"),
                );
              }

              return BibleRefIndex(
                links: snapshot.data ?? const [],
                onOpenBible: (r) => openBibleReference(context, r),
                onOpenPassage: (l) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SectionReaderScreen(
                      versionId: l.versionId,
                      section: l.section,
                      highlight: (l.firstParagraph, l.lastParagraph),
                      repository: repo,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
