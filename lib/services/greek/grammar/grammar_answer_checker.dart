import '../../../models/greek/grammar_question.dart';

class GrammarCheckResult {
  final bool correct;

  final bool lemmaCorrect;

  final bool caseCorrect;

  final bool numberCorrect;

  final bool genderCorrect;

  GrammarCheckResult({
    required this.correct,

    required this.lemmaCorrect,

    required this.caseCorrect,

    required this.numberCorrect,

    required this.genderCorrect,
  });
}

class GrammarAnswerChecker {
  static GrammarCheckResult check({
    required GrammarQuestion question,

    required String lemmaInput,

    GrammarCase? caseInput,

    GrammarNumber? numberInput,

    GrammarGender? genderInput,

    bool checkCase = true,

    bool checkNumber = true,

    bool checkGender = true,
  }) {
    final lemmaCorrect = normalize(lemmaInput) == normalize(question.lemma);

    final caseCorrect = !checkCase || caseInput == question.grammaticalCase;

    final numberCorrect =
        !checkNumber || numberInput == question.grammaticalNumber;

    final genderCorrect =
        !checkGender || genderInput == question.grammaticalGender;

    return GrammarCheckResult(
      correct: lemmaCorrect && caseCorrect && numberCorrect && genderCorrect,

      lemmaCorrect: lemmaCorrect,

      caseCorrect: caseCorrect,

      numberCorrect: numberCorrect,

      genderCorrect: genderCorrect,
    );
  }

  static String normalize(String value) {
    return value.trim().toLowerCase().replaceAll("ς", "σ");
  }
}
