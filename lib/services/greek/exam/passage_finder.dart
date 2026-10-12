import 'dart:math';

import '../../../models/greek/exam/exam_config.dart';
import '../../../models/greek/exam/passage_ref.dart';
import 'corpus_codec.dart';
import 'grammar_phenomena.dart';
import 'vocabulary_help.dart';

/// Ein möglicher Textabschnitt mit den Angaben aus dem Korpusindex.
class PassageCandidate {
  final PassageRef ref;
  final int wordCount;
  final PhenomenonSet certain;
  final PhenomenonSet possible;
  final int unanalyzed;

  /// Obergrenze der Vokabelhilfen (unbekannte Grundformen + unbestimmte
  /// Formen); `null`, wenn nicht berechnet.
  final int? hints;

  const PassageCandidate({
    required this.ref,
    required this.wordCount,
    required this.certain,
    required this.possible,
    required this.unanalyzed,
    this.hints,
  });

  /// Abschnitte mit demselben Anfang (für die gleichmäßige Auswahl).
  String get startKey =>
      "${ref.corpusId}:${ref.bookId}.${ref.chapter}.${ref.firstVerse}";
}

/// Art einer Bedingung der Textsuche.
enum ConstraintKind {
  /// Wortzahl zwischen Mindest- und Höchstlänge.
  length,

  /// Phänomen muss sicher belegt sein.
  required,

  /// Phänomen darf nicht einmal möglich sein.
  excluded,

  /// Für Ausschlüsse muss jedes Wort bestimmt sein.
  completeAnalysis,

  /// Abschnitt (oder ein überlappender) ist als bearbeitet markiert.
  notDone,

  /// Höchstzahl der Vokabelhilfen.
  hints,
}

class SearchConstraint {
  final ConstraintKind kind;
  final String? phenomenonId;

  const SearchConstraint(this.kind, [this.phenomenonId]);

  String get label {
    final phenomenon = phenomenonId == null
        ? null
        : GrammarPhenomena.byId(phenomenonId!);

    return switch (kind) {
      ConstraintKind.length => "Textlänge",
      ConstraintKind.required => "„${phenomenon?.label}“ erforderlich",
      ConstraintKind.excluded => "„${phenomenon?.label}“ ausgeschlossen",
      ConstraintKind.completeAnalysis => "vollständig bestimmte Wörter",
      ConstraintKind.notDone => "bearbeitete Texte ausschließen",
      ConstraintKind.hints => "höchstens so viele Vokabelhilfen",
    };
  }
}

/// Logisch unvereinbare Anforderungen (unabhängig von den Texten).
class Contradiction {
  final String message;
  const Contradiction(this.message);
}

/// Ein Hinweis, welche Lockerung zu Treffern führen würde.
class DiagnosisSuggestion {
  final SearchConstraint? constraint;

  /// Abschnitte, die nur an dieser Bedingung scheitern.
  final int count;

  final String message;

  const DiagnosisSuggestion(this.constraint, this.count, this.message);
}

/// Warum keine Texte gefunden wurden – aus den Daten ermittelt.
class PassageDiagnosis {
  final List<Contradiction> contradictions;
  final List<DiagnosisSuggestion> suggestions;

  /// Erforderliche Phänomene, die in den gewählten Texten (bei dieser
  /// Länge) überhaupt nicht sicher belegt sind.
  final List<String> neverRequired;

  /// Die Länge der Abschnitte, die alle übrigen Bedingungen erfüllen.
  final int? longestOtherwiseMatching;
  final int? shortestOtherwiseMatching;

  /// Prüfung einer konkret gewählten Stelle: die verfehlten Bedingungen.
  final List<SearchConstraint> failedForFixedPassage;

  const PassageDiagnosis({
    this.contradictions = const [],
    this.suggestions = const [],
    this.neverRequired = const [],
    this.longestOtherwiseMatching,
    this.shortestOtherwiseMatching,
    this.failedForFixedPassage = const [],
  });
}

class PassageSearchResult {
  final List<PassageCandidate> matches;
  final PassageDiagnosis? diagnosis;

  const PassageSearchResult(this.matches, [this.diagnosis]);
}

