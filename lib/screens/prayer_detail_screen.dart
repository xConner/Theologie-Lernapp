import 'package:flutter/material.dart';

import '../models/prayer.dart';
import '../services/memorization/memorization_catalog.dart';
import '../widgets/memorization_widgets.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';

class PrayerDetailScreen extends StatefulWidget {
  final Prayer prayer;

  const PrayerDetailScreen({super.key, required this.prayer});

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  Prayer get prayer => widget.prayer;

  late String selectedLanguage;

  @override
  void initState() {
    super.initState();

    // Deutsch bevorzugt, sonst die erste vorhandene Fassung.
    final languages = prayer.languages;
    selectedLanguage = languages.contains("de") ? "de" : languages.first;
  }

  Widget buildLanguageSelector() {
    final languages = prayer.languages;

    // Keine Umschaltung, wenn es nur eine Fassung gibt.
    if (languages.length < 2) {
      return Text(
        PrayerLanguages.name(selectedLanguage),
        style: TextStyle(color: context.colors.textSecondary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,

      children: languages.map((language) {
        return ChoiceChip(
          key: Key("prayer_language_$language"),
          label: Text(PrayerLanguages.name(language)),
          selected: selectedLanguage == language,
          onSelected: (_) {
            setState(() {
              selectedLanguage = language;
            });
          },
        );
      }).toList(),
    );
  }

  Widget buildSection(String heading, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(heading, style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 6),

          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = prayer.versionFor(selectedLanguage)!;

    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);

    return Scaffold(
      appBar: AppBar(
        title: Text(prayer.displayTitle),
        actions: [
          InfoButton(
            module: AppModules.prayers,
            reportDetails: () => {
              "Gebet": "${prayer.displayTitle} (${prayer.id})",
              "Fassung": PrayerLanguages.name(selectedLanguage),
            },
          ),
          const SettingsButton(),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  prayer.titleFor(selectedLanguage),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 4),

                Text(
                  "${PrayerTypes.label(prayer.type)} · "
                  "${PrayerTraditions.label(prayer.tradition)}",
                  style: secondary,
                ),

                const SizedBox(height: 16),

                buildLanguageSelector(),

                const Divider(height: 32),

                SelectableText(
                  version.text,
                  key: const Key("prayer_text"),
                  style: const TextStyle(fontSize: 19, height: 1.6),
                ),

                const SizedBox(height: 20),

                MemorizeButton(
                  key: const Key("prayer_memorize"),
                  work: () => MemorizationCatalog.fromPrayer(prayer),
                  languageCode: selectedLanguage,
                ),

                const Divider(height: 40),

                buildSection("Fassung", [
                  Text(
                    "${PrayerLanguages.name(version.language)} – "
                    "${PrayerVersionStatus.label(version)}",
                  ),
                  const SizedBox(height: 4),
                  Text(version.source, style: secondary),
                  if (version.note != null) ...[
                    const SizedBox(height: 4),
                    Text(version.note!, style: secondary),
                  ],
                ]),

                buildSection("Quelle", [
                  Text(prayer.source),
                  if (prayer.author != null) ...[
                    const SizedBox(height: 4),
                    Text("Verfasser: ${prayer.author}", style: secondary),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    "Originalsprache: "
                    "${PrayerLanguages.name(prayer.originalLanguage)}",
                    style: secondary,
                  ),
                  if (prayer.dating != null) ...[
                    const SizedBox(height: 4),
                    Text("Datierung: ${prayer.dating}", style: secondary),
                  ],
                ]),

                if (prayer.description.isNotEmpty)
                  buildSection("Hintergrund", [Text(prayer.description)]),

                buildSection("Tags", [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prayer.tags
                        .map((tag) => Chip(label: Text(PrayerTags.label(tag))))
                        .toList(),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
