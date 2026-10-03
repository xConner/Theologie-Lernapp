import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_form_analysis.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_settings_service.dart';
import 'package:theologie_lernapp/utils/greek_normalization.dart';

GreekVocabularyEntry _entry(
  int id,
  String lemma, {
  String type = "verb",
  String? article,
  bool deponent = false,
}) {
  return GreekVocabularyEntry(
    id: id,
    step: 1,
    type: type,
    lemma: lemma,
    article: article,
    deponent: deponent,
    translations: const ["x"],
  );
}

void main() {
  GrammarLearning learning([int seed = 1]) {
    return GrammarLearning(random: Random(seed));
  }

  Set<String> pickedTenses(GreekVocabularyEntry entry) {
    final grammar = learning();

    return {
      for (var i = 0; i < 300; i++)
        GrammarQuestionPicker.pickVerbTarget(grammar, entry).tense,
    };
  }

  Set<String> pickedVoices(GreekVocabularyEntry entry) {
    final grammar = learning();

    return {
      for (var i = 0; i < 300; i++)
        GrammarQuestionPicker.pickVerbTarget(grammar, entry).voice,
    };
  }

  group("Zulässige Bestimmungen je Verb", () {
    test("normales Verb: alle Tempora, Aktiv und Medium/Passiv", () {
      final entry = _entry(1, "λύω");

      expect(pickedTenses(entry), {"Präsens", "Imperfekt", "Aorist"});
      expect(pickedVoices(entry), {"Aktiv", "Medium/Passiv"});
    });

    test("εἰμί: kein Aorist, nur Aktiv", () {
      final entry = _entry(2, "εἰμί");

      expect(pickedTenses(entry), {"Präsens", "Imperfekt"});
      expect(pickedVoices(entry), {"Aktiv"});
    });

    test("Verben ohne Imperfekt bzw. nur im Präsens", () {
      expect(pickedTenses(_entry(3, "ἐμβαίνω")), {"Präsens", "Aorist"});
      expect(pickedTenses(_entry(4, "προσεύχομαι", deponent: true)), {
        "Präsens",
      });
    });

    test("Deponens: nur Medium/Passiv", () {
      expect(pickedVoices(_entry(5, "ἔρχομαι", deponent: true)), {
        "Medium/Passiv",
      });
    });

    test("nur aktiv belegte Verben gehen vor Deponens-Markierung", () {
      expect(pickedVoices(_entry(6, "χαίρω", deponent: true)), {"Aktiv"});
    });

    test("Person und Numerus in der Schreibweise der Fragegenerierung", () {
      final grammar = learning();

      for (var i = 0; i < 100; i++) {
        final target = GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry(1, "λύω"),
        );

        expect(["1.", "2.", "3."], contains(target.person));
        expect(["Sg", "Pl"], contains(target.number));
        expect(GrammarQuestionPicker.parsePerson(target.person), isNotNull);
        expect(
          GrammarQuestionPicker.personNumbers,
          contains("${target.person} ${target.number}."),
        );
      }
    });

    test("festgelegte Werte verbrauchen keine Zufallsziehung", () {
      // προσεύχομαι: Tempus und Genus Verbi stehen fest; gezogen wird nur
      // Person/Numerus. Zwei Generatoren mit gleichem Startwert bleiben
      // deshalb nach einer Frage synchron mit einer einzelnen Ziehung.
      final random = Random(7);
      final reference = Random(7);

      GrammarQuestionPicker.pickVerbTarget(
        GrammarLearning(random: random),
        _entry(4, "προσεύχομαι", deponent: true),
      );

      reference.nextDouble();

      expect(random.nextDouble(), reference.nextDouble());
    });
  });

  group("Nomen", () {
    test("Genus folgt dem Artikel", () {
      String gender(String? article) => GrammarQuestionPicker.genderOf(
        _entry(1, "x", type: "noun", article: article),
      );

      expect(gender("ὁ"), "m");
      expect(gender("ἡ"), "f");
      expect(gender("τό"), "n");
      expect(gender("το"), "n");
      expect(gender(null), "m");
    });

    test("Kasus und Numerus aus den Trainerwerten", () {
      final grammar = learning();
      final entry = _entry(1, "λόγος", type: "noun", article: "ὁ");

      final cases = <String>{};
      final numbers = <String>{};

      for (var i = 0; i < 300; i++) {
        final target = GrammarQuestionPicker.pickNounTarget(grammar, entry);

        cases.add(target.grammaticalCase);
        numbers.add(target.number);
        expect(target.gender, "m");
      }

      expect(cases, GrammarQuestionPicker.cases.toSet());
      expect(numbers, {"Sg.", "Pl."});
      expect(GrammarQuestionPicker.nounRequestNumber("Sg."), "Sg");
      expect(GrammarQuestionPicker.nounRequestNumber("Pl."), "Pl");
    });
  });

  group("Auswahl der Grundform", () {
    final words = [
      for (var i = 0; i < 20; i++) _entry(i, "wort$i", type: "noun"),
      _entry(100, "εἰμί"),
      _entry(101, "βλέπω"),
      _entry(102, "γράφω"),
    ];

    Map<String, int> counts(List<GreekVocabularyEntry> available) {
      final grammar = learning(3);
      final result = <String, int>{};

      for (var i = 0; i < 6000; i++) {
        final lemma = GrammarQuestionPicker.pickEntry(grammar, available).lemma;

        result[lemma] = (result[lemma] ?? 0) + 1;
      }

      return result;
    }

    test("εἰμί und Aoristblatt bilden eigene, gleich gewichtete Gruppen", () {
      final result = counts(words);

      // Je ein Drittel: alle Wörter, Aoristblatt, εἰμί. εἰμί zusätzlich mit
      // 1/23 aus der Gesamtliste.
      expect(result["εἰμί"]! / 6000, closeTo(1 / 3 + 1 / 69, 0.03));

      final sheet = result["βλέπω"]! + result["γράφω"]!;

      expect(sheet / 6000, closeTo(1 / 3 + 2 / 69, 0.03));
    });

    test("ohne εἰμί und Aoristblatt nur die Gesamtliste", () {
      final nouns = words.where((e) => e.type == "noun").toList();
      final result = counts(nouns);

      expect(result.keys.toSet(), nouns.map((e) => e.lemma).toSet());
    });

    test("Aoristblatt zählt nur für Verben", () {
      final result = counts([
        _entry(1, "βλέπω", type: "noun"),
        _entry(2, "wort", type: "noun"),
      ]);

      expect(result["βλέπω"]! / 6000, closeTo(0.5, 0.03));
    });

    test("Lernbedarf verschiebt die Auswahl", () {
      final weak = words.first;

      final grammar = GrammarLearning(
        random: Random(3),
        cards: {
          GrammarLearning.lemmaId(weak.id): LearningCard(
            id: GrammarLearning.lemmaId(weak.id),
            difficulty: 10,
            lastReviewed: DateTime.now(),
          ),
        },
      );

      var weakCount = 0;
      var otherCount = 0;

      for (var i = 0; i < 6000; i++) {
        final picked = GrammarQuestionPicker.pickEntry(grammar, words);

        if (picked == weak) weakCount++;
        if (picked == words[1]) otherCount++;
      }

      expect(weakCount, greaterThan(otherCount * 1.5));
    });

    test("Blacklist und Listen enthalten die bekannten Sonderfälle", () {
      expect(GrammarQuestionPicker.blacklist, contains("οἶδα"));
      expect(GrammarQuestionPicker.aoristSheet, contains("λέγω"));
      expect(GrammarQuestionPicker.aoristSheet.length, 28);
      expect(GrammarQuestionPicker.blacklist.length, 18);
    });
  });

  group("Antwortprüfung Nomen", () {
    // τέκνον: Nominativ und Akkusativ Singular sind formal identisch.
    final teknon = parseNounFormAnalyses([
      {'case': 'Nominativ', 'number': 'Sg'},
      {'case': 'Akkusativ', 'number': 'Sg'},
    ]);

    NounAnswerResult check({
      List<NounFormAnalysis> analyses = const [],
      String? userCase,
      String? userNumber,
      String? userGender,
    }) {
      return checkNounAnswer(
        targetCase: "Nominativ",
        targetNumber: "Sg.",
        targetGender: "n",
        analyses: analyses,
        userCase: userCase,
        userNumber: userNumber,
        userGender: userGender,
      );
    }

    test("Zielbestimmung ist richtig", () {
      final result = check(
        userCase: "Nominativ",
        userNumber: "Sg.",
        userGender: "n",
      );

      expect(result, (
        caseCorrect: true,
        numberCorrect: true,
        genderCorrect: true,
      ));
    });

    test("formal identische Form gilt als richtig", () {
      final result = check(
        analyses: teknon,
        userCase: "Akkusativ",
        userNumber: "Sg.",
        userGender: "n",
      );

      expect(result.caseCorrect, isTrue);
      expect(result.numberCorrect, isTrue);
    });

    test("ohne Angaben des Backends gilt nur die Zielbestimmung", () {
      final result = check(userCase: "Akkusativ", userNumber: "Sg.");

      expect(result.caseCorrect, isFalse);
      expect(result.numberCorrect, isTrue);
    });

    test("nicht mögliche Bestimmung bleibt falsch, Teile einzeln", () {
      final result = check(
        analyses: teknon,
        userCase: "Akkusativ",
        userNumber: "Pl.",
        userGender: "m",
      );

      expect(result, (
        caseCorrect: false,
        numberCorrect: false,
        genderCorrect: false,
      ));
    });

    test("Genus hängt am Wort, nicht an der Form", () {
      final result = check(
        analyses: teknon,
        userCase: "Akkusativ",
        userNumber: "Sg.",
        userGender: "m",
      );

      expect(result.genderCorrect, isFalse);
    });

    test("fehlende Auswahl ist falsch", () {
      final result = check(analyses: teknon);

      expect(result, (
        caseCorrect: false,
        numberCorrect: false,
        genderCorrect: false,
      ));
    });
  });

  group("Antwortprüfung Verb", () {
    // ἔλυον: 1. Sg. und 3. Pl. Imperfekt Aktiv sind formal identisch.
    final elyon = parseVerbFormAnalyses([
      {'tense': 'Imperfekt', 'voice': 'Aktiv', 'number': 'Sg', 'person': 1},
      {'tense': 'Imperfekt', 'voice': 'Aktiv', 'number': 'Pl', 'person': 3},
    ]);

    VerbAnswerResult check({
      List<VerbFormAnalysis> analyses = const [],
      String targetVoice = "Aktiv",
      bool deponent = false,
      String? userPersonNumber,
      String? userTense,
      String? userVoice,
    }) {
      return checkVerbAnswer(
        targetPerson: "1.",
        targetNumber: "Sg",
        targetTense: "Imperfekt",
        targetVoice: targetVoice,
        deponent: deponent,
        analyses: analyses,
        userPersonNumber: userPersonNumber,
        userTense: userTense,
        userVoice: userVoice,
      );
    }

    const allCorrect = (
      personCorrect: true,
      tenseCorrect: true,
      voiceCorrect: true,
    );

    test("Zielbestimmung ist richtig", () {
      expect(
        check(
          userPersonNumber: "1. Sg.",
          userTense: "Imperfekt",
          userVoice: "Aktiv",
        ),
        allCorrect,
      );
    });

    test("formal identische Form gilt als richtig", () {
      expect(
        check(
          analyses: elyon,
          userPersonNumber: "3. Pl.",
          userTense: "Imperfekt",
          userVoice: "Aktiv",
        ),
        allCorrect,
      );
    });

    test("ohne Angaben des Backends gilt nur die Zielbestimmung", () {
      final result = check(
        userPersonNumber: "3. Pl.",
        userTense: "Imperfekt",
        userVoice: "Aktiv",
      );

      expect(result, (
        personCorrect: false,
        tenseCorrect: true,
        voiceCorrect: true,
      ));
    });

    test("Mischung zweier möglicher Bestimmungen ist falsch", () {
      final result = check(
        analyses: elyon,
        userPersonNumber: "3. Sg.",
        userTense: "Aorist",
        userVoice: "Aktiv",
      );

      expect(result, (
        personCorrect: false,
        tenseCorrect: false,
        voiceCorrect: true,
      ));
    });

    test("Deponent zählt bei Deponentien wie Medium/Passiv", () {
      final result = check(
        targetVoice: "Medium/Passiv",
        deponent: true,
        userPersonNumber: "1. Sg.",
        userTense: "Imperfekt",
        userVoice: "Deponent",
      );

      expect(result, allCorrect);
    });

    test("Deponent bei einem normalen Verb ist falsch", () {
      final result = check(
        targetVoice: "Medium/Passiv",
        userPersonNumber: "1. Sg.",
        userTense: "Imperfekt",
        userVoice: "Deponent",
      );

      expect(result.voiceCorrect, isFalse);
    });
  });

  group("Grundform", () {
    test("Akzente, Spiritus und Groß-/Kleinschreibung zählen nicht", () {
      expect(lemmaAnswerMatches("ανθρωπος", "ἄνθρωπος"), isTrue);
      expect(lemmaAnswerMatches("  Ἄνθρωπος ", "ἄνθρωπος"), isTrue);
      expect(lemmaAnswerMatches("ειμι", "εἰμί"), isTrue);
      expect(lemmaAnswerMatches("ωδη", "ᾠδή"), isTrue);
    });

    test("Schluss-Sigma und Sigma sind gleichwertig", () {
      expect(lemmaAnswerMatches("λογοσ", "λόγος"), isTrue);
    });

    test("andere Buchstaben bleiben falsch", () {
      expect(lemmaAnswerMatches("λογον", "λόγος"), isFalse);
      expect(lemmaAnswerMatches("", "λόγος"), isFalse);
    });

    test("Anzeige entfernt nur Längenzeichen", () {
      expect(normalizeGreekForDisplay("λῡ́ω").contains("ῡ"), isFalse);
      expect(normalizeGreekForDisplay("λόγος"), "λόγος");
    });
  });

  group("Einstellungen", () {
    test("ohne gespeicherte Werte gelten die Defaults", () {
      for (final data in [null, <String, dynamic>{}, "kaputt"]) {
        final settings = GrammarTrainerSettings.fromMap(data);

        expect(settings.enabledSteps, [1, 2, 3, 4, 5, 6, 7]);
        expect(settings.enabledTypes, ["noun", "verb", "pronoun"]);
        expect(settings.showLemmaFieldNoun, isTrue);
        expect(settings.showLemmaFieldVerb, isTrue);
        expect(settings.showLemmaFieldPronoun, isTrue);
      }
    });

    test("gespeicherte Werte werden gelesen, ungültige verworfen", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledSteps': [5, 2, 9, 0, "x", 3.0],
        'enabledTypes': ["verb", "adjective"],
        'showLemmaFieldNoun': false,
        'showLemmaFieldVerb': "ja",
      });

      expect(settings.enabledSteps, [2, 3, 5]);
      expect(settings.enabledTypes, ["verb"]);
      expect(settings.showLemmaFieldNoun, isFalse);
      expect(settings.showLemmaFieldVerb, isTrue);
    });

    test("Listen sind veränderbar (Einstellungsdialog)", () {
      final settings = GrammarTrainerSettings.fromMap(null);

      settings.enabledSteps.remove(1);
      settings.enabledTypes.clear();

      expect(GrammarTrainerSettings.allSteps.length, 7);
      expect(GrammarTrainerSettings.allTypes.length, 3);
    });

    test("Speicherformat: bestehende Felder unverändert, Pronomen ergänzt", () {
      const settings = GrammarTrainerSettings(
        enabledSteps: [1, 2],
        enabledTypes: ["noun"],
        showLemmaFieldNoun: false,
      );

      expect(settings.toMap(), {
        'enabledSteps': [1, 2],
        'enabledTypes': ["noun"],
        'showLemmaFieldNoun': false,
        'showLemmaFieldVerb': true,
        'showLemmaFieldPronoun': true,
      });
    });

    test("Einstellungen von vor den Pronomen bleiben, wie sie waren", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledSteps': [1, 2],
        'enabledTypes': ["noun", "verb"],
        'showLemmaFieldNoun': true,
        'showLemmaFieldVerb': false,
      });

      expect(settings.enabledSteps, [1, 2]);
      expect(settings.enabledTypes, ["noun", "verb"]);
      expect(settings.showLemmaFieldVerb, isFalse);
      expect(settings.showLemmaFieldPronoun, isTrue);
    });

    test("Pronomen lassen sich ein- und ausschalten", () {
      final on = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledTypes': ["pronoun"],
        'showLemmaFieldPronoun': false,
      });

      expect(on.enabledTypes, ["pronoun"]);
      expect(on.showLemmaFieldPronoun, isFalse);
    });
  });
}
