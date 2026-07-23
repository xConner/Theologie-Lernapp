import '../models/greek/grammar/grammar_question.dart';

class GrammarSettings {
  final List<int> enabledSteps;

  final List<GrammarWordType> enabledWordTypes;

  final bool askLemma;
  final bool askCase;
  final bool askNumber;
  final bool askGender;

  const GrammarSettings({
    required this.enabledSteps,
    required this.enabledWordTypes,
    required this.askLemma,
    required this.askCase,
    required this.askNumber,
    required this.askGender,
  });

  factory GrammarSettings.defaults() {
    return const GrammarSettings(
      enabledSteps: [1, 2, 3, 4],
      enabledWordTypes: [GrammarWordType.noun],
      askLemma: true,
      askCase: true,
      askNumber: true,
      askGender: true,
    );
  }
}
