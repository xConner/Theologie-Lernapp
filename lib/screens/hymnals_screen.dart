import 'package:flutter/material.dart';

import '../info/app_info.dart';
import '../models/hymn.dart';
import '../models/hymnal.dart';
import '../services/hymnal_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hymnal_widgets.dart';
import '../widgets/info_report.dart';
import '../widgets/settings_access.dart';
import 'hymn_detail_screen.dart';
import 'hymn_screen.dart';

/// Eingrenzung der globalen Suche, z. B. „Nur Stammteil“.
class HymnalScope {
  final String id;
  final String label;
  final bool Function(Hymnal hymnal) includes;

  const HymnalScope(this.id, this.label, this.includes);

  /// Die sinnvollen Eingrenzungen für den Katalog: alle, je Gruppe, je Art
  /// (Stammteil, Regionalteile, Ergänzungshefte) und jede Sammlung mit
  /// Liedern, die nicht schon allein eine Art bildet.
  static List<HymnalScope> forLibrary(HymnalLibrary library) {
    final scopes = [HymnalScope("all", "Alle", (_) => true)];

    for (final group in library.groups) {
      final members = library.inGroup(group.id);
      if (members.isEmpty) continue;

      if (members.length > 1) {
        scopes.add(
          HymnalScope(
            "group:${group.id}",
            group.title,
            (h) => h.group == group.id,
          ),
        );
      }

      for (final part in HymnalPart.values) {
        final inPart = library.inGroup(group.id, part);
        final withHymns = [
          for (final hymnal in inPart)
            if (library.hymnsOf(hymnal.id).isNotEmpty) hymnal,
        ];

        if (inPart.length > 1 && withHymns.length > 1) {
          scopes.add(
            HymnalScope(
              "part:${group.id}:${part.name}",
              part.label,
              (h) => h.group == group.id && h.part == part,
            ),
          );
        }

        for (final hymnal in inPart) {
          // Sammlungen ohne Lieder würden immer leer suchen.
          if (inPart.length > 1 && library.hymnsOf(hymnal.id).isEmpty) {
            continue;
          }
          scopes.add(
            HymnalScope(
              "hymnal:${hymnal.id}",
              inPart.length == 1 ? hymnal.title : hymnal.label,
              (h) => h.id == hymnal.id,
            ),
          );
        }
      }
    }

    return scopes;
  }
}

/// Einstieg „Gesangbücher“: globale Suche über alle Sammlungen und darunter
/// die Übersicht der Gesangbücher, Regionalteile, Ergänzungshefte und
/// weiteren Liedsammlungen.
class HymnalsScreen extends StatefulWidget {
  /// Nur für Tests ersetzbar; standardmäßig die ausgelieferten Sammlungen.
  final Future<HymnalLibrary> Function()? loadLibrary;

  const HymnalsScreen({super.key, this.loadLibrary});

  @override
  State<HymnalsScreen> createState() => _HymnalsScreenState();
}

class _HymnalsScreenState extends State<HymnalsScreen> {
  HymnalLibrary? library;
  List<HymnalScope> scopes = const [];
  Object? error;
  bool loading = true;

  final TextEditingController searchController = TextEditingController();
  String query = "";
  String scopeId = "all";

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loaded = await (widget.loadLibrary ?? HymnalService.shared)();
      if (!mounted) return;
      setState(() {
        library = loaded;
        scopes = HymnalScope.forLibrary(loaded);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  HymnalScope get scope =>
      scopes.firstWhere((s) => s.id == scopeId, orElse: () => scopes.first);

  void openHymn(Hymn hymn) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HymnDetailScreen(hymn: hymn, library: library),
      ),
    );
  }

  void openHymnal(Hymnal hymnal) {
    final loaded = library!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HymnScreen(hymnalId: hymnal.id, loadLibrary: () async => loaded),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gesangbücher"),
        actions: const [
          InfoButton(module: AppModules.hymns),
          SettingsButton(),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : library == null
          ? _LoadError(onRetry: load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    key: const Key("hymnals_search"),
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "In allen Gesangbüchern suchen",
                      helperText:
                          "Nummer, Titel, Liedtext, Dichter oder Bibelstelle",
                      border: const OutlineInputBorder(),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: "Suche leeren",
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = "");
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                _ScopeBar(
                  scopes: scopes,
                  selected: scope.id,
                  onSelected: (id) => setState(() => scopeId = id),
                ),
                if (library!.failed.isNotEmpty) _FailedNotice(library!),
                Expanded(
                  child: query.trim().isEmpty && scope.id == "all"
                      ? _Overview(library: library!, onOpen: openHymnal)
                      : _Results(
                          library: library!,
                          query: query,
                          scope: scope,
                          onOpen: openHymn,
                        ),
                ),
              ],
            ),
    );
  }
}

