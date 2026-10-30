import 'dart:math';

import '../../algorithms/learning_selector.dart';
import '../../algorithms/spaced_repetition.dart';

import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/book_learning_storage.dart';
import 'book_catalog.dart';
import 'book_outline.dart';
import 'book_learning_status.dart';
import 'book_plan.dart';
import 'knowledge.dart';
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

  /// Wissensfragen und Musterantworten. Wird ersetzt, wenn sich die
  /// Freigabe der Vorlesungsunterlagen ändert.
  KnowledgeBank knowledge;

  BookLearningState({
    required this.catalog,
    required this.data,
    Map<String, LearningCard>? legacyCards,
    Set<String>? legacyBooks,
    DateTime Function()? clock,
    KnowledgeBank? knowledge,
  }) : legacyCards = {...?legacyCards},
       legacyBooks = {...?legacyBooks},
       clock = clock ?? DateTime.now,
       knowledge = knowledge ?? KnowledgeBank.empty;

  /// Ersetzt die geladenen Daten an Ort und Stelle (z. B. nach einem
  /// Zurücksetzen), damit offene Ansichten und eine laufende Lerneinheit
  /// mit demselben Zustand weiterarbeiten.
  void replaceWith(
    BookLearningData fresh, {
    required Map<String, LearningCard> legacyCards,
    required Set<String> legacyBooks,
  }) {
    data.cards
      ..clear()
      ..addAll(fresh.cards);
    data.precisions
      ..clear()
      ..addAll(fresh.precisions);
    data.plans
      ..clear()
      ..addAll(fresh.plans);
    data.knowledgeCards
      ..clear()
      ..addAll(fresh.knowledgeCards);
    data.knowledgeEnabled = fresh.knowledgeEnabled;

    this.legacyCards
      ..clear()
      ..addAll(legacyCards);
    this.legacyBooks
      ..clear()
      ..addAll(legacyBooks);
  }

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

  /// Die Karte, nach der das Auswahlverfahren gewichtet: der eigene
  /// Lernstand, sonst (als Startwert) der des Endlos-Quiz, sonst eine neue
  /// Karte. Wird nicht gespeichert.
  LearningCard selectionCardOf(BookPericope p) {
    final card = cardOf(p);

    if (card != null && card.lastReviewed != null) return card;

    final legacy = legacyOf(p);

    if (legacy != null &&
        legacy.lastReviewed != null &&
        !(card?.ignoreEndlessQuiz ?? false)) {
      return legacy;
    }

    return LearningCard(id: p.key);
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

  /// Fortschritt eines Gliederungsabschnitts.
  LearningProgress progressOfSection(OutlineSection section) {
    return progressOf(pericopesOfSection(catalog, section));
  }

  /// Der Abschnitt, an dem beim abschnittsweisen Lernen weitergearbeitet
  /// wird: der erste mit noch nicht eingeführten Perikopen, sonst der erste
  /// mit fälligen oder noch nicht sicheren; `null`, wenn alles sicher ist.
  OutlineSection? currentSection(BookOutline outline) {
    for (final s in outline.sections) {
      if (progressOfSection(s).fresh > 0) return s;
    }

    for (final s in outline.sections) {
      final progress = progressOfSection(s);

      if (progress.due > 0 || progress.learning > 0) return s;
    }

    return null;
  }

  /// Der Abschnitt nach [section] in der Gliederung, sonst `null`.
  OutlineSection? sectionAfter(BookOutline outline, OutlineSection section) {
    final i = outline.sections.indexWhere((s) => s.id == section.id);

    return i < 0 || i + 1 >= outline.sections.length
        ? null
        : outline.sections[i + 1];
  }

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

  // ---------- Wissensfragen ----------

  /// Wissensfragen werden einbezogen (Schalter, Standard: ja).
  bool get knowledgeEnabled => data.knowledgeEnabled;

  BookCard? knowledgeCardOf(KnowledgeQuestion q) => data.knowledgeCards[q.id];

  BookCard knowledgeCardFor(KnowledgeQuestion q) =>
      data.knowledgeCards.putIfAbsent(q.id, () => BookCard(id: q.id));

  /// Gewicht für das Auswahlverfahren (ohne Karte: neu).
  LearningCard knowledgeSelectionCardOf(KnowledgeQuestion q) {
    final card = knowledgeCardOf(q);

    return card != null && card.lastReviewed != null
        ? card
        : LearningCard(id: q.id);
  }

  /// Status nach denselben Regeln wie bei den Perikopen.
  PericopeStatus knowledgeStatusOf(KnowledgeQuestion q) =>
      BookLearningRules.statusOf(knowledgeCardOf(q), null, now);

  LearningProgress knowledgeProgressOf(Iterable<KnowledgeQuestion> questions) =>
      LearningProgress.of(questions.map(knowledgeStatusOf));

  /// Wissensfragen, die in Lerneinheiten und Wiederholungen einbezogen
  /// werden: leer, solange sie ausgeschaltet sind.
  List<KnowledgeQuestion> active(Iterable<KnowledgeQuestion> questions) =>
      knowledgeEnabled ? questions.toList() : const [];

  /// Fällige Wissensfragen in [questions] (ohne Rücksicht auf den
  /// Schalter).
  List<KnowledgeQuestion> dueKnowledge(Iterable<KnowledgeQuestion> questions) =>
      [
        for (final q in questions)
          if (knowledgeStatusOf(q).due) q,
      ];
}

