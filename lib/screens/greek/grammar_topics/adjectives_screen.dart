import 'package:flutter/material.dart';

import '../../../services/greek/grammar/greek_declension.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Adjektive der a-/o-Deklination. Die Tabellen entstehen mit derselben
/// Deklination, die der Grammatiktrainer für die Steigerung verwendet.
class AdjectivesScreen extends StatelessWidget {
  const AdjectivesScreen({super.key});

  static final DeclensionParadigm oxytone = declineOxytone(
    stem: "σοφ",
    alphaFeminine: false,
  );

  static final DeclensionParadigm recessive = declineRecessive(
    short: "βέβαι",
    long: "βεβαί",
    alphaFeminine: true,
  );

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Adjektive",
      children: [
        const GrammarSection(
          title: "Überblick",
          child: GrammarBulletList([
            "Adjektive richten sich in Kasus, Numerus und Genus nach ihrem "
                "Bezugswort.",
            "Maskulinum und Neutrum folgen der o-Deklination, das Femininum "
                "der a-Deklination.",
            "Nach ε, ι und ρ endet das Femininum auf -α statt auf -η.",
          ]),
        ),

        GrammarSection(
          title: "Endbetont: σοφός, σοφή, σοφόν",
          description: "geschickt, klug, weise",
          child: DeclensionParadigmTable(paradigm: oxytone),
        ),

        GrammarSection(
          title: "Femininum auf -α: βέβαιος, βεβαία, βέβαιον",
          description:
              "feststehend, fest, zuverlässig, sicher – vor langer Endsilbe "
              "rückt der Akzent nach hinten (βεβαίου).",
          child: DeclensionParadigmTable(paradigm: recessive),
        ),
      ],
    );
  }
}
