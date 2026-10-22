import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/logic/logic_exercise.dart';
import 'package:theologie_lernapp/services/logic/logic_streak_rule.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';

/// Streak-Erfassung der Wissens- und Logikbereiche (Kirchengeschichte,
/// Altes Testament, Logik) und des Klausurerstellers über den gemeinsamen
/// [StreakService] – mit kontrollierbarer Uhr, ohne reale Wartezeiten.

/// Gemeinsamer Speicher („Server“) für mehrere App-Starts.
class MemoryRepository implements StreakRepository {
  final Map<String, Map<String, dynamic>> documents = {};

  /// Wie ein leerer Firestore-Cache: Laden schlägt fehl.
  bool unavailable = false;

  int saves = 0;

  @override
  Future<Map<String, StreakState>> loadAll() async {
    if (unavailable) throw const StreakDataUnavailable();
    return {
      for (final e in documents.entries)
        e.key: StreakState.fromMap(e.key, e.value),
    };
  }

  @override
  Future<void> save(StreakState state) async {
    saves++;
    documents[state.trackId] = state.toMap();
  }
}

/// Die in dieser Änderung neu oder erstmals getestet angebundenen Tracks.
const areaTracks = [
  (StreakTrack.churchHistory, StreakSource.knowledgeQuiz),
  (StreakTrack.oldTestament, StreakSource.oldTestamentQuiz),
  (StreakTrack.logic, StreakSource.logicExercise),
];

