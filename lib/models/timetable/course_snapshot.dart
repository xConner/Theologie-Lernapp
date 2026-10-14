import 'course_catalog.dart';

// Eigenständige Beschreibung einer Veranstaltung: alles, was Anzeige und
// Wochenplan brauchen, unabhängig davon, aus welchem Katalog sie stammt
// (Fakultätskatalog oder fakultätsübergreifende UnivIS-Suche). Wird mit dem
// Stundenplaneintrag gespeichert, damit Veranstaltungen anderer Fakultäten
// auch ohne erneute Suche (und offline) angezeigt werden können.
//
// Enthält nur öffentliche Katalogdaten (wie `/api/catalog`): Titel, Termine,
// Räume, Anzeigenamen der Lehrenden – keine Freitexte.

String? _opt(Object? v) => v is String && v.isNotEmpty ? v : null;
List<String> _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String) e,
      ]
    : const [];
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

/// Terminregel mit aufgelöstem Raumnamen.
class SnapshotRule {
  final SessionRule rule;

  /// Anzeigename des Raums (falls bekannt).
  final String? room;

  const SnapshotRule(this.rule, {this.room});

  String get id => rule.id;

  Map<String, dynamic> toMap() => {...rule.toJson(), "room": ?room};

  static SnapshotRule? tryFromMap(Map<String, dynamic> map) {
    if (_opt(map["id"]) == null) return null;
    return SnapshotRule(SessionRule.fromJson(map), room: _opt(map["room"]));
  }
}

/// Ein konkreter Termin, halboffenes Intervall [start, end).
class SnapshotOccurrence {
  final String ruleId;
  final LocalDateTime start;
  final LocalDateTime end;
  final String? room;
  final bool cancelled;

  const SnapshotOccurrence({
    required this.ruleId,
    required this.start,
    required this.end,
    this.room,
    this.cancelled = false,
  });

  Map<String, dynamic> toMap() => {
    "ruleId": ruleId,
    "start": start.toIso(),
    "end": end.toIso(),
    "room": ?room,
    if (cancelled) "cancelled": true,
  };

  static SnapshotOccurrence? tryFromMap(Map<String, dynamic> map) {
    final start = LocalDateTime.tryParse(map["start"]);
    final end = LocalDateTime.tryParse(map["end"]);
    if (start == null || end == null || !end.instant.isAfter(start.instant)) {
      return null;
    }
    return SnapshotOccurrence(
      ruleId: _opt(map["ruleId"]) ?? "",
      start: start,
      end: end,
      room: _opt(map["room"]),
      cancelled: map["cancelled"] == true,
    );
  }
}

/// Hinweis zu den Terminen (Code der Verarbeitung, z. B. `no-rules`).
class SnapshotNote {
  final String code;
  final bool warning;
  final String detail;

  const SnapshotNote(this.code, {this.warning = false, this.detail = ""});

  ScheduleNote asScheduleNote(String courseId) => ScheduleNote(
    courseId: courseId,
    code: code,
    warning: warning,
    detail: detail,
  );
}

class CourseSnapshot {
  static const int version = 1;

  final String courseId;
  final String semesterId;
  final List<SourceRef> sources;
  final String title;
  final String? number;
  final String? type;
  final num? sws;
  final num? ects;
  final List<String> organizations;
  final List<String> organizationPath;
  final List<String> classification;
  final List<String> moduleCodes;
  final List<String> lecturers;
  final List<SnapshotRule> rules;
  final List<SnapshotOccurrence> occurrences;
  final List<SnapshotNote> notes;
  final String? detailUrl;

  /// Semesterrahmen (Vorlesungszeit, unterrichtsfreie Tage) für eigene
  /// Termine.
  final CatalogSemester? semester;

  /// Zeitpunkt des Abrufs bei der Quelle.
  final DateTime? fetchedAt;

  /// Aus dem vollständigen Fakultätskatalog (sonst aus der
  /// fakultätsübergreifenden Suche). Nur Veranstaltungen des
  /// Fakultätskatalogs werden bei jedem Laden mit der Quelle abgeglichen.
  final bool fromFacultyCatalog;

  const CourseSnapshot({
    required this.courseId,
    required this.semesterId,
    required this.title,
    this.sources = const [],
    this.number,
    this.type,
    this.sws,
    this.ects,
    this.organizations = const [],
    this.organizationPath = const [],
    this.classification = const [],
    this.moduleCodes = const [],
    this.lecturers = const [],
    this.rules = const [],
    this.occurrences = const [],
    this.notes = const [],
    this.detailUrl,
    this.semester,
    this.fetchedAt,
    this.fromFacultyCatalog = false,
  });

