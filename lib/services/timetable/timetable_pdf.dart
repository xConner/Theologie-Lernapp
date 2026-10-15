import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'course_labels.dart';
import 'plan_conflicts.dart';
import 'plan_schedule.dart';
import 'timetable_export.dart';

// Druckbarer Stundenplan als PDF (A4) aus einem [TimetableExport]:
//
// 1. Wochenraster der regelmäßigen Termine – Wochentage als Spalten, Zeit
//    von oben nach unten, Zeitachse auf die tatsächlichen Termine begrenzt.
//    Passt der Zeitraum nicht lesbar auf eine Seite, wird er auf mehrere
//    Seiten aufgeteilt (Spaltenköpfe wiederholt).
// 2. Veranstaltungen mit allen Angaben (Nummer im Raster = Nummer in der
//    Liste; lange Titel stehen hier vollständig).
// 3. Block- und Sondertermine mit Datum, 4. Überschneidungen.
//
// Echter Text in eingebetteter Schrift (Lato, SIL OFL 1.1, mit Umlauten),
// heller Hintergrund unabhängig vom App-Theme, lokal erzeugt.

/// Eingebettete Schriften.
class TimetablePdfFonts {
  final pw.Font regular;
  final pw.Font bold;

  const TimetablePdfFonts(this.regular, this.bold);

  static const String regularAsset = "assets/fonts/Lato-Regular.ttf";
  static const String boldAsset = "assets/fonts/Lato-Bold.ttf";

  static Future<TimetablePdfFonts> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return TimetablePdfFonts(
      pw.Font.ttf(await b.load(regularAsset)),
      pw.Font.ttf(await b.load(boldAsset)),
    );
  }
}

/// Farben je Veranstaltung: zurückhaltende Töne gut unterscheidbarer
/// Farbrichtungen (Füllung hell, Rand kräftig).
const List<(int, int)> _palette = [
  (0xFFE3E9F4, 0xFF3B4C6B), // Blau (Primärfarbe der App)
  (0xFFF3E9D7, 0xFF8A6A33), // Ocker (Akzentfarbe der App)
  (0xFFE2F0E6, 0xFF3F7D58), // Grün
  (0xFFF6E1DC, 0xFFA2412F), // Rotbraun
  (0xFFEAE3F2, 0xFF5F4B8B), // Violett
  (0xFFDDEFEF, 0xFF2E7372), // Petrol
  (0xFFF0EEDB, 0xFF6E6A2C), // Oliv
  (0xFFE6E6E9, 0xFF4E5059), // Grau
];

class _Style {
  final TimetablePdfFonts fonts;
  final TimetableExportOptions options;

  _Style(this.fonts, this.options);

  bool get color => options.colors == ExportColors.color;
  bool get detailed => options.detail == ExportDetail.detailed;

  PdfColor get text => const PdfColor.fromInt(0xFF1E1E22);
  PdfColor get muted => const PdfColor.fromInt(0xFF55555C);
  PdfColor get line => color
      ? const PdfColor.fromInt(0xFFCFC8BA)
      : const PdfColor.fromInt(0xFF9A9A9A);
  PdfColor get heading => color ? const PdfColor.fromInt(0xFF3B4C6B) : text;
  PdfColor get conflict =>
      color ? const PdfColor.fromInt(0xFFB3402E) : PdfColors.black;

  PdfColor fill(int index) =>
      color ? PdfColor.fromInt(_palette[index].$1) : PdfColors.white;
  PdfColor border(int index) =>
      color ? PdfColor.fromInt(_palette[index].$2) : PdfColors.black;

  double get blockFont => detailed ? 7.6 : 8.0;

