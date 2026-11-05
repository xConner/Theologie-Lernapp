import '../../../utils/greek_normalization.dart';
import 'greek_declension.dart';
import 'verb_paradigm.dart';

/// Die athematische Konjugation (Verben auf -μι) nach der Folie
/// „Sprachkurs Griechisch 2 – Die athematische Konjugation (Verben auf -μι)“
/// (Kiel): die „vier großen“ μι-Verben mit Präsensreduplikation δίδωμι,
/// τίθημι, ἵημι und ἵστημι.
///
/// Die Tabellen stehen hier wörtlich wie auf der Folie und gehen den Tabellen
/// des Backends vor ([extend]). Zwei Stellen weichen bewusst ab und sind
/// markiert ([MiVerbTable.note]):
///   * ἵστημι, Aorist aktiv 3. Pl.: Die Folie hat ἔστασαν; die Form des
///     σ-Aorists ist ἔστησαν (berichtigt).
///   * ἵστημι, Spalte „Aorist medium“: Die Folie setzt dort ἔστην mit „(!)“.
///     Das ist der intransitive Wurzelaorist („ich trat hin“) – der Form
///     nach Aktiv. Im Trainer gilt er als Aorist Aktiv.
///
/// Partizipien: Die Folie nennt Nominativ und Genitiv Sg. Die übrigen Kasus
/// bildet [declineParticiple] nach den Partizipientabellen der Lehr-
/// veranstaltung – nur wenn das Ergebnis Nominativ und Genitiv der Folie
/// genau trifft. Sonst (εἵς, εἷσα, ἕν) gelten nur die Formen der Folie.
class GreekMiVerbs {
  GreekMiVerbs._();

  /// Grammatikhinweis der Folie.
  static const List<String> references = [
    "Ars Graeca § 106-107",
    "Grammateion § 3.4.1",
  ];

  static const List<(int, String)> persons = [
    (1, "Sg"),
    (2, "Sg"),
    (3, "Sg"),
    (1, "Pl"),
    (2, "Pl"),
    (3, "Pl"),
  ];

  // ---------------------------------------------------------------------------
  // DIE VIER VERBEN DER FOLIE
  // ---------------------------------------------------------------------------

  static const MiVerb didomi = MiVerb(
    lemma: "δίδωμι",
    meaning: "geben",
    presentStem: "διδω- / διδο-",
    reduplication: "διδ",
    aoristStem: "δω- / δο-",
    tables: [
      MiVerbTable(
        slideTitle: "Präsens aktiv",
        tense: "Präsens",
        voice: "Aktiv",
        forms: [
          "δίδωμι",
          "δίδως",
          "δίδωσι(ν)",
          "δίδομεν",
          "δίδοτε",
          "διδόασι(ν)",
        ],
        infinitive: "διδόναι",
      ),
      MiVerbTable(
        slideTitle: "Präsens passiv",
        tense: "Präsens",
        voice: "Medium/Passiv",
        forms: [
          "δίδομαι",
          "δίδοσαι",
          "δίδοται",
          "διδόμεθα",
          "δίδοσθε",
          "δίδονται",
        ],
        infinitive: "δίδοσθαι",
      ),
      MiVerbTable(
        slideTitle: "Imperfekt aktiv",
        tense: "Imperfekt",
        voice: "Aktiv",
        forms: [
          "ἐδίδουν",
          "ἐδίδους",
          "ἐδίδου",
          "ἐδίδομεν",
          "ἐδίδοτε",
          "ἐδίδοσαν",
        ],
      ),
      MiVerbTable(
        slideTitle: "Imperfekt passiv",
        tense: "Imperfekt",
        voice: "Medium/Passiv",
        forms: [
          "ἐδιδόμην",
          "ἐδίδοσο",
          "ἐδίδοτο",
          "ἐδιδόμεθα",
          "ἐδίδοσθε",
          "ἐδίδοντο",
        ],
      ),
      MiVerbTable(
        slideTitle: "Aorist aktiv",
        tense: "Aorist",
        voice: "Aktiv",
        forms: ["ἔδωκα", "ἔδωκας", "ἔδωκεν", "ἔδομεν", "ἔδοτε", "ἔδοσαν"],
        infinitive: "δοῦναι",
      ),
      MiVerbTable(
        slideTitle: "Aorist medium",
        tense: "Aorist",
        voice: "Medium",
        forms: ["ἐδόμην", "ἔδου", "ἔδοτο", "ἐδόμεθα", "ἔδοσθε", "ἔδοντο"],
        infinitive: "δόσθαι",
      ),
      MiVerbTable(
        slideTitle: "Aorist passiv",
        tense: "Aorist",
        voice: "Passiv",
        forms: ["ἐδόθην", "ἐδόθης", "ἐδόθη", "ἐδόθημεν", "ἐδόθητε", "ἐδόθησαν"],
        infinitive: "δοθῆναι",
      ),
    ],
    participles: [
      MiVerbParticiple(
        tense: "Präsens",
        nominative: ["διδούς", "διδοῦσα", "διδόν"],
        genitive: ["διδόντος", "διδούσης", "διδόντος"],
      ),
      MiVerbParticiple(
        tense: "Aorist",
        nominative: ["δούς", "δοῦσα", "δόν"],
        genitive: ["δόντος", "δούσης", "δόντος"],
      ),
    ],
  );

