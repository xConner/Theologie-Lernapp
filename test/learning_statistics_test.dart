import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/statistics/statistics_repository.dart';
import 'package:theologie_lernapp/services/statistics/statistics_service.dart';
import 'package:theologie_lernapp/widgets/sound_volume_button.dart';
import 'package:theologie_lernapp/widgets/statistics_widgets.dart';

/// Speicher im Arbeitsspeicher, simuliert Firestore je uid.
class MemoryRepository implements StatisticsRepository {
  final Map<String, TrainerDays> data = {};
  bool failLoad = false;

  @override
  Future<Map<String, TrainerDays>> loadAll() async {
    if (failLoad) throw Exception("offline");
    return {for (final e in data.entries) e.key: {...e.value}};
  }

  @override
  Future<void> recordAnswer(String trainerId, String date, bool correct) async {
    final days = data.putIfAbsent(trainerId, () => {});
    days[date] = (days[date] ?? DailyStatistics(date: date)).withAnswer(
      correct: correct,
    );
  }
}

const vocab = StatisticsTrainer.greekVocabulary;
const grammar = StatisticsTrainer.greekGrammar;
const latin = StatisticsTrainer.latinVocabulary;
const perikopen = StatisticsTrainer.perikopenQuiz;

void main() {
  late DateTime now;
  late Map<String?, MemoryRepository> repos;
  late LearningStatisticsService service;

  LearningStatisticsService newService() => LearningStatisticsService(
    repositoryFor: (uid) => repos.putIfAbsent(uid, MemoryRepository.new),
    clock: () => now,
  );

  setUp(() {
    now = DateTime(2026, 9, 27, 10); // Sonntag
    repos = {};
    service = newService();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> answer(
    int correct,
    int wrong, {
    String? uid = "u1",
    StatisticsTrainer trainer = vocab,
    LearningStatisticsService? using,
  }) async {
    final s = using ?? service;
    for (var i = 0; i < correct; i++) {
      await s.recordAnswer(uid: uid, trainer: trainer, correct: true);
    }
    for (var i = 0; i < wrong; i++) {
      await s.recordAnswer(uid: uid, trainer: trainer, correct: false);
    }
  }

  DailyStatistics today({
    String? uid = "u1",
    StatisticsTrainer trainer = vocab,
    LearningStatisticsService? using,
  }) => (using ?? service).lastSevenDays(uid, trainer).last;

  group("Berechnung", () {
    test("10 beantwortet, 7 richtig → 70 %", () {
      expect(StatisticsCalculator.formatAccuracy(7, 10), "70 %");
    });

    test("10 beantwortet, 0 richtig → 0 %", () {
      expect(StatisticsCalculator.formatAccuracy(0, 10), "0 %");
    });

    test("10 beantwortet, 10 richtig → 100 %", () {
      expect(StatisticsCalculator.formatAccuracy(10, 10), "100 %");
    });

    test("0 beantwortet → –", () {
      expect(StatisticsCalculator.formatAccuracy(0, 0), "–");
      expect(const DailyStatistics(date: "2026-09-27").accuracy, isNull);
    });

    test("Rundung zeigt nie 100 % bei falschen Antworten", () {
      expect(StatisticsCalculator.formatAccuracy(199, 200), "99 %");
      expect(StatisticsCalculator.formatAccuracy(1, 300), "1 %");
      expect(StatisticsCalculator.formatAccuracy(18, 24), "75 %");
    });

    test("Fragen = richtig + falsch", () async {
      await answer(18, 6);

      final t = today();
      expect(t.answered, 24);
      expect(t.correct, 18);
      expect(t.wrong, 6);
      expect(t.answered, t.correct + t.wrong);
      expect(t.accuracy, 75);
    });
  });

  group("Tageszuordnung", () {
    test("die letzten 7 Kalendertage einschließlich heute", () {
      final days = StatisticsCalculator.lastDays(now);

      expect(days.map(StatisticsCalculator.shortDate), [
        "21.09.",
        "22.09.",
        "23.09.",
        "24.09.",
        "25.09.",
        "26.09.",
        "27.09.",
      ]);
      expect(days.map(StatisticsCalculator.weekdayLabel), [
        "Mo",
        "Di",
        "Mi",
        "Do",
        "Fr",
        "Sa",
        "So",
      ]);
    });

    test("über Monatsgrenze und Sommerzeit-Umstellung", () {
      // 25.10.2026: Ende der Sommerzeit (MEZ).
      final days = StatisticsCalculator.lastDays(DateTime(2026, 10, 27, 0, 30));

      expect(days.map(StatisticsCalculator.dateKey), [
        "2026-10-21",
        "2026-10-22",
        "2026-10-23",
        "2026-10-24",
        "2026-10-25",
        "2026-10-26",
        "2026-10-27",
      ]);

      expect(
        StatisticsCalculator.lastDays(
          DateTime(2026, 3, 2),
        ).map(StatisticsCalculator.dateKey).first,
        "2026-02-24",
      );
    });

    test("Antworten zählen zum lokalen Kalendertag; Mitternacht = neuer "
        "Tag", () async {
      now = DateTime(2026, 9, 26, 23, 59, 59);
      await answer(2, 1);

      now = DateTime(2026, 9, 27, 0, 0, 1);
      await answer(1, 0);

      final days = service.lastSevenDays("u1", vocab);
      expect(days[5].date, "2026-09-26");
      expect(days[5].answered, 3);
      expect(days[5].correct, 2);
      expect(days[6].date, "2026-09-27");
      expect(days[6].answered, 1);
      expect(repos["u1"]!.data[vocab.id]!.keys, {"2026-09-26", "2026-09-27"});
    });

    test("Tage ohne Aktivität erscheinen mit 0", () async {
      now = DateTime(2026, 9, 23, 12);
      await answer(3, 1);
      now = DateTime(2026, 9, 27, 12);

      final days = service.lastSevenDays("u1", vocab);
      expect(days, hasLength(7));
      expect(days.map((d) => d.answered), [0, 0, 4, 0, 0, 0, 0]);
      expect(
        StatisticsCalculator.formatAccuracy(days[0].correct, days[0].answered),
        "–",
      );
    });

    test("Tage älter als 7 Tage erscheinen nicht", () async {
      now = DateTime(2026, 9, 20, 12);
      await answer(5, 0);
      now = DateTime(2026, 9, 27, 12);

      expect(
        service.lastSevenDays("u1", vocab).every((d) => d.answered == 0),
        isTrue,
      );
    });

    test("Heute entspricht dem letzten Eintrag der 7-Tage-Übersicht", () async {
      await answer(4, 2);

      final days = service.lastSevenDays("u1", vocab);
      expect(days.last.date, StatisticsCalculator.dateKey(now));
      expect(today().answered, 6);
      expect(days.last.answered, 6);
      expect(days.last.correct, 4);
    });
  });

  group("Trainertrennung", () {
    test("jede Antwort erscheint nur in der Statistik ihres Trainers", () async {
      await answer(3, 1, trainer: vocab);
      await answer(2, 2, trainer: grammar);
      await answer(1, 0, trainer: perikopen);
      await answer(0, 3, trainer: latin);

      expect(today(trainer: vocab).answered, 4);
      expect(today(trainer: vocab).correct, 3);
      expect(today(trainer: grammar).answered, 4);
      expect(today(trainer: grammar).correct, 2);
      expect(today(trainer: perikopen).answered, 1);
      expect(today(trainer: perikopen).correct, 1);
      expect(today(trainer: latin).answered, 3);
      expect(today(trainer: latin).wrong, 3);

      expect(repos["u1"]!.data.keys, {
        vocab.id,
        grammar.id,
        latin.id,
        perikopen.id,
      });
    });

    test("Trainer-IDs sind eindeutig", () {
      final ids = StatisticsTrainer.all.map((t) => t.id).toSet();
      expect(ids, hasLength(StatisticsTrainer.all.length));
    });
  });

  group("Persistenz", () {
    test("angemeldeter Nutzer: Statistik bleibt nach erneutem Laden "
        "erhalten", () async {
      await answer(5, 3, uid: "u1");

      final reloaded = newService();
      await reloaded.load("u1");

      expect(reloaded.isLoadedFor("u1"), isTrue);
      expect(today(using: reloaded).answered, 8);
      expect(today(using: reloaded).correct, 5);
    });

    test("Nutzerwechsel: keine Daten eines anderen Nutzers", () async {
      await answer(5, 0, uid: "u1");
      await answer(1, 1, uid: "u2");

      expect(today(uid: "u2").answered, 2);
      // u1 ist nicht mehr geladen → keine (fremden) Werte.
      expect(today(uid: "u1").answered, 0);

      await service.load("u1");
      expect(today(uid: "u1").answered, 5);
      expect(repos[null], isNull);
    });

    test("Ladefehler: Antwort wird trotzdem gezählt, nichts "
        "überschrieben", () async {
      repos["u1"] = MemoryRepository()
        ..data[vocab.id] = {
          "2026-09-27": const DailyStatistics(
            date: "2026-09-27",
            correct: 4,
            wrong: 1,
          ),
        }
        ..failLoad = true;

      await answer(1, 0);
      expect(service.isLoadedFor("u1"), isFalse);

      repos["u1"]!.failLoad = false;
      await service.load("u1");
      expect(today().answered, 6);
      expect(today().correct, 5);
    });

    test("Gastmodus: lokal gespeichert und nach Neustart erhalten", () async {
      final guest = LearningStatisticsService(clock: () => now);

      await answer(3, 2, uid: null, trainer: grammar, using: guest);
      await answer(1, 0, uid: null, trainer: perikopen, using: guest);
      await LocalStatisticsRepository.pendingWrites;

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(
        prefs.getString(LocalStatisticsRepository.storageKey)!,
      );
      expect(stored[grammar.id]["2026-09-27"], {
        "answered": 5,
        "correct": 3,
        "wrong": 2,
      });

      // "Neustart": neuer Service liest aus dem lokalen Speicher.
      final restarted = LearningStatisticsService(clock: () => now);
      await restarted.load(null);

      expect(today(uid: null, trainer: grammar, using: restarted).answered, 5);
      expect(today(uid: null, trainer: grammar, using: restarted).wrong, 2);
      expect(
        today(uid: null, trainer: perikopen, using: restarted).answered,
        1,
      );
      expect(today(uid: null, trainer: vocab, using: restarted).answered, 0);
    });

    test("Gastmodus: defekte lokale Daten werden ignoriert", () async {
      SharedPreferences.setMockInitialValues({
        LocalStatisticsRepository.storageKey: "{kaputt",
      });

      expect(await LocalStatisticsRepository().loadAll(), isEmpty);
    });

    test("ungültige gespeicherte Werte werden verworfen", () {
      final days = StatisticsRepository.parseDays({
        "2026-09-27": {"answered": 3, "correct": 2, "wrong": 1},
        "2026-09-26": {"correct": -4, "wrong": "x"},
        "kein-datum": {"correct": 1},
        "2026-09-25": 5,
      });

      expect(days.keys, {"2026-09-27", "2026-09-26"});
      expect(days["2026-09-26"]!.answered, 0);
      expect(days["2026-09-27"]!.answered, 3);
    });
  });

  group("UI", () {
    Future<void> setWidth(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget trainerAppBar() {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text("Vokabeltrainer"),
            actions: [
              StatisticsButton(uid: "u1", trainer: vocab, service: service),
              const SoundVolumeButton(),
              IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
            ],
          ),
        ),
      );
    }

    Future<void> seedWeek() async {
      final perDay = [(9, 3), (15, 3), (0, 0), (12, 6), (8, 2), (14, 2)];
      for (final (i, (c, w)) in perDay.indexed) {
        now = DateTime(2026, 9, 21 + i, 12);
        await answer(c, w);
      }
      now = DateTime(2026, 9, 27, 12);
      await answer(18, 6);
    }

    for (final width in [320.0, 800.0]) {
      testWidgets("Button öffnet Statistik mit korrekten Werten, Breite "
          "$width ohne Overflow", (tester) async {
        // Service in der Testzone anlegen (FakeAsync).
        service = newService();
        await setWidth(tester, width);
        await seedWeek();

        await tester.pumpWidget(trainerAppBar());

        final button = find.byTooltip("Statistik");
        expect(button, findsOneWidget);
        expect(find.byIcon(Icons.bar_chart), findsOneWidget);

        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.text("Vokabeltrainer – Statistik"), findsOneWidget);
        expect(find.text("Heute"), findsOneWidget);
        expect(find.text("Letzte 7 Tage"), findsOneWidget);

        // Heute: 24 Fragen, 18 richtig, 6 falsch, 75 %.
        final todayCard = find.byType(StatisticsTodayCard);
        for (final text in ["24", "18", "6", "75 %"]) {
          expect(
            find.descendant(of: todayCard, matching: find.text(text)),
            findsOneWidget,
          );
        }

        final week = find.byType(StatisticsWeekCard);
        for (final label in [
          "Mo 21.09.",
          "Di 22.09.",
          "Mi 23.09.",
          "Do 24.09.",
          "Fr 25.09.",
          "Sa 26.09.",
          "So 27.09.",
        ]) {
          expect(
            find.descendant(of: week, matching: find.text(label)),
            findsOneWidget,
          );
        }

        if (width < 400) {
          // Kompakte Darstellung.
          expect(find.text("0 Fragen · 0 richtig · 0 falsch"), findsOneWidget);
          expect(find.text("24 Fragen · 18 richtig · 6 falsch"), findsOneWidget);
          expect(find.text("Quote"), findsNothing);
        } else {
          expect(find.text("Quote"), findsOneWidget);
          expect(find.text("83 %"), findsOneWidget); // Di: 15/18
        }

        // Tag ohne Aktivität: "–" statt "0 %".
        expect(
          find.descendant(of: week, matching: find.text("–")),
          findsOneWidget,
        );
        expect(find.text("0 %"), findsNothing);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets("Statistik ohne Antworten zeigt 0 und –", (tester) async {
      service = newService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsView(uid: "u1", trainer: grammar, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Grammatiktrainer – Statistik"), findsOneWidget);
      final todayCard = find.byType(StatisticsTodayCard);
      expect(
        find.descendant(of: todayCard, matching: find.text("–")),
        findsOneWidget,
      );
      expect(find.text("0 %"), findsNothing);
    });

    testWidgets("Ladefehler zeigt Hinweis statt Werten", (tester) async {
      service = newService();
      repos["u1"] = MemoryRepository()..failLoad = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsView(uid: "u1", trainer: vocab, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Die Statistik konnte nicht geladen werden."),
        findsOneWidget,
      );
      expect(find.byType(StatisticsTodayCard), findsNothing);
    });

    // Die Trainer-Screens benötigen Firebase und lassen sich hier nicht
    // aufbauen; daher wird die Einbindung im Quelltext geprüft.
    test("Statistikbutton und Zählung in allen Trainern", () {
      final trainers = {
        "lib/screens/greek/vocabulary_trainer_screen.dart":
            "StatisticsTrainer.greekVocabulary",
        "lib/screens/greek/grammar_trainer_screen.dart":
            "StatisticsTrainer.greekGrammar",
        "lib/screens/latin/latin_vocabulary_trainer_screen.dart":
            "StatisticsTrainer.latinVocabulary",
        "lib/screens/pericope_quiz/quiz_screen.dart":
            "StatisticsTrainer.perikopenQuiz",
      };

      for (final MapEntry(key: path, value: trainer) in trainers.entries) {
        final source = File(path).readAsStringSync();
        final appBars = RegExp(r"AppBar\(").allMatches(source).length;

        expect(
          RegExp(
            r"StatisticsButton\(\s*uid: [^,]+,\s*trainer: " +
                RegExp.escape(trainer),
          ).allMatches(source).length,
          appBars,
          reason: "$path: Statistikbutton in jeder AppBar",
        );
        expect(
          RegExp(
            r"recordAnswer\(\s*uid: [^,]+,\s*trainer: " + RegExp.escape(trainer),
          ).allMatches(source).length,
          1,
          reason: "$path: genau eine Zählstelle",
        );
      }
    });
  });
}
