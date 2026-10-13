import 'package:flutter/material.dart';

import '../../../services/greek/exam/grammar_phenomena.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Satzlehre: die Konstruktionen und Satzarten, die der Klausurersteller in
/// Texten erkennt. Reine Stichwortliste – eigene Formentabellen oder Übungen
/// gibt es dazu nicht.
class SyntaxScreen extends StatelessWidget {
  const SyntaxScreen({super.key});

  /// Kategorien des Klausurerstellers, die zur Satzlehre gehören. Die
  /// Formenlehre (Modus, Tempus, Genus Verbi, Verbklassen, Nomina, Pronomen)
  /// steht auf den übrigen Seiten der Grammatikübersicht.
  static const List<String> categoryIds = [
    "participleSyntax",
    "infinitiveSyntax",
    "clauses",
    "moodSyntax",
    "negation",
    "rection",
    "wordOrder",
  ];

  /// Stichworte einer Kategorie; nur, was der Klausurersteller erkennt.
  static List<String> labelsOf(String categoryId) {
    return [
      for (final phenomenon in GrammarPhenomena.inCategory(categoryId))
        if (phenomenon.status != PhenomenonStatus.unavailable) phenomenon.label,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Syntax und Konstruktionen",
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: GrammarNote(
            "Stichworte zu den Konstruktionen und Satzarten, die der "
            "Klausurersteller in Texten erkennt. Im Grammatiktrainer werden "
            "sie nicht eigens geübt.",
          ),
        ),

        for (final id in categoryIds)
          if (GrammarPhenomena.category(id) case final category?)
            if (labelsOf(id) case final labels when labels.isNotEmpty)
              GrammarSection(
                title: category.label,
                child: GrammarBulletList(labels),
              ),
      ],
    );
  }
}
