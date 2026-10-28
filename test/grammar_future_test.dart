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
import 'package:theologie_lernapp/screens/greek/grammar_topics/conjugations_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/infinitive_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/participles_screen.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_settings_service.dart';
import 'package:theologie_lernapp/services/greek/grammar/greek_future.dart';
import 'package:theologie_lernapp/services/greek/grammar/verb_paradigm.dart';
import 'package:theologie_lernapp/services/greek/grammar/wiktionary_inflection_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/utils/greek_accents.dart';

/// Paradigmen so, wie das Backend (`/api/greek-verb?paradigm=1`) sie liefert.
final Map<String, dynamic> _fixtures =
    jsonDecode(
          File('test/fixtures/greek_verb_paradigms.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Paradigma, wie der Trainer es nach dem Laden hat: Tabellen des Backends
/// plus Futur.
VerbParadigm _paradigm(String lemma) {
  return GreekFuture.extend(lemma, VerbParadigm.fromJson(_fixtures[lemma]));
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

List<String> _finite(String lemma, String voice, {int variant = 0}) {
  return GreekFuture.conjugate(lemma)[voice]![variant].finite;
}

// Die Folien schreiben das bewegliche ν aus (παύσουσιν), der Trainer
// klammert es wie im Präsens (παύσουσι(ν)).
String _slide(String form) {
  return form.replaceAll("-", "").replaceAll(" (ν)", "(ν)");
}

void main() {
  group("Futur I nach den Folien", () {
    test("Paradigma παύω: Aktiv, Medium, Passiv (Folie „Futur“)", () {
      expect(_finite("παύω", "Aktiv"), [
        "παύσω",
        "παύσεις",
        "παύσει",
        "παύσομεν",
        "παύσετε",
        _slide("παύ-σ-ουσι(ν)"), // Folie: παύ-σ-ουσιν
      ]);
      expect(_finite("παύω", "Medium"), [
        for (final form in [
          "παύ-σ-ομαι",
          "παύ-σ-ῃ",
          "παύ-σ-εται",
          "παυ-σ-όμεθα",
          "παύ-σ-εσθε",
          "παύ-σ-ονται",
        ])
          _slide(form),
      ]);
      expect(_finite("παύω", "Passiv"), [
        for (final form in [
          "παυ-θή-σ-ομαι",
          "παυ-θή-σ-ῃ",
          "παυ-θή-σ-εται",
          "παυ-θη-σ-όμεθα",
          "παυ-θή-σ-εσθε",
          "παυ-θή-σ-ονται",
        ])
          _slide(form),
      ]);
    });

    test("Infinitive (Folie „Infinitive“)", () {
      final forms = GreekFuture.conjugate("παύω");

      expect(forms["Aktiv"]!.single.infinitive, "παύσειν");
      expect(forms["Medium"]!.single.infinitive, "παύσεσθαι");
      expect(forms["Passiv"]!.single.infinitive, "παυθήσεσθαι");
    });

    test("Partizip Futur Aktiv: vollständige Tabelle der Folie", () {
      final participle = GreekFuture.conjugate(
        "παύω",
      )["Aktiv"]!.single.participle!;

      const slide = {
        "m": [
          "παύ-σ-ων",
          "παύ-σ-οντος",
          "παύ-σ-οντι",
          "παύ-σ-οντα",
          "παύ-σ-οντες",
          "παυ-σ-όντων",
          "παύ-σ-ουσι (ν)",
          "παύ-σ-οντας",
        ],
        "f": [
          "παύ-σ-ουσα",
          "παυ-σ-ούσης",
          "παυ-σ-ούσῃ",
          "παύ-σ-ουσαν",
          "παύ-σ-ουσαι",
          "παυ-σ-ουσῶν",
          "παυ-σ-ούσαις",
          "παυ-σ-ούσας",
        ],
        "n": [
          "παῦ-σ-ον",
          "παύ-σ-οντος",
          "παύ-σ-οντι",
          "παῦ-σ-ον",
          "παύ-σ-οντα",
          "παυ-σ-όντων",
          "παύ-σ-ουσι (ν)",
          "παύ-σ-οντα",
        ],
      };

      const cases = ["Nominativ", "Genitiv", "Dativ", "Akkusativ"];

      for (final MapEntry(key: gender, value: forms) in slide.entries) {
        for (var i = 0; i < forms.length; i++) {
          expect(
            participle.form(cases[i % 4], i < 4 ? "Sg" : "Pl", gender),
            _slide(forms[i]),
            reason: "$gender ${cases[i % 4]} ${i < 4 ? "Sg" : "Pl"}",
          );
        }
      }
    });

    test("Partizip Futur Medium und Passiv (a-/o-Deklination)", () {
      String nominatives(String voice) {
        final participle = GreekFuture.conjugate(
          "παύω",
        )[voice]!.single.participle!;

        return [
          for (final gender in ["m", "f", "n"])
            participle.form("Nominativ", "Sg", gender),
        ].join(", ");
      }

      expect(nominatives("Medium"), "παυσόμενος, παυσομένη, παυσόμενον");
      expect(nominatives("Passiv"), "παυθησόμενος, παυθησομένη, παυθησόμενον");

      final medium = GreekFuture.conjugate(
        "παύω",
      )["Medium"]!.single.participle!;
      expect(medium.form("Genitiv", "Sg", "f"), "παυσομένης");
      expect(medium.form("Dativ", "Pl", "m"), "παυσομένοις");
    });

    test("Stammveränderungen der Folien (1. Sg.)", () {
      const expected = {
        // e- und a-Kontrakta
        "ποιέω": ("Aktiv", ["ποιήσω"]),
        "τιμάω": ("Aktiv", ["τιμήσω"]),
        // Labialstämme
        "βλέπω": ("Aktiv", ["βλέψω"]),
        "γράφω": ("Aktiv", ["γράψω"]),
        "πέμπω": ("Aktiv", ["πέμψω"]),
        // Dentalstämme
        "πείθω": ("Aktiv", ["πείσω"]),
        "νομίζω": ("Aktiv", ["νομίσω"]),
        "σῴζω": ("Aktiv", ["σώσω"]),
        // Gutturalstämme
        "ἄγω": ("Aktiv", ["ἄξω"]),
        "ἄρχω": ("Aktiv", ["ἄρξω"]),
        "λέγω": ("Aktiv", ["λέξω", "ἐρῶ"]),
        // Liquidstämme
        "ἀγγέλλω": ("Aktiv", ["ἀγγελῶ"]),
        "μένω": ("Aktiv", ["μενῶ"]),
        "κρίνω": ("Aktiv", ["κρινῶ"]),
        // mediales Futur
        "ἀκούω": ("Medium", ["ἀκούσομαι"]),
        // Futur mit Stammwechsel
        "γίγνομαι": ("Medium", ["γενήσομαι"]),
        "ἔχω": ("Aktiv", ["σχήσω", "ἕξω"]),
        "ἔρχομαι": ("Medium", ["ἐλεύσομαι"]),
        "λαμβάνω": ("Medium", ["λήψομαι"]),
        "ὁράω": ("Medium", ["ὄψομαι"]),
        "πάσχω": ("Medium", ["πείσομαι"]),
        "φέρω": ("Aktiv", ["οἴσω"]),
      };

      for (final MapEntry(key: lemma, value: (voice, forms))
          in expected.entries) {
        final variants = GreekFuture.conjugate(lemma)[voice];

        expect(variants, isNotNull, reason: lemma);
        expect(
          [for (final variant in variants!) variant.finite.first],
          forms,
          reason: lemma,
        );
        expect(GreekFuture.of(lemma)!.source, FutureSource.slides);
      }
    });

    test("Futur von εἰμί (Folie): ἔσται, nicht *ἔσεται", () {
      final eimi = GreekFuture.conjugate("εἰμί");

      expect(eimi.keys, ["Medium"]);
      expect(eimi["Medium"]!.single.finite, [
        "ἔσομαι",
        "ἔσῃ",
        "ἔσται",
        "ἐσόμεθα",
        "ἔσεσθε",
        "ἔσονται",
      ]);
      expect(eimi["Medium"]!.single.infinitive, "ἔσεσθαι");
      expect(
        eimi["Medium"]!.single.participle!.form("Nominativ", "Sg", "f"),
        "ἐσομένη",
      );
    });

    test("Formen der Beispielsätze entstehen genau so", () {
      final forms = {
        for (final lemma in ["ποιέω", "σῴζω", "εἰμί"])
          for (final form in GreekFuture.formsOf(lemma)) form.form: form,
      };

      expect(
        describeVerbAnalysis(forms["ποιήσεται"]!.analysis),
        "3. Sg. Futur Indikativ Medium",
      );
      expect(
        describeVerbAnalysis(forms["ποιηθήσεται"]!.analysis),
        "3. Sg. Futur Indikativ Passiv",
      );
      expect(
        describeVerbAnalysis(forms["σώσεις"]!.analysis),
        "2. Sg. Futur Indikativ Aktiv",
      );
      expect(
        describeVerbAnalysis(forms["ἐσόμεθα"]!.analysis),
        "1. Pl. Futur Indikativ Medium",
      );

      // ὡς σώσοντα τὴν πόλιν: Partizip Futur Aktiv, Akk. Sg. m.
      final sosonta = GreekFuture.formsOf("σῴζω")
          .where((form) {
            return form.form == "σώσοντα";
          })
          .map((form) => describeVerbAnalysis(form.analysis));

      expect(sosonta, contains("Partizip Futur Aktiv · Akkusativ Sg. m"));
    });
  });

  group("Keine zu einfache Bildungsregel", () {
    test("Stammwechsel- und mediale Futura haben kein geratenes Aktiv", () {
      for (final lemma in [
        "ἀκούω",
        "γίγνομαι",
        "ἔρχομαι",
        "λαμβάνω",
        "ὁράω",
        "εἰμί",
      ]) {
        expect(
          GreekFuture.conjugate(lemma).containsKey("Aktiv"),
          isFalse,
          reason: lemma,
        );
      }

      final all = {
        for (final verb in GreekFuture.verbs)
          for (final form in GreekFuture.formsOf(verb.lemma)) form.form,
      };

      // Präsensstamm + σ wäre falsch.
      for (final wrong in [
        "λαμβάνσω",
        "λαμβάνσομαι",
        "ὁράσω",
        "ὁρήσω",
        "ἀκούσω",
        "γίγνσομαι",
        "ἔχσω",
        "φέρσω",
        "ἔσεται",
        "ἀγγέλσω",
        "μένσω",
        "κρίνσω",
        "βλέπσω",
        "ἄγσω",
      ]) {
        expect(all, isNot(contains(wrong)), reason: wrong);
      }
    });

    test("Liquida ohne σ, mit kontrahierten Endungen", () {
      expect(_finite("ἀγγέλλω", "Aktiv"), [
        "ἀγγελῶ",
        "ἀγγελεῖς",
        "ἀγγελεῖ",
        "ἀγγελοῦμεν",
        "ἀγγελεῖτε",
        "ἀγγελοῦσι(ν)",
      ]);
      expect(_finite("ἀγγέλλω", "Medium").first, "ἀγγελοῦμαι");
      // Das Passiv hat σ: Aorist-Passiv-Stamm + ήσομαι.
      expect(_finite("ἀγγέλλω", "Passiv").first, "ἀγγελθήσομαι");
      // μένω: nur Aktiv.
      expect(GreekFuture.conjugate("μένω").keys, ["Aktiv"]);
    });

    test("Futur Passiv nur aus Folie oder Aorist Passiv des Trainers", () {
      // Folie: παυθήσομαι (der Trainer kennt den Aorist ἐπαύσθην).
      expect(_finite("παύω", "Passiv").first, "παυθήσομαι");
      expect(GreekFuture.passiveFromAoristInfinitive("σωθῆναι"), "σωθήσομαι");
      expect(GreekFuture.passiveFromAoristInfinitive("παύσασθαι"), isNull);

      for (final verb in GreekFuture.verbs) {
        final infinitive = verb.aoristPassiveInfinitive;

        if (infinitive == null) continue;

        // Dieselbe Form wie im Aorist des Trainers.
        final aorist = VerbParadigm.fromJson(_fixtures[verb.lemma]).forms
            .where((form) {
              return form.analysis.tense == "Aorist" &&
                  form.analysis.mood == VerbMood.infinitive &&
                  form.analysis.voice == "Passiv";
            })
            .map((form) => form.form);

        expect(aorist, [infinitive], reason: verb.lemma);
      }

      // Ohne Aorist-Passiv-Stamm kein Futur Passiv.
      for (final lemma in ["ἀκούω", "ἔχω", "φέρω", "λέγω", "παιδεύω"]) {
        expect(
          GreekFuture.conjugate(lemma).containsKey("Passiv"),
          isFalse,
          reason: lemma,
        );
      }
    });

    test("Verben mit abweichendem Futur sind nicht hinterlegt", () {
      for (final lemma in [
        "καλέω",
        "ἐάω",
        "δοκέω",
        "θαυμάζω",
        "τρέφω",
        "βαίνω",
        "γιγνώσκω",
        "φεύγω",
        "μανθάνω",
        "εὑρίσκω",
      ]) {
        expect(GreekFuture.supports(lemma), isFalse, reason: lemma);
        expect(GreekFuture.formsOf(lemma), isEmpty, reason: lemma);
      }
    });

    test("Regelverben folgen genau der Regel ihrer Gruppe", () {
      for (final verb in GreekFuture.verbs) {
        if (verb.source != FutureSource.rule ||
            verb.group == FutureGroup.stemChange) {
          continue;
        }

        final present = verb.lemma;
        final future = verb.active.single;
        final stem = present.substring(0, present.length - 1);

        final String expected = switch (verb.group) {
          FutureGroup.vowelStem => "$stemσω",
          FutureGroup.epsilonContract =>
            "${stem.substring(0, stem.length - 1)}ήσω",
          FutureGroup.alphaContract =>
            "${stem.substring(0, stem.length - 1)}ήσω",
          FutureGroup.labial => "${stem.substring(0, stem.length - 1)}ψω",
          FutureGroup.dental => "${stem.substring(0, stem.length - 1)}σω",
          FutureGroup.guttural => "${stem.substring(0, stem.length - 2)}ξω",
          // ἀγγέλλω → ἀγγελῶ: λλ wird zu λ.
          FutureGroup.liquid =>
            "${stem.endsWith("λλ") ? stem.substring(0, stem.length - 1) : stem}ῶ",
          _ => throw StateError(present),
        };

        // Der Akzent der Kontrakta wandert auf das η.
        expect(_stripAccents(future), _stripAccents(expected), reason: present);
      }
    });

    test("jede Form hat Partizip und Infinitiv", () {
      for (final verb in GreekFuture.verbs) {
        for (final MapEntry(key: voice, value: variants)
            in GreekFuture.conjugate(verb.lemma).entries) {
          for (final variant in variants) {
            expect(variant.finite.length, 6);
            expect(
              variant.participle,
              isNotNull,
              reason: "${verb.lemma} $voice",
            );
            expect(
              variant.infinitive,
              anyOf(endsWith("ειν"), endsWith("εῖν"), endsWith("σθαι")),
            );
          }
        }
      }
    });

    test("Verben der Tabelle stehen in der Vokabelliste", () {
      final verbs = {
        for (final entry in _vocabulary())
          if (entry.type == "verb") entry.lemma,
      };

      for (final verb in GreekFuture.verbs) {
        if (verb.lemma == "παύω" || verb.lemma == "πάσχω") continue;

        expect(verbs, contains(verb.lemma));
        expect(GrammarQuestionPicker.blacklist, isNot(contains(verb.lemma)));
      }
    });
  });

  group("Trainer", () {
    Set<String> picked(
      GreekVocabularyEntry entry,
      VerbParadigm paradigm, {
      List<String> moods = GrammarQuestionPicker.moods,
      List<String> tenses = GrammarQuestionPicker.selectableTenses,
      int count = 600,
    }) {
      final grammar = GrammarLearning(random: Random(3));

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

    test("Standardauswahl fragt auch das Futur", () {
      final tenses = {
        for (final key in picked(_entry("ποιέω"), _paradigm("ποιέω")))
          key.split(" ")[1],
      };

      expect(tenses, {"Präsens", "Imperfekt", "Futur", "Aorist"});
    });

    test("nur Futur: Indikativ, Infinitiv, Partizip – nie Imperativ", () {
      expect(picked(_entry("ποιέω"), _paradigm("ποιέω"), tenses: ["Futur"]), {
        for (final mood in ["Indikativ", "Infinitiv", "Partizip"])
          for (final voice in ["Aktiv", "Medium", "Passiv"])
            "$mood Futur $voice",
      });
    });

    test("Futur abgewählt: keine Futurform", () {
      for (final lemma in ["ποιέω", "λέγω", "ἔρχομαι", "εἰμί", "γράφω"]) {
        final keys = picked(
          _entry(lemma),
          _paradigm(lemma),
          tenses: ["Präsens", "Imperfekt", "Aorist"],
          count: 200,
        );

        expect(keys.where((key) => key.contains("Futur")), isEmpty);
      }
    });

    test("gefragte Form gehört tatsächlich zum Futur", () {
      final grammar = GrammarLearning(random: Random(5));

      for (final lemma in ["γράφω", "ἀγγέλλω", "λαμβάνω", "εἰμί", "ἔχω"]) {
        final paradigm = _paradigm(lemma);
        final future = {
          for (final form in GreekFuture.formsOf(lemma)) form.form,
        };

        for (var i = 0; i < 100; i++) {
          final form = GrammarQuestionPicker.pickVerbTarget(
            grammar,
            _entry(lemma),
            paradigm,
            enabledTenses: const ["Futur"],
          )!;

          expect(form.analysis.tense, "Futur");
          expect(future, contains(form.form));
          expect(
            paradigm.analysesOf(form.form),
            contains(form.analysis),
            reason: form.form,
          );
        }
      }
    });

    test("Genera Verbi im Futur folgen dem Futureintrag", () {
      List<String> voices(String lemma, {bool deponent = false}) {
        return GrammarQuestionPicker.allowedVoices(
          _entry(lemma, deponent: deponent),
          "Futur",
          _paradigm(lemma),
        );
      }

      expect(voices("ποιέω"), ["Aktiv", "Medium", "Passiv"]);
      expect(voices("λαμβάνω"), ["Medium", "Passiv"]);
      expect(voices("γίγνομαι", deponent: true), ["Medium"]);
      expect(voices("ἔρχομαι", deponent: true), ["Medium"]);
      // εἰμί gilt sonst als nur aktiv; sein Futur ist medial.
      expect(voices("εἰμί"), ["Medium"]);
      expect(voices("μένω"), ["Aktiv"]);
      expect(voices("ἔχω"), ["Aktiv"]);

      // Präsens und Aorist unverändert.
      expect(
        GrammarQuestionPicker.allowedVoices(
          _entry("ποιέω"),
          "Präsens",
          _paradigm("ποιέω"),
        ),
        ["Aktiv", "Medium/Passiv"],
      );
      expect(
        GrammarQuestionPicker.allowedVoices(
          _entry("ποιέω"),
          "Aorist",
          _paradigm("ποιέω"),
        ),
        ["Aktiv", "Medium"],
      );
    });

    test("andere Tempora werden durch das Futur nicht verändert", () {
      for (final lemma in ["ποιέω", "λέγω", "ἀγγέλλω", "εἰμί"]) {
        final before = VerbParadigm.fromJson(_fixtures[lemma]).forms;
        final after = _paradigm(
          lemma,
        ).forms.where((form) => form.analysis.tense != "Futur").toList();

        expect(after, before, reason: lemma);
      }
    });

    test("nur Futur: Verben ohne Futurstamm sind nicht verfügbar", () {
      bool available(String lemma) {
        return GrammarQuestionPicker.isAvailable(
          _entry(lemma),
          enabledSteps: const [1],
          enabledTypes: const ["verb"],
          pronounIds: const {},
          enabledTenses: const ["Futur"],
        );
      }

      expect(available("ποιέω"), isTrue);
      expect(available("εἰμί"), isTrue);
      expect(available("εὑρίσκω"), isFalse);
      expect(available("βαίνω"), isFalse);

      // Mit Futur nur im Imperativ gibt es keine Frage.
      expect(
        GrammarQuestionPicker.isAvailable(
          _entry("ποιέω"),
          enabledSteps: const [1],
          enabledTypes: const ["verb"],
          pronounIds: const {},
          enabledMoods: const ["Imperativ"],
          enabledTenses: const ["Futur"],
        ),
        isFalse,
      );
    });

    test("jede Vokabelliste-Auswahl mit nur Futur hat Aufgaben", () {
      final vocabulary = _vocabulary();

      for (var step = 1; step <= 7; step++) {
        final available = vocabulary.where((entry) {
          return GrammarQuestionPicker.isAvailable(
            entry,
            enabledSteps: [step],
            enabledTypes: const ["verb"],
            pronounIds: const {},
            enabledTenses: const ["Futur"],
          );
        });

        expect(available, isNotEmpty, reason: "Schritt $step");
      }
    });

    test("Paradigma aus dem Backend wird um das Futur ergänzt", () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'lemma': 'ποιέω', 'paradigm': _fixtures['ποιέω']}),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final paradigm = await WiktionaryInflectionService().getVerbParadigm(
          'ποιέω',
        );

        expect(paradigm!.analysesOf("ποιηθήσεται").single.voice, "Passiv");
        expect(paradigm.analysesOf("ἐποίησα"), isNotEmpty);
      }, () => client);
    });
  });

  group("Antwortprüfung", () {
    test("παῦσον: Imperativ Aorist und Partizip Futur", () {
      final analyses = _paradigm("παύω").analysesOf("παῦσον");
      final described = analyses.map(describeVerbAnalysis).toSet();

      expect(described, contains("2. Sg. Aorist Imperativ Aktiv"));
      expect(described, contains("Partizip Futur Aktiv · Nominativ Sg. n"));
      expect(described, contains("Partizip Futur Aktiv · Akkusativ Sg. n"));
    });

    test("Medium und Passiv sind im Futur verschieden", () {
      final paradigm = _paradigm("ποιέω");
      final target = paradigm.forms.firstWhere((form) {
        return form.form == "ποιήσεται";
      });

      VerbAnswerResult check(String voice) {
        return checkVerbAnswer(
          target: target.analysis,
          analyses: paradigm.analysesOf(target.form),
          deponent: false,
          userMood: "Indikativ",
          userTense: "Futur",
          userVoice: voice,
          userPersonNumber: "3. Sg.",
        );
      }

      expect(check("Medium").correct, isTrue);
      expect(check("Passiv").correct, isFalse);
      expect(check("Passiv").voiceCorrect, isFalse);
    });

    test("Futur und Präsens werden nicht verwechselt", () {
      final paradigm = _paradigm("κρίνω");

      // κρινοῦμεν (Futur) – κρίνομεν (Präsens): nur der Akzent.
      expect(paradigm.analysesOf("κρινοῦμεν").map((a) => a.tense).toSet(), {
        "Futur",
      });
      expect(paradigm.analysesOf("κρίνομεν").map((a) => a.tense).toSet(), {
        "Präsens",
      });
    });
  });

  group("Grammatikübersicht = Trainer", () {
    test("παύω im Futur aus derselben Quelle", () {
      final overview = ConjugationsScreen.pauo("Futur");

      for (final voice in ["Aktiv", "Medium", "Passiv"]) {
        expect(overview[voice], _finite("παύω", voice), reason: voice);
      }
    });

    test("Partizipien der Übersicht sind die des Trainers", () {
      final trainer = {
        for (final form in GreekFuture.formsOf("παύω")) form.form,
      };

      for (final example in ParticiplesScreen.examples) {
        if (!example.title.contains("Futur")) continue;

        expect(trainer, contains(example.masculine), reason: example.title);
        expect(trainer, contains(example.feminine), reason: example.title);
        expect(trainer, contains(example.neuter), reason: example.title);
      }
    });

    Widget app(Widget home) {
      return MaterialApp(theme: AppTheme.light, home: home);
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets("Zeitformen auswählbar, Futur zeigt Formen des Trainers", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const ConjugationsScreen()));

      expect(find.text("Präsens: Bildung"), findsOneWidget);

      await tester.ensureVisible(find.text("Futur I").last);
      await tester.tap(find.text("Futur I").last);
      await tester.pump();

      expect(find.text("Futur I: Bildung"), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final form in GreekFuture.formsOf("παύω")) {
        if (form.analysis.mood != VerbMood.indicative) continue;

        expect(find.text(form.form), findsWidgets, reason: form.form);
      }
    });

    testWidgets("Nachschlagen zeigt das Futur jedes Verbs vollständig", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Auswahl im Menü.
      await tester.pumpWidget(
        app(const ConjugationsScreen(initialTense: "Futur")),
      );

      final dropdown = find.byKey(const ValueKey("future-verb"));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining("ποιέω –").last);
      await tester.pumpAndSettle();

      expect(find.text("ποιηθησόμεθα"), findsOneWidget);

      for (final lemma in ["ποιέω", "λέγω", "ἀγγέλλω", "ἔχω", "εἰμί"]) {
        await tester.pumpWidget(
          app(
            ConjugationsScreen(
              key: ValueKey(lemma),
              initialTense: "Futur",
              initialFutureVerb: lemma,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        for (final variants in GreekFuture.conjugate(lemma).values) {
          for (final variant in variants) {
            for (final form in [...variant.finite, variant.infinitive]) {
              expect(find.text(form), findsWidgets, reason: "$lemma $form");
            }
          }
        }
      }
    });

    testWidgets("jede Zeitform baut ohne Fehler", (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final tense in ConjugationsScreen.tenses) {
        await tester.pumpWidget(
          app(ConjugationsScreen(key: ValueKey(tense), initialTense: tense)),
        );
        expect(tester.takeException(), isNull, reason: tense);
      }

      await tester.pumpWidget(app(const InfinitiveScreen()));
      for (final form in ["παύσειν", "παύσεσθαι", "παυθήσεσθαι"]) {
        expect(find.text(form), findsWidgets, reason: form);
      }
    });
  });

  group("Einstellungen", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("bestehende Einstellungen: Futur ist zusätzlich aktiv", () async {
      // Gespeicherte Einstellungen aus der Zeit vor dem Zeitformfilter.
      SharedPreferences.setMockInitialValues({
        "guest.v1.settings": jsonEncode({
          "greek_grammar_settings": {
            "enabledSteps": [2, 3],
            "enabledTypes": ["noun", "verb"],
            "showLemmaFieldVerb": false,
          },
        }),
      });

      final settings = await GrammarSettingsService().load(null);

      expect(settings.enabledSteps, [2, 3]);
      expect(settings.enabledTypes, ["noun", "verb"]);
      expect(settings.showLemmaFieldVerb, isFalse);
      expect(settings.enabledTenses, contains("Futur"));
      expect(settings.enabledMoods, GrammarQuestionPicker.moods);
    });

    test("Gastmodus: Modi und Zeitformen überstehen den Neustart", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(
          enabledMoods: ["Indikativ", "Partizip"],
          enabledTenses: ["Futur"],
          enabledPronounKinds: ["personal"],
          askLemmaTranslation: true,
        ),
      );

      final loaded = await service.load(null);

      expect(loaded.enabledMoods, ["Indikativ", "Partizip"]);
      expect(loaded.enabledTenses, ["Futur"]);
      expect(loaded.enabledPronounKinds, ["personal"]);
      expect(loaded.askLemmaTranslation, isTrue);
    });

    test("nur Futur bleibt nach dem Neustart gespeichert", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(enabledTenses: ["Futur"]),
      );

      expect((await service.load(null)).enabledTenses, ["Futur"]);

      await service.save(
        null,
        const GrammarTrainerSettings(enabledTenses: ["Futur", "Aorist"]),
      );

      expect((await service.load(null)).enabledTenses, ["Futur", "Aorist"]);
    });
  });
}

String _stripAccents(String text) => stripGreekAccent(text);
