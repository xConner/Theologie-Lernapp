import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/course_snapshot.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/screens/timetable/timetable_export_screen.dart';
import 'package:theologie_lernapp/services/timetable/plan_schedule.dart';
import 'package:theologie_lernapp/services/timetable/timetable_export.dart';
import 'package:theologie_lernapp/services/timetable/timetable_pdf.dart';
import 'package:theologie_lernapp/services/timetable/week_layout.dart';

// Synthetische Veranstaltungen (keine echten Daten).

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

PlanOccurrence occ(
  String entry,
  String date,
  String start,
  String end, {
  String rule = "r1",
  bool regular = true,
  bool cancelled = false,
  bool adjusted = false,
  String? endDate,
  String? room = "Hörsaal 1",
}) => PlanOccurrence(
  id: "$entry@$rule@$date@$start",
  entryId: entry,
  ruleId: rule,
  start: berlinLocal(date, start),
  end: berlinLocal(endDate ?? date, end),
  room: room,
  kind: regular ? SessionKind.weekly : SessionKind.block,
  cancelled: cancelled,
  adjusted: adjusted,
);

PlanCourse course(
  String id,
  String title,
  List<PlanOccurrence> occurrences, {
  List<String> lecturers = const ["Dr. Muster"],
  String? type = "V",
  EntryOverrides overrides = EntryOverrides.none,
}) => PlanCourse(
  entry: TimetableEntry(
    courseId: id,
    semesterId: semester.id,
    title: title,
    scheduleSignature: "",
    overrides: overrides,
  ),
  source: PlanSource.snapshot,
  imported: CourseSnapshot(
    courseId: id,
    semesterId: semester.id,
    title: title,
    number: "0100${id.hashCode % 90 + 10}",
    type: type,
    lecturers: lecturers,
    semester: semester,
  ),
  rules: const [],
  occurrences: occurrences,
);

/// Dienstags 10:15–11:45 von [from] bis [to] (ohne Ferien).
List<PlanOccurrence> weekly(
  String entry,
  List<String> dates, {
  String start = "10:15",
  String end = "11:45",
  String rule = "r1",
  String? room = "Hörsaal 1",
  Set<String> cancelled = const {},
}) => [
  for (final d in dates)
    occ(
      entry,
      d,
      start,
      end,
      rule: rule,
      room: room,
      cancelled: cancelled.contains(d),
    ),
];

const tuesdays = [
  "2026-10-13",
  "2026-10-20",
  "2026-10-27",
  "2026-11-03",
  "2026-11-10",
  "2026-11-17",
  "2026-11-24",
  "2026-12-01",
  "2026-12-08",
  "2026-12-15",
  "2027-01-05",
  "2027-01-12",
  "2027-01-19",
  "2027-01-26",
  "2027-02-02",
  "2027-02-09",
];

final now = DateTime(2026, 10, 15, 9);

TimetableExport build(
  List<PlanCourse> plan, [
  TimetableExportOptions options = const TimetableExportOptions(),
]) => buildTimetableExport(
  plan: plan,
  options: options,
  semester: semester,
  now: now,
);

late TimetablePdfFonts fonts;
late Uint8List regularBytes;

Future<TimetablePdfFonts> loadTestFonts() async {
  ByteData data(String path) =>
      ByteData.sublistView(File(path).readAsBytesSync());
  return TimetablePdfFonts(
    pw.Font.ttf(data(TimetablePdfFonts.regularAsset)),
    pw.Font.ttf(data(TimetablePdfFonts.boldAsset)),
  );
}

int pageCount(Uint8List pdf) =>
    RegExp(r"/Type\s*/Page[^s]").allMatches(String.fromCharCodes(pdf)).length;

/// Text des PDFs über poppler (falls installiert), sonst null.
Future<String?> pdfText(Uint8List pdf) async {
  try {
    final dir = await Directory.systemTemp.createTemp("stundenplan");
    final file = File("${dir.path}/plan.pdf")..writeAsBytesSync(pdf);
    final result = await Process.run("pdftotext", [
      "-layout",
      "-enc",
      "UTF-8",
      file.path,
      "-",
    ], stdoutEncoding: const SystemEncoding());
    await dir.delete(recursive: true);
    return result.exitCode == 0 ? result.stdout as String : null;
  } on ProcessException {
    return null;
  }
}

