import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'private_edition_store.dart';

/// Android/Desktop: eine Datei je Ausgabe im Anwendungsverzeichnis (nicht
/// in einem für andere Apps sichtbaren Ordner).
PrivateEditionBackend createLocalPrivateEditionBackend() =>
    FilePrivateEditionBackend();

class FilePrivateEditionBackend extends PrivateEditionBackend {
  Future<File> _file(String editionId) async {
    final dir = await getApplicationSupportDirectory();
    return File("${dir.path}/philosophy_private/$editionId.json");
  }

  @override
  Future<Map<String, String>?> read(String editionId) async {
    try {
      final file = await _file(editionId);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map;
      return json.map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String editionId, Map<String, String> parts) async {
    final file = await _file(editionId);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(parts), flush: true);
  }

  @override
  Future<void> delete(String editionId) async {
    try {
      final file = await _file(editionId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  Future<bool> has(String editionId) async {
    try {
      return await (await _file(editionId)).exists();
    } catch (_) {
      return false;
    }
  }
}
