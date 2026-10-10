import '../vocabulary/vocabulary_answer_checker.dart';
import '../../../utils/greek_normalization.dart';
import 'adjective_comparisons.dart';
import 'grammar_form_analysis.dart';
import 'grammar_question_picker.dart';
import 'verb_paradigm.dart';

/// Antwortprüfung des Grammatiktrainers, ohne UI und ohne Netzwerk.
///
/// Formal identische Formen (z. B. Nominativ = Akkusativ im Neutrum,
/// 1. Sg. = 3. Pl. im Imperfekt): Jede für die angezeigte Form mögliche
/// Bestimmung (`analyses`) gilt als richtig. Ohne solche Angaben gilt
/// ausschließlich die Zielbestimmung der Aufgabe.

typedef NounAnswerResult = ({
  bool caseCorrect,
  bool numberCorrect,
  bool genderCorrect,
});

/// Einzelergebnisse einer Verbaufgabe. [reference] ist die Bestimmung, an
/// der die Antwort gemessen wurde: die mögliche Bestimmung der Form, die der
/// Antwort am nächsten kommt. Bei einer finiten Form ist [personCorrect]
/// gesetzt, bei einem Partizip stattdessen Kasus, Numerus und Genus; die
/// jeweils anderen sind `null`.
typedef VerbAnswerResult = ({
  bool moodCorrect,
  bool tenseCorrect,
  bool voiceCorrect,
  bool? personCorrect,
  bool? caseCorrect,
  bool? numberCorrect,
  bool? genderCorrect,
  bool correct,
  VerbAnalysis reference,
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

/// Ob die Auswahl [userVoice] das Genus Verbi [voice] einer Form trifft.
/// "Medium/Passiv" (Präsens, Imperfekt) ist als Medium wie als Passiv
/// richtig bestimmt. Ein Deponens hat kein Aktiv; "Deponent" benennt bei
/// diesen Verben also jede ihrer Formen.
bool verbVoiceMatches(
  String? userVoice,
  String voice, {
  required bool deponent,
}) {
  if (userVoice == "Deponent") {
    return deponent && voice != "Aktiv";
  }

  return userVoice == voice ||
      (voice == "Medium/Passiv" &&
          (userVoice == "Medium" || userVoice == "Passiv"));
}

/// Prüft die Bestimmung einer Verbform.
///
/// [analyses] sind alle für die angezeigte Form möglichen Bestimmungen (aus
/// dem Paradigma des Verbs, auch über Modi hinweg: παυόντων ist Imperativ
/// und Partizip). Richtig ist die Antwort nur, wenn sie eine davon
/// vollständig trifft; eine Mischung zweier möglicher Bestimmungen bleibt
/// falsch. Die Einzelwertung richtet sich nach der Bestimmung mit den
/// meisten Übereinstimmungen, bei Gleichstand nach der Zielbestimmung
/// [target].
///
/// Die Antwort in der Schreibweise der Auswahl: [userPersonNumber] "3. Pl.",
/// [userNumber] "Sg.". Person und Numerus zählen nur bei finiten Formen,
/// Kasus, Numerus und Genus nur beim Partizip.
VerbAnswerResult checkVerbAnswer({
  required VerbAnalysis target,
  required List<VerbAnalysis> analyses,
  required bool deponent,
  required String? userMood,
  required String? userTense,
  required String? userVoice,
  String? userPersonNumber,
  String? userCase,
  String? userNumber,
  String? userGender,
}) {
  VerbAnswerResult compare(VerbAnalysis analysis) {
    final participle = analysis.mood == VerbMood.participle;

    final moodCorrect = userMood == analysis.mood;
    final tenseCorrect = userTense == analysis.tense;
    final voiceCorrect = verbVoiceMatches(
      userVoice,
      analysis.voice,
      deponent: deponent,
    );

    final personCorrect = participle
        ? null
        : userPersonNumber == "${analysis.person}. ${analysis.number}.";
    final caseCorrect = participle
        ? userCase == analysis.grammaticalCase
        : null;
    final numberCorrect = participle
        ? userNumber == "${analysis.number}."
        : null;
    final genderCorrect = participle ? userGender == analysis.gender : null;

    return (
      moodCorrect: moodCorrect,
      tenseCorrect: tenseCorrect,
      voiceCorrect: voiceCorrect,
      personCorrect: personCorrect,
      caseCorrect: caseCorrect,
      numberCorrect: numberCorrect,
      genderCorrect: genderCorrect,
      correct:
          moodCorrect &&
          tenseCorrect &&
          voiceCorrect &&
          personCorrect != false &&
          caseCorrect != false &&
          numberCorrect != false &&
          genderCorrect != false,
      reference: analysis,
    );
  }

  // Anteil statt Anzahl: Partizipien haben mehr Bestimmungsstücke als
  // finite Formen.
  double score(VerbAnswerResult result) {
    final parts = [
      result.moodCorrect,
      result.tenseCorrect,
      result.voiceCorrect,
      ?result.personCorrect,
      ?result.caseCorrect,
      ?result.numberCorrect,
      ?result.genderCorrect,
    ];

    return parts.where((part) => part).length / parts.length;
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

/// Einzelergebnisse; `null` = nicht gefragt. [reference] ist die mögliche
/// Bestimmung der Form, an der Stufe, Kasus, Numerus und Genus gemessen
/// wurden; `null`, wenn die Form unbekannt ist.
typedef ComparisonAnswerResult = ({
  bool? lemmaCorrect,
  bool? translationCorrect,
  bool? degreeCorrect,
  bool? caseCorrect,
  bool? numberCorrect,
  bool? genderCorrect,
  bool correct,
  ComparisonAnalysis? reference,
});

/// Prüft eine Antwort der Adjektivsteigerung: Zur angezeigten gesteigerten
/// Form [shown] werden Grundform (Positiv) und/oder deutsche Übersetzung der
/// Grundform gefragt; `null` heißt „nicht gefragt“.
///
/// Gehört die Form zu mehreren Adjektiven (ἐλάττων: μικρός und ὀλίγος),
/// zählt jedes davon. Die Grundform wird wie sonst im Grammatiktrainer
/// verglichen ([lemmaAnswerMatches]: unabhängig von Akzenten, Spiritus,
/// Groß-/Kleinschreibung und Schluss-Sigma), die Übersetzung wie im
/// Vokabeltrainer ([VocabularyAnswerChecker.normalize]); mehrere durch
/// Komma getrennte Übersetzungen sind erlaubt, eine richtige genügt.
///
/// Mit [degreeAsked] zählt die Steigerungsstufe ([userDegree]), mit
/// [formAsked] zählen Kasus, Numerus ("Sg.") und Genus der flektierten
/// Form. Jede für die Form mögliche Bestimmung gilt (σοφωτέρου: Maskulinum
/// und Neutrum), aber nur als Ganzes; gewertet wird die Bestimmung mit den
/// meisten Übereinstimmungen.
ComparisonAnswerResult checkComparisonAnswer({
  required String shown,
  String? lemmaInput,
  String? translationInput,
  bool degreeAsked = false,
  bool formAsked = false,
  String? userDegree,
  String? userCase,
  String? userNumber,
  String? userGender,
}) {
  final owners = AdjectiveComparisons.ownersOf(shown);

  ({
    bool? degreeCorrect,
    bool? caseCorrect,
    bool? numberCorrect,
    bool? genderCorrect,
    ComparisonAnalysis? reference,
  })
  compare(ComparisonAnalysis? analysis) {
    // Formen ohne Deklination (ἥκιστα) haben nur eine Stufe.
    final declined = formAsked && analysis?.grammaticalCase != null;

    return (
      degreeCorrect: degreeAsked ? userDegree == analysis?.degree : null,
      caseCorrect: declined ? userCase == analysis?.grammaticalCase : null,
      numberCorrect: declined ? userNumber == "${analysis?.number}." : null,
      genderCorrect: declined ? userGender == analysis?.gender : null,
      reference: analysis,
    );
  }

  final analyses = AdjectiveComparisons.analysesOf(shown);

  var form = compare(analyses.firstOrNull);

  int score(
    ({
      bool? degreeCorrect,
      bool? caseCorrect,
      bool? numberCorrect,
      bool? genderCorrect,
      ComparisonAnalysis? reference,
    })
    result,
  ) {
    return [
      result.degreeCorrect,
      result.caseCorrect,
      result.numberCorrect,
      result.genderCorrect,
    ].where((part) => part == true).length;
  }

  for (final analysis in analyses.skip(1)) {
    final result = compare(analysis);

    if (score(result) > score(form)) {
      form = result;
    }
  }

  bool? lemmaCorrect;

  if (lemmaInput != null) {
    final tokens = lemmaInput
        .split(RegExp(r'[\s,;/()]+'))
        .where((token) => token.isNotEmpty)
        .toList();

    lemmaCorrect =
        tokens.isNotEmpty &&
        tokens.every((token) {
          return owners.any(
            (owner) => lemmaAnswerMatches(token, owner.positive),
          );
        });
  }

  bool? translationCorrect;

  if (translationInput != null) {
    final accepted = {
      for (final owner in owners)
        for (final translation in owner.translations)
          VocabularyAnswerChecker.normalize(translation),
    };

    translationCorrect = translationInput
        .split(RegExp(r'[,;/]'))
        .map(VocabularyAnswerChecker.normalize)
        .any(accepted.contains);
  }

  return (
    lemmaCorrect: lemmaCorrect,
    translationCorrect: translationCorrect,
    degreeCorrect: form.degreeCorrect,
    caseCorrect: form.caseCorrect,
    numberCorrect: form.numberCorrect,
    genderCorrect: form.genderCorrect,
    correct:
        owners.isNotEmpty &&
        (lemmaCorrect != null || translationCorrect != null) &&
        lemmaCorrect != false &&
        translationCorrect != false &&
        form.degreeCorrect != false &&
        form.caseCorrect != false &&
        form.numberCorrect != false &&
        form.genderCorrect != false,
    reference: form.reference,
  );
}
