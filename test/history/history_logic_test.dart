import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/history/history_course.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/services/history/history_cards.dart';
import 'package:theologie_lernapp/services/history/history_course_loader.dart';
import 'package:theologie_lernapp/services/history/history_lesson.dart';
import 'package:theologie_lernapp/services/history/history_trainer.dart';

import '../church_history/church_history_test_data.dart';
import '../lecture_materials_test_support.dart';
import 'history_test_support.dart';

HistoryTrainer _trainer(HistoryCourse course, {int seed = 1}) => HistoryTrainer(
  course: course,
  book: HistoryCardBook(store: MemoryCardStore().store),
  random: Random(seed),
);

/// Prüft eine Aufgabe auf Eindeutigkeit und auf verratene Antworten.
void _checkTask(HistoryCourse course, HistoryTask task) {
  final reason = "${task.skill.key}: ${task.prompt}";
  expect(task.cardIds, isNotEmpty, reason: reason);
  for (final id in task.cardIds) {
    expect(HistoryCardBook.isHistoryCard(id), isTrue, reason: id);
  }

  // Fragen nach Zeit und Reihenfolge verraten die Datierung nicht.
  if (const {
    HistorySkill.year,
    HistorySkill.recall,
    HistorySkill.chrono,
    HistorySkill.span,
  }.contains(task.skill)) {
    expect(HistoryItem.revealsDate(task.prompt), isFalse, reason: reason);
  }

  switch (task) {
    case HistoryChoiceTask():
      expect(task.options.length, greaterThanOrEqualTo(2), reason: reason);
      expect(task.options.toSet().length, task.options.length, reason: reason);
      expect(task.correctIndex, inInclusiveRange(0, task.options.length - 1));
      if (task.answer.length > 4) {
        expect(task.prompt.contains(task.answer), isFalse, reason: reason);
      }
    case HistoryOrderTask():
      expect(task.items.length, greaterThanOrEqualTo(2), reason: reason);
      for (final a in task.items) {
        for (final b in task.items) {
          if (a != b) {
            expect(areOrderable(a, b), isTrue, reason: "${a.id} / ${b.id}");
          }
        }
      }
    case HistoryYearTask():
      expect(task.min, lessThanOrEqualTo(task.max));
      expect(task.item.dating!.approx, isFalse, reason: reason);
    case HistoryExplainTask():
      expect(task.solution, isNotEmpty, reason: reason);
  }
}

/// Spielt den ganzen Lernpfad mit lauter richtigen Antworten durch.
void _learnAll(HistoryTrainer trainer, {bool correct = true}) {
  for (final lesson in trainer.course.lessons) {
    final session = HistoryLessonSession(
      lesson: lesson,
      trainer: trainer,
      known: [
        for (final i in trainer.course.items)
          if (trainer.isIntroduced(i.id)) i,
      ],
    );
    while (session.current != null) {
      final step = session.current!;
      if (step is LessonIntroStep) {
        session.advance();
      } else if (step is LessonTaskStep) {
        _checkTask(trainer.course, step.task);
        trainer.book.record({for (final id in step.task.cardIds) id: correct});
        session.complete(correct);
      }
    }
  }
}

