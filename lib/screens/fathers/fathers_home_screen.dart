import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/bible/bible_reference.dart';
import '../../models/fathers/fathers.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/info_report.dart';
import 'author_screen.dart';
import 'fulltext_search_screen.dart';
import 'work_screen.dart';

/// Sprachen der Originale für Filter und Anzeige.
const Map<String, String> fathersLanguages = {
  "grc": "Griechisch",
  "la": "Latein",
  "syr": "Syrisch",
  "de": "Deutsch",
};

/// Filter der Bibliothek. Leere Werte filtern nicht.
class FathersFilter {
  final AuthorCategory? category;
  final Epoch? epoch;
  final String? language;
  final String? genre;

  /// Nur Werke mit Text in der App.
  final bool readableOnly;

  const FathersFilter({
    this.category,
    this.epoch,
    this.language,
    this.genre,
    this.readableOnly = false,
  });

  bool get isEmpty =>
      category == null &&
      epoch == null &&
      language == null &&
      genre == null &&
      !readableOnly;

  bool authorMatches(FathersAuthor a) =>
      (category == null || a.category == category) &&
      (epoch == null || a.epoch == epoch) &&
      (language == null || a.languages.contains(language));

  bool workMatches(FathersWork w, FathersAuthor? a) =>
      (a == null || authorMatches(a)) &&
      (language == null ||
          w.originalLanguage == language ||
          (w.originalLanguage == null &&
              (a?.languages.contains(language) ?? false))) &&
      (genre == null || w.genre == genre) &&
      (!readableOnly || w.readableVersion != null);
}

/// Suche im Katalog nach Autor, Werk, Clavis-Nummer und Übersetzer.
class FathersSearch {
  FathersSearch._();

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll("ä", "a")
      .replaceAll("ö", "o")
      .replaceAll("ü", "u")
      .replaceAll("ß", "ss")
      .replaceAll(RegExp(r"[^a-z0-9 ]"), " ")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();

  static bool _all(String haystack, String query) {
    final words = _fold(query).split(" ").where((w) => w.isNotEmpty);

    final text = _fold(haystack);

    return words.every(text.contains);
  }

  static List<FathersAuthor> authors(
    FathersLibrary library,
    String query,
    FathersFilter filter,
  ) {
    return [
      for (final a in library.authors)
        if (filter.authorMatches(a) &&
            (query.isEmpty || _all([a.name, ...a.aliases].join(" "), query)))
          a,
    ]..sort((a, b) => (a.deathYear ?? 9999).compareTo(b.deathYear ?? 9999));
  }

  static List<FathersWork> works(
    FathersLibrary library,
    String query,
    FathersFilter filter,
  ) {
    final found = <FathersWork>[];

    for (final w in library.works) {
      final a = library.author(w.authorId);

      if (!filter.workMatches(w, a)) continue;

      if (query.isNotEmpty) {
        final text = [
          w.title,
          w.originalTitle ?? "",
          w.clavis ?? "",
          a?.name ?? "",
          ...?a?.aliases,
          for (final v in w.versions) ...[v.title, v.translator ?? ""],
        ].join(" ");

        if (!_all(text, query)) continue;
      }

      found.add(w);
    }

    // Werke mit Text zuerst, dann nach Autor (Lebenszeit) und Titel.
    found.sort((x, y) {
      final readable = (y.readableVersion != null ? 1 : 0).compareTo(
        x.readableVersion != null ? 1 : 0,
      );
      if (readable != 0) return readable;

      final ax = library.author(x.authorId)?.deathYear ?? 9999;
      final ay = library.author(y.authorId)?.deathYear ?? 9999;
      if (ax != ay) return ax.compareTo(ay);

      return x.title.compareTo(y.title);
    });

    return found;
  }

  /// Ob [query] eine Bibelstelle mit Kapitel ist (z. B. „Joh 3,16“).
  static BibleReference? bibleReference(String query) {
    if (!RegExp(r"\d").hasMatch(query)) return null;

    final reference = BibleReferenceParser.parse(query);

    // Nur das Buch ergibt Kapitel 1 – das ist keine gemeinte Stelle.
    if (reference == null) return null;

    return reference;
  }
}

/// Hauptbereich „Kirchenväter & Schriften“.
class FathersHomeScreen extends StatefulWidget {
  final FathersRepository? repository;

  const FathersHomeScreen({super.key, this.repository});

  @override
  State<FathersHomeScreen> createState() => _FathersHomeScreenState();
}

