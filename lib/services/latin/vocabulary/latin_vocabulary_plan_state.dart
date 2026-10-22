import 'dart:math';

import '../../../algorithms/daily_new_plan.dart';
import '../../../algorithms/learning_selector.dart';
import '../../../algorithms/review_state.dart';
import '../../../algorithms/spaced_repetition.dart';
import '../../../models/greek/vocabulary/learning_card.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_plan.dart';
import 'latin_vocabulary_plan_store.dart';

/// Alles, was der Latein-Lernplan zur Anzeige und Planung braucht:
/// Vokabeln, die gemeinsamen Karten mit dem Vokabeltrainer, der Plan und
/// die Einführungen.
///
/// Status ohne eigene Stufen: „Neu“ heißt noch nicht eingeführt, alle
/// übrigen Vokabeln haben den [ReviewState] der Wissensbereiche („Zum
/// Wiederholen“, „Zuletzt sicher“). Eine Vokabel gilt als eingeführt, wenn
/// sie im Plan vorgestellt oder (z. B. im freien Vokabeltrainer) schon
/// einmal beantwortet wurde – vorhandene Lernstände werden so übernommen.
class LatinVocabularyPlanState {
  /// Alle Vokabeln in Lehrbuchreihenfolge (Lektion, dann ID).
  final List<LatinVocabularyEntry> entries;

  /// Karten des Vokabeltrainers (Schlüssel: Vokabel-ID als Text).
  final Map<String, LearningCard> cards;

  final LatinVocabularyPlanData data;

  final DateTime Function() clock;

  final SpacedRepetition algorithm;

  LatinVocabularyPlanState({
    required List<LatinVocabularyEntry> entries,
    required this.cards,
    required this.data,
    DateTime Function()? clock,
  }) : entries = [...entries]
         ..sort(
           (a, b) => a.lesson != b.lesson
               ? a.lesson.compareTo(b.lesson)
               : a.id.compareTo(b.id),
         ),
       clock = clock ?? DateTime.now,
       algorithm = SpacedRepetition(clock: clock);

  DateTime get now => clock();

  LatinVocabularyPlan? get plan => data.plan;

  /// Alle Lektionen der Vokabelliste (aufsteigend).
  List<int> get lessons =>
      entries.map((e) => e.lesson).toSet().toList()..sort();

  /// Lektionen des Plans (ohne Plan: alle).
  List<int> get planLessons => [
    for (final lesson in lessons)
      if (plan?.includesLesson(lesson) ?? true) lesson,
  ];

  /// Vokabeln des Plans in Lehrbuchreihenfolge.
  List<LatinVocabularyEntry> get scope {
    final included = planLessons.toSet();

    return [
      for (final e in entries)
        if (included.contains(e.lesson)) e,
    ];
  }

  List<LatinVocabularyEntry> entriesOfLesson(int lesson) => [
    for (final e in entries)
      if (e.lesson == lesson) e,
  ];

  static String idOf(LatinVocabularyEntry entry) => entry.id.toString();

  LearningCard? cardOf(LatinVocabularyEntry entry) => cards[idOf(entry)];

  /// Die Karte zum Verbuchen (dieselbe wie im Vokabeltrainer).
  LearningCard cardFor(LatinVocabularyEntry entry) {
    final id = idOf(entry);

    return cards.putIfAbsent(id, () => LearningCard(id: id));
  }

  /// Die Karte, nach der das Auswahlverfahren gewichtet (wird nicht
  /// gespeichert).
  LearningCard selectionCardOf(LatinVocabularyEntry entry) =>
      cardOf(entry) ?? LearningCard(id: idOf(entry));

  bool isIntroduced(LatinVocabularyEntry entry) =>
      data.introduced.containsKey(entry.id) ||
      cardOf(entry)?.lastReviewed != null;

  /// [ReviewState.fresh]: noch nicht eingeführt. Eingeführt, aber noch nie
  /// abgefragt: zum Wiederholen.
  ReviewState statusOf(LatinVocabularyEntry entry) {
    if (!isIntroduced(entry)) return ReviewState.fresh;

    final card = cardOf(entry);

    if (card == null || card.lastReviewed == null) return ReviewState.due;

    return ReviewState.of(card, algorithm);
  }

  ProgressSummary progressOf(Iterable<LatinVocabularyEntry> words) =>
      ProgressSummary.ofStates(words.map(statusOf));

  /// Fällige Wiederholungen im Plan, die dringendsten zuerst.
  List<LatinVocabularyEntry> get dueReviews {
    final due = [
      for (final e in scope)
        if (statusOf(e) == ReviewState.due) e,
    ];

    double score(LatinVocabularyEntry e) =>
        algorithm.selectionScore(selectionCardOf(e), baseWeight: e.weight);

    due.sort((a, b) => score(b).compareTo(score(a)));

    return due;
  }

