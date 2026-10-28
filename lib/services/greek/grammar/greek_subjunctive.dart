import '../../../utils/greek_accents.dart';
import '../../../utils/greek_normalization.dart';
import 'verb_paradigm.dart';

/// Konjunktiv (ὑποτακτική) nach der Folie „Sprachkurs Griechisch 2 –
/// Konjunktiv“ (Kiel).
///
/// Die Folie behandelt den Konjunktiv Präsens (Aktiv, Medium/Passiv), den
/// Konjunktiv Aorist (Aktiv, Medium, Passiv) an παύω, den starken Aorist an
/// ἔλθω und den Konjunktiv von εἰμί. Diese Paradigmen stehen hier
/// wörtlich ([pauo], [strongAorist], [eimi]) und gehen jeder Regel vor.
///
/// Für die Verben der Vokabelliste bildet [conjugate] die Formen genau nach
/// diesen Paradigmen:
///   * Präsens: Präsensstamm der Grundform + Endungen mit langem
///     Themavokal (παύ-ω-μεν, παύ-η-ται). Nur unkontrahierte Verben auf -ω
///     und -ομαι; die Kontrakta (ποιῶμεν) behandelt die Folie nicht als
///     Paradigma.
///   * Aorist: Aoriststamm ohne Augment, abgelesen am Infinitiv Aorist des
///     Trainers (παῦσαι → παύσ-ω, ἐλθεῖν → ἔλθ-ω, παύσασθαι → παύσ-ωμαι,
///     παυθῆναι → παυθ-ῶ). Wurzelaoriste (βῆναι, γνῶναι) und Stämme ohne
///     Vokal (σχεῖν) bleiben ohne Konjunktiv – dort weicht die Bildung vom
///     Folienparadigma ab.
///
/// Der Akzent ist zurückgezogen: Er steht auf der letzten Stammsilbe, nur
/// in der 1. Pl. Medium auf der Endung (παυώμεθα); im Aorist Passiv tragen
/// die Endungen den Zirkumflex (παυθῶ).
class GreekSubjunctive {
  GreekSubjunctive._();

  static const String mood = VerbMood.subjunctive;

  /// Zeitformen des Konjunktivs auf der Folie.
  static const List<String> tenses = ["Präsens", "Aorist"];

  // ---------------------------------------------------------------------------
  // PARADIGMEN DER FOLIE
  // ---------------------------------------------------------------------------

  /// παύω: Konjunktiv Präsens und Aorist, je Tempus und Genus Verbi
  /// (1.–3. Sg., 1.–3. Pl.).
  static const Map<String, Map<String, List<String>>> pauo = {
    "Präsens": {
      "Aktiv": ["παύω", "παύῃς", "παύῃ", "παύωμεν", "παύητε", "παύωσι(ν)"],
      "Medium/Passiv": [
        "παύωμαι",
        "παύῃ",
        "παύηται",
        "παυώμεθα",
        "παύησθε",
        "παύωνται",
      ],
    },
    "Aorist": {
      "Aktiv": [
        "παύσω",
        "παύσῃς",
        "παύσῃ",
        "παύσωμεν",
        "παύσητε",
        "παύσωσι(ν)",
      ],
      "Medium": [
        "παύσωμαι",
        "παύσῃ",
        "παύσηται",
        "παυσώμεθα",
        "παύσησθε",
        "παύσωνται",
      ],
      "Passiv": [
        "παυθῶ",
        "παυθῇς",
        "παυθῇ",
        "παυθῶμεν",
        "παυθῆτε",
        "παυθῶσι(ν)",
      ],
    },
  };

  /// Konjunktiv des starken Aorists (ἔρχομαι, Aorist ἦλθον).
  static const List<String> strongAorist = [
    "ἔλθω",
    "ἔλθῃς",
    "ἔλθῃ",
    "ἔλθωμεν",
    "ἔλθητε",
    "ἔλθωσι(ν)",
  ];

  /// Konjunktiv von εἰμί.
  static const List<String> eimi = ["ὦ", "ᾖς", "ᾖ", "ὦμεν", "ἦτε", "ὦσι(ν)"];

