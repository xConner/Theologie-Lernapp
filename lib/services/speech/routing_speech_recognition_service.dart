import 'package:flutter/foundation.dart';

import 'latin/latin_speech_recognition_service.dart';
import 'speech_recognition_service.dart';

/// Wählt je Sprache die passende Erkennung: Latein mit dem eigenen Modell
/// ([LatinSpeechRecognitionService]), alle anderen Sprachen wie bisher über
/// den Plattformdienst ([PlatformSpeechRecognitionService]).
///
/// Für den Aufrufer bleibt es eine [SpeechRecognitionService]; welcher Dienst
/// arbeitet, entscheidet allein der Sprachcode. Eine Sprache wird nie durch
/// eine andere ersetzt.
class RoutingSpeechRecognitionService
    implements SpeechRecognitionService, LocalModelSpeechRecognition {
  final SpeechRecognitionService _platform;
  final SpeechRecognitionService _local;

  SpeechRecognitionService? _active;

  /// [local] muss zusätzlich [LocalModelSpeechRecognition] anbieten.
  RoutingSpeechRecognitionService({
    SpeechRecognitionService? platform,
    SpeechRecognitionService? local,
  }) : _platform = platform ?? PlatformSpeechRecognitionService(),
       _local = local ?? LatinSpeechRecognitionService(),
       assert(local == null || local is LocalModelSpeechRecognition);

  LocalModelSpeechRecognition get _model =>
      _local as LocalModelSpeechRecognition;

  SpeechRecognitionService _serviceFor(String languageCode) {
    return usesLocalModel(languageCode) ? _local : _platform;
  }

  @override
  bool get isListening => _platform.isListening || _local.isListening;

  @override
  ValueListenable<bool> get isProcessing => _model.isProcessing;

  /// Verfügbar, sobald einer der beiden Dienste arbeiten kann; ob eine
  /// bestimmte Sprache erkannt wird, beantwortet [supportsLanguage].
  @override
  Future<bool> initialize() async {
    final platform = await _platform.initialize();
    final local = await _local.initialize();

    return platform || local;
  }

  @override
  Future<bool> supportsLanguage(String languageCode) async {
    if (usesLocalModel(languageCode)) return true;

    return await _platform.initialize() &&
        await _platform.supportsLanguage(languageCode);
  }

  @override
  bool usesLocalModel(String languageCode) {
    return _model.usesLocalModel(languageCode);
  }

  @override
  Future<int> pendingDownloadBytes(String languageCode) async {
    if (!usesLocalModel(languageCode)) return 0;

    return _model.pendingDownloadBytes(languageCode);
  }

  @override
  Future<void> prepareModel(
    String languageCode, {
    void Function(double fraction)? onProgress,
  }) async {
    if (!usesLocalModel(languageCode)) return;

    await _model.prepareModel(languageCode, onProgress: onProgress);
  }

  @override
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  }) {
    final service = _serviceFor(languageCode);

    _active = service;

    return service.listen(languageCode: languageCode, onPartial: onPartial);
  }

  @override
  Future<void> stop() async {
    await _active?.stop();
  }

  @override
  Future<void> cancel() async {
    await _platform.cancel();
    await _local.cancel();
  }

  /// Bricht ab und gibt Mikrofon und Sprachmodell frei.
  Future<void> dispose() async {
    await _platform.cancel();

    final local = _local;

    if (local is LatinSpeechRecognitionService) {
      await local.dispose();
    } else {
      await local.cancel();
    }
  }
}
