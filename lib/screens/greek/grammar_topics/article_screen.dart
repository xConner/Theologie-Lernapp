import 'package:flutter/material.dart';

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bestimmter Artikel")),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  "Der bestimmte Artikel",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,

                  child: Table(
                    border: TableBorder.all(),

                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,

                    columnWidths: const {
                      0: FlexColumnWidth(1.3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },

                    children: [
                      TableRow(
                        children: [
                          tableText("Singular", bold: true),

                          Center(child: tableText("Maskulinum", bold: true)),

                          Center(child: tableText("Femininum", bold: true)),

                          Center(child: tableText("Neutrum", bold: true)),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Nominativ"),
                          tableText("ὁ", bold: true),
                          tableText("ἡ", bold: true),
                          tableText("τό", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Genitiv"),
                          tableText("τοῦ", bold: true),
                          tableText("τῆς", bold: true),
                          tableText("τοῦ", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Dativ"),
                          tableText("τῷ", bold: true),
                          tableText("τῇ", bold: true),
                          tableText("τῷ", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Akkusativ"),
                          tableText("τόν", bold: true),
                          tableText("τήν", bold: true),
                          tableText("τό", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Plural", bold: true),
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Nominativ"),
                          tableText("οἱ", bold: true),
                          tableText("αἱ", bold: true),
                          tableText("τά", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Genitiv"),
                          tableText("τῶν", bold: true),
                          tableText("τῶν", bold: true),
                          tableText("τῶν", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Dativ"),
                          tableText("τοῖς", bold: true),
                          tableText("ταῖς", bold: true),
                          tableText("τοῖς", bold: true),
                        ],
                      ),

                      TableRow(
                        children: [
                          tableText("Akkusativ"),
                          tableText("τούς", bold: true),
                          tableText("τάς", bold: true),
                          tableText("τά", bold: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
