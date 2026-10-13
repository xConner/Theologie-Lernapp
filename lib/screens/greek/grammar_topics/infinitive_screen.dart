import 'package:flutter/material.dart';

import '../../../widgets/grammar_overview_widgets.dart';

/// Infinitive Präsens und Aorist, wie sie der Grammatiktrainer abfragt.
class InfinitiveScreen extends StatelessWidget {
  const InfinitiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GrammarTopicScaffold(
      title: "Infinitiv",
      children: [
        GrammarSection(
          title: "Überblick",
          child: GrammarBulletList([
            "Den Infinitiv gibt es im Präsens und im Aorist, nicht im "
                "Imperfekt.",
            "Er hat weder Person noch Numerus; bestimmt werden Tempus und "
                "Genus Verbi.",
            "Im Präsens sind Medium und Passiv formgleich, im Aorist getrennt.",
          ]),
        ),

        GrammarSection(
          title: "Infinitive von παύω",
          child: GrammarTable(
            rows: [
              [
                GrammarCell.header("Tempus"),
                GrammarCell.header("Aktiv"),
                GrammarCell.header("Medium"),
                GrammarCell.header("Passiv"),
              ],
              [
                GrammarCell.label("Präsens"),
                GrammarCell.form("παύειν"),
                GrammarCell.form("παύεσθαι"),
                GrammarCell.form("παύεσθαι"),
              ],
              [
                GrammarCell.label("Aorist"),
                GrammarCell.form("παῦσαι"),
                GrammarCell.form("παύσασθαι"),
                GrammarCell.form("παυθῆναι"),
              ],
            ],
          ),
        ),

        GrammarSection(
          title: "Endungen",
          child: GrammarTable(
            rows: [
              [
                GrammarCell.header("Genus Verbi"),
                GrammarCell.header("Endung"),
                GrammarCell.header("Beispiele"),
              ],
              [
                GrammarCell.label("Aktiv"),
                GrammarCell.form("-ειν"),
                GrammarCell.form("παύειν"),
              ],
              [
                GrammarCell.label("Aktiv (Verba contracta)"),
                GrammarCell.form("-εῖν, -ᾶν, -οῦν"),
                GrammarCell.form("ποιεῖν, τιμᾶν"),
              ],
              [
                GrammarCell.label("Aktiv (starker Aorist)"),
                GrammarCell.form("-εῖν"),
                GrammarCell.form("ἰδεῖν"),
              ],
              [
                GrammarCell.label("Aktiv (Aorist, Wurzelaorist, εἰμί)"),
                GrammarCell.form("-αι"),
                GrammarCell.form("παῦσαι, βῆναι, γνῶναι, εἶναι"),
              ],
              [
                GrammarCell.label("Medium"),
                GrammarCell.form("-σθαι"),
                GrammarCell.form("παύεσθαι, παύσασθαι"),
              ],
              [
                GrammarCell.label("Aorist Passiv"),
                GrammarCell.form("-ῆναι"),
                GrammarCell.form("παυθῆναι"),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
