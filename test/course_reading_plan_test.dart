import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/models/bible/course_reading_plan.dart';
import 'package:theologie_lernapp/models/bible/reading_plan.dart';
import 'package:theologie_lernapp/screens/bible/course_reading_plan_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/lecture_materials/lecture_materials.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/course_reading_schedule.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';

import 'test_asset_bundle.dart';
import 'lecture_materials_test_support.dart';

const String planId = "course-bibelkunde-at-wise-2026";
const String planFile = "assets/reading_plans/$planId.json";

/// Speicher im Arbeitsspeicher, simuliert Firestore.
class MemoryReadingRepository implements BibleReadingRepository {
  final Map<String, Map<String, dynamic>> data = {};

  @override
  Future<Map<String, Map<String, dynamic>>> loadAll() async {
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
    final existing = this.data[id];

    this.data[id] = merge && existing != null ? {...existing, ...data} : data;
  }

  @override
  Future<void> delete(String id) async => data.remove(id);
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

/// Echte Assets, aber eine Plandatei lässt sich ersetzen (neue Folien).
class PatchedBundle extends FileAssetBundle {
  final Map<String, String> replaced;

  PatchedBundle(this.replaced);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return replaced[key] ?? super.loadString(key, cache: cache);
  }
}

/// Feste Kapitel- und Verszahlen für übersichtliche Rechnungen.
class FakeExtent implements BibleExtent {
  /// Buch → Verse je Kapitel.
  final Map<String, List<int>> books;

  const FakeExtent(this.books);

  @override
  int? chapterCount(String bookId) => books[bookId]?.length;

  @override
  int verseCount(String bookId, int chapter) {
    final verses = books[bookId];

    if (verses == null || chapter < 1 || chapter > verses.length) return 0;

    return verses[chapter - 1];
  }
}

CourseSession session(
  String id,
  DateTime date,
  List<String> readings, {
  int? number,
}) {
  return CourseSession(
    id: id,
    number: number ?? int.parse(id.split(".").last),
    date: date,
    topic: id,
    readings: [for (final r in readings) PlanReading.parse(r)!],
    readingSource: readings.isEmpty
        ? CourseReadingSource.none
        : CourseReadingSource.slides,
  );
}