  pw.TextStyle base({double size = 9, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? fonts.bold : fonts.regular,
        fontBold: fonts.bold,
        fontSize: size,
        color: color ?? text,
        lineSpacing: 0.6,
      );
}

PdfPageFormat exportPageFormat(TimetableExportOptions options) =>
    options.orientation == ExportOrientation.landscape
    ? PdfPageFormat.a4.landscape
    : PdfPageFormat.a4;

const double _margin = 28; // ca. 1 cm
const double _timeColumn = 34;
const double _dayHeader = 18;
const double _maxHourHeight = 64;
const double _legendHeight = 24;

/// Kleinste Höhe einer Stunde im Raster; darunter wird aufgeteilt.
double minHourHeight(TimetableExportOptions options) =>
    options.detail == ExportDetail.detailed ? 46 : 34;

/// Zeiträume (Minuten) der Rasterseiten. Passt der ganze Zeitraum lesbar auf
/// eine Seite, ist es einer; sonst werden Abschnitte möglichst an
/// Stundengrenzen gebildet, die kein Termin überspannt.
List<(int, int)> gridPageRanges(
  TimetableExport export,
  double availableHeight,
) {
  final first = export.firstMinute;
  final last = export.lastMinute;
  final maxHours = math.max(
    2,
    (availableHeight / minHourHeight(export.options)).floor(),
  );
  if ((last - first) / 60 <= maxHours) return [(first, last)];
  final blocks = [for (final l in export.grid.values) ...l];
  final ranges = <(int, int)>[];
  var start = first;
  while (start < last) {
    var end = math.min(last, start + maxHours * 60);
    if (end < last) {
      // Möglichst nicht mitten durch einen Termin schneiden.
      for (var candidate = end; candidate > start + 60; candidate -= 60) {
        final crossing = blocks.any(
          (b) => b.startMinute < candidate && b.endMinute > candidate,
        );
        if (!crossing) {
          end = candidate;
          break;
        }
      }
    }
    ranges.add((start, end));
    start = end;
  }
  return ranges;
}

/// Erzeugt das PDF. Liest nur den Export, verändert nichts.
Future<Uint8List> buildTimetablePdf(
  TimetableExport export,
  TimetablePdfFonts fonts, {
  bool compress = true,
}) async {
  final s = _Style(fonts, export.options);
  final format = exportPageFormat(export.options);
  final doc = pw.Document(
    compress: compress,
    title: export.title,
    creator: "theologie.app",
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
  );

  final header = _header(export, s);
  pw.Widget footer(pw.Context context) => _footer(export, s, context);

  if (export.isEmpty) {
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(_margin),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            header,
            pw.SizedBox(height: 24),
            pw.Text(
              export.options.content == ExportContent.special
                  ? "Im Stundenplan gibt es keine Block- oder Sondertermine."
                  : "Im Stundenplan sind noch keine Veranstaltungen eingetragen.",
              style: s.base(size: 11),
            ),
            pw.Spacer(),
            footer(context),
          ],
        ),
      ),
    );
    return doc.save();
  }

  // 1. Wochenraster.
  if (export.hasGrid) {
    const headerHeight = 40.0;
    const footerHeight = 16.0;
    final legendHeight = export.options.showLegend ? _legendHeight : 0.0;
    final available =
        format.height -
        2 * _margin -
        headerHeight -
        footerHeight -
        legendHeight -
        _dayHeader -
        6;
    final ranges = gridPageRanges(export, available);
    for (final (i, range) in ranges.indexed) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(_margin),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              header,
              if (ranges.length > 1)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    "Wochenplan, Teil ${i + 1} von ${ranges.length}: "
                    "${_hour(range.$1)}–${_hour(range.$2)} Uhr",
                    style: s.base(size: 8, color: s.muted),
                  ),
                ),
              pw.Expanded(
                child: pw.LayoutBuilder(
                  builder: (context, constraints) => _grid(
                    export,
                    s,
                    range,
                    constraints!.maxWidth,
                    constraints.maxHeight,
                  ),
                ),
              ),
              if (export.options.showLegend) _legend(export, s),
              footer(context),
            ],
          ),
        ),
      );
    }
  }

  // 2.–4. Listen (mehrseitig, Tabellenköpfe wiederholt).
  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(_margin),
      header: export.hasGrid ? null : (_) => header,
      footer: footer,
      build: (context) => [
        _sectionTitle("Veranstaltungen", s),
        _courseTable(export, s),
        if (export.withoutDates.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              "Ohne feste Termine: ${export.withoutDates.map((c) => "[${c.number}] ${c.title}").join("; ")}",
              style: s.base(size: 8.5, color: s.muted),
            ),
          ),
        if (export.specials.isNotEmpty) ...[
          _sectionTitle("Block- und Sondertermine", s),
          _specialTable(export, s),
        ],
        if (export.conflicts.isNotEmpty) ...[
          _sectionTitle("Überschneidungen", s),
          _conflictTable(export, s),
        ],
      ],
    ),
  );
  return doc.save();
}

String _hour(int minute) =>
    "${(minute ~/ 60).toString().padLeft(2, "0")}:${(minute % 60).toString().padLeft(2, "0")}";

String _date(DateTime d) => "${d.day}.${d.month}.${d.year}";

