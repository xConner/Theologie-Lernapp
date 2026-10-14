import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_catalog.dart';

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

  /// Termine beim Hinzufügen, siehe [scheduleSignatureOf].
  final String scheduleSignature;
  final DateTime? addedAt;

  const TimetableEntry({
    required this.courseId,
    required this.semesterId,
    required this.title,
    required this.scheduleSignature,
    this.sources = const [],
    this.number,
    this.addedAt,
  });

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
    return TimetableEntry(
      courseId: courseId,
      semesterId: map["semesterId"] is String
          ? map["semesterId"] as String
          : "",
      title: title,
      number: map["number"] is String ? map["number"] as String : null,
      scheduleSignature: map["scheduleSignature"] is String
          ? map["scheduleSignature"] as String
          : "",
      sources: [
        if (map["sources"] is List)
          for (final s in map["sources"] as List)
            if (s is Map) SourceRef.fromJson(Map<String, dynamic>.from(s)),
      ],
      addedAt: switch (added) {
        Timestamp() => added.toDate(),
        num() => DateTime.fromMillisecondsSinceEpoch(added.toInt()),
        _ => null,
      },
    );
  }

  /// Ohne `addedAt`: den Zeitpunkt setzt der jeweilige Speicher.
  Map<String, dynamic> toMap() => {
    "courseId": courseId,
    "semesterId": semesterId,
    "sources": [for (final s in sources) s.toJson()],
    "title": title,
    "number": ?number,
    "scheduleSignature": scheduleSignature,
  };
}

/// Vergleichbare Kurzform der Terminregeln einer Veranstaltung
/// (Art, Wochentage, Uhrzeiten, Zeitraum, Raum; ohne Ausfälle).
String scheduleSignatureOf(CatalogCourse course) {
  final parts = [
    for (final r in course.rules)
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
}

TimetableEntryState stateOf(TimetableEntry entry, CourseCatalog catalog) {
  if (entry.semesterId.isNotEmpty && entry.semesterId != catalog.semester.id) {
    return TimetableEntryState.otherSemester;
  }
  final course = catalog.courseById(entry.courseId);
  if (course == null) return TimetableEntryState.missing;
  return scheduleSignatureOf(course) == entry.scheduleSignature
      ? TimetableEntryState.current
      : TimetableEntryState.changed;
}
