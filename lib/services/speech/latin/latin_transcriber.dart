import 'dart:typed_data';

import 'latin_transcriber_stub.dart'
    if (dart.library.io) 'latin_transcriber_io.dart'
    if (dart.library.js_interop) 'latin_transcriber_web.dart'
    as platform;

/// Wandelt eine lateinische Sprachaufnahme auf dem Gerät in Text um.
///
/// Kein Plattformdienst erkennt Latein; deshalb bringt die App dafür ein
/// eigenes, frei verfügbares Modell (Whisper) mit, das vollständig auf dem
/// Gerät bzw. im Browser rechnet. Die Aufnahme verlässt das Gerät nicht.
/// Übertragen wird nur das Modell selbst – einmalig, beim ersten Gebrauch.
///
/// Das Modell schreibt Latein nach Gehör und ohne verlässliche
/// Rechtschreibung; eine bestimmte Aussprache (klassisch oder
/// kirchenlateinisch) setzt es nicht voraus. Den Abgleich mit dem Lerntext
/// übernimmt deshalb `LatinSpeechMatcher`.
abstract class LatinTranscriber {
  /// Die Erkennung dieser Plattform (Android, iOS und Desktop: sherpa-onnx;
  /// Web: Transformers.js in einem Web Worker).
  factory LatinTranscriber() => platform.createLatinTranscriber();

  /// Abtastrate, in der [transcribe] die Aufnahme erwartet.
  static const int sampleRate = 16000;

  /// Kann auf dieser Plattform erkannt werden?
  bool get isSupported;

  /// Datenmenge in Bytes, die noch heruntergeladen werden muss; 0 = das
  /// Modell liegt bereits vor.
  Future<int> pendingDownloadBytes();

  /// Lädt das Modell (falls nötig) und hält es einsatzbereit.
  Future<void> prepare({void Function(double fraction)? onProgress});

  /// Erkennt den Text in [samples] (mono, [sampleRate] Hz, Werte −1 … 1).
  Future<String> transcribe(Float32List samples);

  Future<void> dispose();
}
