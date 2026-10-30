import '../../models/bible/bible_translation.dart';
import '../../models/bible/course_reading_plan.dart';
import '../../models/bible/reading_plan.dart';
import 'bible_books.dart';

/// Kapitel- und Verszahlen für die Planung. Die Ausgaben zählen nicht
/// überall gleich; maßgeblich ist die erste, die das Buch enthält.
abstract class BibleExtent {
  /// `null`, wenn keine Ausgabe das Buch enthält.
  int? chapterCount(String bookId);

  /// 0, wenn es das Kapitel nicht gibt.
  int verseCount(String bookId, int chapter);
}

class TranslationExtent implements BibleExtent {
  final List<BibleTranslation> translations;

  const TranslationExtent(this.translations);

  BibleBookInfo? _book(String bookId) {
    for (final translation in translations) {
      final resolved = BibleBooks.resolveIn(translation, bookId);

      if (resolved != null) return translation.book(resolved);
    }

    return null;
  }

  @override
  int? chapterCount(String bookId) => _book(bookId)?.chapterCount;

  @override
  int verseCount(String bookId, int chapter) =>
      _book(bookId)?.verseCount(chapter) ?? 0;
}

/// Ein Lesestück im Plan: ein Kapitel oder ein Versbereich innerhalb eines
/// Kapitels, mit seiner Sitzung.
class ScheduledPiece {
  final PlanReading piece;
  final int verses;

  /// Sitzung, für die das Stück gelesen sein soll.
  final String sessionId;

  /// Die Lesung der Sitzung, aus der das Stück stammt (z. B. „Ex 1–5“).
  final PlanReading reading;

  /// Kalendertag der Erledigung bzw. `null`, wenn es offen ist.
  final String? doneOn;

  /// Eine frühere Sitzung hat den Text schon eingeplant: Er wird hier nur
  /// zur gezielten Wiederholung angeboten und nicht mitgezählt.
  final bool repeat;

  /// Bei einer Wiederholung: Sitzung, für die der Text zuerst eingeplant
  /// ist.
  final String? firstSessionId;

  final bool reviewed;

  /// Nur im Umfang „ganze Bücher“: ein übriges Kapitel eines Buchs, das die
  /// Sitzung behandelt, das ihre Stellen selbst aber nicht nennen.
  final bool extra;

  const ScheduledPiece({
    required this.piece,
    required this.verses,
    required this.sessionId,
    required this.reading,
    required this.doneOn,
    this.repeat = false,
    this.firstSessionId,
    this.reviewed = false,
    this.extra = false,
  });

  bool get done => doneOn != null;

  String get key => piece.key;

  String get label => piece.label;
}

/// Wie eine Sitzung zeitlich steht.
enum CoursePace {
  /// Keine Lektüre vorgesehen.
  noReading("Keine Lektüre"),

  /// Alles gelesen.
  done("Gelesen"),

  /// Lesezeitraum hat noch nicht begonnen.
  upcoming("Später"),

  onTrack("Im Plan"),

  /// Weniger gelesen, als nach gleichmäßiger Verteilung bis gestern
  /// vorgesehen war.
  behind("Rückstand"),

  /// Die Sitzung ist vorbei, es ist noch etwas offen.
  missed("Nachholen");

  final String label;

  const CoursePace(this.label);
}

/// Planung einer Sitzung zum Stichtag.
class SessionSchedule {
  /// Mit eigenen Änderungen (Termin, Stellen).
  final CourseSession session;

  /// Die Empfehlung aus den Folien bzw. dem Plan.
  final CourseSession recommended;

  final CourseSessionOverride? override;

  /// Geplanter Abschluss: Vorabend oder Sitzungstag.
  final DateTime target;

  /// Erster Tag des Lesezeitraums (Tag nach dem Abschluss der vorigen
  /// Sitzung bzw. Beginn des Plans).
  final DateTime windowStart;

  /// Für diese Sitzung zu lesen (ohne Wiederholungen).
  final List<ScheduledPiece> required;

  /// Schon für eine frühere Sitzung eingeplant.
  final List<ScheduledPiece> repeats;

  /// Verteilung des noch Offenen (und des heute Erledigten) auf die Tage
  /// bis [target]; leer, wenn nichts offen oder die Sitzung vorbei ist.
  final Map<DateTime, List<ScheduledPiece>> days;

  final CoursePace pace;

  /// Lesetage von heute (bzw. Beginn des Zeitraums) bis [target].
  final int daysLeft;

