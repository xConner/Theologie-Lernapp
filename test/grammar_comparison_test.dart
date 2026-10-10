import 'dart:convert';
import 'dart:io';
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

ComparisonAnswerResult _check(
  String shown, {
  String? lemma,
  String? translation,
}) {
  return checkComparisonAnswer(
    shown: shown,
    lemmaInput: lemma,
    translationInput: translation,
  );
}

bool _lemma(String shown, String input) => _check(shown, lemma: input).correct;

bool _translation(String shown, String input) {
  return _check(shown, translation: input).correct;
}

void main() {
  group("Lernstoff", () {
    test("Klausurtabelle: Formen am richtigen Grad", () {
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

    test("normalisiert fällt keine gesteigerte Form mit einem Positiv "
        "oder einem anderen Grad zusammen", () {
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

        for (final form in comparison.comparativeGenitives) {
          add(form, "Genitiv");
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
      List<String> owners(String form) => [
        for (final c in AdjectiveComparisons.ownersOf(form)) c.positive,
      ];

      expect(owners("ἐλάττων"), ["μικρός", "ὀλίγος"]);
      expect(owners("ἔλαττον"), ["μικρός", "ὀλίγος"]);
      expect(owners("ἐλάχιστος"), ["μικρός", "ὀλίγος"]);
      expect(owners("μείζων"), ["μέγας"]);
      expect(owners("πλέονος"), ["πολύς"]);
      // Ein Positiv ist keine gesteigerte Form.
      expect(owners("μέγας"), isEmpty);
    });

    test("vorgelegte Formen: alle gesteigerten, nie seltene oder Positive", () {
      final olig = [for (final f in _adjective("ὀλίγος").shownForms) f.text];

      expect(olig, ["ἐλάττων", "ἔλαττον", "ἐλάχιστος"]);

      final agathos = {
        for (final f in _adjective("ἀγαθός").shownForms) f.text: f.note,
      };

      expect(agathos.keys, [
        "ἀμείνων",
        "ἄμεινον",
        "βελτίων",
        "βέλτιον",
        "κρείττων",
        "κρεῖττον",
        "ἄριστος",
        "βέλτιστος",
        "κράτιστος",
      ]);
      expect(agathos["ἄμεινον"], "Neutrum");
      expect(agathos["ἀμείνων"], isNull);

      final kakos = {
        for (final f in _adjective("κακός").shownForms) f.text: f.note,
      };

      expect(kakos["ἥκιστα"], "Adv.");

      final polys = {
        for (final f in _adjective("πολύς").shownForms) f.text: f.note,
      };

      expect(polys, {
        "πλείων": null,
        "πλέον": "Neutrum",
        "πλεῖστος": null,
        "πλείονος": "Gen. Sg.",
        "πλέονος": "Gen. Sg.",
      });

      for (final comparison in AdjectiveComparisons.all) {
        for (final form in comparison.shownForms) {
          expect(form.text, isNot(comparison.positive));
        }
      }
    });
  });

  group("Antwortprüfung: Grundform", () {
    test("regelmäßige Steigerung (-τερος / -τατος, -εσ-)", () {
      expect(_lemma("σοφώτερος", "σοφός"), isTrue);
      expect(_lemma("σοφώτατος", "σοφός"), isTrue);
      expect(_lemma("ἀξιώτερος", "ἄξιος"), isTrue);
      expect(_lemma("βεβαιότατος", "βέβαιος"), isTrue);
      expect(_lemma("πονηρότερος", "πονηρός"), isTrue);
      expect(_lemma("σωφρονέστερος", "σώφρων"), isTrue);
      expect(_lemma("εὐδαιμονέστατος", "εὐδαίμων"), isTrue);

      expect(_lemma("σοφώτερος", "σοφώτερος"), isFalse);
      expect(_lemma("σωφρονέστερος", "εὐδαίμων"), isFalse);
    });

    test("unregelmäßige Steigerung, auch Neutra und ἥκιστα", () {
      for (final form in [
        "ἀμείνων",
        "βέλτιον",
        "κρείττων",
        "κρεῖττον",
        "ἄριστος",
        "βέλτιστος",
        "κράτιστος",
      ]) {
        expect(_lemma(form, "ἀγαθός"), isTrue, reason: form);
        expect(_lemma(form, "κακός"), isFalse, reason: form);
      }

      for (final form in ["χείρων", "ἧττον", "κάκιστος", "ἥκιστα"]) {
        expect(_lemma(form, "κακός"), isTrue, reason: form);
      }

      expect(_lemma("μεῖζον", "μέγας"), isTrue);
      expect(_lemma("μέγιστος", "μέγας"), isTrue);
      expect(_lemma("μεῖον", "μικρός"), isTrue);
      expect(_lemma("μεῖον", "μέγας"), isFalse);
      expect(_lemma("θᾶττον", "ταχύς"), isTrue);
      expect(_lemma("κάλλιστος", "καλός"), isTrue);
    });

    test("πολύς: πλείων / πλέον, πλεῖστος und der Genitiv", () {
      for (final form in [
        "πλείων",
        "πλέον",
        "πλεῖστος",
        "πλείονος",
        "πλέονος",
      ]) {
        expect(_lemma(form, "πολύς"), isTrue, reason: form);
      }
    });

    test("mehrere akzeptierte Grundformen: ἐλάττων, ἐλάχιστος", () {
      for (final form in ["ἐλάττων", "ἔλαττον", "ἐλάχιστος"]) {
        expect(_lemma(form, "μικρός"), isTrue, reason: form);
        expect(_lemma(form, "ὀλίγος"), isTrue, reason: form);
        expect(_lemma(form, "μικρός / ὀλίγος"), isTrue, reason: form);
        expect(_lemma(form, "μέγας"), isFalse, reason: form);
      }

      // Eine falsche neben einer richtigen bleibt falsch.
      expect(_lemma("ἐλάττων", "μικρός μέγας"), isFalse);
    });

    test("Akzente, Spiritus, Großschreibung und Schluss-Sigma", () {
      expect(_lemma("ἀμείνων", "αγαθος"), isTrue);
      expect(_lemma("ἀμείνων", "ΑΓΑΘΟΣ"), isTrue);
      expect(_lemma("ἥκιστα", "κακοσ"), isTrue);
      expect(_lemma("ἐλάχιστος", "ολιγος"), isTrue);
      expect(_lemma("εὐδαιμονέστερος", "ευδαιμων"), isTrue);
      expect(_lemma("μείζων", " μέγας "), isTrue);

      // Wirklich verschiedene Wörter bleiben verschieden.
      expect(_lemma("μείζων", "μεγα"), isFalse);
      expect(_lemma("ἀμείνων", "αγαθον"), isFalse);
    });

    test("leere Eingabe ist falsch", () {
      expect(_lemma("ἀμείνων", ""), isFalse);
      expect(_lemma("ἀμείνων", "  / "), isFalse);
    });
  });

  group("Antwortprüfung: Übersetzung", () {
    test("Übersetzung der Grundform, eine richtige genügt", () {
      expect(_translation("ἀμείνων", "gut"), isTrue);
      expect(_translation("ἀμείνων", "Gut"), isTrue);
      expect(_translation("ἀμείνων", "besser"), isFalse);
      expect(_translation("μέγιστος", "groß"), isTrue);
      expect(_translation("πλέον", "viel"), isTrue);
      expect(_translation("σοφώτατος", "klug, weise"), isTrue);
      expect(_translation("σοφώτατος", "schnell"), isFalse);
      expect(_translation("θάττων", "schnell"), isTrue);
      expect(_translation("ἥκιστα", "schlecht"), isTrue);
      expect(_translation("ἐλάχιστος", "wenig"), isTrue);
      expect(_translation("ἐλάχιστος", "klein"), isTrue);
      expect(_translation("ἐλάχιστος", ""), isFalse);
    });

    test("Grundform und Übersetzung zusammen", () {
      final both = _check("κρείττων", lemma: "ἀγαθός", translation: "gut");

      expect(both.correct, isTrue);
      expect(both.lemmaCorrect, isTrue);
      expect(both.translationCorrect, isTrue);

      final wrongTranslation = _check(
        "κρείττων",
        lemma: "ἀγαθός",
        translation: "stark",
      );

      expect(wrongTranslation.correct, isFalse);
      expect(wrongTranslation.lemmaCorrect, isTrue);
      expect(wrongTranslation.translationCorrect, isFalse);

      final wrongLemma = _check("κρείττων", lemma: "κακός", translation: "gut");

      expect(wrongLemma.correct, isFalse);
      expect(wrongLemma.lemmaCorrect, isFalse);
      expect(wrongLemma.translationCorrect, isTrue);
    });

    test("nicht Gefragtes wird nicht gewertet", () {
      final onlyLemma = _check("μείζων", lemma: "μέγας");

      expect(onlyLemma.translationCorrect, isNull);
      expect(onlyLemma.correct, isTrue);

      final onlyTranslation = _check("μείζων", translation: "groß");

      expect(onlyTranslation.lemmaCorrect, isNull);
      expect(onlyTranslation.correct, isTrue);

      // Ohne jede Frage gibt es nichts Richtiges.
      expect(_check("μείζων").correct, isFalse);
    });
  });

  group("Fragegenerierung", () {
    test("jede vorlegbare Form kommt vor, Hinweis passt", () {
      final grammar = GrammarLearning(random: Random(1));

      for (final comparison in AdjectiveComparisons.all) {
        final forms = {for (final f in comparison.shownForms) f.text: f.note};

        final seen = <String>{};

        for (var i = 0; i < 300; i++) {
          final target = GrammarQuestionPicker.pickComparisonTarget(
            grammar,
            comparison,
          );

          expect(forms.keys, contains(target.shown));
          expect(target.note, forms[target.shown]);

          seen.add(target.shown);
        }

        expect(seen, forms.keys.toSet(), reason: comparison.positive);
      }
    });

    test("falsch beantwortete Formen kommen häufiger", () {
      final grammar = GrammarLearning(random: Random(2));
      final megas = _adjective("μέγας");

      for (var i = 0; i < 5; i++) {
        grammar.record({
          GrammarLearning.dimensionId("comparison", "form", "μεῖζον"): false,
        });
      }

      var count = 0;

      for (var i = 0; i < 9000; i++) {
        if (GrammarQuestionPicker.pickComparisonTarget(grammar, megas).shown ==
            "μεῖζον") {
          count++;
        }
      }

      // Neutral wäre ein Drittel (μείζων, μεῖζον, μέγιστος).
      expect(count / 9000, greaterThan(0.45));
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

    test("Grundform / Übersetzung: Defaults, Speichern, mindestens eins", () {
      final defaults = GrammarTrainerSettings.fromMap(null);

      expect(defaults.askComparisonLemma, isTrue);
      expect(defaults.askComparisonTranslation, isTrue);

      final onlyTranslation = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'askComparisonLemma': false,
        'askComparisonTranslation': true,
      });

      expect(onlyTranslation.askComparisonLemma, isFalse);
      expect(onlyTranslation.askComparisonTranslation, isTrue);
      expect(onlyTranslation.toMap()['askComparisonLemma'], isFalse);
      expect(onlyTranslation.toMap()['askComparisonTranslation'], isTrue);

      // Beides aus ist ungültig: dann wird die Grundform gefragt.
      final none = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'askComparisonLemma': false,
        'askComparisonTranslation': false,
      });

      expect(none.askComparisonLemma, isTrue);
      expect(none.askComparisonTranslation, isFalse);
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

  group("Flektierte Formen", () {
    List<String> describe(String form) {
      return AdjectiveComparisons.describeForm(form);
    }

    test("Formen der Folien und des Übungsblatts", () {
      // σοφώτερός ἐστιν / σοφώτατός ἐστιν / οὐδὲν μεῖζον.
      expect(describe("σοφώτερος"), ["Komparativ · Nominativ Sg. m"]);
      expect(describe("σοφώτατος"), ["Superlativ · Nominativ Sg. m"]);
      expect(describe("μεῖζον"), [
        "Komparativ · Nominativ Sg. n",
        "Komparativ · Akkusativ Sg. n",
      ]);

      // εὐδαιμονέστεροι, -τέρα und -τάταις wie im Übungsblatt.
      expect(describe("εὐδαιμονέστεροι"), ["Komparativ · Nominativ Pl. m"]);
      expect(describe("σοφωτέρα"), ["Komparativ · Nominativ Sg. f"]);
      expect(describe("σοφωτάταις"), ["Superlativ · Dativ Pl. f"]);

      // -ίων, -ιον (Gen. -ίονος); -ιστος, -ίστη, -ιστον.
      expect(describe("κακίονος"), ["Komparativ · Genitiv Sg. m/f/n"]);
      expect(describe("κάκιον"), [
        "Komparativ · Nominativ Sg. n",
        "Komparativ · Akkusativ Sg. n",
      ]);
      expect(describe("κακίστη"), ["Superlativ · Nominativ Sg. f"]);

      // Gen.: πλείονος oder πλέονος.
      expect(describe("πλείονος"), ["Komparativ · Genitiv Sg. m/f/n"]);
      expect(describe("πλέονος"), ["Komparativ · Genitiv Sg. m/f/n"]);
      expect(describe("πλέον"), [
        "Komparativ · Nominativ Sg. n",
        "Komparativ · Akkusativ Sg. n",
      ]);
    });

    test("Akzent wandert mit der Endung", () {
      final sophos = AdjectiveComparisons.basesOf(_adjective("σοφός"));

      String form(String text, String c, String n, String g) {
        return sophos
            .firstWhere((base) => base.text == text)
            .paradigm!
            .form(c, n, g)!;
      }

      expect(form("σοφώτερος", "Genitiv", "Sg", "m"), "σοφωτέρου");
      expect(form("σοφώτερος", "Nominativ", "Pl", "f"), "σοφώτεραι");
      expect(form("σοφώτατος", "Nominativ", "Sg", "f"), "σοφωτάτη");
      expect(form("σοφώτατος", "Akkusativ", "Pl", "n"), "σοφώτατα");
      expect(form("σοφός", "Genitiv", "Pl", "f"), "σοφῶν");

      final pleistos = AdjectiveComparisons.basesOf(
        _adjective("πολύς"),
      ).firstWhere((base) => base.text == "πλεῖστος").paradigm!;

      expect(pleistos.form("Genitiv", "Sg", "m"), "πλείστου");
      expect(pleistos.form("Nominativ", "Pl", "m"), "πλεῖστοι");
    });

    test("jede vorlegbare Steigerungsform lässt sich deklinieren", () {
      for (final comparison in AdjectiveComparisons.all) {
        for (final base in AdjectiveComparisons.basesOf(comparison)) {
          if (base.text == "ἥκιστα") {
            // Adverb.
            expect(base.paradigm, isNull);
            expect(base.note, "Adv.");
          } else {
            expect(base.paradigm, isNotNull, reason: base.text);
            expect(
              base.paradigm!.form("Nominativ", "Sg", "m"),
              base.text,
              reason: base.text,
            );
          }
        }
      }
    });

    test("Positiv nur nach der a-/o-Deklination, keine seltenen Formen", () {
      final withPositive = {
        for (final comparison in AdjectiveComparisons.all)
          if (AdjectiveComparisons.basesOf(comparison).any((base) {
            return base.degree == AdjectiveComparisons.positive;
          }))
            comparison.positive,
      };

      expect(withPositive, {
        "ἀγαθός",
        "κακός",
        "μικρός",
        "ὀλίγος",
        "καλός",
        "βέβαιος",
        "πονηρός",
        "σοφός",
        "ἄξιος",
      });

      final oligos = [
        for (final base in AdjectiveComparisons.basesOf(_adjective("ὀλίγος")))
          base.text,
      ];

      expect(oligos, ["ὀλίγος", "ἐλάττων", "ἐλάχιστος"]);

      // Femininum auf -α nach ε, ι, ρ.
      expect(describe("μικρά"), contains("Positiv · Nominativ Sg. f"));
      expect(describe("βεβαία"), ["Positiv · Nominativ Sg. f"]);
      expect(describe("σοφή"), ["Positiv · Nominativ Sg. f"]);
    });

    test("flektierte Form gehört zu allen ihren Adjektiven", () {
      expect(
        [
          for (final c in AdjectiveComparisons.ownersOf("ἐλάττονος"))
            c.positive,
        ],
        ["μικρός", "ὀλίγος"],
      );
      expect(
        [
          for (final c in AdjectiveComparisons.ownersOf("σοφωτέρου"))
            c.positive,
        ],
        ["σοφός"],
      );
      expect(AdjectiveComparisons.ownersOf("λόγου"), isEmpty);
      expect(AdjectiveComparisons.analysesOf("λόγου"), isEmpty);
    });

    test("Steigerungsstufe der Tabellenformen", () {
      final polys = _adjective("πολύς");

      expect(AdjectiveComparisons.degreeOf(polys, "πλείων"), "Komparativ");
      expect(AdjectiveComparisons.degreeOf(polys, "πλέον"), "Komparativ");
      expect(AdjectiveComparisons.degreeOf(polys, "πλέονος"), "Komparativ");
      expect(AdjectiveComparisons.degreeOf(polys, "πλεῖστος"), "Superlativ");
      expect(AdjectiveComparisons.degreeOf(polys, "πολύς"), "Positiv");
      expect(GrammarQuestionPicker.degrees, [
        "Positiv",
        "Komparativ",
        "Superlativ",
      ]);
    });
  });

  group("Antwortprüfung: Stufe und Form", () {
    ComparisonAnswerResult check(
      String shown, {
      String lemma = "σοφός",
      bool degreeAsked = true,
      bool formAsked = true,
      String? degree,
      String? grammaticalCase,
      String? number,
      String? gender,
    }) {
      return checkComparisonAnswer(
        shown: shown,
        lemmaInput: lemma,
        degreeAsked: degreeAsked,
        formAsked: formAsked,
        userDegree: degree,
        userCase: grammaticalCase,
        userNumber: number,
        userGender: gender,
      );
    }

    test("Stufe richtig und falsch", () {
      final right = check("σοφώτερος", formAsked: false, degree: "Komparativ");

      expect(right.correct, isTrue);
      expect(right.degreeCorrect, isTrue);
      expect(right.caseCorrect, isNull);

      final wrong = check("σοφώτερος", formAsked: false, degree: "Superlativ");

      expect(wrong.correct, isFalse);
      expect(wrong.degreeCorrect, isFalse);
      // Die Grundform bleibt richtig.
      expect(wrong.lemmaCorrect, isTrue);

      expect(
        check("σοφός", formAsked: false, degree: "Positiv").correct,
        isTrue,
      );
    });

    test("nicht gefragt: wie bisher nur Grundform und Übersetzung", () {
      final result = check("σοφώτερος", degreeAsked: false, formAsked: false);

      expect(result.correct, isTrue);
      expect(result.degreeCorrect, isNull);
      expect(result.caseCorrect, isNull);
      expect(result.numberCorrect, isNull);
      expect(result.genderCorrect, isNull);
    });

    test("formal identische Formen gelten, aber nur als Ganzes", () {
      ComparisonAnswerResult genitive(String number, String gender) {
        return check(
          "σοφωτέρου",
          degree: "Komparativ",
          grammaticalCase: "Genitiv",
          number: number,
          gender: gender,
        );
      }

      // Maskulinum und Neutrum sind im Genitiv Singular gleich.
      expect(genitive("Sg.", "m").correct, isTrue);
      expect(genitive("Sg.", "n").correct, isTrue);

      final feminine = genitive("Sg.", "f");

      expect(feminine.correct, isFalse);
      expect(feminine.genderCorrect, isFalse);
      expect(feminine.caseCorrect, isTrue);
      expect(feminine.numberCorrect, isTrue);

      final plural = genitive("Pl.", "m");

      expect(plural.correct, isFalse);
      expect(plural.numberCorrect, isFalse);
    });

    test("Komparativ auf -ων: Maskulinum und Femininum", () {
      for (final gender in ["m", "f"]) {
        expect(
          check(
            "κακίονες",
            lemma: "κακός",
            degree: "Komparativ",
            grammaticalCase: "Nominativ",
            number: "Pl.",
            gender: gender,
          ).correct,
          isTrue,
        );
      }

      expect(
        check(
          "κακίονες",
          lemma: "κακός",
          degree: "Komparativ",
          grammaticalCase: "Nominativ",
          number: "Pl.",
          gender: "n",
        ).correct,
        isFalse,
      );
    });

    test("Adverb: nur die Stufe zählt", () {
      final result = check("ἥκιστα", lemma: "κακός", degree: "Superlativ");

      expect(result.correct, isTrue);
      expect(result.degreeCorrect, isTrue);
      expect(result.caseCorrect, isNull);
    });

    test("fehlende Auswahl ist falsch", () {
      final result = check("σοφωτέρου");

      expect(result.correct, isFalse);
      expect(result.degreeCorrect, isFalse);
      expect(result.caseCorrect, isFalse);
      expect(result.numberCorrect, isFalse);
      expect(result.genderCorrect, isFalse);
    });
  });

  group("Fragegenerierung: flektierte Formen", () {
    test("Tabellenform trägt ihre Stufe, aber keine Bestimmung", () {
      final grammar = GrammarLearning(random: Random(4));
      final megas = _adjective("μέγας");

      for (var i = 0; i < 100; i++) {
        final target = GrammarQuestionPicker.pickComparisonTarget(
          grammar,
          megas,
        );

        expect(target.base, target.shown);
        expect(
          target.degree,
          target.shown == "μέγιστος" ? "Superlativ" : "Komparativ",
        );
        expect(target.grammaticalCase, isNull);
        expect(target.number, isNull);
        expect(target.gender, isNull);
      }
    });

    test("Form passt zu Stufe, Kasus, Numerus und Genus", () {
      final grammar = GrammarLearning(random: Random(5));

      for (final comparison in AdjectiveComparisons.all) {
        final bases = AdjectiveComparisons.basesOf(comparison);

        for (var i = 0; i < 200; i++) {
          final target = GrammarQuestionPicker.pickComparisonTarget(
            grammar,
            comparison,
            inflected: true,
          );

          final base = bases.firstWhere((base) => base.text == target.base);

          expect(base.degree, target.degree);

          if (base.paradigm == null) {
            expect(target.shown, "ἥκιστα");
            expect(target.note, "Adv.");
            expect(target.grammaticalCase, isNull);

            continue;
          }

          expect(target.note, isNull);
          expect(
            base.paradigm!.form(
              target.grammaticalCase!,
              GrammarQuestionPicker.nounRequestNumber(target.number),
              target.gender!,
            ),
            target.shown,
          );

          // Die Zielbestimmung ist eine richtige Antwort.
          expect(
            checkComparisonAnswer(
              shown: target.shown,
              lemmaInput: comparison.positive,
              degreeAsked: true,
              formAsked: true,
              userDegree: target.degree,
              userCase: target.grammaticalCase,
              userNumber: target.number,
              userGender: target.gender,
            ).correct,
            isTrue,
            reason: target.shown,
          );
        }
      }
    });

    test("alle Stufen kommen vor, der Positiv seltener", () {
      final grammar = GrammarLearning(random: Random(6));
      final sophos = _adjective("σοφός");

      final counts = <String, int>{};

      for (var i = 0; i < 6000; i++) {
        final degree = GrammarQuestionPicker.pickComparisonTarget(
          grammar,
          sophos,
          inflected: true,
        ).degree;

        counts[degree] = (counts[degree] ?? 0) + 1;
      }

      expect(counts.keys.toSet(), {"Positiv", "Komparativ", "Superlativ"});
      expect(counts["Positiv"]!, lessThan(counts["Komparativ"]! * 0.6));

      // Ohne deklinierbaren Positiv nur Komparativ und Superlativ.
      final megas = {
        for (var i = 0; i < 300; i++)
          GrammarQuestionPicker.pickComparisonTarget(
            grammar,
            _adjective("μέγας"),
            inflected: true,
          ).degree,
      };

      expect(megas, {"Komparativ", "Superlativ"});
    });

    test("seltene Formen werden nie flektiert vorgelegt", () {
      final grammar = GrammarLearning(random: Random(7));

      final bases = {
        for (var i = 0; i < 600; i++)
          GrammarQuestionPicker.pickComparisonTarget(
            grammar,
            _adjective("ὀλίγος"),
            inflected: true,
          ).base,
      };

      expect(bases, {"ὀλίγος", "ἐλάττων", "ἐλάχιστος"});
    });
  });

  group("Übersetzung: eigener Schalter der Adjektivsteigerung", () {
    test("Bedeutung der Grundform genügt auch bei flektierter Form", () {
      expect(_check("σοφωτέρου", translation: "weise").correct, isTrue);
      expect(_check("κακίονες", translation: "feige").correct, isTrue);
      expect(_check("σοφωτέρου", translation: "weiser").correct, isFalse);
      // ἐλάττονος gehört zu μικρός und ὀλίγος.
      expect(_check("ἐλάττονος", translation: "klein").correct, isTrue);
      expect(_check("ἐλάττονος", translation: "wenig").correct, isTrue);
      expect(_check("ἐλάττονος", translation: "viel").correct, isFalse);
    });

    test("unabhängig von der Einstellung für Nomen und Verben", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'askComparisonTranslation': true,
        'askLemmaTranslation': false,
      });

      expect(settings.askComparisonTranslation, isTrue);
      expect(settings.askLemmaTranslation, isFalse);
      expect(settings.toMap()['askComparisonTranslation'], isTrue);
    });
  });

  group("Einstellungen: Stufe und Form", () {
    test("ohne gespeicherte Werte eingeschaltet", () {
      for (final data in [
        null,
        // Einstellungen von vor der Erweiterung.
        <String, dynamic>{
          'askComparisonLemma': true,
          'askComparisonTranslation': false,
        },
      ]) {
        final settings = GrammarTrainerSettings.fromMap(data);

        expect(settings.askComparisonDegree, isTrue);
        expect(settings.askComparisonForm, isTrue);
      }
    });

    test("werden gelesen und gespeichert", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'askComparisonDegree': false,
        'askComparisonForm': "ja",
      });

      expect(settings.askComparisonDegree, isFalse);
      expect(settings.askComparisonForm, isTrue);
      expect(settings.toMap()['askComparisonDegree'], isFalse);
      expect(settings.toMap()['askComparisonForm'], isTrue);
    });
  });

  group("Klausur-Extra-Vokabeln (Schritt 8)", () {
    final vocabulary = [
      for (final item in jsonDecode(
        File("assets/greek_vocabulary.json").readAsStringSync(),
      ))
        GreekVocabularyEntry.fromJson(item),
    ];

    test("δεῖ, χρή, ἔξεστιν, δοκεῖ stehen in Schritt 8", () {
      final step8 = {
        for (final entry in vocabulary.where((e) => e.step == 8))
          entry.lemma: entry.translations,
      };

      expect(step8, {
        "δεῖ": ["es ist nötig"],
        "χρή": ["es ist nötig"],
        "ἔξεστιν": ["es ist erlaubt"],
        "δοκεῖ": ["es scheint gut"],
      });
    });

    test("IDs bleiben eindeutig", () {
      final ids = [for (final entry in vocabulary) entry.id];

      expect(ids.toSet().length, ids.length);
    });
  });
}
