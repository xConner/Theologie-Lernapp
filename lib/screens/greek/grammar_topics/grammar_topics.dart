import 'package:flutter/material.dart';

import 'adjectives_screen.dart';
import 'aorist_screen.dart';
import 'aorist_sheet_screen.dart';
import 'article_screen.dart';
import 'comparison_screen.dart';
import 'conjugations_screen.dart';
import 'declinations_screen.dart';
import 'imperative_screen.dart';
import 'infinitive_screen.dart';
import 'participles_screen.dart';
import 'prepositions_screen.dart';
import 'pronouns_screen.dart';
import 'subjunctive_screen.dart';
import 'syntax_screen.dart';

/// Ein Eintrag der Grammatikübersicht.
class GrammarTopic {
  /// Stabile Kennung des Themas.
  final String id;
  final String title;

  /// Kurze Inhaltsangabe unter dem Titel.
  final String subtitle;

  final WidgetBuilder builder;

  const GrammarTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

class GrammarTopicGroup {
  final String title;
  final List<GrammarTopic> topics;

  const GrammarTopicGroup({required this.title, required this.topics});
}

/// Zentrale Liste aller Themen der Grammatikübersicht. Ein neues Thema
/// braucht nur einen Eintrag hier.
class GrammarTopics {
  GrammarTopics._();

  static final List<GrammarTopicGroup> groups = [
    GrammarTopicGroup(
      title: "Nominalformen",
      topics: [
        GrammarTopic(
          id: "article",
          title: "Bestimmter Artikel",
          subtitle: "ὁ, ἡ, τό in allen Kasus",
          builder: (_) => const ArticleScreen(),
        ),
        GrammarTopic(
          id: "declensions",
          title: "Deklinationen",
          subtitle: "o-, a- und 3. Deklination der Substantive",
          builder: (_) => const DeclinationsScreen(),
        ),
        GrammarTopic(
          id: "adjectives",
          title: "Adjektive",
          subtitle: "Adjektive der a-/o-Deklination",
          builder: (_) => const AdjectivesScreen(),
        ),
        GrammarTopic(
          id: "comparison",
          title: "Steigerung der Adjektive",
          subtitle: "Komparativ und Superlativ, unregelmäßige Steigerung",
          builder: (_) => const ComparisonScreen(),
        ),
        GrammarTopic(
          id: "pronouns",
          title: "Pronomen",
          subtitle:
              "Personal-, Possessiv-, Demonstrativ-, Relativ-, "
              "Interrogativ- und Indefinitpronomen",
          builder: (_) => const PronounsScreen(),
        ),
      ],
    ),
    GrammarTopicGroup(
      title: "Verbalformen",
      topics: [
        GrammarTopic(
          id: "conjugations",
          title: "Konjugationen",
          subtitle:
              "Indikativ nach Zeitformen: Präsens, Imperfekt, Futur I, "
              "Aorist – Bildung, Endungen, Aktiv, Medium und Passiv, εἰμί",
          builder: (_) => const ConjugationsScreen(),
        ),
        GrammarTopic(
          id: "aorist",
          title: "Aorist und Stammformen",
          subtitle:
              "Schwacher und starker Aorist, Stammformen der Vokabelliste",
          builder: (_) => const AoristScreen(),
        ),
        GrammarTopic(
          id: "aorist_sheet",
          title: "Aoristblatt",
          subtitle: "Häufige Verben im Aorist mit Infinitiv und Bedeutung",
          builder: (_) => const AoristSheetScreen(),
        ),
        GrammarTopic(
          id: "subjunctive",
          title: "Konjunktiv",
          subtitle:
              "Präsens und Aorist, εἰμί – Gebrauch im Haupt- und Nebensatz",
          builder: (_) => const SubjunctiveScreen(),
        ),
        GrammarTopic(
          id: "imperative",
          title: "Imperativ",
          subtitle: "Präsens und Aorist in Aktiv, Medium und Passiv",
          builder: (_) => const ImperativeScreen(),
        ),
        GrammarTopic(
          id: "infinitive",
          title: "Infinitiv",
          subtitle: "Präsens, Futur und Aorist in Aktiv, Medium und Passiv",
          builder: (_) => const InfinitiveScreen(),
        ),
        GrammarTopic(
          id: "participles",
          title: "Partizipien",
          subtitle: "Präsens, Futur und Aorist mit vollständiger Deklination",
          builder: (_) => const ParticiplesScreen(),
        ),
      ],
    ),
    GrammarTopicGroup(
      title: "Satzlehre",
      topics: [
        GrammarTopic(
          id: "prepositions",
          title: "Präpositionen",
          subtitle: "Kasusrektion und Bedeutungen",
          builder: (_) => const PrepositionsScreen(),
        ),
        GrammarTopic(
          id: "syntax",
          title: "Syntax und Konstruktionen",
          subtitle:
              "Partizipial- und Infinitivkonstruktionen, Nebensätze, "
              "Negationen – mit Erklärung",
          builder: (_) => const SyntaxScreen(),
        ),
      ],
    ),
  ];

  static List<GrammarTopic> get all => [
    for (final group in groups) ...group.topics,
  ];
}
