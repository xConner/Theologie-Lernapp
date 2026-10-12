import 'phenomenon_detection.dart';
import 'syntax_rules.dart';

/// Wie zuverlässig ein Phänomen erkannt wird.
enum PhenomenonStatus {
  /// Unmittelbar aus der morphologischen Bestimmung bzw. der Grundform.
  /// Erforderlich und ausgeschlossen wählbar.
  reliable,

  /// Regelbasiert aus mehreren Formen erschlossen (Satzkonstruktionen). Kann
  /// Fälle übersehen; deshalb nur „erforderlich“, nicht „ausgeschlossen“.
  heuristic,

  /// Mit der vorhandenen Datenbasis nicht erkennbar; nicht wählbar.
  unavailable,
}

/// Anforderung an ein Phänomen in der Klausurkonfiguration.
enum PhenomenonRequirement {
  /// Darf vorkommen (Standard, keine Einschränkung).
  allowed,

  /// Muss im Text sicher belegt sein.
  required,

  /// Darf im Text nicht vorkommen, auch nicht als mögliche Bestimmung einer
  /// mehrdeutigen Form.
  excluded,
}

class GrammarCategory {
  final String id;
  final String label;
  final String? hint;

  /// Jede Verbform hat genau einen Wert dieser Kategorie (Modus, Tempus,
  /// Genus Verbi). Sind alle ausgeschlossen, ist keine Verbform mehr
  /// möglich.
  final bool partitionsVerbs;

  const GrammarCategory(
    this.id,
    this.label, {
    this.hint,
    this.partitionsVerbs = false,
  });
}

class GrammarPhenomenon {
  /// Stabile ID; gespeichert in Konfigurationen und im Korpusindex.
  final String id;
  final String categoryId;
  final String label;

  /// Erklärung: was erkannt wird und wie.
  final String description;

  final PhenomenonStatus status;

  /// Erkennungsregel; `null` bei [PhenomenonStatus.unavailable].
  final PhenomenonDetector? detector;

  /// Phänomene, die bei jedem Beleg dieses Phänomens ebenfalls vorliegen
  /// (Genitivus absolutus → Partizip, Genitiv). Grundlage der Prüfung auf
  /// widersprüchliche Filter.
  final List<String> implies;

  /// In der Aufgabe „Formen im Text finden“ verwendbar: jede Belegform ist
  /// selbst eine Form des Phänomens (nicht nur Teil einer Konstruktion).
  final bool findable;

  const GrammarPhenomenon({
    required this.id,
    required this.categoryId,
    required this.label,
    required this.description,
    required this.status,
    this.detector,
    this.implies = const [],
    this.findable = false,
  });

  bool supports(PhenomenonRequirement requirement) {
    return switch (status) {
      PhenomenonStatus.reliable => true,
      PhenomenonStatus.heuristic =>
        requirement != PhenomenonRequirement.excluded,
      PhenomenonStatus.unavailable =>
        requirement == PhenomenonRequirement.allowed,
    };
  }
}

/// Zentrale Liste der Grammatikphänomene des Klausurerstellers.
///
/// Orientierung: Grammatiktrainer der App (Modi, Tempora, Genera Verbi,
/// Partizipien, Pronomen, Steigerung), Aoristblatt der Vorlesung und die
/// Gliederung einer Graecums-Lerngrammatik (Formenlehre, Kasus-, Tempus-
/// und Moduslehre, Partizipial- und Infinitivkonstruktionen, Nebensätze).
///
/// Ein Filter steht hier nur, wenn er einen eigenständigen, schrittweise
/// gelernten Stoffbereich abbildet (ein Tempus, ein Modus, eine Verbklasse,
/// eine Konstruktion). Person, Numerus, Kasus und Genus werden mit jeder
/// Form mitgelernt und sind keine Filter (siehe [retiredFilters]).
///
/// Ein neues Phänomen braucht nur einen Eintrag hier; eine neue Regel ist
/// eine Funktion in `syntax_rules.dart`. Danach den Korpusindex neu
/// erzeugen (`tool/greek_exam_corpus/README.md`), sonst gilt das Phänomen
/// bis dahin als nicht verfügbar.
class GrammarPhenomena {
  GrammarPhenomena._();

  static const List<GrammarCategory> categories = [
    GrammarCategory(
      "mood",
      "Modus und infinite Formen",
      partitionsVerbs: true,
    ),
    GrammarCategory("tense", "Tempus", partitionsVerbs: true),
    GrammarCategory(
      "voice",
      "Genus Verbi",
      hint:
          "Im Präsens, Imperfekt und Perfekt sind Medium und Passiv "
          "formgleich; im Neuen Testament entscheidet die Bestimmung im "
          "Kontext.",
      partitionsVerbs: true,
    ),
    GrammarCategory("verbclass", "Verbklassen und Stammformen"),
    GrammarCategory("rection", "Verben mit besonderer Rektion"),
    GrammarCategory("noun", "Nomina und Adjektive"),
    GrammarCategory("pronoun", "Pronomen"),
    GrammarCategory("participleSyntax", "Partizipialkonstruktionen"),
    GrammarCategory("infinitiveSyntax", "Infinitivkonstruktionen"),
    GrammarCategory("clauses", "Nebensätze und Rede"),
    GrammarCategory("moodSyntax", "Konjunktiv und Optativ im Satz"),
    GrammarCategory("negation", "Negationen"),
    GrammarCategory("preposition", "Präpositionen und Kasusrektion"),
    GrammarCategory("wordOrder", "Wortstellung"),
  ];

