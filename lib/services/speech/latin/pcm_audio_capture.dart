import 'dart:typed_data';

import 'package:record/record.dart';

/// Mikrofonaufnahme als roher Datenstrom (PCM, 16 Bit, mono).
///
/// Die Aufnahme wird nirgends gespeichert: Sie existiert nur als Datenstrom
/// im Arbeitsspeicher, bis sie ausgewertet ist.
abstract class PcmAudioCapture {
  /// Fragt bei Bedarf die Mikrofon-Berechtigung an.
  Future<bool> requestPermission();

  /// Beginnt die Aufnahme. Der Strom endet nach [stop].
  Future<Stream<Uint8List>> start({required int sampleRate});

  /// Tatsächliche Abtastrate der laufenden Aufnahme; manche Geräte weichen
  /// von der gewünschten ab.
  int get sampleRate;

  Future<void> stop();

  Future<void> dispose();
}

/// Aufnahme über das Paket `record` (Android, iOS, Web, Desktop).
class RecordPcmAudioCapture implements PcmAudioCapture {
  // Erst bei Bedarf anlegen: der Rekorder spricht sofort mit der Plattform.
  AudioRecorder? _recorder;

  int _sampleRate = 0;

  AudioRecorder get _instance => _recorder ??= AudioRecorder();

  @override
  int get sampleRate => _sampleRate;

  @override
  Future<bool> requestPermission() => _instance.hasPermission();

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    _sampleRate = sampleRate;

    await _instance.setOnConfigChanged((config) {
      _sampleRate = config.sampleRate;
    });

    return _instance.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _recorder?.stop();
  }

  @override
  Future<void> dispose() async {
    final recorder = _recorder;

    _recorder = null;

    await recorder?.dispose();
  }
}
