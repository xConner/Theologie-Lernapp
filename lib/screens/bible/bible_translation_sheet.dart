import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bible/bible_translation.dart';
import '../../theme/app_theme.dart';

/// Auswahl der Ausgabe, nach Sprache gruppiert. Die Liste entsteht aus den
/// tatsächlich verfügbaren Ausgaben; [containsBook] kennzeichnet Ausgaben,
/// die das aufgeschlagene Buch nicht enthalten.
Future<BibleTranslation?> showBibleTranslationSheet(
  BuildContext context, {
  required List<BibleTranslation> translations,
  required BibleTranslation selected,
  bool Function(BibleTranslation translation)? containsBook,
}) {
  return showModalBottomSheet<BibleTranslation>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: _TranslationList(
          translations: translations,
          selected: selected,
          containsBook: containsBook,
        ),
      ),
    ),
  );
}

class _TranslationList extends StatelessWidget {
  final List<BibleTranslation> translations;
  final BibleTranslation selected;
  final bool Function(BibleTranslation translation)? containsBook;

  const _TranslationList({
    required this.translations,
    required this.selected,
    required this.containsBook,
  });

  @override
  Widget build(BuildContext context) {
    final groups = BibleLanguages.group(translations);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            "Übersetzung wählen",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Text(
              BibleLanguages.label(entry.key),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          for (final translation in entry.value)
            ListTile(
              key: ValueKey("bible-translation-${translation.id}"),
              contentPadding: const EdgeInsets.only(left: 20, right: 8),
              selected: translation.id == selected.id,
              leading: Icon(
                translation.id == selected.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(translation.name),
              subtitle: Text(
                [
                  translation.edition,
                  translation.licenseType,
                  if (containsBook != null && !containsBook!(translation))
                    "enthält das aufgeschlagene Buch nicht",
                ].join(" · "),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: "Quelle und Lizenz",
                onPressed: () => showBibleTranslationInfo(context, translation),
              ),
              onTap: () => Navigator.pop(context, translation),
            ),
        ],
      ],
    );
  }
}

/// Herkunft, Lizenz und Einschränkungen einer Ausgabe.
Future<void> showBibleTranslationInfo(
  BuildContext context,
  BibleTranslation translation,
) {
  Widget section(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(text),
        ],
      ),
    );
  }

  Widget link(String label, String url) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.open_in_new, size: 18),
        label: Text(label),
        onPressed: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(translation.name),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(translation.edition),
              section(
                "Umfang",
                "${translation.books.length} Bücher"
                    "${translation.hasFootnotes ? ", mit Anmerkungen der Ausgabe" : ""}"
                    " · ohne Internetverbindung lesbar",
              ),
              section("Copyright", translation.copyright),
              section("Lizenz", translation.licenseType),
              for (final restriction in translation.restrictions)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText("• $restriction"),
                ),
              if (translation.licenseUrl.isNotEmpty)
                link("Lizenz ansehen", translation.licenseUrl),
              section(
                "Quelle",
                "${translation.sourceName}, Stand "
                    "${translation.sourceUpdated}. Der Wortlaut wurde "
                    "unverändert übernommen; aus der Quelldatei (USFM) wurden "
                    "nur die Formatmarken entfernt.",
              ),
              for (final deviation in translation.deviations)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText("• $deviation"),
                ),
              if (translation.sourceUrl.isNotEmpty)
                link("Quelle ansehen", translation.sourceUrl),
              if (translation.licenseNotice.isNotEmpty)
                section("Hinweis der Quelle", translation.licenseNotice),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Schließen"),
        ),
      ],
    ),
  );
}