void main() {
  setUpAll(() async {
    fonts = await loadTestFonts();
    regularBytes = File(TimetablePdfFonts.regularAsset).readAsBytesSync();
  });

  group("Wochenplan", () {
    test("regelmäßige Termine erscheinen einmal je Wochenmuster", () {
      final export = build([
        course("A", "Einführung in das Alte Testament", weekly("A", tuesdays)),
      ]);
      expect(export.slots, hasLength(1));
      final slot = export.slots.single;
      expect(slot.weekday, 2);
      expect(slot.startTime, "10:15");
      expect(slot.endTime, "11:45");
      expect(slot.dates, hasLength(16));
      // Die Jahreswechselpause zählt nicht als fehlende Woche.
      expect(slot.everyWeek, isTrue);
      expect(slot.describe(), contains("16 Termine"));
      expect(slot.describe(), isNot(contains("nicht jede Woche")));
      expect(export.specials, isEmpty);
      expect(export.grid[2], hasLength(1));
      expect(export.firstMinute, 10 * 60);
      expect(export.lastMinute, 12 * 60);
      expect(export.weekdays, [1, 2, 3, 4, 5]);
      expect(export.title, "Stundenplan – Wintersemester 2026/27");
    });

    test(
      "zwei Regeln derselben Veranstaltung: zwei Muster, ohne Dubletten",
      () {
        final export = build([
          course("A", "Hebräisch I", [
            ...weekly("A", tuesdays.take(4).toList()),
            ...weekly(
              "A",
              ["2026-10-15", "2026-10-22"],
              start: "14:15",
              end: "15:45",
              rule: "r2",
            ),
          ]),
        ]);
        expect(export.slots, hasLength(2));
        expect(export.courses, hasLength(1));
        expect([for (final s in export.slots) s.weekday], [2, 4]);
      },
    );

    test(
      "14-täglich und Ausfälle werden als Hinweis vermerkt, nicht erfunden",
      () {
        final biweekly = [for (var i = 0; i < 8; i += 2) tuesdays[i]];
        final export = build([
          course("A", "Kolloquium", weekly("A", biweekly)),
          course(
            "B",
            "Übung",
            weekly(
              "B",
              tuesdays.take(4).toList(),
              start: "16:15",
              end: "17:45",
              cancelled: {"2026-10-20"},
            ),
          ),
        ]);
        final a = export.slots.firstWhere((s) => s.course.plan.id == "A");
        expect(a.everyWeek, isFalse);
        expect(a.missingWeeks, ["2026-10-20", "2026-11-03", "2026-11-17"]);
        expect(a.describe(), contains("nicht jede Woche"));
        final b = export.slots.firstWhere((s) => s.course.plan.id == "B");
        expect(b.cancelledDates, ["2026-10-20"]);
        expect(b.dates, hasLength(3));
        expect(b.everyWeek, isTrue);
      },
    );

    test("ohne Semesterdaten keine Aussage über fehlende Wochen", () {
      final export = buildTimetableExport(
        plan: [
          course("A", "Kolloquium", weekly("A", ["2026-10-13", "2026-10-27"])),
        ],
        options: const TimetableExportOptions(),
        now: now,
      );
      expect(export.slots.single.missingWeeks, isEmpty);
      expect(export.title, "Stundenplan");
    });

    test("Überschneidungen: eigene Spuren und Konfliktmarkierung", () {
      final export = build([
        course("A", "Dogmatik", weekly("A", tuesdays.take(3).toList())),
        course(
          "B",
          "Kirchengeschichte",
          weekly("B", tuesdays.take(3).toList(), start: "11:00", end: "12:30"),
        ),
        course(
          "C",
          "Ethik",
          weekly("C", tuesdays.take(3).toList(), start: "14:15", end: "15:45"),
        ),
      ]);
      final blocks = export.grid[2]!;
      expect(blocks, hasLength(3));
      final overlapping = blocks.where((b) => b.lanes == 2).toList();
      expect(overlapping, hasLength(2));
      expect({for (final b in overlapping) b.lane}, {0, 1});
      expect(
        [for (final s in export.slots) "${s.course.title}:${s.conflict}"],
        ["Dogmatik:true", "Kirchengeschichte:true", "Ethik:false"],
      );
      expect(export.conflicts, hasLength(1));
    });

    test("Wochenende nur als Spalte, wenn dort Termine liegen", () {
      final export = build([
        course("A", "Samstagsseminar", weekly("A", ["2026-10-17"])),
      ]);
      expect(export.weekdays, [1, 2, 3, 4, 5, 6]);
    });
  });

  group("Block- und Sondertermine", () {
    test(
      "Einzel-, Block- und mehrtägige Termine stehen gesondert mit Datum",
      () {
        final export = build([
          course("A", "Vorlesung", weekly("A", tuesdays.take(2).toList())),
          course("B", "Blockseminar Diakonie", [
            occ("B", "2026-11-06", "09:00", "17:00", regular: false),
            occ("B", "2026-11-07", "09:00", "13:00", regular: false),
          ]),
          course("C", "Exkursion", [
            occ(
              "C",
              "2027-02-20",
              "08:00",
              "18:00",
              regular: false,
              endDate: "2027-02-22",
            ),
          ]),
        ]);
        expect(export.slots, hasLength(1));
        expect(export.specials, hasLength(3));
        expect(export.specials.first.when, "Fr 6.11.2026, 09:00–17:00");
        expect(
          export.specials.last.when,
          contains("Sa 20.2.2027 08:00 – Mo 22.2.2027 18:00"),
        );
        // Sondertermine nicht im Raster.
        expect(export.grid.values.expand((l) => l), hasLength(1));
      },
    );

    test("Inhaltswahl: nur regelmäßige bzw. nur Sondertermine", () {
      final plan = [
        course("A", "Vorlesung", weekly("A", tuesdays.take(2).toList())),
        course("B", "Blockseminar", [
          occ("B", "2026-11-06", "09:00", "17:00", regular: false),
        ]),
        course("C", "Ohne Termine", const []),
      ];
      final regular = build(
        plan,
        const TimetableExportOptions(content: ExportContent.regular),
      );
      expect(
        [for (final c in regular.courses) c.title],
        ["Ohne Termine", "Vorlesung"],
      );
      expect(regular.specials, isEmpty);
      expect(regular.withoutDates.single.title, "Ohne Termine");

      final special = build(
        plan,
        const TimetableExportOptions(content: ExportContent.special),
      );
      expect([for (final c in special.courses) c.title], ["Blockseminar"]);
      expect(special.slots, isEmpty);
      expect(special.hasGrid, isFalse);

      expect(
        ExportContent.fromFilter(SessionKindFilter.special),
        ExportContent.special,
      );
      expect(
        ExportContent.fromFilter(SessionKindFilter.regular),
        ExportContent.regular,
      );
      expect(
        ExportContent.fromFilter(SessionKindFilter.all),
        ExportContent.all,
      );
    });
  });

  group("Optionen", () {
    test("Titel, Zusatzzeile und Dateiname", () {
      final export = build(
        [course("A", "Vorlesung", weekly("A", tuesdays.take(2).toList()))],
        const TimetableExportOptions(
          title: "  Mein Plan  ",
          subtitle: " Magister Theologiae ",
        ),
      );
      expect(export.title, "Mein Plan");
      expect(export.subtitle, "Magister Theologiae");
      expect(exportFileName(export), "stundenplan-wintersemester-2026-27.pdf");
      expect(build(const []).subtitle, isNull);
    });

    test("Seitenformat: A4 quer als Voreinstellung, hoch wählbar", () {
      expect(
        exportPageFormat(const TimetableExportOptions()).width,
        PdfPageFormat.a4.height,
      );
      expect(
        exportPageFormat(
          const TimetableExportOptions(orientation: ExportOrientation.portrait),
        ).width,
        PdfPageFormat.a4.width,
      );
    });

    test("der Export verändert den Plan nicht", () {
      final occurrences = weekly("A", tuesdays.take(3).toList());
      final plan = [course("A", "Vorlesung", occurrences)];
      build(plan);
      expect(plan.single.occurrences, same(occurrences));
      expect(plan.single.occurrences, hasLength(3));
    });
  });

  group("PDF", () {
    test("leerer Plan: eine Seite mit Hinweis", () async {
      final pdf = await buildTimetablePdf(
        build(const []),
        fonts,
        compress: false,
      );
      expect(String.fromCharCodes(pdf.take(5)), "%PDF-");
      expect(pageCount(pdf), 1);
      final text = await pdfText(pdf);
      if (text != null) expect(text, contains("keine Veranstaltungen"));
    });

    test("echter Text mit Umlauten, fehlende Räume und Dozenten", () async {
      final export = build([
        course(
          "A",
          "Übung zur Einführung in die Ökumene – Grundsätze „Glaube“",
          weekly("A", tuesdays.take(3).toList(), room: null),
          lecturers: const [],
          type: null,
        ),
        course(
          "B",
          "Griechisch für Fortgeschrittene",
          weekly("B", tuesdays.take(3).toList(), start: "14:15", end: "15:45"),
          lecturers: const ["Prof. Dr. Möller-Weiß"],
        ),
      ], const TimetableExportOptions(detail: ExportDetail.detailed));
      final pdf = await buildTimetablePdf(export, fonts, compress: false);
      expect(pageCount(pdf), greaterThanOrEqualTo(2));
      final text = await pdfText(pdf);
      if (text != null) {
        final flat = text.replaceAll(RegExp(r"\s+"), " ");
        expect(flat, contains("Stundenplan – Wintersemester 2026/27"));
        expect(flat, contains("Möller-Weiß"));
        expect(flat, contains("Griechisch für Fortgeschrittene"));
        expect(flat, contains("Ökumene"));
        expect(flat, contains("Stand: 15.10.2026"));
      }
    });

    test("alle Texte sind in der eingebetteten Schrift vorhanden", () {
      final export = build([
        course(
          "A",
          "Übung „Äöüß“ – Ökumene",
          weekly("A", tuesdays.take(4).toList(), cancelled: {"2026-10-20"}),
          overrides: const EntryOverrides(note: "Raum geändert"),
        ),
        course("B", "Blockseminar", [
          occ("B", "2026-11-06", "09:00", "17:00", regular: false),
        ]),
        course("C", "Ohne Termine", const []),
      ], const TimetableExportOptions(subtitle: "Pfarramt · Diplom"));
      final glyphs = TtfParser(
        ByteData.sublistView(regularBytes),
      ).charToGlyphIndexMap;
      final missing = {
        for (final t in exportTexts(export))
          for (final r in t.runes)
            if (r > 0x20 && !glyphs.containsKey(r)) String.fromCharCode(r),
      };
      expect(missing, isEmpty);
    });

    test("lange Titel brechen nicht das Layout", () async {
      final long = "Hauptseminar: ${"Theologie und Gesellschaft " * 12}".trim();
      final export = build([
        course("A", long, weekly("A", tuesdays.take(2).toList())),
        course(
          "B",
          long,
          weekly("B", tuesdays.take(2).toList(), start: "10:45", end: "11:15"),
        ),
      ]);
      final pdf = await buildTimetablePdf(export, fonts, compress: false);
      expect(pageCount(pdf), greaterThanOrEqualTo(2));
      final text = await pdfText(pdf);
      // Vollständiger Titel in der Veranstaltungsliste.
      if (text != null) {
        expect(
          text.replaceAll(RegExp(r"\s+"), " "),
          contains("Theologie und Gesellschaft Theologie und Gesellschaft"),
        );
      }
    });

    test("langer Tag: Raster wird auf mehrere Seiten verteilt", () async {
      final export = build(
        [
          course(
            "A",
            "Frühkurs",
            weekly(
              "A",
              tuesdays.take(2).toList(),
              start: "07:00",
              end: "08:30",
            ),
          ),
          course(
            "B",
            "Mittag",
            weekly(
              "B",
              tuesdays.take(2).toList(),
              start: "12:15",
              end: "13:45",
            ),
          ),
          course(
            "C",
            "Abendkurs",
            weekly(
              "C",
              tuesdays.take(2).toList(),
              start: "20:00",
              end: "21:30",
            ),
          ),
        ],
        const TimetableExportOptions(
          orientation: ExportOrientation.landscape,
          detail: ExportDetail.detailed,
        ),
      );
      expect(export.firstMinute, 7 * 60);
      expect(export.lastMinute, 22 * 60);
      final ranges = gridPageRanges(export, 400);
      expect(ranges.length, greaterThan(1));
      expect(ranges.first.$1, 7 * 60);
      expect(ranges.last.$2, 22 * 60);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, ranges[i - 1].$2);
      }
      final pdf = await buildTimetablePdf(export, fonts, compress: false);
      expect(pageCount(pdf), greaterThanOrEqualTo(3));
      final text = await pdfText(pdf);
      if (text != null) {
        expect(text, contains("Teil 1 von"));
        // Spaltenköpfe auf jeder Rasterseite.
        expect(
          RegExp("Montag").allMatches(text).length,
          greaterThanOrEqualTo(2),
        );
      }
    });

    test("viele Veranstaltungen: Liste läuft über mehrere Seiten", () async {
      final plan = [
        for (var i = 0; i < 40; i++)
          course(
            "K$i",
            "Veranstaltung Nummer $i mit längerem Titel",
            weekly(
              "K$i",
              tuesdays.take(2).toList(),
              start: "${(8 + i % 10).toString().padLeft(2, "0")}:15",
              end: "${(9 + i % 10).toString().padLeft(2, "0")}:00",
            ),
          ),
      ];
      final pdf = await buildTimetablePdf(build(plan), fonts, compress: false);
      expect(pageCount(pdf), greaterThanOrEqualTo(3));
    });

    test("Schwarz-Weiß, Hochformat, ohne Legende und Datum", () async {
      final export = build(
        [
          course("A", "Dogmatik", weekly("A", tuesdays.take(2).toList())),
          course("B", "Ethik", weekly("B", tuesdays.take(2).toList())),
        ],
        const TimetableExportOptions(
          colors: ExportColors.blackWhite,
          orientation: ExportOrientation.portrait,
          showLegend: false,
          showExportDate: false,
        ),
      );
      final pdf = await buildTimetablePdf(export, fonts, compress: false);
      final raw = String.fromCharCodes(pdf);
      expect(
        raw,
        contains(RegExp(r"/MediaBox\s*\[\s*0\s+0\s+595\.\d+\s+841\.\d+")),
      );
      final text = await pdfText(pdf);
      if (text != null) {
        expect(text, isNot(contains("Stand:")));
        expect(text, isNot(contains("Legende")));
      }
    });
  });

  group("Exportdialog", () {
    testWidgets("Optionen ändern die Inhaltsangabe; Plan bleibt unverändert", (
      tester,
    ) async {
      final plan = [
        course("A", "Vorlesung", weekly("A", tuesdays.take(2).toList())),
        course("B", "Blockseminar", [
          occ("B", "2026-11-06", "09:00", "17:00", regular: false),
        ]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: TimetableExportScreen(
            plan: plan,
            semester: semester,
            showPreview: false,
            loadFonts: loadTestFonts,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Stundenplan drucken"), findsOneWidget);
      expect(find.byKey(const ValueKey("export-print")), findsOneWidget);
      expect(find.byKey(const ValueKey("export-share")), findsOneWidget);
      expect(
        find.textContaining("2 Veranstaltungen · 1 wöchentliche Termin"),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey("export-content")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Nur Block- und Sondertermine").last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining("1 Veranstaltung · 1 Block- und Sondertermine"),
        findsOneWidget,
      );

      for (final key in [
        "export-orientation-portrait",
        "export-colors-blackWhite",
      ]) {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      final orientation = tester.widget<SegmentedButton<ExportOrientation>>(
        find.byKey(const ValueKey("export-orientation")),
      );
      expect(orientation.selected, {ExportOrientation.portrait});
      expect(plan[1].occurrences, hasLength(1));
    });

    testWidgets("leerer Plan: Hinweis statt Fehler", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimetableExportScreen(
            plan: const [],
            semester: semester,
            showPreview: false,
            loadFonts: loadTestFonts,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("keine Veranstaltungen"), findsOneWidget);
    });
  });
}
