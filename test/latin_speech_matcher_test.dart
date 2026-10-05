import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/memorization/latin_speech_matcher.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/memorization/text_tokens.dart';

/// Die Transkripte in dieser Datei hat das in der App verwendete Modell
/// (Whisper „small“) aus echten Aufnahmen der jeweiligen Texte erzeugt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const evaluator = MemorizationTextEvaluator();

  late MemorizationCatalog catalog;

  setUpAll(() async {
    catalog = await MemorizationCatalog.load();
  });

  List<String> words(String text) => [
    for (final token in MemorizationNormalizer.tokenize(text))
      if (token.isWord) token.raw,
  ];

  /// Wie der Lernbildschirm: lautlich abgleichen, dann Wort für Wort
  /// vergleichen.
  EvaluationResult check(String target, String transcript) {
    final targetWords = words(target);

    return evaluator.evaluateWords(
      target: targetWords,
      input: LatinSpeechMatcher.reconcile(
        target: targetWords,
        transcript: transcript,
      ),
      spoken: true,
    );
  }

  String appText(String id, [int? from, int? to]) {
    final text = catalog.text(id)!;

    return text.textOf(from ?? 0, to ?? text.segments.length - 1);
  }

  group("Lautschrift", () {
    test("Aussprachetraditionen ergeben dieselbe Form", () {
      final key = LatinSpeechMatcher.phoneticKey;

      expect(key("cælis"), key("caelis"));
      expect(key("cēlīs"), key("caelis"));
      expect(key("tselis"), key("caelis"));
      expect(key("chelis"), key("caelis"));
      expect(key("celis"), key("caelis"));

      expect(key("grazia"), key("gratia"));
      expect(key("gratsia"), key("gratia"));

      expect(key("kui"), key("qui"));
      expect(key("sikut"), key("sicut"));
      expect(key("odie"), key("hodie"));
      expect(key("Catolicam"), key("catholicam"));
      expect(key("judicare"), key("iudicare"));

      // Zerlegte Akzente (NFD) und Satzzeichen.
      expect(key("sanctificétur,"), key("sanctificetur"));
    });

    test("verschiedene Wörter bleiben verschieden", () {
      final key = LatinSpeechMatcher.phoneticKey;

      expect(key("Mater"), isNot(key("Pater")));
      expect(key("tuam"), isNot(key("tuum")));
      expect(key("Dominum"), isNot(key("Deum")));
      expect(key("caelo"), isNot(key("caelis")));
    });
  });

  group("Texte der App mit echten Transkripten", () {
    test("Gloria Patri: wortgetreu trotz Schreibung nach Gehör", () {
      final result = check(
        appText("prayer.gloria_patri.la"),
        "Gloria patri et filio et spiritui sancto, sicuterati in principio "
        "et nunc et semper et in secula seculorum. Amen.",
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
    });

    test("Vaterunser, Abschnitt: verschmolzene Wörter", () {
      final result = check(
        appText("prayer.vaterunser.la", 1, 1),
        "s'antificetour nomentum",
      );

      expect(result.outcome, RecallOutcome.correct);
    });

    test("Vaterunser ganz: wenige Abweichungen statt „falsch“", () {
      final target = appText("prayer.vaterunser.la");

      const transcript =
          "Pater noster kui es in celes, santificet turnomen tuum, advenyat "
          "renyon tuum, fiat voluntas tuua, sikut in celo et in terra, panen "
          "nostrum cotidianum danobis odie, et dimite novis debita nostra, "
          "sikut et nos dimitimus debitoribus nostris, et nenus indukas "
          "intentasionen, sed liberanus amalo.";

      // Ohne lautlichen Abgleich gälte das richtig aufgesagte Gebet als
      // falsch.
      final plain = evaluator.evaluate(
        target: target,
        input: transcript,
        spoken: true,
      );
      expect(plain.outcome, RecallOutcome.incorrect);

      final result = check(target, transcript);

      expect(result.outcome, RecallOutcome.almost);
      expect(result.errors, lessThanOrEqualTo(4));
      expect(result.matched, greaterThanOrEqualTo(44));
    });

    test("Apostolikum ganz: wenige Abweichungen statt „falsch“", () {
      final result = check(
        appText("confession.apostolicum.full.la"),
        "Credo inde un patrem omnipotentem, creatorem celi et terre, et "
        "inyesun Christum filium eius unikum dominum nostrum, qu'y conceptus "
        "est lei spiritus sanctu, natus ex Maria virgine, pasus su poncio "
        "pilatto, Crucifixus mortus etsepultus Deshendit ad inferos "
        "Terziadier surrexit amortus Ashendit ad chelus Sedet ad exteran "
        "deypatris omnipotentis Inde venturus est judicare vivos et mortuos "
        "Credo in spiritum sanctum Sanctum Ecclesium Catolicum Sanctorum "
        "Communionen Remissionen Pekatorum Carnis Resurrectionen Vitam "
        "Eternam Amen",
      );

      expect(result.outcome, RecallOutcome.almost);
      expect(result.errors, lessThanOrEqualTo(5));
    });

    test("exakter Text bleibt wortgetreu", () {
      for (final id in [
        "prayer.vaterunser.la",
        "prayer.gloria_patri.la",
        "prayer.agnus_dei.la",
        "confession.apostolicum.full.la",
        "confession.nicenum.full.la",
      ]) {
        final target = appText(id);

        final result = check(
          target,
          target.toLowerCase().replaceAll(RegExp(r"[,.:;!?]"), ""),
        );

        expect(result.outcome, RecallOutcome.correct, reason: id);
        expect(result.errors, 0, reason: id);
      }
    });
  });

  group("Falsches bleibt falsch", () {
    const credo = "Credo in unum Deum, Patrem omnipotentem,";

    test("anderes Wort", () {
      expect(
        check(credo, "credo in unum dominum patrem omnipotentem").outcome,
        isNot(RecallOutcome.correct),
      );
      expect(
        check("Pater noster, qui es in cælis:", "mater noster qui es in celis")
            .outcome,
        isNot(RecallOutcome.correct),
      );
    });

    test("andere Endung", () {
      final result = check(
        "sanctificetur nomen tuum;",
        "sanctificetur nomen tuam",
      );

      expect(result.errors + result.minor, greaterThan(0));
      expect(
        LatinSpeechMatcher.recognized(
          target: ["sanctificetur", "nomen", "tuum"],
          transcript: "sanctificetur nomen tuam",
        ),
        [true, true, false],
      );
    });

    test("ausgelassenes Wort", () {
      final result = check(credo, "credo in deum patrem omnipotentem");

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.missing, 1);
    });

    test("hinzugefügtes Wort", () {
      final result = check(
        credo,
        "credo in unum deum patrem nostrum omnipotentem",
      );

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.extra, 1);
    });

    test("ganz anderer Text", () {
      final result = check(
        credo,
        "gloria patri et filio et spiritui sancto",
      );

      expect(result.outcome, RecallOutcome.incorrect);
    });

    test("nichts erkannt", () {
      expect(LatinSpeechMatcher.reconcile(target: words(credo), transcript: " "), "");
      expect(check(credo, "").isEmptyInput, isTrue);
    });
  });
}
