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

/// [reference] ist die Bestimmung, an der die Antwort gemessen wurde: die
/// mögliche Bestimmung der Form, die der Antwort am nächsten kommt.
typedef PronounAnswerResult = ({
  bool pronounCorrect,
  bool caseCorrect,
  bool numberCorrect,
  bool genderCorrect,
  PronounFormAnalysis reference,
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

/// Prüft die Bestimmung einer Pronominalform.
///
/// [analyses] sind alle für die angezeigte Form möglichen Bestimmungen (aus
/// den lokalen Paradigmen, auch über Pronomen hinweg). Richtig ist die
/// Antwort nur, wenn sie eine davon vollständig trifft; eine Mischung zweier
/// möglicher Bestimmungen bleibt falsch. Die Einzelwertung richtet sich nach
/// der Bestimmung mit den meisten Übereinstimmungen, bei Gleichstand nach
/// der Zielbestimmung [target].
///
/// [userNumber] und [userGender] wie ausgewählt ("Sg.", "m" bzw.
/// [GrammarQuestionPicker.noGender]). Mit `pronounAsked == false` wird das
/// Pronomen selbst nicht gewertet.
PronounAnswerResult checkPronounAnswer({
  required PronounFormAnalysis target,
  required List<PronounFormAnalysis> analyses,
  required bool pronounAsked,
  required int? userPronoun,
  required String? userCase,
  required String? userNumber,
  required String? userGender,
}) {
  final answeredGender = userGender == GrammarQuestionPicker.noGender
      ? null
      : userGender;

  PronounAnswerResult compare(PronounFormAnalysis analysis) {
    return (
      pronounCorrect: !pronounAsked || userPronoun == analysis.pronounId,
      caseCorrect: userCase == analysis.grammaticalCase,
      numberCorrect: userNumber == '${analysis.number}.',
      // Ohne Auswahl ist auch "kein Genus" nicht beantwortet.
      genderCorrect: userGender != null && answeredGender == analysis.gender,
      reference: analysis,
    );
  }

  int score(PronounAnswerResult result) {
    return (result.pronounCorrect ? 1 : 0) +
        (result.caseCorrect ? 1 : 0) +
        (result.numberCorrect ? 1 : 0) +
        (result.genderCorrect ? 1 : 0);
  }

  var best = compare(target);

  for (final analysis in analyses) {
    final result = compare(analysis);

    if (score(result) > score(best)) {
      best = result;
    }
  }

  return best;
}
