import 'dart:convert';
import 'dart:io';
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

List<dynamic> _vocabulary() =>
    jsonDecode(File("assets/latin_vocabulary.json").readAsStringSync());

/// Lektion je Vokabel-ID, wie sie der Trainer aus der Vokabelliste liest.
final Map<int, int> _lessonOf = {
  for (final entry in _vocabulary()) entry["id"] as int: entry["lesson"] as int,
};

LatinGrammarTaskGenerator _generator({
  int seed = 1,
  GrammarLearning? learning,
}) {
  return LatinGrammarTaskGenerator(
    learning: learning ?? GrammarLearning(random: Random(seed)),
    random: Random(seed),
    lessonOf: _lessonOf,
  );
}

LatinGrammarSettings _only(
  String topic, {
  List<int> disabledLessons = const [],
}) {
  return LatinGrammarSettings(
    enabledTopics: [topic],
    disabledLessons: disabledLessons,
  );
}

/// Lektion eines Worts im Trainer.
int? _lessonOfWord(LatinGrammarTask task) {
  final vocabularyId = switch (task) {
    NominalIdentifyTask(wordType: NominalWordType.noun) =>
      LatinGrammarWords.nouns
          .firstWhere((n) => n.id == task.wordId)
          .vocabularyId,
    NominalIdentifyTask(wordType: NominalWordType.adjective) =>
      LatinGrammarWords.adjectives
          .firstWhere((a) => a.id == task.wordId)
          .vocabularyId,
    NominalIdentifyTask() => null,
    VerbIdentifyTask() => task.verb.vocabularyId,
    ChoiceTask() =>
      LatinGrammarWords.prepositions
          .where((p) => p.lemma == task.prompt)
          .firstOrNull
          ?.vocabularyId,
  };

  return vocabularyId == null ? null : _lessonOf[vocabularyId];
}

LatinVerb _verb(String id) =>
    LatinGrammarWords.verbs.firstWhere((verb) => verb.id == id);