class _ScopeBar extends StatelessWidget {
  final List<HymnalScope> scopes;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ScopeBar({
    required this.scopes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key("hymnal_scopes"),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final scope in scopes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey("hymnal-scope-${scope.id}"),
                label: Text(scope.label),
                selected: scope.id == selected,
                onSelected: (_) => onSelected(scope.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final HymnalLibrary library;
  final ValueChanged<Hymnal> onOpen;

  const _Overview({required this.library, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget heading(String text, {bool sub = false}) => Padding(
      padding: EdgeInsets.fromLTRB(16, sub ? 8 : 16, 16, 4),
      child: Text(
        text,
        style: sub
            ? theme.textTheme.labelLarge?.copyWith(
                color: context.colors.textSecondary,
              )
            : theme.textTheme.titleMedium,
      ),
    );

    return ListView(
      key: const Key("hymnals_overview"),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final group in library.groups)
          if (library.inGroup(group.id).isNotEmpty) ...[
            heading(group.title),
            for (final part in HymnalPart.values)
              if (library.inGroup(group.id, part).isNotEmpty) ...[
                // Eine Zwischenüberschrift nur, wo die Art mehrere Einträge
                // hat oder neben anderen Arten steht.
                if (part != HymnalPart.core &&
                    library.inGroup(group.id).length >
                        library.inGroup(group.id, part).length)
                  heading(part.label, sub: true),
                for (final hymnal in library.inGroup(group.id, part))
                  HymnalTile(
                    hymnal: hymnal,
                    hymns: library.hymnsOf(hymnal.id),
                    failed: library.failed.contains(hymnal.id),
                    onTap: () => onOpen(hymnal),
                  ),
              ],
          ],
      ],
    );
  }
}

class _Results extends StatelessWidget {
  final HymnalLibrary library;
  final String query;
  final HymnalScope scope;
  final ValueChanged<Hymn> onOpen;

  const _Results({
    required this.library,
    required this.query,
    required this.scope,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final included = {
      for (final hymnal in library.hymnals)
        if (scope.includes(hymnal)) hymnal.id,
    };
    bool inScope(Hymn hymn) => included.contains(hymn.collectionId);

    if (query.trim().isEmpty) {
      // Nur eingegrenzt: die Lieder der gewählten Sammlungen der Reihe nach.
      final hymns = [
        for (final hymnal in library.hymnals)
          if (included.contains(hymnal.id)) ...library.hymnsOf(hymnal.id),
      ];
      if (hymns.isEmpty) return _empty(context, included);
      return ListView.builder(
        key: const Key("hymnals_results"),
        itemCount: hymns.length,
        itemBuilder: (context, index) => HymnTile(
          hymn: hymns[index],
          hymnal: library.hymnalOf(hymns[index]),
          onTap: () => onOpen(hymns[index]),
        ),
      );
    }

    final hits = library.index.search(query, where: inScope);
    if (hits.isEmpty) return _empty(context, included);

    return ListView.builder(
      key: const Key("hymnals_results"),
      itemCount: hits.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              hits.length == 1 ? "1 Treffer" : "${hits.length} Treffer",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          );
        }
        final hit = hits[index - 1];
        return HymnTile(
          hymn: hit.hymn,
          hymnal: library.hymnalOf(hit.hymn),
          snippet: hit.snippet,
          onTap: () => onOpen(hit.hymn),
        );
      },
    );
  }

  Widget _empty(BuildContext context, Set<String> included) {
    final withoutHymns = [
      for (final hymnal in library.hymnals)
        if (included.contains(hymnal.id) && library.hymnsOf(hymnal.id).isEmpty)
          hymnal.title,
    ];

    return Center(
      key: const Key("hymnals_no_results"),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          [
            query.trim().isEmpty
                ? "Keine Lieder in dieser Auswahl."
                : "Keine Lieder gefunden.",
            if (withoutHymns.isNotEmpty)
              "Noch ohne Lieder in der App: ${withoutHymns.join(", ")}.",
          ].join("\n"),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FailedNotice extends StatelessWidget {
  final HymnalLibrary library;

  const _FailedNotice(this.library);

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final id in library.failed) library.hymnal(id)?.title ?? id,
    ];

    return Padding(
      key: const Key("hymnals_failed"),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        "Nicht geladen: ${names.join(", ")}. Die übrigen Sammlungen sind "
        "durchsuchbar.",
        style: TextStyle(color: context.colors.error),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key("hymnals_error"),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Die Gesangbücher konnten nicht geladen werden.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text("Erneut versuchen"),
            ),
          ],
        ),
      ),
    );
  }
}
