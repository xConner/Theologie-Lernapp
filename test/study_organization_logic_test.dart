import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/course_snapshot.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/services/timetable/plan_conflicts.dart';
import 'package:theologie_lernapp/services/timetable/plan_schedule.dart';
import 'package:theologie_lernapp/services/timetable/week_layout.dart';

/// Termin am [date] von [start] bis [end] (Kieler Ortszeit).
PlanOccurrence occ(
  String entry,
  String date,
  String start,
  String end, {
  bool regular = true,
  bool cancelled = false,
  String? endDate,
}) => PlanOccurrence(
  id: "$entry@$date@$start",
  entryId: entry,
  ruleId: "$entry-rule",
  start: berlinLocal(date, start),
  end: berlinLocal(endDate ?? date, end),
  regular: regular,
  cancelled: cancelled,
);

const semester = CatalogSemester(
  id: "2026w",
  label: "Wintersemester 2026/27",
  start: "2026-10-01",
  end: "2027-03-31",
  lectureStart: "2026-10-12",
  lectureEnd: "2027-02-12",
  breaks: [
    SemesterBreak(
      "2026-12-21",
      "2027-01-03",
      "unterrichtsfrei (Jahreswechsel)",
    ),
  ],
);

void main() {
  group("Überschneidungsstellen", () {
    test("zwei überschneidende Veranstaltungen: eine Stelle", () {
      final spots = conflictSpots([
        occ("A", "2026-10-13", "10:00", "11:30"),
        occ("B", "2026-10-13", "10:00", "11:30"),
      ]);
      expect(spots, hasLength(1));
      expect(spots.single.entryIds, ["A", "B"]);
      expect(spots.single.start.time, "10:00");
      expect(spots.single.end.time, "11:30");
      expect(spots.single.duration, const Duration(minutes: 90));
      expect(spots.single.weekday, 2);
    });

    test(
      "drei gleichzeitige Veranstaltungen: eine Stelle mit drei Beteiligten",
      () {
        final spots = conflictSpots([
          occ("A", "2026-10-13", "10:00", "11:30"),
          occ("B", "2026-10-13", "10:00", "11:30"),
          occ("C", "2026-10-13", "10:15", "11:00"),
        ]);
        expect(spots, hasLength(1));
        expect(spots.single.entryIds, ["A", "B", "C"]);
        expect(ConflictSummary.of(spots).spots, 1);
        expect(ConflictSummary.of(spots).courses, 3);
      },
    );

    test("mehrere getrennte Konflikte: getrennte Stellen", () {
      final spots = conflictSpots([
        occ("A", "2026-10-13", "10:00", "12:00"),
        occ("B", "2026-10-13", "11:00", "13:00"),
        occ("C", "2026-10-13", "12:30", "14:00"),
        occ("D", "2026-10-15", "08:00", "09:00"),
        occ("E", "2026-10-15", "08:30", "10:00"),
      ]);
      expect(spots, hasLength(3));
      expect(
        [for (final s in spots) s.entryIds],
        [
          ["A", "B"],
          ["B", "C"],
          ["D", "E"],
        ],
      );
      expect(
        [for (final s in spots) "${s.start.time}-${s.end.time}"],
        ["11:00-12:00", "12:30-13:00", "08:30-09:00"],
      );
    });

    test(
      "direkt aufeinanderfolgende Veranstaltungen sind keine Überschneidung",
      () {
        expect(
          conflictSpots([
            occ("A", "2026-10-13", "10:00", "11:30"),
            occ("B", "2026-10-13", "11:30", "13:00"),
          ]),
          isEmpty,
        );
      },
    );

    test(
      "abgesagte Termine und Termine derselben Veranstaltung zählen nicht",
      () {
        expect(
          conflictSpots([
            occ("A", "2026-10-13", "10:00", "11:30"),
            occ("A", "2026-10-13", "11:00", "12:00"),
            occ("B", "2026-10-13", "10:00", "11:30", cancelled: true),
          ]),
          isEmpty,
        );
      },
    );

    test(
      "abweichender Blocktermin: Konflikt nur an seinem Datum, nicht wöchentlich",
      () {
        final weekly = [
          for (final date in ["2026-11-07", "2026-11-14", "2026-11-21"])
            occ("Samstagskurs", date, "10:00", "12:00"),
        ];
        final block = occ(
          "Block",
          "2026-11-14",
          "09:00",
          "16:00",
          regular: false,
        );
        final spots = conflictSpots([...weekly, block]);
        expect(spots, hasLength(1));
        expect(spots.single.date, "2026-11-14");
        final groups = groupConflicts(spots);
        expect(groups, hasLength(1));
        expect(groups.single.recurring, isFalse);
      },
    );

    test(
      "wöchentlicher Konflikt wird zu einer Gruppe mit allen Daten zusammengefasst",
      () {
        final spots = conflictSpots([
          for (final date in ["2026-10-13", "2026-10-20", "2026-10-27"]) ...[
            occ("A", date, "10:00", "11:30"),
            occ("B", date, "10:00", "11:30"),
          ],
        ]);
        expect(spots, hasLength(3));
        final groups = groupConflicts(spots);
        expect(groups, hasLength(1));
        expect(groups.single.recurring, isTrue);
        expect(groups.single.dates, ["2026-10-13", "2026-10-20", "2026-10-27"]);
        expect(groups.single.weekday, 2);
      },
    );

    test(
      "mehrtägiger Block überschneidet sich mit Terminen an jedem berührten Tag",
      () {
        final spots = conflictSpots([
          occ(
            "Block",
            "2026-11-12",
            "09:00",
            "17:00",
            endDate: "2026-11-14",
            regular: false,
          ),
          occ("A", "2026-11-13", "10:00", "12:00"),
        ]);
        expect(spots, hasLength(1));
        expect(spots.single.date, "2026-11-13");
      },
    );
  });

  group("Wochenraster", () {
    test(
      "gleichzeitige Termine liegen nebeneinander, Anschlusstermin in eigener Gruppe",
      () {
        final layout = layoutWeek([
          occ("A", "2026-10-13", "10:00", "11:30"),
          occ("B", "2026-10-13", "10:00", "11:30"),
          occ("C", "2026-10-13", "11:30", "13:00"),
        ], "2026-10-12");
        final tuesday = layout.days[2]!;
        final a = tuesday.firstWhere((b) => b.occurrence.entryId == "A");
        final b = tuesday.firstWhere((b) => b.occurrence.entryId == "B");
        final c = tuesday.firstWhere((b) => b.occurrence.entryId == "C");
        expect({a.lane, b.lane}, {0, 1});
        expect(a.lanes, 2);
        expect(c.lanes, 1);
        expect(c.startMinute, 11 * 60 + 30);
        expect(layout.visibleWeekdays, [1, 2, 3, 4, 5]);
      },
    );

    test(
      "Zeitraum passt sich an frühe und späte Termine an, Wochenende nur mit Terminen",
      () {
        final layout = layoutWeek([
          occ("A", "2026-10-17", "07:15", "08:00"),
          occ("B", "2026-10-14", "18:00", "20:15"),
        ], "2026-10-12");
        expect(layout.firstMinute, 7 * 60);
        expect(layout.lastMinute, 21 * 60);
        expect(layout.visibleWeekdays, [1, 2, 3, 4, 5, 6]);
      },
    );

    test(
      "mehrtägiger Block erscheint an jedem Tag, abgeschnitten auf den Zeitraum",
      () {
        final layout = layoutWeek([
          occ(
            "Block",
            "2026-11-12",
            "14:00",
            "12:00",
            endDate: "2026-11-14",
            regular: false,
          ),
        ], "2026-11-09");
        expect(layout.days[4]!.single.startMinute, 14 * 60);
        expect(layout.days[4]!.single.continuesAfter, isTrue);
        expect(layout.days[5]!.single.continuesBefore, isTrue);
        expect(layout.days[5]!.single.startMinute, layout.firstMinute);
        expect(layout.days[6]!.single.endMinute, 12 * 60);
      },
    );

    test(
      "Filter: regelmäßige und Sondertermine derselben Veranstaltung bleiben getrennt erhalten",
      () {
        final weekly = occ("A", "2026-10-13", "10:00", "11:30");
        final special = occ(
          "A",
          "2026-10-17",
          "09:00",
          "15:00",
          regular: false,
        );
        final all = [weekly, special];
        expect(all.where(SessionKindFilter.all.accepts), hasLength(2));
        expect(all.where(SessionKindFilter.regular.accepts), [weekly]);
        expect(all.where(SessionKindFilter.special.accepts), [special]);
        expect(
          SessionKindFilter.fromName("special"),
          SessionKindFilter.special,
        );
        expect(SessionKindFilter.fromName("kaputt"), SessionKindFilter.all);
      },
    );
  });

  group("Plan aus Import und persönlichen Anpassungen", () {
    CourseSnapshot snapshot({
      List<SnapshotOccurrence>? occurrences,
      List<SnapshotRule>? rules,
    }) => CourseSnapshot(
      courseId: "cau-univis:2026w:Lecture.phil.ethik",
      semesterId: "2026w",
      sources: const [SourceRef("cau-univis", "Lecture.phil.ethik")],
      title: "Einführung in die Ethik",
      number: "050123",
      organizationPath: const [
        "Philosophische Fakultät",
        "Philosophisches Seminar",
      ],
      lecturers: const ["Dr. Beispiel"],
      rules:
          rules ??
          const [
            SnapshotRule(
              SessionRule(
                id: "r1",
                kind: RepeatKind.weekly,
                intervalWeeks: 1,
                weekdays: [2],
                startTime: "10:15",
                endTime: "11:45",
                roomId: "room-1",
              ),
              room: "Hörsaal 1",
            ),
          ],
      occurrences:
          occurrences ??
          [
            for (final date in [
              "2026-10-13",
              "2026-10-20",
              "2026-12-15",
              "2027-01-05",
            ])
              SnapshotOccurrence(
                ruleId: "r1",
                start: berlinLocal(date, "10:15"),
                end: berlinLocal(date, "11:45"),
                room: "Hörsaal 1",
              ),
          ],
      semester: semester,
    );

    test("gespeicherter Import ohne Katalog: Daten aus dem Eintrag", () {
      final entry = TimetableEntry.fromSnapshot(snapshot());
      final plan = resolvePlanCourse(entry);
      expect(plan.source, PlanSource.snapshot);
      expect(plan.title, "Einführung in die Ethik");
      expect(plan.faculty, "Philosophische Fakultät");
      expect(plan.occurrences, hasLength(4));
      expect(plan.occurrences.first.room, "Hörsaal 1");
      expect(plan.hasRegular, isTrue);
    });

    test(
      "Anpassung verschiebt Termine, Daten (Ferien) bleiben, Original bleibt gespeichert",
      () {
        final entry = TimetableEntry.fromSnapshot(
          snapshot(),
          overrides: const EntryOverrides(
            title: "Ethik (Wahlpflicht)",
            rules: {
              "r1": RuleOverride(
                weekday: 3,
                startTime: "12:15",
                endTime: "13:45",
                room: "Seminarraum 2",
              ),
            },
          ),
        );
        final plan = resolvePlanCourse(entry);
        expect(plan.title, "Ethik (Wahlpflicht)");
        expect(
          [for (final o in plan.occurrences) o.date],
          ["2026-10-14", "2026-10-21", "2026-12-16", "2027-01-06"],
        );
        expect(plan.occurrences.first.start.time, "12:15");
        expect(plan.occurrences.first.room, "Seminarraum 2");
        expect(plan.occurrences.first.adjusted, isTrue);
        // Der Import selbst ist unverändert.
        expect(entry.snapshot!.rules.single.rule.startTime, "10:15");
      },
    );

    test("ausgeblendeter Termin und ergänzter Termin (ohne Ferien)", () {
      final entry = TimetableEntry.fromSnapshot(
        snapshot(),
        overrides: const EntryOverrides(
          rules: {"r1": RuleOverride(removed: true)},
          extraSessions: [
            ExtraSession(
              id: "x1",
              weekday: 1,
              startTime: "16:00",
              endTime: "18:00",
            ),
          ],
        ),
      );
      final plan = resolvePlanCourse(entry);
      expect(plan.occurrences.every((o) => o.ruleId == "extra:x1"), isTrue);
      final dates = [for (final o in plan.occurrences) o.date];
      expect(dates.first, "2026-10-12");
      expect(dates.last, "2027-02-08");
      expect(dates, isNot(contains("2026-12-21")));
      expect(dates, isNot(contains("2026-12-28")));
      expect(plan.occurrences.first.start.toIso(), "2026-10-12T16:00:00+02:00");
      expect(plan.occurrences.last.start.toIso(), "2027-02-08T16:00:00+01:00");
    });

    test("fehlende Uhrzeit der Quelle wird durch Ergänzung zu Terminen", () {
      final entry = TimetableEntry.fromSnapshot(
        snapshot(
          rules: const [
            SnapshotRule(
              SessionRule(
                id: "r1",
                kind: RepeatKind.weekly,
                intervalWeeks: 1,
                weekdays: [4],
              ),
            ),
          ],
          occurrences: const [],
        ),
        overrides: const EntryOverrides(
          rules: {"r1": RuleOverride(startTime: "14:15", endTime: "15:45")},
        ),
      );
      final plan = resolvePlanCourse(entry);
      expect(plan.occurrences.first.date, "2026-10-15");
      expect(plan.occurrences.first.start.time, "14:15");
    });

    test(
      "gespeichertes Format: Import und Anpassungen überstehen Hin- und Rückweg",
      () {
        final entry = TimetableEntry.fromSnapshot(
          snapshot(),
          overrides: const EntryOverrides(
            lecturers: "Prof. Dr. Korrigiert",
            rules: {"r1": RuleOverride(room: "Raum 3")},
            extraSessions: [
              ExtraSession(
                id: "x1",
                weekday: 5,
                startTime: "08:00",
                endTime: "09:00",
              ),
            ],
          ),
        );
        final restored = TimetableEntry.tryFromMap(entry.toMap())!;
        expect(restored.snapshot!.title, entry.snapshot!.title);
        expect(restored.snapshot!.occurrences, hasLength(4));
        expect(
          restored.snapshot!.occurrences.first.start.toIso(),
          "2026-10-13T10:15:00+02:00",
        );
        expect(restored.snapshot!.semester!.lectureEnd, "2027-02-12");
        expect(restored.snapshot!.fromFacultyCatalog, isFalse);
        expect(restored.overrides.lecturers, "Prof. Dr. Korrigiert");
        expect(restored.overrides.rules["r1"]!.room, "Raum 3");
        expect(restored.overrides.extraSessions.single.weekday, 5);
        // Version-1-Form für alte Firestore-Regeln: ohne neue Felder.
        expect(entry.toMap(legacy: true).keys, isNot(contains("snapshot")));
        expect(entry.toMap(legacy: true).keys, isNot(contains("overrides")));
      },
    );

    test("ungültige Anpassungen werden beim Lesen verworfen", () {
      final overrides = EntryOverrides.fromMap({
        "rules": {
          "r1": {"startTime": "25:00", "weekday": 0},
        },
        "extraSessions": [
          {"id": "x", "weekday": 2, "startTime": "12:00", "endTime": "11:00"},
          {"id": "y", "weekday": 9, "startTime": "10:00", "endTime": "11:00"},
        ],
      });
      expect(overrides.isEmpty, isTrue);
    });

    test("Sommer- und Winterzeit in Kiel", () {
      expect(
        berlinLocal("2027-03-28", "01:30").toIso(),
        "2027-03-28T01:30:00+01:00",
      );
      expect(
        berlinLocal("2027-03-28", "03:30").toIso(),
        "2027-03-28T03:30:00+02:00",
      );
      expect(
        berlinLocal("2026-10-25", "10:00").toIso(),
        "2026-10-25T10:00:00+01:00",
      );
      expect(
        berlinLocal("2026-10-24", "10:00").toIso(),
        "2026-10-24T10:00:00+02:00",
      );
    });

    test("Wochentage in der Vorlesungszeit ohne unterrichtsfreie Zeit", () {
      final mondays = weeklyDates(semester, 1);
      expect(mondays.first, "2026-10-12");
      expect(mondays, isNot(contains("2026-12-21")));
      expect(mondays, contains("2027-01-04"));
      expect(weeklyDates(semester, 5, from: "2026-11-01", to: "2026-11-30"), [
        "2026-11-06",
        "2026-11-13",
        "2026-11-20",
        "2026-11-27",
      ]);
    });
  });
}
