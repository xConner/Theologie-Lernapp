/// Lateinische Formenlehre: erzeugt die Paradigmen von Substantiven,
/// Adjektiven, Pronomen und Verben, die Grammatikübersicht und
/// Grammatiktrainer gemeinsam verwenden.
///
/// Die Formen werden regelhaft aus Grundform, Genitiv bzw. Stammformen
/// gebildet; unregelmäßige Verben (esse, posse, īre, velle) und die Pronomen
/// sind als Tabellen hinterlegt. Längen werden mit Längenzeichen (ā, ē, ī, ō,
/// ū) geschrieben, wie in der Vokabelliste. Kurze Vokale vor auslautendem -t,
/// -nt, -m, -r und vor -ntur sind berücksichtigt (amat, amant, amer).
///
/// Mehrere Formen einer Zelle sind gleichwertige Nebenformen (amāris –
/// amāre); die erste ist die Hauptform, die im Trainer vorgelegt wird.
library;

// ---------------------------------------------------------------------------
// BESTIMMUNGEN
// ---------------------------------------------------------------------------

class LatinCases {
  LatinCases._();

  static const String nominative = "Nominativ";
  static const String genitive = "Genitiv";
  static const String dative = "Dativ";
  static const String accusative = "Akkusativ";
  static const String ablative = "Ablativ";
  static const String vocative = "Vokativ";

  static const List<String> all = [
    nominative,
    genitive,
    dative,
    accusative,
    ablative,
    vocative,
  ];

  /// Ohne Vokativ (Pronomen haben keinen eigenen Vokativ).
  static const List<String> withoutVocative = [
    nominative,
    genitive,
    dative,
    accusative,
    ablative,
  ];

  static const Map<String, String> short = {
    nominative: "Nom.",
    genitive: "Gen.",
    dative: "Dat.",
    accusative: "Akk.",
    ablative: "Abl.",
    vocative: "Vok.",
  };
}

class LatinNumbers {
  LatinNumbers._();

  static const String singular = "Singular";
  static const String plural = "Plural";

  static const List<String> all = [singular, plural];

  static const Map<String, String> short = {singular: "Sg.", plural: "Pl."};
}

class LatinGenders {
  LatinGenders._();

  static const String masculine = "Maskulinum";
  static const String feminine = "Femininum";
  static const String neuter = "Neutrum";

  static const List<String> all = [masculine, feminine, neuter];

  /// Kürzel der Vokabelliste (m, f, n) → Genus.
  static String fromCode(String code) {
    switch (code) {
      case "m":
        return masculine;
      case "f":
        return feminine;
      case "n":
        return neuter;
    }

    throw ArgumentError("Unbekanntes Genus: $code");
  }

  static const Map<String, String> short = {
    masculine: "m.",
    feminine: "f.",
    neuter: "n.",
  };
}

class LatinMoods {
  LatinMoods._();

  static const String indicative = "Indikativ";
  static const String subjunctive = "Konjunktiv";
  static const String imperative = "Imperativ";
  static const String infinitive = "Infinitiv";

  static const List<String> all = [
    indicative,
    subjunctive,
    imperative,
    infinitive,
  ];
}

class LatinTenses {
  LatinTenses._();

  static const String present = "Präsens";
  static const String imperfect = "Imperfekt";
  static const String future = "Futur I";
  static const String perfect = "Perfekt";
  static const String pluperfect = "Plusquamperfekt";
  static const String futurePerfect = "Futur II";

  static const List<String> all = [
    present,
    imperfect,
    future,
    perfect,
    pluperfect,
    futurePerfect,
  ];
}

class LatinVoices {
  LatinVoices._();

  static const String active = "Aktiv";
  static const String passive = "Passiv";

  static const List<String> all = [active, passive];
}

class LatinPersons {
  LatinPersons._();

  static const List<String> all = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  static const List<String> imperative = ["2. Sg.", "2. Pl."];
}

/// Bestimmung einer nominalen Form. [gender] ist null bei Wörtern ohne
/// Genusunterscheidung in der Form (Personalpronomen).
class NominalAnalysis {
  final String grammaticalCase;
  final String number;
  final String? gender;

  const NominalAnalysis(this.grammaticalCase, this.number, [this.gender]);

  @override
  bool operator ==(Object other) =>
      other is NominalAnalysis &&
      other.grammaticalCase == grammaticalCase &&
      other.number == number &&
      other.gender == gender;

  @override
  int get hashCode => Object.hash(grammaticalCase, number, gender);

  String describe() {
    return [grammaticalCase, number, ?gender].join(" ");
  }

  @override
  String toString() => describe();
}

/// Bestimmung einer Verbform. [person] ist beim Infinitiv null.
class VerbAnalysis {
  final String mood;
  final String tense;
  final String voice;
  final String? person;

  const VerbAnalysis(this.mood, this.tense, this.voice, [this.person]);

  @override
  bool operator ==(Object other) =>
      other is VerbAnalysis &&
      other.mood == mood &&
      other.tense == tense &&
      other.voice == voice &&
      other.person == person;

  @override
  int get hashCode => Object.hash(mood, tense, voice, person);

  /// „3. Sg. Imperfekt Indikativ Aktiv“ bzw. „Infinitiv Präsens Passiv“.
  String describe() {
    if (person == null) {
      return "$mood $tense $voice";
    }

    if (mood == LatinMoods.imperative) {
      return "$person $mood $voice";
    }

    return "$person $tense $mood $voice";
  }

  @override
  String toString() => describe();
}

/// Ein vollständiges Paradigma: Bestimmung → Formen (erste = Hauptform).
class Paradigm<A> {
  final Map<A, List<String>> cells;

