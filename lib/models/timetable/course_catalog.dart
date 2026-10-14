// Veranstaltungskatalog – quellneutral. Das Format entspricht dem
// `CatalogSnapshot` der Serververarbeitung (api/_lib/catalog/model.ts):
// Die App sieht nie UnivIS-XML, sondern nur diese normalisierten Daten.
// Einzeltermine sind bereits aufgelöst; die App rechnet keine
// Wiederholungsregeln selbst aus.
//
// Zeiten: `start`/`end` tragen den Offset der Quelle (Europe/Berlin). Für die
// Anzeige werden Datum und Uhrzeit direkt aus dem Text gelesen – so stimmt
// die Kieler Ortszeit auch auf Geräten in anderen Zeitzonen. Vergleiche
// (Überschneidungen) laufen über den absoluten Zeitpunkt.

/// Ortszeit einer Zeitangabe mit Offset, z. B. `2026-10-22T16:15:00+02:00`.
class LocalDateTime {
  /// `YYYY-MM-DD`.
  final String date;

  /// `HH:MM`.
  final String time;

  /// Absoluter Zeitpunkt (UTC).
  final DateTime instant;

  const LocalDateTime(this.date, this.time, this.instant);

  /// Abstand der Ortszeit zu UTC (z. B. +2 h in der Sommerzeit).
  Duration get offset =>
      DateTime.parse("${date}T$time:00Z").difference(instant);

  /// Zurück ins Austauschformat, z. B. `2026-10-22T16:15:00+02:00`.
  String toIso() {
    final minutes = offset.inMinutes;
    final sign = minutes < 0 ? "-" : "+";
    final abs = minutes.abs();
    String two(int n) => n.toString().padLeft(2, "0");
    return "${date}T$time:00$sign${two(abs ~/ 60)}:${two(abs % 60)}";
  }

  /// Minuten seit Mitternacht (Ortszeit).
  int get minuteOfDay {
    final parts = time.split(":");
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static final RegExp _pattern = RegExp(
    r"^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?(Z|[+-]\d{2}:\d{2})$",
  );

  static LocalDateTime? tryParse(Object? raw) {
    if (raw is! String) return null;
    final match = _pattern.firstMatch(raw);
    final instant = DateTime.tryParse(raw);
    if (match == null || instant == null) return null;
    return LocalDateTime(match.group(1)!, match.group(2)!, instant.toUtc());
  }
}

/// ISO-Wochentag eines Datums `YYYY-MM-DD` (1 = Montag … 7 = Sonntag).
int weekdayOf(String date) => DateTime.parse("${date}T12:00:00Z").weekday;

String _string(Object? v) => v is String ? v : "";
String? _optString(Object? v) => v is String && v.isNotEmpty ? v : null;
num? _num(Object? v) => v is num ? v : null;
List<String> _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String) e,
      ]
    : const [];
List<int> _ints(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is num) e.toInt(),
      ]
    : const [];
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

class SourceRef {
  final String sourceId;
  final String key;

  const SourceRef(this.sourceId, this.key);

  factory SourceRef.fromJson(Map<String, dynamic> json) =>
      SourceRef(_string(json["sourceId"]), _string(json["key"]));

  Map<String, dynamic> toJson() => {"sourceId": sourceId, "key": key};

  @override
  bool operator ==(Object other) =>
      other is SourceRef && other.sourceId == sourceId && other.key == key;

  @override
  int get hashCode => Object.hash(sourceId, key);
}

class CatalogPerson {
  final String id;
  final String? displayName;

  const CatalogPerson({required this.id, this.displayName});

  factory CatalogPerson.fromJson(Map<String, dynamic> json) => CatalogPerson(
    id: _string(json["id"]),
    displayName: _optString(json["displayName"]),
  );
}

class CatalogRoom {
  final String id;
  final String? shortName;
  final String? name;
  final bool online;

  const CatalogRoom({
    required this.id,
    this.shortName,
    this.name,
    this.online = false,
  });

