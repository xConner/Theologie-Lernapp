import 'package:flutter/material.dart';

import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/greek/grammar/grammar_question_picker.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Aoristbildung und die Aorist-Stammformen der Vokabelliste.
class AoristScreen extends StatefulWidget {
  /// Vokabelliste für Tests; sonst wird sie aus den Assets geladen.
  final Future<List<GreekVocabularyEntry>>? vocabulary;

  const AoristScreen({super.key, this.vocabulary});

  /// Verben mit hinterlegter Aorist-Stammform: zuerst die des Aoristblatts
  /// in dessen Reihenfolge, dann die übrigen in der Reihenfolge der
  /// Vokabelliste.
  static ({List<GreekVocabularyEntry> sheet, List<GreekVocabularyEntry> other})
  stemForms(List<GreekVocabularyEntry> vocabulary) {
    final verbs = [
      for (final entry in vocabulary)
        if (entry.type == "verb" && entry.aorist != null) entry,
    ];

    return (
      sheet: [
        for (final lemma in GrammarQuestionPicker.aoristSheet)
          ...verbs.where((entry) => entry.lemma == lemma).take(1),
      ],
      other: [
        for (final entry in verbs)
          if (!GrammarQuestionPicker.aoristSheet.contains(entry.lemma)) entry,
      ],
    );
  }

  @override
  State<AoristScreen> createState() => _AoristScreenState();
}

class _AoristScreenState extends State<AoristScreen> {
  late final Future<List<GreekVocabularyEntry>> _vocabulary =
      widget.vocabulary ?? GreekVocabularyLoader.load();

  static Widget _table(List<GreekVocabularyEntry> entries) {
    return GrammarTable(
      rows: [
        const [
          GrammarCell.header("Präsens"),
          GrammarCell.header("Aorist"),
          GrammarCell.header("Bedeutung"),
        ],
        for (final entry in entries)
          [
            GrammarCell.form(entry.lemma),
            GrammarCell.form(entry.aorist ?? ""),
            GrammarCell.text(entry.translations.join(", ")),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GreekVocabularyEntry>>(
      future: _vocabulary,
      builder: (context, snapshot) {
        final vocabulary = snapshot.data;

        final forms = vocabulary == null
            ? null
            : AoristScreen.stemForms(vocabulary);

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
                "Angegeben ist jeweils die 1. Person Singular Indikativ.",
              ]),
            ),

            if (snapshot.hasError)
              const GrammarStatus.error(
                "Die Stammformen konnten nicht geladen werden.",
              )
            else if (forms == null)
              const GrammarStatus.loading()
            else ...[
              GrammarSection(
                title: "Verben des Aoristblatts",
                child: _table(forms.sheet),
              ),

              GrammarSection(
                title: "Weitere Verben der Vokabelliste",
                child: _table(forms.other),
              ),
            ],
          ],
        );
      },
    );
  }
}
