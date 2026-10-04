import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_card.dart';
import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_home_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_practice_screen.dart';
import 'package:theologie_lernapp/services/memorization/hint_generator.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/memorization_daily_goal.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/memorization/memorization_scheduler.dart';
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

  MemorizationDailyGoal goalOf(List<MemorizationText> texts) =>
      MemorizationDailyGoal.of(scheduler, texts, cards);

  void practice(
    PracticeUnit unit, {
    HintLevel level = HintLevel.free,
    RecallOutcome outcome = RecallOutcome.correct,
  }) {
    scheduler.apply(
      unit: unit,
      practiced: level,
      outcome: outcome,
      cards: cards,
    );
  }

  void recall(MemorizationText text, int index) =>
      practice(PracticeUnit.segment(text, index, HintLevel.free));

  /// Wie die Lernrunde nach jeder Übung: melden, sobald der Tag erledigt ist.
  Future<StreakUpdate?> report(List<MemorizationText> texts) async {
    if (!goalOf(texts).isComplete) return null;

    return service.recordCorrectAnswer(
      uid: "u1",
      track: StreakTrack.memorization,
      source: StreakSource.memorization,
    );
  }

  StreakSnapshot snap([StreakTrack track = StreakTrack.memorization]) =>
      service.snapshotFor("u1", track);

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

  group("Tagesziel", () {
    test("Öffnen und Mitlesen allein erledigen nichts", () {
      final text = makeText("a", 3);

      expect(goalOf([text]).open, 2, reason: "zwei neue Abschnitte je Tag");
      expect(goalOf([text]).done, 0);
      expect(goalOf([text]).isComplete, isFalse);

      practice(
        PracticeUnit.segment(text, 0, HintLevel.read),
        level: HintLevel.read,
      );

      expect(goalOf([text]).open, 2);
      expect(goalOf([text]).done, 0);
      expect(goalOf([text]).isComplete, isFalse);
    });

    test("teilweise erledigt → false, vollständig → true", () {
      final text = makeText("a", 3);

      recall(text, 0);

      expect(goalOf([text]).done, 1);
      expect(goalOf([text]).total, 2);
      expect(goalOf([text]).isComplete, isFalse);

      recall(text, 1);

      expect(goalOf([text]).done, 2);
      expect(goalOf([text]).total, 2);
      expect(goalOf([text]).isComplete, isTrue);
    });

    test("genau eine Wiederholung vorgesehen", () {
      final text = makeText("a", 1);

      expect(goalOf([text]).total, 1);
      expect(goalOf([text]).isComplete, isFalse);

      recall(text, 0);

      expect(goalOf([text]).done, 1);
      expect(goalOf([text]).isComplete, isTrue);
    });

    test("Fehler bei freier Wiedergabe: Abschnitt bleibt offen", () {
      final text = makeText("a", 1);

      practice(
        PracticeUnit.segment(text, 0, HintLevel.free),
        outcome: RecallOutcome.incorrect,
      );

      expect(goalOf([text]).open, 1);
      expect(goalOf([text]).done, 0);
      expect(goalOf([text]).isComplete, isFalse);
    });

    test("mehrere Texte: alle müssen erledigt sein", () {
      final a = makeText("a", 1);
      final b = makeText("b", 1);

      recall(a, 0);

      expect(goalOf([a, b]).done, 1);
      expect(goalOf([a, b]).total, 2);
      expect(goalOf([a, b]).isComplete, isFalse);

      recall(b, 0);

      expect(goalOf([a, b]).isComplete, isTrue);
    });

    test("das fällige Aufsagen des ganzen Textes gehört zum Tagesziel", () {
      final text = makeText("a", 2);

      recall(text, 0);
      recall(text, 1);

      expect(goalOf([text]).open, 1, reason: "ganzer Text steht an");
      expect(goalOf([text]).isComplete, isFalse);

      practice(scheduler.fullUnit(text));

      expect(goalOf([text]).open, 0);
      expect(goalOf([text]).isComplete, isTrue);
    });

    test("nichts vorgesehen: ohne Übung nicht erledigt, mit Übung schon", () {
      final text = makeText("a", 2);

      for (final id in ["a.s0", "a.s1", "a.full"]) {
        cards[id] = stable(id);
      }

      expect(goalOf([text]).total, 0);
      expect(goalOf([text]).isComplete, isFalse);
      expect(goalOf(const []).isComplete, isFalse, reason: "keine Texte");

      // Freiwillig den ganzen Text aufsagen.
      practice(scheduler.fullUnit(text));

      expect(goalOf([text]).open, 0);
      expect(goalOf([text]).isComplete, isTrue);
    });
  });

  group("Streak", () {
    test("erst der vollständige Tag zählt – und nur einmal", () async {
      final text = makeText("a", 3);

      recall(text, 0);
      expect(await report([text]), isNull);
      expect(snap().completedToday, isFalse);
      expect(snap().currentStreak, 0);

      recall(text, 1);
      final update = await report([text]);

      expect(update!.goalReachedNow, isTrue);
      expect(update.streakStarted, isTrue);
      expect(snap().completedToday, isTrue);
      expect(snap().currentStreak, 1);
      expect(snap().todayCorrectAnswers, 1);
      expect(snap().todaySources, {StreakSource.memorization: 1});
    });

    test(
      "weitere Wiederholungen nach dem Abschluss ändern nichts",
      () async {
        final text = makeText("a", 4);

        recall(text, 0);
        recall(text, 1);
        await report([text]);

        final saves = repos["u1"]!.saves;

        // Erneutes Üben erledigter Abschnitte.
        recall(text, 0);
        final again = await report([text]);

        expect(again!.changed, isFalse);
        expect(again.goalReachedNow, isFalse);

        // Zusätzlich begonnene Abschnitte stehen wieder im Plan – der Tag
        // bleibt trotzdem erledigt.
        practice(
          PracticeUnit.segment(text, 2, HintLevel.read),
          level: HintLevel.read,
        );

        expect(goalOf([text]).isComplete, isFalse);
        expect(await report([text]), isNull);

        expect(snap().completedToday, isTrue);
        expect(snap().currentStreak, 1);
        expect(repos["u1"]!.saves, saves);
      },
    );

    test("Status bleibt nach erneutem App-Aufruf erhalten", () async {
      final text = makeText("a", 3);

      recall(text, 0);
      recall(text, 1);
      await report([text]);
      await Future<void>.delayed(Duration.zero);

      service = newService();
      await service.load("u1");

      expect(snap().completedToday, isTrue);
      expect(snap().currentStreak, 1);
    });

    test("nächster Tag wird neu bewertet", () async {
      final text = makeText("a", 4);

      recall(text, 0);
      recall(text, 1);
      await report([text]);

      now = DateTime(2026, 9, 22, 8);

      expect(snap().completedToday, isFalse);
      expect(snap().currentStreak, 1, reason: "gestern erfüllt → noch aktiv");

      // Gestrige Wiederholungen zählen heute nicht.
      expect(goalOf([text]).done, 0);
      expect(goalOf([text]).open, greaterThan(0));
      expect(await report([text]), isNull);
      expect(snap().completedToday, isFalse);

      while (!goalOf([text]).isComplete) {
        final plan = scheduler.planFor(text, cards);

        practice(plan.units.first.withLevel(HintLevel.free));
      }

      final update = await report([text]);

      expect(update!.goalReachedNow, isTrue);
      expect(update.streakStarted, isFalse);
      expect(snap().completedToday, isTrue);
      expect(snap().currentStreak, 2);

      now = DateTime(2026, 9, 24, 8); // Mittwoch ausgelassen
      expect(snap().currentStreak, 0);
      expect(snap().longestStreak, 2);
    });

    test("bestehende Tracks bleiben unverändert", () async {
      final text = makeText("a", 1);

      recall(text, 0);
      await report([text]);

      for (final track in [
        StreakTrack.greek,
        StreakTrack.latin,
        StreakTrack.perikope,
      ]) {
        expect(track.dailyGoal, 10);
        expect(snap(track).todayCorrectAnswers, 0);
        expect(snap(track).currentStreak, 0);
      }

      for (var i = 0; i < 10; i++) {
        await service.recordCorrectAnswer(
          uid: "u1",
          track: StreakTrack.greek,
          source: StreakSource.vocabulary,
        );
      }

      expect(snap(StreakTrack.greek).currentStreak, 1);
      expect(snap().currentStreak, 1);
      expect(
        StreakTrack.all.where((t) => t.id == "memorization"),
        hasLength(1),
      );
      expect(StreakTrack.all.map((t) => t.id).toSet(), hasLength(4));
    });
  });

  group("UI", () {
    late MemorizationCatalog catalog;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      catalog = await MemorizationCatalog.load();
    });

    testWidgets("Lernrunde: Fortschritt, Abschluss, Startseite (Gast)", (
      tester,
    ) async {
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

      StreakSnapshot streak() => StreakService.instance.snapshotFor(
        null,
        StreakTrack.memorization,
      );

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
      expect(find.text("0/2"), findsOneWidget);

      await tapVisible(find.byKey(const Key("memorize_today_start")));
      expect(find.byType(MemorizationPracticeScreen), findsOneWidget);

      // Ersten Abschnitt frei im Kopf aufsagen.
      await tapVisible(find.byKey(const Key("memorize_level_free")));
      await tapVisible(find.text("Im Kopf"));
      await tapVisible(find.byKey(const Key("memorize_reveal")));
      await tapVisible(find.byKey(const Key("memorize_knew")));

      expect(streak().completedToday, isFalse, reason: "erst 1 von 2");

      await tapVisible(find.byKey(const Key("memorize_level_free")));
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
