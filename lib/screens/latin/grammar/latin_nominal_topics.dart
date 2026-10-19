import 'package:flutter/material.dart';

import '../../../services/latin/grammar/latin_grammar_words.dart';
import '../../../services/latin/grammar/latin_morphology.dart';
import '../../../widgets/grammar_overview_widgets.dart';
import 'latin_grammar_widgets.dart';

// Themenseiten der Nominalformen: Kasus, Deklinationen, Adjektive, Pronomen,
// Präpositionen.

class LatinCasesScreen extends StatelessWidget {
  const LatinCasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LatinTopicScaffold(
      title: "Kasus und Satzglieder",
      stage: "Lektion 1–2: Nominativ und Akkusativ",
      children: [
        GrammarSection(
          title: "Die Kasus",
          description:
              "Latein hat sechs Kasus. Die Endung zeigt, welche Rolle ein "
              "Wort im Satz spielt; die Wortstellung ist darum freier als "
              "im Deutschen.",
          child: LatinTextTable(
            [
              ["Kasus", "Frage", "Satzglied", "Beispiel", "Übersetzung"],
              [
                "Nominativ",
                "wer? was?",
                "Subjekt, Prädikatsnomen",
                "Dominus venit.",
                "Der Herr kommt.",
              ],
              [
                "Genitiv",
                "wessen?",
                "Attribut",
                "equus dominī",
                "das Pferd des Herrn",
              ],
              [
                "Dativ",
                "wem?",
                "Objekt",
                "Servus dominō pāret.",
                "Der Sklave gehorcht dem Herrn.",
              ],
              [
                "Akkusativ",
                "wen? was? wohin?",
                "Objekt, Richtung",
                "Servus equum spectat.",
                "Der Sklave betrachtet das Pferd.",
              ],
              [
                "Ablativ",
                "womit? wodurch? wo? wann?",
                "Adverbiale",
                "Populus victōriā gaudet.",
                "Das Volk freut sich über den Sieg.",
              ],
              [
                "Vokativ",
                "Anrede",
                "–",
                "Salvē, domine!",
                "Sei gegrüßt, Herr!",
              ],
            ],
            formColumns: {3},
          ),
        ),
        GrammarSection(
          title: "Subjekt und Prädikat",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Das Prädikat (meist ein Verb) steht oft am Satzende. Seine "
                "Personalendung enthält das Subjekt; ein eigenes Subjektswort "
                "ist nicht nötig.",
              ),
              LatinCallout.rule(
                "Mit esse („sein“) steht ein Prädikatsnomen im Nominativ.",
              ),
              LatinExamples([
                LatinExample("Venit.", "Er (sie, es) kommt."),
                LatinExample("Mercātor clāmat.", "Der Händler schreit."),
                LatinExample(
                  "Dominus senātor est.",
                  "Der Herr ist Senator.",
                  note: "senātor: Prädikatsnomen im Nominativ",
                ),
              ]),
            ],
          ),
        ),
        GrammarSection(
          title: "Ablativ",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Der Ablativ hat im Deutschen keine Entsprechung. Er wird "
                "mit einer Präposition übersetzt, die zum Sinn passt "
                "(mit, durch, von, in, an, über …).",
              ),
              LatinExamples([
                LatinExample(
                  "Servus gladiō pugnat.",
                  "Der Sklave kämpft mit dem Schwert.",
                  note: "Ablativ des Mittels: womit?",
                ),
              ]),
            ],
          ),
        ),
        GrammarSection(
          title: "Genus",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Substantive der a-Deklination sind meist feminin, solche "
                "auf -us der o-Deklination meist maskulin, solche auf -um "
                "neutral.",
              ),
              LatinCallout.exception(
                "Männer bleiben Männer: agricola (Bauer), nauta (Seemann) "
                "und poēta (Dichter) sind maskulin, obwohl sie der "
                "a-Deklination folgen.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LatinAODeclensionScreen extends StatelessWidget {
  const LatinAODeclensionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LatinTopicScaffold(
      title: "a- und o-Deklination",
      stage: "Lektion 1–2 (Wortschatz: domina, dominus, forum …)",
      children: [
        GrammarSection(
          title: "Paradigmen",
          description:
              "Längenzeichen markieren lange Vokale. Sie unterscheiden "
              "Formen, die sonst gleich aussehen: domina (Nom.) – dominā "
              "(Abl.).",
          child: LatinNounTable([
            latinNoun("domina"),
            latinNoun("dominus"),
            latinNoun("puer"),
            latinNoun("ager"),
            latinNoun("forum"),
          ], vocative: true),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Dativ und Ablativ Plural enden in beiden Deklinationen auf "
                "-īs (dominīs, servīs). Seltene Ausnahmen wie fīliābus "
                "unterscheiden die Geschlechter.",
              ),
              LatinCallout.rule(
                "Bei Neutra sind Nominativ und Akkusativ immer gleich; im "
                "Plural enden beide auf -a (forum, fora).",
              ),
              LatinCallout.rule(
                "Der Vokativ gleicht dem Nominativ – außer bei Wörtern auf "
                "-us der o-Deklination: domine!",
              ),
              LatinCallout.exception(
                "Wörter auf -ius bilden den Vokativ auf -ī: fīlius → fīlī! "
                "Bei puer und ager bleibt der Nominativ ohne Endung; ager "
                "verliert im Stamm das e (agrī), puer behält es (puerī).",
              ),
              LatinCallout.tip(
                "Mehrdeutige Formen klärt der Zusammenhang: dominī kann "
                "Genitiv Singular oder Nominativ Plural sein, servīs Dativ "
                "oder Ablativ Plural.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Domina servam vocat.",
              "Die Herrin ruft die Sklavin.",
            ),
            LatinExample(
              "Servī dominō pārent.",
              "Die Sklaven gehorchen dem Herrn.",
            ),
            LatinExample(
              "Amīcī per viās properant.",
              "Die Freunde eilen durch die Straßen.",
            ),
          ]),
        ),
      ],
    );
  }
}

