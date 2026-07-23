import 'package:flutter/material.dart';

class DeclinationsScreen extends StatelessWidget {
  const DeclinationsScreen({super.key});

  static const double cellPadding = 8.0;
  static const double articleWidth = 60.0;

  static Widget tableText(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(cellPadding),

      child: Text(
        text,

        style: TextStyle(
          fontSize: 22,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  static Widget greekForm(String stem, String article, String ending) {
    return Padding(
      padding: const EdgeInsets.all(cellPadding),
      child: Row(
        children: [
          SizedBox(
            width: articleWidth,
            child: Text(article, style: const TextStyle(fontSize: 22)),
          ),

          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "$stem-", style: const TextStyle(fontSize: 22)),
                TextSpan(
                  text: ending,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget declensionTable(List<List<Widget>> rows) {
    return Table(
      border: TableBorder.all(),

      defaultVerticalAlignment: TableCellVerticalAlignment.middle,

      columnWidths: const {
        0: FixedColumnWidth(120),
        1: FixedColumnWidth(300),
        2: FixedColumnWidth(300),
      },

      children: rows.map((row) {
        return TableRow(children: row);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Deklinationen")),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  "o-Deklination",

                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                declensionTable([
                  [
                    tableText(""),
                    tableText("Maskulinum", bold: true),
                    tableText("Neutrum", bold: true),
                  ],

                  [
                    tableText("Singular", bold: true),
                    const SizedBox(),
                    const SizedBox(),
                  ],

                  [
                    tableText("Nom."),
                    greekForm("λόγ", "ὁ", "ος"),
                    greekForm("δένδρ", "τὸ", "ον"),
                  ],

                  [
                    tableText("Gen."),
                    greekForm("λόγ", "τοῦ", "ου"),
                    greekForm("δένδρ", "τοῦ", "ου"),
                  ],

                  [
                    tableText("Dat."),
                    greekForm("λόγ", "τῷ", "ῳ"),
                    greekForm("δένδρ", "τῷ", "ῳ"),
                  ],

                  [
                    tableText("Akk."),
                    greekForm("λόγ", "τὸν", "ον"),
                    greekForm("δένδρ", "τὸ", "ον"),
                  ],

                  [
                    tableText("Plural", bold: true),
                    const SizedBox(),
                    const SizedBox(),
                  ],

                  [
                    tableText("Nom."),
                    greekForm("λόγ", "οἱ", "οι"),
                    greekForm("δένδρ", "τὰ", "α"),
                  ],

                  [
                    tableText("Gen."),
                    greekForm("λόγ", "τῶν", "ων"),
                    greekForm("δένδρ", "τῶν", "ων"),
                  ],

                  [
                    tableText("Dat."),
                    greekForm("λόγ", "τοῖς", "οις"),
                    greekForm("δένδρ", "τοῖς", "οις"),
                  ],

                  [
                    tableText("Akk."),
                    greekForm("λόγ", "τοὺς", "ους"),
                    greekForm("δένδρ", "τὰ", "α"),
                  ],
                ]),

                const SizedBox(height: 32),

                const Text(
                  "a-Deklination",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                declensionTable([
                  [
                    tableText(""),
                    tableText("-η", bold: true),
                    tableText("-α (Stamm endet auf ε, ι, ρ) ", bold: true),
                  ],

                  [
                    tableText("Singular", bold: true),
                    const SizedBox(),
                    const SizedBox(),
                  ],

                  [
                    tableText("Nom."),
                    greekForm("ἀρχ", "ἡ", "ή"),
                    greekForm("καρδί", "ἡ", "α"),
                  ],

                  [
                    tableText("Gen."),
                    greekForm("ἀρχ", "τῆς", "ῆς"),
                    greekForm("καρδί", "τῆς", "ας"),
                  ],

                  [
                    tableText("Dat."),
                    greekForm("ἀρχ", "τῇ", "ῇ"),
                    greekForm("καρδί", "τῇ", "ᾳ"),
                  ],

                  [
                    tableText("Akk."),
                    greekForm("ἀρχ", "τὴν", "ήν"),
                    greekForm("καρδί", "τὴν", "αν"),
                  ],

                  [
                    tableText("Plural", bold: true),
                    const SizedBox(),
                    const SizedBox(),
                  ],

                  [
                    tableText("Nom."),
                    greekForm("ἀρχ", "αἱ", "αί"),
                    greekForm("καρδί", "αἱ", "αι"),
                  ],

                  [
                    tableText("Gen."),
                    greekForm("ἀρχ", "τῶν", "ῶν"),
                    greekForm("καρδί", "τῶν", "ῶν"),
                  ],

                  [
                    tableText("Dat."),
                    greekForm("ἀρχ", "ταῖς", "αῖς"),
                    greekForm("καρδί", "ταῖς", "αις"),
                  ],

                  [
                    tableText("Akk."),
                    greekForm("ἀρχ", "τὰς", "άς"),
                    greekForm("καρδί", "τὰς", "ας"),
                  ],
                ]),

                const SizedBox(height: 40),

                const Text(
                  "3./Konsonantische Deklination",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Table(
                  border: TableBorder.all(),

                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,

                  columnWidths: const {
                    0: FixedColumnWidth(120),
                    1: FixedColumnWidth(300),
                  },

                  children: [
                    [tableText("Singular", bold: true), const SizedBox()],

                    [tableText("Nom."), greekForm("παῖ", "ὁ", "ς")],

                    [tableText("Gen."), greekForm("παιδ", "τοῦ", "ός")],

                    [tableText("Dat."), greekForm("παιδ", "τῷ", "ί")],

                    [tableText("Akk."), greekForm("παῖδ", "τὸν", "α")],

                    [tableText("Plural", bold: true), const SizedBox()],

                    [tableText("Nom."), greekForm("παῖδ", "οἱ", "ες")],

                    [tableText("Gen."), greekForm("παίδ", "τῶν", "ων")],

                    [tableText("Dat."), greekForm("παι", "τοῖς", "σί")],

                    [tableText("Akk."), greekForm("παῖδ", "τοὺς", "ας")],
                  ].map((row) => TableRow(children: row)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
