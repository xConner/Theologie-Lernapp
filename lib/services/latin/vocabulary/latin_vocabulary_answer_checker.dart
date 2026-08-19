import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';

class LatinVocabularyCheckResult {
  final bool correct;

  final bool translationCorrect;
  final bool translationComplete;

  final bool formCorrect;
  final bool genderCorrect;

  LatinVocabularyCheckResult({
    required this.correct,
    required this.translationCorrect,
    required this.translationComplete,
    required this.formCorrect,
    required this.genderCorrect,
  });
}

class LatinVocabularyAnswerChecker {
  static LatinVocabularyCheckResult check({
    required LatinVocabularyEntry entry,

    required String translationInput,

    String formInput = "",

    String genderInput = "",

    bool checkVerbForm = true,

    bool checkNounForm = true,

    bool checkGender = true,

    bool checkAdjectiveForms = true,

    bool requireOnlyOneTranslation = false,
  }) {
    final userTranslations = normalizeTranslations(translationInput);

    final correctTranslations = entry.translations.map(normalize).toList()
      ..sort();

    final exactTranslationMatch = _listsEqual(
      userTranslations,
      correctTranslations,
    );

    final containsOneCorrectTranslation = userTranslations.any(
      (answer) => correctTranslations.contains(answer),
    );

    final translationCorrect = requireOnlyOneTranslation
        ? containsOneCorrectTranslation
        : exactTranslationMatch;

    final translationComplete = exactTranslationMatch;

    bool formCorrect = true;

    // Verben
    if (entry.type == "verb" && checkVerbForm && entry.form != null) {
      formCorrect = normalize(formInput) == normalize(entry.form!);
    }

    // Nomen
    if (entry.type == "noun" && checkNounForm && entry.form != null) {
      formCorrect = normalize(formInput) == normalize(entry.form!);
    }

    // Adjektive
    if (entry.type == "adjective" &&
        checkAdjectiveForms &&
        entry.form != null) {
      formCorrect = normalize(formInput) == normalize(entry.form!);
    }

    bool genderCorrect = true;

    if (entry.type == "noun" && checkGender && entry.gender != null) {
      genderCorrect = normalize(genderInput) == normalize(entry.gender!);
    }

    final correct = translationCorrect && formCorrect && genderCorrect;

    return LatinVocabularyCheckResult(
      correct: correct,
      translationCorrect: translationCorrect,
      translationComplete: translationComplete,
      formCorrect: formCorrect,
      genderCorrect: genderCorrect,
    );
  }

  static List<String> normalizeTranslations(String input) {
    final result = input
        .split(",")
        .map((e) => normalize(e))
        .where((e) => e.isNotEmpty)
        .toList();

    result.sort();

    return result;
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  static String normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(
          RegExp(r'[āēīōūȳăĕĭŏŭ]'),
          (match) => {
            'ā': 'a',
            'ē': 'e',
            'ī': 'i',
            'ō': 'o',
            'ū': 'u',
            'ȳ': 'y',
            'ă': 'a',
            'ĕ': 'e',
            'ĭ': 'i',
            'ŏ': 'o',
            'ŭ': 'u',
          }[match.group(0)]!,
        );
  }
}
