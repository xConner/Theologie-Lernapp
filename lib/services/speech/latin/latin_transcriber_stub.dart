import 'dart:typed_data';

import 'latin_transcriber.dart';

LatinTranscriber createLatinTranscriber() => _UnsupportedLatinTranscriber();

class _UnsupportedLatinTranscriber implements LatinTranscriber {
  @override
  bool get isSupported => false;

  @override
  Future<int> pendingDownloadBytes() async => 0;

  @override
  Future<void> prepare({void Function(double fraction)? onProgress}) async {
    throw UnsupportedError("latin-speech-unavailable");
  }

  @override
  Future<String> transcribe(Float32List samples) async {
    throw UnsupportedError("latin-speech-unavailable");
  }

  @override
  Future<void> dispose() async {}
}
