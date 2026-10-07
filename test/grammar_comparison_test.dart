import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/grammar/adjective_comparison.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/services/greek/grammar/adjective_comparisons.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_settings_service.dart';
import 'package:theologie_lernapp/utils/greek_normalization.dart';
import 'package:theologie_lernapp/utils/word_type_labels.dart';

AdjectiveComparison _adjective(String positive) {
  return AdjectiveComparisons.all.firstWhere((c) => c.positive == positive);
}

ComparisonTarget _target(String direction, {String shown = ""}) {
  return (direction: direction, shown: shown, note: null, prompt: "");
}

bool _correct(
  String positive,
  String direction,
  String input, {
  String shown = "",
}) {
  return checkComparisonAnswer(
    comparison: _adjective(positive),
    target: _target(direction, shown: shown),
    input: input,
  ).correct;
}

const _toComparative = GrammarQuestionPicker.positiveToComparative;
const _toSuperlative = GrammarQuestionPicker.positiveToSuperlative;
const _comparativeToPositive = GrammarQuestionPicker.comparativeToPositive;
const _superlativeToPositive = GrammarQuestionPicker.superlativeToPositive;
const _both = GrammarQuestionPicker.positiveToBoth;
const _genitive = GrammarQuestionPicker.comparativeGenitive;

