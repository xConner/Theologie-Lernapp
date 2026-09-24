import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/widgets/streak_widgets.dart';

/// Speicher im Arbeitsspeicher, simuliert Firestore je uid.
class MemoryRepository implements StreakRepository {
  final Map<String, StreakState> data = {};
  int saves = 0;
  bool failLoad = false;

  @override
  Future<Map<String, StreakState>> loadAll() async {
    if (failLoad) throw Exception("offline");
    return {...data};
  }

  @override
  Future<void> save(StreakState state) async {
    saves++;
    data[state.trackId] = state;
  }
}

void main() {
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

  Future<List<StreakUpdate?>> answer(
    int n, {
    String? uid = "u1",
    StreakTrack track = StreakTrack.greek,
    String source = StreakSource.vocabulary,
  }) async {
    final results = <StreakUpdate?>[];
    for (var i = 0; i < n; i++) {
      results.add(
        await service.recordCorrectAnswer(
          uid: uid,
          track: track,
          source: source,
        ),
      );
    }
    return results;
  }

  StreakSnapshot snap([
    StreakTrack track = StreakTrack.greek,
    String? uid = "u1",
  ]) => service.snapshotFor(uid, track);

  group("Tagesziel", () {
    test(
      "1–9 richtige Antworten: Fortschritt, aber noch keine Streak",
      () async {
        final updates = await answer(9);

        expect(updates.any((u) => u!.goalReachedNow), isFalse);
        expect(snap().todayCorrectAnswers, 9);
        expect(snap().currentStreak, 0);
        expect(snap().completedToday, isFalse);
      },
    );

    test("10. richtige Antwort startet die Streak", () async {
      final updates = await answer(10);

      expect(updates.last!.goalReachedNow, isTrue);
      expect(updates.last!.streakStarted, isTrue);
      expect(snap().currentStreak, 1);
      expect(snap().longestStreak, 1);
      expect(snap().completedToday, isTrue);
    });

    test(
      "11. Antwort am selben Tag erhöht nicht erneut und schreibt nicht",
      () async {
        await answer(10);
        final savesAfterGoal = repos["u1"]!.saves;

        final more = await answer(5);

        expect(more.every((u) => !u!.goalReachedNow && !u.changed), isTrue);
        expect(snap().currentStreak, 1);
        expect(repos["u1"]!.saves, savesAfterGoal);
      },
    );

    test("Vokabeln + Grammatik zählen gemeinsam für die Sprache", () async {
      await answer(5, source: StreakSource.vocabulary);
      final updates = await answer(5, source: StreakSource.grammar);

      expect(updates.last!.goalReachedNow, isTrue);
      expect(snap().todaySources, {"vocabulary": 5, "grammar": 5});
      expect(snap().currentStreak, 1);
    });

    test("Perikopen und Sprachen sind getrennte Tracks", () async {
      await answer(
        10,
        track: StreakTrack.perikope,
        source: StreakSource.perikopenQuiz,
      );
      await answer(4, track: StreakTrack.latin);

      expect(snap(StreakTrack.perikope).currentStreak, 1);
      expect(snap(StreakTrack.greek).todayCorrectAnswers, 0);
      expect(snap(StreakTrack.greek).currentStreak, 0);
      expect(snap(StreakTrack.latin).todayCorrectAnswers, 4);
      expect(snap(StreakTrack.latin).currentStreak, 0);
    });
  });

  group("Kalenderlogik", () {
    test(
      "Mo–Mi erfüllt, Do verpasst, Fr neue Streak 1; longestStreak bleibt",
      () async {
        await answer(10); // Mo
        now = DateTime(2026, 9, 22, 23, 59);
        final tue = await answer(10);
        expect(tue.last!.streakStarted, isFalse);
        now = DateTime(2026, 9, 23, 0, 1);
        await answer(10);
        expect(snap().currentStreak, 3);

        now = DateTime(2026, 9, 24, 12); // Do: nichts gelernt
        expect(snap().currentStreak, 3, reason: "gestern erfüllt → noch aktiv");
        expect(snap().todayCorrectAnswers, 0);

        now = DateTime(2026, 9, 25, 12); // Fr
        expect(snap().currentStreak, 0, reason: "Donnerstag verpasst");
        expect(snap().longestStreak, 3);

        final fri = await answer(10);
        expect(fri.last!.streakStarted, isTrue);
        expect(snap().currentStreak, 1);
        expect(snap().longestStreak, 3);
      },
    );

    test("neuer Tag setzt den Tageszähler zurück", () async {
      await answer(7);
      now = DateTime(2026, 9, 22, 8);

      expect(snap().todayCorrectAnswers, 0);
      await answer(3);
      expect(snap().todayCorrectAnswers, 3);
      expect(snap().completedToday, isFalse);
    });

    test("kalenderbasiert statt 24 Stunden (23:50 → 00:10)", () async {
      now = DateTime(2026, 9, 21, 23, 50);
      await answer(10);
      now = DateTime(2026, 9, 22, 0, 10);
      final updates = await answer(10);

      expect(updates.last!.goalReachedNow, isTrue);
      expect(snap().currentStreak, 2);
    });

    test("Monats- und Jahreswechsel", () async {
      now = DateTime(2026, 12, 31, 20);
      await answer(10);
      now = DateTime(2027, 1, 1, 9);
      await answer(10);

      expect(snap().currentStreak, 2);
    });
  });

  group("Speicher", () {
    test("Reload: neuer Service lädt gespeicherten Stand", () async {
      await answer(10);
      await answer(3, track: StreakTrack.latin);
      await Future<void>.delayed(Duration.zero);

      service = newService();
      await service.load("u1");

      expect(snap().currentStreak, 1);
      expect(snap(StreakTrack.latin).todayCorrectAnswers, 3);
    });

    test("Nutzer getrennt: Gast sieht keine Konto-Streak", () async {
      await answer(10, uid: "u1");
      await service.load(null);

      expect(snap(StreakTrack.greek, null).currentStreak, 0);
      expect(
        snap(StreakTrack.greek, "u1").currentStreak,
        0,
        reason: "nicht geladener Nutzer wird nie angezeigt",
      );
      expect(repos[null]!.data, isEmpty);
    });

    test("Ladefehler: nichts zählen, nichts überschreiben", () async {
      repos["u1"] = MemoryRepository()
        ..data["greek"] = const StreakState(
          trackId: "greek",
          currentStreak: 40,
          longestStreak: 40,
          lastCompletedDate: "2026-09-20",
        )
        ..failLoad = true;

      final result = await service.recordCorrectAnswer(
        uid: "u1",
        track: StreakTrack.greek,
        source: StreakSource.vocabulary,
      );

      expect(result, isNull);
      expect(repos["u1"]!.saves, 0);
      expect(repos["u1"]!.data["greek"]!.currentStreak, 40);
    });

    test("ungültige gespeicherte Werte werden zu Defaults", () {
      final s = StreakState.fromMap("greek", {
        "currentStreak": "x",
        "longestStreak": -3,
        "lastActivityDate": "gestern",
        "todaySources": {"vocabulary": 2, "grammar": "a"},
      });

      expect(s.currentStreak, 0);
      expect(s.longestStreak, 0);
      expect(s.lastActivityDate, isNull);
      expect(s.todaySources, {"vocabulary": 2});
    });

    test(
      "LocalStreakRepository speichert mehrere Tracks ohne Verlust",
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = LocalStreakRepository();

        await Future.wait([
          repo.save(const StreakState(trackId: "greek", currentStreak: 2)),
          repo.save(const StreakState(trackId: "latin", currentStreak: 5)),
        ]);

        final all = await LocalStreakRepository().loadAll();
        expect(all["greek"]!.currentStreak, 2);
        expect(all["latin"]!.currentStreak, 5);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), {LocalStreakRepository.storageKey});
      },
    );
  });

  group("UI", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets("Startseite, Detailansicht und Erfolgsmeldung (Gast)", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ListView(
                children: [
                  const StreakSummary(uid: null),
                  const StreakDetailCard(uid: null, track: StreakTrack.greek),
                  ElevatedButton(
                    onPressed: () => recordStreakAnswer(
                      context,
                      uid: null,
                      track: StreakTrack.greek,
                      source: StreakSource.grammar,
                    ),
                    child: const Text("richtig"),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => StreakService.instance.load(null));
      await tester.pump();

      // Startseite ohne bestehende Streak: keine "0 Tage"-Einträge.
      expect(find.text("Altgriechisch"), findsNothing);
      expect(find.text("0 Tage"), findsNothing);
      expect(find.text("Noch keine aktive Streak"), findsOneWidget);
      expect(find.text("Deine Streak"), findsNothing);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text("richtig"));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 750));

      expect(
        StreakService.instance
            .snapshotFor(null, StreakTrack.greek)
            .todayCorrectAnswers,
        10,
      );
      expect(find.text("🔥 Altgriechisch-Streak gestartet!"), findsOneWidget);
      expect(find.text("1 Tag Streak"), findsOneWidget);
      expect(find.text("Tagesziel erreicht"), findsOneWidget);
      expect(find.text("Deine Streak"), findsOneWidget);
      expect(find.text("Grammatik"), findsNothing);
      expect(find.text("Vokabeln"), findsNothing);
      expect(find.textContaining("richtige Antworten"), findsNothing);
      // Startseite zeigt nur die bestehende Streak.
      expect(find.text("Altgriechisch"), findsOneWidget);
      expect(find.text("Latein"), findsNothing);
      expect(find.text("Perikopen"), findsNothing);
    });

    test("Snackbar-Text beim Fortführen", () {
      final bar = streakSnackBar(
        StreakTrack.perikope,
        const StreakUpdate(
          state: StreakState(trackId: "perikope", currentStreak: 13),
          changed: true,
          goalReachedNow: true,
        ),
      );
      final column = bar.content as Column;
      expect((column.children[0] as Text).data, "🔥 Streak fortgeführt!");
      expect((column.children[1] as Text).data, "Perikopen · 13 Tage");
    });
  });
}
