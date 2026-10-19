import 'package:flutter/material.dart';

import '../../../services/latin/grammar/latin_grammar_words.dart';
import '../../../widgets/grammar_overview_widgets.dart';
import 'latin_grammar_widgets.dart';

/// Satzlehre: Regeln je Konstruktion, die Beispiele stammen aus denselben
/// Sätzen, die der Trainer zur Erkennung vorlegt.
class LatinSyntaxScreen extends StatelessWidget {
  const LatinSyntaxScreen({super.key});

  static const List<(String, List<String>)> _rules = [
    (
      LatinConstructions.aci,
      [
        "Nach Verben des Sagens, Meinens, Wahrnehmens und der Gemütsbewegung "
            "steht ein Akkusativ mit Infinitiv. Der Akkusativ ist das "
            "Subjekt, der Infinitiv das Prädikat des dass-Satzes.",
        "Infinitiv Präsens: gleichzeitig; Infinitiv Perfekt: vorzeitig.",
        "Reflexivpronomen (sē, suus) im AcI beziehen sich auf das Subjekt "
            "des übergeordneten Satzes.",
      ],
    ),
    (
      LatinConstructions.participiumConiunctum,
      [
        "Ein Partizip ist mit einem Satzglied „verbunden“ und stimmt mit "
            "ihm in KNG überein.",
        "Übersetzung je nach Sinn mit Relativsatz, temporal (als, "
            "nachdem), kausal (weil) oder konzessiv (obwohl).",
      ],
    ),
    (
      LatinConstructions.ablativeAbsolute,
      [
        "Substantiv (oder Pronomen) und Partizip stehen im Ablativ und "
            "sind kein Satzglied des übrigen Satzes.",
        "PPA: gleichzeitig (während, als), PPP: vorzeitig (nachdem).",
        "Auch ohne Partizip möglich: Cicerōne cōnsule – als Cicero Konsul "
            "war.",
      ],
    ),
    (
      LatinConstructions.relativeClause,
      [
        "Das Relativpronomen richtet sich in Numerus und Genus nach dem "
            "Bezugswort, der Kasus nach seiner Funktion im Relativsatz.",
      ],
    ),
    (
      LatinConstructions.finalClause,
      [
        "ut / nē + Konjunktiv: Absicht oder Zweck – damit, um zu; nē: "
            "damit nicht.",
      ],
    ),
    (
      LatinConstructions.consecutiveClause,
      [
        "ut / ut nōn + Konjunktiv: Folge – sodass, sodass nicht; oft "
            "angekündigt durch tam, ita, tantus, tālis.",
      ],
    ),
    (
      LatinConstructions.cumClause,
      [
        "cum + Konjunktiv (cum historicum): als, nachdem; kausal: da, weil; "
            "konzessiv: obwohl.",
        "cum + Indikativ ist meist temporal: (immer) wenn, als.",
      ],
    ),
    (
      LatinConstructions.indirectQuestion,
      [
        "Abhängige Fragesätze werden durch ein Fragewort (quis, cūr, "
            "ubi …) oder -ne / num („ob“) eingeleitet und stehen im "
            "Konjunktiv; übersetzt wird mit Indikativ.",
      ],
    ),
    (
      LatinConstructions.dativePossessive,
      [
        "Dativ + esse bezeichnet den Besitzer: Mihi liber est – ich habe "
            "ein Buch.",
      ],
    ),
    (
      LatinConstructions.gerund,
      [
        "Das Gerundium ist der deklinierte Infinitiv (Gen. -ndī, Dat./Abl. "
            "-ndō, Akk. ad -ndum): ars scrībendī – die Kunst des "
            "Schreibens.",
      ],
    ),
    (
      LatinConstructions.gerundive,
      [
        "Das Gerundivum (-ndus, -a, -um) ist ein Adjektiv. Mit esse drückt "
            "es eine Notwendigkeit aus (müssen); attributiv ersetzt es oft "
            "ein Gerundium mit Objekt.",
        "Die handelnde Person steht dabei im Dativ (dativus auctoris).",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LatinTopicScaffold(
      title: "Satzlehre",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        for (final (construction, rules) in _rules)
          GrammarSection(
            title: construction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in rules) LatinCallout.rule(rule),
                LatinExamples([
                  for (final example in LatinGrammarWords.syntaxExamples)
                    if (example.construction == construction)
                      LatinExample(
                        example.sentence,
                        example.translation,
                        note: example.explanation,
                      ),
                ]),
              ],
            ),
          ),
      ],
    );
  }
}