  static const MiVerb tithemi = MiVerb(
    lemma: "τίθημι",
    meaning: "setzen, stellen, legen",
    presentStem: "τιθη- / τιθε-",
    reduplication: "τιθ",
    aoristStem: "θη- / θε-",
    tables: [
      MiVerbTable(
        slideTitle: "Präsens aktiv",
        tense: "Präsens",
        voice: "Aktiv",
        forms: [
          "τίθημι",
          "τίθης",
          "τίθησι(ν)",
          "τίθεμεν",
          "τίθετε",
          "τιθέασι(ν)",
        ],
        infinitive: "τιθέναι",
      ),
      MiVerbTable(
        slideTitle: "Präsens passiv",
        tense: "Präsens",
        voice: "Medium/Passiv",
        forms: [
          "τίθεμαι",
          "τίθεσαι",
          "τίθεται",
          "τιθέμεθα",
          "τίθεσθε",
          "τίθενται",
        ],
        infinitive: "τίθεσθαι",
      ),
      MiVerbTable(
        slideTitle: "Imperfekt aktiv",
        tense: "Imperfekt",
        voice: "Aktiv",
        forms: [
          "ἐτίθην",
          "ἐτίθεις",
          "ἐτίθει",
          "ἐτίθεμεν",
          "ἐτίθετε",
          "ἐτίθεσαν",
        ],
      ),
      MiVerbTable(
        slideTitle: "Imperfekt passiv",
        tense: "Imperfekt",
        voice: "Medium/Passiv",
        forms: [
          "ἐτιθέμην",
          "ἐτίθεσο",
          "ἐτίθετο",
          "ἐτιθέμεθα",
          "ἐτίθεσθε",
          "ἐτίθεντο",
        ],
      ),
      MiVerbTable(
        slideTitle: "Aorist aktiv",
        tense: "Aorist",
        voice: "Aktiv",
        forms: ["ἔθηκα", "ἔθηκας", "ἔθηκεν", "ἔθεμεν", "ἔθετε", "ἔθεσαν"],
        infinitive: "θεῖναι",
      ),
      MiVerbTable(
        slideTitle: "Aorist medium",
        tense: "Aorist",
        voice: "Medium",
        forms: ["ἐθέμην", "ἔθου", "ἔθετο", "ἐθέμεθα", "ἔθεσθε", "ἔθεντο"],
        infinitive: "θέσθαι",
      ),
      MiVerbTable(
        slideTitle: "Aorist passiv",
        tense: "Aorist",
        voice: "Passiv",
        forms: ["ἐτέθην", "ἐτέθης", "ἐτέθη", "ἐτέθημεν", "ἐτέθητε", "ἐτέθησαν"],
        infinitive: "τεθῆναι",
      ),
    ],
    participles: [
      MiVerbParticiple(
        tense: "Präsens",
        nominative: ["τιθείς", "τιθεῖσα", "τιθέν"],
        genitive: ["τιθέντος", "τιθείσης", "τιθέντος"],
      ),
      MiVerbParticiple(
        tense: "Aorist",
        nominative: ["θείς", "θεῖσα", "θέν"],
        genitive: ["θέντος", "θείσης", "θέντος"],
      ),
    ],
  );

