import 'package:flutter/material.dart';

import '../../../widgets/grammar_overview_widgets.dart';

/// Imperativ Präsens und Aorist, wie ihn der Grammatiktrainer abfragt.
class ImperativeScreen extends StatelessWidget {
  const ImperativeScreen({super.key});

  static Widget _table(List<String> header, List<List<String>> rows) {
    return GrammarTable(
      rows: [
        [for (final label in header) GrammarCell.header(label)],
        for (final row in rows)
          [
            GrammarCell.label(row.first),
            for (final form in row.skip(1)) GrammarCell.form(form),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Imperativ",
      children: [
        const GrammarSection(
          title: "Überblick",
          child: GrammarBulletList([
            "Den Imperativ gibt es im Präsens und im Aorist, nicht im "
                "Imperfekt.",
            "Er hat keine 1. Person.",
            "Im Präsens ist die 2. Person Plural formgleich mit dem Indikativ "
                "(παύετε, παύεσθε).",
            "Im Präsens sind Medium und Passiv formgleich, im Aorist getrennt.",
          ]),
        ),

        GrammarSection(
          title: "Endungen",
          description:
              "Die aktiven Endungen gelten auch für den Aorist Passiv.",
          child: _table(
            ["Person", "Aktiv", "Medium"],
            [
              ["3. Sg.", "-τω", "-σθω"],
              ["2. Pl.", "-τε", "-σθε"],
              ["3. Pl.", "-ντων", "-σθων"],
            ],
          ),
        ),

        GrammarSection(
          title: "Imperativ Präsens",
          description: "παύω",
          child: _table(
            ["Person", "Aktiv", "Medium/Passiv"],
            [
              ["2. Sg.", "παῦε", "παύου"],
              ["3. Sg.", "παυέτω", "παυέσθω"],
              ["2. Pl.", "παύετε", "παύεσθε"],
              ["3. Pl.", "παυόντων", "παυέσθων"],
            ],
          ),
        ),

        GrammarSection(
          title: "Imperativ Aorist",
          description: "παύω",
          child: _table(
            ["Person", "Aktiv", "Medium", "Passiv"],
            [
              ["2. Sg.", "παῦσον", "παῦσαι", "παύθητι"],
              ["3. Sg.", "παυσάτω", "παυσάσθω", "παυθήτω"],
              ["2. Pl.", "παύσατε", "παύσασθε", "παύθητε"],
              ["3. Pl.", "παυσάντων", "παυσάσθων", "παυθέντων"],
            ],
          ),
        ),
      ],
    );
  }
}
