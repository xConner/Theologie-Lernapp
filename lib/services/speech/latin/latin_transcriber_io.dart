import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'latin_transcriber.dart';

LatinTranscriber createLatinTranscriber() => SherpaLatinTranscriber();

/// Eine Datei des Modells mit ihrer erwarteten Größe.
class LatinModelFile {
  final String name;
  final int bytes;

  const LatinModelFile(this.name, this.bytes);
}

/// Ein laufender Download des Modells mit allen, die auf ihn warten.
class _Download {
  final List<void Function(double fraction)> listeners = [];

  late final Future<void> done;
}

/// Lateinische Erkennung auf dem Gerät: Whisper über sherpa-onnx (ONNX
/// Runtime) auf Android, iOS und Desktop.
///
/// Das Modell wird einmalig von Hugging Face geladen und im Datenbereich der
/// App abgelegt; danach arbeitet die Erkennung ohne Internet. Gerechnet wird
/// in einem eigenen Isolate, damit die Oberfläche bedienbar bleibt.
class SherpaLatinTranscriber implements LatinTranscriber {
  /// Whisper „small“, mehrsprachig, 8-Bit-quantisiert (ca. 375 MB). Kleinere
  /// Modelle verstehen Latein deutlich schlechter. Die Revision ist
  /// festgeschrieben, damit sich das Modell nicht unbemerkt ändert.
  static const String modelUrl =
      "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/"
      "8f3c18b358db4d1f2fc1eae49d75cd20989e4309/";

  static const String _folder = "latin_stt/whisper-small-8f3c18b3";

  static const LatinModelFile encoder = LatinModelFile(
    "small-encoder.int8.onnx",
    112442483,
  );
  static const LatinModelFile decoder = LatinModelFile(
    "small-decoder.int8.onnx",
    262226114,
  );
  static const LatinModelFile tokens = LatinModelFile(
    "small-tokens.txt",
    816730,
  );

  static const List<LatinModelFile> files = [encoder, decoder, tokens];

  /// Whisper verarbeitet höchstens 30 Sekunden am Stück; längere Aufnahmen
  /// werden an einer leisen Stelle geteilt.
  static const int _maxChunkSeconds = 28;
  static const int _minChunkSeconds = 18;

  /// Laufende Downloads je Zielordner. Ein Download gehört nicht dem
  /// Bildschirm, der ihn angestoßen hat: Er läuft weiter, wenn dieser
  /// verlassen wird, und wird bei der Rückkehr nicht ein zweites Mal
  /// gestartet.
  static final Map<String, _Download> _downloads = {};

  final Future<Directory> Function() _directory;
  final http.Client Function() _client;
  final List<LatinModelFile> _files;

  Future<void>? _ready;

  /// Wird mit jedem [dispose] erhöht; eine Vorbereitung, die danach erst
  /// fertig wird, startet kein Modell mehr.
  int _generation = 0;

  SendPort? _commands;
  ReceivePort? _responses;

  int _nextId = 0;

  final Map<int, Completer<String>> _pending = {};

  /// [directory], [client] und [modelFiles] sind für Tests austauschbar.
  SherpaLatinTranscriber({
    Future<Directory> Function()? directory,
    http.Client Function()? client,
    List<LatinModelFile>? modelFiles,
  }) : _directory = directory ?? _defaultDirectory,
       _client = client ?? http.Client.new,
       _files = modelFiles ?? files;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationSupportDirectory();

