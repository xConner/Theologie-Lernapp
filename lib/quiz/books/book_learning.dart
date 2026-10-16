import 'dart:math';

import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/book_learning_storage.dart';
import 'book_catalog.dart';
import 'book_learning_status.dart';
import 'book_plan.dart';
import 'reference_answer.dart';
import 'verse_precision.dart';

/// Alles, was „Bücher systematisch lernen“ zur Anzeige und Planung braucht:
/// Perikopen, gespeicherte Lernstände, Präzisierungen und Pläne sowie –
/// nur lesend – die Karten des Endlos-Quiz.
class BookLearningState {
  final BookCatalog catalog;

  final BookLearningData data;

  /// Karten des Endlos-Quiz (Schlüssel: Perikopen-ID). Werden nie geändert.
  final Map<String, LearningCard> legacyCards;

  /// Bücher, die im Endlos-Quiz ausgewählt sind. Nur für sie gilt dessen
  /// Lernstand als Startwert: Eine Frage dort umfasst die Stellen aller
  /// gewählten Bücher, nicht aber die übrigen Parallelen.
  final Set<String> legacyBooks;

  final DateTime Function() clock;

  BookLearningState({
    required this.catalog,
    required this.data,
    Map<String, LearningCard>? legacyCards,
    Set<String>? legacyBooks,
    DateTime Function()? clock,
  }) : legacyCards = legacyCards ?? const {},
       legacyBooks = legacyBooks ?? const {},
       clock = clock ?? DateTime.now;

  DateTime get now => clock();

  LearningCard? legacyOf(BookPericope p) {
    if (!legacyBooks.contains(p.book)) return null;

    return legacyCards[p.id];
  }

  BookCard? cardOf(BookPericope p) => data.cards[p.key];

  /// Die Karte zum Verbuchen; neu angelegt mit dem Stand des Endlos-Quiz.
  BookCard cardFor(BookPericope p) {
    return data.cards.putIfAbsent(
      p.key,
      () => BookCard.seeded(p.key, legacyOf(p)),
    );
  }

  PericopeStatus statusOf(BookPericope p) {
    return BookLearningRules.statusOf(cardOf(p), legacyOf(p), now);
  }

  VersePrecision? precisionOf(BookPericope p) => data.precisions[p.key];

  bool isPrecise(BookPericope p) => data.precisions.containsKey(p.key);

  ExpectedReference expectedOf(BookPericope p) {
    return ExpectedReference.of(p.perikope, precisionOf(p));
  }

  LearningProgress progressOf(Iterable<BookPericope> pericopes) {
    return LearningProgress.of(pericopes.map(statusOf));
  }

  BookPlan? planOf(String book) => data.plans[book];

  /// Am Tag von [day] eingeführte Perikopen des Buchs.
  int introducedOn(String book, DateTime day) {
    final start = BookPlan.dayOf(day);
    final end = start.add(const Duration(days: 1));

    int count = 0;

    for (final p in catalog.pericopesOf(book)) {
      final at = cardOf(p)?.introducedAt;

      if (at != null && !at.isBefore(start) && at.isBefore(end)) count++;
    }

    return count;
  }

  /// Wie viele neue Perikopen heute noch vorgeschlagen werden. Ohne Plan
  /// gilt [BookPlan.defaultDailyNew]; ein pausierter Plan schlägt keine vor.
  int newQuotaToday(String book) {
    final plan = planOf(book);

    if (plan != null && plan.paused) return 0;

    final remaining = progressOf(catalog.pericopesOf(book)).fresh;

    final target = plan == null
        ? BookPlan.defaultDailyNew
        : plan.dailyTarget(remaining, now);

    return max(0, min(remaining, target - introducedOn(book, now)));
  }
}

// ==========================
// AUFGABEN
// ==========================

/// Eine Aufgabe einer Lerneinheit. Alle Aufgaben beziehen sich nur auf
/// Perikopenstellen, ihre Zuordnung und Reihenfolge.
sealed class StudyTask {
  const StudyTask();

  /// Die Perikope, deren Lernstand die Aufgabe betrifft.
  BookPericope get target;
}

/// Neue Perikope vorstellen: Titel und Stelle werden gezeigt.
class IntroduceTask extends StudyTask {
  @override
  final BookPericope target;

