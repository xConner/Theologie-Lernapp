import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/bible/bible_reference.dart';
import '../../models/fathers/fathers.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/fathers/fathers_widgets.dart';
import '../../widgets/info_report.dart';
import '../../services/confession_service.dart';
import '../bible/bible_reader_screen.dart';
import '../confession_detail_screen.dart';

/// Öffnet [reference] im Bibel-Reader hervorgehoben.
void openBibleReference(BuildContext context, BibleReference reference) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BibleReaderScreen(
        passages: [
          BiblePassage(
            label: BibleReferenceParser.format(reference),
            reference: reference,
          ),
        ],
      ),
    ),
  );
}

/// Öffnet einen Text aus einem anderen Bereich der App (siehe
/// [WorkVersion.appLink]).
Future<void> openAppLink(BuildContext context, String link) async {
  final (area, id) = switch (link.split(":")) {
    [final a, final i] => (a, i),
    _ => ("", ""),
  };

  if (area != "confession") return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  try {
    final all = await ConfessionService().loadConfessions();
    final confession = all.where((c) => c.id == id).firstOrNull;

    if (confession == null) throw StateError("unbekannt: $id");

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ConfessionDetailScreen(confession: confession),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Der Text konnte nicht geöffnet werden.")),
    );
  }
}

/// Ein Werk: Angaben, Fassungen mit Herkunft und Rechtestand,
/// Inhaltsverzeichnis, Bibelstellen und Suche im Text.
class WorkScreen extends StatefulWidget {
  final String workId;
  final FathersRepository? repository;

  const WorkScreen({super.key, required this.workId, this.repository});

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  late final FathersRepository repo =
      widget.repository ?? FathersRepository.instance;

  late Future<FathersLibrary> _library = repo.library();

  String? _versionId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FathersLibrary>(
      future: _library,
      builder: (context, snapshot) {
        final library = snapshot.data;
        final work = library?.work(widget.workId);

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (library == null || work == null) {
          return ContentPage(
            title: "Werk",
            children: [
              const EmptyHint("Das Werk konnte nicht geladen werden."),
              TextButton(
                onPressed: () => setState(() {
                  _library = repo.library();
                }),
                child: const Text("Erneut laden"),
              ),
            ],
          );
        }

        final version = work.versions.firstWhere(
          (v) => v.id == _versionId,
          orElse: () => work.readableVersion ?? work.versions.first,
        );

        return _WorkView(
          key: ValueKey(version.id),
          library: library,
          work: work,
          version: version,
          repository: repo,
          onVersion: (id) => setState(() => _versionId = id),
        );
      },
    );
  }
}

class _WorkView extends StatefulWidget {
  final FathersLibrary library;
  final FathersWork work;
  final WorkVersion version;
  final FathersRepository repository;
  final ValueChanged<String> onVersion;

  const _WorkView({
    super.key,
    required this.library,
    required this.work,
    required this.version,
    required this.repository,
    required this.onVersion,
  });

  @override
  State<_WorkView> createState() => _WorkViewState();
}

class _WorkViewState extends State<_WorkView> {
  Future<WorkTableOfContents>? _toc;
  Future<List<PassageLink>>? _links;

  final TextEditingController _search = TextEditingController();
  Future<List<TextHit>>? _hits;

  int _tab = 0;

  @override
  void initState() {
    super.initState();

    if (widget.version.hasText) {
      _toc = widget.repository.tableOfContents(widget.version.id);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openSection(int number, [(int, int)? highlight]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionReaderScreen(
          versionId: widget.version.id,
          section: number,
          highlight: highlight,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final version = widget.version;
    final author = widget.library.author(work.authorId);
    final colors = context.colors;

    return ContentPage(
      title: work.title,
      actions: [InfoButton(module: AppModules.fathers)],
      children: [
        Text(
          author?.name ?? work.authorId,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          [
            if (work.originalTitle != null) work.originalTitle!,
            if (work.clavis != null) work.clavis!,
            work.genre,
          ].join(" · "),
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (work.versions.length > 1)
          DropdownButton<String>(
            key: const ValueKey("work-version"),
            isExpanded: true,
            value: version.id,
            items: [
              for (final v in work.versions)
                DropdownMenuItem(
                  value: v.id,
                  child: Text(
                    "${v.title}${v.translator == null ? "" : " (${v.translator})"}",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) widget.onVersion(id);
            },
          ),
        _VersionCard(version: version),
        const SizedBox(height: 12),
        if (version.hasText) ...[
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text("Inhalt")),
              ButtonSegment(value: 1, label: Text("Bibelstellen")),
              ButtonSegment(value: 2, label: Text("Suche")),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _tab = s.first;
              if (_tab == 1) {
                _links ??= widget.repository.linksOfVersion(version.id);
              }
            }),
          ),
          const SizedBox(height: 8),
          if (_tab == 0) _contents(),
          if (_tab == 1) _bibleRefs(),
          if (_tab == 2) _searchView(),
        ] else if (version.appLink != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey("open-app-link"),
              onPressed: () => openAppLink(context, version.appLink!),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text("In der App lesen (Bekenntnisse)"),
            ),
          )
        else
          EmptyHint(
            version.sourceUrl == null
                ? "Das Werk ist nur verzeichnet: ${version.rightsNote ?? "noch keine geprüfte Ausgabe"}."
                : "Der Text dieser Fassung ist in der App nicht enthalten "
                      "(${version.rights.label}). Er ist bei der Quelle lesbar.",
          ),
      ],
    );
  }