  /// Endungen samt langem Themavokal. Aktiv und Aorist Passiv haben
  /// dieselben Endungen; im Aorist Passiv tragen sie den Akzent.
  static const List<String> activeEndings = [
    "ω",
    "ῃς",
    "ῃ",
    "ωμεν",
    "ητε",
    "ωσι(ν)",
  ];

  static const List<String> middleEndings = [
    "ωμαι",
    "ῃ",
    "ηται",
    "ωμεθα",
    "ησθε",
    "ωνται",
  ];

  static const List<String> passiveEndings = [
    "ῶ",
    "ῇς",
    "ῇ",
    "ῶμεν",
    "ῆτε",
    "ῶσι(ν)",
  ];

  /// Person und Numerus der sechs Formen in der Schreibweise des Trainers.
  static const List<(int, String)> persons = [
    (1, "Sg"),
    (2, "Sg"),
    (3, "Sg"),
    (1, "Pl"),
    (2, "Pl"),
    (3, "Pl"),
  ];

  // ---------------------------------------------------------------------------
  // BILDUNG
  // ---------------------------------------------------------------------------

  /// Verben, deren Aorist keinen Konjunktiv nach dem Folienparadigma hat:
  /// Wurzelaoriste (ἔβην → βῶ, ἔγνων → γνῶ) und ἔσχον (σχῶ).
  static const Set<String> _noAoristSubjunctive = {
    "βαίνω",
    "ἀναβαίνω",
    "καταβαίνω",
    "ἐμβαίνω",
    "γιγνώσκω",
    "ἔχω",
    "περιέχω",
  };

  /// Verben auf -μι (τίθημι, δίδωμι, ἀπόλλυμι, δύναμαι): Ihr Konjunktiv
  /// behandelt die Folie nicht. εἰμί steht als eigenes Paradigma da.
  static bool _athematic(String lemma) {
    return lemma.endsWith("μι") ||
        (lemma.endsWith("μαι") && !lemma.endsWith("ομαι"));
  }

  /// Ob der Trainer den Konjunktiv des Verbs im Tempus [tense] bilden kann
  /// – ohne das Paradigma zu laden. Der Aorist hängt zusätzlich an den
  /// Infinitiven des Paradigmas ([conjugate]).
  static bool supports(String lemma, String tense) {
    if (lemma == "παύω") {
      return tenses.contains(tense);
    }

    if (lemma == "εἰμί") {
      return tense == "Präsens";
    }

    // Nur Verben auf -ω und -ομαι (nicht οἶδα, nicht die -μι-Verben).
    if (_athematic(lemma) ||
        lemma.contains(" ") ||
        !(lemma.endsWith("ω") || lemma.endsWith("ομαι"))) {
      return false;
    }

    return switch (tense) {
      "Präsens" =>
        presentForms(lemma, "Aktiv") != null ||
            presentForms(lemma, "Medium/Passiv") != null,
      "Aorist" => !_noAoristSubjunctive.contains(lemma),
      _ => false,
    };
  }

  /// Konjunktivformen eines Verbs je Tempus und Genus Verbi ("Aktiv",
  /// "Medium/Passiv", "Medium", "Passiv"). Präsens aus der Grundform, Aorist
  /// aus den Infinitiven Aorist in [paradigm]; welche Genera Verbi es gibt,
  /// richtet sich nach dem Indikativ Präsens bzw. den Infinitiven Aorist des
  /// Paradigmas. Die Paradigmen der Folie (παύω, ἔλθω, εἰμί) gelten
  /// unverändert.
  static Map<String, Map<String, List<String>>> conjugate(
    String lemma,
    VerbParadigm paradigm,
  ) {
    if (lemma == "παύω") {
      return pauo;
    }

    if (lemma == "εἰμί") {
      return {
        "Präsens": {"Aktiv": eimi},
      };
    }

    if (_athematic(lemma)) {
      return const {};
    }

    final result = <String, Map<String, List<String>>>{};

    final presentVoices = {
      for (final form in paradigm.forms)
        if (form.analysis.tense == "Präsens" &&
            form.analysis.mood == VerbMood.indicative)
          form.analysis.voice,
    };

    final present = <String, List<String>>{};

    for (final voice in const ["Aktiv", "Medium/Passiv"]) {
      if (!presentVoices.contains(voice)) continue;

      final forms = presentForms(lemma, voice);

      if (forms != null) {
        present[voice] = forms;
      }
    }

    if (present.isNotEmpty) {
      result["Präsens"] = present;
    }

    final aorist = <String, List<String>>{};

    for (final form in supports(lemma, "Aorist") ? paradigm.forms : const []) {
      final analysis = form.analysis;

      if (analysis.tense != "Aorist" ||
          analysis.mood != VerbMood.infinitive ||
          aorist.containsKey(analysis.voice)) {
        continue;
      }

      final forms = aoristFromInfinitive(form.form, analysis.voice);

      if (forms != null) {
        aorist[analysis.voice] = forms;
      }
    }

    // ἔρχομαι: der starke Aorist der Folie.
    if (lemma == "ἔρχομαι") {
      aorist["Aktiv"] = strongAorist;
    }

    if (aorist.isNotEmpty) {
      result["Aorist"] = aorist;
    }

    return result;
  }

