import 'package:flutter/material.dart';

import '../../../services/greek/grammar/greek_future.dart';
import '../../../widgets/grammar_overview_widgets.dart';
import '../../../widgets/settings_selection.dart';

/// Konjugationen nach Zeitformen: Bildung, Stamm, Endungen, Diathesen,
/// Besonderheiten und παύω als vollständiges Beispiel, dazu die Endungen
/// im Überblick und εἰμί.
///
/// Das Futur I folgt den Folien „Sprachkurs Griechisch 2 – Futur“; seine
/// Formen bildet [GreekFuture], dieselbe Quelle, aus der der
/// Grammatiktrainer fragt.
class ConjugationsScreen extends StatefulWidget {
  /// Zuerst gezeigte Zeitform.
  final String initialTense;

  /// Verb, dessen Futur unter „Formen nachschlagen“ zuerst steht.
  final String initialFutureVerb;

  const ConjugationsScreen({
    super.key,
    this.initialTense = "Präsens",
    this.initialFutureVerb = "παύω",
  });

  /// Zeitformen der Übersicht in der Reihenfolge des Trainers; Perfekt und
  /// Plusquamperfekt gehören noch nicht zum Lernstoff.
  static const List<String> tenses = [
    "Präsens",
    "Imperfekt",
    GreekFuture.tense,
    "Aorist",
  ];

  static String tenseLabel(String tense) {
    return tense == GreekFuture.tense ? "Futur I" : tense;
  }

  static const List<String> persons = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  // Indikativ von παύω je Zeitform und Genus Verbi (Präsens, Imperfekt und
  // Aorist Aktiv/Medium wie in den Tabellen des Trainers).
  static const Map<String, Map<String, List<String>>> _pauo = {
    "Präsens": {
      "Aktiv": ["παύω", "παύεις", "παύει", "παύομεν", "παύετε", "παύουσι(ν)"],
      "Medium/Passiv": [
        "παύομαι",
        "παύῃ",
        "παύεται",
        "παυόμεθα",
        "παύεσθε",
        "παύονται",
      ],
    },
    "Imperfekt": {
      "Aktiv": [
        "ἔπαυον",
        "ἔπαυες",
        "ἔπαυε(ν)",
        "ἐπαύομεν",
        "ἐπαύετε",
        "ἔπαυον",
      ],
      "Medium/Passiv": [
        "ἐπαυόμην",
        "ἐπαύου",
        "ἐπαύετο",
        "ἐπαυόμεθα",
        "ἐπαύεσθε",
        "ἐπαύοντο",
      ],
    },
    "Aorist": {
      "Aktiv": [
        "ἔπαυσα",
        "ἔπαυσας",
        "ἔπαυσε(ν)",
        "ἐπαύσαμεν",
        "ἐπαύσατε",
        "ἔπαυσαν",
      ],
      "Medium": [
        "ἐπαυσάμην",
        "ἐπαύσω",
        "ἐπαύσατο",
        "ἐπαυσάμεθα",
        "ἐπαύσασθε",
        "ἐπαύσαντο",
      ],
      "Passiv": [
        "ἐπαύθην",
        "ἐπαύθης",
        "ἐπαύθη",
        "ἐπαύθημεν",
        "ἐπαύθητε",
        "ἐπαύθησαν",
      ],
    },
  };

  /// Indikativ von παύω in der Zeitform [tense], je Genus Verbi. Das Futur
  /// kommt aus [GreekFuture].
  static Map<String, List<String>> pauo(String tense) {
    if (tense == GreekFuture.tense) {
      return {
        for (final MapEntry(key: voice, value: variants)
            in GreekFuture.conjugate("παύω").entries)
          voice: variants.first.finite,
      };
    }

    return _pauo[tense] ?? const {};
  }

