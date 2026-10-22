import 'dart:math';

import '../models/greek/vocabulary/learning_card.dart';
import 'daily_new_plan.dart';
import 'learning_selector.dart';
import 'review_state.dart';
import 'spaced_repetition.dart';

/// Gemeinsamer Kern der Vokabel-Lernpläne (Latein: Lektionen, Griechisch:
/// Lernschritte). Was ein Plan festlegt: neue Vokabeln pro Tag (optional bis
/// zu einem Zieldatum), Pause und die einbezogenen Einheiten.
abstract class VocabularyPlanRules with DailyNewPlan {
  const VocabularyPlanRules();

  bool get paused;

  /// Gehört die Einheit (Lektion, Lernschritt) zum Plan?
  bool includesUnit(int unit);
}

/// Alles, was ein Vokabel-Lernplan zur Anzeige und Planung braucht:
/// Vokabeln, die gemeinsamen Karten mit dem Vokabeltrainer, der Plan und
/// die Einführungen. Die Sprachbereiche liefern nur, wie eine Vokabel
/// heißt, zu welcher Einheit sie gehört und wie sie gewichtet ist.
///
/// Status ohne eigene Stufen: „Neu“ heißt noch nicht eingeführt, alle
/// übrigen Vokabeln haben den [ReviewState] der Wissensbereiche („Zum
/// Wiederholen“, „Zuletzt sicher“). Eine Vokabel gilt als eingeführt, wenn
/// sie im Plan vorgestellt oder (z. B. im freien Vokabeltrainer) schon
/// einmal beantwortet wurde – vorhandene Lernstände werden so übernommen.
abstract class VocabularyPlanState<E> {
  final List<E> _entries;

  /// Karten des Vokabeltrainers (Schlüssel: Vokabel-ID als Text).
  final Map<String, LearningCard> cards;

  final DateTime Function() clock;

  final SpacedRepetition algorithm;

  VocabularyPlanState({
    required List<E> entries,
    required this.cards,
    DateTime Function()? clock,
    // Der Parameter heißt wie die sortierte Liste [entries]; sortiert wird
    // erst beim ersten Zugriff, weil [unitOf] hier noch nicht bereitsteht.
    // ignore: prefer_initializing_formals
  }) : _entries = entries,
       clock = clock ?? DateTime.now,
       algorithm = SpacedRepetition(clock: clock);

  /// Einheit der Vokabel (Lektion, Lernschritt).
  int unitOf(E entry);

  int entryIdOf(E entry);

  /// Inhaltliches Grundgewicht für die Auswahl.
  double weightOf(E entry);

  /// Der aktuelle Plan; `null` ohne Plan.
  VocabularyPlanRules? get rules;

  /// Vokabel-ID → Zeitpunkt der Einführung im Plan.
  Map<int, DateTime> get introduced;

  /// Alle Vokabeln in Lehrreihenfolge (Einheit, dann ID).
  late final List<E> entries = [..._entries]
    ..sort(
      (a, b) => unitOf(a) != unitOf(b)
          ? unitOf(a).compareTo(unitOf(b))
          : entryIdOf(a).compareTo(entryIdOf(b)),
    );

  DateTime get now => clock();

  /// Alle Einheiten der Vokabelliste (aufsteigend).
  List<int> get units => entries.map(unitOf).toSet().toList()..sort();

  /// Einheiten des Plans (ohne Plan: alle).
  List<int> get planUnits => [
    for (final unit in units)
      if (rules?.includesUnit(unit) ?? true) unit,
  ];

  /// Vokabeln des Plans in Lehrreihenfolge.
  List<E> get scope {
    final included = planUnits.toSet();

    return [
      for (final e in entries)
        if (included.contains(unitOf(e))) e,
    ];
  }

  List<E> entriesOfUnit(int unit) => [
    for (final e in entries)
      if (unitOf(e) == unit) e,
  ];

  String cardIdOf(E entry) => entryIdOf(entry).toString();

  LearningCard? cardOf(E entry) => cards[cardIdOf(entry)];

  /// Die Karte zum Verbuchen (dieselbe wie im Vokabeltrainer).
  LearningCard cardFor(E entry) {
    final id = cardIdOf(entry);

    return cards.putIfAbsent(id, () => LearningCard(id: id));
  }

  /// Die Karte, nach der das Auswahlverfahren gewichtet (wird nicht
  /// gespeichert).
  LearningCard selectionCardOf(E entry) =>
      cardOf(entry) ?? LearningCard(id: cardIdOf(entry));