  static const MiVerb hiemi = MiVerb(
    lemma: "ἵημι",
    meaning: "senden, schicken",
    presentStem: "ἱη- / ἱε-",
    reduplication: "ι",
    aoristStem: "ἡ- / ἑ-",
    tables: [
      MiVerbTable(
        slideTitle: "Präsens aktiv",
        tense: "Präsens",
        voice: "Aktiv",
        forms: ["ἵημι", "ἵης", "ἵησι(ν)", "ἵεμεν", "ἵετε", "ἱᾶσι(ν)"],
        infinitive: "ἱέναι",
      ),
      MiVerbTable(
        slideTitle: "Präsens passiv",
        tense: "Präsens",
        voice: "Medium/Passiv",
        forms: ["ἵεμαι", "ἵεσαι", "ἵεται", "ἱέμεθα", "ἵεσθε", "ἵενται"],
        infinitive: "ἵεσθαι",
      ),
      MiVerbTable(
        slideTitle: "Imperfekt aktiv",
        tense: "Imperfekt",
        voice: "Aktiv",
        forms: ["ἵειν", "ἵεις", "ἵει", "ἵεμεν", "ἵετε", "ἵεσαν"],
      ),
      MiVerbTable(
        slideTitle: "Imperfekt passiv",
        tense: "Imperfekt",
        voice: "Medium/Passiv",
        forms: ["ἱέμην", "ἵεσο", "ἵετο", "ἱέμεθα", "ἵεσθε", "ἵεντο"],
      ),
      MiVerbTable(
        slideTitle: "Aorist aktiv",
        tense: "Aorist",
        voice: "Aktiv",
        forms: ["ἧκα", "ἧκας", "ἧκεν", "εἷμεν", "εἷτε", "εἷσαν"],
        infinitive: "εἷναι",
      ),
      MiVerbTable(
        slideTitle: "Aorist medium",
        tense: "Aorist",
        voice: "Medium",
        forms: ["εἵμην", "εἷσο", "εἷτο", "εἵμεθα", "εἷσθε", "εἷντο"],
        infinitive: "ἕσθαι",
      ),
      MiVerbTable(
        slideTitle: "Aorist passiv",
        tense: "Aorist",
        voice: "Passiv",
        forms: ["εἵθην", "εἵθης", "εἵθη", "εἵθημεν", "εἵθητε", "εἵθησαν"],
        infinitive: "ἑθῆναι",
      ),
    ],
    participles: [
      MiVerbParticiple(
        tense: "Präsens",
        nominative: ["ἱείς", "ἱεῖσα", "ἱέν"],
        genitive: ["ἱέντος", "ἱείσης", "ἱέντος"],
      ),
      MiVerbParticiple(
        tense: "Aorist",
        nominative: ["εἵς", "εἷσα", "ἕν"],
        genitive: ["ἕντος", "εἵσης", "ἕντος"],
      ),
    ],
  );