  const Paradigm(this.cells);

  List<String> formsOf(A analysis) => cells[analysis] ?? const [];

  String? mainForm(A analysis) {
    final forms = formsOf(analysis);
    return forms.isEmpty ? null : forms.first;
  }

  /// Alle Bestimmungen, zu denen [form] (exakt, mit Längenzeichen) gehört –
  /// auch als Nebenform.
  List<A> analysesOf(String form) {
    return [
      for (final entry in cells.entries)
        if (entry.value.contains(form)) entry.key,
    ];
  }

  Iterable<String> get allForms => cells.values.expand((forms) => forms);
}

// ---------------------------------------------------------------------------
// SUBSTANTIVE
// ---------------------------------------------------------------------------

enum LatinDeclension {
  a("a-Deklination"),
  o("o-Deklination"),
  third("3. Deklination"),
  u("u-Deklination"),
  e("e-Deklination");

  final String label;

  const LatinDeclension(this.label);
}

class LatinNoun {
  /// Stabile Kennung im Grammatiktrainer (Lernstand je Wort).
  final String id;
  final String lemma;
  final String genitive;

  /// m, f oder n
  final String genderCode;
  final LatinDeclension declension;

  /// 3. Deklination: Genitiv Plural auf -ium (Mischdeklination: urbs).
  final bool iStem;

  final List<String> translations;

  /// ID in der Vokabelliste, falls das Wort aus dem Lehrbuchwortschatz
  /// stammt; sonst ein Beispielwort der Grammatik.
  final int? vocabularyId;

  const LatinNoun({
    required this.id,
    required this.lemma,
    required this.genitive,
    required this.genderCode,
    required this.declension,
    this.iStem = false,
    required this.translations,
    this.vocabularyId,
  });

  String get gender => LatinGenders.fromCode(genderCode);

  bool get isNeuter => genderCode == "n";

  /// „dominus, dominī m.“
  String get dictionaryForm => "$lemma, $genitive $genderCode.";

  String get stem {
    String cut(String ending) {
      if (!genitive.endsWith(ending)) {
        throw StateError("$lemma: Genitiv $genitive endet nicht auf -$ending");
      }
      return genitive.substring(0, genitive.length - ending.length);
    }

    switch (declension) {
      case LatinDeclension.a:
        return cut("ae");
      case LatinDeclension.o:
        return cut("ī");
      case LatinDeclension.third:
        return cut("is");
      case LatinDeclension.u:
        return cut("ūs");
      case LatinDeclension.e:
        return genitive.endsWith("ēī") ? cut("ēī") : cut("eī");
    }
  }

  Paradigm<NominalAnalysis> paradigm() {
    final forms = nounForms(
      lemma: lemma,
      stem: stem,
      declension: declension,
      neuter: isNeuter,
      iStem: iStem,
    );

    return Paradigm({
      for (final entry in forms.entries)
        NominalAnalysis(entry.key.$1, entry.key.$2): entry.value,
    });
  }
}

/// Kasus und Numerus einer Tabellenzelle.
typedef CaseNumber = (String, String);

const String _sg = LatinNumbers.singular;
const String _pl = LatinNumbers.plural;

Map<CaseNumber, List<String>> _caseTable(
  List<String> singular,
  List<String> plural,
) {
  return {
    for (var i = 0; i < LatinCases.all.length; i++) ...{
      (LatinCases.all[i], _sg): [singular[i]],
      (LatinCases.all[i], _pl): [plural[i]],
    },
  };
}

/// Formen eines Substantivs (bzw. einer Genusreihe eines Adjektivs).
Map<CaseNumber, List<String>> nounForms({
  required String lemma,
  required String stem,
  required LatinDeclension declension,
  required bool neuter,
  bool iStem = false,
  bool adjectiveIStem = false,
}) {
  final s = stem;

  switch (declension) {
    case LatinDeclension.a:
      return _caseTable(
        [lemma, "${s}ae", "${s}ae", "${s}am", "$sā", lemma],
        ["${s}ae", "$sārum", "$sīs", "$sās", "$sīs", "${s}ae"],
      );

    case LatinDeclension.o:
      if (neuter) {
        return _caseTable(
          [lemma, "$sī", "$sō", lemma, "$sō", lemma],
          ["${s}a", "$sōrum", "$sīs", "${s}a", "$sīs", "${s}a"],
        );
      }

      final String vocative;

      if (lemma.endsWith("ius")) {
        // fīlius → fīlī
        vocative = "${lemma.substring(0, lemma.length - 3)}ī";
      } else if (lemma.endsWith("us")) {
        vocative = "${s}e";
      } else {
        // puer, ager: Vokativ = Nominativ
        vocative = lemma;
      }

      return _caseTable(
        [lemma, "$sī", "$sō", "${s}um", "$sō", vocative],
        ["$sī", "$sōrum", "$sīs", "$sōs", "$sīs", "$sī"],
      );

    case LatinDeclension.third:
      // Adjektive der 3. Deklination: Ablativ Singular -ī, Neutrum Plural
      // -ia, Genitiv Plural -ium.
      final ablSg = adjectiveIStem ? "$sī" : "${s}e";
      final genPl = iStem || adjectiveIStem ? "${s}ium" : "${s}um";

      if (neuter) {
        final nomPl = iStem || adjectiveIStem ? "${s}ia" : "${s}a";

        return _caseTable(
          [lemma, "${s}is", "$sī", lemma, ablSg, lemma],
          [nomPl, genPl, "${s}ibus", nomPl, "${s}ibus", nomPl],
        );
      }

      return _caseTable(
        [lemma, "${s}is", "$sī", "${s}em", ablSg, lemma],
        ["$sēs", genPl, "${s}ibus", "$sēs", "${s}ibus", "$sēs"],
      );

    case LatinDeclension.u:
      return _caseTable(
        [lemma, "$sūs", "${s}uī", "${s}um", "$sū", lemma],
        ["$sūs", "${s}uum", "${s}ibus", "$sūs", "${s}ibus", "$sūs"],
      );

    case LatinDeclension.e:
      // Nach Vokal Genitiv/Dativ auf -ēī (diēī), sonst -eī (reī).
      final afterVowel = RegExp(r"[aeiouāēīōū]$").hasMatch(s);
      final genDat = afterVowel ? "$sēī" : "${s}eī";

      return _caseTable(
        [lemma, genDat, genDat, "${s}em", "$sē", lemma],
        ["$sēs", "$sērum", "$sēbus", "$sēs", "$sēbus", "$sēs"],
      );
  }
}

