import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/services/timetable/course_catalog_source.dart';
import 'package:theologie_lernapp/services/timetable/timetable_store.dart';

/// Wie Firestore: Jede Änderung geht sofort an alle Beobachter – zwei
/// Stores auf demselben Backend verhalten sich wie zwei Geräte desselben
/// Kontos.
class InMemoryTimetableBackend implements TimetableBackend {
  final Map<String, Map<String, dynamic>> docs = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool failWrites;
  bool failWatch;
  bool failReads;

  /// Schreibt bis einschließlich so vielen Einträgen, danach Fehler.
  int? failPutsAfter;
  int puts = 0;

  /// Einträge, die der Server (noch) nicht bestätigt (`read(confirmed: true)`).
  final Set<String> unconfirmed = {};

  InMemoryTimetableBackend({
    this.failWrites = false,
    this.failWatch = false,
    this.failReads = false,
  });

  Map<String, Map<String, dynamic>> _copy() => {
    for (final e in docs.entries) e.key: Map<String, dynamic>.from(e.value),
  };

  @override
  Stream<Map<String, Map<String, dynamic>>> watch() {
    if (failWatch) {
      return Stream.error(StateError("Verbindung verweigert"));
    }
    late final StreamController<Map<String, Map<String, dynamic>>> c;
    StreamSubscription<void>? sub;
    c = StreamController(
      onListen: () {
        sub = _changes.stream.listen((_) => c.add(_copy()));
        c.add(_copy());
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> read({
    bool confirmed = false,
  }) async {
    if (failReads) throw StateError("Lesen fehlgeschlagen");
    final copy = _copy();
    if (confirmed) copy.removeWhere((id, _) => unconfirmed.contains(id));
    return copy;
  }

  @override
  Future<void> put(String id, Map<String, dynamic> data) async {
    if (failWrites || (failPutsAfter != null && puts >= failPutsAfter!)) {
      throw StateError("Schreiben fehlgeschlagen");
    }
    puts++;
    docs[id] = {...data, "addedAt": 1};
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    if (failWrites) throw StateError("Schreiben fehlgeschlagen");
    docs.remove(id);
    _changes.add(null);
  }
}

class MemoryAssetBundle extends AssetBundle {
  final Map<String, String> files;

  MemoryAssetBundle(this.files);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = files[key];
    if (value == null) throw StateError("Asset $key fehlt");
    return value;
  }
}

/// JSON des synthetischen Katalogs; mit [asApi] wie vom Server
/// (`/api/catalog`) ausgeliefert, mit [semester] für ein anderes Semester.
Map<String, dynamic> catalogJson({
  bool asApi = false,
  String semester = "2026w",
  String cacheState = "refreshed",
}) {
  var raw = File(SyntheticCourseCatalogSource.asset).readAsStringSync();
  if (semester != "2026w") {
    raw = raw
        .replaceAll(":2026w:", ":$semester:")
        .replaceAll('"2026w"', '"$semester"')
        .replaceAll("Wintersemester 2026/27", "Sommersemester 2027");
  }
  final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
  if (asApi) {
    json["synthetic"] = false;
    json.remove("notice");
    json["cache"] = {
      "state": cacheState,
      "fetchedAt": "2026-10-14T06:00:00.000Z",
    };
  }
  return json;
}

/// Katalogquelle mit mehreren Semestern aus vorbereiteten Katalogen.
class FakeCatalogSource implements CourseCatalogSource {
  final Map<String, CourseCatalog> catalogs;
  final List<SemesterOption> options;
  final CatalogOrigin origin;
  final bool stale;
  final List<String> loads = [];

  FakeCatalogSource(
    this.catalogs, {
    List<SemesterOption>? options,
    this.origin = CatalogOrigin.network,
    this.stale = false,
  }) : options =
           options ??
           [
             for (final c in catalogs.values)
               SemesterOption(c.semester.id, c.semester.label),
           ];

  @override
  Future<List<SemesterOption>> semesters() async => options;

  @override
  Future<CatalogLoad> load(String semesterId) async {
    loads.add(semesterId);
    final catalog = catalogs[semesterId];
    if (catalog == null) {
      throw const CatalogUnavailableException(
        "Kein Katalog für dieses Semester.",
      );
    }
    return CatalogLoad(
      catalog: catalog,
      origin: origin,
      updatedAt: DateTime.utc(2026, 10, 14, 6),
      sourceStale: stale,
    );
  }
}

class FailingCatalogSource implements CourseCatalogSource {
  int calls = 0;
  final CourseCatalogSource? recoverWith;

  FailingCatalogSource({this.recoverWith});

  @override
  Future<List<SemesterOption>> semesters() async {
    calls++;
    final recover = recoverWith;
    if (calls > 1 && recover != null) return recover.semesters();
    throw const CatalogUnavailableException(
      "Der Veranstaltungskatalog ist derzeit nicht verfügbar.",
    );
  }

  @override
  Future<CatalogLoad> load(String semesterId) {
    final recover = recoverWith;
    if (recover != null) return recover.load(semesterId);
    return Future.error(const CatalogFormatException("nicht erreichbar"));
  }
}

/// Katalog wie vom Server für eine Suche nach Veranstaltungen einer
/// anderen Fakultät (synthetisch, aber im Format von `/api/catalog?q=`).
Map<String, dynamic> foreignSearchJson() => {
  "version": 1,
  "synthetic": false,
  "provenance": {
    "sourceId": "cau-univis",
    "system": "univis",
    "institution": "Christian-Albrechts-Universität zu Kiel",
    "url": null,
    "fetchedAt": "2026-10-14T06:00:00.000Z",
    "contentHash": null,
  },
  "semester": catalogJson()["semester"],
  "courses": [
    {
      "id": "cau-univis:2026w:Lecture.phil.test.ethik",
      "semesterId": "2026w",
      "sources": [
        {"sourceId": "cau-univis", "key": "Lecture.phil.test.ethik"},
      ],
      "number": "050999",
      "title": "Testseminar: Einführung in die Ethik",
      "moduleCodes": [],
      "type": "S",
      "sws": 2,
      "ects": null,
      "organizations": ["Testabteilung Praktische Philosophie"],
      "organizationPath": [
        "Philosophische Fakultät",
        "Testseminar Philosophie",
        "Testabteilung Praktische Philosophie",
      ],
      "classification": [],
      "lecturerIds": ["cau-univis:p0000000000000001"],
      "rules": [
        {
          "id": "phil-r1",
          "kind": "weekly",
          "intervalWeeks": 1,
          "weekdays": [2],
          "startTime": "11:15",
          "endTime": "12:45",
          "roomId": "cau-univis:Room.phil.1",
        },
        {
          "id": "phil-r2",
          "kind": "weekly",
          "intervalWeeks": 1,
          "weekdays": [4],
        },
      ],
      "detailUrl": null,
    },
  ],
  "persons": [
    {"id": "cau-univis:p0000000000000001", "displayName": "Dr. Test Philosoph"},
  ],
  "rooms": [
    {
      "id": "cau-univis:Room.phil.1",
      "shortName": "Test-PH 1",
      "name": "Testhörsaal Philosophie",
      "online": false,
    },
  ],
  "occurrences": [
    for (final date in ["2026-11-03", "2026-11-10", "2026-11-17"])
      {
        "id": "phil-r1@$date",
        "courseId": "cau-univis:2026w:Lecture.phil.test.ethik",
        "ruleId": "phil-r1",
        "date": date,
        "start": "${date}T11:15:00+01:00",
        "end": "${date}T12:45:00+01:00",
        "roomId": "cau-univis:Room.phil.1",
        "status": "scheduled",
      },
  ],
  "issues": [
    {
      "courseId": "cau-univis:2026w:Lecture.phil.test.ethik",
      "ruleId": "phil-r2",
      "code": "missing-time",
      "severity": "warning",
      "detail": "Uhrzeit fehlt",
    },
  ],
  "search": {"total": 1, "returned": 1, "truncated": false},
};

/// Fakultätskatalog aus den synthetischen Testdaten, Suche mit vorbereiteten
/// Ergebnissen bzw. Fehler.
class SearchingCatalogSource
    implements CourseCatalogSource, CourseSearchSource {
  final CourseCatalogSource catalogs;
  Object? failWith;
  final List<Map<String, String?>> searches = [];

  SearchingCatalogSource(this.catalogs, {this.failWith});

  @override
  Future<List<SemesterOption>> semesters() => catalogs.semesters();

  @override
  Future<CatalogLoad> load(String semesterId) => catalogs.load(semesterId);

  @override
  Future<List<FacultyOption>> faculties() async => const [
    FacultyOption("010000000", "Theologische Fakultät"),
    FacultyOption("050000000", "Philosophische Fakultät"),
  ];

  @override
  Future<CourseSearchResult> search({
    required String semesterId,
    String? text,
    String? number,
    String? facultyId,
  }) async {
    searches.add({"text": text, "number": number, "faculty": facultyId});
    final failure = failWith;
    if (failure != null) throw failure;
    final catalog = CourseCatalog.fromJson(foreignSearchJson());
    return CourseSearchResult(
      catalog: catalog,
      total: catalog.courses.length,
      fetchedAt: catalog.provenance.fetchedAt,
    );
  }
}
