import 'package:flutter/material.dart';

import '../../models/apocrypha/apocrypha.dart';
import '../../services/apocrypha/apocrypha_repository.dart';
import '../../services/apocrypha/apocrypha_user_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import 'apocrypha_widgets.dart';

/// Zeile der Vergleichsansicht: Vers/Absatz der gewählten Fassung und die
/// gleich gezählten der Vergleichsfassung.
class AlignedRow {
  final List<TextBlock> primary;
  final List<TextBlock> secondary;

  const AlignedRow(this.primary, this.secondary);
}

/// Ordnet zwei Fassungen derselben Einheit einander zu: nach Versnummer,
/// wenn beide nummeriert sind, sonst bei gleicher Zahl der Absätze der
/// Reihe nach. Passt beides nicht, stehen beide Texte als Ganzes
/// nebeneinander (eine Zeile).
List<AlignedRow> alignBlocks(List<TextBlock> a, List<TextBlock> b) {
  bool numbered(List<TextBlock> x) =>
      x.isNotEmpty && x.every((t) => t.number.isNotEmpty);

  if (numbered(a) && numbered(b)) {
    final byNumber = <String, List<TextBlock>>{};
    for (final t in b) {
      byNumber.putIfAbsent(t.number, () => []).add(t);
    }
    final rows = <AlignedRow>[];
    final used = <String>{};
    for (final t in a) {
      final match = used.add(t.number)
          ? byNumber[t.number] ?? const <TextBlock>[]
          : const <TextBlock>[];
      rows.add(AlignedRow([t], match));
    }
    final rest = [
      for (final t in b)
        if (!used.contains(t.number)) t,
    ];
    if (rest.isNotEmpty) rows.add(AlignedRow(const [], rest));
    // Kaum Übereinstimmungen: andere Zählung, nicht zeilenweise vergleichen.
    if (rest.length > b.length / 2) return [AlignedRow(a, b)];
    return rows;
  }
  if (a.length == b.length) {
    return [
      for (var i = 0; i < a.length; i++) AlignedRow([a[i]], [b[i]]),
    ];
  }
  return [AlignedRow(a, b)];
}

/// Leser einer Fassung mit Fassungswechsel, Vergleichsansicht,
/// Abschnittsnavigation, Lesezeichen und gespeicherter Position.
class ApocryphaReaderScreen extends StatefulWidget {
  final String workId;

  /// Ohne Angabe: zuletzt gewählte Fassung, sonst die Standardfassung.
  final String? versionId;

  /// Ohne Angabe: erster Abschnitt.
  final String? unitId;

  /// Vers/Absatz, der hervorgehoben und angesprungen wird.
  final String? highlightBlock;
  final ApocryphaRepository repository;
  final ApocryphaUserData userData;

  const ApocryphaReaderScreen({
    super.key,
    required this.workId,
    required this.repository,
    required this.userData,
    this.versionId,
    this.unitId,
    this.highlightBlock,
  });

  @override
  State<ApocryphaReaderScreen> createState() => _ApocryphaReaderScreenState();
}

class _ApocryphaReaderScreenState extends State<ApocryphaReaderScreen> {
  ApocryphaRepository get repo => widget.repository;

  ApocryphaWork? work;
  ApocryphaVersion? version;
  ApocryphaVersion? parallel;
  List<TocUnit> toc = const [];
  List<TocUnit> parallelToc = const [];
  int index = 0;
  Future<(UnitText, UnitText?)>? _text;
  ApocryphaUserState user = const ApocryphaUserState();
  double scale = 1;
  String? highlight;
  Object? error;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    highlight = widget.highlightBlock;
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final catalog = await repo.catalog();
      try {
        user = await widget.userData.load();
      } catch (_) {}
      final work = catalog.work(widget.workId);
      if (work == null) throw StateError("Werk ${widget.workId} fehlt");
      ApocryphaVersion? pick(String? id) {
        final v = id == null ? null : catalog.version(id);
        return v != null && v.workId == work.id && v.hasText ? v : null;
      }