// ---------------------------------------------------------------------------
// ADJEKTIVE
// ---------------------------------------------------------------------------

enum LatinAdjectiveClass {
  /// bonus, bona, bonum; līber, lībera, līberum; pulcher, pulchra, pulchrum
  ao,

  /// fortis, forte (zweiendig, 3. Deklination)
  thirdTwoEndings,

  /// fēlīx, Gen. fēlīcis (einendig, 3. Deklination)
  thirdOneEnding,
}

class LatinAdjective {
  final String id;

  /// Maskulinum Nominativ Singular
  final String lemma;

  /// a/o: Femininum und Neutrum („bona“, „bonum“); zweiendig: Neutrum
  /// („forte“); einendig: Genitiv („fēlīcis“).
  final String feminine;
  final String neuter;
  final String? genitive;

  final LatinAdjectiveClass adjectiveClass;
  final List<String> translations;
  final int? vocabularyId;

  const LatinAdjective({
    required this.id,
    required this.lemma,
    this.feminine = "",
    this.neuter = "",
    this.genitive,
    required this.adjectiveClass,
    required this.translations,
    this.vocabularyId,
  });

  /// „bonus, -a, -um“ bzw. „fortis, forte“ / „fēlīx, Gen. fēlīcis“.
  String get dictionaryForm {
    switch (adjectiveClass) {
      case LatinAdjectiveClass.ao:
        return "$lemma, $feminine, $neuter";
      case LatinAdjectiveClass.thirdTwoEndings:
        return "$lemma, $neuter";
      case LatinAdjectiveClass.thirdOneEnding:
        return "$lemma, Gen. $genitive";
    }
  }

  Paradigm<NominalAnalysis> paradigm() {
    final cells = <NominalAnalysis, List<String>>{};

    void add(String gender, Map<CaseNumber, List<String>> forms) {
      for (final entry in forms.entries) {
        cells[NominalAnalysis(entry.key.$1, entry.key.$2, gender)] =
            entry.value;
      }
    }

    switch (adjectiveClass) {
      case LatinAdjectiveClass.ao:
        // Stamm aus dem Femininum: bona → bon-, lībera → līber-,
        // pulchra → pulchr-.
        final stem = feminine.substring(0, feminine.length - 1);

        add(
          LatinGenders.masculine,
          nounForms(
            lemma: lemma,
            stem: stem,
            declension: LatinDeclension.o,
            neuter: false,
          ),
        );
        add(
          LatinGenders.feminine,
          nounForms(
            lemma: feminine,
            stem: stem,
            declension: LatinDeclension.a,
            neuter: false,
          ),
        );
        add(
          LatinGenders.neuter,
          nounForms(
            lemma: neuter,
            stem: stem,
            declension: LatinDeclension.o,
            neuter: true,
          ),
        );

      case LatinAdjectiveClass.thirdTwoEndings:
        final stem = lemma.substring(0, lemma.length - 2); // fortis → fort

        for (final gender in [LatinGenders.masculine, LatinGenders.feminine]) {
          add(
            gender,
            nounForms(
              lemma: lemma,
              stem: stem,
              declension: LatinDeclension.third,
              neuter: false,
              adjectiveIStem: true,
            ),
          );
        }
        add(
          LatinGenders.neuter,
          nounForms(
            lemma: neuter,
            stem: stem,
            declension: LatinDeclension.third,
            neuter: true,
            adjectiveIStem: true,
          ),
        );

      case LatinAdjectiveClass.thirdOneEnding:
        final stem = genitive!.substring(0, genitive!.length - 2);

        for (final gender in [LatinGenders.masculine, LatinGenders.feminine]) {
          add(
            gender,
            nounForms(
              lemma: lemma,
              stem: stem,
              declension: LatinDeclension.third,
              neuter: false,
              adjectiveIStem: true,
            ),
          );
        }
        add(
          LatinGenders.neuter,
          nounForms(
            lemma: lemma,
            stem: stem,
            declension: LatinDeclension.third,
            neuter: true,
            adjectiveIStem: true,
          ),
        );
    }

    return Paradigm(cells);
  }
}

// ---------------------------------------------------------------------------
// PRONOMEN
// ---------------------------------------------------------------------------

class LatinPronoun {
  final String id;

  /// Überschrift, z. B. „is, ea, id“
  final String label;

  /// Art, z. B. „Demonstrativpronomen“
  final String kind;

  /// Ob die Formen nach Genus unterschieden werden (nicht bei ego, tū …).
  final bool hasGender;

  final List<String> translations;

  /// Kasus → Singular- bzw. Pluralformen; bei [hasGender] je Genus
  /// (Maskulinum, Femininum, Neutrum), sonst eine Spalte. Nebenformen mit
  /// „/“ getrennt; „–“ = keine Form.
  final Map<String, List<String>> singular;
  final Map<String, List<String>> plural;

