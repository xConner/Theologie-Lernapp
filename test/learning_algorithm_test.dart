import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/algorithms/learning_selector.dart';
import 'package:theologie_lernapp/algorithms/spaced_repetition.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';

void main() {
  var now = DateTime(2026, 10, 3, 12);

  DateTime clock() => now;

  late SpacedRepetition algorithm;

  setUp(() {
    now = DateTime(2026, 10, 3, 12);
    algorithm = SpacedRepetition(clock: clock);
  });

  LearningCard reviewed({
    String id = "c",
    double stability = 1,
    double difficulty = 5,
    Duration ago = const Duration(hours: 1),
  }) {
    return LearningCard(
      id: id,
      stability: stability,
      difficulty: difficulty,
      lastReviewed: now.subtract(ago),
    );
  }

  /// Zählt, wie oft jede ID bei [draws] unabhängigen Auswahlen gewählt wird.
  Map<String, int> draw(
    List<String> ids,
    Map<String, LearningCard> cards, {
    Map<String, double> weights = const {},
    int draws = 20000,
  }) {
    final random = Random(1);
    final counts = {for (final id in ids) id: 0};

    for (var i = 0; i < draws; i++) {
      // Ohne Mindestabstand, damit die Ziehungen unabhängig sind.
      final selector = LearningSelector(
        algorithm: algorithm,
        cooldown: 0,
        random: random,
      );

      final id = selector.select(
        candidates: ids,
        idOf: (id) => id,
        cards: cards,
        baseWeightOf: (id) => weights[id] ?? 1.0,
      )!;

      counts[id] = counts[id]! + 1;
    }

    return counts;
  }

  group("Auswahlwert", () {
    test("Grundgewicht wirkt proportional bei gleichem Lernstand", () {
      final card = reviewed();

      expect(
        algorithm.selectionScore(card, baseWeight: 10),
        closeTo(10 * algorithm.selectionScore(card), 1e-9),
      );

      final counts = draw(
        ["a", "b"],
        {"a": reviewed(id: "a"), "b": reviewed(id: "b")},
        weights: {"a": 3},
      );

      expect(counts["a"]! / counts["b"]!, closeTo(3, 0.3));
    });

    test("Grundgewicht bleibt trotz unterschiedlichem Lernverlauf wirksam", () {
      // Wichtig + sicher gegen unwichtig + schwach: beides fällig.
      final safe = reviewed(difficulty: 1);
      final weak = reviewed(difficulty: 10);

      final important = algorithm.selectionScore(safe, baseWeight: 10);
      final unimportant = algorithm.selectionScore(weak, baseWeight: 1);

      expect(important, greaterThan(unimportant));

      // Das schwache, niedrig gewichtete Element verschwindet aber nicht.
      expect(unimportant, greaterThan(algorithm.selectionScore(safe)));
    });

    test("falsch beantwortete Karte hat höhere Priorität", () {
      final right = reviewed(ago: const Duration(days: 1));
      final wrong = reviewed(ago: const Duration(days: 1));

      algorithm.answer(right, true);
      algorithm.answer(wrong, false);

      now = now.add(const Duration(minutes: 10));

      expect(
        algorithm.selectionScore(wrong),
        greaterThan(10 * algorithm.selectionScore(right)),
      );
      expect(algorithm.need(wrong), greaterThan(algorithm.need(right)));
    });

    test("Fehler zählt auch bei lange nicht gefragter Karte", () {
      final card = reviewed(stability: 48, ago: const Duration(days: 30));

      algorithm.answer(card, false);

      expect(card.difficulty, 6);
      expect(card.stability, algorithm.lapseStability);
    });

    test("gerade gefragte Karte ist praktisch gesperrt", () {
      final card = LearningCard(id: "c");

      algorithm.answer(card, true);

      expect(algorithm.selectionScore(card), lessThan(0.001));
    });

    test("Fehler kommt nach wenigen Minuten wieder, nicht sofort", () {
      final card = LearningCard(id: "c");

      algorithm.answer(card, false);

      expect(algorithm.due(card), lessThan(0.001));

      now = now.add(const Duration(minutes: 3));

      expect(algorithm.due(card), greaterThanOrEqualTo(1));
    });

    test("lange nicht gefragte Karte wird wieder relevant, aber begrenzt", () {
      final card = reviewed(stability: 24, ago: const Duration(hours: 2));

      final early = algorithm.selectionScore(card);

      card.lastReviewed = now.subtract(const Duration(days: 2));

      final dueScore = algorithm.selectionScore(card);

      card.lastReviewed = now.subtract(const Duration(days: 365));

      final late = algorithm.selectionScore(card);

      expect(dueScore, greaterThan(100 * early));
      expect(late, closeTo(algorithm.maxDue, 1e-9));
    });

    test("mehrfach richtig verlängert den Abstand schrittweise", () {
      final card = LearningCard(id: "c");
      final intervals = <double>[];

      for (var i = 0; i < 5; i++) {
        algorithm.answer(card, true);
        intervals.add(card.stability);

        // Erst wieder fragen, wenn die Karte deutlich fällig ist.
        now = now.add(Duration(minutes: (card.stability * 60 * 3).ceil()));
      }

      for (var i = 1; i < intervals.length; i++) {
        expect(intervals[i], greaterThan(intervals[i - 1] * 1.5));
      }

      expect(card.difficulty, lessThan(5));
    });

    test("richtig, richtig, falsch setzt den Abstand zurück", () {
      final card = LearningCard(id: "c");

      algorithm.answer(card, true);
      now = now.add(const Duration(hours: 6));
      algorithm.answer(card, true);
      now = now.add(const Duration(days: 2));

      final before = card.difficulty;

      algorithm.answer(card, false);

      expect(card.stability, algorithm.lapseStability);
      expect(card.difficulty, before + 1);
    });

    test("nach einer Pause gewusst: Abstand folgt der Pause", () {
      final card = LearningCard(id: "c");

      algorithm.answer(card, false);
      now = now.add(const Duration(days: 1));
      algorithm.answer(card, true);

      expect(card.stability, closeTo(12, 0.1));
    });

    test("Werte bleiben in ihren Grenzen", () {
      final card = LearningCard(id: "c");

      for (var i = 0; i < 30; i++) {
        algorithm.answer(card, false);
      }

      expect(card.difficulty, 10);
      expect(algorithm.need(card), 2);

      for (var i = 0; i < 60; i++) {
        now = now.add(const Duration(days: 400));
        algorithm.answer(card, true);
      }

      expect(card.difficulty, 1);
      expect(card.stability, algorithm.maxStability);
      expect(algorithm.need(card), 0.5);
    });

    test("Begründung nennt die Faktoren", () {
      final card = reviewed(difficulty: 8, ago: const Duration(days: 9));

      expect(
        algorithm.explain(card, baseWeight: 2),
        allOf(
          contains("Grundgewicht 2.0"),
          contains("erhöht"),
          contains("lange nicht gefragt"),
        ),
      );
      expect(
        algorithm.explain(LearningCard(id: "n")),
        contains("noch nie gefragt"),
      );
    });
  });

  group("Auswahl", () {
    test("wählt nur aus den übergebenen (gefilterten) Kandidaten", () {
      // Eine sehr dringende Karte außerhalb des Pools darf nie erscheinen.
      final cards = {
        "disabled": reviewed(
          id: "disabled",
          difficulty: 10,
          ago: const Duration(days: 30),
        ),
      };

      final selector = LearningSelector(algorithm: algorithm);

      for (var i = 0; i < 500; i++) {
        final id = selector.select(
          candidates: ["a", "b", "c"],
          idOf: (id) => id,
          cards: cards,
        );

        expect(id, isNot("disabled"));
      }

      expect(
        selector.select(candidates: <String>[], idOf: (id) => id, cards: cards),
        isNull,
      );
    });

    test("bei Gleichstand entscheidet der Zufall gleichmäßig", () {
      final ids = ["a", "b", "c", "d"];

      final counts = draw(ids, {for (final id in ids) id: reviewed(id: id)});

      for (final id in ids) {
        expect(counts[id]! / 20000, closeTo(0.25, 0.02));
      }
    });

    test("Mindestabstand: keine direkte Wiederholung", () {
      final ids = ["a", "b", "c", "d"];

      // "a" ist mit Abstand am dringendsten.
      final cards = {
        "a": reviewed(id: "a", difficulty: 10, ago: const Duration(days: 9)),
        for (final id in ids.skip(1))
          id: reviewed(id: id, ago: const Duration(minutes: 1)),
      };

      final selector = LearningSelector(
        algorithm: algorithm,
        random: Random(2),
      );

      String? previous;
      String? beforePrevious;

      for (var i = 0; i < 300; i++) {
        final id = selector.select(
          candidates: ids,
          idOf: (id) => id,
          cards: cards,
        );

        // Halber Pool gesperrt: die letzten zwei Fragen.
        expect(id, isNot(previous));
        expect(id, isNot(beforePrevious));

        beforePrevious = previous;
        previous = id;
      }
    });

    test("einzelne Frage im Pool bleibt wählbar", () {
      final selector = LearningSelector(algorithm: algorithm);

      for (var i = 0; i < 3; i++) {
        expect(
          selector.select(candidates: ["a"], idOf: (id) => id, cards: {}),
          "a",
        );
      }
    });

    test("viele neue Karten verdrängen fällige Wiederholungen nicht", () {
      final ids = [for (var i = 0; i < 400; i++) "new$i", "weak", "safe"];

      final cards = {
        "weak": reviewed(id: "weak", difficulty: 8),
        "safe": reviewed(id: "safe", difficulty: 3),
      };

      final counts = draw(ids, cards);

      final newShare = 1 - (counts["weak"]! + counts["safe"]!) / 20000;

      // 400 neue Karten zählen zusammen wie 8 fällige:
      // 8 / (8 + 1,6 + 0,6).
      expect(newShare, closeTo(8 / 10.2, 0.02));
      expect(counts["weak"]! / counts["safe"]!, closeTo(1.6 / 0.6, 0.4));
    });

    test("neue Karten dominieren, wenn nichts fällig ist", () {
      final ids = [for (var i = 0; i < 50; i++) "new$i", "fresh"];

      final cards = {
        "fresh": reviewed(id: "fresh", ago: const Duration(minutes: 2)),
      };

      expect(draw(ids, cards)["fresh"]! / 20000, lessThan(0.01));
    });

    test("Grundgewicht gilt auch für neue Karten", () {
      final counts = draw(["a", "b"], {}, weights: {"a": 4});

      expect(counts["a"]! / counts["b"]!, closeTo(4, 0.4));
    });
  });

  group("Grammatik", () {
    GrammarLearning learning({int seed = 3}) {
      return GrammarLearning(random: Random(seed), clock: clock);
    }

    const tenses = ["Präsens", "Imperfekt", "Aorist"];

    Map<String, int> drawTense(GrammarLearning grammar, List<String> values) {
      final counts = {for (final value in values) value: 0};

      for (var i = 0; i < 20000; i++) {
        final value = grammar.pickValue("verb", "tense", values);

        counts[value] = counts[value]! + 1;
      }

      return counts;
    }

    test("Karten-IDs sind als Firestore-Dokument-ID verwendbar", () {
      expect(
        GrammarLearning.dimensionId("verb", "voice", "Medium/Passiv"),
        "dim.verb.voice.Medium-Passiv",
      );
      expect(
        GrammarLearning.dimensionId("verb", "person", "1. Sg"),
        "dim.verb.person.1-Sg",
      );
      expect(
        GrammarLearning.dimensionId("noun", "number", "Pl."),
        "dim.noun.number.Pl",
      );
      expect(GrammarLearning.lemmaId(41), "lemma.41");
    });

    test("ohne Lernstand werden alle Werte gleich häufig gewählt", () {
      final counts = drawTense(learning(), tenses);

      for (final tense in tenses) {
        expect(counts[tense]! / 20000, closeTo(1 / 3, 0.02));
      }
    });

    test("schwache Kategorie wird gezielt stärker priorisiert", () {
      final grammar = learning();

      final aorist = GrammarLearning.dimensionId("verb", "tense", "Aorist");
      final present = GrammarLearning.dimensionId("verb", "tense", "Präsens");

      for (var i = 0; i < 3; i++) {
        grammar.record({aorist: false, present: true});
      }

      expect(grammar.need(aorist), closeTo(1.6, 1e-9));
      expect(grammar.need(present), closeTo(0.85, 1e-9));

      // Nur das Tempus ist betroffen, nicht z. B. die Person.
      expect(
        grammar.need(GrammarLearning.dimensionId("verb", "person", "1. Sg")),
        1,
      );

      final counts = drawTense(grammar, tenses);

      expect(counts["Aorist"]! / counts["Präsens"]!, closeTo(1.6 / 0.85, 0.2));
      expect(counts["Aorist"]!, greaterThan(counts["Imperfekt"]!));
    });

    test("nur zulässige Werte werden gewählt", () {
      final grammar = learning();

      // Aorist ist sehr schwach, für dieses Verb aber nicht zulässig.
      for (var i = 0; i < 5; i++) {
        grammar.record({
          GrammarLearning.dimensionId("verb", "tense", "Aorist"): false,
        });
      }

      final counts = drawTense(grammar, const ["Präsens", "Imperfekt"]);

      expect(counts.keys, ["Präsens", "Imperfekt"]);
      expect(counts.values.reduce((a, b) => a + b), 20000);
    });

    test("einmal falsch, mehrfach falsch, mehrfach richtig", () {
      final grammar = learning();

      const id = "dim.noun.case.Dativ";

      grammar.record({id: false});
      final once = grammar.need(id);

      grammar.record({id: false});
      grammar.record({id: false});
      final often = grammar.need(id);

      expect(once, greaterThan(1));
      expect(often, greaterThan(once));

      for (var i = 0; i < 40; i++) {
        grammar.record({id: true});
      }

      expect(grammar.need(id), 0.5);
    });

    test("sichere Werte werden nach langer Pause wieder neutral", () {
      final grammar = learning();

      const id = "dim.noun.case.Dativ";

      for (var i = 0; i < 12; i++) {
        grammar.record({id: true});
      }

      final safe = grammar.need(id);

      now = now.add(const Duration(days: 14));
      final later = grammar.need(id);

      now = now.add(const Duration(days: 365));

      expect(safe, closeTo(0.5, 0.11));
      expect(later, greaterThan(safe));
      expect(grammar.need(id), closeTo(1, 0.01));
    });

    test("Schwächen verschwinden nicht durch Abwarten", () {
      final grammar = learning();

      const id = "dim.noun.case.Dativ";

      grammar.record({id: false});
      final weak = grammar.need(id);

      now = now.add(const Duration(days: 365));

      expect(grammar.need(id), weak);
    });

    test("Gruppen behalten ihr Grundgewicht (z. B. εἰμί ein Drittel)", () {
      final grammar = learning();

      final all = [for (var i = 0; i < 200; i++) i];
      final aoristSheet = [for (var i = 0; i < 20; i++) i];
      const eimi = 41;

      var eimiCount = 0;

      for (var i = 0; i < 20000; i++) {
        final picked = grammar.pickFromGroups([
          all,
          aoristSheet,
          [eimi],
        ], GrammarLearning.lemmaId);

        if (picked == eimi) {
          eimiCount++;
        }
      }

      // 1/3 über die eigene Gruppe + 1/3 · 1/200 über die Gesamtliste.
      expect(eimiCount / 20000, closeTo(1 / 3 + 1 / 600, 0.02));
    });

    test("Lernbedarf verschiebt die Gruppen, hebt die Priorität nicht auf", () {
      final grammar = learning();

      final all = [for (var i = 0; i < 200; i++) i];
      const eimi = 41;

      double share() {
        var count = 0;

        for (var i = 0; i < 20000; i++) {
          if (grammar.pickFromGroups([
                all,
                [eimi],
              ], GrammarLearning.lemmaId) ==
              eimi) {
            count++;
          }
        }

        return count / 20000;
      }

      final neutral = share();

      for (var i = 0; i < 40; i++) {
        grammar.record({GrammarLearning.lemmaId(eimi): true});
      }

      final mastered = share();

      for (var i = 0; i < 40; i++) {
        grammar.record({GrammarLearning.lemmaId(eimi): false});
      }

      final weak = share();

      expect(neutral, closeTo(0.5, 0.02));
      // Sicher beherrscht: seltener, aber weiterhin deutlich präsent.
      expect(mastered, closeTo(1 / 3, 0.02));
      expect(weak, closeTo(2 / 3, 0.02));
    });

    test("schwache Grundform kommt innerhalb ihrer Gruppe häufiger", () {
      final grammar = learning();

      final group = [1, 2, 3, 4];

      for (var i = 0; i < 5; i++) {
        grammar.record({GrammarLearning.lemmaId(1): false});
      }

      final counts = {for (final id in group) id: 0};

      for (var i = 0; i < 20000; i++) {
        final picked = grammar.pickFromGroups([group], GrammarLearning.lemmaId);

        counts[picked] = counts[picked]! + 1;
      }

      expect(counts[1]! / counts[2]!, closeTo(2, 0.2));
    });

    test("record liefert die geänderten Karten zum Speichern", () {
      final grammar = learning();

      final changed = grammar.record({"dim.a": true, "lemma.1": false});

      expect(changed.map((card) => card.id), ["dim.a", "lemma.1"]);
      expect(changed[0].difficulty, 4.75);
      expect(changed[1].difficulty, 6);
      expect(changed.every((card) => card.lastReviewed == now), isTrue);
    });
  });
}