  bool isIntroduced(E entry) =>
      introduced.containsKey(entryIdOf(entry)) ||
      cardOf(entry)?.lastReviewed != null;

  /// [ReviewState.fresh]: noch nicht eingeführt. Eingeführt, aber noch nie
  /// abgefragt: zum Wiederholen.
  ReviewState statusOf(E entry) {
    if (!isIntroduced(entry)) return ReviewState.fresh;

    final card = cardOf(entry);

    if (card == null || card.lastReviewed == null) return ReviewState.due;

    return ReviewState.of(card, algorithm);
  }

  ProgressSummary progressOf(Iterable<E> words) =>
      ProgressSummary.ofStates(words.map(statusOf));

  /// Fällige Wiederholungen im Plan, die dringendsten zuerst.
  List<E> get dueReviews {
    final due = [
      for (final e in scope)
        if (statusOf(e) == ReviewState.due) e,
    ];

    double score(E e) =>
        algorithm.selectionScore(selectionCardOf(e), baseWeight: weightOf(e));

    due.sort((a, b) => score(b).compareTo(score(a)));

    return due;
  }

  /// Im Plan eingeführte Vokabeln des Tages von [day].
  List<E> introducedOn(DateTime day) {
    final start = DailyNewPlan.dayOf(day);
    final end = start.add(const Duration(days: 1));

    return [
      for (final e in entries)
        if (introduced[entryIdOf(e)] case final at?)
          if (!at.isBefore(start) && at.isBefore(end)) e,
    ];
  }

  /// Wie viele neue Vokabeln heute noch eingeführt werden. Ohne oder bei
  /// pausiertem Plan keine.
  int get newQuotaToday {
    final plan = rules;

    if (plan == null || plan.paused) return 0;

    final remaining = progressOf(scope).fresh;

    // Die heute schon eingeführten zählen für das Tagesziel mit.
    final introducedToday = introducedOn(now).length;

    final target = plan.dailyTarget(remaining + introducedToday, now);

    return max(0, min(remaining, target - introducedToday));
  }

  /// Die heute noch einzuführenden Vokabeln: die nächsten noch nicht
  /// eingeführten in Lehrreihenfolge (Einheit für Einheit).
  List<E> get newToday {
    final quota = newQuotaToday;

    if (quota == 0) return const [];

    return [
      for (final e in scope)
        if (statusOf(e) == ReviewState.fresh) e,
    ].take(quota).toList();
  }

  /// Die Einheit, an der der Plan gerade arbeitet: die erste mit noch nicht
  /// eingeführten Vokabeln, sonst die erste mit fälligen.
  int? get currentUnit {
    for (final unit in planUnits) {
      if (progressOf(entriesOfUnit(unit)).fresh > 0) return unit;
    }

    for (final unit in planUnits) {
      if (progressOf(entriesOfUnit(unit)).due > 0) return unit;
    }

    return null;
  }

  /// Voraussichtlicher Tag, an dem alle Vokabeln des Plans eingeführt sind
  /// (`null` ohne Plan, pausiert oder wenn schon alle eingeführt sind).
  DateTime? get expectedCompletion {
    final plan = rules;

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
  bool markIntroduced(E entry) {
    final id = entryIdOf(entry);

    if (introduced.containsKey(id)) return false;

    introduced[id] = now;

    return true;
  }
}

// ==========================
// LERNEINHEIT
// ==========================

/// Eine Aufgabe der Lerneinheit.
sealed class PlanTask<E> {
  final E entry;

  const PlanTask(this.entry);
}

/// Neue Vokabel vorstellen (mit Lösung).
class IntroduceTask<E> extends PlanTask<E> {
  const IntroduceTask(super.entry);
}

/// Vokabel abfragen.
class RecallTask<E> extends PlanTask<E> {
  /// Kurz nach der Einführung (die Lösung wurde gerade gezeigt).
  final bool afterIntroduction;