  /// Konjunktiv Präsens aus der Grundform: unkontrahierte Verben auf -ω
  /// (Aktiv und Medium/Passiv) und auf -ομαι (Medium/Passiv). `null` bei
  /// Kontrakta, Verben auf -μι und allem, was die Folie nicht abdeckt.
  static List<String>? presentForms(String lemma, String voice) {
    if (lemma.contains(" ") || _contracted(lemma)) {
      return null;
    }

    final String stem;

    if (lemma.endsWith("ομαι")) {
      if (voice != "Medium/Passiv") {
        return null;
      }

      stem = lemma.substring(0, lemma.length - 4);
    } else if (lemma.endsWith("ω")) {
      stem = lemma.substring(0, lemma.length - 1);
    } else {
      return null;
    }

    if (!hasGreekAccent(stem)) {
      return null;
    }

    return voice == "Aktiv" ? _active(stem) : _middle(stem);
  }

  static bool _contracted(String lemma) {
    final plain = normalizeGreekForComparison(lemma);

    return const [
      "εω",
      "αω",
      "οω",
      "εομαι",
      "αομαι",
      "οομαι",
    ].any(plain.endsWith);
  }

  /// Konjunktiv Aorist aus dem Infinitiv Aorist ([voice] wie im Trainer:
  /// "Aktiv", "Medium", "Passiv"):
  ///   * Aktiv -αι (σ-Aorist, auch ψ/ξ und Liquida: παῦσαι, μεῖναι) oder
  ///     -εῖν (starker Aorist: ἐλθεῖν),
  ///   * Medium -ασθαι (παύσασθαι) oder -έσθαι (γενέσθαι),
  ///   * Passiv -ῆναι (παυθῆναι, γραφῆναι).
  /// `null`, wenn der Infinitiv nicht in dieses Schema passt.
  static List<String>? aoristFromInfinitive(String infinitive, String voice) {
    switch (voice) {
      case "Aktiv":
        if (infinitive.endsWith("εῖν")) {
          return _accented(
            infinitive.substring(0, infinitive.length - 3),
            _active,
          );
        }

        // Wurzelaoriste (βῆναι, γνῶναι, δῦναι) und -μι-Verben (θεῖναι,
        // δοῦναι) bilden den Konjunktiv anders.
        if (infinitive.endsWith("σθαι") ||
            infinitive.endsWith("ῆναι") ||
            infinitive.endsWith("ῶναι") ||
            infinitive.endsWith("ῦναι") ||
            !infinitive.endsWith("αι")) {
          return null;
        }

        return _accented(
          infinitive.substring(0, infinitive.length - 2),
          _active,
        );

      case "Medium":
        if (infinitive.endsWith("έσθαι")) {
          return _accented(
            infinitive.substring(0, infinitive.length - 5),
            _middle,
          );
        }

        if (infinitive.endsWith("ασθαι")) {
          return _accented(
            infinitive.substring(0, infinitive.length - 5),
            _middle,
          );
        }

        return null;

      case "Passiv":
        if (!infinitive.endsWith("ῆναι")) {
          return null;
        }

        final stem = stripGreekAccent(
          infinitive.substring(0, infinitive.length - 4),
        );

        return [for (final ending in passiveEndings) "$stem$ending"];

      default:
        return null;
    }
  }

