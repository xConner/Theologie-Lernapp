import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_card.dart';
import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/services/memorization/hint_generator.dart';
import 'package:theologie_lernapp/services/memorization/memorization_daily_goal.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/memorization/memorization_scheduler.dart';
import 'package:theologie_lernapp/services/memorization/memorization_session.dart';
import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/widgets/memorization_widgets.dart';

/// Lernzustand beim Auswendiglernen: kurzfristiger Übungsstand und
/// langfristiger Wiederholungsabstand, über alle Lernwege hinweg.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late MemorizationScheduler scheduler;
  late Map<String, MemorizationCard> cards;

  final text = MemorizationText(
    id: "t.de",
    workId: "t",
    title: "Testtext",
    workTitle: "Testtext",
    languageCode: "de",
    type: MemorizationTextType.other,
    segments: [
      for (var i = 0; i < 4; i++)
        MemorizationSegment(id: "t.de.s$i", text: "Abschnitt Nummer $i.", order: i),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    now = DateTime(2026, 3, 1, 9);
    scheduler = MemorizationScheduler(clock: () => now);
    cards = {};
  });

  MemorizationCard card(int index) => cards[text.segments[index].id]!;

  SegmentStatus status(int index) =>
      scheduler.status(cards[text.segments[index].id]);

  /// Freie Wiedergabe eines Abschnitts – der Weg, den jede Übung nimmt.
  void recall(int index, [RecallOutcome outcome = RecallOutcome.correct]) {
    scheduler.apply(
      unit: PracticeUnit.segment(text, index, HintLevel.free),
      practiced: HintLevel.free,
      outcome: outcome,
      cards: cards,
    );
  }

  void wait(Duration duration) => now = now.add(duration);

  /// Gelernter Abschnitt mit dem Abstand [days], zuletzt gestern geübt.
  void setLearned(int index, {required double days}) {
    final id = text.segments[index].id;

    cards[id] = MemorizationCard(
      id: id,
      stability: days * 24,
      lastReviewed: now.subtract(const Duration(days: 1)),
      level: MemorizationCard.maxLevel,
      attempts: 6,
      successes: 6,
      streak: 6,
      learned: true,
      startedAt: now.subtract(const Duration(days: 60)),
    );
  }

  group("Fehler", () {
    test("Fall 1: kleine Abweichung stuft einen sicheren Abschnitt nur "
        "leicht zurück", () {
      setLearned(0, days: 30);
      expect(status(0), SegmentStatus.secure);

      recall(0, RecallOutcome.almost);

      expect(status(0), SegmentStatus.shaky);
      expect(card(0).relearn, MemorizationScheduler.slipSteps);
      expect(card(0).stability, 15 * 24, reason: "halber Abstand bleibt");
      expect(card(0).difficulty, lessThan(5.5));

      // Eine fehlerfreie Wiedergabe genügt zur Bestätigung.
      recall(0);

      expect(status(0), SegmentStatus.stable);
      expect(card(0).stability, greaterThanOrEqualTo(15 * 24));
      expect(scheduler.dueAt(card(0))!.difference(now).inDays, 15);
    });

    test("Fall 5: Vergessen wirft einen langfristig sicheren Abschnitt "
        "zurück", () {
      setLearned(0, days: 40);
      wait(const Duration(days: 39));
      expect(status(0), SegmentStatus.secure);

      recall(0, RecallOutcome.incorrect);

      expect(status(0), SegmentStatus.shaky);
      expect(card(0).relearn, MemorizationScheduler.lapseSteps);
      expect(card(0).streak, 0);
      expect(card(0).lastLapse, now);
      expect(card(0).level, HintLevel.firstLetters.index);
      expect(card(0).stability, closeTo(4 * 24, 0.001));
      expect(card(0).difficulty, 6);

      // Steht sofort wieder im Tagesplan, mit Hilfe.
      final plan = scheduler.planFor(text, cards);
      expect(plan.units.first.from, 0);
      expect(plan.units.first.level, HintLevel.firstLetters);

      recall(0);
      recall(0);

      // Wieder gelernt – aber nicht mehr „langfristig sicher“.
      expect(status(0), SegmentStatus.stable);
      expect(card(0).stability, lessThan(5 * 24));
    });

    test("Fehler wiegt schwerer als kleine Abweichung", () {
      setLearned(0, days: 10);
      setLearned(1, days: 10);

      recall(0, RecallOutcome.almost);
      recall(1, RecallOutcome.incorrect);

      expect(card(0).stability, greaterThan(card(1).stability));
      expect(card(0).relearn, lessThan(card(1).relearn));
      expect(card(0).difficulty, lessThan(card(1).difficulty));
    });
  });

  group("Intensivüben", () {
    test("Fall 2: unsicherer Abschnitt wird durch mehrfach korrektes Üben "
        "wieder gelernt", () {
      recall(0);
      wait(const Duration(days: 1));
      recall(0, RecallOutcome.incorrect);

      expect(status(0), SegmentStatus.shaky);
      expect(scheduler.weakUnits(text, cards).map((u) => u.from), [0]);

      // Einmal richtig reicht noch nicht.
      recall(0);
      expect(status(0), SegmentStatus.shaky);
      expect(card(0).relearn, 1);

      wait(const Duration(seconds: 20));
      recall(0);

      expect(status(0), SegmentStatus.recent);
      expect(card(0).relearn, 0);
      expect(
        segmentStatusLine(scheduler, card(0)),
        "Frisch gelernt · Wiederholung morgen",
      );

      // Der Tagesplan verlangt ihn heute nicht mehr.
      expect(
        scheduler.planFor(text, cards).units.where((u) => u.from == 0),
        isEmpty,
      );

      wait(const Duration(seconds: 20));
      recall(0);

      expect(scheduler.weakUnits(text, cards), isEmpty);
    });

    test("Fall 3: viele richtige Antworten in kurzer Zeit ergeben keinen "
        "langen Abstand", () {
      recall(0);
      wait(const Duration(days: 1));
      recall(0, RecallOutcome.incorrect);

      for (var i = 0; i < 20; i++) {
        wait(const Duration(seconds: 30));
        recall(0);
      }

      expect(status(0), SegmentStatus.recent);
      expect(card(0).streak, 20);
      expect(card(0).stability, lessThan(24));
      expect(
        card(0).stability,
        greaterThanOrEqualTo(MemorizationScheduler.minReviewHours),
      );

      // Morgen steht er wieder an.
      wait(const Duration(days: 1));
      expect(scheduler.isDue(card(0)), isTrue);
    });

    test("Fall 4: zeitlich verteilte Wiederholungen festigen langfristig", () {
      // Dieselbe Anzahl richtiger Antworten, einmal gedrängt …
      recall(0);
      for (var i = 0; i < 6; i++) {
        wait(const Duration(minutes: 1));
        recall(0);
      }
      final crammed = card(0).stability;

      // … einmal über Wochen verteilt.
      recall(1);
      for (final days in [1, 2, 4, 8, 16, 32]) {
        wait(Duration(days: days));
        recall(1);
      }

      expect(card(1).stability, greaterThan(crammed * 10));
      expect(status(1), SegmentStatus.secure);
      expect(scheduler.dueAt(card(1))!.difference(now).inDays, greaterThan(20));
    });

    test("Fall 7: gezieltes Üben eines Abschnitts aktualisiert den "
        "Lernstand – die Runde bleibt dran, bis er bestätigt ist", () {
      setLearned(2, days: 5);

      final session = MemorizationSession(
        scheduler: scheduler,
        cards: cards,
        units: [PracticeUnit.segment(text, 2, HintLevel.free)],
      );

      session.complete(
        practiced: HintLevel.free,
        outcome: RecallOutcome.incorrect,
      );

      expect(status(2), SegmentStatus.shaky);
      expect(session.isFinished, isFalse);

      var freeSuccesses = 0;

      while (!session.isFinished) {
        final level = session.current!.level;

        session.complete(practiced: level, outcome: RecallOutcome.correct);

        if (level == HintLevel.free) freeSuccesses++;

        expect(freeSuccesses, lessThan(10));
      }

      expect(freeSuccesses, MemorizationScheduler.lapseSteps);
      expect(status(2), isNot(SegmentStatus.shaky));
      expect(card(2).relearn, 0);
    });
  });

  group("Schwachstellen", () {
    test("Fall 6: sortiert nach Bedarf; ein alter Einzelfehler zählt "
        "nicht mehr", () {
      // 0: ein einzelner, längst ausgebügelter Fehler.
      setLearned(0, days: 6);
      card(0)
        ..failures = 1
        ..difficulty = 5.25
        ..lastLapse = now.subtract(const Duration(days: 10));

      // 1: wiederholt falsch, zuletzt vor zwei Tagen.
      setLearned(1, days: 2);
      card(1)
        ..failures = 3
        ..successes = 4
        ..streak = 1
        ..difficulty = 7.5
        ..lastLapse = now.subtract(const Duration(days: 2));

      // 2: gerade unsicher.
      setLearned(2, days: 3);
      recall(2, RecallOutcome.incorrect);

      // 3: unauffällig.
      setLearned(3, days: 6);

      expect(scheduler.weakUnits(text, cards).map((u) => u.from), [2, 1]);
      expect(
        scheduler.weakness(card(0)),
        lessThan(MemorizationScheduler.weakThreshold),
      );
      expect(scheduler.weakness(card(3)), 0);
    });
  });

  group("Tagesziel", () {
    test("Fall 8 und 9: Intensivüben allein erfüllt das Tagesziel nicht, "
        "die vorgesehenen Wiederholungen schon", () {
      setLearned(0, days: 8);
      setLearned(1, days: 8);

      MemorizationDailyGoal goal() =>
          MemorizationDailyGoal.of(scheduler, [text], cards);

      expect(goal().open, 2, reason: "zwei neue Abschnitte");

      // Bereits Gelerntes ausgiebig üben.
      for (var i = 0; i < 10; i++) {
        recall(0);
        recall(1);
      }

      expect(goal().open, 2);
      expect(goal().isComplete, isFalse);

      recall(2);
      recall(3);

      expect(goal().open, 1, reason: "ganzer Text steht an");
      expect(goal().isComplete, isFalse);

      scheduler.apply(
        unit: scheduler.fullUnit(text),
        practiced: HintLevel.free,
        outcome: RecallOutcome.correct,
        cards: cards,
      );

      expect(goal().open, 0);
      expect(goal().isComplete, isTrue);
    });

    test("ein im freien Üben entdeckter Fehler gehört zum Tagesplan", () {
      for (var i = 0; i < 4; i++) {
        setLearned(i, days: 8);
      }
      cards[text.fullCardId] = MemorizationCard(
        id: text.fullCardId,
        stability: 8 * 24,
        lastReviewed: now.subtract(const Duration(days: 1)),
        learned: true,
      );

      expect(scheduler.planFor(text, cards).isEmpty, isTrue);

      recall(3, RecallOutcome.incorrect);

      expect(scheduler.planFor(text, cards).units.single.from, 3);
    });

    test("Fall 11: Tageswechsel", () {
      recall(0);
      recall(1);

      expect(scheduler.planFor(text, cards).isEmpty, isTrue);
      expect(
        segmentStatusLine(scheduler, card(0)),
        "Frisch gelernt · Wiederholung morgen",
      );

      // Unbestätigter Fehler bleibt über Nacht unsicher.
      recall(1, RecallOutcome.incorrect);

      wait(const Duration(days: 1));

      expect(status(0), SegmentStatus.recent);
      expect(status(1), SegmentStatus.shaky);
      expect(
        segmentStatusLine(scheduler, card(0)),
        "Frisch gelernt · Wiederholung heute",
      );

      final plan = scheduler.planFor(text, cards);

      expect(plan.reviewSegments, 2);
      expect(plan.newSegments, 2);

      final goal = MemorizationDailyGoal.of(scheduler, [text], cards);
      expect(goal.done, 0, reason: "gestrige Übungen zählen heute nicht");
      expect(goal.open, 4);

      // Nach der Wiederholung am zweiten Tag: gefestigt.
      recall(0);
      expect(status(0), SegmentStatus.stable);
    });
  });

  group("Speicherung", () {
    test("Fall 10: Kurzzeit-Stand übersteht beide Formate", () {
      recall(0);
      wait(const Duration(days: 1));
      recall(0, RecallOutcome.incorrect);
      recall(0);

      final local = MemorizationCard.fromJson("a", card(0).toJson());
      final remote = MemorizationCard.fromFirestore("a", card(0).toFirestore());

      for (final loaded in [local, remote]) {
        expect(loaded.relearn, 1);
        expect(loaded.streak, 1);
        expect(loaded.lastLapse, card(0).lastLapse);
        expect(loaded.stability, card(0).stability);
        expect(scheduler.status(loaded), SegmentStatus.shaky);
      }
    });

    test("Fall 10: Lernstand nach Neustart unverändert (Gast)", () async {
      recall(0);
      recall(1);
      wait(const Duration(days: 1));
      recall(1, RecallOutcome.almost);

      final repository = MemorizationRepository(null);
      await repository.load();
      await repository.saveCards(cards.values.toList());

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      for (final segment in text.segments.take(2)) {
        expect(
          scheduler.status(reloaded.cards[segment.id]),
          scheduler.status(cards[segment.id]),
        );
        expect(
          segmentStatusLine(scheduler, reloaded.cards[segment.id]),
          segmentStatusLine(scheduler, cards[segment.id]),
        );
      }

      expect(scheduler.status(reloaded.cards["t.de.s1"]), SegmentStatus.shaky);
    });

    test("bestehende Lernstände: nichts geht verloren, nichts bleibt "
        "hängen", () {
      // Bisher „unsicher“ wegen eines Fehlers mit Mini-Abstand.
      final stuck = MemorizationCard.fromJson("a", {
        "stability": 0.05,
        "difficulty": 6.0,
        "lastReviewed": now.millisecondsSinceEpoch,
        "level": 5,
        "attempts": 9,
        "successes": 7,
        "failures": 1,
        "learned": true,
      });

      expect(stuck.learned, isTrue);
      expect(stuck.successes, 7);
      expect(stuck.relearn, 1);
      expect(scheduler.status(stuck), SegmentStatus.shaky);

      cards["t.de.s0"] = MemorizationCard.fromJson("t.de.s0", stuck.toJson()
        ..remove("relearn")
        ..remove("streak"));

      recall(0);

      expect(status(0), SegmentStatus.recent);

      // Bisher „unsicher“ nur wegen hoher Schwierigkeit: gilt als gelernt.
      final hard = MemorizationCard.fromJson("b", {
        "stability": 40.0,
        "difficulty": 7.0,
        "lastReviewed": now.millisecondsSinceEpoch,
        "level": 5,
        "successes": 5,
        "failures": 2,
        "learned": true,
      });

      expect(hard.relearn, 0);
      expect(scheduler.status(hard), SegmentStatus.stable);

      // Mit Hilfestufe unter „frei“ weiterhin unsicher, nicht gelernte
      // Abschnitte weiterhin in Arbeit.
      final helped = MemorizationCard.fromJson("c", {
        "level": 3,
        "failures": 1,
        "learned": true,
      });
      final open = MemorizationCard.fromJson("d", {"level": 2, "attempts": 3});

      expect(scheduler.status(helped), SegmentStatus.shaky);
      expect(scheduler.status(open), SegmentStatus.learning);
      expect(open.relearn, 0);
    });
  });
}
