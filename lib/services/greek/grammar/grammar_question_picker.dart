import '../../../algorithms/grammar_learning.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';

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

/// Fachliche Regeln der Fragegenerierung im Grammatiktrainer: welche Wörter
/// und welche Bestimmungen überhaupt gefragt werden dürfen.
///
/// Die Regeln legen nur die zulässigen Kandidaten fest. Gewichtet wird
/// anschließend ausschließlich über [GrammarLearning]; die Reihenfolge der
/// Zufallsziehungen (Nomen: Kasus, Numerus – Verb: Person, Tempus, Genus
/// Verbi) ist Teil des Verhaltens.
class GrammarQuestionPicker {
  GrammarQuestionPicker._();

  static const List<String> types = ["noun", "verb"];

  static const List<String> cases = [
    "Nominativ",
    "Genitiv",
    "Dativ",
    "Akkusativ",
  ];

  static const List<String> numbers = ["Sg.", "Pl."];

  static const List<String> genders = ["m", "f", "n"];

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
    "ἀγγέλλω",
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

  /// Wählt die Grundform der nächsten Frage aus den bereits gefilterten
  /// Wörtern. Drei Gruppen mit demselben Grundgewicht: alle Wörter, die
  /// Verben des Aoristblatts und εἰμί (jeweils soweit verfügbar). Der
  /// Lernbedarf verschiebt die Auswahl zwischen den Gruppen und innerhalb
  /// der gewählten Gruppe.
  static GreekVocabularyEntry pickEntry(
    GrammarLearning grammar,
    List<GreekVocabularyEntry> available,
  ) {
    final aoristSheetVerbs = available.where((entry) {
      return entry.type == "verb" && aoristSheet.contains(entry.lemma);
    }).toList();

    final eimi = available.where((entry) => entry.lemma == _eimi).firstOrNull;

    return grammar.pickFromGroups([
      available,
      if (aoristSheetVerbs.isNotEmpty) aoristSheetVerbs,
      if (eimi != null) [eimi],
    ], (entry) => GrammarLearning.lemmaId(entry.id));
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
