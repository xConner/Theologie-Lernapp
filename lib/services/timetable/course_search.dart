import '../../models/timetable/course_catalog.dart';

/// Such- und Filterkriterien. `null` bzw. leer = kein Filter.
class CourseFilter {
  final String query;
  final String? lecturerId;

  /// Institut bzw. Fachbereich ([CatalogCourse.institutes]).
  final String? organization;

  /// Fakultät ([CatalogCourse.faculty]).
  final String? faculty;
  final String? type;

  /// ISO-Wochentag (1 = Montag).
  final int? weekday;

  const CourseFilter({
    this.query = "",
    this.lecturerId,
    this.organization,
    this.faculty,
    this.type,
    this.weekday,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      lecturerId == null &&
      organization == null &&
      faculty == null &&
      type == null &&
      weekday == null;

  CourseFilter copyWith({
    String? query,
    String? Function()? lecturerId,
    String? Function()? organization,
    String? Function()? faculty,
    String? Function()? type,
    int? Function()? weekday,
  }) => CourseFilter(
    query: query ?? this.query,
    lecturerId: lecturerId != null ? lecturerId() : this.lecturerId,
    organization: organization != null ? organization() : this.organization,
    faculty: faculty != null ? faculty() : this.faculty,
    type: type != null ? type() : this.type,
    weekday: weekday != null ? weekday() : this.weekday,
  );
}

/// Kleinschreibung, Umlaute und ß vereinheitlicht, Satzzeichen als
/// Leerraum: „Übung“ findet „ubung“, „uebung“ und „Übung“.
String normalizeForSearch(String text) {
  var s = text.toLowerCase();
  const replacements = {
    "ä": "a",
    "ö": "o",
    "ü": "u",
    "ß": "ss",
    "ae": "a",
    "oe": "o",
    "ue": "u",
    "á": "a",
    "à": "a",
    "é": "e",
    "è": "e",
    "ê": "e",
  };
  for (final e in replacements.entries) {
    s = s.replaceAll(e.key, e.value);
  }
  return s.replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
}

/// Wochentage, an denen eine Veranstaltung stattfindet (aus den Terminen,
/// ersatzweise aus den Regeln).
Set<int> weekdaysOf(CourseCatalog catalog, CatalogCourse course) {
  final fromOccurrences = {
    for (final o in catalog.occurrencesOf(course.id))
      if (!o.cancelled) weekdayOf(o.date),
  };
  if (fromOccurrences.isNotEmpty) return fromOccurrences;
  return {for (final r in course.rules) ...r.weekdays};
}

bool _matchesQuery(CourseCatalog catalog, CatalogCourse course, String query) {
  final words = normalizeForSearch(query).split(" ").where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = normalizeForSearch(
    [
      course.title,
      course.number ?? "",
      ...course.moduleCodes,
      ...catalog.lecturerNames(course),
      ...course.organizations,
      ...course.organizationPath,
      ...course.classification,
    ].join(" "),
  );
  // Alle Wörter müssen vorkommen (in beliebiger Reihenfolge).
  return words.every(haystack.contains);
}

/// Gefilterte Veranstaltungen, alphabetisch nach Titel.
List<CatalogCourse> filterCourses(CourseCatalog catalog, CourseFilter filter) {
  final result = catalog.courses.where((c) {
    if (filter.lecturerId != null &&
        !c.lecturerIds.contains(filter.lecturerId)) {
      return false;
    }
    if (filter.organization != null &&
        !c.institutes.contains(filter.organization)) {
      return false;
    }
    if (filter.faculty != null && c.faculty != filter.faculty) return false;
    if (filter.type != null && c.type != filter.type) return false;
    if (filter.weekday != null &&
        !weekdaysOf(catalog, c).contains(filter.weekday)) {
      return false;
    }
    return _matchesQuery(catalog, c, filter.query);
  }).toList();
  result.sort(
    (a, b) =>
        normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title)),
  );
  return result;
}

/// Auswahlwerte der Filter – nur, was im Katalog tatsächlich vorkommt.
class CourseFacets {
  /// Lehrperson-Kennung → Name, nach Nachname sortiert.
  final List<CatalogPerson> lecturers;

  /// Institute bzw. Fachbereiche.
  final List<String> organizations;
  final List<String> faculties;
  final List<String> types;
  final List<int> weekdays;

  const CourseFacets({
    required this.lecturers,
    required this.organizations,
    this.faculties = const [],
    required this.types,
    required this.weekdays,
  });

  factory CourseFacets.of(CourseCatalog catalog) {
    final lecturerIds = {for (final c in catalog.courses) ...c.lecturerIds};
    final lecturers =
        [
          for (final id in lecturerIds)
            if (catalog.persons[id] case final p? when p.displayName != null) p,
        ]..sort(
          (a, b) =>
              _surname(a.displayName!).compareTo(_surname(b.displayName!)),
        );
    return CourseFacets(
      lecturers: lecturers,
      organizations: {for (final c in catalog.courses) ...c.institutes}.toList()
        ..sort(),
      faculties: {for (final c in catalog.courses) ?c.faculty}.toList()..sort(),
      types: {for (final c in catalog.courses) ?c.type}.toList()..sort(),
      weekdays: {
        for (final c in catalog.courses) ...weekdaysOf(catalog, c),
      }.toList()..sort(),
    );
  }

  static String _surname(String name) =>
      normalizeForSearch(name.split(" ").last);
}
