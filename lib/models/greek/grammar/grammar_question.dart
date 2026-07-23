enum GrammarWordType { noun, adjective, verb, pronoun, article }

enum GrammarCase { nominative, genitive, dative, accusative }

enum GrammarNumber { singular, plural }

enum GrammarGender { masculine, feminine, neuter }

class GrammarQuestion {
  final String surfaceForm;
  final String lemma;

  final GrammarWordType wordType;

  final GrammarCase? grammaticalCase;
  final GrammarNumber? grammaticalNumber;
  final GrammarGender? grammaticalGender;

  const GrammarQuestion({
    required this.surfaceForm,
    required this.lemma,
    required this.wordType,
    this.grammaticalCase,
    this.grammaticalNumber,
    this.grammaticalGender,
  });
}
