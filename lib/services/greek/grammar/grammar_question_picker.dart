import 'dart:math';

import '../../../algorithms/grammar_learning.dart';
import '../../../models/greek/grammar/adjective_comparison.dart';
import '../../../models/greek/grammar/pronoun_paradigm.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'adjective_comparisons.dart';
import 'greek_declension.dart';
import 'verb_paradigm.dart';

/// Zielbestimmung einer Nomen-Aufgabe in der Schreibweise des Trainers
/// ("Akkusativ", "Sg.", "m").
typedef NounTarget = ({String grammaticalCase, String number, String gender});

/// Zielbestimmung einer Pronomen-Aufgabe in der Schreibweise des Trainers
/// ("Akkusativ", "Sg.", "m" bzw. [GrammarQuestionPicker.noGender]) samt der
/// anzuzeigenden Form.
typedef PronounTarget = ({
  String grammaticalCase,
  String number,
  String gender,
  String form,
});

/// Aufgabe der Adjektivsteigerung: die angezeigte Form [shown] und ein
/// Hinweis darunter ([note]: "Neutrum", "Adv.", "Gen. Sg."). Gefragt werden
/// Grundform und/oder Übersetzung des Positivs, die Steigerungsstufe
/// ([degree]) und – bei einer flektierten Form – Kasus, Numerus und Genus.
///
/// [base] ist die Tabellenform, zu der [shown] gehört (σοφώτερος zu
/// σοφωτέρου). Kasus, Numerus ("Sg.") und Genus sind `null`, wenn die Form
/// nicht bestimmt werden soll.
typedef ComparisonTarget = ({
  String shown,
  String? note,
  String base,
  String degree,
  String? grammaticalCase,
  String? number,
  String? gender,
});

/// Fachliche Regeln der Fragegenerierung im Grammatiktrainer: welche Wörter
/// und welche Bestimmungen überhaupt gefragt werden dürfen.
///
/// Die Regeln legen nur die zulässigen Kandidaten fest. Gewichtet wird
/// anschließend ausschließlich über [GrammarLearning]; die Reihenfolge der
/// Zufallsziehungen (Nomen: Kasus, Numerus – Verb: Modus, Tempus, Genus
/// Verbi, dann Person bzw. Kasus, Numerus, Genus) ist Teil des Verhaltens.
class GrammarQuestionPicker {
  GrammarQuestionPicker._();

  static const List<String> types = ["noun", "verb", "pronoun", "comparison"];

  static const List<String> cases = declensionCases;

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

  /// Person und Numerus des Imperativs: Eine 1. Person gibt es nicht.
  static const List<String> imperativePersonNumbers = [
    "2. Sg.",
    "3. Sg.",
    "2. Pl.",
    "3. Pl.",
  ];

  static const List<String> tenses = ["Präsens", "Imperfekt", "Aorist"];

  /// Modi der Verbaufgaben, einzeln wählbar.
  static const List<String> moods = VerbMood.all;

  /// Tempora, in denen es den Modus [mood] gibt: Imperativ, Infinitiv und
  /// Partizip kennen kein Imperfekt. Ohne Modus alle Tempora.
  static List<String> tensesOfMood(String? mood) {
    return mood == null || mood == VerbMood.indicative
        ? tenses
        : const ["Präsens", "Aorist"];
  }

  /// Person und Numerus, die im Modus [mood] zur Wahl stehen.
  static List<String> personNumbersOfMood(String? mood) {
    return mood == VerbMood.imperative
        ? imperativePersonNumbers
        : personNumbers;
  }

  /// Ob im Modus [mood] Person und Numerus bestimmt werden (finite Formen).
  /// Ohne gewählten Modus steht das Feld noch nicht zur Wahl, damit es den
  /// Modus der Lösung nicht verrät.
  static bool asksPersonNumber(String? mood) {
    return mood == VerbMood.indicative || mood == VerbMood.imperative;
  }

  /// Ob im Modus [mood] Kasus, Numerus und Genus bestimmt werden (Partizip).
  static bool asksCaseNumberGender(String? mood) {
    return mood == VerbMood.participle;
  }