  const LatinPronoun({
    required this.id,
    required this.label,
    required this.kind,
    required this.hasGender,
    required this.translations,
    required this.singular,
    required this.plural,
  });

  Paradigm<NominalAnalysis> paradigm() {
    final cells = <NominalAnalysis, List<String>>{};

    void add(String number, Map<String, List<String>> table) {
      for (final entry in table.entries) {
        for (var i = 0; i < entry.value.length; i++) {
          final raw = entry.value[i];

          if (raw == "–") continue;

          final gender = hasGender ? LatinGenders.all[i] : null;

          cells[NominalAnalysis(entry.key, number, gender)] = raw.split("/");
        }
      }
    }

    add(_sg, singular);
    add(_pl, plural);

    return Paradigm(cells);
  }
}

// ---------------------------------------------------------------------------
// VERBEN
// ---------------------------------------------------------------------------

enum LatinConjugation {
  a("a-Konjugation"),
  e("e-Konjugation"),
  i("i-Konjugation"),
  consonant("konsonantische Konjugation"),
  mixed("konsonantische Konjugation mit i-Erweiterung"),
  irregular("unregelmäßiges Verb");

  final String label;

  const LatinConjugation(this.label);
}

class LatinVerb {
  final String id;

  /// Infinitiv Präsens Aktiv
  final String infinitive;

  /// 1. Sg. Präsens
  final String present;

  /// 1. Sg. Perfekt; null, wenn das Perfekt nicht trainiert wird
  /// (Semideponentien wie gaudēre: gāvīsus sum).
  final String? perfect;

  /// PPP bzw. Supinum (Stammform), nur zur Anzeige.
  final String? supine;

  final LatinConjugation conjugation;

  /// Bildet das Verb ein persönliches Passiv?
  final bool hasPassive;

  /// Abweichender Imperativ Singular (dūc, dīc, fac).
  final String? imperativeSingular;

  final List<String> translations;
  final int? vocabularyId;

  const LatinVerb({
    required this.id,
    required this.infinitive,
    required this.present,
    this.perfect,
    this.supine,
    required this.conjugation,
    this.hasPassive = true,
    this.imperativeSingular,
    required this.translations,
    this.vocabularyId,
  });

  /// „amāre, amō, amāvī, amātum“
  String get principalParts {
    return [infinitive, present, ?perfect, ?supine].join(", ");
  }

  bool get hasPerfect => perfect != null;

  /// Präsensstamm ohne Kennvokal: amāre → am, monēre → mon, audīre → aud,
  /// mittere → mitt, capere → cap.
  String get _root => infinitive.substring(0, infinitive.length - 3);

  /// Perfektstamm: amāvī → amāv.
  String? get perfectStem => perfect?.substring(0, perfect!.length - 1);

  Paradigm<VerbAnalysis> paradigm() {
    if (conjugation == LatinConjugation.irregular) {
      return _irregularParadigm(this);
    }

    final cells = <VerbAnalysis, List<String>>{};

    _addPresentSystem(cells);

    final perfectStem = this.perfectStem;

    if (perfectStem != null) {
      _addPerfectForms(cells, perfectStem);
    }

    return Paradigm(cells);
  }

  void _addPresentSystem(Map<VerbAnalysis, List<String>> cells) {
    final r = _root;
    final c = conjugation;
    final table = _presentEndings[c]!;

    void add(
      String mood,
      String tense,
      String voice,
      List<String> endings, {
      String? base,
    }) {
      for (var i = 0; i < 6; i++) {
        cells[VerbAnalysis(mood, tense, voice, LatinPersons.all[i])] = [
          for (final ending in endings[i].split("/")) "${base ?? r}$ending",
        ];
      }
    }

    add(
      LatinMoods.indicative,
      LatinTenses.present,
      LatinVoices.active,
      table.presentActive,
    );
    add(
      LatinMoods.indicative,
      LatinTenses.imperfect,
      LatinVoices.active,
      _imperfectActive,
      base: "$r${table.imperfectVowel}",
    );
    add(
      LatinMoods.indicative,
      LatinTenses.future,
      LatinVoices.active,
      table.futureActive,
    );
    add(
      LatinMoods.subjunctive,
      LatinTenses.present,
      LatinVoices.active,
      table.subjunctiveActive,
    );

    // Konjunktiv Imperfekt: Infinitiv ohne -e + Endungen (amār-em).
    final infinitiveStem = infinitive.substring(0, infinitive.length - 1);

    add(
      LatinMoods.subjunctive,
      LatinTenses.imperfect,
      LatinVoices.active,
      _subjunctiveImperfectActive,
      base: infinitiveStem,
    );

    cells[const VerbAnalysis(
      LatinMoods.imperative,
      LatinTenses.present,
      LatinVoices.active,
      "2. Sg.",
    )] = [
      imperativeSingular ?? "$r${table.imperativeSingular}",
    ];
    cells[const VerbAnalysis(
      LatinMoods.imperative,
      LatinTenses.present,
      LatinVoices.active,
      "2. Pl.",
    )] = [
      "$r${table.imperativePlural}",
    ];

    cells[const VerbAnalysis(
      LatinMoods.infinitive,
      LatinTenses.present,
      LatinVoices.active,
    )] = [
      infinitive,
    ];

    if (!hasPassive) return;

    add(
      LatinMoods.indicative,
      LatinTenses.present,
      LatinVoices.passive,
      table.presentPassive,
    );
    add(
      LatinMoods.indicative,
      LatinTenses.imperfect,
      LatinVoices.passive,
      _imperfectPassive,
      base: "$r${table.imperfectVowel}",
    );
    add(
      LatinMoods.indicative,
      LatinTenses.future,
      LatinVoices.passive,
      table.futurePassive,
    );
    add(
      LatinMoods.subjunctive,
      LatinTenses.present,
      LatinVoices.passive,
      table.subjunctivePassive,
    );
    add(
      LatinMoods.subjunctive,
      LatinTenses.imperfect,
      LatinVoices.passive,
      _subjunctiveImperfectPassive,
      base: infinitiveStem,
    );

    cells[const VerbAnalysis(
      LatinMoods.infinitive,
      LatinTenses.present,
      LatinVoices.passive,
    )] = [
      "$r${table.infinitivePassive}",
    ];
  }
}

