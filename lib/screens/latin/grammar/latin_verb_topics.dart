import 'package:flutter/material.dart';

import '../../../services/latin/grammar/latin_grammar_words.dart';
import '../../../services/latin/grammar/latin_morphology.dart';
import '../../../widgets/grammar_overview_widgets.dart';
import 'latin_grammar_widgets.dart';

// Themenseiten der Verbformen.

List<LatinVerb> _modelVerbs() => [
  latinVerb("amare"),
  latinVerb("monere"),
  latinVerb("audire"),
  latinVerb("mittere"),
  latinVerb("capere"),
];

class LatinPresentScreen extends StatelessWidget {
  const LatinPresentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LatinTopicScaffold(
      title: "Präsens und Konjugationen",
      stage: "Lektion 1: 3. Person und esse; Lektion 2–3: alle Personen",
      children: [
        GrammarSection(
          title: "Präsens Indikativ Aktiv",
          description:
              "Die Konjugationsklasse erkennt man am Infinitiv: -āre, -ēre, "
              "-īre, -ere (kurzes e). capere gehört zur konsonantischen "
              "Konjugation mit i-Erweiterung.",
          child: LatinVerbTable(
            verbs: _modelVerbs(),
            tense: LatinTenses.present,
            showConjugation: true,
          ),
        ),
        GrammarSection(
          title: "Unregelmäßige Verben",
          child: LatinVerbTable(
            verbs: [
              latinVerb("esse"),
              latinVerb("posse"),
              latinVerb("ire"),
              latinVerb("velle"),
            ],
            tense: LatinTenses.present,
          ),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Personalendungen: -ō / -m, -s, -t, -mus, -tis, -nt. Die "
                "Endung zeigt die Person; das Subjekt muss nicht eigens "
                "genannt werden.",
              ),
              LatinCallout.rule(
                "In der konsonantischen Konjugation tritt vor die Endung "
                "ein Bindevokal: mitt-i-s, mitt-u-nt.",
              ),
              LatinCallout.exception(
                "esse ist unregelmäßig. posse ist aus pot- und esse "
                "zusammengesetzt: pot- vor Vokal (potest), pos- vor s "
                "(possum). Komposita wie adesse (dasein) werden wie esse "
                "konjugiert.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample("Servus clāmat.", "Der Sklave schreit."),
            LatinExample("Venīmus.", "Wir kommen."),
            LatinExample("Dominus adest.", "Der Herr ist da."),
            LatinExample("Tacēre nōn possum.", "Ich kann nicht schweigen."),
            LatinExample("Quid vīs?", "Was willst du?"),
          ]),
        ),
      ],
    );
  }
}

class LatinImperativeInfinitiveScreen extends StatelessWidget {
  const LatinImperativeInfinitiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final verbs = _modelVerbs();

