import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/fathers/fathers.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/fathers/fathers_repository.dart';
import '../../theme/app_theme.dart';
import '../content_page.dart';

/// Bausteine der Bibliothek „Kirchenväter & Schriften“ und der
/// Versdetailansicht im Bibel-Reader.

/// Angaben zu Ausgabe, Übersetzer, Jahr und Quelle einer Fassung.
String versionCitation(WorkVersion v) {
  return [
    if (v.translator != null) "Übers. ${v.translator}",
    if (v.series != null) v.series!,
    if (v.published != null) v.published!,
    if (v.year != null && !(v.published ?? "").contains(v.year!)) v.year!,
  ].join(" · ");
}

/// Kennzeichnung von Textart, Verfügbarkeit und Rechtestand.
class VersionTags extends StatelessWidget {
  final WorkVersion version;

  const VersionTags(this.version, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (version.hasText || version.appLink != null)
          Tag(version.kind.label, icon: Icons.history_edu_outlined),
        Tag(
          version.hasText
              ? version.availability.label
              : version.appLink != null
              ? "Text in der App"
              : version.sourceUrl != null
              ? "Nur externer Link"
              : "Nur verzeichnet",
          color: version.hasText ? colors.success : colors.textSecondary,
          icon: version.hasText ? Icons.menu_book_outlined : Icons.link,
        ),
        if (!version.hasText)
          Tag(version.rights.label, icon: Icons.gavel_outlined),
      ],
    );
  }
}

/// Art, Herkunft und Sicherheit einer Zuordnung.
class LinkTags extends StatelessWidget {
  final PassageLink link;

  const LinkTags(this.link, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final color = switch (link.confidence) {
      Confidence.high => colors.primary,
      Confidence.medium => colors.textSecondary,
      Confidence.low => colors.error,
    };

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Tag(link.kind.label, color: color),
        Tag(
          "${link.method.label} · ${link.confidence.label}",
          icon: Icons.link_rounded,
        ),
      ],
    );
  }
}

/// Öffnet [url] außerhalb der App.
Future<void> openExternal(String url) {
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Ein zugeordneter Abschnitt mit Autor, Werk, Fundstelle und den
/// betreffenden Absätzen. Der Text wird erst beim Anzeigen geladen.
class PassageCard extends StatefulWidget {
  final PassageLink link;
  final FathersLibrary library;
  final FathersRepository repository;

  /// Zum vollständigen Werk (an dieser Stelle).
  final VoidCallback? onOpenWork;

  /// Zur Bibelstelle der Zuordnung, z. B. aus der Werkansicht heraus.
  final VoidCallback? onOpenBible;

  /// Höchstzahl gezeigter Absätze; der Rest steht im Werk.
  final int maxParagraphs;

  const PassageCard({
    super.key,
    required this.link,
    required this.library,
    required this.repository,
    this.onOpenWork,
    this.onOpenBible,
    this.maxParagraphs = 3,
  });

  @override
  State<PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<PassageCard> {
  late Future<(WorkSection?, SectionEntry?)> _text = _load();

  Future<(WorkSection?, SectionEntry?)> _load() async {
    final link = widget.link;

    final toc = await widget.repository.tableOfContents(link.versionId);

    final section = await widget.repository.section(
      link.versionId,
      link.section,
    );

    return (section, toc.entry(link.section));
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final colors = context.colors;

    final author = widget.library.author(link.authorId);
    final found = widget.library.version(link.versionId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              author?.name ?? link.authorId,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              found?.work.title ?? link.workId,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            LinkTags(link),
            const SizedBox(height: 8),
            FutureBuilder<(WorkSection?, SectionEntry?)>(
              future: _text,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }

                final section = snapshot.data?.$1;

                if (snapshot.hasError || section == null) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Der Text konnte nicht geladen werden.",
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _text = _load()),
                        child: const Text("Erneut laden"),
                      ),
                    ],
                  );
                }

                return _excerpt(context, section, snapshot.data?.$2);
              },
            ),
            if (found != null) ...[
              const SizedBox(height: 6),
              Text(
                "${found.version.kind.label} · ${versionCitation(found.version)}",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
            Wrap(
              spacing: 4,
              children: [
                if (widget.onOpenWork != null)
                  TextButton.icon(
                    key: ValueKey("open-work-${link.id}"),
                    onPressed: widget.onOpenWork,
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text("Im Werk lesen"),
                  ),
                if (widget.onOpenBible != null)
                  TextButton.icon(
                    key: ValueKey("open-bible-${link.id}"),
                    onPressed: widget.onOpenBible,
                    icon: const Icon(Icons.auto_stories_outlined, size: 18),
                    label: Text(BibleReferenceParser.format(link.reference)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _excerpt(
    BuildContext context,
    WorkSection section,
    SectionEntry? entry,
  ) {
    final link = widget.link;
    final colors = context.colors;

    final last = link.lastParagraph.clamp(0, section.paragraphs.length - 1);
    final first = link.firstParagraph.clamp(0, last);

    final shown = [
      for (int i = first; i <= last && i < first + widget.maxParagraphs; i++)
        section.paragraphs[i],
    ];

    final more = last - first + 1 > shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry != null)
          Text(
            [...entry.path, entry.title].join(" › ") +
                (entry.sourceRef == null ? "" : " (${entry.sourceRef})"),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colors.accent, width: 3)),
          ),
          child: SelectableText(shown.join("\n\n")),
        ),
        if (more)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Gekürzt – der vollständige Abschnitt steht im Werk.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        if (link.citedAs != null || link.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                if (link.citedAs != null)
                  "Stellenangabe der Ausgabe: ${link.citedAs}",
                if (link.note != null) link.note!,
              ].join(" · "),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}