  const IntroduceTask(this.target);
}

/// Stelle zu einem Titel abrufen.
class RecallTask extends StudyTask {
  @override
  final BookPericope target;

  final ReferencePrompt prompt;

  /// Kommt kurz nach der Einführung: zählt nie als zeitlich getrennter Abruf.
  final bool afterIntroduction;

  const RecallTask(
    this.target, {
    this.prompt = ReferencePrompt.none,
    this.afterIntroduction = false,
  });
}

enum ChoiceKind {
  /// Welche Perikope kommt nach [ChoiceTask.context] 0?
  next,

  /// Welche Perikope steht zwischen [ChoiceTask.context] 0 und 1?
  between,

  /// Welche der nahe beieinanderliegenden Stellen gehört zum Titel?
  compare,
}

/// Auswahlaufgabe; bewertet wird allein über die Perikopen der Liste.
class ChoiceTask extends StudyTask {
  final ChoiceKind kind;

  @override
  final BookPericope target;

  final List<BookPericope> context;

  final List<BookPericope> options;

  const ChoiceTask({
    required this.kind,
    required this.target,
    required this.context,
    required this.options,
  });

  int get correctIndex => options.indexOf(target);

  bool get isOrder => kind != ChoiceKind.compare;
}

/// Mehrere Perikopen in die richtige Reihenfolge bringen.
class ArrangeTask extends StudyTask {
  /// Richtige Reihenfolge.
  final List<BookPericope> ordered;

  /// Angezeigte (gemischte) Reihenfolge.
  final List<BookPericope> shuffled;

  const ArrangeTask({required this.ordered, required this.shuffled});

  @override
  BookPericope get target => ordered.first;
}

// ==========================
// LERNMODI
// ==========================

enum StudyMode {
  learnBook("Buch lernen"),
  chapter("Kapiteltraining"),
  mixed("Gemischte Wiederholung"),
  order("Reihenfolge lernen"),
  difficult("Schwierige Perikopen"),
  exam("Prüfung"),
  selection("Ausgewählte Perikopen"),
  review("Wiederholungen");

  final String label;

  const StudyMode(this.label);
}

/// Stellt die Aufgaben der Lernmodi zusammen.
class StudyPlanner {
  final BookLearningState state;

  final Random _random;

  StudyPlanner(this.state, {Random? random}) : _random = random ?? Random();

  /// Höchstzahl der Wiederholungen je Lerneinheit.
  static const int maxReviews = 20;

  // ---------- Modus A: Buch lernen ----------

  /// Zuerst die fälligen Wiederholungen (am längsten überfällige zuerst),
  /// danach neue Perikopen in Buchreihenfolge bis zur Tagesmenge. Neue
  /// Perikopen werden eingeführt und einige Aufgaben später abgefragt.
  List<StudyTask> learnBook(String book, {int? newCount}) {
    final pericopes = state.catalog.pericopesOf(book);

    final due = _dueSorted(pericopes).take(maxReviews).toList();

    final count = newCount ?? state.newQuotaToday(book);

    final fresh = pericopes
        .where((p) => state.statusOf(p).level == LearningLevel.fresh)
        .take(count)
        .toList();

    return _interleave(due, fresh);
  }

  /// Neue Perikopen, die heute laut Plan eingeführt würden.
  List<BookPericope> suggestedNew(String book) {
    return state.catalog
        .pericopesOf(book)
        .where((p) => state.statusOf(p).level == LearningLevel.fresh)
        .take(state.newQuotaToday(book))
        .toList();
  }

  // ---------- Modus B: Kapiteltraining ----------

  /// Alle Perikopen der Kapitel [from]–[to]: fällige zuerst, dann die
  /// übrigen in Buchreihenfolge; neue werden eingeführt.
  List<StudyTask> chapter(String book, int from, int to) {
    final pericopes = state.catalog.inChapters(book, from, to);

    final due = _dueSorted(pericopes);

    final rest = pericopes.where((p) => !due.contains(p)).toList();

    return _interleave(due, rest);
  }

  // ---------- Modus C: Gemischte Wiederholung ----------

