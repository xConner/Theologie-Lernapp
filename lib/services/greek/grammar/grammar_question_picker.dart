import 'dart:math';

import '../../../algorithms/grammar_learning.dart';
import '../../../models/greek/grammar/adjective_comparison.dart';
import '../../../models/greek/grammar/pronoun_paradigm.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'adjective_comparisons.dart';

/// Zielbestimmung einer Nomen-Aufgabe in der Schreibweise des Trainers
/// ("Akkusativ", "Sg.", "m").
typedef NounTarget = ({String grammaticalCase, String number, String gender});

/// Zielbestimmung einer Verb-Aufgabe. [person] und [number] in der
/// Schreibweise der Fragegenerierung ("3.", "Pl"), Tempus und Genus Verbi
/// wie im Trainer angezeigt.
typedef VerbTarget = ({
  String person,
  String number,
  String tense,
  String voice,
});

/// Zielbestimmung einer Pronomen-Aufgabe in der Schreibweise des Trainers
/// ("Akkusativ", "Sg.", "m" bzw. [GrammarQuestionPicker.noGender]) samt der
/// anzuzeigenden Form.
typedef PronounTarget = ({
  String grammaticalCase,
  String number,
  String gender,
  String form,
});

/// Aufgabe der Adjektivsteigerung: [direction] ist einer der Werte aus
/// [GrammarQuestionPicker.comparisonDirections], [shown] die angezeigte Form,
/// [note] ein Hinweis darunter (Übersetzung des Positivs, "Neutrum" …),
/// [prompt] die Frage.
typedef ComparisonTarget = ({
  String direction,
  String shown,
  String? note,
  String prompt,
});

/// Fachliche Regeln der Fragegenerierung im Grammatiktrainer: welche Wörter
/// und welche Bestimmungen überhaupt gefragt werden dürfen.
///
/// Die Regeln legen nur die zulässigen Kandidaten fest. Gewichtet wird
/// anschließend ausschließlich über [GrammarLearning]; die Reihenfolge der
/// Zufallsziehungen (Nomen: Kasus, Numerus – Verb: Person, Tempus, Genus
/// Verbi) ist Teil des Verhaltens.
class GrammarQuestionPicker {
  GrammarQuestionPicker._();

  static const List<String> types = ["noun", "verb", "pronoun", "comparison"];

  static const List<String> cases = [
    "Nominativ",
    "Genitiv",
    "Dativ",
    "Akkusativ",
  ];

  static const List<String> numbers = ["Sg.", "Pl."];

  static const List<String> genders = ["m", "f", "n"];

  /// Pronomenarten (`kind` der Paradigmen), einzeln wählbar.
  static const List<String> pronounKinds = [
    "personal",
    "possessive",
    "demonstrative",
    "relative",
    "interrogative",
    "indefinite",
  ];

  /// Steigerungsarten der Adjektivsteigerung, einzeln wählbar.
  static const List<String> comparisonKinds = ["irregular", "regular"];

  static String comparisonKindLabel(String kind) {
    return kind == "irregular" ? "Unregelmäßige" : "Regelmäßige";
  }

  static const String positiveToComparative = "positive-comparative";
  static const String positiveToSuperlative = "positive-superlative";
  static const String comparativeToPositive = "comparative-positive";
  static const String superlativeToPositive = "superlative-positive";
  static const String positiveToBoth = "positive-both";
  static const String comparativeGenitive = "comparative-genitive";

  /// Beschriftung des Eingabefelds.
  static String comparisonAnswerLabel(String direction) {
    switch (direction) {
      case positiveToComparative:
        return "Komparativ";

      case positiveToSuperlative:
        return "Superlativ";

      case positiveToBoth:
        return "Komparativ und Superlativ";

      case comparativeGenitive:
        return "Genitiv Sg. des Komparativs";

      default:
        return "Positiv";
    }
  }