pw.Widget _header(TimetableExport export, _Style s) => pw.Container(
  height: 40,
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              export.title,
              style: s.base(size: 14, bold: true, color: s.heading),
              maxLines: 1,
            ),
            if (export.subtitle != null)
              pw.Text(
                export.subtitle!,
                style: s.base(size: 9, color: s.muted),
                maxLines: 1,
              ),
          ],
        ),
      ),
      if (export.options.showExportDate)
        pw.Text(
          "Stand: ${_date(export.exportedAt)}",
          style: s.base(size: 8, color: s.muted),
        ),
    ],
  ),
);

pw.Widget _footer(
  TimetableExport export,
  _Style s,
  pw.Context context,
) => pw.Container(
  height: 16,
  alignment: pw.Alignment.bottomLeft,
  child: pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          "Quelle: UnivIS der CAU Kiel; eigene Anpassungen mit * gekennzeichnet · erstellt mit theologie.app",
          style: s.base(size: 7, color: s.muted),
          maxLines: 1,
        ),
      ),
      pw.Text(
        "Seite ${context.pageNumber} von ${context.pagesCount}",
        style: s.base(size: 7, color: s.muted),
      ),
    ],
  ),
);

pw.Widget _legend(TimetableExport export, _Style s) {
  final items = <String>[
    "[Nr.] = Veranstaltung in der Liste",
    if (export.courses.any((c) => c.plan.hasOverrides) ||
        export.slots.any((x) => x.adjusted))
      "* von dir angepasst",
    if (export.slots.any((x) => x.conflict)) "! Überschneidung",
    if (export.slots.any((x) => !x.everyWeek || x.cancelledDates.isNotEmpty))
      "° nicht jede Woche (Rhythmus am Termin) bzw. mit Ausfällen",
    if (export.specials.isNotEmpty && export.options.content.includesSpecial)
      "Block- und Sondertermine: Liste ab der nächsten Seite",
  ];
  return pw.Container(
    height: _legendHeight,
    alignment: pw.Alignment.centerLeft,
    child: pw.Text(
      items.join("  ·  "),
      style: s.base(size: 7.5, color: s.muted),
      maxLines: 2,
    ),
  );
}

pw.Widget _grid(
  TimetableExport export,
  _Style s,
  (int, int) range,
  double width,
  double height,
) {
  final days = export.weekdays;
  final dayWidth = (width - _timeColumn) / days.length;
  final hours = (range.$2 - range.$1) / 60;
  // Wenige Stunden nicht über die ganze Seite strecken.
  final hourHeight = math.min((height - _dayHeader) / hours, _maxHourHeight);
  final bodyHeight = hours * hourHeight;
  double y(int minute) => _dayHeader + (minute - range.$1) / 60 * hourHeight;

  final children = <pw.Widget>[
    // Spaltenköpfe.
    for (final (i, d) in days.indexed)
      pw.Positioned(
        left: _timeColumn + i * dayWidth,
        top: 0,
        child: pw.Container(
          width: dayWidth,
          height: _dayHeader,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: s.text, width: 0.8)),
          ),
          child: pw.Text(weekdayName(d), style: s.base(size: 9.5, bold: true)),
        ),
      ),
    // Stundenlinien und Zeitachse.
    for (var h = 0; h <= hours; h++) ...[
      pw.Positioned(
        left: _timeColumn,
        top: _dayHeader + h * hourHeight,
        child: pw.Container(
          width: width - _timeColumn,
          height: 0.4,
          color: s.line,
        ),
      ),
      if (h < hours)
        pw.Positioned(
          left: 0,
          top: _dayHeader + h * hourHeight + 1,
          child: pw.SizedBox(
            width: _timeColumn - 4,
            child: pw.Text(
              _hour(range.$1 + h * 60),
              textAlign: pw.TextAlign.right,
              style: s.base(size: 7.5, color: s.muted),
            ),
          ),
        ),
    ],
    // Spaltentrenner.
    for (var i = 0; i <= days.length; i++)
      pw.Positioned(
        left: _timeColumn + i * dayWidth,
        top: _dayHeader,
        child: pw.Container(width: 0.4, height: bodyHeight, color: s.line),
      ),
  ];

  for (final (i, d) in days.indexed) {
    for (final b in export.grid[d] ?? const <GridBlock>[]) {
      final start = math.max(b.startMinute, range.$1);
      final end = math.min(b.endMinute, range.$2);
      if (end <= start) continue;
      final laneWidth = dayWidth / b.lanes;
      children.add(
        pw.Positioned(
          left: _timeColumn + i * dayWidth + b.lane * laneWidth + 1.5,
          top: y(start) + 1,
          child: _block(
            b,
            s,
            laneWidth - 3,
            math.max(10, (end - start) / 60 * hourHeight - 2),
            continuesBefore: b.startMinute < range.$1,
            continuesAfter: b.endMinute > range.$2,
          ),
        ),
      );
    }
  }

  return pw.SizedBox(
    width: width,
    height: height,
    child: pw.Stack(children: children),
  );
}

