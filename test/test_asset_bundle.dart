import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Liefert die echten Dateien aus `assets/` direkt von der Platte.
///
/// Für Widget-Tests: `rootBundle.loadString` dekodiert große Dateien per
/// `compute` in einem Isolate, was unter dem Fake-Async der Widget-Tests
/// nicht zuverlässig abschließt.
class FileAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return utf8.decode(File(key).readAsBytesSync());
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async {
    return parser(await loadString(key));
  }
}
