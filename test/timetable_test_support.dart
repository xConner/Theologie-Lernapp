import 'dart:async';
import 'dart:convert';

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

  InMemoryTimetableBackend({this.failWrites = false, this.failWatch = false});

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
  Future<void> put(String id, Map<String, dynamic> data) async {
    if (failWrites) throw StateError("Schreiben fehlgeschlagen");
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

class FailingCatalogSource implements CourseCatalogSource {
  int calls = 0;
  final CourseCatalogSource? recoverWith;

  FailingCatalogSource({this.recoverWith});

  @override
  Future<CourseCatalog> load() {
    calls++;
    final recover = recoverWith;
    if (calls > 1 && recover != null) return recover.load();
    return Future.error(const CatalogFormatException("nicht erreichbar"));
  }
}