  Widget _contents() {
    return FutureBuilder<WorkTableOfContents>(
      future: _toc,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final toc = snapshot.data;

        if (toc == null) {
          return Column(
            children: [
              const EmptyHint(
                "Das Inhaltsverzeichnis konnte nicht geladen werden.",
              ),
              TextButton(
                onPressed: () => setState(() {
                  _toc = widget.repository.tableOfContents(widget.version.id);
                }),
                child: const Text("Erneut laden"),
              ),
            ],
          );
        }

        // Lange Werke: Die Liste baut nur die sichtbaren Einträge auf.
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: toc.sections.length,
          itemBuilder: (context, i) {
            final s = toc.sections[i];

            return ListTile(
              key: ValueKey("section-${s.number}"),
              dense: true,
              title: Text(s.title),
              subtitle: s.path.isEmpty ? null : Text(s.path.join(" › ")),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openSection(s.number),
            );
          },
        );
      },
    );
  }

  Widget _bibleRefs() {
    return FutureBuilder<List<PassageLink>>(
      future: _links,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final links = snapshot.data;

        if (links == null) {
          return const EmptyHint(
            "Die Bibelstellen konnten nicht geladen werden.",
          );
        }

        if (links.isEmpty) {
          return const EmptyHint(
            "In diesem Werk sind noch keine Bibelstellen erschlossen.",
          );
        }

        return BibleRefIndex(
          links: links,
          onOpenBible: (r) => openBibleReference(context, r),
          onOpenPassage: (l) =>
              _openSection(l.section, (l.firstParagraph, l.lastParagraph)),
        );
      },
    );
  }

  Widget _searchView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey("work-search"),
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Im Text suchen (mind. 3 Zeichen)",
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (q) => setState(() {
            _hits = widget.repository.searchVersion(widget.version.id, q);
          }),
        ),
        const SizedBox(height: 8),
        if (_hits != null)
          FutureBuilder<List<TextHit>>(
            future: _hits,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              final hits = snapshot.data ?? const [];

              if (snapshot.hasError) {
                return const EmptyHint("Die Suche ist fehlgeschlagen.");
              }

              if (hits.isEmpty) {
                return const EmptyHint("Keine Treffer.");
              }

              return Column(
                children: [
                  for (final h in hits)
                    ListTile(
                      dense: true,
                      title: Text(h.snippet),
                      subtitle: Text("Abschnitt ${h.section}"),
                      onTap: () =>
                          _openSection(h.section, (h.paragraph, h.paragraph)),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Herkunft, Ausgabe und Rechte einer Fassung.
class _VersionCard extends StatelessWidget {
  final WorkVersion version;

  const _VersionCard({required this.version});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    TableRow row(String label, String? value) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 4),
          child: Text(label, style: TextStyle(color: colors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(value ?? "–"),
        ),
      ],
    );

    return Card(
      key: const ValueKey("version-card"),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(version.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            VersionTags(version),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {0: IntrinsicColumnWidth()},
              children: [
                row("Übersetzer", version.translator),
                row("Ausgabe", version.series),
                row("Erschienen", version.published ?? version.year),
                row("Quelle", version.sourceName),
                row("Rechte", version.rightsNote ?? version.rights.label),
              ],
            ),
            if (version.sourceUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openExternal(version.sourceUrl!),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text("Bei der Quelle öffnen"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bibelstellen einer Menge von Zuordnungen, nach Buch in kanonischer
/// Reihenfolge.
class BibleRefIndex extends StatelessWidget {
  final List<PassageLink> links;
  final ValueChanged<BibleReference> onOpenBible;
  final ValueChanged<PassageLink> onOpenPassage;

  const BibleRefIndex({
    super.key,
    required this.links,
    required this.onOpenBible,
    required this.onOpenPassage,
  });

  @override
  Widget build(BuildContext context) {
    final byBook = <String, List<PassageLink>>{};

    for (final l in links) {
      byBook.putIfAbsent(l.reference.bookId, () => []).add(l);
    }

    final books = byBook.keys.toList()
      ..sort((a, b) => BibleBooks.order(a).compareTo(BibleBooks.order(b)));

    int position(PassageLink l) =>
        l.reference.chapter * 1000 + (l.reference.verse ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final book in books)
          ExpansionTile(
            key: ValueKey("refs-$book"),
            title: Text(BibleBooks.nameOf(book)),
            subtitle: Text("${byBook[book]!.length} Stellen"),
            children: [
              for (final l
                  in byBook[book]!
                    ..sort((a, b) => position(a).compareTo(position(b))))
                ListTile(
                  dense: true,
                  title: Text(BibleReferenceParser.format(l.reference)),
                  subtitle: Text(l.kind.label),
                  onTap: () => onOpenPassage(l),
                  trailing: IconButton(
                    tooltip: "In der Bibel öffnen",
                    icon: const Icon(Icons.auto_stories_outlined),
                    onPressed: () => onOpenBible(l.reference),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Liest einen Abschnitt eines Werks; Bibelstellen der Ausgabe darin
/// führen in den Reader. [highlight] hebt Absätze hervor (z. B. den Teil,
/// der zu einem Vers gehört).
class SectionReaderScreen extends StatefulWidget {
  final String versionId;
  final int section;
  final (int, int)? highlight;
  final FathersRepository? repository;

  const SectionReaderScreen({
    super.key,
    required this.versionId,
    required this.section,
    this.highlight,
    this.repository,
  });

  @override
  State<SectionReaderScreen> createState() => _SectionReaderScreenState();
}

class _SectionReaderScreenState extends State<SectionReaderScreen> {
  late final FathersRepository repo =
      widget.repository ?? FathersRepository.instance;

  late int _number = widget.section;
  late (int, int)? _highlight = widget.highlight;

  late Future<_SectionData> _data = _load();

  final Map<int, GlobalKey> _keys = {};

  Future<_SectionData> _load() async {
    final library = await repo.library();
    final toc = await repo.tableOfContents(widget.versionId);
    final section = await repo.section(widget.versionId, _number);
    final links = await repo.linksOfVersion(widget.versionId);

    return _SectionData(library, toc, section, [
      for (final l in links)
        if (l.section == _number) l,
    ]);
  }

  void _go(int number) {
    setState(() {
      _number = number;
      _highlight = null;
      _keys.clear();
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SectionData>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (data == null || data.section == null) {
          return ContentPage(
            title: "Abschnitt",
            children: [
              const EmptyHint("Der Abschnitt konnte nicht geladen werden."),
              TextButton(
                key: const ValueKey("section-retry"),
                onPressed: () => setState(() {
                  _data = _load();
                }),
                child: const Text("Erneut laden"),
              ),
            ],
          );
        }

        return _page(context, data);
      },
    );
  }

  Widget _page(BuildContext context, _SectionData data) {
    final colors = context.colors;
    final found = data.library.version(widget.versionId);
    final entry = data.toc.entry(_number);
    final section = data.section!;
    final index = data.toc.sections.indexWhere((s) => s.number == _number);

    final highlight = _highlight;

    if (highlight != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[highlight.$1]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.1);
      });
    }

    // Absatz → Bibelstellen, die die Ausgabe dort nennt.
    final byParagraph = <int, List<PassageLink>>{};

    for (final l in data.links) {
      byParagraph.putIfAbsent(l.firstParagraph, () => []).add(l);
    }

    return ContentPage(
      title: found?.work.title ?? "Abschnitt",
      actions: [InfoButton(module: AppModules.fathers)],
      children: [
        if (found != null)
          Text(
            data.library.author(found.work.authorId)?.name ?? "",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (entry != null)
          Text(
            [...entry.path, entry.title].join(" › "),
            key: const ValueKey("section-title"),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        if (found != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              "${found.version.kind.label} · ${versionCitation(found.version)}"
              "${entry?.sourceRef == null ? "" : " · ${entry!.sourceRef}"}",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        for (int i = 0; i < section.paragraphs.length; i++)
          Container(
            key: _keys.putIfAbsent(i, GlobalKey.new),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            decoration:
                highlight != null && i >= highlight.$1 && i <= highlight.$2
                ? BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  section.paragraphs[i],
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
                if (byParagraph[i] case final refs?)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final l in refs)
                        ActionChip(
                          key: ValueKey("ref-chip-${l.id}"),
                          avatar: const Icon(
                            Icons.auto_stories_outlined,
                            size: 16,
                          ),
                          label: Text(BibleReferenceParser.format(l.reference)),
                          tooltip: l.kind.label,
                          onPressed: () =>
                              openBibleReference(context, l.reference),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        if (section.notes.isNotEmpty) ...[
          const ContentSectionTitle("Anmerkungen der Ausgabe"),
          for (final (i, note) in section.notes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText(
                "[${i + 1}] $note",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 12),
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          children: [
            if (index > 0)
              TextButton.icon(
                key: const ValueKey("section-previous"),
                onPressed: () => _go(data.toc.sections[index - 1].number),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text("Vorheriger Abschnitt"),
              ),
            if (index >= 0 && index < data.toc.sections.length - 1)
              TextButton.icon(
                key: const ValueKey("section-next"),
                onPressed: () => _go(data.toc.sections[index + 1].number),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text("Nächster Abschnitt"),
              ),
          ],
        ),
        if (found != null)
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    WorkScreen(workId: found.work.id, repository: repo),
              ),
            ),
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text("Zum Werk"),
          ),
      ],
    );
  }
}

class _SectionData {
  final FathersLibrary library;
  final WorkTableOfContents toc;
  final WorkSection? section;
  final List<PassageLink> links;

  const _SectionData(this.library, this.toc, this.section, this.links);
}