  /// Im Plan eingeführte Vokabeln des Tages von [day].
  List<LatinVocabularyEntry> introducedOn(DateTime day) {
    final start = DailyNewPlan.dayOf(day);
    final end = start.add(const Duration(days: 1));

    return [
      for (final e in entries)
        if (data.introduced[e.id] case final at?)
          if (!at.isBefore(start) && at.isBefore(end)) e,
    ];
  }

  /// Wie viele neue Vokabeln heute noch eingeführt werden. Ohne oder bei
  /// pausiertem Plan keine.
  int get newQuotaToday {
    final plan = this.plan;

    if (plan == null || plan.paused) return 0;

    final remaining = progressOf(scope).fresh;

    // Die heute schon eingeführten zählen für das Tagesziel mit.
    final introducedToday = introducedOn(now).length;

    final target = plan.dailyTarget(remaining + introducedToday, now);

    return max(0, min(remaining, target - introducedToday));
  }

  /// Die heute noch einzuführenden Vokabeln: die nächsten noch nicht
  /// eingeführten in Lehrbuchreihenfolge (Lektion für Lektion).
  List<LatinVocabularyEntry> get newToday {
    final quota = newQuotaToday;

    if (quota == 0) return const [];

    return [
      for (final e in scope)
        if (statusOf(e) == ReviewState.fresh) e,
    ].take(quota).toList();
  }

  /// Die Lektion, an der der Plan gerade arbeitet: die erste mit noch nicht
  /// eingeführten Vokabeln, sonst die erste mit fälligen.
  int? get currentLesson {
    for (final lesson in planLessons) {
      if (progressOf(entriesOfLesson(lesson)).fresh > 0) return lesson;
    }

    for (final lesson in planLessons) {
      if (progressOf(entriesOfLesson(lesson)).due > 0) return lesson;
    }

    return null;
  }

  /// Voraussichtlicher Tag, an dem alle Vokabeln des Plans eingeführt sind
  /// (`null` ohne Plan, pausiert oder wenn schon alle eingeführt sind).
  DateTime? get expectedCompletion {
    final plan = this.plan;

    if (plan == null || plan.paused) return null;

    final remaining = progressOf(scope).fresh;

    if (remaining == 0) return null;

    final today = DailyNewPlan.dayOf(now);
    final afterToday = remaining - newQuotaToday;

    if (afterToday <= 0) return today;

    final tomorrow = today.add(const Duration(days: 1));
    final perDay = max(1, plan.dailyTarget(afterToday, tomorrow));

    // Kalendertage statt Stunden (Sommerzeit).
    final days = (afterToday / perDay).ceil();

    return DateTime(today.year, today.month, today.day + days);
  }

  /// Merkt die Einführung vor; `false`, wenn die Vokabel schon eingeführt
  /// war (dann bleibt der erste Zeitpunkt).
  bool markIntroduced(LatinVocabularyEntry entry) {
    if (data.introduced.containsKey(entry.id)) return false;

    data.introduced[entry.id] = now;

    return true;
  }
}

// ==========================
// LERNEINHEIT
// ==========================

/// Eine Aufgabe der Lerneinheit.
sealed class LatinPlanTask {
  final LatinVocabularyEntry entry;

  const LatinPlanTask(this.entry);
}

/// Neue Vokabel vorstellen (mit Lösung).
class LatinIntroduceTask extends LatinPlanTask {
  const LatinIntroduceTask(super.entry);
}

/// Vokabel abfragen.
class LatinRecallTask extends LatinPlanTask {
  /// Kurz nach der Einführung (die Lösung wurde gerade gezeigt).
  final bool afterIntroduction;

  const LatinRecallTask(super.entry, {this.afterIntroduction = false});
}

/// Bildet eine Lerneinheit des Plans Schritt für Schritt – wie die
/// Lerneinheiten in „Bücher systematisch lernen“ (`AdaptiveStudyQueue`) mit
/// dem unveränderten Auswahlverfahren des Vokabeltrainers
/// ([LearningSelector]: Grundgewicht × Lernbedarf × Fälligkeit, gewichtete
/// Zufallswahl, zuletzt gefragte kurz gesperrt):
///
///   * Neu sind nur die Vokabeln des Tages ([LatinVocabularyPlanState.
///     newToday]); jede wird vorgestellt und [introGap] Aufgaben später
///     abgefragt.
///   * Wiederholt wird aus allen eingeführten Vokabeln des Plans; fällige
///     und häufig falsche haben das größte Gewicht. Gewählt wird nach jeder
///     Antwort neu.
///   * Je Einheit wird jede Vokabel einmal abgefragt, nach einer falschen
///     Antwort genau ein weiteres Mal. Höchstens [questions] geplante
///     Abfragen, nie mehr, als es abfragbare Vokabeln gibt.
class LatinPlanSession {
  final LatinVocabularyPlanState state;

