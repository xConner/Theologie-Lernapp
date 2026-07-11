import '../models/greek_vocabulary_entry.dart';

class VocabularyAnswerChecker {
  static bool check({
    required GreekVocabularyEntry entry,

    required String translationInput,

    String articleInput = "",

    String genitiveInput = "",

    String aoristInput = "",

    bool checkArticle = true,

    bool checkGenitive = true,

    bool checkAorist = true,
  }) {
    // Übersetzungen prüfen

    final userTranslations = normalizeTranslations(translationInput);

    final correctTranslations = entry.translations.map(normalize).toList()
      ..sort();

    if (!_listsEqual(userTranslations, correctTranslations)) {
      return false;
    }

    // Nomen

    if (entry.type == "noun") {
      if (checkArticle) {
        if (normalize(articleInput) != normalize(entry.article ?? "")) {
          return false;
        }
      }

      if (checkGenitive) {
        if (normalize(genitiveInput) != normalize(entry.genitive ?? "")) {
          return false;
        }
      }
    }

    // Verben

    if (entry.type == "verb" && checkAorist) {
      if (normalize(aoristInput) != normalize(entry.aorist ?? "")) {
        return false;
      }
    }

    return true;
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
        // Final-Sigma
        .replaceAll("ς", "σ")
        // Griechische Akzente entfernen
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        // häufige Varianten
        .replaceAll("ϐ", "β")
        .replaceAll("ϑ", "θ")
        .replaceAll("ϕ", "φ")
        .replaceAll("ϖ", "π");
  }
}