void main() {
  group("Lernstoff", () {
    test("Klausurtabelle: unregelmäßige Formen am richtigen Grad", () {
      final agathos = _adjective("ἀγαθός");

      expect(AdjectiveComparison.allTexts(agathos.comparatives), [
        "ἀμείνων",
        "ἄμεινον",
        "βελτίων",
        "βέλτιον",
        "κρείττων",
        "κρεῖττον",
      ]);
      expect(AdjectiveComparison.allTexts(agathos.superlatives), [
        "ἄριστος",
        "βέλτιστος",
        "κράτιστος",
      ]);

      final kakos = _adjective("κακός");

      expect(AdjectiveComparison.allTexts(kakos.comparatives), [
        "κακίων",
        "κάκιον",
        "χείρων",
        "χεῖρον",
        "ἥττων",
        "ἧττον",
      ]);
      expect(AdjectiveComparison.allTexts(kakos.superlatives), [
        "κάκιστος",
        "χείριστος",
        "ἥκιστα",
      ]);

      expect(AdjectiveComparison.allTexts(_adjective("μέγας").comparatives), [
        "μείζων",
        "μεῖζον",
      ]);
      expect(AdjectiveComparison.allTexts(_adjective("πολύς").comparatives), [
        "πλείων",
        "πλέον",
      ]);
      expect(_adjective("πολύς").comparativeGenitives, ["πλείονος", "πλέονος"]);
    });

    test("vollständige Reihe für das Feedback", () {
      expect(
        _adjective("ἀγαθός").row,
        "ἀγαθός → ἀμείνων (ἄμεινον) / βελτίων (βέλτιον) / κρείττων (κρεῖττον)"
        " → ἄριστος / βέλτιστος / κράτιστος",
      );
      expect(
        _adjective("ὀλίγος").row,
        "ὀλίγος → (ὀλείζων) / ἐλάττων (ἔλαττον) → (ὀλίγιστος) / ἐλάχιστος",
      );
      expect(
        _adjective("κακός").row,
        endsWith("→ κάκιστος / χείριστος / ἥκιστα (Adv.)"),
      );
    });

    test("Komparative auf -ων/-ον bzw. -τερος, Superlative auf -τος", () {
      for (final comparison in AdjectiveComparisons.all) {
        expect(comparison.comparatives, isNotEmpty);
        expect(comparison.superlatives, isNotEmpty);

        for (final form in comparison.comparatives) {
          expect(
            form.text.endsWith("ων") || form.text.endsWith("τερος"),
            isTrue,
            reason: form.text,
          );

          if (form.neuter != null) {
            expect(form.neuter!.endsWith("ον"), isTrue, reason: form.neuter);
          }
        }

        for (final form in comparison.superlatives) {
          expect(
            form.text.endsWith("τος") || form.text == "ἥκιστα",
            isTrue,
            reason: form.text,
          );
        }
      }
    });

    test("normalisiert fallen keine Formen verschiedener Grade zusammen", () {
      final degreeOf = <String, String>{};

      void add(String form, String degree) {
        final key = normalizeGreekForComparison(form);
        final previous = degreeOf.putIfAbsent(key, () => degree);

        expect(previous, degree, reason: form);
      }

      for (final comparison in AdjectiveComparisons.all) {
        add(comparison.positive, "Positiv");

        for (final form in AdjectiveComparison.allTexts(
          comparison.comparatives,
        )) {
          add(form, "Komparativ");
        }

        for (final form in AdjectiveComparison.allTexts(
          comparison.superlatives,
        )) {
          add(form, "Superlativ");
        }
      }
    });

    test("eigene, eindeutige IDs außerhalb der Vokabelliste", () {
      final ids = [for (final c in AdjectiveComparisons.all) c.id];

      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id >= 10000), isTrue);
    });

    test("unregelmäßige Adjektive haben Vorrang", () {
      final weights = {
        for (final c in AdjectiveComparisons.all) c.positive: c.weight,
      };

      expect(weights["ἀγαθός"], greaterThanOrEqualTo(weights["κακός"]!));
      expect(weights["κακός"], greaterThan(weights["μέγας"]!));
      expect(weights["μικρός"], greaterThan(weights["πολύς"]!));
      expect(weights["πολύς"], greaterThan(weights["ὀλίγος"]!));
      expect(weights["ὀλίγος"], greaterThan(weights["καλός"]!));
      expect(weights["ταχύς"], greaterThan(weights["σοφός"]!));

      for (final c in AdjectiveComparisons.all.where((c) => !c.irregular)) {
        expect(c.weight, 1, reason: c.positive);
      }
    });

    test("ἐλάττων und ἐλάχιστος gehören zu μικρός und ὀλίγος", () {
      List<String> owners(String form, {required bool superlative}) => [
        for (final c in AdjectiveComparisons.ownersOf(
          form,
          superlative: superlative,
        ))
          c.positive,
      ];

      expect(owners("ἐλάττων", superlative: false), ["μικρός", "ὀλίγος"]);
      expect(owners("ἔλαττον", superlative: false), ["μικρός", "ὀλίγος"]);
      expect(owners("ἐλάχιστος", superlative: true), ["μικρός", "ὀλίγος"]);
      expect(owners("μείζων", superlative: false), ["μέγας"]);
      // Grad wird beachtet: μείζων ist kein Superlativ.
      expect(owners("μείζων", superlative: true), isEmpty);
    });
  });

  group("Antwortprüfung", () {
    test("regelmäßige Steigerung mit -τερος / -τατος", () {
      expect(_correct("σοφός", _toComparative, "σοφώτερος"), isTrue);
      expect(_correct("σοφός", _toSuperlative, "σοφώτατος"), isTrue);
      expect(_correct("ἄξιος", _toComparative, "ἀξιώτερος"), isTrue);
      expect(_correct("βέβαιος", _toSuperlative, "βεβαιότατος"), isTrue);
      expect(_correct("πονηρός", _toComparative, "πονηρότερος"), isTrue);
    });

    test("regelmäßige Steigerung mit -εσ-", () {
      expect(_correct("σώφρων", _toComparative, "σωφρονέστερος"), isTrue);
      expect(_correct("εὐδαίμων", _toSuperlative, "εὐδαιμονέστατος"), isTrue);
      expect(_correct("σώφρων", _toComparative, "σωφρονώτερος"), isFalse);
    });

    test("Komparativ und Superlativ werden nicht vertauscht", () {
      expect(_correct("σοφός", _toComparative, "σοφώτατος"), isFalse);
      expect(_correct("σοφός", _toSuperlative, "σοφώτερος"), isFalse);
      expect(_correct("ἀγαθός", _toComparative, "ἄριστος"), isFalse);
      expect(_correct("ἀγαθός", _toSuperlative, "ἀμείνων"), isFalse);
      expect(_correct("μέγας", _toSuperlative, "μείζων"), isFalse);
      // Eine falsche Form neben einer richtigen bleibt falsch.
      expect(_correct("ἀγαθός", _toComparative, "ἀμείνων ἄριστος"), isFalse);
    });

    test("alle Varianten von ἀγαθός sind richtig, auch im Neutrum", () {
      for (final form in [
        "ἀμείνων",
        "βελτίων",
        "κρείττων",
        "ἄμεινον",
        "βέλτιον",
        "κρεῖττον",
      ]) {
        expect(_correct("ἀγαθός", _toComparative, form), isTrue, reason: form);
      }

      for (final form in ["ἄριστος", "βέλτιστος", "κράτιστος"]) {
        expect(_correct("ἀγαθός", _toSuperlative, form), isTrue, reason: form);
      }

      expect(
        _correct("ἀγαθός", _toComparative, "ἀμείνων / βελτίων / κρείττων"),
        isTrue,
      );
    });

    test("κακός: χείρων, ἥττων, χεῖρον; ἥκιστα als Superlativ", () {
      for (final form in ["κακίων", "χείρων", "ἥττων", "κάκιον", "χεῖρον"]) {
        expect(_correct("κακός", _toComparative, form), isTrue, reason: form);
      }

      for (final form in ["κάκιστος", "χείριστος", "ἥκιστα"]) {
        expect(_correct("κακός", _toSuperlative, form), isTrue, reason: form);
      }

      expect(_correct("κακός", _toComparative, "ἥκιστα"), isFalse);
    });

    test("πολύς: πλείων / πλέον und der Genitiv πλείονος / πλέονος", () {
      expect(_correct("πολύς", _toComparative, "πλείων"), isTrue);
      expect(_correct("πολύς", _toComparative, "πλέον"), isTrue);
      expect(_correct("πολύς", _toSuperlative, "πλεῖστος"), isTrue);
      expect(_correct("πολύς", _toComparative, "πλεῖστος"), isFalse);

      expect(_correct("πολύς", _genitive, "πλείονος"), isTrue);
      expect(_correct("πολύς", _genitive, "πλέονος"), isTrue);
      expect(_correct("πολύς", _genitive, "πλείων"), isFalse);
    });

    test("μικρός und ὀλίγος, seltene Formen werden akzeptiert", () {
      for (final form in ["μικρότερος", "μείων", "μεῖον", "ἐλάττων"]) {
        expect(_correct("μικρός", _toComparative, form), isTrue, reason: form);
      }

      expect(_correct("μικρός", _toSuperlative, "ἐλάχιστος"), isTrue);
      expect(_correct("μικρός", _toSuperlative, "μικρότατος"), isTrue);
      expect(_correct("ὀλίγος", _toComparative, "ὀλείζων"), isTrue);
      expect(_correct("ὀλίγος", _toSuperlative, "ὀλίγιστος"), isTrue);
      expect(_correct("ὀλίγος", _toComparative, "μείων"), isFalse);
    });

    test("Komparativ/Superlativ → Positiv", () {
      expect(
        _correct("μέγας", _comparativeToPositive, "μέγας", shown: "μείζων"),
        isTrue,
      );
      expect(
        _correct("μέγας", _comparativeToPositive, "μικρός", shown: "μείζων"),
        isFalse,
      );
      expect(
        _correct("κακός", _comparativeToPositive, "κακός", shown: "ἧττον"),
        isTrue,
      );
      expect(
        _correct(
          "ἀγαθός",
          _superlativeToPositive,
          "ἀγαθός",
          shown: "κράτιστος",
        ),
        isTrue,
      );

      // ἐλάττων / ἐλάχιστος: beide Positive sind richtig.
      for (final positive in ["μικρός", "ὀλίγος"]) {
        expect(
          _correct(
            "μικρός",
            _comparativeToPositive,
            positive,
            shown: "ἐλάττων",
          ),
          isTrue,
        );
        expect(
          _correct(
            "ὀλίγος",
            _superlativeToPositive,
            positive,
            shown: "ἐλάχιστος",
          ),
          isTrue,
        );
      }

      final result = checkComparisonAnswer(
        comparison: _adjective("μικρός"),
        target: _target(_comparativeToPositive, shown: "ἐλάττων"),
        input: "μέγας",
      );

      expect(result.correct, isFalse);
      expect(result.expected, "μικρός / ὀλίγος");
    });

    test("komplette Reihe: Komparativ und Superlativ", () {
      expect(_correct("κακός", _both, "κακίων κάκιστος"), isTrue);
      expect(_correct("κακός", _both, "κακίων – κάκιστος"), isTrue);
      expect(_correct("κακός", _both, "χείρων, ἥκιστα"), isTrue);
      expect(_correct("κακός", _both, "κάκιστος κακίων"), isTrue);

      expect(_correct("κακός", _both, "κακίων"), isFalse);
      expect(_correct("κακός", _both, "κάκιστος κάκιστος"), isFalse);
      expect(_correct("κακός", _both, "κακίων μέγιστος"), isFalse);

      final result = checkComparisonAnswer(
        comparison: _adjective("μέγας"),
        target: _target(_both),
        input: "",
      );

      expect(result.correct, isFalse);
      expect(result.expected, "μείζων (μεῖζον) – μέγιστος");
    });

    test("Akzente, Spiritus, Großschreibung und Schluss-Sigma", () {
      expect(_correct("ἀγαθός", _toComparative, "αμεινων"), isTrue);
      expect(_correct("ἀγαθός", _toComparative, "ΑΜΕΙΝΩΝ"), isTrue);
      expect(_correct("ἀγαθός", _toComparative, "κρειττον"), isTrue);
      expect(_correct("κακός", _toComparative, "ηττων"), isTrue);
      expect(_correct("κακός", _toSuperlative, "ηκιστα"), isTrue);
      expect(_correct("πολύς", _toSuperlative, "πλειστοσ"), isTrue);
      expect(
        _correct("μέγας", _comparativeToPositive, "μεγασ", shown: "μεῖζον"),
        isTrue,
      );

      // Wirklich verschiedene Formen bleiben verschieden.
      expect(_correct("μέγας", _toComparative, "μεῖον"), isFalse);
      expect(_correct("μέγας", _toComparative, "μειζον"), isTrue);
      expect(_correct("ἀγαθός", _toComparative, "αμεινος"), isFalse);
    });

    test("leere Eingabe ist falsch", () {
      expect(_correct("ἀγαθός", _toComparative, ""), isFalse);
      expect(_correct("ἀγαθός", _toComparative, "  / "), isFalse);
    });
  });

  group("Fragegenerierung", () {
    test("alle Fragearten kommen vor, der Genitiv nur bei πολύς", () {
      final grammar = GrammarLearning(random: Random(1));
      final random = Random(2);

      Set<String> directions(String positive) => {
        for (var i = 0; i < 400; i++)
          GrammarQuestionPicker.pickComparisonTarget(
            grammar,
            _adjective(positive),
            random,
          ).direction,
      };

      expect(directions("πολύς"), {
        _toComparative,
        _toSuperlative,
        _comparativeToPositive,
        _superlativeToPositive,
        _both,
        _genitive,
      });
      expect(directions("ἀγαθός").contains(_genitive), isFalse);
      expect(directions("σοφός").length, 5);
    });

    test("angezeigte Form passt zur Frageart, seltene Formen nie", () {
      final grammar = GrammarLearning(random: Random(3));
      final random = Random(4);

      for (final comparison in AdjectiveComparisons.all) {
        final comparatives = AdjectiveComparison.allTexts([
          for (final f in comparison.comparatives)
            if (!f.rare) f,
        ]);
        final superlatives = AdjectiveComparison.allTexts([
          for (final f in comparison.superlatives)
            if (!f.rare) f,
        ]);

        for (var i = 0; i < 100; i++) {
          final target = GrammarQuestionPicker.pickComparisonTarget(
            grammar,
            comparison,
            random,
          );

          switch (target.direction) {
            case _comparativeToPositive:
              expect(comparatives, contains(target.shown));
            case _superlativeToPositive:
              expect(superlatives, contains(target.shown));
            default:
              expect(target.shown, comparison.positive);
              expect(target.note, comparison.translations.join(", "));
          }

          expect(target.prompt, isNotEmpty);
        }
      }
    });

    test("Neutra werden ebenfalls vorgelegt und als Neutrum markiert", () {
      final grammar = GrammarLearning(random: Random(5));
      final random = Random(6);

      final shown = <String, String?>{};

      for (var i = 0; i < 1000; i++) {
        final target = GrammarQuestionPicker.pickComparisonTarget(
          grammar,
          _adjective("ἀγαθός"),
          random,
        );

        if (target.direction == _comparativeToPositive) {
          shown[target.shown] = target.note;
        }
      }

      expect(shown.keys.toSet(), {
        "ἀμείνων",
        "ἄμεινον",
        "βελτίων",
        "βέλτιον",
        "κρείττων",
        "κρεῖττον",
      });
      expect(shown["ἄμεινον"], "Neutrum");
      expect(shown["ἀμείνων"], isNull);
    });

    test("unregelmäßige Adjektive kommen deutlich häufiger", () {
      final grammar = GrammarLearning(random: Random(7));

      final counts = <String, int>{};

      for (var i = 0; i < 20000; i++) {
        final picked = GrammarQuestionPicker.pickEntry(
          grammar,
          AdjectiveComparisons.entries,
        );

        counts[picked.lemma] = (counts[picked.lemma] ?? 0) + 1;
      }

      final irregular = AdjectiveComparisons.all
          .where((c) => c.irregular)
          .fold(0, (sum, c) => sum + (counts[c.positive] ?? 0));

      expect(irregular / 20000, greaterThan(0.75));
      expect(counts["ἀγαθός"]!, greaterThan(counts["μέγας"]!));
      expect(counts["μέγας"]!, greaterThan(counts["καλός"]!));
      expect(counts["καλός"]!, greaterThan(counts["σοφός"]!));
      // Regelmäßige kommen trotzdem vor.
      expect(counts["σοφός"], greaterThan(0));
    });

    test("falsch beantwortete Adjektive kommen häufiger", () {
      final grammar = GrammarLearning(random: Random(8));
      final sophos = _adjective("σοφός");

      int count() {
        var result = 0;

        for (var i = 0; i < 20000; i++) {
          if (GrammarQuestionPicker.pickEntry(
                grammar,
                AdjectiveComparisons.entries,
              ).id ==
              sophos.id) {
            result++;
          }
        }

        return result;
      }

      final before = count();

      for (var i = 0; i < 5; i++) {
        grammar.record({GrammarLearning.lemmaId(sophos.id): false});
      }

      expect(count(), greaterThan(before * 1.5));
    });

    test("Filter: Wortart und Steigerungsart, unabhängig von Schritten", () {
      final agathos = AdjectiveComparisons.entries.firstWhere(
        (e) => e.lemma == "ἀγαθός",
      );
      final sophos = AdjectiveComparisons.entries.firstWhere(
        (e) => e.lemma == "σοφός",
      );

      bool available(
        GreekVocabularyEntry entry, {
        List<String> types = const ["comparison"],
        List<String> kinds = const ["irregular", "regular"],
      }) {
        return GrammarQuestionPicker.isAvailable(
          entry,
          enabledSteps: const [1],
          enabledTypes: types,
          pronounIds: const {},
          comparisonIds: AdjectiveComparisons.idsOfKinds(kinds),
        );
      }

      expect(available(agathos), isTrue);
      expect(available(sophos), isTrue);
      expect(available(agathos, kinds: ["irregular"]), isTrue);
      expect(available(sophos, kinds: ["irregular"]), isFalse);
      expect(available(sophos, kinds: ["regular"]), isTrue);
      expect(available(agathos, types: ["noun", "verb"]), isFalse);
    });
  });

  group("Einstellungen", () {
    test("Steigerungsarten werden gelesen und gespeichert", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledTypes': ["comparison"],
        'enabledComparisonKinds': ["irregular", "kaputt", 3],
      });

      expect(settings.enabledTypes, ["comparison"]);
      expect(settings.enabledComparisonKinds, ["irregular"]);
      expect(settings.toMap()['enabledComparisonKinds'], ["irregular"]);

      // Ohne gespeicherte Unterauswahl: alle.
      expect(
        GrammarTrainerSettings.fromMap(<String, dynamic>{
          'enabledTypes': ["noun"],
        }).enabledComparisonKinds,
        ["irregular", "regular"],
      );
    });

    test("Beschriftung", () {
      expect(wordTypeFilterLabel("comparison"), "Adjektivsteigerung");
      expect(
        GrammarQuestionPicker.comparisonKindLabel("irregular"),
        "Unregelmäßige",
      );
      expect(
        GrammarQuestionPicker.comparisonKindLabel("regular"),
        "Regelmäßige",
      );
    });
  });
}