/// Perfekt, Plusquamperfekt, Futur II (Indikativ), Konjunktiv Perfekt und
/// Plusquamperfekt sowie Infinitiv Perfekt im Aktiv.
void _addPerfectForms(Map<VerbAnalysis, List<String>> cells, String s) {
  void add(String mood, String tense, List<String> endings) {
    for (var i = 0; i < 6; i++) {
      cells[VerbAnalysis(
        mood,
        tense,
        LatinVoices.active,
        LatinPersons.all[i],
      )] = [
        for (final ending in endings[i].split("/")) "$s$ending",
      ];
    }
  }

  add(LatinMoods.indicative, LatinTenses.perfect, const [
    "ī",
    "istī",
    "it",
    "imus",
    "istis",
    "ērunt/ēre",
  ]);
  add(LatinMoods.indicative, LatinTenses.pluperfect, const [
    "eram",
    "erās",
    "erat",
    "erāmus",
    "erātis",
    "erant",
  ]);
  add(LatinMoods.indicative, LatinTenses.futurePerfect, const [
    "erō",
    "eris",
    "erit",
    "erimus",
    "eritis",
    "erint",
  ]);
  add(LatinMoods.subjunctive, LatinTenses.perfect, const [
    "erim",
    "eris",
    "erit",
    "erimus",
    "eritis",
    "erint",
  ]);
  add(LatinMoods.subjunctive, LatinTenses.pluperfect, const [
    "issem",
    "issēs",
    "isset",
    "issēmus",
    "issētis",
    "issent",
  ]);

  cells[const VerbAnalysis(
    LatinMoods.infinitive,
    LatinTenses.perfect,
    LatinVoices.active,
  )] = [
    "${s}isse",
  ];
}

const List<String> _imperfectActive = [
  "bam",
  "bās",
  "bat",
  "bāmus",
  "bātis",
  "bant",
];

const List<String> _imperfectPassive = [
  "bar",
  "bāris/bāre",
  "bātur",
  "bāmur",
  "bāminī",
  "bantur",
];

const List<String> _subjunctiveImperfectActive = [
  "em",
  "ēs",
  "et",
  "ēmus",
  "ētis",
  "ent",
];

const List<String> _subjunctiveImperfectPassive = [
  "er",
  "ēris/ēre",
  "ētur",
  "ēmur",
  "ēminī",
  "entur",
];

class _PresentEndings {
  final List<String> presentActive;
  final List<String> presentPassive;

  /// Bindevokal vor -ba- im Imperfekt (amā-bam, audiē-bam).
  final String imperfectVowel;
  final List<String> futureActive;
  final List<String> futurePassive;
  final List<String> subjunctiveActive;
  final List<String> subjunctivePassive;
  final String imperativeSingular;
  final String imperativePlural;
  final String infinitivePassive;

  const _PresentEndings({
    required this.presentActive,
    required this.presentPassive,
    required this.imperfectVowel,
    required this.futureActive,
    required this.futurePassive,
    required this.subjunctiveActive,
    required this.subjunctivePassive,
    required this.imperativeSingular,
    required this.imperativePlural,
    required this.infinitivePassive,
  });
}

