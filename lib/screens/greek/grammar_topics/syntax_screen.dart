import 'package:flutter/material.dart';

import '../../../services/greek/exam/grammar_phenomena.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Satzlehre: Konstruktionen und Satzarten mit kurzer Erklärung. Die
/// Stichworte stammen aus der Liste des Klausurerstellers – auch die, die er
/// in Texten nicht erkennen kann.
class SyntaxScreen extends StatelessWidget {
  const SyntaxScreen({super.key});

  /// Kategorien des Klausurerstellers, die zur Satzlehre gehören. Die
  /// Formenlehre (Modus, Tempus, Genus Verbi, Verbklassen, Nomina, Pronomen)
  /// steht auf den übrigen Seiten der Grammatikübersicht.
  static const List<String> categoryIds = [
    "participleSyntax",
    "infinitiveSyntax",
    "clauses",
    "moodSyntax",
    "negation",
    "rection",
    "wordOrder",
  ];

  /// Erklärung je Phänomen (ID aus [GrammarPhenomena]).
  static const Map<String, String> explanations = {
    // Partizipialkonstruktionen
    "syntax.genitive_absolute":
        "Partizip und Bezugswort stehen im Genitiv und sind vom übrigen Satz "
        "losgelöst; das Bezugswort ist kein Satzglied des Hauptsatzes. "
        "Übersetzung als Nebensatz (als, während, weil, obwohl): "
        "ἀνατείλαντος τοῦ ἡλίου – als die Sonne aufgegangen war.",
    "syntax.participium_coniunctum":
        "Das Partizip kongruiert mit einem Satzglied des übergeordneten "
        "Satzes und beschreibt dessen Handlung näher. Übersetzung je nach "
        "Sinn temporal, kausal, konzessiv, modal oder beigeordnet: ταῦτα "
        "εἰπὼν ἀπῆλθεν – nachdem er dies gesagt hatte, ging er weg.",
    "syntax.articular_participle":
        "Mit Artikel steht das Partizip attributiv oder wie ein Substantiv. "
        "Übersetzung meist als Relativsatz: ὁ πιστεύων – der, der glaubt; "
        "der Glaubende.",
    "syntax.periphrastic":
        "Eine Form von εἰμί bildet zusammen mit einem Partizip das "
        "Prädikat: ἦν διδάσκων – er lehrte, er war dabei zu lehren.",
    "syntax.accusative_absolute":
        "Wie der Genitivus absolutus, aber im Akkusativ Singular Neutrum. "
        "Er steht bei unpersönlichen Ausdrücken: ἐξόν – da es erlaubt ist; "
        "δέον – da es nötig ist.",

    // Infinitivkonstruktionen
    "syntax.aci":
        "Nach Verben des Sagens, Meinens und Wahrnehmens sowie nach "
        "unpersönlichen Ausdrücken (δεῖ, ἔξεστιν) steht das Subjekt des "
        "Infinitivs im Akkusativ. Übersetzung meist als dass-Satz: λέγει "
        "τὸν ἄνθρωπον ἐλθεῖν – er sagt, dass der Mensch gekommen ist.",
    "syntax.nci":
        "Steht das übergeordnete Verb im Passiv (λέγεται) oder ist es "
        "δοκέω, wird der Subjektsakkusativ des AcI zum Nominativ und "
        "Subjekt des Satzes: ὁ ἄνθρωπος λέγεται ἐλθεῖν – man sagt, dass "
        "der Mensch gekommen ist.",
    "syntax.articular_infinitive":
        "Der Artikel im Neutrum Singular macht den Infinitiv zum "
        "Substantiv; der Kasus des Artikels zeigt seine Funktion im Satz: "
        "τὸ ζῆν – das Leben.",
    "syntax.prepositional_infinitive":
        "Der substantivierte Infinitiv nach einer Präposition ersetzt einen "
        "Nebensatz: ἐν τῷ (während), μετὰ τό (nachdem), διὰ τό (weil), "
        "εἰς τό und πρὸς τό (damit), πρὸ τοῦ (bevor).",
    "syntax.complementary_infinitive":
        "Verben wie δύναμαι, θέλω, μέλλω, ἄρχομαι und δεῖ werden durch "
        "einen Infinitiv ergänzt: δύναται ἐλθεῖν – er kann kommen.",

    // Nebensätze und Rede
    "clause.relative":
        "Nebensatz, eingeleitet durch ein Relativpronomen. Es richtet sich "
        "in Numerus und Genus nach dem Bezugswort, im Kasus nach seiner "
        "Funktion im Relativsatz.",
    "clause.relative_generalizing":
        "ὃς ἄν bzw. ὃς ἐάν mit Konjunktiv: wer auch immer; jeder, der …",
    "clause.conditional":
        "Bedingungssatz, eingeleitet durch εἰ oder ἐάν (wenn, falls). Modus "
        "und Tempus zeigen, wie die Bedingung gemeint ist: Realis, "
        "Eventualis, Irrealis oder Potentialis.",
    "clause.conditional_real":
        "εἰ mit Indikativ: Die Bedingung wird ohne Aussage über ihre "
        "Wirklichkeit einfach gesetzt – wenn …, dann …",
    "clause.conditional_eventual":
        "ἐάν mit Konjunktiv: Die Bedingung wird erwartet oder wiederholt "
        "sich – wenn, falls, jedes Mal wenn.",
    "clause.conditional_unreal":
        "εἰ mit Indikativ eines Vergangenheitstempus, im Hauptsatz ἄν mit "
        "Indikativ eines Vergangenheitstempus: Die Bedingung ist nicht "
        "erfüllt – wenn … wäre, würde …",
    "clause.conditional_potential":
        "Optativ mit ἄν: Die Aussage wird als bloß möglich hingestellt – "
        "könnte, dürfte wohl.",
    "clause.final":
        "ἵνα oder ὅπως mit Konjunktiv gibt den Zweck an (damit, um zu). "
        "ἵνα leitet in der Koine auch Inhaltssätze ein (dass).",
    "clause.consecutive":
        "ὥστε gibt die Folge an (sodass): mit Infinitiv die mögliche, mit "
        "Indikativ die tatsächlich eingetretene Folge.",
    "clause.causal":
        "Gibt den Grund an (weil, da): ἐπεί, ἐπειδή, διότι, auch ὅτι.",
    "clause.temporal":
        "Gibt die Zeit an: ὅτε (als), ὅταν mit Konjunktiv (wenn, sooft), "
        "ἕως (bis, solange), πρίν (bevor).",
    "clause.indirect_speech":
        "Nach Verben des Sagens, Wissens und Wahrnehmens gibt ὅτι den "
        "Inhalt wieder (dass). Vor wörtlicher Rede bleibt ὅτι unübersetzt "
        "(ὅτι recitativum).",
    "clause.indirect_question":
        "Abhängige Frage nach einem Verb des Sagens, Wissens oder Fragens, "
        "eingeleitet durch ein Fragewort (τίς, πῶς, ποῦ) oder durch εἰ (ob).",

    // Konjunktiv und Optativ im Satz
    "mood.hortatory":
        "1. Person Plural Konjunktiv im Hauptsatz als Aufforderung: ἄγωμεν "
        "– lasst uns gehen!",
    "mood.prohibitive":
        "μή mit Konjunktiv Aorist der 2. Person als Verbot: μὴ φοβηθῇς – "
        "fürchte dich nicht!",
    "mood.deliberative":
        "Konjunktiv der 1. Person in einer überlegenden Frage: τί "
        "ποιήσωμεν; – was sollen wir tun?",
    "mood.wish_optative":
        "Optativ ohne ἄν als erfüllbarer Wunsch: μὴ γένοιτο – das sei "
        "ferne!",
    "mood.emphatic_negation":
        "οὐ μή mit Konjunktiv Aorist verneint nachdrücklich: gewiss nicht, "
        "niemals.",

    // Negationen
    "negation.compound":
        "Negationen aus οὐ bzw. μή und einem weiteren Wort: οὐδέ / μηδέ "
        "(und nicht, auch nicht), οὐδείς / μηδείς (niemand, kein), οὔτε … "
        "οὔτε (weder … noch), οὐκέτι / μηκέτι (nicht mehr). οὐ verneint "
        "Aussagen im Indikativ, μή die übrigen Modi, Infinitiv und Partizip.",

    // Rektion
    "rection.genitive":
        "Diese Verben haben ihre Ergänzung im Genitiv, wo das Deutsche "
        "meist einen Akkusativ setzt: ἀκούω τινός – ich höre jemanden.",
    "rection.dative":
        "Diese Verben haben ihre Ergänzung im Dativ: ἀκολουθέω τινί – ich "
        "folge jemandem; πιστεύω τινί – ich glaube jemandem.",
    "rection.double_accusative":
        "Diese Verben haben zwei Akkusative, einen der Person und einen der "
        "Sache: διδάσκω τινά τι – ich lehre jemanden etwas.",

    // Wortstellung
    "wordorder.attributive":
        "Das Attribut steht zwischen Artikel und Substantiv oder mit "
        "wiederholtem Artikel dahinter – der gute Mensch.",
    "wordorder.predicative":
        "Das Adjektiv steht außerhalb von Artikel und Substantiv und ist "
        "Prädikatsnomen – der Mensch ist gut.",
    "wordorder.hyperbaton":
        "Zusammengehörige Wörter (etwa Attribut und Substantiv) werden "
        "durch andere Satzglieder getrennt, meist zur Hervorhebung.",
  };

  /// Die Phänomene einer Kategorie – auch die, die der Klausurersteller
  /// nicht erkennt.
  static List<GrammarPhenomenon> phenomenaOf(String categoryId) {
    return GrammarPhenomena.inCategory(categoryId);
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Syntax und Konstruktionen",
      children: [
        for (final id in categoryIds)
          if (GrammarPhenomena.category(id) case final category?)
            GrammarSection(
              title: category.label,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final phenomenon in phenomenaOf(id))
                    GrammarDefinition(
                      term: phenomenon.label,
                      explanation: explanations[phenomenon.id],
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
