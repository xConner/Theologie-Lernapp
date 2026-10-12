import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/exam/greek_exam.dart';
import '../../../models/greek/exam/greek_morph_analysis.dart';
import '../grammar/grammar_answer_check.dart';

/// Eingabe einer Formbestimmung in der Schreibweise der Auswahl
/// (wie im Grammatiktrainer: "3. Sg.", "Sg.", "m").
class ParsingAnswer {
  final String lemma;
  final String? mood;
  final String? tense;
  final String? voice;
  final String? personNumber;
  final String? grammaticalCase;
  final String? number;
  final String? gender;

  const ParsingAnswer({
    this.lemma = "",
    this.mood,
    this.tense,
    this.voice,
    this.personNumber,
    this.grammaticalCase,
    this.number,
    this.gender,
  });
}

/// Bestimmungsstücke einer Formbestimmung.
enum ParsingField {
  lemma,
  mood,
  tense,
  voice,
  personNumber,
  grammaticalCase,
  number,
  gender,
}

/// Ergebnis einer Formbestimmung. [fields] enthält nur die für die
/// Vergleichsbestimmung [reference] relevanten Felder.
class ParsingResult {
  final bool correct;
  final Map<ParsingField, bool> fields;

  /// Die Bestimmung, an der die Antwort gemessen wurde: die mögliche
  /// Bestimmung mit den meisten Übereinstimmungen, bei Gleichstand die des
  /// Kontexts.
  final LemmaAnalysis reference;

  /// Die richtige Antwort trifft eine formal mögliche Bestimmung, die im
  /// Kontext nicht vorliegt.
  final bool onlyFormallyPossible;

  /// Weitere Bestimmungen, die für die Form gelten.
  final List<LemmaAnalysis> alsoPossible;

  const ParsingResult({
    required this.correct,
    required this.fields,
    required this.reference,
    required this.onlyFormallyPossible,
    required this.alsoPossible,
  });
}

/// Antwortprüfung des Klausurerstellers, ohne UI.
///
/// Jede für die Form mögliche Bestimmung ([ParsingItem.accepted]) gilt
/// als richtig, aber nur als Ganzes (Grundform und alle Bestimmungsstücke
/// derselben Bestimmung); eine Mischung zweier Bestimmungen bleibt falsch.
/// Grundform und Genus Verbi werden wie im Grammatiktrainer verglichen
/// (`lemmaAnswerMatches`, `verbVoiceMatches`).
class ExamAnswerCheck {
  ExamAnswerCheck._();

  /// Felder, die bei der Bestimmung [a] einer Verbform gefragt sind.
  static List<ParsingField> verbFieldsOf(GreekMorphAnalysis a) => [
    ParsingField.lemma,
    ParsingField.mood,
    ParsingField.tense,
    ParsingField.voice,
    if (a.isFinite) ParsingField.personNumber,
    if (a.isParticiple) ...[
      ParsingField.grammaticalCase,
      ParsingField.number,
      ParsingField.gender,
    ],
  ];

  /// Felder einer Nominalform: Grundform, Kasus, Numerus, Genus (soweit die
  /// Bestimmung ein Genus hat).
  static List<ParsingField> nominalFieldsOf(GreekMorphAnalysis a) => [
    ParsingField.lemma,
    ParsingField.grammaticalCase,
    ParsingField.number,
    if (a.gender != "-") ParsingField.gender,
  ];

  static Map<ParsingField, bool> _compare(
    LemmaAnalysis reading,
    ParsingAnswer answer,
    List<ParsingField> fields,
  ) {
    final a = reading.analysis;

    bool check(ParsingField field) => switch (field) {
      ParsingField.lemma => lemmaAnswerMatches(answer.lemma, reading.lemma),
      ParsingField.mood => answer.mood == GreekMorphAnalysis.moodLabels[a.mood],
      ParsingField.tense =>
        answer.tense == GreekMorphAnalysis.tenseLabels[a.tense],
      ParsingField.voice =>
        a.voiceLabel != null &&
            verbVoiceMatches(answer.voice, a.voiceLabel!, deponent: false),
      ParsingField.personNumber =>
        answer.personNumber ==
            "${a.person}. ${GreekMorphAnalysis.numberLabels[a.number]}.",
      ParsingField.grammaticalCase =>
        answer.grammaticalCase == GreekMorphAnalysis.caseLabels[a.grammaticalCase],
      ParsingField.number =>
        answer.number == "${GreekMorphAnalysis.numberLabels[a.number]}.",
      ParsingField.gender =>
        answer.gender == GreekMorphAnalysis.genderLabels[a.gender],
    };

    return {for (final field in fields) field: check(field)};
  }

  static ParsingResult _best(
    ParsingItem item,
    ParsingAnswer answer,
    List<ParsingField> Function(GreekMorphAnalysis) fieldsOf,
  ) {
    ParsingResult? best;
    double bestScore = -1;

    for (final reading in item.accepted) {
      final fields = _compare(reading, answer, fieldsOf(reading.analysis));
      final hits = fields.values.where((ok) => ok).length;
      final score = fields.isEmpty ? 0.0 : hits / fields.length;

      // Bei Gleichstand bleibt die frühere Bestimmung (Kontext zuerst).
      if (score > bestScore) {
        bestScore = score;
        best = ParsingResult(
          correct: hits == fields.length,
          fields: fields,
          reference: reading,
          onlyFormallyPossible:
              item.context != null && reading != item.context,
          alsoPossible: const [],
        );
      }
    }

    final result = best!;

    return ParsingResult(
      correct: result.correct,
      fields: result.fields,
      reference: result.reference,
      onlyFormallyPossible: result.onlyFormallyPossible,
      alsoPossible: [
        for (final r in item.accepted)
          if (r != result.reference) r,
      ],
    );
  }

  static ParsingResult checkVerb(ParsingItem item, ParsingAnswer answer) =>
      _best(item, answer, verbFieldsOf);

  static ParsingResult checkNominal(ParsingItem item, ParsingAnswer answer) =>
      _best(item, answer, nominalFieldsOf);

  /// Ergebnis der Aufgabe „Formen finden“.
  static ({Set<int> found, Set<int> missed, Set<int> wrong}) checkFindForms(
    FindFormsTask task,
    Set<int> selected,
  ) {
    return (
      found: selected.intersection(task.targets),
      missed: task.targets.difference(selected),
      wrong: selected.difference(task.targets).difference(task.tolerated),
    );
  }
}
