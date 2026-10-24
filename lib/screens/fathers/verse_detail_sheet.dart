import 'package:flutter/material.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import '../../models/fathers/fathers.dart';
import '../../models/greek/perikope.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/bible/pericope_headings.dart';
import '../../services/bible/versification_map.dart';
import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/fathers/fathers_widgets.dart';
import 'work_screen.dart';

/// Öffnet die Versdetailansicht zu Vers [verse] in Kapitel [chapter] von
/// [translation] (Zählung der Ausgabe). [onOpenReference] schlägt eine
/// Stelle (Zählung der Perikopenliste) im Reader auf.
Future<void> showVerseDetails(
  BuildContext context, {
  required BibleTranslation translation,
  required List<BibleTranslation> translations,
  required String bookId,
  required int chapter,
  required int verse,
  required PericopeHeadings headings,
  required void Function(BibleReference reference) onOpenReference,
  FathersRepository? repository,
}) {
  final edition = BibleBooks.resolveIn(translation, bookId) ?? bookId;

  final list = ListVersification.toList(
    translation: translation,
    translations: translations,
    bookId: edition,
    chapter: chapter,
    verse: verse,
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scroll) => VerseDetailView(
        bookId: bookId,
        chapter: list?.chapter ?? chapter,
        verse: list?.verse ?? verse,
        editionLabel: list == null || list == (chapter: chapter, verse: verse)
            ? null
            : "$chapter,$verse in ${translation.shortName}",
        uncertain: list == null,
        headings: headings,
        repository: repository ?? FathersRepository.instance,
        scrollController: scroll,
        onOpenReference: (reference) {
          Navigator.pop(context);
          onOpenReference(reference);
        },
      ),
    ),
  );
}

/// Inhalt der Versdetailansicht: Kirchenväter, verwandte Stellen und – wenn
/// die Perikopenliste den Vers kennt – der Perikopenkontext.
class VerseDetailView extends StatefulWidget {
  /// Stelle in der Zählung der Perikopenliste.
  final String bookId;
  final int chapter;
  final int verse;

  /// Stelle in der Ausgabe, wenn sie anders zählt.
  final String? editionLabel;

  /// Die Zählung der Ausgabe ließ sich nicht sicher übertragen.
  final bool uncertain;

  final PericopeHeadings headings;
  final FathersRepository repository;
  final ScrollController? scrollController;
  final void Function(BibleReference reference) onOpenReference;

  const VerseDetailView({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.editionLabel,
    this.uncertain = false,
    required this.headings,
    required this.repository,
    this.scrollController,
    required this.onOpenReference,
  });

  @override
  State<VerseDetailView> createState() => _VerseDetailViewState();
}

class _VerseDetailViewState extends State<VerseDetailView> {
  late Future<_VerseData> _data = _load();

  /// Gewählte Perikope für den erweiterten Kontext (null = nur der Vers).
  Perikope? _pericope;

  /// Gewählter Kommentator (null = alle).
  String? _author;

  int _tab = 0;

  late final List<Perikope> _pericopes = widget.headings.containing(
    widget.bookId,
    widget.chapter,
    widget.verse,
  );

  BibleReference get _verseRef => BibleReference(
    bookId: widget.bookId,
    chapter: widget.chapter,
    verse: widget.verse,
  );

  Future<_VerseData> _load() async {
    final repo = widget.repository;

    final library = await repo.library();

    final pericope = _pericope;

    final range = pericope == null
        ? null
        : BibleReferenceParser.passageOf(pericope)?.reference;

    final links = range == null
        ? await repo.linksForVerse(widget.bookId, widget.chapter, widget.verse)
        : await repo.linksForRange(range);

    final refs = await repo.crossReferences(
      widget.bookId,
      widget.chapter,
      widget.verse,
    );

    return _VerseData(library, _sorted(links, library), refs);
  }

  /// Verszuordnungen vor Abschnittszuordnungen, sichere vor unsicheren,
  /// dann nach Lebenszeit des Autors.
  static List<PassageLink> _sorted(
    List<PassageLink> links,
    FathersLibrary library,
  ) {
    int rank(PassageLink l) => switch (l.kind) {
      LinkKind.verseCommentary => 0,
      LinkKind.sectionCommentary => 1,
      LinkKind.quotation => 2,
      LinkKind.reference => 3,
      LinkKind.suggested => 4,
    };

    final sorted = [...links]
      ..sort((a, b) {
        final byKind = rank(a).compareTo(rank(b));
        if (byKind != 0) return byKind;

        final byConfidence = a.confidence.index.compareTo(b.confidence.index);
        if (byConfidence != 0) return byConfidence;

        final ya = library.author(a.authorId)?.deathYear ?? 9999;
        final yb = library.author(b.authorId)?.deathYear ?? 9999;

        return ya.compareTo(yb);
      });

    // Mehrere Zitate desselben Verses im selben Abschnitt nur einmal.
    final seen = <String>{};

    return [
      for (final l in sorted)
        if (seen.add("${l.versionId}|${l.section}|${l.firstParagraph}")) l,
    ];
  }

  void _reload() => setState(() {
    _data = _load();
  });

  @override
  Widget build(BuildContext context) {
    final title = BibleReferenceParser.format(_verseRef);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: const ValueKey("verse-detail-title"),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.editionLabel != null || widget.uncertain)
                Text(
                  widget.uncertain
                      ? "Diese Ausgabe zählt hier anders; die Zuordnung zur "
                            "deutschen Zählung ist nicht sicher."
                      : "Deutsche Zählung (${widget.editionLabel}).",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text("Kirchenväter")),
              ButtonSegment(value: 1, label: Text("Verwandte Stellen")),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: FutureBuilder<_VerseData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data;

