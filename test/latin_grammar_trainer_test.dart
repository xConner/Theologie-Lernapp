import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_answer_check.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_store.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_trainer.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_words.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_morphology.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';

LatinGrammarTaskGenerator _generator({
  int seed = 1,
  GrammarLearning? learning,
}) {
  return LatinGrammarTaskGenerator(
    learning: learning ?? GrammarLearning(random: Random(seed)),
    random: Random(seed),
  );
}

LatinGrammarSettings _only(String topic, {List<String>? kinds}) {
  return LatinGrammarSettings(
    enabledTopics: [topic],
    enabledKinds: kinds ?? LatinGrammarKinds.all,
  );
}

LatinNoun _noun(String id) =>
    LatinGrammarWords.nouns.firstWhere((noun) => noun.id == id);

LatinVerb _verb(String id) =>
    LatinGrammarWords.verbs.firstWhere((verb) => verb.id == id);

void main() {
  group("Aufgaben erzeugen", () {
    test("jedes Thema liefert stimmige Aufgaben", () {
      final generator = _generator();

      for (final topic in LatinTrainerTopics.ids) {
        for (var i = 0; i < 150; i++) {
          final task = generator.next(_only(topic));

          expect(task, isNotNull, reason: topic);
          expect(task!.topic, topic);

          switch (task) {
            case NominalIdentifyTask():
              expect(task.analyses, contains(task.target), reason: task.form);
              expect(task.lemmas, isNotEmpty);
            case NominalBuildTask():
              expect(task.accepted, isNotEmpty);

              for (final form in task.accepted) {
                expect(task.otherForms.keys, isNot(contains(form)));
              }
            case VerbIdentifyTask():
              expect(task.analyses, contains(task.target), reason: task.form);
              expect(
                LatinGrammarTaskGenerator.topicContains(topic, task.target),
                isTrue,
              );
            case VerbBuildTask():
              expect(task.accepted, isNotEmpty);
              expect(
                LatinGrammarTaskGenerator.topicContains(topic, task.target),
                isTrue,
              );
            case ChoiceTask():
              expect(task.options, contains(task.answer));
              expect(task.options.toSet(), hasLength(task.options.length));
          }
        }
      }
    });

    test("Aufgabenarten werden beachtet", () {
      final generator = _generator(seed: 3);

      for (var i = 0; i < 100; i++) {
        final identify = generator.next(
          _only(
            LatinTrainerTopics.verbsPresent,
            kinds: [LatinGrammarKinds.identify],
          ),
        );
        final build = generator.next(
          _only(LatinTrainerTopics.nounsAO, kinds: [LatinGrammarKinds.build]),
        );

        expect(identify, isA<VerbIdentifyTask>());
        expect(build, isA<NominalBuildTask>());
      }
    });

    test("ohne Vokativ-Einstellung wird kein Vokativ gefragt", () {
      final generator = _generator(seed: 5);

      for (var i = 0; i < 300; i++) {
        final task = generator.next(_only(LatinTrainerTopics.nounsAO));

        final target = switch (task) {
          NominalIdentifyTask() => task.target,
          NominalBuildTask() => task.target,
          _ => null,
        };

        expect(target?.grammaticalCase, isNot(LatinCases.vocative));
      }
    });

    test("nur Wörter aus dem Wortschatz", () {
      final generator = _generator(seed: 7);

      const settings = LatinGrammarSettings(
        enabledTopics: [
          LatinTrainerTopics.nounsAO,
          LatinTrainerTopics.nouns3,
          LatinTrainerTopics.verbsPresent,
          LatinTrainerTopics.verbsPerfect,
          LatinTrainerTopics.prepositions,
        ],
        vocabularyOnly: true,
      );

      final nounIds = {
        for (final n in LatinGrammarWords.nouns)
          if (n.vocabularyId != null) n.id,
      };

      for (var i = 0; i < 300; i++) {
        final task = generator.next(settings)!;

        switch (task) {
          case NominalIdentifyTask():
            expect(nounIds, contains(task.wordId));
          case NominalBuildTask():
            expect(nounIds, contains(task.wordId));
          case VerbIdentifyTask():
            expect(task.verb.vocabularyId, isNotNull);
          case VerbBuildTask():
            expect(task.verb.vocabularyId, isNotNull);
          case ChoiceTask():
            final lemma = task.prompt;
            final preposition = LatinGrammarWords.prepositions.firstWhere(
              (p) => p.lemma == lemma,
            );
            expect(preposition.vocabularyId, isNotNull);
        }
      }
    });

    test("Themen ohne passende Wörter sind nicht verfügbar", () {
      final generator = _generator();

      // Adjektive kommen im Wortschatz der Lektionen 1–3 nicht vor.
      expect(
        generator.availableTopics(
          const LatinGrammarSettings(
            enabledTopics: [LatinTrainerTopics.adjectives],
            vocabularyOnly: true,
          ),
        ),
        isEmpty,
      );

      expect(
        generator.next(
          const LatinGrammarSettings(
            enabledTopics: [LatinTrainerTopics.nounsAO],
            enabledKinds: [],
          ),
        ),
        isNull,
      );

      // Auswahlaufgaben brauchen keine Aufgabenart.
      expect(
        generator.next(
          const LatinGrammarSettings(
            enabledTopics: [LatinTrainerTopics.prepositions],
            enabledKinds: [],
          ),
        ),
        isA<ChoiceTask>(),
      );
    });

    test("schwache Werte kommen häufiger", () {
      final learning = GrammarLearning(random: Random(11));

      for (var i = 0; i < 6; i++) {
        learning.record({
          GrammarLearning.dimensionId("noun", "case", LatinCases.ablative):
              false,
        });
      }

      for (final c in [
        LatinCases.nominative,
        LatinCases.genitive,
        LatinCases.dative,
        LatinCases.accusative,
      ]) {
        for (var i = 0; i < 6; i++) {
          learning.record({
            GrammarLearning.dimensionId("noun", "case", c): true,
          });
        }
      }

      final generator = _generator(seed: 11, learning: learning);
      final counts = <String, int>{};

      for (var i = 0; i < 1000; i++) {
        final task =
            generator.next(
                  _only(
                    LatinTrainerTopics.nounsAO,
                    kinds: [LatinGrammarKinds.identify],
                  ),
                )
                as NominalIdentifyTask;

        counts.update(
          task.target.grammaticalCase,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }

      expect(
        counts[LatinCases.ablative]!,
        greaterThan(counts[LatinCases.nominative]! * 2),
      );
    });
  });

  group("Antworten prüfen", () {
    test("Längenzeichen sind beim Bilden freiwillig", () {
      final result = checkFormAnswer(
        input: "amas",
        accepted: ["amās"],
        otherForms: {"amat": "3. Sg."},
      );

      expect(result.correct, isTrue);
      expect(result.macronMismatch, isFalse);
    });

    test("gesetzte Längen müssen die gefragte Form treffen", () {
      final venire = _verb("venire").paradigm();
      const present = VerbAnalysis(
        LatinMoods.indicative,
        LatinTenses.present,
        LatinVoices.active,
        "3. Sg.",
      );

      final accepted = venire.formsOf(present);
      final others = {
        for (final entry in venire.cells.entries)
          if (entry.key != present)
            for (final form in entry.value) form: entry.key.describe(),
      };

      final perfect = checkFormAnswer(
        input: "vēnit",
        accepted: accepted,
        otherForms: others,
      );

      expect(perfect.correct, isFalse);
      expect(perfect.otherAnalysis, contains(LatinTenses.perfect));

      expect(
        checkFormAnswer(
          input: "venit",
          accepted: accepted,
          otherForms: others,
        ).correct,
        isTrue,
      );
    });

    test("„Längenzeichen verlangen“ zählt nur exakte Formen", () {
      final result = checkFormAnswer(
        input: "amas",
        accepted: ["amās"],
        otherForms: const {},
        requireMacrons: true,
      );

      expect(result.correct, isFalse);
      expect(result.macronMismatch, isTrue);

      expect(
        checkFormAnswer(
          input: "amās",
          accepted: ["amās"],
          otherForms: const {},
          requireMacrons: true,
        ).correct,
        isTrue,
      );
    });

    test("falsch gesetzte Längen: richtig mit Hinweis", () {
      final result = checkFormAnswer(
        input: "āmas",
        accepted: ["amās"],
        otherForms: const {},
      );

      expect(result.correct, isTrue);
      expect(result.macronMismatch, isTrue);
    });

    test("Groß-/Kleinschreibung, j und zerlegte Längenzeichen", () {
      expect(
        checkFormAnswer(
          input: "  Adjuvo ",
          accepted: ["adiuvō"],
          otherForms: const {},
        ).correct,
        isTrue,
      );

      expect(
        checkFormAnswer(
          input: "amās",
          accepted: ["amās"],
          otherForms: const {},
          requireMacrons: true,
        ).correct,
        isTrue,
      );
    });

    test("Nebenformen sind gleichwertig", () {
      final paradigm = _verb("amare").paradigm();
      const analysis = VerbAnalysis(
        LatinMoods.indicative,
        LatinTenses.present,
        LatinVoices.passive,
        "2. Sg.",
      );

      final accepted = paradigm.formsOf(analysis);

      expect(accepted, containsAll(["amāris", "amāre"]));

      for (final form in accepted) {
        expect(
          checkFormAnswer(
            input: form,
            accepted: accepted,
            otherForms: const {},
          ).correct,
          isTrue,
        );
      }
    });

    test("andere Form des Paradigmas wird benannt, Tippfehler erkannt", () {
      final paradigm = _noun("dominus").paradigm();
      const target = NominalAnalysis(
        LatinCases.accusative,
        LatinNumbers.plural,
      );
      final accepted = paradigm.formsOf(target);
      final others = {
        for (final entry in paradigm.cells.entries)
          if (entry.key != target)
            for (final form in entry.value) form: entry.key.describe(),
      };

      final grammatical = checkFormAnswer(
        input: "dominum",
        accepted: accepted,
        otherForms: others,
      );

      expect(grammatical.correct, isFalse);
      expect(grammatical.otherAnalysis, "Akkusativ Singular");
      expect(grammatical.likelyTypo, isFalse);

      final typo = checkFormAnswer(
        input: "dominoss",
        accepted: accepted,
        otherForms: others,
      );

      expect(typo.correct, isFalse);
      expect(typo.likelyTypo, isTrue);
      expect(typo.expected, "dominōs");
    });

    test("mehrdeutige Formen: jede vollständige Bestimmung zählt", () {
      final generator = _generator(seed: 2);
      NominalIdentifyTask? task;

      for (var i = 0; i < 2000 && task == null; i++) {
        final next = generator.next(
          _only(
            LatinTrainerTopics.nounsAO,
            kinds: [LatinGrammarKinds.identify],
          ),
        );

        if (next is NominalIdentifyTask && next.form == "servī") task = next;
      }

      expect(task, isNotNull);

      final genitive = checkNominalIdentification(
        task!,
        grammaticalCase: LatinCases.genitive,
        number: LatinNumbers.singular,
        gender: LatinGenders.masculine,
      );
      final nominative = checkNominalIdentification(
        task,
        grammaticalCase: LatinCases.nominative,
        number: LatinNumbers.plural,
        gender: LatinGenders.masculine,
      );
      final mixed = checkNominalIdentification(
        task,
        grammaticalCase: LatinCases.genitive,
        number: LatinNumbers.plural,
        gender: LatinGenders.masculine,
      );

      expect(genitive.correct, isTrue);
      expect(nominative.correct, isTrue);
      expect(mixed.correct, isFalse);
    });

    test("beim Infinitiv zählt keine Person", () {
      final verb = _verb("amare");
      const target = VerbAnalysis(
        LatinMoods.infinitive,
        LatinTenses.present,
        LatinVoices.active,
      );

      final task = VerbIdentifyTask(
        topic: LatinTrainerTopics.verbsPresent,
        verb: verb,
        form: "amāre",
        target: target,
        analyses: verb.paradigm().analysesOf("amāre"),
        explanation: "",
      );

      final result = checkVerbIdentification(
        task,
        mood: LatinMoods.infinitive,
        tense: LatinTenses.present,
        voice: LatinVoices.active,
        person: null,
      );

      expect(result.correct, isTrue);

      // amāre ist auch 2. Sg. Präsens Passiv (Nebenform zu amāris).
      final passive = checkVerbIdentification(
        task,
        mood: LatinMoods.indicative,
        tense: LatinTenses.present,
        voice: LatinVoices.passive,
        person: "2. Sg.",
      );

      expect(passive.correct, isTrue);
    });

    test("Grundform ohne Längenzeichen und als 1. Sg.", () {
      final verb = _verb("venire");

      expect(lemmaMatches("venire", verbLemmas(verb)), isTrue);
      expect(lemmaMatches("Veniō", verbLemmas(verb)), isTrue);
      expect(lemmaMatches("venis", verbLemmas(verb)), isFalse);
    });

    test("Bestimmungsfelder gehen einzeln in den Lernstand ein", () {
      final task = VerbIdentifyTask(
        topic: LatinTrainerTopics.verbsPresent,
        verb: _verb("amare"),
        form: "amat",
        target: const VerbAnalysis(
          LatinMoods.indicative,
          LatinTenses.present,
          LatinVoices.active,
          "3. Sg.",
        ),
        analyses: const [],
        explanation: "",
      );

      final results = learningResults(
        task: task,
        correct: false,
        fields: {"mood": true, "tense": true, "voice": true, "person": false},
      );

      expect(
        results[GrammarLearning.dimensionId("verb", "person", "3. Sg.")],
        isFalse,
      );
      expect(
        results[GrammarLearning.dimensionId(
          "verb",
          "tense",
          LatinTenses.present,
        )],
        isTrue,
      );
      expect(
        results[LatinGrammarTaskGenerator.topicCardId(
          LatinTrainerTopics.verbsPresent,
        )],
        isFalse,
      );
      expect(
        results[LatinGrammarTaskGenerator.wordCardId("verb", "amare")],
        isFalse,
      );
    });
  });

  group("Einstellungen", () {
    test("Speichern und Laden", () {
      const settings = LatinGrammarSettings(
        enabledTopics: [LatinTrainerTopics.syntax, LatinTrainerTopics.nouns3],
        enabledKinds: [LatinGrammarKinds.build],
        askLemma: true,
        requireMacrons: true,
        includeVocative: true,
        vocabularyOnly: true,
      );

      final restored = LatinGrammarSettings.fromMap(settings.toMap());

      // Reihenfolge der Themen folgt dem Lehrgang.
      expect(restored.enabledTopics, [
        LatinTrainerTopics.nouns3,
        LatinTrainerTopics.syntax,
      ]);
      expect(restored.enabledKinds, [LatinGrammarKinds.build]);
      expect(restored.askLemma, isTrue);
      expect(restored.requireMacrons, isTrue);
      expect(restored.includeVocative, isTrue);
      expect(restored.vocabularyOnly, isTrue);
    });

    test("unbekannte oder fehlende Werte fallen auf Defaults zurück", () {
      final restored = LatinGrammarSettings.fromMap({
        "enabledTopics": ["nouns_ao", "greek_aorist"],
        "askLemma": "ja",
      });

      expect(restored.enabledTopics, [LatinTrainerTopics.nounsAO]);
      expect(restored.enabledKinds, LatinGrammarKinds.all);
      expect(restored.askLemma, isFalse);

      expect(
        LatinGrammarSettings.fromMap(null).enabledTopics,
        LatinTrainerTopics.defaults,
      );
    });

    test("Prüfung der Auswahl", () {
      expect(
        const LatinGrammarSettings(enabledTopics: []).validate(),
        isNotNull,
      );
      expect(
        const LatinGrammarSettings(
          enabledTopics: [LatinTrainerTopics.nounsAO],
          enabledKinds: [],
        ).validate(),
        isNotNull,
      );
      expect(
        const LatinGrammarSettings(
          enabledTopics: [
            LatinTrainerTopics.nounsAO,
            LatinTrainerTopics.prepositions,
          ],
          enabledKinds: [],
        ).validate(),
        isNull,
      );
      expect(const LatinGrammarSettings().validate(), isNull);
    });
  });

  group("Speicher", () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test("Lernstand und Einstellungen werden lokal gespeichert", () async {
      final store = LatinGrammarStore.forUser(null);

      await store.record(LatinTrainerTopics.nounsAO, true, [
        LearningCard(id: "dim.noun.case.Ablativ", difficulty: 6),
      ]);
      await store.record(LatinTrainerTopics.nounsAO, false, const []);

      final progress = await store.load();

      expect(progress.topic(LatinTrainerTopics.nounsAO).correct, 1);
      expect(progress.topic(LatinTrainerTopics.nounsAO).wrong, 1);
      expect(progress.cards["dim.noun.case.Ablativ"]!.difficulty, 6);

      await store.saveSettings(
        const LatinGrammarSettings(enabledTopics: [LatinTrainerTopics.syntax]),
      );

      expect((await store.loadSettings()).enabledTopics, [
        LatinTrainerTopics.syntax,
      ]);
    });

    test("Zurücksetzen betrifft nur Latein-Grammatik", () async {
      final local = LocalLearningStore.instance;
      final store = LatinGrammarStore.forUser(null);

      await local.saveCard(
        LocalLearningStore.greekGrammar,
        LearningCard(id: "dim.noun.case.Dativ", difficulty: 8),
      );
      await store.record(LatinTrainerTopics.pronouns, true, [
        LearningCard(id: "dim.noun.case.Dativ", difficulty: 2),
      ]);
      await store.saveSettings(
        const LatinGrammarSettings(enabledTopics: [LatinTrainerTopics.syntax]),
      );

      await ProgressDataService().resetArea(null, ProgressArea.latinGrammar);

      final progress = await store.load();

      expect(progress.cards, isEmpty);
      expect(progress.topics, isEmpty);
      expect((await store.loadSettings()).enabledTopics, [
        LatinTrainerTopics.syntax,
      ]);
      expect(
        (await local.loadCards(
          LocalLearningStore.greekGrammar,
        ))["dim.noun.case.Dativ"]!.difficulty,
        8,
      );
    });

    test("Altgriechisch zurücksetzen lässt Latein stehen", () async {
      final store = LatinGrammarStore.forUser(null);

      await store.record(LatinTrainerTopics.nounsAO, true, const []);
      await ProgressDataService().resetArea(null, ProgressArea.greekGrammar);

      expect((await store.load()).topic(LatinTrainerTopics.nounsAO).correct, 1);
    });

    test("alle Lernstände zurücksetzen umfasst Latein-Grammatik", () async {
      final store = LatinGrammarStore.forUser(null);

      await store.record(LatinTrainerTopics.nounsAO, true, const []);
      await ProgressDataService().resetProgress(null);

      expect((await store.load()).topics, isEmpty);
    });

    test("Gastdaten werden erkannt und gelöscht", () async {
      final local = LocalLearningStore.instance;
      final store = LatinGrammarStore.forUser(null);

      expect(await local.hasGuestData(), isFalse);
      await store.record(LatinTrainerTopics.nounsAO, true, const []);
      expect(await local.hasGuestData(), isTrue);

      await local.clearGuestData();
      expect((await store.load()).topics, isEmpty);
    });

    test("Bereich ist beschrieben und getrennt von Altgriechisch", () {
      expect(ProgressArea.latinGrammar.collection, isNull);
      expect(ProgressArea.latinGrammar.documents, [
        LocalLearningStore.latinGrammar,
      ]);
      expect(
        ProgressArea.greekGrammar.collection,
        LocalLearningStore.greekGrammar,
      );
      expect(ProgressArea.latinGrammar.scopeDescription, contains("Latein"));
    });
  });
}
