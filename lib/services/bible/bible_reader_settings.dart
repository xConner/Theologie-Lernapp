import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/bible_reference.dart';

/// Einstellungen und Lesestand des Bibel-Readers.
///
/// Wie Erscheinungsbild und Sound gehören sie zum Gerät und liegen deshalb
/// in den `SharedPreferences` – für Gäste und angemeldete Nutzer gleich,
/// ohne Abgleich über das Konto.
class BibleReaderSettings {
  static const String _translationKey = 'bible_translation';
  static const String _positionKey = 'bible_position';
  static const String _fontScaleKey = 'bible_font_scale';
  static const String _notesKey = 'bible_show_notes';

  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.75;

  /// Kennung der bevorzugten Ausgabe; `null` = Standard (erste Ausgabe).
  String? translationId;

  /// Zuletzt gelesene Stelle (Buch, Kapitel, oberster sichtbarer Vers).
  BibleReference? position;

  double fontScale = 1;

  /// Anmerkungen der Ausgabe (Fußnoten, Apparat) anzeigen.
  bool showNotes = true;

  static Future<BibleReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final settings = BibleReaderSettings()
      ..translationId = prefs.getString(_translationKey)
      ..position = parsePosition(prefs.getString(_positionKey))
      ..showNotes = prefs.getBool(_notesKey) ?? true;

    final scale = prefs.getDouble(_fontScaleKey) ?? 1;

    settings.fontScale = scale.clamp(minFontScale, maxFontScale).toDouble();

    return settings;
  }

  Future<void> saveTranslation(String id) async {
    translationId = id;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_translationKey, id);
  }

  Future<void> savePosition(BibleReference value) async {
    if (value == position) return;

    position = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_positionKey, formatPosition(value));
  }

  Future<void> saveFontScale(double value) async {
    fontScale = value.clamp(minFontScale, maxFontScale).toDouble();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble(_fontScaleKey, fontScale);
  }

  Future<void> saveShowNotes(bool value) async {
    showNotes = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_notesKey, value);
  }

  static String formatPosition(BibleReference reference) {
    return "${reference.bookId}|${reference.chapter}|${reference.verse ?? 0}";
  }

  /// Fehlende oder unlesbare Werte ergeben `null`.
  static BibleReference? parsePosition(String? stored) {
    final parts = stored?.split("|");

    if (parts == null || parts.length != 3 || parts[0].isEmpty) return null;

    final chapter = int.tryParse(parts[1]);
    final verse = int.tryParse(parts[2]);

    if (chapter == null || chapter < 1 || verse == null) return null;

    return BibleReference(
      bookId: parts[0],
      chapter: chapter,
      verse: verse > 0 ? verse : null,
    );
  }
}