pw.Widget _block(
  GridBlock b,
  _Style s,
  double width,
  double height, {
  bool continuesBefore = false,
  bool continuesAfter = false,
}) {
  final slot = b.slot;
  final c = slot.course;
  final size = s.blockFont;
  final lineHeight = size * 1.28;
  final lines = math.max<int>(1, ((height - 4) / lineHeight).floor());
  final marks = [
    if (slot.adjusted) "*",
    if (!slot.everyWeek || slot.cancelledDates.isNotEmpty) "°",
  ].join();
  final prefix = "${slot.conflict ? "! " : ""}[${c.number}]$marks ";
  final time =
      "${continuesBefore ? "… " : ""}${timeRange(slot.startTime, slot.endTime)}${continuesAfter ? " …" : ""}";
  final extra = [
    time,
    // Rhythmus in eigener Zeile, damit er auch in schmalen Spalten bleibt.
    ?slot.rhythm,
    ?slot.room,
    if (s.detailed && c.lecturers.isNotEmpty) c.lecturers.join(", "),
    if (s.detailed && c.type != null) courseTypeLabel(c.type),
  ];
  final List<pw.Widget> content;
  if (lines == 1) {
    content = [
      pw.Text(
        "$prefix${slot.startTime} ${c.title}",
        style: s.base(size: size, bold: true),
        maxLines: 1,
      ),
    ];
  } else {
    final titleLines = math.max<int>(
      1,
      math.min<int>(3, lines - math.min<int>(extra.length, lines - 1)),
    );
    content = [
      pw.Text(
        "$prefix${c.title}",
        style: s.base(size: size, bold: true),
        maxLines: titleLines,
      ),
      for (final e in extra.take(lines - titleLines))
        pw.Text(e, style: s.base(size: size), maxLines: 1),
    ];
  }
  return pw.Container(
    width: width,
    height: height,
    padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
    decoration: pw.BoxDecoration(
      color: s.fill(c.colorIndex),
      border: pw.Border.all(
        color: slot.conflict ? s.conflict : s.border(c.colorIndex),
        width: slot.conflict ? 1.6 : 0.7,
        // Gepunktet: Wochen unbekannt (siehe Liste).
        style: slot.tentative
            ? pw.BorderStyle.dotted
            : slot.conflict && !s.color
            ? pw.BorderStyle.dashed
            : pw.BorderStyle.solid,
      ),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
    child: pw.ClipRect(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: content,
      ),
    ),
  );
}

pw.Widget _sectionTitle(String text, _Style s) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
  child: pw.Text(text, style: s.base(size: 11.5, bold: true, color: s.heading)),
);

pw.Widget _table(
  _Style s,
  List<String> headers,
  List<List<String>> rows,
  Map<int, pw.TableColumnWidth> widths,
) => pw.TableHelper.fromTextArray(
  headers: headers,
  data: rows,
  headerCount: 1,
  columnWidths: widths,
  border: pw.TableBorder(
    horizontalInside: pw.BorderSide(color: s.line, width: 0.4),
    bottom: pw.BorderSide(color: s.line, width: 0.4),
  ),
  headerDecoration: pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: s.text, width: 0.8)),
  ),
  headerStyle: s.base(size: 8.5, bold: true),
  cellStyle: s.base(size: 8.5),
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
  cellAlignment: pw.Alignment.topLeft,
  headerAlignment: pw.Alignment.bottomLeft,
);

