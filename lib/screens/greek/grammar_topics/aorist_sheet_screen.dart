import 'package:flutter/material.dart';

import '../../../widgets/grammar_overview_widgets.dart';

/// Eine Zeile des Aoristblatts.
typedef AoristSheetVerb = ({
  String present,
  String aorist,
  String infinitive,
  String meaning,
});

/// Das Aoristblatt der Vorlesung („Häufige Verben im Aorist“,
/// `assets/Aoristblatt - Kopie.pdf`): dieselben Gruppen, Spalten und Zeilen
/// in derselben Reihenfolge.
class AoristSheetScreen extends StatelessWidget {
  const AoristSheetScreen({super.key});

  static const List<(String, List<AoristSheetVerb>)> groups = [
    (
      "Labialstämme",
      [
        (
          present: "βλέπω",
          aorist: "ἔβλεψα",
          infinitive: "βλέψαι",
          meaning: "schauen",
        ),
        (
          present: "γράφω",
          aorist: "ἔγραψα",
          infinitive: "γράψαι",
          meaning: "schreiben",
        ),
        (
          present: "πέμπω",
          aorist: "ἔπεμψα",
          infinitive: "πέμψαι",
          meaning: "schicken",
        ),
      ],
    ),
    (
      "Dentalstämme",
      [
        (
          present: "νομίζω",
          aorist: "ἐνόμισα",
          infinitive: "νομίσαι",
          meaning: "glauben, meinen",
        ),
        (
          present: "πείθω",
          aorist: "ἔπεισα",
          infinitive: "πεῖσαι",
          meaning: "überreden",
        ),
        (
          present: "σῴζω",
          aorist: "ἔσωσα",
          infinitive: "σῶσαι",
          meaning: "retten",
        ),
      ],
    ),
    (
      "Gutturalstämme",
      [
        (
          present: "ἄρχω",
          aorist: "ἦρξα",
          infinitive: "ἄρξαι",
          meaning: "herrschen",
        ),
        (
          present: "πράττω",
          aorist: "ἔπραξα",
          infinitive: "πρᾶξαι",
          meaning: "tun, machen",
        ),
        (
          present: "τάττω",
          aorist: "ἔταξα",
          infinitive: "τάξαι",
          meaning: "aufstellen",
        ),
        (
          present: "φυλάττω",
          aorist: "ἐφύλαξα",
          infinitive: "φυλάξαι",
          meaning: "bewachen",
        ),
      ],
    ),
    (
      "Liquidstämme",
      [
        (
          present: "ἀγγέλλω",
          aorist: "ἤγγειλα",
          infinitive: "ἀγγεῖλαι",
          meaning: "melden, verkünden",
        ),
        (
          present: "κρίνω",
          aorist: "ἔκρινα",
          infinitive: "κρῖναι",
          meaning: "urteilen",
        ),
        (
          present: "μένω",
          aorist: "ἔμεινα",
          infinitive: "μεῖναι",
          meaning: "bleiben, warten",
        ),
      ],
    ),
    (
      "Starker Aorist",
      [
        (
          present: "ἄγω",
          aorist: "ἤγαγον",
          infinitive: "ἀγαγεῖν",
          meaning: "führen, treiben",
        ),
        (
          present: "βάλλω",
          aorist: "ἔβαλον",
          infinitive: "βαλεῖν",
          meaning: "werfen, treffen",
        ),
        (
          present: "γίγνομαι",
          aorist: "ἐγενόμην",
          infinitive: "γενέσθαι",
          meaning: "werden, entstehen",
        ),
        (
          present: "ἔρχομαι",
          aorist: "ἦλθον",
          infinitive: "ἐλθεῖν",
          meaning: "kommen",
        ),
        (
          present: "εὑρίσκω",
          aorist: "ηὗρον",
          infinitive: "εὑρεῖν",
          meaning: "finden",
        ),
        (
          present: "ἔχω",
          aorist: "ἔσχον",
          infinitive: "σχεῖν",
          meaning: "haben, halten",
        ),
        (
          present: "λαμβάνω",
          aorist: "ἔλαβον",
          infinitive: "λαβεῖν",
          meaning: "nehmen, ergreifen",
        ),
        (
          present: "λέγω",
          aorist: "εἶπον",
          infinitive: "εἰπεῖν",
          meaning: "sagen",
        ),
        (
          present: "λείπω",
          aorist: "ἔλιπον",
          infinitive: "λιπεῖν",
          meaning: "verlassen",
        ),
        (
          present: "μανθάνω",
          aorist: "ἔμαθον",
          infinitive: "μαθεῖν",
          meaning: "lernen, verstehen",
        ),
        (
          present: "ὁράω",
          aorist: "εἶδον",
          infinitive: "ἰδεῖν",
          meaning: "sehen",
        ),
        (
          present: "φεύγω",
          aorist: "ἔφυγον",
          infinitive: "φυγεῖν",
          meaning: "fliehen",
        ),
        (
          present: "φέρω",
          aorist: "ἤνεγκον",
          infinitive: "ἐνεγκεῖν",
          meaning: "tragen",
        ),
      ],
    ),
    (
      "Wurzelaorist",
      [
        (
          present: "βαίνω",
          aorist: "ἔβην",
          infinitive: "βῆναι",
          meaning: "gehen",
        ),
        (
          present: "γιγνώσκω",
          aorist: "ἔγνων",
          infinitive: "γνῶναι",
          meaning: "erkennen",
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Aoristblatt",
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: GrammarNote("Häufige Verben im Aorist"),
        ),

        for (final (title, verbs) in groups)
          GrammarSection(
            title: title,
            child: GrammarTable(
              rows: [
                const [
                  GrammarCell.header("Präsens"),
                  GrammarCell.header("Aorist"),
                  GrammarCell.header("Infinitiv Aorist"),
                  GrammarCell.header("dt. Bedeutung"),
                ],
                for (final verb in verbs)
                  [
                    GrammarCell.form(verb.present),
                    GrammarCell.form(verb.aorist),
                    GrammarCell.form(verb.infinitive),
                    GrammarCell.text(verb.meaning),
                  ],
              ],
            ),
          ),
      ],
    );
  }
}
