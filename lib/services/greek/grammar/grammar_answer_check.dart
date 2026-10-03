import '../../../utils/greek_normalization.dart';
import 'grammar_form_analysis.dart';
import 'grammar_question_picker.dart';

/// Antwortprüfung des Grammatiktrainers, ohne UI und ohne Netzwerk.
///
/// Formal identische Formen (z. B. Nominativ = Akkusativ im Neutrum,
/// 1. Sg. = 3. Pl. im Imperfekt): Jede für die angezeigte Form mögliche
/// Bestimmung (`analyses`, vom Backend geliefert) gilt als richtig. Ohne
/// solche Angaben gilt ausschließlich die Zielbestimmung der Aufgabe.

typedef NounAnswerResult = ({
  bool caseCorrect,
  bool numberCorrect,
  bool genderCorrect,
});

typedef VerbAnswerResult = ({
  bool personCorrect,
  bool tenseCorrect,
  bool voiceCorrect,
});

/// Vergleicht die eingegebene Grundform mit dem Lemma, unabhängig von
/// Akzenten, Spiritus, Längenzeichen, Groß-/Kleinschreibung und Schluss-Sigma.
bool lemmaAnswerMatches(String input, String lemma) {
  final userLemma = normalizeGreekForComparison(input.trim());

  final correctLemma = normalizeGreekForComparison(lemma.trim());

  return userLemma.toLowerCase() == correctLemma.toLowerCase();
}

NounAnswerResult checkNounAnswer({
  required String? targetCase,
  required String? targetNumber,
  required String? targetGender,
  required List<NounFormAnalysis> analyses,
  required String? userCase,
  required String? userNumber,
  required String? userGender,
}) {
  final matchesForm = nounAnswerMatchesForm(
    analyses,
    userCase: userCase,
    userNumber: userNumber,
  );

  return (
    caseCorrect: matchesForm || userCase == targetCase,
    numberCorrect: matchesForm || userNumber == targetNumber,
    // Das Genus hängt am Wort, nicht an der Form.
    genderCorrect: userGender == targetGender,
  );
}

/// [targetPerson] und [targetNumber] in der Schreibweise der
/// Fragegenerierung ("3.", "Pl"), [userPersonNumber] wie ausgewählt
/// ("3. Pl.").
VerbAnswerResult checkVerbAnswer({
  required String? targetPerson,
  required String? targetNumber,
  required String? targetTense,
  required String? targetVoice,
  required bool deponent,
  required List<VerbFormAnalysis> analyses,
  required String? userPersonNumber,
  required String? userTense,
  required String? userVoice,
}) {
  // Ein Deponens hat nur mediale/passive Formen; "Deponent" benennt bei
  // diesen Verben also dieselbe Form wie "Medium/Passiv".
  final answeredVoice = userVoice == "Deponent" && deponent
      ? "Medium/Passiv"
      : userVoice;

  final matchesForm =
      GrammarQuestionPicker.parsePerson(targetPerson) != null &&
      verbAnswerMatchesForm(
        analyses,
        userPersonNumber: userPersonNumber,
        userTense: userTense,
        userVoice: answeredVoice,
      );

  return (
    personCorrect:
        matchesForm || userPersonNumber == "$targetPerson $targetNumber.",
    tenseCorrect: matchesForm || userTense == targetTense,
    voiceCorrect: matchesForm || answeredVoice == targetVoice,
  );
}
