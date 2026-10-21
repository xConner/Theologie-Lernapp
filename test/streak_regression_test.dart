import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';

/// Gemeinsamer „Server“: Mehrere Geräte (Services) sehen dieselben Daten.
class FakeServer {
  final Map<String, Map<String, dynamic>> documents = {};

  StreakState? operator [](String trackId) {
    final data = documents[trackId];
    return data == null ? null : StreakState.fromMap(trackId, data);
  }
}

/// Bildet [FirestoreStreakRepository] nach: Offline liefert Firestore den
/// lokalen Cache, der im Web nach einem Neuladen leer ist.
class FakeFirestoreRepository implements StreakRepository {
  final FakeServer server;

  /// Offline mit leerem Cache (Web nach Neuladen).
  bool offline = false;

  /// Speichervorgänge schlagen fehl.
  bool failSave = false;

  /// Speichervorgänge warten auf [releaseSaves].
  bool delaySaves = false;
  final List<Completer<void>> _delayed = [];

  int saves = 0;

  FakeFirestoreRepository(this.server);

  @override
  Future<Map<String, StreakState>> loadAll() async {
    return FirestoreStreakRepository.statesFromDocuments(
      offline ? {} : {...server.documents},
      fromCache: offline,
    );
  }

  @override
  Future<void> save(StreakState state) async {
    saves++;
    if (delaySaves) {
      final completer = Completer<void>();
      _delayed.add(completer);
      await completer.future;
    }
    if (failSave) throw Exception("Schreiben fehlgeschlagen");
    server.documents[state.trackId] = state.toMap();
  }

  void releaseSaves() {
    delaySaves = false;
    for (final c in _delayed) {
      c.complete();
    }
    _delayed.clear();
  }
}

const greek = StreakTrack.greek;

