import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'latin_transcriber.dart';

LatinTranscriber createLatinTranscriber() => WebLatinTranscriber();

/// Lateinische Erkennung im Browser: Whisper über Transformers.js und ONNX
/// Runtime Web (WebAssembly) in einem Web Worker (`web/latin_stt/worker.js`).
///
/// Die Oberfläche bleibt während der Erkennung bedienbar, weil das Modell
/// nicht im Haupt-Thread rechnet. Bibliotheken und Worker liegen im eigenen
/// Build; nur das Modell wird einmalig von Hugging Face geladen und danach
/// im Cache des Browsers gehalten.
class WebLatinTranscriber implements LatinTranscriber {
  /// Größe des Modells (Encoder und Decoder, 8-Bit-quantisiert) in Bytes –
  /// für den Hinweis vor dem Herunterladen.
  static const int _modelBytes = 253 * 1000 * 1000;

  /// Der Worker gehört nicht dem Bildschirm, der ihn gestartet hat: Ein
  /// laufender Download wird beim Verlassen nicht abgebrochen (der Browser
  /// behielte sonst nichts davon) und bei der Rückkehr nicht doppelt
  /// gestartet.
  static _LatinWorker? _shared;

  _LatinWorker get _worker => _shared ??= _LatinWorker();

  bool _disposed = false;

  @override
  bool get isSupported {
    // Ohne Mikrofonzugriff (z. B. unsichere Herkunft) gibt es nichts zu
    // erkennen.
    return web.window.isSecureContext &&
        (web.window.navigator as JSObject).has("mediaDevices");
  }

  @override
  Future<int> pendingDownloadBytes() async {
    return await _worker.isAvailable() ? 0 : _modelBytes;
  }

  @override
  Future<void> prepare({void Function(double fraction)? onProgress}) {
    _disposed = false;

    return _worker.load(onProgress);
  }

  @override
  Future<String> transcribe(Float32List samples) async {
    await prepare();

    return _worker.transcribe(samples);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;

    final worker = _shared;

    if (worker == null) return;

    // Erst nach einem laufenden Download beenden; wird das Modell inzwischen
    // wieder gebraucht, bleibt der Worker bestehen.
    worker.releaseWhenIdle(() {
      if (identical(_shared, worker)) _shared = null;
    });
  }
}

/// Der Web Worker mit dem Modell und der Nachrichtenaustausch mit ihm.
class _LatinWorker {
  web.Worker? _worker;

  Future<void>? _ready;

  final List<void Function(double fraction)> _progress = [];

  int _nextId = 0;

  final Map<int, Completer<String>> _pending = {};

  Completer<bool>? _status;
  Completer<void>? _loading;

  void Function()? _onReleased;

  web.Worker _start() {
    final existing = _worker;

    if (existing != null) return existing;

    final worker = web.Worker(
      Uri.base.resolve("latin_stt/worker.js").toString().toJS,
      web.WorkerOptions(type: "module"),
    );

    worker.onmessage = ((web.MessageEvent event) {
      _onMessage(event.data);
    }).toJS;

    worker.onerror = ((web.Event event) {
      _failAll(StateError("latin-speech-worker-failed"));
    }).toJS;

    return _worker = worker;
  }

  void _onMessage(JSAny? data) {
    final message = data.dartify();

    if (message is! Map) return;

    switch (message["type"]) {
      case "status":
        _status?.complete(message["cached"] == true);
        _status = null;

      case "progress":
        final fraction = message["fraction"];

        if (fraction is num) {
          for (final listener in List.of(_progress)) {
            listener(fraction.toDouble().clamp(0, 1));
          }
        }

      case "ready":
        _loading?.complete();
        _loading = null;

      case "result":
        final id = message["id"];

        if (id is num) {
          _pending.remove(id.toInt())?.complete("${message["text"] ?? ""}");
        }

      case "error":
        final error = StateError("${message["message"] ?? "latin-speech"}");
        final id = message["id"];

        if (id is num) {
          _pending.remove(id.toInt())?.completeError(error);
        } else {
          _failAll(error);
        }
    }
  }

  void _failAll(Object error) {
    _status?.complete(false);
    _status = null;

    _loading?.completeError(error);
    _loading = null;

    for (final completer in _pending.values) {
      completer.completeError(error);
    }
    _pending.clear();
  }

  void _post(Map<String, Object?> message) {
    _start().postMessage(message.jsify());
  }

  /// Liegt das Modell geladen oder im Cache des Browsers vor?
  Future<bool> isAvailable() async {
    if (_ready != null && _loading == null) return true;

    var status = _status;

    if (status == null) {
      status = _status = Completer<bool>();
      _post({"type": "status"});
    }

    return status.future;
  }

  Future<void> load(void Function(double fraction)? onProgress) async {
    // Das Modell wird wieder gebraucht.
    _onReleased = null;

    if (onProgress != null) _progress.add(onProgress);

    try {
      await (_ready ??= _load());
    } finally {
      _progress.remove(onProgress);
    }
  }

  Future<void> _load() async {
    final loading = Completer<void>();

    _loading = loading;
    _post({"type": "load"});

    try {
      await loading.future;
    } catch (_) {
      // Beim nächsten Versuch erneut laden.
      _ready = null;
      rethrow;
    } finally {
      _releaseIfRequested();
    }
  }

  Future<String> transcribe(Float32List samples) {
    final id = _nextId++;
    final completer = Completer<String>();

    _pending[id] = completer;

    final audio = samples.toJS;

    final message = JSObject()
      ..["type"] = "transcribe".toJS
      ..["id"] = id.toJS
      ..["audio"] = audio;

    // Die Aufnahme wird übergeben, nicht kopiert.
    final buffer = (audio as JSObject).getProperty<JSObject>("buffer".toJS);

    _start().postMessage(message, [buffer].toJS);

    return completer.future;
  }

  /// Beendet den Worker und gibt das Modell frei – sofort oder, solange noch
  /// geladen wird, danach. [onReleased] meldet das Ende.
  void releaseWhenIdle(void Function() onReleased) {
    _onReleased = onReleased;

    if (_loading == null) _releaseIfRequested();
  }

  void _releaseIfRequested() {
    final onReleased = _onReleased;

    if (onReleased == null) return;

    _onReleased = null;

    _worker?.terminate();
    _worker = null;
    _ready = null;

    _failAll(StateError("latin-speech-closed"));

    onReleased();
  }
}