// ==========================
// AUFGABEN
// ==========================

/// Eine Aufgabe einer Lerneinheit: zu einer Perikope ([PericopeTask]) oder
/// eine inhaltliche Wissensfrage ([KnowledgeTask]).
sealed class StudyTask {
  const StudyTask();
}

/// Aufgaben zu Perikopenstellen, ihrer Zuordnung und Reihenfolge.
sealed class PericopeTask extends StudyTask {
  const PericopeTask();

  /// Die Perikope, deren Lernstand die Aufgabe betrifft.
  BookPericope get target;
}

/// Eine inhaltliche Wissensfrage. Die Auswahlmöglichkeiten sind beim
/// Erstellen gemischt, damit die Anzeige stabil bleibt.
class KnowledgeTask extends StudyTask {
  final KnowledgeQuestion question;

  /// Auswahl ([KnowledgeFormat.choice], [KnowledgeFormat.multi]) bzw. die
  /// rechte Spalte ([KnowledgeFormat.match]) bzw. die zu ordnenden Einträge
  /// ([KnowledgeFormat.order]), gemischt.
  final List<String> options;

  const KnowledgeTask(this.question, this.options);

  factory KnowledgeTask.of(KnowledgeQuestion q, Random random) {
    List<String> shuffled(List<String> values) {
      final list = [...values]..shuffle(random);

      // Eine Reihenfolge-Aufgabe soll nicht schon gelöst erscheinen.
      if (q.format == KnowledgeFormat.order && list.length > 1) {
        for (int i = 0; i < 5 && _same(list, values); i++) {
          list.shuffle(random);
        }
        if (_same(list, values)) list.add(list.removeAt(0));
      }

      return list;
    }

    return KnowledgeTask(q, switch (q.format) {
      KnowledgeFormat.choice ||
      KnowledgeFormat.multi => shuffled([...q.correct, ...q.distractors]),
      KnowledgeFormat.match => shuffled([for (final p in q.pairs) p.right]),
      KnowledgeFormat.order => shuffled(q.items),
      KnowledgeFormat.reveal => const [],
    });
  }

