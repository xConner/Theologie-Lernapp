import 'package:flutter/material.dart';

import '../../../services/greek/grammar/greek_future.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Infinitive Präsens, Futur und Aorist, wie sie der Grammatiktrainer
/// abfragt. Die Futurformen kommen aus [GreekFuture].
class InfinitiveScreen extends StatelessWidget {
  const InfinitiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final future = GreekFuture.conjugate("παύω");

    return GrammarTopicScaffold(
      title: "Infinitiv",
      children: [
        const GrammarSection(
          title: "Überblick",
          child: GrammarBulletList([
            "Den Infinitiv gibt es im Präsens, im Futur und im Aorist, nicht "
                "im Imperfekt.",
            "Er hat weder Person noch Numerus; bestimmt werden Tempus und "
                "Genus Verbi.",
            "Im Präsens sind Medium und Passiv formgleich, im Futur und im "
                "Aorist getrennt.",
          ]),
        ),

        GrammarSection(
          title: "Infinitive von παύω",
          child: GrammarTable(
            rows: [
              const [
                GrammarCell.header("Tempus"),
                GrammarCell.header("Aktiv"),
                GrammarCell.header("Medium"),
                GrammarCell.header("Passiv"),
              ],
              const [
                GrammarCell.label("Präsens"),
                GrammarCell.form("παύειν"),
                GrammarCell.form("παύεσθαι"),
                GrammarCell.form("παύεσθαι"),
              ],
              [
                const GrammarCell.label("Futur"),
                for (final voice in const ["Aktiv", "Medium", "Passiv"])
                  GrammarCell.form(future[voice]!.first.infinitive),
              ],
              const [
                GrammarCell.label("Aorist"),
                GrammarCell.form("παῦσαι"),
                GrammarCell.form("παύσασθαι"),
                GrammarCell.form("παυθῆναι"),
              ],
            ],
          ),
        ),

        const GrammarSection(
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
                GrammarCell.form("παύειν, παύσειν"),
              ],
              [
                GrammarCell.label("Aktiv (Verba contracta)"),
                GrammarCell.form("-εῖν, -ᾶν, -οῦν"),
                GrammarCell.form("ποιεῖν, τιμᾶν, ἀγγελεῖν (Futur)"),
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
                GrammarCell.form("παύεσθαι, παύσεσθαι, παύσασθαι"),
              ],
              [
                GrammarCell.label("Futur Passiv"),
                GrammarCell.form("-θήσεσθαι"),
                GrammarCell.form("παυθήσεσθαι"),
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