              if (snapshot.hasError || data == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EmptyHint(
                        "Die Angaben zu diesem Vers konnten nicht geladen "
                        "werden.",
                      ),
                      TextButton(
                        key: const ValueKey("verse-detail-retry"),
                        onPressed: _reload,
                        child: const Text("Erneut laden"),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: _tab == 0
                    ? _fathers(context, data)
                    : _related(context, data),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _fathers(BuildContext context, _VerseData data) {
    final colors = context.colors;

    final authors = <String, int>{};

    for (final l in data.links) {
      authors[l.authorId] = (authors[l.authorId] ?? 0) + 1;
    }

    final author = authors.containsKey(_author) ? _author : null;

    final shown = [
      for (final l in data.links)
        if (author == null || l.authorId == author) l,
    ];

    return [
      if (_pericopes.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              key: const ValueKey("scope-verse"),
              label: const Text("Nur dieser Vers"),
              selected: _pericope == null,
              onSelected: (_) {
                _pericope = null;
                _reload();
              },
            ),
            for (final p in _pericopes.take(2))
              ChoiceChip(
                key: ValueKey("scope-pericope-${p.id}"),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    "Perikope: ${p.title} "
                    "(${BibleReferenceParser.passageOf(p)?.label ?? p.book})",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                selected: _pericope?.id == p.id,
                onSelected: (_) {
                  _pericope = p;
                  _reload();
                },
              ),
          ],
        ),
      if (authors.length > 1) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text("Alle (${data.links.length})"),
              selected: author == null,
              onSelected: (_) => setState(() => _author = null),
            ),
            for (final e in authors.entries)
              ChoiceChip(
                key: ValueKey("author-${e.key}"),
                label: Text(
                  "${data.library.author(e.key)?.name ?? e.key} (${e.value})",
                ),
                selected: author == e.key,
                onSelected: (_) => setState(() => _author = e.key),
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      if (shown.isEmpty)
        EmptyHint(
          _pericope == null
              ? "Zu diesem Vers ist noch kein Abschnitt eines Kirchenvaters "
                    "erschlossen. Es werden nur Zuordnungen gezeigt, die "
                    "sich aus den Ausgaben belegen lassen."
              : "Zu dieser Perikope ist noch kein Abschnitt erschlossen.",
        ),
      for (final l in shown)
        PassageCard(
          key: ValueKey("passage-${l.id}"),
          link: l,
          library: data.library,
          repository: widget.repository,
          onOpenWork: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionReaderScreen(
                versionId: l.versionId,
                section: l.section,
                highlight: (l.firstParagraph, l.lastParagraph),
                repository: widget.repository,
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          "Historische Übersetzungen sind keine heutigen wissenschaftlichen "
          "Standardübersetzungen. Die Väter legen nicht einheitlich aus; "
          "die Abschnitte stehen für sich.",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ),
    ];
  }

  List<Widget> _related(BuildContext context, _VerseData data) {
    final colors = context.colors;

    final parallels = <(Perikope, Perikope)>[];

    for (final p in _pericopes) {
      if (!_gospels.contains(BibleBooks.byAbbreviation(p.book)?.id)) continue;

      for (final other in widget.headings.sameIdElsewhere(
        p,
        bookId: widget.bookId,
      )) {
        if (_gospels.contains(BibleBooks.byAbbreviation(other.book)?.id)) {
          parallels.add((p, other));
        }
      }
    }

    Widget tile(
      BibleReference target,
      String kind,
      String? reason, {
      Key? key,
    }) {
      return ListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.subdirectory_arrow_right_rounded),
        title: Text(BibleReferenceParser.format(target)),
        subtitle: Text(reason == null ? kind : "$kind · $reason"),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => widget.onOpenReference(target),
      );
    }

    return [
      if (parallels.isNotEmpty) ...[
        const ContentSectionTitle("Parallelstellen"),
        for (final (p, other) in parallels)
          if (BibleReferenceParser.passageOf(other) case final passage?)
            tile(
              passage.reference,
              CrossRefKind.parallel.label,
              "„${p.title}“ (Perikopen-Datensatz theologie.app)",
              key: ValueKey("parallel-${passage.label}"),
            ),
      ],
      const ContentSectionTitle("Verwandte Stellen"),
      if (data.crossRefs.isEmpty)
        const EmptyHint("Für diesen Vers sind keine Querverweise erfasst."),
      for (final r in data.crossRefs.take(40))
        tile(
          r.target,
          r.kind.label,
          r.votes == null ? null : "Bewertung ${r.votes}",
          key: ValueKey("xref-${BibleReferenceParser.format(r.target)}"),
        ),
      if (data.crossRefs.length > 40)
        Text(
          "${data.crossRefs.length - 40} weitere, schwächer bewertete "
          "Verweise sind ausgeblendet.",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          "Verwandte Stellen: OpenBible.info Cross References (CC BY), "
          "beruhend auf dem Treasury of Scripture Knowledge und "
          "Nutzerbewertungen. Die Quelle nennt nicht, wie die Stellen "
          "zusammenhängen (Zitat, Anspielung, Thema); die Bewertung zeigt nur, "
          "wie viele Nutzer den Verweis für hilfreich hielten. "
          "Parallelstellen: Perikopen-Datensatz von theologie.app.",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ),
    ];
  }

  static const Set<String> _gospels = {"MAT", "MRK", "LUK", "JHN"};
}

class _VerseData {
  final FathersLibrary library;
  final List<PassageLink> links;
  final List<CrossReference> crossRefs;

  const _VerseData(this.library, this.links, this.crossRefs);
}
