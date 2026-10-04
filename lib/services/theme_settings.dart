import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert das vom Nutzer gewählte Erscheinungsbild lokal auf dem Gerät,
/// sodass es einen Neustart der App überdauert. Die Auswahl gehört zum Gerät
/// und nicht zum Konto, deshalb liegt sie wie die Sound-Einstellungen in den
/// `SharedPreferences` und nicht in Firestore.
///
/// `MyApp` hört auf diese Einstellungen und reicht [themeMode] an die
/// `MaterialApp` weiter. Die Themes selbst stehen in `theme/app_theme.dart`.
/// Kommen weitere Farbschemata hinzu (z. B. Sepia), erhält diese Klasse
/// neben [themeMode] einen zweiten, ebenso gespeicherten Wert für das
/// gewählte Schema.
class ThemeSettings extends ChangeNotifier {
  ThemeSettings._();

  static final ThemeSettings instance = ThemeSettings._();

  static const ThemeMode defaultThemeMode = ThemeMode.system;

  static const String _themeModeKey = 'app_theme_mode';

  ThemeMode _themeMode = defaultThemeMode;

  /// [ThemeMode.system] folgt der Einstellung des Betriebssystems, auch
  /// wenn diese sich bei laufender App ändert.
  ThemeMode get themeMode => _themeMode;

  /// Lädt die gespeicherte Auswahl. Wird beim App-Start einmal aufgerufen;
  /// solange sie noch nicht geladen ist, gilt [defaultThemeMode].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _themeMode = parseThemeMode(prefs.getString(_themeModeKey));

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;

    _themeMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
  }

  /// Fehlende oder unbekannte Werte ergeben [defaultThemeMode].
  static ThemeMode parseThemeMode(String? stored) {
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) return mode;
    }

    return defaultThemeMode;
  }
}