class _FathersHomeScreenState extends State<FathersHomeScreen> {
  late final FathersRepository repo =
      widget.repository ?? FathersRepository.instance;

  late Future<FathersLibrary> _library = repo.library();

  final TextEditingController _query = TextEditingController();

  String query = "";
  FathersFilter filter = const FathersFilter();
  int tab = 0;

  /// Treffer zu einer eingegebenen Bibelstelle.
  Future<List<PassageLink>>? _refHits;
  BibleReference? _ref;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    final reference = FathersSearch.bibleReference(value);

    setState(() {
      query = value.trim();
      _ref = reference;
      _refHits = reference == null ? null : _linksFor(reference);
    });
  }

  Future<List<PassageLink>> _linksFor(BibleReference r) {
    final verse = r.verse;

    if (verse != null && r.endVerse == null && !r.openEnd) {
      return repo.linksForVerse(r.bookId, r.chapter, verse);
    }

    return repo.linksForRange(r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kirchenväter & Schriften"),
        actions: [InfoButton(module: AppModules.fathers)],
      ),
      body: FutureBuilder<FathersLibrary>(
        future: _library,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final library = snapshot.data;

          if (library == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyHint(
                    "Die Bibliothek konnte nicht geladen werden.",
                  ),
                  TextButton(
                    key: const ValueKey("fathers-retry"),
                    onPressed: () => setState(() {
                      _library = repo.library();
                    }),
                    child: const Text("Erneut laden"),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentPage.maxWidth),
              child: _content(context, library),
            ),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, FathersLibrary library) {
    final ref = _ref;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            key: const ValueKey("fathers-search"),
            controller: _query,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Autor, Werk, CPL/CPG oder Bibelstelle (z. B. Joh 1,1)",
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: "Suche leeren",
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _query.clear();
                        _setQuery("");
                      },
                    ),
            ),
            onChanged: _setQuery,
          ),
        ),
        _filters(context, library),
        if (ref != null)
          Expanded(child: _referenceResults(context, library, ref))
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text("Werke")),
                ButtonSegment(value: 1, label: Text("Autoren")),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => tab = s.first),
            ),
          ),
          Expanded(
            child: tab == 0
                ? _works(context, library)
                : _authors(context, library),
          ),
        ],
      ],
    );
  }

  Widget _filters(BuildContext context, FathersLibrary library) {
    final genres = {for (final w in library.works) w.genre}.toList()..sort();

    Widget menu<T>({
      required String label,
      required T? value,
      required Map<T, String> options,
      required ValueChanged<T?> onChanged,
      required Key key,
    }) {
      return PopupMenuButton<T?>(
        key: key,
        tooltip: label,
        onSelected: onChanged,
        itemBuilder: (_) => [
          PopupMenuItem<T?>(value: null, child: Text("Alle ($label)")),
          for (final e in options.entries)
            PopupMenuItem<T?>(value: e.key, child: Text(e.value)),
        ],
        child: Chip(
          label: Text(value == null ? label : options[value] ?? label),
          avatar: Icon(
            value == null ? Icons.filter_list : Icons.check,
            size: 16,
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          menu<AuthorCategory>(
            key: const ValueKey("filter-category"),
            label: "Kategorie",
            value: filter.category,
            options: {for (final c in AuthorCategory.values) c: c.label},
            onChanged: (v) => setState(
              () => filter = FathersFilter(
                category: v,
                epoch: filter.epoch,
                language: filter.language,
                genre: filter.genre,
                readableOnly: filter.readableOnly,
              ),
            ),
          ),
          const SizedBox(width: 8),
          menu<Epoch>(
            key: const ValueKey("filter-epoch"),
            label: "Epoche",
            value: filter.epoch,
            options: {for (final e in Epoch.values) e: e.label},
            onChanged: (v) => setState(
              () => filter = FathersFilter(
                category: filter.category,
                epoch: v,
                language: filter.language,
                genre: filter.genre,
                readableOnly: filter.readableOnly,
              ),
            ),
          ),
          const SizedBox(width: 8),
          menu<String>(
            key: const ValueKey("filter-language"),
            label: "Sprache",
            value: filter.language,
            options: fathersLanguages,
            onChanged: (v) => setState(
              () => filter = FathersFilter(
                category: filter.category,
                epoch: filter.epoch,
                language: v,
                genre: filter.genre,
                readableOnly: filter.readableOnly,
              ),
            ),
          ),
          const SizedBox(width: 8),
          menu<String>(
            key: const ValueKey("filter-genre"),
            label: "Gattung",
            value: filter.genre,
            options: {for (final g in genres) g: g},
            onChanged: (v) => setState(
              () => filter = FathersFilter(
                category: filter.category,
                epoch: filter.epoch,
                language: filter.language,
                genre: v,
                readableOnly: filter.readableOnly,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const ValueKey("filter-readable"),
            label: const Text("Mit Volltext"),
            selected: filter.readableOnly,
            onSelected: (v) => setState(
              () => filter = FathersFilter(
                category: filter.category,
                epoch: filter.epoch,
                language: filter.language,
                genre: filter.genre,
                readableOnly: v,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _works(BuildContext context, FathersLibrary library) {
    final works = FathersSearch.works(library, query, filter);
    final colors = context.colors;

    return ListView.builder(
      key: const ValueKey("fathers-works"),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      itemCount: works.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${works.length} Werke"
                    "${works.length == library.works.length ? "" : " von ${library.works.length}"}",
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                if (query.length >= 3)
                  TextButton.icon(
                    key: const ValueKey("fathers-fulltext"),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullTextSearchScreen(
                          query: query,
                          repository: repo,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.manage_search_rounded, size: 18),
                    label: const Text("In den Volltexten suchen"),
                  ),
              ],
            ),
          );
        }

        final w = works[i - 1];
        final a = library.author(w.authorId);
        final availability = w.availability;

        return ListTile(
          key: ValueKey("work-${w.id}"),
          title: Text(w.title),
          subtitle: Text(
            [
              a?.name ?? w.authorId,
              w.genre,
              if (w.clavis != null) w.clavis!,
            ].join(" · "),
          ),
          trailing: Tooltip(
            message: availability.label,
            child: Icon(
              availability == Availability.external
                  ? Icons.link
                  : Icons.menu_book_rounded,
              color: availability == Availability.external
                  ? colors.textSecondary
                  : colors.primary,
            ),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkScreen(workId: w.id, repository: repo),
            ),
          ),
        );
      },
    );
  }

  Widget _authors(BuildContext context, FathersLibrary library) {
    final authors = FathersSearch.authors(library, query, filter);

    if (authors.isEmpty) {
      return const EmptyHint("Keine Autoren gefunden.");
    }

    return ListView.builder(
      key: const ValueKey("fathers-authors"),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      itemCount: authors.length,
      itemBuilder: (context, i) {
        final a = authors[i];
        final count = library.worksOf(a.id).length;

        return ListTile(
          key: ValueKey("author-${a.id}"),
          title: Text(a.name),
          subtitle: Text(
            [
              if (a.lifeDates != null) a.lifeDates!,
              a.category.label,
              "$count ${count == 1 ? "Werk" : "Werke"}",
            ].join(" · "),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AuthorScreen(authorId: a.id, repository: repo),
            ),
          ),
        );
      },
    );
  }

  Widget _referenceResults(
    BuildContext context,
    FathersLibrary library,
    BibleReference ref,
  ) {
    return FutureBuilder<List<PassageLink>>(
      future: _refHits,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final links = [
          for (final l in snapshot.data ?? const <PassageLink>[])
            if (filter.authorMatches(
                  library.author(l.authorId) ??
                      const FathersAuthor(
                        id: "",
                        name: "",
                        category: AuthorCategory.churchFather,
                      ),
                ) &&
                (filter.genre == null ||
                    library.work(l.workId)?.genre == filter.genre))
              l,
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Kirchenväter zu ${BibleReferenceParser.format(ref)}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => openBibleReference(context, ref),
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  label: const Text("Bibel"),
                ),
              ],
            ),
            if (snapshot.hasError)
              Column(
                children: [
                  const EmptyHint(
                    "Die Zuordnungen konnten nicht geladen werden.",
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _refHits = _linksFor(ref);
                    }),
                    child: const Text("Erneut laden"),
                  ),
                ],
              )
            else if (links.isEmpty)
              const EmptyHint(
                "Zu dieser Stelle ist noch kein Abschnitt erschlossen.",
              ),
            for (final l in links)
              ListTile(
                key: ValueKey("ref-hit-${l.id}"),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "${library.author(l.authorId)?.name ?? l.authorId}: "
                  "${library.work(l.workId)?.title ?? l.workId}",
                ),
                subtitle: Text(
                  "${BibleReferenceParser.format(l.reference)} · "
                  "${l.kind.label} · ${l.confidence.label}",
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
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
              ),
          ],
        );
      },
    );
  }
}