  /// Fällige, schwierige und bereits gelernte Perikopen gemischt. Neue
  /// Perikopen kommen nicht vor.
  List<StudyTask> mixed(Iterable<BookPericope> scope, {int limit = 20}) {
    final started = scope
        .where((p) => state.statusOf(p).level != LearningLevel.fresh)
        .toList();

    final due = _dueSorted(started);

    final difficult =
        started.where((p) => !due.contains(p) && _isDifficult(p)).toList()
          ..shuffle(_random);

    final others =
        started
            .where((p) => !due.contains(p) && !difficult.contains(p))
            .toList()
          ..shuffle(_random);

    final chosen = <BookPericope>[
      ...due.take(limit ~/ 2),
      ...difficult.take(limit ~/ 4),
    ];

    for (final p in [...due, ...difficult, ...others]) {
      if (chosen.length >= limit) break;
      if (!chosen.contains(p)) chosen.add(p);
    }

    chosen.shuffle(_random);

    return [
      for (final p in chosen)
        if (_isDifficult(p) && _random.nextBool())
          compareOrRecall(p)
        else
          RecallTask(p, prompt: promptFor(p)),
    ];
  }

  // ---------- Modus D: Reihenfolge lernen ----------

  /// Reihenfolge-Aufgaben in [ordered] (Perikopen eines Kapitels, Bereichs
  /// oder Buchs in Buchreihenfolge). Leer, wenn es weniger als drei sind.
  List<StudyTask> order(List<BookPericope> ordered, {int count = 10}) {
    if (ordered.length < 3) return [];

    final tasks = <StudyTask>[];

    for (int i = 0; i < count * 3 && tasks.length < count; i++) {
      final kind = _random.nextInt(3);

      final task = switch (kind) {
        0 => _nextTask(ordered),
        1 => _betweenTask(ordered),
        _ => _arrangeTask(ordered),
      };

      if (task != null) tasks.add(task);
    }

    return tasks;
  }

  ChoiceTask? _nextTask(List<BookPericope> ordered) {
    final i = _random.nextInt(ordered.length - 1);

    final anchor = ordered[i];
    final answer = ordered[i + 1];

    final options = _distinctOptions(
      ordered,
      answer,
      exclude: {anchor},
      near: i + 1,
    );

    if (options == null) return null;

    return ChoiceTask(
      kind: ChoiceKind.next,
      target: answer,
      context: [anchor],
      options: options,
    );
  }

  ChoiceTask? _betweenTask(List<BookPericope> ordered) {
    final i = 1 + _random.nextInt(ordered.length - 2);

    final before = ordered[i - 1];
    final answer = ordered[i];
    final after = ordered[i + 1];

    final options = _distinctOptions(
      ordered,
      answer,
      exclude: {before, after},
      near: i,
    );

    if (options == null) return null;

    return ChoiceTask(
      kind: ChoiceKind.between,
      target: answer,
      context: [before, after],
      options: options,
    );
  }

  /// Antwort und bis zu drei Ablenker aus der Nähe; alle Titel verschieden,
  /// damit jede Option eindeutig ist. `null`, wenn es keinen Ablenker gibt.
  List<BookPericope>? _distinctOptions(
    List<BookPericope> ordered,
    BookPericope answer, {
    required Set<BookPericope> exclude,
    required int near,
  }) {
    final titles = {answer.title, for (final p in exclude) p.title};

    final candidates = <BookPericope>[];

    // Nach Entfernung sortiert: nahe Perikopen sind die guten Ablenker.
    for (int d = 1; d < ordered.length && candidates.length < 3; d++) {
      for (final j in [near + d, near - d]) {
        if (j < 0 || j >= ordered.length) continue;

        final p = ordered[j];

        if (exclude.contains(p) || p == answer) continue;
        if (!titles.add(p.title)) continue;

        candidates.add(p);

        if (candidates.length >= 3) break;
      }
    }

    if (candidates.isEmpty) return null;

    return [answer, ...candidates]..shuffle(_random);
  }

  ArrangeTask? _arrangeTask(List<BookPericope> ordered) {
    final size = min(4, ordered.length);

    final start = _random.nextInt(ordered.length - size + 1);

    final window = ordered.sublist(start, start + size);

    // Gleiche Titel wären beim Ordnen nicht unterscheidbar.
    if ({for (final p in window) p.title}.length != window.length) return null;

    final shuffled = [...window];

    for (int i = 0; i < 5; i++) {
      shuffled.shuffle(_random);

      if (!_sameOrder(shuffled, window)) break;
    }

    if (_sameOrder(shuffled, window)) {
      shuffled.add(shuffled.removeAt(0));
    }

    return ArrangeTask(ordered: window, shuffled: shuffled);
  }

