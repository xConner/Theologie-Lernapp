import 'dart:math';

import '../../models/bible/course_reading_plan.dart';
import '../../models/bible/reading_plan.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/course_reading_schedule.dart';
import 'book_catalog.dart';
import 'book_learning.dart';
import 'book_learning_status.dart';
import 'knowledge.dart';

/// Gespeicherte Einstellung des Lernpfads zu einem Leseplan: nur, ab wann
/// er gilt. Der Lernstand selbst steht ausschließlich in den Karten von
/// „Bücher systematisch lernen“ (`pericope_books`).
class ReadingPathSettings {
  /// Kalendertag (`yyyy-MM-dd`), an dem der Lernpfad begonnen wurde.
  /// Wochen, deren Sitzung davor lag, sind freiwillig (kein Rückstand).
  final String startedOn;

  const ReadingPathSettings({required this.startedOn});

  static ReadingPathSettings? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final started = raw["startedOn"];

    if (started is! String || CourseDates.parse(started) == null) return null;

    return ReadingPathSettings(startedOn: started);
  }

  Map<String, dynamic> toJson() => {"startedOn": startedOn};
}

/// Wie eine Woche des Lernpfads steht.
enum PathWeekState {
  /// Sitzung vor Beginn des Lernpfads: freiwillig, kein Rückstand.
  beforeStart("Vor Beginn"),

  /// Alle Perikopen der Woche sind eingeführt.
  done("Abgeschlossen"),

  /// Die laufende Woche.
  current("Diese Woche"),

  /// Vorbei, aber noch nicht alle Perikopen eingeführt.
  behind("Rückstand"),

  upcoming("Später");

  final String label;

  const PathWeekState(this.label);
}

/// Eine Woche des Lernpfads: eine Sitzung des Leseplans mit Lektüre und
/// die Perikopen der Perikopenliste, die ihre Stellen berühren.
class PathWeek {
  final SessionSchedule session;

  /// Perikopen, die in dieser Woche neu sind – in der Reihenfolge der
  /// Bücher, wie die Sitzung sie nennt, und innerhalb eines Buchs nach der
  /// Perikopenliste. Eine Perikope gehört nur zur ersten Woche, deren
  /// Stellen sie berührt.
  final List<BookPericope> pericopes;

  /// Bücher der Woche (Abkürzungen der Perikopenliste), in Planreihenfolge.
  final List<String> books;

  /// Kapitelbereiche je Buch, die die Stellen der Woche abdecken (für die
  /// Wissensfragen).
  final Map<String, List<(int, int)>> chapterRuns;

  /// Sitzung vor Beginn des Lernpfads (siehe [ReadingPathSettings]).
  final bool beforeStart;

  const PathWeek({
    required this.session,
    required this.pericopes,
    required this.books,
    required this.chapterRuns,
    required this.beforeStart,
  });

  String get id => session.id;

  int get number => session.session.number;

  String get topic => session.session.topic;

  /// Sitzungstermin.
  DateTime get date => session.date;

  /// Erster Tag der Woche (Lesezeitraum des Leseplans).
  DateTime get start => session.windowStart;

  /// Bis dahin sollen die Perikopen eingeführt sein (wie die Lektüre:
  /// Vorabend bzw. Sitzungstag).
  DateTime get target => session.target;
}

