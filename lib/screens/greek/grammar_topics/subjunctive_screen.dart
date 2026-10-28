import 'package:flutter/material.dart';

import '../../../services/greek/grammar/greek_subjunctive.dart';
import '../../../services/greek/grammar/subjunctive_exercises.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Konjunktiv nach der Folie „Sprachkurs Griechisch 2 – Konjunktiv“: dieselben
/// Paradigmen und Sätze, die der Grammatiktrainer abfragt
/// ([GreekSubjunctive], [SubjunctiveExercises]).
class SubjunctiveScreen extends StatelessWidget {
  const SubjunctiveScreen({super.key});

  static const List<String> _persons = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  static Widget _table(Map<String, List<String>> voices) {
    return GrammarTable(
      rows: [
        [
          const GrammarCell.header("Person"),
          for (final voice in voices.keys) GrammarCell.header(voice),
        ],
        for (var i = 0; i < _persons.length; i++)
          [
            GrammarCell.label(_persons[i]),
            for (final forms in voices.values) GrammarCell.form(forms[i]),
          ],
      ],
    );
  }

  static Widget _sentences(List<SubjunctiveUsageTask> tasks) {
    return GrammarTable(
      rows: [
        const [GrammarCell.header("Satz"), GrammarCell.header("Konjunktiv")],
        for (final task in tasks)
          [
            GrammarCell.text(
              "${task.sentence}\n${task.translation}"
              "${task.reference == null ? '' : '\n${task.reference} · '
                        'Übersetzung ergänzt'}",
            ),
            GrammarCell.text("${task.form}\n${task.analysis}"),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = [
      for (final task in SubjunctiveExercises.usageTasks)
        if (task.reference == null) task,
    ];

    final newTestament = [
      for (final task in SubjunctiveExercises.usageTasks)
        if (task.reference != null) task,
      SubjunctiveExercises.john127,
    ]..sort((a, b) => a.id.compareTo(b.id));

    return GrammarTopicScaffold(
      title: "Konjunktiv",
      children: [
        const GrammarSection(
          title: "Bildung",
          child: GrammarBulletList([
            "Den Konjunktiv gibt es im Präsens und im Aorist.",
            "Kennzeichen ist der lange Themavokal: ω statt ο, η statt ε, "
                "ῃ statt ει (Ind. παύομεν, παύετε, παύεις → Konj. παύωμεν, "
                "παύητε, παύῃς).",
            "Kein Augment – auch nicht im Aorist (ἐπαύσαμεν → παύσωμεν, "
                "ἦλθον → ἔλθω).",
            "Konjunktiv Aorist: Aoriststamm + Konjunktivendungen (παύσ-ω, "
                "starker Aorist ἔλθ-ω); Aorist Passiv: θ-Stamm + aktive "
                "Endungen mit Zirkumflex (παυθ-ῶ).",
            "Im Präsens sind Medium und Passiv formgleich, im Aorist "
                "getrennt.",
          ]),
        ),

        GrammarSection(
          title: "Konjunktiv Präsens",
          description: "παύω",
          child: _table(GreekSubjunctive.pauo["Präsens"]!),
        ),

        GrammarSection(
          title: "Konjunktiv Aorist",
          description: "παύω",
          child: _table(GreekSubjunctive.pauo["Aorist"]!),
        ),

        GrammarSection(
          title: "Konjunktiv des starken Aorists",
          description: "ἔρχομαι, Aorist ἦλθον",
          child: _table({"Aktiv": GreekSubjunctive.strongAorist}),
        ),

        GrammarSection(
          title: "Konjunktiv von εἰμί",
          child: _table({"εἰμί": GreekSubjunctive.eimi}),
        ),

        const GrammarSection(
          title: "Verwechslungsgefahr",
          child: GrammarBulletList([
            "1. Sg. Präsens Aktiv: Indikativ und Konjunktiv sind gleich "
                "(παύω).",
            "Konjunktiv Aorist und Indikativ Futur können gleich lauten "
                "(λύσω, παύσω) – nach ἵνα, ἐάν oder μή steht der "
                "Konjunktiv.",
            "παύῃ ist 3. Sg. Aktiv oder 2. Sg. Medium/Passiv.",
            "Mt 7,1: Μὴ κρίνετε ist Imperativ (kurzes ε), κριθῆτε "
                "Konjunktiv Aorist Passiv (η).",
          ]),
        ),

        GrammarSection(
          title: "Konjunktiv im Hauptsatz",
          child: GrammarBulletList([
            for (final use in SubjunctiveUse.values)
              if (use.clause == "Hauptsatz")
                "${use.label}: ${use.rule} – ${use.translation}",
          ]),
        ),

        GrammarSection(
          title: "Konjunktiv im Nebensatz",
          child: GrammarBulletList([
            for (final use in SubjunctiveUse.values)
              if (use.clause == "Nebensatz")
                "${use.label}: ${use.rule} – ${use.translation}",
          ]),
        ),

        GrammarSection(
          title: "Beispielsätze der Folie",
          child: _sentences(slide),
        ),

        GrammarSection(
          title: "Sätze aus dem Neuen Testament",
          description:
              "Die Folie nennt die Sätze ohne Stelle und ohne Übersetzung; "
              "beides ist ergänzt.",
          child: _sentences(newTestament),
        ),

        const GrammarSection(
          title: "Ergänzungen (nicht auf der Folie)",
          child: GrammarBulletList([
            "Joh 1,27: ἵνα + Konjunktiv nach ἄξιος ist kein Finalsatz, "
                "sondern steht für einen Infinitiv („würdig, … zu lösen“). "
                "Der Satz wird deshalb im Trainer nicht nach seiner "
                "Verwendung gefragt.",
            "Verbote stehen meist als μή + Konjunktiv Aorist (μὴ νομίσητε, "
                "μὴ μεριμνήσητε) oder als μή + Imperativ Präsens (μὴ "
                "κρίνετε); μὴ φονεύῃς auf der Folie hat den Konjunktiv "
                "Präsens.",
            "ποιῶμεν ist kontrahiert aus ποιέ-ωμεν. Kontrakta werden im "
                "Trainer nicht als Konjunktiv Präsens gefragt.",
          ]),
        ),

        const GrammarSection(
          title: "Grammatikhinweis der Folie",
          child: GrammarBulletList(["Ars Graeca § 211", "Grammateion § 6.9"]),
        ),

        const GrammarSection(
          title: "Im Grammatiktrainer",
          child: GrammarBulletList([
            "Formen bestimmen: Wortart Verb → Verbformen → Konjunktiv. "
                "Präsens bei unkontrahierten Verben auf -ω und -ομαι, "
                "Aorist aus dem Infinitiv Aorist (ohne Wurzelaoriste wie "
                "βῆναι, γνῶναι).",
            "Formen bilden und Gebrauch im Satz: Wortart Konjunktiv.",
          ]),
        ),
      ],
    );
  }
}
