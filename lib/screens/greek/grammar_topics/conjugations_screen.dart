import 'package:flutter/material.dart';

import '../../../widgets/grammar_overview_widgets.dart';

class ConjugationsScreen extends StatelessWidget {
  const ConjugationsScreen({super.key});

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
      title: "Konjugationen",
      children: [
        GrammarSection(
          title: "Primäre Endungen",
          description: "Präsens",
          child: _table(
            ["Person", "Akt.", "Med./Pass."],
            [
              ["1. Sg.", "-ω", "-μαι"],
              ["2. Sg.", "-εις", "-η"],
              ["3. Sg.", "-ει", "-ται"],
              ["1. Pl.", "-μεν", "-μεθα"],
              ["2. Pl.", "-τε", "-σθε"],
              ["3. Pl.", "-σι(ν)", "-νται"],
            ],
          ),
        ),

        GrammarSection(
          title: "Sekundäre Endungen",
          description: "Imperfekt und Aorist",
          child: _table(
            ["Person", "Akt.", "Med./Pass."],
            [
              ["1. Sg.", "-ν", "-μην"],
              ["2. Sg.", "-ς", "-σο"],
              ["3. Sg.", "-", "-το"],
              ["1. Pl.", "-μεν", "-μεθα"],
              ["2. Pl.", "-τε", "-σθε"],
              ["3. Pl.", "-ν / -σαν", "-ντο"],
            ],
          ),
        ),

        GrammarSection(
          title: "εἰμί",
          child: _table(
            ["Person", "Prä.", "Impf."],
            [
              ["1. Sg.", "εἰμί", "ἦν"],
              ["2. Sg.", "εἶ", "ἦς"],
              ["3. Sg.", "ἐστί(ν)", "ἦν"],
              ["1. Pl.", "ἐσμέν", "ἦμεν"],
              ["2. Pl.", "ἐστέ", "ἦτε"],
              ["3. Pl.", "εἰσί(ν)", "ἦσαν"],
            ],
          ),
        ),
      ],
    );
  }
}
