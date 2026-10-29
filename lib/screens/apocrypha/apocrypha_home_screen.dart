import 'dart:async';

import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/apocrypha/apocrypha.dart';
import '../../services/apocrypha/apocrypha_repository.dart';
import '../../services/apocrypha/apocrypha_user_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/info_report.dart';
import 'apocrypha_reader_screen.dart';
import 'apocrypha_widgets.dart';
import 'apocrypha_work_screen.dart';

/// Kurze Erklärung je Kategorie für die Übersicht.
const Map<String, String> apocryphaCategoryHints = {
  "deuterokanonisch":
      "Bücher der Septuaginta außerhalb der hebräischen Bibel. Katholisch "
      "und orthodox kanonisch, in Luthers Bibel als Anhang „Apokryphen“.",
  "pseudepigraphen":
      "Jüdische Schriften unter dem Namen biblischer Gestalten, meist aus "
      "der Zeit des Zweiten Tempels.",
  "evangelien":
      "Außerkanonische Evangelien und Jesusüberlieferung, viele nur in "
      "Fragmenten erhalten.",
  "apostolische_vaeter":
      "Christliche Schriften des späten 1. und 2. Jahrhunderts, die "
      "kirchlich gelesen, aber nicht in den Kanon aufgenommen wurden.",
  "kirchenordnungen": "Frühchristliche Gemeindeordnungen und Unterweisungen.",
  "apokalypsen": "Jüdische und christliche Offenbarungsschriften.",
  "apostelakten": "Legendarische Erzählungen über Apostel.",
  "nag_hammadi": "Koptische Funde von 1945 und verwandte gnostische Schriften.",
  "poesie": "Psalmen, Oden und Gebete außerhalb des Psalters.",
  "fruehchristlich": "Weitere frühchristliche Schriften und Kanonlisten.",
};

/// Hauptbereich „Apokryphen & außerkanonische Schriften“.
class ApocryphaHomeScreen extends StatefulWidget {
  final String? uid;
  final ApocryphaRepository? repository;
  final ApocryphaUserData? userData;

  const ApocryphaHomeScreen({
    super.key,
    this.uid,
    this.repository,
    this.userData,
  });

  @override
  State<ApocryphaHomeScreen> createState() => _ApocryphaHomeScreenState();
}

class _ApocryphaHomeScreenState extends State<ApocryphaHomeScreen> {
  late final ApocryphaRepository repo =
      widget.repository ?? ApocryphaRepository.instance;
  late final ApocryphaUserData userData =
      widget.userData ?? ApocryphaUserData.forUser(widget.uid);

  late Future<ApocryphaCatalog> _catalog = repo.catalog();
  ApocryphaUserState user = const ApocryphaUserState();