/// Endungen an den Präsensstamm ohne Kennvokal (am-, mon-, aud-, mitt-,
/// cap-).
const Map<LatinConjugation, _PresentEndings> _presentEndings = {
  LatinConjugation.a: _PresentEndings(
    presentActive: ["ō", "ās", "at", "āmus", "ātis", "ant"],
    presentPassive: ["or", "āris/āre", "ātur", "āmur", "āminī", "antur"],
    imperfectVowel: "ā",
    futureActive: ["ābō", "ābis", "ābit", "ābimus", "ābitis", "ābunt"],
    futurePassive: [
      "ābor",
      "āberis/ābere",
      "ābitur",
      "ābimur",
      "ābiminī",
      "ābuntur",
    ],
    subjunctiveActive: ["em", "ēs", "et", "ēmus", "ētis", "ent"],
    subjunctivePassive: ["er", "ēris/ēre", "ētur", "ēmur", "ēminī", "entur"],
    imperativeSingular: "ā",
    imperativePlural: "āte",
    infinitivePassive: "ārī",
  ),
  LatinConjugation.e: _PresentEndings(
    presentActive: ["eō", "ēs", "et", "ēmus", "ētis", "ent"],
    presentPassive: ["eor", "ēris/ēre", "ētur", "ēmur", "ēminī", "entur"],
    imperfectVowel: "ē",
    futureActive: ["ēbō", "ēbis", "ēbit", "ēbimus", "ēbitis", "ēbunt"],
    futurePassive: [
      "ēbor",
      "ēberis/ēbere",
      "ēbitur",
      "ēbimur",
      "ēbiminī",
      "ēbuntur",
    ],
    subjunctiveActive: ["eam", "eās", "eat", "eāmus", "eātis", "eant"],
    subjunctivePassive: [
      "ear",
      "eāris/eāre",
      "eātur",
      "eāmur",
      "eāminī",
      "eantur",
    ],
    imperativeSingular: "ē",
    imperativePlural: "ēte",
    infinitivePassive: "ērī",
  ),
  LatinConjugation.i: _PresentEndings(
    presentActive: ["iō", "īs", "it", "īmus", "ītis", "iunt"],
    presentPassive: ["ior", "īris/īre", "ītur", "īmur", "īminī", "iuntur"],
    imperfectVowel: "iē",
    futureActive: ["iam", "iēs", "iet", "iēmus", "iētis", "ient"],
    futurePassive: ["iar", "iēris/iēre", "iētur", "iēmur", "iēminī", "ientur"],
    subjunctiveActive: ["iam", "iās", "iat", "iāmus", "iātis", "iant"],
    subjunctivePassive: [
      "iar",
      "iāris/iāre",
      "iātur",
      "iāmur",
      "iāminī",
      "iantur",
    ],
    imperativeSingular: "ī",
    imperativePlural: "īte",
    infinitivePassive: "īrī",
  ),
  LatinConjugation.consonant: _PresentEndings(
    presentActive: ["ō", "is", "it", "imus", "itis", "unt"],
    presentPassive: ["or", "eris/ere", "itur", "imur", "iminī", "untur"],
    imperfectVowel: "ē",
    futureActive: ["am", "ēs", "et", "ēmus", "ētis", "ent"],
    futurePassive: ["ar", "ēris/ēre", "ētur", "ēmur", "ēminī", "entur"],
    subjunctiveActive: ["am", "ās", "at", "āmus", "ātis", "ant"],
    subjunctivePassive: ["ar", "āris/āre", "ātur", "āmur", "āminī", "antur"],
    imperativeSingular: "e",
    imperativePlural: "ite",
    infinitivePassive: "ī",
  ),
  LatinConjugation.mixed: _PresentEndings(
    presentActive: ["iō", "is", "it", "imus", "itis", "iunt"],
    presentPassive: ["ior", "eris/ere", "itur", "imur", "iminī", "iuntur"],
    imperfectVowel: "iē",
    futureActive: ["iam", "iēs", "iet", "iēmus", "iētis", "ient"],
    futurePassive: ["iar", "iēris/iēre", "iētur", "iēmur", "iēminī", "ientur"],
    subjunctiveActive: ["iam", "iās", "iat", "iāmus", "iātis", "iant"],
    subjunctivePassive: [
      "iar",
      "iāris/iāre",
      "iātur",
      "iāmur",
      "iāminī",
      "iantur",
    ],
    imperativeSingular: "e",
    imperativePlural: "ite",
    infinitivePassive: "ī",
  ),
};

// ---------------------------------------------------------------------------
// UNREGELMÄSSIGE VERBEN
// ---------------------------------------------------------------------------

/// Tabellen der unregelmäßigen Verben; Schlüssel ist der Infinitiv ohne
/// Präfix. Formen je Person; Nebenformen mit „/“.
class _IrregularTable {
  final List<String> present;
  final List<String> imperfect;
  final List<String> future;
  final List<String> subjunctivePresent;
  final List<String> subjunctiveImperfect;

  /// Imperativ 2. Sg. und 2. Pl.; null, wenn es keinen gibt (posse, velle).
  final List<String>? imperative;

  /// Abweichende Formen des Perfektsystems (Bestimmung → Formen), die die
  /// regelmäßig gebildeten ersetzen (īre: īstī statt iistī).
  final List<(VerbAnalysis, List<String>)> perfectOverrides;

  const _IrregularTable({
    required this.present,
    required this.imperfect,
    required this.future,
    required this.subjunctivePresent,
    required this.subjunctiveImperfect,
    this.imperative,
    this.perfectOverrides = const [],
  });
}

