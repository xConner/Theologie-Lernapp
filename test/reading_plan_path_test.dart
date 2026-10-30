import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/course_reading_plan.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/quiz/books/adaptive_study_queue.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/book_study_session.dart';
import 'package:theologie_lernapp/quiz/books/reading_plan_path.dart';
import 'package:theologie_lernapp/services/bible/course_reading_schedule.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';

/// Kapitelzahlen der Bücher, die die Tests brauchen (je 60 Verse; Verse
/// spielen für die Zuordnung der Perikopen keine Rolle).
class TestExtent implements BibleExtent {
  static const Map<String, int> chapters = {"GEN": 50, "EXO": 40, "LEV": 27};

  const TestExtent();

  @override
  int? chapterCount(String bookId) => chapters[bookId];

  @override
  int verseCount(String bookId, int chapter) {
    final count = chapters[bookId];

    return count != null && chapter >= 1 && chapter <= count ? 60 : 0;
  }
}

class TestClock {
  DateTime now;

  TestClock(this.now);

  DateTime call() => now;
}

/// Ein Leseplan mit Sitzungen (ID, Termin, Stellen) im Format der Datei.
CourseReadingPlan plan(List<(String, String, List<String>)> sessions) {
  return CourseReadingPlan.fromJson({
    "format": CourseReadingPlan.format,
    "formatVersion": 1,
    "id": "test-plan",
    "name": "Testplan",
    "course": "Übung",
    "source": "Test",
    "sessions": [
      for (final (index, (id, date, readings)) in sessions.indexed)
        {
          "id": id,
          "number": index + 1,
          "date": date,
          "topic": id,
          "readingSource": readings.isEmpty ? "none" : "slides",
          "readings": readings,
        },
    ],
  });
}

