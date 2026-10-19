import 'latin_morphology.dart';

/// Wörter, Pronomen, Präpositionen und Sätze des Lateinischen
/// Grammatiktrainers und der Grammatikübersicht.
///
/// Wörter mit [LatinNoun.vocabularyId] usw. stammen aus der Vokabelliste
/// (`assets/latin_vocabulary.json`, Lehrbuch prima., Lektionen 1–3); ihre
/// Genitive und Stammformen sind die üblichen Wörterbuchangaben. Die übrigen
/// sind Beispielwörter, mit denen sich Deklinationen und Konjugationen
/// zeigen lassen, die im bisherigen Wortschatz noch nicht vorkommen
/// (z. B. die konsonantische Konjugation). Mit der Einstellung „Nur Wörter
/// aus dem Vokabeltrainer“ fragt der Trainer ausschließlich die ersteren ab.
class LatinGrammarWords {
  LatinGrammarWords._();

  // ---------------------------------------------------------------------------
  // SUBSTANTIVE
  // ---------------------------------------------------------------------------

  static const List<LatinNoun> nouns = [
    // a-Deklination
    LatinNoun(
      id: "domina",
      lemma: "domina",
      genitive: "dominae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Herrin"],
      vocabularyId: 8,
    ),
    LatinNoun(
      id: "serva",
      lemma: "serva",
      genitive: "servae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Sklavin"],
      vocabularyId: 10,
    ),
    LatinNoun(
      id: "victoria",
      lemma: "victōria",
      genitive: "victōriae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Sieg"],
      vocabularyId: 25,
    ),
    LatinNoun(
      id: "amica",
      lemma: "amīca",
      genitive: "amīcae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Freundin"],
      vocabularyId: 44,
    ),
    LatinNoun(
      id: "via",
      lemma: "via",
      genitive: "viae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Weg", "Straße"],
      vocabularyId: 46,
    ),
    LatinNoun(
      id: "taberna",
      lemma: "taberna",
      genitive: "tabernae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Gasthaus", "Laden"],
      vocabularyId: 63,
    ),
    LatinNoun(
      id: "bestia",
      lemma: "bēstia",
      genitive: "bēstiae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Tier"],
      vocabularyId: 68,
    ),
    LatinNoun(
      id: "ecclesia",
      lemma: "ecclēsia",
      genitive: "ecclēsiae",
      genderCode: "f",
      declension: LatinDeclension.a,
      translations: ["Kirche", "Gemeinde"],
    ),

    // o-Deklination
    LatinNoun(
      id: "dominus",
      lemma: "dominus",
      genitive: "dominī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Herr"],
      vocabularyId: 6,
    ),
    LatinNoun(
      id: "servus",
      lemma: "servus",
      genitive: "servī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Sklave"],
      vocabularyId: 9,
    ),
    LatinNoun(
      id: "equus",
      lemma: "equus",
      genitive: "equī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Pferd"],
      vocabularyId: 17,
    ),
    LatinNoun(
      id: "populus",
      lemma: "populus",
      genitive: "populī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Volk"],
      vocabularyId: 22,
    ),
    LatinNoun(
      id: "circus",
      lemma: "circus",
      genitive: "circī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Zirkus", "Rennbahn"],
      vocabularyId: 41,
    ),
    LatinNoun(
      id: "amicus",
      lemma: "amīcus",
      genitive: "amīcī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Freund"],
      vocabularyId: 43,
    ),
    LatinNoun(
      id: "frumentum",
      lemma: "frūmentum",
      genitive: "frūmentī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Getreide"],
      vocabularyId: 29,
    ),
    LatinNoun(
      id: "furtum",
      lemma: "furtum",
      genitive: "furtī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Diebstahl"],
      vocabularyId: 36,
    ),
    LatinNoun(
      id: "forum",
      lemma: "forum",
      genitive: "forī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Forum", "Marktplatz"],
      vocabularyId: 40,
    ),
    LatinNoun(
      id: "aedificium",
      lemma: "aedificium",
      genitive: "aedificiī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Gebäude"],
      vocabularyId: 61,
    ),
    LatinNoun(
      id: "verbum",
      lemma: "verbum",
      genitive: "verbī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Wort"],
      vocabularyId: 77,
    ),
    LatinNoun(
      id: "consilium",
      lemma: "cōnsilium",
      genitive: "cōnsiliī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Beratung", "Beschluss", "Plan", "Rat"],
      vocabularyId: 94,
    ),
    LatinNoun(
      id: "puer",
      lemma: "puer",
      genitive: "puerī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Junge", "Kind"],
    ),
    LatinNoun(
      id: "ager",
      lemma: "ager",
      genitive: "agrī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Acker", "Feld"],
    ),
    LatinNoun(
      id: "filius",
      lemma: "fīlius",
      genitive: "fīliī",
      genderCode: "m",
      declension: LatinDeclension.o,
      translations: ["Sohn"],
    ),
    LatinNoun(
      id: "peccatum",
      lemma: "peccātum",
      genitive: "peccātī",
      genderCode: "n",
      declension: LatinDeclension.o,
      translations: ["Sünde", "Fehler"],
    ),

    // 3. Deklination
    LatinNoun(
      id: "victor",
      lemma: "victor",
      genitive: "victōris",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["Sieger"],
      vocabularyId: 20,
    ),
    LatinNoun(
      id: "clamor",
      lemma: "clāmor",
      genitive: "clāmōris",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["Lärm", "Geschrei"],
      vocabularyId: 24,
    ),
    LatinNoun(
      id: "mercator",
      lemma: "mercātor",
      genitive: "mercātōris",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["Kaufmann", "Händler"],
      vocabularyId: 26,
    ),
    LatinNoun(
      id: "senator",
      lemma: "senātor",
      genitive: "senātōris",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["Senator"],
      vocabularyId: 64,
    ),
    LatinNoun(
      id: "rex",
      lemma: "rēx",
      genitive: "rēgis",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["König"],
    ),
    LatinNoun(
      id: "homo",
      lemma: "homō",
      genitive: "hominis",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["Mensch"],
    ),
    LatinNoun(
      id: "pater",
      lemma: "pater",
      genitive: "patris",
      genderCode: "m",
      declension: LatinDeclension.third,
      translations: ["Vater"],
    ),
    LatinNoun(
      id: "mater",
      lemma: "māter",
      genitive: "mātris",
      genderCode: "f",
      declension: LatinDeclension.third,
      translations: ["Mutter"],
    ),
    LatinNoun(
      id: "nomen",
      lemma: "nōmen",
      genitive: "nōminis",
      genderCode: "n",
      declension: LatinDeclension.third,
      translations: ["Name"],
    ),
    LatinNoun(
      id: "corpus",
      lemma: "corpus",
      genitive: "corporis",
      genderCode: "n",
      declension: LatinDeclension.third,
      translations: ["Körper", "Leib"],
    ),
    LatinNoun(
      id: "urbs",
      lemma: "urbs",
      genitive: "urbis",
      genderCode: "f",
      declension: LatinDeclension.third,
      iStem: true,
      translations: ["Stadt"],
    ),

    // u- und e-Deklination
    LatinNoun(
      id: "senatus",
      lemma: "senātus",
      genitive: "senātūs",
      genderCode: "m",
      declension: LatinDeclension.u,
      translations: ["Senat"],
    ),
    LatinNoun(
      id: "manus",
      lemma: "manus",
      genitive: "manūs",
      genderCode: "f",
      declension: LatinDeclension.u,
      translations: ["Hand", "Schar"],
    ),
    LatinNoun(
      id: "res",
      lemma: "rēs",
      genitive: "reī",
      genderCode: "f",
      declension: LatinDeclension.e,
      translations: ["Sache", "Ding", "Angelegenheit"],
    ),
    LatinNoun(
      id: "dies",
      lemma: "diēs",
      genitive: "diēī",
      genderCode: "m",
      declension: LatinDeclension.e,
      translations: ["Tag"],
    ),
  ];

  // ---------------------------------------------------------------------------
  // ADJEKTIVE
  // ---------------------------------------------------------------------------

  /// Im Wortschatz der Lektionen 1–3 kommen noch keine Adjektive vor; alle
  /// sind Beispielwörter.
  static const List<LatinAdjective> adjectives = [
    LatinAdjective(
      id: "bonus",
      lemma: "bonus",
      feminine: "bona",
      neuter: "bonum",
      adjectiveClass: LatinAdjectiveClass.ao,
      translations: ["gut"],
    ),
    LatinAdjective(
      id: "magnus",
      lemma: "magnus",
      feminine: "magna",
      neuter: "magnum",
      adjectiveClass: LatinAdjectiveClass.ao,
      translations: ["groß"],
    ),
    LatinAdjective(
      id: "laetus",
      lemma: "laetus",
      feminine: "laeta",
      neuter: "laetum",
      adjectiveClass: LatinAdjectiveClass.ao,
      translations: ["froh", "fröhlich"],
    ),
    LatinAdjective(
      id: "sanctus",
      lemma: "sānctus",
      feminine: "sāncta",
      neuter: "sānctum",
      adjectiveClass: LatinAdjectiveClass.ao,
      translations: ["heilig"],
    ),
    LatinAdjective(
      id: "miser",
      lemma: "miser",
      feminine: "misera",
      neuter: "miserum",
      adjectiveClass: LatinAdjectiveClass.ao,
      translations: ["elend", "unglücklich"],
    ),
    LatinAdjective(
      id: "pulcher",
      lemma: "pulcher",
      feminine: "pulchra",
      neuter: "pulchrum",
      adjectiveClass: LatinAdjectiveClass.ao,
      translations: ["schön"],
    ),
    LatinAdjective(
      id: "fortis",
      lemma: "fortis",
      neuter: "forte",
      adjectiveClass: LatinAdjectiveClass.thirdTwoEndings,
      translations: ["tapfer", "stark"],
    ),
    LatinAdjective(
      id: "omnis",
      lemma: "omnis",
      neuter: "omne",
      adjectiveClass: LatinAdjectiveClass.thirdTwoEndings,
      translations: ["jeder", "ganz", "Pl. alle"],
    ),
    LatinAdjective(
      id: "felix",
      lemma: "fēlīx",
      genitive: "fēlīcis",
      adjectiveClass: LatinAdjectiveClass.thirdOneEnding,
      translations: ["glücklich", "erfolgreich"],
    ),
  ];

  // ---------------------------------------------------------------------------
  // PRONOMEN
  // ---------------------------------------------------------------------------

  static const List<LatinPronoun> pronouns = [
    LatinPronoun(
      id: "ego",
      label: "ego – nōs",
      kind: "Personalpronomen (1. Person)",
      hasGender: false,
      translations: ["ich", "wir"],
      singular: {
        LatinCases.nominative: ["ego"],
        LatinCases.genitive: ["meī"],
        LatinCases.dative: ["mihi"],
        LatinCases.accusative: ["mē"],
        LatinCases.ablative: ["mē"],
      },
      plural: {
        LatinCases.nominative: ["nōs"],
        LatinCases.genitive: ["nostrī/nostrum"],
        LatinCases.dative: ["nōbīs"],
        LatinCases.accusative: ["nōs"],
        LatinCases.ablative: ["nōbīs"],
      },
    ),
    LatinPronoun(
      id: "tu",
      label: "tū – vōs",
      kind: "Personalpronomen (2. Person)",
      hasGender: false,
      translations: ["du", "ihr"],
      singular: {
        LatinCases.nominative: ["tū"],
        LatinCases.genitive: ["tuī"],
        LatinCases.dative: ["tibi"],
        LatinCases.accusative: ["tē"],
        LatinCases.ablative: ["tē"],
      },
      plural: {
        LatinCases.nominative: ["vōs"],
        LatinCases.genitive: ["vestrī/vestrum"],
        LatinCases.dative: ["vōbīs"],
        LatinCases.accusative: ["vōs"],
        LatinCases.ablative: ["vōbīs"],
      },
    ),
    LatinPronoun(
      id: "se",
      label: "sē",
      kind: "Reflexivpronomen (3. Person)",
      hasGender: false,
      translations: ["sich"],
      singular: {
        LatinCases.nominative: ["–"],
        LatinCases.genitive: ["suī"],
        LatinCases.dative: ["sibi"],
        LatinCases.accusative: ["sē"],
        LatinCases.ablative: ["sē"],
      },
      plural: {
        LatinCases.nominative: ["–"],
        LatinCases.genitive: ["suī"],
        LatinCases.dative: ["sibi"],
        LatinCases.accusative: ["sē"],
        LatinCases.ablative: ["sē"],
      },
    ),
    LatinPronoun(
      id: "is",
      label: "is, ea, id",
      kind: "Demonstrativpronomen",
      hasGender: true,
      translations: ["dieser", "er, sie, es"],
      singular: {
        LatinCases.nominative: ["is", "ea", "id"],
        LatinCases.genitive: ["eius", "eius", "eius"],
        LatinCases.dative: ["eī", "eī", "eī"],
        LatinCases.accusative: ["eum", "eam", "id"],
        LatinCases.ablative: ["eō", "eā", "eō"],
      },
      plural: {
        LatinCases.nominative: ["eī/iī", "eae", "ea"],
        LatinCases.genitive: ["eōrum", "eārum", "eōrum"],
        LatinCases.dative: ["eīs/iīs", "eīs/iīs", "eīs/iīs"],
        LatinCases.accusative: ["eōs", "eās", "ea"],
        LatinCases.ablative: ["eīs/iīs", "eīs/iīs", "eīs/iīs"],
      },
    ),
    LatinPronoun(
      id: "hic",
      label: "hic, haec, hoc",
      kind: "Demonstrativpronomen",
      hasGender: true,
      translations: ["dieser (hier)"],
      singular: {
        LatinCases.nominative: ["hic", "haec", "hoc"],
        LatinCases.genitive: ["huius", "huius", "huius"],
        LatinCases.dative: ["huic", "huic", "huic"],
        LatinCases.accusative: ["hunc", "hanc", "hoc"],
        LatinCases.ablative: ["hōc", "hāc", "hōc"],
      },
      plural: {
        LatinCases.nominative: ["hī", "hae", "haec"],
        LatinCases.genitive: ["hōrum", "hārum", "hōrum"],
        LatinCases.dative: ["hīs", "hīs", "hīs"],
        LatinCases.accusative: ["hōs", "hās", "haec"],
        LatinCases.ablative: ["hīs", "hīs", "hīs"],
      },
    ),
    LatinPronoun(
      id: "ille",
      label: "ille, illa, illud",
      kind: "Demonstrativpronomen",
      hasGender: true,
      translations: ["jener"],
      singular: {
        LatinCases.nominative: ["ille", "illa", "illud"],
        LatinCases.genitive: ["illīus", "illīus", "illīus"],
        LatinCases.dative: ["illī", "illī", "illī"],
        LatinCases.accusative: ["illum", "illam", "illud"],
        LatinCases.ablative: ["illō", "illā", "illō"],
      },
      plural: {
        LatinCases.nominative: ["illī", "illae", "illa"],
        LatinCases.genitive: ["illōrum", "illārum", "illōrum"],
        LatinCases.dative: ["illīs", "illīs", "illīs"],
        LatinCases.accusative: ["illōs", "illās", "illa"],
        LatinCases.ablative: ["illīs", "illīs", "illīs"],
      },
    ),
    LatinPronoun(
      id: "qui",
      label: "quī, quae, quod",
      kind: "Relativpronomen",
      hasGender: true,
      translations: ["der, die, das", "welcher"],
      singular: {
        LatinCases.nominative: ["quī", "quae", "quod"],
        LatinCases.genitive: ["cuius", "cuius", "cuius"],
        LatinCases.dative: ["cui", "cui", "cui"],
        LatinCases.accusative: ["quem", "quam", "quod"],
        LatinCases.ablative: ["quō", "quā", "quō"],
      },
      plural: {
        LatinCases.nominative: ["quī", "quae", "quae"],
        LatinCases.genitive: ["quōrum", "quārum", "quōrum"],
        LatinCases.dative: ["quibus", "quibus", "quibus"],
        LatinCases.accusative: ["quōs", "quās", "quae"],
        LatinCases.ablative: ["quibus", "quibus", "quibus"],
      },
    ),
  ];

  // ---------------------------------------------------------------------------
  // VERBEN
  // ---------------------------------------------------------------------------

  static const List<LatinVerb> verbs = [
    // a-Konjugation
    LatinVerb(
      id: "cogitare",
      infinitive: "cōgitāre",
      present: "cōgitō",
      perfect: "cōgitāvī",
      supine: "cōgitātum",
      conjugation: LatinConjugation.a,
      translations: ["denken", "nachdenken"],
      vocabularyId: 1,
    ),
    LatinVerb(
      id: "stare",
      infinitive: "stāre",
      present: "stō",
      perfect: "stetī",
      conjugation: LatinConjugation.a,
      hasPassive: false,
      translations: ["stehen"],
      vocabularyId: 11,
    ),
    LatinVerb(
      id: "spectare",
      infinitive: "spectāre",
      present: "spectō",
      perfect: "spectāvī",
      supine: "spectātum",
      conjugation: LatinConjugation.a,
      translations: ["anschauen", "betrachten"],
      vocabularyId: 12,
    ),
    LatinVerb(
      id: "clamare",
      infinitive: "clāmāre",
      present: "clāmō",
      perfect: "clāmāvī",
      supine: "clāmātum",
      conjugation: LatinConjugation.a,
      translations: ["laut rufen", "schreien"],
      vocabularyId: 13,
    ),
    LatinVerb(
      id: "rogare",
      infinitive: "rogāre",
      present: "rogō",
      perfect: "rogāvī",
      supine: "rogātum",
      conjugation: LatinConjugation.a,
      translations: ["fragen", "bitten"],
      vocabularyId: 27,
    ),
    LatinVerb(
      id: "amare",
      infinitive: "amāre",
      present: "amō",
      perfect: "amāvī",
      supine: "amātum",
      conjugation: LatinConjugation.a,
      translations: ["lieben"],
      vocabularyId: 31,
    ),
    LatinVerb(
      id: "properare",
      infinitive: "properāre",
      present: "properō",
      perfect: "properāvī",
      conjugation: LatinConjugation.a,
      hasPassive: false,
      translations: ["eilen", "sich beeilen"],
      vocabularyId: 39,
    ),
    LatinVerb(
      id: "exspectare",
      infinitive: "exspectāre",
      present: "exspectō",
      perfect: "exspectāvī",
      supine: "exspectātum",
      conjugation: LatinConjugation.a,
      translations: ["warten", "erwarten"],
      vocabularyId: 52,
    ),
    LatinVerb(
      id: "narrare",
      infinitive: "narrāre",
      present: "narrō",
      perfect: "narrāvī",
      supine: "narrātum",
      conjugation: LatinConjugation.a,
      translations: ["erzählen"],
      vocabularyId: 53,
    ),
    LatinVerb(
      id: "adiuvare",
      infinitive: "adiuvāre",
      present: "adiuvō",
      perfect: "adiūvī",
      supine: "adiūtum",
      conjugation: LatinConjugation.a,
      translations: ["helfen", "unterstützen"],
      vocabularyId: 58,
    ),
    LatinVerb(
      id: "vocare",
      infinitive: "vocāre",
      present: "vocō",
      perfect: "vocāvī",
      supine: "vocātum",
      conjugation: LatinConjugation.a,
      translations: ["rufen", "nennen"],
      vocabularyId: 59,
    ),
    LatinVerb(
      id: "parare",
      infinitive: "parāre",
      present: "parō",
      perfect: "parāvī",
      supine: "parātum",
      conjugation: LatinConjugation.a,
      translations: ["(vor)bereiten", "vorhaben", "erwerben"],
      vocabularyId: 70,
    ),
    LatinVerb(
      id: "laborare",
      infinitive: "labōrāre",
      present: "labōrō",
      perfect: "labōrāvī",
      conjugation: LatinConjugation.a,
      hasPassive: false,
      translations: ["arbeiten", "sich anstrengen"],
      vocabularyId: 81,
    ),
    LatinVerb(
      id: "salutare",
      infinitive: "salūtāre",
      present: "salūtō",
      perfect: "salūtāvī",
      supine: "salūtātum",
      conjugation: LatinConjugation.a,
      translations: ["grüßen", "begrüßen"],
      vocabularyId: 88,
    ),
    LatinVerb(
      id: "intrare",
      infinitive: "intrāre",
      present: "intrō",
      perfect: "intrāvī",
      supine: "intrātum",
      conjugation: LatinConjugation.a,
      translations: ["betreten", "hineingehen"],
      vocabularyId: 93,
    ),
    LatinVerb(
      id: "necare",
      infinitive: "necāre",
      present: "necō",
      perfect: "necāvī",
      supine: "necātum",
      conjugation: LatinConjugation.a,
      translations: ["töten"],
      vocabularyId: 97,
    ),
    LatinVerb(
      id: "servare",
      infinitive: "servāre",
      present: "servō",
      perfect: "servāvī",
      supine: "servātum",
      conjugation: LatinConjugation.a,
      translations: ["retten", "bewahren"],
      vocabularyId: 98,
    ),
    LatinVerb(
      id: "laudare",
      infinitive: "laudāre",
      present: "laudō",
      perfect: "laudāvī",
      supine: "laudātum",
      conjugation: LatinConjugation.a,
      translations: ["loben"],
      vocabularyId: 102,
    ),

    // e-Konjugation
    LatinVerb(
      id: "tacere",
      infinitive: "tacēre",
      present: "taceō",
      perfect: "tacuī",
      conjugation: LatinConjugation.e,
      hasPassive: false,
      translations: ["schweigen"],
      vocabularyId: 15,
    ),
    LatinVerb(
      id: "videre",
      infinitive: "vidēre",
      present: "videō",
      perfect: "vīdī",
      supine: "vīsum",
      conjugation: LatinConjugation.e,
      translations: ["sehen"],
      vocabularyId: 19,
    ),
    LatinVerb(
      id: "gaudere",
      infinitive: "gaudēre",
      present: "gaudeō",
      conjugation: LatinConjugation.e,
      hasPassive: false,
      translations: ["sich freuen"],
      vocabularyId: 21,
    ),
    LatinVerb(
      id: "ridere",
      infinitive: "rīdēre",
      present: "rīdeō",
      perfect: "rīsī",
      supine: "rīsum",
      conjugation: LatinConjugation.e,
      translations: ["lachen", "auslachen"],
      vocabularyId: 30,
    ),
    LatinVerb(
      id: "debere",
      infinitive: "dēbēre",
      present: "dēbeō",
      perfect: "dēbuī",
      supine: "dēbitum",
      conjugation: LatinConjugation.e,
      translations: ["müssen", "sollen", "schulden"],
      vocabularyId: 35,
    ),
    LatinVerb(
      id: "sedere",
      infinitive: "sedēre",
      present: "sedeō",
      perfect: "sēdī",
      conjugation: LatinConjugation.e,
      hasPassive: false,
      translations: ["sitzen"],
      vocabularyId: 72,
    ),
    LatinVerb(
      id: "parere",
      infinitive: "pārēre",
      present: "pāreō",
      perfect: "pāruī",
      conjugation: LatinConjugation.e,
      hasPassive: false,
      translations: ["gehorchen"],
      vocabularyId: 75,
    ),
    LatinVerb(
      id: "monere",
      infinitive: "monēre",
      present: "moneō",
      perfect: "monuī",
      supine: "monitum",
      conjugation: LatinConjugation.e,
      translations: ["mahnen", "ermahnen"],
      vocabularyId: 79,
    ),
    LatinVerb(
      id: "audere",
      infinitive: "audēre",
      present: "audeō",
      conjugation: LatinConjugation.e,
      hasPassive: false,
      translations: ["wagen"],
      vocabularyId: 96,
    ),

    // i-Konjugation
    LatinVerb(
      id: "venire",
      infinitive: "venīre",
      present: "veniō",
      perfect: "vēnī",
      supine: "ventum",
      conjugation: LatinConjugation.i,
      hasPassive: false,
      translations: ["kommen"],
      vocabularyId: 5,
    ),
    LatinVerb(
      id: "reperire",
      infinitive: "reperīre",
      present: "reperiō",
      perfect: "repperī",
      supine: "repertum",
      conjugation: LatinConjugation.i,
      translations: ["finden", "wiederfinden"],
      vocabularyId: 47,
    ),
    LatinVerb(
      id: "audire",
      infinitive: "audīre",
      present: "audiō",
      perfect: "audīvī",
      supine: "audītum",
      conjugation: LatinConjugation.i,
      translations: ["hören"],
      vocabularyId: 48,
    ),
    LatinVerb(
      id: "scire",
      infinitive: "scīre",
      present: "sciō",
      perfect: "scīvī",
      supine: "scītum",
      conjugation: LatinConjugation.i,
      translations: ["wissen", "kennen"],
      vocabularyId: 73,
    ),

    // konsonantische Konjugation (Beispielverben)
    LatinVerb(
      id: "mittere",
      infinitive: "mittere",
      present: "mittō",
      perfect: "mīsī",
      supine: "missum",
      conjugation: LatinConjugation.consonant,
      translations: ["schicken", "loslassen"],
    ),
    LatinVerb(
      id: "ducere",
      infinitive: "dūcere",
      present: "dūcō",
      perfect: "dūxī",
      supine: "ductum",
      conjugation: LatinConjugation.consonant,
      imperativeSingular: "dūc",
      translations: ["führen", "ziehen"],
    ),
    LatinVerb(
      id: "dicere",
      infinitive: "dīcere",
      present: "dīcō",
      perfect: "dīxī",
      supine: "dictum",
      conjugation: LatinConjugation.consonant,
      imperativeSingular: "dīc",
      translations: ["sagen", "nennen"],
    ),
    LatinVerb(
      id: "legere",
      infinitive: "legere",
      present: "legō",
      perfect: "lēgī",
      supine: "lēctum",
      conjugation: LatinConjugation.consonant,
      translations: ["lesen", "sammeln"],
    ),
    LatinVerb(
      id: "agere",
      infinitive: "agere",
      present: "agō",
      perfect: "ēgī",
      supine: "āctum",
      conjugation: LatinConjugation.consonant,
      translations: ["treiben", "tun", "verhandeln"],
    ),
    LatinVerb(
      id: "capere",
      infinitive: "capere",
      present: "capiō",
      perfect: "cēpī",
      supine: "captum",
      conjugation: LatinConjugation.mixed,
      translations: ["fassen", "nehmen", "erobern"],
    ),
    LatinVerb(
      id: "facere",
      infinitive: "facere",
      present: "faciō",
      perfect: "fēcī",
      supine: "factum",
      conjugation: LatinConjugation.mixed,
      // Passiv: fierī (unregelmäßig)
      hasPassive: false,
      imperativeSingular: "fac",
      translations: ["machen", "tun"],
    ),

    // unregelmäßige Verben
    LatinVerb(
      id: "esse",
      infinitive: "esse",
      present: "sum",
      perfect: "fuī",
      conjugation: LatinConjugation.irregular,
      hasPassive: false,
      translations: ["sein", "sich befinden"],
      vocabularyId: 3,
    ),
    LatinVerb(
      id: "adesse",
      infinitive: "adesse",
      present: "adsum",
      perfect: "adfuī",
      conjugation: LatinConjugation.irregular,
      hasPassive: false,
      translations: ["da sein", "helfen"],
      vocabularyId: 34,
    ),
    LatinVerb(
      id: "velle",
      infinitive: "velle",
      present: "volō",
      perfect: "voluī",
      conjugation: LatinConjugation.irregular,
      hasPassive: false,
      translations: ["wollen"],
      vocabularyId: 95,
    ),
    LatinVerb(
      id: "posse",
      infinitive: "posse",
      present: "possum",
      perfect: "potuī",
      conjugation: LatinConjugation.irregular,
      hasPassive: false,
      translations: ["können"],
    ),
    LatinVerb(
      id: "ire",
      infinitive: "īre",
      present: "eō",
      perfect: "iī",
      supine: "itum",
      conjugation: LatinConjugation.irregular,
      hasPassive: false,
      translations: ["gehen"],
    ),
  ];

  // ---------------------------------------------------------------------------
  // PRÄPOSITIONEN
  // ---------------------------------------------------------------------------

  static const List<LatinPreposition> prepositions = [
    LatinPreposition("ā/ab", [LatinCases.ablative], "von, von … her"),
    LatinPreposition(
      "ad",
      [LatinCases.accusative],
      "zu, bei, nach",
      vocabularyId: 38,
    ),
    LatinPreposition("ante", [LatinCases.accusative], "vor", vocabularyId: 66),
    LatinPreposition("apud", [LatinCases.accusative], "bei", vocabularyId: 83),
    LatinPreposition("circum", [LatinCases.accusative], "um … herum"),
    LatinPreposition("contrā", [LatinCases.accusative], "gegen"),
    LatinPreposition("cum", [LatinCases.ablative], "mit, zusammen mit"),
    LatinPreposition("dē", [LatinCases.ablative], "von … herab, über"),
    LatinPreposition("ē/ex", [LatinCases.ablative], "aus, von … her"),
    LatinPreposition(
      "in",
      [LatinCases.accusative, LatinCases.ablative],
      "mit Akk.: in (… hinein), nach (wohin?), gegen; "
          "mit Abl.: in, an, auf (wo?)",
      vocabularyId: 91,
    ),
    LatinPreposition("inter", [LatinCases.accusative], "zwischen, unter"),
    LatinPreposition("ob", [LatinCases.accusative], "wegen"),
    LatinPreposition("per", [LatinCases.accusative], "durch", vocabularyId: 45),
    LatinPreposition("post", [LatinCases.accusative], "nach, hinter"),
    LatinPreposition("prō", [LatinCases.ablative], "für, vor, anstelle von"),
    LatinPreposition(
      "propter",
      [LatinCases.accusative],
      "wegen",
      vocabularyId: 100,
    ),
    LatinPreposition("sine", [LatinCases.ablative], "ohne"),
    LatinPreposition("sub", [
      LatinCases.accusative,
      LatinCases.ablative,
    ], "mit Akk.: unter (wohin?); mit Abl.: unter (wo?)"),
    LatinPreposition("trāns", [
      LatinCases.accusative,
    ], "über … hinaus, jenseits"),
  ];

  // ---------------------------------------------------------------------------
  // SATZLEHRE
  // ---------------------------------------------------------------------------

  static const List<LatinSyntaxExample> syntaxExamples = [
    LatinSyntaxExample(
      id: "aci_videt",
      sentence: "Servus dominum venīre videt.",
      translation: "Der Sklave sieht, dass der Herr kommt.",
      construction: LatinConstructions.aci,
      explanation:
          "Nach videt (Verb der Wahrnehmung) steht ein AcI: dominum ist der "
          "Subjektsakkusativ, venīre der Infinitiv. Übersetzung mit "
          "„dass“.",
    ),
    LatinSyntaxExample(
      id: "aci_gaudet",
      sentence: "Mārcus amīcum adesse gaudet.",
      translation: "Markus freut sich, dass der Freund da ist.",
      construction: LatinConstructions.aci,
      explanation:
          "Auch nach Verben der Gemütsbewegung (gaudēre) steht ein AcI: "
          "amīcum adesse – dass der Freund da ist.",
    ),
    LatinSyntaxExample(
      id: "aci_dico",
      sentence: "Dīcō tē bene labōrāre.",
      translation: "Ich sage, dass du gut arbeitest.",
      construction: LatinConstructions.aci,
      explanation:
          "Nach einem Verb des Sagens (dīcō) steht ein AcI: tē ist "
          "Subjektsakkusativ, labōrāre der Infinitiv.",
    ),
    LatinSyntaxExample(
      id: "ablabs_veniente",
      sentence: "Dominō veniente servī tacent.",
      translation: "Als der Herr kommt, schweigen die Sklaven.",
      construction: LatinConstructions.ablativeAbsolute,
      explanation:
          "Bezugswort (dominō) und Partizip (veniente) stehen im Ablativ und "
          "sind kein Satzglied des übrigen Satzes. Partizip Präsens: "
          "gleichzeitig.",
    ),
    LatinSyntaxExample(
      id: "ablabs_capta",
      sentence: "Urbe captā hostēs discessērunt.",
      translation:
          "Nachdem die Stadt eingenommen worden war, zogen die Feinde ab.",
      construction: LatinConstructions.ablativeAbsolute,
      explanation:
          "urbe captā: Substantiv und PPP im Ablativ, vom übrigen Satz "
          "losgelöst. Das PPP drückt Vorzeitigkeit aus.",
    ),
    LatinSyntaxExample(
      id: "ablabs_audito",
      sentence: "Hōc audītō omnēs rīsērunt.",
      translation: "Nachdem sie dies gehört hatten, lachten alle.",
      construction: LatinConstructions.ablativeAbsolute,
      explanation:
          "hōc audītō: Pronomen und PPP im Ablativ, vorzeitig; das Subjekt "
          "des Hauptsatzes (omnēs) ist der Handelnde.",
    ),
    LatinSyntaxExample(
      id: "pc_laudati",
      sentence: "Mīlitēs ā duce laudātī gaudent.",
      translation:
          "Die Soldaten freuen sich, weil sie vom Feldherrn gelobt worden "
          "sind.",
      construction: LatinConstructions.participiumConiunctum,
      explanation:
          "laudātī stimmt in Kasus, Numerus und Genus mit dem Subjekt "
          "mīlitēs überein (Participium coniunctum). Je nach Sinn temporal, "
          "kausal oder konzessiv übersetzen.",
    ),
    LatinSyntaxExample(
      id: "relative_quam",
      sentence: "Amīca, quam vidēs, in forō labōrat.",
      translation: "Die Freundin, die du siehst, arbeitet auf dem Forum.",
      construction: LatinConstructions.relativeClause,
      explanation:
          "quam richtet sich in Numerus und Genus nach dem Bezugswort amīca "
          "(Sg. f.), im Kasus nach seiner Funktion im Relativsatz "
          "(Akkusativobjekt zu vidēs).",
    ),
    LatinSyntaxExample(
      id: "relative_cui",
      sentence: "Puella, cui librum dedī, gaudet.",
      translation: "Das Mädchen, dem ich das Buch gegeben habe, freut sich.",
      construction: LatinConstructions.relativeClause,
      explanation:
          "cui (Dativ Sg.) bezieht sich auf puella; der Dativ ergibt sich "
          "aus dedī (wem?).",
    ),
    LatinSyntaxExample(
      id: "final_ut",
      sentence: "Servī labōrant, ut dominus gaudeat.",
      translation: "Die Sklaven arbeiten, damit der Herr sich freut.",
      construction: LatinConstructions.finalClause,
      explanation:
          "ut mit Konjunktiv (gaudeat) gibt einen Zweck an: „damit“. "
          "Verneint steht nē.",
    ),
    LatinSyntaxExample(
      id: "consecutive_ut",
      sentence: "Tam fortis erat, ut nēmō eum vinceret.",
      translation: "Er war so tapfer, dass niemand ihn besiegte.",
      construction: LatinConstructions.consecutiveClause,
      explanation:
          "tam im Hauptsatz kündigt eine Folge an: ut mit Konjunktiv "
          "(vinceret) – „sodass“. Verneint steht ut nōn.",
    ),
    LatinSyntaxExample(
      id: "cum_historicum",
      sentence: "Cum dominus vēnisset, servī tacuērunt.",
      translation: "Als der Herr gekommen war, schwiegen die Sklaven.",
      construction: LatinConstructions.cumClause,
      explanation:
          "cum mit Konjunktiv Plusquamperfekt (vēnisset) in einer Erzählung "
          "der Vergangenheit: „als, nachdem“ (vorzeitig).",
    ),
    LatinSyntaxExample(
      id: "indirect_cur",
      sentence: "Senātor rogat, cūr populus clāmet.",
      translation: "Der Senator fragt, warum das Volk schreit.",
      construction: LatinConstructions.indirectQuestion,
      explanation:
          "Ein Fragewort (cūr) leitet nach rogat eine abhängige Frage ein; "
          "sie steht im Konjunktiv (clāmet), übersetzt wird mit Indikativ.",
    ),
    LatinSyntaxExample(
      id: "indirect_quis",
      sentence: "Nesciō, quis vēnerit.",
      translation: "Ich weiß nicht, wer gekommen ist.",
      construction: LatinConstructions.indirectQuestion,
      explanation:
          "quis leitet eine indirekte Frage ein; Konjunktiv Perfekt "
          "(vēnerit) zeigt Vorzeitigkeit zur Gegenwart.",
    ),
    LatinSyntaxExample(
      id: "dativus_possessivus",
      sentence: "Mercātōrī multum frūmentum est.",
      translation: "Der Kaufmann hat viel Getreide.",
      construction: LatinConstructions.dativePossessive,
      explanation:
          "Dativ + esse bezeichnet den Besitzer: „dem Kaufmann ist viel "
          "Getreide“ – der Kaufmann hat viel Getreide.",
    ),
    LatinSyntaxExample(
      id: "gerund",
      sentence: "Ars scrībendī difficilis est.",
      translation: "Die Kunst des Schreibens ist schwierig.",
      construction: LatinConstructions.gerund,
      explanation:
          "scrībendī ist ein Gerundium im Genitiv: der substantivierte "
          "Infinitiv („des Schreibens“), abhängig von ars.",
    ),
    LatinSyntaxExample(
      id: "gerundive",
      sentence: "Ad urbem videndam vēnērunt.",
      translation: "Sie kamen, um die Stadt zu besichtigen.",
      construction: LatinConstructions.gerundive,
      explanation:
          "videndam stimmt als Gerundivum mit urbem überein (Akk. Sg. f.); "
          "ad + Gerundivum drückt einen Zweck aus: „um … zu“.",
    ),
  ];
}

