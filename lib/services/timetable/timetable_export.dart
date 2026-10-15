import '../../models/timetable/course_catalog.dart';
import 'course_labels.dart';
import 'plan_conflicts.dart';
import 'plan_schedule.dart';
import 'timetable_schedule.dart';
import 'week_layout.dart';

// Inhalt des druckbaren Stundenplans – unabhängig vom PDF. Grundlage ist
// derselbe aufgelöste Plan wie in der App ([PlanCourse]: Import plus
// persönliche Anpassungen) mit denselben Konflikt- und Rasterfunktionen
// (plan_conflicts.dart, week_layout.dart). Es gibt keine eigene
// Terminberechnung: Wochenmuster werden aus den konkreten Terminen
// zusammengefasst, nicht aus Regeln neu berechnet.
//
// * Regelmäßige Termine erscheinen im Wochenraster einmal je Muster
//   (Wochentag, Uhrzeit, Raum) mit Zeitraum und Anzahl; finden sie nicht in
//   jeder Vorlesungswoche statt oder fallen sie aus, steht das in der
//   Veranstaltungsliste.
// * Die Art der Termine kommt aus plan_schedule.dart ([SessionKind]), wie in
//   der Wochenansicht und im Filter: Auch nicht wöchentliche Serien
//   (14-täglich, wiederkehrende Einzeltermine, Wochen unbekannt) stehen im
//   Raster, mit ihrem Rhythmus.
// * Block- und Einzeltermine stehen mit Datum in einer eigenen Liste.
// * Überschneidungen: dieselben Stellen wie in der App.

/// Was exportiert wird.
enum ExportContent {
  all("Regelmäßige und Sondertermine"),
  regular("Nur regelmäßige Veranstaltungen"),
  special("Nur Block- und Sondertermine");

  final String label;
  const ExportContent(this.label);

  /// Voreinstellung passend zum Filter der Wochenansicht.
  static ExportContent fromFilter(SessionKindFilter filter) => switch (filter) {
    SessionKindFilter.all => ExportContent.all,
    SessionKindFilter.regular => ExportContent.regular,
    SessionKindFilter.special => ExportContent.special,
  };

  bool get includesRegular => this != ExportContent.special;
  bool get includesSpecial => this != ExportContent.regular;
}

enum ExportOrientation {
  landscape("Querformat"),
  portrait("Hochformat");

  final String label;
  const ExportOrientation(this.label);
}

enum ExportDetail {
  compact("Kompakt"),
  detailed("Ausführlich");

  final String label;
  const ExportDetail(this.label);
}

enum ExportColors {
  color("Dezente Farben"),
  blackWhite("Schwarz-Weiß");

  final String label;
  const ExportColors(this.label);
}

/// Einstellungen des Exports. Die Voreinstellungen ergeben ohne weitere
/// Wahl einen gut lesbaren Plan (A4 quer, kompakt, dezente Farben).
class TimetableExportOptions {
  final ExportOrientation orientation;
  final ExportDetail detail;
  final ExportColors colors;
  final ExportContent content;

  /// Überschrift; leer → „Stundenplan – Semester“.
  final String title;

  /// Freie Zusatzzeile (z. B. Studiengang) – nur, wenn der Nutzer sie
  /// einträgt.
  final String subtitle;
  final bool showExportDate;
  final bool showLegend;

  const TimetableExportOptions({
    this.orientation = ExportOrientation.landscape,
    this.detail = ExportDetail.compact,
    this.colors = ExportColors.color,
    this.content = ExportContent.all,
    this.title = "",
    this.subtitle = "",
    this.showExportDate = true,
    this.showLegend = true,
  });

  TimetableExportOptions copyWith({
    ExportOrientation? orientation,
    ExportDetail? detail,
    ExportColors? colors,
    ExportContent? content,
    String? title,
    String? subtitle,
    bool? showExportDate,
    bool? showLegend,
  }) => TimetableExportOptions(
    orientation: orientation ?? this.orientation,
    detail: detail ?? this.detail,
    colors: colors ?? this.colors,
    content: content ?? this.content,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    showExportDate: showExportDate ?? this.showExportDate,
    showLegend: showLegend ?? this.showLegend,
  );
}

/// Eine Veranstaltung des Exports mit laufender Nummer (Verweis zwischen
/// Raster und Liste).
class ExportCourse {
  final int number;
  final PlanCourse plan;

