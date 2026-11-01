import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/algorithms/spaced_repetition.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/adaptive_study_queue.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_status.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/quiz/books/book_plan.dart';
import 'package:theologie_lernapp/quiz/books/book_study_session.dart';
import 'package:theologie_lernapp/quiz/books/reference_answer.dart';
import 'package:theologie_lernapp/quiz/books/verse_precision.dart';
import 'package:theologie_lernapp/quiz/quiz_question.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';

import 'fine_mk_fixture.dart';

/// Uhr, die Tests vorstellen können.
class TestClock {
  DateTime now;

  TestClock(this.now);

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

void main() {
  late List<Perikope> all;
  late BookCatalog catalog;

  setUpAll(() {
    // Die Lernlogik wird an der feinen Markus-Gliederung geprüft.
    all = withFineMarkus([
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ]);

    catalog = BookCatalog.fromPerikopen(all);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BookPericope mk(String id, {int occurrence = 0}) {
    return catalog
        .pericopesOf("Mk")
        .where((p) => p.id == id)
        .elementAt(occurrence);
  }

  ExpectedReference precise(BookPericope p, int sc, int sv, int ec, int ev) {
    return ExpectedReference.of(
      p.perikope,
      VersePrecision(
        startChapter: sc,
        startVerse: sv,
        endChapter: ec,
        endVerse: ev,
      ),
    );
  }

  group("Katalog aus den vorhandenen Perikopen", () {
    test("enthält genau die abzufragenden Einträge der Liste", () {
      final required = all.where((p) => p.required).length;

      expect(catalog.all.length, required);

      for (final p in catalog.all) {
        expect(all, contains(p.perikope));
      }
    });

    test("Bücher in biblischer Reihenfolge, Perikopen nach Stelle", () {
      final books = catalog.books;

      expect(books.indexOf("Gen"), lessThan(books.indexOf("Mk")));
      expect(books.indexOf("Mt"), lessThan(books.indexOf("Mk")));
      expect(books.indexOf("Mk"), lessThan(books.indexOf("Offb")));

      final markus = catalog.pericopesOf("Mk");

      expect(markus.first.id, "johannestaeufer");

      for (int i = 1; i < markus.length; i++) {
        final a = markus[i - 1].perikope;
        final b = markus[i].perikope;

        expect(
          a.startChapter < b.startChapter ||
              (a.startChapter == b.startChapter &&
                  a.startVerse <= b.startVerse),
          isTrue,
          reason: "${a.id} vor ${b.id}",
        );
        expect(markus[i].index, i);
      }
    });

    test("mehrfach vorkommende IDs bleiben getrennte Einträge", () {
      final calls = catalog
          .pericopesOf("Mk")
          .where((p) => p.id == "berufungjuenger")
          .toList();

      expect(calls.length, 3);
      expect(calls.map((p) => p.key).toSet().length, 3);
      // Die ID selbst bleibt unverändert.
      expect(calls.every((p) => p.perikope.id == "berufungjuenger"), isTrue);
    });

    test("Kapitel und Kapitelbereiche", () {
      final chapters = catalog.chaptersOf("Mk");

      expect(chapters.first, 1);
      expect(chapters, orderedEquals([...chapters]..sort()));

      final first = catalog.inChapters("Mk", 1, 1);

      expect(first, isNotEmpty);
      expect(first.every((p) => p.chapter == 1), isTrue);
    });
  });

  group("Antwortprüfung passend zur Genauigkeit", () {
    test("kapitelgenau: nur das Kapitel zählt", () {
      final p = mk("berufungjuenger", occurrence: 1);
      final expected = ExpectedReference.of(p.perikope, null);

      expect(expected.versePrecise, isFalse);
      expect(expected.text, "Mk 1");

      expect(ReferenceAnswerChecker.check("Mk 1", expected).correct, isTrue);
      expect(
        ReferenceAnswerChecker.check("Markus 1", expected).correct,
        isTrue,
      );
      // Klein geschrieben und mit Leerraum: dieselbe Stelle.
      expect(ReferenceAnswerChecker.check(" mk 1 ", expected).correct, isTrue);

      // Verse sind hier nicht verlangt – zusätzliche Verse sind kein Fehler.
      final withVerses = ReferenceAnswerChecker.check("Mk 1,14-20", expected);
      expect(withVerses.correct, isTrue);
      expect(withVerses.versesIgnored, isTrue);

      expect(
        ReferenceAnswerChecker.check("Mk 2", expected).verdict,
        AnswerVerdict.wrongChapter,
      );
      expect(
        ReferenceAnswerChecker.check("Mt 1", expected).verdict,
        AnswerVerdict.wrongBook,
      );
      expect(
        ReferenceAnswerChecker.check("Mk", expected).verdict,
        AnswerVerdict.invalid,
      );
    });

    test("kapitelübergreifend kapitelgenau", () {
      final gen = catalog.pericopesOf("Gen").first;
      final expected = ExpectedReference.of(gen.perikope, null);

      expect(expected.text, "Gen 1-2");
      expect(ReferenceAnswerChecker.check("Gen 1-2", expected).correct, isTrue);
      expect(ReferenceAnswerChecker.check("Gen 1–2", expected).correct, isTrue);
      expect(ReferenceAnswerChecker.check("Gen 1", expected).correct, isFalse);
    });

    test("versgenau präzisiert: Verse müssen der Präzisierung entsprechen", () {
      final p = mk("berufungjuenger", occurrence: 1);
      final expected = precise(p, 1, 14, 1, 20);

      expect(expected.text, "Mk 1,14-20");

      for (final ok in [
        "Mk 1,14-20",
        "Mk 1, 14–20",
        "Mk 1:14-20",
        "Markus 1,14-20",
        "Mk 1,14 - 20",
      ]) {
        expect(
          ReferenceAnswerChecker.check(ok, expected).correct,
          isTrue,
          reason: ok,
        );
      }

      expect(
        ReferenceAnswerChecker.check("Mk 1,14-19", expected).verdict,
        AnswerVerdict.wrongVerses,
      );
      expect(
        ReferenceAnswerChecker.check("Mk 1", expected).verdict,
        AnswerVerdict.missingVerses,
      );
      expect(
        ReferenceAnswerChecker.check("Mk 2,14-20", expected).verdict,
        AnswerVerdict.wrongChapter,
      );
    });

    test("Buchkontext: nur Kapitel (und ggf. Verse) eingeben", () {
      final p = mk("berufungjuenger", occurrence: 1);
      final expected = precise(p, 1, 14, 1, 20);

      expect(
        ReferenceAnswerChecker.check(
          "1,14-20",
          expected,
          contextBook: "Mk",
        ).correct,
        isTrue,
      );
      // Wer das Buch trotzdem mittippt, wird nicht bestraft.
      expect(
        ReferenceAnswerChecker.check(
          "Mk 1,14-20",
          expected,
          contextBook: "Mk",
        ).correct,
        isTrue,
      );

      final chapterOnly = ExpectedReference.of(p.perikope, null);

      expect(
        ReferenceAnswerChecker.check(
          "1",
          chapterOnly,
          contextBook: "Mk",
        ).correct,
        isTrue,
      );
      expect(
        ReferenceAnswerChecker.check(
          "2",
          chapterOnly,
          contextBook: "Mk",
        ).verdict,
        AnswerVerdict.wrongChapter,
      );

      // Ohne Buchkontext genügt die Kapitelzahl nicht.
      expect(
        ReferenceAnswerChecker.check("1", chapterOnly).verdict,
        AnswerVerdict.invalid,
      );
    });

    group("Eingabe prüfen, bevor bewertet wird", () {
      String? problem(String input, {String? book}) =>
          ReferenceAnswerChecker.problem(
            input,
            contextBook: book,
            structure: catalog.structure,
          );

      test("leere Eingabe ist kein Fehler", () {
        expect(problem(""), isNull);
        expect(problem("   ", book: "Gen"), isNull);
      });

      test("ein Buch ausgewählt: Kapitelzahl genügt", () {
        expect(problem("5", book: "Gen"), isNull);
        expect(problem("Gen 5", book: "Gen"), isNull);
        expect(problem("Genesis 5", book: "Gen"), isNull);
      });

      test("mehrere Bücher: das Buch ist nötig", () {
        expect(problem("5"), "Bitte auch das Buch angeben, z. B. Gen 5.");
        expect(problem("Gen 5"), isNull);
        expect(problem("gen 5"), isNull);
        expect(problem("1. Mose 5"), isNull);
      });

      test("unbekanntes Buch", () {
        expect(problem("Xyz 5"), "„Xyz“ ist kein bekanntes Bibelbuch.");
      });

      test("Buch ohne Kapitel", () {
        expect(problem("Gen"), startsWith("Bitte auch das Kapitel angeben"));
      });

      test("Kapitel ohne Perikopen", () {
        final max = catalog.structure.chapterCount("Mk");

        expect(max, 16);
        expect(
          problem("${max + 1}", book: "Mk"),
          "In Mk gibt es Perikopen nur bis Kapitel 16.",
        );
        expect(problem("0", book: "Mk"), isNotNull);
      });

      test("unlesbare Angabe", () {
        expect(problem("5,,3", book: "Mk"), startsWith("Ungültige Angabe"));
      });
    });

    test("Bücher mit Ziffer im Namen", () {
      final cor = catalog.pericopesOf("1Kor").first;
      final expected = ExpectedReference.of(cor.perikope, null);

      expect(
        ReferenceAnswerChecker.check(expected.text, expected).correct,
        isTrue,
      );
      expect(
        ReferenceAnswerChecker.check(
          "${cor.perikope.startChapter}",
          expected,
          contextBook: "1Kor",
        ).correct,
        isTrue,
      );

      final makk = catalog.pericopesOf("1.Makk").first;
      final makkExpected = ExpectedReference.of(makk.perikope, null);

      expect(
        ReferenceAnswerChecker.check(makkExpected.text, makkExpected).correct,
        isTrue,
      );
    });

    test("global versgenaue Perikopen bleiben versgenau", () {
      final p = Perikope(
        id: "x",
        title: "Test",
        book: "Mk",
        startChapter: 4,
        startVerse: 35,
        endChapter: 4,
        endVerse: 41,
        required: true,
        precision: "verse",
      );

      final expected = ExpectedReference.of(p, null);

      expect(expected.versePrecise, isTrue);
      expect(expected.personal, isFalse);
      expect(
        ReferenceAnswerChecker.check("Mk 4,35-41", expected).correct,
        isTrue,
      );
      expect(ReferenceAnswerChecker.check("Mk 4", expected).correct, isFalse);
    });
  });

  group("Verspräzisierung prüfen", () {
    final p = Perikope(
      id: "x",
      title: "Test",
      book: "Mk",
      startChapter: 1,
      startVerse: 14,
      endChapter: 1,
      endVerse: 15,
      required: true,
      precision: "chapter",
    );

    int? counts(int chapter) => chapter == 1 ? 45 : null;

    VersePrecision v(int sc, int sv, int ec, int ev) => VersePrecision(
      startChapter: sc,
      startVerse: sv,
      endChapter: ec,
      endVerse: ev,
    );

    test("gültige Präzisierung", () {
      expect(
        VersePrecisionValidator.validate(
          p,
          v(1, 14, 1, 20),
          verseCount: counts,
        ),
        isNull,
      );
    });

    test("Kapitel außerhalb der Perikope", () {
      expect(
        VersePrecisionValidator.validate(p, v(2, 1, 2, 12), verseCount: counts),
        isNotNull,
      );
    });

    test("Endvers vor Anfangsvers", () {
      expect(
        VersePrecisionValidator.validate(
          p,
          v(1, 20, 1, 14),
          verseCount: counts,
        ),
        isNotNull,
      );
    });

    test("Vers jenseits des Kapitelendes", () {
      expect(
        VersePrecisionValidator.validate(
          p,
          v(1, 14, 1, 46),
          verseCount: counts,
        ),
        "Kapitel 1 hat nur 45 Verse.",
      );
    });

    test("ohne bekannte Verszahl nur Formprüfung", () {
      expect(VersePrecisionValidator.validate(p, v(1, 14, 1, 99)), isNull);
    });

    test("Vorschlag stammt aus der Liste, ist aber keine Vorgabe", () {
      expect(VersePrecisionValidator.suggestionOf(p), v(1, 14, 1, 15));
    });

    test("ungültige gespeicherte Werte werden verworfen", () {
      expect(VersePrecision.fromJson({"startChapter": 1}), isNull);
      expect(
        VersePrecision.fromJson({
          "startChapter": 1,
          "startVerse": 5,
          "endChapter": 1,
          "endVerse": 2,
        }),
        isNull,
      );
    });
  });

  group("Lernstatus", () {
    late TestClock clock;
    late SpacedRepetition algorithm;

    setUp(() {
      clock = TestClock(DateTime(2026, 10, 1, 8));
      algorithm = SpacedRepetition(clock: clock.call);
    });

    test("ohne Daten neu", () {
      expect(
        BookLearningRules.statusOf(null, null, clock.now).level,
        LearningLevel.fresh,
      );
    });

    test("sofort nach dem Zeigen der Lösung nie sicher", () {
      final card = BookCard(id: "k", introducedAt: clock.now);

      for (int i = 0; i < 5; i++) {
        clock.advance(const Duration(minutes: 1));
        BookLearningRules.recordRecall(
          card,
          true,
          algorithm,
          clock.now,
          revealed: i == 0,
        );
      }

      final status = BookLearningRules.statusOf(card, null, clock.now);

      expect(card.correctCount, 5);
      expect(card.spacedStreak, 0);
      expect(status.level, LearningLevel.learning);
    });

    test("zwei zeitlich getrennte richtige Abrufe machen sicher", () {
      final card = BookCard(id: "k");

      BookLearningRules.recordRecall(card, true, algorithm, clock.now);

      clock.advance(const Duration(hours: 13));
      BookLearningRules.recordRecall(card, true, algorithm, clock.now);

      expect(
        BookLearningRules.statusOf(card, null, clock.now).level,
        LearningLevel.learning,
      );

      clock.advance(const Duration(days: 1));
      BookLearningRules.recordRecall(card, true, algorithm, clock.now);

      expect(
        BookLearningRules.statusOf(card, null, clock.now).level,
        LearningLevel.secure,
      );
    });

    test("ein Fehler setzt die Zählung zurück", () {
      final card = BookCard(id: "k", lastReviewed: clock.now, spacedStreak: 2);

      clock.advance(const Duration(days: 1));
      BookLearningRules.recordRecall(card, false, algorithm, clock.now);

      final status = BookLearningRules.statusOf(card, null, clock.now);

      expect(status.level, LearningLevel.learning);
      expect(status.recentlyWrong, isTrue);
      expect(card.wrongCount, 1);
    });

    test("sicher gelernt und zugleich fällig", () {
      final card = BookCard(
        id: "k",
        stability: 24,
        lastReviewed: clock.now,
        spacedStreak: 3,
      );

      expect(BookLearningRules.statusOf(card, null, clock.now).due, isFalse);

      clock.advance(const Duration(hours: 25));

      final status = BookLearningRules.statusOf(card, null, clock.now);

      expect(status.level, LearningLevel.secure);
      expect(status.due, isTrue);
      expect(status.label, "Sicher gelernt · Wiederholung fällig");
    });

    test("schwierig nach mehreren Fehlern", () {
      final card = BookCard(id: "k");

      for (int i = 0; i < 2; i++) {
        BookLearningRules.recordRecall(card, false, algorithm, clock.now);
        clock.advance(const Duration(hours: 1));
      }

      expect(
        BookLearningRules.statusOf(card, null, clock.now).difficult,
        isTrue,
      );
    });

    test("Lernstand des Endlos-Quiz als Startwert", () {
      final weak = LearningCard(id: "q", stability: 5, lastReviewed: clock.now);
      final strong = LearningCard(
        id: "q",
        stability: 100,
        lastReviewed: clock.now,
      );

      final weakStatus = BookLearningRules.statusOf(null, weak, clock.now);
      final strongStatus = BookLearningRules.statusOf(null, strong, clock.now);

      expect(weakStatus.level, LearningLevel.learning);
      expect(weakStatus.fromEndlessQuiz, isTrue);
      expect(strongStatus.level, LearningLevel.secure);

      final seeded = BookCard.seeded("k", strong);

      expect(seeded.stability, 100);
      expect(seeded.lastReviewed, clock.now);
      expect(seeded.spacedStreak, BookLearningRules.secureSpacedRecalls);
    });

    test("Reihenfolge-Aufgaben ändern den Status nicht", () {
      final card = BookCard(id: "k");

      BookLearningRules.recordOrder(card, true);
      BookLearningRules.recordOrder(card, false);

      expect(card.lastReviewed, isNull);
      expect(card.orderCorrect, 1);
      expect(card.orderWrong, 1);
      expect(
        BookLearningRules.statusOf(card, null, clock.now).level,
        LearningLevel.fresh,
      );
    });

    test("Fortschritt zählt Stufen und Fälligkeit getrennt", () {
      final progress = LearningProgress.of(const [
        PericopeStatus(level: LearningLevel.fresh),
        PericopeStatus(level: LearningLevel.learning, due: true),
        PericopeStatus(level: LearningLevel.secure, due: true),
        PericopeStatus(level: LearningLevel.secure),
      ]);

      expect(progress.total, 4);
      expect(progress.fresh, 1);
      expect(progress.learning, 1);
      expect(progress.secure, 2);
      expect(progress.due, 2);
      expect(progress.secureShare, 0.5);
    });

    test("Karten überstehen das Speichern", () {
      final card = BookCard(
        id: "k",
        stability: 3,
        difficulty: 6,
        lastReviewed: clock.now,
        correctCount: 4,
        wrongCount: 1,
        spacedStreak: 2,
        lastWrong: clock.now,
        introducedAt: clock.now,
        orderCorrect: 2,
        orderWrong: 3,
      );

      final copy = BookCard.fromJson("k", card.toJson());

      expect(copy.toJson(), card.toJson());
    });
  });

  group("Lernplan und Lerneinheiten", () {
    late TestClock clock;

    setUp(() {
      clock = TestClock(DateTime(2026, 10, 1, 8));
    });

    BookLearningState stateWith({
      Map<String, BookCard>? cards,
      Map<String, BookPlan>? plans,
      Map<String, LearningCard>? legacy,
      Set<String>? legacyBooks,
    }) {
      return BookLearningState(
        catalog: catalog,
        data: BookLearningData(cards: cards, plans: plans),
        legacyCards: legacy,
        legacyBooks: legacyBooks,
        clock: clock.call,
      );
    }

    test("Tagesmenge aus dem Plan, abzüglich heute eingeführter", () {
      final markus = catalog.pericopesOf("Mk");

      final state = stateWith(
        plans: {"Mk": BookPlan(book: "Mk", dailyNew: 5, createdAt: clock.now)},
        cards: {
          markus[0].key: BookCard(id: markus[0].key, introducedAt: clock.now),
          markus[1].key: BookCard(
            id: markus[1].key,
            introducedAt: clock.now.subtract(const Duration(days: 1)),
          ),
        },
      );

      expect(state.introducedOn("Mk", clock.now), 1);
      expect(state.newQuotaToday("Mk"), 4);
    });

    test("pausierter Plan schlägt nichts Neues vor", () {
      final state = stateWith(
        plans: {
          "Mk": BookPlan(
            book: "Mk",
            dailyNew: 5,
            createdAt: clock.now,
            paused: true,
          ),
        },
      );

      expect(state.newQuotaToday("Mk"), 0);

      // Nichts begonnen, nichts Neues: Die Einheit ist sofort zu Ende.
      final queue = AdaptiveStudyQueue(
        state: state,
        scope: catalog.pericopesOf("Mk"),
        maxNew: state.newQuotaToday("Mk"),
      );

      expect(queue.questions, 0);
      expect(queue.next(), isNull);
    });

    test("Zieldatum erhöht die Tagesmenge", () {
      final total = catalog.pericopesOf("Mk").length;

      final plan = BookPlan(
        book: "Mk",
        dailyNew: 1,
        createdAt: clock.now,
        targetDate: DateTime(2026, 10, 10),
      );

      expect(plan.daysLeft(clock.now), 10);
      expect(plan.requiredPerDay(total, clock.now), (total / 10).ceil());
      expect(plan.dailyTarget(total, clock.now), (total / 10).ceil());

      final state = stateWith(plans: {"Mk": plan});

      expect(state.newQuotaToday("Mk"), (total / 10).ceil());
    });

    test("Plan übersteht das Speichern", () {
      final plan = BookPlan(
        book: "Mk",
        dailyNew: 4,
        createdAt: clock.now,
        targetDate: DateTime(2027, 1, 1),
        paused: true,
      );

      final copy = BookPlan.fromJson("Mk", plan.toJson())!;

      expect(copy.toJson(), plan.toJson());
    });

    test("Endlos-Quiz zählt nur für dort ausgewählte Bücher", () {
      final feeding = catalog.all.where((p) => p.id == "speisung5000");

      final legacy = {
        "speisung5000": LearningCard(
          id: "speisung5000",
          stability: 200,
          lastReviewed: clock.now,
        ),
      };

      final state = stateWith(legacy: legacy, legacyBooks: {"Mk"});

      for (final p in feeding) {
        expect(
          state.statusOf(p).level,
          p.book == "Mk" ? LearningLevel.secure : LearningLevel.fresh,
          reason: p.book,
        );
      }
    });

    test("Prüfung fragt jede Perikope einmal ohne Hilfe ab", () {
      final state = stateWith();
      final scope = catalog.inChapters("Mk", 1, 2);

      final tasks = StudyPlanner(state, random: Random(4)).exam(scope);

      expect(tasks.length, scope.length);
      expect(
        tasks.map((t) => (t as PericopeTask).target).toSet(),
        scope.toSet(),
      );
      expect(tasks.every((t) => t is RecallTask), isTrue);
    });
  });

  group("Reihenfolge", () {
    test("Aufgaben werden nur an der tatsächlichen Reihenfolge bewertet", () {
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
      );

      final ordered = catalog.pericopesOf("Mk");

      final tasks = StudyPlanner(
        state,
        random: Random(7),
      ).order(ordered, count: 40);

      expect(tasks, hasLength(40));

      for (final task in tasks) {
        switch (task) {
          case ChoiceTask(kind: ChoiceKind.next):
            final anchor = task.context.single;
            expect(task.target.index, anchor.index + 1);
          case ChoiceTask(kind: ChoiceKind.between):
            expect(task.context[0].index, task.target.index - 1);
            expect(task.context[1].index, task.target.index + 1);
          case ArrangeTask():
            for (int i = 1; i < task.ordered.length; i++) {
              expect(task.ordered[i].index, task.ordered[i - 1].index + 1);
            }
            expect(task.shuffled.toSet(), task.ordered.toSet());
          default:
            fail("Unerwartete Aufgabe $task");
        }

        if (task is ChoiceTask) {
          expect(task.options, contains(task.target));
          // Eindeutige Titel: Jede Option ist unterscheidbar.
          expect(
            task.options.map((p) => p.title).toSet().length,
            task.options.length,
          );
        }
      }
    });

    test("zu wenige Perikopen: keine Aufgaben", () {
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
      );

      expect(
        StudyPlanner(state).order(catalog.pericopesOf("Mk").take(2).toList()),
        isEmpty,
      );
    });
  });

  group("Lerneinheit und Speicherung", () {
    late TestClock clock;

    setUp(() {
      clock = TestClock(DateTime(2026, 10, 1, 8));
    });

    test(
      "Antworten werden verbucht und bleiben nach Neustart erhalten",
      () async {
        final storage = LocalBookLearningStorage();

        final state = BookLearningState(
          catalog: catalog,
          data: await storage.load(),
          clock: clock.call,
        );

        final p = catalog.pericopesOf("Mk").first;

        final session = StudySession(
          state: state,
          storage: storage,
          mode: StudyMode.selection,
          tasks: [IntroduceTask(p), RecallTask(p, afterIntroduction: true)],
        );

        await session.completeIntroduction();
        session.advance();

        final check = await session.answerRecall("Mk 1");

        expect(check.correct, isTrue);

        await session.flush();

        final reloaded = await LocalBookLearningStorage().load();

        final card = reloaded.cards[p.key]!;

        expect(card.introducedAt, clock.now);
        expect(card.correctCount, 1);
        // Direkt nach der Einführung: kein zeitlich getrennter Abruf.
        expect(card.spacedStreak, 0);

        // Die Karten des Endlos-Quiz bleiben unberührt.
        expect(
          await LocalLearningStore.instance.loadCards(
            LocalLearningStore.perikopen,
          ),
          isEmpty,
        );
      },
    );

    test("Prüfung sammelt Fehler mit erwarteter Stelle", () async {
      final storage = LocalBookLearningStorage();

      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: clock.call,
      );

      final first = catalog.pericopesOf("Mk")[0];
      final call = catalog.pericopesOf("Mk")[3];

      state.data.precisions[call.key] = const VersePrecision(
        startChapter: 1,
        startVerse: 14,
        endChapter: 1,
        endVerse: 20,
      );

      final session = StudySession(
        state: state,
        storage: storage,
        mode: StudyMode.exam,
        tasks: [RecallTask(first), RecallTask(call)],
      );

      await session.answerRecall("Mk 1");
      session.advance();
      await session.answerRecall("Mk 1");
      session.advance();

      expect(session.finished, isTrue);
      expect(session.correctCount, 1);
      expect((session.mistakes.single.task as PericopeTask).target, call);
      expect(session.mistakes.single.expected, "Mk 1,14-20");
      expect(
        session.mistakes.single.note,
        "Kapitel richtig, aber die Verse fehlen.",
      );
    });

    test("Reihenfolge ordnen verbucht nur die Reihenfolge", () async {
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
        clock: clock.call,
      );

      final window = catalog.pericopesOf("Mk").sublist(4, 7);

      final session = StudySession(
        state: state,
        storage: LocalBookLearningStorage(),
        mode: StudyMode.order,
        tasks: [
          ArrangeTask(ordered: window, shuffled: window.reversed.toList()),
        ],
      );

      final correct = await session.answerArrange([
        window[0],
        window[2],
        window[1],
      ]);

      expect(correct, isFalse);
      expect(state.cardOf(window[0])!.orderCorrect, 1);
      expect(state.cardOf(window[1])!.orderWrong, 1);
      expect(state.cardOf(window[0])!.lastReviewed, isNull);
    });

    test("Präzisierung speichern, laden und zurücksetzen", () async {
      final storage = LocalBookLearningStorage();
      final p = catalog.pericopesOf("Mk")[3];

      const precision = VersePrecision(
        startChapter: 1,
        startVerse: 14,
        endChapter: 1,
        endVerse: 20,
      );

      await storage.savePrecision(p.key, precision);

      var data = await LocalBookLearningStorage().load();

      expect(data.precisions[p.key], precision);
      expect(
        ExpectedReference.of(p.perikope, data.precisions[p.key]).text,
        "Mk 1,14-20",
      );

      // Die globale Perikope bleibt unverändert.
      expect(p.perikope.precision, "chapter");

      await storage.savePrecision(p.key, null);

      data = await LocalBookLearningStorage().load();

      expect(data.precisions, isEmpty);
      expect(
        ExpectedReference.of(p.perikope, data.precisions[p.key]).text,
        "Mk 1",
      );
    });

    test("Zurücksetzen behält Präzisierungen und Pläne", () async {
      final storage = LocalBookLearningStorage();

      await storage.saveCards([BookCard(id: "a", lastReviewed: clock.now)]);
      await storage.savePrecision(
        "a",
        const VersePrecision(
          startChapter: 1,
          startVerse: 1,
          endChapter: 1,
          endVerse: 2,
        ),
      );
      await storage.savePlan(
        "Mk",
        BookPlan(book: "Mk", dailyNew: 2, createdAt: clock.now),
      );

      expect(await LocalLearningStore.instance.hasGuestData(), isTrue);

      await LocalLearningStore.instance.resetProgress();

      final data = await storage.load();

      expect(data.cards, isEmpty);
      expect(data.precisions, hasLength(1));
      expect(data.plans, hasLength(1));

      await LocalLearningStore.instance.clearGuestData();

      final cleared = await storage.load();

      expect(cleared.precisions, isEmpty);
      expect(cleared.plans, isEmpty);
    });

    test("defekte lokale Daten führen nicht zum Absturz", () async {
      SharedPreferences.setMockInitialValues({
        "guest.v1.quiz_settings.pericope_books": "{kaputt",
        "guest.v1.quiz_settings.pericope_precision": jsonEncode({
          "items": {
            "a": "falsch",
            "b": {"startChapter": 1},
          },
        }),
      });

      final data = await LocalBookLearningStorage().load();

      expect(data.cards, isEmpty);
      expect(data.precisions, isEmpty);
    });
  });

  group("Buchkontext der Lerneinheit", () {
    StudySession sessionFor(List<StudyTask> tasks) => StudySession(
      state: BookLearningState(catalog: catalog, data: BookLearningData()),
      storage: LocalBookLearningStorage(),
      mode: StudyMode.review,
      tasks: tasks,
    );

    test("ein Buch: Buch vorgegeben, Kapitel genügt", () async {
      final p = catalog.pericopesOf("Gen")[4];
      final session = sessionFor([RecallTask(p), RecallTask(p)]);

      expect(session.contextBook, "Gen");
      expect(session.contextBooks, ["Gen"]);
      expect(session.inputProblem("${p.chapter}"), isNull);

      final check = await session.answerRecall("${p.chapter}");

      expect(check.correct, isTrue);
      expect(check.given, "Gen ${p.chapter}");
    });

    test("mehrere Bücher: Buch nötig, gleiche Quelle für Prüfung", () async {
      final gen = catalog.pericopesOf("Gen").first;
      final mark = catalog.pericopesOf("Mk").first;

      final session = sessionFor([RecallTask(mark), RecallTask(gen)]);

      expect(session.contextBook, isNull);
      // In Buchreihenfolge.
      expect(session.contextBooks, ["Gen", "Mk"]);
      expect(session.inputProblem("1"), isNotNull);
      expect(session.inputProblem("Mk 1"), isNull);

      final check = await session.answerRecall("Mk 1");

      expect(check.correct, isTrue);
    });

    test("jede Abfrage einer Einheit hat dieselbe Form", () {
      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(),
      );

      // Der Buchkontext folgt aus dem Umfang der Einheit, nicht aus der
      // einzelnen Aufgabe.
      for (int seed = 0; seed < 5; seed++) {
        final session = StudySession(
          state: state,
          storage: LocalBookLearningStorage(),
          mode: StudyMode.chapter,
          queue: AdaptiveStudyQueue(
            state: state,
            scope: catalog.inChapters("Mk", 1, 3),
            maxNew: 6,
            random: Random(seed),
          ),
        );

        expect(session.contextBook, "Mk");
      }
    });
  });

  group("Buchgliederung", () {
    late BookOutlines outlines;

    setUpAll(() {
      outlines = BookOutlines.fromJson(
        jsonDecode(File(BookOutlines.asset).readAsStringSync())
            as Map<String, dynamic>,
      );
    });

    test("Grenzen kapitel- oder versgenau", () {
      expect(OutlinePosition.parse("6,6")!.verse, 6);
      expect(OutlinePosition.parse("11")!.verse, isNull);
      expect(OutlinePosition.parse(3)!.chapter, 3);
      expect(OutlinePosition.parse("6,"), isNull);
      expect(OutlinePosition.parse("0"), isNull);

      const s = OutlineSection(
        id: "x",
        book: "Mk",
        title: "X",
        start: OutlinePosition(3, 7),
        end: OutlinePosition(6, 5),
      );

      expect(s.containsStart(3, 7), isTrue);
      expect(s.containsStart(3, 6), isFalse);
      expect(s.containsStart(6, 5), isTrue);
      expect(s.containsStart(6, 6), isFalse);
      expect(s.rangeText, "3,7–6,5");

      const whole = OutlineSection(
        id: "y",
        book: "Mk",
        title: "Y",
        start: OutlinePosition(11),
        end: OutlinePosition(13),
      );

      expect(whole.containsStart(13, 37), isTrue);
      expect(whole.containsStart(14, 1), isFalse);
      expect(whole.rangeText, "Kapitel 11–13");
    });

    test(
      "hinterlegte Gliederung: jede Perikope genau einmal, in Reihenfolge",
      () {
        expect(outlines.hasDefined("Mk"), isTrue);

        final outline = outlines.outlineFor(catalog, "Mk");

        expect(outline.provisional, isTrue);
        expect(outline.automatic, isFalse);

        final all = [
          for (final section in outline.sections)
            ...pericopesOfSection(catalog, section),
        ];

        expect(all, catalog.pericopesOf("Mk"));
        expect(
          outline.sections.map((s) => s.id).toSet().length,
          outline.sections.length,
        );

        // Halbvers-Grenze Mk 6,6: Ablehnung in Nazaret (6,1) bleibt vorn,
        // die Aussendung (6,6) beginnt den nächsten Abschnitt.
        final third = pericopesOfSection(catalog, outline.sections[2]);
        final fourth = pericopesOfSection(catalog, outline.sections[3]);

        expect(third.last.title, "Die Ablehnung Jesu in seiner Heimat");
        expect(fourth.first.title, "Die Aussendung der zwölf Jünger");
      },
    );

    test("ohne Gliederung: automatisch nach ganzen Kapiteln", () {
      expect(outlines.hasDefined("Num"), isFalse);

      final outline = outlines.outlineFor(catalog, "Num");

      expect(outline.automatic, isTrue);
      expect(outline.sections, isNotEmpty);

      final all = [
        for (final section in outline.sections)
          ...pericopesOfSection(catalog, section),
      ];

      expect(all, catalog.pericopesOf("Num"));

      for (final section in outline.sections) {
        expect(section.start.verse, isNull);
        expect(section.end.verse, isNull);
      }

      // Bücher mit nur einer Perikope gehen auch.
      expect(outlines.outlineFor(catalog, "Obd").sections, hasLength(1));
    });

    test("Lücken der Gliederung landen in „Weitere Perikopen“", () {
      final partial = BookOutlines.fromJson({
        "books": {
          "Mk": {
            "sections": [
              {"id": "a", "title": "Anfang", "start": "1", "end": "2"},
            ],
          },
        },
      });

      final outline = partial.outlineFor(catalog, "Mk");

      expect(outline.sections, hasLength(2));
      expect(outline.sections.last.title, "Weitere Perikopen");

      final rest = pericopesOfSection(catalog, outline.sections.last);

      expect(rest.every((p) => p.chapter >= 3), isTrue);
      expect(
        rest.length +
            pericopesOfSection(catalog, outline.sections.first).length,
        catalog.pericopesOf("Mk").length,
      );
    });

    test("ungültige Abschnitte werden übergangen", () {
      final parsed = BookOutlines.fromJson({
        "books": {
          "Mk": {
            "sections": [
              {"id": "ok", "title": "Gut", "start": "1", "end": "3"},
              {"id": "ok", "title": "Doppelte ID", "start": "4", "end": "5"},
              {"id": "rev", "title": "Rückwärts", "start": "9", "end": "8"},
              {"title": "Ohne ID", "start": "1", "end": "2"},
              {"id": "bad", "title": "Kaputt", "start": "x", "end": "2"},
            ],
          },
          "Lk": "kein Objekt",
        },
      });

      final outline = parsed.outlineFor(catalog, "Mk");

      expect(outline.sections.first.id, "ok");
      expect(outline.sections.where((s) => s.id == "ok"), hasLength(1));
      expect(parsed.hasDefined("Lk"), isFalse);
      expect(BookOutlines.fromJson({}).hasDefined("Mk"), isFalse);
    });

    test("Abschnitt lernen: nur Perikopen des Abschnitts", () {
      final clock = TestClock(DateTime(2026, 10, 1, 8));

      final outline = outlines.outlineFor(catalog, "Mk");
      final section = outline.sections[1];
      final members = pericopesOfSection(catalog, section);

      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(
          cards: {
            members[2].key: BookCard(
              id: members[2].key,
              lastReviewed: clock.now.subtract(const Duration(days: 3)),
            ),
          },
        ),
        clock: clock.call,
      );

      final queue = AdaptiveStudyQueue(
        state: state,
        scope: members,
        maxNew: 6,
        random: Random(3),
      );

      final tasks = [for (var t = queue.next(); t != null; t = queue.next()) t];

      expect(
        tasks.every((t) => section.contains((t as PericopeTask).target)),
        isTrue,
      );
      expect(tasks.whereType<IntroduceTask>().length, 6);
      expect(
        tasks.where((t) => (t as PericopeTask).target == members[2]),
        isNotEmpty,
      );

      // Weitergelernt wird im ersten Abschnitt mit neuen Perikopen.
      expect(state.currentSection(outline)!.id, outline.sections.first.id);
      expect(state.sectionAfter(outline, section)!.id, outline.sections[2].id);
      expect(state.sectionAfter(outline, outline.sections.last), isNull);
    });

    test("alles sicher: der Abschnitt wird trotzdem wiederholt", () {
      final clock = TestClock(DateTime(2026, 10, 1, 8));

      final outline = outlines.outlineFor(catalog, "Mk");
      final section = outline.sections.first;
      final members = pericopesOfSection(catalog, section);

      final state = BookLearningState(
        catalog: catalog,
        data: BookLearningData(
          cards: {
            for (final p in members)
              p.key: BookCard(
                id: p.key,
                stability: 500,
                lastReviewed: clock.now,
                spacedStreak: 3,
              ),
          },
        ),
        clock: clock.call,
      );

      final queue = AdaptiveStudyQueue(state: state, scope: members, maxNew: 6);

      final targets = {
        for (var t = queue.next(); t != null; t = queue.next())
          (t as PericopeTask).target,
      };

      // Kategorien schließen nichts aus: Auch sichere, nicht fällige
      // Perikopen kommen vor – jede einmal.
      expect(targets, members.toSet());
      expect(state.progressOfSection(section).secure, members.length);
      expect(state.currentSection(outline)!.id, outline.sections[1].id);
    });
  });

  group("Endlos-Quiz unverändert", () {
    test("Fragen fassen weiterhin alle Stellen einer ID zusammen", () {
      final questions = QuizQuestion.fromPerikopen(all);

      final calls = questions.singleWhere((q) => q.id == "berufungjuenger");

      expect(calls.variants.where((p) => p.book == "Mk").length, 3);
      expect(questions.length, all.map((p) => p.id).toSet().length);
    });
  });
}