    return LatinTopicScaffold(
      title: "Imperativ und Infinitiv",
      stage: "Lektion 3: salvē / salvēte, Imperative",
      children: [
        GrammarSection(
          title: "Imperativ",
          child: LatinVerbTable(
            verbs: [...verbs, latinVerb("esse")],
            mood: LatinMoods.imperative,
            tense: LatinTenses.present,
          ),
        ),
        const GrammarSection(
          title: "Regeln zum Imperativ",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Imperativ Singular = Präsensstamm (amā, monē, audī), "
                "Plural = Stamm + -te (amāte). In der konsonantischen "
                "Konjugation: mitte, mittite.",
              ),
              LatinCallout.exception(
                "Kurzformen im Singular: dīc! (sag!), dūc! (führe!), fac! "
                "(mach!).",
              ),
              LatinCallout.rule(
                "Verbote: nōlī (Sg.) / nōlīte (Pl.) + Infinitiv.",
              ),
              LatinExamples([
                LatinExample("Audī, serve!", "Hör, Sklave!"),
                LatinExample("Venīte, amīcī!", "Kommt, Freunde!"),
                LatinExample("Nōlī clāmāre!", "Schrei nicht!"),
                LatinExample("Salvēte!", "Seid gegrüßt!"),
              ]),
            ],
          ),
        ),
        GrammarSection(title: "Infinitive", child: LatinInfinitiveTable(verbs)),
        const GrammarSection(
          title: "Regeln zum Infinitiv",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Infinitiv Präsens Passiv: -rī (amārī, monērī, audīrī); in "
                "der konsonantischen Konjugation nur -ī (mittī, capī).",
              ),
              LatinCallout.rule(
                "Infinitiv Perfekt Aktiv: Perfektstamm + -isse (amāvisse).",
              ),
              LatinExamples([
                LatinExample(
                  "Servī labōrāre dēbent.",
                  "Die Sklaven müssen arbeiten.",
                  note: "Infinitiv als Ergänzung zu dēbēre",
                ),
                LatinExample(
                  "Errāre hūmānum est.",
                  "Irren ist menschlich.",
                  note: "Infinitiv als Subjekt",
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class LatinImperfectFutureScreen extends StatelessWidget {
  const LatinImperfectFutureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final verbs = [..._modelVerbs(), latinVerb("esse")];

    return LatinTopicScaffold(
      title: "Imperfekt und Futur I",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        GrammarSection(
          title: "Imperfekt",
          child: LatinVerbTable(verbs: verbs, tense: LatinTenses.imperfect),
        ),
        GrammarSection(
          title: "Futur I",
          child: LatinVerbTable(verbs: verbs, tense: LatinTenses.future),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Imperfekt: Kennzeichen -ba- (amābam), in der i- und "
                "konsonantischen Konjugation -ēba- (audiēbam, mittēbam).",
              ),
              LatinCallout.rule(
                "Futur I in der a- und e-Konjugation: -b- mit Bindevokal "
                "(amābō, amābis … amābunt); in den übrigen Konjugationen "
                "-a- in der 1. Sg., sonst -e- (mittam, mittēs, mittet …).",
              ),
              LatinCallout.tip(
                "„bō-bi-bu“ bei a und e, „a-e-e-e“ bei den übrigen. Achtung: "
                "mittēs (Futur) – mittis (Präsens).",
              ),
              LatinCallout.rule(
                "In Erzählungen steht das Imperfekt für Hintergrund, Dauer "
                "und Wiederholung, das Perfekt für einmalige, abgeschlossene "
                "Handlungen.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Servī diū labōrābant.",
              "Die Sklaven arbeiteten lange.",
            ),
            LatinExample("Crās veniam.", "Morgen werde ich kommen."),
          ]),
        ),
      ],
    );
  }
}

class LatinPerfectScreen extends StatelessWidget {
  const LatinPerfectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final verbs = [..._modelVerbs(), latinVerb("esse")];
    final model = [latinVerb("amare"), latinVerb("mittere"), latinVerb("esse")];

    final vocabularyVerbs = [
      for (final verb in LatinGrammarWords.verbs)
        if (verb.vocabularyId != null) verb,
    ];

