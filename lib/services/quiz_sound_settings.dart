import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein Trainer bzw. Quiz, das eigene Antwort-Sounds abspielen kann. Jedes
/// Modul entscheidet über eigene Booleans, ob sein Richtig- bzw.
/// Falsch-Sound abgespielt wird; die Lautstärke selbst ist dagegen für alle
/// Module gemeinsam (siehe [QuizSoundSettings.volume]).
enum SoundModule { pericopeQuiz, greekGrammar, greekVocabulary, latinVocabulary }

/// Persistiert die Nutzer-Einstellungen für die Antwort-Sounds im Quizsystem
/// lokal auf dem Gerät, sodass sie einen Neustart der App überdauern.
///
/// Die Lautstärke ist bewusst global für alle Trainer/Quizzes: Es gibt nur
/// einen gespeicherten Wert, den alle Module gemeinsam nutzen. Ob ein
/// bestimmter Sound in einem bestimmten Modul überhaupt abgespielt wird,
/// entscheidet dagegen ein eigener Boolean pro Modul und Sound-Art.
class QuizSoundSettings extends ChangeNotifier {
  QuizSoundSettings._();

  static final QuizSoundSettings instance = QuizSoundSettings._();

  static const double defaultVolume = 0.7;

  static const String _volumeKey = 'quiz_sound_volume';

  double _volume = defaultVolume;

  double get volume => _volume;

  final Map<SoundModule, bool> _correctEnabled = {
    for (final module in SoundModule.values) module: true,
  };

  final Map<SoundModule, bool> _wrongEnabled = {
    for (final module in SoundModule.values) module: true,
  };

  bool isCorrectSoundEnabled(SoundModule module) =>
      _correctEnabled[module] ?? true;

  bool isWrongSoundEnabled(SoundModule module) => _wrongEnabled[module] ?? true;

  /// Lädt die gespeicherten Einstellungen. Wird beim App-Start einmal
  /// aufgerufen; solange sie noch nicht geladen sind, gelten die Defaults.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _volume = prefs.getDouble(_volumeKey) ?? defaultVolume;

    for (final module in SoundModule.values) {
      _correctEnabled[module] = prefs.getBool(_correctKey(module)) ?? true;
      _wrongEnabled[module] = prefs.getBool(_wrongKey(module)) ?? true;
    }

    notifyListeners();
  }

  /// Setzt die globale Lautstärke (Reglerposition 0.0–1.0, stufenlos).
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);

    if (_volume == clamped) return;

    _volume = clamped;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, clamped);
  }

  Future<void> setCorrectSoundEnabled(SoundModule module, bool value) async {
    if (_correctEnabled[module] == value) return;

    _correctEnabled[module] = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_correctKey(module), value);
  }

  Future<void> setWrongSoundEnabled(SoundModule module, bool value) async {
    if (_wrongEnabled[module] == value) return;

    _wrongEnabled[module] = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wrongKey(module), value);
  }

  String _correctKey(SoundModule module) =>
      'quiz_sound_correct_enabled_${module.name}';

  String _wrongKey(SoundModule module) =>
      'quiz_sound_wrong_enabled_${module.name}';

  /// Wandelt die lineare Reglerposition (0.0–1.0) in eine gehörrichtige
  /// Lautstärke um. Menschliches Lautstärkeempfinden ist nicht linear,
  /// weshalb ein linearer Regler bei z. B. 10 % kaum leiser wirkt als bei
  /// 100 %. Die hier verwendete exponentielle Kurve (ein gängiger
  /// "Audio-Taper") sorgt dafür, dass niedrige Reglerwerte deutlich leiser
  /// klingen und der gesamte Bereich gut nutzbar ist.
  static double curvedVolume(double linear) {
    final t = linear.clamp(0.0, 1.0);

    if (t <= 0) return 0;

    return (math.pow(10, t) - 1) / 9;
  }
}