  /// Farbindex (0 … [exportPaletteSize] − 1), je Veranstaltung fest.
  final int colorIndex;

  const ExportCourse(this.number, this.plan, this.colorIndex);

  String get title => plan.title;
  String? get type => plan.imported?.type;
  List<String> get lecturers => plan.lecturers;
}

/// Ein wiederkehrender Termin (zusammengefasst aus den konkreten Terminen
/// derselben Serie mit gleichem Wochentag, gleicher Uhrzeit und gleichem
/// Raum) – wöchentlich oder in anderem Rhythmus ([kind]).
class RecurringSlot {
  final ExportCourse course;

  /// [SessionKind.weekly], [SessionKind.recurring], [SessionKind.series] oder
  /// [SessionKind.tentative] (Wochen unbekannt).
  final SessionKind kind;

  /// „14-täglich“ usw.; null bei wöchentlichen Terminen.
  final String? rhythm;
  final int weekday;
  final String startTime;
  final String endTime;
  final String? room;

  /// Stattfindende Daten (ohne Ausfälle), sortiert.
  final List<String> dates;

  /// Als Ausfall eingetragene Daten.
  final List<String> cancelledDates;

  /// Nur bei wöchentlichen Terminen: Vorlesungswochen zwischen erstem und
  /// letztem Termin ohne Termin (ohne unterrichtsfreie Zeit).
  final List<String> missingWeeks;
  final bool adjusted;

  /// Mindestens ein Termin dieses Musters überschneidet sich.
  final bool conflict;

  /// Repräsentativer Termin (für das Raster).
  final PlanOccurrence sample;

  const RecurringSlot({
    required this.course,
    this.kind = SessionKind.weekly,
    this.rhythm,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.dates,
    required this.cancelledDates,
    required this.missingWeeks,
    required this.adjusted,
    required this.conflict,
    required this.sample,
  });

  String get firstDate => dates.isNotEmpty ? dates.first : sample.date;
  String get lastDate => dates.isNotEmpty ? dates.last : sample.date;

  /// Wöchentlich und jede Vorlesungswoche zwischen erstem und letztem
  /// Termin.
  bool get everyWeek => kind == SessionKind.weekly && missingWeeks.isEmpty;

  bool get tentative => kind == SessionKind.tentative;

  /// „Di 10:15–11:45 · Hörsaal 1 · 13.10.–2.2.2027 (14 Termine)“,
  /// „… (8 Termine, 14-täglich)“; bei unbekannten Wochen ohne Daten.
  String describe({bool withRoom = true}) {
    final note = rhythm ?? (everyWeek ? null : "nicht jede Woche");
    final parts = [
      "${weekdayName(weekday, short: true)} ${timeRange(startTime, endTime)}",
      if (withRoom && room != null) room!,
      if (tentative)
        "$rhythm (Startwoche in der Quelle nicht angegeben)"
      else if (dates.length <= 1)
        "am ${formatDate(firstDate)}"
      else
        "${formatDate(firstDate, withYear: false)}–${formatDate(lastDate)} "
            "(${dates.length} Termine${note == null ? "" : ", $note"})",
    ];
    return parts.join(" · ");
  }
}

/// Ein Block- bzw. Einzeltermin.
class SpecialDate {
  final ExportCourse course;
  final PlanOccurrence occurrence;
  final bool conflict;

  const SpecialDate(this.course, this.occurrence, this.conflict);

  String get when {
    final o = occurrence;
    if (o.spansDays) {
      return "${weekdayName(weekdayOf(o.start.date), short: true)} "
          "${formatDate(o.start.date)} ${o.start.time} – "
          "${weekdayName(weekdayOf(o.end.date), short: true)} "
          "${formatDate(o.end.date)} ${o.end.time}";
    }
    return "${weekdayName(weekdayOf(o.date), short: true)} ${formatDate(o.date)}, "
        "${timeRange(o.start.time, o.end.time)}";
  }
}

/// Ein Block im Wochenraster (Spur wie in der App).
class GridBlock {
  final RecurringSlot slot;
  final int startMinute;
  final int endMinute;
  final int lane;
  final int lanes;

  const GridBlock(
    this.slot,
    this.startMinute,
    this.endMinute,
    this.lane,
    this.lanes,
  );
}