  /// Frühere Filter, die keine eigene Lernstufe abbilden, sondern eine
  /// Grunddimension der Formenlehre in Einzelfälle zerlegten (einzelne
  /// Personen, Numeri, Kasus, Genera) oder Wörter des ersten Lernschritts
  /// betrafen (Artikel, οὐ, μή). Wer Präsens gewählt hat, bekommt alle
  /// Personen und Numeri des Präsens; wer Partizipien zulässt, alle Kasus,
  /// Numeri und Genera.
  ///
  /// Gespeicherte Anforderungen mit diesen IDs entfallen beim Lesen
  /// (`ExamConfig.fromMap`): der betroffene Stoff ist danach uneingeschränkt
  /// erlaubt.
  static const Set<String> retiredFilters = {
    "verb.person.first",
    "verb.person.second",
    "verb.person.third",
    "verb.number.singular",
    "verb.number.plural",
    "participle.case.n",
    "participle.case.g",
    "participle.case.d",
    "participle.case.a",
    "participle.number.s",
    "participle.number.p",
    "participle.gender.m",
    "participle.gender.f",
    "participle.gender.n",
    "case.vocative",
    "pronoun.article",
    "negation.ou",
    "negation.me",
    "preposition.genitive",
    "preposition.dative",
    "preposition.accusative",
  };

  static GrammarCategory? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static final Map<String, GrammarPhenomenon> _byId = {
    for (final p in all) p.id: p,
  };

  static GrammarPhenomenon? byId(String id) => _byId[id];

  static List<GrammarPhenomenon> inCategory(String categoryId) => [
    for (final p in all)
      if (p.categoryId == categoryId) p,
  ];

  /// Phänomene, die der Index des Korpus erfassen muss.
  static Iterable<GrammarPhenomenon> get detectable =>
      all.where((p) => p.detector != null);

  // Hilfen für kurze Einträge.
  static GrammarPhenomenon _morph(
    String id,
    String category,
    String label,
    MorphPattern pattern, {
    String? description,
    List<String> implies = const [],
  }) {
    return GrammarPhenomenon(
      id: id,
      categoryId: category,
      label: label,
      description:
          description ??
          "Erkannt an der morphologischen Bestimmung jeder Wortform.",
      status: PhenomenonStatus.reliable,
      detector: MorphDetector(pattern),
      implies: implies,
      findable: true,
    );
  }

  static GrammarPhenomenon _lemmas(
    String id,
    String category,
    String label,
    List<String> lemmas, {
    MorphPattern? pattern,
    bool compounds = false,
    String? description,
    List<String> implies = const [],
    bool findable = true,
  }) {
    return GrammarPhenomenon(
      id: id,
      categoryId: category,
      label: label,
      description:
          description ?? "Erkannt an der Grundform: ${lemmas.join(', ')}.",
      status: PhenomenonStatus.reliable,
      detector: LemmaDetector(lemmas, pattern: pattern, compounds: compounds),
      implies: implies,
      findable: findable,
    );
  }

  static GrammarPhenomenon _rule(
    String id,
    String category,
    String label,
    String description,
    List<int> Function(DetectionView) rule, {
    List<String> implies = const [],
  }) {
    return GrammarPhenomenon(
      id: id,
      categoryId: category,
      label: label,
      description: description,
      status: PhenomenonStatus.heuristic,
      detector: RuleDetector(rule),
      implies: implies,
    );
  }

  static GrammarPhenomenon _unavailable(
    String id,
    String category,
    String label,
    String reason,
  ) {
    return GrammarPhenomenon(
      id: id,
      categoryId: category,
      label: label,
      description: reason,
      status: PhenomenonStatus.unavailable,
    );
  }

  static const _verb = {"V-"};

  /// Starke (thematische) Aoriste: Verben des Aoristblatts der Vorlesung und
  /// weitere häufige Verben des Neuen Testaments. Komposita zählen mit.
  static const List<String> strongAoristVerbs = [
    "ἄγω",
    "βάλλω",
    "γίνομαι",
    "γίγνομαι",
    "ἔρχομαι",
    "εὑρίσκω",
    "ἔχω",
    "λαμβάνω",
    "λείπω",
    "μανθάνω",
    "ὁράω",
    "φεύγω",
    "θνῄσκω",
    "πίπτω",
    "πάσχω",
    "πίνω",
    "ἐσθίω",
    "τίκτω",
    "τυγχάνω",
    "λανθάνω",
    "ἁμαρτάνω",
    "αἱρέω",
    "τρέχω",
    "κάμνω",
  ];

  /// Wurzelaoriste (ἔβην, ἔγνων, ἔστην); Komposita zählen mit.
  static const List<String> rootAoristVerbs = ["βαίνω", "γινώσκω", "γιγνώσκω"];

