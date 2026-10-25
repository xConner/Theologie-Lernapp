import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_settings_service.dart';
import 'package:theologie_lernapp/services/greek/grammar/verb_paradigm.dart';

/// Paradigmen so, wie das Backend (`/api/greek-verb?paradigm=1`) sie liefert.
final Map<String, dynamic> _fixtures =
    jsonDecode(
          File('test/fixtures/greek_verb_paradigms.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

VerbParadigm _paradigm(String lemma) => VerbParadigm.fromJson(_fixtures[lemma]);

GreekVocabularyEntry _entry(
  String lemma, {
  String type = "verb",
  int step = 1,
  String? article,
}) {
  return GreekVocabularyEntry(
    id: lemma.hashCode,
    step: step,
    type: type,
    lemma: lemma,
    article: article,
    translations: const ["x"],
  );
}

const _allTenses = ["Präsens", "Imperfekt", "Perfekt", "Aorist", "Futur"];

void main() {
  final pauo = _paradigm("παύω");

  // Tempora von [count] gezogenen Verbaufgaben.
  Set<String> pickedTenses(
    GreekVocabularyEntry entry,
    VerbParadigm paradigm, {
    List<String> enabledMoods = GrammarQuestionPicker.moods,
    required List<String> enabledTenses,
    int count = 400,
  }) {
    final grammar = GrammarLearning(random: Random(7));

    return {
      for (var i = 0; i < count; i++)
        GrammarQuestionPicker.pickVerbTarget(
          grammar,
          entry,
          paradigm,
          enabledMoods: enabledMoods,
          enabledTenses: enabledTenses,
        )!.analysis.tense,
    };
  }

  group("Standardauswahl", () {
    test("zur Wahl stehen die fünf Zeitformen", () {
      expect(GrammarTrainerSettings.allTenses, _allTenses);
      expect(const GrammarTrainerSettings().enabledTenses, _allTenses);
    });

    test("ohne gespeicherte Zeitformen sind alle fünf aktiv", () {
      for (final data in [
        null,
        "kaputt",
        <String, dynamic>{},
        // Einstellungen von vor dem Zeitformfilter.
        <String, dynamic>{
          'enabledSteps': [2],
          'enabledTypes': ["verb"],
          'enabledMoods': ["Indikativ"],
        },
        <String, dynamic>{'enabledTenses': "Präsens"},
      ]) {
        expect(
          GrammarTrainerSettings.fromMap(data).enabledTenses,
          _allTenses,
          reason: "$data",
        );
      }
    });

    test("bisheriges Verhalten: alle Formen des Lernstoffs bleiben", () {
      final grammar = GrammarLearning(random: Random(1));
      final withDefault = GrammarTrainerSettings.fromMap(null);

      final tenses = {
        for (var i = 0; i < 400; i++)
          GrammarQuestionPicker.pickVerbTarget(
            grammar,
            _entry("παύω"),
            pauo,
            enabledTenses: withDefault.enabledTenses,
          )!.analysis.tense,
      };

      expect(tenses, {"Präsens", "Imperfekt", "Aorist"});
    });

    test("Liste ist eine veränderbare Kopie (Einstellungsdialog)", () {
      GrammarTrainerSettings.fromMap(null).enabledTenses.clear();

      expect(GrammarTrainerSettings.allTenses.length, 5);
    });
  });

  group("Gespeicherte Auswahl", () {
    test("einzelne und mehrere Zeitformen werden gelesen", () {
      expect(
        GrammarTrainerSettings.fromMap(<String, dynamic>{
          'enabledTenses': ["Aorist"],
        }).enabledTenses,
        ["Aorist"],
      );
      expect(
        GrammarTrainerSettings.fromMap(<String, dynamic>{
          'enabledTenses': ["Präsens", "Aorist"],
        }).enabledTenses,
        ["Präsens", "Aorist"],
      );
    });

    test("unbekannte Werte werden verworfen", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledTenses': ["Plusquamperfekt", 3, "Futur", "Imperfekt"],
      });

      expect(settings.enabledTenses, ["Futur", "Imperfekt"]);
    });

    test("leere oder nicht abfragbare Auswahl stellt alle wieder her", () {
      for (final tenses in [
        <Object>[],
        ["Plusquamperfekt"],
        ["Perfekt", "Futur"],
      ]) {
        expect(
          GrammarTrainerSettings.fromMap(<String, dynamic>{
            'enabledTenses': tenses,
          }).enabledTenses,
          _allTenses,
          reason: "$tenses",
        );
      }
    });

    test("toMap speichert die Auswahl neben den übrigen Filtern", () {
      const settings = GrammarTrainerSettings(
        enabledTypes: ["verb"],
        enabledMoods: ["Indikativ"],
        enabledTenses: ["Imperfekt"],
      );

      final map = settings.toMap();

      expect(map['enabledTenses'], ["Imperfekt"]);
      expect(map['enabledMoods'], ["Indikativ"]);
      expect(map['enabledTypes'], ["verb"]);
    });
  });

  group("Persistenz (Gastmodus)", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("ohne gespeicherte Einstellungen alle fünf", () async {
      final settings = await GrammarSettingsService().load(null);

      expect(settings.enabledTenses, _allTenses);
    });

    test("Auswahl wird gespeichert und wiederhergestellt", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(enabledTenses: ["Präsens", "Aorist"]),
      );

      expect((await service.load(null)).enabledTenses, ["Präsens", "Aorist"]);

      await service.save(
        null,
        const GrammarTrainerSettings(enabledTenses: ["Imperfekt"]),
      );

      expect((await service.load(null)).enabledTenses, ["Imperfekt"]);
    });

    test("die übrigen gespeicherten Filter bleiben erhalten", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(
          enabledSteps: [2, 4],
          enabledTypes: ["noun", "verb"],
          showLemmaFieldVerb: false,
          enabledTenses: ["Aorist"],
        ),
      );

      final loaded = await service.load(null);

      expect(loaded.enabledSteps, [2, 4]);
      expect(loaded.enabledTypes, ["noun", "verb"]);
      expect(loaded.showLemmaFieldVerb, isFalse);
      expect(loaded.enabledTenses, ["Aorist"]);
    });

    test("eine leere Auswahl wird nie gespeichert", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(enabledTenses: ["Aorist"]),
      );

      for (final tenses in [
        const <String>[],
        const ["Perfekt"],
      ]) {
        await service.save(null, GrammarTrainerSettings(enabledTenses: tenses));

        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString("guest.v1.settings")!)
                as Map<String, dynamic>;

        expect(
          stored["greek_grammar_settings"]["enabledTenses"],
          _allTenses,
          reason: "$tenses",
        );
        expect((await service.load(null)).enabledTenses, _allTenses);
      }
    });
  });

  group("Validierung im Einstellungsdialog", () {
    String? error(List<String> tenses, {List<String>? moods}) {
      return GrammarTrainerSettings.tenseSelectionError(
        enabledMoods: moods ?? GrammarQuestionPicker.moods,
        enabledTenses: tenses,
      );
    }

    test("gültige Auswahl", () {
      expect(error(_allTenses), isNull);
      expect(error(["Präsens"]), isNull);
      expect(error(["Präsens", "Aorist"]), isNull);
      expect(error(["Imperfekt"], moods: ["Indikativ"]), isNull);
      expect(error(["Aorist", "Futur"], moods: ["Partizip"]), isNull);
    });

    test("leere Auswahl wird abgewiesen", () {
      expect(error([]), "Mindestens eine Zeitform muss ausgewählt sein.");
    });

    test("nur Perfekt/Futur wird abgewiesen", () {
      expect(error(["Perfekt"]), contains("noch nicht abgefragt"));
      expect(error(["Perfekt", "Futur"]), contains("noch nicht abgefragt"));
    });

    test("Imperfekt ohne Indikativ wird abgewiesen", () {
      expect(
        error(["Imperfekt"], moods: ["Imperativ", "Partizip"]),
        contains("nur im Indikativ"),
      );
    });
  });

  group("Fragegenerierung", () {
    test("nur eine Zeitform: alle Verbfragen in dieser Zeitform", () {
      for (final tense in ["Präsens", "Imperfekt", "Aorist"]) {
        expect(pickedTenses(_entry("παύω"), pauo, enabledTenses: [tense]), {
          tense,
        });
      }
    });

    test("Präsens und Aorist: nur diese beiden", () {
      expect(
        pickedTenses(
          _entry("παύω"),
          pauo,
          enabledTenses: ["Präsens", "Aorist"],
        ),
        {"Präsens", "Aorist"},
      );
    });

    test("deaktivierte Zeitformen kommen bei keinem Verb vor", () {
      for (final lemma in ["παύω", "λέγω", "ἔρχομαι", "εὑρίσκω", "ποιέω"]) {
        final tenses = pickedTenses(
          _entry(lemma),
          _paradigm(lemma),
          enabledTenses: ["Imperfekt", "Perfekt"],
          count: 150,
        );

        expect(tenses, {"Imperfekt"}, reason: lemma);
      }
    });

    test("Perfekt und Futur allein liefern keine Verbform", () {
      final grammar = GrammarLearning(random: Random(1));

      expect(
        GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry("παύω"),
          pauo,
          enabledTenses: const ["Perfekt", "Futur"],
        ),
        isNull,
      );
      expect(
        GrammarQuestionPicker.askableTenses(["Perfekt", "Futur", "Aorist"]),
        ["Aorist"],
      );
      expect(GrammarQuestionPicker.tenseLabel("Perfekt"), "Perfekt (folgt)");
      expect(GrammarQuestionPicker.tenseLabel("Aorist"), "Aorist");
    });

    test("isAskable beachtet die Zeitform", () {
      final aorist = pauo.forms.firstWhere((form) {
        return form.analysis.tense == "Aorist";
      });

      expect(
        GrammarQuestionPicker.isAskable(
          _entry("παύω"),
          pauo,
          aorist.analysis,
          enabledTenses: const ["Präsens"],
        ),
        isFalse,
      );
      expect(
        GrammarQuestionPicker.isAskable(
          _entry("παύω"),
          pauo,
          aorist.analysis,
          enabledTenses: const ["Aorist"],
        ),
        isTrue,
      );
    });
  });

  group("Zusammenspiel mit den übrigen Filtern", () {
    bool available(
      GreekVocabularyEntry entry, {
      List<String> types = GrammarQuestionPicker.types,
      List<int> steps = const [1],
      List<String> moods = GrammarQuestionPicker.moods,
      required List<String> tenses,
    }) {
      return GrammarQuestionPicker.isAvailable(
        entry,
        enabledSteps: steps,
        enabledTypes: types,
        pronounIds: const {},
        enabledMoods: moods,
        enabledTenses: tenses,
      );
    }

    test("Nomen sind vom Zeitformfilter nicht betroffen", () {
      final noun = _entry("λόγος", type: "noun", article: "ὁ");

      for (final tenses in [
        _allTenses,
        ["Aorist"],
        ["Perfekt"],
        <String>[],
      ]) {
        expect(available(noun, tenses: tenses), isTrue, reason: "$tenses");
      }

      // Schritte und Wortarten gelten weiter.
      expect(available(noun, tenses: ["Aorist"], steps: [2]), isFalse);
      expect(available(noun, tenses: ["Aorist"], types: ["verb"]), isFalse);
    });

    test("Verben ohne gewählte Zeitform werden nicht gefragt", () {
      // εἰμί hat keinen Aorist.
      expect(available(_entry("εἰμί"), tenses: ["Aorist"]), isFalse);
      expect(available(_entry("εἰμί"), tenses: ["Präsens"]), isTrue);
      expect(available(_entry("παύω"), tenses: ["Aorist"]), isTrue);

      // προσεύχομαι gibt es nur im Präsens.
      expect(
        available(_entry("προσεύχομαι"), tenses: ["Imperfekt", "Aorist"]),
        isFalse,
      );
    });

    test("Zeitform und Modus wirken zusammen", () {
      // Das Imperfekt gibt es nur im Indikativ.
      expect(
        available(_entry("παύω"), tenses: ["Imperfekt"], moods: ["Partizip"]),
        isFalse,
      );
      // εἰμί: im Infinitiv nur Präsens.
      expect(
        available(
          _entry("εἰμί"),
          tenses: ["Imperfekt", "Aorist"],
          moods: ["Infinitiv"],
        ),
        isFalse,
      );
      expect(
        available(_entry("παύω"), tenses: ["Aorist"], moods: ["Partizip"]),
        isTrue,
      );

      final grammar = GrammarLearning(random: Random(2));

      for (var i = 0; i < 200; i++) {
        final analysis = GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry("παύω"),
          pauo,
          enabledMoods: const ["Imperativ", "Infinitiv"],
          enabledTenses: const ["Aorist"],
        )!.analysis;

        expect(analysis.tense, "Aorist");
        expect(["Imperativ", "Infinitiv"], contains(analysis.mood));
      }
    });

    test("Schritt- und Wortartfilter gelten auch für Verben weiter", () {
      expect(
        available(_entry("παύω", step: 3), tenses: ["Aorist"], steps: [1]),
        isFalse,
      );
      expect(
        available(_entry("παύω"), tenses: ["Aorist"], types: ["noun"]),
        isFalse,
      );
    });
  });
}
