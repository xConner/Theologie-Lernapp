import '../models/greek_vocabulary_entry.dart';

class VocabularyCheckResult {
  final bool correct;

  final bool translationCorrect;
  final bool articleCorrect;
  final bool genitiveCorrect;
  final bool aoristCorrect;

  VocabularyCheckResult({
    required this.correct,
    required this.translationCorrect,
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
  }) {
    // Übersetzungen

    final userTranslations = normalizeTranslations(translationInput);

    final correctTranslations = entry.translations.map(normalize).toList()
      ..sort();

    final translationCorrect = _listsEqual(
      userTranslations,
      correctTranslations,
    );

    // Artikel

    bool articleCorrect = true;

    if (entry.type == "noun" && checkArticle) {
      articleCorrect =
          normalize(articleInput) == normalize(entry.article ?? "");
    }

    // Genitiv

    bool genitiveCorrect = true;

    if (entry.type == "noun" && checkGenitive) {
      genitiveCorrect =
          normalize(genitiveInput) == normalize(entry.genitive ?? "");
    }

    // Aorist

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
      // Alpha
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

      // Epsilon
      "έ": "ε",
      "ὲ": "ε",
      "ἐ": "ε",
      "ἑ": "ε",
      "ἒ": "ε",
      "ἓ": "ε",
      "ἔ": "ε",
      "ἕ": "ε",

      // Eta
      "ή": "η",
      "ὴ": "η",
      "ῆ": "η",
      "ἠ": "η",
      "ἡ": "η",
      "ἤ": "η",
      "ἥ": "η",

      // Iota
      "ί": "ι",
      "ὶ": "ι",
      "ῖ": "ι",
      "ἰ": "ι",
      "ἱ": "ι",
      "ἴ": "ι",
      "ἵ": "ι",

      // Omikron
      "ό": "ο",
      "ὸ": "ο",
      "ὀ": "ο",
      "ὁ": "ο",
      "ὂ": "ο",
      "ὃ": "ο",
      "ὄ": "ο",
      "ὅ": "ο",

      // Ypsilon
      "ύ": "υ",
      "ὺ": "υ",
      "ῦ": "υ",
      "ὐ": "υ",
      "ὑ": "υ",
      "ὔ": "υ",
      "ὕ": "υ",

      // Omega
      "ώ": "ω",
      "ὼ": "ω",
      "ῶ": "ω",
      "ὠ": "ω",
      "ὡ": "ω",
      "ὤ": "ω",
      "ὥ": "ω",

      // Rho
      "ῤ": "ρ",
      "ῥ": "ρ",

      // Sonderzeichen
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
        // kombinierende Akzente und Hauche entfernen
        .replaceAll(RegExp(r'[\u0300-\u036f\u1fbd-\u1fff]'), '')
        // Final-Sigma vereinheitlichen
        .replaceAll("ς", "σ");
  }
}
