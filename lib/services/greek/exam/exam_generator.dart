import 'dart:math';

import '../../../models/greek/exam/exam_config.dart';
import '../../../models/greek/exam/greek_exam.dart';
import '../../../models/greek/exam/passage_ref.dart';
import '../../../models/greek/exam/text_corpus.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'corpus_codec.dart';
import 'exam_corpus_source.dart';
import 'exam_task_types.dart';
import 'grammar_phenomena.dart';
import 'passage_finder.dart';
import 'phenomenon_detection.dart';
import 'vocabulary_help.dart';

/// Ergebnis einer Generierung: Klausur oder begründete Absage.
sealed class ExamOutcome {
  const ExamOutcome();
}

class ExamCreated extends ExamOutcome {
  final GreekExam exam;
  const ExamCreated(this.exam);
}

class ExamNotPossible extends ExamOutcome {
  final PassageDiagnosis diagnosis;

  /// Hinweis, wie viele Abschnitte es ohne Buch- und Korpuseinschränkung
  /// gäbe (`null`, wenn nicht eingeschränkt).
  final int? unrestrictedMatches;

  /// Beim Austausch: Es gibt keinen anderen passenden Text.
  final bool noAlternative;

  const ExamNotPossible(
    this.diagnosis, {
    this.unrestrictedMatches,
    this.noAlternative = false,
  });
}

/// Erstellt Klausuren und tauscht einzelne Aufgaben aus.
///
/// Austausch des Textes erstellt die Aufgaben 2–4 neu (sie beziehen sich
/// auf den Text), mit denselben Aufgabenarten; der Austausch der Verben
/// oder einer der Aufgaben 3/4 lässt alles andere unverändert. Der
/// Bearbeitungsstatus wird hier nie geändert.
class ExamGenerator {
  final ExamCorpusSource source;
  final Random random;

  /// In dieser Sitzung gezeigte Abschnitte; sie werden erst wieder gewählt,
  /// wenn es keine anderen passenden gibt.
  final Set<PassageRef> shown = {};

  ExamGenerator({required this.source, Random? random})
    : random = random ?? Random();

  Future<Map<String, CorpusIndex>> _indexes(Iterable<String> corpusIds) async {
    final available = {for (final c in await source.loadCorpora()) c.id};

    return {
      for (final id in corpusIds)
        if (available.contains(id)) id: await source.loadIndex(id),
    };
  }

  Future<DetectionContext> _detectionContext() async {
    final lexicon = await source.loadLexicon();
    return DetectionContext(declensionOf: (lemma) => lexicon[lemma]?.declension);
  }

  /// Erstellt eine Klausur nach [config].
  Future<ExamOutcome> generate({
    required ExamConfig config,
    required Set<PassageRef> done,
    required List<GreekVocabularyEntry> vocabulary,
    Set<PassageRef> avoid = const {},
    bool alternativeOnly = false,
  }) async {
    final knowledge = VocabularyKnowledge(
      VocabularyMatcher(vocabulary),
      config.knownSteps,
    );

    final finder = PassageFinder(
      indexes: await _indexes(config.corpusIds),
      config: config,
      done: done,
      knowledge: knowledge,
    );

    final result = finder.search();

    if (result.matches.isEmpty) {
      return ExamNotPossible(
        result.diagnosis ?? const PassageDiagnosis(),
        unrestrictedMatches: await _unrestrictedCount(config, done, knowledge),
      );
    }

    var chosen = PassageFinder.pick(
      result.matches,
      random,
      avoid: {...shown, ...avoid},
    );

    if (chosen == null && !alternativeOnly) {
      chosen = PassageFinder.pick(result.matches, random);
    }

    if (chosen == null) {
      return ExamNotPossible(
        result.diagnosis ?? const PassageDiagnosis(),
        noAlternative: true,
      );
    }

    final exam = await _build(
      config: config,
      candidate: chosen,
      matches: result.matches,
      knowledge: knowledge,
    );

    shown.add(chosen.ref);

    return ExamCreated(exam);
  }

  /// Ein anderer Text zu denselben Kriterien. Aufgaben 2–4 werden mit
  /// denselben Aufgabenarten neu erstellt.
  Future<ExamOutcome> replaceText(
    GreekExam exam, {
    required Set<PassageRef> done,
    required List<GreekVocabularyEntry> vocabulary,
  }) {
    // Eine konkret gewählte Stelle lässt sich nicht austauschen.
    final config = exam.config.copyWith(fixedPassage: () => null);

    return generate(
      config: config,
      done: done,
      vocabulary: vocabulary,
      avoid: {exam.passage.ref},
      alternativeOnly: true,
    );
  }