  static bool _sameOrder(List<BookPericope> a, List<BookPericope> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---------- Modus E: Schwierige Perikopen ----------

  /// Häufig falsch beantwortete und kürzlich verwechselte Perikopen, die
  /// fehleranfälligsten zuerst; abwechselnd mit Vergleichsaufgaben.
  List<StudyTask> difficult(Iterable<BookPericope> scope, {int limit = 20}) {
    final list = scope.where(_isDifficultOrRecent).toList()
      ..sort(
        (a, b) => state
            .statusOf(b)
            .wrongCount
            .compareTo(state.statusOf(a).wrongCount),
      );

    final tasks = <StudyTask>[];

    for (final p in list.take(limit)) {
      tasks.add(RecallTask(p, prompt: promptFor(p)));

      final compare = _compareTask(p);
      if (compare != null) tasks.add(compare);
    }

    return tasks;
  }

  bool _isDifficult(BookPericope p) => state.statusOf(p).difficult;

  bool _isDifficultOrRecent(BookPericope p) {
    final s = state.statusOf(p);
    return s.difficult || s.recentlyWrong;
  }

  // ---------- Modus F: Prüfung ----------

  /// Jede Perikope einmal, vollständig aus dem Gedächtnis, gemischt.
  List<StudyTask> exam(Iterable<BookPericope> scope) {
    final list = scope.toList()..shuffle(_random);

    return [for (final p in list) RecallTask(p)];
  }

  // ---------- Einzelne Perikopen, Auswahl, Wiederholungen ----------

  /// Gezielte Auswahl: neue werden eingeführt, die übrigen abgefragt.
  List<StudyTask> selection(Iterable<BookPericope> selected) {
    final list = selected.toList();

    final due = _dueSorted(list);

    final rest = list.where((p) => !due.contains(p)).toList();

    return _interleave(due, rest);
  }

  /// Fällige Wiederholungen aus [scope] (auch buchübergreifend).
  List<StudyTask> review(Iterable<BookPericope> scope, {bool shuffle = true}) {
    final list = scope.toList();

    if (shuffle) list.shuffle(_random);

    return [for (final p in list) RecallTask(p, prompt: promptFor(p))];
  }

  // ---------- Bausteine ----------

  List<BookPericope> _dueSorted(Iterable<BookPericope> pericopes) {
    final due = pericopes.where((p) => state.statusOf(p).due).toList()
      ..sort((a, b) {
        final at = state.statusOf(a).dueAt!;
        final bt = state.statusOf(b).dueAt!;
        return at.compareTo(bt);
      });

    return due;
  }

  /// Wiederholungen und weitere Perikopen; neue werden eingeführt und erst
  /// nach zwei weiteren Aufgaben abgefragt (kurzer Abstand statt sofortiger
  /// Wiederholung der gerade gezeigten Lösung).
  List<StudyTask> _interleave(
    List<BookPericope> first,
    List<BookPericope> then,
  ) {
    final result = <StudyTask>[];

    final pending = <({RecallTask task, int wait})>[];

    void tick() {
      for (int i = 0; i < pending.length; i++) {
        pending[i] = (task: pending[i].task, wait: pending[i].wait - 1);
      }

      while (pending.isNotEmpty && pending.first.wait <= 0) {
        result.add(pending.removeAt(0).task);
      }
    }

    for (final p in [...first, ...then]) {
      if (state.statusOf(p).level == LearningLevel.fresh) {
        result.add(IntroduceTask(p));

        pending.add((
          task: RecallTask(p, prompt: _introPrompt(p), afterIntroduction: true),
          wait: 3,
        ));
      } else {
        result.add(RecallTask(p, prompt: promptFor(p)));
      }

      tick();
    }

    for (final item in pending) {
      result.add(item.task);
    }

    return result;
  }

  ReferencePrompt _introPrompt(BookPericope p) {
    final expected = state.expectedOf(p);

    return expected.versePrecise && _singleChapter(expected)
        ? ReferencePrompt.bookAndChapter
        : ReferencePrompt.book;
  }

  static bool _singleChapter(ExpectedReference e) {
    final r = e.reference;
    return r.endChapter == null || r.endChapter == r.startChapter;
  }

  /// Abfrageform je nach Lernstand: Wer eine Perikope noch lernt, bekommt
  /// das Buch (bei versgenauen Perikopen im Wechsel auch das Kapitel)
  /// vorgegeben; sicher gelernte werden meist ohne Hilfe abgefragt.
  ReferencePrompt promptFor(BookPericope p) {
    final status = state.statusOf(p);

    final expected = state.expectedOf(p);

    final verseForm = expected.versePrecise && _singleChapter(expected);

    if (status.level == LearningLevel.secure) {
      return _random.nextInt(4) == 0
          ? ReferencePrompt.book
          : ReferencePrompt.none;
    }

    if (verseForm && _random.nextBool()) {
      return ReferencePrompt.bookAndChapter;
    }

    return _random.nextInt(3) == 0
        ? ReferencePrompt.none
        : ReferencePrompt.book;
  }

  StudyTask compareOrRecall(BookPericope p) {
    return _compareTask(p) ?? RecallTask(p, prompt: promptFor(p));
  }

  /// Vergleich: Titel gegeben, die richtige unter nahe beieinanderliegenden
  /// Stellen wählen. Nur Stellen mit verschiedener Schreibweise kommen
  /// infrage (kapitelgenaue Nachbarn im selben Kapitel wären gleich).
  ChoiceTask? _compareTask(BookPericope p) {
    final book = state.catalog.pericopesOf(p.book);

    final texts = {state.expectedOf(p).text};

    final options = <BookPericope>[];

    for (int d = 1; d < book.length && options.length < 3; d++) {
      for (final j in [p.index + d, p.index - d]) {
        if (j < 0 || j >= book.length) continue;

        final other = book[j];

        if (texts.add(state.expectedOf(other).text)) {
          options.add(other);

          if (options.length >= 3) break;
        }
      }

      // Nur wirklich nahe Stellen: höchstens acht Perikopen entfernt.
      if (d >= 8) break;
    }

    if (options.length < 2) return null;

    return ChoiceTask(
      kind: ChoiceKind.compare,
      target: p,
      context: const [],
      options: [p, ...options]..shuffle(_random),
    );
  }
}

/// Einteilung der Wiederholungen für die Wiederholungsübersicht.
class ReviewBuckets {
  final List<BookPericope> overdue;
  final List<BookPericope> dueToday;
  final List<BookPericope> soon;
  final List<BookPericope> recentlyWrong;

