import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/services/lecture_materials/lecture_materials.dart';

/// Die geschützten Vorlesungsunterlagen liegen nicht im öffentlichen
/// Repository (docs/lecture-materials.md), sondern lokal in
/// `lecture_materials/` (oder im Verzeichnis aus LECTURE_MATERIALS_DIR).
/// Tests der echten Inhalte laufen nur, wenn es vorhanden ist.
final String lectureMaterialsDir =
    Platform.environment["LECTURE_MATERIALS_DIR"] ?? "lecture_materials";

bool get lectureMaterialsPresent =>
    File("$lectureMaterialsDir/old_testament/course.json").existsSync();

/// Früherer Asset-Pfad → Datei im Verzeichnis der Unterlagen, sonst null.
String? lectureMaterialsFile(String assetPath) {
  const prefixes = [
    "assets/old_testament/",
    "assets/church_history/",
    "assets/reading_plans/course-",
    "assets/info/",
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

/// Die lokalen Unterlagen als freigegebene Quelle.
FakeLectureMaterialsSource directoryLectureMaterialsSource() {
  final dir = Directory(lectureMaterialsDir);
  return FakeLectureMaterialsSource({
    for (final f in dir.listSync(recursive: true).whereType<File>())
      f.path
          .substring(dir.path.length + 1)
          .replaceAll(Platform.pathSeparator, "/"): f
          .readAsBytesSync(),
  });
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