  // Setzt den Akut auf den letzten Vokal des Stammes (bei Diphthongen auf
  // den zweiten Bestandteil: παυσ- → παύσ-) und hängt die Endungen an.
  static List<String>? _accented(
    String stem,
    List<String> Function(String) endings,
  ) {
    final accented = withAcuteOnLastVowel(stripGreekAccent(stem));

    return accented == null ? null : endings(accented);
  }

  static List<String> _active(String stem) {
    return [for (final ending in activeEndings) "$stem$ending"];
  }

  // 1. Pl.: Der Akzent rückt auf die Endung (παυώμεθα).
  static List<String> _middle(String stem) {
    final plain = stripGreekAccent(stem);

    return [
      for (final ending in middleEndings)
        ending == "ωμεθα" ? "$plainώμεθα" : "$stem$ending",
    ];
  }

  /// [stem] mit Akut auf dem letzten Vokal; `null`, wenn der Stamm keinen
  /// Vokal hat (σχ-) oder der Vokal keinen Akut tragen kann.
  static String? withAcuteOnLastVowel(String stem) {
    final runes = stem.runes.toList();

    for (var i = runes.length - 1; i >= 0; i--) {
      final plain = normalizeGreekForComparison(String.fromCharCode(runes[i]));

      if (plain.isEmpty || !"αεηιουω".contains(plain)) continue;

      final accented = _acuteOf(runes[i]);

      if (accented == null) {
        return null;
      }

      runes[i] = accented;

      return String.fromCharCodes(runes);
    }

    return null;
  }

  static const Map<int, int> _acute = {
    0x03B1: 0x03AC, // α → ά
    0x03B5: 0x03AD, // ε → έ
    0x03B7: 0x03AE, // η → ή
    0x03B9: 0x03AF, // ι → ί
    0x03BF: 0x03CC, // ο → ό
    0x03C5: 0x03CD, // υ → ύ
    0x03C9: 0x03CE, // ω → ώ
  };

  // Vokale mit Spiritus: Im Achterblock folgt der Akut vier Stellen nach
  // Lenis bzw. Asper (ἐ → ἔ, εἰ → εἴ).
  static int? _acuteOf(int rune) {
    if (rune >= 0x1F00 && rune <= 0x1F6F) {
      return (rune & 0x7) <= 1 ? rune + 4 : null;
    }

    return _acute[rune];
  }

  // ---------------------------------------------------------------------------
  // FORMEN DES TRAINERS
  // ---------------------------------------------------------------------------

  /// Die Konjunktivformen als Formen des Trainers.
  static List<VerbForm> formsOf(String lemma, VerbParadigm paradigm) {
    return [
      for (final MapEntry(key: tense, value: voices) in conjugate(
        lemma,
        paradigm,
      ).entries)
        for (final MapEntry(key: voice, value: forms) in voices.entries)
          for (var i = 0; i < forms.length; i++)
            (
              form: forms[i],
              analysis: (
                mood: mood,
                tense: tense,
                voice: voice,
                person: persons[i].$1,
                number: persons[i].$2,
                grammaticalCase: null,
                gender: null,
              ),
            ),
    ];
  }

  /// [paradigm] samt den Konjunktivformen des Verbs.
  static VerbParadigm extend(String lemma, VerbParadigm paradigm) {
    final subjunctive = formsOf(lemma, paradigm);

    if (subjunctive.isEmpty) {
      return paradigm;
    }

    return VerbParadigm([
      for (final form in paradigm.forms)
        if (form.analysis.mood != mood) form,
      ...subjunctive,
    ]);
  }

  // ---------------------------------------------------------------------------
  // ERKLÄRUNGEN
  // ---------------------------------------------------------------------------

  /// Endungen eines Genus Verbi im Konjunktiv.
  static List<String> endingsOf(String tense, String voice) {
    if (tense == "Aorist" && voice == "Passiv") {
      return passiveEndings;
    }

    return voice == "Aktiv" ? activeEndings : middleEndings;
  }

