import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_catalog.dart';
import 'course_snapshot.dart';

String? _opt(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Persönliche Korrektur einer Terminregel der Quelle.
class RuleOverride {
  /// Termin ausgeblendet (z. B. Übung, die man nicht besucht).
  final bool removed;

  /// Anderer Wochentag (nur bei wöchentlichen Terminen).
  final int? weekday;
  final String? startTime;
  final String? endTime;
  final String? room;

  const RuleOverride({
    this.removed = false,
    this.weekday,
    this.startTime,
    this.endTime,
    this.room,
  });

  bool get isEmpty =>
      !removed &&
      weekday == null &&
      startTime == null &&
      endTime == null &&
      room == null;

  Map<String, dynamic> toMap() => {
    if (removed) "removed": true,
    "weekday": ?weekday,
    "startTime": ?startTime,
    "endTime": ?endTime,
    "room": ?room,
  };

  static RuleOverride fromMap(Map<String, dynamic> map) => RuleOverride(
    removed: map["removed"] == true,
    weekday: map["weekday"] is num && (map["weekday"] as num) >= 1
        ? (map["weekday"] as num).toInt().clamp(1, 7)
        : null,
    startTime: validTime(map["startTime"]),
    endTime: validTime(map["endTime"]),
    room: _opt(map["room"]),
  );
}

/// Selbst ergänzter wöchentlicher Termin (z. B. wenn die Quelle keinen
/// angibt).
class ExtraSession {
  final String id;
  final int weekday;
  final String startTime;
  final String endTime;
  final String? room;

  const ExtraSession({
    required this.id,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.room,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "weekday": weekday,
    "startTime": startTime,
    "endTime": endTime,
    "room": ?room,
  };

  static ExtraSession? tryFromMap(Map<String, dynamic> map) {
    final id = _opt(map["id"]);
    final weekday = map["weekday"];
    final start = validTime(map["startTime"]);
    final end = validTime(map["endTime"]);
    if (id == null || weekday is! num || start == null || end == null) {
      return null;
    }
    if (weekday < 1 || weekday > 7 || start.compareTo(end) >= 0) return null;
    return ExtraSession(
      id: id,
      weekday: weekday.toInt(),
      startTime: start,
      endTime: end,
      room: _opt(map["room"]),
    );
  }
}

/// `HH:MM` (00:00–23:59) oder null.
String? validTime(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r"^([01]\d|2[0-3]):([0-5]\d)$").firstMatch(v.trim());
  return m == null ? null : v.trim();
}

/// Persönliche Anpassungen eines Eintrags. Getrennt von den importierten
/// Daten gespeichert: Ein späterer Abgleich mit der Quelle ändert sie nie.
class EntryOverrides {
  final String? title;
  final String? lecturers;
  final String? note;
  final Map<String, RuleOverride> rules;
  final List<ExtraSession> extraSessions;

  const EntryOverrides({
    this.title,
    this.lecturers,
    this.note,
    this.rules = const {},
    this.extraSessions = const [],
  });

  static const EntryOverrides none = EntryOverrides();

  bool get isEmpty =>
      title == null &&
      lecturers == null &&
      note == null &&
      rules.values.every((r) => r.isEmpty) &&
      extraSessions.isEmpty;

  /// Betrifft Termine (nicht nur Texte)?
  bool get changesSchedule =>
      rules.values.any((r) => !r.isEmpty) || extraSessions.isNotEmpty;

  Map<String, dynamic> toMap() => {
    "title": ?title,
    "lecturers": ?lecturers,
    "note": ?note,
    if (rules.values.any((r) => !r.isEmpty))
      "rules": {
        for (final e in rules.entries)
          if (!e.value.isEmpty) e.key: e.value.toMap(),
      },
    if (extraSessions.isNotEmpty)
      "extraSessions": [for (final x in extraSessions) x.toMap()],
  };

  static EntryOverrides fromMap(Object? raw) {
    if (raw is! Map) return none;
    final map = Map<String, dynamic>.from(raw);
    final rules = <String, RuleOverride>{};
    if (map["rules"] is Map) {
      for (final e in (map["rules"] as Map).entries) {
        if (e.key is String && e.value is Map) {
          final o = RuleOverride.fromMap(Map<String, dynamic>.from(e.value));
          if (!o.isEmpty) rules[e.key as String] = o;
        }
      }
    }
    return EntryOverrides(
      title: _opt(map["title"]),
      lecturers: _opt(map["lecturers"]),
      note: _opt(map["note"]),
      rules: rules,
      extraSessions: [
        if (map["extraSessions"] is List)
          for (final x in map["extraSessions"] as List)
            if (x is Map)
              ?ExtraSession.tryFromMap(Map<String, dynamic>.from(x)),
      ],
    );
  }
}

/// Eine Veranstaltung im persönlichen Stundenplan.
///
/// Getrennt vom Katalog: Gespeichert werden nur die Zuordnung (Kennung,
/// Quellkennungen, Semester) und ein kleiner Schnappschuss (Titel,
/// Terminsignatur) zum Zeitpunkt des Hinzufügens. Eine Aktualisierung des
/// Katalogs ändert Einträge nie; die App vergleicht nur und zeigt
/// Abweichungen an ([TimetableEntryState]).
class TimetableEntry {
  final String courseId;
  final String semesterId;

  /// Alle Quellkennungen der Veranstaltung (auch zusammengeführter
  /// Dubletten), damit die Zuordnung eine Neuverarbeitung übersteht.
  final List<SourceRef> sources;
  final String title;
  final String? number;

  /// Termine beim Hinzufügen bzw. letzten Übernehmen, siehe
  /// [scheduleSignatureOf].
  final String scheduleSignature;
  final DateTime? addedAt;

  /// Importierte Daten der Veranstaltung (ab Version 2 gespeichert; ältere
  /// Einträge haben keinen und werden über den Katalog aufgelöst).
  final CourseSnapshot? snapshot;

  /// Persönliche Anpassungen.
  final EntryOverrides overrides;

  const TimetableEntry({
    required this.courseId,
    required this.semesterId,
    required this.title,
    required this.scheduleSignature,
    this.sources = const [],
    this.number,
    this.addedAt,
    this.snapshot,
    this.overrides = EntryOverrides.none,
  });

  /// Aus einer eigenständigen Beschreibung (Katalog oder Suche).
  factory TimetableEntry.fromSnapshot(
    CourseSnapshot snapshot, {
    EntryOverrides overrides = EntryOverrides.none,
  }) => TimetableEntry(
    courseId: snapshot.courseId,
    semesterId: snapshot.semesterId,
    sources: snapshot.sources,
    title: snapshot.title,
    number: snapshot.number,
    scheduleSignature: snapshot.scheduleSignature,
    snapshot: snapshot,
    overrides: overrides,
  );

  TimetableEntry copyWith({
    CourseSnapshot? snapshot,
    EntryOverrides? overrides,
    String? scheduleSignature,
    String? title,
  }) => TimetableEntry(
    courseId: courseId,
    semesterId: semesterId,
    sources: snapshot?.sources ?? sources,
    title: title ?? snapshot?.title ?? this.title,
    number: snapshot?.number ?? number,
    scheduleSignature: scheduleSignature ?? this.scheduleSignature,
    addedAt: addedAt,
    snapshot: snapshot ?? this.snapshot,
    overrides: overrides ?? this.overrides,
  );

  /// Angezeigter Titel (persönliche Anpassung vor Quelle).
  String get displayTitle => overrides.title ?? title;

  factory TimetableEntry.fromCourse(CatalogCourse course, {DateTime? now}) =>
      TimetableEntry(
        courseId: course.id,
        semesterId: course.semesterId,
        sources: course.sources,
        title: course.title,
        number: course.number,
        scheduleSignature: scheduleSignatureOf(course),
        addedAt: now ?? DateTime.now(),
      );

  /// Gespeichertes Format (Firestore und lokal gleich). Ungültiges → null.
  static TimetableEntry? tryFromMap(Map<String, dynamic> map) {
    final courseId = map["courseId"];
    final title = map["title"];
    if (courseId is! String || courseId.isEmpty || title is! String) {
      return null;
    }
    final added = map["addedAt"];
    final semesterId = map["semesterId"] is String
        ? map["semesterId"] as String
        : "";
    final sources = [
      if (map["sources"] is List)
        for (final s in map["sources"] as List)
          if (s is Map) SourceRef.fromJson(Map<String, dynamic>.from(s)),
    ];
    return TimetableEntry(
      courseId: courseId,
      semesterId: semesterId,
      title: title,
      number: map["number"] is String ? map["number"] as String : null,
      scheduleSignature: map["scheduleSignature"] is String
          ? map["scheduleSignature"] as String
          : "",
      sources: sources,
      addedAt: switch (added) {
        Timestamp() => added.toDate(),
        num() => DateTime.fromMillisecondsSinceEpoch(added.toInt()),
        _ => null,
      },
      snapshot: CourseSnapshot.tryFromMap(
        map["snapshot"],
        courseId: courseId,
        semesterId: semesterId,
        sources: sources,
      ),
      overrides: EntryOverrides.fromMap(map["overrides"]),
    );
  }

  /// Ohne `addedAt`: den Zeitpunkt setzt der jeweilige Speicher. Mit
  /// [legacy] nur die Felder von Version 1 (für Firestore-Regeln, die die
  /// neuen Felder noch nicht kennen).
  Map<String, dynamic> toMap({bool legacy = false}) => {
    "courseId": courseId,
    "semesterId": semesterId,
    "sources": [for (final s in sources) s.toJson()],
    "title": title,
    "number": ?number,
    "scheduleSignature": scheduleSignature,
    if (!legacy && snapshot != null) "snapshot": snapshot!.toMap(),
    if (!legacy && !overrides.isEmpty) "overrides": overrides.toMap(),
  };
}

/// Vergleichbare Kurzform der Terminregeln einer Veranstaltung
/// (Art, Wochentage, Uhrzeiten, Zeitraum, Raum; ohne Ausfälle).
String scheduleSignatureOf(CatalogCourse course) =>
    scheduleSignatureOfRules(course.rules);

/// Abgleich eines Eintrags mit dem aktuellen Katalog.
enum TimetableEntryState {
  /// Termine wie beim Hinzufügen.
  current,

  /// Termine oder Raum haben sich seitdem geändert.
  changed,

  /// Im Katalog dieses Semesters nicht (mehr) vorhanden.
  missing,

  /// Gehört zu einem anderen Semester als dem angezeigten Katalog.
  otherSemester,

  /// Aus der fakultätsübergreifenden Suche: nicht Teil des
  /// Fakultätskatalogs, Daten aus dem gespeicherten Import.
  external,
}

/// Die Veranstaltung eines Eintrags im Katalog: über die Kennung, sonst über
/// eine gemeinsame Quellkennung (Dubletten werden je nach Abfrage anders
/// zusammengeführt).
CatalogCourse? catalogCourseFor(TimetableEntry entry, CourseCatalog catalog) {
  if (entry.semesterId.isNotEmpty && entry.semesterId != catalog.semester.id) {
    return null;
  }
  final direct = catalog.courseById(entry.courseId);
  if (direct != null) return direct;
  if (entry.sources.isEmpty) return null;
  for (final c in catalog.courses) {
    if (c.sources.any(entry.sources.contains)) return c;
  }
  return null;
}

TimetableEntryState stateOf(TimetableEntry entry, CourseCatalog catalog) {
  if (entry.semesterId.isNotEmpty && entry.semesterId != catalog.semester.id) {
    return TimetableEntryState.otherSemester;
  }
  final course = catalogCourseFor(entry, catalog);
  if (course == null) {
    final snapshot = entry.snapshot;
    return snapshot != null && !snapshot.fromFacultyCatalog
        ? TimetableEntryState.external
        : TimetableEntryState.missing;
  }
  return scheduleSignatureOf(course) == entry.scheduleSignature
      ? TimetableEntryState.current
      : TimetableEntryState.changed;
}
