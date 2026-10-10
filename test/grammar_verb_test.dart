import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/verb_paradigm.dart';
import 'package:theologie_lernapp/services/greek/grammar/wiktionary_inflection_service.dart';

/// Paradigmen so, wie das Backend (`/api/greek-verb?paradigm=1`) sie liefert.
final Map<String, dynamic> _fixtures =
    jsonDecode(
          File('test/fixtures/greek_verb_paradigms.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

VerbParadigm _paradigm(String lemma) => VerbParadigm.fromJson(_fixtures[lemma]);

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

VerbAnalysis _finite(
  String mood,
  String tense,
  String voice,
  int person,
  String number,
) {
  return (
    mood: mood,
    tense: tense,
    voice: voice,
    person: person,
    number: number,
    grammaticalCase: null,
    gender: null,
  );
}

VerbAnalysis _participle(
  String tense,
  String voice,
  String grammaticalCase,
  String number,
  String gender,
) {
  return (
    mood: VerbMood.participle,
    tense: tense,
    voice: voice,
    person: null,
    number: number,
    grammaticalCase: grammaticalCase,
    gender: gender,
  );
}

String? _form(VerbParadigm paradigm, VerbAnalysis analysis) {
  for (final form in paradigm.forms) {
    if (form.analysis == analysis) return form.form;
  }

  return null;
}

/// 2. Sg., 3. Sg., 2. Pl., 3. Pl.
List<String?> _imperative(VerbParadigm paradigm, String tense, String voice) {
  return [
    for (final (person, number) in const [
      (2, "Sg"),
      (3, "Sg"),
      (2, "Pl"),
      (3, "Pl"),
    ])
      _form(
        paradigm,
        _finite(VerbMood.imperative, tense, voice, person, number),
      ),
  ];
}

Set<String> _combinations(Iterable<VerbAnalysis> analyses) {
  return {
    for (final analysis in analyses)
      "${analysis.mood} ${analysis.tense} ${analysis.voice}",
  };
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  final pauo = _paradigm("παύω");

  group("Indikativ", () {
    test("Präsens, Imperfekt und Aorist von παύω", () {
      List<String?> row(String tense, String voice) {
        return [
          for (final (person, number) in const [
            (1, "Sg"),
            (2, "Sg"),
            (3, "Sg"),
            (1, "Pl"),
            (2, "Pl"),
            (3, "Pl"),
          ])
            _form(
              pauo,
              _finite(VerbMood.indicative, tense, voice, person, number),
            ),
        ];
      }

      expect(row("Präsens", "Aktiv"), [
        "παύω",
        "παύεις",
        "παύει",
        "παύομεν",
        "παύετε",
        "παύουσι",
      ]);
      expect(row("Präsens", "Medium/Passiv"), [
        "παύομαι",
        "παύῃ",
        "παύεται",
        "παυόμεθα",
        "παύεσθε",
        "παύονται",
      ]);
      expect(row("Imperfekt", "Aktiv").first, "ἔπαυον");
      expect(row("Imperfekt", "Medium/Passiv").first, "ἐπαυόμην");
      expect(row("Aorist", "Aktiv"), [
        "ἔπαυσα",
        "ἔπαυσας",
        "ἔπαυσε",
        "ἐπαύσαμεν",
        "ἐπαύσατε",
        "ἔπαυσαν",
      ]);
    });

    test("Aorist trennt Medium und Passiv, Präsens und Imperfekt nicht", () {
      String? first(String tense, String voice) {
        return _form(pauo, _finite(VerbMood.indicative, tense, voice, 1, "Sg"));
      }

      expect(first("Aorist", "Medium"), "ἐπαυσάμην");
      expect(first("Aorist", "Passiv"), isNotNull);
      expect(first("Aorist", "Medium/Passiv"), isNull);
      expect(first("Präsens", "Medium"), isNull);
      expect(first("Präsens", "Passiv"), isNull);

      expect(VerbParadigm.voiceLabel("Präsens", "middle"), "Medium/Passiv");
      expect(VerbParadigm.voiceLabel("Aorist", "middle"), "Medium");
      expect(VerbParadigm.voiceLabel("Aorist", "passive"), "Passiv");
      expect(VerbParadigm.voiceLabel("Aorist", "active"), "Aktiv");
      expect(VerbParadigm.voiceLabel("Aorist", "kaputt"), isNull);
    });

    test("Aorist über ein anderes Lemma: λέγω → εἶπον", () {
      expect(
        _form(
          _paradigm("λέγω"),
          _finite(VerbMood.indicative, "Aorist", "Aktiv", 1, "Sg"),
        ),
        "εἶπον",
      );
    });
  });

  group("Imperativ", () {
    test("Präsens und Aorist, Aktiv und Medium von παύω", () {
      expect(_imperative(pauo, "Präsens", "Aktiv"), [
        "παῦε",
        "παυέτω",
        "παύετε",
        "παυόντων",
      ]);
      expect(_imperative(pauo, "Präsens", "Medium/Passiv"), [
        "παύου",
        "παυέσθω",
        "παύεσθε",
        "παυέσθων",
      ]);
      expect(_imperative(pauo, "Aorist", "Aktiv"), [
        "παῦσον",
        "παυσάτω",
        "παύσατε",
        "παυσάντων",
      ]);
      expect(_imperative(pauo, "Aorist", "Medium"), [
        "παῦσαι",
        "παυσάσθω",
        "παύσασθε",
        "παυσάσθων",
      ]);
    });

    test("Verba contracta, starker Aorist, Wurzelaorist und εἰμί", () {
      expect(_imperative(_paradigm("ποιέω"), "Präsens", "Aktiv"), [
        "ποίει",
        "ποιείτω",
        "ποιεῖτε",
        "ποιούντων",
      ]);
      expect(_imperative(_paradigm("λέγω"), "Aorist", "Aktiv"), [
        "εἰπέ",
        "εἰπέτω",
        "εἴπετε",
        "εἰπόντων",
      ]);
      expect(_imperative(_paradigm("ὁράω"), "Aorist", "Aktiv").first, "ἰδέ");
      expect(_imperative(_paradigm("βαίνω"), "Aorist", "Aktiv"), [
        "βῆθι",
        "βήτω",
        "βῆτε",
        "βάντων",
      ]);
      expect(_imperative(_paradigm("εἰμί"), "Präsens", "Aktiv"), [
        "ἴσθι",
        "ἔστω",
        "ἔστε",
        "ἔστων",
      ]);
    });

    test("Aorist nur mit augmentiertem Indikativ: εὑρίσκω", () {
      final heurisko = _paradigm("εὑρίσκω");

      expect(
        _form(
          heurisko,
          _finite(VerbMood.indicative, "Aorist", "Aktiv", 1, "Sg"),
        ),
        "ηὗρον",
      );
      expect(_imperative(heurisko, "Aorist", "Aktiv").first, "εὑρέ");
      expect(
        _form(heurisko, _participle("Aorist", "Aktiv", "Nominativ", "Sg", "m")),
        "εὑρών",
      );
    });
  });

  group("Partizipien", () {
    test("jede Bestimmung liefert die Form der Folientabellen", () {
      String? form(
        String tense,
        String voice,
        String grammaticalCase,
        String number,
        String gender,
      ) {
        return _form(
          pauo,
          _participle(tense, voice, grammaticalCase, number, gender),
        );
      }

      expect(form("Präsens", "Aktiv", "Nominativ", "Sg", "m"), "παύων");
      expect(form("Präsens", "Aktiv", "Nominativ", "Sg", "n"), "παῦον");
      expect(form("Präsens", "Aktiv", "Genitiv", "Pl", "f"), "παυουσῶν");
      expect(form("Präsens", "Aktiv", "Dativ", "Pl", "m"), "παύουσι(ν)");
      expect(form("Präsens", "Medium/Passiv", "Dativ", "Sg", "m"), "παυομένῳ");
      expect(
        form("Präsens", "Medium/Passiv", "Akkusativ", "Pl", "f"),
        "παυομένας",
      );
      expect(form("Aorist", "Aktiv", "Akkusativ", "Sg", "n"), "παῦσαν");
      expect(form("Aorist", "Aktiv", "Genitiv", "Sg", "f"), "παυσάσης");
      expect(form("Aorist", "Medium", "Nominativ", "Pl", "f"), "παυσάμεναι");
      expect(form("Aorist", "Medium", "Genitiv", "Pl", "n"), "παυσαμένων");
    });

    test("je Tempus und Genus Verbi alle 24 Formen", () {
      for (final (tense, voice) in const [
        ("Präsens", "Aktiv"),
        ("Präsens", "Medium/Passiv"),
        ("Aorist", "Aktiv"),
        ("Aorist", "Medium"),
      ]) {
        final cells = pauo.forms.where((form) {
          return form.analysis.mood == VerbMood.participle &&
              form.analysis.tense == tense &&
              form.analysis.voice == voice;
        });

        expect(cells.length, 24, reason: "$tense $voice");
      }
    });

    test("starker Aorist, Verba contracta und εἰμί", () {
      final horao = _paradigm("ὁράω");
      final poieo = _paradigm("ποιέω");
      final eimi = _paradigm("εἰμί");

      expect(
        _form(horao, _participle("Aorist", "Aktiv", "Nominativ", "Sg", "f")),
        "ἰδοῦσα",
      );
      expect(
        _form(horao, _participle("Aorist", "Aktiv", "Akkusativ", "Pl", "m")),
        "ἰδόντας",
      );
      expect(
        _form(horao, _participle("Präsens", "Aktiv", "Genitiv", "Sg", "m")),
        "ὁρῶντος",
      );
      expect(
        _form(poieo, _participle("Präsens", "Aktiv", "Genitiv", "Sg", "n")),
        "ποιοῦντος",
      );
      expect(
        _form(
          poieo,
          _participle("Präsens", "Medium/Passiv", "Nominativ", "Sg", "m"),
        ),
        "ποιούμενος",
      );
      expect(
        _form(eimi, _participle("Präsens", "Aktiv", "Genitiv", "Sg", "m")),
        "ὄντος",
      );
      expect(
        _form(eimi, _participle("Präsens", "Aktiv", "Dativ", "Pl", "f")),
        "οὔσαις",
      );
    });
  });

  group("Unzulässige Kombinationen", () {
    test("kein Imperativ und kein Partizip im Imperfekt", () {
      for (final lemma in _fixtures.keys) {
        for (final form in _paradigm(lemma).forms) {
          if (form.analysis.tense == "Imperfekt") {
            expect(form.analysis.mood, VerbMood.indicative, reason: lemma);
          }
        }
      }
    });

    test("kein Imperativ der 1. Person", () {
      for (final lemma in _fixtures.keys) {
        for (final form in _paradigm(lemma).forms) {
          if (form.analysis.mood == VerbMood.imperative) {
            expect(form.analysis.person, isNot(1), reason: lemma);
          }
        }
      }

      // Auch dann nicht, wenn das Backend dort eine Form lieferte.
      final paradigm = VerbParadigm.fromJson({
        'Präsens': {
          'indicative': {
            'active': [
              "παύω",
              "παύεις",
              "παύει",
              "παύομεν",
              "παύετε",
              "παύουσι",
            ],
          },
          'imperative': {
            'active': [
              "παύω",
              "παῦε",
              "παυέτω",
              "παύωμεν",
              "παύετε",
              "παυόντων",
            ],
          },
        },
      });

      expect(
        paradigm.forms.where((form) {
          return form.analysis.mood == VerbMood.imperative;
        }).length,
        4,
      );
    });

    test("finite Formen haben eine Person, Partizipien Kasus und Genus", () {
      for (final form in pauo.forms) {
        final analysis = form.analysis;

        if (analysis.mood == VerbMood.participle) {
          expect(analysis.person, isNull);
          expect(analysis.grammaticalCase, isNotNull);
          expect(analysis.gender, isNotNull);
        } else {
          expect(analysis.person, isNotNull);
          expect(analysis.grammaticalCase, isNull);
          expect(analysis.gender, isNull);
        }
      }
    });

    test("Auswahl der Modi folgt der Grammatik", () {
      expect(GrammarQuestionPicker.tensesOfMood(VerbMood.indicative), [
        "Präsens",
        "Imperfekt",
        "Aorist",
      ]);
      expect(GrammarQuestionPicker.tensesOfMood(VerbMood.imperative), [
        "Präsens",
        "Aorist",
      ]);
      expect(GrammarQuestionPicker.tensesOfMood(VerbMood.participle), [
        "Präsens",
        "Aorist",
      ]);
      expect(GrammarQuestionPicker.tensesOfMood(null).length, 3);

      expect(GrammarQuestionPicker.personNumbersOfMood(VerbMood.imperative), [
        "2. Sg.",
        "3. Sg.",
        "2. Pl.",
        "3. Pl.",
      ]);
      expect(
        GrammarQuestionPicker.personNumbersOfMood(VerbMood.indicative).length,
        6,
      );
    });
  });

  group("Anzeige der Felder", () {
    test("Person und Numerus nur bei finiten Modi", () {
      expect(
        GrammarQuestionPicker.asksPersonNumber(VerbMood.indicative),
        isTrue,
      );
      expect(
        GrammarQuestionPicker.asksPersonNumber(VerbMood.imperative),
        isTrue,
      );
      expect(
        GrammarQuestionPicker.asksPersonNumber(VerbMood.participle),
        isFalse,
      );
    });

    test("Kasus, Numerus und Genus nur beim Partizip", () {
      expect(
        GrammarQuestionPicker.asksCaseNumberGender(VerbMood.participle),
        isTrue,
      );
      expect(
        GrammarQuestionPicker.asksCaseNumberGender(VerbMood.indicative),
        isFalse,
      );
      expect(
        GrammarQuestionPicker.asksCaseNumberGender(VerbMood.imperative),
        isFalse,
      );
    });

    test("ohne gewählten Modus verrät kein Feld die Lösung", () {
      expect(GrammarQuestionPicker.asksPersonNumber(null), isFalse);
      expect(GrammarQuestionPicker.asksCaseNumberGender(null), isFalse);
    });

    test("Genus Verbi: Aktiv, Medium, Passiv", () {
      expect(GrammarQuestionPicker.voices, ["Aktiv", "Medium", "Passiv"]);
      expect(GrammarQuestionPicker.moods, [
        "Indikativ",
        "Imperativ",
        "Partizip",
      ]);
    });
  });

  group("Unzuverlässige Daten", () {
    test("Partizipien außerhalb der gelernten Typen fehlen", () {
      final tithemi = _paradigm("τίθημι");

      // τιθείς und θείς werden nicht dekliniert, τιθέμενος schon.
      expect(
        _combinations([
          for (final form in tithemi.forms)
            if (form.analysis.mood == VerbMood.participle) form.analysis,
        ]),
        {"Partizip Präsens Medium/Passiv", "Partizip Aorist Medium"},
      );

      // Aorist Passiv (παυσθείς) gehört nicht zum Lernstoff.
      expect(
        _form(pauo, _participle("Aorist", "Passiv", "Nominativ", "Sg", "m")),
        isNull,
      );
    });

    test("Imperativ mit unpassenden Endungen wird verworfen", () {
      Map<String, dynamic> withImperative(List<String?> imperative) {
        return {
          'Präsens': {
            'indicative': {
              'active': [
                "παύω",
                "παύεις",
                "παύει",
                "παύομεν",
                "παύετε",
                "παύουσι",
              ],
            },
            'imperative': {'active': imperative},
          },
        };
      }

      int imperatives(List<String?> imperative) {
        return VerbParadigm.fromJson(withImperative(imperative)).forms.where((
          form,
        ) {
          return form.analysis.mood == VerbMood.imperative;
        }).length;
      }

      expect(
        imperatives([null, "παῦε", "παυέτω", null, "παύετε", "παυόντων"]),
        4,
      );
      // Mediale Endung in einer aktiven Zeile.
      expect(
        imperatives([null, "παῦε", "παυέσθω", null, "παύετε", "παυόντων"]),
        0,
      );
      // 2. Pl. weicht vom Indikativ ab.
      expect(
        imperatives([null, "παῦε", "παυέτω", null, "παύσατε", "παυόντων"]),
        0,
      );
      // Unvollständige Zeile.
      expect(imperatives([null, "παῦε", null, null, "παύετε", "παυόντων"]), 0);
    });

    test("Imperativ ohne Indikativ desselben Genus Verbi wird verworfen", () {
      final paradigm = VerbParadigm.fromJson({
        'Präsens': {
          'indicative': {
            'active': [
              "παύω",
              "παύεις",
              "παύει",
              "παύομεν",
              "παύετε",
              "παύουσι",
            ],
          },
          'imperative': {
            'middle/passive': [
              null,
              "παύου",
              "παυέσθω",
              null,
              "παύεσθε",
              "παυέσθων",
            ],
          },
        },
      });

      expect(
        paradigm.forms.every((form) {
          return form.analysis.mood == VerbMood.indicative;
        }),
        isTrue,
      );
    });

    test("ungültige Antworten ergeben ein leeres Paradigma", () {
      for (final json in [
        null,
        "kaputt",
        <String, dynamic>{},
        {'Präsens': "x"},
        {
          'Präsens': {
            'indicative': {
              'active': ["παύω"],
              'kaputt': [1, 2, 3, 4, 5, 6],
            },
          },
        },
      ]) {
        expect(VerbParadigm.fromJson(json).forms, isEmpty);
      }
    });

    test("fehlende Einzelformen fehlen, die übrigen bleiben", () {
      final tithemi = _paradigm("τίθημι");

      expect(
        _form(
          tithemi,
          _finite(VerbMood.indicative, "Aorist", "Aktiv", 1, "Sg"),
        ),
        isNull,
      );
      expect(
        _form(
          tithemi,
          _finite(VerbMood.indicative, "Aorist", "Aktiv", 1, "Pl"),
        ),
        "ἔθεμεν",
      );
    });
  });

  group("Formal identische Formen", () {
    test("παυόντων: Imperativ und Partizip", () {
      expect(pauo.analysesOf("παυόντων"), [
        _finite(VerbMood.imperative, "Präsens", "Aktiv", 3, "Pl"),
        _participle("Präsens", "Aktiv", "Genitiv", "Pl", "m"),
        _participle("Präsens", "Aktiv", "Genitiv", "Pl", "n"),
      ]);
    });

    test("παύουσι(ν): Indikativ und Partizip, bewegliches ν zählt nicht", () {
      final expected = [
        _finite(VerbMood.indicative, "Präsens", "Aktiv", 3, "Pl"),
        _participle("Präsens", "Aktiv", "Dativ", "Pl", "m"),
        _participle("Präsens", "Aktiv", "Dativ", "Pl", "n"),
      ];

      expect(pauo.analysesOf("παύουσι"), expected);
      expect(pauo.analysesOf("παύουσι(ν)"), expected);
    });

    test("παύετε: Indikativ und Imperativ", () {
      expect(pauo.analysesOf("παύετε"), [
        _finite(VerbMood.indicative, "Präsens", "Aktiv", 2, "Pl"),
        _finite(VerbMood.imperative, "Präsens", "Aktiv", 2, "Pl"),
      ]);
    });

    test("ἔπαυον: 1. Sg. und 3. Pl.", () {
      expect(pauo.analysesOf("ἔπαυον"), [
        _finite(VerbMood.indicative, "Imperfekt", "Aktiv", 1, "Sg"),
        _finite(VerbMood.indicative, "Imperfekt", "Aktiv", 3, "Pl"),
      ]);
    });

    test("παυομένων: Genitiv Plural aller Genera", () {
      expect(pauo.analysesOf("παυομένων"), [
        for (final gender in const ["m", "f", "n"])
          _participle("Präsens", "Medium/Passiv", "Genitiv", "Pl", gender),
      ]);
    });

    test("eindeutige und unbekannte Formen", () {
      expect(pauo.analysesOf("ἔπαυσα").length, 1);
      expect(pauo.analysesOf("λόγος"), isEmpty);
    });

    test("Beschreibung der Bestimmung", () {
      expect(
        describeVerbAnalysis(
          _finite(VerbMood.imperative, "Aorist", "Medium", 2, "Sg"),
        ),
        "2. Sg. Aorist Imperativ Medium",
      );
      expect(
        describeVerbAnalysis(
          _participle("Präsens", "Medium/Passiv", "Dativ", "Pl", "f"),
        ),
        "Partizip Präsens Medium/Passiv · Dativ Pl. f",
      );
    });
  });

  group("Fragegenerierung", () {
    Set<String> picked(
      GreekVocabularyEntry entry,
      VerbParadigm paradigm, {
      List<String> enabledMoods = GrammarQuestionPicker.moods,
      int seed = 1,
    }) {
      final grammar = GrammarLearning(random: Random(seed));

      return _combinations([
        for (var i = 0; i < 600; i++)
          GrammarQuestionPicker.pickVerbTarget(
            grammar,
            entry,
            paradigm,
            enabledMoods: enabledMoods,
          )!.analysis,
      ]);
    }

    test("normales Verb: alle Kombinationen des Lernstoffs", () {
      expect(picked(_entry("παύω"), pauo), {
        "Indikativ Präsens Aktiv",
        "Indikativ Präsens Medium/Passiv",
        "Indikativ Imperfekt Aktiv",
        "Indikativ Imperfekt Medium/Passiv",
        "Indikativ Aorist Aktiv",
        "Indikativ Aorist Medium",
        "Imperativ Präsens Aktiv",
        "Imperativ Präsens Medium/Passiv",
        "Imperativ Aorist Aktiv",
        "Imperativ Aorist Medium",
        "Partizip Präsens Aktiv",
        "Partizip Präsens Medium/Passiv",
        "Partizip Aorist Aktiv",
        "Partizip Aorist Medium",
      });
    });

    test("gewählt wird nur eine Form, die das Paradigma enthält", () {
      final grammar = GrammarLearning(random: Random(3));

      for (var i = 0; i < 300; i++) {
        final target = GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry("παύω"),
          pauo,
        )!;

        expect(pauo.forms, contains(target));
        expect(_form(pauo, target.analysis), target.form);
      }
    });

    test("nur eingeschaltete Modi", () {
      expect(
        picked(_entry("παύω"), pauo, enabledMoods: [VerbMood.participle]),
        {
          "Partizip Präsens Aktiv",
          "Partizip Präsens Medium/Passiv",
          "Partizip Aorist Aktiv",
          "Partizip Aorist Medium",
        },
      );
      expect(
        picked(_entry("παύω"), pauo, enabledMoods: [VerbMood.imperative]),
        {
          "Imperativ Präsens Aktiv",
          "Imperativ Präsens Medium/Passiv",
          "Imperativ Aorist Aktiv",
          "Imperativ Aorist Medium",
        },
      );
    });

    test("ohne passende Form gibt es keine Frage", () {
      final grammar = GrammarLearning(random: Random(1));

      expect(
        GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry("παύω"),
          pauo,
          enabledMoods: const [],
        ),
        isNull,
      );
      expect(
        GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry("παύω"),
          const VerbParadigm([]),
        ),
        isNull,
      );

      // Das einzige Partizip von βούλομαι im Aorist (βουληθείς) ist nicht
      // zuverlässig gebildet: Es bleibt das Präsens.
      expect(
        picked(
          _entry("βούλομαι", deponent: true),
          _paradigm("βούλομαι"),
          enabledMoods: [VerbMood.participle],
        ),
        {"Partizip Präsens Medium/Passiv"},
      );
    });

    test("εἰμί: kein Aorist, nur Aktiv", () {
      expect(picked(_entry("εἰμί"), _paradigm("εἰμί")), {
        "Indikativ Präsens Aktiv",
        "Indikativ Imperfekt Aktiv",
        "Imperativ Präsens Aktiv",
        "Partizip Präsens Aktiv",
      });
    });

    test("Verben ohne Imperfekt bzw. nur im Präsens", () {
      expect(GrammarQuestionPicker.allowedTenses(_entry("ἐμβαίνω")), [
        "Präsens",
        "Aorist",
      ]);
      expect(
        GrammarQuestionPicker.allowedTenses(
          _entry("προσεύχομαι", deponent: true),
        ),
        ["Präsens"],
      );
      expect(GrammarQuestionPicker.allowedTenses(_entry("εἰμί")), [
        "Präsens",
        "Imperfekt",
      ]);
    });

    test("Deponens: kein Aktiv, im Aorist die tatsächlich gebildete Form", () {
      // ἔρχομαι bildet den Aorist aktiv (ἦλθον).
      expect(picked(_entry("ἔρχομαι", deponent: true), _paradigm("ἔρχομαι")), {
        "Indikativ Präsens Medium/Passiv",
        "Indikativ Imperfekt Medium/Passiv",
        "Indikativ Aorist Aktiv",
        "Imperativ Präsens Medium/Passiv",
        "Imperativ Aorist Aktiv",
        "Partizip Präsens Medium/Passiv",
        "Partizip Aorist Aktiv",
      });

      // γίγνομαι bildet ihn medial (ἐγενόμην).
      expect(
        GrammarQuestionPicker.allowedVoices(
          _entry("γίγνομαι", deponent: true),
          "Aorist",
          _paradigm("γίγνομαι"),
        ),
        ["Medium"],
      );
    });

    test("Aorist Passiv nur beim Deponens und nur im Indikativ", () {
      final boulomai = _entry("βούλομαι", deponent: true);

      // ἐβουλήθην ist der einzige Aorist von βούλομαι.
      expect(
        picked(boulomai, _paradigm("βούλομαι")),
        containsAll(["Indikativ Aorist Passiv"]),
      );
      expect(
        picked(boulomai, _paradigm("βούλομαι")).where((combination) {
          return combination.endsWith("Passiv") &&
              !combination.endsWith("Medium/Passiv") &&
              !combination.startsWith("Indikativ");
        }),
        isEmpty,
      );

      // Beim normalen Verb gehört das Aorist Passiv nicht zum Lernstoff.
      expect(
        GrammarQuestionPicker.allowedVoices(_entry("παύω"), "Aorist", pauo),
        ["Aktiv", "Medium"],
      );
      expect(
        GrammarQuestionPicker.allowedVoices(_entry("παύω"), "Präsens", pauo),
        ["Aktiv", "Medium/Passiv"],
      );
    });

    test("nur aktiv belegte Verben gehen vor Deponens-Markierung", () {
      expect(
        GrammarQuestionPicker.allowedVoices(
          _entry("χαίρω", deponent: true),
          "Präsens",
          pauo,
        ),
        ["Aktiv"],
      );
    });

    test("festgelegte Werte verbrauchen keine Zufallsziehung", () {
      // Steht nur eine Form zur Wahl, wird nichts gezogen: Zwei Generatoren
      // mit gleichem Startwert bleiben synchron.
      final random = Random(7);
      final reference = Random(7);

      final only = (
        form: "παύω",
        analysis: _finite(VerbMood.indicative, "Präsens", "Aktiv", 1, "Sg"),
      );

      expect(
        GrammarQuestionPicker.pickVerbTarget(
          GrammarLearning(random: random),
          _entry("παύω"),
          VerbParadigm([only]),
        ),
        only,
      );

      expect(random.nextDouble(), reference.nextDouble());
    });

    test("Lernbedarf verschiebt die Auswahl des Modus", () {
      final grammar = GrammarLearning(random: Random(5));

      for (var i = 0; i < 5; i++) {
        grammar.record({
          GrammarLearning.dimensionId("verb", "mood", "Partizip"): false,
        });
      }

      var participles = 0;

      for (var i = 0; i < 6000; i++) {
        final target = GrammarQuestionPicker.pickVerbTarget(
          grammar,
          _entry("παύω"),
          pauo,
        )!;

        if (target.analysis.mood == VerbMood.participle) participles++;
      }

      // Neutral wäre ein Drittel.
      expect(participles / 6000, greaterThan(0.45));
    });
  });

  group("Antwortprüfung", () {
    final present = _finite(VerbMood.indicative, "Präsens", "Aktiv", 3, "Sg");

    test("finite Form: Zielbestimmung ist richtig", () {
      final result = checkVerbAnswer(
        target: present,
        analyses: const [],
        deponent: false,
        userMood: "Indikativ",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "3. Sg.",
      );

      expect(result.correct, isTrue);
      expect(result.personCorrect, isTrue);
      // Kasus, Numerus und Genus gehören nicht zu einer finiten Form.
      expect(result.caseCorrect, isNull);
      expect(result.numberCorrect, isNull);
      expect(result.genderCorrect, isNull);
    });

    test("falscher Modus macht die Antwort falsch", () {
      final result = checkVerbAnswer(
        target: present,
        analyses: const [],
        deponent: false,
        userMood: "Imperativ",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "3. Sg.",
      );

      expect(result.correct, isFalse);
      expect(result.moodCorrect, isFalse);
      expect(result.tenseCorrect, isTrue);
      expect(result.personCorrect, isTrue);
    });

    test("Medium/Passiv: Medium und Passiv gelten, Aktiv nicht", () {
      bool voice(String target, String user, {bool deponent = false}) {
        return checkVerbAnswer(
          target: _finite(VerbMood.indicative, "Präsens", target, 1, "Sg"),
          analyses: const [],
          deponent: deponent,
          userMood: "Indikativ",
          userTense: "Präsens",
          userVoice: user,
          userPersonNumber: "1. Sg.",
        ).voiceCorrect;
      }

      expect(voice("Medium/Passiv", "Medium"), isTrue);
      expect(voice("Medium/Passiv", "Passiv"), isTrue);
      expect(voice("Medium/Passiv", "Aktiv"), isFalse);

      // Im Aorist sind Medium und Passiv verschiedene Formen.
      expect(voice("Medium", "Medium"), isTrue);
      expect(voice("Medium", "Passiv"), isFalse);
      expect(voice("Passiv", "Medium"), isFalse);
      expect(voice("Aktiv", "Medium"), isFalse);

      // "Deponent" zählt nur bei Deponentien und nie für aktive Formen.
      expect(voice("Medium/Passiv", "Deponent", deponent: true), isTrue);
      expect(voice("Medium/Passiv", "Deponent"), isFalse);
      expect(voice("Aktiv", "Deponent", deponent: true), isFalse);
    });

    test("Partizip: Kasus, Numerus und Genus zählen einzeln", () {
      final target = _participle("Aorist", "Medium", "Dativ", "Pl", "f");

      VerbAnswerResult check({
        String userCase = "Dativ",
        String userNumber = "Pl.",
        String userGender = "f",
      }) {
        return checkVerbAnswer(
          target: target,
          analyses: const [],
          deponent: false,
          userMood: "Partizip",
          userTense: "Aorist",
          userVoice: "Medium",
          userCase: userCase,
          userNumber: userNumber,
          userGender: userGender,
        );
      }

      expect(check().correct, isTrue);
      expect(check().personCorrect, isNull);

      final wrongCase = check(userCase: "Genitiv");

      expect(wrongCase.correct, isFalse);
      expect(wrongCase.caseCorrect, isFalse);
      expect(wrongCase.numberCorrect, isTrue);
      expect(wrongCase.genderCorrect, isTrue);

      expect(check(userNumber: "Sg.").numberCorrect, isFalse);
      expect(check(userGender: "m").genderCorrect, isFalse);
    });

    test("Partizip als finite Form bestimmt: nichts davon stimmt", () {
      final result = checkVerbAnswer(
        target: _participle("Präsens", "Aktiv", "Nominativ", "Sg", "m"),
        analyses: const [],
        deponent: false,
        userMood: "Indikativ",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "1. Sg.",
      );

      expect(result.correct, isFalse);
      expect(result.moodCorrect, isFalse);
      expect(result.caseCorrect, isFalse);
      expect(result.numberCorrect, isFalse);
      expect(result.genderCorrect, isFalse);
      expect(result.personCorrect, isNull);
    });

    test("formal identische Form gilt über Modi hinweg", () {
      final target = _participle("Präsens", "Aktiv", "Genitiv", "Pl", "m");
      final analyses = pauo.analysesOf("παυόντων");

      final asImperative = checkVerbAnswer(
        target: target,
        analyses: analyses,
        deponent: false,
        userMood: "Imperativ",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "3. Pl.",
      );

      expect(asImperative.correct, isTrue);
      expect(asImperative.reference.mood, VerbMood.imperative);
      expect(asImperative.personCorrect, isTrue);
      expect(asImperative.caseCorrect, isNull);

      final asNeuter = checkVerbAnswer(
        target: target,
        analyses: analyses,
        deponent: false,
        userMood: "Partizip",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userCase: "Genitiv",
        userNumber: "Pl.",
        userGender: "n",
      );

      expect(asNeuter.correct, isTrue);
      expect(asNeuter.reference.gender, "n");
    });

    test("Mischung zweier möglicher Bestimmungen ist falsch", () {
      // ἔπαυον: 1. Sg. und 3. Pl. – aber nicht 3. Sg.
      final result = checkVerbAnswer(
        target: _finite(VerbMood.indicative, "Imperfekt", "Aktiv", 1, "Sg"),
        analyses: pauo.analysesOf("ἔπαυον"),
        deponent: false,
        userMood: "Indikativ",
        userTense: "Imperfekt",
        userVoice: "Aktiv",
        userPersonNumber: "3. Sg.",
      );

      expect(result.correct, isFalse);
      expect(result.personCorrect, isFalse);
      expect(result.tenseCorrect, isTrue);

      // Imperativ-Person zu einer Partizip-Bestimmung.
      final mixed = checkVerbAnswer(
        target: _participle("Präsens", "Aktiv", "Genitiv", "Pl", "m"),
        analyses: pauo.analysesOf("παυόντων"),
        deponent: false,
        userMood: "Partizip",
        userTense: "Präsens",
        userVoice: "Aktiv",
        userPersonNumber: "3. Pl.",
        userCase: "Genitiv",
        userNumber: "Sg.",
        userGender: "m",
      );

      expect(mixed.correct, isFalse);
      expect(mixed.numberCorrect, isFalse);
      expect(mixed.caseCorrect, isTrue);
    });

    test("ohne weitere Bestimmungen gilt nur die Zielbestimmung", () {
      final result = checkVerbAnswer(
        target: _finite(VerbMood.indicative, "Imperfekt", "Aktiv", 1, "Sg"),
        analyses: const [],
        deponent: false,
        userMood: "Indikativ",
        userTense: "Imperfekt",
        userVoice: "Aktiv",
        userPersonNumber: "3. Pl.",
      );

      expect(result.correct, isFalse);
      expect(result.personCorrect, isFalse);
    });

    test("fehlende Auswahl ist falsch", () {
      final result = checkVerbAnswer(
        target: present,
        analyses: const [],
        deponent: false,
        userMood: null,
        userTense: null,
        userVoice: null,
      );

      expect(result.correct, isFalse);
      expect(result.moodCorrect, isFalse);
      expect(result.tenseCorrect, isFalse);
      expect(result.voiceCorrect, isFalse);
      expect(result.personCorrect, isFalse);
    });
  });

  group("WiktionaryInflectionService", () {
    test("Paradigma wird geladen und gecacht", () async {
      final requests = <Uri>[];

      final client = MockClient((request) async {
        requests.add(request.url);

        return _json({'lemma': 'παύω', 'paradigm': _fixtures['παύω']});
      });

      await http.runWithClient(() async {
        final service = WiktionaryInflectionService();

        expect(service.cachedVerbParadigm('παύω'), isNull);

        final paradigm = await service.getVerbParadigm('παύω');

        expect(paradigm!.analysesOf("ἔπαυον").length, 2);
        expect(await service.getVerbParadigm('παύω'), same(paradigm));
        expect(service.cachedVerbParadigm('παύω'), same(paradigm));

        expect(requests.length, 1);
        expect(requests.single.path, '/api/greek-verb');
        expect(requests.single.queryParameters, {
          'lemma': 'παύω',
          'paradigm': '1',
        });
      }, () => client);
    });

    test("λέγω fragt den Aorist über εἶπον ab", () async {
      late Uri requested;

      final client = MockClient((request) async {
        requested = request.url;

        return _json({'lemma': 'λέγω', 'paradigm': _fixtures['λέγω']});
      });

      await http.runWithClient(() async {
        await WiktionaryInflectionService().getVerbParadigm('λέγω');

        expect(requested.queryParameters['aoristLemma'], 'εἶπον');
      }, () => client);
    });

    test("nicht gefunden: keine Formen, kein Cache", () async {
      var requests = 0;

      final client = MockClient((request) async {
        requests++;

        return _json({'error': 'Keine Flexionstabelle gefunden.'}, 404);
      });

      await http.runWithClient(() async {
        final service = WiktionaryInflectionService();

        expect(await service.getVerbParadigm('οἶδα'), isNull);
        expect(await service.getVerbParadigm('οἶδα'), isNull);
        expect(service.cachedVerbParadigm('οἶδα'), isNull);
        expect(requests, 2);
      }, () => client);
    });

    test("Antwort ohne verwertbare Formen gilt als nicht gefunden", () async {
      final client = MockClient((request) async {
        return _json({
          'lemma': 'κλαίω',
          'paradigm': {'Präsens': "kaputt"},
        });
      });

      await http.runWithClient(() async {
        final service = WiktionaryInflectionService();

        expect(await service.getVerbParadigm('κλαίω'), isNull);
        expect(service.cachedVerbParadigm('κλαίω'), isNull);
      }, () => client);
    });

    test("Serverfehler wird gemeldet statt als Form behandelt", () async {
      final client = MockClient((request) async {
        return _json({'error': 'Wiktionary HTTP 503'}, 502);
      });

      await http.runWithClient(() async {
        await expectLater(
          WiktionaryInflectionService().getVerbParadigm('γράφω'),
          throwsException,
        );
      }, () => client);
    });
  });
}