  /// Aus einem Katalog (Fakultätskatalog oder Suchergebnis).
  factory CourseSnapshot.fromCatalog(
    CourseCatalog catalog,
    CatalogCourse course, {
    bool fromFacultyCatalog = false,
  }) {
    String? roomOf(String? id) => id == null ? null : catalog.rooms[id]?.label;
    return CourseSnapshot(
      courseId: course.id,
      semesterId: course.semesterId.isNotEmpty
          ? course.semesterId
          : catalog.semester.id,
      sources: course.sources,
      title: course.title,
      number: course.number,
      type: course.type,
      sws: course.sws,
      ects: course.ects,
      organizations: course.organizations,
      organizationPath: course.organizationPath,
      classification: course.classification,
      moduleCodes: course.moduleCodes,
      lecturers: catalog.lecturerNames(course),
      rules: [
        for (final r in course.rules) SnapshotRule(r, room: roomOf(r.roomId)),
      ],
      occurrences: [
        for (final o in catalog.occurrencesOf(course.id))
          SnapshotOccurrence(
            ruleId: o.ruleId,
            start: o.start,
            end: o.end,
            room: roomOf(o.roomId),
            cancelled: o.cancelled,
          ),
      ],
      notes: [
        for (final n in catalog.notesOf(course.id))
          SnapshotNote(n.code, warning: n.warning, detail: n.detail),
      ],
      detailUrl: course.detailUrl,
      semester: catalog.semester,
      fetchedAt: catalog.provenance.fetchedAt,
      fromFacultyCatalog: fromFacultyCatalog,
    );
  }

  String? get faculty =>
      organizationPath.isNotEmpty ? organizationPath.first : null;

  String? get institute => organizationPath.length > 1
      ? organizationPath[1]
      : organizations.firstOrNull;

  /// Räume aller Regeln (ohne Dopplungen).
  List<String> get rooms => {for (final r in rules) ?r.room}.toList();

  bool sharesSourceWith(Iterable<SourceRef> other) =>
      other.any(sources.contains);

  String get scheduleSignature =>
      scheduleSignatureOfRules([for (final r in rules) r.rule]);

  Map<String, dynamic> toMap() => {
    "v": version,
    "title": title,
    "number": ?number,
    "type": ?type,
    "sws": ?sws,
    "ects": ?ects,
    if (organizations.isNotEmpty) "organizations": organizations,
    if (organizationPath.isNotEmpty) "organizationPath": organizationPath,
    if (classification.isNotEmpty) "classification": classification,
    if (moduleCodes.isNotEmpty) "moduleCodes": moduleCodes,
    if (lecturers.isNotEmpty) "lecturers": lecturers,
    "rules": [for (final r in rules) r.toMap()],
    "occurrences": [for (final o in occurrences) o.toMap()],
    if (notes.isNotEmpty)
      "notes": [
        for (final n in notes)
          {"code": n.code, if (n.warning) "warning": true, "detail": n.detail},
      ],
    "detailUrl": ?detailUrl,
    if (semester != null) "semester": semester!.toJson(),
    if (fetchedAt != null) "fetchedAt": fetchedAt!.toUtc().toIso8601String(),
    "catalog": fromFacultyCatalog ? "faculty" : "search",
  };

  /// Gespeicherte Form lesen; Kennung, Semester und Quellen kommen aus dem
  /// Eintrag. Unbrauchbar → null.
  static CourseSnapshot? tryFromMap(
    Object? raw, {
    required String courseId,
    required String semesterId,
    List<SourceRef> sources = const [],
  }) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final title = _opt(map["title"]);
    if (title == null) return null;
    return CourseSnapshot(
      courseId: courseId,
      semesterId: semesterId,
      sources: sources,
      title: title,
      number: _opt(map["number"]),
      type: _opt(map["type"]),
      sws: map["sws"] is num ? map["sws"] as num : null,
      ects: map["ects"] is num ? map["ects"] as num : null,
      organizations: _strings(map["organizations"]),
      organizationPath: _strings(map["organizationPath"]),
      classification: _strings(map["classification"]),
      moduleCodes: _strings(map["moduleCodes"]),
      lecturers: _strings(map["lecturers"]),
      rules: [for (final r in _maps(map["rules"])) ?SnapshotRule.tryFromMap(r)],
      occurrences: [
        for (final o in _maps(map["occurrences"]))
          ?SnapshotOccurrence.tryFromMap(o),
      ]..sort((a, b) => a.start.instant.compareTo(b.start.instant)),
      notes: [
        for (final n in _maps(map["notes"]))
          if (_opt(n["code"]) != null)
            SnapshotNote(
              n["code"] as String,
              warning: n["warning"] == true,
              detail: _opt(n["detail"]) ?? "",
            ),
      ],
      detailUrl: _opt(map["detailUrl"]),
      semester: map["semester"] is Map
          ? CatalogSemester.fromJson(
              Map<String, dynamic>.from(map["semester"] as Map),
            )
          : null,
      fetchedAt: DateTime.tryParse(_opt(map["fetchedAt"]) ?? ""),
      fromFacultyCatalog: map["catalog"] == "faculty",
    );
  }
}

/// Vergleichbare Kurzform von Terminregeln (Art, Wochentage, Uhrzeiten,
/// Zeitraum, Raum; ohne Ausfälle).
String scheduleSignatureOfRules(Iterable<SessionRule> rules) {
  final parts = [
    for (final r in rules)
      [
        r.kind.name,
        r.intervalWeeks ?? "",
        r.weekdays.join(","),
        r.startTime ?? "",
        r.endTime ?? "",
        r.startDate ?? "",
        r.endDate ?? "",
        r.roomId ?? "",
      ].join("|"),
  ]..sort();
  return parts.join(";");
}