/// Sucht Textabschnitte, die zur Klausurkonfiguration passen.
///
/// Abschnitte sind zusammenhängende Verse eines Kapitels, die mit einem
/// Satz bzw. Absatz beginnen und mit einem Satzende enden. Geprüft wird
/// allein der Korpusindex (je Vers sicher und möglicherweise belegte
/// Phänomene); die Texte selbst werden erst für den gewählten Abschnitt
/// geladen.
class PassageFinder {
  /// Ausgewählte Korpora mit ihrem Index.
  final Map<String, CorpusIndex> indexes;
  final ExamConfig config;
  final Set<PassageRef> done;
  final VocabularyKnowledge? knowledge;

  PassageFinder({
    required this.indexes,
    required this.config,
    this.done = const {},
    this.knowledge,
  });

  // ---------------------------------------------------------------------------
  // BEDINGUNGEN
  // ---------------------------------------------------------------------------

  late final List<SearchConstraint> constraints = [
    const SearchConstraint(ConstraintKind.length),
    for (final id in config.requiredPhenomena)
      SearchConstraint(ConstraintKind.required, id),
    for (final id in config.excludedPhenomena)
      SearchConstraint(ConstraintKind.excluded, id),
    if (config.excludedPhenomena.isNotEmpty)
      const SearchConstraint(ConstraintKind.completeAnalysis),
    if (config.excludeDone && done.isNotEmpty)
      const SearchConstraint(ConstraintKind.notDone),
    if (config.maxHints != null && knowledge != null)
      const SearchConstraint(ConstraintKind.hints),
  ];

