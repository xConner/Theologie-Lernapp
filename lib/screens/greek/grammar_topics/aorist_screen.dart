import 'package:flutter/material.dart';

import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/greek/grammar/grammar_question_picker.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Aoristbildung und die Aorist-Stammformen der Vokabelliste. Die Verben des
/// Aoristblatts stehen auf ihrer eigenen Seite.
class AoristScreen extends StatefulWidget {
  /// Vokabelliste für Tests; sonst wird sie aus den Assets geladen.
  final Future<List<GreekVocabularyEntry>>? vocabulary;

  const AoristScreen({super.key, this.vocabulary});

  /// Verben mit hinterlegter Aorist-Stammform, die nicht auf dem
  /// Aoristblatt stehen, in der Reihenfolge der Vokabelliste.
  static List<GreekVocabularyEntry> stemForms(
    List<GreekVocabularyEntry> vocabulary,
  ) {
    return [
      for (final entry in vocabulary)
        if (entry.type == "verb" &&
            entry.aorist != null &&
            !GrammarQuestionPicker.aoristSheet.contains(entry.lemma))
          entry,
    ];
  }

  @override
  State<AoristScreen> createState() => _AoristScreenState();
}

class _AoristScreenState extends State<AoristScreen> {
  late final Future<List<GreekVocabularyEntry>> _vocabulary =
      widget.vocabulary ?? GreekVocabularyLoader.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GreekVocabularyEntry>>(
      future: _vocabulary,
      builder: (context, snapshot) {
        final vocabulary = snapshot.data;

        return GrammarTopicScaffold(
          title: "Aorist und Stammformen",
          children: [
            const GrammarSection(
              title: "Überblick",
              child: GrammarBulletList([
                "Der Indikativ Aorist hat das Augment und die sekundären "
                    "Endungen.",
                "Schwacher Aorist: Aoriststamm auf -σα (ἔπαυσα, ἔγραψα).",
                "Starker Aorist: eigener Stamm mit den Endungen des "
                    "Imperfekts (ἔλαβον, ἦλθον).",
                "Wurzelaorist: ἔβην, ἔγνων.",
                "Im Aorist sind Medium und Passiv getrennte Formen.",
                "Die häufigsten Verben stehen im Aoristblatt.",
              ]),
            ),

            if (snapshot.hasError)
              const GrammarStatus.error(
                "Die Stammformen konnten nicht geladen werden.",
              )
            else if (vocabulary == null)
              const GrammarStatus.loading()
            else
              GrammarSection(
                title: "Weitere Verben der Vokabelliste",
                description:
                    "Angegeben ist die 1. Person Singular Indikativ Aorist.",
                child: GrammarTable(
                  rows: [
                    const [
                      GrammarCell.header("Präsens"),
                      GrammarCell.header("Aorist"),
                      GrammarCell.header("Bedeutung"),
                    ],
                    for (final entry in AoristScreen.stemForms(vocabulary))
                      [
                        GrammarCell.form(entry.lemma),
                        GrammarCell.form(entry.aorist ?? ""),
                        GrammarCell.text(entry.translations.join(", ")),
                      ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
