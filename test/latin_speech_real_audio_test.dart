// Echte Erkennung: lateinische Aufnahmen (WAV) → Whisper über sherpa-onnx →
// lautlicher Abgleich → Wortvergleich. Läuft nur, wenn Modell und Aufnahmen
// vorliegen, weil beides nicht im Repository liegt:
//
//   LATIN_STT_MODEL_DIR  Ordner mit den drei Modelldateien
//                        (SherpaLatinTranscriber.files)
//   LATIN_STT_AUDIO_DIR  Ordner mit WAV-Dateien (PCM, 16 Bit, mono); der
//                        Dateiname enthält das Kürzel des Textes (siehe
//                        [texts]), z. B. `it_m__credo_nic.wav`
//
//   LATIN_STT_LIB_DIR    (nur ohne gebaute App nötig) Ordner mit der
//                        sherpa-onnx-Bibliothek, unter Windows `windows/` im
//                        Paket `sherpa_onnx_windows`; derselbe Ordner muss in
//                        PATH stehen
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/memorization/latin_speech_matcher.dart';
import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/speech/latin/latin_speech_recognition_service.dart';
import 'package:theologie_lernapp/services/speech/latin/latin_transcriber_io.dart';
import 'package:theologie_lernapp/services/speech/latin/pcm_audio_capture.dart';

const Map<String, String> texts = {
  "credo_nic":
      "Credo in unum Deum, Patrem omnipotentem, factorem caeli et terrae, "
      "visibilium omnium et invisibilium.",
  "pater1":
      "Pater noster, qui es in caelis, sanctificetur nomen tuum. Adveniat "
      "regnum tuum. Fiat voluntas tua, sicut in caelo et in terra.",
  "gloria_patri":
      "Gloria Patri, et Filio, et Spiritui Sancto, sicut erat in principio, "
      "et nunc, et semper, et in saecula saeculorum. Amen.",
};

/// Spielt eine WAV-Datei ab, als käme sie vom Mikrofon.
class WavCapture implements PcmAudioCapture {
  final Uint8List pcm;

  @override
  final int sampleRate;

  StreamController<Uint8List>? _controller;

  WavCapture._(this.pcm, this.sampleRate);

  factory WavCapture(File file) {
    final bytes = file.readAsBytesSync();
    final data = ByteData.sublistView(bytes);

    var rate = 16000;
    var offset = 12;

    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);

      if (id == "fmt ") {
        expect(data.getUint16(offset + 10, Endian.little), 1, reason: "mono");
        expect(data.getUint16(offset + 22, Endian.little), 16, reason: "Bit");
        rate = data.getUint32(offset + 12, Endian.little);
      } else if (id == "data") {
        final end = (offset + 8 + size).clamp(0, bytes.length);

        return WavCapture._(bytes.sublist(offset + 8, end), rate);
      }

      offset += 8 + size + (size & 1);
    }

    throw FormatException("Keine Audiodaten: ${file.path}");
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    final controller = _controller = StreamController<Uint8List>();

    for (var i = 0; i < pcm.length; i += 3200) {
      final end = i + 3200 < pcm.length ? i + 3200 : pcm.length;

      controller.add(Uint8List.sublistView(pcm, i, end));
    }

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _controller?.close();
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  final modelDir = Platform.environment["LATIN_STT_MODEL_DIR"];
  final audioDir = Platform.environment["LATIN_STT_AUDIO_DIR"];

  final skip = modelDir == null || audioDir == null
      ? "LATIN_STT_MODEL_DIR und LATIN_STT_AUDIO_DIR nicht gesetzt"
      : null;

  test(
    "Aufnahme → Whisper → Abgleich → Wortvergleich",
    () async {
      final libDir = Platform.environment["LATIN_STT_LIB_DIR"];

      // Windows fände sonst eine ältere onnxruntime.dll des Systems.
      if (libDir != null && Platform.isWindows) {
        DynamicLibrary.open("$libDir/onnxruntime.dll");
      }

      final transcriber = SherpaLatinTranscriber(
        directory: () async => Directory(modelDir!),
      );

      // Das Modell liegt vor: nichts herunterzuladen.
      expect(await transcriber.pendingDownloadBytes(), 0);

      const evaluator = MemorizationTextEvaluator();

      Future<String> hear(File file) async {
        final service = LatinSpeechRecognitionService(
          transcriber: transcriber,
          capture: WavCapture(file),
        );

        final result = service.listen(languageCode: "la");

        await pumpEventQueue();
        await service.stop();

        return result;
      }

      EvaluationResult check(String target, String transcript) {
        final words = target.split(RegExp(r"\s+"));

        return evaluator.evaluateWords(
          target: words,
          input: LatinSpeechMatcher.reconcile(
            target: words,
            transcript: transcript,
          ),
          spoken: true,
        );
      }

      final files =
          Directory(audioDir!)
              .listSync()
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith(".wav"))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      var heard = 0;
      var words = 0;
      var missed = 0;

      for (final file in files) {
        final name = file.uri.pathSegments.last;

        for (final entry in texts.entries) {
          if (!name.contains(entry.key)) continue;

          final watch = Stopwatch()..start();
          final transcript = await hear(file);
          final result = check(entry.value, transcript);
          final targetWords = entry.value.split(RegExp(r"\s+"));
          final count = targetWords.length;

          final recognized = LatinSpeechMatcher.recognized(
            target: targetWords,
            transcript: transcript,
          );
          final unrecognized = [
            for (var i = 0; i < count; i++)
              if (!recognized[i]) targetWords[i],
          ];

          // ignore: avoid_print
          print(
            "$name (${watch.elapsedMilliseconds} ms): „$transcript“ → "
            "${result.outcome.name}, ${result.errors} von $count Wörtern "
            "abweichend${unrecognized.isEmpty ? "" : " $unrecognized"}",
          );

          expect(transcript, isNotEmpty, reason: name);

          heard++;
          words += count;
          missed += result.errors;

          // Dieselbe Aufnahme gegen einen anderen Text: nicht „richtig“.
          final other = texts.entries.firstWhere((e) => e.key != entry.key);

          expect(
            check(other.value, transcript).outcome,
            RecallOutcome.incorrect,
            reason: "$name gegen ${other.key}",
          );
        }
      }

      await transcriber.dispose();

      // ignore: avoid_print
      print("$heard Aufnahmen, $missed von $words Wörtern abweichend");

      expect(heard, greaterThan(0));
      expect(missed / words, lessThan(0.15));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
