import 'package:flutter/material.dart';

import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../../utils/greek_normalization.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Eine Präposition der Vokabelliste mit ihrem Kasus ("Gen.", leer ohne
/// Angabe) und den Bedeutungen in dieser Verbindung.
typedef PrepositionUse = ({
  String preposition,
  String grammaticalCase,
  List<String> translations,
});

/// Präpositionen der Vokabelliste mit ihrer Kasusrektion.
class PrepositionsScreen extends StatefulWidget {
  /// Vokabelliste für Tests; sonst wird sie aus den Assets geladen.
  final Future<List<GreekVocabularyEntry>>? vocabulary;

  const PrepositionsScreen({super.key, this.vocabulary});

  /// Liest die Einträge der Wortart Präposition ("διά + Gen."). Gleiche
  /// Verbindungen werden zusammengefasst, die Verbindungen einer Präposition
  /// stehen beieinander.
  static List<PrepositionUse> uses(List<GreekVocabularyEntry> vocabulary) {
    final result = <PrepositionUse>[];

    for (final entry in vocabulary) {
      if (entry.type != "preposition") continue;

      final parts = entry.lemma.split(" + ");
      final preposition = parts.first.trim();

      final grammaticalCase = parts.length > 1
          ? "${parts[1].trim().replaceAll(".", "")}."
          : "";

      final known = result.indexWhere((use) {
        return use.preposition == preposition &&
            use.grammaticalCase == grammaticalCase;
      });

      if (known < 0) {
        result.add((
          preposition: preposition,
          grammaticalCase: grammaticalCase,
          translations: List.of(entry.translations),
        ));

        continue;
      }

      for (final translation in entry.translations) {
        if (!result[known].translations.contains(translation)) {
          result[known].translations.add(translation);
        }
      }
    }

    // Stabil: Die Verbindungen einer Präposition behalten ihre Reihenfolge.
    final order = {for (var i = 0; i < result.length; i++) result[i]: i};

    result.sort((a, b) {
      final byName = normalizeGreekForComparison(
        a.preposition,
      ).compareTo(normalizeGreekForComparison(b.preposition));

      return byName != 0 ? byName : order[a]!.compareTo(order[b]!);
    });

    return result;
  }

  @override
  State<PrepositionsScreen> createState() => _PrepositionsScreenState();
}

class _PrepositionsScreenState extends State<PrepositionsScreen> {
  late final Future<List<GreekVocabularyEntry>> _vocabulary =
      widget.vocabulary ?? GreekVocabularyLoader.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GreekVocabularyEntry>>(
      future: _vocabulary,
      builder: (context, snapshot) {
        final vocabulary = snapshot.data;

        return GrammarTopicScaffold(
          title: "Präpositionen",
          children: [
            if (snapshot.hasError)
              const GrammarStatus.error(
                "Die Präpositionen konnten nicht geladen werden.",
              )
            else if (vocabulary == null)
              const GrammarStatus.loading()
            else
              GrammarSection(
                title: "Präpositionen und Kasusrektion",
                description:
                    "Präpositionen der Vokabelliste. Viele haben je nach "
                    "Kasus eine andere Bedeutung.",
                child: GrammarTable(
                  rows: [
                    const [
                      GrammarCell.header("Präposition"),
                      GrammarCell.header("Kasus"),
                      GrammarCell.header("Bedeutung"),
                    ],
                    for (final use in PrepositionsScreen.uses(vocabulary))
                      [
                        GrammarCell.form(use.preposition),
                        GrammarCell.label(use.grammaticalCase),
                        GrammarCell.text(use.translations.join(", ")),
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
