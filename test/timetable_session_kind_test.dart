import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/course_snapshot.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/services/timetable/plan_conflicts.dart';
import 'package:theologie_lernapp/services/timetable/plan_schedule.dart';
import 'package:theologie_lernapp/services/timetable/timetable_schedule.dart';
import 'package:theologie_lernapp/services/timetable/timetable_export.dart';
import 'package:theologie_lernapp/services/timetable/timetable_pdf.dart';
import 'package:theologie_lernapp/services/timetable/week_layout.dart';

import 'timetable_export_test.dart' as t;

// Einordnung der Termine (wöchentlich, alle n Wochen, wiederkehrend ohne
// Rhythmus, Wochen unbekannt, Block, Einzeltermin) über den echten Weg:
// gespeicherter Import → resolvePlanCourse → Filter, Wochenraster, PDF.
// Synthetische Veranstaltungen, keine echten Daten.

const semester = t.semester;

/// Montage der Vorlesungszeit (ohne Jahreswechselpause).
const mondays = [
  "2026-10-12",
  "2026-10-19",
  "2026-10-26",
  "2026-11-02",
  "2026-11-09",
  "2026-11-16",
  "2026-11-23",
  "2026-11-30",
  "2026-12-07",
  "2026-12-14",
  "2027-01-04",
  "2027-01-11",
  "2027-01-18",
  "2027-01-25",
  "2027-02-01",
  "2027-02-08",
];

SessionRule weeklyRule(String id, {int interval = 1, int weekday = 1}) =>
    SessionRule(
      id: id,
      kind: RepeatKind.weekly,
      intervalWeeks: interval,
      weekdays: [weekday],
      startTime: "10:00",
      endTime: "12:00",
    );

SessionRule singleRule(String id, String date, {String start = "10:00"}) =>
    SessionRule(
      id: id,
      kind: RepeatKind.single,
      startDate: date,
      endDate: date,
      startTime: start,
      endTime: "12:00",
    );

SnapshotOccurrence at(String rule, String date, {String start = "10:00"}) =>
    SnapshotOccurrence(
      ruleId: rule,
      start: berlinLocal(date, start),
      end: berlinLocal(date, "12:00"),
      room: "Seminarraum 2",
    );

/// Veranstaltung aus Regeln und importierten Terminen, aufgelöst wie in der
/// App.
PlanCourse planOf(
  String id,
  List<SessionRule> rules,
  List<SnapshotOccurrence> occurrences,
) => resolvePlanCourse(
  TimetableEntry.fromSnapshot(
    CourseSnapshot(
      courseId: id,
      semesterId: semester.id,
      title: "Veranstaltung $id",
      lecturers: const ["Dr. Muster"],
      rules: [for (final r in rules) SnapshotRule(r, room: "Seminarraum 2")],
      occurrences: occurrences,
      semester: semester,
    ),
  ),
);

PlanCourse weeklyMonday() =>
    planOf("weekly", [weeklyRule("w")], [for (final d in mondays) at("w", d)]);

/// `w2 1` mit Startdatum: Termine alle zwei Wochen.
PlanCourse biweeklyMonday() => planOf(
  "biweekly",
  [weeklyRule("w2", interval: 2)],
  [for (var i = 0; i < mondays.length; i += 2) at("w2", mondays[i])],
);

/// Einzeltermine (`s1`) montags in unregelmäßigem Abstand.
PlanCourse irregularSingles() {
  const dates = ["2026-10-12", "2026-10-19", "2026-11-09", "2026-11-30"];
  return planOf(
    "singles",
    [for (final (i, d) in dates.indexed) singleRule("s$i", d)],
    [for (final (i, d) in dates.indexed) at("s$i", d)],
  );
}

/// Echte Blockveranstaltung: Mo–Fr in einer Woche (`bd 1,2,3,4,5`).
PlanCourse realBlock() {
  const days = [
    "2026-11-09",
    "2026-11-10",
    "2026-11-11",
    "2026-11-12",
    "2026-11-13",
  ];
  return planOf(
    "block",
    [
      const SessionRule(
        id: "b",
        kind: RepeatKind.block,
        weekdays: [1, 2, 3, 4, 5],
        startDate: "2026-11-09",
        endDate: "2026-11-13",
        startTime: "09:00",
        endTime: "12:00",
      ),
    ],
    [
      for (final d in days)
        SnapshotOccurrence(
          ruleId: "b",
          start: berlinLocal(d, "09:00"),
          end: berlinLocal(d, "12:00"),
        ),
    ],
  );
}

Set<SessionKind> kinds(PlanCourse p) => {for (final o in p.occurrences) o.kind};

List<String> titlesInWeek(
  List<PlanCourse> plan,
  String monday,
  SessionKindFilter filter,
) {
  final layout = layoutWeek([
    for (final p in plan)
      for (final o in p.occurrences)
        if (filter.accepts(o)) o,
  ], monday);
  return [
    for (final blocks in layout.days.values)
      for (final b in blocks) b.occurrence.entryId,
  ]..sort();
}