pw.Widget _courseTable(TimetableExport export, _Style s) {
  final detailed = s.detailed;
  final rows = <List<String>>[];
  for (final c in export.courses) {
    final slots = [
      for (final x in export.slots)
        if (x.course == c) x,
    ];
    final specials = [
      for (final x in export.specials)
        if (x.course == c) x,
    ];
    final times = [
      for (final x in slots) x.describe(),
      if (specials.isNotEmpty)
        specials.length == 1
            ? "1 Block-/Sondertermin"
            : "${specials.length} Block-/Sondertermine",
      if (slots.isEmpty && specials.isEmpty) "ohne feste Termine",
    ];
    final notes = [
      if (c.plan.hasOverrides) "* von dir angepasst",
      for (final x in slots)
        if (x.cancelledDates.isNotEmpty)
          "fällt aus: ${x.cancelledDates.map((d) => formatDate(d, withYear: false)).join(", ")}",
      for (final x in slots)
        if (x.missingWeeks.isNotEmpty)
          "ohne Termin: ${x.missingWeeks.map((d) => formatDate(d, withYear: false)).join(", ")}",
      // Kein gleichmäßiger Rhythmus: die tatsächlichen Daten nennen.
      for (final x in slots)
        if (x.kind == SessionKind.series)
          "Termine ${weekdayName(x.weekday, short: true)}: ${x.dates.map((d) => formatDate(d, withYear: false)).join(", ")}",
      for (final x in slots)
        if (x.tentative)
          "${weekdayName(x.weekday, short: true)} ${x.startTime}: ${x.rhythm}; "
              "die Quelle nennt keine Startwoche – bitte in UnivIS prüfen",
      if (c.plan.entry.overrides.note != null) c.plan.entry.overrides.note!,
    ];
    rows.add([
      "${c.number}",
      c.title,
      courseTypeLabel(c.type),
      times.join("\n"),
      c.lecturers.isEmpty ? "–" : c.lecturers.join(", "),
      if (detailed) [c.plan.number ?? "–", ?c.plan.faculty].join("\n"),
      notes.join("\n"),
    ]);
  }
  return _table(
    s,
    [
      "Nr.",
      "Veranstaltung",
      "Art",
      "Termine",
      "Dozent",
      if (detailed) "Nummer / Fakultät",
      "Hinweise",
    ],
    rows,
    {
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(3),
      4: const pw.FlexColumnWidth(1.6),
      if (detailed) 5: const pw.FlexColumnWidth(1.4),
      (detailed ? 6 : 5): const pw.FlexColumnWidth(1.8),
    },
  );
}

pw.Widget _specialTable(TimetableExport export, _Style s) => _table(
  s,
  ["Wann", "Nr.", "Veranstaltung", "Raum", "Hinweis"],
  [
    for (final x in export.specials)
      [
        x.when,
        "${x.course.number}",
        x.course.title,
        x.occurrence.room ?? "–",
        [
          if (x.occurrence.cancelled) "fällt aus",
          if (x.occurrence.adjusted) "* angepasst",
          if (x.conflict) "! Überschneidung",
        ].join(", "),
      ],
  ],
  {
    0: const pw.FlexColumnWidth(2.4),
    1: const pw.FixedColumnWidth(22),
    2: const pw.FlexColumnWidth(3),
    3: const pw.FlexColumnWidth(1.4),
    4: const pw.FlexColumnWidth(1.4),
  },
);

pw.Widget _conflictTable(TimetableExport export, _Style s) => _table(
  s,
  ["Wann", "Dauer", "Beteiligte Veranstaltungen"],
  [
    for (final g in export.conflicts)
      [
        "${weekdayName(g.weekday, short: true)} ${timeRange(g.startTime, g.endTime)}\n"
            "${g.recurring ? "an ${g.dates.length} Terminen (${formatDate(g.dates.first, withYear: false)}–${formatDate(g.dates.last)})" : "am ${formatDate(g.first.date)}"}",
        _duration(g.first),
        [
          for (final id in g.entryIds)
            if (export.courseOf(id) case final c?) "[${c.number}] ${c.title}",
        ].join("\n"),
      ],
  ],
  {
    0: const pw.FlexColumnWidth(2),
    1: const pw.FlexColumnWidth(0.8),
    2: const pw.FlexColumnWidth(4),
  },
);

String _duration(ConflictSpot spot) {
  final m = spot.duration.inMinutes;
  final h = m ~/ 60;
  if (h == 0) return "$m Min.";
  return m % 60 == 0 ? "$h Std." : "$h Std. ${m % 60} Min.";
}

/// Alle Texte, die im PDF erscheinen (für die Prüfung der Schriftabdeckung).
Iterable<String> exportTexts(TimetableExport export) sync* {
  yield export.title;
  if (export.subtitle != null) yield export.subtitle!;
  for (final c in export.courses) {
    yield c.title;
    yield* c.lecturers;
    yield courseTypeLabel(c.type);
    if (c.plan.faculty != null) yield c.plan.faculty!;
  }
  for (final x in export.slots) {
    yield x.describe();
  }
  for (final x in export.specials) {
    yield x.when;
    if (x.occurrence.room != null) yield x.occurrence.room!;
  }
  for (final d in const [1, 2, 3, 4, 5, 6, 7]) {
    yield weekdayName(d);
  }
  yield "Überschneidungen · Block- und Sondertermine · fällt aus · „Hinweis“ – …";
}
