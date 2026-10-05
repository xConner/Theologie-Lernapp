import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/speech/speech_recognition_service.dart';

void main() {
  String? resolve(String languageCode, List<String> installed) =>
      PlatformSpeechRecognitionService.resolveLocale(languageCode, installed);

  group("Sprachkennung der Erkennung", () {
    test("Latein: nicht über den Plattformdienst, kein Ersatz", () {
      // Latein erkennt das eigene Modell (LatinSpeechRecognitionService);
      // der Plattformdienst wird dafür nie angefragt.
      expect(resolve("la", ["de_DE", "la", "en_US"]), isNull);

      // Gerät nennt Sprachen, Latein ist nicht dabei.
      expect(resolve("la", ["de_DE", "en_US", "it_IT"]), isNull);

      // Ähnliche Kürzel sind kein Latein (Lettisch, Laotisch).
      expect(resolve("la", ["lv_LV", "lo_LA"]), isNull);

      // Plattform nennt keine Sprachen (Web): nicht auf Verdacht anfragen.
      expect(resolve("la", const []), isNull);
    });

    test("Deutsch und Englisch unverändert", () {
      expect(resolve("de", ["en_US", "de_AT", "de_DE"]), "de_DE");
      expect(resolve("de", ["en_US", "de_CH"]), "de_CH");
      expect(resolve("de", ["en_US", "de_LU"]), "de_LU");
      expect(resolve("de", ["en_US", "fr_FR"]), isNull);
      expect(resolve("en", ["en_US", "en_GB"]), "en_GB");
      expect(resolve("en", ["de_DE", "en-AU"]), "en-AU");

      // Ohne Liste (Web) wird die bevorzugte Variante versucht.
      expect(resolve("de", const []), "de-DE");
      expect(resolve("en", const []), "en-GB");
    });

    test("Sprachen ohne Erkennung", () {
      expect(resolve("gr", ["de_DE", "el_GR"]), isNull);
      expect(resolve("gr", const []), isNull);
      expect(resolve("xx", const []), isNull);
    });
  });

  group("Lateinisches Transkript im bestehenden Vergleich", () {
    const evaluator = MemorizationTextEvaluator();

    EvaluationResult check(String target, String input) =>
        evaluator.evaluate(target: target, input: input, spoken: true);

    test("Satzzeichen, Großschreibung und Akzente zählen nicht", () {
      final result = check(
        "Credo in unum Deum, Patrem omnipoténtem,\nfactórem cæli et terræ;",
        "credo in unum deum patrem omnipotentem factorem caeli et terrae",
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
      expect(result.minor, 0);
    });

    test("zerlegte Akzente (NFD) und Ligaturen", () {
      final result = check(
        "Pater noster, qui es in cælis: sanctificétur nomen tuum.",
        "Pater noster qui es in caelis sanctificétur nomen tuum",
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
    });

    test("anderer Wortlaut bleibt eine Abweichung", () {
      final result = check(
        "Credo in unum Deum",
        "Credo in unum Dominum",
      );

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.wrong, 1);
    });
  });
}