const Map<String, _IrregularTable> _irregularTables = {
  "esse": _IrregularTable(
    present: ["sum", "es", "est", "sumus", "estis", "sunt"],
    imperfect: ["eram", "erās", "erat", "erāmus", "erātis", "erant"],
    future: ["erō", "eris", "erit", "erimus", "eritis", "erunt"],
    subjunctivePresent: ["sim", "sīs", "sit", "sīmus", "sītis", "sint"],
    subjunctiveImperfect: [
      "essem",
      "essēs",
      "esset",
      "essēmus",
      "essētis",
      "essent",
    ],
    imperative: ["es", "este"],
  ),
  "posse": _IrregularTable(
    present: ["possum", "potes", "potest", "possumus", "potestis", "possunt"],
    imperfect: [
      "poteram",
      "poterās",
      "poterat",
      "poterāmus",
      "poterātis",
      "poterant",
    ],
    future: [
      "poterō",
      "poteris",
      "poterit",
      "poterimus",
      "poteritis",
      "poterunt",
    ],
    subjunctivePresent: [
      "possim",
      "possīs",
      "possit",
      "possīmus",
      "possītis",
      "possint",
    ],
    subjunctiveImperfect: [
      "possem",
      "possēs",
      "posset",
      "possēmus",
      "possētis",
      "possent",
    ],
  ),
  "īre": _IrregularTable(
    present: ["eō", "īs", "it", "īmus", "ītis", "eunt"],
    imperfect: ["ībam", "ībās", "ībat", "ībāmus", "ībātis", "ībant"],
    future: ["ībō", "ībis", "ībit", "ībimus", "ībitis", "ībunt"],
    subjunctivePresent: ["eam", "eās", "eat", "eāmus", "eātis", "eant"],
    subjunctiveImperfect: ["īrem", "īrēs", "īret", "īrēmus", "īrētis", "īrent"],
    imperative: ["ī", "īte"],
    perfectOverrides: [
      (
        VerbAnalysis(
          LatinMoods.indicative,
          LatinTenses.perfect,
          LatinVoices.active,
          "2. Sg.",
        ),
        ["īstī", "iistī"],
      ),
      (
        VerbAnalysis(
          LatinMoods.indicative,
          LatinTenses.perfect,
          LatinVoices.active,
          "2. Pl.",
        ),
        ["īstis", "iistis"],
      ),
      (
        VerbAnalysis(
          LatinMoods.subjunctive,
          LatinTenses.pluperfect,
          LatinVoices.active,
          "1. Sg.",
        ),
        ["īssem", "iissem"],
      ),
      (
        VerbAnalysis(
          LatinMoods.subjunctive,
          LatinTenses.pluperfect,
          LatinVoices.active,
          "2. Sg.",
        ),
        ["īssēs", "iissēs"],
      ),
      (
        VerbAnalysis(
          LatinMoods.subjunctive,
          LatinTenses.pluperfect,
          LatinVoices.active,
          "3. Sg.",
        ),
        ["īsset", "iisset"],
      ),
      (
        VerbAnalysis(
          LatinMoods.subjunctive,
          LatinTenses.pluperfect,
          LatinVoices.active,
          "1. Pl.",
        ),
        ["īssēmus", "iissēmus"],
      ),
      (
        VerbAnalysis(
          LatinMoods.subjunctive,
          LatinTenses.pluperfect,
          LatinVoices.active,
          "2. Pl.",
        ),
        ["īssētis", "iissētis"],
      ),
      (
        VerbAnalysis(
          LatinMoods.subjunctive,
          LatinTenses.pluperfect,
          LatinVoices.active,
          "3. Pl.",
        ),
        ["īssent", "iissent"],
      ),
      (
        VerbAnalysis(
          LatinMoods.infinitive,
          LatinTenses.perfect,
          LatinVoices.active,
        ),
        ["īsse", "iisse"],
      ),
    ],
  ),
  "velle": _IrregularTable(
    present: ["volō", "vīs", "vult", "volumus", "vultis", "volunt"],
    imperfect: [
      "volēbam",
      "volēbās",
      "volēbat",
      "volēbāmus",
      "volēbātis",
      "volēbant",
    ],
    future: ["volam", "volēs", "volet", "volēmus", "volētis", "volent"],
    subjunctivePresent: [
      "velim",
      "velīs",
      "velit",
      "velīmus",
      "velītis",
      "velint",
    ],
    subjunctiveImperfect: [
      "vellem",
      "vellēs",
      "vellet",
      "vellēmus",
      "vellētis",
      "vellent",
    ],
  ),
};

/// Infinitive, deren Formen als Tabelle hinterlegt sind (auch mit Präfix:
/// adesse = ad + esse).
const List<String> irregularInfinitives = ["esse", "posse", "īre", "velle"];

Paradigm<VerbAnalysis> _irregularParadigm(LatinVerb verb) {
  String? base;
  var prefix = "";

  // Grundform am Wortende, davor ein Präfix (ad-esse).
  for (final candidate in irregularInfinitives) {
    if (verb.infinitive.endsWith(candidate)) {
      final rest = verb.infinitive.substring(
        0,
        verb.infinitive.length - candidate.length,
      );

      base = candidate;
      prefix = rest;
      break;
    }
  }

  final table = _irregularTables[base];

  if (table == null) {
    throw StateError("Keine Tabelle für ${verb.infinitive}");
  }

  final cells = <VerbAnalysis, List<String>>{};

  void add(String mood, String tense, List<String> forms) {
    for (var i = 0; i < 6; i++) {
      cells[VerbAnalysis(
        mood,
        tense,
        LatinVoices.active,
        LatinPersons.all[i],
      )] = [
        for (final form in forms[i].split("/")) "$prefix$form",
      ];
    }
  }

  add(LatinMoods.indicative, LatinTenses.present, table.present);
  add(LatinMoods.indicative, LatinTenses.imperfect, table.imperfect);
  add(LatinMoods.indicative, LatinTenses.future, table.future);
  add(LatinMoods.subjunctive, LatinTenses.present, table.subjunctivePresent);
  add(
    LatinMoods.subjunctive,
    LatinTenses.imperfect,
    table.subjunctiveImperfect,
  );

  final imperative = table.imperative;

  if (imperative != null) {
    for (var i = 0; i < 2; i++) {
      cells[VerbAnalysis(
        LatinMoods.imperative,
        LatinTenses.present,
        LatinVoices.active,
        LatinPersons.imperative[i],
      )] = [
        "$prefix${imperative[i]}",
      ];
    }
  }

  cells[const VerbAnalysis(
    LatinMoods.infinitive,
    LatinTenses.present,
    LatinVoices.active,
  )] = [
    verb.infinitive,
  ];

  final perfectStem = verb.perfectStem;

  if (perfectStem != null) {
    _addPerfectForms(cells, perfectStem);

    for (final (analysis, forms) in table.perfectOverrides) {
      cells[analysis] = [for (final form in forms) "$prefix$form"];
    }
  }

  return Paradigm(cells);
}

// ---------------------------------------------------------------------------
// ERKLÄRUNGEN
// ---------------------------------------------------------------------------

