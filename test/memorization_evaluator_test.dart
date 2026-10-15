import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
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

  group("Text außerhalb der abgefragten Abschnitte", () {
    MemorizationText textOf(String id, List<String> segments) {
      return MemorizationText(
        id: id,
        workId: id,
        title: id,
        workTitle: id,
        languageCode: "de",
        type: MemorizationTextType.prayer,
        segments: [
          for (var i = 0; i < segments.length; i++)
            MemorizationSegment(id: "$id.$i", text: segments[i], order: i),
        ],
      );
    }

    final vaterunser = textOf("prayer.test.de", [
      "Vater unser im Himmel,",
      "geheiligt werde dein Name.",
      "Dein Reich komme.",
      "Dein Wille geschehe, wie im Himmel, so auf Erden.",
      "Unser tägliches Brot gib uns heute.",
      "Und vergib uns unsere Schuld, wie auch wir vergeben unsern Schuldigern.",
      "Und führe uns nicht in Versuchung, sondern erlöse uns von dem Bösen.",
      "Denn dein ist das Reich und die Kraft und die Herrlichkeit in Ewigkeit.",
      "Amen.",
    ]);

    // Wie die Übungsansicht: Teil [first] bis [last] (1-basiert) wird
    // abgefragt, die Nachbarabschnitte dienen als Kontext.
    EvaluationResult recite(
      MemorizationText text,
      int first,
      int last,
      String input, {
      bool spoken = false,
    }) {
      final target = [
        for (final token in MemorizationNormalizer.tokenize(
          text.textOf(first - 1, last - 1),
        ))
          if (token.isWord) token.raw,
      ];

      final context = MemorizationTextEvaluator.neighbourWords(
        [for (final segment in text.segments) segment.text],
        first - 1,
        last - 1,
        limit: input.trim().split(RegExp(r"\s+")).length + 10,
      );

      return evaluator.evaluateWords(
        target: target,
        input: input,
        spoken: spoken,
        before: context.before,
        after: context.after,
      );
    }

    String parts(int first, int last) => vaterunser.textOf(first - 1, last - 1);

    test("Teile 2–5 verlangt, korrekte Teile 1–6 eingegeben: richtig", () {
      final result = recite(vaterunser, 2, 5, parts(1, 6));

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
      expect(result.ignoredBefore, 4);
      expect(result.ignoredAfter, 11);
      expect(result.messages(), isEmpty);
      expect(result.errorTargetIndices, isEmpty);
    });

    test("Teile 2–5 verlangt und genau diese eingegeben: richtig", () {
      final result = recite(vaterunser, 2, 5, parts(2, 5));

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
      expect(result.hasIgnoredContext, isFalse);
    });

    test("fehlendes Wort im verlangten Bereich zählt weiterhin", () {
      final input = parts(1, 6).replaceFirst("Dein Reich", "Dein");
      final result = recite(vaterunser, 2, 5, input);

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.missing, 1);
      expect(result.extra, 0);
      expect(result.alignment.firstWhere((a) => a.isError).expected, "Reich");
      expect(result.messages(), [
        "Es fehlt: „Reich“",
        "Text vor oder nach den abgefragten Abschnitten wurde nicht bewertet.",
      ]);
    });

    test("falsches Wort im verlangten Bereich zählt weiterhin", () {
      final input = parts(1, 6).replaceFirst("werde", "sei");
      final result = recite(vaterunser, 2, 5, input);

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.wrong, 1);
      expect(result.errors, 1);
      expect(result.messages().first, "Anderes Wort: „sei“ statt „werde“");
    });

    test("mehrere korrekte Abschnitte davor und danach: richtig", () {
      final result = recite(vaterunser, 3, 5, parts(1, 8));

      expect(result.outcome, RecallOutcome.correct);
      expect(result.errors, 0);
      expect(result.ignoredBefore, 8);
      expect(result.ignoredAfter, 36);
    });

    test("zusätzlicher Text, aber unvollständiger Bereich: nicht richtig", () {
      // Teil 4 fehlt.
      final input = [parts(1, 3), parts(5, 6)].join("\n");
      final result = recite(vaterunser, 2, 5, input);

      expect(result.outcome, RecallOutcome.incorrect);
      expect(result.missing, 9);
      expect(result.messages().first, startsWith("Es fehlen: „Dein Wille"));
    });

    test("nur Text der Nachbarabschnitte ist keine richtige Antwort", () {
      final result = recite(vaterunser, 2, 5, parts(1, 1));

      expect(result.outcome, RecallOutcome.incorrect);
      expect(result.isEmptyInput, isFalse);
    });

    test("fremde Wörter vor dem Bereich werden nicht abgetrennt", () {
      final result = recite(vaterunser, 2, 5, "Hallo Welt ${parts(2, 5)}");

      expect(result.outcome, isNot(RecallOutcome.correct));
      expect(result.extra, 2);
      expect(result.hasIgnoredContext, isFalse);
      expect(result.messages(), ["Zu viel: „Hallo Welt“"]);
    });

    test("kleine Fehler im zusätzlichen Text schaden nicht", () {
      final input = "Vater unser in Himmel ${parts(2, 5)} Und vergib uns";
      final result = recite(vaterunser, 2, 5, input);

      expect(result.outcome, RecallOutcome.correct);
      expect(result.ignoredBefore, 4);
      expect(result.ignoredAfter, 3);
    });

    test("über die Grenze hinaus angefangener Abschnitt: richtig", () {
      final result = recite(vaterunser, 9, 9, "${parts(8, 8)} Amen");

      expect(result.outcome, RecallOutcome.correct);
      expect(result.ignoredBefore, 13);
    });

    test("einzelnes richtiges Folgewort („Amen“) wird nicht bestraft", () {
      final result = recite(vaterunser, 8, 8, "${parts(8, 8)} Amen");

      expect(result.outcome, RecallOutcome.correct);
      expect(result.ignoredAfter, 1);
    });

    test("gesprochen mit Füllwörtern und Zusatztext: richtig", () {
      final result = recite(
        vaterunser,
        2,
        3,
        "ähm Vater unser im Himmel geheiligt werde dein Name äh "
        "dein Reich komme dein Wille",
        spoken: true,
      );

      expect(result.outcome, RecallOutcome.correct);
      expect(result.ignoredBefore, 4);
      expect(result.ignoredAfter, 2);
    });

    group("wiederkehrende Formulierungen", () {
      final litanei = textOf("prayer.kyrie.de", [
        "Herr, erbarme dich.",
        "Christus, erbarme dich.",
        "Herr, erbarme dich.",
        "Christus, höre uns.",
        "Herr, erbarme dich.",
      ]);

      test("der verlangte Abschnitt wird nicht mit einem gleichen "
          "Nachbarabschnitt verwechselt", () {
        final result = recite(litanei, 3, 3, "Herr, erbarme dich.");

        expect(result.outcome, RecallOutcome.correct);
        expect(result.hasIgnoredContext, isFalse);
        expect(result.matched, 3);
      });

      test("gleiche Abschnitte davor und danach werden abgetrennt", () {
        final result = recite(
          litanei,
          3,
          4,
          "Herr erbarme dich Christus erbarme dich Herr erbarme dich "
          "Christus höre uns Herr erbarme dich",
        );

        expect(result.outcome, RecallOutcome.correct);
        expect(result.ignoredBefore, 6);
        expect(result.ignoredAfter, 3);
      });

      test("ein Fehler im Bereich wird nicht durch den gleich lautenden "
          "Vorabschnitt verdeckt", () {
        // Teile 3–4 verlangt; „erbarme dich“ statt „höre uns“ entspricht
        // wortgleich den Teilen 1–2.
        final result = recite(
          litanei,
          3,
          4,
          "Herr erbarme dich Christus erbarme dich",
        );

        expect(result.outcome, isNot(RecallOutcome.correct));
        expect(result.hasIgnoredContext, isFalse);
        expect(result.wrong, 2);
        expect(result.errorTargetIndices, {4, 5});
      });

      test("Wiederholung des Anfangs am Ende wird abgetrennt", () {
        final result = recite(
          litanei,
          2,
          4,
          "Christus erbarme dich Herr erbarme dich Christus höre uns "
          "Herr erbarme dich",
        );

        expect(result.outcome, RecallOutcome.correct);
        expect(result.ignoredAfter, 3);
        expect(result.matched, 9);
      });
    });

    test("Nachbarwörter umfassen ganze Abschnitte bis zur Wortgrenze", () {
      final segments = [for (final s in vaterunser.segments) s.text];

      final context = MemorizationTextEvaluator.neighbourWords(
        segments,
        3,
        4,
        limit: 5,
      );

      // Je Seite ganze Abschnitte, bis mindestens fünf Wörter da sind.
      expect(context.before, [
        "geheiligt",
        "werde",
        "dein",
        "Name.",
        "Dein",
        "Reich",
        "komme.",
      ]);
      expect(context.after.length, 11);

      final edge = MemorizationTextEvaluator.neighbourWords(
        segments,
        0,
        8,
        limit: 50,
      );

      expect(edge.before, isEmpty);
      expect(edge.after, isEmpty);
    });
  });
}
