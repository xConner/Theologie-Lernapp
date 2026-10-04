import 'package:flutter/material.dart';

import '../models/confession.dart';
import '../services/memorization/memorization_catalog.dart';
import '../widgets/memorization_widgets.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';

class ConfessionDetailScreen extends StatefulWidget {
  final Confession confession;

  const ConfessionDetailScreen({super.key, required this.confession});

  @override
  State<ConfessionDetailScreen> createState() => _ConfessionDetailScreenState();
}

class _ConfessionDetailScreenState extends State<ConfessionDetailScreen> {
  Confession get confession => widget.confession;

  late String selectedLanguage;

  int selectedSectionIndex = 0;

  @override
  void initState() {
    super.initState();

    selectedLanguage = confession.languages.first;
  }

  String languageName(String code) {
    switch (code) {
      case "de":
        return "Deutsch";

      case "en":
        return "Englisch";

      case "la":
        return "Latein";

      case "gr":
        return "Griechisch";

      default:
        return code;
    }
  }

  void changeSection(int index) {
    if (index < 0 || index >= confession.sections.length) {
      return;
    }

    setState(() {
      selectedSectionIndex = index;
    });
  }

  String currentSectionTitle() {
    return confession.sections[selectedSectionIndex].title[selectedLanguage] ??
        confession.sections[selectedSectionIndex].title["de"] ??
        confession.sections[selectedSectionIndex].id;
  }

  bool get hasMultipleSections => confession.sections.length > 1;

  bool get hasCurrentText =>
      (confession.sections[selectedSectionIndex].texts[selectedLanguage] ?? "")
          .trim()
          .isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          confession.title[selectedLanguage] ??
              confession.title["de"] ??
              confession.id,
        ),

        actions: [
          InfoButton(
            module: AppModules.confessions,
            reportDetails: () => {
              "Bekenntnis":
                  "${confession.title["de"] ?? confession.id} "
                  "(${confession.id})",
              "Sprache": languageName(selectedLanguage),
              if (hasMultipleSections) "Abschnitt": currentSectionTitle(),
            },
          ),
          const SettingsButton(),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      confession.title[selectedLanguage] ??
                          confession.title["de"] ??
                          confession.id,

                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,

                      children: [
                        DropdownButton<String>(
                          value: selectedLanguage,

                          items: confession.languages
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(languageName(lang)),
                                ),
                              )
                              .toList(),

                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedLanguage = value;
                            });
                          },
                        ),

                        // Nur anbieten, wenn der Abschnitt in dieser Sprache
                        // vorliegt.
                        if (hasCurrentText)
                          MemorizeButton(
                            key: const Key("confession_memorize"),
                            work: () => MemorizationCatalog.fromConfession(
                              confession,
                              confession.sections[selectedSectionIndex],
                            ),
                            languageCode: selectedLanguage,
                          ),
                      ],
                    ),

                    // Section-Auswahl nur anzeigen,
                    // wenn mehrere Sections vorhanden sind
                    if (hasMultipleSections) ...[
                      const Divider(height: 32),

                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),

                            onPressed: selectedSectionIndex > 0
                                ? () => changeSection(selectedSectionIndex - 1)
                                : null,
                          ),

                          Expanded(
                            child: DropdownButton<int>(
                              value: selectedSectionIndex,

                              isExpanded: true,

                              items: List.generate(confession.sections.length, (
                                index,
                              ) {
                                final section = confession.sections[index];

                                return DropdownMenuItem(
                                  value: index,

                                  child: Text(
                                    section.title[selectedLanguage] ??
                                        section.title["de"] ??
                                        section.id,
                                  ),
                                );
                              }),

                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                changeSection(value);
                              },
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.arrow_forward),

                            onPressed:
                                selectedSectionIndex <
                                    confession.sections.length - 1
                                ? () => changeSection(selectedSectionIndex + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],

                    const Divider(height: 32),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      SelectableText(
                        confession
                                .sections[selectedSectionIndex]
                                .texts[selectedLanguage] ??
                            "",

                        style: const TextStyle(fontSize: 18, height: 1.5),

                        selectionControls: MaterialTextSelectionControls(),
                      ),

                      // Quellenangabe der angezeigten Sprachfassung.
                      if (hasCurrentText &&
                          confession.sources[selectedLanguage] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 24),

                          child: Text(
                            "Quelle: ${confession.sources[selectedLanguage]}",

                            key: const Key("confession_source"),

                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
