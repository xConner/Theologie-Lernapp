import 'package:flutter/material.dart';

class ConjugationsScreen extends StatelessWidget {
  const ConjugationsScreen({super.key});

  static const double cellPadding = 8.0;

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

  Widget endingTable(List<List<Widget>> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Table(
        border: TableBorder.all(),

        defaultVerticalAlignment: TableCellVerticalAlignment.middle,

        columnWidths: const {
          0: FixedColumnWidth(120),
          1: FixedColumnWidth(220),
          2: FixedColumnWidth(220),
        },

        children: rows.map((row) {
          return TableRow(children: row);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konjugationen")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),

            child: Column(
              children: [
                const Text(
                  "Primäre Endungen",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                endingTable([
                  [
                    tableText("Person", bold: true),
                    tableText("Akt.", bold: true),
                    tableText("Med./Pass.", bold: true),
                  ],

                  [tableText("1. Sg."), tableText("-ω"), tableText("-μαι")],

                  [tableText("2. Sg."), tableText("-εις"), tableText("-η")],

                  [tableText("3. Sg."), tableText("-ει"), tableText("-ται")],

                  [tableText("1. Pl."), tableText("-μεν"), tableText("-μεθα")],

                  [tableText("2. Pl."), tableText("-τε"), tableText("-σθε")],

                  [
                    tableText("3. Pl."),
                    tableText("-σι(ν)"),
                    tableText("-νται"),
                  ],
                ]),

                const SizedBox(height: 40),

                const Text(
                  "Sekundäre Endungen",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                endingTable([
                  [
                    tableText("Person", bold: true),
                    tableText("Akt.", bold: true),
                    tableText("Med./Pass.", bold: true),
                  ],

                  [tableText("1. Sg."), tableText("-ν"), tableText("-μην")],

                  [tableText("2. Sg."), tableText("-ς"), tableText("-σο")],

                  [tableText("3. Sg."), tableText("-"), tableText("-το")],

                  [tableText("1. Pl."), tableText("-μεν"), tableText("-μεθα")],

                  [tableText("2. Pl."), tableText("-τε"), tableText("-σθε")],

                  [
                    tableText("3. Pl."),
                    tableText("-ν / -σαν"),
                    tableText("-ντο"),
                  ],
                ]),

                const SizedBox(height: 40),

                const Text(
                  "εἰμί",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                endingTable([
                  [
                    tableText("Person", bold: true),
                    tableText("Prä.", bold: true),
                    tableText("Impf.", bold: true),
                  ],

                  [tableText("1. Sg."), tableText("εἰμί"), tableText("ἦν")],

                  [tableText("2. Sg."), tableText("εἶ"), tableText("ἦς")],

                  [tableText("3. Sg."), tableText("ἐστί(ν)"), tableText("ἦν")],

                  [tableText("1. Pl."), tableText("ἐσμέν"), tableText("ἦμεν")],

                  [tableText("2. Pl."), tableText("ἐστέ"), tableText("ἦτε")],

                  [
                    tableText("3. Pl."),
                    tableText("εἰσί(ν)"),
                    tableText("ἦσαν"),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