class TimetableExport {
  final String title;
  final String? subtitle;
  final String? semesterLabel;
  final TimetableExportOptions options;
  final List<ExportCourse> courses;
  final List<RecurringSlot> slots;
  final List<SpecialDate> specials;

  /// Überschneidungsstellen (gruppiert wie in der App).
  final List<ConflictGroup> conflicts;

  /// ISO-Wochentag → Blöcke im Raster.
  final Map<int, List<GridBlock>> grid;
  final int firstMinute;
  final int lastMinute;

  /// Veranstaltungen ohne Termine im Export (z. B. ohne feste Termine).
  final List<ExportCourse> withoutDates;
  final DateTime exportedAt;

  const TimetableExport({
    required this.title,
    required this.subtitle,
    required this.semesterLabel,
    required this.options,
    required this.courses,
    required this.slots,
    required this.specials,
    required this.conflicts,
    required this.grid,
    required this.firstMinute,
    required this.lastMinute,
    required this.withoutDates,
    required this.exportedAt,
  });

  bool get isEmpty => courses.isEmpty;
  bool get hasGrid => slots.isNotEmpty;

  /// Spalten des Rasters: Mo–Fr, Wochenende nur mit Terminen.
  List<int> get weekdays => [
    for (var d = 1; d <= 7; d++)
      if (d <= 5 || (grid[d]?.isNotEmpty ?? false)) d,
  ];

  ExportCourse? courseOf(String entryId) =>
      courses.where((c) => c.plan.id == entryId).firstOrNull;
}

/// Anzahl der Farben im Export (je Veranstaltung reihum).
const int exportPaletteSize = 8;

