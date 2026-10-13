import 'package:flutter/material.dart';

import '../../../services/greek/grammar/greek_declension.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Ein Partizip der Übersicht: Überschrift und die drei Nominative des
/// Singulars, aus denen [declineParticiple] die Tabelle bildet.
typedef ParticipleExample = ({
  String title,
  String masculine,
  String feminine,
  String neuter,
});

/// Die Partizipientypen des Grammatiktrainers. Die Tabellen entstehen mit
/// derselben Deklination, die der Trainer verwendet.
class ParticiplesScreen extends StatelessWidget {
  const ParticiplesScreen({super.key});

  static const List<ParticipleExample> examples = [
    (
      title: "Partizip Präsens Aktiv",
      masculine: "παύων",
      feminine: "παύουσα",
      neuter: "παῦον",
    ),
    (
      title: "Partizip Präsens Medium/Passiv",
      masculine: "παυόμενος",
      feminine: "παυομένη",
      neuter: "παυόμενον",
    ),
    (
      title: "Partizip Aorist Aktiv",
      masculine: "παύσας",
      feminine: "παύσασα",
      neuter: "παῦσαν",
    ),
    (
      title: "Partizip Aorist Medium",
      masculine: "παυσάμενος",
      feminine: "παυσαμένη",
      neuter: "παυσάμενον",
    ),
    (
      title: "Partizip des starken Aorists (Aktiv)",
      masculine: "ἰδών",
      feminine: "ἰδοῦσα",
      neuter: "ἰδόν",
    ),
    (
      title: "Partizip Präsens von εἰμί",
      masculine: "ὤν",
      feminine: "οὖσα",
      neuter: "ὄν",
    ),
  ];

  static DeclensionParadigm? paradigmOf(ParticipleExample example) {
    return declineParticiple(
      masculine: example.masculine,
      feminine: example.feminine,
      neuter: example.neuter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Partizipien",
      children: [
        const GrammarSection(
          title: "Überblick",
          child: GrammarBulletList([
            "Partizipien gibt es im Präsens und im Aorist, nicht im "
                "Imperfekt.",
            "Sie werden wie Adjektive dekliniert; bestimmt werden Tempus, "
                "Genus Verbi, Kasus, Numerus und Genus.",
            "Aktive Partizipien folgen im Maskulinum und Neutrum der "
                "3. Deklination (-ντ-), im Femininum der a-Deklination.",
            "Partizipien auf -μενος, -μένη, -μενον folgen der "
                "a-/o-Deklination.",
            "Das bewegliche ν steht in Klammern: παύουσι(ν).",
          ]),
        ),

        for (final example in examples)
          if (paradigmOf(example) case final paradigm?)
            GrammarSection(
              title: example.title,
              description:
                  "${example.masculine}, ${example.feminine}, "
                  "${example.neuter}",
              child: DeclensionParadigmTable(paradigm: paradigm),
            ),
      ],
    );
  }
}
