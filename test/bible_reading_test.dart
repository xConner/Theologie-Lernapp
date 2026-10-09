import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reading.dart';
import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/bible/reading_plan.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/reading_plan_codec.dart';
import 'package:theologie_lernapp/services/bible/reading_plan_text.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';

import 'test_asset_bundle.dart';

/// Speicher im Arbeitsspeicher, simuliert Firestore je uid.
class MemoryReadingRepository implements BibleReadingRepository {
  final Map<String, Map<String, dynamic>> data = {};
  int writes = 0;
  bool failLoad = false;

  @override
  Future<Map<String, Map<String, dynamic>>> loadAll() async {
    if (failLoad) throw Exception("offline");

    // Wie ein echter Speicher: nur JSON-taugliche Kopien.
    return {
      for (final entry in data.entries)
        entry.key: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(entry.value)) as Map,
        ),
    };
  }

  @override
  Future<void> save(
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    writes++;

    final existing = this.data[id];

    this.data[id] = merge && existing != null ? _merged(existing, data) : data;
  }

  @override
  Future<void> delete(String id) async {
    writes++;
    data.remove(id);
  }

  static Map<String, dynamic> _merged(
    Map<String, dynamic> target,
    Map<String, dynamic> changes,
  ) {
    final result = {...target};

    for (final entry in changes.entries) {
      final before = result[entry.key];
      final value = entry.value;

      result[entry.key] = before is Map && value is Map
          ? _merged(
              Map<String, dynamic>.from(before),
              Map<String, dynamic>.from(value),
            )
          : value;
    }

    return result;
  }
}

class MemoryStreakRepository implements StreakRepository {
  final Map<String, StreakState> data = {};

  @override
  Future<Map<String, StreakState>> loadAll() async => {...data};