  const ReviewBuckets({
    required this.overdue,
    required this.dueToday,
    required this.soon,
    required this.recentlyWrong,
  });

  /// * überfällig: seit vor heute fällig
  /// * heute fällig: im Lauf des heutigen Tages fällig (auch später heute)
  /// * bald fällig: in den nächsten [soonDays] Tagen
  /// * kürzlich falsch: Fehler in den letzten 7 Tagen
  factory ReviewBuckets.of(
    BookLearningState state,
    Iterable<BookPericope> scope, {
    int soonDays = 3,
  }) {
    final now = state.now;

    final today = BookPlan.dayOf(now);
    final tomorrow = today.add(const Duration(days: 1));
    final soonEnd = tomorrow.add(Duration(days: soonDays));

    final overdue = <BookPericope>[];
    final dueToday = <BookPericope>[];
    final soon = <BookPericope>[];
    final wrong = <BookPericope>[];

    for (final p in scope) {
      final s = state.statusOf(p);

      final at = s.dueAt;

      if (s.recentlyWrong) wrong.add(p);

      if (at == null) continue;

      if (at.isBefore(today)) {
        overdue.add(p);
      } else if (at.isBefore(tomorrow)) {
        dueToday.add(p);
      } else if (at.isBefore(soonEnd)) {
        soon.add(p);
      }
    }

    int byDue(BookPericope a, BookPericope b) =>
        state.statusOf(a).dueAt!.compareTo(state.statusOf(b).dueAt!);

    overdue.sort(byDue);
    dueToday.sort(byDue);
    soon.sort(byDue);

    return ReviewBuckets(
      overdue: overdue,
      dueToday: dueToday,
      soon: soon,
      recentlyWrong: wrong,
    );
  }
}