  /// Kurze Begründung, warum [form] mit der Bestimmung [analysis] im
  /// Konjunktiv steht bzw. nicht steht – für die Rückmeldung nach einer
  /// falschen Antwort. [userMood], [userTense], [userVoice] und
  /// [userPersonNumber] ("2. Sg.") wie ausgewählt; [paradigm] liefert die
  /// Vergleichsform im anderen Modus. Leer, wenn der Konjunktiv bei dieser
  /// Antwort keine Rolle spielt.
  static List<String> explain({
    required String form,
    required VerbAnalysis analysis,
    required VerbParadigm? paradigm,
    String? userMood,
    String? userTense,
    String? userVoice,
    String? userPersonNumber,
  }) {
    final hints = <String>[];

    if (analysis.mood == mood) {
      if (userMood != null && userMood != mood) {
        hints.add(
          "$form ist Konjunktiv: Kennzeichen ist der lange Themavokal ω/η "
          "statt ο/ε (Ind. παύομεν → Konj. παύωμεν), in der 2./3. Sg. Aktiv "
          "ῃ statt ει (παύεις → παύῃς).",
        );

        final indicative = _counterpart(
          paradigm,
          analysis,
          VerbMood.indicative,
        );

        if (indicative != null && indicative != form) {
          hints.add("Der Indikativ lautete: $indicative.");
        }
      }

      if (userTense != null && userTense != analysis.tense) {
        hints.add(
          analysis.tense == "Aorist"
              ? "Aoriststamm, aber ohne Augment – der Konjunktiv hat nie "
                    "ein Augment: σ-Aorist παύσ-ω, starker Aorist ἔλθ-ω, "
                    "Aorist Passiv παυθ-ῶ."
              : "Präsensstamm ohne σ oder θ (παύ-ω, παύ-ωμαι); den "
                    "Konjunktiv gibt es nur im Präsens und Aorist.",
        );
      }

      if (userVoice != null &&
          !(userVoice == analysis.voice ||
              (analysis.voice == "Medium/Passiv" &&
                  (userVoice == "Medium" || userVoice == "Passiv")))) {
        hints.add(switch ((analysis.tense, analysis.voice)) {
          ("Aorist", "Passiv") =>
            "Aorist Passiv: θ-Stamm + aktive Endungen mit Zirkumflex "
                "(παυθῶ, παυθῇς, παυθῶμεν).",
          ("Aorist", "Medium") =>
            "Aorist Medium: σ-Stamm + mediale Endungen (παύσωμαι, "
                "παύσηται, παυσώμεθα).",
          (_, "Medium/Passiv") =>
            "Mediale Endungen (-ωμαι, -ῃ, -ηται …); im Präsens sind Medium "
                "und Passiv formgleich.",
          _ => "Aktive Endungen (-ω, -ῃς, -ῃ, -ωμεν, -ητε, -ωσι(ν)).",
        });
      }

      final person = "${analysis.person}. ${analysis.number}.";

      if (userPersonNumber != null &&
          userPersonNumber != person &&
          analysis.person != null) {
        final index = persons.indexOf((analysis.person!, analysis.number!));
        final ending = endingsOf(analysis.tense, analysis.voice)[index];

        hints.add("Endung -$ending = $person");
      }

      return hints;
    }

    // Für einen Konjunktiv gehalten, ist aber keiner.
    if (userMood == mood && analysis.mood == VerbMood.indicative) {
      final subjunctive = _counterpart(paradigm, analysis, mood);

      hints.add(
        "$form ist kein Konjunktiv: Der Indikativ hat den kurzen "
        "Themavokal ο/ε bzw. ει (παύομεν, παύεις) und in den "
        "Vergangenheitstempora das Augment.",
      );

      if (subjunctive != null) {
        hints.add("Der Konjunktiv lautete: $subjunctive.");
      }
    }

    return hints;
  }

  // Dieselbe Bestimmung im Modus [wanted] (Aorist Passiv im Indikativ gibt
  // es nur bei Deponentien im Trainer, im Paradigma aber immer).
  static String? _counterpart(
    VerbParadigm? paradigm,
    VerbAnalysis analysis,
    String wanted,
  ) {
    if (paradigm == null) {
      return null;
    }

    for (final candidate in paradigm.forms) {
      final other = candidate.analysis;

      if (other.mood == wanted &&
          other.tense == analysis.tense &&
          other.voice == analysis.voice &&
          other.person == analysis.person &&
          other.number == analysis.number) {
        return candidate.form;
      }
    }

    return null;
  }
}
