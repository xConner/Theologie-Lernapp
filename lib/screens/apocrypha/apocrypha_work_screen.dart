import 'package:flutter/material.dart';

import '../../models/apocrypha/apocrypha.dart';
import '../../services/apocrypha/apocrypha_repository.dart';
import '../../services/apocrypha/apocrypha_user_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/content_page.dart';
import '../../widgets/fathers/fathers_widgets.dart' show openExternal;
import 'apocrypha_reader_screen.dart';
import 'apocrypha_widgets.dart';

/// Werkseite: Einordnung, Forschungsstand, Kanonstatus und Fassungen.
class ApocryphaWorkScreen extends StatefulWidget {
  final String workId;
  final ApocryphaRepository repository;
  final ApocryphaUserData userData;

  const ApocryphaWorkScreen({
    super.key,
    required this.workId,
    required this.repository,
    required this.userData,
  });

  @override
  State<ApocryphaWorkScreen> createState() => _ApocryphaWorkScreenState();
}

class _ApocryphaWorkScreenState extends State<ApocryphaWorkScreen> {
  late final Future<ApocryphaCatalog> _catalog = widget.repository.catalog();
  ApocryphaUserState user = const ApocryphaUserState();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final state = await widget.userData.load();
      if (mounted) setState(() => user = state);
    } catch (_) {}
  }

  Future<void> _read({String? versionId, String? unitId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApocryphaReaderScreen(
          workId: widget.workId,
          versionId: versionId,
          unitId: unitId,
          repository: widget.repository,
          userData: widget.userData,
        ),
      ),
    );
    _loadUser();
  }

  Future<void> _toggleFavorite() async {
    final favorite = !user.isFavorite(widget.workId);
    setState(() {
      user = ApocryphaUserState(
        positions: user.positions,
        bookmarks: user.bookmarks,
        versions: user.versions,
        parallels: user.parallels,
        textScale: user.textScale,
        favorites: {
          ...user.favorites,
          if (favorite) widget.workId: DateTime.now(),
        }..removeWhere((k, _) => !favorite && k == widget.workId),
      );
    });
    try {
      await widget.userData.setFavorite(widget.workId, favorite);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Merkliste nicht gespeichert.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApocryphaCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        final work = snapshot.data?.work(widget.workId);
        if (work == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snapshot.connectionState == ConnectionState.done
                ? const EmptyHint("Werk nicht gefunden.")
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return ContentPage(
          title: work.title,
          actions: [
            IconButton(
              key: const ValueKey("apocrypha-favorite"),
              tooltip: user.isFavorite(work.id)
                  ? "Von der Merkliste entfernen"
                  : "Auf die Merkliste",
              icon: Icon(
                user.isFavorite(work.id)
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
              ),
              onPressed: _toggleFavorite,
            ),
          ],
          children: _content(context, snapshot.data!, work),
        );
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    ApocryphaCatalog catalog,
    ApocryphaWork work,
  ) {
    final colors = context.colors;
    final position = user.positions[work.id];
    final readable = work.readableVersions;
    final attribution = work.attribution;

    return [
      if (work.altTitles.isNotEmpty)
        Text(
          work.altTitles.join(" · "),
          style: TextStyle(color: colors.textSecondary),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final c in work.categories) Tag(catalog.categoryLabel(c)),
          Tag(work.tradition.label),
          Tag(
            work.preservation.label,
            color: work.preservation == Preservation.complete
                ? colors.success
                : colors.accent,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(work.summary),
      const SizedBox(height: 12),
      if (readable.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (position != null && catalog.version(position.versionId) != null)
              FilledButton.icon(
                key: const ValueKey("apocrypha-resume"),
                onPressed: () => _read(
                  versionId: position.versionId,
                  unitId: position.unitId,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Weiterlesen"),
              ),
            if (position == null)
              FilledButton.icon(
                key: const ValueKey("apocrypha-read"),
                onPressed: () => _read(),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text("Lesen"),
              )
            else
              OutlinedButton.icon(
                key: const ValueKey("apocrypha-read"),
                onPressed: () => _read(),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text("Von vorn lesen"),
              ),
          ],
        )
      else
        Text(
          work.noTextReason ??
              "Zu diesem Werk gibt es in der App keinen Text; die Fassungen "
                  "unten verweisen auf Ausgaben.",
          style: TextStyle(color: colors.textSecondary),
        ),
      const ContentSectionTitle("Einordnung"),
      FactRow("Gattung", work.genre),
      FactRow("Entstehung", work.dating.label),
      if (work.place != null) FactRow("Ort", work.place!),
      if (work.originalLanguage != null)
        FactRow("Ursprache", work.originalLanguage!),
      if (attribution != null)
        FactRow(
          attribution.kind == AttributionKind.pseudepigraph
              ? "Zugeschrieben (pseudepigraph)"
              : "Zuschreibung (${attribution.kind.label})",
          [
            attribution.name,
            if (attribution.note != null) attribution.note!,
          ].join(" – "),
        ),
      if (work.transmission != null)
        FactRow("Überlieferung", work.transmission!),
      FactRow(
        "Erhaltung",
        [
          work.preservation.label,
          if (work.preservationNote != null) work.preservationNote!,
        ].join(" – "),
      ),
      if (work.versification != null) FactRow("Zählung", work.versification!),
      if (work.assessments.isNotEmpty) ...[
        const ContentSectionTitle("Forschungsstand"),
        for (final level in AssessmentLevel.values)
          if (work.assessments.any((a) => a.level == level)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                level.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: switch (level) {
                    AssessmentLevel.secure => colors.success,
                    AssessmentLevel.likely => colors.primary,
                    AssessmentLevel.disputed => colors.accent,
                  },
                ),
              ),
            ),
            for (final a in work.assessments)
              if (a.level == level)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text("• ${a.text}"),
                ),
          ],
      ],
      if (work.significance != null) ...[
        const ContentSectionTitle("Bedeutung"),
        Text(work.significance!),
      ],
      if (work.canon.isNotEmpty || work.canonNote != null) ...[
        const ContentSectionTitle("Kanonstatus"),
        if (work.canon.isNotEmpty) _canonTable(context, work),
        if (work.canonNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(work.canonNote!),
          ),
      ],
      const ContentSectionTitle("Fassungen"),
      if (work.translationNote != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(work.translationNote!),
        ),
      if (work.noTranslationReason != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            work.noTranslationReason!,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      for (final v in work.versions) _versionCard(context, catalog, v),
      if (work.links.isNotEmpty) ...[
        const ContentSectionTitle("Weitere Ressourcen"),
        for (final (label, url) in work.links)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_new_rounded),
            title: Text(label),
            onTap: () => openExternal(url),
          ),
      ],
    ];
  }

  Widget _canonTable(BuildContext context, ApocryphaWork work) {
    final colors = context.colors;
    final entries = [...work.canon]
      ..sort(
        (a, b) => canonTraditions.keys
            .toList()
            .indexOf(a.tradition)
            .compareTo(canonTraditions.keys.toList().indexOf(b.tradition)),
      );
    return Column(
      key: const ValueKey("apocrypha-canon"),
      children: [
        for (final c in entries)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    c.traditionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.statusLabel),
                      if (c.note != null)
                        Text(
                          c.note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _versionCard(
    BuildContext context,
    ApocryphaCatalog catalog,
    ApocryphaVersion v,
  ) {
    final colors = context.colors;
    final source = catalog.sources[v.source];
    return Card(
      key: ValueKey("apocrypha-version-${v.id}"),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Tag(languageName(v.language)),
                Tag(v.kind.label),
                Tag(
                  v.coverage.label,
                  color: coverageColor(context, v.coverage),
                ),
                Tag(
                  v.license == null || v.license == v.rights.label
                      ? v.rights.label
                      : "${v.rights.label} · ${v.license}",
                  color: rightsColor(context, v.rights),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (v.coverageNote != null) FactRow("Umfang", v.coverageNote!),
            if (v.translator != null) FactRow("Übersetzer", v.translator!),
            if (v.editor != null) FactRow("Herausgeber", v.editor!),
            if (v.edition != null) FactRow("Ausgabe", v.edition!),
            if (v.year != null) FactRow("Jahr", v.year!),
            if (v.basis != null) FactRow("Vorlage", v.basis!),
            if (v.source == "app")
              const FactRow(
                "Digitale Quelle",
                "Bibelbereich dieser App (dort beschrieben)",
              )
            else if (source != null)
              FactRow("Digitale Quelle", source.name),
            if (v.sourceNote != null) FactRow("Hinweis", v.sourceNote!),
            if (v.rightsNote != null) FactRow("Rechte", v.rightsNote!),
            if (v.attribution != null) FactRow("Nachweis", v.attribution!),
            if (v.transcriptionNote != null)
              FactRow("Wiedergabe", v.transcriptionNote!),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (v.hasText)
                  TextButton.icon(
                    key: ValueKey("apocrypha-read-${v.id}"),
                    onPressed: () => _read(versionId: v.id),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text("Lesen (${v.units} Abschnitte)"),
                  ),
                if (v.url != null)
                  TextButton.icon(
                    onPressed: () => openExternal(v.url!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(v.hasText ? "Quelle" : "Extern lesen"),
                  ),
                if (source != null)
                  TextButton.icon(
                    onPressed: () => openExternal(source.url),
                    icon: const Icon(Icons.source_outlined, size: 18),
                    label: const Text("Digitalisat"),
                  ),
              ],
            ),
            if (!v.hasText && v.url == null)
              Text(
                "Kein Text in der App.",
                style: TextStyle(color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
