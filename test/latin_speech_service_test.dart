import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:theologie_lernapp/services/speech/latin/latin_speech_recognition_service.dart';
import 'package:theologie_lernapp/services/speech/latin/latin_transcriber.dart';
import 'package:theologie_lernapp/services/speech/latin/latin_transcriber_io.dart';
import 'package:theologie_lernapp/services/speech/latin/pcm_audio_capture.dart';
import 'package:theologie_lernapp/services/speech/routing_speech_recognition_service.dart';
import 'package:theologie_lernapp/services/speech/speech_recognition_service.dart';

/// Liefert vorgegebene Rohdaten statt einer Mikrofonaufnahme.
class FakeCapture implements PcmAudioCapture {
  Uint8List pcm;
  bool permission;
  int rate;

  /// Fehler beim Starten der Aufnahme (z. B. Mikrofon belegt).
  Object? startError;

  bool stopped = false;
  StreamController<Uint8List>? _controller;

  FakeCapture(
    this.pcm, {
    this.permission = true,
    this.rate = 16000,
    this.startError,
  });

  @override
  int get sampleRate => rate;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    stopped = false;

    if (startError != null) throw startError!;

    final controller = _controller = StreamController<Uint8List>();

    for (var i = 0; i < pcm.length; i += 3200) {
      controller.add(
        Uint8List.sublistView(pcm, i, math.min(i + 3200, pcm.length)),
      );
    }

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    await _controller?.close();
  }

  @override
  Future<void> dispose() async {}
}

class FakeTranscriber implements LatinTranscriber {
  final String text;
  final bool supported;

  /// Fehler bei der Erkennung (z. B. Modell abgestürzt).
  final Object? error;

  final List<int> lengths = [];
  int prepared = 0;

  FakeTranscriber(this.text, {this.supported = true, this.error});

  @override
  bool get isSupported => supported;

  @override
  Future<int> pendingDownloadBytes() async => prepared > 0 ? 0 : 1000;

  @override
  Future<void> prepare({void Function(double fraction)? onProgress}) async {
    prepared++;
    onProgress?.call(1);
  }

  @override
  Future<String> transcribe(Float32List samples) async {
    lengths.add(samples.length);

    if (error != null) throw error!;

    return text;
  }

  @override
  Future<void> dispose() async {}
}

/// Plattformdienst, der nur die genannten Sprachen erkennt.
class FakePlatform implements SpeechRecognitionService {
  final bool available;
  final Set<String> languages;

  final List<String> listened = [];
  int stops = 0;

  FakePlatform({this.available = true, this.languages = const {"de", "en"}});

  @override
  bool get isListening => false;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<bool> supportsLanguage(String languageCode) async =>
      languages.contains(languageCode);

  @override
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  }) async {
    listened.add(languageCode);

    return "Text vom Plattformdienst";
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {}
}

/// Ein Ton (PCM, 16 Bit, mono) von [seconds] Länge.
Uint8List tone(double seconds, {int rate = 16000, double level = 0.3}) {
  final count = (seconds * rate).round();
  final data = ByteData(count * 2);

  for (var i = 0; i < count; i++) {
    final value = math.sin(i * 2 * math.pi * 220 / rate) * level * 32767;
    data.setInt16(i * 2, value.round(), Endian.little);
  }

  return data.buffer.asUint8List();
}