      final version =
          pick(widget.versionId) ??
          pick(user.versions[work.id]) ??
          work.defaultVersion;
      if (version == null) throw StateError("Kein Text zu ${work.id}");
      var parallel = pick(user.parallels[work.id]);
      if (parallel?.id == version.id) parallel = null;

      final toc = await repo.toc(version.id);
      final parallelToc = parallel == null
          ? const <TocUnit>[]
          : await repo.toc(parallel.id);
      final start = toc.indexWhere((u) => u.id == widget.unitId);

      if (!mounted) return;
      setState(() {
        this.work = work;
        this.version = version;
        this.parallel = parallel;
        this.toc = toc;
        this.parallelToc = parallelToc;
        scale = user.textScale;
        index = start < 0 ? 0 : start;
      });
      _loadUnit();
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void _loadUnit() {
    final unit = toc[index];
    final p = parallel;
    final pUnit = p == null
        ? null
        : parallelToc.where((u) => u.id == unit.id).firstOrNull;
    setState(() {
      _text = () async {
        final main = await repo.unit(version!.id, unit);
        final other = p == null || pUnit == null
            ? null
            : await repo.unit(p.id, pUnit);
        return (main, other);
      }();
    });
    widget.userData
        .setPosition(
          ReadingPosition(
            workId: work!.id,
            versionId: version!.id,
            unitId: unit.id,
            updated: DateTime.now(),
          ),
        )
        .catchError((Object _) {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _go(int i) {
    if (i < 0 || i >= toc.length) return;
    highlight = null;
    index = i;
    _loadUnit();
  }

  Future<void> _switchVersion(ApocryphaVersion v) async {
    final unitId = toc[index].id;
    final newToc = await repo.toc(v.id);
    if (!mounted) return;
    final i = newToc.indexWhere((u) => u.id == unitId);
    setState(() {
      version = v;
      toc = newToc;
      index = i < 0 ? 0 : i;
      if (parallel?.id == v.id) {
        parallel = null;
        parallelToc = const [];
      }
    });
    widget.userData.setVersion(work!.id, v.id).catchError((Object _) {});
    if (parallel == null) {
      widget.userData.setParallel(work!.id, null).catchError((Object _) {});
    }
    _loadUnit();
  }

  Future<void> _setParallel(ApocryphaVersion? v) async {
    final newToc = v == null ? const <TocUnit>[] : await repo.toc(v.id);
    if (!mounted) return;
    setState(() {
      parallel = v;
      parallelToc = newToc;
    });
    widget.userData.setParallel(work!.id, v?.id).catchError((Object _) {});
    _loadUnit();
  }

  void _setScale(double value) {
    setState(() => scale = value.clamp(0.8, 1.6));
    widget.userData.setTextScale(scale).catchError((Object _) {});
  }

  String _blockKey(TextBlock b, int i) => b.number.isEmpty ? "#$i" : b.number;

  Future<void> _toggleBookmark(String block) async {
    final mark = ApocryphaBookmark(
      versionId: version!.id,
      unitId: toc[index].id,
      block: block,
      added: DateTime.now(),
    );
    final set = !user.bookmarks.containsKey(mark.key);
    setState(() {
      user = ApocryphaUserState(
        positions: user.positions,
        favorites: user.favorites,
        versions: user.versions,
        parallels: user.parallels,
        textScale: user.textScale,
        bookmarks: {...user.bookmarks, if (set) mark.key: mark}
          ..removeWhere((k, _) => !set && k == mark.key),
      );
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(set ? "Lesezeichen gesetzt." : "Lesezeichen entfernt."),
          duration: const Duration(seconds: 2),
        ),
      );
    try {
      await widget.userData.setBookmark(mark, set);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final work = this.work;
    final version = this.version;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyHint("Der Text konnte nicht geladen werden."),
      );
    }
    if (work == null || version == null || toc.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final unit = toc[index];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(work.title, overflow: TextOverflow.ellipsis),
            Text(
              version.label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<ApocryphaVersion>(
            key: const ValueKey("apocrypha-version-menu"),
            tooltip: "Fassung wählen",
            icon: const Icon(Icons.translate_rounded),
            onSelected: _switchVersion,
            itemBuilder: (_) => [
              for (final v in work.readableVersions)
                CheckedPopupMenuItem(
                  value: v,
                  checked: v.id == version.id,
                  child: Text(v.label),
                ),
            ],
          ),
          if (work.readableVersions.length > 1)
            PopupMenuButton<String>(
              key: const ValueKey("apocrypha-parallel-menu"),
              tooltip: "Vergleichen mit",
              icon: Icon(
                parallel == null
                    ? Icons.vertical_split_outlined
                    : Icons.vertical_split_rounded,
              ),
              onSelected: (id) => _setParallel(
                id.isEmpty
                    ? null
                    : work.readableVersions.firstWhere((v) => v.id == id),
              ),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: "",
                  checked: parallel == null,
                  child: const Text("Ohne Vergleich"),
                ),
                for (final v in work.readableVersions)
                  if (v.id != version.id)
                    CheckedPopupMenuItem(
                      value: v.id,
                      checked: v.id == parallel?.id,
                      child: Text(v.label),
                    ),
              ],
            ),
          PopupMenuButton<String>(
            tooltip: "Ansicht",
            onSelected: (v) => switch (v) {
              "bigger" => _setScale(scale + 0.1),
              "smaller" => _setScale(scale - 0.1),
              _ => _showToc(context),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "toc", child: Text("Inhaltsverzeichnis")),
              PopupMenuItem(value: "bigger", child: Text("Schrift größer")),
              PopupMenuItem(value: "smaller", child: Text("Schrift kleiner")),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<(UnitText, UnitText?)>(
          future: _text,
          builder: (context, snapshot) {
            final data = snapshot.data;
            Widget body;
            if (snapshot.hasError) {
              body = Column(
                children: [
                  const EmptyHint("Der Abschnitt konnte nicht geladen werden."),
                  TextButton(
                    onPressed: _loadUnit,
                    child: const Text("Erneut laden"),
                  ),
                ],
              );
            } else if (data == null) {
              body = const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              body = _unitBody(context, unit, data.$1, data.$2);
            }
            return SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: parallel == null ? ContentPage.maxWidth : 1100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(context, version, unit),
                      body,
                      _navigation(context),
                      _sourceNote(context, version),
                      if (parallel != null) _sourceNote(context, parallel!),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ApocryphaVersion version, TocUnit unit) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (version.coverage != Coverage.full)
          Container(
            key: const ValueKey("apocrypha-coverage-note"),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.accent.withValues(alpha: 0.6)),
            ),
            child: Text(
              "Fassung ${version.coverage.label}"
              "${version.coverageNote == null ? "" : ": ${version.coverageNote}"}",
            ),
          ),
        InkWell(
          key: const ValueKey("apocrypha-toc-button"),
          onTap: () => _showToc(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    unit.fullLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  "${index + 1}/${toc.length}",
                  style: TextStyle(color: colors.textSecondary),
                ),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
        if (unit.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              unit.title!,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _unitBody(
    BuildContext context,
    TocUnit unit,
    UnitText main,
    UnitText? other,
  ) {
    final p = parallel;
    final children = <Widget>[];

    if (p == null) {
      for (var i = 0; i < main.blocks.length; i++) {
        children.add(_block(context, main.blocks[i], i, version!, true));
      }
    } else {
      if (other == null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Dieser Abschnitt fehlt in „${p.label}“.",
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        );
      }
      final rows = alignBlocks(main.blocks, other?.blocks ?? const []);
      final wide = MediaQuery.sizeOf(context).width >= 700;
      var i = 0;
      for (final row in rows) {
        final left = [
          for (final b in row.primary) _block(context, b, i++, version!, true),
        ];
        final right = [
          for (final b in row.secondary) _block(context, b, -1, p, false),
        ];
        children.add(
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: left)),
                    const SizedBox(width: 20),
                    Expanded(child: Column(children: right)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...left,
                    if (right.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 12, bottom: 6),
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: context.colors.divider,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(children: right),
                      ),
                  ],
                ),
        );
      }
    }

    void notes(String title, List<String> list) {
      if (list.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      );
      for (var n = 0; n < list.length; n++) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              "[${n + 1}] ${list[n]}",
              style: TextStyle(
                fontSize: 13.5 * scale,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        );
      }
    }