void main() {
  // Echte Inhalte: geschützte Vorlesungsunterlagen, nicht im Repository.
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials("Leseplan zur Übung Bibelkunde AT");
    return;
  }

  // Der Leseplan kommt aus den freigegebenen Vorlesungsunterlagen.
  setUp(() => useLectureMaterials(directoryLectureMaterialsSource()));

  TestWidgetsFlutterBinding.ensureInitialized();

  final bundle = FileAssetBundle();

  late List<BibleTranslation> translations;
  late TranslationExtent extent;
  late CourseReadingPlan plan;

  setUpAll(() async {
    translations = await AssetBibleTextSource(
      bundle: bundle,
    ).loadTranslations();

    extent = TranslationExtent(translations);

    plan = CourseReadingPlan.fromJson(
      jsonDecode(await bundle.loadString(planFile)),
    );
  });

  CourseSchedule compute(
    CourseReadingProgress progress,
    DateTime today, {
    CourseReadingPlan? with_,
    BibleExtent? using,
  }) {
    return CourseSchedule.compute(
      plan: with_ ?? plan,
      progress: progress,
      today: today,
      extent: using ?? extent,
    );
  }

  CourseReadingProgress started(
    String on, {
    bool finishEve = true,
    Map<String, String> done = const {},
  }) {
    return CourseReadingProgress(
      planId: planId,
      startedOn: on,
      finishEve: finishEve,
      done: done,
    );
  }

  // ==========================
  // DATEN DES PLANS
  // ==========================

  group("Plan zur Übung Bibelkunde AT", () {
    test("steht im Index und wird vom Dienst geladen", () async {
      // Erst nach der Freigabe der Vorlesungsunterlagen sichtbar.
      expect(LectureMaterials.instance.files(prefix: "reading_plans/"), [
        "reading_plans/$planId.json",
      ]);

      final service = BibleReadingService(
        repositoryFor: (_) => MemoryReadingRepository(),
        bundle: bundle,
        translations: () async => translations,
        streaks: StreakService(repositoryFor: (_) => MemoryStreakRepository()),
      );

      await service.load(null);

      expect(service.coursePlan(planId)?.sessions.length, 14);
      // Die übrigen Pläne bleiben unberührt.
      expect(service.plans.length, 6);
    });

    test("Termine und Themen entsprechen dem Seminarplan (Folie 5)", () {
      final unit = jsonDecode(
        File(
          lectureMaterialsFile(
            "assets/old_testament/units/bibelkunde-01.json",
          )!,
        ).readAsStringSync(),
      );

      final slide = (unit["slides"] as List).firstWhere(
        (s) => s["number"] == 5,
      );

      final rows = [
        for (final match in RegExp(
          r"^(\d{2})\.(\d{2})\.(\d{4}) – (.+)$",
          multiLine: true,
        ).allMatches(slide["text"] as String))
          (
            DateTime(
              int.parse(match.group(3)!),
              int.parse(match.group(2)!),
              int.parse(match.group(1)!),
            ),
            match.group(4)!,
          ),
      ];

      expect(rows.length, 14);

      expect([for (final s in plan.sessions) (s.date, s.topic)], rows);

      // Alle Sitzungen sind Donnerstage.
      for (final s in plan.sessions) {
        expect(s.date.weekday, DateTime.thursday, reason: s.id);
      }
    });

    test("Lesestellen der Sitzungen 2–4 nach Folie 7", () {
      List<String> keys(String id) => [
        for (final r in plan.session(id)!.readings) r.key,
      ];

      expect(plan.session("bk.01")!.readings, isEmpty);
      expect(keys("bk.02"), ["GEN"]);
      expect(keys("bk.03"), ["EXO 1-5", "EXO 7-24", "EXO 32-34", "LEV 16"]);
      expect(keys("bk.04"), [
        "NUM 6:22-26",
        "NUM 10:11-12",
        "NUM 10:33-36",
        "NUM 11-14",
        "NUM 20-25",
        "NUM 27:12-23",
        "DEU 1",
        "DEU 4-8",
        "DEU 12-18",
        "DEU 26",
        "DEU 30-34",
      ]);

      for (final id in ["bk.02", "bk.03", "bk.04"]) {
        expect(plan.session(id)!.readingSource, CourseReadingSource.slides);
      }

      // Später ist nur das Thema bekannt: als vorläufig gekennzeichnet.
      for (final s in plan.sessions.skip(4)) {
        expect(s.readingSource, CourseReadingSource.provisional, reason: s.id);
        expect(s.note, contains("vorläufig"), reason: s.id);
      }
    });

    test("jede Stelle lässt sich aufschlagen", () {
      for (final s in plan.sessions) {
        for (final r in s.readings) {
          expect(r.problemIn(translations), isNull, reason: "${s.id} $r");
        }
      }
    });

    test("kein Kapitel ist zweimal Pflicht", () {
      final schedule = compute(started("2026-10-22"), DateTime(2026, 10, 22));

      final keys = [
        for (final s in schedule.sessions)
          for (final p in s.required) p.key,
      ];

      expect(keys.toSet().length, keys.length);
      expect(schedule.sessions.every((s) => s.repeats.isEmpty), isTrue);
    });

    test("verweist auf die vorhandenen Sitzungen im Bereich AT", () {
      final course = jsonDecode(
        File(
          lectureMaterialsFile("assets/old_testament/course.json")!,
        ).readAsStringSync(),
      );

      final unitIds = {
        for (final file in course["units"] as List)
          jsonDecode(
            File(
              lectureMaterialsFile("assets/old_testament/$file")!,
            ).readAsStringSync(),
          )["id"],
      };

      for (final s in plan.sessions) {
        if (s.unitId != null) expect(unitIds, contains(s.unitId));
      }

      expect(plan.session("bk.02")!.unitId, "bk.02");
    });

    test("Zwischentests nach Folie 10", () {
      expect(
        [for (final m in plan.milestones) CourseDates.key(m.start)],
        ["2026-11-13", "2026-12-11", "2027-01-22", "2027-02-08"],
      );
    });

    test("ungültige Plandateien werden abgelehnt", () {
      Map<String, dynamic> base() =>
          jsonDecode(File(lectureMaterialsFile(planFile)!).readAsStringSync());

      expect(
        () => CourseReadingPlan.fromJson(base()..["format"] = "x"),
        throwsFormatException,
      );

      final duplicate = base();
      (duplicate["sessions"] as List)[1]["id"] = "bk.01";
      expect(
        () => CourseReadingPlan.fromJson(duplicate),
        throwsFormatException,
      );

      final badDate = base();
      (badDate["sessions"] as List)[1]["date"] = "2026-02-30";
      expect(() => CourseReadingPlan.fromJson(badDate), throwsFormatException);

      final noReadings = base();
      (noReadings["sessions"] as List)[1]["readings"] = [];
      expect(
        () => CourseReadingPlan.fromJson(noReadings),
        throwsFormatException,
      );
    });
  });

  // ==========================
  // LESESTÜCKE
  // ==========================

  group("Lesestücke", () {
    test("ganzes Buch → alle Kapitel", () {
      final pieces = CourseSchedule.pieces(PlanReading.parse("GEN")!, extent);

      expect(pieces.length, 50);
      expect(pieces.first.key, "GEN 1");
      expect(pieces.last.key, "GEN 50");
      expect(
        pieces.fold(0, (sum, p) => sum + CourseSchedule.versesOf(p, extent)),
        1533,
      );
    });

    test("Kapitel- und Versbereiche bleiben fein unterteilt", () {
      List<String> keys(String reading) => [
        for (final p in CourseSchedule.pieces(
          PlanReading.parse(reading)!,
          extent,
        ))
          p.key,
      ];

      expect(keys("EXO 1-5"), ["EXO 1", "EXO 2", "EXO 3", "EXO 4", "EXO 5"]);
      expect(keys("NUM 6:22-26"), ["NUM 6:22-26"]);
      expect(keys("NUM 10:11-12"), ["NUM 10:11-12"]);
      expect(
        CourseSchedule.versesOf(PlanReading.parse("NUM 6:22-26")!, extent),
        5,
      );
      // Versbereich über die Kapitelgrenze; ein ab Vers 1 vollständiges
      // Kapitel zählt als Kapitel.
      expect(keys("GEN 1:1-2:3"), ["GEN 1", "GEN 2:1-3"]);
    });

    test("ein gelesenes Kapitel deckt seine Versbereiche ab", () {
      final progress = started("2026-10-22", done: {"NUM 10": "2026-11-06"});

      expect(progress.isDone(PlanReading.parse("NUM 10:11-12")!), isTrue);
      expect(progress.isDone(PlanReading.parse("NUM 10:33-36")!), isTrue);
      expect(progress.isDone(PlanReading.parse("NUM 11")!), isFalse);

      // Ein Versbereich deckt das Kapitel nicht ab.
      final partial = started(
        "2026-10-22",
        done: {"NUM 6:22-26": "2026-11-06"},
      );

      expect(partial.isDone(PlanReading.parse("NUM 6")!), isFalse);
    });

    test("Kurzangabe fasst aufeinanderfolgende Kapitel zusammen", () {
      final pieces = [
        for (final k in ["GEN 1", "GEN 2", "GEN 3", "GEN 5", "NUM 6:22-26"])
          PlanReading.parse(k)!,
      ];

      expect(compactLabel(pieces), "Gen 1–3; Gen 5; Num 6,22–26");
    });
  });

  // ==========================
  // TERMINE UND VERTEILUNG
  // ==========================

  group("Termine und Verteilung", () {
    test("Genesis: ab heute (Fr, 23.10.) bis zum Vorabend Mi, 28.10.", () {
      final schedule = compute(started("2026-10-23"), DateTime(2026, 10, 23));

      final next = schedule.next!;

      expect(next.id, "bk.02");
      expect(next.date, DateTime(2026, 10, 29));
      expect(next.target, DateTime(2026, 10, 28));
      expect(next.daysLeft, 6);
      expect(next.required.length, 50);
      expect(next.pace, CoursePace.onTrack);

      // Alle 50 Kapitel genau einmal, verteilt auf Fr–Mi.
      final assigned = [
        for (final entry in next.days.entries)
          for (final p in entry.value) (entry.key, p.key),
      ];

      expect(assigned.length, 50);
      expect({for (final a in assigned) a.$2}.length, 50);
      expect(next.days.keys, [
        for (var d = 23; d <= 28; d++) DateTime(2026, 10, d),
      ]);

      // Gleichmäßig nach Versen: kein Tag weicht stark vom Schnitt ab.
      final average = 1533 / 6;

      for (final day in next.days.values) {
        final verses = day.fold(0, (sum, p) => sum + p.verses);

        expect(verses, inInclusiveRange(average * 0.75, average * 1.25));
      }

      // Reihenfolge des Buchs bleibt erhalten.
      expect(
        [for (final a in assigned) a.$2],
        [for (var c = 1; c <= 50; c++) "GEN $c"],
      );

      expect(schedule.todayPieces.first.key, "GEN 1");
      expect(next.minutesPerDay, lessThan(CourseSchedule.tightMinutes));
      expect(next.tight, isFalse);
    });

    test("ohne Vorabend endet der Zeitraum am Sitzungstag", () {
      final schedule = compute(
        started("2026-10-23", finishEve: false),
        DateTime(2026, 10, 23),
      );

      final next = schedule.next!;

      expect(next.target, DateTime(2026, 10, 29));
      expect(next.daysLeft, 7);
      expect(next.days.keys.last, DateTime(2026, 10, 29));
    });

    test("danach geht es lückenlos mit der nächsten Sitzung weiter", () {
      final schedule = compute(started("2026-10-23"), DateTime(2026, 10, 23));

      final exodus = schedule.session("bk.03")!;
      final numeri = schedule.session("bk.04")!;

      // Genesis bis Mi, 28.10.; Exodus/Levitikus ab Do, 29.10. bis Mi,
      // 04.11.; Numeri/Dtn ab Do, 05.11.
      expect(exodus.windowStart, DateTime(2026, 10, 29));
      expect(exodus.target, DateTime(2026, 11, 4));
      expect(exodus.pace, CoursePace.upcoming);
      expect(exodus.days.keys.first, DateTime(2026, 10, 29));
      expect(exodus.days.keys.last, DateTime(2026, 11, 4));
      expect(exodus.required.length, 27);

      expect(numeri.windowStart, DateTime(2026, 11, 5));
      expect(numeri.target, DateTime(2026, 11, 11));

      // Keine Überschneidung der Zeiträume.
      for (var i = 1; i < schedule.sessions.length; i++) {
        final before = schedule.sessions[i - 1];
        final s = schedule.sessions[i];

        expect(
          s.windowStart,
          CourseDates.addDays(before.target, 1),
          reason: s.id,
        );
      }
    });

    test("Weihnachtspause: Sitzung 10 hat drei Wochen", () {
      final schedule = compute(started("2026-10-22"), DateTime(2026, 12, 17));

      final s10 = schedule.session("bk.10")!;

      expect(s10.windowStart, DateTime(2026, 12, 17));
      expect(s10.target, DateTime(2027, 1, 6));
      expect(CourseDates.daysBetweenInclusive(s10.windowStart, s10.target), 21);
    });

    test("am Sitzungstag ist der Sitzungstag spätester Termin", () {
      final schedule = compute(started("2026-10-23"), DateTime(2026, 10, 29));

      final genesis = schedule.session("bk.02")!;

      // Vorabend vorbei: alles Offene steht auf dem Sitzungstag.
      expect(genesis.target, DateTime(2026, 10, 29));
      expect(genesis.daysLeft, 1);
      expect(genesis.days.keys, [DateTime(2026, 10, 29)]);
      expect(genesis.pace, CoursePace.behind);
      expect(schedule.next!.id, "bk.02");
      expect(schedule.overdue, isEmpty);
    });

    test("nach der Sitzung: Offenes wird nachgeholt, nicht verteilt", () {
      final schedule = compute(
        started("2026-10-23", done: {"GEN 1": "2026-10-23"}),
        DateTime(2026, 10, 30),
      );

      final genesis = schedule.session("bk.02")!;

      expect(genesis.pace, CoursePace.missed);
      expect(genesis.days, isEmpty);
      expect(schedule.overdue.length, 49);
      expect(schedule.next!.id, "bk.03");
      // Das heutige Pensum gehört zur nächsten Sitzung.
      expect(schedule.todayPieces.every((p) => p.sessionId == "bk.03"), isTrue);
    });

    test(
      "verbleibende Tage zählen Kalendertage, auch über die Zeitumstellung",
      () {
        // 25.10.2026: Ende der Sommerzeit.
        expect(
          CourseDates.daysBetweenInclusive(
            DateTime(2026, 10, 23),
            DateTime(2026, 10, 28),
          ),
          6,
        );
        expect(
          CourseDates.addDays(DateTime(2026, 10, 24), 2),
          DateTime(2026, 10, 26),
        );
        expect(
          CourseDates.daysBetweenInclusive(
            DateTime(2026, 10, 28),
            DateTime(2026, 10, 23),
          ),
          0,
        );
      },
    );

    test(
      "zu kurzer Zeitraum: alles auf einen Tag, deutlich gekennzeichnet",
      () {
        final schedule = compute(started("2026-10-28"), DateTime(2026, 10, 28));

        final genesis = schedule.next!;

        expect(genesis.daysLeft, 1);
        expect(genesis.days.keys, [DateTime(2026, 10, 28)]);
        expect(genesis.days.values.single.length, 50);
        expect(genesis.versesPerDay, 1533);
        expect(genesis.tight, isTrue);
        expect(genesis.veryTight, isTrue);
      },
    );

    test("Rückstand: weniger gelesen als bis gestern vorgesehen", () {
      final behind = compute(started("2026-10-22"), DateTime(2026, 10, 25));

      expect(behind.next!.pace, CoursePace.behind);
      // Das Offene wird auf die übrigen Tage neu verteilt.
      expect(behind.next!.days.keys.first, DateTime(2026, 10, 25));
      expect(behind.next!.days.keys.last, DateTime(2026, 10, 28));

      final onTrack = compute(
        started(
          "2026-10-22",
          done: {for (var c = 1; c <= 25; c++) "GEN $c": "2026-10-24"},
        ),
        DateTime(2026, 10, 25),
      );

      expect(onTrack.next!.pace, CoursePace.onTrack);
      expect(onTrack.next!.days.values.expand((d) => d).first.key, "GEN 26");
    });

    test("das heutige Pensum bleibt beim Abhaken stehen", () {
      final today = DateTime(2026, 10, 23);
      final before = compute(started("2026-10-23"), today);
      final keys = [for (final p in before.todayPieces) p.key];

      final progress = started(
        "2026-10-23",
      ).withPieces([before.todayPieces.first.piece], true, "2026-10-23");

      final after = compute(progress, today);

      expect([for (final p in after.todayPieces) p.key], keys);
      expect(after.todayPieces.first.done, isTrue);

      // Am nächsten Tag wird nur das Offene verteilt.
      final tomorrow = compute(progress, DateTime(2026, 10, 24));

      expect(
        tomorrow.next!.days.values.expand((d) => d).map((p) => p.key),
        isNot(contains(keys.first)),
      );
      expect(tomorrow.next!.daysLeft, 5);
    });

    test("alles gelesen: nichts mehr eingeplant", () {
      final schedule = compute(
        started(
          "2026-10-23",
          done: {for (var c = 1; c <= 50; c++) "GEN $c": "2026-10-22"},
        ),
        DateTime(2026, 10, 24),
      );

      expect(schedule.session("bk.02")!.pace, CoursePace.done);
      expect(schedule.session("bk.02")!.days, isEmpty);
      // Nächste Sitzung mit Lektüre bleibt Genesis (noch nicht vorbei),
      // vorgelesen wird Exodus.
      expect(schedule.after(schedule.next!)!.id, "bk.03");
    });

    test("Verteilung nach Gewicht ist lückenlos und geordnet", () {
      final days = CourseSchedule.distribute([10, 10, 10, 10, 40], 4);

      expect(days, [0, 0, 1, 1, 3]);
      expect(CourseSchedule.distribute([5, 5], 1), [0, 0]);
      expect(CourseSchedule.distribute([0, 0, 0], 3), [0, 1, 2]);

      for (final d in CourseSchedule.distribute(
        List.generate(150, (i) => 10 + i % 7),
        7,
      )) {
        expect(d, inInclusiveRange(0, 6));
      }
    });
  });

  // ==========================
  // WIEDERHOLUNGEN UND ÄNDERUNGEN
  // ==========================

  group("Wiederholungen und eigene Änderungen", () {
    const small = FakeExtent({
      "GEN": [30, 30, 30, 30],
      "EXO": [20, 20],
    });

    CourseReadingPlan twoSessions() => CourseReadingPlan(
      id: "t",
      name: "Test",
      course: "Kurs",
      source: "Test",
      sessions: [
        session("s.1", DateTime(2026, 11, 5), ["GEN 1-3"]),
        session("s.2", DateTime(2026, 11, 12), ["GEN 3-4", "EXO"]),
      ],
    );

    test("ein Text zweier Sitzungen ist nur einmal Pflicht", () {
      final schedule = compute(
        CourseReadingProgress(planId: "t", startedOn: "2026-11-01"),
        DateTime(2026, 11, 1),
        with_: twoSessions(),
        using: small,
      );

      final second = schedule.session("s.2")!;

      expect(
        [for (final p in second.required) p.key],
        ["GEN 4", "EXO 1", "EXO 2"],
      );
      expect([for (final p in second.repeats) p.key], ["GEN 3"]);
      expect(second.repeats.single.firstSessionId, "s.1");
      // Wiederholungen zählen nicht zum Umfang der zweiten Sitzung.
      expect(second.totalVerses, 70);
    });

    test("bereits Gelesenes wird nicht erneut eingeplant", () {
      final schedule = compute(
        CourseReadingProgress(
          planId: "t",
          startedOn: "2026-11-01",
          done: {"GEN 1": "2026-10-20", "GEN 2": "2026-10-20"},
        ),
        DateTime(2026, 11, 1),
        with_: twoSessions(),
        using: small,
      );

      final first = schedule.session("s.1")!;

      expect(first.days.values.expand((d) => d).map((p) => p.key), ["GEN 3"]);
      expect(first.doneVerses, 60);
    });

    test("Wiederholung lässt sich getrennt abhaken", () {
      final progress = CourseReadingProgress(
        planId: "t",
        startedOn: "2026-11-01",
        done: {"GEN 3": "2026-11-02"},
      ).withReview(PlanReading.parse("GEN 3")!, true, "2026-11-10");

      final schedule = compute(
        progress,
        DateTime(2026, 11, 10),
        with_: twoSessions(),
        using: small,
      );

      final repeat = schedule.session("s.2")!.repeats.single;

      expect(repeat.done, isTrue);
      expect(repeat.reviewed, isTrue);
    });

    test("eigener Termin verschiebt nur das Offene", () {
      final plan = twoSessions();

      final progress =
          CourseReadingProgress(
            planId: "t",
            startedOn: "2026-11-01",
            done: {"GEN 1": "2026-11-01"},
          ).withOverride(
            "s.1",
            CourseSessionOverride(
              basedOn: plan.sessions.first.fingerprint,
              date: DateTime(2026, 11, 3),
            ),
          );

      final schedule = compute(
        progress,
        DateTime(2026, 11, 2),
        with_: plan,
        using: small,
      );

      final first = schedule.session("s.1")!;

      expect(first.dateChanged, isTrue);
      expect(first.recommended.date, DateTime(2026, 11, 5));
      expect(first.target, DateTime(2026, 11, 2));
      expect(first.daysLeft, 1);
      expect(first.doneVerses, 30);
      expect(first.days.values.single.map((p) => p.key), ["GEN 2", "GEN 3"]);
      expect(first.recommendationChanged, isFalse);
    });

    test("eigener Termin sortiert die Sitzungen neu", () {
      final plan = twoSessions();

      final progress =
          CourseReadingProgress(
            planId: "t",
            startedOn: "2026-11-01",
          ).withOverride(
            "s.2",
            CourseSessionOverride(
              basedOn: plan.sessions[1].fingerprint,
              date: DateTime(2026, 11, 4),
            ),
          );

      final schedule = compute(
        progress,
        DateTime(2026, 11, 1),
        with_: plan,
        using: small,
      );

      expect([for (final s in schedule.sessions) s.id], ["s.2", "s.1"]);
      // Jetzt ist GEN 3 Pflicht für s.2 und Wiederholung für s.1.
      expect(schedule.session("s.1")!.repeats.single.key, "GEN 3");
    });

    test("geänderte Empfehlung überschreibt eigene Änderung nicht", () {
      final old = twoSessions();

      final progress =
          CourseReadingProgress(
            planId: "t",
            startedOn: "2026-11-01",
          ).withOverride(
            "s.2",
            CourseSessionOverride(
              basedOn: old.sessions[1].fingerprint,
              readings: [PlanReading.parse("EXO 1")!],
            ),
          );

      // Neue Folien: s.2 hat jetzt andere Stellen.
      final updated = CourseReadingPlan(
        id: "t",
        name: "Test",
        course: "Kurs",
        source: "Test",
        sessions: [
          old.sessions[0],
          session("s.2", DateTime(2026, 11, 12), ["EXO 2"]),
        ],
      );

      final schedule = compute(
        progress,
        DateTime(2026, 11, 1),
        with_: updated,
        using: small,
      );

      final second = schedule.session("s.2")!;

      expect(second.recommendationChanged, isTrue);
      expect([for (final p in second.required) p.key], ["EXO 1"]);
      expect([for (final r in second.recommended.readings) r.key], ["EXO 2"]);
    });

    test("Speichern und Laden verlieren nichts", () {
      final progress =
          CourseReadingProgress(
            planId: planId,
            startedOn: "2026-10-23",
            finishEve: false,
            done: {"GEN 1": "2026-10-23", "NUM 6:22-26": "2026-11-06"},
            reviewed: {"GEN 3": "2026-11-01"},
          ).withOverride(
            "bk.05",
            CourseSessionOverride(
              basedOn: "x",
              date: DateTime(2026, 11, 20),
              readings: [PlanReading.parse("JOS 1-12")!],
            ),
          );

      final restored = CourseReadingProgress.fromMap(
        jsonDecode(jsonEncode(progress.toMap())),
      )!;

      expect(restored.toMap(), progress.toMap());

      // Ungültige Einträge werden übergangen, der Rest bleibt.
      final damaged = CourseReadingProgress.fromMap({
        "planId": planId,
        "startedOn": "kaputt",
        "done": {"GEN 1": "2026-10-23", "???": "2026-10-23", "GEN 2": 5},
        "overrides": {"bk.05": "kaputt"},
      })!;

      expect(damaged.done, {"GEN 1": "2026-10-23"});
      expect(damaged.overrides, isEmpty);
      expect(damaged.finishEve, isTrue);
      expect(CourseReadingProgress.fromMap({"planId": 3}), isNull);
    });

    test("Bearbeiten: angezeigte Stellen lassen sich wieder einlesen", () {
      for (final s in plan.sessions) {
        final text = [for (final r in s.readings) editText(r)].join("; ");

        final parsed = parseReadings(text, extent);

        expect(parsed.problems, isEmpty, reason: text);
        expect(
          [for (final r in parsed.readings) r.key],
          [for (final r in s.readings) r.key],
          reason: text,
        );
      }

      final wrong = parseReadings("Gen 51; Quatsch 3; Num 6,99", extent);

      expect(wrong.readings, isEmpty);
      expect(wrong.problems.length, 3);
    });
  });

  // ==========================
  // DIENST: SPEICHERUNG, STREAK, ANPASSUNG
  // ==========================

  group("Umfang: ganze Bücher", () {
    const small = FakeExtent({
      "GEN": [10, 10, 10, 10, 10],
      "EXO": [20, 20, 20, 20],
      "LEV": [5, 5, 5],
    });

    CourseReadingPlan sessions() => CourseReadingPlan(
      id: "t",
      name: "Test",
      course: "Kurs",
      source: "Test",
      sessions: [
        session("s.1", DateTime(2026, 11, 5), ["GEN 2", "GEN 4:3-5"]),
        session("s.2", DateTime(2026, 11, 12), ["EXO 1", "GEN 5", "LEV 2"]),
        session("s.3", DateTime(2026, 11, 19), ["EXO 3"]),
      ],
    );

    CourseReadingProgress progress({
      bool whole = true,
      Map<String, String> done = const {},
      String since = "2026-11-01",
    }) {
      final base = CourseReadingProgress(
        planId: "t",
        startedOn: "2026-11-01",
        done: done,
      );

      return whole ? base.withWholeBooks(true, since) : base;
    }

    CourseSchedule plan(CourseReadingProgress progress, {DateTime? today}) =>
        compute(
          progress,
          today ?? DateTime(2026, 11, 1),
          with_: sessions(),
          using: small,
        );

    List<String> keys(SessionSchedule s) => [for (final p in s.required) p.key];

    test("Modus A: nur die benötigten Kapitel (wie bisher)", () {
      final schedule = plan(progress(whole: false));

      expect(keys(schedule.session("s.1")!), ["GEN 2", "GEN 4:3-5"]);
      expect(schedule.extraCount, 0);
    });

    test("Modus B: alle Kapitel, Reihenfolge erhalten, nichts doppelt", () {
      final schedule = plan(progress());

      // GEN 5 nennt Sitzung 2 selbst: Es bleibt dort und wird nicht
      // vorgezogen. Aus Gen 4,3-5 wird das ganze Kapitel.
      expect(keys(schedule.session("s.1")!), [
        "GEN 1",
        "GEN 2",
        "GEN 3",
        "GEN 4",
      ]);
      expect(
        [for (final p in schedule.session("s.1")!.extras) p.key],
        ["GEN 1", "GEN 3"],
      );

      // Exodus und Levitikus vollständig; EXO 3 bleibt bei Sitzung 3.
      expect(keys(schedule.session("s.2")!), [
        "EXO 1",
        "EXO 2",
        "EXO 4",
        "GEN 5",
        "LEV 1",
        "LEV 2",
        "LEV 3",
      ]);
      expect(keys(schedule.session("s.3")!), ["EXO 3"]);

      // Jedes Kapitel genau einmal Pflicht, keine Wiederholungen erzeugt.
      final all = [
        for (final s in schedule.sessions)
          for (final p in s.required) p.key,
      ];
      expect(all.toSet().length, all.length);
      expect(all.toSet(), {
        for (final book in ["GEN", "EXO", "LEV"])
          for (var c = 1; c <= small.chapterCount(book)!; c++) "$book $c",
      });
      expect(schedule.sessions.every((s) => s.repeats.isEmpty), isTrue);
    });

    test("verteilt die zusätzlichen Kapitel gleichmäßig auf die Tage", () {
      final first = plan(progress()).session("s.1")!;

      // 1.11. bis Vorabend 4.11.: vier Tage, je ein Kapitel zu 10 Versen.
      expect(first.daysLeft, 4);
      expect(
        [
          for (final day in first.days.values) [for (final p in day) p.key],
        ],
        [
          ["GEN 1"],
          ["GEN 2"],
          ["GEN 3"],
          ["GEN 4"],
        ],
      );
      expect(first.versesPerDay, 10);
    });

    test("Umschalten verliert keinen Fortschritt", () {
      final done = {"GEN 1": "2026-11-01", "GEN 4:3-5": "2026-11-01"};

      final whole = plan(progress(done: done));
      final s1 = whole.session("s.1")!;

      // Das ganze Kapitel 4 ist noch offen, Gen 1 gelesen.
      expect(
        [
          for (final p in s1.required)
            if (p.done) p.key,
        ],
        ["GEN 1"],
      );

      // Zurück zu Modus A: Der gelesene Versbereich zählt wieder.
      final back = progress(done: done).withWholeBooks(false, "2026-11-02");
      final s1Back = plan(back).session("s.1")!;

      expect(back.done, done);
      expect(
        [
          for (final p in s1Back.required)
            if (p.done) p.key,
        ],
        ["GEN 4:3-5"],
      );
      expect(back.wholeBooksSince, isNull);
    });

    test("manuell geänderte Sitzung: ergänzt ohne Dubletten, "
        "zurück bleibt die eigene Fassung", () {
      final original = sessions().sessions.first;
      // Eigene Fassung von Sitzung 1: Gen 3 dazu, Gen 2 doppelt genannt.
      final edited = CourseSessionOverride(
        basedOn: original.fingerprint,
        readings: [
          for (final r in ["GEN 2", "GEN 3", "GEN 2", "GEN 4:3-5"])
            PlanReading.parse(r)!,
        ],
      );

      final whole = plan(progress().withOverride("s.1", edited));

      expect(keys(whole.session("s.1")!), ["GEN 1", "GEN 2", "GEN 3", "GEN 4"]);
      // GEN 3 ist eigene Stelle, kein „zusätzliches“ Kapitel mehr.
      expect([for (final p in whole.session("s.1")!.extras) p.key], ["GEN 1"]);

      final all = [
        for (final s in whole.sessions)
          for (final p in s.required) p.key,
      ];
      expect(all.toSet().length, all.length);

      // Zurück zu „Nur vorgesehene Kapitel“: die eigene Fassung gilt
      // weiter, der Kursplan selbst bleibt unverändert.
      final back = progress(whole: false).withOverride("s.1", edited);
      expect(keys(plan(back).session("s.1")!).toSet(), {
        "GEN 2",
        "GEN 3",
        "GEN 4:3-5",
      });
      expect(
        [for (final r in sessions().sessions.first.readings) r.key],
        ["GEN 2", "GEN 4:3-5"],
      );

      // Override zurückgenommen: wieder die Empfehlung des Kurses.
      final reset = back.withOverride("s.1", null);
      expect(keys(plan(reset).session("s.1")!), ["GEN 2", "GEN 4:3-5"]);
    });

    test("Sitzungen vor dem Einschalten werden nicht erweitert", () {
      final schedule = plan(
        progress(since: "2026-11-06"),
        today: DateTime(2026, 11, 6),
      );

      expect(keys(schedule.session("s.1")!), ["GEN 2", "GEN 4:3-5"]);
      expect(schedule.session("s.2")!.extras, isNotEmpty);
      // Kein Kapitel der vergangenen Sitzung kommt als „Nachholen“ dazu.
      expect(schedule.overdue.map((p) => p.key), ["GEN 2", "GEN 4:3-5"]);
    });

    test("Speichern und Laden behalten Einstellung, Datum und Pause", () {
      final saved = progress().copyWith(paused: true);
      final restored = CourseReadingProgress.fromMap(saved.toMap())!;

      expect(restored.wholeBooks, isTrue);
      expect(restored.wholeBooksSince, "2026-11-01");
      expect(restored.paused, isTrue);

      // Ältere Daten ohne die Felder: Modus A, nicht pausiert.
      final old = CourseReadingProgress.fromMap({
        "planId": "t",
        "startedOn": "2026-11-01",
      })!;

      expect(old.wholeBooks, isFalse);
      expect(old.paused, isFalse);
    });

    test("echter Plan: Exodus und Levitikus vollständig in Sitzung 3", () {
      final schedule = compute(
        CourseReadingProgress(
          planId: planId,
          startedOn: "2026-10-30",
        ).withWholeBooks(true, "2026-10-30"),
        DateTime(2026, 10, 30),
      );

      final s3 = schedule.session("bk.03")!;

      expect(
        [for (final p in s3.required) p.key],
        [
          for (var c = 1; c <= 40; c++) "EXO $c",
          for (var c = 1; c <= 27; c++) "LEV $c",
        ],
      );
      // Eigene Stellen: Ex 1–5, 7–24, 32–34 (26 Kapitel) und Lev 16.
      expect(s3.extras.length, 40 + 27 - 26 - 1);

      final s4 = schedule.session("bk.04")!;

      expect(s4.required.first.key, "NUM 1");
      expect(s4.required.last.key, "DEU 34");
      // Nur ganze Kapitel, keine Versbereiche mehr.
      expect(s4.required.every((p) => p.piece.verse == null), isTrue);
    });
  });

  group("Dienst", () {
    late DateTime now;
    late MemoryReadingRepository repository;
    late MemoryStreakRepository streakRepository;
    late StreakService streaks;

    BibleReadingService newService({BundleOverride? patched}) {
      streaks = StreakService(
        repositoryFor: (_) => streakRepository,
        clock: () => now,
      );

      return BibleReadingService(
        repositoryFor: (_) => repository,
        clock: () => now,
        streaks: streaks,
        bundle: patched?.bundle ?? bundle,
        translations: () async => translations,
      );
    }

    setUp(() {
      now = DateTime(2026, 10, 23, 18);
      repository = MemoryReadingRepository();
      streakRepository = MemoryStreakRepository();
    });

    test("starten, abhaken, Streak und Neustart", () async {
      var service = newService();

      await service.load("u1");
      await service.loadCourseExtent();

      expect(service.courseSchedule("u1", planId), isNull);

      await service.startCoursePlan("u1", planId);

      final schedule = service.courseSchedule("u1", planId)!;
      final today = schedule.todayPieces;

      expect(today, isNotEmpty);
      expect(schedule.next!.id, "bk.02");

      final result = await service.setCoursePieces(
        uid: "u1",
        planId: planId,
        pieces: [for (final p in today) p.piece],
        done: true,
      );

      expect(result!.logged, isTrue);
      expect(result.streak!.goalReachedNow, isTrue);
      expect(streaks.snapshotFor("u1", StreakTrack.bible).todaySources, {
        StreakSource.readingPlan: 1,
      });
      expect(
        service.entriesOn("u1", "2026-10-23").single.text,
        startsWith("Gen 1"),
      );

      // Ein zweiter Klick ändert nichts.
      expect(
        await service.setCoursePieces(
          uid: "u1",
          planId: planId,
          pieces: [today.first.piece],
          done: true,
        ),
        isNull,
      );

      await pumpEventQueue();

      service = newService();

      await service.load("u1");
      await service.loadCourseExtent();

      final restored = service.courseSchedule("u1", planId)!;

      expect(
        [for (final p in restored.todayPieces) p.key],
        [for (final p in today) p.key],
      );
      expect(restored.todayPieces.every((p) => p.done), isTrue);

      // Nächster Tag: Das Offene wird auf die übrigen fünf Tage verteilt.
      now = DateTime(2026, 10, 24, 8);

      final tomorrow = service.courseSchedule("u1", planId)!;

      expect(tomorrow.next!.daysLeft, 5);
      expect(tomorrow.next!.pace, CoursePace.onTrack);
    });

    test("Anpassungen behalten erledigte Lektüre", () async {
      final service = newService();

      await service.load("u1");
      await service.loadCourseExtent();
      await service.startCoursePlan("u1", planId);

      await service.setCoursePieces(
        uid: "u1",
        planId: planId,
        pieces: [PlanReading.parse("GEN 1")!, PlanReading.parse("GEN 2")!],
        done: true,
      );

      await service.setCourseOverride(
        "u1",
        planId,
        "bk.02",
        date: DateTime(2026, 10, 27),
      );

      var genesis = service.courseSchedule("u1", planId)!.session("bk.02")!;

      expect(genesis.dateChanged, isTrue);
      expect(genesis.target, DateTime(2026, 10, 26));
      expect(genesis.required.where((p) => p.done).length, 2);

      // Gleiche Angaben wie die Empfehlung sind keine Änderung.
      await service.setCourseOverride(
        "u1",
        planId,
        "bk.02",
        date: DateTime(2026, 10, 29),
        readings: [PlanReading.parse("GEN")!],
      );

      expect(service.courseProgressOf("u1", planId)!.overrides, isEmpty);

      await service.setCourseOverride(
        "u1",
        planId,
        "bk.02",
        readings: [PlanReading.parse("GEN 1-11")!],
      );

      genesis = service.courseSchedule("u1", planId)!.session("bk.02")!;

      expect(genesis.readingsChanged, isTrue);
      expect(genesis.required.length, 11);
      expect(genesis.doneVerses, greaterThan(0));

      await service.clearCourseOverride("u1", planId, "bk.02");

      genesis = service.courseSchedule("u1", planId)!.session("bk.02")!;

      expect(genesis.required.length, 50);
      expect(genesis.required.where((p) => p.done).length, 2);

      // Vorabend aus: Sitzungstag als Abschluss.
      await service.setCourseFinishEve("u1", planId, false);

      expect(
        service.courseSchedule("u1", planId)!.session("bk.02")!.target,
        DateTime(2026, 10, 29),
      );
      expect(repository.data["course_$planId"]!["finishEve"], isFalse);
    });

    test(
      "neue Folien: Empfehlung aktualisiert, Lektüre und Änderung bleiben",
      () async {
        var service = newService();

        await service.load("u1");
        await service.loadCourseExtent();
        await service.startCoursePlan("u1", planId);

        await service.setCoursePieces(
          uid: "u1",
          planId: planId,
          pieces: [PlanReading.parse("JOS 1")!, PlanReading.parse("RUT 1")!],
          done: true,
        );

        await service.setCourseOverride(
          "u1",
          planId,
          "bk.05",
          readings: [PlanReading.parse("JOS 1-6")!],
        );

        await pumpEventQueue();

        // Neue Folien mit den tatsächlichen Stellen für Sitzung 5 und einem
        // geänderten Termin für Sitzung 6.
        final json = jsonDecode(
          File(lectureMaterialsFile(planFile)!).readAsStringSync(),
        );
        final sessions = json["sessions"] as List;

        sessions[4]["readings"] = ["JOS 1-11", "JDG 2-8", "RUT"];
        sessions[4]["readingSource"] = "slides";
        sessions[5]["date"] = "2026-11-27";

        // Geänderte Plandatei in den freigegebenen Unterlagen.
        await useLectureMaterials(
          FakeLectureMaterialsSource({
            ...directoryLectureMaterialsSource().files,
            "reading_plans/$planId.json": utf8.encode(jsonEncode(json)),
          }),
        );

        service = newService(
          patched: BundleOverride({planFile: jsonEncode(json)}),
        );

        await service.load("u1");
        await service.loadCourseExtent();

        final schedule = service.courseSchedule("u1", planId)!;
        final s5 = schedule.session("bk.05")!;

        // Die eigene Änderung gilt weiter, der Hinweis ist sichtbar.
        expect(s5.recommendationChanged, isTrue);
        expect(s5.required.length, 6);
        expect(s5.required.first.done, isTrue);

        // Ohne eigene Änderung gilt der neue Termin sofort.
        expect(schedule.session("bk.06")!.date, DateTime(2026, 11, 27));

        final progress = service.courseProgressOf("u1", planId)!;

        expect(progress.done.keys, containsAll(["JOS 1", "RUT 1"]));

        // Behalten: Hinweis weg, Änderung bleibt.
        await service.keepCourseOverride("u1", planId, "bk.05");

        expect(
          service
              .courseSchedule("u1", planId)!
              .session("bk.05")!
              .recommendationChanged,
          isFalse,
        );

        // Übernehmen: neue Empfehlung, gelesene Kapitel bleiben gelesen.
        await service.clearCourseOverride("u1", planId, "bk.05");

        final adopted = service.courseSchedule("u1", planId)!.session("bk.05")!;

        expect(adopted.session.readingSource, CourseReadingSource.slides);
        expect(
          [for (final p in adopted.required.where((p) => p.done)) p.key],
          ["JOS 1", "RUT 1"],
        );
      },
    );

    test("ganze Bücher und Pause: umschaltbar, Fortschritt bleibt", () async {
      final service = newService();

      await service.load("u1");
      await service.loadCourseExtent();
      await service.startCoursePlan("u1", planId);

      await service.setCoursePieces(
        uid: "u1",
        planId: planId,
        pieces: [PlanReading.parse("GEN 1")!],
        done: true,
      );

      expect(service.courseSchedule("u1", planId)!.extraCount, 0);

      await service.setCourseWholeBooks("u1", planId, true);

      final whole = service.courseSchedule("u1", planId)!;

      expect(whole.extraCount, greaterThan(0));
      expect(repository.data["course_$planId"]!["wholeBooks"], isTrue);
      expect(
        repository.data["course_$planId"]!["wholeBooksSince"],
        "2026-10-23",
      );
      expect(service.courseProgressOf("u1", planId)!.done.keys, ["GEN 1"]);

      await service.setCourseWholeBooks("u1", planId, false);

      expect(service.courseSchedule("u1", planId)!.extraCount, 0);
      expect(service.courseProgressOf("u1", planId)!.done.keys, ["GEN 1"]);

      await service.setCoursePaused("u1", planId, true);

      expect(service.startedCoursePlans("u1").single.$2.paused, isTrue);
      expect(repository.data["course_$planId"]!["paused"], isTrue);
      expect(service.courseProgressOf("u1", planId)!.done.keys, ["GEN 1"]);
    });

    test("Beenden verwirft nur den Plan, nicht den Leseverlauf", () async {
      final service = newService();

      await service.load("u1");
      await service.startCoursePlan("u1", planId);
      await service.setCoursePieces(
        uid: "u1",
        planId: planId,
        pieces: [PlanReading.parse("GEN 1")!],
        done: true,
      );

      await service.endCoursePlan("u1", planId);

      expect(service.courseProgressOf("u1", planId), isNull);
      expect(repository.data.containsKey("course_$planId"), isFalse);
      expect(service.entriesOn("u1", "2026-10-23"), isNotEmpty);
    });

    test("Gäste und Konten sind getrennt", () async {
      final repositories = <String?, MemoryReadingRepository>{};

      final service = BibleReadingService(
        repositoryFor: (uid) =>
            repositories.putIfAbsent(uid, MemoryReadingRepository.new),
        clock: () => now,
        streaks: StreakService(repositoryFor: (_) => MemoryStreakRepository()),
        bundle: bundle,
        translations: () async => translations,
      );

      await service.startCoursePlan("u1", planId);

      expect(service.courseProgressOf("u1", planId), isNotNull);

      await service.load(null);

      expect(service.courseProgressOf(null, planId), isNull);
      expect(repositories[null]!.data, isEmpty);
    });
  });
}

/// Ersetzt einzelne Asset-Dateien (z. B. eine aktualisierte Plandatei).
class BundleOverride {
  final PatchedBundle bundle;

  BundleOverride(Map<String, String> files) : bundle = PatchedBundle(files);
}
