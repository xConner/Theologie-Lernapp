import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/algorithms/spaced_repetition.dart';
import 'package:theologie_lernapp/models/church_history/church_history.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/church_history/church_history_progress.dart';
import 'package:theologie_lernapp/services/church_history/church_history_quiz.dart';
import 'package:theologie_lernapp/services/church_history/church_history_search.dart';
import 'package:theologie_lernapp/services/church_history/church_history_store.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';

import 'church_history_test_data.dart';

final _allKinds = QuizKind.values.toSet();

/// Alle Aufgaben, die der Pool mit mehreren Zufallsfolgen erzeugt.
List<QuizQuestion> _build(
  ChurchHistoryQuiz quiz, {
  LearningScope scope = LearningScope.all,
  Set<QuizKind>? kinds,
  int seeds = 5,
}) {
  return [
    for (var seed = 0; seed < seeds; seed++)
      for (final c in quiz.candidates(scope, kinds ?? _allKinds))
        ?c.build(Random(seed)),
  ];
}

void main() {
  final data = loadChurchHistory();

  group("Aufgaben", () {
    final quiz = ChurchHistoryQuiz(data: data);
    final questions = _build(quiz);

    test("jede Aufgabenart kommt vor", () {
      expect(questions.map((q) => q.kind).toSet(), _allKinds);
    });

    test("fast jeder Inhalt ergibt eine Aufgabe", () {
      final candidates = quiz.candidates(LearningScope.all, _allKinds);
      final built = {
        for (final c in candidates)
          if (c.build(Random(1)) != null) c.cardId,
      };
      expect(built.length, greaterThan(candidates.length * 0.9));
    });

    test("Auswahlfragen haben eindeutige Optionen und eine richtige", () {
      for (final q in questions.whereType<ChoiceQuestion>()) {
        expect(q.options.length, greaterThanOrEqualTo(2), reason: q.prompt);
        expect(q.options.toSet().length, q.options.length, reason: q.prompt);
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
        expect(q.isCorrect(q.correctIndex), isTrue);
        expect(q.cardIds.single, q.cardId);
      }
    });

    test("Ablenker in Datierungsfragen überschneiden sich nicht", () {
      final byLabel = <String, HistoricalDating>{
        for (final e in data.entries)
          if (e.dating != null) e.dating!.label: e.dating!,
      };

      final dateQuestions = questions.whereType<ChoiceQuestion>().where(
        (q) => q.kind == QuizKind.date && q.cardId.endsWith("|date"),
      );
      expect(dateQuestions, isNotEmpty);

      for (final q in dateQuestions) {
        final datings = [for (final o in q.options) byLabel[o]!];
        for (var i = 0; i < datings.length; i++) {
          for (var j = i + 1; j < datings.length; j++) {
            expect(
              datings[i].overlaps(datings[j]),
              isFalse,
              reason: "${q.prompt}: ${q.options}",
            );
          }
        }
      }
    });

    test("Datierungsfrage nennt die Unschärfe", () {
      final q = ChurchHistoryQuiz(data: data)
          .candidates(LearningScope.all, {QuizKind.date})
          .firstWhere((c) => c.cardId == "event.martys_term|date")
          .build(Random(0))!;
      expect(q.prompt, contains("ungefähr"));
    });

    test("Reihenfolge: eindeutig und nie schon sortiert", () {
      final orders = questions.whereType<OrderQuestion>().toList();
      expect(orders, isNotEmpty);

      for (final q in orders) {
        expect(q.items.length, inInclusiveRange(3, 4));
        for (var i = 0; i < q.items.length; i++) {
          for (var j = i + 1; j < q.items.length; j++) {
            expect(q.items[i].dating!.overlaps(q.items[j].dating!), isFalse);
          }
        }
        expect(q.isCorrect(q.items), isFalse);
        expect(q.isCorrect(q.correctOrder), isTrue);
        expect(q.evaluate(q.correctOrder).every((x) => x), isTrue);
        expect(q.cardIds.length, q.items.length);
      }
    });

    test("Personenfragen: verknüpfte Personen sind keine Ablenker", () {
      for (final q in questions.whereType<ChoiceQuestion>().where(
        (q) => q.cardId.endsWith("|actor"),
      )) {
        final event = data.entry(q.cardId.split("|").first)!;
        final linked = {
          for (final p in data.relatedOf(event.id))
            if (p.type == EntryType.person) p.name,
        };
        for (var i = 0; i < q.options.length; i++) {
          if (i == q.correctIndex) continue;
          expect(linked, isNot(contains(q.options[i])), reason: q.prompt);
        }
      }
    });

    test("Personenrätsel verraten den Namen nicht", () {
      for (final q in questions.whereType<ChoiceQuestion>().where(
        (q) => q.cardId.endsWith("|person"),
      )) {
        expect(q.prompt, isNot(contains(q.answer)), reason: q.cardId);
      }
    });

    test("Begriffsfragen verraten die Antwort nicht im Fragetext", () {
      for (final q in questions.whereType<ChoiceQuestion>().where(
        (q) => q.cardId.endsWith("|name"),
      )) {
        expect(
          q.prompt.toLowerCase(),
          isNot(contains(q.answer.toLowerCase())),
          reason: q.cardId,
        );
      }

      // Erklärungen als Antwortmöglichkeit: eigener Name ausgeblendet.
      final martyrdom = questions.whereType<ChoiceQuestion>().firstWhere(
        (q) => q.cardId == "term.martyrdom|term",
      );
      expect(martyrdom.answer.toLowerCase(), isNot(contains("martyrium")));
    });

    test("Fragen ohne Folienbezug sind als Ergänzung erkennbar", () {
      for (final q in questions) {
        if (q.lectureId == null) {
          expect(q.slides, isEmpty);
        } else {
          final lecture = data.lecture(q.lectureId!)!;
          for (final n in q.slides) {
            expect(lecture.slide(n), isNotNull, reason: q.prompt);
          }
        }
      }
    });
  });

  group("Lernumfang", () {
    final quiz = ChurchHistoryQuiz(data: data);

    test("einzelne Vorlesung enthält nur ihre Inhalte", () {
      final ids = {
        for (final c in quiz.candidates(
          const LearningScope.lecture("lecture.01"),
          {QuizKind.lecture, QuizKind.recall},
        ))
          c.cardId.split("|").first,
      };

      expect(ids, contains("q.l01.label"));
      expect(ids.any((id) => id.startsWith("q.l02.")), isFalse);
      expect(ids, isNot(contains("list.persecutions")));
    });

    test("alle bisherigen Vorlesungen umfassen beide Vorlesungen", () {
      final ids = {
        for (final c in quiz.candidates(LearningScope.allLectures, {
          QuizKind.lecture,
        }))
          c.cardId.split("|").first,
      };
      expect(ids.any((id) => id.startsWith("q.l01.")), isTrue);
      expect(ids.any((id) => id.startsWith("q.l02.")), isTrue);
    });

    test("Thema filtert auf seine Einträge", () {
      const scope = LearningScope.theme("theme.martyrdom");
      final entries = quiz.entriesIn(scope);
      expect(entries, isNotEmpty);
      expect(
        entries.every((e) => e.themeIds.contains("theme.martyrdom")),
        isTrue,
      );
      expect(quiz.candidates(scope, {QuizKind.recall}), isEmpty);
    });

    test("Epoche: Ereignisse der Antike", () {
      final entries = quiz.entriesIn(
        const LearningScope.epoch("epoch.antiquity"),
      );
      expect(entries.map((e) => e.id), contains("event.nero_64"));
      expect(entries.map((e) => e.id), isNot(contains("person.karl_holl")));
    });

    test("Schlüssel und Rückweg", () {
      for (final scope in [
        LearningScope.all,
        LearningScope.allLectures,
        const LearningScope.lecture("lecture.02"),
        const LearningScope.epoch("epoch.antiquity"),
        const LearningScope.theme("theme.mission"),
      ]) {
        expect(LearningScope.parse(scope.key, data), scope);
        expect(scope.label(data), isNotEmpty);
      }

      // Gelöschte Vorlesung oder kaputter Wert: alles.
      expect(
        LearningScope.parse("lecture:lecture.99", data),
        LearningScope.all,
      );
      expect(LearningScope.parse("x", data), LearningScope.all);
      expect(LearningScope.parse(null, data), LearningScope.all);
    });
  });

  group("Wiederholung", () {
    test("eine Antwort wird auf die Lernkarte gebucht", () {
      final quiz = ChurchHistoryQuiz(data: data, random: Random(3));
      final q = quiz.next(LearningScope.all, {QuizKind.person})!;

      final changed = quiz.record(q, {for (final id in q.cardIds) id: false});

      expect(changed.map((c) => c.id), q.cardIds);
      expect(quiz.isDifficult(q.cardIds.first), isTrue);
      expect(quiz.cards[q.cardIds.first]!.lastReviewed, isNotNull);
    });

    test("schwierig ist nicht dauerhaft: richtige Antworten senken es", () {
      final quiz = ChurchHistoryQuiz(data: data);
      final q = quiz.next(LearningScope.all, {QuizKind.lecture})!;
      final id = q.cardIds.single;

      quiz.record(q, {id: false});
      expect(quiz.isDifficult(id), isTrue);

      // Richtige Antworten mit zeitlichem Abstand senken den Lernbedarf.
      for (var i = 0; i < 3 && quiz.isDifficult(id); i++) {
        final card = quiz.cards[id]!;
        card.lastReviewed = card.lastReviewed!.subtract(
          const Duration(days: 7),
        );
        quiz.record(q, {id: true});
      }
      expect(quiz.isDifficult(id), isFalse);
    });

    test("„Nur schwierige“ ohne schwierige Inhalte liefert nichts", () {
      final quiz = ChurchHistoryQuiz(data: data);
      expect(
        quiz.next(LearningScope.all, _allKinds, onlyDifficult: true),
        isNull,
      );
    });

    test("„Nur schwierige“ fragt genau diese Inhalte", () {
      final card = LearningCard(id: "q.l02.decius|lecture", difficulty: 8)
        ..lastReviewed = DateTime.now();
      final quiz = ChurchHistoryQuiz(
        data: data,
        cards: {card.id: card},
        random: Random(1),
      );

      for (var i = 0; i < 5; i++) {
        final q = quiz.next(LearningScope.all, _allKinds, onlyDifficult: true);
        if (q == null) {
          // Gerade gestellte Fragen sperrt der Auswähler kurz.
          continue;
        }
        expect(q.cardIds, [card.id]);
      }
    });

    test("Reihenfolge bucht jedes Ereignis einzeln", () {
      final quiz = ChurchHistoryQuiz(data: data, random: Random(4));
      final q = quiz.next(LearningScope.all, {QuizKind.order}) as OrderQuestion;
      final results = q.evaluate(q.items);

      quiz.record(q, {
        for (var i = 0; i < q.items.length; i++) q.cardIds[i]: results[i],
      });

      expect(quiz.cards.length, q.items.length);
    });

    test("Lernstand: neu, zu wiederholen, zuletzt sicher", () {
      final algorithm = SpacedRepetition();
      expect(ReviewState.of(null, algorithm), ReviewState.fresh);

      final good = LearningCard(id: "a");
      algorithm.answer(good, true);
      expect(ReviewState.of(good, algorithm), ReviewState.stable);

      final bad = LearningCard(id: "b");
      algorithm.answer(bad, false);
      expect(ReviewState.of(bad, algorithm), ReviewState.due);

      final summary = ProgressSummary.of(
        ["a", "b", "c", "a"],
        {"a": good, "b": bad},
        algorithm,
      );
      expect(summary.total, 3);
      expect(summary.fresh, 1);
      expect(summary.due, 1);
      expect(summary.stable, 1);
    });
  });

  group("Suche", () {
    final search = ChurchHistorySearch(data);

    test("Name findet Person zuerst", () {
      final hits = search.search("Decius");
      expect(hits.first.targetId, "person.decius");
      expect(hits.map((h) => h.targetId), contains("event.decian_persecution"));
    });

    test("Jahreszahl findet Ereignisse im Zeitraum und Epoche", () {
      final ids = search.search("250").map((h) => h.targetId);
      expect(ids, contains("event.decian_persecution"));
      expect(ids, contains("epoch.antiquity"));
      expect(ids, isNot(contains("event.nero_64")));
    });

    test("Umlaute und Groß-/Kleinschreibung", () {
      expect(
        search.search("maertyrer").map((h) => h.targetId),
        contains("term.martyrdom"),
      );
      expect(ChurchHistorySearch.normalize("Märtyrer"), "maertyrer");
      expect(
        ChurchHistorySearch.normalize("„Propaganda der Tat“"),
        "propaganda der tat",
      );
    });

    test("Folientext wird durchsucht", () {
      final hits = search.search("Matryrium");
      final slide = hits.firstWhere((h) => h.kind == SearchHitKind.slide);
      expect(slide.targetId, "lecture.02");
      expect(slide.slide, 12);
    });

    test("leere Suche und kein Treffer", () {
      expect(search.search("  "), isEmpty);
      expect(search.search("xyzqwv"), isEmpty);
    });
  });

  group("Speicherung", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Lernkarten und Einstellungen bleiben erhalten", () async {
      final store = LocalChurchHistoryStore();
      final card = LearningCard(id: "person.nero|person");
      SpacedRepetition().answer(card, false);

      await store.saveCards([card]);
      await store.saveSettings(
        ChurchHistorySettings(
          scope: "lecture:lecture.02",
          kinds: {QuizKind.order},
          onlyDifficult: true,
        ),
      );

      final cards = await LocalChurchHistoryStore().loadCards();
      expect(cards[card.id]!.difficulty, card.difficulty);

      final settings = await LocalChurchHistoryStore().loadSettings();
      expect(settings.scope, "lecture:lecture.02");
      expect(settings.kinds, {QuizKind.order});
      expect(settings.onlyDifficult, isTrue);
    });

    test("Zurücksetzen einzelner Karten", () async {
      final store = LocalChurchHistoryStore();
      await store.saveCards([LearningCard(id: "a"), LearningCard(id: "b")]);
      await store.resetCards(["a"]);

      expect((await store.loadCards()).keys, ["b"]);
    });

    test("kaputte Einstellungen fallen auf die Vorgaben zurück", () {
      final s = ChurchHistorySettings.fromMap({
        "scope": 3,
        "kinds": ["unknown"],
      });
      expect(s.scope, "all");
      expect(s.kinds, _allKinds);
      expect(ChurchHistorySettings.fromMap(null).onlyDifficult, isFalse);
    });

    test(
      "Bereich zurücksetzen löscht Lernstand, nicht Einstellungen",
      () async {
        final store = LocalChurchHistoryStore();
        await store.saveCards([LearningCard(id: "a")]);
        await store.saveSettings(ChurchHistorySettings(onlyDifficult: true));

        await ProgressDataService().resetArea(null, ProgressArea.churchHistory);

        expect(await store.loadCards(), isEmpty);
        expect((await store.loadSettings()).onlyDifficult, isTrue);
      },
    );

    test("ohne Anmeldung wird lokal gespeichert", () {
      expect(ChurchHistoryStore.forUser(null), isA<LocalChurchHistoryStore>());
      expect(
        LocalLearningStore.quizDocuments,
        containsAll([
          LocalLearningStore.churchHistory,
          LocalLearningStore.churchHistorySettings,
        ]),
      );
    });
  });

  group("Einbindung", () {
    test("Statistik, Serie und Deep Link", () {
      expect(StatisticsTrainer.all, contains(StatisticsTrainer.churchHistory));
      expect(StreakTrack.all, contains(StreakTrack.churchHistory));
      expect(StreakTrack.churchHistory.sources, [
        StreakSource.knowledgeQuiz,
        StreakSource.chronology,
      ]);
      expect(AppDeepLink.churchHistory, "/church-history");
    });
  });
}
