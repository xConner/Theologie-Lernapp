import 'package:flutter/material.dart';

import '../../../services/greek/grammar/greek_mi_verbs.dart';
import '../../../services/greek/grammar/mi_verb_exercises.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Verben auf -μι nach der Folie „Sprachkurs Griechisch 2 – Die
/// athematische Konjugation“: dieselben Tabellen und Sätze, die der
/// Grammatiktrainer abfragt ([GreekMiVerbs], [MiVerbExercises]).
class MiVerbsScreen extends StatelessWidget {
  const MiVerbsScreen({super.key});

  static const List<String> _persons = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  // Eine Tabelle der Folie: die vier Verben nebeneinander, darunter der
  // Infinitiv.
  static Widget _table(String slideTitle) {
    final tables = [
      for (final verb in GreekMiVerbs.verbs) verb.table(slideTitle),
    ];

    final hasInfinitive = tables.any((table) => table.infinitive != null);

    return GrammarTable(
      rows: [
        [
          const GrammarCell.header("Person"),
          for (final verb in GreekMiVerbs.verbs) GrammarCell.header(verb.lemma),
        ],
        for (var i = 0; i < _persons.length; i++)
          [
            GrammarCell.label(_persons[i]),
            for (final table in tables)
              GrammarCell.form(
                table.rootAorist && i == 0
                    ? "${table.forms[i]} (!)"
                    : table.forms[i],
              ),
          ],
        if (hasInfinitive)
          [
            const GrammarCell.label("Infinitiv"),
            for (final table in tables)
              GrammarCell.form(table.infinitive ?? "–"),
          ],
      ],
    );
  }

  static Widget _participles(String tense) {
    final participles = [
      for (final verb in GreekMiVerbs.verbs)
        verb.participles.firstWhere((p) => p.tense == tense),
    ];

    return GrammarTable(
      rows: [
        [
          const GrammarCell.header(""),
          for (final verb in GreekMiVerbs.verbs) GrammarCell.header(verb.lemma),
        ],
        [
          const GrammarCell.label("Nom. Sg."),
          for (final participle in participles)
            GrammarCell.form(participle.nominative.join(", ")),
        ],
        [
          const GrammarCell.label("Gen. Sg."),
          for (final participle in participles)
            GrammarCell.form(participle.genitive.join(", ")),
        ],
      ],
    );
  }

  static String _tableNote(String slideTitle) {
    return [
      for (final verb in GreekMiVerbs.verbs)
        if (verb.table(slideTitle) case MiVerbTable(:final note?))
          "${verb.lemma}: $note",
    ].join("\n");
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      "Präsens aktiv",
      "Präsens passiv",
      "Imperfekt aktiv",
      "Imperfekt passiv",
      "Aorist aktiv",
      "Aorist medium",
      "Aorist passiv",
    ];

    return GrammarTopicScaffold(
      title: "Verben auf -μι",
      children: [
        GrammarSection(
          title: "Die „vier großen“ μι-Verben",
          description:
              "Mit Präsensreduplikation – Bedeutungen wie auf der Folie.",
          child: GrammarBulletList([
            for (final verb in GreekMiVerbs.verbs)
              "${verb.lemma} – ${verb.meaning}",
          ]),
        ),

        const GrammarSection(
          title: "Woran man sie erkennt",
          description:
              "Aus den Tabellen der Folie zusammengefasst (Ergänzung, nicht "
              "als Text auf der Folie).",
          child: GrammarBulletList(GreekMiVerbs.features),
        ),

        for (final title in titles)
          GrammarSection(
            title: title,
            description: switch (_tableNote(title)) {
              "" when title.endsWith("passiv") && !title.startsWith("Aorist") =>
                "Medium und Passiv sind formgleich; im Trainer „Medium/Passiv“.",
              "" => null,
              final note => note,
            },
            child: _table(title),
          ),

        GrammarSection(
          title: "Partizipien Präsens",
          description: "Nominativ und Genitiv Sg., m – f – n",
          child: _participles("Präsens"),
        ),

        GrammarSection(
          title: "Partizipien Aorist",
          description: "στήσας gehört zum σ-Aorist ἔστησα.",
          child: _participles("Aorist"),
        ),

        GrammarSection(
          title: "Sätze der Folie",
          description:
              "Die Folie nennt die Sätze ohne Stelle und ohne Übersetzung; "
              "beides ist ergänzt.",
          child: GrammarTable(
            rows: [
              const [GrammarCell.header("Satz"), GrammarCell.header("μι-Form")],
              for (final task in MiVerbExercises.usageTasks)
                [
                  GrammarCell.text(
                    "${task.sentence}\n${task.translation}\n"
                    "${task.reference}",
                  ),
                  GrammarCell.text(
                    "${task.form} (${task.verb})\n${task.analysis}"
                    "${task.compound == null ? '' : '\n${task.compound}'}",
                  ),
                ],
            ],
          ),
        ),

        const GrammarSection(
          title: "Ergänzungen (nicht auf der Folie)",
          child: GrammarBulletList([
            "Im Neuen Testament dringt das κ des Aorists auch in den Plural: "
                "ἔθηκαν (Mk 16,6), ἔδωκαν – das Paradigma der Folie hat "
                "ἔθεσαν, ἔδοσαν.",
            "Komposita wie ἀφίημι (ἀπό + ἵημι: vergeben), ἀνίστημι (ἀνά + "
                "ἵστημι: aufstehen) und ἀποδίδωμι (zurückgeben) werden wie "
                "das Simplex konjugiert; das Augment steht nach der "
                "Präposition (ἀν-έ-στη).",
            "Konjunktiv und Imperativ der μι-Verben behandelt die Folie "
                "nicht; im Trainer gibt es keinen Konjunktiv der μι-Verben. "
                "Den Imperativ von δίδωμι und τίθημι fragt der Trainer aus "
                "den Wörterbuchtabellen ab.",
          ]),
        ),

        const GrammarSection(
          title: "Grammatikhinweis der Folie",
          child: GrammarBulletList(GreekMiVerbs.references),
        ),

        const GrammarSection(
          title: "Im Grammatiktrainer",
          child: GrammarBulletList([
            "Wortart „Verben auf -μι“ mit drei Aufgabenarten: Formen "
                "bestimmen (alle vier Verben, es gelten die gewählten Modi "
                "und Zeitformen), Formen bilden (jede Form der Folie) und "
                "Sätze (Grundform und Tempus).",
            "δίδωμι und τίθημι aus der Vokabelliste werden auch beim "
                "Bestimmen der Verben in ihren Schritten nach der Folie "
                "gefragt (ἐτίθην, ἔδωκα, Aorist Passiv im Indikativ).",
          ]),
        ),
      ],
    );
  }
}