void main() {
  late BookCatalog catalog;

  setUpAll(() {
    catalog = BookCatalog.fromPerikopen([
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ]);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Woche 1: Ex 1–20, Woche 2: Ex 21–40, Woche 3: Lev ganz.
  final weekly = plan([
    ("w.01", "2026-11-05", ["EXO 1-20"]),
    ("w.02", "2026-11-12", ["EXO 21-40"]),
    ("w.03", "2026-11-19", ["LEV"]),
  ]);

  CourseSchedule scheduleOn(
    DateTime today, {
    CourseReadingPlan? of,
    String startedOn = "2026-10-29",
    bool wholeBooks = false,
  }) {
    final progress = CourseReadingProgress(
      planId: "test-plan",
      startedOn: startedOn,
      wholeBooks: wholeBooks,
      wholeBooksSince: wholeBooks ? startedOn : null,
    );

    return CourseSchedule.compute(
      plan: of ?? weekly,
      progress: progress,
      today: today,
      extent: const TestExtent(),
    );
  }

  ReadingPlanPath pathOn(
    DateTime today, {
    CourseReadingPlan? of,
    String? startedOn = "2026-10-29",
  }) {
    return ReadingPlanPath.build(
      planId: "test-plan",
      schedule: scheduleOn(today, of: of),
      catalog: catalog,
      settings: startedOn == null
          ? null
          : ReadingPathSettings(startedOn: startedOn),
    );
  }

  List<BookPericope> exodus(int from, int to) => [
    for (final p in catalog.pericopesOf("Ex"))
      if (p.chapter >= from && p.chapter <= to) p,
  ];

  /// Führt [pericopes] am Tag [day] ein und fragt sie richtig ab, wie es
  /// eine Lerneinheit tut.
  void learn(
    BookLearningState state,
    Iterable<BookPericope> pericopes,
    DateTime day,
  ) {
    for (final p in pericopes) {
      final card = state.cardFor(p);
      card.introducedAt ??= day;
      card.lastReviewed = day;
      card.stability = 24;
      card.correctCount++;
    }
  }

  group("Wochen aus dem Bibelleseplan", () {
    test("Perikopen gehören zur ersten Woche, deren Stellen sie berühren", () {
      final path = pathOn(DateTime(2026, 10, 30));

      expect(path.weeks.map((w) => w.id), ["w.01", "w.02", "w.03"]);

      final w1 = path.weeks[0];
      final w2 = path.weeks[1];
      final w3 = path.weeks[2];

      expect(w1.books, ["Ex"]);
      expect(w3.books, ["Lev"]);

      // Alle Exodus-Perikopen genau einmal, in Buchreihenfolge.
      expect([...w1.pericopes, ...w2.pericopes], catalog.pericopesOf("Ex"));
      expect(w3.pericopes, catalog.pericopesOf("Lev"));

      // Eine Perikope, die über Kapitel 20 hinausreicht, steht in Woche 1.
      for (final p in w2.pericopes) {
        expect(p.perikope.startChapter, greaterThan(20));
      }

      // Die Mengen ergeben sich aus den Daten, nicht aus dem Code.
      expect(w1.pericopes.length, exodus(1, 20).length);
    });

    test("Leseplan zur Übung: Woche 3 führt Exodus vor Levitikus ein", () {
      final real = CourseReadingPlan.fromJson(
        jsonDecode(
              File(
                "assets/reading_plans/${ReadingPlanPath.defaultPlanId}.json",
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );

      final path = pathOn(
        DateTime(2026, 10, 30),
        of: real,
        startedOn: "2026-10-30",
      );

      final current = path.current!;

      expect(current.id, "bk.03");
      expect(current.books, ["Ex", "Lev"]);

      final books = current.pericopes.map((p) => p.book).toList();
      final firstLev = books.indexOf("Lev");

      expect(firstLev, greaterThan(0));
      expect(books.sublist(firstLev).every((b) => b == "Lev"), isTrue);

      // Nur die Kapitel der Folie (Ex 1–5; 7–24; 32–34 / Lev 16).
      for (final p in current.pericopes) {
        if (p.book == "Lev") expect(p.perikope.startChapter, 16);
        if (p.book == "Ex") {
          expect(
            p.chapters.any(
              (c) => c <= 5 || (c >= 7 && c <= 24) || (c >= 32 && c <= 34),
            ),
            isTrue,
          );
        }
      }

      // Genesis (Sitzung 2 am 29.10., vor Beginn) ist freiwillig.
      final genesis = path.weeks.firstWhere((w) => w.id == "bk.02");
      expect(genesis.beforeStart, isTrue);
    });

    test("Umfang „ganze Bücher“ nimmt die übrigen Kapitel mit", () {
      final real = plan([
        ("w.01", "2026-11-05", ["EXO 1-5", "LEV 16"]),
      ]);

      final whole = ReadingPlanPath.build(
        planId: "test-plan",
        schedule: scheduleOn(
          DateTime(2026, 10, 30),
          of: real,
          wholeBooks: true,
        ),
        catalog: catalog,
        settings: const ReadingPathSettings(startedOn: "2026-10-29"),
      );

      expect(
        whole.weeks.single.pericopes.length,
        catalog.pericopesOf("Ex").length + catalog.pericopesOf("Lev").length,
      );
    });
  });

  group("Tagesmenge und Wochen", () {
    test("Szenario 3: neue Woche – neue Perikopen werden ermittelt", () async {
      // Woche 1 ist gelernt, heute beginnt Woche 2 (Abschluss 11.11.).
      final today = DateTime(2026, 11, 6, 9);
      final path = pathOn(today);
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: () => today,
      );

      learn(state, path.weeks[0].pericopes, DateTime(2026, 11, 1));

      expect(path.current!.id, "w.02");
      expect(path.stateOf(path.weeks[0], state), PathWeekState.done);
      expect(path.stateOf(path.weeks[1], state), PathWeekState.current);
      expect(path.stateOf(path.weeks[2], state), PathWeekState.upcoming);

      final fresh = path.freshDue(state);
      expect(fresh, path.weeks[1].pericopes);

      // 6.–11.11. = 6 Tage (Vorabend der Sitzung).
      expect(path.daysLeftInWeek, 6);
      expect(path.newToday(state), (fresh.length / 6).ceil());

      // Die Lerneinheit führt genau die vorgesehenen ein.
      final planned = path.newToday(state);

      final session = StudySession(
        state: state,
        storage: LocalBookLearningStorage(),
        mode: StudyMode.readingPlan,
        queue: AdaptiveStudyQueue(
          state: state,
          scope: path.scope(state),
          maxNew: path.newToday(state),
          paceNew: true,
        ),
      );

      final introduced = <BookPericope>{};

      while (!session.finished) {
        final task = session.current;
        if (task is IntroduceTask) {
          introduced.add(task.target);
          await session.completeIntroduction();
        }
        session.advance();
      }

      // Trotz fälliger Wiederholungen alle vorgesehenen (Tagesmenge).
      expect(introduced.length, planned);
      expect(path.newToday(state), 0);
      expect(path.weeks[1].pericopes.toSet().containsAll(introduced), isTrue);
    });

    test("Heute Eingeführtes verschiebt die Tagesmenge nicht", () {
      final today = DateTime(2026, 10, 30, 9);
      final path = pathOn(today);
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: () => today,
      );

      final perDay = path.perDay(state);
      final first = path.newToday(state);
      expect(first, perDay);

      learn(state, path.freshDue(state).take(2), today);

      expect(path.perDay(state), perDay);
      expect(path.newToday(state), perDay - 2);
    });

    test("Szenario 5: übersprungene Woche – Rückstand zuerst, konsistent", () {
      // Nichts gelernt, heute in Woche 3 (Abschluss 18.11.).
      final today = DateTime(2026, 11, 15, 9);
      final path = pathOn(today);
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: () => today,
      );

      expect(path.current!.id, "w.03");
      expect(path.stateOf(path.weeks[0], state), PathWeekState.behind);
      expect(path.stateOf(path.weeks[1], state), PathWeekState.behind);

      final backlog = path.backlog(state);
      expect(backlog, [...path.weeks[0].pericopes, ...path.weeks[1].pericopes]);

      // Reihenfolge: Rückstand vor der laufenden Woche.
      final fresh = path.freshDue(state);
      expect(fresh.take(backlog.length), backlog);
      expect(fresh.length, backlog.length + path.weeks[2].pericopes.length);

      // Verteilt auf die verbleibenden 4 Tage (15.–18.11.).
      expect(path.daysLeftInWeek, 4);
      expect(path.newToday(state), (fresh.length / 4).ceil());

      // Die Einheit beginnt beim Rückstand (Fenster der nächsten).
      final scope = path.scope(state);
      expect(scope.take(backlog.length), backlog);
    });

    test("Wochen vor dem Beginn des Lernpfads sind kein Rückstand", () {
      final today = DateTime(2026, 11, 15, 9);
      final path = pathOn(today, startedOn: "2026-11-13");
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: () => today,
      );

      expect(path.stateOf(path.weeks[0], state), PathWeekState.beforeStart);
      expect(path.stateOf(path.weeks[1], state), PathWeekState.beforeStart);
      expect(path.backlog(state), isEmpty);
      expect(path.freshDue(state), path.weeks[2].pericopes);
    });

    test("Szenario 6: Perikopen späterer Wochen schon gelernt", () {
      final today = DateTime(2026, 10, 30, 9);
      final path = pathOn(today);
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: () => today,
      );

      // Woche 2 schon vorher (z. B. als einzelnes Buch) gelernt.
      learn(state, path.weeks[1].pericopes, DateTime(2026, 10, 20));

      expect(path.current!.id, "w.01");
      expect(path.stateOf(path.weeks[1], state), PathWeekState.done);
      expect(path.learnedAhead(state), path.weeks[1].pericopes);

      // Sie werden nicht neu eingeführt, aber wiederholt.
      expect(path.freshDue(state), path.weeks[0].pericopes);
      final scope = path.scope(state);
      expect(scope.toSet().containsAll(path.weeks[1].pericopes), isTrue);
      expect(scope.where((p) => p.book == "Lev"), isEmpty);

      // Nach Woche 1 gibt es in Woche 2 nichts Neues: Vorauslernen springt
      // direkt zu Levitikus.
      learn(state, path.weeks[0].pericopes, today);
      expect(path.aheadWeek(state)!.id, "w.03");
    });

    test("Szenario 7: Übergang von Exodus zu Levitikus nach Zeitplan", () {
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
      );

      // Vor dem Abschluss von Woche 2 (11.11.): Exodus.
      final before = pathOn(DateTime(2026, 11, 11, 20));
      expect(before.current!.books, ["Ex"]);
      expect(before.freshDue(state).every((p) => p.book == "Ex"), isTrue);

      // Bleibt etwas offen, gilt wie beim Lesen spätestens der Sitzungstag.
      expect(pathOn(DateTime(2026, 11, 12, 8)).current!.id, "w.02");

      // Danach: Levitikus ist dran; offenes Exodus bleibt Rückstand.
      final after = pathOn(DateTime(2026, 11, 13, 8));
      expect(after.current!.id, "w.03");
      expect(after.current!.books, ["Lev"]);

      final fresh = after.freshDue(state);
      final firstLev = fresh.indexWhere((p) => p.book == "Lev");
      expect(fresh.sublist(0, firstLev).every((p) => p.book == "Ex"), isTrue);

      // Ist Exodus gelernt, kommt nur noch Levitikus.
      learn(state, catalog.pericopesOf("Ex"), DateTime(2026, 11, 10));
      expect(after.freshDue(state), catalog.pericopesOf("Lev"));
      expect(after.backlog(state), isEmpty);

      // Nach dem Plan: Zieldatum vorbei, Rest ist Rückstand.
      final ended = pathOn(DateTime(2026, 12, 1));
      expect(ended.current, isNull);
      expect(ended.daysLeftInPlan, 0);
      expect(ended.stateOf(ended.weeks[2], state), PathWeekState.behind);
    });
  });

  group("Wiederholung", () {
    test(
      "Szenario 4: fällige und falsch beantwortete Perikopen kommen dran",
      () async {
        final today = DateTime(2026, 11, 6, 9);
        final path = pathOn(today);
        final state = BookLearningState(
          catalog: catalog,
          data: BookLearningData(),
          clock: () => today,
        );

        final w1 = path.weeks[0].pericopes;

        // Woche 1 gelernt; die Hälfte ist fällig, eine oft falsch.
        learn(state, w1, DateTime(2026, 11, 1));
        for (final p in w1.take(w1.length ~/ 2)) {
          state.cardOf(p)!.stability = 12;
        }
        final hard = state.cardOf(w1.first)!
          ..wrongCount = 4
          ..difficulty = 9
          ..lastWrong = DateTime(2026, 11, 5);

        // Sicher beherrschte (langer Abstand) sind nicht fällig.
        for (final p in w1.skip(w1.length ~/ 2)) {
          state.cardOf(p)!
            ..stability = 24 * 30
            ..spacedStreak = 2;
        }

        final due = path.dueReviews(state);
        expect(due.length, w1.length ~/ 2);
        expect(state.statusOf(w1.first).difficult, isTrue);
        expect(hard.wrongCount, 4);

        // Neue Perikopen werden trotzdem eingeführt (eigenes Budget).
        final planned = path.newToday(state);
        expect(planned, greaterThan(0));

        final session = StudySession(
          state: state,
          storage: LocalBookLearningStorage(),
          mode: StudyMode.readingPlan,
          queue: AdaptiveStudyQueue(
            state: state,
            scope: path.scope(state),
            maxNew: path.newToday(state),
            paceNew: true,
          ),
        );

        final reviewed = <BookPericope>{};
        var introduced = 0;

        while (!session.finished) {
          final task = session.current!;
          if (task is IntroduceTask) {
            introduced++;
            await session.completeIntroduction();
          }
          if (task is PericopeTask && task is! IntroduceTask) {
            if (w1.contains(task.target)) reviewed.add(task.target);
          }
          session.advance();
        }

        expect(introduced, planned);
        expect(reviewed, isNotEmpty);
        // Wiederholt wird vor allem Fälliges (gewichtete Wahl).
        expect(reviewed.intersection(due.toSet()), isNotEmpty);
      },
    );
  });

  group("Gemeinsamer Lernstand", () {
    test(
      "Szenario 1: im Einzelbuchmodus gelernt – im Lernpfad eingeführt",
      () async {
        final storage = LocalBookLearningStorage();
        final clock = TestClock(DateTime(2026, 10, 30, 9));
        final state = BookLearningState(
          catalog: catalog,
          data: await storage.load(),
          clock: clock.call,
        );

        final p = catalog.pericopesOf("Ex").first;

        // „Einzelne Bücher“: Buch-Lerneinheit über Exodus.
        final session = StudySession(
          state: state,
          storage: storage,
          mode: StudyMode.learnBook,
          tasks: [IntroduceTask(p), RecallTask(p, afterIntroduction: true)],
        );

        await session.completeIntroduction();
        session.advance();
        await session.answerRecall("1");
        await session.flush();

        // Neu geladen wie beim nächsten Öffnen des Lernpfads.
        final reloaded = BookLearningState(
          catalog: catalog,
          data: await LocalBookLearningStorage().load(),
          clock: clock.call,
        );

        final path = pathOn(clock.now);

        expect(path.weeks[0].pericopes, contains(p));
        expect(path.freshDue(reloaded), isNot(contains(p)));
        expect(path.progress(reloaded).learning, 1);
        expect(path.introducedToday(reloaded), 1);
        expect(reloaded.cardOf(p)!.correctCount, 1);
      },
    );

    test(
      "Szenario 2: im Lernpfad gelernt – im Einzelbuchmodus fortgeschritten",
      () async {
        final storage = LocalBookLearningStorage();
        final clock = TestClock(DateTime(2026, 10, 30, 9));
        final state = BookLearningState(
          catalog: catalog,
          data: await storage.load(),
          clock: clock.call,
        );

        final path = pathOn(clock.now);

        final session = StudySession(
          state: state,
          storage: storage,
          mode: StudyMode.readingPlan,
          queue: AdaptiveStudyQueue(
            state: state,
            scope: path.scope(state),
            maxNew: 1,
          ),
        );

        BookPericope? learned;

        while (!session.finished) {
          final task = session.current!;

          if (task is IntroduceTask) {
            learned = task.target;
            await session.completeIntroduction();
          } else if (task is RecallTask) {
            // „Im Kopf“: gewusst.
            await session.assessRecall(true);
          }

          session.advance();
        }

        await session.flush();

        expect(learned, isNotNull);

        // Eine Karte, derselbe Schlüssel wie im Einzelbuchmodus.
        final data = await LocalBookLearningStorage().load();
        expect(data.cards.keys, [learned!.key]);

        final book = BookLearningState(
          catalog: catalog,
          data: data,
          clock: clock.call,
        );

        final progress = book.progressOf(catalog.pericopesOf("Ex"));
        expect(progress.learning, 1);
        expect(progress.fresh, catalog.pericopesOf("Ex").length - 1);
        expect(book.introducedOn("Ex", clock.now), 1);
        expect(book.cardOf(learned)!.correctCount, 1);
        expect(book.cardOf(learned)!.lastReviewed, clock.now);
      },
    );
  });

  group("Speicherung", () {
    test("Beginn steht in pericope_plans neben den Buchplänen", () async {
      final storage = LocalBookLearningStorage();

      // Bestehender Buchplan aus früheren Versionen.
      await LocalLearningStore.instance.mergeQuizDocument(
        LocalLearningStore.pericopePlans,
        "plans",
        {
          "Ex": {"dailyNew": 4, "createdAt": 0},
        },
      );

      var data = await storage.load();
      expect(data.readingPaths, isEmpty);
      expect(data.plans["Ex"]!.dailyNew, 4);

      await storage.saveReadingPath(
        "test-plan",
        const ReadingPathSettings(startedOn: "2026-10-30"),
      );

      data = await LocalBookLearningStorage().load();
      expect(data.readingPaths["test-plan"]!.startedOn, "2026-10-30");
      expect(data.plans["Ex"]!.dailyNew, 4);

      await storage.saveReadingPath("test-plan", null);

      data = await LocalBookLearningStorage().load();
      expect(data.readingPaths, isEmpty);
      expect(data.plans["Ex"]!.dailyNew, 4);
    });

    test("Ohne Beginn: Vorschau ohne Tagesmenge, nur Wiederholungen", () {
      final today = DateTime(2026, 10, 30, 9);
      final path = pathOn(today, startedOn: null);
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: () => today,
      );

      expect(path.started, isFalse);
      expect(path.current!.id, "w.01");
      expect(path.newToday(state), 0);
      expect(path.scope(state), isEmpty);
    });
  });
}
