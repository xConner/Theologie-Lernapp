import 'package:flutter/material.dart';

import '../../../widgets/grammar_overview_widgets.dart';

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key});

  static List<Widget> _row(String label, String m, String f, String n) {
    return [
      GrammarCell.label(label),
      GrammarCell.form(m),
      GrammarCell.form(f),
      GrammarCell.form(n),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Bestimmter Artikel",
      children: [
        GrammarSection(
          title: "Der bestimmte Artikel",
          child: GrammarTable(
            headerRows: const {0, 5},
            rows: [
              const [
                GrammarCell.header("Singular"),
                GrammarCell.header("Maskulinum"),
                GrammarCell.header("Femininum"),
                GrammarCell.header("Neutrum"),
              ],
              _row("Nominativ", "ὁ", "ἡ", "τό"),
              _row("Genitiv", "τοῦ", "τῆς", "τοῦ"),
              _row("Dativ", "τῷ", "τῇ", "τῷ"),
              _row("Akkusativ", "τόν", "τήν", "τό"),
              const [GrammarCell.header("Plural")],
              _row("Nominativ", "οἱ", "αἱ", "τά"),
              _row("Genitiv", "τῶν", "τῶν", "τῶν"),
              _row("Dativ", "τοῖς", "ταῖς", "τοῖς"),
              _row("Akkusativ", "τούς", "τάς", "τά"),
            ],
          ),
        ),
      ],
    );
  }
}