class LatinThirdDeclensionScreen extends StatelessWidget {
  const LatinThirdDeclensionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LatinTopicScaffold(
      title: "3. Deklination",
      stage: "Lektion 1–2 (Wortschatz: victor, clāmor, mercātor, senātor)",
      children: [
        GrammarSection(
          title: "Paradigmen",
          child: LatinNounTable([
            latinNoun("victor"),
            latinNoun("rex"),
            latinNoun("nomen"),
            latinNoun("corpus"),
            latinNoun("urbs"),
          ]),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Der Nominativ Singular ist vielgestaltig. Den Stamm zeigt "
                "erst der Genitiv: victor, victōr-is; rēx, rēg-is; nōmen, "
                "nōmin-is. Darum lernt man Nominativ und Genitiv zusammen.",
              ),
              LatinExample(
                "Endungen: -, -is, -ī, -em, -e | -ēs, -um, -ibus, -ēs, -ibus",
                "Maskulina und Feminina; Neutra: Nom. = Akk., Plural auf -a",
              ),
              LatinCallout.exception(
                "i-Stämme bilden den Genitiv Plural auf -ium (urbs, urbium; "
                "auch Wörter mit zwei Konsonanten vor -is wie mōns, montium). "
                "Neutra auf -e, -al, -ar haben Ablativ -ī und Plural -ia "
                "(mare, marī, maria, marium).",
              ),
              LatinCallout.tip(
                "Das Genus lässt sich in der 3. Deklination selten an der "
                "Endung ablesen. Wörter auf -or (victor, clāmor) sind meist "
                "maskulin, auf -men und -us (nōmen, corpus) neutral.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Mercātor clāmōrem audit.",
              "Der Händler hört das Geschrei.",
            ),
            LatinExample(
              "Senātōrēs victōrem laudant.",
              "Die Senatoren loben den Sieger.",
            ),
          ]),
        ),
      ],
    );
  }
}

class LatinUEDeclensionScreen extends StatelessWidget {
  const LatinUEDeclensionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LatinTopicScaffold(
      title: "u- und e-Deklination",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        GrammarSection(
          title: "Paradigmen",
          child: LatinNounTable([
            latinNoun("senatus"),
            latinNoun("manus"),
            latinNoun("res"),
            latinNoun("dies"),
          ]),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "u-Deklination: Genitiv Singular, Nominativ und Akkusativ "
                "Plural lauten gleich (senātūs). Die meisten Wörter sind "
                "maskulin.",
              ),
              LatinCallout.exception(
                "manus (Hand) und domus (Haus) sind feminin; domus hat "
                "zusätzlich Formen der o-Deklination (domī „zu Hause“, "
                "domum „nach Hause“).",
              ),
              LatinCallout.rule(
                "e-Deklination: fast alle Wörter sind feminin, nur diēs "
                "(Tag) ist meist maskulin.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Senātus populusque Rōmānus",
              "Senat und Volk von Rom",
            ),
            LatinExample("rēs pūblica", "der Staat (die öffentliche Sache)"),
          ]),
        ),
      ],
    );
  }
}

class LatinAdjectivesScreen extends StatelessWidget {
  const LatinAdjectivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bonus = latinAdjective("bonus");
    final fortis = latinAdjective("fortis");
    final felix = latinAdjective("felix");

