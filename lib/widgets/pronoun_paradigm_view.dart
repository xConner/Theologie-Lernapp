import 'package:flutter/material.dart';

import '../models/greek/grammar/pronoun_paradigm.dart';
import '../theme/app_theme.dart';

/// Formentabelle, Gebrauchshinweise und Beispielsätze eines Pronomens.
/// Wird in der Grammatikübersicht und im Grammatiktrainer (nach der Antwort)
/// verwendet.
class PronounParadigmView extends StatelessWidget {
  final PronounParadigm paradigm;

  const PronounParadigmView({super.key, required this.paradigm});

  static const List<(String, String)> _cases = [
    ("Nominativ", "Nom."),
    ("Genitiv", "Gen."),
    ("Dativ", "Dat."),
    ("Akkusativ", "Akk."),
  ];

  static const List<(String, String)> _numbers = [
    ("Sg", "Singular"),
    ("Pl", "Plural"),
  ];

  static Widget _cell(String text, {bool bold = false, double fontSize = 18}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _forms(String grammaticalCase, String number, String? gender) {
    final cell = paradigm.cell(grammaticalCase, number, gender);

    if (cell == null) {
      return "";
    }

    return cell.forms.map((form) => form.text).join(" / ");
  }

  Widget _table(BuildContext context) {
    final genders = paradigm.genders;

    // Ohne Genus (ἐγώ, σύ) eine einzige Formenspalte.
    final List<String?> columns = genders.isEmpty ? [null] : genders;

    return Table(
      border: TableBorder.all(color: context.colors.textSecondary),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: IntrinsicColumnWidth()},
      children: [
        for (final (number, numberLabel) in _numbers) ...[
          TableRow(
            children: [
              _cell(numberLabel, bold: true, fontSize: 14),
              for (final gender in columns)
                _cell(
                  gender == null ? "" : "$gender.",
                  bold: true,
                  fontSize: 14,
                ),
            ],
          ),
          for (final (grammaticalCase, caseLabel) in _cases)
            TableRow(
              children: [
                _cell(caseLabel, fontSize: 14),
                for (final gender in columns)
                  _cell(_forms(grammaticalCase, number, gender), bold: true),
              ],
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          paradigm.kindLabel,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(width: double.infinity, child: _table(context)),

        if (paradigm.usage.isNotEmpty) ...[
          const SizedBox(height: 16),

          const Text("Gebrauch", style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 4),

          for (final line in paradigm.usage)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text("• $line"),
            ),
        ],

        if (paradigm.examples.isNotEmpty) ...[
          const SizedBox(height: 12),

          const Text(
            "Beispiele",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          for (final example in paradigm.examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    example.greek,
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    example.german,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