  final TextEditingController _query = TextEditingController();
  String query = "";
  ApocryphaFilter filter = const ApocryphaFilter();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final state = await userData.load();
      if (mounted) setState(() => user = state);
    } catch (_) {
      // Ohne gespeicherte Daten weiterlesen.
    }
  }

  Future<void> _openWork(String workId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApocryphaWorkScreen(
          workId: workId,
          repository: repo,
          userData: userData,
        ),
      ),
    );
    _loadUser();
  }

  Future<void> _openReader(
    String workId, {
    String? versionId,
    String? unitId,
    String? block,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApocryphaReaderScreen(
          workId: workId,
          versionId: versionId,
          unitId: unitId,
          highlightBlock: block,
          repository: repo,
          userData: userData,
        ),
      ),
    );
    _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Apokryphen & außerkanonische Schriften"),
        actions: [
          IconButton(
            key: const ValueKey("apocrypha-bookmarks"),
            tooltip: "Lesezeichen",
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () async {
              final catalog = await _catalog;
              if (!context.mounted) return;
              _showBookmarks(context, catalog);
            },
          ),
          InfoButton(module: AppModules.apocrypha),
        ],
      ),
      body: FutureBuilder<ApocryphaCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = snapshot.data;
          if (catalog == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyHint("Der Katalog konnte nicht geladen werden."),
                  TextButton(
                    onPressed: () => setState(() {
                      _catalog = repo.catalog();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      key: const ValueKey("apocrypha-search"),
                      controller: _query,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Titel, Name oder Übersetzer",
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: "Suche leeren",
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _query.clear();
                                  setState(() => query = "");
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => query = v.trim()),
                    ),
                  ),
                  _filters(context, catalog),
                  Expanded(
                    child: query.isEmpty && filter.isEmpty
                        ? _overview(context, catalog)
                        : _results(context, catalog),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filters(BuildContext context, ApocryphaCatalog catalog) {
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

    Widget toggle(
      String key,
      String label,
      bool value,
      ValueChanged<bool> on,
    ) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        key: ValueKey(key),
        label: Text(label),
        selected: value,
        onSelected: (v) => setState(() => on(v)),
      ),
    );

    final languages = {for (final w in catalog.works) ...w.textLanguages};

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          menu<String>(
            key: const ValueKey("apocrypha-filter-category"),
            label: "Gruppe",
            value: filter.category,
            options: {for (final c in catalog.categories) c.id: c.label},
            onChanged: (v) =>
                setState(() => filter = filter.copyWith(category: v)),
          ),
          const SizedBox(width: 8),
          menu<Tradition>(
            key: const ValueKey("apocrypha-filter-tradition"),
            label: "Herkunft",
            value: filter.tradition,
            options: {for (final t in Tradition.values) t: t.label},
            onChanged: (v) =>
                setState(() => filter = filter.copyWith(tradition: v)),
          ),
          const SizedBox(width: 8),
          menu<ApocryphaEpoch>(
            key: const ValueKey("apocrypha-filter-epoch"),
            label: "Epoche",
            value: filter.epoch,
            options: {for (final e in ApocryphaEpoch.values) e: e.label},
            onChanged: (v) =>
                setState(() => filter = filter.copyWith(epoch: v)),
          ),
          const SizedBox(width: 8),
          menu<String>(
            key: const ValueKey("apocrypha-filter-language"),
            label: "Sprache",
            value: filter.language,
            options: {
              for (final e in apocryphaLanguages.entries)
                if (languages.contains(e.key)) e.key: e.value,
            },
            onChanged: (v) =>
                setState(() => filter = filter.copyWith(language: v)),
          ),
          const SizedBox(width: 8),
          menu<int>(
            key: const ValueKey("apocrypha-filter-translations"),
            label: "Übersetzungen",
            value: filter.minTranslations == 0 ? null : filter.minTranslations,
            options: const {
              1: "mind. 1 Übersetzung",
              2: "mind. 2 Übersetzungen",
            },
            onChanged: (v) => setState(
              () => filter = filter.copyWith(minTranslations: v ?? 0),
            ),
          ),
          toggle(
            "apocrypha-filter-text",
            "Mit Volltext",
            filter.textOnly,
            (v) => filter = filter.copyWith(textOnly: v),
          ),
          toggle(
            "apocrypha-filter-original",
            "Originaltext",
            filter.originalOnly,
            (v) => filter = filter.copyWith(originalOnly: v),
          ),
          toggle(
            "apocrypha-filter-complete",
            "Vollständig",
            filter.completeOnly,
            (v) => filter = filter.copyWith(
              completeOnly: v,
              fragmentaryOnly: v ? false : null,
            ),
          ),
          toggle(
            "apocrypha-filter-fragmentary",
            "Fragmentarisch",
            filter.fragmentaryOnly,
            (v) => filter = filter.copyWith(
              fragmentaryOnly: v,
              completeOnly: v ? false : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Startansicht: Weiterlesen, Merkliste und die Gruppen statt einer
  /// langen Liste.
  Widget _overview(BuildContext context, ApocryphaCatalog catalog) {
    final colors = context.colors;
    final recent = [
      for (final p in user.recent)
        if (catalog.work(p.workId) != null) p,
    ].take(3).toList();
    final favorites = [
      for (final id
          in (user.favorites.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => e.key))
        ?catalog.work(id),
    ];
    final withText = catalog.works.where((w) => w.hasText).length;

    return ListView(
      key: const ValueKey("apocrypha-overview"),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          "${catalog.works.length} Werke, davon $withText mit Text in der App. "
          "Ob eine Schrift als „apokryph“ gilt, hängt von der Kirche ab; "
          "jede Werkseite nennt den Status je Kirche.",
          style: TextStyle(color: colors.textSecondary),
        ),
        if (recent.isNotEmpty) ...[
          const ContentSectionTitle("Weiterlesen"),
          for (final p in recent) _recentTile(context, catalog, p),
        ],
        if (favorites.isNotEmpty) ...[
          const ContentSectionTitle("Merkliste"),
          for (final w in favorites)
            ApocryphaWorkTile(
              work: w,
              favorite: true,
              onTap: () => _openWork(w.id),
            ),
        ],
        const ContentSectionTitle("Gruppen"),
        for (final c in catalog.categories) _categoryCard(context, catalog, c),
      ],
    );
  }

  Widget _recentTile(
    BuildContext context,
    ApocryphaCatalog catalog,
    ReadingPosition p,
  ) {
    final work = catalog.work(p.workId)!;
    final version = catalog.version(p.versionId);
    return ListTile(
      key: ValueKey("apocrypha-recent-${work.id}"),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.play_circle_outline_rounded),
      title: Text(work.title),
      subtitle: Text(version?.label ?? p.versionId),
      onTap: () =>
          _openReader(work.id, versionId: p.versionId, unitId: p.unitId),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    ApocryphaCatalog catalog,
    ApocryphaCategory c,
  ) {
    final works = catalog.worksIn(c.id);
    final readable = works.where((w) => w.hasText).length;
    return Card(
      key: ValueKey("apocrypha-category-${c.id}"),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => filter = filter.copyWith(category: c.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (apocryphaCategoryHints[c.id] != null) ...[
                const SizedBox(height: 4),
                Text(apocryphaCategoryHints[c.id]!),
              ],
              const SizedBox(height: 6),
              Text(
                "${works.length} Werke · $readable mit Text",
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results(BuildContext context, ApocryphaCatalog catalog) {
    final works = ApocryphaSearch.works(catalog, query, filter);
    final colors = context.colors;
    final category = filter.category;

    return ListView.builder(
      key: const ValueKey("apocrypha-results"),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      itemCount: works.length + 1 + (works.isEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null &&
                    apocryphaCategoryHints[category] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(apocryphaCategoryHints[category]!),
                  ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      "${works.length} von ${catalog.works.length} Werken",
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    TextButton(
                      key: const ValueKey("apocrypha-reset"),
                      onPressed: () => setState(() {
                        filter = const ApocryphaFilter();
                        query = "";
                        _query.clear();
                      }),
                      child: const Text("Zur Übersicht"),
                    ),
                    if (query.length >= 3)
                      TextButton.icon(
                        key: const ValueKey("apocrypha-fulltext"),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApocryphaFullTextScreen(
                              query: query,
                              works: works.isEmpty ? null : works,
                              language: filter.language,
                              repository: repo,
                              userData: userData,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.manage_search_rounded, size: 18),
                        label: const Text("In den Texten suchen"),
                      ),
                  ],
                ),
              ],
            ),
          );
        }
        if (works.isEmpty) {
          return const EmptyHint("Keine Werke gefunden.");
        }
        final w = works[i - 1];
        return ApocryphaWorkTile(
          work: w,
          favorite: user.isFavorite(w.id),
          onTap: () => _openWork(w.id),
        );
      },
    );
  }

  void _showBookmarks(BuildContext context, ApocryphaCatalog catalog) {
    final bookmarks = [
      for (final b in user.bookmarkList)
        if (catalog.version(b.versionId) != null) b,
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: bookmarks.isEmpty
            ? const EmptyHint(
                "Noch keine Lesezeichen. Im Leser einen Vers oder Absatz "
                "lange antippen, um ein Lesezeichen zu setzen.",
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final b in bookmarks)
                    ListTile(
                      leading: const Icon(Icons.bookmark_rounded),
                      title: Text(catalog.work(b.workId)?.title ?? b.workId),
                      subtitle: Text(
                        "${catalog.version(b.versionId)!.label} · "
                        "${b.unitId}${b.block.startsWith("#") ? "" : ", ${b.block}"}",
                      ),
                      onTap: () {
                        Navigator.pop(sheet);
                        _openReader(
                          b.workId,
                          versionId: b.versionId,
                          unitId: b.unitId,
                          block: b.block,
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

/// Volltextsuche in den Fassungen mit eigenem Text.
class ApocryphaFullTextScreen extends StatefulWidget {
  final String query;
  final Iterable<ApocryphaWork>? works;
  final String? language;
  final ApocryphaRepository repository;
  final ApocryphaUserData userData;

  const ApocryphaFullTextScreen({
    super.key,
    required this.query,
    required this.repository,
    required this.userData,
    this.works,
    this.language,
  });

  @override
  State<ApocryphaFullTextScreen> createState() =>
      _ApocryphaFullTextScreenState();
}

class _ApocryphaFullTextScreenState extends State<ApocryphaFullTextScreen> {
  final List<FullTextHit> hits = [];
  StreamSubscription<FullTextHit>? _search;
  bool done = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _search = widget.repository
        .fullText(widget.query, language: widget.language, works: widget.works)
        .listen(
          (hit) => setState(() => hits.add(hit)),
          onError: (Object _) => setState(() => failed = done = true),
          onDone: () => setState(() => done = true),
        );
  }

  @override
  void dispose() {
    _search?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    return Scaffold(
      appBar: AppBar(title: Text("„$query“ in den Texten")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentPage.maxWidth),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: hits.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      failed
                          ? "Die Suche wurde wegen eines Ladefehlers abgebrochen."
                          : done
                          ? "${hits.length} Treffer"
                                "${hits.length >= 200 ? " (Suche nach 200 Treffern beendet)" : ""}. "
                                "Septuaginta und Vulgata durchsucht die Bibelsuche."
                          : "Suche … ${hits.length} Treffer",
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    if (!done) const LinearProgressIndicator(),
                    if (done && hits.isEmpty)
                      const EmptyHint("Keine Treffer in den Texten."),
                  ],
                );
              }
              final h = hits[i - 1];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "${h.work.title} · ${h.unit.fullLabel}"
                  "${h.block.number.isEmpty ? "" : ", ${h.block.number}"}",
                ),
                subtitle: Text(
                  "${h.version.label}\n${_excerpt(h.block.text, query)}",
                  style: apocryphaTextStyle(
                    context,
                    h.version.language,
                    scale: 0.85,
                    color: context.colors.textSecondary,
                  ),
                ),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApocryphaReaderScreen(
                      workId: h.work.id,
                      versionId: h.version.id,
                      unitId: h.unit.id,
                      highlightBlock: h.block.number.isEmpty
                          ? null
                          : h.block.number,
                      repository: widget.repository,
                      userData: widget.userData,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _excerpt(String text, String query) {
    final i = text.toLowerCase().indexOf(query.toLowerCase());
    if (i < 0 || text.length <= 160) {
      return text.length <= 160 ? text : "${text.substring(0, 160)} …";
    }
    final start = (i - 60).clamp(0, text.length);
    final end = (i + query.length + 80).clamp(0, text.length);
    return "${start > 0 ? "… " : ""}${text.substring(start, end)}"
        "${end < text.length ? " …" : ""}";
  }
}
