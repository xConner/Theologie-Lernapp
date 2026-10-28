import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/subjunctive_screen.dart';
import 'package:theologie_lernapp/services/greek/grammar/adjective_comparisons.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_settings_service.dart';
import 'package:theologie_lernapp/services/greek/grammar/greek_future.dart';
import 'package:theologie_lernapp/services/greek/grammar/greek_subjunctive.dart';
import 'package:theologie_lernapp/services/greek/grammar/subjunctive_exercises.dart';
import 'package:theologie_lernapp/services/greek/grammar/verb_paradigm.dart';
import 'package:theologie_lernapp/services/greek/grammar/wiktionary_inflection_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/greek_grammar_progress_view.dart';

/// Paradigmen so, wie das Backend (`/api/greek-verb?paradigm=1`) sie liefert.
final Map<String, dynamic> _fixtures =
    jsonDecode(
          File('test/fixtures/greek_verb_paradigms.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Paradigma, wie der Trainer es nach dem Laden hat: Tabellen des Backends,
/// Futur und Konjunktiv.
VerbParadigm _paradigm(String lemma) {
  return GreekSubjunctive.extend(
    lemma,
    GreekFuture.extend(lemma, VerbParadigm.fromJson(_fixtures[lemma])),
  );
}

List<GreekVocabularyEntry> _vocabulary() {
  final List<dynamic> json = jsonDecode(
    File("assets/greek_vocabulary.json").readAsStringSync(),
  );

  return [for (final item in json) GreekVocabularyEntry.fromJson(item)];
}

GreekVocabularyEntry _entry(String lemma, {bool deponent = false}) {
  return GreekVocabularyEntry(
    id: lemma.hashCode,
    step: 1,
    type: "verb",
    lemma: lemma,
    deponent: deponent,
    translations: const ["x"],
  );
}

List<String> _forms(String lemma, String tense, String voice) {
  return GreekSubjunctive.conjugate(lemma, _paradigm(lemma))[tense]![voice]!;
}

void main() {
  group("Paradigmen der Folie", () {
    test("παύω: Präsens Aktiv und Medium/Passiv", () {
      expect(GreekSubjunctive.pauo["Präsens"]!["Aktiv"], [
        "παύω",
        "παύῃς",
        "παύῃ",
        "παύωμεν",
        "παύητε",
        "παύωσι(ν)",
      ]);
      expect(GreekSubjunctive.pauo["Präsens"]!["Medium/Passiv"], [
        "παύωμαι",
        "παύῃ",
        "παύηται",
        "παυώμεθα",
        "παύησθε",
        "παύωνται",
      ]);
    });

    test("παύω: Aorist Aktiv, Medium, Passiv", () {
      final aorist = GreekSubjunctive.pauo["Aorist"]!;

      expect(aorist["Aktiv"], [
        "παύσω",
        "παύσῃς",
        "παύσῃ",
        "παύσωμεν",
        "παύσητε",
        "παύσωσι(ν)",
      ]);
      expect(aorist["Medium"], [
        "παύσωμαι",
        "παύσῃ",
        "παύσηται",
        "παυσώμεθα",
        "παύσησθε",
        "παύσωνται",
      ]);
      expect(aorist["Passiv"], [
        "παυθῶ",
        "παυθῇς",
        "παυθῇ",
        "παυθῶμεν",
        "παυθῆτε",
        "παυθῶσι(ν)",
      ]);
    });

    test("starker Aorist ἔλθω und εἰμί", () {
      expect(GreekSubjunctive.strongAorist, [
        "ἔλθω",
        "ἔλθῃς",
        "ἔλθῃ",
        "ἔλθωμεν",
        "ἔλθητε",
        "ἔλθωσι(ν)",
      ]);
      expect(GreekSubjunctive.eimi, ["ὦ", "ᾖς", "ᾖ", "ὦμεν", "ἦτε", "ὦσι(ν)"]);
    });

    test("die Bildungsregel ergibt genau die Paradigmen der Folie", () {
      final present = GreekSubjunctive.pauo["Präsens"]!;
      final aorist = GreekSubjunctive.pauo["Aorist"]!;

      expect(GreekSubjunctive.presentForms("παύω", "Aktiv"), present["Aktiv"]);
      expect(
        GreekSubjunctive.presentForms("παύω", "Medium/Passiv"),
        present["Medium/Passiv"],
      );
      expect(
        GreekSubjunctive.aoristFromInfinitive("παῦσαι", "Aktiv"),
        aorist["Aktiv"],
      );
      expect(
        GreekSubjunctive.aoristFromInfinitive("παύσασθαι", "Medium"),
        aorist["Medium"],
      );
      expect(
        GreekSubjunctive.aoristFromInfinitive("παυθῆναι", "Passiv"),
        aorist["Passiv"],
      );
      expect(
        GreekSubjunctive.aoristFromInfinitive("ἐλθεῖν", "Aktiv"),
        GreekSubjunctive.strongAorist,
      );
    });

    test("Formen der Beispielsätze entstehen genau so", () {
      String present(String lemma, String voice, int index) {
        return GreekSubjunctive.presentForms(lemma, voice)![index];
      }

      String aorist(String infinitive, String voice, int index) {
        return GreekSubjunctive.aoristFromInfinitive(infinitive, voice)![index];
      }

      expect(present("φονεύω", "Aktiv", 1), "φονεύῃς");
      expect(present("εὔχομαι", "Medium/Passiv", 3), "εὐχώμεθα");
      expect(aorist("ποιῆσαι", "Aktiv", 3), "ποιήσωμεν");
      expect(present("ἐσθίω", "Aktiv", 3), "ἐσθίωμεν");
      expect(present("πίπτω", "Aktiv", 2), "πίπτῃ");
      expect(present("βιοτεύω", "Aktiv", 3), "βιοτεύωμεν");
      expect(present("θέλω", "Aktiv", 1), "θέλῃς");
      expect(aorist("λαβεῖν", "Aktiv", 0), "λάβω");
      expect(aorist("λῦσαι", "Aktiv", 0), "λύσω");
      expect(aorist("νομίσαι", "Aktiv", 4), "νομίσητε");
      expect(aorist("κριθῆναι", "Passiv", 4), "κριθῆτε");
      expect(aorist("μεριμνῆσαι", "Aktiv", 4), "μεριμνήσητε");
      expect(aorist("φαγεῖν", "Aktiv", 3), "φάγωμεν");
      expect(aorist("πιεῖν", "Aktiv", 3), "πίωμεν");
      expect(aorist("περιβαλέσθαι", "Medium", 3), "περιβαλώμεθα");
    });

    test("jede Bildungsaufgabe der Sätze folgt der Regel", () {
      for (final task in SubjunctiveExercises.buildTasks) {
        if (task.source == "Paradigma der Folie") continue;

        // Die Konjunktivform steht wörtlich im Beispielsatz.
        expect(task.source, contains(task.answer), reason: task.answer);
      }
    });

    test("jede Satzaufgabe enthält ihre Konjunktivform", () {
      for (final task in [
        ...SubjunctiveExercises.usageTasks,
        SubjunctiveExercises.john127,
      ]) {
        expect(task.sentence, contains(task.form), reason: task.form);
        expect(GreekSubjunctive.tenses, contains(task.tense));
        expect(task.analysis, contains("Konjunktiv ${task.tense}"));
      }
    });

    test("Übersetzungen: Folie oder als ergänzt markiert", () {
      final fromSlide = [
        for (final task in SubjunctiveExercises.usageTasks)
          if (task.translationFromSlide) task.translation,
      ];

      expect(fromSlide, [
        "Töte nicht!",
        "Lasst uns beten!",
        "Lasst uns Menschen machen!",
        "Was sollen wir tun?",
        "Was sollen wir essen?",
        "Ich fürchte, dass Regen fällt.",
        "Wir essen, um zu leben / damit wir leben.",
        "Komm, wenn / wann immer du willst!",
      ]);

      for (final task in SubjunctiveExercises.usageTasks) {
        if (!task.translationFromSlide) {
          expect(task.reference, matches(RegExp(r'^(Mt|Joh) \d+,\d+$')));
        }
      }
    });

    test("jede Verwendung der Folie wird geübt", () {
      expect({
        for (final task in SubjunctiveExercises.usageTasks)
          if (task.use != null) task.use!,
      }, SubjunctiveUse.values.toSet());
      expect(SubjunctiveExercises.john127.use, isNull);
      expect([
        for (final task in SubjunctiveExercises.usageTasks) task.id,
      ], isNot(contains(SubjunctiveExercises.john127.id)));
    });
  });

  group("IDs", () {
    test("eindeutig, stabil und ohne Überschneidung", () {
      final build = [for (final t in SubjunctiveExercises.buildTasks) t.id];
      final usage = [for (final t in SubjunctiveExercises.usageTasks) t.id];
      final all = [...build, ...usage];

      expect(all.toSet().length, all.length);
      expect(build.length, 57);
      expect(usage.length, 15);

      for (final id in build) {
        expect(id >= 11010 && id <= 11199, isTrue, reason: "$id");
      }
      for (final id in usage) {
        expect(id >= 11201 && id <= 11298, isTrue, reason: "$id");
      }

      final others = {
        for (final entry in _vocabulary()) entry.id,
        for (final entry in AdjectiveComparisons.entries) entry.id,
      };

      expect(all.toSet().intersection(others), isEmpty);

      // Feste Stichproben: Diese IDs dürfen sich nie ändern.
      expect(SubjunctiveExercises.buildTask(11055)!.answer, "παυθῶσι(ν)");
      expect(SubjunctiveExercises.buildTask(11060)!.answer, "ἔλθω");
      expect(SubjunctiveExercises.buildTask(11070)!.answer, "ὦ");
      expect(SubjunctiveExercises.usageTask(11211)!.form, "κριθῆτε");
    });

    test("keine doppelte Bildungsaufgabe", () {
      final keys = [
        for (final task in SubjunctiveExercises.buildTasks)
          "${task.lemma} ${task.description}",
      ];

      expect(keys.toSet().length, keys.length);
    });
  });

  group("Keine geratenen Formen", () {
    test("kein Konjunktiv Präsens bei Kontrakta und -μι-Verben", () {
      for (final lemma in [
        "ποιέω",
        "τιμάω",
        "ἀφικνέομαι",
        "φοβέομαι",
        "τίθημι",
        "δύναμαι",
        "ἀπόλλυμαι",
        "οἶδα",
      ]) {
        expect(GreekSubjunctive.supports(lemma, "Präsens"), isFalse);
        expect(GreekSubjunctive.presentForms(lemma, "Aktiv"), isNull);
        expect(GreekSubjunctive.presentForms(lemma, "Medium/Passiv"), isNull);
      }
    });

    test("Wurzelaoriste, ἔσχον und -μι-Verben ohne Konjunktiv Aorist", () {
      for (final lemma in ["βαίνω", "γιγνώσκω", "ἔχω", "τίθημι", "δίδωμι"]) {
        expect(GreekSubjunctive.supports(lemma, "Aorist"), isFalse);
        expect(
          _paradigm(lemma).forms.where((form) {
            return form.analysis.mood == VerbMood.subjunctive &&
                form.analysis.tense == "Aorist";
          }),
          isEmpty,
          reason: lemma,
        );
      }

      expect(GreekSubjunctive.aoristFromInfinitive("βῆναι", "Aktiv"), isNull);
      expect(GreekSubjunctive.aoristFromInfinitive("γνῶναι", "Aktiv"), isNull);
      expect(GreekSubjunctive.aoristFromInfinitive("σχεῖν", "Aktiv"), isNull);
    });

    test("kein Konjunktiv Futur oder Imperfekt", () {
      for (final lemma in _fixtures.keys) {
        for (final form in _paradigm(lemma).forms) {
          if (form.analysis.mood == VerbMood.subjunctive) {
            expect(GreekSubjunctive.tenses, contains(form.analysis.tense));
            expect(form.analysis.person, isNotNull);
          }
        }
      }
    });

    test("Folie geht vor Wiktionary: παυθῶ statt παυσθῶ", () {
      final paradigm = _paradigm("παύω");

      expect(paradigm.analysesOf("παυθῶμεν"), isNotEmpty);
      expect(paradigm.analysesOf("παυσθῶμεν"), isEmpty);
    });

    test("Akzent auf der letzten Stammsilbe, mit Spiritus", () {
      expect(GreekSubjunctive.withAcuteOnLastVowel("παυσ"), "παύσ");
      expect(GreekSubjunctive.withAcuteOnLastVowel("ἐλθ"), "ἔλθ");
      expect(GreekSubjunctive.withAcuteOnLastVowel("εἰπ"), "εἴπ");
      expect(GreekSubjunctive.withAcuteOnLastVowel("ἰδ"), "ἴδ");
      expect(GreekSubjunctive.withAcuteOnLastVowel("σχ"), isNull);
      expect(_forms("ὁράω", "Aorist", "Aktiv").first, "ἴδω");
      expect(_forms("λέγω", "Aorist", "Aktiv").first, "εἴπω");
      expect(_forms("ἀγγέλλω", "Aorist", "Aktiv").first, "ἀγγείλω");
      expect(_forms("μένω", "Aorist", "Aktiv").first, "μείνω");
      expect(_forms("γίγνομαι", "Aorist", "Medium"), [
        "γένωμαι",
        "γένῃ",
        "γένηται",
        "γενώμεθα",
        "γένησθε",
        "γένωνται",
      ]);
      expect(_forms("σῴζω", "Präsens", "Medium/Passiv")[3], "σῳζώμεθα");
    });

    test("Deponentien: nur ihre eigenen Genera Verbi", () {
      final conjugated = GreekSubjunctive.conjugate(
        "ἔρχομαι",
        _paradigm("ἔρχομαι"),
      );

      expect(conjugated["Präsens"]!.keys, ["Medium/Passiv"]);
      expect(conjugated["Präsens"]!["Medium/Passiv"]!.first, "ἔρχωμαι");
      expect(conjugated["Aorist"], {"Aktiv": GreekSubjunctive.strongAorist});

      expect(
        GreekSubjunctive.conjugate("βούλομαι", _paradigm("βούλομαι"))["Aorist"],
        {
          "Passiv": [
            "βουληθῶ",
            "βουληθῇς",
            "βουληθῇ",
            "βουληθῶμεν",
            "βουληθῆτε",
            "βουληθῶσι(ν)",
          ],
        },
      );
    });

    test("εἰμί: nur das Paradigma der Folie", () {
      final forms = [
        for (final form in _paradigm("εἰμί").forms)
          if (form.analysis.mood == VerbMood.subjunctive) form,
      ];

      expect([for (final form in forms) form.form], GreekSubjunctive.eimi);
      expect({for (final form in forms) form.analysis.tense}, {"Präsens"});
    });
  });

  group("Trainer: Konjunktivformen bestimmen", () {
    Set<String> picked(
      GreekVocabularyEntry entry,
      VerbParadigm paradigm, {
      List<String> moods = GrammarQuestionPicker.moods,
      List<String> tenses = GrammarQuestionPicker.selectableTenses,
      int count = 600,
    }) {
      final grammar = GrammarLearning(random: Random(5));

      return {
        for (var i = 0; i < count; i++)
          if (GrammarQuestionPicker.pickVerbTarget(
                grammar,
                entry,
                paradigm,
                enabledMoods: moods,
                enabledTenses: tenses,
              )
              case final form?)
            "${form.analysis.mood} ${form.analysis.tense} "
                "${form.analysis.voice}",
      };
    }

    test("Modus Konjunktiv: Präsens und Aorist, Aorist Passiv inklusive", () {
      expect(VerbMood.all, contains("Konjunktiv"));
      expect(GrammarQuestionPicker.tensesOfMood("Konjunktiv"), [
        "Präsens",
        "Aorist",
      ]);
      expect(GrammarQuestionPicker.asksPersonNumber("Konjunktiv"), isTrue);

      expect(
        picked(_entry("πείθω"), _paradigm("πείθω"), moods: ["Konjunktiv"]),
        {
          "Konjunktiv Präsens Aktiv",
          "Konjunktiv Präsens Medium/Passiv",
          "Konjunktiv Aorist Aktiv",
          "Konjunktiv Aorist Medium",
          "Konjunktiv Aorist Passiv",
        },
      );
    });

    test("Standardauswahl fragt auch den Konjunktiv", () {
      final moods = {
        for (final key in picked(_entry("πείθω"), _paradigm("πείθω")))
          key.split(" ")[0],
      };

      expect(moods, contains("Konjunktiv"));
    });

    test("Konjunktiv abgewählt: keine Konjunktivform", () {
      final moods = [
        for (final mood in GrammarQuestionPicker.moods)
          if (mood != "Konjunktiv") mood,
      ];

      expect(
        picked(
          _entry("πείθω"),
          _paradigm("πείθω"),
          moods: moods,
        ).where((key) => key.startsWith("Konjunktiv")),
        isEmpty,
      );
    });

    test("Aorist Passiv im Indikativ weiterhin nicht gefragt", () {
      expect(
        GrammarQuestionPicker.allowedVoices(
          _entry("ποιέω"),
          "Aorist",
          _paradigm("ποιέω"),
        ),
        ["Aktiv", "Medium"],
      );
      expect(
        GrammarQuestionPicker.allowedVoices(
          _entry("ποιέω"),
          "Aorist",
          _paradigm("ποιέω"),
          mood: "Konjunktiv",
        ),
        ["Aktiv", "Medium", "Passiv"],
      );
    });

    test("nur Konjunktiv: Verfügbarkeit ohne geratene Formen", () {
      bool available(String lemma, List<String> tenses) {
        return GrammarQuestionPicker.isAvailable(
          _entry(lemma),
          enabledSteps: const [1],
          enabledTypes: const ["verb"],
          pronounIds: const {},
          enabledMoods: const ["Konjunktiv"],
          enabledTenses: tenses,
        );
      }

      expect(available("πείθω", ["Präsens"]), isTrue);
      expect(available("ποιέω", ["Präsens"]), isFalse);
      expect(available("ποιέω", ["Aorist"]), isTrue);
      expect(available("βαίνω", ["Aorist"]), isFalse);
      expect(available("εἰμί", ["Präsens"]), isTrue);
      expect(available("εἰμί", ["Aorist"]), isFalse);
      expect(available("πείθω", ["Futur", "Imperfekt"]), isFalse);
    });

    test("jedes verfügbare Verb der Testdaten hat tatsächlich eine Form", () {
      for (final lemma in _fixtures.keys) {
        final entry = _entry(lemma);

        for (final tenses in [
          ["Präsens"],
          ["Aorist"],
        ]) {
          if (!GrammarQuestionPicker.isAvailable(
            entry,
            enabledSteps: const [1],
            enabledTypes: const ["verb"],
            pronounIds: const {},
            enabledMoods: const ["Konjunktiv"],
            enabledTenses: tenses,
          )) {
            continue;
          }

          expect(
            GrammarQuestionPicker.pickVerbTarget(
              GrammarLearning(random: Random(1)),
              entry,
              _paradigm(lemma),
              enabledMoods: const ["Konjunktiv"],
              enabledTenses: tenses,
            ),
            isNotNull,
            reason: "$lemma $tenses",
          );
        }
      }
    });

    test("jeder Schritt hat mit nur Konjunktiv Aufgaben", () {
      final vocabulary = _vocabulary();

      for (var step = 1; step <= 7; step++) {
        final available = vocabulary.where((entry) {
          return GrammarQuestionPicker.isAvailable(
            entry,
            enabledSteps: [step],
            enabledTypes: const ["verb"],
            pronounIds: const {},
            enabledMoods: const ["Konjunktiv"],
          );
        });

        expect(available, isNotEmpty, reason: "Schritt $step");
      }
    });

    test("andere Modi werden durch den Konjunktiv nicht verändert", () {
      for (final lemma in ["ποιέω", "πείθω", "ἔρχομαι", "εἰμί"]) {
        final before = GreekFuture.extend(
          lemma,
          VerbParadigm.fromJson(_fixtures[lemma]),
        ).forms;
        final after = _paradigm(lemma).forms
            .where((form) => form.analysis.mood != VerbMood.subjunctive)
            .toList();

        expect(after, before, reason: lemma);
      }
    });

    test("Paradigma aus dem Backend wird um den Konjunktiv ergänzt", () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'lemma': 'πείθω', 'paradigm': _fixtures['πείθω']}),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final paradigm = await WiktionaryInflectionService().getVerbParadigm(
          'πείθω',
        );

        expect(paradigm!.analysesOf("πεισθῶμεν").map(describeVerbAnalysis), [
          "1. Pl. Aorist Konjunktiv Passiv",
        ]);
        expect(paradigm.analysesOf("ἔπεισα"), isNotEmpty);
        expect(paradigm.analysesOf("πείσω").map((a) => a.mood).toSet(), {
          "Indikativ",
          "Konjunktiv",
        });
      }, () => client);
    });
  });

  group("Antwortprüfung: bestimmen", () {
    VerbAnswerResult check(
      VerbParadigm paradigm,
      String form, {
      required String mood,
      required String tense,
      required String voice,
      required String person,
    }) {
      final analyses = paradigm.analysesOf(form);

      return checkVerbAnswer(
        target: analyses.first,
        analyses: analyses,
        deponent: false,
        userMood: mood,
        userTense: tense,
        userVoice: voice,
        userPersonNumber: person,
      );
    }

    test("Konjunktiv Aorist richtig, Indikativ falsch", () {
      final paradigm = _paradigm("ποιέω");

      expect(
        check(
          paradigm,
          "ποιήσωμεν",
          mood: "Konjunktiv",
          tense: "Aorist",
          voice: "Aktiv",
          person: "1. Pl.",
        ).correct,
        isTrue,
      );

      final wrong = check(
        paradigm,
        "ποιήσωμεν",
        mood: "Indikativ",
        tense: "Aorist",
        voice: "Aktiv",
        person: "1. Pl.",
      );

      expect(wrong.correct, isFalse);
      expect(wrong.moodCorrect, isFalse);
    });

    test(
      "formgleich: Konj. Aorist = Ind. Futur, Konj. = Ind. Präsens 1. Sg.",
      () {
        final poieo = _paradigm("ποιέω");

        for (final (mood, tense) in [
          ("Konjunktiv", "Aorist"),
          ("Indikativ", "Futur"),
        ]) {
          expect(
            check(
              poieo,
              "ποιήσω",
              mood: mood,
              tense: tense,
              voice: "Aktiv",
              person: "1. Sg.",
            ).correct,
            isTrue,
            reason: mood,
          );
        }

        final peitho = _paradigm("πείθω");

        for (final mood in ["Konjunktiv", "Indikativ"]) {
          expect(
            check(
              peitho,
              "πείθω",
              mood: mood,
              tense: "Präsens",
              voice: "Aktiv",
              person: "1. Sg.",
            ).correct,
            isTrue,
            reason: mood,
          );
        }

        // παύῃ: 3. Sg. Aktiv oder 2. Sg. Medium/Passiv.
        final pauo = _paradigm("παύω");

        expect(
          check(
            pauo,
            "παύῃ",
            mood: "Konjunktiv",
            tense: "Präsens",
            voice: "Medium",
            person: "2. Sg.",
          ).correct,
          isTrue,
        );
        expect(
          check(
            pauo,
            "παύῃ",
            mood: "Konjunktiv",
            tense: "Präsens",
            voice: "Aktiv",
            person: "3. Sg.",
          ).correct,
          isTrue,
        );
      },
    );

    test("Konjunktiv und Indikativ: langer gegen kurzen Themavokal", () {
      final paradigm = _paradigm("πείθω");

      expect(paradigm.analysesOf("πείθωμεν").map((a) => a.mood).toSet(), {
        "Konjunktiv",
      });
      expect(paradigm.analysesOf("πείθομεν").map((a) => a.mood).toSet(), {
        "Indikativ",
      });
    });

    test("Erklärung bei verwechseltem Modus", () {
      final paradigm = _paradigm("πείθω");
      final subjunctive = paradigm.analysesOf("πείθωμεν").single;

      final hints = GreekSubjunctive.explain(
        form: "πείθωμεν",
        analysis: subjunctive,
        paradigm: paradigm,
        userMood: "Indikativ",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "1. Pl.",
      );

      expect(hints.first, contains("lange Themavokal"));
      expect(hints, contains("Der Indikativ lautete: πείθομεν."));

      final indicative = paradigm.analysesOf("πείθομεν").single;
      final reverse = GreekSubjunctive.explain(
        form: "πείθομεν",
        analysis: indicative,
        paradigm: paradigm,
        userMood: "Konjunktiv",
      );

      expect(reverse.first, contains("kein Konjunktiv"));
      expect(reverse, contains("Der Konjunktiv lautete: πείθωμεν."));
    });

    test("Erklärung bei Tempus, Genus Verbi und Person", () {
      final paradigm = _paradigm("πείθω");
      final analysis = paradigm.analysesOf("πεισθῆτε").single;

      final hints = GreekSubjunctive.explain(
        form: "πεισθῆτε",
        analysis: analysis,
        paradigm: paradigm,
        userMood: "Konjunktiv",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "1. Pl.",
      );

      expect(hints.join(" "), contains("ohne Augment"));
      expect(hints.join(" "), contains("Aorist Passiv: θ-Stamm"));
      expect(hints.join(" "), contains("Endung -ῆτε = 2. Pl."));

      // Richtige Antwort: keine Erklärung.
      expect(
        GreekSubjunctive.explain(
          form: "πεισθῆτε",
          analysis: analysis,
          paradigm: paradigm,
          userMood: "Konjunktiv",
          userTense: "Aorist",
          userVoice: "Passiv",
          userPersonNumber: "2. Pl.",
        ),
        isEmpty,
      );
    });
  });

  group("Antwortprüfung: bilden", () {
    bool correct(String input, String answer) {
      return SubjunctiveExercises.checkForm(input, answer).correct;
    }

    test("genaue Form, mit und ohne Akzente", () {
      expect(correct("παυθῶμεν", "παυθῶμεν"), isTrue);
      expect(SubjunctiveExercises.checkForm("παυθωμεν", "παυθῶμεν"), (
        correct: true,
        diacriticsMissing: true,
      ));
      expect(correct("ἔλθω", "ἔλθω"), isTrue);
      expect(correct("ελθω", "ἔλθω"), isTrue);
      expect(correct("Παύωμεν", "παύωμεν"), isTrue);
    });

    test("Eingabe der App-Tastatur (kombinierende Zeichen)", () {
      // παυθ + ω + Zirkumflex + μεν
      expect(correct("παυθῶμεν", "παυθῶμεν"), isTrue);
      // ᾖς: η + Lenis + Zirkumflex + Iota subscriptum
      expect(correct("ᾖς", "ᾖς"), isTrue);
      expect(correct("ἦς", "ᾖς"), isFalse);
    });

    test("Iota subscriptum ist Pflicht", () {
      expect(correct("παύης", "παύῃς"), isFalse);
      expect(correct("παυης", "παύῃς"), isFalse);
      expect(correct("ης", "ᾖς"), isFalse);
      expect(correct("ῃς", "ᾖς"), isTrue);
    });

    test("gesetzte Akzente und Spiritus müssen stimmen", () {
      expect(correct("παυθώμεν", "παυθῶμεν"), isFalse);
      expect(correct("παύθωμεν", "παυθῶμεν"), isFalse);
      expect(correct("ἕλθω", "ἔλθω"), isFalse);
      // Gravis zählt als Akut.
      expect(correct("παὺω", "παύω"), isTrue);
    });

    test("bewegliches ν ist freigestellt", () {
      expect(correct("παύωσι", "παύωσι(ν)"), isTrue);
      expect(correct("παύωσιν", "παύωσι(ν)"), isTrue);
      expect(correct("παύωσι(ν)", "παύωσι(ν)"), isFalse);
      expect(correct("παύουσι", "παύωσι(ν)"), isFalse);
    });

    test("Indikativ statt Konjunktiv ist falsch", () {
      expect(correct("παύομεν", "παύωμεν"), isFalse);
      expect(correct("παύεις", "παύῃς"), isFalse);
      expect(correct("ἐπαύσαμεν", "παύσωμεν"), isFalse);
      expect(correct("", "παύω"), isFalse);
    });

    test("Fehlererklärungen beim Bilden", () {
      final task = SubjunctiveExercises.buildTask(11011)!; // παύῃς

      expect(
        SubjunctiveExercises.explainBuild(task, "παύης").first,
        contains("Iota subscriptum"),
      );
      expect(
        SubjunctiveExercises.explainBuild(task, "παύεις").join(" "),
        contains("langer Themavokal"),
      );
      expect(
        SubjunctiveExercises.explainBuild(task, "παύῃ").join(" "),
        contains("ist die 3. Sg."),
      );
      expect(
        SubjunctiveExercises.explainBuild(task, "παύεις").last,
        "Bildung: Präsensstamm + Endung -ῃς (2. Sg. Aktiv).",
      );

      final aorist = SubjunctiveExercises.buildTask(11033)!; // παύσωμεν

      expect(
        SubjunctiveExercises.explainBuild(aorist, "ἐπαύσωμεν").join(" "),
        contains("Kein Augment"),
      );
    });
  });

  group("Thema Konjunktiv im Trainer", () {
    test("Wortart und Aufgabenarten", () {
      expect(GrammarQuestionPicker.types, contains("subjunctive"));
      expect(GrammarQuestionPicker.subjunctiveKinds, ["build", "usage"]);
      expect(SubjunctiveExercises.kindLabel("build"), "Formen bilden");
      expect(SubjunctiveExercises.kindLabel("usage"), "Gebrauch im Satz");
    });

    test("Aufgaben nach Aufgabenart verfügbar, unabhängig von Schritten", () {
      bool available(GreekVocabularyEntry entry, List<String> kinds) {
        return GrammarQuestionPicker.isAvailable(
          entry,
          enabledSteps: const [1],
          enabledTypes: const ["subjunctive"],
          pronounIds: const {},
          subjunctiveIds: SubjunctiveExercises.idsOfKinds(kinds),
        );
      }

      final build = SubjunctiveExercises.entries.first;
      final usage = SubjunctiveExercises.entries.last;

      expect(available(build, ["build"]), isTrue);
      expect(available(usage, ["build"]), isFalse);
      expect(available(usage, ["usage"]), isTrue);
      expect(available(build, ["usage"]), isFalse);
      expect(
        GrammarQuestionPicker.isAvailable(
          build,
          enabledSteps: const [1],
          enabledTypes: const ["verb"],
          pronounIds: const {},
          subjunctiveIds: SubjunctiveExercises.idsOfKinds(const ["build"]),
        ),
        isFalse,
      );
    });

    test("Auswahl: eigene Gruppe neben den Wortarten", () {
      final grammar = GrammarLearning(random: Random(2));
      final vocabulary = [
        ..._vocabulary().where((entry) => entry.type != "pronoun"),
        ...SubjunctiveExercises.entries,
      ];

      var subjunctive = 0;

      for (var i = 0; i < 600; i++) {
        if (GrammarQuestionPicker.pickEntry(grammar, vocabulary).type ==
            "subjunctive") {
          subjunctive++;
        }
      }

      // Eine eigene Gruppe neben „alle Wörter“, Aoristblatt und εἰμί –
      // nicht Teil von „alle Wörter“ (sonst wäre es gut die Hälfte).
      expect(subjunctive, greaterThan(100));
      expect(subjunctive, lessThan(300));
    });

    test("Lernfortschritt: Merkmale des Konjunktivs werden angezeigt", () {
      expect(
        GreekGrammarProgressView.parse(
          GrammarLearning.dimensionId("subjunctive", "function", "Finalsatz"),
        ),
        ("subjunctive", "function", "Finalsatz"),
      );
      expect(
        GreekGrammarProgressView.parse(
          GrammarLearning.dimensionId("subjunctive", "person", "2. Pl"),
        ),
        ("subjunctive", "person", "2. Pl"),
      );
    });
  });

  group("Einstellungen", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Standard: beide Aufgabenarten, Modus Konjunktiv aktiv", () {
      final settings = GrammarTrainerSettings.fromMap(null);

      expect(settings.enabledSubjunctiveKinds, ["build", "usage"]);
      expect(settings.enabledMoods, contains("Konjunktiv"));
      expect(settings.enabledTypes, contains("subjunctive"));
    });

    test("gespeicherte Auswahl bleibt unverändert", () async {
      // Einstellungen von vor dem Konjunktiv: Wortarten und Modi gespeichert.
      SharedPreferences.setMockInitialValues({
        "guest.v1.settings": jsonEncode({
          "greek_grammar_settings": {
            "enabledSteps": [2, 3],
            "enabledTypes": ["noun", "verb"],
            "enabledMoods": ["Indikativ", "Partizip"],
            "enabledTenses": ["Aorist"],
          },
        }),
      });

      final settings = await GrammarSettingsService().load(null);

      expect(settings.enabledSteps, [2, 3]);
      expect(settings.enabledTypes, ["noun", "verb"]);
      expect(settings.enabledMoods, ["Indikativ", "Partizip"]);
      expect(settings.enabledTenses, ["Aorist"]);
      expect(settings.enabledSubjunctiveKinds, ["build", "usage"]);
    });

    test("Gastmodus: Konjunktiv-Auswahl übersteht den Neustart", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(
          enabledTypes: ["subjunctive"],
          enabledMoods: ["Konjunktiv"],
          enabledSubjunctiveKinds: ["usage"],
        ),
      );

      final loaded = await service.load(null);

      expect(loaded.enabledTypes, ["subjunctive"]);
      expect(loaded.enabledMoods, ["Konjunktiv"]);
      expect(loaded.enabledSubjunctiveKinds, ["usage"]);
    });

    test("unbekannte Aufgabenarten werden verworfen", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledSubjunctiveKinds': ["usage", "optativ", 3],
      });

      expect(settings.enabledSubjunctiveKinds, ["usage"]);
    });
  });

  group("Grammatikübersicht", () {
    testWidgets("zeigt die Paradigmen und Sätze der Folie", (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SubjunctiveScreen()),
      );

      expect(tester.takeException(), isNull);

      for (final form in ["παύωμεν", "παυώμεθα", "παυθῶσι(ν)"]) {
        expect(find.text(form), findsWidgets, reason: form);
      }

      await tester.scrollUntilVisible(
        find.textContaining("Ars Graeca § 211"),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining("Grammateion § 6.9"), findsOneWidget);
    });
  });
}