  factory CatalogRoom.fromJson(Map<String, dynamic> json) => CatalogRoom(
    id: _string(json["id"]),
    shortName: _optString(json["shortName"]),
    name: _optString(json["name"]),
    online: json["online"] == true,
  );

  /// Kurzbezeichnung für Listen, sonst der volle Name.
  String get label => shortName ?? name ?? "Raum unbekannt";
}

/// Unterrichtsfreier Zeitraum (inklusive).
class SemesterBreak {
  final String start;
  final String end;
  final String label;

  const SemesterBreak(this.start, this.end, this.label);
}

class CatalogSemester {
  final String id;
  final String label;
  final String start;
  final String end;
  final String lectureStart;
  final String lectureEnd;
  final List<SemesterBreak> breaks;

  const CatalogSemester({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.lectureStart,
    required this.lectureEnd,
    this.breaks = const [],
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "label": label,
    "start": start,
    "end": end,
    "lectureStart": lectureStart,
    "lectureEnd": lectureEnd,
    "breaks": [
      for (final b in breaks)
        {"start": b.start, "end": b.end, "label": b.label},
    ],
  };

  factory CatalogSemester.fromJson(Map<String, dynamic> json) =>
      CatalogSemester(
        id: _string(json["id"]),
        label: _string(json["label"]),
        start: _string(json["start"]),
        end: _string(json["end"]),
        lectureStart: _string(json["lectureStart"]),
        lectureEnd: _string(json["lectureEnd"]),
        breaks: [
          for (final b in _maps(json["breaks"]))
            SemesterBreak(
              _string(b["start"]),
              _string(b["end"]),
              _string(b["label"]),
            ),
        ],
      );
}

enum RepeatKind { weekly, single, block, unknown }

/// Terminangabe einer Veranstaltung, wie die Quelle sie macht.
class SessionRule {
  final String id;
  final RepeatKind kind;
  final int? intervalWeeks;

  /// ISO-Wochentage (1 = Montag).
  final List<int> weekdays;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;
  final List<String> excludedDates;
  final String? roomId;

  const SessionRule({
    required this.id,
    required this.kind,
    this.intervalWeeks,
    this.weekdays = const [],
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.excludedDates = const [],
    this.roomId,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "kind": kind.name,
    "intervalWeeks": ?intervalWeeks,
    "weekdays": weekdays,
    "startTime": ?startTime,
    "endTime": ?endTime,
    "startDate": ?startDate,
    "endDate": ?endDate,
    if (excludedDates.isNotEmpty) "excludedDates": excludedDates,
    "roomId": ?roomId,
  };

  factory SessionRule.fromJson(Map<String, dynamic> json) => SessionRule(
    id: _string(json["id"]),
    kind: RepeatKind.values.firstWhere(
      (k) => k.name == json["kind"],
      orElse: () => RepeatKind.unknown,
    ),
    intervalWeeks: _num(json["intervalWeeks"])?.toInt(),
    weekdays: _ints(json["weekdays"]),
    startTime: _optString(json["startTime"]),
    endTime: _optString(json["endTime"]),
    startDate: _optString(json["startDate"]),
    endDate: _optString(json["endDate"]),
    excludedDates: _strings(json["excludedDates"]),
    roomId: _optString(json["roomId"]),
  );
}

enum OccurrenceStatus { scheduled, cancelled }

/// Ein konkreter Termin, halboffenes Intervall [start, end).
class CourseOccurrence {
  final String id;
  final String courseId;
  final String ruleId;
  final LocalDateTime start;
  final LocalDateTime end;
  final String? roomId;
  final OccurrenceStatus status;

  const CourseOccurrence({
    required this.id,
    required this.courseId,
    required this.ruleId,
    required this.start,
    required this.end,
    this.roomId,
    this.status = OccurrenceStatus.scheduled,
  });

  /// Datum `YYYY-MM-DD` des Beginns (Ortszeit der Quelle).
  String get date => start.date;

  bool get cancelled => status == OccurrenceStatus.cancelled;