  /// Logisch unvereinbare Anforderungen: ein gefordertes Phänomen setzt ein
  /// ausgeschlossenes voraus, oder alle Werte einer Verbkategorie sind
  /// ausgeschlossen, obwohl eine Verbform gefordert ist.
  static List<Contradiction> contradictionsOf(ExamConfig config) {
    final result = <Contradiction>[];
    final excluded = config.excludedPhenomena.toSet();

    Set<String> closure(String id) {
      final seen = <String>{};
      final stack = [id];

      while (stack.isNotEmpty) {
        final next = stack.removeLast();
        if (!seen.add(next)) continue;
        stack.addAll(GrammarPhenomena.byId(next)?.implies ?? const []);
      }

      return seen..remove(id);
    }

    var requiresVerb = false;

    for (final id in config.requiredPhenomena) {
      final phenomenon = GrammarPhenomena.byId(id);
      if (phenomenon == null) continue;

      final implied = closure(id);

      for (final other in implied.intersection(excluded)) {
        result.add(
          Contradiction(
            "„${phenomenon.label}“ ist erforderlich, setzt aber "
            "„${GrammarPhenomena.byId(other)?.label}“ voraus, das "
            "ausgeschlossen ist.",
          ),
        );
      }

      // Verlangt das Phänomen eine Verbform? (Es selbst oder etwas, das es
      // voraussetzt, gehört zu Modus, Tempus oder Genus Verbi, oder es ist
      // eine Verbkategorie.)
      bool isVerbal(String p) {
        final category = GrammarPhenomena.category(
          GrammarPhenomena.byId(p)?.categoryId ?? "",
        );
        return (category?.partitionsVerbs ?? false) ||
            p.startsWith("verb.") ||
            p.startsWith("participle.");
      }

      if (isVerbal(id) || implied.any(isVerbal)) requiresVerb = true;
    }

    for (final category in GrammarPhenomena.categories) {
      if (!category.partitionsVerbs) continue;

      final members = GrammarPhenomena.inCategory(category.id);

      if (members.every((p) => excluded.contains(p.id)) && requiresVerb) {
        result.add(
          Contradiction(
            "In „${category.label}“ sind alle Werte ausgeschlossen, es wird "
            "aber eine Verbform verlangt.",
          ),
        );
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // ABSCHNITTE
  // ---------------------------------------------------------------------------

  bool _bookAllowed(String bookId) =>
      config.bookIds.isEmpty || config.bookIds.contains(bookId);

  bool _chapterAllowed(int chapter) {
    if (config.bookIds.length != 1) return true;
    final from = config.chapterFrom;
    final to = config.chapterTo;
    return (from == null || chapter >= from) && (to == null || chapter <= to);
  }

  final Map<String, List<int>> _lemmaHintFlags = {};

  /// Je Grundform des Index: 1 = braucht eine Hilfe, 0 = bekannt (auch
  /// vorausgesetzte Funktionswörter und gängige Eigennamen), -1 = sonstiger
  /// Eigenname (zählt nicht als Schwierigkeit).
  List<int> _hintFlags(CorpusIndex index) {
    return _lemmaHintFlags.putIfAbsent(index.corpusId, () {
      final k = knowledge!;
      return [
        for (final lemma in index.lemmas)
          k.isKnown(lemma)
              ? 0
              : (VocabularyHelpBuilder.isCapitalized(lemma) ? -1 : 1),
      ];
    });
  }

  final Expando<List<String>> _unknownGroups = Expando();

  /// Grundformgruppen des Verses, die eine Vokabelhilfe brauchen.
  List<String> _unknownOf(CorpusIndex index, VerseInfo verse) {
    return _unknownGroups[verse] ??= () {
      final flags = _hintFlags(index);
      return [
        for (final group in verse.lemmaGroups)
          if (!group.any((id) => flags[id] == 0) &&
              !group.every((id) => flags[id] == -1))
            CorpusCodec.encodeInts(group),
      ];
    }();
  }

  int _hintCount(CorpusIndex index, Iterable<VerseInfo> verses) {
    final unknown = <String>{};
    var unanalyzed = 0;

    for (final verse in verses) {
      unanalyzed += verse.unanalyzed;
      unknown.addAll(_unknownOf(index, verse));
    }

    return unknown.length + unanalyzed;
  }

  /// Alle satzgerechten Abschnitte mit [minWords]…[maxWords] Wörtern in den
  /// gewählten Büchern und Kapiteln.
  Iterable<PassageCandidate> windows({
    required int minWords,
    required int maxWords,
    bool withHints = false,
  }) sync* {
    for (final MapEntry(key: corpusId, value: index) in indexes.entries) {
      for (final book in index.books) {
        if (!_bookAllowed(book.id)) continue;

        for (final chapter in book.chapters) {
          if (!_chapterAllowed(chapter.number)) continue;

          final verses = chapter.verses;

          for (var s = 0; s < verses.length; s++) {
            final startsSentence =
                s == 0 || verses[s - 1].endsSentence || verses[s].paragraphStart;
            if (!startsSentence) continue;

            var words = 0;
            var certain = PhenomenonSet.empty;
            var possible = PhenomenonSet.empty;
            var unanalyzed = 0;
            final unknown = <String>{};

            for (var e = s; e < verses.length; e++) {
              final verse = verses[e];
              words += verse.wordCount;
              if (words > maxWords) break;

              certain = certain.union(verse.certain);
              possible = possible.union(verse.possible);
              unanalyzed += verse.unanalyzed;
              if (withHints) unknown.addAll(_unknownOf(index, verse));

              final endsSentence =
                  verse.endsSentence || e == verses.length - 1;

              if (words >= minWords && endsSentence) {
                yield PassageCandidate(
                  ref: PassageRef(
                    corpusId: corpusId,
                    bookId: book.id,
                    chapter: chapter.number,
                    firstVerse: verses[s].label,
                    lastVerse: verse.label,
                  ),
                  wordCount: words,
                  certain: certain,
                  possible: possible,
                  unanalyzed: unanalyzed,
                  hints: withHints ? unknown.length + unanalyzed : null,
                );
              }
            }
          }
        }
      }
    }
  }

  /// Der Abschnitt einer konkret gewählten Stelle; `null`, wenn es die
  /// Verse im Index nicht gibt.
  PassageCandidate? candidateFor(PassageRef ref, {bool withHints = false}) {
    final index = indexes[ref.corpusId];
    final book = index?.book(ref.bookId);
    if (index == null || book == null) return null;
    if (ref.chapter < 1 || ref.chapter > book.chapters.length) return null;

    final verses = book.chapters[ref.chapter - 1].verses;
    final first = verses.indexWhere((v) => v.label == ref.firstVerse);
    final last = verses.indexWhere((v) => v.label == ref.lastVerse);
    if (first < 0 || last < first) return null;

    final range = verses.sublist(first, last + 1);

    return PassageCandidate(
      ref: ref,
      wordCount: range.fold(0, (sum, v) => sum + v.wordCount),
      certain: range.fold(PhenomenonSet.empty, (s, v) => s.union(v.certain)),
      possible: range.fold(PhenomenonSet.empty, (s, v) => s.union(v.possible)),
      unanalyzed: range.fold(0, (sum, v) => sum + v.unanalyzed),
      hints: withHints ? _hintCount(index, range) : null,
    );
  }

  /// Bedingungen, die der Abschnitt verfehlt (Indizes in [constraints]).
  List<int> failures(PassageCandidate c, {bool checkLength = true}) {
    final failed = <int>[];
    final index = indexes[c.ref.corpusId]!;

    for (var i = 0; i < constraints.length; i++) {
      final constraint = constraints[i];
      final bit = constraint.phenomenonId == null
          ? null
          : index.bitOf(constraint.phenomenonId!);

      final ok = switch (constraint.kind) {
        ConstraintKind.length =>
          !checkLength ||
              (c.wordCount >= config.minWords &&
                  c.wordCount <= config.maxWords),
        // Nicht im Index erfasst: weder belegbar noch ausschließbar.
        ConstraintKind.required => bit != null && c.certain.contains(bit),
        ConstraintKind.excluded => bit != null && !c.possible.contains(bit),
        ConstraintKind.completeAnalysis => c.unanalyzed == 0,
        ConstraintKind.notDone => !done.any(c.ref.overlaps),
        ConstraintKind.hints =>
          c.hints == null || c.hints! <= config.maxHints!,
      };

      if (!ok) failed.add(i);
    }

    return failed;
  }

  bool get _needsHints => constraints.any((c) => c.kind == ConstraintKind.hints);

  // ---------------------------------------------------------------------------
  // SUCHE
  // ---------------------------------------------------------------------------

  PassageSearchResult search() {
    final contradictions = contradictionsOf(config);

    if (contradictions.isNotEmpty) {
      return PassageSearchResult(
        const [],
        PassageDiagnosis(contradictions: contradictions),
      );
    }

    final fixed = config.fixedPassage == null
        ? null
        : PassageRef.tryParse(config.fixedPassage!);

    if (fixed != null) {
      final candidate = candidateFor(fixed, withHints: _needsHints);

      if (candidate == null) {
        return const PassageSearchResult(
          [],
          PassageDiagnosis(
            suggestions: [
              DiagnosisSuggestion(
                null,
                0,
                "Die gewählte Stelle gibt es in diesem Text nicht.",
              ),
            ],
          ),
        );
      }

      final failed = failures(candidate, checkLength: false);

      if (failed.isEmpty) return PassageSearchResult([candidate]);

      return PassageSearchResult(
        const [],
        PassageDiagnosis(
          failedForFixedPassage: [for (final i in failed) constraints[i]],
        ),
      );
    }

    final matches = [
      for (final c in windows(
        minWords: config.minWords,
        maxWords: config.maxWords,
        withHints: _needsHints,
      ))
        if (failures(c).isEmpty) c,
    ];

    if (matches.isNotEmpty) return PassageSearchResult(matches);

    return PassageSearchResult(const [], diagnose());
  }

  /// Ermittelt aus den Daten, woran die Suche scheitert: welche einzelne
  /// Bedingung die meisten Abschnitte verhindert, ob geforderte Phänomene
  /// überhaupt belegt sind und welche Länge möglich wäre.
  PassageDiagnosis diagnose() {
    final onlyFailing = List<int>.filled(constraints.length, 0);
    final satisfiedInRange = List<int>.filled(constraints.length, 0);
    int? longest;
    int? shortest;

    final lengthIndex = constraints.indexWhere(
      (c) => c.kind == ConstraintKind.length,
    );

    for (final c in windows(
      minWords: 1,
      maxWords: max(ExamConfig.highestWords, config.maxWords) + 100,
      withHints: _needsHints,
    )) {
      final failed = failures(c);
      final inRange = !failed.contains(lengthIndex);

      if (inRange) {
        for (var i = 0; i < constraints.length; i++) {
          if (!failed.contains(i)) satisfiedInRange[i]++;
        }
      }

      if (failed.length == 1) onlyFailing[failed.single]++;

      if (failed.isEmpty || (failed.length == 1 && failed.single == lengthIndex)) {
        longest = max(longest ?? 0, c.wordCount);
        shortest = min(shortest ?? 1 << 30, c.wordCount);
      }
    }

    final suggestions = <DiagnosisSuggestion>[];

    for (var i = 0; i < constraints.length; i++) {
      final count = onlyFailing[i];
      if (count == 0) continue;

      final constraint = constraints[i];
      final message = switch (constraint.kind) {
        ConstraintKind.length =>
          longest != null && longest < config.minWords
              ? "Mindestlänge verringern: Der längste Abschnitt, der alle "
                    "übrigen Kriterien erfüllt, hat $longest Wörter."
              : "Höchstlänge erhöhen: Der kürzeste Abschnitt, der alle "
                    "übrigen Kriterien erfüllt, hat $shortest Wörter.",
        ConstraintKind.required =>
          "Ohne die Bedingung ${constraint.label} gäbe es $count passende "
              "Abschnitte.",
        ConstraintKind.excluded =>
          "Wenn ${GrammarPhenomena.byId(constraint.phenomenonId!)?.label} "
              "wieder erlaubt ist, gäbe es $count passende Abschnitte.",
        ConstraintKind.completeAnalysis =>
          "$count Abschnitte erfüllen alle Kriterien, enthalten aber Wörter "
              "ohne Bestimmung. Ausgeschlossene Phänomene lassen sich dort "
              "nicht sicher ausschließen (vor allem Septuaginta). Weniger "
              "Ausschlüsse oder das Neue Testament wählen.",
        ConstraintKind.notDone =>
          "$count bereits bearbeitete Abschnitte würden passen. Bearbeitete "
              "Texte wieder zulassen.",
        ConstraintKind.hints =>
          "Mit mehr erlaubten Vokabelhilfen gäbe es $count passende "
              "Abschnitte (oder mehr Lernschritte als bekannt wählen).",
      };

      suggestions.add(DiagnosisSuggestion(constraint, count, message));
    }

    suggestions.sort((a, b) => b.count.compareTo(a.count));

    final neverRequired = [
      for (var i = 0; i < constraints.length; i++)
        if (constraints[i].kind == ConstraintKind.required &&
            satisfiedInRange[i] == 0)
          constraints[i].phenomenonId!,
    ];

    return PassageDiagnosis(
      suggestions: suggestions,
      neverRequired: neverRequired,
      longestOtherwiseMatching: longest,
      shortestOtherwiseMatching: shortest,
    );
  }

  // ---------------------------------------------------------------------------
  // AUSWAHL
  // ---------------------------------------------------------------------------

  /// Wählt einen Abschnitt: gleichverteilt über alle Anfangsverse mit
  /// mindestens einem passenden Abschnitt, dann über deren Abschnitte. So
  /// werden lange Bücher nicht übergewichtet, kurze Abschnitte nicht
  /// bevorzugt und keine Stelle systematisch vorgezogen. Abschnitte aus
  /// [avoid] (in dieser Sitzung schon gezeigt oder die aktuelle Klausur)
  /// kommen nur in Frage, wenn es keine anderen gibt.
  static PassageCandidate? pick(
    List<PassageCandidate> matches,
    Random random, {
    Set<PassageRef> avoid = const {},
  }) {
    if (matches.isEmpty) return null;

    var pool = matches.where((c) => !avoid.any(c.ref.overlaps)).toList();
    if (pool.isEmpty) pool = matches.where((c) => !avoid.contains(c.ref)).toList();
    if (pool.isEmpty) return null;

    final byStart = <String, List<PassageCandidate>>{};
    for (final c in pool) {
      byStart.putIfAbsent(c.startKey, () => []).add(c);
    }

    final starts = byStart.keys.toList();
    final group = byStart[starts[random.nextInt(starts.length)]]!;

    return group[random.nextInt(group.length)];
  }
}