    notes(
      p == null ? "Anmerkungen der Ausgabe" : "Anmerkungen: ${version!.label}",
      main.notes,
    );
    if (other != null && p != null) {
      notes("Anmerkungen: ${p.label}", other.notes);
    }

    return Column(
      key: ValueKey("apocrypha-unit-${unit.id}"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Ein Vers/Absatz. [i] < 0: Vergleichsfassung (ohne Lesezeichen).
  Widget _block(
    BuildContext context,
    TextBlock b,
    int i,
    ApocryphaVersion v,
    bool primary,
  ) {
    final colors = context.colors;
    final key = primary ? _blockKey(b, i) : null;
    final marked =
        key != null &&
        user.bookmarks.containsKey(
          ApocryphaBookmark.keyOf(v.id, toc[index].id, key),
        );
    final highlighted = primary && highlight != null && highlight == key;
    final style = apocryphaTextStyle(
      context,
      v.language,
      scale: scale,
      color: primary ? null : colors.textSecondary,
    );

    final spans = <InlineSpan>[];
    if (b.number.isNotEmpty) {
      spans.add(
        TextSpan(
          text: "${b.number} ",
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w700,
            color: colors.primary,
            fontFamily: null,
          ),
        ),
      );
    }
    final marker = RegExp(r"\[\d+\]");
    var last = 0;
    for (final m in marker.allMatches(b.text)) {
      spans.add(TextSpan(text: b.text.substring(last, m.start)));
      spans.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(fontSize: 11 * scale, color: colors.primary),
        ),
      );
      last = m.end;
    }
    spans.add(TextSpan(text: b.text.substring(last)));