  @override
  Future<void> save(StreakState state) async {
    data[state.trackId] = state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bundle = FileAssetBundle();

  late List<BibleTranslation> translations;

  // Ausgaben mit den 66 Büchern in gewohnter Kapitelzählung.
  late List<BibleTranslation> protestant;

  late List<ReadingPlan> builtIn;

  setUpAll(() async {
    translations = await AssetBibleTextSource(
      bundle: bundle,
    ).loadTranslations();

    protestant = translations
        .where((t) => t.language == "de" || t.language == "en")
        .toList();

    final index = jsonDecode(
      await bundle.loadString("assets/reading_plans/index.json"),
    );

    builtIn = [
      for (final file in index["plans"] as List)
        ReadingPlanCodec.decode(
          await bundle.loadString("assets/reading_plans/$file"),
          translations: translations,
          builtIn: true,
        ),
    ];
  });

  ReadingPlan builtInPlan(String id) => builtIn.firstWhere((p) => p.id == id);

  // ==========================
  // STELLENANGABEN
  // ==========================

  group("Stellenangaben des Planformats", () {
    test("liest und schreibt alle Formen", () {
      for (final key in [
        "JOL",
        "GEN 1",
        "GEN 1-3",
        "JHN 3:16",
        "JHN 3:16-21",
        "GEN 1:1-2:3",
        "1SA 4-7",
      ]) {
        expect(PlanReading.parse(key)?.key, key);
      }

      expect(PlanReading.parse(" gen 1 "), isNull, reason: "Kleinbuchstaben");
      expect(PlanReading.parse("GEN 1–3")?.key, "GEN 1-3");
      expect(PlanReading.parse("GEN 2-2")?.key, "GEN 2");
    });

    test("weist ungültige Formen zurück", () {
      for (final input in [
        "",
        "Genesis 1",
        "GEN 0",
        "GEN 3-1",
        "GEN 1-3:5",
        "GEN 1:5-2",
        "GEN 1:0",
        "GEN 2:3-1:1",
        "GEN 1,3",
      ]) {
        expect(PlanReading.parse(input), isNull, reason: input);
      }
    });

    test("deutsche Anzeige und Stelle für den Reader", () {
      expect(PlanReading.parse("GEN 1-3")!.label, "Gen 1–3");
      expect(PlanReading.parse("JHN 3:16-21")!.label, "Joh 3,16–21");
      expect(PlanReading.parse("JOL")!.label, BibleBooks.nameOf("JOL"));

      expect(
        PlanReading.parse("JHN 3:16-21")!.reference,
        const BibleReference(
          bookId: "JHN",
          chapter: 3,
          verse: 16,
          endVerse: 21,
        ),
      );

      final book = PlanReading.parse("JOL")!.reference;

      expect(book.chapter, 1);
      expect(book.containsVerse(4, 1), isTrue, reason: "ganzes Buch");
    });

    test("prüft Buch, Kapitel und Vers an den Ausgaben", () {
      String? problem(String key) =>
          PlanReading.parse(key)!.problemIn(translations);

      expect(problem("GEN 50"), isNull);
      expect(problem("PSA 119:176"), isNull);
      expect(problem("TOB 1"), isNull, reason: "Apokryphen in LXX/Vulgata");

      expect(problem("XYZ 1"), contains("Unbekanntes Buch"));
      expect(problem("GEN 51"), contains("kein Kapitel 51"));
      expect(problem("GEN 49-51"), contains("kein Kapitel 51"));
      expect(problem("JHN 3:99"), contains("keinen Vers 99"));
      expect(problem("JHN 3:16-99"), contains("keinen Vers 99"));
    });

    test("Texteingabe eigener Pläne", () {
      String? key(String input) => ReadingPlanText.parseReading(input)?.key;

      expect(key("Mk 4"), "MRK 4");
      expect(key("Gen 1-3"), "GEN 1-3");
      expect(key("Joh 3,16-21"), "JHN 3:16-21");
      expect(key("1. Mose 1,1–2,4"), "GEN 1:1-2:4");
      expect(key("Joel"), "JOL");
      expect(key("PSA 23"), "PSA 23");
      expect(key("Quatsch 3"), isNull);
      expect(key("Mk 4,35ff"), isNull);

      final built = ReadingPlanText.build(
        id: "plan-test",
        name: "Test",
        description: "",
        days: "Mk 1-2; Ps 1\n\nMk 3\nUnsinn 9",
      );

      expect(built.json["days"], [
        ["MRK 1-2", "PSA 1"],
        ["MRK 3"],
        <String>[],
      ]);
      expect(built.problems.single, contains("Tag 3"));

      final id = ReadingPlanText.newId("Mein Über-Plan!", DateTime(2026));

      expect(ReadingPlanCodec.idPattern.hasMatch(id), isTrue);
      expect(id, startsWith("plan-mein-ueber-plan-"));
    });
  });

  // ==========================
  // INTEGRIERTE PLÄNE
  // ==========================

  group("Integrierte Pläne", () {
    /// Kapitel (Buch, Nummer) einer Lesung in [t].
    Iterable<(String, int)> chaptersOf(PlanReading r, BibleTranslation t) {
      final book = t.book(BibleBooks.resolveIn(t, r.bookId)!)!;
      final first = r.chapter ?? 1;
      final last = r.chapter == null
          ? book.chapterCount
          : r.endChapter ?? r.chapter!;

      return [for (var c = first; c <= last; c++) (r.bookId, c)];
    }

    test("Auswahl, Dauer und Kennungen", () {
      expect(
        {for (final plan in builtIn) plan.id: plan.dayCount},
        {
          "bible-1-year": 365,
          "bible-6-months": 180,
          "bible-90-days": 90,
          "nt-90-days": 90,
          "gospels-30-days": 30,
          "bible-marathon-30-days": 30,
        },
      );

      for (final plan in builtIn) {
        expect(ReadingPlanCodec.idPattern.hasMatch(plan.id), isTrue);
        expect(plan.name, isNotEmpty);
        expect(plan.description, isNotEmpty);
        expect(plan.language, "de");
        expect(plan.sourceName, "theologie.app");
        expect(plan.builtIn, isTrue);
      }
    });

    test("jeder Tag hat Lesungen, keine Lesung steht doppelt", () {
      for (final plan in builtIn) {
        final seen = <String>{};

        for (var day = 1; day <= plan.dayCount; day++) {
          expect(plan.readingsOn(day), isNotEmpty, reason: "${plan.id} $day");

          for (final reading in plan.readingsOn(day)) {
            expect(
              seen.add(reading.key),
              isTrue,
              reason: "${plan.id}: ${reading.key} doppelt",
            );
          }
        }
      }
    });

    test("jede Lesung lässt sich in jeder Ausgabe aufschlagen, die das Buch "
        "enthält", () {
      for (final plan in builtIn) {
        for (final day in plan.days) {
          for (final reading in day.readings) {
            var found = 0;

            for (final t in translations) {
              if (BibleBooks.resolveIn(t, reading.bookId) == null) continue;

              found++;

              expect(
                reading.problemInTranslation(t),
                isNull,
                reason: "${plan.id}: ${reading.key} in ${t.id}",
              );
            }

            // Mindestens alle deutschen, englischen und die lateinische.
            expect(found, greaterThanOrEqualTo(7), reason: reading.key);
          }
        }
      }
    });

    test("Ganzbibel-Pläne decken jedes Kapitel der 66 Bücher genau einmal "
        "ab – in jeder deutschen und englischen Ausgabe", () {
      for (final id in [
        "bible-1-year",
        "bible-6-months",
        "bible-90-days",
        "bible-marathon-30-days",
      ]) {
        final plan = builtInPlan(id);

        for (final t in protestant) {
          final expected = [
            for (final book in t.books)
              for (var c = 1; c <= book.chapterCount; c++) (book.id, c),
          ];

          expect(expected.length, 1189);

          final read = [
            for (final day in plan.days)
              for (final reading in day.readings) ...chaptersOf(reading, t),
          ];

          expect(read.length, read.toSet().length, reason: "$id doppelt");
          expect(read.toSet(), expected.toSet(), reason: "$id in ${t.id}");
        }
      }
    });

    test("NT- und Evangelienplan decken genau ihre Bücher ab", () {
      final t = protestant.first;

      for (final (id, books) in [
        (
          "nt-90-days",
          [
            for (final b in BibleBooks.all)
              if (b.testament == BibleTestament.newTestament) b.id,
          ],
        ),
        ("gospels-30-days", ["MAT", "MRK", "LUK", "JHN"]),
      ]) {
        final expected = {
          for (final book in books)
            for (var c = 1; c <= t.book(book)!.chapterCount; c++) (book, c),
        };

        final read = [
          for (final day in builtInPlan(id).days)
            for (final reading in day.readings) ...chaptersOf(reading, t),
        ];

        expect(read.length, read.toSet().length);
        expect(read.toSet(), expected, reason: id);
      }
    });

    test("fortlaufende Pläne folgen der Reihenfolge der Bibel", () {
      for (final id in [
        "bible-90-days",
        "bible-marathon-30-days",
        "nt-90-days",
        "gospels-30-days",
      ]) {
        final order = [
          for (final day in builtInPlan(id).days)
            for (final reading in day.readings)
              BibleBooks.order(reading.bookId) * 1000 + (reading.chapter ?? 1),
        ];

        expect(order, [...order]..sort(), reason: id);
      }
    });

    test("die Tage sind gleichmäßig verteilt", () {
      for (final plan in builtIn) {
        final verses = [
          for (final day in plan.days)
            day.readings.fold<int>(
              0,
              (sum, r) => sum + r.extentIn(translations).verses,
            ),
        ];

        final average = verses.reduce((a, b) => a + b) / verses.length;
        final max = verses.reduce((a, b) => a > b ? a : b);
        final min = verses.reduce((a, b) => a < b ? a : b);

        // Psalm 119 (176 Verse) ist nicht teilbar, daher etwas Spielraum.
        expect(max, lessThan(average * 2 + 120), reason: plan.id);
        expect(min, greaterThan(average * 0.35), reason: plan.id);
      }
    });

    test("sehr intensive Pläne sind als solche erkennbar", () {
      ReadingPlanExtent extent(String id) =>
          builtInPlan(id).extentIn(translations);

      expect(extent("bible-1-year").isIntensive, isFalse);
      expect(extent("nt-90-days").isIntensive, isFalse);
      expect(extent("gospels-30-days").isIntensive, isFalse);

      expect(extent("bible-90-days").isIntensive, isTrue);
      expect(
        builtInPlan("bible-90-days").difficulty,
        ReadingPlanDifficulty.intensive,
      );

      final marathon = extent("bible-marathon-30-days");

      expect(marathon.isExtreme, isTrue);
      expect(marathon.chaptersPerDay, closeTo(1189 / 30, 0.5));
      expect(marathon.minutesPerDay, greaterThan(90));
      expect(
        builtInPlan("bible-marathon-30-days").difficulty,
        ReadingPlanDifficulty.extreme,
      );

      expect(extent("bible-1-year").verses, 31102);
      expect(extent("bible-1-year").summary, contains("Kapitel"));
    });
  });

  // ==========================
  // IMPORT UND EXPORT
  // ==========================

  group("Plandateien", () {
    const valid = {
      "format": "theologie.app/reading-plan",
      "formatVersion": 1,
      "id": "mein-plan",
      "name": "Mein Plan",
      "description": "Drei Tage Markus",
      "language": "de",
      "category": "gospels",
      "difficulty": "easy",
      "source": {"name": "Ich", "url": "https://example.org"},
      "license": "CC0 1.0",
      "days": [
        ["MRK 1-2", "PSA 1"],
        {
          "title": "Gleichnisse",
          "readings": ["MRK 4:1-34"],
        },
        ["JOL"],
      ],
    };

    List<String> problemsOf(Object? json) {
      try {
        ReadingPlanCodec.decode(
          json is String ? json : jsonEncode(json),
          translations: translations,
        );
      } on ReadingPlanFormatException catch (e) {
        return e.problems;
      }

      return const [];
    }

    Map<String, dynamic> changed(Map<String, dynamic> changes) {
      return {...valid, ...changes}..removeWhere((_, value) => value == null);
    }

    test("gültige Datei wird vollständig gelesen", () {
      final plan = ReadingPlanCodec.decode(
        jsonEncode(valid),
        translations: translations,
      );

      expect(plan.id, "mein-plan");
      expect(plan.name, "Mein Plan");
      expect(plan.dayCount, 3);
      expect(plan.readingCount, 4);
      expect(plan.days[1].title, "Gleichnisse");
      expect(plan.readingsOn(2).single.key, "MRK 4:1-34");
      expect(plan.difficulty, ReadingPlanDifficulty.easy);
      expect(plan.categoryLabel, "Evangelien");
      expect(plan.sourceUrl, "https://example.org");
      expect(plan.license, "CC0 1.0");
      expect(plan.builtIn, isFalse);
    });

    test("Mindestangaben genügen", () {
      final plan = ReadingPlanCodec.decode(
        '{"id": "kurz", "name": "Kurz", "days": [["GEN 1"]]}',
        translations: translations,
      );

      expect(plan.language, "de");
      expect(plan.difficulty, isNull);
    });

    test("Export und erneuter Import ergeben denselben Plan", () {
      final plan = ReadingPlanCodec.decode(jsonEncode(valid));
      final exported = ReadingPlanCodec.encode(plan);
      final again = ReadingPlanCodec.decode(
        exported,
        translations: translations,
      );

      expect(ReadingPlanCodec.toJson(again), ReadingPlanCodec.toJson(plan));
      expect(jsonDecode(exported)["days"], valid["days"]);

      // Auch die integrierten Pläne überstehen den Weg unverändert.
      for (final plan in builtIn) {
        final copy = ReadingPlanCodec.decode(ReadingPlanCodec.encode(plan));

        expect(ReadingPlanCodec.toJson(copy), ReadingPlanCodec.toJson(plan));
      }
    });

    test("ungültige Dateien: verständliche Meldungen", () {
      expect(problemsOf("").single, contains("leer"));
      expect(problemsOf("{kaputt").single, contains("kein gültiges JSON"));
      expect(problemsOf("[1, 2]").single, contains("JSON-Objekt"));

      expect(
        problemsOf({"name": "Ohne alles"}),
        containsAll([contains("„id“ fehlt"), contains("„days“ fehlt")]),
      );

      expect(
        problemsOf(changed({"id": "Mein Plan!"})).single,
        contains("Kennung"),
      );
      expect(problemsOf(changed({"name": "  "})).single, contains("„name“"));
      expect(
        problemsOf(changed({"formatVersion": 2})).single,
        contains("Formatversion"),
      );
      expect(
        problemsOf(changed({"difficulty": "brutal"})).single,
        contains("Schwierigkeitsgrad"),
      );
      expect(
        problemsOf(changed({"days": <Object>[]})).single,
        contains("keine Tage"),
      );
      expect(
        problemsOf(changed({"days": "MRK 1"})).single,
        contains("Liste der Tage"),
      );
    });

    test("ungültige Bibelstellen werden mit Tag und Stelle genannt", () {
      final problems = problemsOf(
        changed({
          "days": [
            ["MRK 1", "XYZ 3"],
            <String>[],
            ["GEN 51"],
            ["Markus 1"],
            ["JHN 3:99"],
            ["MRK 2", "MRK 2"],
            [42],
          ],
        }),
      );

      expect(problems, hasLength(7));
      expect(problems[0], allOf(contains("Tag 1"), contains("XYZ")));
      expect(problems[1], contains("Tag 2 enthält keine Lesung"));
      expect(problems[2], allOf(contains("Tag 3"), contains("Kapitel 51")));
      expect(problems[3], allOf(contains("Tag 4"), contains("Markus 1")));
      expect(problems[4], allOf(contains("Tag 5"), contains("Vers 99")));
      expect(problems[5], allOf(contains("Tag 6"), contains("doppelt")));
      expect(problems[6], contains("Tag 7"));
    });

    test("viele Fehler werden zusammengefasst", () {
      final problems = problemsOf(
        changed({
          "days": [
            for (var i = 0; i < 40; i++) ["XYZ $i"],
          ],
        }),
      );

      expect(problems.length, 13);
      expect(problems.last, contains("weitere Probleme"));
    });
  });

  // ==========================
  // LESEN, STREAK, PLANFORTSCHRITT
  // ==========================

  group("Bibellesen", () {
    late DateTime now;
    late Map<String?, MemoryReadingRepository> repos;
    late Map<String?, MemoryStreakRepository> streakRepos;
    late StreakService streaks;
    late BibleReadingService service;

    BibleReadingService newService() {
      streaks = StreakService(
        repositoryFor: (uid) =>
            streakRepos.putIfAbsent(uid, MemoryStreakRepository.new),
        clock: () => now,
      );

      return BibleReadingService(
        repositoryFor: (uid) =>
            repos.putIfAbsent(uid, MemoryReadingRepository.new),
        clock: () => now,
        streaks: streaks,
        bundle: bundle,
        translations: () async => translations,
      );
    }

    setUp(() {
      now = DateTime(2026, 9, 28, 10); // Montag
      repos = {};
      streakRepos = {};
      service = newService();
    });

    StreakSnapshot streak([String? uid = "u1"]) =>
        streaks.snapshotFor(uid, StreakTrack.bible);

    /// App neu starten: alles kommt aus dem Speicher.
    Future<void> restart() async {
      await pumpEventQueue();

      service = newService();

      await service.load("u1");
      await streaks.load("u1");
    }

    Future<BibleReadingResult?> mark(
      int day,
      int reading, {
      String plan = "gospels-30-days",
      bool done = true,
    }) {
      return service.setPlanReading(
        uid: "u1",
        planId: plan,
        day: day,
        reading: reading,
        done: done,
      );
    }

    test("das Laden allein zählt nichts", () async {
      await service.load("u1");
      await streaks.load("u1");

      expect(service.plans.length, 6);
      expect(streak().currentStreak, 0);
      expect(streak().completedToday, isFalse);
      expect(service.readingDayCount("u1"), 0);
      expect(repos["u1"]!.writes, 0);
      expect(streakRepos["u1"]!.data, isEmpty);
    });

    test("bestätigte freie Lesung ohne Plan zählt für die Streak", () async {
      final result = await service.confirmReading(uid: "u1", text: "Mk 4");

      expect(result.logged, isTrue);
      expect(result.streak!.goalReachedNow, isTrue);
      expect(result.streak!.streakStarted, isTrue);

      expect(streak().completedToday, isTrue);
      expect(streak().currentStreak, 1);
      expect(streak().todaySources, {StreakSource.bibleReading: 1});

      expect(service.startedPlans("u1"), isEmpty);
      expect(service.entriesOn("u1", "2026-09-28").single.text, "Mk 4");
      expect(service.readingDayCount("u1"), 1);
    });

    test("die Stellenangabe ist optional", () async {
      final result = await service.confirmReading(uid: "u1");

      expect(result.streak!.goalReachedNow, isTrue);
      expect(service.entriesOn("u1", service.today).single.text, "");
    });

    test("mehrere Lesungen am Tag: mehrere Einträge, ein Lesetag", () async {
      await service.confirmReading(uid: "u1", text: "Mk 4");

      final second = await service.confirmReading(uid: "u1", text: "Ps 23");

      expect(second.streak!.changed, isFalse);
      expect(second.streak!.goalReachedNow, isFalse);

      expect(service.entriesOn("u1", service.today).map((e) => e.text), [
        "Mk 4",
        "Ps 23",
      ]);
      expect(service.readingDayCount("u1"), 1);
      expect(streak().currentStreak, 1);
      expect(streak().todayCorrectAnswers, 1);
    });

    test("wiederholtes Bestätigen derselben Lesung erzeugt nichts", () async {
      await service.confirmReading(uid: "u1", text: "Mk 4");
      await pumpEventQueue();

      final writes = repos["u1"]!.writes;

      for (var i = 0; i < 5; i++) {
        await service.confirmReading(uid: "u1", text: "  mk   4 ");
      }

      await pumpEventQueue();

      expect(service.entriesOn("u1", service.today), hasLength(1));
      expect(repos["u1"]!.writes, writes);
      expect(streak().currentStreak, 1);
    });

    test("aufeinanderfolgende Tage über die Monatsgrenze, ein Tag ohne "
        "Lesung beginnt neu", () async {
      for (final day in [
        DateTime(2026, 9, 28, 22),
        DateTime(2026, 9, 29, 7),
        DateTime(2026, 9, 30, 23, 59),
        DateTime(2026, 10, 1, 0, 1),
        DateTime(2026, 10, 2, 12),
      ]) {
        now = day;

        await service.confirmReading(uid: "u1");
      }

      expect(streak().currentStreak, 5);
      expect(service.readingDayCount("u1"), 5);
      expect(service.entriesOn("u1", "2026-09-30"), hasLength(1));
      expect(service.entriesOn("u1", "2026-10-01"), hasLength(1));

      // 3. Oktober ohne Lesung.
      now = DateTime(2026, 10, 3, 23);
      expect(streak().currentStreak, 5, reason: "gestern gelesen → aktiv");
      expect(streak().completedToday, isFalse);

      now = DateTime(2026, 10, 4, 9);
      expect(streak().currentStreak, 0);

      await service.confirmReading(uid: "u1");

      expect(streak().currentStreak, 1);
      expect(streak().longestStreak, 5);
    });

    test("der Tag ist der lokale Kalendertag, nicht der UTC-Tag", () async {
      // Kurz nach Mitternacht Ortszeit: in UTC je nach Zeitzone noch der
      // Vortag bzw. schon der Folgetag.
      now = DateTime(2026, 10, 1, 0, 30);

      await service.confirmReading(uid: "u1", text: "Nachts");

      expect(service.today, "2026-10-01");
      expect(service.entriesOn("u1", "2026-10-01"), hasLength(1));
      expect(streakRepos["u1"]!.data["bible"]!.lastCompletedDate, "2026-10-01");

      // Derselbe Zeitpunkt als UTC-Angabe ändert den Tag der Uhr nicht.
      now = DateTime.utc(2026, 10, 1, 23, 30);

      await service.confirmReading(uid: "u1", text: "Spät");

      expect(service.entriesOn("u1", "2026-10-01"), hasLength(2));
      expect(streak().currentStreak, 1);
    });

    test("Planlesung zählt für die Streak und für den Plan", () async {
      await service.startPlan("u1", "gospels-30-days");

      final plan = service.plan("gospels-30-days")!;

      expect(service.progressOf("u1", plan.id)!.startedOn, "2026-09-28");
      expect(service.progressOf("u1", plan.id)!.currentDay(plan), 1);
      expect(streak().completedToday, isFalse, reason: "Beginnen zählt nicht");

      final result = await mark(1, 0);

      expect(result!.streak!.goalReachedNow, isTrue);
      expect(streak().currentStreak, 1);
      expect(streak().todaySources, {StreakSource.readingPlan: 1});

      final progress = service.progressOf("u1", plan.id)!;

      expect(progress.isDone(1, 0), isTrue);
      expect(progress.isDayComplete(plan, 1), isTrue);
      expect(progress.currentDay(plan), 2);
      expect(progress.completedDays(plan), 1);

      final entry = service.entriesOn("u1", service.today).single;

      expect(entry.planId, plan.id);
      expect(entry.text, plan.readingsOn(1).first.label);
    });

    test("freie Lesung erhält die Streak, erledigt aber keinen "
        "Plantag", () async {
      await service.startPlan("u1", "bible-1-year");

      final plan = service.plan("bible-1-year")!;

      await service.confirmReading(
        uid: "u1",
        text: plan.readingsOn(1).first.label,
      );

      expect(streak().completedToday, isTrue);

      final progress = service.progressOf("u1", plan.id)!;

      expect(progress.doneReadings(plan), 0);
      expect(progress.isDayComplete(plan, 1), isFalse);
      expect(progress.currentDay(plan), 1);
    });

    test("mehrere Lesungen eines Plantags in beliebiger Reihenfolge", () async {
      await service.startPlan("u1", "bible-1-year");

      final plan = service.plan("bible-1-year")!;

      expect(plan.readingsOn(1), hasLength(2));

      // Zuerst die zweite Lesung, dann eine von Tag 3.
      await mark(1, 1, plan: plan.id);
      await mark(3, 0, plan: plan.id);

      var progress = service.progressOf("u1", plan.id)!;

      expect(progress.isDone(1, 0), isFalse);
      expect(progress.isDone(1, 1), isTrue);
      expect(progress.doneOn(plan, 1), 1);
      expect(progress.isDayComplete(plan, 1), isFalse);
      expect(progress.currentDay(plan), 1);
      expect(progress.doneReadings(plan), 2);

      await mark(1, 0, plan: plan.id);

      progress = service.progressOf("u1", plan.id)!;

      expect(progress.isDayComplete(plan, 1), isTrue);
      expect(progress.currentDay(plan), 2);
      expect(progress.fraction(plan), closeTo(3 / plan.readingCount, 1e-9));

      // Drei Lesungen, ein Lesetag.
      expect(service.entriesOn("u1", service.today), hasLength(3));
      expect(streak().currentStreak, 1);
      expect(streak().todayCorrectAnswers, 1);
    });

    test("doppeltes Abhaken und unbekannte Lesungen ändern nichts", () async {
      await service.startPlan("u1", "gospels-30-days");

      expect(await mark(1, 0), isNotNull);
      await pumpEventQueue();

      final writes = repos["u1"]!.writes;

      expect(await mark(1, 0), isNull, reason: "schon erledigt");
      expect(await mark(1, 7), isNull, reason: "Lesung gibt es nicht");
      expect(await mark(99, 0), isNull, reason: "Tag gibt es nicht");
      expect(await mark(2, 0, done: false), isNull, reason: "war offen");
      expect(
        await mark(1, 0, plan: "nt-90-days"),
        isNull,
        reason:
            "nicht "
            "begonnen",
      );

      await pumpEventQueue();

      expect(repos["u1"]!.writes, writes);
      expect(service.entriesOn("u1", service.today), hasLength(1));
    });

    test("Abhaken zurücknehmen: Plan und Verlauf folgen, die Streak "
        "bleibt", () async {
      await service.startPlan("u1", "gospels-30-days");
      await mark(1, 0);

      final result = await mark(1, 0, done: false);

      expect(result, isNotNull);

      final plan = service.plan("gospels-30-days")!;

      expect(service.progressOf("u1", plan.id)!.doneReadings(plan), 0);
      expect(service.entriesOn("u1", service.today), isEmpty);
      expect(service.readingDayCount("u1"), 0);
      expect(streak().completedToday, isTrue);
    });

    test("Fortschritt, Verlauf und Streak überstehen den Neustart", () async {
      await service.startPlan("u1", "gospels-30-days");
      await mark(1, 0);
      await mark(2, 0);
      await service.confirmReading(uid: "u1", text: "Ps 23");

      await restart();

      final plan = service.plan("gospels-30-days")!;
      final progress = service.progressOf("u1", plan.id)!;

      expect(progress.startedOn, "2026-09-28");
      expect(progress.completedDays(plan), 2);
      expect(progress.currentDay(plan), 3);
      expect(service.entriesOn("u1", "2026-09-28"), hasLength(3));
      expect(streak().currentStreak, 1);

      // Wiederaufnahme am nächsten Tag.
      now = DateTime(2026, 9, 29, 8);

      await mark(3, 0);

      expect(service.progressOf("u1", plan.id)!.currentDay(plan), 4);
      expect(streak().currentStreak, 2);
      expect(service.readingDayCount("u1"), 2);

      // Plan und Streak liegen in getrennten Speichern.
      expect(repos["u1"]!.data.keys, {"plan_gospels-30-days", "log_2026"});
      expect(streakRepos["u1"]!.data.keys, {"bible"});
    });

    test("Pausieren, Fortsetzen und Beenden", () async {
      await service.startPlan("u1", "gospels-30-days");
      await mark(1, 0);

      await service.setPaused("u1", "gospels-30-days", true);

      expect(service.progressOf("u1", "gospels-30-days")!.paused, isTrue);
      expect(await mark(2, 0), isNull, reason: "pausiert");

      // Frei lesen geht weiter, auch über Tage hinweg.
      now = DateTime(2026, 9, 29, 8);
      await service.confirmReading(uid: "u1", text: "Ps 1");

      expect(streak().currentStreak, 2);

      await restart();

      final plan = service.plan("gospels-30-days")!;

      expect(service.progressOf("u1", plan.id)!.paused, isTrue);

      await service.setPaused("u1", plan.id, false);

      expect(service.progressOf("u1", plan.id)!.currentDay(plan), 2);
      expect(await mark(2, 0), isNotNull);

      // Ein zweiter Start setzt nichts zurück.
      await service.startPlan("u1", plan.id);

      expect(service.progressOf("u1", plan.id)!.doneReadings(plan), 2);

      await service.endPlan("u1", plan.id);
      await restart();

      expect(service.progressOf("u1", plan.id), isNull);
      expect(service.startedPlans("u1"), isEmpty);
      expect(service.readingDayCount("u1"), 2, reason: "Verlauf bleibt");
      expect(streak().currentStreak, 2, reason: "Streak bleibt");
    });

    test("ein ganzer Plan lässt sich abschließen", () async {
      await service.startPlan("u1", "gospels-30-days");

      final plan = service.plan("gospels-30-days")!;

      for (var day = 1; day <= plan.dayCount; day++) {
        for (var i = 0; i < plan.readingsOn(day).length; i++) {
          await mark(day, i);
        }
      }

      final progress = service.progressOf("u1", plan.id)!;

      expect(progress.isComplete(plan), isTrue);
      expect(progress.currentDay(plan), isNull);
      expect(progress.fraction(plan), 1);
      expect(streak().currentStreak, 1, reason: "alles an einem Tag");
    });

    test("Nutzer sind getrennt (Konto und Gast)", () async {
      await service.confirmReading(uid: "u1", text: "Mk 1");
      await service.startPlan("u1", "nt-90-days");

      await service.load(null);
      await streaks.load(null);

      expect(service.entriesOn(null, service.today), isEmpty);
      expect(service.startedPlans(null), isEmpty);
      expect(
        service.entriesOn("u1", service.today),
        isEmpty,
        reason: "nicht mehr geladen",
      );
      expect(streak(null).currentStreak, 0);

      await service.confirmReading(uid: null, text: "Ps 1");

      expect(repos[null]!.data.keys, {"log_2026"});
      expect(repos["u1"]!.data.keys, {"log_2026", "plan_nt-90-days"});
    });

    test("nicht ladbarer Verlauf: nichts wird überschrieben, die Streak "
        "zählt trotzdem", () async {
      repos["u1"] = MemoryReadingRepository()
        ..failLoad = true
        ..data["log_2026"] = {
          "days": {
            "2026-09-01": [
              {"id": "free:alt", "text": "Alt"},
            ],
          },
        };

      final result = await service.confirmReading(uid: "u1", text: "Mk 4");

      expect(result.logged, isFalse);
      expect(result.streak!.goalReachedNow, isTrue);
      expect(service.isLoaded("u1"), isFalse);

      await service.startPlan("u1", "nt-90-days");
      await pumpEventQueue();

      expect(repos["u1"]!.writes, 0);

      // Später wieder erreichbar: Die alten Daten sind noch da.
      repos["u1"]!.failLoad = false;

      await service.confirmReading(uid: "u1", text: "Mk 5");
      await pumpEventQueue();

      expect(service.readingDayCount("u1"), 2);
      expect((repos["u1"]!.data["log_2026"]!["days"] as Map).keys, {
        "2026-09-01",
        "2026-09-28",
      });
    });

    test("defekte gespeicherte Daten werden übergangen", () async {
      repos["u1"] = MemoryReadingRepository()
        ..data.addAll({
          "log_2026": {
            "days": {
              "2026-09-27": [
                {"id": "free:a", "text": "A"},
                {"id": "free:a", "text": "A"},
                "Unsinn",
                {"text": "ohne id"},
              ],
              "2026-09-26": "kaputt",
            },
          },
          "plan_gospels-30-days": {
            "planId": "gospels-30-days",
            "startedOn": "2026-09-01",
            "done": {
              "1": [0, 0, 99, -1, "x"],
              "x": [0],
              "500": [0],
            },
          },
          "plan_kaputt": {"done": 5},
          "custom_kaputt": {"json": "{"},
        });

      await service.load("u1");

      final plan = service.plan("gospels-30-days")!;
      final progress = service.progressOf("u1", plan.id)!;

      expect(service.entriesOn("u1", "2026-09-27"), hasLength(1));
      expect(service.readingDayCount("u1"), 1);
      expect(progress.doneReadings(plan), 1);
      expect(progress.currentDay(plan), 2);
      expect(service.plans.length, 6);
    });

    test("eigenen Plan importieren, nutzen, neu laden und löschen", () async {
      const source =
          '{"id": "mein-plan", "name": "Mein Plan", '
          '"days": [["MRK 1-2", "PSA 1"], ["JOL"]]}';

      final plan = await service.importPlan("u1", source);

      expect(plan.builtIn, isFalse);
      expect(service.plans.length, 7);

      await service.startPlan("u1", "mein-plan");
      await mark(1, 1, plan: "mein-plan");

      await restart();

      final loaded = service.plan("mein-plan")!;

      expect(loaded.name, "Mein Plan");
      expect(loaded.readingsOn(2).single.wholeBook, isTrue);
      expect(service.progressOf("u1", "mein-plan")!.isDone(1, 1), isTrue);

      // Export im selben Format.
      expect(jsonDecode(ReadingPlanCodec.encode(loaded))["days"], [
        ["MRK 1-2", "PSA 1"],
        ["JOL"],
      ]);

      await service.deletePlan("u1", "mein-plan");
      await restart();

      expect(service.plan("mein-plan"), isNull);
      expect(service.progressOf("u1", "mein-plan"), isNull);
      expect(repos["u1"]!.data.keys, {"log_2026"});
    });

    test("derselbe Plan wird nicht doppelt importiert", () async {
      const source =
          '{"id": "mein-plan", "name": "Mein Plan", '
          '"days": [["MRK 1"]]}';

      await service.importPlan("u1", source);
      await pumpEventQueue();

      final writes = repos["u1"]!.writes;

      await expectLater(
        service.importPlan("u1", source),
        throwsA(
          isA<ReadingPlanFormatException>().having(
            (e) => e.problems.single,
            "Meldung",
            contains("bereits vorhanden"),
          ),
        ),
      );

      // Auch nicht unter der Kennung eines integrierten Plans.
      await expectLater(
        service.importPlan(
          "u1",
          '{"id": "bible-1-year", "name": "Kopie", "days": [["GEN 1"]]}',
        ),
        throwsA(isA<ReadingPlanFormatException>()),
      );

      await pumpEventQueue();

      expect(service.plans.length, 7);
      expect(repos["u1"]!.writes, writes);
    });

    test("ungültiger Plan wird nicht gespeichert", () async {
      await expectLater(
        service.importPlan(
          "u1",
          '{"id": "falsch", "name": "Falsch", "days": [["GEN 51"]]}',
        ),
        throwsA(isA<ReadingPlanFormatException>()),
      );

      await service.load("u1");
      await pumpEventQueue();

      expect(service.plan("falsch"), isNull);
      expect(repos["u1"]!.writes, 0);
    });

    test("integrierte Pläne lassen sich nicht löschen", () async {
      await service.startPlan("u1", "nt-90-days");
      await service.deletePlan("u1", "nt-90-days");

      expect(service.plan("nt-90-days"), isNotNull);
      expect(service.progressOf("u1", "nt-90-days"), isNotNull);
    });
  });

  // ==========================
  // SPEICHERFORMATE
  // ==========================

  group("Speicher", () {
    test("Gast: lokal und dauerhaft, tageweise zusammengeführt", () async {
      SharedPreferences.setMockInitialValues({});

      final repository = LocalBibleReadingRepository();

      await repository.save("log_2026", {
        "days": {
          "2026-09-28": [
            {"id": "free:a", "text": "A"},
          ],
        },
      }, merge: true);

      await repository.save("log_2026", {
        "days": {
          "2026-09-29": [
            {"id": "free:b", "text": "B"},
          ],
        },
      }, merge: true);

      await repository.save("plan_x", {"planId": "x", "paused": true});
      await repository.save("plan_x", {"planId": "x"});
      await repository.save("plan_y", {"planId": "y"});
      await repository.delete("plan_y");

      final loaded = await LocalBibleReadingRepository().loadAll();

      expect(loaded.keys, {"log_2026", "plan_x"});
      expect((loaded["log_2026"]!["days"] as Map).keys, {
        "2026-09-28",
        "2026-09-29",
      });
      expect(loaded["plan_x"], {"planId": "x"}, reason: "ohne merge ersetzt");

      // Bestehende Gastdaten anderer Bereiche bleiben unberührt.
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getKeys(), {LocalBibleReadingRepository.storageKey});
    });

    test("Gast: defekte lokale Daten ergeben einen leeren Stand", () async {
      SharedPreferences.setMockInitialValues({
        LocalBibleReadingRepository.storageKey: "{kaputt",
      });

      expect(await LocalBibleReadingRepository().loadAll(), isEmpty);
    });

    test("Fortschritt und Einträge überstehen das Speicherformat", () {
      final progress = const ReadingPlanProgress(
        planId: "p",
        startedOn: "2026-09-28",
        paused: true,
      ).withReading(2, 1, true).withReading(2, 0, true).withReading(7, 0, true);

      final copy = ReadingPlanProgress.fromMap(
        jsonDecode(jsonEncode(progress.toMap())) as Map,
      )!;

      expect(copy.toMap(), progress.toMap());
      expect(copy.paused, isTrue);
      expect(copy.done, {
        2: {0, 1},
        7: {0},
      });
      expect(progress.withReading(7, 0, false).done.keys, [2]);

      final entry = BibleReadingEntry.plan(
        planId: "p",
        day: 2,
        reading: 1,
        text: "Mk 4",
      );

      final entryCopy = BibleReadingEntry.fromMap(
        jsonDecode(jsonEncode(entry.toMap())),
      )!;

      expect(entryCopy.id, "plan:p:2:1");
      expect(entryCopy.fromPlan, isTrue);
      expect(BibleReadingEntry.free(" Mk  4 ").id, "free:mk 4");
      expect(BibleReadingEntry.free("x" * 500).text.length, 120);
    });
  });
}
