import 'grammar_question.dart';

class MorphologyRequest {
  final String lemma;

  final GrammarCase grammaticalCase;

  final GrammarNumber number;

  const MorphologyRequest({
    required this.lemma,
    required this.grammaticalCase,
    required this.number,
  });
}