  // Mehrere Formulierungen je Frageart, damit die Fragen nicht immer gleich
  // aussehen.
  static const Map<String, List<String>> _comparisonPrompts = {
    positiveToComparative: ["Komparativ?", "Wie lautet der Komparativ?"],
    positiveToSuperlative: ["Superlativ?", "Wie lautet der Superlativ?"],
    comparativeToPositive: [
      "Positiv?",
      "Welcher Positiv gehört zu diesem Komparativ?",
    ],
    superlativeToPositive: [
      "Positiv?",
      "Welcher Positiv gehört zu diesem Superlativ?",
    ],
    positiveToBoth: ["Komparativ und Superlativ?"],
    comparativeGenitive: ["Genitiv Sg. des Komparativs?"],
  };

  /// Auswahl für Pronomen ohne Genus (ἐγώ, σύ).
  static const String noGender = "–";

  /// Genus-Auswahl bei Pronomen. Sie ist bei jedem Pronomen dieselbe, damit
  /// die Auswahl nicht schon verrät, um welches Pronomen es geht.
  static const List<String> pronounGenders = ["m", "f", "n", noGender];

  /// Person und Numerus, wie der Nutzer sie auswählt.
  static const List<String> personNumbers = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  /// Person und Numerus, wie die Fragegenerierung sie verwendet.
  static const List<String> verbPersonNumbers = [
    "1. Sg",
    "2. Sg",
    "3. Sg",
    "1. Pl",
    "2. Pl",
    "3. Pl",
  ];

  static const List<String> tenses = ["Präsens", "Imperfekt", "Aorist"];

  // "Deponent" ist vorerst nicht wählbar, weil die Deponentien in der
  // Vokabelliste noch nicht vollständig markiert sind. Zum Reaktivieren hier
  // wieder aufnehmen; die Antwortprüfung wertet die Auswahl bereits aus.
  static const List<String> voices = ["Aktiv", "Medium/Passiv"];

  /// Wörter, die im Grammatiktrainer nie gefragt werden.
  static const Set<String> blacklist = {
    "οἶδα",
    "εὐαγγελίζομαι",
    "ἐγείρομαι",
    "ἄρχομαι",
    "πείθομαι",
    "θησαυρίζω",
    "ἐκκόπτω",
    "φοβέομαι",
    "πειράομαι",
    "ἐκπορεύομαι",
    "οἶμαι",
    "καθαρίζομαι",
    "ἐκπλήσσομαι",
    "πορεύομαι",
    "μεταπέμπομαι",
    "σής",
    "βλαβή",
    "ἀββά",
  };

  static const Set<String> activeOnlyVerbs = {
    "εἰμί",
    "ἄπειμι",
    "σύνειμι",
    "ἀσθενέω",
    "μένω",
    "ἐπερωτάω",
    "ἐπιτιμάω",
    "θέλω",
    "βαίνω",
    "χαίρω",
  };

  static const Set<String> presentOnlyVerbs = {"προσεύχομαι"};

  static const Set<String> noAorist = {"εἰμί", "ἄπειμι", "σύνειμι", "ὑποπτεύω"};

  static const Set<String> noImperfect = {"ἐμβαίνω"};

  /// Verben des Aoristblatts: eigene, gleich gewichtete Auswahlgruppe.
  static const Set<String> aoristSheet = {
    "βλέπω",
    "γράφω",
    "πέμπω",
    "νομίζω",
    "πείθω",
    "σῴζω",
    "ἄρχω",
    "πράττω", //Aorist anderes Lemma nehmen
    "τάττω", //Aorist anderes Lemma nehmen
    "φυλάττω", //Aorist anderes Lemma nehmen
    "ἀγγέλλω", //Attischer statt Koine Aorist
    "κρίνω",
    "μένω",
    "ἄγω",
    "βάλλω",
    "γίγνομαι",
    "ἔρχομαι",
    "εὑρίσκω", //Zweite Aorist Tabelle
    "ἔχω",
    "λαμβάνω",
    "λέγω",
    "λείπω", //Normaler statt Koine Aorist
    "μανθάνω",
    "ὁράω",
    "φεύγω",
    "φέρω", //Zweite Aorist Tabelle
    "βαίνω",
    "γιγνώσκω",
  };

  static const String _eimi = "εἰμί";

