import 'package:shared_preferences/shared_preferences.dart';

/// Einstellungen des Gesangbuchs.
///
/// Wie die Einstellungen des Bibel-Readers gehören sie zum Gerät und liegen
/// in den `SharedPreferences` – für Gäste und angemeldete Nutzer gleich.
class HymnSettings {
  static const String _scoresKey = 'hymn_show_scores';

  /// „Text und Noten“ statt „Nur Text“.
  bool showScores = false;

  static Future<HymnSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return HymnSettings()..showScores = prefs.getBool(_scoresKey) ?? false;
  }

  Future<void> saveShowScores(bool value) async {
    showScores = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_scoresKey, value);
  }
}