    return LatinTopicScaffold(
      title: "Adjektive und KNG-Kongruenz",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        GrammarSection(
          title: "a-/o-Deklination: ${bonus.dictionaryForm}",
          description:
              "Maskulinum und Neutrum nach der o-, Femininum nach der "
              "a-Deklination. Ebenso miser, misera, miserum und pulcher, "
              "pulchra, pulchrum.",
          child: LatinGenderTable(bonus.paradigm()),
        ),
        GrammarSection(
          title: "3. Deklination: ${fortis.dictionaryForm}",
          description: "Zweiendig: eine Form für Maskulinum und Femininum.",
          child: LatinGenderTable(fortis.paradigm()),
        ),
        GrammarSection(
          title: "3. Deklination: ${felix.dictionaryForm}",
          description: "Einendig: der Nominativ ist für alle Genera gleich.",
          child: LatinGenderTable(felix.paradigm()),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "KNG-Kongruenz: Ein Adjektiv richtet sich in Kasus, Numerus "
                "und Genus nach seinem Bezugswort. Die Endungen müssen "
                "dabei nicht gleich aussehen.",
              ),
              LatinCallout.exception(
                "Adjektive der 3. Deklination haben im Ablativ Singular -ī "
                "(fortī), im Genitiv Plural -ium und im Neutrum Plural -ia "
                "(fortia).",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "nauta bonus",
              "der gute Seemann",
              note:
                  "nauta (a-Dekl., m.) + bonus (m.): gleiche KNG, andere "
                  "Endung",
            ),
            LatinExample("victōrī fortī", "dem tapferen Sieger"),
            LatinExample(
              "Domina laeta est.",
              "Die Herrin ist froh.",
              note: "Adjektiv als Prädikatsnomen",
            ),
          ]),
        ),
      ],
    );
  }
}

class LatinPronounsScreen extends StatelessWidget {
  const LatinPronounsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demonstratives = [
      latinPronoun("is"),
      latinPronoun("hic"),
      latinPronoun("ille"),
      latinPronoun("qui"),
    ];

    return LatinTopicScaffold(
      title: "Pronomen",
      stage: "Lektion 2–3: ego, tū, nōs; weitere weiterführend",
      children: [
        GrammarSection(
          title: "Personalpronomen und Reflexivpronomen",
          description:
              "sē bezieht sich auf das Subjekt des Satzes (sich); einen "
              "Nominativ gibt es nicht.",
          child: LatinPersonalPronounTable([
            latinPronoun("ego"),
            latinPronoun("tu"),
            latinPronoun("se"),
          ]),
        ),
        for (final pronoun in demonstratives)
          GrammarSection(
            title: pronoun.label,
            description: "${pronoun.kind}: ${pronoun.translations.join(", ")}",
            child: LatinGenderTable(pronoun.paradigm()),
          ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Im Nominativ steht das Personalpronomen nur, wenn es "
                "betont ist: Ego labōrō, tū tacēs.",
              ),
              LatinCallout.rule(
                "suus, sua, suum (sein, ihr) bezieht sich auf das Subjekt "
                "(reflexiv); eius (dessen, deren) auf eine andere Person.",
              ),
              LatinCallout.rule(
                "Das Relativpronomen richtet sich in Numerus und Genus "
                "nach seinem Bezugswort, der Kasus nach seiner Funktion im "
                "Relativsatz.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Servus dominum suum amat.",
              "Der Sklave liebt seinen (eigenen) Herrn.",
            ),
            LatinExample(
              "Servus dominum eius amat.",
              "Der Sklave liebt dessen Herrn.",
            ),
            LatinExample(
              "Servus, quem dominus vocat, venit.",
              "Der Sklave, den der Herr ruft, kommt.",
              note: "quem: Sg. m. wie servus, Akkusativ als Objekt zu vocat",
            ),
          ]),
        ),
      ],
    );
  }
}

class LatinPrepositionsScreen extends StatelessWidget {
  const LatinPrepositionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LatinTopicScaffold(
      title: "Präpositionen",
      stage: "Lektion 2–3: ad, per, ante, apud, in, propter",
      children: [
        GrammarSection(
          title: "Präpositionen und ihr Kasus",
          description: "★ = im Wortschatz der Lektionen 1–3",
          child: LatinTextTable(
            [
              ["Präposition", "Kasus", "Bedeutung"],
              for (final p in LatinGrammarWords.prepositions)
                [
                  "${p.lemma}${p.vocabularyId != null ? " ★" : ""}",
                  p.cases.map((c) => LatinCases.short[c]).join(" / "),
                  p.meaning,
                ],
            ],
            formColumns: const {0},
          ),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "in und sub stehen auf die Frage „wohin?“ mit dem "
                "Akkusativ, auf die Frage „wo?“ mit dem Ablativ.",
              ),
              LatinCallout.exception(
                "cum wird an Personalpronomen angehängt: mēcum (mit mir), "
                "tēcum, nōbīscum, vōbīscum.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Servus in forum properat.",
              "Der Sklave eilt auf das Forum.",
              note: "wohin? → Akkusativ",
            ),
            LatinExample(
              "Servus in forō est.",
              "Der Sklave ist auf dem Forum.",
              note: "wo? → Ablativ",
            ),
            LatinExample(
              "Mercātor propter furtum clāmat.",
              "Der Händler schreit wegen des Diebstahls.",
            ),
          ]),
        ),
      ],
    );
  }
}