    return LatinTopicScaffold(
      title: "Perfekt, Plusquamperfekt, Futur II",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        GrammarSection(
          title: "Perfekt",
          child: LatinVerbTable(verbs: verbs, tense: LatinTenses.perfect),
        ),
        GrammarSection(
          title: "Plusquamperfekt",
          child: LatinVerbTable(verbs: model, tense: LatinTenses.pluperfect),
        ),
        GrammarSection(
          title: "Futur II",
          child: LatinVerbTable(verbs: model, tense: LatinTenses.futurePerfect),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Alle Formen des Perfektsystems werden vom Perfektstamm "
                "gebildet (3. Stammform ohne -ī). Perfekt: -ī, -istī, -it, "
                "-imus, -istis, -ērunt; Plusquamperfekt: + eram, erās …; "
                "Futur II: + erō, eris … erint.",
              ),
              LatinCallout.rule(
                "Arten der Perfektbildung: v-Perfekt (amāvī), u-Perfekt "
                "(monuī), s-Perfekt (mīsī, dīxī), Dehnungsperfekt (vēnī, "
                "vīdī, lēgī, cēpī), Reduplikation (stetī, dedī).",
              ),
              LatinCallout.exception(
                "Manche Formen unterscheiden sich nur in der Länge: venit "
                "(er kommt) – vēnit (er ist gekommen); legit – lēgit.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample("Mercātor vēnit.", "Der Händler ist gekommen / kam."),
            LatinExample(
              "Dominus servum vocāverat.",
              "Der Herr hatte den Sklaven gerufen.",
            ),
          ]),
        ),
        GrammarSection(
          title: "Stammformen der Verben aus dem Wortschatz",
          description:
              "Infinitiv, 1. Sg. Präsens, 1. Sg. Perfekt und – soweit "
              "hinterlegt – PPP bzw. Supinum.",
          child: LatinTextTable(
            [
              ["Verb", "Stammformen", "Konjugation"],
              for (final verb in vocabularyVerbs)
                [verb.infinitive, verb.principalParts, verb.conjugation.label],
            ],
            formColumns: const {1},
          ),
        ),
      ],
    );
  }
}

class LatinPassiveScreen extends StatelessWidget {
  const LatinPassiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = [latinVerb("amare"), latinVerb("mittere")];

    return LatinTopicScaffold(
      title: "Passiv",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        GrammarSection(
          title: "Präsens Passiv",
          child: LatinVerbTable(
            verbs: _modelVerbs(),
            tense: LatinTenses.present,
            voice: LatinVoices.passive,
          ),
        ),
        GrammarSection(
          title: "Imperfekt Passiv",
          child: LatinVerbTable(
            verbs: model,
            tense: LatinTenses.imperfect,
            voice: LatinVoices.passive,
          ),
        ),
        GrammarSection(
          title: "Futur I Passiv",
          child: LatinVerbTable(
            verbs: model,
            tense: LatinTenses.future,
            voice: LatinVoices.passive,
          ),
        ),
        const GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Passivendungen: -or / -r, -ris (-re), -tur, -mur, -minī, "
                "-ntur.",
              ),
              LatinCallout.rule(
                "Perfekt Passiv: PPP + Form von esse (laudātus est – er ist "
                "gelobt worden). Das PPP richtet sich nach dem Subjekt.",
              ),
              LatinCallout.rule(
                "Der Urheber steht bei Personen mit ā/ab + Ablativ, bei "
                "Sachen im bloßen Ablativ.",
              ),
              LatinCallout.exception(
                "Verben ohne Objekt (venīre, stāre, properāre) bilden kein "
                "persönliches Passiv.",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Servus ā dominō vocātur.",
              "Der Sklave wird vom Herrn gerufen.",
            ),
            LatinExample("Urbs capitur.", "Die Stadt wird eingenommen."),
          ]),
        ),
      ],
    );
  }
}

class LatinSubjunctiveScreen extends StatelessWidget {
  const LatinSubjunctiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final verbs = [..._modelVerbs(), latinVerb("esse")];
    final model = [latinVerb("amare"), latinVerb("mittere"), latinVerb("esse")];

