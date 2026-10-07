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