void main() {
  group("Aufgaben erzeugen", () {
    test("jedes Thema liefert stimmige Aufgaben", () {
      final generator = _generator();

      // Die u- und e-Deklination kommt im Wortschatz noch nicht vor.
      final topics = LatinTrainerTopics.ids.where(
        (t) => t != LatinTrainerTopics.nounsUE,
      );

      for (final topic in topics) {
        for (var i = 0; i < 150; i++) {
          final task = generator.next(_only(topic));

          expect(task, isNotNull, reason: topic);
          expect(task!.topic, topic);

          switch (task) {
            case NominalIdentifyTask():
              expect(task.analyses, contains(task.target), reason: task.form);
              expect(task.lemmas, isNotEmpty);
            case VerbIdentifyTask():
              expect(task.analyses, contains(task.target), reason: task.form);
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

    test("es gibt nur Bestimmungs- und Auswahlaufgaben", () {
      final generator = _generator(seed: 3);
      final settings = LatinGrammarSettings(
        enabledTopics: LatinTrainerTopics.ids,
      );

      for (var i = 0; i < 300; i++) {
        expect(
          generator.next(settings),
          anyOf(
            isA<NominalIdentifyTask>(),
            isA<VerbIdentifyTask>(),
            isA<ChoiceTask>(),
          ),
        );
      }
    });

    test("ohne Vokativ-Einstellung wird kein Vokativ gefragt", () {
      final generator = _generator(seed: 5);

      for (var i = 0; i < 300; i++) {
        final task = generator.next(_only(LatinTrainerTopics.nounsAO));

        final target = switch (task) {
          NominalIdentifyTask() => task.target,
          _ => null,
        };

        expect(target?.grammaticalCase, isNot(LatinCases.vocative));
      }
    });

    test("nur Wörter der ausgewählten Lektionen", () {
      final generator = _generator(seed: 7);

      // Nur Lektion 4 und 8.
      final settings = LatinGrammarSettings(
        enabledTopics: LatinTrainerTopics.ids,
        disabledLessons: [
          for (var lesson = 1; lesson <= 13; lesson++)
            if (lesson != 4 && lesson != 8) lesson,
        ],
      );

      final seen = <int>{};

      for (var i = 0; i < 500; i++) {
        final task = generator.next(settings)!;
        final lesson = _lessonOfWord(task);

        if (task.topic == LatinTrainerTopics.pronouns ||
            task.topic == LatinTrainerTopics.syntax) {
          // Pronomen und Satzkonstruktionen gehören zu keiner Lektion.
          continue;
        }

        expect(lesson, isNotNull, reason: "${task.topic} ohne Lektion");
        expect([4, 8], contains(lesson), reason: task.topic);
        seen.add(lesson!);
      }

      expect(seen, {4, 8});
    });

    test("Musterwörter ohne Vokabel werden nicht abgefragt", () {
      final generator = _generator(seed: 9);
      final settings = LatinGrammarSettings(
        enabledTopics: LatinTrainerTopics.ids,
      );

      for (var i = 0; i < 500; i++) {
        final task = generator.next(settings)!;

        if (task.topic == LatinTrainerTopics.pronouns ||
            task.topic == LatinTrainerTopics.syntax) {
          continue;
        }

        expect(_lessonOfWord(task), isNotNull, reason: task.topic);
      }
    });

    test("Vokabel-IDs der Grammatikwörter passen zur Vokabelliste", () {
      final lemmaOf = {
        for (final entry in _vocabulary())
          entry["id"] as int: "${entry["lemma"]}|${entry["type"]}",
      };

      for (final noun in LatinGrammarWords.nouns) {
        if (noun.vocabularyId == null) continue;
        expect(lemmaOf[noun.vocabularyId], "${noun.lemma}|noun");
      }

      for (final adjective in LatinGrammarWords.adjectives) {
        if (adjective.vocabularyId == null) continue;
        expect(lemmaOf[adjective.vocabularyId], "${adjective.lemma}|adjective");
      }

      for (final verb in LatinGrammarWords.verbs) {
        if (verb.vocabularyId == null) continue;
        // velle ist im Wortschatz der Lektion 3 als volō verzeichnet.
        expect(
          lemmaOf[verb.vocabularyId],
          anyOf("${verb.infinitive}|verb", "${verb.present}|verb"),
        );
      }

      for (final preposition in LatinGrammarWords.prepositions) {
        if (preposition.vocabularyId == null) continue;
        expect(
          lemmaOf[preposition.vocabularyId],
          "${preposition.lemma}|preposition",
        );
      }
    });

    test("Themen ohne passende Wörter sind nicht verfügbar", () {
      final generator = _generator();

      // Adjektive kommen erst ab Lektion 10 vor.
      expect(
        generator.availableTopics(
          _only(
            LatinTrainerTopics.adjectives,
            disabledLessons: [10, 11, 12, 13],
          ),
        ),
        isEmpty,
      );
      expect(generator.availableTopics(_only(LatinTrainerTopics.adjectives)), [
        LatinTrainerTopics.adjectives,
      ]);

      // Ohne Lektionsangabe (z. B. Vokabelliste nicht geladen) bleiben nur
      // Pronomen und Satzkonstruktionen.
      final withoutLessons = LatinGrammarTaskGenerator(
        learning: GrammarLearning(random: Random(1)),
        random: Random(1),
      );

      expect(
        withoutLessons.availableTopics(
          LatinGrammarSettings(enabledTopics: LatinTrainerTopics.ids),
        ),
        [LatinTrainerTopics.pronouns, LatinTrainerTopics.syntax],
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
            generator.next(_only(LatinTrainerTopics.nounsAO))
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
    test("mehrdeutige Formen: jede vollständige Bestimmung zählt", () {
      final generator = _generator(seed: 2);
      NominalIdentifyTask? task;

      for (var i = 0; i < 2000 && task == null; i++) {
        final next = generator.next(_only(LatinTrainerTopics.nounsAO));

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
        disabledLessons: [5, 2],
        askLemma: true,
        includeVocative: true,
      );

      final restored = LatinGrammarSettings.fromMap(settings.toMap());

      // Reihenfolge der Themen folgt dem Lehrgang.
      expect(restored.enabledTopics, [
        LatinTrainerTopics.nouns3,
        LatinTrainerTopics.syntax,
      ]);
      expect(restored.disabledLessons, [2, 5]);
      expect(restored.askLemma, isTrue);
      expect(restored.includeVocative, isTrue);
    });

    test("unbekannte oder fehlende Werte fallen auf Defaults zurück", () {
      final restored = LatinGrammarSettings.fromMap({
        "enabledTopics": ["nouns_ao", "greek_aorist"],
        "askLemma": "ja",
      });

      expect(restored.enabledTopics, [LatinTrainerTopics.nounsAO]);
      expect(restored.disabledLessons, isEmpty);
      expect(restored.askLemma, isFalse);

      expect(
        LatinGrammarSettings.fromMap(null).enabledTopics,
        LatinTrainerTopics.defaults,
      );
    });

    test("Prüfung der Auswahl", () {
      const lessons = [1, 2, 3];

      expect(
        const LatinGrammarSettings(enabledTopics: []).validate(lessons),
        isNotNull,
      );
      expect(
        const LatinGrammarSettings(disabledLessons: lessons).validate(lessons),
        isNotNull,
      );
      expect(
        const LatinGrammarSettings(disabledLessons: [1, 2]).validate(lessons),
        isNull,
      );
      expect(const LatinGrammarSettings().validate(lessons), isNull);
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
