import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_card.dart';
import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_home_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_practice_screen.dart';
import 'package:theologie_lernapp/services/memorization/hint_generator.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/memorization/memorization_scheduler.dart';
import 'package:theologie_lernapp/services/memorization/memorization_session.dart';
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

MemorizationText makeText(String id, int segments) {
  return MemorizationText(
    id: id,
    workId: id,
    title: id,
    workTitle: id,
    languageCode: "de",
    type: MemorizationTextType.other,
    segments: [
      for (var i = 0; i < segments; i++)
        MemorizationSegment(id: "$id.s$i", text: "Abschnitt $i", order: i),
    ],
  );
}

void main() {
  const evaluator = MemorizationTextEvaluator();

  late DateTime now;
  late MemorizationScheduler scheduler;
  late Map<String, MemorizationCard> cards;
  late Map<String?, MemoryRepository> repos;
  late StreakService service;

  StreakService newService() => StreakService(
    repositoryFor: (uid) => repos.putIfAbsent(uid, MemoryRepository.new),
    clock: () => now,
  );

  setUp(() {
    now = DateTime(2026, 9, 21, 10); // Montag
    scheduler = MemorizationScheduler(clock: () => now);
    cards = {};
    repos = {};
    service = newService();
  });

  StreakSnapshot snap([StreakTrack track = StreakTrack.memorization]) =>
      service.snapshotFor("u1", track);

  /// Wie die Lernrunde nach jeder ausgewerteten Übung: verbuchen und – falls
  /// die Regel greift – der Streak melden. Liefert die Meldung (null = nicht
  /// gemeldet).
  Future<StreakUpdate?> exercise(
    MemorizationSession session, {
    HintLevel? level,
    RecallOutcome outcome = RecallOutcome.correct,
    EvaluationResult? result,
  }) async {
    final practiced = level ?? session.current!.level;

    session.complete(practiced: practiced, outcome: outcome);

    if (!MemorizationStreakRule.counts(practiced: practiced, result: result)) {
      return null;
    }

    return service.recordCorrectAnswer(
      uid: "u1",
      track: StreakTrack.memorization,
      source: StreakSource.memorization,
    );
  }

  /// Lernrunde „Heute lernen“ über alle [texts], wie im Menü.
  MemorizationSession today(List<MemorizationText> texts) {
    return MemorizationSession(
      scheduler: scheduler,
      cards: cards,
      units: [
        for (final text in texts) ...scheduler.planFor(text, cards).units,
      ],
    );
  }

  /// Übt die Runde in der vorgeschlagenen Reihenfolge, bis die Streak für
  /// heute erfüllt ist; liefert die Zahl der nötigen Übungen.
  Future<int> exercisesUntilStreak(MemorizationSession session) async {
    var count = 0;

    while (!snap().completedToday && !session.isFinished) {
      await exercise(session);
      count++;
    }

    return count;
  }

  /// Gelernter, erst in Wochen wieder fälliger Abschnitt.
  MemorizationCard stable(String id) => MemorizationCard(
    id: id,
    stability: 24.0 * 30,
    lastReviewed: now.subtract(const Duration(days: 1)),
    level: MemorizationCard.maxLevel,
    attempts: 3,
    successes: 3,
    learned: true,
    startedAt: now.subtract(const Duration(days: 9)),
  );

  /// Gelernter, heute fälliger Abschnitt.
  MemorizationCard due(String id) => MemorizationCard(
    id: id,
    stability: 24.0 * 3,
    lastReviewed: now.subtract(const Duration(days: 4)),
    level: MemorizationCard.maxLevel,
    attempts: 3,
    successes: 3,
    learned: true,
    startedAt: now.subtract(const Duration(days: 9)),
  );

  group("Regel: was zählt", () {
    test("Mitlesen zählt nicht", () {
      expect(MemorizationStreakRule.counts(practiced: HintLevel.read), isFalse);
    });

    test("jede Hilfestufe mit Abruf zählt – Selbsteinschätzung im Kopf", () {
      for (final level in HintLevel.values.skip(1)) {
        expect(
          MemorizationStreakRule.counts(practiced: level),
          isTrue,
          reason: level.name,
        );
      }
    });

    test("getippt und gesprochen zählt, auch mit Fehlern", () {
      for (final spoken in [false, true]) {
        for (final input in [
          "Vater unser im Himmel",
          "Vater unsa im",
          "etwas ganz anderes",
        ]) {
          final result = evaluator.evaluateWords(
            target: ["Vater", "unser", "im", "Himmel"],
            input: input,
            spoken: spoken,
          );

          expect(
            MemorizationStreakRule.counts(
              practiced: HintLevel.free,
              result: result,
            ),
            isTrue,
            reason: "$input (gesprochen: $spoken)",
          );
        }
      }

      // Lückentext: nur die fehlenden Wörter.
      final gaps = evaluator.evaluateWords(
        target: ["unser"],
        input: "unser",
        spoken: false,
      );

      expect(
        MemorizationStreakRule.counts(
          practiced: HintLevel.fewGaps,
          result: gaps,
        ),
        isTrue,
      );
    });

    test("eine leere Eingabe zählt nicht", () {
      final result = evaluator.evaluateWords(
        target: ["Vater", "unser"],
        input: " ?! ",
        spoken: false,
      );

      expect(result.isEmptyInput, isTrue);
      expect(
        MemorizationStreakRule.counts(
          practiced: HintLevel.free,
          result: result,
        ),
        isFalse,
      );
    });
  });

  group("Streak", () {
    test("Nutzer A–D (1, 3, 10, 20 Texte): eine Übung genügt", () async {
      for (final textCount in [1, 3, 10, 20]) {
        cards = {};
        repos = {};
        service = newService();

        // Je Text zwei gelernte, heute fällige Abschnitte und zwei neue.
        final texts = [for (var t = 0; t < textCount; t++) makeText("t$t", 4)];

        for (final text in texts) {
          for (final segment in text.segments.take(2)) {
            cards[segment.id] = due(segment.id);
          }
        }

        final session = today(texts);

        // Der Lernplan wächst mit der Zahl der Texte …
        expect(session.remaining, greaterThanOrEqualTo(2 * textCount));

        // … das Streak-Ziel nicht.
        expect(
          await exercisesUntilStreak(session),
          1,
          reason: "$textCount Texte",
        );
        expect(snap().currentStreak, 1);

        // Nur der erste Text wurde angefasst.
        final touchedTexts = {
          for (final id in session.touched) id.split(".").first,
        };
        expect(touchedTexts, {"t0"});
      }
    });

    test(
      "neuer Text: Mitlesen zählt nicht, die erste Abrufübung schon",
      () async {
        final text = makeText("a", 1);
        final session = today([text]);

        expect(session.current!.level, HintLevel.read);
        expect(await exercise(session), isNull);
        expect(snap().completedToday, isFalse);

        // Danach mit Lücken: zählt.
        expect(session.current!.level, HintLevel.fewGaps);
        expect(await exercisesUntilStreak(session), 1);
        expect(snap().completedToday, isTrue);
      },
    );

    test("Überspringen und Abbrechen zählen nicht", () async {
      final text = makeText("a", 2);

      for (final segment in text.segments) {
        cards[segment.id] = due(segment.id);
      }

      final session = today([text]);

      session.skip();

      expect(snap().completedToday, isFalse);
      expect(snap().todayCorrectAnswers, 0);
      expect(repos["u1"]?.saves ?? 0, 0);
    });

    test("auch ein Fehler bei freier Wiedergabe zählt", () async {
      final text = makeText("a", 1);
      cards["a.s0"] = due("a.s0");

      final update = await exercise(
        today([text]),
        outcome: RecallOutcome.incorrect,
      );

      expect(update!.goalReachedNow, isTrue);
      expect(update.streakStarted, isTrue);
    });

    test(
      "nichts fällig: freiwilliges Aufsagen zählt, ohne Übung nichts",
      () async {
        final text = makeText("a", 2);

        for (final id in ["a.s0", "a.s1", "a.full"]) {
          cards[id] = stable(id);
        }

        expect(scheduler.planFor(text, cards).isEmpty, isTrue);
        expect(snap().completedToday, isFalse);

        final session = MemorizationSession(
          scheduler: scheduler,
          cards: cards,
          units: [scheduler.fullUnit(text)],
        );

        await exercise(session);

        expect(snap().completedToday, isTrue);
      },
    );

    test("weitere Übungen am selben Tag ändern nichts", () async {
      final text = makeText("a", 4);

      for (final segment in text.segments) {
        cards[segment.id] = due(segment.id);
      }

      final session = today([text]);

      expect((await exercise(session))!.goalReachedNow, isTrue);

      final saves = repos["u1"]!.saves;

      while (!session.isFinished) {
        final again = await exercise(session);

        expect(again!.changed, isFalse);
        expect(again.goalReachedNow, isFalse);
      }

      expect(snap().currentStreak, 1);
      expect(snap().todayCorrectAnswers, 1);
      expect(snap().todaySources, {StreakSource.memorization: 1});
      expect(repos["u1"]!.saves, saves);
    });

    test("Status bleibt nach erneutem App-Aufruf erhalten", () async {
      final text = makeText("a", 3);

      await exercise(today([text]), level: HintLevel.free);
      await Future<void>.delayed(Duration.zero);

      service = newService();
      await service.load("u1");

      expect(snap().completedToday, isTrue);
      expect(snap().currentStreak, 1);
    });

    test("nächster Tag wird neu bewertet, ein ausgelassener Tag beendet "
        "die Streak", () async {
      final text = makeText("a", 4);

      await exercise(today([text]), level: HintLevel.free);

      now = DateTime(2026, 9, 22, 8);

      expect(snap().completedToday, isFalse);
      expect(snap().currentStreak, 1, reason: "gestern erfüllt → noch aktiv");

      final update = await exercise(today([text]), level: HintLevel.free);

      expect(update!.goalReachedNow, isTrue);
      expect(update.streakStarted, isFalse);
      expect(snap().currentStreak, 2);

      now = DateTime(2026, 9, 24, 8); // Mittwoch ausgelassen
      expect(snap().currentStreak, 0);
      expect(snap().longestStreak, 2);
    });

    test("bestehende Streak aus dem alten System läuft weiter", () async {
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

      final text = makeText("a", 2);
      cards["a.s0"] = due("a.s0");

      await exercise(today([text]));

      expect(snap().currentStreak, 13);
      expect(snap().longestStreak, 30);
      expect(
        repos["u1"]!.data["memorization"]!.lastCompletedDate,
        "2026-09-21",
      );
    });

    test(
      "heute schon nach altem System erfüllt: keine zweite Zählung",
      () async {
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

        final text = makeText("a", 2);

        final update = await exercise(today([text]), level: HintLevel.free);

        expect(update!.changed, isFalse);
        expect(snap().currentStreak, 4);
        expect(repos["u1"]!.saves, 0);
      },
    );

    test("andere Streaks bleiben unverändert", () async {
      final text = makeText("a", 1);

      await exercise(today([text]), level: HintLevel.free);

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
      expect(StreakTrack.memorization.dailyGoal, 1);
      expect(StreakTrack.all.map((t) => t.id), [
        "greek",
        "latin",
        "perikope",
        "memorization",
      ]);
    });
  });

  group("UI", () {
    late MemorizationCatalog catalog;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      catalog = await MemorizationCatalog.load();
    });

    testWidgets("Lernrunde: Mitlesen und Überspringen zählen nicht, die "
        "erste Abrufübung schon (Gast)", (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.runAsync(
        () => StreakService.instance.load(null, refresh: true),
      );

      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await settle();
      }

      StreakSnapshot streak() =>
          StreakService.instance.snapshotFor(null, StreakTrack.memorization);

      final repository = MemorizationRepository(null);

      // Im Fake-Async laufen Speicherzugriffe nur weiter, wenn gepumpt wird.
      Future<void> drive(Future<void> future) async {
        var done = false;

        future.then((_) => done = true);

        for (var i = 0; i < 100 && !done; i++) {
          await tester.pump();
        }

        expect(done, isTrue, reason: "Speicherzugriff nicht abgeschlossen");
      }

      await drive(repository.load());
      await drive(repository.addText("prayer.kyrie.de"));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MemorizationHomeScreen(
            repository: repository,
            catalog: Future.value(catalog),
          ),
        ),
      );
      await settle();

      expect(find.text("Noch keine aktive Streak"), findsOneWidget);
      expect(find.text("Noch offen"), findsOneWidget);
      expect(find.byKey(const Key("streak_today_hint")), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StreakDetailCard),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
        reason: "kein Zähler, kein Fortschrittsbalken",
      );

      await tapVisible(find.byKey(const Key("memorize_today_start")));
      expect(find.byType(MemorizationPracticeScreen), findsOneWidget);

      // Ersten neuen Abschnitt mitlesen: zählt nicht.
      await tapVisible(find.byKey(const Key("memorize_read_done")));
      expect(streak().completedToday, isFalse);

      // Zweiten neuen Abschnitt überspringen: zählt nicht.
      await tapVisible(find.text("Überspringen"));
      expect(streak().completedToday, isFalse);

      // Den mitgelesenen Abschnitt frei im Kopf aufsagen: zählt.
      await tapVisible(find.byKey(const Key("memorize_level_free")));
      await tapVisible(find.text("Im Kopf"));
      await tapVisible(find.byKey(const Key("memorize_reveal")));
      await tapVisible(find.byKey(const Key("memorize_knew")));

      expect(streak().completedToday, isTrue);
      expect(streak().currentStreak, 1);
      expect(
        find.text("🔥 Streak für „Texte auswendig lernen“ gestartet!"),
        findsOneWidget,
      );

      await tapVisible(find.byKey(const Key("memorize_done")));

      expect(find.byType(MemorizationHomeScreen), findsOneWidget);
      expect(find.text("1 Tag Streak"), findsOneWidget);
      expect(find.text("Tagesziel erreicht"), findsOneWidget);

      // Gespeichert wie die anderen Tracks.
      final stored = await tester.runAsync(LocalStreakRepository().loadAll);
      expect(stored!["memorization"]!.streakCompletedToday, isTrue);

      // Startseite: eigener Eintrag neben den anderen Lernbereichen.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: StreakSummary(uid: null)),
        ),
      );
      await settle();

      expect(find.text("Texte auswendig lernen"), findsOneWidget);
      expect(find.text("1 Tag"), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