    return LatinTopicScaffold(
      title: "Konjunktiv",
      stage: "weiterführend (nach Lektion 3)",
      children: [
        GrammarSection(
          title: "Konjunktiv Präsens",
          child: LatinVerbTable(
            verbs: verbs,
            mood: LatinMoods.subjunctive,
            tense: LatinTenses.present,
          ),
        ),
        GrammarSection(
          title: "Konjunktiv Imperfekt",
          child: LatinVerbTable(
            verbs: verbs,
            mood: LatinMoods.subjunctive,
            tense: LatinTenses.imperfect,
          ),
        ),
        GrammarSection(
          title: "Konjunktiv Perfekt",
          child: LatinVerbTable(
            verbs: model,
            mood: LatinMoods.subjunctive,
            tense: LatinTenses.perfect,
          ),
        ),
        GrammarSection(
          title: "Konjunktiv Plusquamperfekt",
          child: LatinVerbTable(
            verbs: model,
            mood: LatinMoods.subjunctive,
            tense: LatinTenses.pluperfect,
          ),
        ),
        const GrammarSection(
          title: "Bildung",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Konjunktiv Präsens: a-Konjugation -e- (amem), sonst -a- "
                "(moneam, audiam, mittam, capiam); esse: sim.",
              ),
              LatinCallout.rule(
                "Konjunktiv Imperfekt: Infinitiv Präsens + Endung (amārem, "
                "essem). Konjunktiv Plusquamperfekt: Infinitiv Perfekt + "
                "Endung (amāvissem).",
              ),
              LatinCallout.rule(
                "Konjunktiv Perfekt: Perfektstamm + -erim, -eris, -erit … "
                "(amāverim).",
              ),
            ],
          ),
        ),
        const GrammarSection(
          title: "Zeitenfolge (consecutio temporum)",
          description:
              "Im konjunktivischen Gliedsatz hängt das Tempus vom Hauptsatz "
              "und vom Zeitverhältnis ab.",
          child: LatinTextTable([
            ["Hauptsatz", "gleichzeitig", "vorzeitig"],
            ["Präsens / Futur", "Konj. Präsens", "Konj. Perfekt"],
            ["Vergangenheit", "Konj. Imperfekt", "Konj. Plusquamperfekt"],
          ]),
        ),
        const GrammarSection(
          title: "Konjunktiv im Hauptsatz",
          child: LatinExamples([
            LatinExample(
              "Gaudeāmus!",
              "Lasst uns fröhlich sein!",
              note: "Hortativ (Aufforderung, 1. Pl.)",
            ),
            LatinExample(
              "Sī tacuissēs, philosophus mānsissēs.",
              "Wenn du geschwiegen hättest, wärst du ein Philosoph geblieben.",
              note: "Irrealis der Vergangenheit: Konj. Plusquamperfekt",
            ),
          ]),
        ),
      ],
    );
  }
}

class LatinParticiplesScreen extends StatelessWidget {
  const LatinParticiplesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LatinTopicScaffold(
      title: "Partizipien",
      stage: "weiterführend (nach Lektion 3); nicht im Trainer",
      children: [
        GrammarSection(
          title: "Die drei Partizipien",
          child: LatinTextTable(
            [
              ["Partizip", "Beispiel", "Zeitverhältnis", "Genus verbi"],
              [
                "Präsens Aktiv (PPA)",
                "amāns, amantis",
                "gleichzeitig",
                "aktiv",
              ],
              [
                "Perfekt Passiv (PPP)",
                "amātus, -a, -um",
                "vorzeitig",
                "passiv",
              ],
              ["Futur Aktiv (PFA)", "amātūrus, -a, -um", "nachzeitig", "aktiv"],
            ],
            formColumns: {1},
          ),
        ),
        GrammarSection(
          title: "Regeln",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatinCallout.rule(
                "Das PPA wird wie ein einendiges Adjektiv der 3. Deklination "
                "dekliniert (Genitiv -ntis). PPP und PFA folgen der "
                "a-/o-Deklination.",
              ),
              LatinCallout.exception(
                "Das PPA hat im Ablativ Singular meist -e (amante); als "
                "Adjektiv gebraucht -ī.",
              ),
              LatinCallout.rule(
                "Partizipien richten sich in KNG nach ihrem Bezugswort und "
                "lassen sich oft als Gliedsatz übersetzen (als, weil, "
                "obwohl …), siehe Satzlehre.",
              ),
            ],
          ),
        ),
        GrammarSection(
          title: "Beispiele",
          child: LatinExamples([
            LatinExample(
              "Servum clāmantem audiō.",
              "Ich höre den Sklaven schreien / wie der Sklave schreit.",
            ),
            LatinExample("Urbs capta ārdet.", "Die eingenommene Stadt brennt."),
          ]),
        ),
      ],
    );
  }
}