    if (highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _highlightKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.2);
        }
      });
    }

    final text = Container(
      key: highlighted ? _highlightKey : null,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: highlighted
          ? BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(style: style, children: spans),
              textDirection: apocryphaTextDirection(v.language),
            ),
          ),
          if (marked)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Icon(
                Icons.bookmark_rounded,
                size: 16,
                color: colors.accent,
              ),
            ),
        ],
      ),
    );
    if (key == null) return text;
    return GestureDetector(
      key: ValueKey("apocrypha-block-$key"),
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _toggleBookmark(key),
      child: text,
    );
  }

  Widget _navigation(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          if (index > 0)
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey("apocrypha-prev"),
                onPressed: () => _go(index - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(
                  toc[index - 1].label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          if (index < toc.length - 1)
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey("apocrypha-next"),
                onPressed: () => _go(index + 1),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(
                  toc[index + 1].label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  /// Pflichtangaben der Lizenz und Herkunft unter jedem Abschnitt.
  Widget _sourceNote(BuildContext context, ApocryphaVersion v) {
    final parts = [
      v.label,
      if (v.translator != null) "Übers.: ${v.translator}",
      if (v.edition != null) v.edition!,
      v.license ?? v.rights.label,
      if (v.attribution != null) v.attribution!,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        parts.join(" · "),
        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
      ),
    );
  }

  void _showToc(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: toc.length,
          itemBuilder: (context, i) {
            final u = toc[i];
            final newGroup =
                u.path.isNotEmpty &&
                (i == 0 || toc[i - 1].path.join() != u.path.join());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (newGroup)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      u.path.join(" · "),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ListTile(
                  selected: i == index,
                  title: Text(u.label),
                  subtitle: u.title == null
                      ? null
                      : Text(
                          u.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () {
                    Navigator.pop(sheet);
                    _go(i);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