  /// Ob ein Wort zu den Filtern des Trainers gehört. Pronomen sind eine
  /// eigene Inhaltsgruppe und hängen nicht an den Schritten; gefragt werden
  /// kann nur ein Pronomen, für das ein Paradigma vorliegt
  /// ([pronounIds]). Ebenso die Adjektivsteigerung: gefragt werden die
  /// Adjektive der gewählten Steigerungsarten ([comparisonIds]).
  static bool isAvailable(
    GreekVocabularyEntry entry, {
    required List<int> enabledSteps,
    required List<String> enabledTypes,
    required Set<int> pronounIds,
    Set<int> comparisonIds = const {},
  }) {
    if (!enabledTypes.contains(entry.type) || blacklist.contains(entry.lemma)) {
      return false;
    }

    if (entry.type == "pronoun") {
      return pronounIds.contains(entry.id);
    }

    if (entry.type == AdjectiveComparisons.type) {
      return comparisonIds.contains(entry.id);
    }

    return enabledSteps.contains(entry.step);
  }

  /// Wählt die Grundform der nächsten Frage aus den bereits gefilterten
  /// Wörtern. Fünf Gruppen mit demselben Grundgewicht: alle Wörter, die
  /// Verben des Aoristblatts, εἰμί, die Pronomen und die Adjektivsteigerung
  /// (jeweils soweit verfügbar). Der Lernbedarf verschiebt die Auswahl
  /// zwischen den Gruppen und innerhalb der gewählten Gruppe; bei der
  /// Adjektivsteigerung zählt dort zusätzlich die Priorität des Adjektivs
  /// (unregelmäßige deutlich häufiger).
  static GreekVocabularyEntry pickEntry(
    GrammarLearning grammar,
    List<GreekVocabularyEntry> available,
  ) {
    final aoristSheetVerbs = available.where((entry) {
      return entry.type == "verb" && aoristSheet.contains(entry.lemma);
    }).toList();

    final eimi = available.where((entry) => entry.lemma == _eimi).firstOrNull;

    final pronouns = available.where((entry) {
      return entry.type == "pronoun";
    }).toList();

    final comparisons = available.where((entry) {
      return entry.type == AdjectiveComparisons.type;
    }).toList();

    return grammar.pickFromGroups(
      [
        available,
        if (aoristSheetVerbs.isNotEmpty) aoristSheetVerbs,
        if (eimi != null) [eimi],
        if (pronouns.isNotEmpty) pronouns,
        if (comparisons.isNotEmpty) comparisons,
      ],
      (entry) => GrammarLearning.lemmaId(entry.id),
      weightOf: (entry) {
        return entry.type == AdjectiveComparisons.type ? entry.weight : 1;
      },
    );
  }

  /// Frageart nach Lernbedarf; bei Komparativ → Positiv bzw. Superlativ →
  /// Positiv auch die vorgelegte Form (Maskulinum oder Neutrum, nie eine
  /// seltene Form) nach Lernbedarf, sodass falsch beantwortete Formen
  /// häufiger wiederkommen. Die Formulierung entscheidet der Zufall.
  static ComparisonTarget pickComparisonTarget(
    GrammarLearning grammar,
    AdjectiveComparison comparison,
    Random random,
  ) {
    List<ComparisonForm> shownForms(List<ComparisonForm> forms) {
      return forms.where((form) => !form.rare).toList();
    }

    final comparatives = shownForms(comparison.comparatives);
    final superlatives = shownForms(comparison.superlatives);

    final direction = grammar.pickValue("comparison", "direction", [
      positiveToComparative,
      positiveToSuperlative,
      if (comparatives.isNotEmpty) comparativeToPositive,
      if (superlatives.isNotEmpty) superlativeToPositive,
      positiveToBoth,
      if (comparison.comparativeGenitives.isNotEmpty) comparativeGenitive,
    ]);

    var shown = comparison.positive;
    String? note = comparison.translations.join(", ");

    if (direction == comparativeToPositive ||
        direction == superlativeToPositive) {
      final forms = direction == comparativeToPositive
          ? comparatives
          : superlatives;

      shown = grammar.pickValue("comparison", "form", [
        for (final form in forms) ...form.texts,
      ]);

      final form = forms.firstWhere((form) => form.texts.contains(shown));

      note = shown == form.neuter ? "Neutrum" : form.note;
    }

    final prompts = _comparisonPrompts[direction]!;

    return (
      direction: direction,
      shown: shown,
      note: note,
      prompt: prompts[random.nextInt(prompts.length)],
    );
  }