void main() {
  group("Einordnung", () {
    test(
      "1. wöchentlicher Montagstermin: wöchentlich, ohne Rhythmushinweis",
      () {
        final p = weeklyMonday();
        expect(kinds(p), {SessionKind.weekly});
        expect(p.occurrences.every((o) => o.regular), isTrue);
        expect(rhythmLabel(p.occurrences.first), isNull);
        expect(titlesInWeek([p], "2026-10-19", SessionKindFilter.all), [
          "weekly",
        ]);
        expect(titlesInWeek([p], "2026-10-19", SessionKindFilter.regular), [
          "weekly",
        ]);
      },
    );

    test("2. zweiwöchentlicher Montagstermin: regelmäßig, „14-täglich“", () {
      final p = biweeklyMonday();
      expect(kinds(p), {SessionKind.recurring});
      expect(p.occurrences.first.intervalWeeks, 2);
      expect(rhythmLabel(p.occurrences.first), "14-täglich");
      expect(p.hasRegular, isTrue);
      expect(p.hasSpecial, isFalse);
      // Im Raster am Montag – nur in den Wochen, in denen er stattfindet.
      expect(titlesInWeek([p], "2026-10-12", SessionKindFilter.all), [
        "biweekly",
      ]);
      expect(titlesInWeek([p], "2026-10-19", SessionKindFilter.all), isEmpty);
      final block = layoutWeek(p.occurrences, "2026-10-12").days[1]!.single;
      expect(block.startMinute, 10 * 60);
      expect(block.endMinute, 12 * 60);
    });

    test(
      "3. Einzeltermine mit unbekanntem Rhythmus: wiederkehrend, kein Block",
      () {
        final p = irregularSingles();
        expect(kinds(p), {SessionKind.series});
        expect(p.occurrences.every((o) => o.regular), isTrue);
        expect(p.occurrences.first.intervalWeeks, isNull);
        // Kein erfundener Abstand.
        expect(rhythmLabel(p.occurrences.first), "nicht wöchentlich");
        expect(SessionKindFilter.special.accepts(p.occurrences.first), isFalse);
        expect(
          {for (final o in p.occurrences) o.seriesId},
          hasLength(1),
          reason: "eine Serie trotz einer Regel je Termin",
        );
      },
    );

    test("Einzeltermine im festen Abstand: Rhythmus aus den Daten", () {
      // 14-täglich über die Jahreswechselpause (zwei freie Montage).
      const dates = ["2026-11-30", "2026-12-14", "2027-01-11", "2027-01-25"];
      final p = planOf(
        "fortnight",
        [for (final (i, d) in dates.indexed) singleRule("s$i", d)],
        [for (final (i, d) in dates.indexed) at("s$i", d)],
      );
      expect(kinds(p), {SessionKind.recurring});
      expect(p.occurrences.first.intervalWeeks, 2);
      expect(rhythmLabel(p.occurrences.first), "14-täglich");
    });

    test("zwei Einzeltermine genügen nicht für einen Rhythmus", () {
      const dates = ["2026-10-12", "2026-10-26"];
      final p = planOf(
        "two",
        [for (final (i, d) in dates.indexed) singleRule("s$i", d)],
        [for (final (i, d) in dates.indexed) at("s$i", d)],
      );
      expect(kinds(p), {SessionKind.single});
      expect(rhythmLabel(p.occurrences.first), "Einzeltermin");
      // Einzeltermin, nicht Blockveranstaltung.
      expect(sessionKindDescription(p.occurrences.first), "Einzeltermin");
    });

    test(
      "4. echte Blockveranstaltung: über den Filter ein- und ausblendbar",
      () {
        final plan = [realBlock(), biweeklyMonday()];
        expect(kinds(plan.first), {SessionKind.block});
        const week = "2026-11-09";
        expect(titlesInWeek(plan, week, SessionKindFilter.all), [
          "biweekly",
          ...List.filled(5, "block"),
        ]);
        expect(titlesInWeek(plan, week, SessionKindFilter.special), [
          ...List.filled(5, "block"),
        ]);
        expect(titlesInWeek(plan, week, SessionKindFilter.regular), [
          "biweekly",
        ]);
      },
    );

    test("mehrwöchiger Block (Mo–Fr, drei Wochen) bleibt ein Block", () {
      final days = [
        for (final monday in ["2027-02-15", "2027-02-22", "2027-03-01"])
          for (var i = 0; i < 5; i++) addDays(monday, i),
      ];
      final p = planOf(
        "intensive",
        [
          const SessionRule(
            id: "b",
            kind: RepeatKind.block,
            weekdays: [1, 2, 3, 4, 5],
            startDate: "2027-02-15",
            endDate: "2027-03-05",
            startTime: "10:00",
            endTime: "12:00",
          ),
        ],
        [for (final d in days) at("b", d)],
      );
      expect(p.occurrences, hasLength(15));
      expect(kinds(p), {SessionKind.block});
    });

    test(
      "5. zweiwöchentlich bleibt sichtbar, wenn Blocktermine ausgeblendet sind",
      () {
        final plan = [biweeklyMonday(), realBlock()];
        expect(titlesInWeek(plan, "2026-10-12", SessionKindFilter.regular), [
          "biweekly",
        ]);
        expect(
          titlesInWeek(plan, "2026-10-12", SessionKindFilter.special),
          isEmpty,
        );
      },
    );

    test("„alle 2 Wochen“ ohne Startwoche: in jeder Woche als unsicher", () {
      final p = planOf("unknown", [weeklyRule("w2", interval: 2)], const []);
      expect(p.occurrences, hasLength(mondays.length));
      expect(kinds(p), {SessionKind.tentative});
      expect(p.occurrences.every((o) => o.regular), isTrue);
      expect(rhythmLabel(p.occurrences.first), "14-täglich, Wochen unbekannt");
      // Keine sicheren Überschneidungen mit unsicheren Terminen.
      expect(
        conflictSpots([...p.occurrences, ...weeklyMonday().occurrences]),
        isEmpty,
      );
      expect(titlesInWeek([p], "2026-10-19", SessionKindFilter.regular), [
        "unknown",
      ]);
    });

    test("wöchentliche Regel bleibt wöchentlich (Ausfälle ändern nichts)", () {
      final p = planOf(
        "w",
        [weeklyRule("w")],
        [for (final d in mondays.skip(1)) at("w", d)],
      );
      expect(kinds(p), {SessionKind.weekly});
    });
  });

  group("PDF-Export", () {
    test(
      "6. nicht wöchentliche Termine stehen im Wochenraster, nicht nur in der Liste",
      () async {
        final plan = [
          weeklyMonday(),
          biweeklyMonday(),
          irregularSingles(),
          realBlock(),
          planOf("unknown", [
            weeklyRule("w2", interval: 2, weekday: 3),
          ], const []),
        ];
        final export = buildTimetableExport(
          plan: plan,
          options: const TimetableExportOptions(),
          semester: semester,
          now: t.now,
        );
        String slotOf(String id) =>
            export.slots.singleWhere((s) => s.course.plan.id == id).describe();
        expect(export.slots, hasLength(4), reason: "je Serie genau ein Muster");
        expect(slotOf("weekly"), contains("16 Termine"));
        expect(slotOf("weekly"), isNot(contains("14-täglich")));
        expect(slotOf("biweekly"), contains("8 Termine, 14-täglich"));
        expect(slotOf("singles"), contains("4 Termine, nicht wöchentlich"));
        expect(slotOf("unknown"), contains("14-täglich, Wochen unbekannt"));
        expect(slotOf("unknown"), isNot(contains("Termine (")));
        // Nur die Blockveranstaltung in der Zusatzliste, keine Dubletten.
        expect({for (final x in export.specials) x.course.plan.id}, {"block"});
        expect(export.specials, hasLength(5));
        // Im Raster: Montag drei Serien, Mittwoch die unsichere.
        expect(
          [for (final b in export.grid[1]!) b.slot.course.plan.id]..sort(),
          ["biweekly", "singles", "weekly"],
        );
        expect(export.grid[3]!.single.slot.tentative, isTrue);

        final fonts = await t.loadTestFonts();
        final pdf = await buildTimetablePdf(export, fonts, compress: false);
        final text = await t.pdfText(pdf);
        if (text != null) {
          final flat = text.replaceAll(RegExp(r"\s+"), " ");
          expect(flat, contains("14-täglich"));
          expect(flat, contains("nicht wöchentlich"));
          expect(flat, contains("Startwoche"));
        }
      },
    );

    test("7. Filter, Wochenansicht und PDF nutzen dieselbe Einordnung", () {
      final plan = [
        weeklyMonday(),
        biweeklyMonday(),
        irregularSingles(),
        realBlock(),
      ];
      final all = [for (final p in plan) ...p.occurrences];
      for (final (filter, content) in [
        (SessionKindFilter.regular, ExportContent.regular),
        (SessionKindFilter.special, ExportContent.special),
        (SessionKindFilter.all, ExportContent.all),
      ]) {
        expect(ExportContent.fromFilter(filter), content);
        final export = buildTimetableExport(
          plan: plan,
          options: TimetableExportOptions(content: content),
          semester: semester,
          now: t.now,
        );
        final accepted = {
          for (final o in all)
            if (filter.accepts(o)) o.id,
        };
        // Was der Filter zeigt, steht im Export – im Raster (regelmäßig)
        // oder in der Zusatzliste (Block/Einzel), nie in beiden.
        final inGrid = {
          for (final s in export.slots)
            for (final o in all)
              if (o.entryId == s.course.plan.id &&
                  o.regular &&
                  o.seriesId == s.sample.seriesId)
                o.id,
        };
        final inList = {for (final x in export.specials) x.occurrence.id};
        expect(inGrid.intersection(inList), isEmpty);
        expect(inGrid.union(inList), accepted);
        expect(inGrid, {
          for (final o in all)
            if (filter.accepts(o) && o.regular) o.id,
        });
      }
    });
  });
}