  static const MiVerb histemi = MiVerb(
    lemma: "ἵστημι",
    meaning: "stellen",
    presentStem: "ἱστη- / ἱστα-",
    reduplication: "ιστ",
    aoristStem: "στη- / στα-",
    tables: [
      MiVerbTable(
        slideTitle: "Präsens aktiv",
        tense: "Präsens",
        voice: "Aktiv",
        forms: [
          "ἵστημι",
          "ἵστης",
          "ἵστησι(ν)",
          "ἵσταμεν",
          "ἵστατε",
          "ἵστασι(ν)",
        ],
        infinitive: "ἱστάναι",
      ),
      MiVerbTable(
        slideTitle: "Präsens passiv",
        tense: "Präsens",
        voice: "Medium/Passiv",
        forms: [
          "ἵσταμαι",
          "ἵστασαι",
          "ἵσταται",
          "ἱστάμεθα",
          "ἵστασθε",
          "ἵστανται",
        ],
        infinitive: "ἵστασθαι",
      ),
      MiVerbTable(
        slideTitle: "Imperfekt aktiv",
        tense: "Imperfekt",
        voice: "Aktiv",
        forms: ["ἵστην", "ἵστης", "ἵστη", "ἵσταμεν", "ἵστατε", "ἵστασαν"],
      ),
      MiVerbTable(
        slideTitle: "Imperfekt passiv",
        tense: "Imperfekt",
        voice: "Medium/Passiv",
        forms: [
          "ἱστάμην",
          "ἵστασο",
          "ἵστατο",
          "ἱστάμεθα",
          "ἵστασθε",
          "ἵσταντο",
        ],
      ),
      MiVerbTable(
        slideTitle: "Aorist aktiv",
        tense: "Aorist",
        voice: "Aktiv",
        forms: [
          "ἔστησα",
          "ἔστησας",
          "ἔστησεν",
          "ἐστήσαμεν",
          "ἐστήσατε",
          "ἔστησαν",
        ],
        infinitive: "στῆσαι",
        kind: "σ-Aorist ἔστησα, transitiv („ich stellte“)",
        note:
            "3. Pl.: Die Folie hat ἔστασαν; die Form des σ-Aorists ist "
            "ἔστησαν (berichtigt).",
      ),
      MiVerbTable(
        slideTitle: "Aorist medium",
        tense: "Aorist",
        voice: "Aktiv",
        forms: ["ἔστην", "ἔστης", "ἔστη", "ἔστημεν", "ἔστητε", "ἔστησαν"],
        infinitive: "στῆναι",
        kind: "Wurzelaorist ἔστην, intransitiv („ich trat hin, stand“)",
        rootAorist: true,
        note:
            "Die Folie setzt ἔστην mit „(!)“ in die Spalte „Aorist "
            "medium“: Der Form nach ist es Aktiv – der intransitive "
            "Wurzelaorist („ich trat hin“). Im Trainer gilt er als Aorist "
            "Aktiv. Das eigentliche Aorist Medium (ἐστησάμην) steht nicht "
            "auf der Folie.",
      ),
      MiVerbTable(
        slideTitle: "Aorist passiv",
        tense: "Aorist",
        voice: "Passiv",
        forms: [
          "ἐστάθην",
          "ἐστάθης",
          "ἐστάθη",
          "ἐστάθημεν",
          "ἐστάθητε",
          "ἐστάθησαν",
        ],
        infinitive: "σταθῆναι",
      ),
    ],
    participles: [
      MiVerbParticiple(
        tense: "Präsens",
        nominative: ["ἱστάς", "ἱστᾶσα", "ἱστάν"],
        genitive: ["ἱστάντος", "ἱστάσης", "ἱστάντος"],
      ),
      MiVerbParticiple(
        tense: "Aorist",
        nominative: ["στήσας", "στήσασα", "στῆσαν"],
        genitive: ["στήσαντος", "στησάσης", "στήσαντος"],
        kind: "zum σ-Aorist ἔστησα",
      ),
    ],
  );

  /// Die vier Verben in der Reihenfolge der Folie.
  static const List<MiVerb> verbs = [didomi, tithemi, hiemi, histemi];

  static List<String> get lemmas => [for (final verb in verbs) verb.lemma];

  static MiVerb? byLemma(String lemma) {
    for (final verb in verbs) {
      if (verb.lemma == lemma) return verb;
    }

    return null;
  }

  /// Ob das Verb auf der Folie steht.
  static bool covers(String lemma) => byLemma(lemma) != null;

  /// Verben, die nicht in der Vokabelliste stehen und vom Backend nicht
  /// geladen werden: Der Trainer kennt von ihnen nur die Folie.
  static bool slideOnly(String lemma) {
    return lemma == hiemi.lemma || lemma == histemi.lemma;
  }

  /// Modi, in denen der Trainer Formen des Verbs hat: die der Folie,
  /// bei δίδωμι und τίθημι zusätzlich der Imperativ aus dem Backend.
  static const List<String> slideMoods = [
    VerbMood.indicative,
    VerbMood.infinitive,
    VerbMood.participle,
  ];

  static const List<String> slideTenses = ["Präsens", "Imperfekt", "Aorist"];

