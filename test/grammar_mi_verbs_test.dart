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
import 'package:theologie_lernapp/screens/greek/grammar_topics/mi_verbs_screen.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_settings_service.dart';
import 'package:theologie_lernapp/services/greek/grammar/greek_future.dart';
import 'package:theologie_lernapp/services/greek/grammar/greek_mi_verbs.dart';
import 'package:theologie_lernapp/services/greek/grammar/greek_subjunctive.dart';
import 'package:theologie_lernapp/services/greek/grammar/mi_verb_exercises.dart';
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

/// Paradigma, wie der Trainer es nach dem Laden hat.
VerbParadigm _paradigm(String lemma) {
  final backend = _fixtures.containsKey(lemma)
      ? GreekSubjunctive.extend(
          lemma,
          GreekFuture.extend(lemma, VerbParadigm.fromJson(_fixtures[lemma])),
        )
      : null;

  return GreekMiVerbs.extend(lemma, backend);
}

List<GreekVocabularyEntry> _vocabulary() {
  final List<dynamic> json = jsonDecode(
    File("assets/greek_vocabulary.json").readAsStringSync(),
  );

  return [for (final item in json) GreekVocabularyEntry.fromJson(item)];
}

List<String> _described(VerbParadigm paradigm, String form) {
  return [for (final a in paradigm.analysesOf(form)) describeVerbAnalysis(a)];
}

GreekVocabularyEntry _verbEntry(String lemma) {
  return MiVerbExercises.verbEntries.firstWhere((e) => e.lemma == lemma);
}

