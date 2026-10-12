import '../../../services/greek/exam/corpus_codec.dart';
import '../../../services/greek/exam/vocabulary_help.dart';
import 'corpus_token.dart';
import 'exam_config.dart';
import 'passage_ref.dart';
import 'text_corpus.dart';

/// Der Text einer Klausur: Abschnitt, Verse und Wortformen.
class ExamPassage {
  final PassageRef ref;
  final TextCorpus corpus;
  final List<CorpusVerse> verses;

  ExamPassage({required this.ref, required this.corpus, required this.verses});

  /// Alle Wortformen des Abschnitts; Aufgaben verweisen über den Index in
  /// diese Liste auf eine Form.
  late final List<CorpusToken> tokens = [
    for (final verse in verses) ...verse.tokens,
  ];

  /// Index der ersten Form jedes Verses in [tokens].
  late final List<int> verseOffsets = () {
    final offsets = <int>[];
    var offset = 0;
    for (final verse in verses) {
      offsets.add(offset);
      offset += verse.tokens.length;
    }
    return offsets;
  }();

  int get wordCount => tokens.length;
}

/// Beleg eines geforderten Phänomens im gewählten Text.
class CriterionEvidence {
  final String phenomenonId;

  /// Belegformen (Indizes in [ExamPassage.tokens]).
  final List<int> tokens;

  const CriterionEvidence(this.phenomenonId, this.tokens);
}

/// Nachvollziehbare Angaben zur Textauswahl.
class PassageSelection {
  /// Anzahl der Abschnitte, die alle Kriterien erfüllten.
  final int matchCount;

  /// Anzahl der verschiedenen Anfangsverse darunter.
  final int startCount;

  /// Konkrete Stelle statt automatischer Auswahl.
  final bool fixed;

  final List<CriterionEvidence> required;

  /// Ausgeschlossene Phänomene, deren Fehlen geprüft ist.
  final List<String> excluded;

  const PassageSelection({
    required this.matchCount,
    required this.startCount,
    required this.fixed,
    required this.required,
    required this.excluded,
  });
}

/// Eine Aufgabe der Klausur. Aufgaben sind unveränderlich; ausgetauscht
/// wird die ganze Aufgabe.
sealed class ExamTask {
  const ExamTask();

  /// Aufgabenart (`ExamTaskTypes`).
  String get typeId;
}

/// Aufgabe 1: Übersetzung mit Vokabelhilfen.
class TranslationTask extends ExamTask {
  final List<VocabularyHint> hints;

  const TranslationTask(this.hints);

  @override
  String get typeId => "translation";
}

/// Eine zu bestimmende Form.
class ParsingItem {
  /// Index in [ExamPassage.tokens].
  final int tokenIndex;
  final CorpusToken token;

  /// Bestimmung im Kontext (NT); `null`, wenn nur formal bestimmt.
  final LemmaAnalysis? context;

  /// Alle als richtig geltenden Bestimmungen (Kontext zuerst, dann formal
  /// ebenfalls mögliche).
  final List<LemmaAnalysis> accepted;

  const ParsingItem({
    required this.tokenIndex,
    required this.token,
    required this.context,
    required this.accepted,
  });
}

/// Aufgabe 2: Verbformen bestimmen.
class VerbParsingTask extends ExamTask {
  final List<ParsingItem> items;

  const VerbParsingTask(this.items);

  @override
  String get typeId => "verb_parsing";
}

/// Formen im Text markieren: alle Formen einer Kategorie ("find_forms")
/// oder die Formen einer Konstruktion ("construction_marking").
class FindFormsTask extends ExamTask {
  final String phenomenonId;

  /// Formen, die sicher dazugehören (müssen markiert werden).
  final Set<int> targets;

  /// Formen, deren Markierung nicht als Fehler gilt: nach einer anderen
  /// möglichen Bestimmung zugehörig oder Teil der Konstruktion, ohne
  /// verlangt zu sein (Bezugswort, Artikel, regierendes Verb).
  final Set<int> tolerated;

  /// Arbeitsanweisung; `null` = „alle Formen“ des Phänomens.
  final String? instruction;

  /// Erklärung zu [tolerated] in der Auswertung.
  final String? toleratedNote;

  @override
  final String typeId;

  const FindFormsTask({
    required this.phenomenonId,
    required this.targets,
    required this.tolerated,
    this.instruction,
    this.toleratedNote,
    this.typeId = "find_forms",
  });
}

/// Eine Auswahlfrage zu einer Stelle des Textes.
class ChoiceItem {
  /// Die Form, nach der gefragt ist (Index in [ExamPassage.tokens]).
  final int tokenIndex;

  /// Weitere Formen, die zur Lösung gehören (Bezugswort, regiertes Wort);
  /// sie werden erst mit der Auswertung gezeigt.
  final List<int> related;

  final String question;
  final List<String> options;
  final String answer;

  /// Kurze Begründung der Lösung.
  final String? explanation;

  const ChoiceItem({
    required this.tokenIndex,
    required this.question,
    required this.options,
    required this.answer,
    this.related = const [],
    this.explanation,
  });
}

/// Auswahlfragen zum Text (Konstruktion benennen, Kasus nach Präposition).
class ChoiceTask extends ExamTask {
  @override
  final String typeId;
  final String instruction;
  final List<ChoiceItem> items;

  const ChoiceTask({
    required this.typeId,
    required this.instruction,
    required this.items,
  });
}

/// Nominalformen (Nomen, Adjektive, Pronomen) bestimmen.
class NounParsingTask extends ExamTask {
  final List<ParsingItem> items;

  const NounParsingTask(this.items);

  @override
  String get typeId => "noun_parsing";
}

/// Platzhalter, wenn der Text für eine Aufgabenart nichts hergibt.
class UnavailableTask extends ExamTask {
  @override
  final String typeId;
  final String reason;

  const UnavailableTask(this.typeId, this.reason);
}

/// Eine generierte Übungsklausur.
class GreekExam {
  final ExamConfig config;
  final ExamPassage passage;
  final PassageSelection selection;
  final TranslationTask translation;
  final ExamTask verbs;

  /// Aufgaben 3 und 4.
  final List<ExamTask> extra;

  const GreekExam({
    required this.config,
    required this.passage,
    required this.selection,
    required this.translation,
    required this.verbs,
    required this.extra,
  });

  GreekExam copyWith({ExamTask? verbs, List<ExamTask>? extra}) {
    return GreekExam(
      config: config,
      passage: passage,
      selection: selection,
      translation: translation,
      verbs: verbs ?? this.verbs,
      extra: extra ?? this.extra,
    );
  }
}
