import 'package:flutter/material.dart';

import '../../../models/greek/grammar/adjective_comparison.dart';
import '../../../services/greek/grammar/adjective_comparisons.dart';
import '../../../services/greek/grammar/greek_declension.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Steigerung der Adjektive: die Reihen, die der Grammatiktrainer abfragt.
class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  static final DeclensionParadigm? comparative = declineComparative(
    masculine: "ἀμείνων",
    neuter: "ἄμεινον",
  );

  static Widget _table(bool irregular) {
    return GrammarTable(
      rows: [
        const [
          GrammarCell.header(AdjectiveComparisons.positive),
          GrammarCell.header(AdjectiveComparisons.comparative),
          GrammarCell.header(AdjectiveComparisons.superlative),
          GrammarCell.header("Bedeutung"),
        ],
        for (final comparison in AdjectiveComparisons.all)
          if (comparison.irregular == irregular)
            [
              GrammarCell.form(comparison.positive),
              GrammarCell.form(
                AdjectiveComparison.describe(
                  comparison.comparatives,
                ).replaceAll(" / ", "\n"),
              ),
              GrammarCell.form(
                AdjectiveComparison.describe(
                  comparison.superlatives,
                ).replaceAll(" / ", "\n"),
              ),
              GrammarCell.text(comparison.translations.join(", ")),
            ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final comparative = ComparisonScreen.comparative;

    return GrammarTopicScaffold(
      title: "Steigerung der Adjektive",
      children: [
        const GrammarSection(
          title: "Überblick",
          child: GrammarBulletList([
            "Regelmäßig: Komparativ auf -τερος, -α, -ον, Superlativ auf "
                "-τατος, -η, -ον (a-/o-Deklination).",
            "Daneben: Komparativ auf -(ί)ων, -(ι)ον (3. Deklination), "
                "Superlativ auf -ιστος, -η, -ον.",
            "In Klammern stehen das Neutrum des Komparativs und Hinweise zur "
                "Form; ganz eingeklammerte Formen sind selten.",
          ]),
        ),

        GrammarSection(title: "Unregelmäßige Steigerung", child: _table(true)),

        GrammarSection(title: "Regelmäßige Steigerung", child: _table(false)),

        if (comparative != null)
          GrammarSection(
            title: "Deklination des Komparativs auf -ων, -ον",
            description:
                "ἀμείνων, ἄμεινον – Maskulinum und Femininum sind gleich; "
                "angegeben sind die unkontrahierten Formen.",
            child: DeclensionParadigmTable(paradigm: comparative),
          ),
      ],
    );
  }
}
