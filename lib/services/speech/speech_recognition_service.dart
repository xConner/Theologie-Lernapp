import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Spracherkennung für das Aufsagen von Texten.
///
/// Die Schnittstelle liefert ausschließlich Text. Ausgewertet wird er lokal
/// (`MemorizationTextEvaluator`); eine KI-API ist nicht beteiligt. Die
/// konkrete Erkennung ist austauschbar – z. B. durch ein Modell, das
/// vollständig auf dem Gerät läuft.
///
/// WICHTIG: Die Schnittstelle sagt nichts darüber aus, wo die Erkennung
/// stattfindet. Die Standard-Implementierung nutzt den Dienst des
/// Betriebssystems bzw. Browsers; dieser kann die Aufnahme zur Erkennung an
/// seinen Anbieter übertragen (siehe [PlatformSpeechRecognitionService]).
abstract class SpeechRecognitionService {
  /// Bereitet die Erkennung vor und fragt bei Bedarf die
  /// Mikrofon-Berechtigung an. false = auf diesem Gerät nicht verfügbar
  /// oder nicht erlaubt.
  Future<bool> initialize();

  /// Kann die Sprache ([languageCode] wie in den Texten: "de", "en", "la",
  /// "gr") erkannt werden?
  Future<bool> supportsLanguage(String languageCode);

  /// Hört zu, bis der Sprecher pausiert oder [stop] aufgerufen wird, und
  /// liefert den erkannten Text. [onPartial] erhält Zwischenstände.
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  });

  /// Beendet das Zuhören; [listen] liefert das bis dahin Erkannte.
  Future<void> stop();

  /// Bricht ab und verwirft das Erkannte.
  Future<void> cancel();

  bool get isListening;
}

/// Erkennung über den Sprachdienst der Plattform (Paket `speech_to_text`):
/// Android (SpeechRecognizer), iOS/macOS (Speech-Framework), Web (Web Speech
/// API, nur in Browsern, die sie anbieten – derzeit v. a. Chrome, Edge und
/// Safari).
///
/// Datenschutz: Die App nimmt selbst nichts auf und speichert kein Audio;
/// sie erhält nur das Transkript. Ob der Plattformdienst auf dem Gerät
/// arbeitet oder das Audio an seinen Anbieter (z. B. Google, Apple) sendet,
/// entscheidet die Plattform – darauf weist die Oberfläche vor der ersten
/// Nutzung hin. Eine Offline-Erkennung wird nicht zugesichert.
class PlatformSpeechRecognitionService implements SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();

  /// Sprachen der Texte → Sprachkürzel der Erkennung. Für Latein und
  /// Altgriechisch bietet keine Plattform eine Erkennung an.
  static const Map<String, List<String>> _locales = {
    "de": ["de-DE", "de-AT", "de-CH"],
    "en": ["en-GB", "en-US"],
  };

  bool _available = false;

  List<LocaleName>? _deviceLocales;

  Completer<String>? _completer;

  String _lastWords = "";

  void Function(String text)? _onPartial;

  @override
  bool get isListening => _completer != null;

  @override
  Future<bool> initialize() async {
    if (_available) return true;

    try {
      _available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } catch (_) {
      // Kein Plugin auf dieser Plattform bzw. Dienst nicht vorhanden.
      _available = false;
    }

    return _available;
  }

  @override
  Future<bool> supportsLanguage(String languageCode) async {
    return await _localeFor(languageCode) != null;
  }

  Future<String?> _localeFor(String languageCode) async {
    final wanted = _locales[languageCode];

    if (wanted == null) return null;

    try {
      _deviceLocales ??= await _speech.locales();
    } catch (_) {
      _deviceLocales = [];
    }

    final installed = _deviceLocales!;

    // Manche Plattformen (Web) nennen keine Sprachen: dann die bevorzugte
    // Variante versuchen.
    if (installed.isEmpty) return wanted.first;

    String normalize(String id) => id.replaceAll("_", "-").toLowerCase();

    for (final id in wanted) {
      for (final locale in installed) {
        if (normalize(locale.localeId) == id.toLowerCase()) {
          return locale.localeId;
        }
      }
    }

    for (final locale in installed) {
      if (normalize(locale.localeId).startsWith("$languageCode-")) {
        return locale.localeId;
      }
    }

    return null;
  }

  @override
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  }) async {
    if (!await initialize()) {
      throw StateError("speech-unavailable");
    }

    final locale = await _localeFor(languageCode);

    if (locale == null) {
      throw StateError("speech-language-unsupported");
    }

    // Ein laufendes Zuhören zuerst sauber beenden.
    if (_completer != null) {
      await cancel();
    }

    final completer = Completer<String>();

    _completer = completer;
    _lastWords = "";
    _onPartial = onPartial;

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(minutes: 3),
          pauseFor: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      _finish(error: error);
    }

    return completer.future;
  }

  @override
  Future<void> stop() async {
    if (_completer == null) return;

    try {
      await _speech.stop();
    } catch (_) {
      // Das Ergebnis wird unten in jedem Fall abgeschlossen.
    }

    // Meldet die Plattform kein abschließendes Ergebnis, gilt das zuletzt
    // Erkannte.
    final completer = _completer;

    Future.delayed(const Duration(seconds: 3), () {
      if (identical(_completer, completer)) _finish();
    });
  }

  @override
  Future<void> cancel() async {
    final completer = _completer;

    _completer = null;
    _onPartial = null;

    try {
      await _speech.cancel();
    } catch (_) {
      // Nichts zu verwerfen.
    }

    if (completer != null && !completer.isCompleted) {
      completer.complete("");
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (_completer == null) return;

    _lastWords = result.recognizedWords;

    _onPartial?.call(_lastWords);

    if (result.finalResult) {
      _finish();
    }
  }

  void _onStatus(String status) {
    // „done“ folgt auf das letzte Ergebnis; auch ohne Ergebnis endet damit
    // das Zuhören (z. B. Stille).
    if (status == SpeechToText.doneStatus) {
      _finish();
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (_completer == null) return;

    // Nichts gehört / kein Treffer ist kein Fehler, sondern ein leeres
    // Ergebnis.
    const silent = {"error_no_match", "error_speech_timeout", "no-speech"};

    if (_lastWords.isNotEmpty || silent.contains(error.errorMsg)) {
      _finish();
    } else {
      _finish(error: StateError(error.errorMsg));
    }
  }

  void _finish({Object? error}) {
    final completer = _completer;

    _completer = null;
    _onPartial = null;

    if (completer == null || completer.isCompleted) return;

    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete(_lastWords);
    }
  }
}
