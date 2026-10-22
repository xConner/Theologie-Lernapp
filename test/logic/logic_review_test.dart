import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/logic/logic_exercise.dart';
import 'package:theologie_lernapp/services/logic/logic_progress_store.dart';
import 'package:theologie_lernapp/services/logic/logic_review.dart';

OpenExercise exercise(String? id) => OpenExercise(
  id: id,
  origin: ExerciseOrigin.course,
  group: "Übung 1",
  question: "Warum?",
  sample: "Darum.",
);

void main() {
  final now = DateTime(2026, 10, 22, 9);

  TaskProgress solved(int correct, DateTime at, {bool last = true}) =>
      TaskProgress(correct: correct, wrong: 0, lastCorrect: last, at: at);

  group("Abstände", () {
    test("wachsen mit den richtigen Lösungen und enden bei 60 Tagen", () {
      expect(
        [for (var c = 1; c <= 7; c++) LogicReview.intervalFor(c)],
        [3, 7, 14, 30, 60, 60, 60],
      );
    });

    test("Fälligkeit nach lokalen Kalendertagen, nicht nach Stunden", () {
      // Abends gelöst, drei Kalendertage später morgens fällig.
      final task = solved(1, DateTime(2026, 10, 19, 23, 50));
      expect(
        LogicReview.isDueAgain(task, DateTime(2026, 10, 21, 23, 59)),
        isFalse,
      );
      expect(
        LogicReview.isDueAgain(task, DateTime(2026, 10, 22, 0, 1)),
        isTrue,
      );
    });

    test("über die Zeitumstellung hinweg", () {
      final task = solved(2, DateTime(2026, 10, 20, 12));
      expect(LogicReview.isDueAgain(task, DateTime(2026, 10, 26, 12)), isFalse);
      expect(
        LogicReview.isDueAgain(task, DateTime(2026, 10, 27, 0, 30)),
        isTrue,
      );
    });

    test("falsch gelöste und ungeübte Übungen sind nicht „wieder fällig“", () {
      expect(LogicReview.isDueAgain(const TaskProgress(), now), isFalse);
      expect(
        LogicReview.isDueAgain(solved(1, DateTime(2026), last: false), now),
        isFalse,
      );
    });
  });

  test("Auswahl: erst falsche, dann fällige, älteste zuerst; ungeübte, "
      "frische und erzeugte Übungen fehlen", () {
    final exercises = [
      exercise("fresh"),
      exercise("recent"),
      exercise("due.new"),
      exercise("wrong.new"),
      exercise("due.old"),
      exercise("wrong.old"),
      exercise(null),
    ];
    final progress = LogicProgress(
      tasks: {
        "recent": solved(1, DateTime(2026, 10, 21)),
        "due.new": solved(1, DateTime(2026, 10, 15)),
        "due.old": solved(4, DateTime(2026, 9, 1)),
        "wrong.new": solved(0, DateTime(2026, 10, 21), last: false),
        "wrong.old": solved(3, DateTime(2026, 10, 1), last: false),
      },
    );

    expect(
      [for (final e in LogicReview.select(exercises, progress, now)) e.id],
      ["wrong.old", "wrong.new", "due.old", "due.new"],
    );
  });
}