  /// Mehrtägig (durchgehender Block).
  bool get spansDays => end.date != start.date;

  static CourseOccurrence? tryFromJson(Map<String, dynamic> json) {
    final start = LocalDateTime.tryParse(json["start"]);
    final end = LocalDateTime.tryParse(json["end"]);
    final id = _optString(json["id"]);
    final courseId = _optString(json["courseId"]);
    if (start == null || end == null || id == null || courseId == null) {
      return null;
    }
    if (!end.instant.isAfter(start.instant)) return null;
    return CourseOccurrence(
      id: id,
      courseId: courseId,
      ruleId: _string(json["ruleId"]),
      start: start,
      end: end,
      roomId: _optString(json["roomId"]),
      status: json["status"] == "cancelled"
          ? OccurrenceStatus.cancelled
          : OccurrenceStatus.scheduled,
    );
  }
}

/// Hinweis der Quelle bzw. Verarbeitung zu einer Veranstaltung.
class ScheduleNote {
  final String courseId;
  final String code;
  final bool warning;
  final String detail;

  const ScheduleNote({
    required this.courseId,
    required this.code,
    required this.warning,
    required this.detail,
  });

  factory ScheduleNote.fromJson(Map<String, dynamic> json) => ScheduleNote(
    courseId: _string(json["courseId"]),
    code: _string(json["code"]),
    warning: json["severity"] == "warning",
    detail: _string(json["detail"]),
  );
}

class CatalogCourse {
  final String id;
  final String semesterId;
  final List<SourceRef> sources;
  final String? number;
  final String title;
  final List<String> moduleCodes;
  final String? type;
  final num? sws;
  final num? ects;
  final List<String> organizations;

  /// Einrichtungshierarchie, oberste Ebene (Fakultät) zuerst.
  final List<String> organizationPath;
  final List<String> classification;
  final List<String> lecturerIds;
  final List<SessionRule> rules;
  final String? detailUrl;

  const CatalogCourse({
    required this.id,
    required this.semesterId,
    required this.title,
    this.sources = const [],
    this.number,
    this.moduleCodes = const [],
    this.type,
    this.sws,
    this.ects,
    this.organizations = const [],
    this.organizationPath = const [],
    this.classification = const [],
    this.lecturerIds = const [],
    this.rules = const [],
    this.detailUrl,
  });

  /// Fakultät bzw. oberste Einrichtung, falls bekannt.
  String? get faculty =>
      organizationPath.isNotEmpty ? organizationPath.first : null;

  /// Institut (zweite Ebene), sonst die anbietende Einrichtung.
  String? get institute => institutes.firstOrNull;

  /// Institute für Filter: die zweite Ebene der Hierarchie, sonst alle
  /// anbietenden Einrichtungen (bei zusammengeführten Dubletten mehrere).
  List<String> get institutes =>
      organizationPath.length > 1 ? [organizationPath[1]] : organizations;

  static CatalogCourse? tryFromJson(Map<String, dynamic> json) {
    final id = _optString(json["id"]);
    final title = _optString(json["title"]);
    if (id == null || title == null) return null;
    return CatalogCourse(
      id: id,
      semesterId: _string(json["semesterId"]),
      title: title,
      sources: [for (final s in _maps(json["sources"])) SourceRef.fromJson(s)],
      number: _optString(json["number"]),
      moduleCodes: _strings(json["moduleCodes"]),
      type: _optString(json["type"]),
      sws: _num(json["sws"]),
      ects: _num(json["ects"]),
      organizations: _strings(json["organizations"]),
      organizationPath: _strings(json["organizationPath"]),
      classification: _strings(json["classification"]),
      lecturerIds: _strings(json["lecturerIds"]),
      rules: [for (final r in _maps(json["rules"])) SessionRule.fromJson(r)],
      detailUrl: _optString(json["detailUrl"]),
    );
  }
}

/// Herkunft eines Katalogs.
class CatalogProvenance {
  final String sourceId;
  final String institution;
  final String? url;
  final DateTime? fetchedAt;