void main() {
  group("Tabellen der Folie", () {
    test("vier Verben mit je sieben Tabellen und zwei Partizipien", () {
      expect(GreekMiVerbs.lemmas, ["δίδωμι", "τίθημι", "ἵημι", "ἵστημι"]);

      for (final verb in GreekMiVerbs.verbs) {
        expect(
          [for (final table in verb.tables) table.slideTitle],
          [
            "Präsens aktiv",
            "Präsens passiv",
            "Imperfekt aktiv",
            "Imperfekt passiv",
            "Aorist aktiv",
            "Aorist medium",
            "Aorist passiv",
          ],
          reason: verb.lemma,
        );

        for (final table in verb.tables) {
          expect(table.forms.length, 6, reason: verb.lemma);
          // Imperfekt ohne Infinitiv, alle anderen Tabellen mit.
          expect(
            table.infinitive == null,
            table.tense == "Imperfekt",
            reason: "${verb.lemma} ${table.slideTitle}",
          );
        }

        expect(verb.participles.map((p) => p.tense), ["Präsens", "Aorist"]);
      }
    });

    test("Formen wörtlich nach der Folie", () {
      expect(GreekMiVerbs.didomi.table("Präsens aktiv").forms, [
        "δίδωμι",
        "δίδως",
        "δίδωσι(ν)",
        "δίδομεν",
        "δίδοτε",
        "διδόασι(ν)",
      ]);
      expect(GreekMiVerbs.tithemi.table("Imperfekt aktiv").forms, [
        "ἐτίθην",
        "ἐτίθεις",
        "ἐτίθει",
        "ἐτίθεμεν",
        "ἐτίθετε",
        "ἐτίθεσαν",
      ]);
      expect(GreekMiVerbs.hiemi.table("Aorist aktiv").forms, [
        "ἧκα",
        "ἧκας",
        "ἧκεν",
        "εἷμεν",
        "εἷτε",
        "εἷσαν",
      ]);
      expect(GreekMiVerbs.hiemi.table("Aorist medium").infinitive, "ἕσθαι");
      expect(
        GreekMiVerbs.histemi.table("Aorist passiv").infinitive,
        "σταθῆναι",
      );
      expect(
        GreekMiVerbs.didomi.table("Präsens passiv").voice,
        "Medium/Passiv",
      );
    });

    test("ἵστημι: ἔστησαν berichtigt, ἔστην als Wurzelaorist (Aktiv)", () {
      final sigma = GreekMiVerbs.histemi.table("Aorist aktiv");
      final root = GreekMiVerbs.histemi.table("Aorist medium");

      expect(sigma.forms.last, "ἔστησαν");
      expect(sigma.note, contains("ἔστασαν"));
      expect(sigma.voice, "Aktiv");

      expect(root.forms, [
        "ἔστην",
        "ἔστης",
        "ἔστη",
        "ἔστημεν",
        "ἔστητε",
        "ἔστησαν",
      ]);
      expect(root.voice, "Aktiv");
      expect(root.rootAorist, isTrue);
      expect(root.infinitive, "στῆναι");
      expect(root.note, contains("(!)"));
    });

    test("Partizipien: vollständig dekliniert, wo die Folie es bestätigt", () {
      for (final verb in GreekMiVerbs.verbs) {
        for (final participle in verb.participles) {
          final cells = GreekMiVerbs.participleCells(participle);
          final declined = GreekMiVerbs.participleDeclension(participle);

          // εἵς, εἷσα, ἕν lässt sich nicht bestätigen: nur die Folie.
          if (participle.nominative.first == "εἵς") {
            expect(declined, isNull);
            expect(cells.length, 7);
            expect(cells.map((c) => c.form).toSet(), {
              ...participle.nominative,
              ...participle.genitive,
            });
            continue;
          }

          expect(declined, isNotNull, reason: participle.nominative.first);
          expect(cells.length, 24);
        }
      }

      String form(MiVerbParticiple p, String c, String n, String g) {
        return GreekMiVerbs.participleDeclension(p)!.form(c, n, g)!;
      }

      final didous = GreekMiVerbs.didomi.participles.first;
      final histas = GreekMiVerbs.histemi.participles.first;
      final stesas = GreekMiVerbs.histemi.participles.last;

      expect(form(didous, "Dativ", "Pl", "m"), "διδοῦσι(ν)");
      expect(form(didous, "Akkusativ", "Sg", "f"), "διδοῦσαν");
      expect(form(histas, "Dativ", "Pl", "n"), "ἱστᾶσι(ν)");
      expect(form(stesas, "Genitiv", "Pl", "f"), "στησασῶν");
    });
  });

  group("Paradigma im Trainer", () {
    test("τίθημι: Folie ersetzt die Backend-Tabellen, Rest bleibt", () {
      final paradigm = _paradigm("τίθημι");

      // Imperfekt und Aorist Sg. der Folie statt ἐτίθουν bzw. Lücken.
      expect(_described(paradigm, "ἐτίθην"), [
        "1. Sg. Imperfekt Indikativ Aktiv",
      ]);
      expect(paradigm.analysesOf("ἐτίθουν"), isEmpty);
      expect(_described(paradigm, "ἔθηκα"), ["1. Sg. Aorist Indikativ Aktiv"]);
      expect(_described(paradigm, "ἐτέθην"), [
        "1. Sg. Aorist Indikativ Passiv",
      ]);
      expect(_described(paradigm, "τιθείς"), [
        "Partizip Präsens Aktiv · Nominativ Sg. m",
      ]);

      // Aus dem Backend: Imperativ und mediale Partizipien.
      expect(_described(paradigm, "θές"), ["2. Sg. Aorist Imperativ Aktiv"]);
      expect(paradigm.analysesOf("τιθέμενος"), isNotEmpty);

      // Kein Konjunktiv der μι-Verben.
      expect(
        paradigm.forms.where((f) => f.analysis.mood == VerbMood.subjunctive),
        isEmpty,
      );
    });

    test("ἵστημι und ἵημι nur aus der Folie", () {
      final histemi = _paradigm("ἵστημι");

      expect(
        histemi.forms.map((f) => f.analysis.mood).toSet(),
        GreekMiVerbs.slideMoods.toSet(),
      );

      // ἔστησαν: 3. Pl. beider Aoriste – einmal genannt.
      expect(_described(histemi, "ἔστησαν"), [
        "3. Pl. Aorist Indikativ Aktiv",
        "3. Pl. Aorist Indikativ Aktiv",
      ]);
      // ἵστης: Präsens und Imperfekt sind formgleich.
      expect(_described(histemi, "ἵστης"), [
        "2. Sg. Präsens Indikativ Aktiv",
        "2. Sg. Imperfekt Indikativ Aktiv",
      ]);

      final hiemi = _paradigm("ἵημι");

      expect(_described(hiemi, "ἕν").toSet(), {
        "Partizip Aorist Aktiv · Nominativ Sg. n",
        "Partizip Aorist Aktiv · Akkusativ Sg. n",
      });
    });

    test("Service: ἵστημι ohne Netz, δίδωμι ohne Netz aus der Folie", () async {
      var requests = 0;

      final client = MockClient((request) async {
        requests++;
        throw http.ClientException("offline");
      });

      await http.runWithClient(() async {
        final service = WiktionaryInflectionService();

        final histemi = await service.getVerbParadigm("ἵστημι");
        expect(requests, 0);
        expect(histemi!.analysesOf("ἔστην"), isNotEmpty);

        final didomi = await service.getVerbParadigm("δίδωμι");
        expect(requests, 1);
        expect(_described(didomi!, "ἔδωκα"), ["1. Sg. Aorist Indikativ Aktiv"]);
        expect(service.cachedVerbParadigm("δίδωμι"), same(didomi));
      }, () => client);
    });

    test("Service: δίδωμι mit Backend behält den Imperativ", () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'lemma': 'δίδωμι', 'paradigm': _fixtures['δίδωμι']}),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final paradigm = await WiktionaryInflectionService().getVerbParadigm(
          "δίδωμι",
        );

        expect(_described(paradigm!, "δός"), ["2. Sg. Aorist Imperativ Aktiv"]);
        expect(_described(paradigm, "ἐδόθησαν"), [
          "3. Pl. Aorist Indikativ Passiv",
        ]);
      }, () => client);
    });
  });

  group("Formen bestimmen", () {
    test("Verbaufgaben nur über die Wortart Verben auf -μι", () {
      final entry = _verbEntry("ἵστημι");

      bool available({
        List<String> types = const ["mi_verbs"],
        List<String> kinds = MiVerbExercises.kinds,
        List<String> moods = VerbMood.all,
      }) {
        return GrammarQuestionPicker.isAvailable(
          entry,
          enabledSteps: const [1, 2, 3, 4, 5, 6, 7],
          enabledTypes: types,
          pronounIds: const {},
          miVerbIds: MiVerbExercises.idsOfKinds(kinds),
          enabledMoods: moods,
        );
      }

      expect(available(), isTrue);
      expect(available(types: const ["verb"]), isFalse);
      expect(available(kinds: const ["build", "usage"]), isFalse);
      // Von ἵστημι gibt es weder Imperativ noch Konjunktiv.
      expect(available(moods: const ["Imperativ", "Konjunktiv"]), isFalse);
      expect(available(moods: const ["Partizip"]), isTrue);
    });

    test("Aorist Passiv im Indikativ gefragt, ἔστην und ἔστησα beide", () {
      final grammar = GrammarLearning(random: Random(4));
      final entry = _verbEntry("ἵστημι");
      final paradigm = _paradigm("ἵστημι");

      final picked = <String>{};

      for (var i = 0; i < 1500; i++) {
        final target = GrammarQuestionPicker.pickVerbTarget(
          grammar,
          entry,
          paradigm,
          enabledMoods: const [VerbMood.indicative],
          enabledTenses: const ["Aorist"],
        );

        picked.add(target!.form);
      }

      expect(picked, containsAll(["ἐστάθην", "ἔστην", "ἔστησα", "ἔστη"]));
    });

    test("Vokabel τίθημι: Aorist Passiv Indikativ gehört zum Lernstoff", () {
      final entry = _vocabulary().firstWhere((e) => e.lemma == "τίθημι");
      final paradigm = _paradigm("τίθημι");

      expect(GrammarQuestionPicker.allowedVoices(entry, "Aorist", paradigm), [
        "Aktiv",
        "Medium",
        "Passiv",
      ]);

      // Ein anderes Verb bleibt wie bisher.
      final pauo = GreekVocabularyEntry(
        id: 1,
        step: 1,
        type: "verb",
        lemma: "παύω",
        translations: const ["x"],
      );

      expect(
        GrammarQuestionPicker.allowedVoices(pauo, "Aorist", _paradigm("παύω")),
        isNot(contains("Passiv")),
      );
    });

    test("ἔστην: Aktiv richtig, Medium falsch – mit Erklärung", () {
      final paradigm = _paradigm("ἵστημι");
      final analyses = paradigm.analysesOf("ἔστην");

      VerbAnswerResult check(String voice) {
        return checkVerbAnswer(
          target: analyses.first,
          analyses: analyses,
          deponent: false,
          userMood: "Indikativ",
          userTense: "Aorist",
          userVoice: voice,
          userPersonNumber: "1. Sg.",
        );
      }

      expect(check("Aktiv").correct, isTrue);
      expect(check("Medium").correct, isFalse);

      final hints = GreekMiVerbs.explain(
        lemma: "ἵστημι",
        form: "ἔστην",
        analysis: analyses.first,
        userTense: "Aorist",
        userVoice: "Medium",
        userPersonNumber: "1. Sg.",
      );

      expect(hints.single, contains("Wurzelaorist"));
    });

    test("Erklärungen: Tempus und Ablaut, nichts bei anderen Verben", () {
      final paradigm = _paradigm("δίδωμι");
      final edidou = paradigm.analysesOf("ἐδίδου").first;

      expect(
        GreekMiVerbs.explain(
          lemma: "δίδωμι",
          form: "ἐδίδου",
          analysis: edidou,
          userTense: "Aorist",
        ).single,
        contains("Augment"),
      );

      final didomen = paradigm.analysesOf("δίδομεν").first;

      expect(
        GreekMiVerbs.explain(
          lemma: "δίδωμι",
          form: "δίδομεν",
          analysis: didomen,
          userTense: "Präsens",
          userPersonNumber: "1. Sg.",
        ).single,
        contains("Ablaut"),
      );

      expect(
        GreekMiVerbs.explain(
          lemma: "παύω",
          form: "παύομεν",
          analysis: didomen,
          userTense: "Aorist",
        ),
        isEmpty,
      );
    });
  });

  group("Formen bilden", () {
    test("jede Form der Folie, stabile und eindeutige IDs", () {
      final tasks = MiVerbExercises.buildTasks;

      // Je Verb 7 × 6 Formen, 5 Infinitive, 2 × 6 Partizipformen.
      expect(tasks.length, 4 * (42 + 5 + 12));
      expect(tasks.map((t) => t.id).toSet().length, tasks.length);

      for (final task in tasks) {
        expect(task.id, inInclusiveRange(11500, 11899));
      }

      final first = MiVerbExercises.buildTask(11500)!;
      expect(first.answer, "δίδωμι");
      expect(first.description, "1. Sg. Präsens Indikativ Aktiv");

      final infinitive = MiVerbExercises.buildTask(11666)!;
      expect(infinitive.answer, "τεθῆναι");
      expect(infinitive.description, "Infinitiv Aorist Passiv");

      final participle = MiVerbExercises.buildTask(11884)!;
      expect(participle.answer, "στησάσης");
      expect(participle.description, "Partizip Aorist Aktiv · Genitiv Sg. f");
      expect(participle.hint, contains("ἔστησα"));

      final root = MiVerbExercises.buildTask(11850)!;
      expect(root.answer, "ἔστην");
      expect(root.hint, contains("Wurzelaorist"));
    });

    test("Antwortprüfung: Akzente optional, bewegliches ν frei", () {
      final edoke = MiVerbExercises.buildTasks.firstWhere(
        (t) => t.answer == "ἔδωκεν",
      );

      for (final input in ["ἔδωκεν", "ἔδωκε", "εδωκεν"]) {
        expect(
          MiVerbExercises.checkForm(input, edoke).correct,
          isTrue,
          reason: input,
        );
      }

      expect(MiVerbExercises.checkForm("ἐδώκεν", edoke).correct, isFalse);
      expect(MiVerbExercises.checkForm("ἔδωκα", edoke).correct, isFalse);

      final didosi = MiVerbExercises.buildTask(11502)!;

      for (final input in ["δίδωσι", "δίδωσιν", "διδωσι"]) {
        expect(
          MiVerbExercises.checkForm(input, didosi).correct,
          isTrue,
          reason: input,
        );
      }
    });

    test("Fehlererklärungen", () {
      MiVerbBuildTask task(String answer, String lemma) {
        return MiVerbExercises.buildTasks.firstWhere(
          (t) => t.answer == answer && t.lemma == lemma,
        );
      }

      // Imperfekt statt Aorist: welche Form es ist, und keine Reduplikation.
      final hints = MiVerbExercises.explainBuild(
        task("ἔδωκα", "δίδωμι"),
        "ἐδίδουν",
      );
      expect(hints.first, contains("1. Sg. Imperfekt Indikativ Aktiv"));
      expect(hints.join(" "), contains("keine Präsensreduplikation"));

      // Präsens ohne Reduplikation.
      expect(
        MiVerbExercises.explainBuild(task("τίθεμεν", "τίθημι"), "θεμεν"),
        contains(contains("Reduplikation")),
      );

      // κ im Plural.
      expect(
        MiVerbExercises.explainBuild(
          task("ἔθεσαν", "τίθημι"),
          "ἔθηκαν",
        ).join(" "),
        contains("ohne κ"),
      );

      // Aorist Passiv ohne θη.
      expect(
        MiVerbExercises.explainBuild(
          task("ἐδόθην", "δίδωμι"),
          "ἐδόμην",
        ).join(" "),
        contains("θη"),
      );

      // Form eines anderen Verbs.
      expect(
        MiVerbExercises.explainBuild(task("ἔδωκα", "δίδωμι"), "ἔθηκα").first,
        contains("τίθημι"),
      );

      // Nur Akzent falsch.
      expect(MiVerbExercises.explainBuild(task("ἔδωκα", "δίδωμι"), "ἐδῶκα"), [
        "Buchstaben richtig – Akzent oder Spiritus stimmen nicht.",
      ]);
    });
  });

  group("Sätze", () {
    test("Sätze der Folie mit Form, Verb und Tempus", () {
      final tasks = MiVerbExercises.usageTasks;

      expect(tasks.length, 7);
      expect(tasks.map((t) => t.id).toSet().length, 7);

      for (final task in tasks) {
        expect(task.sentence, contains(task.form), reason: task.form);
        expect(GreekMiVerbs.lemmas, contains(task.verb));
        expect(MiVerbExercises.usageTenses, contains(task.tense));
        expect(task.reference, isNotEmpty);
      }

      final aneste = tasks.firstWhere((t) => t.form == "ἀνέστη");
      expect(aneste.verb, "ἵστημι");
      expect(aneste.tense, "Aorist");
      expect(aneste.reference, "Mk 5,42");

      expect(tasks.firstWhere((t) => t.form == "ἐδίδου").tense, "Imperfekt");
    });
  });

  group("Auswahl und Einstellungen", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Aufgabenarten einzeln wählbar", () {
      expect(MiVerbExercises.idsOfKinds(const ["identify"]), {
        11401,
        11402,
        11403,
        11404,
      });
      expect(MiVerbExercises.idsOfKinds(const ["usage"]), {
        for (final t in MiVerbExercises.usageTasks) t.id,
      });

      final build = MiVerbExercises.entries.firstWhere((e) => e.id == 11500);

      expect(
        GrammarQuestionPicker.isAvailable(
          build,
          enabledSteps: const [],
          enabledTypes: const ["mi_verbs"],
          pronounIds: const {},
          miVerbIds: MiVerbExercises.idsOfKinds(const ["build"]),
        ),
        isTrue,
      );
      expect(
        GrammarQuestionPicker.isAvailable(
          build,
          enabledSteps: const [],
          enabledTypes: const ["verb"],
          pronounIds: const {},
          miVerbIds: MiVerbExercises.idsOfKinds(const ["build"]),
        ),
        isFalse,
      );
    });

    test("eigene Gruppe, nicht Teil von „alle Wörter“", () {
      final grammar = GrammarLearning(random: Random(3));
      final vocabulary = [
        ..._vocabulary().where((entry) => entry.type != "pronoun"),
        ...MiVerbExercises.entries,
      ];

      var mi = 0;

      for (var i = 0; i < 600; i++) {
        if (MiVerbExercises.owns(
          GrammarQuestionPicker.pickEntry(grammar, vocabulary),
        )) {
          mi++;
        }
      }

      expect(mi, greaterThan(100));
      expect(mi, lessThan(300));
    });

    test("Standard: alle Aufgabenarten; gespeicherte Auswahl bleibt", () async {
      expect(GrammarTrainerSettings.fromMap(null).enabledMiVerbKinds, [
        "identify",
        "build",
        "usage",
      ]);
      expect(
        GrammarTrainerSettings.fromMap(null).enabledTypes,
        contains("mi_verbs"),
      );

      SharedPreferences.setMockInitialValues({
        "guest.v1.settings": jsonEncode({
          "greek_grammar_settings": {
            "enabledTypes": ["noun", "verb"],
          },
        }),
      });

      final settings = await GrammarSettingsService().load(null);

      expect(settings.enabledTypes, ["noun", "verb"]);
      expect(settings.enabledMiVerbKinds, MiVerbExercises.kinds);
    });

    test("Gastmodus: Auswahl übersteht den Neustart", () async {
      final service = GrammarSettingsService();

      await service.save(
        null,
        const GrammarTrainerSettings(
          enabledTypes: ["mi_verbs"],
          enabledMiVerbKinds: ["usage"],
        ),
      );

      final loaded = await service.load(null);

      expect(loaded.enabledTypes, ["mi_verbs"]);
      expect(loaded.enabledMiVerbKinds, ["usage"]);
    });

    test("unbekannte Aufgabenarten werden verworfen", () {
      final settings = GrammarTrainerSettings.fromMap(<String, dynamic>{
        'enabledMiVerbKinds': ["build", "optativ", 3],
      });

      expect(settings.enabledMiVerbKinds, ["build"]);
    });

    test("Lernfortschritt zeigt Grundform und Tempus", () {
      expect(
        GreekGrammarProgressView.label(
          GrammarLearning.dimensionId("mi_verbs", "lemma", "ἵστημι"),
        ),
        "Verben auf -μι – Grundform: ἵστημι",
      );
    });
  });

  group("Grammatikübersicht", () {
    testWidgets("zeigt die Tabellen, Sätze und den Grammatikhinweis", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const MiVerbsScreen()),
      );

      expect(tester.takeException(), isNull);

      for (final form in ["δίδωμι", "τιθέασι(ν)", "ἱᾶσι(ν)"]) {
        expect(find.text(form), findsWidgets, reason: form);
      }

      await tester.scrollUntilVisible(
        find.text("ἔστην (!)"),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.scrollUntilVisible(
        find.textContaining("Ars Graeca § 106-107"),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining("Grammateion § 3.4.1"), findsOneWidget);
    });
  });
}
