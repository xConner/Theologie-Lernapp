import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../info/module_info.dart';

/// Geschützte Vorlesungsunterlagen (siehe docs/lecture-materials.md).
///
/// Folien, Abschriften, Zusammenfassungen, Dozentenangaben und Lesepläne
/// der Lehrveranstaltungen (Altes Testament mit der Übung Bibelkunde,
/// Kirchengeschichte) liegen nicht im App-Bundle, sondern in Firestore unter
/// `lecture_materials/{Datei}`. Lesen darf sie nur ein Konto, das in
/// `lecture_access/allowlist` steht – das prüfen die Security Rules bei
/// jedem Abruf (`firestore.rules`). Der Client entscheidet nichts selbst: Er
/// versucht, `lecture_materials/manifest` vom Server zu lesen; nur wenn das
/// gelingt, gelten die Unterlagen als [available].
///
/// Ohne Freigabe verhält sich die App so, als gäbe es die Bereiche nicht:
/// keine Knöpfe, keine Hinweise, keine Fehlermeldung.
///
/// Dateien werden über ihren früheren Asset-Pfad angesprochen
/// (`assets/old_testament/units/einheit-01.json`), damit Daten, IDs und
/// Bildpfade unverändert bleiben; [bundle] liefert sie wie ein AssetBundle.
class LectureMaterials extends ChangeNotifier {
  LectureMaterials({LectureMaterialsSource? source})
    : _source = source ?? FirestoreLectureMaterialsSource();

  /// Ersetzbar nur für Tests.
  static LectureMaterials instance = LectureMaterials();

  /// Lernbereiche (IDs von Streak-Track, Statistik, Info und Lernstand), die
  /// ausschließlich aus geschützten Unterlagen bestehen.
  static const Set<String> protectedAreaIds = {
    "church_history",
    "old_testament",
  };

  /// Präfix der früheren Asset-Pfade.
  static const String assetPrefix = "assets/";

  final LectureMaterialsSource _source;

  LectureManifest? _manifest;
  Map<String, ModuleInfo> _moduleInfos = const {};
  int _generation = 0;
  int _check = 0;
  String? _uid;
  Future<void>? _pending;
  StreamSubscription<User?>? _subscription;
  Timer? _retry;
  int _retries = 0;

  final Map<String, Future<Uint8List>> _files = {};
  late final AssetBundle bundle = _LectureMaterialsBundle(this);

  /// Freigegeben und vom Server bestätigt.
  bool get available => _manifest != null;

  /// Ändert sich bei jedem Wechsel der Freigabe; Zwischenspeicher, die
  /// geschützte Inhalte halten, verwerfen sich damit.
  int get generation => _generation;

  /// Dateien (Pfade ohne `assets/`), leer ohne Freigabe.
  List<String> files({String prefix = ""}) => [
    for (final f in _manifest?.files ?? const <String>[])
      if (f.startsWith(prefix)) f,
  ];

  /// Ist der Lernbereich mit dieser ID sichtbar?
  bool showsArea(String id) => available || !protectedAreaIds.contains(id);

  /// Info zu einem geschützten Bereich (aus `info/<id>.json`); ohne
  /// Freigabe der Platzhalter [fallback] ohne Inhalt.
  ModuleInfo moduleInfo(ModuleInfo fallback) =>
      _moduleInfos[fallback.id] ?? fallback;

  /// Beginnt, Anmeldungen zu verfolgen (einmal in main()). Jede Anmeldung,
  /// jeder Kontowechsel und jede Token-Erneuerung (etwa stündlich) prüft
  /// die Freigabe neu; eine entzogene Freigabe greift so spätestens dann.
  void start({FirebaseAuth? auth}) {
    _subscription ??= (auth ?? FirebaseAuth.instance).idTokenChanges().listen(
      (user) => check(user?.isAnonymous == false ? user!.uid : null),
    );
  }

  /// Wartet auf eine laufende Prüfung (z. B. vor einem direkten Aufruf).
  Future<void> ready() => _pending ?? Future.value();

  /// Prüft die Freigabe für das Konto [uid] (null = abgemeldet oder Gast).
  Future<void> check(String? uid) {
    final number = ++_check;
    _retry?.cancel();

    // Anderes Konto: Inhalte des vorigen sofort verwerfen.
    if (uid != _uid) {
      _uid = uid;
      _retries = 0;
      _set(null, const {});
    }

    if (uid == null) {
      _pending = null;
      return Future.value();
    }

    final future = _load(number);
    _pending = future;
    return future;
  }