void main() {
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials("Geschichte Schritt für Schritt (Logik)");
    return;
  }

  final courses = {
    "Kirchengeschichte": churchHistoryCourse(),
    "AT Vorlesung": oldTestamentCourse(OtCourseId.lecture),
    "AT Bibelkunde": oldTestamentCourse(OtCourseId.bibelkunde),
  };

  group("Daten", () {
    for (final entry in courses.entries) {
      final course = entry.value;

      test("${entry.key}: Lernschritte sind klein und decken alles ab", () {
        expect(course.items, isNotEmpty);
        expect(course.lessons, isNotEmpty);
        final inLessons = <String>[];
        for (final l in course.lessons) {
          expect(l.itemIds.length, inInclusiveRange(1, 4), reason: l.id);
          inLessons.addAll(l.itemIds);
        }
        expect(inLessons.toSet().length, inLessons.length);
        expect(inLessons.toSet(), {for (final i in course.items) i.id});
      });

      test("${entry.key}: jede Aussage hat eine Quelle", () {
        for (final item in course.items) {
          expect(item.statements, isNotEmpty, reason: item.id);
          for (final s in item.statements.where((s) => !s.supplement)) {
            expect(s.source, isNotNull, reason: item.id);
          }
        }
      });

      test("${entry.key}: Übersichten sind zeitlich stimmig", () {
        for (final s in course.sequences) {
          final items = [for (final id in s.itemIds) course.item(id)!];
          for (var i = 1; i < items.length; i++) {
            expect(
              isClearlyBefore(items[i], items[i - 1]),
              isFalse,
              reason: "${s.id}: ${items[i - 1].id} → ${items[i].id}",
            );
          }
        }
      });
    }

    test("Kirchengeschichte: nutzt die vorhandenen IDs", () {
      final data = loadChurchHistory();
      final course = courses["Kirchengeschichte"]!;
      for (final e in data.entries.where((e) => e.id.startsWith("person."))) {
        expect(course.item(e.id), isNotNull, reason: e.id);
      }
      for (final e in data.epochs) {
        expect(course.item(e.id)?.kind, HistoryItemKind.period);
      }
    });

    test("AT: Datierungen je Veranstaltung, umstrittene markiert", () {
      final vl = courses["AT Vorlesung"]!;
      final bk = courses["AT Bibelkunde"]!;
      final kingdomsVl = vl.item("event.koenigtuemer");
      final kingdomsBk = bk.item("event.koenigtuemer");
      if (kingdomsVl != null && kingdomsBk != null) {
        expect(kingdomsVl.dating!.label, isNot(kingdomsBk.dating!.label));
      }
      for (final course in [vl, bk]) {
        for (final i in course.items) {
          if (i.dating?.disputed ?? false) {
            expect(i.dating!.note, isNotNull, reason: i.id);
          }
        }
      }
    });

    test("Fehlerhafte Daten werden abgelehnt", () {
      final json = readJson(HistoryCourseLoader.churchHistoryPath);
      final lessons = json["lessons"] as List;
      (lessons.first as Map)["items"] = [
        ...(lessons.first as Map)["items"] as List,
        "person.gibt_es_nicht",
      ];
      expect(
        () => HistoryCourseLoader.churchHistory(loadChurchHistory(), json),
        throwsFormatException,
      );
    });
  });

  group("Datierung", () {
    test("ungefähre Angaben überschneiden sich mit Unschärfe", () {
      final course = courses["AT Vorlesung"]!;
      final datings = course.items.where((i) => i.dating != null).toList();
      for (final a in datings) {
        for (final b in datings) {
          if (a == b) continue;
          if (isClearlyBefore(a, b)) {
            expect(isClearlyBefore(b, a), isFalse);
            expect(areOrderable(a, b), isTrue);
          }
        }
      }
    });

    test("Jahrhunderte und Abstände ohne Jahr 0", () {
      expect(yearsBetween(-1, 1), 1);
      expect(yearsBetween(-587, -539), 48);
      expect(centuryOf(-587), -6);
      expect(centuryOf(313), 4);
      expect(centuryLabel(-6), contains("v. Chr."));
    });
  });

  group("Lernstufen", () {
    final course = courses["Kirchengeschichte"]!;

    test("nicht eingeführt → Grundlagen → Verknüpfen → ohne Hilfen", () {
      final trainer = _trainer(course);
      final item = course.items.firstWhere(
        (i) => i.kind == HistoryItemKind.person,
      );
      String card(HistorySkill s) => HistoryTrainer.cardId(item.id, s);

      expect(trainer.stageOf(item), HistoryStage.none);

      trainer.book.record({card(HistorySkill.intro): true});
      expect(trainer.isIntroduced(item.id), isTrue);
      expect(trainer.stageOf(item), HistoryStage.basics);

      trainer.book.record({card(HistorySkill.life): true});
      expect(trainer.stageOf(item), HistoryStage.linking);

      trainer.book.record({card(HistorySkill.deed): true});
      expect(trainer.stageOf(item), HistoryStage.free);

      // Ein Fehler in der Grundlage führt zurück.
      trainer.book.record({card(HistorySkill.life): false});
      expect(trainer.stageOf(item), HistoryStage.basics);
    });

    test("ohne Lernschritt gibt es im eigenen Umfang keine Aufgaben", () {
      final trainer = _trainer(course);
      for (final mode in HistoryMode.values) {
        expect(trainer.next(mode, onlyIntroduced: true), isNull);
      }
      // „Alle Inhalte“ sperrt nichts, beginnt aber mit Grundlagen.
      final task = trainer.next(HistoryMode.mixed, onlyIntroduced: false);
      expect(task, isNotNull);
      expect(task!.skill.stage, HistoryStage.basics);
    });

    test("Chronologie baut sich stufenweise auf", () {
      final trainer = _trainer(course);
      final pool = trainer.pool(onlyIntroduced: false);
      expect(trainer.chronologyLevel(pool), 1);
      final dated = pool.where((i) => i.dating != null).take(10);
      for (final i in dated) {
        trainer.book.record({
          HistoryTrainer.cardId(i.id, HistorySkill.chrono): true,
        });
      }
      expect(trainer.chronologyLevel(pool), 4);
    });
  });

  group("Aufgaben", () {
    for (final entry in courses.entries) {
      test("${entry.key}: eindeutig in allen Modi und Stufen", () {
        for (var seed = 0; seed < 3; seed++) {
          final trainer = _trainer(entry.value, seed: seed);
          _learnAll(trainer);
          // Mehrere Runden: Stufen steigen mit den Antworten.
          for (var round = 0; round < 4; round++) {
            for (final mode in HistoryMode.values) {
              for (var i = 0; i < 15; i++) {
                final task = trainer.next(mode, onlyIntroduced: true);
                if (task == null) break;
                _checkTask(entry.value, task);
                expect(mode.skills, contains(task.skill));
                trainer.book.record({for (final id in task.cardIds) id: true});
              }
            }
          }
        }
      });

      test("${entry.key}: alle Modi haben nach dem Lernpfad Aufgaben", () {
        final trainer = _trainer(entry.value);
        _learnAll(trainer);
        // Jeder Inhalt hat eine Einführungsfrage und gilt danach als
        // eingeführt.
        for (final i in entry.value.items) {
          expect(trainer.isIntroduced(i.id), isTrue, reason: i.id);
        }
        for (var round = 0; round < 3; round++) {
          for (final mode in HistoryMode.values) {
            for (var i = 0; i < 20; i++) {
              final task = trainer.next(mode, onlyIntroduced: true);
              if (task == null) break;
              trainer.book.record({for (final id in task.cardIds) id: true});
            }
          }
        }
        for (final mode in HistoryMode.values) {
          expect(
            trainer.next(mode, onlyIntroduced: true),
            isNotNull,
            reason: mode.name,
          );
        }
      });
    }

    test("Verknüpfungsaufgaben fragen nur nach Eingeführtem", () {
      final course = courses["Kirchengeschichte"]!;
      final trainer = _trainer(course);
      final first = course.lessons.take(3).expand(course.itemsOfLesson);
      final known = first.toSet();
      for (final i in known) {
        for (final s in [
          HistorySkill.intro,
          HistorySkill.life,
          HistorySkill.when,
          HistorySkill.year,
        ]) {
          trainer.book.record({HistoryTrainer.cardId(i.id, s): true});
        }
      }
      for (var n = 0; n < 60; n++) {
        final task = trainer.next(
          HistoryMode.connections,
          onlyIntroduced: true,
        );
        if (task == null) break;
        for (final id in task.itemIds) {
          expect(known.any((i) => i.id == id), isTrue, reason: id);
        }
        trainer.book.record({for (final id in task.cardIds) id: true});
      }
    });
  });

  group("Lernschritt", () {
    final course = courses["Kirchengeschichte"]!;

    test("erst vorstellen, dann prüfen, festigen, verknüpfen", () {
      final trainer = _trainer(course);
      final lesson = course.lessons[1];
      final session = HistoryLessonSession(
        lesson: lesson,
        trainer: trainer,
        known: course.itemsOfLesson(course.lessons[0]),
      );
      final phases = <String>[];
      var introduced = <String>{};
      while (session.current != null) {
        final step = session.current!;
        if (step is LessonIntroStep) {
          phases.add("intro");
          introduced.add(step.item.id);
          session.advance();
        } else if (step is LessonTaskStep) {
          phases.add(step.phase.name);
          // Abgefragt wird nur, was schon vorgestellt ist.
          if (step.phase == LessonPhase.check) {
            expect(introduced, containsAll(step.task.itemIds.take(1)));
          }
          trainer.book.record({for (final id in step.task.cardIds) id: true});
          session.complete(true);
        }
      }
      expect(phases.first, "intro");
      expect(
        phases.indexOf("consolidate"),
        greaterThan(phases.indexOf("check")),
      );
      expect(phases.where((p) => p == "connect").length, lessThanOrEqualTo(2));
      for (final i in course.itemsOfLesson(lesson)) {
        expect(trainer.isIntroduced(i.id), isTrue, reason: i.id);
      }
      expect(session.correct, session.answered);
    });

    test("Fehler kommen mit Abstand wieder, nicht endlos", () {
      final trainer = _trainer(course);
      final session = HistoryLessonSession(
        lesson: course.lessons.first,
        trainer: trainer,
        known: const [],
      );
      session.advance();
      final first = session.current as LessonTaskStep;
      expect(first.phase, LessonPhase.check);
      var seen = 0;
      while (session.current != null) {
        final step = session.current!;
        if (step is LessonIntroStep) {
          session.advance();
          continue;
        }
        step as LessonTaskStep;
        if (identical(step.task, first.task)) {
          seen++;
          session.complete(false);
        } else {
          session.complete(true);
        }
      }
      // Erster Versuch und zwei Wiederholungen.
      expect(seen, 3);
      expect(session.mistakes, containsAll(first.task.itemIds));
      expect(session.correct, session.answered - 1);
    });

    test("Fortschritt ohne Beherrschungsbehauptung", () {
      final trainer = _trainer(course);
      final items = course.itemsOfLesson(course.lessons.first);
      expect(
        HistoryLessonProgress.of(trainer, items).status,
        LessonStatus.fresh,
      );
      trainer.book.record({
        HistoryTrainer.cardId(items.first.id, HistorySkill.intro): true,
      });
      final progress = HistoryLessonProgress.of(trainer, items);
      expect(progress.introduced, 1);
      expect(
        progress.status,
        items.length == 1 ? LessonStatus.introduced : LessonStatus.started,
      );
      expect(progress.cards.total, 1);
    });
  });

  group("Lernkarten", () {
    test("speichert der Reihe nach und lädt nach dem Speichern", () async {
      final memory = MemoryCardStore()..delay = const Duration(milliseconds: 5);
      final book = HistoryCardBook(store: memory.store);
      book.record({"a|h.intro": true});
      book.record({"a|h.intro": false, "b|h.intro": true});
      expect(book.answered("a|h.intro"), isTrue);
      await book.reload();
      expect(memory.writes, [
        ["a|h.intro"],
        ["a|h.intro", "b|h.intro"],
      ]);
      // Der spätere Stand (falsch) ist gespeichert, nicht der frühere.
      expect(
        book["a|h.intro"]!.difficulty,
        memory.saved["a|h.intro"]!.difficulty,
      );
      expect(book.solid("a|h.intro"), isFalse);
    });

    test("ein Fehler beim Speichern blockiert spätere nicht", () async {
      final memory = MemoryCardStore()..fail = true;
      final errors = <Object>[];
      final book = HistoryCardBook(store: memory.store)
        ..onSaveError = errors.add;
      book.record({"a|h.intro": true});
      await book.flush();
      memory.fail = false;
      book.record({"b|h.intro": true});
      await book.flush();
      expect(errors, hasLength(1));
      expect(memory.saved.keys, ["b|h.intro"]);
    });

    test("Zurücksetzen nach ausstehenden Schreibvorgängen", () async {
      final memory = MemoryCardStore()..delay = const Duration(milliseconds: 5);
      final book = HistoryCardBook(store: memory.store);
      book.record({"a|h.intro": true});
      await book.reset(["a|h.intro"]);
      expect(memory.saved, isEmpty);
      expect(book.cards, isEmpty);
    });

    test("Kartennamen trennen sich vom Wissensquiz", () {
      expect(
        HistoryTrainer.cardId("person.decius", HistorySkill.year),
        "person.decius|h.year",
      );
      expect(HistoryCardBook.isHistoryCard("person.decius|role"), isFalse);
      expect(
        HistoryTrainer.nextCardId("seq.persecutions", "event.x"),
        "seq.persecutions/event.x|h.next",
      );
    });
  });
}
