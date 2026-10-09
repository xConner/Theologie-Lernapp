import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_practice_screen.dart';
import 'package:theologie_lernapp/services/memorization/hint_generator.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/memorization/memorization_scheduler.dart';
import 'package:theologie_lernapp/services/memorization/memorization_streak_rule.dart';
import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/streak_widgets.dart';

/// Speicher im Arbeitsspeicher, simuliert Firestore je uid.
class MemoryRepository implements StreakRepository {
  final Map<String, StreakState> data = {};
  int saves = 0;

  @override
  Future<Map<String, StreakState>> loadAll() async => {...data};

  @override
  Future<void> save(StreakState state) async {
    saves++;
    data[state.trackId] = state;
  }
}

void main() {
  const evaluator = MemorizationTextEvaluator();

  const target = ["Vater", "unser", "im", "Himmel"];

  late DateTime now;
  late Map<String?, MemoryRepository> repos;
  late StreakService service;

  StreakService newService() => StreakService(
    repositoryFor: (uid) => repos.putIfAbsent(uid, MemoryRepository.new),
    clock: () => now,
  );

  setUp(() {
    now = DateTime(2026, 9, 21, 10); // Montag
    repos = {};
    service = newService();
  });

  StreakSnapshot snap([StreakTrack track = StreakTrack.memorization]) =>
      service.snapshotFor("u1", track);

  EvaluationResult typed(String input, {bool spoken = false}) {
    return evaluator.evaluateWords(
      target: target,
      input: input,
      spoken: spoken,
    );
  }

  final correct = typed("Vater unser im Himmel");

  /// Wie die Lernrunde nach jeder ausgewerteten Übung: Greift die Regel,
  /// wird der Streak gemeldet. Liefert die Meldung (null = nicht gemeldet).
  /// [result] null = Selbsteinschätzung bzw. Mitlesen.
  Future<StreakUpdate?> exercise(
    EvaluationResult? result, {
    HintLevel level = HintLevel.free,
  }) async {
    if (!MemorizationStreakRule.counts(practiced: level, result: result)) {
      return null;
    }

    return service.recordCorrectAnswer(
      uid: "u1",
      track: StreakTrack.memorization,
      source: StreakSource.memorization,
    );
  }

  Future<void> correctAnswers(int count) async {
    for (var i = 0; i < count; i++) {
      await exercise(correct);
    }
  }

  group("Regel: was zählt", () {
    test("Mitlesen zählt nicht", () {
      expect(MemorizationStreakRule.counts(practiced: HintLevel.read), isFalse);
      expect(
        MemorizationStreakRule.counts(
          practiced: HintLevel.read,
          result: correct,
        ),
        isFalse,
      );
    });

    test("Selbsteinschätzung im Kopf zählt auf keiner Hilfestufe", () {
      for (final level in HintLevel.values) {
        expect(
          MemorizationStreakRule.counts(practiced: level),
          isFalse,
          reason: level.name,
        );
      }
    });

    test("nur wortgetreu richtige Eingaben zählen – getippt und "
        "gesprochen", () {
      for (final spoken in [false, true]) {
        final exact = typed("Vater unser im Himmel", spoken: spoken);

        expect(exact.outcome, RecallOutcome.correct);
        expect(
          MemorizationStreakRule.counts(
            practiced: HintLevel.free,
            result: exact,
          ),
          isTrue,
          reason: "gesprochen: $spoken",
        );

        for (final input in ["Vater unser im", "etwas ganz anderes"]) {
          final result = typed(input, spoken: spoken);

          expect(result.outcome, isNot(RecallOutcome.correct));
          expect(
            MemorizationStreakRule.counts(
              practiced: HintLevel.free,
              result: result,
            ),
            isFalse,
            reason: "$input (gesprochen: $spoken)",
          );
        }
      }
    });

    test("ein richtig gefüllter Lückentext zählt, ein falscher nicht", () {
      for (final (input, expected) in [("unser", true), ("euer", false)]) {
        final gaps = evaluator.evaluateWords(
          target: ["unser"],
          input: input,
          spoken: false,
        );

        expect(
          MemorizationStreakRule.counts(
            practiced: HintLevel.fewGaps,
            result: gaps,
          ),
          expected,
          reason: input,
        );
      }
    });

    test("eine leere Eingabe zählt nicht", () {
      final result = typed(" ?! ");

      expect(result.isEmptyInput, isTrue);
      expect(
        MemorizationStreakRule.counts(
          practiced: HintLevel.free,
          result: result,
        ),
        isFalse,
      );
    });

    test("die Regel folgt der Bewertung des Wortvergleichs unverändert", () {
      for (final input in [
        "Vater unser im Himmel",
        "vater unser im himmel",
        "Vater unsa im Himmel",
        "Vater im unser Himmel",
        "Vater unser",
      ]) {
        final result = typed(input);

        expect(
          MemorizationStreakRule.counts(
            practiced: HintLevel.free,
            result: result,
          ),
          result.outcome == RecallOutcome.correct,
          reason: input,
        );
      }
    });
  });

  group("Streak", () {
    test("Tagesziel sind zehn richtige Antworten", () {
      expect(StreakTrack.memorization.dailyGoal, 10);
    });

    test("9 von 10 erfüllen den Tag nicht, die zehnte Antwort schon", () async {
      for (var i = 1; i <= 9; i++) {
        final update = await exercise(correct);

        expect(update!.goalReachedNow, isFalse, reason: "Antwort $i");
        expect(snap().todayCorrectAnswers, i);
        expect(snap().completedToday, isFalse);
        expect(snap().currentStreak, 0);
      }

      final tenth = await exercise(correct);

      expect(tenth!.goalReachedNow, isTrue);
      expect(tenth.streakStarted, isTrue);
      expect(snap().todayCorrectAnswers, 10);
      expect(snap().completedToday, isTrue);
      expect(snap().currentStreak, 1);
    });

    test("„Gewusst“ im Kopf erfüllt die Schwelle nie", () async {
      for (var i = 0; i < 25; i++) {
        expect(await exercise(null), isNull);
      }

      expect(snap().todayCorrectAnswers, 0);
      expect(snap().completedToday, isFalse);
      expect(repos["u1"]?.saves ?? 0, 0);
    });

    test("falsche, unvollständige und leere Eingaben zählen nicht", () async {
      await correctAnswers(9);

      for (final input in ["Vater unser im", "etwas ganz anderes", " "]) {
        expect(await exercise(typed(input)), isNull, reason: input);
      }

      expect(await exercise(correct, level: HintLevel.read), isNull);

      expect(snap().todayCorrectAnswers, 9);
      expect(snap().completedToday, isFalse);
    });

    test("weitere richtige Antworten nach dem Ziel ändern nichts", () async {
      await correctAnswers(10);
      await Future<void>.delayed(Duration.zero);

      final saves = repos["u1"]!.saves;

      for (var i = 0; i < 5; i++) {
        final again = await exercise(correct);

        expect(again!.changed, isFalse);
        expect(again.goalReachedNow, isFalse);
      }

      expect(snap().currentStreak, 1);
      expect(snap().todayCorrectAnswers, 10);
      expect(snap().todaySources, {StreakSource.memorization: 10});
      expect(repos["u1"]!.saves, saves);
    });

    test(
      "der Zwischenstand bleibt nach erneutem App-Aufruf erhalten",
      () async {
        await correctAnswers(9);
        await Future<void>.delayed(Duration.zero);

        service = newService();
        await service.load("u1");

        expect(snap().todayCorrectAnswers, 9);
        expect(snap().completedToday, isFalse);

        expect((await exercise(correct))!.goalReachedNow, isTrue);
        await Future<void>.delayed(Duration.zero);

        service = newService();
        await service.load("u1");

        expect(snap().completedToday, isTrue);
        expect(snap().currentStreak, 1);
      },
    );

    test("der nächste Tag beginnt bei null, ein ausgelassener Tag beendet "
        "die Streak", () async {
      await correctAnswers(10);

      now = DateTime(2026, 9, 22, 8);

      expect(snap().completedToday, isFalse);
      expect(snap().todayCorrectAnswers, 0);
      expect(snap().currentStreak, 1, reason: "gestern erfüllt → noch aktiv");

      await correctAnswers(9);

      expect(snap().todayCorrectAnswers, 9);
      expect(snap().currentStreak, 1);

      final update = await exercise(correct);

      expect(update!.goalReachedNow, isTrue);
      expect(update.streakStarted, isFalse);
      expect(snap().currentStreak, 2);

      now = DateTime(2026, 9, 24, 8); // Mittwoch ausgelassen
      expect(snap().currentStreak, 0);
      expect(snap().longestStreak, 2);
    });

    test("ein Tag mit nur neun Antworten zählt nicht für die Streak", () async {
      await correctAnswers(10);

      now = DateTime(2026, 9, 22, 8);
      await correctAnswers(9);

      now = DateTime(2026, 9, 23, 8);

      expect(snap().currentStreak, 0);
      expect(snap().longestStreak, 1);

      await correctAnswers(10);

      expect(snap().currentStreak, 1, reason: "neue Streak");
    });

    test("bestehende Streak aus dem alten System (eine Übung am Tag) bleibt "
        "erhalten und läuft mit der neuen Schwelle weiter", () async {
      repos["u1"] = MemoryRepository()
        ..data["memorization"] = StreakState.fromMap("memorization", {
          "currentStreak": 12,
          "longestStreak": 30,
          "lastActivityDate": "2026-09-20",
          "lastCompletedDate": "2026-09-20",
          "todayCorrectAnswers": 1,
          "todaySources": {"memorization": 1},
          "streakCompletedToday": true,
        });

      await service.load("u1");

      expect(snap().currentStreak, 12);
      expect(snap().longestStreak, 30);
      expect(snap().completedToday, isFalse);
      expect(snap().todayCorrectAnswers, 0);

      // Eine Antwort genügt heute nicht mehr …
      await exercise(correct);

      expect(snap().completedToday, isFalse);
      expect(snap().currentStreak, 12);
      expect(repos["u1"]!.data["memorization"]!.longestStreak, 30);

      // … erst die zehnte führt die Streak fort.
      await correctAnswers(9);

      expect(snap().currentStreak, 13);
      expect(snap().longestStreak, 30);
      expect(
        repos["u1"]!.data["memorization"]!.lastCompletedDate,
        "2026-09-21",
      );
    });

    test("heute schon nach altem System erfüllt: der Tag bleibt erfüllt, "
        "keine zweite Zählung", () async {
      repos["u1"] = MemoryRepository()
        ..data["memorization"] = StreakState.fromMap("memorization", {
          "currentStreak": 4,
          "longestStreak": 4,
          "lastActivityDate": "2026-09-21",
          "lastCompletedDate": "2026-09-21",
          "todayCorrectAnswers": 1,
          "todaySources": {"memorization": 1},
          "streakCompletedToday": true,
        });

      final update = await exercise(correct);

      expect(update!.changed, isFalse);
      expect(snap().completedToday, isTrue);
      expect(snap().currentStreak, 4);
      expect(repos["u1"]!.saves, 0);
    });

    test("andere Streaks bleiben unverändert", () async {
      await correctAnswers(10);

      expect(snap().currentStreak, 1);

      for (final track in [
        StreakTrack.greek,
        StreakTrack.latin,
        StreakTrack.perikope,
      ]) {
        expect(track.dailyGoal, 10);
        expect(snap(track).todayCorrectAnswers, 0);
        expect(snap(track).currentStreak, 0);
      }

      expect(snap(StreakTrack.bible).currentStreak, 0);

      for (var i = 0; i < 9; i++) {
        await service.recordCorrectAnswer(
          uid: "u1",
          track: StreakTrack.greek,
          source: StreakSource.vocabulary,
        );
      }

      expect(snap(StreakTrack.greek).completedToday, isFalse);

      await service.recordCorrectAnswer(
        uid: "u1",
        track: StreakTrack.greek,
        source: StreakSource.vocabulary,
      );

      expect(snap(StreakTrack.greek).currentStreak, 1);
      expect(snap(StreakTrack.latin).currentStreak, 0);
      expect(snap(StreakTrack.perikope).currentStreak, 0);
      expect(StreakTrack.all.map((t) => t.id), [
        "greek",
        "latin",
        "perikope",
        "memorization",
        "bible",
      ]);
    });
  });

  group("UI", () {
    StreakSnapshot streak() =>
        StreakService.instance.snapshotFor(null, StreakTrack.memorization);

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await settle(tester);
    }

    testWidgets("Menü zeigt den Tagesfortschritt: „7 von 10 richtigen "
        "Antworten“", (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(() async {
        await StreakService.instance.load(null, refresh: true);

        for (var i = 0; i < 7; i++) {
          await StreakService.instance.recordCorrectAnswer(
            uid: null,
            track: StreakTrack.memorization,
            source: StreakSource.memorization,
          );
        }
      });

      const card = MaterialApp(
        home: Scaffold(
          body: StreakDetailCard(
            uid: null,
            track: StreakTrack.memorization,
            goalNoun: "richtigen Antworten",
            todayHint: "Hinweis",
          ),
        ),
      );

      await tester.pumpWidget(card);
      await settle(tester);

      expect(find.text("7 von 10 richtigen Antworten"), findsOneWidget);
      expect(find.text("7/10"), findsOneWidget);
      expect(find.text("Noch keine aktive Streak"), findsOneWidget);
      expect(find.byKey(const Key("streak_today_hint")), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.7, 0.001),
      );

      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          await StreakService.instance.recordCorrectAnswer(
            uid: null,
            track: StreakTrack.memorization,
            source: StreakSource.memorization,
          );
        }
      });
      await settle(tester);

      expect(find.text("10 von 10 richtigen Antworten"), findsOneWidget);
      expect(find.text("Tagesziel erreicht"), findsOneWidget);
      expect(find.text("1 Tag Streak"), findsOneWidget);
    });

    testWidgets("Lernrunde: Selbsteinschätzung und falsche Eingaben zählen "
        "nicht, jede richtige Eingabe genau einmal (Gast)", (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(
        () => StreakService.instance.load(null, refresh: true),
      );

      // Zwölf gleichlautende Abschnitte: Jede Übung erwartet dieselbe
      // Eingabe, unabhängig von der Reihenfolge der Runde.
      final text = MemorizationText(
        id: "t",
        workId: "t",
        title: "t",
        workTitle: "t",
        languageCode: "de",
        type: MemorizationTextType.other,
        segments: [
          for (var i = 0; i < 12; i++)
            MemorizationSegment(
              id: "t.s$i",
              text: "Vater unser im Himmel",
              order: i,
            ),
        ],
      );

      final repository = MemorizationRepository(null);

      // Im Fake-Async laufen Speicherzugriffe nur weiter, wenn gepumpt wird.
      var loaded = false;

      repository.load().then((_) => loaded = true);

      for (var i = 0; i < 100 && !loaded; i++) {
        await tester.pump();
      }

      expect(loaded, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MemorizationPracticeScreen(
            repository: repository,
            units: [
              for (var i = 0; i < 12; i++)
                PracticeUnit.segment(text, i, HintLevel.free),
            ],
          ),
        ),
      );
      await settle(tester);

      Future<void> submit(String input) async {
        await tester.enterText(find.byKey(const Key("memorize_input")), input);
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key("memorize_check")));
      }

      // Im Kopf mit „Gewusst“: zählt nicht.
      await tapVisible(tester, find.text("Im Kopf"));
      await tapVisible(tester, find.byKey(const Key("memorize_reveal")));
      await tapVisible(tester, find.byKey(const Key("memorize_knew")));

      expect(streak().todayCorrectAnswers, 0);

      await tapVisible(tester, find.text("Tippen"));

      // Neun richtige Eingaben: jede zählt genau einmal.
      for (var i = 1; i <= 9; i++) {
        await submit("Vater unser im Himmel");

        expect(streak().todayCorrectAnswers, i);

        // Nach der Auswertung gibt es nichts mehr, das erneut zählen könnte.
        expect(find.byKey(const Key("memorize_check")), findsNothing);

        await tapVisible(tester, find.byKey(const Key("memorize_next")));

        expect(streak().todayCorrectAnswers, i);
      }

      expect(streak().completedToday, isFalse);

      // Eine falsche Eingabe: weiterhin 9 von 10.
      await submit("etwas ganz anderes");

      expect(streak().todayCorrectAnswers, 9);
      expect(streak().completedToday, isFalse);

      await tapVisible(tester, find.byKey(const Key("memorize_next")));

      // Die zehnte richtige Eingabe erfüllt den Tag.
      await submit("Vater unser im Himmel");

      expect(streak().todayCorrectAnswers, 10);
      expect(streak().completedToday, isTrue);
      expect(streak().currentStreak, 1);
      expect(
        find.text("🔥 Streak für „Texte auswendig lernen“ gestartet!"),
        findsOneWidget,
      );

      // Gespeichert wie die anderen Tracks.
      final stored = await tester.runAsync(LocalStreakRepository().loadAll);
      expect(stored!["memorization"]!.streakCompletedToday, isTrue);
      expect(stored["memorization"]!.todayCorrectAnswers, 10);
    });
  });
}
