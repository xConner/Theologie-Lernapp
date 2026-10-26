import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Vorlesungsunterlagen nur für freigeschaltete Konten (siehe
/// docs/lecture-materials.md).
///
/// Folien, Abschriften, Zusammenfassungen und Lesepläne der
/// Lehrveranstaltungen (Altes Testament mit der Übung Bibelkunde,
/// Kirchengeschichte) erscheinen nur, wenn der Server bestätigt, dass das
/// angemeldete Konto in `lecture_access/allowlist` steht (Security Rules,
/// `firestore.rules`). Der Client entscheidet nichts selbst: Nur wenn das
/// Lesen von `lecture_access/check` gelingt, gelten die Unterlagen als
/// [available].
///
/// Ohne Freigabe verhält sich die App so, als gäbe es die Bereiche nicht:
/// keine Knöpfe, keine Hinweise, keine Fehlermeldung.
///
/// Dateien werden über ihren Asset-Pfad angesprochen
/// (`assets/old_testament/units/einheit-01.json`); [bundle] liefert sie erst
/// nach der Freigabe.
class LectureMaterials extends ChangeNotifier {
  LectureMaterials({LectureMaterialsSource? source})
    : _source = source ?? BundledLectureMaterialsSource();

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
      _set(null);
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
    var failed = false;

    try {
      manifest = await _source.manifest();
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
    if (!failed || !available) _set(manifest);

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

  void _set(LectureManifest? manifest) {
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

/// Liste der Dateien der Unterlagen.
class LectureManifest {
  /// Pfade ohne `assets/`, z. B. `old_testament/course.json`.
  final List<String> files;

  const LectureManifest(this.files);
}

/// Der Server hat den Abruf abgelehnt (keine Freigabe, nicht angemeldet).
class LectureMaterialsDenied implements Exception {
  const LectureMaterialsDenied();
}

/// Woher die geschützten Dateien kommen.
abstract class LectureMaterialsSource {
  /// Die Dateiliste; wirft [LectureMaterialsDenied] ohne Freigabe.
  Future<LectureManifest?> manifest();

  /// Inhalt einer Datei; wirft [LectureMaterialsDenied] ohne Freigabe.
  Future<Uint8List> file(String path);
}

/// Unterlagen aus dem App-Bundle (`assets/old_testament/`,
/// `assets/church_history/`, `assets/reading_plans/course-*`), freigegeben
/// erst nach der Prüfung beim Server: `lecture_access/check` ist laut
/// `firestore.rules` nur für Konten aus `lecture_access/allowlist` lesbar.
/// Immer vom Server gelesen, damit kein früherer Stand gilt.
///
/// Die Dateien selbst sind damit nur in der Oberfläche verborgen, nicht vor
/// direkten Abrufen geschützt (siehe docs/lecture-materials.md).
class BundledLectureMaterialsSource implements LectureMaterialsSource {
  BundledLectureMaterialsSource({this.firestore, this.bundle});

  /// Standard: `FirebaseFirestore.instance`.
  final FirebaseFirestore? firestore;

  /// Standard: `rootBundle`.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  /// Asset-Pfade, die zu den Unterlagen gehören.
  static const List<String> prefixes = [
    "assets/old_testament/",
    "assets/church_history/",
    "assets/reading_plans/course-",
  ];

  @override
  Future<LectureManifest?> manifest() async {
    try {
      await (firestore ?? FirebaseFirestore.instance)
          .collection("lecture_access")
          .doc("check")
          .get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      if (e.code == "permission-denied" || e.code == "unauthenticated") {
        throw const LectureMaterialsDenied();
      }
      rethrow;
    }

    final assets = await AssetManifest.loadFromAssetBundle(_assets);
    return LectureManifest(
      [
        for (final a in assets.listAssets())
          if (prefixes.any(a.startsWith))
            a.substring(LectureMaterials.assetPrefix.length),
      ]..sort(),
    );
  }

  @override
  Future<Uint8List> file(String path) async {
    final data = await _assets.load("${LectureMaterials.assetPrefix}$path");
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
