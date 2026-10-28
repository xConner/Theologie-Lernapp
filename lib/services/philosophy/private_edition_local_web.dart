import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'private_edition_store.dart';

/// Browser: `localStorage` über SharedPreferences. Reicht der Platz nicht
/// (je nach Browser etwa 5 MB für alle Daten der Seite), bleibt die Ausgabe
/// nur für die laufende Sitzung geladen; mit Konto liegt sie ohnehin dort.
PrivateEditionBackend createLocalPrivateEditionBackend() =>
    PrefsPrivateEditionBackend();

class PrefsPrivateEditionBackend extends PrivateEditionBackend {
  static String _key(String editionId) => "philosophy.private.$editionId";

  @override
  Future<Map<String, String>?> read(String editionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(editionId));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map;
      return json.map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String editionId, Map<String, String> parts) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_key(editionId), jsonEncode(parts));
    if (!ok) throw StateError("localStorage voll");
  }

  @override
  Future<void> delete(String editionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(editionId));
  }

  @override
  Future<bool> has(String editionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key(editionId));
  }
}
