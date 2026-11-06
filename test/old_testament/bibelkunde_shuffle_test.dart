import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/knowledge.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';

import 'old_testament_test_data.dart';

Map<String, dynamic> _json(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

/// Alle Wissensfragen wie in der App (öffentlich + Musterantworten).
KnowledgeBank _bank() {
  final index = _json("${KnowledgeBank.root}/index.json");

  return KnowledgeBank.merge([
    for (final file in index["files"] as List)
      KnowledgeBank.parse(_json("${KnowledgeBank.root}/$file")),
    KnowledgeBank.parse(
      _json("assets/old_testament/model_answers/bk02-genesis.json"),
    ),
  ]);
}

/// Bibelkunde: Antworten erscheinen bei jeder Abfrage in neuer Reihenfolge,
/// Auswahlfragen ziehen ihre falschen Möglichkeiten aus einem Pool, beim
/// Zuordnen werden beide Spalten nur gemischt.
void main() {
  const seeds = 60;

  group("Wissensfragen (Bücher systematisch lernen)", () {
    final bank = _bank();

    List<KnowledgeQuestion> ofFormat(KnowledgeFormat f) => [
      for (final q in bank.questions)
        if (q.format == f) q,
    ];

    test("Auswahl: richtige Antwort + 3 Ablenker aus dem Pool", () {
      for (final q in ofFormat(KnowledgeFormat.choice)) {
        for (var seed = 0; seed < 10; seed++) {
          final task = KnowledgeTask.of(q, Random(seed));
          final shown = task.options.where((o) => o != q.correct.single);

          expect(
            task.options,
            hasLength(1 + KnowledgeTask.shownDistractors),
            reason: q.id,
          );
          expect(
            task.options.where((o) => o == q.correct.single),
            hasLength(1),
            reason: q.id,
          );
          expect(q.distractors, containsAll(shown), reason: q.id);
          expect(
            task.options.toSet(),
            hasLength(task.options.length),
            reason: q.id,
          );
        }
      }
    });

    test("Auswahl: jede Frage hat mehr Ablenker, als gezeigt werden", () {
      for (final q in ofFormat(KnowledgeFormat.choice)) {
        expect(
          q.distractors.length,
          greaterThan(KnowledgeTask.shownDistractors),
          reason: "${q.id}: Pool zu klein für wechselnde Ablenker",
        );
      }
    });

    test("Auswahl: Ablenker und Position der Lösung wechseln", () {
      for (final q in ofFormat(KnowledgeFormat.choice)) {
        final sets = <String>{};
        final positions = <int>{};
        final random = Random(7);

        for (var i = 0; i < seeds; i++) {
          final task = KnowledgeTask.of(q, random);
          sets.add(
            ([...task.options]
                  ..remove(q.correct.single)
                  ..sort())
                .join("|"),
          );
          positions.add(task.options.indexOf(q.correct.single));
        }

        expect(sets.length, greaterThan(1), reason: q.id);
        expect(positions.length, greaterThan(2), reason: q.id);
      }
    });

    test("Mehrfachauswahl: alle richtigen, höchstens 3 Ablenker", () {
      for (final q in ofFormat(KnowledgeFormat.multi)) {
        final random = Random(3);
        final firsts = <String>{};

        for (var i = 0; i < seeds; i++) {
          final task = KnowledgeTask.of(q, random);
          final shown = [
            for (final o in task.options)
              if (!q.correct.contains(o)) o,
          ];

          expect(task.options, containsAll(q.correct), reason: q.id);
          expect(shown.length, min(q.distractors.length, 3), reason: q.id);
          expect(q.distractors, containsAll(shown), reason: q.id);
          firsts.add(task.options.first);
        }

        expect(firsts.length, greaterThan(1), reason: q.id);
      }
    });

    test("Zuordnen: beide Spalten gemischt, sonst unverändert", () {
      final match = ofFormat(KnowledgeFormat.match);
      expect(match, isNotEmpty);

      for (final q in match) {
        final random = Random(11);
        final lefts = <String>{};
        final rights = <String>{};
        final all = [for (var i = 0; i < q.pairs.length; i++) i];

        for (var i = 0; i < seeds; i++) {
          final task = KnowledgeTask.of(q, random);

          expect(task.pairIndices, unorderedEquals(all), reason: q.id);
          expect(
            task.options,
            unorderedEquals([for (final p in q.pairs) p.right]),
            reason: q.id,
          );
          lefts.add(task.pairIndices.join(","));
          rights.add(task.options.join("|"));
        }

        expect(lefts.length, greaterThan(1), reason: q.id);
        expect(rights.length, greaterThan(1), reason: q.id);
      }
    });

    test("ohne gespeicherte Reihenfolge: Paare wie in den Daten", () {
      final q = ofFormat(KnowledgeFormat.match).first;
      final task = KnowledgeTask(q, const []);

      expect(task.pairIndices, [for (var i = 0; i < q.pairs.length; i++) i]);
    });
  });

  group("Übung Bibelkunde (Vorlesungsquiz)", () {
    final bk = loadOldTestament().forCourse(OtCourseId.bibelkunde);
    final quiz = OldTestamentQuiz(data: bk);
    // Eigene Folienfragen der Übung (geteilte Vorlesungsfragen nicht).
    final byCard = {
      for (final u in bk.units)
        for (final q in u.questions)
          OldTestamentQuiz.cardId(q.id, OtQuizKind.lecture): q,
    };
    final curated = [
      for (final c in quiz.candidates(OtScope.all, {OtQuizKind.lecture}))
        if (byCard.containsKey(c.cardId)) c,
    ];

    test("alle Folienfragen sind abfragbar", () {
      expect(curated, hasLength(byCard.length));
    });

    test("jede Folienfrage hat mehr Ablenker, als gezeigt werden", () {
      for (final q in byCard.values) {
        expect(
          q.distractors.length,
          greaterThan(OldTestamentQuiz.shownCuratedDistractors),
          reason: q.id,
        );
      }
    });

    test("Ablenker und Reihenfolge wechseln von Abfrage zu Abfrage", () {
      for (final c in curated) {
        final q = byCard[c.cardId]!;
        final random = Random(5);
        final sets = <String>{};
        final positions = <int>{};

        for (var i = 0; i < seeds; i++) {
          final question = c.build(random)! as OtChoiceQuestion;
          final wrong = [...question.options]..remove(q.answer);

          expect(question.answer, q.answer, reason: q.id);
          expect(
            question.options,
            hasLength(1 + OldTestamentQuiz.shownCuratedDistractors),
            reason: q.id,
          );
          expect(q.distractors, containsAll(wrong), reason: q.id);

          sets.add((wrong..sort()).join("|"));
          positions.add(question.correctIndex);
        }

        expect(sets.length, greaterThan(1), reason: q.id);
        expect(positions.length, greaterThan(2), reason: q.id);
      }
    });
  });
}