    return Directory("${base.path}/$_folder");
  }

  @override
  bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows ||
      Platform.isLinux;

  Future<List<LatinModelFile>> _missing() async {
    final directory = await _directory();
    final missing = <LatinModelFile>[];

    for (final file in _files) {
      final local = File("${directory.path}/${file.name}");

      if (!await local.exists() || await local.length() != file.bytes) {
        missing.add(file);
      }
    }

    return missing;
  }

  @override
  Future<int> pendingDownloadBytes() async {
    if (_ready != null) return 0;

    var bytes = 0;

    for (final file in await _missing()) {
      bytes += file.bytes;
    }

    return bytes;
  }

  @override
  Future<void> prepare({void Function(double fraction)? onProgress}) {
    final generation = _generation;

    return _ready ??= () async {
      try {
        await download(onProgress: onProgress);

        if (generation != _generation) {
          throw StateError("latin-speech-closed");
        }

        await _startIsolate();

        // Inzwischen freigegeben: das eben gestartete Modell wieder beenden.
        if (generation != _generation) {
          _stopIsolate();
          throw StateError("latin-speech-closed");
        }
      } catch (_) {
        // Beim nächsten Versuch erneut vorbereiten.
        if (generation == _generation) _ready = null;
        rethrow;
      }
    }();
  }

  /// Lädt die fehlenden Dateien des Modells. Läuft für denselben Ordner
  /// bereits ein Download, wird auf diesen gewartet.
  @visibleForTesting
  Future<void> download({void Function(double fraction)? onProgress}) async {
    final directory = await _directory();

    var running = _downloads[directory.path];

    if (running == null) {
      final started = running = _Download();

      _downloads[directory.path] = started;

      started.done = _fetch(directory, (fraction) {
        for (final listener in List.of(started.listeners)) {
          listener(fraction);
        }
      }).whenComplete(() => _downloads.remove(directory.path));
    }

    if (onProgress != null) running.listeners.add(onProgress);

    try {
      await running.done;
    } finally {
      running.listeners.remove(onProgress);
    }
  }

  Future<void> _fetch(
    Directory directory,
    void Function(double fraction) onProgress,
  ) async {
    final missing = await _missing();

    if (missing.isEmpty) return;

    await directory.create(recursive: true);

    final total = missing.fold<int>(0, (sum, file) => sum + file.bytes);
    var done = 0;

    final client = _client();

    try {
      for (final file in missing) {
        final target = File("${directory.path}/${file.name}");
        final partial = File("${target.path}.part");

        final response = await client.send(
          http.Request("GET", Uri.parse("$modelUrl${file.name}")),
        );

        if (response.statusCode != 200) {
          throw HttpException(
            "latin-speech-model: HTTP ${response.statusCode}",
          );
        }

        final sink = partial.openWrite();

        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            done += chunk.length;
            onProgress((done / total).clamp(0, 1));
          }
        } finally {
          await sink.close();
        }

        // Unvollständig oder verändert: nicht verwenden.
        if (await partial.length() != file.bytes) {
          await partial.delete();
          throw const HttpException("latin-speech-model: incomplete");
        }

        await partial.rename(target.path);
      }
    } finally {
      client.close();
    }
  }

  Future<void> _startIsolate() async {
    final directory = await _directory();
    final responses = ReceivePort();
    final started = Completer<SendPort>();

    responses.listen((message) {
      if (message is SendPort) {
        started.complete(message);
      } else if (message is List && message.length == 3) {
        final completer = _pending.remove(message[0] as int);
        final error = message[2] as String?;

        if (error != null) {
          completer?.completeError(StateError(error));
        } else {
          completer?.complete(message[1] as String);
        }
      } else if (message is String && !started.isCompleted) {
        started.completeError(StateError(message));
      }
    });

    await Isolate.spawn(_run, [
      responses.sendPort,
      "${directory.path}/${encoder.name}",
      "${directory.path}/${decoder.name}",
      "${directory.path}/${tokens.name}",
      math.max(1, math.min(4, Platform.numberOfProcessors)),
    ]);

    try {
      _commands = await started.future;
    } catch (_) {
      responses.close();
      rethrow;
    }

    _responses = responses;
  }

  /// Läuft im Isolate: lädt das Modell einmal und erkennt dann Aufnahme für
  /// Aufnahme.
  static void _run(List<Object> arguments) {
    final main = arguments[0] as SendPort;

    final sherpa.OfflineRecognizer recognizer;

    try {
      sherpa.initBindings();

      recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: arguments[1] as String,
              decoder: arguments[2] as String,
              language: "la",
              task: "transcribe",
            ),
            tokens: arguments[3] as String,
            numThreads: arguments[4] as int,
            debug: false,
          ),
        ),
      );
    } catch (error) {
      main.send("latin-speech-model: $error");
      return;
    }

    final commands = ReceivePort();

    main.send(commands.sendPort);

    commands.listen((message) {
      if (message is! List) {
        recognizer.free();
        commands.close();
        return;
      }

      final id = message[0] as int;

      try {
        final samples = (message[1] as TransferableTypedData)
            .materialize()
            .asFloat32List();

        final stream = recognizer.createStream();

        try {
          stream.acceptWaveform(
            samples: samples,
            sampleRate: LatinTranscriber.sampleRate,
          );
          recognizer.decode(stream);

          main.send([id, recognizer.getResult(stream).text, null]);
        } finally {
          stream.free();
        }
      } catch (error) {
        main.send([id, "", "latin-speech: $error"]);
      }
    });
  }

  @override
  Future<String> transcribe(Float32List samples) async {
    await prepare();

    final parts = <String>[];

    for (final chunk in splitAtPauses(samples)) {
      final id = _nextId++;
      final completer = Completer<String>();

      _pending[id] = completer;

      _commands!.send([
        id,
        TransferableTypedData.fromList([chunk]),
      ]);

      final text = (await completer.future).trim();

      if (text.isNotEmpty) parts.add(text);
    }

    return parts.join(" ");
  }

  /// Teilt eine Aufnahme in Stücke von höchstens [_maxChunkSeconds], jeweils
  /// an der leisesten Stelle (einer Sprechpause) im hinteren Teil.
  static List<Float32List> splitAtPauses(Float32List samples) {
    const rate = LatinTranscriber.sampleRate;
    const maxLength = _maxChunkSeconds * rate;
    const minLength = _minChunkSeconds * rate;
    const window = rate ~/ 5;

    final chunks = <Float32List>[];
    var start = 0;

    while (samples.length - start > maxLength) {
      var cut = start + maxLength;
      var quietest = double.infinity;

      for (
        var position = start + minLength;
        position + window <= start + maxLength;
        position += window ~/ 2
      ) {
        var energy = 0.0;

        for (var i = position; i < position + window; i++) {
          energy += samples[i] * samples[i];
        }

        if (energy < quietest) {
          quietest = energy;
          cut = position + window ~/ 2;
        }
      }

      chunks.add(Float32List.sublistView(samples, start, cut));
      start = cut;
    }

    chunks.add(Float32List.sublistView(samples, start));

    return chunks;
  }

  /// Das Isolate gibt das Modell auf „close“ selbst frei und endet.
  void _stopIsolate() {
    _commands?.send("close");
    _commands = null;

    _responses?.close();
    _responses = null;
  }

  @override
  Future<void> dispose() async {
    _generation++;
    _stopIsolate();

    _ready = null;

    for (final completer in _pending.values) {
      completer.completeError(StateError("latin-speech-closed"));
    }
    _pending.clear();
  }
}
