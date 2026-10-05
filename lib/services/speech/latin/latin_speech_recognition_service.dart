import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../speech_recognition_service.dart';
import 'latin_transcriber.dart';
import 'pcm_audio_capture.dart';

/// Spracherkennung für Latein mit einem eigenen Modell auf dem Gerät.
///
/// Ablauf: Mikrofon aufnehmen ([PcmAudioCapture]) → Aufnahme im
/// Arbeitsspeicher sammeln → nach [stop] auf dem Gerät in Text umwandeln
/// ([LatinTranscriber]) → Aufnahme verwerfen. Anders als der Plattformdienst
/// liefert das Modell keine Zwischenstände und hört nicht von selbst auf: Das
/// Zuhören endet mit [stop] oder nach [maxDuration].
///
/// Datenschutz: Die Aufnahme wird weder gespeichert noch übertragen. Nur das
/// Modell wird einmalig heruntergeladen (siehe [LatinTranscriber]).
class LatinSpeechRecognitionService
    implements SpeechRecognitionService, LocalModelSpeechRecognition {
  static const String languageCode = "la";

  /// Länger wird nicht zugehört; die Aufnahme bleibt im Arbeitsspeicher.
  static const Duration maxDuration = Duration(minutes: 3);

  /// Kürzere Aufnahmen enthalten keinen Text (versehentliches Antippen).
  static const Duration _minDuration = Duration(milliseconds: 400);

  /// Leiser als das ist Stille. Ohne diese Schwelle „erkennt“ das Modell in
  /// Rauschen Wörter, die niemand gesagt hat.
  static const double _silenceLevel = 0.004;

  final LatinTranscriber _transcriber;
  final PcmAudioCapture _capture;

  final ValueNotifier<bool> _processing = ValueNotifier(false);

  _Session? _session;

  LatinSpeechRecognitionService({
    LatinTranscriber? transcriber,
    PcmAudioCapture? capture,
  }) : _transcriber = transcriber ?? LatinTranscriber(),
       _capture = capture ?? RecordPcmAudioCapture();

  @override
  bool get isListening => _session != null;

  @override
  ValueListenable<bool> get isProcessing => _processing;

  /// Die Mikrofon-Berechtigung wird erst beim Zuhören angefragt.
  @override
  Future<bool> initialize() async => _transcriber.isSupported;

  @override
  Future<bool> supportsLanguage(String languageCode) async {
    return usesLocalModel(languageCode);
  }

  @override
  bool usesLocalModel(String languageCode) {
    return languageCode == LatinSpeechRecognitionService.languageCode &&
        _transcriber.isSupported;
  }

  @override
  Future<int> pendingDownloadBytes(String languageCode) {
    return _transcriber.pendingDownloadBytes();
  }

  @override
  Future<void> prepareModel(
    String languageCode, {
    void Function(double fraction)? onProgress,
  }) {
    return _transcriber.prepare(onProgress: onProgress);
  }

  @override
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  }) async {
    if (!usesLocalModel(languageCode)) {
      throw StateError("speech-language-unsupported");
    }

    if (!await _capture.requestPermission()) {
      throw StateError("speech-unavailable");
    }

    // Ein laufendes Zuhören zuerst sauber beenden.
    if (_session != null) {
      await cancel();
    }

    final session = _Session();

    _session = session;

    try {
      final stream = await _capture.start(
        sampleRate: LatinTranscriber.sampleRate,
      );

      final limit =
          maxDuration.inSeconds * math.max(_capture.sampleRate, 1) * 2;

      session.subscription = stream.listen(
        (chunk) {
          session.bytes.add(chunk);

          if (session.bytes.length >= limit) stop();
        },
        onError: (Object error) => _fail(session, error),
        onDone: () {
          if (!session.closed.isCompleted) session.closed.complete();
        },
      );
    } catch (error) {
      _fail(session, error);
    }

    return session.result.future;
  }

  @override
  Future<void> stop() async {
    final session = _session;

    if (session == null || session.stopping) return;

    session.stopping = true;

    try {
      await _capture.stop();

      // Der Strom liefert nach dem Stoppen noch die letzten Daten.
      await session.closed.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      await session.subscription?.cancel();

      final samples = toSamples(
        session.bytes.takeBytes(),
        sampleRate: _capture.sampleRate,
      );

      if (!identical(_session, session)) return;

      if (!_containsSpeech(samples)) {
        _finish(session, "");
        return;
      }

      _processing.value = true;

      final text = await _transcriber.transcribe(samples);

      _finish(session, text.trim());
    } catch (error) {
      _fail(session, error);
    } finally {
      if (_session == null) _processing.value = false;
    }
  }

  @override
  Future<void> cancel() async {
    final session = _session;

    if (session == null) return;

    _session = null;
    _processing.value = false;

    session.bytes.clear();

    try {
      await session.subscription?.cancel();
      await _capture.stop();
    } catch (_) {
      // Nichts zu verwerfen.
    }

    if (!session.result.isCompleted) session.result.complete("");
  }

  /// Gibt Mikrofon und Modell frei.
  Future<void> dispose() async {
    await cancel();
    await _capture.dispose();
    await _transcriber.dispose();

    _processing.dispose();
  }

  void _finish(_Session session, String text) {
    if (identical(_session, session)) _session = null;

    session.bytes.clear();

    if (!session.result.isCompleted) session.result.complete(text);
  }

  void _fail(_Session session, Object error) {
    if (identical(_session, session)) _session = null;

    session.bytes.clear();
    session.subscription?.cancel();
    _capture.stop().catchError((Object _) {});

    if (!session.result.isCompleted) session.result.completeError(error);
  }

  static bool _containsSpeech(Float32List samples) {
    final minSamples =
        LatinTranscriber.sampleRate * _minDuration.inMilliseconds ~/ 1000;

    if (samples.length < minSamples) return false;

    var sum = 0.0;

    for (final sample in samples) {
      sum += sample * sample;
    }

    return math.sqrt(sum / samples.length) >= _silenceLevel;
  }

  /// Rohdaten (PCM, 16 Bit, Little Endian, mono) → Abtastwerte −1 … 1 in der
  /// Abtastrate des Modells.
  @visibleForTesting
  static Float32List toSamples(Uint8List pcm, {required int sampleRate}) {
    final count = pcm.lengthInBytes ~/ 2;
    final data = ByteData.sublistView(pcm);
    final samples = Float32List(count);

    for (var i = 0; i < count; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }

    const wanted = LatinTranscriber.sampleRate;

    if (sampleRate == wanted || sampleRate <= 0 || count == 0) return samples;

    // Geräte, die die gewünschte Rate nicht liefern: linear umrechnen.
    final length = (count * wanted / sampleRate).floor();
    final resampled = Float32List(length);

    for (var i = 0; i < length; i++) {
      final position = i * sampleRate / wanted;
      final index = position.floor();
      final next = math.min(index + 1, count - 1);
      final fraction = position - index;

      resampled[i] = samples[index] * (1 - fraction) + samples[next] * fraction;
    }

    return resampled;
  }
}

/// Ein Zuhören von [LatinSpeechRecognitionService.listen] bis zum Ergebnis.
class _Session {
  final Completer<String> result = Completer<String>();
  final Completer<void> closed = Completer<void>();
  final BytesBuilder bytes = BytesBuilder();

  StreamSubscription<Uint8List>? subscription;

  bool stopping = false;
}
