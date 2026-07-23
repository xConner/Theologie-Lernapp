import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';

class VocabularyCheckResult {
  final bool correct;

  final bool translationCorrect;

  // Zeigt an, ob die Übersetzung vollständig dem Muster entspricht.
  // Wird nur für Feedback benutzt.
  final bool translationComplete;

  final bool articleCorrect;
  final bool genitiveCorrect;
  final bool aoristCorrect;

  VocabularyCheckResult({
    required this.correct,
    required this.translationCorrect,
    required this.translationComplete,
    required this.articleCorrect,
    required this.genitiveCorrect,
    required this.aoristCorrect,
  });
}

class VocabularyAnswerChecker {
  static VocabularyCheckResult check({
    required GreekVocabularyEntry entry,

    required String translationInput,

    String articleInput = "",

    String genitiveInput = "",

    String aoristInput = "",

    bool checkArticle = true,

    bool checkGenitive = true,

    bool checkAorist = true,

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

    bool articleCorrect = true;

    if (entry.type == "noun" && checkArticle) {
      articleCorrect =
          normalize(articleInput) == normalize(entry.article ?? "");
    }

    bool genitiveCorrect = true;

    if (entry.type == "noun" && checkGenitive) {
      genitiveCorrect =
          normalize(genitiveInput) == normalize(entry.genitive ?? "");
    }

    bool aoristCorrect = true;

    if (entry.type == "verb" && checkAorist) {
      aoristCorrect = normalize(aoristInput) == normalize(entry.aorist ?? "");
    }

    final correct =
        translationCorrect &&
        articleCorrect &&
        genitiveCorrect &&
        aoristCorrect;

    return VocabularyCheckResult(
      correct: correct,

      translationCorrect: translationCorrect,

      translationComplete: translationComplete,

      articleCorrect: articleCorrect,

      genitiveCorrect: genitiveCorrect,

      aoristCorrect: aoristCorrect,
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
    const Map<String, String> greekNormalization = {
      "ά": "α",
      "ὰ": "α",
      "ᾶ": "α",
      "ἀ": "α",
      "ἁ": "α",
      "ἂ": "α",
      "ἃ": "α",
      "ἄ": "α",
      "ἅ": "α",
      "ἆ": "α",
      "ἇ": "α",

      "έ": "ε",
      "ὲ": "ε",
      "ἐ": "ε",
      "ἑ": "ε",
      "ἒ": "ε",
      "ἓ": "ε",
      "ἔ": "ε",
      "ἕ": "ε",

      "ή": "η",
      "ὴ": "η",
      "ῆ": "η",
      "ἠ": "η",
      "ἡ": "η",
      "ἤ": "η",
      "ἥ": "η",

      "ί": "ι",
      "ὶ": "ι",
      "ῖ": "ι",
      "ἰ": "ι",
      "ἱ": "ι",
      "ἴ": "ι",
      "ἵ": "ι",

      "ό": "ο",
      "ὸ": "ο",
      "ὀ": "ο",
      "ὁ": "ο",
      "ὂ": "ο",
      "ὃ": "ο",
      "ὄ": "ο",
      "ὅ": "ο",

      "ύ": "υ",
      "ὺ": "υ",
      "ῦ": "υ",
      "ὐ": "υ",
      "ὑ": "υ",
      "ὔ": "υ",
      "ὕ": "υ",

      "ώ": "ω",
      "ὼ": "ω",
      "ῶ": "ω",
      "ὠ": "ω",
      "ὡ": "ω",
      "ὤ": "ω",
      "ὥ": "ω",

      "ῤ": "ρ",
      "ῥ": "ρ",

      "ϐ": "β",
      "ϑ": "θ",
      "ϕ": "φ",
      "ϖ": "π",
    };

    return value
        .toLowerCase()
        .trim()
        .split("")
        .map((char) => greekNormalization[char] ?? char)
        .join()
        .replaceAll(RegExp(r'[\u0300-\u036f\u1fbd-\u1fff]'), '')
        .replaceAll("ς", "σ");
  }
}