  /// Beispielsätze der Folien mit Bestimmung der Futurform.
  static const List<(String, String)> futureSentences = [
    ("πιστεύσω ὑμῖν.", "πιστεύσω: 1. Sg. Ind. Fut. Akt. von πιστεύω"),
    (
      "διώξουσιν ὑμᾶς.",
      "διώξουσιν: 3. Pl. Ind. Fut. Akt. von διώκω (κ + σ → ξ)",
    ),
    (
      "ὁ γεωργὸς τὰ ὄργανα οὐ ποιήσεται.",
      "ποιήσεται: 3. Sg. Ind. Fut. Med. von ποιέω",
    ),
    (
      "τὰ ὄργανα ὑπὸ τοῦ γεωργοῦ οὐ ποιηθήσεται.",
      "ποιηθήσεται: 3. Sg. Ind. Fut. Pass. von ποιέω",
    ),
    (
      "οἱ ἀδελφοί σου φονεύσουσιν ἀλλήλους.",
      "φονεύσουσιν: 3. Pl. Ind. Fut. Akt. von φονεύω",
    ),
    ("μόνον τὸ σῶμα σώσεις.", "σώσεις: 2. Sg. Ind. Fut. Akt. von σῴζω"),
    ("εὐδαίμονες ἐσόμεθα.", "ἐσόμεθα: 1. Pl. Ind. Fut. von εἰμί"),
  ];

  /// ὡς + Partizip Futur (final) – Beispiele der Folien.
  static const List<(String, String)> finalParticiples = [
    (
      "ὁ τῶν Ἀθηναίων βασιλεὺς ἦλθεν εἰς Δελφούς, ὡς ἐρωτήσων τὸν θεὸν "
          "περὶ τῆς τύχης τῆς τῶν Ἀθηνῶν.",
      "ἐρωτήσων: Part. Fut. Akt. Nom. Sg. m. von ἐρωτάω",
    ),
    (
      "ἐκέλευσεν οὖν ὁ θεὸς αὐτὸν τὴν θυγατέρα θῦσαι, ὡς σώσοντα τὴν πόλιν.",
      "σώσοντα: Part. Fut. Akt. Akk. Sg. m. von σῴζω",
    ),
    (
      "ταχέως πάλιν εἰς Ἀθήνας ἦλθεν, ὡς συμβουλευσόμενος τῇ γυναικί.",
      "συμβουλευσόμενος: Part. Fut. Med. Nom. Sg. m. von συμβουλεύω",
    ),
  ];

  @override
  State<ConjugationsScreen> createState() => _ConjugationsScreenState();
}

class _ConjugationsScreenState extends State<ConjugationsScreen> {
  late String _tense = widget.initialTense;

  // Verb, dessen Futur vollständig angezeigt wird.
  late String _futureVerb = widget.initialFutureVerb;

  static Widget _table(List<String> header, List<List<String>> rows) {
    return GrammarTable(
      rows: [
        [for (final label in header) GrammarCell.header(label)],
        for (final row in rows)
          [
            GrammarCell.label(row.first),
            for (final form in row.skip(1)) GrammarCell.form(form),
          ],
      ],
    );
  }

