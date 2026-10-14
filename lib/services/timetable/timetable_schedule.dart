import '../../models/timetable/course_catalog.dart';

// Wochen und unterrichtsfreie Zeit. Überschneidungen: plan_conflicts.dart,
// Raster: week_layout.dart.

// --- Wochen ------------------------------------------------------------------

DateTime _day(String date) => DateTime.parse("${date}T00:00:00Z");

String _iso(DateTime day) => day.toIso8601String().substring(0, 10);

/// Montag der Woche eines Datums.
String mondayOf(String date) {
  final d = _day(date);
  return _iso(d.subtract(Duration(days: d.weekday - 1)));
}

String addDays(String date, int days) =>
    _iso(_day(date).add(Duration(days: days)));

/// Montage aller Wochen des Semesters (Semesterbeginn bis -ende).
List<String> semesterWeeks(CatalogSemester semester) {
  final weeks = <String>[];
  for (
    var m = mondayOf(semester.start);
    m.compareTo(semester.end) <= 0;
    m = addDays(m, 7)
  ) {
    weeks.add(m);
  }
  return weeks;
}

/// Woche, die zuerst gezeigt wird: die aktuelle, wenn sie im Semester liegt,
/// sonst die erste Vorlesungswoche.
String initialWeek(CatalogSemester semester, DateTime today) {
  final todayIso = _iso(DateTime.utc(today.year, today.month, today.day));
  if (todayIso.compareTo(semester.start) >= 0 &&
      todayIso.compareTo(semester.end) <= 0) {
    return mondayOf(todayIso);
  }
  return mondayOf(semester.lectureStart);
}

/// Unterrichtsfreie Zeit, in der ein Datum liegt.
SemesterBreak? breakOn(CatalogSemester semester, String date) {
  for (final b in semester.breaks) {
    if (date.compareTo(b.start) >= 0 && date.compareTo(b.end) <= 0) return b;
  }
  return null;
}

/// Unterrichtsfreie Zeiträume, die die Woche ab [monday] berühren.
List<SemesterBreak> breaksInWeek(CatalogSemester semester, String monday) {
  final sunday = addDays(monday, 6);
  return [
    for (final b in semester.breaks)
      if (b.start.compareTo(sunday) <= 0 && b.end.compareTo(monday) >= 0) b,
  ];
}