/// Kurze Regel zu einer Nominalform, z. B. „o-Deklination, Ablativ Plural:
/// Endung -īs (dominīs).“
String explainNounForm(LatinNoun noun, NominalAnalysis analysis) {
  final form = noun.paradigm().mainForm(analysis) ?? "";
  final ending = _ending(form, noun.stem);

  final buffer = StringBuffer(
    "${noun.declension.label}, ${analysis.grammaticalCase} "
    "${analysis.number}",
  );

  if (ending != null && ending.isNotEmpty) {
    buffer.write(": Endung -$ending");
  } else {
    buffer.write(": Form wie die Grundform");
  }

  buffer.write(" ($form). Stamm aus dem Genitiv: ${noun.genitive} → ");
  buffer.write("${noun.stem}-.");

  if (noun.isNeuter &&
      (analysis.grammaticalCase == LatinCases.nominative ||
          analysis.grammaticalCase == LatinCases.accusative ||
          analysis.grammaticalCase == LatinCases.vocative)) {
    buffer.write(" Neutrum: Nominativ, Akkusativ und Vokativ sind gleich.");
  }

  return buffer.toString();
}

String? _ending(String form, String stem) {
  return form.startsWith(stem) ? form.substring(stem.length) : null;
}

const Map<String, String> _activeEndings = {
  "1. Sg.": "-ō bzw. -m",
  "2. Sg.": "-s",
  "3. Sg.": "-t",
  "1. Pl.": "-mus",
  "2. Pl.": "-tis",
  "3. Pl.": "-nt",
};

const Map<String, String> _passiveEndings = {
  "1. Sg.": "-r",
  "2. Sg.": "-ris (auch -re)",
  "3. Sg.": "-tur",
  "1. Pl.": "-mur",
  "2. Pl.": "-minī",
  "3. Pl.": "-ntur",
};

const Map<String, String> _perfectEndings = {
  "1. Sg.": "-ī",
  "2. Sg.": "-istī",
  "3. Sg.": "-it",
  "1. Pl.": "-imus",
  "2. Pl.": "-istis",
  "3. Pl.": "-ērunt",
};

/// Kurze Regel zu einer Verbform: Stamm, Tempus-/Moduszeichen und
/// Personalendung.
String explainVerbForm(LatinVerb verb, VerbAnalysis analysis) {
  final form = verb.paradigm().mainForm(analysis) ?? "";

  if (verb.conjugation == LatinConjugation.irregular &&
      (analysis.tense == LatinTenses.present ||
          analysis.tense == LatinTenses.imperfect ||
          analysis.tense == LatinTenses.future)) {
    return "${verb.infinitive} ist unregelmäßig: Die Formen des "
        "Präsensstamms werden gelernt ($form).";
  }

  final person = analysis.person;

  if (analysis.mood == LatinMoods.infinitive) {
    switch ((analysis.tense, analysis.voice)) {
      case (LatinTenses.present, LatinVoices.active):
        return "Infinitiv Präsens Aktiv: Präsensstamm + -re ($form).";
      case (LatinTenses.present, LatinVoices.passive):
        return "Infinitiv Präsens Passiv: -rī, in der konsonantischen "
            "Konjugation -ī ($form).";
      default:
        return "Infinitiv Perfekt Aktiv: Perfektstamm + -isse ($form).";
    }
  }

  if (analysis.mood == LatinMoods.imperative) {
    return person == "2. Sg."
        ? "Imperativ Singular: reiner Präsensstamm, in der konsonantischen "
              "Konjugation mit -e ($form)."
        : "Imperativ Plural: Präsensstamm + -te, in der konsonantischen "
              "Konjugation -ite ($form).";
  }

  final personal =
      analysis.tense == LatinTenses.perfect &&
          analysis.mood == LatinMoods.indicative
      ? _perfectEndings[person]
      : analysis.voice == LatinVoices.passive
      ? _passiveEndings[person]
      : _activeEndings[person];

  final String marker;

  switch ((analysis.mood, analysis.tense)) {
    case (LatinMoods.indicative, LatinTenses.present):
      marker = "Präsensstamm ohne Tempuszeichen";
    case (LatinMoods.indicative, LatinTenses.imperfect):
      marker = "Präsensstamm + Tempuszeichen -bā-/-ba-";
    case (LatinMoods.indicative, LatinTenses.future):
      marker =
          verb.conjugation == LatinConjugation.a ||
              verb.conjugation == LatinConjugation.e
          ? "a-/e-Konjugation: Tempuszeichen -b- mit -ō, -i-, -u- "
                "(amā-b-ō, amā-bi-t, amā-bu-nt)"
          : "i- und konsonantische Konjugation: Tempuszeichen -a- (1. Sg.) "
                "bzw. -ē-/-e-";
    case (LatinMoods.subjunctive, LatinTenses.present):
      marker = verb.conjugation == LatinConjugation.a
          ? "a-Konjugation: Moduszeichen -ē-/-e- statt des Kennvokals"
          : "Moduszeichen -ā-/-a-";
    case (LatinMoods.subjunctive, LatinTenses.imperfect):
      marker = "Infinitiv Präsens + Personalendung (Moduszeichen -rē-/-re-)";
    case (LatinMoods.indicative, LatinTenses.perfect):
      marker = "Perfektstamm ${verb.perfectStem}- + Perfektendung";
    case (LatinMoods.indicative, LatinTenses.pluperfect):
      marker = "Perfektstamm + -erā-/-era- (wie das Imperfekt von esse)";
    case (LatinMoods.indicative, LatinTenses.futurePerfect):
      marker =
          "Perfektstamm + -erō/-eri- (wie das Futur von esse, 3. Pl. "
          "-erint)";
    case (LatinMoods.subjunctive, LatinTenses.perfect):
      marker = "Perfektstamm + Moduszeichen -eri-";
    case (LatinMoods.subjunctive, LatinTenses.pluperfect):
      marker = "Perfektstamm + -issē-/-isse- (Infinitiv Perfekt + Endung)";
    default:
      marker = "";
  }

  return "${analysis.tense} ${analysis.mood} ${analysis.voice}: $marker, "
      "Personalendung $personal ($form).";
}
