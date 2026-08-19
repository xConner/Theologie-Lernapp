import 'latin_vocabulary_entry.dart';

class LatinVocabularyQuestion {
  final LatinVocabularyEntry entry;

  /// Wird die zusätzliche Verbform abgefragt?
  final bool checkVerbForm;

  /// Wird die zusätzliche Nomenform (z. B. Genitiv) abgefragt?
  final bool checkNounForm;

  /// Wird das Genus eines Nomens abgefragt?
  final bool checkGender;

  /// Werden bei Adjektiven die Formen für Femininum und Neutrum abgefragt?
  final bool checkAdjectiveForms;

  const LatinVocabularyQuestion({
    required this.entry,
    this.checkVerbForm = true,
    this.checkNounForm = true,
    this.checkGender = true,
    this.checkAdjectiveForms = true,
  });

  bool get hasVerbFormField {
    return entry.type == "verb" && entry.form != null;
  }

  bool get hasNounFormField {
    return entry.type == "noun" && entry.form != null;
  }

  bool get hasAdjectiveFormsField {
    return entry.type == "adjective" && entry.form != null;
  }

  bool get hasGenderField {
    return entry.type == "noun" && checkGender && entry.gender != null;
  }

  bool get hasExtraLatinFields {
    return hasVerbFormField ||
        hasNounFormField ||
        hasGenderField ||
        hasAdjectiveFormsField;
  }
}