void main() {
  late DateTime now;
  late FakeServer server;

  /// Ein Gerät bzw. ein App-Start: eigener Service, gemeinsamer Server.
  (StreakService, FakeFirestoreRepository) device() {
    final repo = FakeFirestoreRepository(server);
    final service = StreakService(repositoryFor: (_) => repo, clock: () => now);
    return (service, repo);
  }

  Future<List<StreakUpdate?>> learn(
    StreakService service,
    int n, {
    StreakTrack track = greek,
    String source = StreakSource.vocabulary,
  }) async {
    return [
      for (var i = 0; i < n; i++)
        await service.recordCorrectAnswer(
          uid: "u1",
          track: track,
          source: source,
        ),
    ];
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    now = DateTime(2026, 10, 12, 18); // Montag
    server = FakeServer();
  });

  group("Regression: kein Reset beim erneuten Öffnen", () {
    test("aufeinanderfolgende Tage mit Neustart der App", () async {
      for (var day = 0; day < 5; day++) {
        now = DateTime(2026, 10, 12 + day, 7, 30);

        // App neu geöffnet: Streak des Vortags ist noch sichtbar.
        final (service, _) = device();
        await service.load("u1", refresh: true);
        expect(service.snapshotFor("u1", greek).currentStreak, day);

        await learn(service, 10);
        await settle();
        expect(service.snapshotFor("u1", greek).currentStreak, day + 1);
      }

      // Am nächsten Morgen vor dem Lernen: weiterhin 5.
      now = DateTime(2026, 10, 17, 6);
      final (service, _) = device();
      await service.load("u1", refresh: true);
      expect(service.snapshotFor("u1", greek).currentStreak, 5);
      expect(server[greek.id]!.longestStreak, 5);
    });

    test(
      "offline geöffnet (leerer Cache): Streak wird nicht mit 1 überschrieben",
      () async {
        server.documents[greek.id] = const StreakState(
          trackId: "greek",
          currentStreak: 40,
          longestStreak: 40,
          lastActivityDate: "2026-10-11",
          lastCompletedDate: "2026-10-11",
          todayCorrectAnswers: 10,
          streakCompletedToday: true,
        ).toMap();

        final (service, repo) = device();
        repo.offline = true;
        await service.load("u1", refresh: true);

        final updates = await learn(service, 10);
        await settle();

        // Nichts gezählt oder gespeichert, solange der Stand unbekannt ist.
        expect(updates.every((u) => u == null), isTrue);
        expect(repo.saves, 0);
        expect(server[greek.id]!.currentStreak, 40);

        // Wieder online: Die offline gelernten Antworten werden mit ihrem
        // Zeitpunkt nachgetragen und führen die Streak fort.
        repo.offline = false;
        now = now.add(const Duration(minutes: 1));
        await service.load("u1", refresh: true);
        await settle();

        expect(service.snapshotFor("u1", greek).currentStreak, 41);
        expect(server[greek.id]!.currentStreak, 41);
        expect(server[greek.id]!.longestStreak, 41);
        expect(server[greek.id]!.lastCompletedDate, "2026-10-12");
      },
    );

    test("leerer Cache ist ein Ladefehler, leere Serverantwort nicht", () {
      expect(
        () =>
            FirestoreStreakRepository.statesFromDocuments({}, fromCache: true),
        throwsA(isA<StreakDataUnavailable>()),
      );
      expect(
        FirestoreStreakRepository.statesFromDocuments({}, fromCache: false),
        isEmpty,
      );
      final cached = FirestoreStreakRepository.statesFromDocuments({
        "greek": {"currentStreak": 3, "lastCompletedDate": "2026-10-11"},
      }, fromCache: true);
      expect(cached["greek"]!.currentStreak, 3);
    });

    test(
      "lange geöffneter Tab: anderes Gerät hat die Streak fortgeführt",
      () async {
        final (laptop, _) = device();
        final (phone, _) = device();

        // Montag am Laptop gelernt, Tab bleibt offen.
        await learn(laptop, 10);
        await settle();

        // Di und Mi nur am Handy.
        now = DateTime(2026, 10, 13, 9);
        await phone.load("u1", refresh: true);
        await learn(phone, 10);
        now = DateTime(2026, 10, 14, 9);
        await learn(phone, 10);
        await settle();
        expect(server[greek.id]!.currentStreak, 3);

        // Donnerstag im alten Laptop-Tab: Streak geht auf 4 statt auf 1.
        now = DateTime(2026, 10, 15, 20);
        final updates = await learn(laptop, 10);
        await settle();

        expect(updates.last!.goalReachedNow, isTrue);
        expect(updates.last!.currentStreak, 4);
        expect(server[greek.id]!.currentStreak, 4);
        expect(server[greek.id]!.longestStreak, 4);
      },
    );

    test(
      "Startseite lädt neu: Stand mit 0 aus dem Cache bleibt ohne Folgen",
      () async {
        final (service, repo) = device();
        await learn(service, 10);
        await settle();

        repo.offline = true;
        await service.load("u1", refresh: true);

        // Fehlgeschlagenes Neuladen: angezeigte Streak bleibt erhalten.
        expect(service.snapshotFor("u1", greek).currentStreak, 1);
        expect(service.snapshotFor("u1", greek).completedToday, isTrue);
      },
    );
  });

  group("Tageslogik", () {
    test("erster Lerntag, mehrere Einheiten am selben Tag", () async {
      final (service, repo) = device();

      final first = await learn(service, 10);
      expect(first.last!.streakStarted, isTrue);

      // Weitere Lerneinheiten am selben Tag: keine Erhöhung, kein Reset,
      // kein weiterer Schreibvorgang.
      final savesAfterGoal = repo.saves;
      final more = await learn(service, 25, source: StreakSource.grammar);
      await settle();

      expect(more.any((u) => u!.goalReachedNow), isFalse);
      expect(repo.saves, savesAfterGoal);
      expect(server[greek.id]!.currentStreak, 1);
      expect(server[greek.id]!.todayCorrectAnswers, 10);
    });

    test("verpasster Tag: neue Streak, längste bleibt", () async {
      final (service, _) = device();
      await learn(service, 10);
      now = DateTime(2026, 10, 13, 9);
      await learn(service, 10);
      now = DateTime(2026, 10, 14, 9);
      await learn(service, 10);
      expect(service.snapshotFor("u1", greek).currentStreak, 3);

      now = DateTime(2026, 10, 16, 9); // 15. verpasst
      expect(service.snapshotFor("u1", greek).currentStreak, 0);
      await learn(service, 10);
      await settle();

      expect(server[greek.id]!.currentStreak, 1);
      expect(server[greek.id]!.longestStreak, 3);
    });

    test("Mitternacht: 23:59:59 und 00:00:00 sind zwei Lerntage", () async {
      final (service, _) = device();
      now = DateTime(2026, 10, 12, 23, 59, 59);
      await learn(service, 10);
      now = DateTime(2026, 10, 13);
      final updates = await learn(service, 10);

      expect(updates.last!.goalReachedNow, isTrue);
      expect(updates.last!.currentStreak, 2);
    });

    test("Sommer- und Winterzeitumstellung", () async {
      final (service, _) = device();

      // Sommerzeit beginnt am 29.03.2026 (Tag mit 23 Stunden).
      now = DateTime(2026, 3, 28, 23, 30);
      await learn(service, 10);
      now = DateTime(2026, 3, 29, 23, 30);
      await learn(service, 10);
      now = DateTime(2026, 3, 30, 0, 30);
      await learn(service, 10);
      expect(service.snapshotFor("u1", greek).currentStreak, 3);

      // Winterzeit beginnt am 25.10.2026 (Tag mit 25 Stunden).
      final (winter, _) = device();
      server.documents.clear();
      now = DateTime(2026, 10, 24, 0, 30);
      await learn(winter, 10);
      now = DateTime(2026, 10, 25, 23, 59);
      await learn(winter, 10);
      now = DateTime(2026, 10, 26, 0, 1);
      await learn(winter, 10);
      expect(winter.snapshotFor("u1", greek).currentStreak, 3);

      expect(
        StreakCalculator.previousDateKey(DateTime(2026, 3, 30, 0, 30)),
        "2026-03-29",
      );
      expect(
        StreakCalculator.previousDateKey(DateTime(2026, 10, 26, 0, 30)),
        "2026-10-25",
      );
    });

    test("UTC-Zeitpunkte werden dem lokalen Kalendertag zugeordnet", () {
      final instants = [
        DateTime.utc(2026, 10, 19, 22, 30),
        DateTime.utc(2026, 10, 20, 0, 30),
        DateTime.utc(2026, 3, 29, 0, 30),
        DateTime.utc(2026, 10, 25, 1, 30),
      ];

      for (final utc in instants) {
        final local = utc.toLocal();
        expect(StreakCalculator.dateKey(utc), StreakCalculator.dateKey(local));
        expect(
          StreakCalculator.previousDateKey(utc),
          StreakCalculator.previousDateKey(local),
        );
      }

      // Lernen mit einer UTC-Uhr ergibt dieselbe Streak wie lokal.
      var state = const StreakState(trackId: "greek");
      for (final day in [12, 13, 14]) {
        final utc = DateTime(2026, 10, day, 23, 30).toUtc();
        for (var i = 0; i < 10; i++) {
          state = StreakCalculator.record(
            state,
            utc,
            source: "vocabulary",
          ).state;
        }
      }
      expect(state.currentStreak, 3);
      expect(state.lastCompletedDate, "2026-10-14");
    });

    test("Uhr zurückgestellt: älterer Tag überschreibt keinen neueren", () {
      const state = StreakState(
        trackId: "greek",
        currentStreak: 5,
        longestStreak: 5,
        lastActivityDate: "2026-10-14",
        lastCompletedDate: "2026-10-14",
        todayCorrectAnswers: 10,
        streakCompletedToday: true,
      );

      final update = StreakCalculator.record(
        state,
        DateTime(2026, 10, 13, 22),
        source: "vocabulary",
      );

      expect(update.changed, isFalse);
      expect(update.state.currentStreak, 5);
    });
  });

  group("Persistenz", () {
    test(
      "doppelte und gleichzeitige Aufrufe zählen jeden Tag einmal",
      () async {
        final (service, repo) = device();

        final updates = await Future.wait([
          for (var i = 0; i < 30; i++)
            service.recordCorrectAnswer(
              uid: "u1",
              track: greek,
              source: StreakSource.vocabulary,
            ),
        ]);
        await settle();

        expect(updates.where((u) => u!.goalReachedNow).length, 1);
        expect(repo.saves, 10);
        expect(server[greek.id]!.currentStreak, 1);
        expect(server[greek.id]!.todayCorrectAnswers, 10);
      },
    );

    test(
      "verspätete Speicherung: Neuladen überschreibt nicht den neueren Stand",
      () async {
        final (service, repo) = device();
        await learn(service, 10);
        now = DateTime(2026, 10, 13, 9);

        repo.delaySaves = true;
        await learn(service, 10);
        expect(service.snapshotFor("u1", greek).currentStreak, 2);

        // Startseite lädt neu, während der Server noch den Vortag kennt.
        await service.load("u1", refresh: true);
        expect(service.snapshotFor("u1", greek).currentStreak, 2);
        expect(service.snapshotFor("u1", greek).completedToday, isTrue);

        repo.releaseSaves();
        await settle();
        expect(server[greek.id]!.currentStreak, 2);
      },
    );

    test("fehlgeschlagene Speicherung wird beim Neuladen nachgeholt", () async {
      final (service, repo) = device();
      await learn(service, 10);
      now = DateTime(2026, 10, 13, 9);

      repo.failSave = true;
      await learn(service, 10);
      await settle();
      expect(server[greek.id]!.currentStreak, 1);
      expect(service.snapshotFor("u1", greek).currentStreak, 2);

      repo.failSave = false;
      await service.load("u1", refresh: true);
      await settle();

      expect(server[greek.id]!.currentStreak, 2);
      expect(server[greek.id]!.lastCompletedDate, "2026-10-13");

      // Neustart der App zeigt den gespeicherten Stand.
      final (restarted, _) = device();
      await restarted.load("u1");
      expect(restarted.snapshotFor("u1", greek).currentStreak, 2);
    });

    test("fehlende Daten: nichts angezeigt, nichts überschrieben", () async {
      server.documents[greek.id] = const StreakState(
        trackId: "greek",
        currentStreak: 7,
        longestStreak: 9,
        lastCompletedDate: "2026-10-11",
      ).toMap();

      final (service, repo) = device();
      repo.offline = true;
      await service.load("u1");

      expect(service.snapshotFor("u1", greek).currentStreak, 0);
      expect(repo.saves, 0);
      expect(server[greek.id]!.currentStreak, 7);

      repo.offline = false;
      await service.load("u1");
      expect(service.snapshotFor("u1", greek).currentStreak, 7);
      expect(service.snapshotFor("u1", greek).longestStreak, 9);
    });

    test("offline nachgetragene Antworten: höchstens das Tagesziel", () async {
      final (service, repo) = device();
      repo.offline = true;

      // Anfangs gelten Fehlversuche für 30 s; danach neuer Versuch.
      await learn(service, 50);
      repo.offline = false;
      now = now.add(StreakService.retryDelay);
      final update = await service.recordCorrectAnswer(
        uid: "u1",
        track: greek,
        source: StreakSource.vocabulary,
      );
      await settle();

      expect(update!.changed, isFalse, reason: "Tagesziel schon nachgetragen");
      expect(server[greek.id]!.currentStreak, 1);
      expect(server[greek.id]!.todayCorrectAnswers, 10);
    });

    test("Zusammenführen: weiter fortgeschrittener Stand gewinnt", () {
      const older = StreakState(
        trackId: "greek",
        currentStreak: 4,
        longestStreak: 12,
        lastActivityDate: "2026-10-12",
        lastCompletedDate: "2026-10-12",
        todayCorrectAnswers: 10,
        streakCompletedToday: true,
      );
      const newer = StreakState(
        trackId: "greek",
        currentStreak: 4,
        longestStreak: 5,
        lastActivityDate: "2026-10-13",
        lastCompletedDate: "2026-10-12",
        todayCorrectAnswers: 3,
      );

      for (final merged in [
        StreakCalculator.merge(older, newer),
        StreakCalculator.merge(newer, older),
      ]) {
        expect(merged.lastActivityDate, "2026-10-13");
        expect(merged.todayCorrectAnswers, 3);
        expect(merged.longestStreak, 12);
      }

      // Am selben erfüllten Tag gewinnt die längere (nicht zurückgesetzte)
      // Streak.
      const reset = StreakState(
        trackId: "greek",
        currentStreak: 1,
        longestStreak: 1,
        lastActivityDate: "2026-10-12",
        lastCompletedDate: "2026-10-12",
        todayCorrectAnswers: 10,
        streakCompletedToday: true,
      );
      expect(StreakCalculator.merge(reset, older).currentStreak, 4);
    });

    test(
      "Gast: Neuladen während eines Speichervorgangs liest den neuen Stand",
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = LocalStreakRepository();

        final save = repo.save(
          const StreakState(trackId: "greek", currentStreak: 6),
        );
        final loaded = await repo.loadAll();
        await save;

        expect(loaded["greek"]!.currentStreak, 6);
      },
    );
  });

  group("Zurücksetzen", () {
    test("kein Lernbereich speichert seinen Lernstand bei den Streaks", () {
      for (final area in ProgressArea.values) {
        expect(area.collection, isNot("streaks"));
        expect(area.documents, isNot(contains("streaks")));
      }
    });

    test(
      "Bereich oder Lernstand zurücksetzen lässt Gast-Streaks unverändert",
      () async {
        SharedPreferences.setMockInitialValues({});
        const streak = StreakState(
          trackId: "latin",
          currentStreak: 8,
          longestStreak: 8,
          lastCompletedDate: "2026-10-12",
        );
        await LocalStreakRepository().save(streak);

        final service = ProgressDataService();
        for (final area in ProgressArea.values) {
          await service.resetArea(null, area);
        }
        await service.resetProgress(null);
        await LocalLearningStore.instance.clearGuestData();

        final all = await LocalStreakRepository().loadAll();
        expect(all["latin"]!.currentStreak, 8);
        expect(all["latin"]!.longestStreak, 8);
      },
    );
  });
}