  // ---------------------------------------------------------------------------
  // FORMEN DES TRAINERS
  // ---------------------------------------------------------------------------

  /// Alle Formen der Folie als Formen des Trainers.
  static List<VerbForm> formsOf(MiVerb verb) {
    final forms = <VerbForm>[];

    for (final table in verb.tables) {
      for (var i = 0; i < table.forms.length; i++) {
        forms.add((
          form: table.forms[i],
          analysis: (
            mood: VerbMood.indicative,
            tense: table.tense,
            voice: table.voice,
            person: persons[i].$1,
            number: persons[i].$2,
            grammaticalCase: null,
            gender: null,
          ),
        ));
      }

      final infinitive = table.infinitive;

      if (infinitive != null) {
        forms.add((
          form: infinitive,
          analysis: (
            mood: VerbMood.infinitive,
            tense: table.tense,
            voice: table.voice,
            person: null,
            number: null,
            grammaticalCase: null,
            gender: null,
          ),
        ));
      }
    }

    for (final participle in verb.participles) {
      for (final cell in participleCells(participle)) {
        forms.add((
          form: cell.form,
          analysis: (
            mood: VerbMood.participle,
            tense: participle.tense,
            voice: "Aktiv",
            person: null,
            number: cell.number,
            grammaticalCase: cell.grammaticalCase,
            gender: cell.gender,
          ),
        ));
      }
    }

    return forms;
  }

  /// Die Formen eines Partizips: vollständig dekliniert, wenn die
  /// Deklination Nominativ und Genitiv der Folie genau trifft, sonst nur die
  /// Formen der Folie (Nominativ, Genitiv und der Akkusativ Sg. n, der dem
  /// Nominativ gleicht).
  static List<DeclinedForm> participleCells(MiVerbParticiple participle) {
    final declension = participleDeclension(participle);

    if (declension != null) {
      return declension.forms;
    }

    return [
      for (var g = 0; g < declensionGenders.length; g++) ...[
        (
          grammaticalCase: "Nominativ",
          number: "Sg",
          gender: declensionGenders[g],
          form: participle.nominative[g],
        ),
        (
          grammaticalCase: "Genitiv",
          number: "Sg",
          gender: declensionGenders[g],
          form: participle.genitive[g],
        ),
      ],
      (
        grammaticalCase: "Akkusativ",
        number: "Sg",
        gender: "n",
        form: participle.nominative[2],
      ),
    ];
  }

  /// Die vollständige Deklination, soweit sie sich an der Folie bestätigen
  /// lässt; `null` sonst.
  static DeclensionParadigm? participleDeclension(MiVerbParticiple participle) {
    final declension = declineParticiple(
      masculine: participle.nominative[0],
      feminine: participle.nominative[1],
      neuter: participle.nominative[2],
    );

    if (declension == null) {
      return null;
    }

    for (var g = 0; g < declensionGenders.length; g++) {
      final gender = declensionGenders[g];

      if (declension.form("Nominativ", "Sg", gender) !=
              participle.nominative[g] ||
          declension.form("Genitiv", "Sg", gender) != participle.genitive[g]) {
        return null;
      }
    }

    return declension;
  }

  /// Das Paradigma des Verbs: die Formen der Folie, dazu aus [backend] alle
  /// Formen, zu denen die Folie nichts sagt (Imperativ, Partizipien Medium
  /// und Passiv). Wo die Folie eine Tabelle hat (Modus, Tempus, Genus
  /// Verbi), ersetzt sie die des Backends ganz (ἐτίθην statt ἐτίθουν,
  /// ἔδωκα statt einer leeren Zelle). Andere Verben bleiben unverändert.
  static VerbParadigm extend(String lemma, VerbParadigm? backend) {
    final verb = byLemma(lemma);

    if (verb == null) {
      return backend ?? const VerbParadigm([]);
    }

    final slide = formsOf(verb);

    final covered = {
      for (final form in slide)
        (form.analysis.mood, form.analysis.tense, form.analysis.voice),
    };

    return VerbParadigm([
      for (final form in backend?.forms ?? const <VerbForm>[])
        if (!covered.contains((
          form.analysis.mood,
          form.analysis.tense,
          form.analysis.voice,
        )))
          form,
      ...slide,
    ]);
  }