  /// Andere Verbformen aus demselben Text; `null`, wenn es keine anderen
  /// gibt.
  Future<GreekExam?> replaceVerbs(GreekExam exam) async {
    final task = ExamTaskTypes.verbParsing.create(
      ExamTaskContext(
        passage: exam.passage,
        detection: await _detectionContext(),
        count: exam.config.verbCount,
      ),
      random,
      previous: exam.verbs,
    );

    return task == null ? null : exam.copyWith(verbs: task);
  }

  /// Aufgabe 3 ([slot] 0) bzw. 4 ([slot] 1) austauschen: eine andere
  /// Aufgabe derselben Art oder, mit [typeId], eine Aufgabe einer anderen
  /// Art. `null`, wenn der Text keine andere hergibt.
  Future<GreekExam?> replaceExtraTask(
    GreekExam exam,
    int slot, {
    String? typeId,
  }) async {
    final current = exam.extra[slot];
    final type = ExamTaskTypes.byId(typeId ?? current.typeId);
    if (type == null) return null;

    final task = type.create(
      ExamTaskContext(
        passage: exam.passage,
        detection: await _detectionContext(),
      ),
      random,
      previous: type.id == current.typeId ? current : null,
    );

    if (task == null) return null;

    return exam.copyWith(extra: [...exam.extra]..[slot] = task);
  }

  // ---------------------------------------------------------------------------

  Future<int?> _unrestrictedCount(
    ExamConfig config,
    Set<PassageRef> done,
    VocabularyKnowledge knowledge,
  ) async {
    final all = [for (final c in await source.loadCorpora()) c.id];
    final restricted =
        config.bookIds.isNotEmpty ||
        config.fixedPassage != null ||
        !all.every(config.corpusIds.contains);

    if (!restricted) return null;
    if (PassageFinder.contradictionsOf(config).isNotEmpty) return null;

    final broader = PassageFinder(
      indexes: await _indexes(all),
      config: config.copyWith(
        corpusIds: all,
        bookIds: const [],
        chapterFrom: () => null,
        chapterTo: () => null,
        fixedPassage: () => null,
      ),
      done: done,
      knowledge: knowledge,
    );

    return broader.search().matches.length;
  }

  Future<GreekExam> _build({
    required ExamConfig config,
    required PassageCandidate candidate,
    required List<PassageCandidate> matches,
    required VocabularyKnowledge knowledge,
  }) async {
    final ref = candidate.ref;
    final corpora = await source.loadCorpora();
    final corpus = corpora.firstWhere((c) => c.id == ref.corpusId);
    final book = await source.loadBook(ref.corpusId, ref.bookId);
    final lexicon = await source.loadLexicon();
    final detection = DetectionContext(
      declensionOf: (lemma) => lexicon[lemma]?.declension,
    );

    final chapter = book.chapters[ref.chapter - 1];
    final first = chapter.indexWhere((v) => v.label == ref.firstVerse);
    final last = chapter.indexWhere((v) => v.label == ref.lastVerse);

    final passage = ExamPassage(
      ref: ref,
      corpus: corpus,
      verses: chapter.sublist(first, last + 1),
    );

    final selection = PassageSelection(
      matchCount: matches.length,
      startCount: {for (final m in matches) m.startKey}.length,
      fixed: config.fixedPassage != null,
      required: [
        for (final id in config.requiredPhenomena)
          if (GrammarPhenomena.byId(id) case final phenomenon?)
            CriterionEvidence(
              id,
              detectInPassage(
                passage,
                phenomenon,
                DetectionMode.certain,
                detection,
              ),
            ),
      ],
      excluded: config.excludedPhenomena.toList(),
    );

    ExamTask extraTask(String typeId) {
      final type = ExamTaskTypes.byId(typeId);

      return type?.create(
            ExamTaskContext(passage: passage, detection: detection),
            random,
          ) ??
          UnavailableTask(
            typeId,
            "Der Text enthält keine geeigneten Formen für diese Aufgabe.",
          );
    }

    return GreekExam(
      config: config,
      passage: passage,
      selection: selection,
      translation: TranslationTask(
        VocabularyHelpBuilder(knowledge, lexicon).build(passage.tokens),
      ),
      verbs:
          ExamTaskTypes.verbParsing.create(
            ExamTaskContext(
              passage: passage,
              detection: detection,
              count: config.verbCount,
            ),
            random,
          ) ??
          const UnavailableTask(
            "verb_parsing",
            "Der Text enthält keine eindeutig als Verb bestimmten Formen.",
          ),
      extra: [for (final typeId in config.extraTaskTypes) extraTask(typeId)],
    );
  }

  /// Anzeigename einer Textstelle ("Joh 1,1–5 (NT)").
  static String describe(PassageRef ref, TextCorpus? corpus, String bookName) {
    final suffix = corpus == null ? "" : " (${corpus.shortName})";
    return "$bookName ${ref.verseLabel}$suffix";
  }
}