/// Baut den Export aus dem aufgelösten Plan. Verändert nichts.
TimetableExport buildTimetableExport({
  required List<PlanCourse> plan,
  required TimetableExportOptions options,
  CatalogSemester? semester,
  DateTime? now,
}) {
  final sorted = [...plan]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  bool accepted(PlanOccurrence o) => o.regular
      ? options.content.includesRegular
      : options.content.includesSpecial;

  // Nur Veranstaltungen mit Terminen im gewählten Inhalt (bzw. ganz ohne
  // Termine – sie werden gesondert genannt, sofern regelmäßige gezeigt werden).
  final relevant = [
    for (final p in sorted)
      if (p.occurrences.any(accepted) ||
          (p.occurrences.isEmpty && options.content.includesRegular))
        p,
  ];
  final courses = [
    for (final (i, p) in relevant.indexed)
      ExportCourse(i + 1, p, i % exportPaletteSize),
  ];
  final byId = {for (final c in courses) c.plan.id: c};

  final occurrences = [
    for (final c in courses)
      for (final o in c.plan.occurrences)
        if (accepted(o)) o,
  ];
  final spots = conflictSpots(occurrences);
  final conflicting = conflictingOccurrenceIds(spots);

  // Regelmäßige Termine je Regel und Muster zusammenfassen.
  final groups = <String, List<PlanOccurrence>>{};
  for (final o in occurrences) {
    if (!o.regular || o.spansDays) continue;
    final key = [
      o.entryId,
      o.seriesId,
      weekdayOf(o.date),
      o.start.time,
      o.end.time,
      o.room ?? "",
    ].join("|");
    (groups[key] ??= []).add(o);
  }
  final slots = <RecurringSlot>[];
  for (final list in groups.values) {
    list.sort((a, b) => a.start.instant.compareTo(b.start.instant));
    final first = list.first;
    final held = [
      for (final o in list)
        if (!o.cancelled) o.date,
    ];
    final cancelled = [
      for (final o in list)
        if (o.cancelled) o.date,
    ];
    final all = [for (final o in list) o.date];
    slots.add(
      RecurringSlot(
        course: byId[first.entryId]!,
        kind: first.kind,
        rhythm: rhythmLabel(first),
        weekday: weekdayOf(first.date),
        startTime: first.start.time,
        endTime: first.end.time,
        room: first.room,
        // Unsichere Termine sind keine Daten.
        dates: first.tentative ? const [] : held,
        cancelledDates: cancelled,
        missingWeeks: semester == null || first.kind != SessionKind.weekly
            ? const []
            : _missingWeeks(all, semester),
        adjusted: list.any((o) => o.adjusted),
        conflict: list.any((o) => conflicting.contains(o.id)),
        sample: first,
      ),
    );
  }
  slots.sort((a, b) {
    final d = a.weekday.compareTo(b.weekday);
    if (d != 0) return d;
    final t = a.startTime.compareTo(b.startTime);
    return t != 0 ? t : a.course.number.compareTo(b.course.number);
  });

  // Mehrtägige wöchentliche Termine passen nicht ins Raster → Liste.
  final specials =
      [
        for (final o in occurrences)
          if (!o.regular || o.spansDays)
            SpecialDate(byId[o.entryId]!, o, conflicting.contains(o.id)),
      ]..sort(
        (a, b) =>
            a.occurrence.start.instant.compareTo(b.occurrence.start.instant),
      );

  // Raster mit denselben Spuren wie die Wochenansicht.
  var first = 24 * 60;
  var last = 0;
  final perDay = <int, List<DayBlock>>{};
  final slotOf = <String, RecurringSlot>{};
  for (final s in slots) {
    final start = s.sample.start.minuteOfDay;
    final end = s.sample.end.minuteOfDay;
    if (end <= start) continue;
    if (start < first) first = start;
    if (end > last) last = end;
    final blockId = "${s.sample.id}#slot";
    slotOf[blockId] = s;
    (perDay[s.weekday] ??= []).add(
      DayBlock(
        occurrence: PlanOccurrence(
          id: blockId,
          entryId: s.sample.entryId,
          ruleId: s.sample.ruleId,
          start: s.sample.start,
          end: s.sample.end,
        ),
        startMinute: start,
        endMinute: end,
        lane: 0,
        lanes: 1,
      ),
    );
  }
  if (slots.isEmpty) {
    first = 8 * 60;
    last = 18 * 60;
  }
  final grid = <int, List<GridBlock>>{
    for (final e in perDay.entries)
      e.key: [
        for (final b in assignLanes(e.value))
          GridBlock(
            slotOf[b.occurrence.id]!,
            b.startMinute,
            b.endMinute,
            b.lane,
            b.lanes,
          ),
      ],
  };

  final title = options.title.trim().isNotEmpty
      ? options.title.trim()
      : semester == null
      ? "Stundenplan"
      : "Stundenplan – ${semester.label}";

  return TimetableExport(
    title: title,
    subtitle: options.subtitle.trim().isEmpty ? null : options.subtitle.trim(),
    semesterLabel: semester?.label,
    options: options,
    courses: courses,
    slots: slots,
    specials: specials,
    conflicts: groupConflicts(spots),
    grid: grid,
    // Volle Stunden um die tatsächlichen Termine.
    firstMinute: (first ~/ 60) * 60,
    lastMinute: ((last + 59) ~/ 60) * 60,
    withoutDates: [
      for (final c in courses)
        if (c.plan.occurrences.isEmpty) c,
    ],
    exportedAt: now ?? DateTime.now(),
  );
}

/// Wochen (Montage) zwischen erstem und letztem Termin ohne Termin dieses
/// Musters, ohne Wochen, deren Termin in die unterrichtsfreie Zeit fiele.
List<String> _missingWeeks(List<String> dates, CatalogSemester semester) {
  if (dates.length < 2) return const [];
  final weekday = weekdayOf(dates.first);
  final have = {for (final d in dates) mondayOf(d)};
  final missing = <String>[];
  for (
    var m = mondayOf(dates.first);
    m.compareTo(mondayOf(dates.last)) <= 0;
    m = addDays(m, 7)
  ) {
    if (have.contains(m)) continue;
    final day = addDays(m, weekday - 1);
    if (breakOn(semester, day) != null) continue;
    missing.add(day);
  }
  return missing;
}

/// Dateiname, z. B. `stundenplan-wintersemester-2026-27.pdf`.
String exportFileName(TimetableExport export) {
  final base = (export.semesterLabel ?? "")
      .toLowerCase()
      .replaceAll("ä", "ae")
      .replaceAll("ö", "oe")
      .replaceAll("ü", "ue")
      .replaceAll("ß", "ss")
      .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
      .replaceAll(RegExp(r"^-+|-+$"), "");
  return base.isEmpty ? "stundenplan.pdf" : "stundenplan-$base.pdf";
}
