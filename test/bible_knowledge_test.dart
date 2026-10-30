import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/algorithms/spaced_repetition.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_controller.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_status.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/quiz/books/knowledge.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';

class FakeSettingsService implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Gen"};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLearningService implements LearningService {
  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> readJson(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

const String modelAnswers =
    "assets/old_testament/model_answers/bk02-genesis.json";

/// Alle Fragen aus den Dateien wie in der App (öffentlich + Musterantworten).
KnowledgeBank fullBank() {
  final index = readJson("${KnowledgeBank.root}/index.json");

  return KnowledgeBank.merge([
    for (final file in index["files"] as List)
      KnowledgeBank.parse(readJson("${KnowledgeBank.root}/$file")),
    KnowledgeBank.parse(readJson(modelAnswers)),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const chapters = {"Gen": 50, "Ex": 40, "Lev": 27};

  late KnowledgeBank bank;
  late List<Perikope> perikopen;
  late BookOutlines outlines;

  setUpAll(() {
    bank = fullBank();

    perikopen = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        if (chapters.containsKey(entry["book"]))
          Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];

    outlines = BookOutlines.fromJson(readJson(BookOutlines.asset));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  var now = DateTime(2026, 11, 2, 8);

  Future<BookLearningController> loadWith(BookLearningStorage storage) async {
    final controller = await BookLearningController.load(
      perikopen: perikopen,
      uid: null,
      storage: storage,
      learningService: FakeLearningService(),
      settingsService: FakeSettingsService(),
      outlines: outlines,
      clock: () => now,
      loadKnowledge: (_) async => bank,
    );
    await controller.knowledgeReady;
    return controller;
  }

  Future<BookLearningController> load() => loadWith(LocalBookLearningStorage());

  group("Daten", () {
    test("alle Dateien lesbar, IDs eindeutig, Bereiche im Buch", () {
      expect(bank.ofBook("Gen").length, greaterThanOrEqualTo(33 + 51));
      expect(bank.ofBook("Ex").length, greaterThanOrEqualTo(29));
      expect(bank.ofBook("Lev").length, greaterThanOrEqualTo(18));

      final ids = [for (final q in bank.questions) q.id];
      expect(ids.toSet().length, ids.length);

      for (final q in bank.questions) {
        expect(chapters, contains(q.book), reason: q.id);

        final range = q.range;
        if (range == null) continue;

        expect(range.startChapter, greaterThanOrEqualTo(1), reason: q.id);
        expect(
          range.endChapter,
          lessThanOrEqualTo(chapters[q.book]!),
          reason: q.id,
        );
        expect(
          range.startChapter,
          lessThanOrEqualTo(range.endChapter),
          reason: q.id,
        );
      }

      // Keine Frage zweimal mit demselben Wortlaut im selben Buch.
      final prompts = [for (final q in bank.questions) "${q.book}|${q.prompt}"];
      expect(prompts.toSet().length, prompts.length);
    });

    test("Musterantworten: zehn Aufgaben, je mit Lernfragen verknüpft", () {
      final tasks = bank.tasksOf("Gen");

      expect(tasks.length, 10);
      expect(
        [for (final t in tasks) t.number],
        [for (var i = 1; i <= 10; i++) i],
      );

      for (final task in tasks) {
        expect(task.id, startsWith("ma.bk02."));
        expect(task.sessionId, "bk.02");
        expect(task.answer.trim(), isNotEmpty);

        final questions = bank.questionsOfTask(task);
        expect(questions, isNotEmpty, reason: task.id);

        for (final q in questions) {
          expect(q.source, KnowledgeSource.modelAnswer);
          expect(q.taskId, task.id);
          expect(q.sessionId, "bk.02");
        }
      }

      expect([for (final t in tasks) ...bank.questionsOfTask(t)].length, 51);
    });

    test("doppelte IDs beim Zusammenführen werden abgelehnt", () {
      final gen = KnowledgeBank.parse(
        readJson("${KnowledgeBank.root}/gen.json"),
      );

      expect(() => KnowledgeBank.merge([gen, gen]), throwsFormatException);
    });

    test("ungültige Fragen werden abgelehnt", () {
      KnowledgeQuestion parse(Map<String, dynamic> json) =>
          KnowledgeQuestion.fromJson(json, book: "Gen");

      expect(
        () => parse({"id": "x", "format": "reveal", "prompt": "?"}),
        throwsFormatException,
      );
      expect(
        () => parse({
          "id": "x",
          "format": "choice",
          "prompt": "?",
          "correct": ["a"],
          "distractors": ["b"],
        }),
        throwsFormatException,
      );
      expect(
        () => parse({
          "id": "x",
          "format": "order",
          "prompt": "?",
          "items": ["a", "b", "a"],
        }),
        throwsFormatException,
      );
    });
  });

  group("Bereiche", () {
    test("Schreibweisen von Bereichen", () {
      final a = KnowledgeRange.parse("12")!;
      expect((a.startChapter, a.endChapter), (12, 12));

      final b = KnowledgeRange.parse("12-25")!;
      expect((b.startChapter, b.endChapter), (12, 25));

      final c = KnowledgeRange.parse("12,1-25,18")!;
      expect(
        (c.startChapter, c.startVerse, c.endChapter, c.endVerse),
        (12, 1, 25, 18),
      );

      // Ohne Komma nach einem Startvers: Versbereich im selben Kapitel.
      final d = KnowledgeRange.parse("19,1-29")!;
      expect((d.startChapter, d.endChapter, d.endVerse), (19, 19, 29));
    });

    test("Zuordnung zu Kapiteln und zum ganzen Buch", () {
      final inAbraham = bank.inChapters("Gen", 12, 25);

      expect(inAbraham, isNotEmpty);
      for (final q in inAbraham) {
        expect(q.range, isNotNull);
        expect(q.range!.withinChapters(12, 25), isTrue, reason: q.id);
      }

      // Buchfragen ohne Bereich nur beim ganzen Buch.
      expect(inAbraham.any((q) => q.id == "bq.gen.kapitel"), isFalse);
      expect(
        bank.inChapters("Gen", 1, 50, wholeBook: true).map((q) => q.id),
        contains("bq.gen.kapitel"),
      );
    });

    test("Zuordnung zu Abschnitten der Gliederung", () async {
      final controller = await load();
      final outline = controller.outlineFor("Gen");

      final assigned = <String>{};

      for (final section in outline.sections) {
        for (final q in controller.knowledgeOfSection(section)) {
          expect(q.range!.withinSection(section), isTrue, reason: q.id);
          assigned.add(q.id);
        }
      }

      expect(assigned, isNotEmpty);
    });
  });

  group("Einheiten", () {
    setUp(() => now = DateTime(2026, 11, 2, 8));

    test(
      "Wissensfragen mischen sich in die Buch-Einheit, nichts doppelt",
      () async {
        final controller = await load();
        final session = controller.bookSession("Gen");

        final asked = <String>[];
        var pericopeTasks = 0;
        var guard = 0;

        while (!session.finished && guard++ < 200) {
          final task = session.current!;

          switch (task) {
            case KnowledgeTask():
              asked.add(task.question.id);
              await session.answerKnowledge(true, given: "");
              session.advance();
            case IntroduceTask():
              await session.completeIntroduction();
              session.advance();
            case PericopeTask():
              pericopeTasks++;
              // Perikopen-Abfragen hier nur überspringen.
              session.advance();
          }
        }

        expect(asked, isNotEmpty);
        expect(asked.length, lessThanOrEqualTo(5));
        expect(asked.toSet().length, asked.length);
        expect(pericopeTasks, greaterThan(0));
        expect(asked.every((id) => bank.question(id)!.book == "Gen"), isTrue);
      },
    );

    test("reine Wissensfragen-Einheit: höchstens 12, davon 6 neu", () async {
      final controller = await load();
      final session = controller.knowledgeSession(bank.ofBook("Ex"));

      final asked = <String>[];
      var guard = 0;

      while (!session.finished && guard++ < 50) {
        final task = session.current as KnowledgeTask;
        asked.add(task.question.id);
        await session.answerKnowledge(false, given: "");
        session.advance();
      }

      // Alle Fragen sind neu: höchstens die erlaubten neuen.
      expect(asked.length, BookLearningController.knowledgeOnlyNew);
      expect(asked.toSet().length, asked.length);
    });

    test("Aufgaben zeigen die Reihenfolge nie schon gelöst", () {
      final order = bank.questions.firstWhere(
        (q) => q.format == KnowledgeFormat.order,
      );

      for (var seed = 0; seed < 50; seed++) {
        final task = KnowledgeTask.of(order, Random(seed));
        expect(task.options, isNot(orderedEquals(order.items)));
        expect(task.options.toSet(), order.items.toSet());
      }
    });
  });

  group("Wiederholung (Spaced Repetition)", () {
    test(
      "falsch: bald fällig; richtig mit Abstand: länger und sicher",
      () async {
        now = DateTime(2026, 11, 2, 8);
        final controller = await load();
        final q = bank.question("bq.gen.kapitel")!;

        final state = controller.state;
        expect(state.knowledgeStatusOf(q).level, LearningLevel.fresh);

        final card = state.knowledgeCardFor(q);
        final algorithm = SpacedRepetition(clock: () => now);

        BookLearningRules.recordRecall(card, false, algorithm, now);
        expect(state.knowledgeStatusOf(q).level, LearningLevel.learning);

        now = now.add(const Duration(days: 1));
        expect(state.knowledgeStatusOf(q).due, isTrue);
        expect(state.dueKnowledge([q]), [q]);

        BookLearningRules.recordRecall(card, true, algorithm, now);
        final firstGap = state.knowledgeStatusOf(q).dueAt!.difference(now);

        now = now.add(const Duration(days: 3));
        BookLearningRules.recordRecall(card, true, algorithm, now);
        final secondGap = state.knowledgeStatusOf(q).dueAt!.difference(now);

        expect(secondGap, greaterThan(firstGap));
        expect(state.knowledgeStatusOf(q).level, LearningLevel.secure);
        expect(state.knowledgeStatusOf(q).due, isFalse);
      },
    );

    test("Wiederholung umfasst fällige Wissensfragen, jede einmal", () async {
      now = DateTime(2026, 11, 2, 8);
      final controller = await load();
      final questions = bank.ofBook("Lev").take(4).toList();

      final session = controller.knowledgeSession(questions);
      while (!session.finished) {
        await session.answerKnowledge(false, given: "");
        session.advance();
      }

      now = now.add(const Duration(days: 2));

      final due = controller.state.dueKnowledge(bank.ofBook("Lev"));
      expect(due.toSet(), questions.toSet());

      final planner = StudyPlanner(controller.state);
      final review = planner.knowledgeReview(due);
      final ids = [for (final t in review) (t as KnowledgeTask).question.id];

      expect(ids.toSet(), {for (final q in questions) q.id});
      expect(ids.toSet().length, ids.length);
    });
  });

  group("Schalter", () {
    test(
      "an als Standard; aus: keine Fragen in Einheiten und Wiederholung",
      () async {
        now = DateTime(2026, 11, 2, 8);
        final controller = await load();

        expect(controller.state.knowledgeEnabled, isTrue);

        await controller.setKnowledgeEnabled(false);

        expect(controller.state.active(bank.ofBook("Gen")), isEmpty);
        expect(
          controller.knowledgeSession(bank.ofBook("Gen")).finished,
          isTrue,
        );

        final session = controller.bookSession("Gen");
        var guard = 0;
        while (!session.finished && guard++ < 100) {
          expect(session.current, isNot(isA<KnowledgeTask>()));
          if (session.current is IntroduceTask) {
            await session.completeIntroduction();
          }
          session.advance();
        }

        // Perikopen bleiben unberührt.
        expect(controller.catalog.pericopesOf("Gen"), isNotEmpty);
      },
    );

    test(
      "Einstellung und Lernstand bleiben über Aus/An und Neuladen",
      () async {
        now = DateTime(2026, 11, 2, 8);
        final storage = LocalBookLearningStorage();
        final controller = await loadWith(storage);
        final questions = bank.ofBook("Ex").take(3).toList();

        final session = controller.knowledgeSession(questions);
        while (!session.finished) {
          await session.answerKnowledge(true, given: "");
          session.advance();
        }
        await session.flush();

        await controller.setKnowledgeEnabled(false);

        final reloaded = await loadWith(LocalBookLearningStorage());
        expect(reloaded.state.knowledgeEnabled, isFalse);
        // Ausgeschaltet: Lernstand ist trotzdem gespeichert.
        for (final q in questions) {
          expect(reloaded.state.knowledgeCardOf(q)?.correctCount, 1);
        }

        await reloaded.setKnowledgeEnabled(true);

        final again = await loadWith(LocalBookLearningStorage());
        expect(again.state.knowledgeEnabled, isTrue);
        expect(
          again.state.knowledgeProgressOf(questions).learning +
              again.state.knowledgeProgressOf(questions).secure,
          questions.length,
        );
        expect(again.state.active(questions), questions);
      },
    );
  });
}
