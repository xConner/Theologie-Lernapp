import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/algorithms/ordered_introduction.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/church_history/church_history_quiz.dart';
import 'package:theologie_lernapp/services/church_history/church_history_store.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';

import 'church_history/church_history_test_data.dart';
import 'old_testament/old_testament_test_data.dart';

void main() {
  group("orderedIntroduction", () {
    final positions = {"a": 2, "b": 0, "c": 1, "d": 0, "e": 3};

    List<String> run(Set<String> seen, {int window = 2}) => orderedIntroduction(
      ["a", "b", "c", "d", "e"],
      idOf: (id) => id,
      cards: {for (final id in seen) id: LearningCard(id: id)},
      positionOf: (id) => positions[id]!,
      window: window,
    );

    test("ohne Lernstand: die ersten neuen Inhalte nach Position, bei "
        "Gleichstand in Pool-Reihenfolge", () {
      expect(run({}), ["b", "d"]);
      expect(run({}, window: 3), ["b", "d", "c"]);
    });

    test("Geübtes bleibt vollständig, Neues rückt nach", () {
      expect(run({"b"}), ["b", "d", "c"]);
      expect(run({"b", "d", "e"}), ["b", "d", "e", "c", "a"]);
      expect(run({"a", "b", "c", "d", "e"}), ["a", "b", "c", "d", "e"]);
    });
  });

  group("Kirchengeschichte", () {
    final data = loadChurchHistory();

    test("Position folgt der ersten Vorlesung bzw. Sitzung", () {
      final quiz = ChurchHistoryQuiz(data: data);
      final candidates = quiz.candidates(
        LearningScope.all,
        QuizKind.values.toSet(),
      );

      for (final c in candidates.where((c) => c.kind == QuizKind.lecture)) {
        final itemId = c.cardId.split("|").first;
        final unit = data.units.indexWhere(
          (u) => u.questions.any((q) => q.id == itemId),
        );
        expect(quiz.positionOf(c), unit, reason: c.cardId);
      }
      expect(
        candidates.map(quiz.positionOf).every((p) => p <= data.units.length),
        isTrue,
      );
    });

    test("ohne Lernstand kommt die erste Aufgabe aus der ersten Vorlesung", () {
      for (var seed = 0; seed < 20; seed++) {
        final quiz = ChurchHistoryQuiz(data: data, random: Random(seed));
        final question = quiz.next(LearningScope.allLectures, {
          QuizKind.lecture,
        }, inOrder: true)!;
        final itemId = question.cardIds.first.split("|").first;
        expect(
          data.units.first.questions.map((q) => q.id),
          contains(itemId),
          reason: "Seed $seed",
        );
      }
    });

    test("Einstellung wird gespeichert und gelesen", () {
      final settings = ChurchHistorySettings().copyWith(inOrder: true);
      expect(ChurchHistorySettings.fromMap(settings.toMap()).inOrder, isTrue);
      expect(ChurchHistorySettings.fromMap({}).inOrder, isFalse);
    });
  });

  group("Altes Testament", () {
    final data = loadOldTestament();

    test("ohne Lernstand nur die ersten drei Inhalte der Einheit", () {
      final kinds = OtQuizKind.values.toSet();
      final first = OldTestamentQuiz(
        data: data,
      ).candidates(OtScope.all, kinds).take(3).map((c) => c.cardId).toSet();

      for (var seed = 0; seed < 20; seed++) {
        final quiz = OldTestamentQuiz(data: data, random: Random(seed));
        final question = quiz.next(OtScope.all, kinds, inOrder: true)!;
        expect(first, contains(question.cardId), reason: "Seed $seed");
      }
    });

    test("ohne die Einstellung bleibt der ganze Pool", () {
      final kinds = OtQuizKind.values.toSet();
      final all = OldTestamentQuiz(data: data).candidates(OtScope.all, kinds);
      final asked = {
        for (var seed = 0; seed < 60; seed++)
          OldTestamentQuiz(
            data: data,
            random: Random(seed),
          ).next(OtScope.all, kinds)!.cardId,
      };
      expect(all.length, greaterThan(3));
      expect(asked.length, greaterThan(3));
    });

    test("Einstellung wird gespeichert und gelesen", () {
      const settings = OldTestamentSettings(inOrder: true);
      expect(OldTestamentSettings.fromMap(settings.toMap()).inOrder, isTrue);
      expect(
        OldTestamentSettings.fromMap(
          settings.copyWith(onlyDifficult: true).toMap(),
        ).inOrder,
        isTrue,
      );
    });
  });
}