class LatinPreposition {
  final String lemma;
  final List<String> cases;
  final String meaning;
  final int? vocabularyId;

  const LatinPreposition(
    this.lemma,
    this.cases,
    this.meaning, {
    this.vocabularyId,
  });

  /// Antwort im Trainer: „Akkusativ“, „Ablativ“ oder „Akkusativ und
  /// Ablativ“.
  String get caseAnswer => cases.join(" und ");
}

/// Konstruktionen, die der Trainer in Sätzen erkennen lässt.
class LatinConstructions {
  LatinConstructions._();

  static const String aci = "AcI";
  static const String ablativeAbsolute = "Ablativus absolutus";
  static const String participiumConiunctum = "Participium coniunctum";
  static const String relativeClause = "Relativsatz";
  static const String finalClause = "Finalsatz (ut/nē)";
  static const String consecutiveClause = "Konsekutivsatz (ut/ut nōn)";
  static const String cumClause = "cum-Satz mit Konjunktiv";
  static const String indirectQuestion = "Indirekte Frage";
  static const String dativePossessive = "Dativus possessivus";
  static const String gerund = "Gerundium";
  static const String gerundive = "Gerundivum";

  static const List<String> all = [
    aci,
    ablativeAbsolute,
    participiumConiunctum,
    relativeClause,
    finalClause,
    consecutiveClause,
    cumClause,
    indirectQuestion,
    dativePossessive,
    gerund,
    gerundive,
  ];
}

class LatinSyntaxExample {
  final String id;
  final String sentence;
  final String translation;
  final String construction;
  final String explanation;

  const LatinSyntaxExample({
    required this.id,
    required this.sentence,
    required this.translation,
    required this.construction,
    required this.explanation,
  });
}