  /// Genus eines Nomens, bestimmt aus dem Artikel.
  static String genderOf(GreekVocabularyEntry entry) {
    switch (entry.article) {
      case "ἡ":
        return "f";

      case "τό" || "το":
        return "n";

      default:
        return "m";
    }
  }

  static NounTarget pickNounTarget(
    GrammarLearning grammar,
    GreekVocabularyEntry entry,
  ) {
    final grammaticalCase = grammar.pickValue("noun", "case", cases);

    final number = grammar.pickValue("noun", "number", numbers);

    return (
      grammaticalCase: grammaticalCase,
      number: number,
      gender: genderOf(entry),
    );
  }

  /// Kasus, Numerus und – soweit das Pronomen eines hat – Genus werden nach
  /// Lernbedarf gewählt; unter mehreren Formvarianten der Zelle (ἐμοῦ / μου,
  /// τίσι / τίσιν) entscheidet der Zufall. `null`, wenn das Paradigma die
  /// Zelle nicht enthält.
  static PronounTarget? pickPronounTarget(
    GrammarLearning grammar,
    PronounParadigm paradigm,
    Random random,
  ) {
    final grammaticalCase = grammar.pickValue("pronoun", "case", cases);

    final number = grammar.pickValue("pronoun", "number", numbers);

    final paradigmGenders = paradigm.genders;

    final gender = paradigmGenders.isEmpty
        ? null
        : grammar.pickValue("pronoun", "gender", paradigmGenders);

    final cell = paradigm.cell(
      grammaticalCase,
      nounRequestNumber(number),
      gender,
    );

    if (cell == null || cell.forms.isEmpty) {
      return null;
    }

    return (
      grammaticalCase: grammaticalCase,
      number: number,
      gender: gender ?? noGender,
      form: cell.forms[random.nextInt(cell.forms.length)].text,
    );
  }

  /// Für das Verb zulässige Tempora.
  static List<String> allowedTenses(GreekVocabularyEntry entry) {
    if (presentOnlyVerbs.contains(entry.lemma)) {
      return const ["Präsens"];
    }

    if (noAorist.contains(entry.lemma)) {
      return const ["Präsens", "Imperfekt"];
    }

    if (noImperfect.contains(entry.lemma)) {
      return const ["Präsens", "Aorist"];
    }

    return tenses;
  }

  /// Für das Verb zulässige Genera Verbi. Ein Deponens hat nur
  /// mediale/passive Formen.
  static List<String> allowedVoices(GreekVocabularyEntry entry) {
    if (activeOnlyVerbs.contains(entry.lemma)) {
      return const ["Aktiv"];
    }

    if (entry.deponent) {
      return const ["Medium/Passiv"];
    }

    return const ["Aktiv", "Medium/Passiv"];
  }

  /// Erst die für das Verb zulässigen Werte bestimmen, dann gewichten. Steht
  /// nur ein Wert zur Wahl, wird nicht gezogen.
  static VerbTarget pickVerbTarget(
    GrammarLearning grammar,
    GreekVocabularyEntry entry,
  ) {
    final personNumber = grammar
        .pickValue("verb", "person", verbPersonNumbers)
        .split(" ");

    final tenseOptions = allowedTenses(entry);

    final tense = tenseOptions.length == 1
        ? tenseOptions.single
        : grammar.pickValue("verb", "tense", tenseOptions);

    final voiceOptions = allowedVoices(entry);

    final voice = voiceOptions.length == 1
        ? voiceOptions.single
        : grammar.pickValue("verb", "voice", voiceOptions);

    return (
      person: personNumber[0],
      number: personNumber[1],
      tense: tense,
      voice: voice,
    );
  }

  /// "1." → 1; `null` bei ungültiger Angabe.
  static int? parsePerson(String? value) {
    switch (value) {
      case "1.":
        return 1;

      case "2.":
        return 2;

      case "3.":
        return 3;

      default:
        return null;
    }
  }

  /// Numerus eines Nomens in der Schreibweise der Backend-Anfrage.
  static String nounRequestNumber(String? number) {
    return number == "Sg." ? "Sg" : "Pl";
  }
}