void main() {
  group("Lateinische Erkennung", () {
    test("Aufnahme → Modell → Text; die Auswertung wird angezeigt", () async {
      final transcriber = FakeTranscriber(" Pater noster kui es in celis ");
      final capture = FakeCapture(tone(2));

      final service = LatinSpeechRecognitionService(
        transcriber: transcriber,
        capture: capture,
      );

      final processing = <bool>[];
      service.isProcessing.addListener(
        () => processing.add(service.isProcessing.value),
      );

      expect(await service.initialize(), isTrue);
      expect(await service.supportsLanguage("la"), isTrue);
      expect(await service.supportsLanguage("de"), isFalse);

      final result = service.listen(languageCode: "la");

      await pumpEventQueue();
      expect(service.isListening, isTrue);

      await service.stop();

      expect(await result, "Pater noster kui es in celis");
      expect(service.isListening, isFalse);
      expect(capture.stopped, isTrue);
      expect(transcriber.lengths, [2 * 16000]);
      expect(processing, [true, false]);
    });

    test("Stille und versehentliches Antippen: kein Modellaufruf", () async {
      final transcriber = FakeTranscriber("erfunden");

      for (final pcm in [tone(2, level: 0.0005), tone(0.1)]) {
        final service = LatinSpeechRecognitionService(
          transcriber: transcriber,
          capture: FakeCapture(pcm),
        );

        final result = service.listen(languageCode: "la");

        await pumpEventQueue();
        await service.stop();

        expect(await result, "");
      }

      expect(transcriber.lengths, isEmpty);
    });

    test("abweichende Abtastrate wird umgerechnet", () async {
      final transcriber = FakeTranscriber("credo");

      final service = LatinSpeechRecognitionService(
        transcriber: transcriber,
        capture: FakeCapture(tone(1, rate: 48000), rate: 48000),
      );

      final result = service.listen(languageCode: "la");

      await pumpEventQueue();
      await service.stop();

      expect(await result, "credo");
      expect(transcriber.lengths, [16000]);
    });

    test("Rohdaten: 16 Bit, Little Endian → −1 … 1", () {
      final data = ByteData(6)
        ..setInt16(0, 0, Endian.little)
        ..setInt16(2, 16384, Endian.little)
        ..setInt16(4, -32768, Endian.little);

      expect(
        LatinSpeechRecognitionService.toSamples(
          data.buffer.asUint8List(),
          sampleRate: 16000,
        ),
        [0.0, 0.5, -1.0],
      );
    });

    test("abbrechen verwirft die Aufnahme", () async {
      final transcriber = FakeTranscriber("credo");

      final service = LatinSpeechRecognitionService(
        transcriber: transcriber,
        capture: FakeCapture(tone(2)),
      );

      final result = service.listen(languageCode: "la");

      await pumpEventQueue();
      await service.cancel();

      expect(await result, "");
      expect(transcriber.lengths, isEmpty);
      expect(service.isListening, isFalse);
    });

    test("ohne Mikrofon-Freigabe und für andere Sprachen: Fehler", () async {
      final denied = LatinSpeechRecognitionService(
        transcriber: FakeTranscriber("credo"),
        capture: FakeCapture(tone(1), permission: false),
      );

      await expectLater(
        denied.listen(languageCode: "la"),
        throwsA(
          isA<SpeechRecognitionException>().having(
            (e) => e.failure,
            "failure",
            SpeechFailure.microphonePermission,
          ),
        ),
      );

      final service = LatinSpeechRecognitionService(
        transcriber: FakeTranscriber("credo"),
        capture: FakeCapture(tone(1)),
      );

      await expectLater(service.listen(languageCode: "de"), throwsStateError);
    });

    test("Fehler nennen ihre Ursache: Mikrofon oder Erkennung", () async {
      Matcher fails(SpeechFailure failure, Object cause) => throwsA(
        isA<SpeechRecognitionException>()
            .having((e) => e.failure, "failure", failure)
            .having((e) => e.cause, "cause", cause),
      );

      // Das Mikrofon lässt sich nicht starten.
      final busy = StateError("NotReadableError");
      final blocked = LatinSpeechRecognitionService(
        transcriber: FakeTranscriber("credo"),
        capture: FakeCapture(tone(1), startError: busy),
      );

      await expectLater(
        blocked.listen(languageCode: "la"),
        fails(SpeechFailure.microphone, busy),
      );
      expect(blocked.isListening, isFalse);

      // Die Aufnahme liegt vor, das Modell scheitert.
      final crash = StateError("out of memory");
      final service = LatinSpeechRecognitionService(
        transcriber: FakeTranscriber("credo", error: crash),
        capture: FakeCapture(tone(1)),
      );

      final result = service.listen(languageCode: "la");
      final expectation = expectLater(
        result,
        fails(SpeechFailure.recognition, crash),
      );

      await pumpEventQueue();
      await service.stop();
      await expectation;

      expect(service.isListening, isFalse);
      expect(service.isProcessing.value, isFalse);

      // Danach kann erneut zugehört werden.
      final again = LatinSpeechRecognitionService(
        transcriber: FakeTranscriber("credo"),
        capture: FakeCapture(tone(1)),
      );
      final retry = again.listen(languageCode: "la");

      await pumpEventQueue();
      await again.stop();

      expect(await retry, "credo");
    });

    test("lange Aufnahmen werden in Sprechpausen geteilt", () {
      const rate = LatinTranscriber.sampleRate;

      // 70 s Ton mit Pausen bei 20–21 s und 45–46 s.
      final samples = Float32List(70 * rate);

      for (var i = 0; i < samples.length; i++) {
        final second = i / rate;
        final pause =
            (second >= 20 && second < 21) || (second >= 45 && second < 46);

        samples[i] = pause ? 0 : 0.3 * math.sin(i * 0.1);
      }

      final chunks = SherpaLatinTranscriber.splitAtPauses(samples);

      expect(chunks.fold<int>(0, (sum, c) => sum + c.length), samples.length);

      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(28 * rate));
      }

      // Der erste Schnitt liegt in der ersten Pause.
      expect(chunks.first.length / rate, inInclusiveRange(20, 21));

      // Kurze Aufnahmen bleiben ganz.
      expect(
        SherpaLatinTranscriber.splitAtPauses(Float32List(5 * rate)),
        hasLength(1),
      );
    });
  });

  group("Modell laden", () {
    const modelFiles = [
      LatinModelFile("encoder.onnx", 6000),
      LatinModelFile("decoder.onnx", 3000),
      LatinModelFile("tokens.txt", 1000),
    ];

    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync("latin_stt_test");
    });

    tearDown(() {
      directory.deleteSync(recursive: true);
    });

    // Server, der jede Datei in Stücken liefert; [respond] kann eine Antwort
    // ersetzen.
    ({http.Client Function() client, List<String> requests}) server({
      http.StreamedResponse? Function(String name)? respond,
      Future<void>? hold,
    }) {
      final requests = <String>[];

      http.Client client() => MockClient.streaming((request, _) async {
        final name = request.url.pathSegments.last;

        requests.add(request.url.toString());

        final replaced = respond?.call(name);

        if (replaced != null) return replaced;

        final size = modelFiles.firstWhere((file) => file.name == name).bytes;

        Stream<List<int>> body() async* {
          for (var sent = 0; sent < size; sent += 1000) {
            await hold;
            yield List.filled(math.min(1000, size - sent), 7);
          }
        }

        return http.StreamedResponse(body(), 200);
      });

      return (client: client, requests: requests);
    }

    SherpaLatinTranscriber transcriber(http.Client Function() client) {
      return SherpaLatinTranscriber(
        directory: () async => Directory("${directory.path}/model"),
        client: client,
        modelFiles: modelFiles,
      );
    }

    test("fehlendes Modell: Größe nennen, laden, danach nichts mehr", () async {
      final remote = server();
      final model = transcriber(remote.client);

      expect(await model.pendingDownloadBytes(), 10000);

      final progress = <double>[];

      await model.download(onProgress: progress.add);

      expect(remote.requests, [
        for (final file in modelFiles)
          "${SherpaLatinTranscriber.modelUrl}${file.name}",
      ]);

      expect(progress.first, greaterThan(0));
      expect(progress.last, 1.0);

      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }

      expect(await model.pendingDownloadBytes(), 0);

      for (final file in modelFiles) {
        expect(
          File("${directory.path}/model/${file.name}").lengthSync(),
          file.bytes,
        );
      }

      // Vorhandene Dateien werden nicht erneut geladen.
      await model.download();
      expect(remote.requests, hasLength(3));
    });

    test("Server-Fehler: Fehler, nichts Halbes, erneuter Versuch lädt nur "
        "das Fehlende", () async {
      var failing = true;

      final remote = server(
        respond: (name) => failing && name == "decoder.onnx"
            ? http.StreamedResponse(const Stream.empty(), 404)
            : null,
      );
      final model = transcriber(remote.client);

      await expectLater(model.download(), throwsA(isA<HttpException>()));

      expect(await model.pendingDownloadBytes(), 4000);
      expect(
        Directory(
          "${directory.path}/model",
        ).listSync().map((entry) => entry.uri.pathSegments.last),
        ["encoder.onnx"],
      );

      failing = false;
      remote.requests.clear();

      await model.download();

      expect(remote.requests, hasLength(2));
      expect(await model.pendingDownloadBytes(), 0);
    });

    test(
      "abgebrochene Übertragung: unvollständige Datei wird verworfen",
      () async {
        final remote = server(
          respond: (name) => name == "encoder.onnx"
              ? http.StreamedResponse(Stream.value(List.filled(2500, 7)), 200)
              : null,
        );
        final model = transcriber(remote.client);

        await expectLater(model.download(), throwsA(isA<HttpException>()));

        expect(await model.pendingDownloadBytes(), 10000);
        expect(Directory("${directory.path}/model").listSync(), isEmpty);
      },
    );

    test("keine Verbindung: Fehler statt Absturz", () async {
      final model = transcriber(
        () => MockClient((_) => throw const SocketException("offline")),
      );

      await expectLater(model.download(), throwsA(isA<SocketException>()));
      await expectLater(model.prepare(), throwsA(isA<SocketException>()));

      expect(await model.pendingDownloadBytes(), 10000);
    });

    test("ein laufender Download wird nicht doppelt gestartet", () async {
      final hold = Completer<void>();
      final remote = server(hold: hold.future);

      // Zwei Bildschirme nacheinander: Der zweite schließt sich dem
      // laufenden Download an.
      final first = transcriber(remote.client);
      final second = transcriber(remote.client);

      final firstProgress = <double>[];
      final secondProgress = <double>[];

      final a = first.download(onProgress: firstProgress.add);

      await pumpEventQueue();

      // Der erste Bildschirm wird verlassen.
      await first.dispose();

      final b = second.download(onProgress: secondProgress.add);

      hold.complete();

      await Future.wait([a, b]);

      expect(remote.requests, hasLength(3));
      expect(firstProgress.last, 1.0);
      expect(secondProgress.last, 1.0);
      expect(await second.pendingDownloadBytes(), 0);
    });
  });

  group("Wahl des Dienstes je Sprache", () {
    RoutingSpeechRecognitionService routing({
      required FakePlatform platform,
      FakeTranscriber? transcriber,
    }) {
      return RoutingSpeechRecognitionService(
        platform: platform,
        local: LatinSpeechRecognitionService(
          transcriber: transcriber ?? FakeTranscriber("credo in unum deum"),
          capture: FakeCapture(tone(1)),
        ),
      );
    }

    test("Latein → eigenes Modell, Deutsch/Englisch → Plattform", () async {
      final platform = FakePlatform();
      final service = routing(platform: platform);

      expect(await service.initialize(), isTrue);

      expect(service.usesLocalModel("la"), isTrue);
      expect(service.usesLocalModel("de"), isFalse);
      expect(service.usesLocalModel("en"), isFalse);

      expect(
        await service.listen(languageCode: "de"),
        "Text vom Plattformdienst",
      );
      expect(
        await service.listen(languageCode: "en"),
        "Text vom Plattformdienst",
      );
      await service.stop();

      expect(platform.listened, ["de", "en"]);
      expect(platform.stops, 1);

      final result = service.listen(languageCode: "la");

      await pumpEventQueue();
      await service.stop();

      expect(await result, "credo in unum deum");

      // Latein hat den Plattformdienst nie erreicht.
      expect(platform.listened, ["de", "en"]);
      expect(platform.stops, 1);
    });

    test("Latein funktioniert ohne Plattformdienst", () async {
      final platform = FakePlatform(available: false, languages: const {});
      final service = routing(platform: platform);

      expect(await service.initialize(), isTrue);
      expect(await service.supportsLanguage("la"), isTrue);
      expect(await service.supportsLanguage("de"), isFalse);
      expect(await service.supportsLanguage("gr"), isFalse);

      final result = service.listen(languageCode: "la");

      await pumpEventQueue();
      await service.stop();

      expect(await result, "credo in unum deum");
      expect(platform.listened, isEmpty);
    });

    test("Modell: Download-Größe und Vorbereitung nur für Latein", () async {
      final transcriber = FakeTranscriber("credo");
      final service = routing(
        platform: FakePlatform(),
        transcriber: transcriber,
      );

      expect(await service.pendingDownloadBytes("de"), 0);
      expect(await service.pendingDownloadBytes("la"), 1000);

      await service.prepareModel("de");
      expect(transcriber.prepared, 0);

      final progress = <double>[];
      await service.prepareModel("la", onProgress: progress.add);

      expect(transcriber.prepared, 1);
      expect(progress, [1.0]);
      expect(await service.pendingDownloadBytes("la"), 0);
    });

    test("ohne lateinische Erkennung: Latein wird nicht ersetzt", () async {
      final platform = FakePlatform();
      final service = routing(
        platform: platform,
        transcriber: FakeTranscriber("credo", supported: false),
      );

      expect(await service.initialize(), isTrue);
      expect(await service.supportsLanguage("la"), isFalse);
      expect(await service.supportsLanguage("de"), isTrue);
    });
  });
}