/// Lernpfad „Nach Bibelleseplan lernen“: Die Wochen (Sitzungen) des
/// Leseplans bestimmen, welche Perikopen wann neu eingeführt werden.
///
/// Grundsätze:
///
///   * Datenquelle ist allein der hinterlegte Leseplan samt eigener
///     Änderungen (Termine, Stellen, Umfang „ganze Bücher“), wie ihn
///     [CourseSchedule] plant, und die Perikopenliste. Im Code steht weder
///     eine Perikope noch eine Anzahl.
///   * Kein eigener Lernstand: Eingeführt, gelernt, fällig – alles kommt aus
///     dem [BookLearningState], denselben Karten wie beim Lernen einzelner
///     Bücher. Was dort gelernt wird, zählt hier und umgekehrt.
///   * Maßgeblich ist der tatsächliche Stand, nicht der Kalender: Noch nicht
///     eingeführte Perikopen vergangener Wochen bleiben als Rückstand vorn
///     in der Reihe; schon gelernte Perikopen späterer Wochen werden nicht
///     erneut eingeführt, sondern nur wiederholt.
///   * Tagesmenge = noch nicht eingeführte Perikopen bis einschließlich der
///     laufenden Woche, gleichmäßig verteilt auf die Tage bis zu ihrem
///     Abschluss (wie [DailyNewPlan] mit Zieldatum). Heute schon
///     eingeführte zählen mit, damit sich die Menge im Laufe des Tages nicht
///     verschiebt.
class ReadingPlanPath {
  /// Der Leseplan zur Übung Bibelkunde AT.
  static const String defaultPlanId = "course-bibelkunde-at-wise-2026";

  /// Höchstens so viele neue Perikopen je Lerneinheit; reicht die
  /// Tagesmenge weiter, folgt eine weitere Einheit.
  static const int maxNewPerUnit = 8;

  /// Neue Perikopen je Einheit beim Vorauslernen.
  static const int aheadPerUnit = 5;

  final String planId;

  final DateTime today;

  /// Beginn des Lernpfads; `null`, solange er nicht begonnen wurde (die
  /// Vorschau rechnet dann ab heute).
  final DateTime? startedOn;

  /// Alle Wochen mit Lektüre, nach Termin.
  final List<PathWeek> weeks;

  const ReadingPlanPath._({
    required this.planId,
    required this.today,
    required this.startedOn,
    required this.weeks,
  });

  bool get started => startedOn != null;

  /// Bildet die Wochen aus der Planung des Leseplans. Perikopen, die keine
  /// Stelle des Plans berührt, gehören zu keiner Woche.
  factory ReadingPlanPath.build({
    required String planId,
    required CourseSchedule schedule,
    required BookCatalog catalog,
    ReadingPathSettings? settings,
  }) {
    final today = CourseDates.day(schedule.today);

    final startedOn = settings == null
        ? null
        : CourseDates.parse(settings.startedOn);

    final from = startedOn ?? today;

    final assigned = <String>{};

    final weeks = <PathWeek>[];

    for (final session in schedule.sessions) {
      if (!session.hasReading) continue;

      final pieces = [
        for (final p in session.required) p.piece,
        for (final p in session.repeats) p.piece,
      ];

      final books = <String>[];
      final byBook = <String, List<PlanReading>>{};

      for (final piece in pieces) {
        final book = _catalogBook(catalog, piece.bookId);

        if (book == null) continue;

        if (!byBook.containsKey(book)) books.add(book);

        byBook.putIfAbsent(book, () => []).add(piece);
      }

      final pericopes = <BookPericope>[];
      final runs = <String, List<(int, int)>>{};

      for (final book in books) {
        final bookPieces = byBook[book]!;

        for (final p in catalog.pericopesOf(book)) {
          if (assigned.contains(p.key)) continue;

          if (bookPieces.any((piece) => _touches(p, piece))) {
            assigned.add(p.key);
            pericopes.add(p);
          }
        }

        runs[book] = _runs({for (final piece in bookPieces) piece.chapter!});
      }

      weeks.add(
        PathWeek(
          session: session,
          pericopes: List.unmodifiable(pericopes),
          books: List.unmodifiable(books),
          chapterRuns: runs,
          beforeStart: session.date.isBefore(from),
        ),
      );
    }

    return ReadingPlanPath._(
      planId: planId,
      today: today,
      startedOn: startedOn,
      weeks: List.unmodifiable(weeks),
    );
  }

  /// Buchabkürzung der Perikopenliste zu einer Buchkennung des Plans.
  static String? _catalogBook(BookCatalog catalog, String bookId) {
    final known = BibleBooks.byId(bookId);

    if (known == null) return null;

    if (catalog.hasBook(known.abbreviation)) return known.abbreviation;

    for (final book in catalog.books) {
      if (BibleBooks.byAbbreviation(book)?.id == bookId) return book;
    }

    return null;
  }

