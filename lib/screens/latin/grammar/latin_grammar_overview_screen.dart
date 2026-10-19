import 'package:flutter/material.dart';

import '../../../info/app_info.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/grammar_overview_widgets.dart';
import 'latin_nominal_topics.dart';
import 'latin_syntax_topics.dart';
import 'latin_verb_topics.dart';

class LatinGrammarTopic {
  final String id;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const LatinGrammarTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

class LatinGrammarTopicGroup {
  final String title;
  final String? description;
  final List<LatinGrammarTopic> topics;

  const LatinGrammarTopicGroup({
    required this.title,
    this.description,
    required this.topics,
  });
}

/// Themen der lateinischen Grammatikübersicht in der Reihenfolge des
/// Lehrgangs. Die Zuordnung zu den Lektionen 1–3 ist aus deren Wortschatz
/// erschlossen (welche Formen er voraussetzt); für die folgenden Themen
/// gilt die übliche Reihenfolge der Schulgrammatik.
class LatinGrammarTopics {
  LatinGrammarTopics._();

  static final List<LatinGrammarTopicGroup> groups = [
    LatinGrammarTopicGroup(
      title: "Lektionen 1–3",
      description: "Stoff, den der Wortschatz der Lektionen 1–3 voraussetzt.",
      topics: [
        LatinGrammarTopic(
          id: "cases",
          title: "Kasus und Satzglieder",
          subtitle: "Subjekt, Prädikat, Objekt; Genus",
          builder: (_) => const LatinCasesScreen(),
        ),
        LatinGrammarTopic(
          id: "present",
          title: "Präsens und Konjugationen",
          subtitle:
              "a-, e-, i-, konsonantische Konjugation; esse, posse, "
              "īre, velle",
          builder: (_) => const LatinPresentScreen(),
        ),
        LatinGrammarTopic(
          id: "declension_ao",
          title: "a- und o-Deklination",
          subtitle: "domina, dominus, puer, ager, forum",
          builder: (_) => const LatinAODeclensionScreen(),
        ),
        LatinGrammarTopic(
          id: "declension_3",
          title: "3. Deklination",
          subtitle: "victor, rēx, nōmen, corpus, urbs",
          builder: (_) => const LatinThirdDeclensionScreen(),
        ),
        LatinGrammarTopic(
          id: "prepositions",
          title: "Präpositionen",
          subtitle: "mit Akkusativ und Ablativ",
          builder: (_) => const LatinPrepositionsScreen(),
        ),
        LatinGrammarTopic(
          id: "imperative_infinitive",
          title: "Imperativ und Infinitiv",
          subtitle: "Befehle, Verbote, Infinitive",
          builder: (_) => const LatinImperativeInfinitiveScreen(),
        ),
        LatinGrammarTopic(
          id: "pronouns",
          title: "Pronomen",
          subtitle: "ego, tū, sē; is, hic, ille; quī",
          builder: (_) => const LatinPronounsScreen(),
        ),
      ],
    ),
    LatinGrammarTopicGroup(
      title: "Weiterführend",
      description:
          "Für die folgenden Lektionen liegt kein Abgleich mit dem "
          "Lehrbuch vor; die Reihenfolge folgt dem üblichen Lehrgang.",
      topics: [
        LatinGrammarTopic(
          id: "adjectives",
          title: "Adjektive und KNG-Kongruenz",
          subtitle: "bonus, pulcher, fortis, fēlīx",
          builder: (_) => const LatinAdjectivesScreen(),
        ),
        LatinGrammarTopic(
          id: "imperfect_future",
          title: "Imperfekt und Futur I",
          subtitle: "Indikativ Aktiv",
          builder: (_) => const LatinImperfectFutureScreen(),
        ),
        LatinGrammarTopic(
          id: "perfect",
          title: "Perfekt, Plusquamperfekt, Futur II",
          subtitle: "Perfektbildung und Stammformen",
          builder: (_) => const LatinPerfectScreen(),
        ),
        LatinGrammarTopic(
          id: "declension_ue",
          title: "u- und e-Deklination",
          subtitle: "senātus, manus, rēs, diēs",
          builder: (_) => const LatinUEDeclensionScreen(),
        ),
        LatinGrammarTopic(
          id: "passive",
          title: "Passiv",
          subtitle: "Präsens, Imperfekt, Futur I; Urheber",
          builder: (_) => const LatinPassiveScreen(),
        ),
        LatinGrammarTopic(
          id: "subjunctive",
          title: "Konjunktiv",
          subtitle: "Bildung, Zeitenfolge, Gebrauch im Hauptsatz",
          builder: (_) => const LatinSubjunctiveScreen(),
        ),
        LatinGrammarTopic(
          id: "participles",
          title: "Partizipien",
          subtitle: "PPA, PPP, PFA",
          builder: (_) => const LatinParticiplesScreen(),
        ),
        LatinGrammarTopic(
          id: "syntax",
          title: "Satzlehre",
          subtitle: "AcI, Ablativus absolutus, Nebensätze, Gerundium",
          builder: (_) => const LatinSyntaxScreen(),
        ),
      ],
    ),
  ];
}

class LatinGrammarOverviewScreen extends StatelessWidget {
  const LatinGrammarOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GrammarTopicScaffold(
      title: "Grammatikübersicht",
      module: AppModules.latinGrammarOverview,
      children: [
        for (final group in LatinGrammarTopics.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(group.title, style: textTheme.titleLarge),
          ),
          if (group.description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: GrammarNote(group.description!),
            ),

          for (final topic in group.topics)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(topic.title, style: textTheme.titleMedium),
                subtitle: Text(
                  topic.subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: topic.builder),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