  const RecallTask(super.entry, {this.afterIntroduction = false});
}

/// Bildet eine Lerneinheit des Plans Schritt für Schritt – wie die
/// Lerneinheiten in „Bücher systematisch lernen“ (`AdaptiveStudyQueue`) mit
/// dem unveränderten Auswahlverfahren der Vokabeltrainer
/// ([LearningSelector]: Grundgewicht × Lernbedarf × Fälligkeit, gewichtete
/// Zufallswahl, zuletzt gefragte kurz gesperrt):
///
///   * Neu sind nur die Vokabeln des Tages ([VocabularyPlanState.newToday]);
///     jede wird vorgestellt und [introGap] Aufgaben später abgefragt.
///   * Wiederholt wird aus allen eingeführten Vokabeln des Plans; fällige
///     und häufig falsche haben das größte Gewicht. Gewählt wird nach jeder
///     Antwort neu.
///   * Je Einheit wird jede Vokabel einmal abgefragt, nach einer falschen
///     Antwort genau ein weiteres Mal. Höchstens [questions] geplante
///     Abfragen, nie mehr, als es abfragbare Vokabeln gibt.
class VocabularyPlanSession<E> {
  final VocabularyPlanState<E> state;

  /// Geplante Abfragen der Einheit (Einführungen und Wiederholungen nach
  /// Fehlern zählen nicht).
  final int questions;

  final List<E> _newEntries;

  static const int defaultQuestions = 15;

  /// So viele andere Aufgaben liegen zwischen Einführung und Abfrage.
  static const int introGap = 2;

  final LearningSelector selector;

  int _asked = 0;
  int _introduced = 0;
  int _correct = 0;
  int _answered = 0;

  final List<({E entry, int wait})> _pending = [];

  final Map<int, int> _askCount = {};
  final Set<int> _lastWrong = {};

  VocabularyPlanSession({
    required this.state,
    int questions = defaultQuestions,
    Random? random,
  }) : _newEntries = state.newToday,
       questions = min(questions, _poolSize(state)),
       selector = LearningSelector(algorithm: state.algorithm, random: random);

  static int _poolSize<E>(VocabularyPlanState<E> state) {
    final started = state.scope.where(state.isIntroduced).length;

    return started + state.newToday.length;
  }

  int get asked => _asked;
  int get introduced => _introduced;
  int get answered => _answered;
  int get correct => _correct;

  int _id(E e) => state.entryIdOf(e);

  /// Ob die Vokabel in dieser Einheit noch abgefragt werden darf.
  bool _askable(E e) {
    final count = _askCount[_id(e)] ?? 0;

    if (count == 0) return true;

    return count == 1 && _lastWrong.contains(_id(e));
  }

  /// Die nächste Aufgabe oder `null`, wenn die Einheit vorbei ist.
  PlanTask<E>? next() {
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

    final pending = {for (final p in _pending) _id(p.entry)};

    final fresh = <E>[
      if (!retriesOnly && left > _pending.length)
        for (final e in _newEntries)
          if (!state.isIntroduced(e) && !pending.contains(_id(e))) e,
    ];

    final candidates = [
      ...fresh,
      for (final e in state.scope)
        if (state.isIntroduced(e) &&
            !pending.contains(_id(e)) &&
            _askable(e) &&
            (!retriesOnly || (_askCount[_id(e)] ?? 0) > 0))
          e,
    ];

    if (candidates.isEmpty) {
      return _pending.isEmpty
          ? null
          : _ask(_pending.removeAt(0).entry, afterIntroduction: true);
    }

    final chosen =
        selector.select(
              candidates: candidates,
              idOf: state.cardIdOf,
              cards: {
                for (final e in candidates)
                  state.cardIdOf(e): state.selectionCardOf(e),
              },
              baseWeightOf: state.weightOf,
            )
            as E;

    if (!state.isIntroduced(chosen)) {
      _introduced++;
      _pending.add((entry: chosen, wait: introGap + 1));

      return IntroduceTask<E>(chosen);
    }

    return _ask(chosen);
  }

  PlanTask<E> _ask(E e, {bool afterIntroduction = false}) {
    final count = _askCount[_id(e)] ?? 0;

    if (count == 0) _asked++;

    _askCount[_id(e)] = count + 1;
    selector.markAsked(state.cardIdOf(e));

    return RecallTask<E>(e, afterIntroduction: afterIntroduction);
  }

  /// Verbucht eine Antwort im gemeinsamen Lernstand und gibt die geänderte
  /// Karte zum Speichern zurück.
  LearningCard answer(E e, bool correct) {
    final card = state.cardFor(e);

    state.algorithm.answer(card, correct);

    _answered++;

    if (correct) {
      _correct++;
      _lastWrong.remove(_id(e));
    } else {
      _lastWrong.add(_id(e));
    }

    return card;
  }
}