  // Indikativ: je Genus Verbi eine Spalte.
  static Widget _indicative(Map<String, List<String>> voices) {
    return _table(
      ["Person", ...voices.keys],
      [
        for (var i = 0; i < ConjugationsScreen.persons.length; i++)
          [ConjugationsScreen.persons[i], for (final v in voices.values) v[i]],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: "Konjugationen",
      children: [
        GrammarSection(
          title: "Zeitformen im Vergleich",
          description:
              "1. Sg. Indikativ von παύω. Kennzeichen: Augment (ἐ-), "
              "σ des Futurs, σα des Aorists, θη des Passivs.",
          child: _table(
            ["Zeitform", "Aktiv", "Medium", "Passiv"],
            [
              for (final tense in ConjugationsScreen.tenses)
                [
                  ConjugationsScreen.tenseLabel(tense),
                  ..._firstSingular(ConjugationsScreen.pauo(tense)),
                ],
            ],
          ),
        ),

        GrammarSection(
          title: "Zeitform wählen",
          description:
              "Perfekt und Plusquamperfekt folgen, sobald sie zum "
              "Lernstoff gehören. Ein Futur II gibt es im Lernstoff nicht.",
          child: SingleSelectChips(
            label: "Zeitform",
            options: [
              for (final tense in ConjugationsScreen.tenses)
                ConjugationsScreen.tenseLabel(tense),
            ],
            value: ConjugationsScreen.tenseLabel(_tense),
            onChanged: (label) {
              setState(() {
                _tense = ConjugationsScreen.tenses.firstWhere(
                  (tense) => ConjugationsScreen.tenseLabel(tense) == label,
                );
              });
            },
          ),
        ),

        ...switch (_tense) {
          "Präsens" => _present(),
          "Imperfekt" => _imperfect(),
          GreekFuture.tense => _future(),
          _ => _aorist(),
        },

        GrammarSection(
          title: "Primäre Endungen",
          description: "Präsens und Futur",
          child: _table(
            ["Person", "Akt.", "Med./Pass."],
            [
              ["1. Sg.", "-ω", "-μαι"],
              ["2. Sg.", "-εις", "-η"],
              ["3. Sg.", "-ει", "-ται"],
              ["1. Pl.", "-μεν", "-μεθα"],
              ["2. Pl.", "-τε", "-σθε"],
              ["3. Pl.", "-σι(ν)", "-νται"],
            ],
          ),
        ),

        GrammarSection(
          title: "Sekundäre Endungen",
          description: "Imperfekt und Aorist",
          child: _table(
            ["Person", "Akt.", "Med./Pass."],
            [
              ["1. Sg.", "-ν", "-μην"],
              ["2. Sg.", "-ς", "-σο"],
              ["3. Sg.", "-", "-το"],
              ["1. Pl.", "-μεν", "-μεθα"],
              ["2. Pl.", "-τε", "-σθε"],
              ["3. Pl.", "-ν / -σαν", "-ντο"],
            ],
          ),
        ),

        GrammarSection(
          title: "εἰμί",
          child: _table(
            ["Person", "Prä.", "Impf.", "Fut."],
            [
              for (var i = 0; i < 6; i++)
                [
                  ConjugationsScreen.persons[i],
                  _eimiPresent[i],
                  _eimiImperfect[i],
                  GreekFuture.conjugate("εἰμί")["Medium"]!.first.finite[i],
                ],
            ],
          ),
        ),
      ],
    );
  }

  static const List<String> _eimiPresent = [
    "εἰμί",
    "εἶ",
    "ἐστί(ν)",
    "ἐσμέν",
    "ἐστέ",
    "εἰσί(ν)",
  ];

  static const List<String> _eimiImperfect = [
    "ἦν",
    "ἦς",
    "ἦν",
    "ἦμεν",
    "ἦτε",
    "ἦσαν",
  ];

  // Aktiv, Medium, Passiv; im Präsens und Imperfekt steht die
  // Medium/Passiv-Form in beiden Spalten.
  static List<String> _firstSingular(Map<String, List<String>> voices) {
    final shared = voices["Medium/Passiv"]?.first;

    return [
      voices["Aktiv"]?.first ?? "–",
      shared ?? voices["Medium"]?.first ?? "–",
      shared ?? voices["Passiv"]?.first ?? "–",
    ];
  }

  // ---------------------------------------------------------------------------
  // PRÄSENS
  // ---------------------------------------------------------------------------

  List<Widget> _present() {
    return [
      const GrammarSection(
        title: "Präsens: Bildung",
        child: GrammarBulletList([
          "Präsensstamm + Themavokal (ο/ε) + primäre Endungen: παύ-ο-μεν.",
          "Kein Augment, kein Tempuszeichen.",
          "Medium und Passiv sind formgleich (Medium/Passiv).",
          "Deponentien (γίγνομαι, ἔρχομαι) haben nur mediale Formen mit "
              "aktiver Bedeutung.",
          "Verba contracta ziehen den Stammvokal mit der Endung zusammen "
              "(ποιέω → ποιῶ, τιμάω → τιμῶ).",
        ]),
      ),
      GrammarSection(
        title: "Präsens: Endungen",
        child: _table(
          ["Person", "Aktiv", "Medium/Passiv"],
          [
            ["1. Sg.", "-ω", "-ομαι"],
            ["2. Sg.", "-εις", "-ῃ"],
            ["3. Sg.", "-ει", "-εται"],
            ["1. Pl.", "-ομεν", "-ομεθα"],
            ["2. Pl.", "-ετε", "-εσθε"],
            ["3. Pl.", "-ουσι(ν)", "-ονται"],
          ],
        ),
      ),
      GrammarSection(
        title: "Präsens von παύω",
        child: _indicative(ConjugationsScreen.pauo("Präsens")),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // IMPERFEKT
  // ---------------------------------------------------------------------------

  List<Widget> _imperfect() {
    return [
      const GrammarSection(
        title: "Imperfekt: Bildung",
        child: GrammarBulletList([
          "Augment + Präsensstamm + Themavokal + sekundäre Endungen: "
              "ἔ-παυ-ο-ν.",
          "Syllabisches Augment ἐ- vor Konsonant; vor Vokal wird der "
              "Anlaut gedehnt (ἀκούω → ἤκουον).",
          "Das Imperfekt gibt es nur im Indikativ.",
          "Medium und Passiv sind wie im Präsens formgleich.",
          "εἰμί: ἦν, ἦς, ἦν … (siehe unten).",
        ]),
      ),
      GrammarSection(
        title: "Imperfekt: Endungen",
        child: _table(
          ["Person", "Aktiv", "Medium/Passiv"],
          [
            ["1. Sg.", "-ον", "-ομην"],
            ["2. Sg.", "-ες", "-ου"],
            ["3. Sg.", "-ε(ν)", "-ετο"],
            ["1. Pl.", "-ομεν", "-ομεθα"],
            ["2. Pl.", "-ετε", "-εσθε"],
            ["3. Pl.", "-ον", "-οντο"],
          ],
        ),
      ),
      GrammarSection(
        title: "Imperfekt von παύω",
        child: _indicative(ConjugationsScreen.pauo("Imperfekt")),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // AORIST
  // ---------------------------------------------------------------------------

  List<Widget> _aorist() {
    return [
      const GrammarSection(
        title: "Aorist: Bildung",
        child: GrammarBulletList([
          "Schwacher Aorist: Augment + Stamm + σα + sekundäre Endungen: "
              "ἔ-παυ-σα.",
          "Stammveränderungen vor σ wie im Futur: ἔβλεψα, ἔπεισα, ἦρξα; "
              "Liquidstämme ohne σ: ἤγγειλα, ἔκρινα.",
          "Starker Aorist: eigener Stamm mit den Endungen des Imperfekts "
              "(ἔλαβον, ἦλθον, εἶπον); Wurzelaorist: ἔβην, ἔγνων.",
          "Medium und Passiv sind getrennt: Medium ἐπαυσάμην, Passiv mit θη "
              "ἐπαύθην.",
          "Im Trainer wird das Aorist Passiv nur im Infinitiv (παυθῆναι), "
              "im Partizip (παυθείς) und bei Deponentien gefragt.",
          "Die häufigsten Verben stehen im Aoristblatt.",
        ]),
      ),
      GrammarSection(
        title: "Aorist: Endungen",
        child: _table(
          ["Person", "Aktiv", "Medium", "Passiv"],
          [
            ["1. Sg.", "-σα", "-σαμην", "-θην"],
            ["2. Sg.", "-σας", "-σω", "-θης"],
            ["3. Sg.", "-σε(ν)", "-σατο", "-θη"],
            ["1. Pl.", "-σαμεν", "-σαμεθα", "-θημεν"],
            ["2. Pl.", "-σατε", "-σασθε", "-θητε"],
            ["3. Pl.", "-σαν", "-σαντο", "-θησαν"],
          ],
        ),
      ),
      GrammarSection(
        title: "Aorist von παύω",
        child: _indicative(ConjugationsScreen.pauo("Aorist")),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // FUTUR I (FOLIEN)
  // ---------------------------------------------------------------------------

  List<Widget> _future() {
    final pauo = GreekFuture.conjugate("παύω");

    final slideGroups = <FutureGroup, List<FutureVerb>>{};
    for (final verb in GreekFuture.verbs) {
      if (verb.source == FutureSource.slides && verb.lemma != "παύω") {
        (slideGroups[verb.group] ??= []).add(verb);
      }
    }

    final ruleVerbs = [
      for (final verb in GreekFuture.verbs)
        if (verb.source == FutureSource.rule) verb,
    ];

    final participle = pauo["Aktiv"]!.first.participle;

    return [
      const GrammarSection(
        title: "Futur I: Bildung",
        description: "Nach den Folien (Ars Graeca § 86.2, Grammateion § 3.2.3)",
        child: GrammarBulletList([
          "Futurstamm + Themavokal (ο/ε) + primäre Endungen, ohne Augment.",
          "Kennzeichen: σ nach dem Stamm (παύ-σ-ω); im Passiv θη + σ "
              "(παυ-θή-σ-ομαι).",
          "Aktiv und Medium haben denselben Futurstamm (παύσω – "
              "παύσομαι), das Passiv einen eigenen mit θη. Anders als im "
              "Präsens sind Medium und Passiv verschieden.",
          "Medium und Passiv haben die Endungen des Präsens "
              "Medium/Passiv (-ομαι, -ῃ, -εται …).",
          "Das σ verändert viele Stämme (Kontrakta, Labiale, Dentale, "
              "Gutturale) – siehe Stammveränderungen. Liquidstämme bilden "
              "das Futur ohne σ.",
          "Futur gibt es im Indikativ, Infinitiv und Partizip, nicht im "
              "Imperativ.",
        ]),
      ),
      GrammarSection(
        title: "Futur I: Endungen",
        child: _table(
          ["Person", "Aktiv", "Medium", "Passiv"],
          [
            ["1. Sg.", "-σ-ω", "-σ-ομαι", "-θή-σ-ομαι"],
            ["2. Sg.", "-σ-εις", "-σ-ῃ", "-θή-σ-ῃ"],
            ["3. Sg.", "-σ-ει", "-σ-εται", "-θή-σ-εται"],
            ["1. Pl.", "-σ-ομεν", "-σ-όμεθα", "-θη-σ-όμεθα"],
            ["2. Pl.", "-σ-ετε", "-σ-εσθε", "-θή-σ-εσθε"],
            ["3. Pl.", "-σ-ουσι(ν)", "-σ-ονται", "-θή-σ-ονται"],
          ],
        ),
      ),
      GrammarSection(
        title: "Futur I von παύω",
        child: _indicative({
          for (final MapEntry(key: voice, value: variants) in pauo.entries)
            voice: variants.first.finite,
        }),
      ),
      GrammarSection(
        title: "Infinitiv und Partizip Futur",
        description:
            "Die Partizipien auf -σόμενος werden regelmäßig nach der "
            "a-/o-Deklination flektiert.",
        child: _table(
          ["Genus Verbi", "Infinitiv", "Partizip (m, f, n)"],
          [
            for (final MapEntry(key: voice, value: variants) in pauo.entries)
              [voice, variants.first.infinitive, _nominatives(variants.first)],
          ],
        ),
      ),
      if (participle != null)
        GrammarSection(
          title: "Partizip Futur Aktiv",
          description: _nominatives(pauo["Aktiv"]!.first),
          child: DeclensionParadigmTable(paradigm: participle),
        ),

      GrammarSection(
        title: "Stammveränderungen",
        description:
            "Verben der Folien; die Regel steht unter der Gruppe. "
            "Ein Strich heißt: im Lernstoff nicht vorgesehen oder ohne "
            "verlässliche Daten.",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final MapEntry(key: group, value: verbs)
                in slideGroups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  "${group.label}: ${group.rule}",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _stemTable(verbs),
            ],
          ],
        ),
      ),

      GrammarSection(
        title: "Formen nachschlagen",
        description:
            "Vollständiges Futur eines Verbs – genau die Formen, die der "
            "Trainer fragt.",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              key: const ValueKey("future-verb"),
              isExpanded: true,
              value: _futureVerb,
              items: [
                for (final verb in GreekFuture.verbs)
                  DropdownMenuItem(
                    value: verb.lemma,
                    child: Text("${verb.lemma} – ${verb.group.label}"),
                  ),
              ],
              onChanged: (lemma) {
                if (lemma != null) {
                  setState(() => _futureVerb = lemma);
                }
              },
            ),
            const SizedBox(height: 8),
            ..._fullFuture(_futureVerb),
          ],
        ),
      ),

      GrammarSection(
        title: "Beispielsätze der Folien",
        child: GrammarTable(
          rows: [
            const [GrammarCell.header("Satz"), GrammarCell.header("Futur")],
            for (final (sentence, analysis)
                in ConjugationsScreen.futureSentences)
              [GrammarCell.form(sentence), GrammarCell.text(analysis)],
          ],
        ),
      ),
      GrammarSection(
        title: "ὡς + Partizip Futur: final",
        description: "„um zu …“",
        child: GrammarTable(
          rows: [
            const [GrammarCell.header("Satz"), GrammarCell.header("Partizip")],
            for (final (sentence, analysis)
                in ConjugationsScreen.finalParticiples)
              [GrammarCell.form(sentence), GrammarCell.text(analysis)],
          ],
        ),
      ),

      GrammarSection(
        title: "Weitere Verben der Vokabelliste",
        description:
            "Nicht auf den Folien, aber genau nach der Regel ihrer Gruppe "
            "gebildet.",
        child: _stemTable(ruleVerbs, showGroup: true),
      ),

      const GrammarSection(
        title: "Grenzen",
        child: GrammarBulletList([
          "Abgefragt wird das Futur nur bei Verben dieser Seite. Verben, "
              "deren Futur von den Folienregeln abweicht (καλέω → καλέσω, "
              "ἐάω → ἐάσω, δοκέω → δόξω, θαυμάζω → θαυμάσομαι, τρέφω → "
              "θρέψω) oder das die Folien nicht behandeln, fehlen bewusst.",
          "Liquidstämme: Die Folien nennen nur die 1. Sg. (ἀγγελῶ). Die "
              "übrigen Formen folgen der ε-Kontraktion (ἀγγελεῖς, "
              "ἀγγελοῦμεν …), ebenso ἐρῶ.",
          "Futur Passiv nur, wo die Folien es nennen (παυθήσομαι, "
              "ποιηθήσομαι) oder der Aorist Passiv des Trainers den Stamm "
              "liefert (σωθῆναι → σωθήσομαι).",
          "εἶμι („ich werde gehen“, zu ἔρχομαι) hat Präsensformen und wird "
              "nicht als Futur gefragt.",
          "πείσομαι ist Futur Medium von πείθω und Futur von πάσχω.",
        ]),
      ),
    ];
  }

  static String _nominatives(FutureVoiceForms forms) {
    final participle = forms.participle;

    if (participle == null) {
      return "–";
    }

    return [
      for (final gender in const ["m", "f", "n"])
        participle.form("Nominativ", "Sg", gender) ?? "",
    ].join(", ");
  }

  Widget _stemTable(List<FutureVerb> verbs, {bool showGroup = false}) {
    String first(Map<String, List<FutureVoiceForms>> forms, String voice) {
      final variants = forms[voice];

      return variants == null
          ? "–"
          : [for (final v in variants) v.finite.first].join(" / ");
    }

    return GrammarTable(
      rows: [
        [
          const GrammarCell.header("Präsens"),
          if (showGroup) const GrammarCell.header("Gruppe"),
          const GrammarCell.header("Aktiv"),
          const GrammarCell.header("Medium"),
          const GrammarCell.header("Passiv"),
        ],
        for (final verb in verbs)
          if (GreekFuture.conjugate(verb.lemma) case final forms)
            [
              GrammarCell.form(verb.lemma),
              if (showGroup) GrammarCell.text(verb.group.label),
              GrammarCell.form(first(forms, "Aktiv")),
              GrammarCell.form(first(forms, "Medium")),
              GrammarCell.form(first(forms, "Passiv")),
            ],
      ],
    );
  }

  List<Widget> _fullFuture(String lemma) {
    final verb = GreekFuture.of(lemma)!;
    final forms = GreekFuture.conjugate(lemma);

    final columns = <String, List<String>>{};
    final infinitives = <String, String>{};
    final participles = <String, String>{};

    for (final MapEntry(key: voice, value: variants) in forms.entries) {
      for (final variant in variants) {
        final label = variants.length > 1
            ? "$voice (${variant.finite.first})"
            : voice;

        columns[label] = variant.finite;
        infinitives[label] = variant.infinitive;
        participles[label] = _nominatives(variant);
      }
    }

    return [
      Text(
        "${verb.group.label}: ${verb.group.rule}"
        "${verb.source == FutureSource.rule ? " – nach der Folienregel" : ""}",
      ),
      const SizedBox(height: 8),
      _table(
        ["Person", ...columns.keys],
        [
          for (var i = 0; i < ConjugationsScreen.persons.length; i++)
            [
              ConjugationsScreen.persons[i],
              for (final c in columns.values) c[i],
            ],
          ["Infinitiv", ...infinitives.values],
          ["Partizip", ...participles.values],
        ],
      ),
    ];
  }
}