  /// Die Tabelle, zu der die Form [form] mit der Bestimmung [analysis]
  /// gehört (bei ἵστημι trennt sie ἔστησα und ἔστην); `null` außerhalb der
  /// Folie.
  static MiVerbTable? tableOf(
    String lemma,
    String form,
    VerbAnalysis analysis,
  ) {
    final verb = byLemma(lemma);

    if (verb == null || analysis.mood == VerbMood.participle) {
      return null;
    }

    for (final table in verb.tables) {
      if (table.tense != analysis.tense || table.voice != analysis.voice) {
        continue;
      }

      if (table.forms.contains(form) || table.infinitive == form) {
        return table;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // ERKLÄRUNGEN
  // ---------------------------------------------------------------------------

  /// Kennzeichen der μι-Verben nach den Tabellen der Folie.
  static const List<String> features = [
    "Athematisch: Die Endungen treten ohne Themavokal an den Stamm "
        "(δίδω-μι, δίδο-μεν; Ind. Präsens Aktiv -μι, -ς, -σι(ν), -μεν, -τε, "
        "-ασι(ν)).",
    "Präsensreduplikation mit ι: δι-δω-μι, τι-θη-μι, ἵ-η-μι (aus *ἱ-ἑ-), "
        "ἵ-στη-μι (aus *σι-στη-). Sie gehört nur zu Präsens und Imperfekt.",
    "Ablaut: im Sg. Aktiv langer Stammvokal (δίδω-μι, τίθη-μι, ἵστη-μι), "
        "im Plural und im Medium/Passiv kurzer (δίδο-μεν, τίθε-μαι, "
        "ἵστα-μαι).",
    "Imperfekt: Augment vor der Reduplikation (ἐ-δίδουν, ἐ-τίθην); bei "
        "ἵημι und ἵστημι zeigt sich das Augment nur in der Länge des ι "
        "(ἵειν, ἵστην).",
    "Aorist Aktiv ohne Reduplikation: im Sg. mit κ (ἔδωκα, ἔθηκα, ἧκα), "
        "im Plural und im Medium ohne κ (ἔδομεν, ἐδόμην, ἐθέμην).",
    "ἵστημι hat zwei Aoriste: ἔστησα (σ-Aorist, transitiv: „ich stellte“) "
        "und ἔστην (Wurzelaorist, intransitiv: „ich trat hin, stand“).",
    "Aorist Passiv: kurzer Stamm + θη + Endungen (ἐ-δό-θην, ἐ-στά-θην); "
        "bei τίθημι ἐ-τέ-θην (θ vor θ wird τ).",
  ];

  /// Kurze Begründungen zu einer falsch bestimmten Form eines μι-Verbs der
  /// Folie – für die Rückmeldung im Grammatiktrainer. Leer bei anderen
  /// Verben und wenn nur Kasus, Numerus oder Genus verfehlt wurden.
  static List<String> explain({
    required String lemma,
    required String form,
    required VerbAnalysis analysis,
    String? userTense,
    String? userVoice,
    String? userPersonNumber,
  }) {
    final verb = byLemma(lemma);

    if (verb == null) {
      return const [];
    }

    final hints = <String>[];
    final table = tableOf(lemma, form, analysis);

    if (userTense != null && userTense != analysis.tense) {
      hints.add(switch (analysis.tense) {
        "Präsens" =>
          "Präsens: Präsensstamm mit Reduplikation (${verb.presentStem}), "
              "kein Augment.",
        "Imperfekt" =>
          "Imperfekt: Präsensstamm mit Reduplikation (${verb.presentStem}) "
              "und Augment.",
        "Aorist" =>
          "Aorist: Stamm ohne Präsensreduplikation (${verb.aoristStem})"
              "${analysis.voice == "Passiv" ? " + θη" : ""}.",
        _ => "Tempus: ${analysis.tense}.",
      });
    }

    if (table != null &&
        table.rootAorist &&
        userVoice != null &&
        userVoice != analysis.voice) {
      hints.add(
        "$form gehört zum Wurzelaorist ἔστην: aktive Form, intransitive "
        "Bedeutung („trat hin, stand“). Die Folie führt ihn mit „(!)“ in "
        "der Spalte „Aorist medium“.",
      );
    } else if (userVoice != null &&
        userVoice != analysis.voice &&
        analysis.tense == "Aorist" &&
        analysis.voice == "Passiv") {
      hints.add("Aorist Passiv: Kennzeichen θη (ἐδόθην, ἐτέθην, ἐστάθην).");
    }

    final person = "${analysis.person}. ${analysis.number}.";

    if (userPersonNumber != null &&
        analysis.person != null &&
        userPersonNumber != person &&
        analysis.voice == "Aktiv" &&
        analysis.tense == "Präsens") {
      hints.add(
        "Ablaut: im Sg. Aktiv langer Stammvokal (δίδω-μι), im Plural kurzer "
        "(δίδο-μεν); Endungen -μι, -ς, -σι(ν), -μεν, -τε, -ασι(ν).",
      );
    }

    return hints;
  }
}

/// Ein Verb der Folie.
class MiVerb {
  final String lemma;

  /// Bedeutung wie auf der Folie.
  final String meaning;

  /// Präsensstamm in Lang- und Kurzform ("διδω- / διδο-").
  final String presentStem;

  /// Reduplikationssilbe ohne Zeichen, zum Erkennen in Eingaben ("διδ").
  final String reduplication;

  /// Aoriststamm ohne Reduplikation ("δω- / δο-").
  final String aoristStem;

  /// Die Tabellen in der Reihenfolge der Folie: Präsens aktiv, Präsens
  /// passiv, Imperfekt aktiv, Imperfekt passiv, Aorist aktiv, Aorist
  /// medium, Aorist passiv.
  final List<MiVerbTable> tables;

  /// Partizip Präsens und Partizip Aorist (Aktiv).
  final List<MiVerbParticiple> participles;

  const MiVerb({
    required this.lemma,
    required this.meaning,
    required this.presentStem,
    required this.reduplication,
    required this.aoristStem,
    required this.tables,
    required this.participles,
  });

  /// Die Tabelle der Folie mit dem Titel [slideTitle].
  MiVerbTable table(String slideTitle) {
    return tables.firstWhere((table) => table.slideTitle == slideTitle);
  }
}

/// Eine Spalte einer Tabelle der Folie: sechs Formen (1.–3. Sg., 1.–3. Pl.)
/// und, wo die Folie ihn nennt, der Infinitiv.
class MiVerbTable {
  /// Überschrift der Folie ("Aorist medium").
  final String slideTitle;

  final String tense;

  /// Genus Verbi im Trainer: "Aktiv", "Medium/Passiv" (Folie: „passiv“ im
  /// Präsens und Imperfekt, formgleich mit dem Medium), "Medium", "Passiv".
  final String voice;

  final List<String> forms;
  final String? infinitive;

  /// Art des Aorists, wo ein Verb zwei hat ("σ-Aorist ἔστησα, transitiv").
  final String? kind;

  /// Der Wurzelaorist ἔστην (Folie: Spalte „Aorist medium“ mit „(!)“).
  final bool rootAorist;

  /// Abweichung von der Folie, als Ergänzung angezeigt.
  final String? note;

  const MiVerbTable({
    required this.slideTitle,
    required this.tense,
    required this.voice,
    required this.forms,
    this.infinitive,
    this.kind,
    this.rootAorist = false,
    this.note,
  });
}

/// Ein Partizip der Folie: Nominativ und Genitiv Sg. in m, f, n.
class MiVerbParticiple {
  final String tense;
  final List<String> nominative;
  final List<String> genitive;

  /// Zugehöriger Aorist, wo ein Verb zwei hat.
  final String? kind;

  const MiVerbParticiple({
    required this.tense,
    required this.nominative,
    required this.genitive,
    this.kind,
  });
}

/// Formen, die sich höchstens im beweglichen ν unterscheiden, gelten als
/// gleich (δίδωσι = δίδωσι(ν) = δίδωσιν).
String miVerbComparable(String form) {
  return normalizeGreekForComparison(
    form.replaceAll("(ν)", ""),
  ).replaceAll(RegExp(r'ν$'), "");
}