  /// Berührt die Perikope das Lesestück (ein Kapitel oder ein Versbereich
  /// in einem Kapitel)?
  static bool _touches(BookPericope p, PlanReading piece) {
    final chapter = piece.chapter!;
    final pericope = p.perikope;

    if (pericope.startChapter > chapter || pericope.endChapter < chapter) {
      return false;
    }

    final verse = piece.verse;

    if (verse == null) return true;

    final end = piece.endVerse ?? verse;

    final from = pericope.startChapter == chapter ? pericope.startVerse : 1;
    final to = pericope.endChapter == chapter ? pericope.endVerse : 1 << 20;

    return from <= end && to >= verse;
  }

  static List<(int, int)> _runs(Set<int> chapters) {
    final sorted = chapters.toList()..sort();

    final result = <(int, int)>[];

    for (final c in sorted) {
      if (result.isNotEmpty && result.last.$2 == c - 1) {
        result[result.length - 1] = (result.last.$1, c);
      } else {
        result.add((c, c));
      }
    }

    return result;
  }

  // ---------- Wochen ----------

  /// Die laufende Woche: die erste, die heute noch nicht abgeschlossen ist
  /// (Abschluss heute oder später); `null`, wenn der Plan vorbei ist.
  PathWeek? get current {
    for (final w in weeks) {
      if (!w.target.isBefore(today)) return w;
    }

    return null;
  }

  /// Wochen, die der Lernpfad verlangt (ab Beginn).
  List<PathWeek> get planned => [
    for (final w in weeks)
      if (!w.beforeStart) w,
  ];

  /// Verlangte Wochen bis einschließlich der laufenden.
  List<PathWeek> get dueWeeks {
    final now = current;

    return [
      for (final w in planned)
        if (now == null || !w.date.isAfter(now.date)) w,
    ];
  }

  /// Die nächste verlangte Woche nach der laufenden.
  PathWeek? get next {
    final now = current;

    for (final w in planned) {
      if (now != null && w.date.isAfter(now.date)) return w;
    }

    return null;
  }

  /// Letzte verlangte Woche: ihr Abschluss ist das Zieldatum des Plans.
  PathWeek? get last => planned.isEmpty ? null : planned.last;

  /// Tage bis zum Abschluss der laufenden Woche (einschließlich heute,
  /// mindestens 1).
  int get daysLeftInWeek {
    final now = current;

    if (now == null) return 1;

    return max(1, now.target.difference(today).inDays + 1);
  }

  /// Tage bis zum Abschluss der letzten Woche (mindestens 0).
  int get daysLeftInPlan {
    final end = last;

    if (end == null) return 0;

    return max(0, end.target.difference(today).inDays + 1);
  }

  PathWeekState stateOf(PathWeek week, BookLearningState state) {
    if (week.beforeStart) return PathWeekState.beforeStart;

    final fresh = week.pericopes.any((p) => _isFresh(state, p));

    if (!fresh) return PathWeekState.done;

    final now = current;

    if (now != null && week.id == now.id) return PathWeekState.current;

    if (now == null || week.date.isBefore(now.date)) {
      return PathWeekState.behind;
    }

    return PathWeekState.upcoming;
  }

  // ---------- Perikopen ----------

  static bool _isFresh(BookLearningState state, BookPericope p) =>
      state.statusOf(p).level == LearningLevel.fresh;

  /// Alle Perikopen der verlangten Wochen, in Planreihenfolge.
  List<BookPericope> get plannedPericopes => [
    for (final w in planned) ...w.pericopes,
  ];

  /// Bis zum Ende der laufenden Woche einzuführen (in Planreihenfolge).
  List<BookPericope> get duePericopes => [
    for (final w in dueWeeks) ...w.pericopes,
  ];

  /// Noch nicht eingeführte Perikopen bis einschließlich der laufenden
  /// Woche: zuerst der Rückstand, dann die laufende Woche.
  List<BookPericope> freshDue(BookLearningState state) => [
    for (final p in duePericopes)
      if (_isFresh(state, p)) p,
  ];