  static bool _same(List<String> a, List<String> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Neue Perikope vorstellen: Titel und Stelle werden gezeigt.
class IntroduceTask extends PericopeTask {
  @override
  final BookPericope target;

  const IntroduceTask(this.target);
}

/// Stelle zu einem Titel abrufen.
///
/// Ob das Buch vorgegeben ist, bestimmt nicht die Aufgabe, sondern der
/// Buchkontext der ganzen Lerneinheit ([StudySession.contextBook]): So ist
/// die Eingabe innerhalb einer Einheit immer gleich.
class RecallTask extends PericopeTask {
  @override
  final BookPericope target;

  /// Kommt kurz nach der Einführung: zählt nie als zeitlich getrennter Abruf.
  final bool afterIntroduction;

  const RecallTask(this.target, {this.afterIntroduction = false});
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
class ChoiceTask extends PericopeTask {
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
class ArrangeTask extends PericopeTask {
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
  section("Abschnitt lernen"),
  chapter("Kapitel lernen"),
  order("Reihenfolge lernen"),
  exam("Prüfung"),
  selection("Einzelne Perikope"),
  review("Wiederholungen"),
  knowledge("Wissensfragen");

  final String label;

  const StudyMode(this.label);
}

/// Stellt die Aufgaben der Lernmodi zusammen.
///
/// Die eigentlichen Lerneinheiten (Buch, Abschnitt, Kapitel) bildet
/// [AdaptiveStudyQueue] fortlaufend mit dem Auswahlverfahren des
/// Perikopenquiz. Hier stehen die festen Aufgabenfolgen: Reihenfolge,
/// Prüfung, einzelne Perikopen und Wiederholungslisten.
class StudyPlanner {
  final BookLearningState state;

  final Random _random;

  StudyPlanner(this.state, {Random? random}) : _random = random ?? Random();

  /// Neue Perikopen, die heute laut Plan noch eingeführt würden.
  int newToday(String book) => state.newQuotaToday(book);

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

  // ---------- Prüfung ----------

  /// Jede Perikope einmal, vollständig aus dem Gedächtnis, gemischt.
  List<StudyTask> exam(Iterable<BookPericope> scope) {
    final list = scope.toList()..shuffle(_random);

    return [for (final p in list) RecallTask(p)];
  }

  // ---------- Einzelne Perikope, Wiederholungslisten ----------

  /// Eine Perikope gezielt üben: eine neue wird zuerst eingeführt.
  List<StudyTask> single(BookPericope p) {
    if (state.statusOf(p).level == LearningLevel.fresh) {
      return [IntroduceTask(p), RecallTask(p, afterIntroduction: true)];
    }

    return [RecallTask(p)];
  }

  /// Eine feste Liste (z. B. „Überfällig“, „Fehler wiederholen“) je einmal
  /// abfragen – in der Reihenfolge des Auswahlverfahrens: gewichtet nach
  /// Lernbedarf und Fälligkeit, mit Zufall statt starrer Sortierung.
  List<StudyTask> review(Iterable<BookPericope> scope) {
    final algorithm = SpacedRepetition(clock: state.clock);

    final remaining = scope.toList();
    final ordered = <BookPericope>[];

    while (remaining.isNotEmpty) {
      final next = pickWeighted(
        remaining,
        (p) => algorithm.selectionScore(state.selectionCardOf(p)),
        _random,
      );

      remaining.remove(next);
      ordered.add(next);
    }

    return [for (final p in ordered) RecallTask(p)];
  }

  /// Wissensfragen je einmal, gereiht wie [review] (Lernbedarf ×
  /// Fälligkeit mit Zufall).
  List<StudyTask> knowledgeReview(Iterable<KnowledgeQuestion> scope) {
    final algorithm = SpacedRepetition(clock: state.clock);

    final remaining = scope.toSet().toList();
    final tasks = <StudyTask>[];

    while (remaining.isNotEmpty) {
      final next = pickWeighted(
        remaining,
        (q) => algorithm.selectionScore(state.knowledgeSelectionCardOf(q)),
        _random,
      );

      remaining.remove(next);
      tasks.add(KnowledgeTask.of(next, _random));
    }

    return tasks;
  }

  /// Wissensfragen in fester Reihenfolge (z. B. die Lernfragen einer
  /// Aufgabe mit Musterantwort).
  List<StudyTask> knowledgeInOrder(Iterable<KnowledgeQuestion> questions) => [
    for (final q in questions) KnowledgeTask.of(q, _random),
  ];

  StudyTask compareOrRecall(BookPericope p) {
    return _compareTask(p) ?? RecallTask(p);
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