  /// Geplante Abfragen der Einheit (Einführungen und Wiederholungen nach
  /// Fehlern zählen nicht).
  final int questions;

  final List<LatinVocabularyEntry> _newEntries;

  static const int defaultQuestions = 15;

  /// So viele andere Aufgaben liegen zwischen Einführung und Abfrage.
  static const int introGap = 2;

  final LearningSelector selector;

  int _asked = 0;
  int _introduced = 0;
  int _correct = 0;
  int _answered = 0;

  final List<({LatinVocabularyEntry entry, int wait})> _pending = [];

  final Map<int, int> _askCount = {};
  final Set<int> _lastWrong = {};

  LatinPlanSession({
    required this.state,
    int questions = defaultQuestions,
    Random? random,
  }) : _newEntries = state.newToday,
       questions = min(questions, _poolSize(state)),
       selector = LearningSelector(algorithm: state.algorithm, random: random);

  static int _poolSize(LatinVocabularyPlanState state) {
    final started = state.scope.where(state.isIntroduced).length;

    return started + state.newToday.length;
  }

  int get asked => _asked;
  int get introduced => _introduced;
  int get answered => _answered;
  int get correct => _correct;

  /// Ob die Vokabel in dieser Einheit noch abgefragt werden darf.
  bool _askable(LatinVocabularyEntry e) {
    final count = _askCount[e.id] ?? 0;

    if (count == 0) return true;

    return count == 1 && _lastWrong.contains(e.id);
  }

  /// Die nächste Aufgabe oder `null`, wenn die Einheit vorbei ist.
  LatinPlanTask? next() {
    for (var i = 0; i < _pending.length; i++) {
      _pending[i] = (entry: _pending[i].entry, wait: _pending[i].wait - 1);
    }

    final left = questions - _asked;

    // Eingeführte Vokabeln nach kurzer Pause abfragen – spätestens, wenn
    // nur noch so viele Abfragen übrig sind.
    if (_pending.isNotEmpty &&
        (_pending.first.wait <= 0 || left <= _pending.length)) {
      return _ask(_pending.removeAt(0).entry, afterIntroduction: true);
    }

    // Geplante Abfragen erledigt: nur noch Wiederholungen nach Fehlern.
    final retriesOnly = left <= 0;

    final pending = {for (final p in _pending) p.entry.id};

    final fresh = <LatinVocabularyEntry>[
      if (!retriesOnly && left > _pending.length)
        for (final e in _newEntries)
          if (!state.isIntroduced(e) && !pending.contains(e.id)) e,
    ];

    final candidates = [
      ...fresh,
      for (final e in state.scope)
        if (state.isIntroduced(e) &&
            !pending.contains(e.id) &&
            _askable(e) &&
            (!retriesOnly || (_askCount[e.id] ?? 0) > 0))
          e,
    ];

    if (candidates.isEmpty) {
      return _pending.isEmpty
          ? null
          : _ask(_pending.removeAt(0).entry, afterIntroduction: true);
    }

    final chosen = selector.select(
      candidates: candidates,
      idOf: LatinVocabularyPlanState.idOf,
      cards: {
        for (final e in candidates)
          LatinVocabularyPlanState.idOf(e): state.selectionCardOf(e),
      },
      baseWeightOf: (e) => e.weight,
    )!;

    if (!state.isIntroduced(chosen)) {
      _introduced++;
      _pending.add((entry: chosen, wait: introGap + 1));

      return LatinIntroduceTask(chosen);
    }

    return _ask(chosen);
  }

  LatinPlanTask _ask(LatinVocabularyEntry e, {bool afterIntroduction = false}) {
    final count = _askCount[e.id] ?? 0;

    if (count == 0) _asked++;

    _askCount[e.id] = count + 1;
    selector.markAsked(LatinVocabularyPlanState.idOf(e));

    return LatinRecallTask(e, afterIntroduction: afterIntroduction);
  }

  /// Verbucht eine Antwort im gemeinsamen Lernstand und gibt die geänderte
  /// Karte zum Speichern zurück.
  LearningCard answer(LatinVocabularyEntry e, bool correct) {
    final card = state.cardFor(e);

    state.algorithm.answer(card, correct);

    _answered++;

    if (correct) {
      _correct++;
      _lastWrong.remove(e.id);
    } else {
      _lastWrong.add(e.id);
    }

    return card;
  }
}