void main() {
  late DateTime now;
  late MemoryRepository repo;

  /// Ein App-Start: eigener Service, gemeinsamer Speicher.
  StreakService start() =>
      StreakService(repositoryFor: (_) => repo, clock: () => now);

  Future<List<StreakUpdate?>> learn(
    StreakService service,
    StreakTrack track,
    String source,
    int n,
  ) async => [
    for (var i = 0; i < n; i++)
      await service.recordCorrectAnswer(
        uid: "u1",
        track: track,
        source: source,
      ),
  ];

  setUp(() {
    now = DateTime(2026, 10, 12, 18); // Montag
    repo = MemoryRepository();
  });

  group("Tracks", () {
    test("jede Track-ID kommt einmal vor; Logik ist ein eigener Track", () {
      final ids = [for (final t in StreakTrack.all) t.id];
      expect(ids.toSet(), hasLength(ids.length));
      expect(StreakTrack.all, contains(StreakTrack.logic));
      expect(StreakTrack.logic.id, "logic");
      expect(StreakTrack.logic.dailyGoal, 5);
      expect(StreakTrack.logic.sources, [StreakSource.logicExercise]);
    });

    test("Klausurersteller zählt zum Track Altgriechisch", () {
      expect(StreakTrack.greek.sources, [
        StreakSource.vocabulary,
        StreakSource.grammar,
        StreakSource.exam,
      ]);
      expect(StreakSource.label(StreakSource.exam), "Klausurersteller");
      expect(StreakSource.label(StreakSource.logicExercise), "Übungen");
    });

    test(
      "bestehende Tracks unverändert (gespeicherte Daten bleiben gültig)",
      () {
        expect(
          {for (final t in StreakTrack.all) t.id: t.dailyGoal},
          {
            "greek": 10,
            "latin": 10,
            "perikope": 10,
            "church_history": 10,
            "old_testament": 10,
            "memorization": 10,
            "bible": 1,
            "logic": 5,
          },
        );
      },
    );
  });

  group("Logik-Regel", () {
    test("nur automatisch geprüfte, richtige Übungen zählen", () {
      const proof = ProofExercise(
        id: "l4.k1.a",
        origin: ExerciseOrigin.course,
        group: "Übung 1",
        theorem: "p ⊢ p",
        system: "l4",
        solution: [],
      );
      const wellFormed = WellFormedExercise(
        id: null,
        origin: ExerciseOrigin.extra,
        group: "Erzeugt",
        expression: "p",
      );
      const open = OpenExercise(
        id: "l1.open",
        origin: ExerciseOrigin.course,
        group: "Übung 1",
        question: "Warum?",
        sample: "Darum.",
      );

      expect(LogicStreakRule.counts(proof, correct: true), isTrue);
      expect(LogicStreakRule.counts(wellFormed, correct: true), isTrue);
      expect(LogicStreakRule.counts(proof, correct: false), isFalse);
      expect(LogicStreakRule.counts(open, correct: true), isFalse);
      expect(LogicStreakRule.counts(open, correct: false), isFalse);
    });

    test("Statistik: jede automatisch geprüfte Übung, offene nicht", () {
      const proof = ProofExercise(
        id: "l4.k1.a",
        origin: ExerciseOrigin.course,
        group: "Übung 1",
        theorem: "p ⊢ p",
        system: "l4",
        solution: [],
      );
      const open = OpenExercise(
        id: "l1.open",
        origin: ExerciseOrigin.course,
        group: "Übung 1",
        question: "Warum?",
        sample: "Darum.",
      );

      expect(LogicStreakRule.countsForStatistics(proof), isTrue);
      expect(LogicStreakRule.countsForStatistics(open), isFalse);
      expect(StatisticsTrainer.all, contains(StatisticsTrainer.logic));
      expect(StatisticsTrainer.all, contains(StatisticsTrainer.memorization));
    });
  });

  for (final (track, source) in areaTracks) {
    group("${track.label}: Tageslogik", () {
      test("erster Lerntag: erst das Tagesziel startet die Streak", () async {
        final service = start();

        final before = await learn(service, track, source, track.dailyGoal - 1);
        expect(before.every((u) => u!.goalReachedNow == false), isTrue);
        expect(service.snapshotFor("u1", track).currentStreak, 0);
        expect(
          service.snapshotFor("u1", track).todayCorrectAnswers,
          track.dailyGoal - 1,
        );

        final last = await learn(service, track, source, 1);
        expect(last.single!.goalReachedNow, isTrue);
        expect(last.single!.streakStarted, isTrue);
        expect(service.snapshotFor("u1", track).currentStreak, 1);
        expect(repo.documents[track.id]!["todaySources"], {
          source: track.dailyGoal,
        });
      });

      test("mehrere Aktivitäten am selben Tag zählen einmal", () async {
        final service = start();
        await learn(service, track, source, track.dailyGoal);
        final saves = repo.saves;

        final more = await learn(service, track, source, 7);
        expect(more.every((u) => !u!.changed && !u.goalReachedNow), isTrue);
        expect(repo.saves, saves, reason: "kein weiterer Schreibvorgang");
        expect(service.snapshotFor("u1", track).currentStreak, 1);
      });

      test("aufeinanderfolgende Tage, ausgelassener Tag", () async {
        final service = start();
        for (var day = 0; day < 3; day++) {
          now = DateTime(2026, 10, 12 + day, 9);
          await learn(service, track, source, track.dailyGoal);
        }
        expect(service.snapshotFor("u1", track).currentStreak, 3);

        // 15.10. ausgelassen: am 16. ist die Streak abgelaufen.
        now = DateTime(2026, 10, 16, 9);
        expect(service.snapshotFor("u1", track).currentStreak, 0);
        expect(service.snapshotFor("u1", track).longestStreak, 3);

        await learn(service, track, source, track.dailyGoal);
        expect(service.snapshotFor("u1", track).currentStreak, 1);
        expect(service.snapshotFor("u1", track).longestStreak, 3);
      });

      test("App-Neustart: Stand wird geladen und fortgeführt", () async {
        await learn(start(), track, source, track.dailyGoal);

        now = DateTime(2026, 10, 13, 7);
        final restarted = start();
        await restarted.load("u1");
        expect(restarted.snapshotFor("u1", track).currentStreak, 1);

        await learn(restarted, track, source, track.dailyGoal);
        expect(restarted.snapshotFor("u1", track).currentStreak, 2);

        final third = start();
        await third.load("u1");
        expect(third.snapshotFor("u1", track).currentStreak, 2);
        expect(third.snapshotFor("u1", track).completedToday, isTrue);
      });

      test("Mitternacht und Sommer-/Winterzeit", () async {
        final service = start();

        // 23:59:59 und 00:00:00 sind zwei Lerntage.
        now = DateTime(2026, 10, 12, 23, 59, 59);
        await learn(service, track, source, track.dailyGoal);
        now = DateTime(2026, 10, 13);
        await learn(service, track, source, track.dailyGoal);
        expect(service.snapshotFor("u1", track).currentStreak, 2);

        // Winterzeit beginnt am 25.10.2026 (Tag mit 25 Stunden).
        final winter = start();
        repo.documents.clear();
        for (final t in [
          DateTime(2026, 10, 24, 23, 30),
          DateTime(2026, 10, 25, 23, 59),
          DateTime(2026, 10, 26, 0, 1),
        ]) {
          now = t;
          await learn(winter, track, source, track.dailyGoal);
        }
        expect(winter.snapshotFor("u1", track).currentStreak, 3);

        // Sommerzeit beginnt am 29.03.2026 (Tag mit 23 Stunden).
        final summer = start();
        repo.documents.clear();
        for (final t in [
          DateTime(2026, 3, 28, 23, 30),
          DateTime(2026, 3, 29, 23, 30),
          DateTime(2026, 3, 30, 0, 30),
        ]) {
          now = t;
          await learn(summer, track, source, track.dailyGoal);
        }
        expect(summer.snapshotFor("u1", track).currentStreak, 3);
      });

      test("gleichzeitige Meldungen zählen genau einmal", () async {
        final service = start();
        final updates = await Future.wait([
          for (var i = 0; i < 30; i++)
            service.recordCorrectAnswer(
              uid: "u1",
              track: track,
              source: source,
            ),
        ]);

        expect(updates.where((u) => u!.goalReachedNow), hasLength(1));
        expect(service.snapshotFor("u1", track).currentStreak, 1);
        expect(
          service.snapshotFor("u1", track).todayCorrectAnswers,
          track.dailyGoal,
        );
        expect(repo.saves, track.dailyGoal);
      });

      test(
        "nicht ladbarer Stand setzt nichts zurück und wird nachgetragen",
        () async {
          repo.documents[track.id] = StreakState(
            trackId: track.id,
            currentStreak: 12,
            longestStreak: 20,
            lastActivityDate: "2026-10-11",
            lastCompletedDate: "2026-10-11",
            todayCorrectAnswers: track.dailyGoal,
            streakCompletedToday: true,
          ).toMap();

          repo.unavailable = true;
          final service = start();
          final pending = await learn(service, track, source, track.dailyGoal);
          expect(pending.every((u) => u == null), isTrue);
          expect(
            repo.saves,
            0,
            reason: "ohne gelesenen Stand nichts speichern",
          );
          expect(repo.documents[track.id]!["currentStreak"], 12);

          // Verbindung wieder da (nach der Wartezeit für den nächsten Versuch).
          repo.unavailable = false;
          now = now.add(StreakService.retryDelay);
          await service.load("u1", refresh: true);

          expect(service.snapshotFor("u1", track).currentStreak, 13);
          expect(repo.documents[track.id]!["currentStreak"], 13);
          expect(repo.documents[track.id]!["longestStreak"], 20);
        },
      );
    });
  }

  group("Bereiche bleiben getrennt", () {
    test(
      "Klausurersteller und Vokabeln zählen gemeinsam für Altgriechisch",
      () async {
        final service = start();
        await learn(service, StreakTrack.greek, StreakSource.vocabulary, 6);
        await learn(service, StreakTrack.greek, StreakSource.exam, 4);

        final s = service.snapshotFor("u1", StreakTrack.greek);
        expect(s.currentStreak, 1);
        expect(s.todaySources, {
          StreakSource.vocabulary: 6,
          StreakSource.exam: 4,
        });
      },
    );

    test("Antworten eines Bereichs ändern keinen anderen Track", () async {
      final service = start();
      await learn(service, StreakTrack.logic, StreakSource.logicExercise, 5);
      await learn(
        service,
        StreakTrack.churchHistory,
        StreakSource.chronology,
        3,
      );

      expect(service.snapshotFor("u1", StreakTrack.logic).currentStreak, 1);
      expect(
        service
            .snapshotFor("u1", StreakTrack.churchHistory)
            .todayCorrectAnswers,
        3,
      );
      for (final other in StreakTrack.all) {
        if (other == StreakTrack.logic || other == StreakTrack.churchHistory) {
          continue;
        }
        expect(repo.documents.containsKey(other.id), isFalse, reason: other.id);
        expect(service.snapshotFor("u1", other).todayCorrectAnswers, 0);
      }
    });

    test("bestehende Streaks anderer Bereiche bleiben beim ersten Logik-Tag "
        "erhalten", () async {
      repo.documents["greek"] = const StreakState(
        trackId: "greek",
        currentStreak: 30,
        longestStreak: 30,
        lastActivityDate: "2026-10-11",
        lastCompletedDate: "2026-10-11",
        todayCorrectAnswers: 10,
        streakCompletedToday: true,
      ).toMap();

      final service = start();
      await learn(service, StreakTrack.logic, StreakSource.logicExercise, 5);

      expect(repo.documents["greek"]!["currentStreak"], 30);
      expect(service.snapshotFor("u1", StreakTrack.greek).currentStreak, 30);
    });
  });
}