  const CatalogProvenance({
    required this.sourceId,
    required this.institution,
    this.url,
    this.fetchedAt,
  });

  factory CatalogProvenance.fromJson(Map<String, dynamic> json) =>
      CatalogProvenance(
        sourceId: _string(json["sourceId"]),
        institution: _string(json["institution"]),
        url: _optString(json["url"]),
        fetchedAt: DateTime.tryParse(_string(json["fetchedAt"])),
      );
}

class CatalogFormatException implements Exception {
  final String message;

  const CatalogFormatException(this.message);

  @override
  String toString() => "CatalogFormatException: $message";
}

/// Ein Semesterkatalog mit Nachschlagetabellen.
class CourseCatalog {
  /// Synthetische Testdaten (bis zur Klärung der Nutzungsrechte).
  final bool synthetic;
  final CatalogProvenance provenance;
  final CatalogSemester semester;
  final List<CatalogCourse> courses;
  final Map<String, CatalogPerson> persons;
  final Map<String, CatalogRoom> rooms;

  /// Termine je Veranstaltung, nach Beginn sortiert.
  final Map<String, List<CourseOccurrence>> occurrencesByCourse;
  final Map<String, List<ScheduleNote>> notesByCourse;

  CourseCatalog({
    required this.synthetic,
    required this.provenance,
    required this.semester,
    required this.courses,
    required this.persons,
    required this.rooms,
    required this.occurrencesByCourse,
    required this.notesByCourse,
  });

  /// Liest das JSON der Serververarbeitung. Unvollständige Einträge werden
  /// übergangen; fehlen Semester oder Veranstaltungsliste ganz, ist der
  /// Katalog unbrauchbar ([CatalogFormatException]).
  factory CourseCatalog.fromJson(Map<String, dynamic> json) {
    if (json["semester"] is! Map || json["courses"] is! List) {
      throw const CatalogFormatException(
        "Semester oder Veranstaltungen fehlen",
      );
    }

    final courses = [
      for (final c in _maps(json["courses"])) ?CatalogCourse.tryFromJson(c),
    ];
    final occurrences = <String, List<CourseOccurrence>>{};
    for (final raw in _maps(json["occurrences"])) {
      final o = CourseOccurrence.tryFromJson(raw);
      if (o != null) (occurrences[o.courseId] ??= []).add(o);
    }
    for (final list in occurrences.values) {
      list.sort((a, b) => a.start.instant.compareTo(b.start.instant));
    }
    final notes = <String, List<ScheduleNote>>{};
    for (final raw in _maps(json["issues"])) {
      final n = ScheduleNote.fromJson(raw);
      (notes[n.courseId] ??= []).add(n);
    }

    return CourseCatalog(
      synthetic: json["synthetic"] == true,
      provenance: CatalogProvenance.fromJson(
        Map<String, dynamic>.from(json["provenance"] as Map? ?? const {}),
      ),
      semester: CatalogSemester.fromJson(
        Map<String, dynamic>.from(json["semester"] as Map),
      ),
      courses: courses,
      persons: {
        for (final p in _maps(json["persons"]))
          if (_optString(p["id"]) != null)
            p["id"] as String: CatalogPerson.fromJson(p),
      },
      rooms: {
        for (final r in _maps(json["rooms"]))
          if (_optString(r["id"]) != null)
            r["id"] as String: CatalogRoom.fromJson(r),
      },
      occurrencesByCourse: occurrences,
      notesByCourse: notes,
    );
  }

  late final Map<String, CatalogCourse> _byId = {
    for (final c in courses) c.id: c,
  };

  CatalogCourse? courseById(String id) => _byId[id];

  List<CourseOccurrence> occurrencesOf(String courseId) =>
      occurrencesByCourse[courseId] ?? const [];

  List<ScheduleNote> notesOf(String courseId) =>
      notesByCourse[courseId] ?? const [];

  List<String> lecturerNames(CatalogCourse course) => [
    for (final id in course.lecturerIds) ?persons[id]?.displayName,
  ];
}