  /// Verse am Tag, wenn das Offene gleichmäßig verteilt wird.
  final int versesPerDay;

  const SessionSchedule({
    required this.session,
    required this.recommended,
    required this.override,
    required this.target,
    required this.windowStart,
    required this.required,
    required this.repeats,
    required this.days,
    required this.pace,
    required this.daysLeft,
    required this.versesPerDay,
  });

  String get id => session.id;

  DateTime get date => session.date;

  bool get hasReading => session.readings.isNotEmpty;

  bool get dateChanged => override?.date != null;

  bool get readingsChanged => override?.readings != null;

  /// Die Empfehlung hat sich seit der eigenen Änderung geändert.
  bool get recommendationChanged {
    final o = override;

    return o != null && o.basedOn != recommended.fingerprint;
  }

  int get totalVerses => required.fold(0, (sum, p) => sum + p.verses);

  /// Zusätzliche Kapitel im Umfang „ganze Bücher“.
  List<ScheduledPiece> get extras => [
    for (final p in required)
      if (p.extra) p,
  ];

  int get doneVerses =>
      required.where((p) => p.done).fold(0, (sum, p) => sum + p.verses);

  int get openVerses => totalVerses - doneVerses;

  List<ScheduledPiece> get open => [
    for (final p in required)
      if (!p.done) p,
  ];

  int get minutesPerDay =>
      (versesPerDay / ReadingPlanExtent.versesPerMinute).round();

  int get openMinutes =>
      (openVerses / ReadingPlanExtent.versesPerMinute).round();

  /// Mehr als [CourseSchedule.tightMinutes] am Tag.
  bool get tight =>
      openVerses > 0 &&
      pace != CoursePace.missed &&
      minutesPerDay >= CourseSchedule.tightMinutes;

  /// Mehr als [CourseSchedule.unrealisticMinutes] am Tag.
  bool get veryTight =>
      tight && minutesPerDay >= CourseSchedule.unrealisticMinutes;

  double get fraction => totalVerses == 0 ? 1 : doneVerses / totalVerses;
}

/// Planung eines Leseplans zur Lehrveranstaltung an einem Stichtag.
///
/// Grundsatz: Bis zu jeder Sitzung sind ihre Texte gelesen. Der Lesezeitraum
/// einer Sitzung beginnt am Tag nach dem geplanten Abschluss der vorigen,
/// endet am Vorabend (bzw. am Sitzungstag, siehe
/// [CourseReadingProgress.finishEve]) und wird nach Versen gleichmäßig
/// verteilt, kapitelweise. Jeden Tag wird das Offene auf die verbleibenden
/// Tage neu verteilt; was heute erledigt wurde, bleibt im heutigen Pensum
/// stehen, damit es sich beim Abhaken nicht verschiebt. Spätester Termin ist
/// immer der Sitzungstag.
class CourseSchedule {
  /// Ab hier gilt der Zeitraum als knapp (Minuten am Tag).
  static const int tightMinutes = 45;

  /// Ab hier ist das Pensum kaum zu schaffen.
  static const int unrealisticMinutes = 75;

  final DateTime today;
  final List<SessionSchedule> sessions;
  final List<CourseMilestone> milestones;

  const CourseSchedule({
    required this.today,
    required this.sessions,
    required this.milestones,
  });

  /// Verse aller Sitzungen (ohne Wiederholungen).
  int get totalVerses => sessions.fold(0, (sum, s) => sum + s.totalVerses);

  int get doneVerses => sessions.fold(0, (sum, s) => sum + s.doneVerses);

  /// Anteil des gelesenen Umfangs am ganzen Plan.
  double get fraction => totalVerses == 0 ? 1 : doneVerses / totalVerses;

  /// Zusätzliche Kapitel im Umfang „ganze Bücher“, über alle Sitzungen.
  int get extraCount => sessions.fold(0, (sum, s) => sum + s.extras.length);

  /// Heutiges Pensum aller Sitzungen (offen und heute erledigt).
  List<ScheduledPiece> get todayPieces => [
    for (final s in sessions) ...?s.days[today],
  ];

  /// Nächste Sitzung mit Lektüre, die noch nicht vorbei ist.
  SessionSchedule? get next {
    for (final s in sessions) {
      if (s.hasReading && !s.date.isBefore(today)) return s;
    }

    return null;
  }

