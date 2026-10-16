import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/adaptive_study_queue.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_status.dart';
import 'package:theologie_lernapp/quiz/books/book_study_session.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';

class TestClock {
  DateTime now;

  TestClock(this.now);

  DateTime call() => now;
}

void main() {
  late BookCatalog catalog;
  late List<BookPericope> markus;

  setUpAll(() {
    final all = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];

    catalog = BookCatalog.fromPerikopen(all);
    markus = catalog.pericopesOf("Mk");
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final now = DateTime(2026, 10, 1, 8);

  BookCard learned(
    BookPericope p, {
    double stability = 24,
    double difficulty = 5,
    Duration ago = const Duration(days: 2),
  }) {
    return BookCard(
      id: p.key,
      stability: stability,
      difficulty: difficulty,
      lastReviewed: now.subtract(ago),
      spacedStreak: 1,
    );
  }

  BookLearningState stateWith(
    Map<String, BookCard> cards, {
    Map<String, LearningCard>? legacy,
  }) {
    return BookLearningState(
      catalog: catalog,
      data: BookLearningData(cards: cards),
      legacyCards: legacy,
      legacyBooks: {"Mk"},
      clock: () => now,
    );
  }

  /// Wie oft [p] bei vielen Zufallsfolgen als erste Abfrage kommt.
  int firstPicks(
    BookLearningState state,
    List<BookPericope> scope,
    BookPericope p, {
    int runs = 400,
  }) {
    int count = 0;

    for (int seed = 0; seed < runs; seed++) {
      final queue = AdaptiveStudyQueue(
        state: state,
        scope: scope,
        maxNew: 0,
        random: Random(seed),
      );

      if (queue.next()!.target == p) count++;
    }

    return count;
  }

  group("Auswahl wie im Perikopenquiz", () {
    test("höherer Wiederholungsbedarf wird häufiger gewählt", () {
      final hard = markus[0];
      final easy = markus[1];

      final state = stateWith({
        hard.key: learned(hard, difficulty: 9),
        easy.key: learned(easy, difficulty: 2),
      });

      final hardCount = firstPicks(state, [hard, easy], hard);

      // Lernbedarf 9/5 = 1,8 gegenüber 0,5: etwa 78 %.
      expect(hardCount, greaterThan(260));
      expect(hardCount, lessThan(400));
    });

    test("lange nicht abgefragte vor gerade abgefragten", () {
      final old = markus[0];
      final fresh = markus[1];

      final state = stateWith({
        old.key: learned(old, ago: const Duration(days: 10)),
        fresh.key: learned(fresh, ago: const Duration(minutes: 30)),
      });

      expect(firstPicks(state, [old, fresh], old), greaterThan(380));
    });

    test("nicht chronologisch und mit Zufall bei gleichem Stand", () {
      final scope = markus.take(12).toList();

      final state = stateWith({for (final p in scope) p.key: learned(p)});

      final first = <BookPericope>{};
      final orders = <String>{};

      for (int seed = 0; seed < 50; seed++) {
        final queue = AdaptiveStudyQueue(
          state: state,
          scope: scope,
          maxNew: 0,
          random: Random(seed),
        );

        final targets = [
          for (var t = queue.next(); t != null; t = queue.next()) t.target,
        ];

        first.add(targets.first);
        orders.add(targets.map((p) => p.index).join(","));

        // Jede Perikope genau einmal (alle richtig, keine Wiederholung).
        expect(targets.toSet(), scope.toSet());
      }

      expect(first.length, greaterThan(6));
      expect(orders.length, greaterThan(40));
      expect(orders.contains(scope.map((p) => p.index).join(",")), isFalse);
    });

    test("lang Vergessenes kommt in einer großen Einheit fast immer", () {
      final scope = markus.take(30).toList();
      final forgotten = scope[17];

      final state = stateWith({
        for (final p in scope)
          p.key: p == forgotten
              ? learned(p, stability: 240, ago: const Duration(days: 60))
              : learned(p, stability: 240, ago: const Duration(days: 1)),
      });

      int hits = 0;

      for (int seed = 0; seed < 100; seed++) {
        final queue = AdaptiveStudyQueue(
          state: state,
          scope: scope,
          maxNew: 0,
          random: Random(seed),
        );

        final targets = {
          for (var t = queue.next(); t != null; t = queue.next()) t.target,
        };

        if (targets.contains(forgotten)) hits++;
      }

      expect(hits, greaterThan(95));
    });

    test("Startwert aus dem Endlos-Quiz wird für die Auswahl genutzt", () {
      final a = markus[0];
      final b = markus[1];

      // Nur das Endlos-Quiz kennt a – lange nicht gefragt und schwierig.
      final state = stateWith(
        {b.key: learned(b, ago: const Duration(hours: 1))},
        legacy: {
          a.id: LearningCard(
            id: a.id,
            stability: 24,
            difficulty: 8,
            lastReviewed: now.subtract(const Duration(days: 5)),
          ),
        },
      );

      expect(state.selectionCardOf(a).difficulty, 8);
      expect(firstPicks(state, [a, b], a), greaterThan(380));
    });
  });

  group("Neue Perikopen", () {
    test("aus einem Fenster der nächsten, nicht streng der Reihe nach", () {
      final state = stateWith({});

      final firstIntro = <int>{};

      for (int seed = 0; seed < 60; seed++) {
        final queue = AdaptiveStudyQueue(
          state: state,
          scope: markus,
          maxNew: 3,
          random: Random(seed),
        );

        final tasks = [
          for (var t = queue.next(); t != null; t = queue.next()) t,
        ];

        final intros = tasks.whereType<IntroduceTask>().toList();

        expect(intros, hasLength(3));
        expect(queue.questions, 3);

        for (final intro in intros) {
          // Das Fenster rückt mit jeder eingeführten Perikope nach.
          expect(
            intro.target.index,
            lessThan(AdaptiveStudyQueue.newWindow + intros.length),
          );

          final i = tasks.indexOf(intro);
          final recall = tasks.indexWhere(
            (t) => t is RecallTask && t.target == intro.target,
          );

          // Erst einführen, dann mit Abstand abfragen.
          expect(recall, greaterThan(i + 1));
          expect((tasks[recall] as RecallTask).afterIntroduction, isTrue);
        }

        firstIntro.add(intros.first.target.index);
      }

      expect(firstIntro.length, greaterThan(3));
    });

    test("werden mit Wiederholungen gemischt, nicht nur vorn angehängt", () {
      final learnedOnes = markus.skip(20).take(10).toList();

      final state = stateWith({
        for (final p in learnedOnes)
          p.key: learned(p, ago: const Duration(days: 4)),
      });

      final positions = <int>[];

      for (int seed = 0; seed < 40; seed++) {
        final queue = AdaptiveStudyQueue(
          state: state,
          scope: markus,
          maxNew: 2,
          random: Random(seed),
        );

        final tasks = [
          for (var t = queue.next(); t != null; t = queue.next()) t,
        ];

        positions.add(tasks.indexWhere((t) => t is IntroduceTask));
      }

      // Mal früh, mal später in der Einheit.
      expect(positions.toSet().length, greaterThan(3));
    });

    test("ohne Erlaubnis für Neues bleiben neue Perikopen außen vor", () {
      final p = markus[30];

      final state = stateWith({p.key: learned(p)});

      final queue = AdaptiveStudyQueue(state: state, scope: markus, maxNew: 0);

      final tasks = [for (var t = queue.next(); t != null; t = queue.next()) t];

      expect(tasks.map((t) => t.target), [p]);
    });
  });

  group("Ablauf einer Einheit", () {
    test("Fehler: einmal später erneut, sonst keine Wiederholung", () async {
      final clock = TestClock(now);

      final scope = markus.take(8).toList();

      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(
          cards: {for (final p in scope) p.key: learned(p)},
        ),
        clock: clock.call,
      );

      final wrongOnce = scope[3];

      final session = StudySession(
        state: state,
        storage: LocalBookLearningStorage(),
        mode: StudyMode.chapter,
        queue: AdaptiveStudyQueue(
          state: state,
          scope: scope,
          maxNew: 0,
          random: Random(5),
        ),
      );

      final asked = <BookPericope>[];

      while (!session.finished) {
        final task = session.current!;

        clock.now = clock.now.add(const Duration(minutes: 1));

        if (task is RecallTask) {
          final first = !asked.contains(task.target);

          asked.add(task.target);

          await session.answerRecall(
            task.target == wrongOnce && first
                ? "Mk 16"
                : state.expectedOf(task.target).text,
          );
        } else if (task is ChoiceTask) {
          asked.add(task.target);
          await session.answerChoice(task.correctIndex);
        }

        session.advance();
      }

      expect(asked.where((p) => p == wrongOnce), hasLength(2));
      expect(asked.where((p) => p != wrongOnce).toSet(), hasLength(7));
      // 8 geplante Abfragen plus eine Wiederholung nach dem Fehler.
      expect(asked.length, 9);

      // Nie zweimal direkt hintereinander.
      for (int i = 1; i < asked.length; i++) {
        expect(asked[i], isNot(asked[i - 1]));
      }
    });

    test("Fortschrittsanzeige zählt Abfragen", () {
      final scope = markus.take(4).toList();

      final state = stateWith({for (final p in scope) p.key: learned(p)});

      final session = StudySession(
        state: state,
        storage: LocalBookLearningStorage(),
        mode: StudyMode.chapter,
        queue: AdaptiveStudyQueue(state: state, scope: scope, maxNew: 0),
      );

      expect(session.progressLabel, "Abfrage 1 von 4");
      expect(session.progress, 0);
    });

    test("Auswahl allein ändert keine Lernstände", () {
      final scope = markus.take(10).toList();

      final cards = {for (final p in scope) p.key: learned(p)};
      final before = {
        for (final e in cards.entries) e.key: jsonEncode(e.value.toJson()),
      };

      final legacy = {
        scope.first.id: LearningCard(
          id: scope.first.id,
          stability: 3,
          lastReviewed: now,
        ),
      };

      final state = stateWith(cards, legacy: legacy);

      final queue = AdaptiveStudyQueue(state: state, scope: scope, maxNew: 0);

      while (queue.next() != null) {}

      expect({
        for (final e in state.data.cards.entries)
          e.key: jsonEncode(e.value.toJson()),
      }, before);
      expect(legacy[scope.first.id]!.stability, 3);
      expect(state.statusOf(scope[2]).level, LearningLevel.learning);
    });
  });
}