  Future<void> _load(int number) async {
    LectureManifest? manifest;
    final infos = <String, ModuleInfo>{};
    var failed = false;

    try {
      manifest = await _source.manifest();
      for (final path in manifest?.files ?? const <String>[]) {
        if (!path.startsWith("info/") || !path.endsWith(".json")) continue;
        final info = ModuleInfo.fromJson(
          jsonDecode(utf8.decode(await _source.file(path)))
              as Map<String, dynamic>,
        );
        infos[info.id] = info;
      }
    } on LectureMaterialsDenied {
      manifest = null;
    } catch (e) {
      // Fehler (offline, Zeitüberschreitung) zählen wie keine Freigabe;
      // später ein neuer Versuch. Bewusst ohne Einzelheiten im Protokoll.
      debugPrint("Unterlagen nicht prüfbar (${e.runtimeType}).");
      manifest = null;
      failed = true;
    }

    if (number != _check) return;

    // Vorübergehender Fehler bei bestehender Freigabe desselben Kontos:
    // Stand behalten. Jeder einzelne Abruf prüft der Server ohnehin.
    if (!failed || !available) _set(manifest, infos);

    if (failed && _retries < 3) {
      _retries++;
      final uid = _uid;
      _retry = Timer(Duration(seconds: 15 * _retries), () {
        if (uid == _uid) check(uid);
      });
    } else if (!failed) {
      _retries = 0;
    }
  }

  void _set(LectureManifest? manifest, Map<String, ModuleInfo> infos) {
    final was = _manifest;
    if (manifest == null && was == null) return;

    if (manifest == null ||
        was == null ||
        !listEquals(manifest.files, was.files)) {
      _generation++;
      _files.clear();
      // Bereits dekodierte Folienbilder nicht weiter anzeigen.
      PaintingBinding.instance.imageCache.clear();
    }

    _manifest = manifest;
    _moduleInfos = manifest == null ? const {} : infos;
    notifyListeners();
  }

  Future<Uint8List> _file(String path) {
    final manifest = _manifest;
    if (manifest == null || !manifest.files.contains(path)) {
      return Future.error(FlutterError("Unable to load asset: $path"));
    }

    final generation = _generation;
    final cached = _files[path];
    if (cached != null) return cached;

    final future = _source.file(path).then((bytes) {
      // Freigabe inzwischen entzogen oder Konto gewechselt.
      if (generation != _generation) {
        throw FlutterError("Unable to load asset: $path");
      }
      return bytes;
    });
    _files[path] = future;
    future.catchError((Object _) {
      if (identical(_files[path], future)) _files.remove(path);
      return Uint8List(0);
    });
    return future;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}

/// Liste der geschützten Dateien (Dokument `lecture_materials/manifest`).
class LectureManifest {
  /// Pfade ohne `assets/`, z. B. `old_testament/course.json`.
  final List<String> files;

  const LectureManifest(this.files);

  factory LectureManifest.fromMap(Map<String, dynamic> map) => LectureManifest([
    for (final f in map["files"] as List? ?? const []) f as String,
  ]);
}

/// Der Server hat den Abruf abgelehnt (keine Freigabe, nicht angemeldet).
class LectureMaterialsDenied implements Exception {
  const LectureMaterialsDenied();
}

/// Woher die geschützten Dateien kommen.
abstract class LectureMaterialsSource {
  /// Die Dateiliste; wirft [LectureMaterialsDenied] ohne Freigabe, null wenn
  /// (noch) nichts hochgeladen ist.
  Future<LectureManifest?> manifest();

  /// Inhalt einer Datei; wirft [LectureMaterialsDenied] ohne Freigabe.
  Future<Uint8List> file(String path);
}

/// Firestore: `lecture_materials/manifest` und je Datei ein Dokument
/// `lecture_materials/<Pfad mit ~ statt />` mit dem Inhalt in `data`.
/// Immer vom Server gelesen, damit die Security Rules bei jedem Abruf
/// greifen und kein früher Zwischenstand gilt.
class FirestoreLectureMaterialsSource implements LectureMaterialsSource {
  FirestoreLectureMaterialsSource({this.firestore});

  static const String collection = "lecture_materials";

  /// Standard: `FirebaseFirestore.instance`.
  final FirebaseFirestore? firestore;

  static String documentId(String path) => path.replaceAll("/", "~");

  Future<Map<String, dynamic>?> _get(String id) async {
    try {
      final snapshot = await (firestore ?? FirebaseFirestore.instance)
          .collection(collection)
          .doc(id)
          .get(const GetOptions(source: Source.server));
      return snapshot.data();
    } on FirebaseException catch (e) {
      if (e.code == "permission-denied" || e.code == "unauthenticated") {
        throw const LectureMaterialsDenied();
      }
      rethrow;
    }
  }

  @override
  Future<LectureManifest?> manifest() async {
    final data = await _get("manifest");
    return data == null ? null : LectureManifest.fromMap(data);
  }

  @override
  Future<Uint8List> file(String path) async {
    final data = await _get(documentId(path));
    final blob = data?["data"];
    if (blob is! Blob) throw FlutterError("Unable to load asset: $path");
    return blob.bytes;
  }
}

/// Liefert geschützte Dateien unter ihrem früheren Asset-Pfad.
class _LectureMaterialsBundle extends AssetBundle {
  _LectureMaterialsBundle(this._owner);

  final LectureMaterials _owner;

  String _path(String key) => key.startsWith(LectureMaterials.assetPrefix)
      ? key.substring(LectureMaterials.assetPrefix.length)
      : key;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await _owner._file(_path(key)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(await _owner._file(_path(key)));

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));

  @override
  void evict(String key) {}
}