  /// Nächste Sitzung (auch ohne Lektüre), die noch nicht vorbei ist.
  SessionSchedule? get nextSession {
    for (final s in sessions) {
      if (!s.date.isBefore(today)) return s;
    }

    return null;
  }

  /// Offene Stücke vergangener Sitzungen.
  List<ScheduledPiece> get overdue => [
    for (final s in sessions)
      if (s.pace == CoursePace.missed) ...s.open,
  ];

  /// Erste Sitzung nach [session] mit offener Lektüre (zum Vorauslesen).
  SessionSchedule? after(SessionSchedule session) {
    final index = sessions.indexOf(session);

    for (var i = index + 1; i < sessions.length; i++) {
      if (sessions[i].open.isNotEmpty) return sessions[i];
    }

    return null;
  }

  SessionSchedule? session(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }

    return null;
  }

  /// Zerlegt eine Lesung in Lesestücke: ganze Kapitel, Versbereiche nur
  /// innerhalb eines Kapitels.
  static List<PlanReading> pieces(PlanReading reading, BibleExtent extent) {
    final book = reading.bookId;
    final first = reading.chapter;

    if (first == null) {
      final count = extent.chapterCount(book) ?? 0;

      return [
        for (var c = 1; c <= count; c++) PlanReading(bookId: book, chapter: c),
      ];
    }

    final last = reading.endChapter ?? first;
    final verse = reading.verse;

    if (verse == null) {
      return [
        for (var c = first; c <= last; c++)
          PlanReading(bookId: book, chapter: c),
      ];
    }

    PlanReading part(int chapter, int from, int to) {
      final count = extent.verseCount(book, chapter);

      // Ganzes Kapitel → als Kapitel führen, damit Abhaken und
      // Überschneidungen einheitlich sind.
      if (from == 1 && count > 0 && to >= count) {
        return PlanReading(bookId: book, chapter: chapter);
      }

      return PlanReading(
        bookId: book,
        chapter: chapter,
        verse: from,
        endVerse: to == from ? null : to,
      );
    }

    if (last == first) {
      return [part(first, verse, reading.endVerse ?? verse)];
    }

    return [
      part(first, verse, extent.verseCount(book, first)),
      for (var c = first + 1; c < last; c++)
        PlanReading(bookId: book, chapter: c),
      part(last, 1, reading.endVerse ?? 1),
    ];
  }

  static int versesOf(PlanReading piece, BibleExtent extent) {
    final chapter = piece.chapter!;
    final verse = piece.verse;

    if (verse == null) return extent.verseCount(piece.bookId, chapter);

    return (piece.endVerse ?? verse) - verse + 1;
  }

  /// Deckt [a] das Stück [b] ab (gleich oder ganzes Kapitel von [b])?
  static bool covers(PlanReading a, PlanReading b) {
    if (a.key == b.key) return true;

    return a.verse == null &&
        a.bookId == b.bookId &&
        a.chapter == b.chapter &&
        b.verse != null;
  }

  /// Verteilt Stücke mit den Gewichten [weights] der Reihe nach auf [days]
  /// Tage, möglichst gleichmäßig: Ein Stück kommt auf den Tag, in den die
  /// Mitte seines Umfangs fällt. Liefert je Stück den Tag (ab 0).
  static List<int> distribute(List<int> weights, int days) {
    if (days <= 1) return List.filled(weights.length, 0);

    final total = weights.fold(0, (sum, w) => sum + w);

    if (total == 0) {
      return [
        for (var i = 0; i < weights.length; i++) i * days ~/ weights.length,
      ];
    }

    final result = <int>[];
    var before = 0;

    for (final w in weights) {
      final day = ((before + w / 2) * days / total).floor();

      result.add(day >= days ? days - 1 : day);

      before += w;
    }

    return result;
  }

  /// Die Sitzungen mit eigenen Änderungen, nach Termin geordnet.
  static List<(CourseSession, CourseSession, CourseSessionOverride?)>
  effectiveSessions(CourseReadingPlan plan, CourseReadingProgress progress) {
    final result = [
      for (final s in plan.sessions)
        (
          s.copyWith(
            date: progress.overrides[s.id]?.date,
            readings: progress.overrides[s.id]?.readings,
          ),
          s,
          progress.overrides[s.id],
        ),
    ];

    result.sort((a, b) {
      final byDate = a.$1.date.compareTo(b.$1.date);

      return byDate != 0 ? byDate : a.$1.number.compareTo(b.$1.number);
    });

    return result;
  }

  /// Umfang „ganze Bücher“: alle Kapitel der Bücher, die [own] berührt, in
  /// der Reihenfolge der Bücher (wie sie die Sitzung nennt) und Kapitel.
  ///
  /// * Eigene ganze Kapitel bleiben, wie sie sind.
  /// * Ein Kapitel, aus dem die Sitzung nur Verse nennt, wird ganz gelesen
  ///   (es deckt die Verse ab; ein schon gelesener Versbereich bleibt
  ///   gespeichert).
  /// * Ein Kapitel, das eine spätere Sitzung selbst nennt, bleibt dort und
  ///   wird hier nicht vorgezogen.
  /// * Alle übrigen Kapitel kommen als ergänzend (`extra`) hinzu.
  static List<(PlanReading, PlanReading, bool)> _wholeBooks(
    List<(PlanReading, PlanReading)> own,
    List<PlanReading> later,
    BibleExtent extent,
  ) {
    String chapterKey(PlanReading p) => "${p.bookId} ${p.chapter}";

    final laterChapters = {for (final p in later) chapterKey(p)};

    final books = <String>{
      for (final (piece, _) in own) piece.bookId,
    }.toList();

    final result = <(PlanReading, PlanReading, bool)>[];

    for (final book in books) {
      final count = extent.chapterCount(book) ?? 0;

      // Ohne Kapitelzahlen bleibt es bei den eigenen Stellen.
      if (count == 0) {
        for (final (piece, reading) in own) {
          if (piece.bookId == book) result.add((piece, reading, false));
        }

        continue;
      }

      for (var c = 1; c <= count; c++) {
        final chapter = PlanReading(bookId: book, chapter: c);

        final mine = [
          for (final entry in own)
            if (entry.$1.bookId == book && entry.$1.chapter == c) entry,
        ];

        if (mine.isNotEmpty) {
          result.add((chapter, mine.first.$2, false));
        } else if (!laterChapters.contains(chapterKey(chapter))) {
          result.add((chapter, PlanReading.book(book), true));
        }
      }
    }

    return result;
  }

  static CourseSchedule compute({
    required CourseReadingPlan plan,
    required CourseReadingProgress progress,
    required DateTime today,
    required BibleExtent extent,
  }) {
    today = CourseDates.day(today);

    final todayKey = CourseDates.key(today);
    final startedOn = CourseDates.parse(progress.startedOn) ?? today;

    // Stücke, die schon eine frühere Sitzung einplant.
    final claimed = <PlanReading, String>{};

    final result = <SessionSchedule>[];

    final sessions = effectiveSessions(plan, progress);

    // Die eigenen Stellen jeder Sitzung, zerlegt in Lesestücke.
    final own = [
      for (final (session, _, _) in sessions)
        [
          for (final reading in session.readings)
            for (final piece in pieces(reading, extent)) (piece, reading),
        ],
    ];

    final since = progress.wholeBooks
        ? CourseDates.parse(progress.wholeBooksSince) ?? startedOn
        : null;

    DateTime? previousTarget;

    for (final (index, (session, recommended, override)) in sessions.indexed) {
      final eve = CourseDates.addDays(session.date, -1);

      var start = previousTarget == null
          ? startedOn
          : CourseDates.addDays(previousTarget, 1);

      if (start.isBefore(startedOn)) start = startedOn;

      // Vorabend nur, wenn er im Lesezeitraum liegt.
      final target = progress.finishEve && !eve.isBefore(start)
          ? eve
          : session.date;

      // Umfang „ganze Bücher“ erst für Sitzungen ab dem Einschalten.
      final expand = since != null && !session.date.isBefore(since);

      final candidates = expand
          ? _wholeBooks(own[index], [
              for (final later in own.skip(index + 1))
                for (final (piece, _) in later) piece,
            ], extent)
          : [
              for (final (piece, reading) in own[index])
                (piece, reading, false),
            ];

      final required = <ScheduledPiece>[];
      final repeats = <ScheduledPiece>[];
      final seen = <String>{};

      for (final (piece, reading, extra) in candidates) {
        // Dieselbe Stelle zweimal in einer Sitzung nur einmal.
        if (!seen.add(piece.key)) continue;

        String? first;

        for (final entry in claimed.entries) {
          if (covers(entry.key, piece)) {
            first = entry.value;
            break;
          }
        }

        // Ein ergänzendes Kapitel, das schon eingeplant ist, entfällt
        // (keine Wiederholung, die niemand verlangt hat).
        if (extra && first != null) continue;

        final scheduled = ScheduledPiece(
          piece: piece,
          verses: versesOf(piece, extent),
          sessionId: session.id,
          reading: reading,
          doneOn: progress.doneOn(piece),
          repeat: first != null,
          firstSessionId: first,
          reviewed: progress.isReviewed(piece),
          extra: extra,
        );

        if (first != null) {
          repeats.add(scheduled);
        } else {
          required.add(scheduled);
        }
      }

      for (final p in required) {
        claimed[p.piece] = session.id;
      }

      result.add(
        _plan(
          session: session,
          recommended: recommended,
          override: override,
          target: target,
          windowStart: start,
          required: required,
          repeats: repeats,
          today: today,
          todayKey: todayKey,
        ),
      );

      previousTarget = target;
    }

    return CourseSchedule(
      today: today,
      sessions: result,
      milestones: plan.milestones,
    );
  }

  static SessionSchedule _plan({
    required CourseSession session,
    required CourseSession recommended,
    required CourseSessionOverride? override,
    required DateTime target,
    required DateTime windowStart,
    required List<ScheduledPiece> required,
    required List<ScheduledPiece> repeats,
    required DateTime today,
    required String todayKey,
  }) {
    SessionSchedule build(
      CoursePace pace, {
      Map<DateTime, List<ScheduledPiece>> days = const {},
      int daysLeft = 0,
      int versesPerDay = 0,
      DateTime? until,
    }) {
      return SessionSchedule(
        session: session,
        recommended: recommended,
        override: override,
        target: until ?? target,
        windowStart: windowStart,
        required: required,
        repeats: repeats,
        days: days,
        pace: pace,
        daysLeft: daysLeft,
        versesPerDay: versesPerDay,
      );
    }

    if (session.readings.isEmpty) return build(CoursePace.noReading);

    // Offen zu Beginn des heutigen Tages.
    final pending = [
      for (final p in required)
        if (!p.done || p.doneOn == todayKey) p,
    ];

    final open = required.where((p) => !p.done);

    if (open.isEmpty && pending.every((p) => p.doneOn != todayKey)) {
      return build(CoursePace.done);
    }

    if (session.date.isBefore(today)) {
      return build(open.isEmpty ? CoursePace.done : CoursePace.missed);
    }

    // Am Sitzungstag (oder wenn der Vorabend schon vorbei ist) bleibt der
    // Sitzungstag als spätester Termin.
    final until = target.isBefore(today) ? session.date : target;

    final from = today.isAfter(windowStart) ? today : windowStart;

    final daysLeft = CourseDates.daysBetweenInclusive(from, until);

    final assignment = distribute([
      for (final p in pending) p.verses,
    ], daysLeft);

    final days = <DateTime, List<ScheduledPiece>>{};

    for (var i = 0; i < pending.length; i++) {
      days
          .putIfAbsent(CourseDates.addDays(from, assignment[i]), () => [])
          .add(pending[i]);
    }

    final pendingVerses = pending.fold(0, (sum, p) => sum + p.verses);

    final versesPerDay = daysLeft == 0
        ? pendingVerses
        : (pendingVerses / daysLeft).ceil();

    if (open.isEmpty) {
      return build(
        CoursePace.done,
        days: days,
        daysLeft: daysLeft,
        until: until,
      );
    }

    if (today.isBefore(windowStart)) {
      return build(
        CoursePace.upcoming,
        days: days,
        daysLeft: daysLeft,
        versesPerDay: versesPerDay,
        until: until,
      );
    }

    // Soll bis gestern bei gleichmäßiger Verteilung über den ganzen
    // Zeitraum.
    final windowDays = CourseDates.daysBetweenInclusive(windowStart, until);
    final baseline = distribute([
      for (final p in required) p.verses,
    ], windowDays);
    final elapsed = CourseDates.daysBetweenInclusive(windowStart, today) - 1;

    var expected = 0;
    var doneBefore = 0;

    for (var i = 0; i < required.length; i++) {
      final p = required[i];

      if (baseline[i] < elapsed) expected += p.verses;

      if (p.done && p.doneOn != todayKey) doneBefore += p.verses;
    }

    return build(
      doneBefore < expected ? CoursePace.behind : CoursePace.onTrack,
      days: days,
      daysLeft: daysLeft,
      versesPerDay: versesPerDay,
      until: until,
    );
  }
}
