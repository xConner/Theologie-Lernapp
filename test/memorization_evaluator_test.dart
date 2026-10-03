import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/memorization/text_tokens.dart';

void main() {
  const evaluator = MemorizationTextEvaluator();

  EvaluationResult check(String target, String input, {bool spoken = false}) {
    return evaluator.evaluate(target: target, input: input, spoken: spoken);
  }

  List<AlignmentType> types(EvaluationResult result) =>
      result.alignment.map((a) => a.type).toList();

  group("Normalisierung", () {
    test("Groß-/Kleinschreibung, Satzzeichen und Leerraum zählen nicht", () {
      final result = check(
        "Dein Wille geschehe, wie im Himmel so auf Erden.",
        "  dein wille   GESCHEHE\nwie im himmel so auf erden ",
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
      expect(result.minor, 0);
      expect(result.matched, 9);
      expect(result.messages(), isEmpty);
    });

    test("ß/ss und Umlaute/ae gelten als gleich", () {
      expect(MemorizationNormalizer.word("daß"), "dass");
      expect(MemorizationNormalizer.word("Väter,"), "vaeter");
      expect(check("daß die Väter", "dass die Vaeter").errors, 0);
    });

    test("Griechisch wird ohne Akzente und Spiritus verglichen", () {
      final result = check(
        "Πάτερ ἡμῶν ὁ ἐν τοῖς οὐρανοῖς·",
        "πατερ ημων ο εν τοις ουρανοις",
      );

      expect(result.outcome, RecallOutcome.correct);
    });

    test("Synonyme sind Abweichungen", () {
      final result = check(
        "geheiligt werde dein Name",
        "geheiligt sei dein Name",
      );

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.wrong, 1);
      expect(result.messages(), ["Anderes Wort: „sei“ statt „werde“"]);
    });
  });

  group("Abweichungen", () {
    test("fehlendes Wort am Ende", () {
      final result = check(
        "Unser tägliches Brot gib uns heute.",
        "Unser tägliches Brot gib uns.",
      );

      expect(result.missing, 1);
      expect(result.alignment.last.type, AlignmentType.missing);
      expect(result.alignment.last.expected, "heute.");
      expect(result.alignment.last.targetIndex, 5);
      expect(result.messages(), ["Es fehlt: „heute“"]);
      expect(result.outcome, RecallOutcome.almost);
    });

    test("fehlendes Wort in der Mitte (gesprochen)", () {
      final result = check(
        "Dein Wille geschehe, wie im Himmel so auf Erden.",
        "dein Wille geschehe wie im Himmel auf Erden",
        spoken: true,
      );

      expect(result.missing, 1);
      expect(result.extra, 0);
      expect(result.wrong, 0);
      expect(result.matched, 8);
      expect(result.errorTargetIndices, {6});
      expect(result.messages(spoken: true), ["Es fehlt: „so“"]);
    });

    test("mehrere fehlende Wörter werden zusammengefasst", () {
      final result = check(
        "Dein Wille geschehe, wie im Himmel so auf Erden.",
        "Dein Wille geschehe so auf Erden",
      );

      expect(result.missing, 3);
      expect(result.messages(), ["Es fehlen: „wie im Himmel“"]);
      expect(result.outcome, RecallOutcome.incorrect);
    });

    test("zusätzliche Wörter", () {
      final result = check(
        "Dein Reich komme.",
        "Dein heiliges Reich komme bald",
      );

      expect(result.extra, 2);
      expect(result.missing, 0);
      expect(types(result), [
        AlignmentType.match,
        AlignmentType.extra,
        AlignmentType.match,
        AlignmentType.match,
        AlignmentType.extra,
      ]);
      expect(result.messages(), ["Zu viel: „heiliges“", "Zu viel: „bald“"]);
    });

    test("vertauschte Nachbarwörter", () {
      final result = check(
        "Unser tägliches Brot gib uns heute",
        "Unser tägliches Brot uns gib heute",
      );

      expect(result.swappedPairs, 1);
      expect(result.missing, 0);
      expect(result.extra, 0);
      expect(result.wrong, 0);
      expect(result.errors, 1);
      expect(result.messages(), ["Vertauscht: „gib“ und „uns“"]);
    });

    test("verschobenes Wort", () {
      final result = check(
        "wie im Himmel so auf Erden",
        "so wie im Himmel auf Erden",
      );

      expect(result.missing, 1);
      expect(result.extra, 1);
      expect(result.messages(), ["An der falschen Stelle: „so“"]);
    });

    test("leicht falsch geschriebenes Wort ist eine kleine Abweichung", () {
      final result = check("Dein Wille geschehe.", "Dein Wille geschehen.");

      expect(result.minor, 1);
      expect(result.errors, 0);
      expect(result.outcome, RecallOutcome.correct);
      expect(result.alignment.last.type, AlignmentType.substitution);
      expect(result.alignment.last.minor, isTrue);
      expect(result.messages(), [
        "Kleine Abweichung: „geschehen“ statt „geschehe“",
      ]);
    });

    test("kurze und sinnverändernde Wörter sind keine kleine Abweichung", () {
      expect(MemorizationTextEvaluator.isMinorDeviation("dem", "den"), isFalse);
      expect(
        MemorizationTextEvaluator.isMinorDeviation("deine", "meine"),
        isFalse,
      );
      expect(
        MemorizationTextEvaluator.isMinorDeviation("himmel", "himmels"),
        isTrue,
      );
      expect(
        MemorizationTextEvaluator.isMinorDeviation(
          "herrlichkeit",
          "herlichkeid",
        ),
        isTrue,
      );
    });

    test("viele kleine Abweichungen sind nicht mehr wortgetreu", () {
      final result = check(
        "Himmel Erden Vater Schuld",
        "Himmels Erde Vaters Schulde",
      );

      expect(result.errors, 0);
      expect(result.minor, 4);
      expect(result.outcome, RecallOutcome.almost);
    });

    test("leere Eingabe", () {
      final result = check("Dein Reich komme.", "   ");

      expect(result.isEmptyInput, isTrue);
      expect(result.outcome, RecallOutcome.incorrect);
      expect(result.missing, 3);
      expect(result.messages(), ["Keine Eingabe."]);
      expect(result.messages(spoken: true), ["Es wurde nichts erkannt."]);
    });

    test("völlig anderer Text", () {
      final result = check(
        "Vater unser im Himmel",
        "Ich glaube an Gott den Vater",
      );

      expect(result.outcome, RecallOutcome.incorrect);
    });

    test("ein Fehler in einem sehr kurzen Abschnitt ist nicht »fast«", () {
      expect(
        check("Dein Reich komme", "Dein Reich").outcome,
        RecallOutcome.incorrect,
      );
    });
  });

  group("Spracherkennung", () {
    test("Füllwörter werden nur gesprochen ignoriert", () {
      const target = "Dein Reich komme.";

      expect(check(target, "ähm dein Reich äh komme", spoken: true).errors, 0);
      expect(check(target, "ähm dein Reich komme").extra, 1);
    });

    test("Ziffern statt Zahlwörtern", () {
      final result = check(
        "am dritten Tage auferstanden von den Toten",
        "am 3. Tage auferstanden von den Toten",
        spoken: true,
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.minor, 0);
    });
  });

  group("Mehrere Abschnitte", () {
    test("Abweichungen lassen sich den Wörtern des Zieltextes zuordnen", () {
      // Zwei Abschnitte mit je drei Wörtern; Fehler nur im zweiten.
      final result = evaluator.evaluateWords(
        target: ["Dein", "Reich", "komme.", "Dein", "Wille", "geschehe,"],
        input: "Dein Reich komme dein Name geschehe",
      );

      expect(result.errorTargetIndices, {4});
      expect(result.alignment[4].expected, "Wille");
      expect(result.alignment[4].actual, "Name");
    });

    test("abgefragt werden können auch nur einzelne Wörter (Lücken)", () {
      final result = evaluator.evaluateWords(
        target: ["Wille", "Himmel", "Erden."],
        input: "wille himmel erden",
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.targetCount, 3);
    });
  });
}
