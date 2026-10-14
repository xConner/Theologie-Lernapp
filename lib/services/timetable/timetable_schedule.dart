import '../../models/timetable/course_catalog.dart';

/// Zwei sich überschneidende Termine. Intervalle sind halboffen
/// [start, end): Endet ein Termin um 10:00 und beginnt der nächste um 10:00,
/// ist das keine Überschneidung. Abgesagte Termine zählen nicht.
class OccurrenceConflict {
  final CourseOccurrence a;
  final CourseOccurrence b;

  const OccurrenceConflict(this.a, this.b);

  Duration get overlap {
    final end = a.end.instant.isBefore(b.end.instant)
        ? a.end.instant
        : b.end.instant;
    final start = a.start.instant.isAfter(b.start.instant)
        ? a.start.instant
        : b.start.instant;
    return end.difference(start);
  }
}

/// Alle Paare sich überschneidender Termine verschiedener Veranstaltungen
/// (Sweep über die nach Beginn sortierten Termine).
List<OccurrenceConflict> findConflicts(Iterable<CourseOccurrence> occurrences) {
  final items = occurrences.where((o) => !o.cancelled).toList()
    ..sort((x, y) => x.start.instant.compareTo(y.start.instant));
  final result = <OccurrenceConflict>[];
  final active = <CourseOccurrence>[];
  for (final item in items) {
    active.removeWhere((o) => !o.end.instant.isAfter(item.start.instant));
    for (final other in active) {
      if (other.courseId != item.courseId) {
        result.add(OccurrenceConflict(other, item));
      }
    }
    active.add(item);
  }
  return result;
}

/// Termine der gewählten Veranstaltungen.
List<CourseOccurrence> occurrencesOfCourses(
  CourseCatalog catalog,
  Iterable<String> courseIds,
) => [for (final id in courseIds) ...catalog.occurrencesOf(id)];

/// Je Veranstaltung: Veranstaltungen, mit denen sie sich mindestens einmal
/// überschneidet, samt Anzahl der betroffenen Termine.
Map<String, Map<String, int>> conflictsByCourse(
  CourseCatalog catalog,
  Iterable<String> courseIds,
) {
  final result = <String, Map<String, int>>{};
  for (final c in findConflicts(occurrencesOfCourses(catalog, courseIds))) {
    final ab = result[c.a.courseId] ??= {};
    ab[c.b.courseId] = (ab[c.b.courseId] ?? 0) + 1;
    final ba = result[c.b.courseId] ??= {};
    ba[c.a.courseId] = (ba[c.a.courseId] ?? 0) + 1;
  }
  return result;
}

/// Überschneidungen von [courseId] mit dem Stundenplan [plannedIds]
/// (Veranstaltung → Anzahl Termine). Für die Anzeige vor dem Hinzufügen.
Map<String, int> conflictsWithPlan(
  CourseCatalog catalog,
  String courseId,
  Iterable<String> plannedIds,
) {
  final ids = {...plannedIds, courseId};
  return conflictsByCourse(catalog, ids)[courseId] ?? const {};
}

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

/// Ein Termin in der Wochenansicht.
class WeekItem {
  final CatalogCourse course;
  final CourseOccurrence occurrence;

  /// Andere Veranstaltungen, mit denen sich genau dieser Termin überschneidet.
  final List<CatalogCourse> conflictsWith;

  const WeekItem(this.course, this.occurrence, this.conflictsWith);

  bool get hasConflict => conflictsWith.isNotEmpty;
}

/// Termine der Woche ab [monday], je ISO-Wochentag nach Beginn sortiert.
/// Mehrtägige Blöcke erscheinen an jedem Tag, den sie berühren.
Map<int, List<WeekItem>> weekSchedule(
  CourseCatalog catalog,
  Iterable<String> courseIds,
  String monday,
) {
  final sunday = addDays(monday, 6);
  final inWeek = [
    for (final o in occurrencesOfCourses(catalog, courseIds))
      if (o.start.date.compareTo(sunday) <= 0 &&
          o.end.date.compareTo(monday) >= 0)
        o,
  ];
  final conflicts = <String, Set<String>>{};
  for (final c in findConflicts(inWeek)) {
    (conflicts[c.a.id] ??= {}).add(c.b.courseId);
    (conflicts[c.b.id] ??= {}).add(c.a.courseId);
  }

  final days = <int, List<WeekItem>>{for (var d = 1; d <= 7; d++) d: []};
  for (final o in inWeek) {
    final course = catalog.courseById(o.courseId);
    if (course == null) continue;
    final others = [
      for (final id in conflicts[o.id] ?? const <String>{})
        ?catalog.courseById(id),
    ];
    for (var d = 0; d < 7; d++) {
      final date = addDays(monday, d);
      if (o.start.date.compareTo(date) <= 0 &&
          o.end.date.compareTo(date) >= 0) {
        days[d + 1]!.add(WeekItem(course, o, others));
      }
    }
  }
  for (final list in days.values) {
    list.sort(
      (x, y) =>
          x.occurrence.start.instant.compareTo(y.occurrence.start.instant),
    );
  }
  return days;
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