  // Genera Verbi, wie der Nutzer sie auswählt. Im Präsens und Imperfekt
  // sind Medium und Passiv formgleich ("Medium/Passiv"); dort gelten beide.
  //
  // "Deponent" ist vorerst nicht wählbar, weil die Deponentien in der
  // Vokabelliste noch nicht vollständig markiert sind. Zum Reaktivieren hier
  // wieder aufnehmen; die Antwortprüfung wertet die Auswahl bereits aus.
  static const List<String> voices = ["Aktiv", "Medium", "Passiv"];

  /// Steigerungsstufen der Adjektivsteigerung.
  static const List<String> degrees = AdjectiveComparisons.degrees;

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

  /// Eine beliebige gesteigerte Form des Adjektivs (Komparativ, Superlativ,
  /// Neutrum, Genitiv des Komparativs – nie eine seltene Form), gewählt nach
  /// Lernbedarf: falsch beantwortete Formen kommen häufiger wieder.
  ///
  /// Mit [inflected] wird stattdessen eine flektierte Form vorgelegt: erst
  /// die Steigerungsstufe (der Positiv seltener, und nur wo er sich nach der
  /// a-/o-Deklination bilden lässt), dann die Tabellenform, dann Kasus,
  /// Numerus und Genus. Formen ohne Deklination (ἥκιστα) bleiben, wie sie
  /// sind.
  static ComparisonTarget pickComparisonTarget(
    GrammarLearning grammar,
    AdjectiveComparison comparison, {
    bool inflected = false,
  }) {
    if (!inflected) {
      final forms = comparison.shownForms;

      final shown = grammar.pickValue("comparison", "form", [
        for (final form in forms) form.text,
      ]);

      return (
        shown: shown,
        note: forms.firstWhere((form) => form.text == shown).note,
        base: shown,
        degree: AdjectiveComparisons.degreeOf(comparison, shown),
        grammaticalCase: null,
        number: null,
        gender: null,
      );
    }

    final bases = AdjectiveComparisons.basesOf(comparison);

    final degree = grammar.pickValue(
      "comparison",
      "degree",
      [
        for (final degree in degrees)
          if (bases.any((base) => base.degree == degree)) degree,
      ],
      weightOf: (degree) {
        return degree == AdjectiveComparisons.positive ? 0.4 : 1;
      },
    );

    final text = grammar.pickValue("comparison", "form", [
      for (final base in bases)
        if (base.degree == degree) base.text,
    ]);

    final base = bases.firstWhere((base) => base.text == text);
    final paradigm = base.paradigm;

    if (paradigm == null) {
      return (
        shown: text,
        note: base.note,
        base: text,
        degree: degree,
        grammaticalCase: null,
        number: null,
        gender: null,
      );
    }

    final grammaticalCase = grammar.pickValue("comparison", "case", cases);
    final number = grammar.pickValue("comparison", "number", numbers);
    final gender = grammar.pickValue("comparison", "gender", genders);

    return (
      shown: paradigm.form(grammaticalCase, nounRequestNumber(number), gender)!,
      note: null,
      base: text,
      degree: degree,
      grammaticalCase: grammaticalCase,
      number: number,
      gender: gender,
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

  /// Für das Verb im Tempus [tense] und Modus [mood] zulässige Genera
  /// Verbi, soweit das Paradigma sie enthält.
  ///
  /// Im Präsens und Imperfekt Aktiv und Medium/Passiv, im Aorist Aktiv und
  /// Medium. Das Aorist Passiv gehört nur beim Infinitiv zum Lernstoff
  /// (παυθῆναι). Ein Deponens hat kein Aktiv – im Aorist steht deshalb die
  /// Form, die es tatsächlich bildet: Medium (ἐγενόμην), sonst Passiv
  /// (ἐβουλήθην), sonst Aktiv (ἦλθον).
  static List<String> allowedVoices(
    GreekVocabularyEntry entry,
    String tense,
    VerbParadigm paradigm, {
    String mood = VerbMood.indicative,
  }) {
    final existing = {
      for (final form in paradigm.forms)
        if (form.analysis.tense == tense &&
            form.analysis.mood == VerbMood.indicative)
          form.analysis.voice,
    };

    if (activeOnlyVerbs.contains(entry.lemma)) {
      return [if (existing.contains("Aktiv")) "Aktiv"];
    }

    if (!entry.deponent) {
      return [
        for (final voice in const ["Aktiv", "Medium/Passiv", "Medium"])
          if (existing.contains(voice)) voice,
        if (mood == VerbMood.infinitive && existing.contains("Passiv"))
          "Passiv",
      ];
    }

    if (tense != "Aorist") {
      return [if (existing.contains("Medium/Passiv")) "Medium/Passiv"];
    }

    for (final voice in const ["Medium", "Passiv", "Aktiv"]) {
      if (existing.contains(voice)) {
        return [voice];
      }
    }

    return const [];
  }

  /// Ob die Form zum Lernstoff des Verbs gehört: Tempus und Genus Verbi
  /// zulässig, Modus eingeschaltet. Das Aorist Passiv wird nur im Indikativ
  /// (Deponentien) und im Infinitiv gefragt.
  static bool isAskable(
    GreekVocabularyEntry entry,
    VerbParadigm paradigm,
    VerbAnalysis analysis, {
    List<String> enabledMoods = moods,
  }) {
    return enabledMoods.contains(analysis.mood) &&
        allowedTenses(entry).contains(analysis.tense) &&
        allowedVoices(
          entry,
          analysis.tense,
          paradigm,
          mood: analysis.mood,
        ).contains(analysis.voice) &&
        (analysis.voice != "Passiv" ||
            analysis.mood == VerbMood.indicative ||
            analysis.mood == VerbMood.infinitive);
  }

  /// Wählt die Form einer Verbaufgabe aus dem Paradigma: nur Formen, die es
  /// dort gibt und die zum Lernstoff gehören ([isAskable]). Erst die
  /// zulässigen Werte bestimmen, dann gewichten; steht nur ein Wert zur
  /// Wahl, wird nicht gezogen. `null`, wenn keine Form in Frage kommt.
  static VerbForm? pickVerbTarget(
    GrammarLearning grammar,
    GreekVocabularyEntry entry,
    VerbParadigm paradigm, {
    List<String> enabledMoods = moods,
  }) {
    var candidates = [
      for (final form in paradigm.forms)
        if (isAskable(
          entry,
          paradigm,
          form.analysis,
          enabledMoods: enabledMoods,
        ))
          form,
    ];

    if (candidates.isEmpty) {
      return null;
    }

    // Schränkt die Kandidaten auf einen nach Lernbedarf gewählten Wert der
    // Dimension ein. [order] legt die Reihenfolge der Werte fest.
    void narrow(
      String type,
      String dimension,
      List<String> order,
      String Function(VerbAnalysis) valueOf,
    ) {
      final options = [
        for (final value in order)
          if (candidates.any((form) => valueOf(form.analysis) == value)) value,
      ];

      final picked = options.length == 1
          ? options.single
          : grammar.pickValue(type, dimension, options);

      candidates = [
        for (final form in candidates)
          if (valueOf(form.analysis) == picked) form,
      ];
    }

    narrow("verb", "mood", moods, (analysis) => analysis.mood);
    narrow("verb", "tense", tenses, (analysis) => analysis.tense);
    narrow("verb", "voice", const [
      "Aktiv",
      "Medium/Passiv",
      "Medium",
      "Passiv",
    ], (analysis) => analysis.voice);

    if (candidates.first.analysis.mood == VerbMood.participle) {
      narrow(
        "participle",
        "case",
        cases,
        (analysis) => analysis.grammaticalCase!,
      );
      narrow(
        "participle",
        "number",
        numbers,
        (analysis) => "${analysis.number}.",
      );
      narrow("participle", "gender", genders, (analysis) => analysis.gender!);
    } else if (candidates.first.analysis.person != null) {
      narrow(
        "verb",
        "person",
        verbPersonNumbers,
        (analysis) => "${analysis.person}. ${analysis.number}",
      );
    }

    return candidates.first;
  }

  /// Numerus eines Nomens in der Schreibweise der Backend-Anfrage.
  static String nounRequestNumber(String? number) {
    return number == "Sg." ? "Sg" : "Pl";
  }
}