  /// Rückstand: noch nicht eingeführte Perikopen vergangener Wochen.
  List<BookPericope> backlog(BookLearningState state) {
    final now = current;

    return [
      for (final w in dueWeeks)
        if (now == null || w.id != now.id)
          for (final p in w.pericopes)
            if (_isFresh(state, p)) p,
    ];
  }

  /// Heute eingeführte Perikopen bis einschließlich der laufenden Woche –
  /// gleich, in welchem Modus.
  int introducedToday(BookLearningState state) {
    final end = today.add(const Duration(days: 1));

    int count = 0;

    for (final p in duePericopes) {
      final at = state.cardOf(p)?.introducedAt;

      if (at != null && !at.isBefore(today) && at.isBefore(end)) count++;
    }

    return count;
  }

  /// Neue Perikopen am Tag, damit bis zum Abschluss der laufenden Woche
  /// alles eingeführt ist (einschließlich der heute schon eingeführten).
  int perDay(BookLearningState state) {
    if (!started) return 0;

    final open = freshDue(state).length + introducedToday(state);

    return (open / daysLeftInWeek).ceil();
  }

  /// Wie viele neue Perikopen heute noch eingeführt werden.
  int newToday(BookLearningState state) {
    if (!started) return 0;

    final fresh = freshDue(state).length;

    return max(0, min(fresh, perDay(state) - introducedToday(state)));
  }

  /// Perikopen späterer Wochen, die schon (z. B. beim Lernen einzelner
  /// Bücher) eingeführt sind.
  List<BookPericope> learnedAhead(BookLearningState state) {
    final due = duePericopes.toSet();

    return [
      for (final w in planned)
        for (final p in w.pericopes)
          if (!due.contains(p) && !_isFresh(state, p)) p,
    ];
  }

  /// Umfang einer Lerneinheit: die einzuführenden Perikopen in
  /// Planreihenfolge (Rückstand zuerst), dahinter alle schon begonnenen
  /// Perikopen des Plans zur Wiederholung – auch solche aus späteren Wochen
  /// oder aus Wochen vor dem Beginn. Noch nicht eingeführte Perikopen
  /// späterer Wochen kommen nur mit [ahead] dazu.
  List<BookPericope> scope(BookLearningState state, {PathWeek? ahead}) {
    final result = <BookPericope>[];
    final seen = <String>{};

    void add(BookPericope p) {
      if (seen.add(p.key)) result.add(p);
    }

    if (started) duePericopes.forEach(add);

    if (ahead != null) ahead.pericopes.forEach(add);

    for (final w in weeks) {
      for (final p in w.pericopes) {
        if (!_isFresh(state, p)) add(p);
      }
    }

    return result;
  }

  /// Begonnene Perikopen des Plans, deren Wiederholung jetzt ansteht.
  List<BookPericope> dueReviews(BookLearningState state) => [
    for (final w in weeks)
      for (final p in w.pericopes)
        if (state.statusOf(p).due) p,
  ];

  /// Die nächste Woche mit noch nicht eingeführten Perikopen nach der
  /// laufenden (zum Vorauslernen).
  PathWeek? aheadWeek(BookLearningState state) {
    final due = dueWeeks.map((w) => w.id).toSet();

    for (final w in planned) {
      if (!due.contains(w.id) && w.pericopes.any((p) => _isFresh(state, p))) {
        return w;
      }
    }

    return null;
  }

  /// Fortschritt über alle verlangten Wochen.
  LearningProgress progress(BookLearningState state) =>
      state.progressOf(plannedPericopes);

  /// Wissensfragen, die ganz in den Kapiteln der [weeks] liegen.
  static List<KnowledgeQuestion> knowledgeOf(
    BookLearningState state,
    Iterable<PathWeek> weeks,
  ) {
    final result = <KnowledgeQuestion>{};

    for (final w in weeks) {
      for (final entry in w.chapterRuns.entries) {
        for (final (from, to) in entry.value) {
          result.addAll(state.knowledge.inChapters(entry.key, from, to));
        }
      }
    }

    return result.toList();
  }
}
