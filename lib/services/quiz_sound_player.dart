import 'package:audioplayers/audioplayers.dart';

import 'quiz_sound_settings.dart';

/// Spielt kurze, lokale Feedback-Sounds für richtige/falsche Quiz-Antworten
/// ab. Nutzt einen einzigen wiederverwendeten [AudioPlayer], damit bei
/// schneller Bedienung nie mehrere Sound-Instanzen unkontrolliert
/// übereinanderlaufen – ein neuer Aufruf stoppt automatisch den vorherigen.
///
/// Fehler bei der Wiedergabe (z. B. fehlendes Audio-Backend auf einer
/// Plattform) werden bewusst verschluckt, damit die Quizlogik davon nie
/// beeinträchtigt wird.
class QuizSoundPlayer {
  QuizSoundPlayer._() {
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setPlayerMode(PlayerMode.lowLatency);
  }

  static final QuizSoundPlayer instance = QuizSoundPlayer._();

  static const String _correctAsset = 'sounds/correct.wav';
  static const String _incorrectAsset = 'sounds/incorrect.wav';

  final AudioPlayer _player = AudioPlayer();

  Future<void> playCorrect(SoundModule module) {
    if (!QuizSoundSettings.instance.isCorrectSoundEnabled(module)) {
      return Future.value();
    }

    return _play(_correctAsset);
  }

  Future<void> playIncorrect(SoundModule module) {
    if (!QuizSoundSettings.instance.isWrongSoundEnabled(module)) {
      return Future.value();
    }

    return _play(_incorrectAsset);
  }

  /// Spielt eine Hörprobe der aktuellen Lautstärke ab, unabhängig von den
  /// Pro-Modul-Einstellungen. Wird beim Bedienen des Lautstärkereglers als
  /// direktes Feedback genutzt.
  Future<void> previewVolume() => _play(_correctAsset);

  Future<void> _play(String asset) async {
    final volume = QuizSoundSettings.curvedVolume(
      QuizSoundSettings.instance.volume,
    );

    if (volume <= 0) {
      return;
    }

    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // Sound-Wiedergabe ist rein kosmetisch und darf das Quiz nie stören.
    }
  }
}
