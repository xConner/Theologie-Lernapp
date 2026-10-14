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
