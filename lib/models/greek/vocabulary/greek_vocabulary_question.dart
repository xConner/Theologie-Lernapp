import 'greek_vocabulary_entry.dart';

class VocabularyQuestion {
  final GreekVocabularyEntry entry;

  /// Werden Artikel bei Nomen geprüft?
  final bool checkArticle;

  /// Wird Genitiv bei Nomen geprüft?
  final bool checkGenitive;

  /// Wird Aorist bei Verben geprüft?
  final bool checkAorist;

  VocabularyQuestion({
    required this.entry,

    this.checkArticle = true,

    this.checkGenitive = true,

    this.checkAorist = true,
  });

  bool get hasArticleField {
    return entry.type == "noun" && checkArticle;
  }

  bool get hasGenitiveField {
    return entry.type == "noun" && checkGenitive;
  }

  bool get hasAoristField {
    return entry.type == "verb" && checkAorist;
  }

  bool get hasExtraGreekFields {
    return hasArticleField || hasGenitiveField || hasAoristField;
  }
}
