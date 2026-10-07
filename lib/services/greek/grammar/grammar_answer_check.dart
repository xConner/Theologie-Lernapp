import '../../../models/greek/grammar/adjective_comparison.dart';
import '../../../utils/greek_normalization.dart';
import 'adjective_comparisons.dart';
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

/// [expected] beschreibt die richtigen Antworten für das Feedback.
typedef ComparisonAnswerResult = ({bool correct, String expected});

/// Prüft eine Antwort der Adjektivsteigerung.
///
/// Die Eingabe darf mehrere Formen enthalten (getrennt durch Leerzeichen,
/// Komma, Schrägstrich, Bindestrich …). Jede eingegebene Form muss zum
/// gefragten Grad gehören – ein Superlativ auf die Frage nach dem Komparativ
/// ist also falsch, jede der Varianten (ἀμείνων, βελτίων, κρείττων,
/// Neutrum ἄμεινον …) dagegen richtig. Bei „Komparativ und Superlativ“ muss
/// mindestens je eine Form beider Grade dabei sein. Verglichen wird wie bei
/// der Grundform ([lemmaAnswerMatches]): unabhängig von Akzenten, Spiritus,
/// Groß-/Kleinschreibung und Schluss-Sigma.
ComparisonAnswerResult checkComparisonAnswer({
  required AdjectiveComparison comparison,
  required ComparisonTarget target,
  required String input,
}) {
  final tokens = input
      .split(RegExp(r'[\s,;/()\-–—→]+'))
      .where((token) => token.isNotEmpty)
      .toList();

  bool matchesAny(String token, Iterable<String> forms) {
    return forms.any((form) => lemmaAnswerMatches(token, form));
  }

  bool allMatch(Iterable<String> forms) {
    return tokens.isNotEmpty &&
        tokens.every((token) => matchesAny(token, forms));
  }

  final comparatives = AdjectiveComparison.allTexts(comparison.comparatives);
  final superlatives = AdjectiveComparison.allTexts(comparison.superlatives);

  switch (target.direction) {
    case GrammarQuestionPicker.positiveToComparative:
      return (
        correct: allMatch(comparatives),
        expected: AdjectiveComparison.describe(comparison.comparatives),
      );

    case GrammarQuestionPicker.positiveToSuperlative:
      return (
        correct: allMatch(superlatives),
        expected: AdjectiveComparison.describe(comparison.superlatives),
      );

    case GrammarQuestionPicker.comparativeToPositive ||
        GrammarQuestionPicker.superlativeToPositive:
      // ἐλάττων gehört zu μικρός und zu ὀλίγος: beide sind richtig.
      final positives = [
        for (final owner in AdjectiveComparisons.ownersOf(
          target.shown,
          superlative:
              target.direction == GrammarQuestionPicker.superlativeToPositive,
        ))
          owner.positive,
      ];

      return (correct: allMatch(positives), expected: positives.join(" / "));

    case GrammarQuestionPicker.positiveToBoth:
      return (
        correct:
            allMatch([...comparatives, ...superlatives]) &&
            tokens.any((token) => matchesAny(token, comparatives)) &&
            tokens.any((token) => matchesAny(token, superlatives)),
        expected:
            "${AdjectiveComparison.describe(comparison.comparatives)} – "
            "${AdjectiveComparison.describe(comparison.superlatives)}",
      );

    default:
      return (
        correct: allMatch(comparison.comparativeGenitives),
        expected: comparison.comparativeGenitives.join(" / "),
      );
  }
}
