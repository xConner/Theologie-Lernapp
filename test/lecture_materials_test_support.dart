import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/services/lecture_materials/lecture_materials.dart';

/// Die Vorlesungsunterlagen liegen in `assets/` (docs/lecture-materials.md);
/// LECTURE_MATERIALS_DIR erlaubt ein anderes Verzeichnis mit demselben
/// Aufbau. Tests der echten Inhalte laufen nur, wenn es vorhanden ist.
final String lectureMaterialsDir =
    Platform.environment["LECTURE_MATERIALS_DIR"] ?? "assets";

bool get lectureMaterialsPresent =>
    File("$lectureMaterialsDir/old_testament/course.json").existsSync();

/// Früherer Asset-Pfad → Datei im Verzeichnis der Unterlagen, sonst null.
String? lectureMaterialsFile(String assetPath) {
  const prefixes = [
    "assets/old_testament/",
    "assets/church_history/",
    "assets/reading_plans/course-",
  ];
  for (final p in prefixes) {
    if (assetPath.startsWith(p)) {
      return "$lectureMaterialsDir/${assetPath.substring("assets/".length)}";
    }
  }
  return null;
}

/// Ohne Unterlagen: ein übersprungener Test statt der Inhaltstests.
void skipWithoutLectureMaterials(String what) {
  test(
    what,
    () {},
    skip: "Geschützte Vorlesungsunterlagen fehlen ($lectureMaterialsDir/)",
  );
}

/// Unterlagen aus dem Speicher; [denied] = Server lehnt ab (keine Freigabe).
class FakeLectureMaterialsSource implements LectureMaterialsSource {
  final Map<String, Uint8List> files;
  bool denied;
  final List<String> requests = [];

  FakeLectureMaterialsSource(this.files, {this.denied = false});

  @override
  Future<LectureManifest?> manifest() async {
    requests.add("manifest");
    if (denied) throw const LectureMaterialsDenied();
    return LectureManifest(files.keys.toList()..sort());
  }

  @override
  Future<Uint8List> file(String path) async {
    requests.add(path);
    if (denied) throw const LectureMaterialsDenied();
    final bytes = files[path];
    if (bytes == null) throw StateError("fehlt: $path");
    return bytes;
  }
}

/// Die echten Unterlagen (nur deren Dateien) als freigegebene Quelle.
FakeLectureMaterialsSource directoryLectureMaterialsSource() {
  final dir = Directory(lectureMaterialsDir);
  final files = <String, Uint8List>{};
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    final path = f.path
        .substring(dir.path.length + 1)
        .replaceAll(Platform.pathSeparator, "/");
    if (lectureMaterialsFile("assets/$path") != null) {
      files[path] = f.readAsBytesSync();
    }
  }
  return FakeLectureMaterialsSource(files);
}

/// Setzt [LectureMaterials.instance] für einen Test und stellt es danach
/// wieder her. [uid] != null prüft sofort die Freigabe.
Future<LectureMaterials> useLectureMaterials(
  LectureMaterialsSource source, {
  String? uid = "user",
}) async {
  final previous = LectureMaterials.instance;
  final materials = LectureMaterials(source: source);
  LectureMaterials.instance = materials;
  addTearDown(() => LectureMaterials.instance = previous);
  if (uid != null) await materials.check(uid);
  return materials;
}