  /// Verben mit Suppletivstämmen (εἶπον, εἶδον, ἤνεγκον, ἦλθον, ἔφαγον,
  /// ἔδραμον, εἷλον).
  static const List<String> suppletiveVerbs = [
    "ὁράω",
    "φέρω",
    "ἔρχομαι",
    "ἐσθίω",
    "τρέχω",
    "αἱρέω",
  ];

  static final List<GrammarPhenomenon> all = [
    // -------------------------------------------------------------------------
    // MODUS
    // -------------------------------------------------------------------------
    _morph(
      "verb.mood.indicative",
      "mood",
      "Indikativ",
      const MorphPattern(pos: _verb, mood: "I"),
    ),
    _morph(
      "verb.mood.subjunctive",
      "mood",
      "Konjunktiv",
      const MorphPattern(pos: _verb, mood: "S"),
    ),
    _morph(
      "verb.mood.optative",
      "mood",
      "Optativ",
      const MorphPattern(pos: _verb, mood: "O"),
    ),
    _morph(
      "verb.mood.imperative",
      "mood",
      "Imperativ",
      const MorphPattern(pos: _verb, mood: "D"),
    ),
    _morph(
      "verb.mood.infinitive",
      "mood",
      "Infinitiv",
      const MorphPattern(pos: _verb, mood: "N"),
    ),
    _morph(
      "verb.mood.participle",
      "mood",
      "Partizip",
      const MorphPattern(pos: _verb, mood: "P"),
    ),

    // -------------------------------------------------------------------------
    // TEMPUS
    // -------------------------------------------------------------------------
    _morph(
      "verb.tense.present",
      "tense",
      "Präsens",
      const MorphPattern(pos: _verb, tense: "P"),
    ),
    _morph(
      "verb.tense.imperfect",
      "tense",
      "Imperfekt",
      const MorphPattern(pos: _verb, tense: "I"),
    ),
    _morph(
      "verb.tense.future",
      "tense",
      "Futur",
      const MorphPattern(pos: _verb, tense: "F"),
    ),
    _morph(
      "verb.tense.aorist",
      "tense",
      "Aorist",
      const MorphPattern(pos: _verb, tense: "A"),
    ),
    _morph(
      "verb.tense.perfect",
      "tense",
      "Perfekt",
      const MorphPattern(pos: _verb, tense: "X"),
    ),
    _morph(
      "verb.tense.pluperfect",
      "tense",
      "Plusquamperfekt",
      const MorphPattern(pos: _verb, tense: "Y"),
    ),

    // -------------------------------------------------------------------------
    // GENUS VERBI
    // -------------------------------------------------------------------------
    _morph(
      "verb.voice.active",
      "voice",
      "Aktiv",
      const MorphPattern(pos: _verb, voice: "A"),
    ),
    _morph(
      "verb.voice.middle",
      "voice",
      "Medium",
      const MorphPattern(pos: _verb, voice: "M"),
    ),
    _morph(
      "verb.voice.passive",
      "voice",
      "Passiv",
      const MorphPattern(pos: _verb, voice: "P"),
    ),

    // -------------------------------------------------------------------------
    // VERBKLASSEN UND STAMMFORMEN
    // -------------------------------------------------------------------------
    GrammarPhenomenon(
      id: "verb.aorist.strong",
      categoryId: "verbclass",
      label: "Starker (thematischer) Aorist",
      description:
          "Aorist Aktiv/Medium eines Verbs mit starkem Aorist laut "
          "Aoristblatt und Vokabular (ἤγαγον, ἔβαλον, ἐγενόμην, ἦλθον, εὗρον, "
          "ἔσχον, ἔλαβον, ἔλιπον, ἔμαθον, εἶδον, ἔφυγον u. a.), auch in "
          "Komposita. Mischformen der Koine (ἦλθαν, εἶπαν) zählen mit; Verben "
          "außerhalb der Liste werden nicht erkannt.",
      status: PhenomenonStatus.heuristic,
      detector: LemmaDetector(
        [...strongAoristVerbs, "λέγω"],
        pattern: const MorphPattern(pos: _verb, tense: "A", voice: "AM"),
        compounds: true,
      ),
      implies: const ["verb.tense.aorist"],
      findable: false,
    ),
    GrammarPhenomenon(
      id: "verb.aorist.root",
      categoryId: "verbclass",
      label: "Wurzelaorist (ἔβην, ἔγνων)",
      description:
          "Aorist Aktiv von βαίνω und γινώσκω samt Komposita (Aoristblatt).",
      status: PhenomenonStatus.reliable,
      detector: LemmaDetector(
        rootAoristVerbs,
        pattern: const MorphPattern(pos: _verb, tense: "A", voice: "A"),
        compounds: true,
      ),
      implies: const ["verb.tense.aorist"],
      findable: true,
    ),
    _morph(
      "verb.aorist.passive",
      "verbclass",
      "Aorist Passiv (-θη-/-η-)",
      const MorphPattern(pos: _verb, tense: "A", voice: "P"),
      implies: const ["verb.tense.aorist", "verb.voice.passive"],
    ),
    _lemmas(
      "verb.lemma.eimi",
      "verbclass",
      "εἰμί",
      const ["εἰμί"],
      pattern: MorphPattern.verb,
    ),
    GrammarPhenomenon(
      id: "verb.class.mi",
      categoryId: "verbclass",
      label: "Verben auf -μι (δίδωμι, τίθημι, ἵστημι, δείκνυμι …)",
      description:
          "Erkannt an der Grundform auf -μι (ohne εἰμί und seine Komposita).",
      status: PhenomenonStatus.reliable,
      detector: LemmaSuffixDetector(
        const ["μι"],
        except: const ["ειμι"],
        pattern: MorphPattern.verb,
      ),
      findable: true,
    ),
    GrammarPhenomenon(
      id: "verb.class.contract",
      categoryId: "verbclass",
      label: "Verba contracta (-άω, -έω, -όω)",
      description: "Erkannt an der Grundform auf -άω, -έω, -όω.",
      status: PhenomenonStatus.reliable,
      detector: LemmaSuffixDetector(
        const ["αω", "εω", "οω"],
        pattern: MorphPattern.verb,
      ),
      findable: true,
    ),
    GrammarPhenomenon(
      id: "verb.class.deponent",
      categoryId: "verbclass",
      label: "Deponentien (Grundform auf -μαι)",
      description:
          "Erkannt an der Grundform auf -μαι. Verben, deren Medium im "
          "Wörterbuch unter dem Aktiv steht, zählen nicht.",
      status: PhenomenonStatus.reliable,
      detector: LemmaSuffixDetector(
        const ["μαι"],
        pattern: MorphPattern.verb,
      ),
      findable: true,
    ),
    _lemmas(
      "verb.suppletive",
      "verbclass",
      "Suppletivformen (εἶπον, εἶδον, ἦλθον, ἤνεγκα, ἔφαγον …)",
      const [...suppletiveVerbs],
      pattern: const MorphPattern(pos: _verb, tense: "AFXY"),
      compounds: true,
      description:
          "Aorist, Futur oder Perfekt von ὁράω, φέρω, ἔρχομαι, ἐσθίω, "
          "τρέχω, αἱρέω (auch Komposita) sowie von λέγω.",
    ),
    _lemmas(
      "verb.suppletive.lego",
      "verbclass",
      "εἶπον / ἐρῶ / εἴρηκα (zu λέγω)",
      const ["λέγω", "εἶπον"],
      pattern: const MorphPattern(pos: _verb, tense: "AFXY"),
    ),
    _lemmas(
      "verb.lemma.oida",
      "verbclass",
      "οἶδα (Perfekt mit Präsensbedeutung)",
      const ["οἶδα"],
      pattern: MorphPattern.verb,
    ),

    // -------------------------------------------------------------------------
    // REKTION
    // -------------------------------------------------------------------------
    _lemmas(
      "rection.genitive",
      "rection",
      "Verben mit Genitiv (ἀκούω, ἄρχω, ἅπτομαι, κρατέω …)",
      SyntaxRules.genitiveVerbs,
      pattern: MorphPattern.verb,
      description:
          "Erkannt wird das Verb (${SyntaxRules.genitiveVerbs.take(8).join(', ')} "
          "u. a.). Ob die Genitivergänzung im Text steht, wird nicht geprüft.",
    ),
    _lemmas(
      "rection.dative",
      "rection",
      "Verben mit Dativ (πιστεύω, ἀκολουθέω, ὑπακούω, προσκυνέω …)",
      const [
        "πιστεύω",
        "ἀκολουθέω",
        "ὑπακούω",
        "διακονέω",
        "προσκυνέω",
        "εὐχαριστέω",
        "χαρίζομαι",
        "ἀρέσκω",
        "βοηθέω",
        "δουλεύω",
        "ἐπιτιμάω",
        "λατρεύω",
        "ὀργίζομαι",
        "ὑποτάσσω",
        "ἐντέλλομαι",
        "ἀπειθέω",
        "ὀφείλω",
        "ἐγγίζω",
        "ἀντίκειμαι",
      ],
      pattern: MorphPattern.verb,
      description:
          "Erkannt wird das Verb. Ob die Dativergänzung im Text steht, wird "
          "nicht geprüft.",
    ),
    _lemmas(
      "rection.double_accusative",
      "rection",
      "Verben mit doppeltem Akkusativ (διδάσκω, αἰτέω, ἐρωτάω …)",
      const ["διδάσκω", "αἰτέω", "ἐρωτάω", "ἐνδύω", "ποτίζω", "ὀνομάζω"],
      pattern: MorphPattern.verb,
      description:
          "Erkannt wird das Verb. Ob beide Akkusative im Text stehen, wird "
          "nicht geprüft.",
    ),

    // -------------------------------------------------------------------------
    // NOMINA UND ADJEKTIVE
    // -------------------------------------------------------------------------
    GrammarPhenomenon(
      id: "noun.declension.first",
      categoryId: "noun",
      label: "Nomen der a-Deklination (1. Deklination)",
      description:
          "Deklinationsklasse laut Wiktionary-Flexionstabelle des Nomens. "
          "Nomen ohne Tabelle bleiben unberücksichtigt.",
      status: PhenomenonStatus.heuristic,
      detector: DeclensionDetector(1),
      findable: false,
    ),
    GrammarPhenomenon(
      id: "noun.declension.second",
      categoryId: "noun",
      label: "Nomen der o-Deklination (2. Deklination)",
      description:
          "Deklinationsklasse laut Wiktionary-Flexionstabelle des Nomens. "
          "Nomen ohne Tabelle bleiben unberücksichtigt.",
      status: PhenomenonStatus.heuristic,
      detector: DeclensionDetector(2),
      findable: false,
    ),
    GrammarPhenomenon(
      id: "noun.declension.third",
      categoryId: "noun",
      label: "Nomen der 3. Deklination",
      description:
          "Deklinationsklasse laut Wiktionary-Flexionstabelle des Nomens. "
          "Nomen ohne Tabelle bleiben unberücksichtigt.",
      status: PhenomenonStatus.heuristic,
      detector: DeclensionDetector(3),
      findable: false,
    ),
    _lemmas(
      "noun.irregular",
      "noun",
      "Besondere Nomina (ἀνήρ, γυνή, πατήρ, μήτηρ, χείρ, ὕδωρ …)",
      const [
        "ἀνήρ",
        "γυνή",
        "πατήρ",
        "μήτηρ",
        "θυγάτηρ",
        "γαστήρ",
        "χείρ",
        "ναῦς",
        "βοῦς",
        "Ζεύς",
        "ὕδωρ",
        "οὖς",
        "κύων",
        "γόνυ",
        "θρίξ",
        "πῦρ",
      ],
      pattern: const MorphPattern(pos: {"N-"}),
    ),
    _lemmas(
      "adjective.irregular",
      "noun",
      "Unregelmäßige Adjektive (πολύς, μέγας)",
      const ["πολύς", "μέγας"],
      pattern: const MorphPattern(pos: {"A-"}),
    ),
    _morph(
      "adjective.comparative",
      "noun",
      "Komparativ",
      const MorphPattern(degree: "C"),
      description:
          "Steigerungsstufe aus der morphologischen Bestimmung (Adjektive "
          "und Adverbien).",
    ),
    _morph(
      "adjective.superlative",
      "noun",
      "Superlativ",
      const MorphPattern(degree: "S"),
      description:
          "Steigerungsstufe aus der morphologischen Bestimmung (Adjektive "
          "und Adverbien).",
    ),
    _lemmas(
      "numeral",
      "noun",
      "Zahlwörter (εἷς, δύο, τρεῖς … πρῶτος, δεύτερος …)",
      const [
        "εἷς",
        "δύο",
        "τρεῖς",
        "τέσσαρες",
        "πέντε",
        "ἕξ",
        "ἑπτά",
        "ὀκτώ",
        "ἐννέα",
        "δέκα",
        "ἕνδεκα",
        "δώδεκα",
        "δεκαπέντε",
        "δεκατέσσαρες",
        "δεκαοκτώ",
        "εἴκοσι",
        "τριάκοντα",
        "τεσσεράκοντα",
        "πεντήκοντα",
        "ἑξήκοντα",
        "ἑβδομήκοντα",
        "ὀγδοήκοντα",
        "ἐνενήκοντα",
        "ἑκατόν",
        "διακόσιοι",
        "τριακόσιοι",
        "τετρακόσιοι",
        "πεντακόσιοι",
        "ἑξακόσιοι",
        "χίλιοι",
        "δισχίλιοι",
        "τρισχίλιοι",
        "τετρακισχίλιοι",
        "πεντακισχίλιοι",
        "μύριοι",
        "χιλιάς",
        "μυριάς",
        "πρῶτος",
        "δεύτερος",
        "τρίτος",
        "τέταρτος",
        "πέμπτος",
        "ἕκτος",
        "ἕβδομος",
        "ὄγδοος",
        "ἔνατος",
        "δέκατος",
        "ἑνδέκατος",
        "δωδέκατος",
      ],
      description:
          "Erkannt an der Grundform (Kardinal- und Ordinalzahlen, "
          "Zahlsubstantive).",
    ),

    // -------------------------------------------------------------------------
    // PRONOMEN UND ARTIKEL
    // -------------------------------------------------------------------------
    _lemmas(
      "pronoun.personal",
      "pronoun",
      "Personalpronomen der 1./2. Person (ἐγώ, σύ, ἡμεῖς, ὑμεῖς)",
      const ["ἐγώ", "σύ", "ἡμεῖς", "ὑμεῖς"],
      pattern: const MorphPattern(pos: {"RP"}),
    ),
    _lemmas(
      "pronoun.autos",
      "pronoun",
      "αὐτός (Personal- bzw. Identitätspronomen)",
      const ["αὐτός"],
    ),
    _lemmas(
      "pronoun.reflexive",
      "pronoun",
      "Reflexivpronomen (ἐμαυτοῦ, σεαυτοῦ, ἑαυτοῦ)",
      const ["ἐμαυτοῦ", "σεαυτοῦ", "ἑαυτοῦ"],
    ),
    _lemmas(
      "pronoun.reciprocal",
      "pronoun",
      "Reziprokpronomen (ἀλλήλων)",
      const ["ἀλλήλων"],
    ),
    _lemmas(
      "pronoun.possessive",
      "pronoun",
      "Possessivpronomen (ἐμός, σός, ἡμέτερος, ὑμέτερος)",
      const ["ἐμός", "σός", "ἡμέτερος", "ὑμέτερος"],
    ),
    _morph(
      "pronoun.demonstrative",
      "pronoun",
      "Demonstrativpronomen (οὗτος, ἐκεῖνος, ὅδε)",
      const MorphPattern(pos: {"RD"}),
    ),
    _morph(
      "pronoun.relative",
      "pronoun",
      "Relativpronomen (ὅς, ὅστις)",
      const MorphPattern(pos: {"RR"}),
    ),
    _lemmas(
      "pronoun.interrogative",
      "pronoun",
      "Interrogativpronomen (τίς, τί)",
      const ["τίς"],
      pattern: const MorphPattern(pos: {"RI"}),
    ),
    _lemmas(
      "pronoun.indefinite",
      "pronoun",
      "Indefinitpronomen (τις, τι)",
      const ["τις"],
      pattern: const MorphPattern(pos: {"RI"}),
    ),

    // -------------------------------------------------------------------------
    // PARTIZIPIALKONSTRUKTIONEN
    // -------------------------------------------------------------------------
    _rule(
      "syntax.genitive_absolute",
      "participleSyntax",
      "Genitivus absolutus",
      "Partizip im Genitiv ohne Artikel und Präposition mit kongruentem "
          "Nomen/Pronomen im Genitiv im selben Satz; nicht nach Verben mit "
          "Genitivobjekt (ἀκούω u. a.).",
      SyntaxRules.genitiveAbsolute,
      implies: const ["verb.mood.participle"],
    ),
    _rule(
      "syntax.participium_coniunctum",
      "participleSyntax",
      "Participium coniunctum (PC)",
      "Partizip ohne Artikel, das mit einem Bezugswort im Satz kongruiert "
          "oder im Nominativ zum Subjekt des Prädikats gehört; ohne "
          "Genitivus absolutus und Umschreibung mit εἰμί.",
      SyntaxRules.participiumConiunctum,
      implies: const ["verb.mood.participle"],
    ),
    _rule(
      "syntax.articular_participle",
      "participleSyntax",
      "Partizip mit Artikel (substantiviert/attributiv)",
      "Artikel unmittelbar vor einem kongruenten Partizip (ὁ πιστεύων).",
      SyntaxRules.articularParticiple,
      implies: const ["verb.mood.participle"],
    ),
    _rule(
      "syntax.periphrastic",
      "participleSyntax",
      "Umschreibung mit εἰμί + Partizip",
      "Finite Form von εἰμί und bis zu drei Wörter danach ein Partizip im "
          "Nominativ desselben Numerus (ἦν διδάσκων).",
      SyntaxRules.periphrasticConstruction,
      implies: const ["verb.mood.participle", "verb.lemma.eimi"],
    ),
    _unavailable(
      "syntax.accusative_absolute",
      "participleSyntax",
      "Accusativus absolutus",
      "Im Bibeltext äußerst selten; ohne Syntaxanalyse nicht von einem "
          "Akkusativobjekt mit Partizip zu unterscheiden.",
    ),

    // -------------------------------------------------------------------------
    // INFINITIVKONSTRUKTIONEN
    // -------------------------------------------------------------------------
    _rule(
      "syntax.aci",
      "infinitiveSyntax",
      "AcI (Accusativus cum infinitivo)",
      "Nomen/Pronomen im Akkusativ vor dem Infinitiv, nach einem Verb des "
          "Sagens/Meinens bzw. einem unpersönlichen Ausdruck (δεῖ, ἔξεστιν, "
          "ἐγένετο), oder Subjektsakkusativ zwischen Artikel und Infinitiv (πρὸ τοῦ "
          "ὑμᾶς αἰτῆσαι). Ein vorangestelltes Akkusativobjekt des "
          "Infinitivs kann fälschlich als Subjektsakkusativ erscheinen.",
      SyntaxRules.accusativeWithInfinitive,
      implies: const ["verb.mood.infinitive"],
    ),
    _unavailable(
      "syntax.nci",
      "infinitiveSyntax",
      "NcI (Nominativus cum infinitivo)",
      "Erfordert die Zuordnung des Subjekts zum Infinitiv; ohne "
          "Syntaxanalyse nicht zuverlässig von anderen Infinitiven zu "
          "trennen.",
    ),
    _rule(
      "syntax.articular_infinitive",
      "infinitiveSyntax",
      "Substantivierter Infinitiv (mit Artikel)",
      "Artikel im Neutrum Singular vor einem Infinitiv (τὸ ζῆν, τοῦ "
          "σπεῖραι), höchstens drei Wörter dazwischen.",
      SyntaxRules.articularInfinitive,
      implies: const ["verb.mood.infinitive"],
    ),
    _rule(
      "syntax.prepositional_infinitive",
      "infinitiveSyntax",
      "Präposition + Artikel + Infinitiv (ἐν τῷ, διὰ τό, μετὰ τό, εἰς τό)",
      "Wie der substantivierte Infinitiv, mit Präposition vor dem Artikel.",
      SyntaxRules.prepositionalInfinitive,
      implies: const [
        "verb.mood.infinitive",
        "syntax.articular_infinitive",
      ],
    ),
    _rule(
      "syntax.complementary_infinitive",
      "infinitiveSyntax",
      "Ergänzungsinfinitiv (δύναμαι, θέλω, μέλλω, δεῖ … + Inf.)",
      "Finite Form eines Verbs, das einen Infinitiv regiert, und bis zu "
          "sechs Wörter danach ein Infinitiv.",
      SyntaxRules.complementaryInfinitive,
      implies: const ["verb.mood.infinitive"],
    ),

    // -------------------------------------------------------------------------
    // NEBENSÄTZE UND REDE
    // -------------------------------------------------------------------------
    _morph(
      "clause.relative",
      "clauses",
      "Relativsatz (eingeleitet durch ὅς, ὅστις)",
      const MorphPattern(pos: {"RR"}),
      description:
          "Erkannt am Relativpronomen; Relativadverbien (ὅπου, ὅθεν) zählen "
          "nicht.",
    ),
    _rule(
      "clause.relative_generalizing",
      "clauses",
      "Verallgemeinernder Relativsatz (ὃς ἄν + Konj.)",
      "Relativpronomen, unmittelbar danach ἄν/ἐάν und im Satz ein "
          "Konjunktiv.",
      SyntaxRules.generalizingRelative,
      implies: const ["clause.relative", "verb.mood.subjunctive"],
    ),
    _lemmas(
      "clause.conditional",
      "clauses",
      "Bedingungssatz (εἰ, ἐάν, κἄν)",
      const ["εἰ", "ἐάν", "κἄν"],
      pattern: const MorphPattern(pos: {"C-"}),
      description:
          "Erkannt an der Konjunktion. εἰ leitet auch indirekte Fragen ein; "
          "auch diese Sätze zählen hier.",
    ),
    _rule(
      "clause.conditional_real",
      "clauses",
      "Realis (εἰ + Indikativ)",
      "εἰ und danach ein Indikativ, ohne ἄν im Satz.",
      SyntaxRules.realCondition,
      implies: const ["clause.conditional", "verb.mood.indicative"],
    ),
    _rule(
      "clause.conditional_eventual",
      "clauses",
      "Eventualis (ἐάν + Konjunktiv)",
      "ἐάν bzw. κἄν und danach ein Konjunktiv.",
      SyntaxRules.eventualCondition,
      implies: const ["clause.conditional", "verb.mood.subjunctive"],
    ),
    _rule(
      "clause.conditional_unreal",
      "clauses",
      "Irrealis (εἰ + Ind. der Vergangenheit … ἄν)",
      "εἰ mit Indikativ Imperfekt/Aorist/Plusquamperfekt und im selben "
          "Satz ἄν mit einem weiteren solchen Indikativ.",
      SyntaxRules.unrealCondition,
      implies: const ["clause.conditional", "verb.mood.indicative"],
    ),
    _rule(
      "clause.conditional_potential",
      "clauses",
      "Potentialis (Optativ + ἄν)",
      "Optativ und ἄν im selben Satzteil.",
      SyntaxRules.potentialOptative,
      implies: const ["verb.mood.optative"],
    ),
    _lemmas(
      "clause.final",
      "clauses",
      "Final- bzw. Inhaltssatz (ἵνα, ὅπως)",
      const ["ἵνα", "ὅπως"],
      pattern: const MorphPattern(pos: {"C-", "D-"}),
      description:
          "Erkannt an der Konjunktion. ἵνα leitet auch Inhalts- und "
          "Folgesätze ein; die Funktion wird nicht unterschieden.",
    ),
    _lemmas(
      "clause.consecutive",
      "clauses",
      "Konsekutivsatz (ὥστε)",
      const ["ὥστε"],
    ),
    _lemmas(
      "clause.causal",
      "clauses",
      "Kausalsatz (ἐπεί, ἐπειδή, διότι, καθότι)",
      const ["ἐπεί", "ἐπειδή", "ἐπειδήπερ", "διότι", "καθότι"],
      description:
          "Erkannt an der Konjunktion. Kausales ὅτι ist nicht von "
          "deklarativem ὅτι zu unterscheiden und zählt nicht.",
    ),
    _lemmas(
      "clause.temporal",
      "clauses",
      "Temporalsatz (ὅτε, ὅταν, ἡνίκα, ἐπάν, πρίν, ἕως als Konjunktion)",
      const ["ὅτε", "ὅταν", "ἡνίκα", "ἐπάν", "πρίν", "ἕως", "ὁπότε"],
      pattern: const MorphPattern(pos: {"C-", "D-"}),
      description:
          "Erkannt an der Konjunktion; ἕως nur, wo es als Konjunktion bestimmt "
          "ist (nicht als Präposition). Temporales ὡς und ἐπεί zählen nicht.",
    ),
    _rule(
      "clause.indirect_speech",
      "clauses",
      "Indirekte Rede mit ὅτι (nach Verb des Sagens/Wahrnehmens)",
      "ὅτι nach einem Verb des Sagens, Wissens oder Wahrnehmens im selben "
          "Satz. Zitierendes ὅτι (recitativum) wird nicht unterschieden.",
      SyntaxRules.thatClauseAfterSpeech,
    ),
    _rule(
      "clause.indirect_question",
      "clauses",
      "Indirekte Frage",
      "Fragewort (τίς, πῶς, ποῦ, πόθεν, πότε, ποῖος, πόσος) nach einem Verb "
          "des Sagens, Wissens oder Fragens in einem Satz ohne Fragezeichen.",
      SyntaxRules.indirectQuestion,
    ),

    // -------------------------------------------------------------------------
    // KONJUNKTIV UND OPTATIV IM SATZ
    // -------------------------------------------------------------------------
    _rule(
      "mood.hortatory",
      "moodSyntax",
      "Adhortativ (1. Pl. Konjunktiv im Hauptsatz)",
      "1. Person Plural Konjunktiv ohne einleitende Konjunktion davor.",
      SyntaxRules.hortatorySubjunctive,
      implies: const ["verb.mood.subjunctive"],
    ),
    _rule(
      "mood.prohibitive",
      "moodSyntax",
      "Prohibitiv (μή + Aorist Konjunktiv)",
      "μή (nicht nach οὐ) und bis zu drei Wörter danach ein Aorist "
          "Konjunktiv der 2. Person.",
      SyntaxRules.prohibitiveSubjunctive,
      implies: const ["verb.mood.subjunctive"],
    ),
    _rule(
      "mood.deliberative",
      "moodSyntax",
      "Deliberativ (Konjunktiv in der Frage)",
      "Konjunktiv der 1. Person in einem Satz mit Fragezeichen, ohne "
          "einleitende Konjunktion davor.",
      SyntaxRules.deliberativeSubjunctive,
      implies: const ["verb.mood.subjunctive"],
    ),
    _rule(
      "mood.wish_optative",
      "moodSyntax",
      "Wunschoptativ (μὴ γένοιτο)",
      "Optativ ohne ἄν und ohne εἰ im Satz.",
      SyntaxRules.wishOptative,
      implies: const ["verb.mood.optative"],
    ),
    GrammarPhenomenon(
      id: "mood.emphatic_negation",
      categoryId: "moodSyntax",
      label: "Verstärkte Verneinung (οὐ μή)",
      description: "οὐ unmittelbar gefolgt von μή.",
      status: PhenomenonStatus.reliable,
      detector: const AdjacentLemmaDetector("οὐ", "μή"),
    ),

    // -------------------------------------------------------------------------
    // NEGATIONEN
    // -------------------------------------------------------------------------
    _lemmas(
      "negation.compound",
      "negation",
      "Zusammengesetzte Negationen (οὐδέ, μηδέ, οὐδείς, μηδείς, οὔτε …)",
      const [
        "οὐδέ",
        "μηδέ",
        "οὐδείς",
        "μηδείς",
        "οὐθείς",
        "μηθείς",
        "οὔτε",
        "μήτε",
        "οὐκέτι",
        "μηκέτι",
        "οὔπω",
        "μήπω",
        "οὐδέποτε",
        "μηδέποτε",
        "οὐδαμῶς",
        "μηδαμῶς",
        "οὐδέπω",
        "μηδέπω",
      ],
    ),

    // -------------------------------------------------------------------------
    // PRÄPOSITIONEN
    // -------------------------------------------------------------------------
    _lemmas(
      "preposition.multi_case",
      "preposition",
      "Präpositionen mit mehreren Kasus (διά, κατά, μετά, περί, ὑπέρ, ὑπό, "
          "παρά, ἐπί, πρός)",
      const [
        "διά",
        "κατά",
        "μετά",
        "περί",
        "ὑπέρ",
        "ὑπό",
        "παρά",
        "ἐπί",
        "πρός",
        "ἀμφί",
      ],
      pattern: MorphPattern.preposition,
    ),

    // -------------------------------------------------------------------------
    // WORTSTELLUNG
    // -------------------------------------------------------------------------
    _rule(
      "wordorder.attributive",
      "wordOrder",
      "Attributive Stellung (ὁ ἀγαθὸς ἄνθρωπος / ὁ ἄνθρωπος ὁ ἀγαθός)",
      "Artikel – Adjektiv – Nomen bzw. Nomen – Artikel – Adjektiv, alle "
          "kongruent und unmittelbar hintereinander.",
      SyntaxRules.attributivePosition,
    ),
    _unavailable(
      "wordorder.predicative",
      "wordOrder",
      "Prädikative Stellung (ἀγαθὸς ὁ ἄνθρωπος)",
      "Ohne Satzanalyse nicht sicher von anderen Stellungen zu trennen.",
    ),
    _unavailable(
      "wordorder.hyperbaton",
      "wordOrder",
      "Sperrung (Hyperbaton)",
      "Erfordert die Zuordnung getrennt stehender Satzglieder; nicht "
          "erkennbar.",
    ),
  ];
}
