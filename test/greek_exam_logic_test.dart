import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/exam/corpus_token.dart';
import 'package:theologie_lernapp/models/greek/exam/exam_config.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_exam.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_morph_analysis.dart';
import 'package:theologie_lernapp/models/greek/exam/passage_ref.dart';
import 'package:theologie_lernapp/models/greek/exam/text_corpus.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/services/greek/exam/corpus_codec.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_answer_check.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_store.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_task_types.dart';
import 'package:theologie_lernapp/services/greek/exam/grammar_phenomena.dart';
import 'package:theologie_lernapp/services/greek/exam/greek_form_key.dart';
import 'package:theologie_lernapp/services/greek/exam/passage_finder.dart';
import 'package:theologie_lernapp/services/greek/exam/phenomenon_detection.dart';
import 'package:theologie_lernapp/services/greek/exam/vocabulary_help.dart';

// -----------------------------------------------------------------------------
// HILFEN FÜR KÜNSTLICHE TEXTE
// -----------------------------------------------------------------------------

LemmaAnalysis la(String lemma, String code) =>
    LemmaAnalysis(lemma, GreekMorphAnalysis(code));

CorpusToken ctx(String surface, String lemma, String code, [List<LemmaAnalysis> more = const []]) =>
    CorpusToken(surface, [la(lemma, code), ...more], AnalysisReliability.contextual);

CorpusToken formal(String surface, List<LemmaAnalysis> analyses) =>
    CorpusToken(surface, analyses, AnalysisReliability.formal);

const CorpusToken unknown = CorpusToken(
  "ξξξ",
  [],
  AnalysisReliability.unanalyzed,
);

GreekVocabularyEntry vocab(
  int step,
  String lemma,
  List<String> translations, {
  String type = "noun",
}) => GreekVocabularyEntry(
  id: lemma.hashCode,
  step: step,
  type: type,
  lemma: lemma,
  translations: translations,
);

/// Index mit einem Kapitel; je Vers Wortzahl, Satzende, Phänomene.
CorpusIndex syntheticIndex(
  List<({int words, bool end, List<String> certain, List<String> possible, int unanalyzed})> verses, {
  String corpusId = "nt",
  String book = "JHN",
}) {
  final phenomena = [for (final p in GrammarPhenomena.detectable) p.id];

  PhenomenonSet set(List<String> ids) =>
      PhenomenonSet.of([for (final id in ids) phenomena.indexOf(id)]);

  return CorpusIndex(
    corpusId: corpusId,
    phenomena: phenomena,
    lemmas: const ["λόγος"],
    books: [
      BookInfo(book, [
        ChapterInfo(1, [
          for (final (i, v) in verses.indexed)
            VerseInfo(
              label: "${i + 1}",
              wordCount: v.words,
              paragraphStart: i == 0,
              endsSentence: v.end,
              certain: set(v.certain),
              possible: set([...v.certain, ...v.possible]),
              unanalyzed: v.unanalyzed,
              lemmaGroups: const [
                [0],
              ],
            ),
        ]),
      ]),
    ],
  );
}

({int words, bool end, List<String> certain, List<String> possible, int unanalyzed}) verse(
  int words, {
  bool end = true,
  List<String> certain = const [],
  List<String> possible = const [],
  int unanalyzed = 0,
}) => (
  words: words,
  end: end,
  certain: certain,
  possible: possible,
  unanalyzed: unanalyzed,
);

void main() {
  // ---------------------------------------------------------------------------
  group("Formschlüssel", () {
    test("Gravis, Großschreibung und Schluss-Sigma werden vereinheitlicht", () {
      expect(greekFormKey("Θεὸς,"), greekFormKey("θεός"));
      expect(greekFormKey("ΘΕΟΣ"), "θεος");
      expect(greekFormKey("ἘΝ"), "ἐν");
    });

    test("Akzente und Spiritus unterscheiden weiterhin Formen", () {
      expect(greekFormKey("ἡ"), isNot(greekFormKey("ἥ")));
      expect(greekFormKey("τίς"), isNot(greekFormKey("τις")));
    });

    test("Zweiter Akzent eines Enklitikons fällt weg", () {
      expect(greekFormKey("ἄνθρωπός"), greekFormKey("ἄνθρωπος"));
    });

    test("Längenzeichen und kombinierende Akzente aus Wörterbüchern", () {
      // ῡ + kombinierender Akut, wie in Wiktionary-Tabellen
      expect(greekFormKey("λῡ́ω"), greekFormKey("λύω"));
      expect(greekFormKey("λῡ́ουσῐν"), greekFormKey("λύουσιν"));
      expect(composeGreek("ἄ"), "ἄ");
    });

    test("Elision bleibt erhalten, textkritische Zeichen nicht", () {
      expect(greekFormKey("διʼ"), "δι’");
      expect(greekFormKey("⸀λόγος"), greekFormKey("λόγος"));
      expect(splitGreekWords("⸂ἐν ἀρχῇ⸃ – ἦν."), ["⸂ἐν", "ἀρχῇ⸃", "ἦν."]);
    });

    test("Satzende an Punkt, Hochpunkt und Fragezeichen", () {
      expect(endsGreekSentence("λόγος."), isTrue);
      expect(endsGreekSentence("ἀνθρώπων·"), isTrue);
      expect(endsGreekSentence("ποιεῖς;"), isTrue);
      expect(endsGreekSentence("λόγος,"), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group("Textidentität", () {
    test("ID wird gelesen und geschrieben", () {
      const ref = PassageRef(
        corpusId: "lxx",
        bookId: "1MA",
        chapter: 2,
        firstVerse: "22a",
        lastVerse: "25",
      );

      expect(ref.id, "lxx:1MA.2.22a-25");
      expect(PassageRef.tryParse(ref.id), ref);
      expect(PassageRef.tryParse("unsinn"), isNull);
    });

    test("Überschneidung nur im selben Kapitel und Versbereich", () {
      final a = PassageRef.tryParse("nt:JHN.1.1-5")!;

      expect(a.overlaps(PassageRef.tryParse("nt:JHN.1.5-9")!), isTrue);
      expect(a.overlaps(PassageRef.tryParse("nt:JHN.1.6-9")!), isFalse);
      expect(a.overlaps(PassageRef.tryParse("nt:JHN.2.1-5")!), isFalse);
      expect(a.overlaps(PassageRef.tryParse("lxx:JHN.1.1-5")!), isFalse);
      expect(PassageRef.compareVerses("22", "22a"), lessThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  group("Phänomenkatalog", () {
    test("IDs sind eindeutig, Kategorien und Voraussetzungen existieren", () {
      final ids = <String>{};

      for (final p in GrammarPhenomena.all) {
        expect(ids.add(p.id), isTrue, reason: "doppelte ID ${p.id}");
        expect(GrammarPhenomena.category(p.categoryId), isNotNull, reason: p.id);

        for (final implied in p.implies) {
          expect(GrammarPhenomena.byId(implied), isNotNull, reason: "${p.id} → $implied");
        }
      }
    });

    test("Status bestimmt die wählbaren Anforderungen", () {
      for (final p in GrammarPhenomena.all) {
        switch (p.status) {
          case PhenomenonStatus.reliable:
            expect(p.detector, isNotNull);
            expect(p.supports(PhenomenonRequirement.excluded), isTrue);
          case PhenomenonStatus.heuristic:
            expect(p.detector, isNotNull);
            expect(p.supports(PhenomenonRequirement.required), isTrue);
            expect(p.supports(PhenomenonRequirement.excluded), isFalse);
          case PhenomenonStatus.unavailable:
            expect(p.detector, isNull);
            expect(p.supports(PhenomenonRequirement.required), isFalse);
        }
      }
    });

    test("Gefordert sind die zentralen Graecum-Bereiche", () {
      for (final id in [
        "verb.mood.indicative",
        "verb.mood.imperative",
        "verb.mood.infinitive",
        "verb.mood.participle",
        "verb.tense.present",
        "verb.tense.aorist",
        "verb.tense.future",
        "verb.voice.passive",
        "participle.case.g",
        "syntax.aci",
        "syntax.genitive_absolute",
        "syntax.participium_coniunctum",
        "clause.relative",
        "clause.conditional",
        "negation.me",
        "preposition.genitive",
        "adjective.comparative",
      ]) {
        expect(GrammarPhenomena.byId(id), isNotNull, reason: id);
      }

      expect(
        GrammarPhenomena.byId("syntax.nci")!.status,
        PhenomenonStatus.unavailable,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group("Erkennung und Mehrdeutigkeit", () {
    final participle = GrammarPhenomena.byId("verb.mood.participle")!;

    test("Mehrdeutige Form: möglich, aber nicht sicher", () {
      final tokens = [
        formal("λύοντος", [la("λύω", "V--PAPGSM-")]),
        formal("ἄρα", [la("ἄρα", "X---------"), la("αἴρω", "V-2AAD-S--")]),
      ];

      final certain = DetectionView(tokens, DetectionMode.certain);
      final possible = DetectionView(tokens, DetectionMode.possible);
      final imperative = GrammarPhenomena.byId("verb.mood.imperative")!;

      expect(participle.detector!.detect(certain), [0]);
      expect(imperative.detector!.detect(certain), isEmpty);
      expect(imperative.detector!.detect(possible), [1]);
    });

    test("Unbestimmte Form gilt nie als sicher nicht vorhanden", () {
      final view = DetectionView([unknown], DetectionMode.certain);
      expect(view.holdsNot(0, (a) => a.analysis.isVerb), isFalse);
    });

    test("Im Kontext bestimmte Form zählt nur mit ihrer Kontextbestimmung", () {
      // ἦν: Kontext 3. Sg., formal auch 1. Sg.
      final token = ctx("ἦν", "εἰμί", "V-3IAI-S--", [la("εἰμί", "V-1IAI-S--")]);
      final first = GrammarPhenomena.byId("verb.person.first")!;

      expect(first.detector!.detect(DetectionView([token], DetectionMode.possible)), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group("Konfiguration", () {
    test("wird verlustfrei gespeichert und gelesen", () {
      final config = const ExamConfig(
        corpusIds: ["nt", "lxx"],
        bookIds: ["MRK"],
        chapterFrom: 2,
        chapterTo: 4,
        minWords: 40,
        maxWords: 90,
        maxHints: 12,
        excludeDone: false,
        knownSteps: [1, 2, 3],
        verbCount: 7,
        extraTaskTypes: ["noun_parsing", "find_forms"],
      )
          .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required)
          .withRequirement("verb.tense.future", PhenomenonRequirement.excluded);

      final read = ExamConfig.fromMap(config.toMap());

      expect(read.toMap(), config.toMap());
    });

    test("ungültige Werte fallen auf Zulässiges zurück", () {
      final read = ExamConfig.fromMap({
        "minWords": 200,
        "maxWords": 50,
        "requirements": {
          "gibt.es.nicht": "required",
          // heuristisch erkannt → nicht ausschließbar
          "syntax.aci": "excluded",
          "verb.tense.future": "excluded",
        },
        "knownSteps": [1, 99],
        "verbCount": 99,
      });

      expect(read.minWords, 50);
      expect(read.maxWords, 200);
      expect(read.requirements, {"verb.tense.future": PhenomenonRequirement.excluded});
      expect(read.knownSteps, [1]);
      expect(read.verbCount, ExamConfig.maxVerbCount);
    });
  });

  // ---------------------------------------------------------------------------
  group("Textsuche", () {
    final index = syntheticIndex([
      verse(30),
      verse(30, certain: ["syntax.genitive_absolute", "verb.mood.participle", "participle.case.g"]),
      verse(30, possible: ["verb.tense.future"]),
      verse(30, unanalyzed: 2),
      verse(30, end: false),
      verse(30),
    ]);

    PassageFinder finder(ExamConfig config, {Set<PassageRef> done = const {}}) =>
        PassageFinder(indexes: {"nt": index}, config: config, done: done);

    test("Abschnitte beginnen und enden an Satzgrenzen, Länge im Rahmen", () {
      final windows = finder(const ExamConfig(minWords: 50, maxWords: 70))
          .windows(minWords: 50, maxWords: 70)
          .map((c) => c.ref.id)
          .toList();

      // Vers 5 endet ohne Satzende: 4–5 ist kein Abschnitt, Vers 6 beginnt
      // mitten im Satz.
      expect(windows, ["nt:JHN.1.1-2", "nt:JHN.1.2-3", "nt:JHN.1.3-4", "nt:JHN.1.5-6"]);
    });

    test("Mindest- und Höchstwortzahl", () {
      final result = finder(const ExamConfig(minWords: 85, maxWords: 95)).search();
      expect(result.matches.map((c) => c.wordCount).toSet(), {90});
    });

    test("erforderlich verlangt einen sicheren Beleg", () {
      final config = const ExamConfig(minWords: 10, maxWords: 40)
          .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required);

      expect(finder(config).search().matches.map((c) => c.ref.id), ["nt:JHN.1.2-2"]);
    });

    test("ausgeschlossen verbietet auch mögliche Belege und unbestimmte Wörter", () {
      final config = const ExamConfig(minWords: 10, maxWords: 40)
          .withRequirement("verb.tense.future", PhenomenonRequirement.excluded);

      expect(
        finder(config).search().matches.map((c) => c.ref.id),
        // 3: Futur möglich, 4: unbestimmte Wörter
        ["nt:JHN.1.1-1", "nt:JHN.1.2-2"],
      );
    });

    test("bearbeitete Abschnitte und Überschneidungen werden ausgeschlossen", () {
      const config = ExamConfig(minWords: 10, maxWords: 40);
      final done = {PassageRef.tryParse("nt:JHN.1.3-4")!};

      final ids = finder(config, done: done).search().matches.map((c) => c.ref.id);
      expect(ids, ["nt:JHN.1.1-1", "nt:JHN.1.2-2"]);

      final allowed = finder(config.copyWith(excludeDone: false), done: done).search();
      expect(allowed.matches, hasLength(4));
    });

    test("konkrete Stelle wird nur verwendet, wenn sie die Kriterien erfüllt", () {
      final ok = finder(const ExamConfig(fixedPassage: "nt:JHN.1.2-2")
              .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required))
          .search();
      expect(ok.matches.single.ref.id, "nt:JHN.1.2-2");

      final failing = finder(const ExamConfig(fixedPassage: "nt:JHN.1.1-1")
              .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required))
          .search();
      expect(failing.matches, isEmpty);
      expect(
        failing.diagnosis!.failedForFixedPassage.single.kind,
        ConstraintKind.required,
      );
    });

    test("Höchstzahl der Vokabelhilfen richtet sich nach den Lernschritten", () {
      final matcher = VocabularyMatcher([vocab(3, "λόγος", ["Wort"])]);
      const config = ExamConfig(minWords: 10, maxWords: 40, maxHints: 0);

      PassageSearchResult search(List<int> steps) => PassageFinder(
        indexes: {"nt": index},
        config: config,
        knowledge: VocabularyKnowledge(matcher, steps),
      ).search();

      // λόγος bekannt: keine Hilfe nötig.
      expect(search([1, 2, 3]).matches, isNotEmpty);

      // λόγος unbekannt: jede Stelle braucht eine Hilfe.
      final unknownWords = search([1, 2]);
      expect(unknownWords.matches, isEmpty);
      expect(
        unknownWords.diagnosis!.suggestions.map((s) => s.constraint?.kind),
        contains(ConstraintKind.hints),
      );
    });

    test("Auswahl ist zufällig über alle Anfangsverse verteilt", () {
      final big = syntheticIndex([for (var i = 0; i < 40; i++) verse(20)]);
      final f = PassageFinder(
        indexes: {"nt": big},
        config: const ExamConfig(minWords: 20, maxWords: 60),
      );
      final matches = f.search().matches;
      final random = Random(7);

      final starts = <String>{
        for (var i = 0; i < 400; i++)
          PassageFinder.pick(matches, random)!.ref.firstVerse,
      };

      // Nicht immer der erste Abschnitt; nahezu alle Anfänge kommen vor.
      expect(starts.length, greaterThan(30));
    });

    test("bereits gezeigte Abschnitte werden gemieden, solange es andere gibt", () {
      final matches = finder(const ExamConfig(minWords: 10, maxWords: 40)).search().matches;
      final avoid = {for (final m in matches.skip(1)) m.ref};

      for (var seed = 0; seed < 20; seed++) {
        expect(
          PassageFinder.pick(matches, Random(seed), avoid: avoid)!.ref,
          matches.first.ref,
        );
      }

      expect(
        PassageFinder.pick(
          matches,
          Random(1),
          avoid: {for (final m in matches) m.ref},
        ),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group("Rückmeldung ohne Treffer", () {
    test("Widerspruch: gefordertes Phänomen setzt ausgeschlossenes voraus", () {
      final config = const ExamConfig()
          .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required)
          .withRequirement("verb.mood.participle", PhenomenonRequirement.excluded);

      final contradictions = PassageFinder.contradictionsOf(config);
      expect(contradictions, hasLength(1));
      expect(contradictions.single.message, contains("Partizip"));
    });

    test("Widerspruch: alle Tempora ausgeschlossen, Verbform gefordert", () {
      var config = const ExamConfig()
          .withRequirement("verb.mood.participle", PhenomenonRequirement.required);

      for (final p in GrammarPhenomena.inCategory("tense")) {
        config = config.withRequirement(p.id, PhenomenonRequirement.excluded);
      }

      expect(
        PassageFinder.contradictionsOf(config).map((c) => c.message),
        contains(contains("Tempus")),
      );
    });

    test("zu enge Filter: Hinweise aus den Daten", () {
      final index = syntheticIndex([
        verse(30, possible: ["verb.tense.future"]),
        verse(30),
      ]);

      final config = const ExamConfig(minWords: 50, maxWords: 70)
          .withRequirement("verb.tense.future", PhenomenonRequirement.excluded);

      final finder = PassageFinder(indexes: {"nt": index}, config: config);
      final result = finder.search();

      expect(result.matches, isEmpty);
      expect(result.diagnosis!.contradictions, isEmpty);

      final messages = result.diagnosis!.suggestions.map((s) => s.message).join("\n");
      // Futur verhindert 1–2; ohne Mindestlänge passt Vers 2 allein.
      expect(messages, contains("Futur"));
      expect(messages, contains("Mindestlänge verringern"));
      expect(result.diagnosis!.longestOtherwiseMatching, 30);
    });

    test("erforderliches Phänomen, das nirgends belegt ist", () {
      final index = syntheticIndex([verse(30), verse(30)]);
      final config = const ExamConfig(minWords: 20, maxWords: 70)
          .withRequirement("verb.mood.optative", PhenomenonRequirement.required);

      final result = PassageFinder(indexes: {"nt": index}, config: config).search();
      expect(result.diagnosis!.neverRequired, ["verb.mood.optative"]);
    });
  });

  // ---------------------------------------------------------------------------
  group("Vokabelschritte und Vokabelhilfen", () {
    final entries = [
      vocab(1, "λόγος", ["Wort", "Rede"]),
      vocab(2, "γίγνομαι", ["werden", "entstehen"], type: "verb"),
      vocab(3, "ἄρχω", ["herrschen"], type: "verb"),
      vocab(3, "ἄρχομαι", ["anfangen"], type: "verb"),
      vocab(4, "οὐ / οὐκ / οὐχ", ["nicht"], type: "particle"),
      vocab(5, "ἀμφί + Gen.", ["um … herum"], type: "preposition"),
      vocab(6, "οὐ μόνον … ἀλλὰ καί", ["nicht nur … sondern auch"], type: "phrase"),
      vocab(8, "θάλαττα", ["Meer"]),
    ];
    final matcher = VocabularyMatcher(entries);

    test("Einträge mit Alternativen und Zusätzen werden zerlegt", () {
      expect(VocabularyMatcher.lemmaKeysOf("οὐ / οὐκ / οὐχ"), containsAll(["οὐ", "οὐκ", "οὐχ"]));
      expect(VocabularyMatcher.lemmaKeysOf("ἀμφί + Gen."), contains("ἀμφί"));
      expect(VocabularyMatcher.lemmaKeysOf("οὐ μόνον … ἀλλὰ καί"), isEmpty);
    });

    test("attische und Koine-Schreibung werden zugeordnet", () {
      expect(matcher.entriesFor("γίνομαι").single.lemma, "γίγνομαι");
      expect(matcher.entriesFor("θάλασσα").single.lemma, "θάλαττα");
    });

    test("mediale Form findet den Eintrag auf -ομαι zuerst", () {
      final middle = la("ἄρχω", "V-3AMI-S--");
      final active = la("ἄρχω", "V-3PAI-S--");

      expect(matcher.entriesFor("ἄρχω", middle).first.lemma, "ἄρχομαι");
      expect(matcher.entriesFor("ἄρχω", active).map((e) => e.lemma), ["ἄρχω"]);
    });

    test("bekannt ist nur, was zu den gewählten Schritten gehört", () {
      final knowledge = VocabularyKnowledge(matcher, [1]);

      expect(knowledge.isKnown("λόγος"), isTrue);
      expect(knowledge.isKnown("γίνομαι"), isFalse);
      expect(knowledge.knowsToken(unknown), isFalse);
    });

    test("Hilfen: Übersetzung aus späterem Schritt, Wörterbuch, Mehrdeutigkeit", () {
      final knowledge = VocabularyKnowledge(matcher, [1]);
      final lexicon = GreekLexicon({
        "κόσμος": const LexiconEntry(german: ["Ordnung", "Welt"]),
        "σκότος": const LexiconEntry(english: ["darkness"]),
      });

      final hints = VocabularyHelpBuilder(knowledge, lexicon).build([
        ctx("λόγος", "λόγος", "N-----NSM-"),
        ctx("ἐγένετο", "γίνομαι", "V-3AMI-S--"),
        ctx("κόσμου", "κόσμος", "N-----GSM-"),
        ctx("κόσμῳ", "κόσμος", "N-----DSM-"),
        ctx("σκότος", "σκότος", "N-----NSN-"),
        formal("ἄρα", [la("ἄρα", "X---------"), la("αἴρω", "V-2AAD-S--")]),
        ctx("Ἰωάννης", "Ἰωάννης", "N-----NSM-"),
        unknown,
      ]);

      expect(hints, hasLength(6));

      // λόγος ist bekannt (Schritt 1) und erhält keine Hilfe.
      expect(hints[0].lemmas.single.headword, "γίγνομαι");
      expect(hints[0].lemmas.single.meanings, ["werden", "entstehen"]);
      expect(hints[0].lemmas.single.step, 2);

      expect(hints[1].forms, ["κόσμου", "κόσμῳ"]);
      expect(hints[1].lemmas.single.source, MeaningSource.wiktionaryGerman);

      expect(hints[2].lemmas.single.source, MeaningSource.wiktionaryEnglish);

      expect(hints[3].ambiguous, isTrue);
      expect(hints[3].lemmas.map((l) => l.lemma), ["ἄρα", "αἴρω"]);

      expect(hints[4].lemmas.single.properName, isTrue);
      expect(hints[5].unanalyzed, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group("Verbbestimmung", () {
    // ἔλεγον: 1. Sg. und 3. Pl. Imperfekt (formal), im Kontext 3. Pl.
    final item = ParsingItem(
      tokenIndex: 0,
      token: ctx("ἔλεγον", "λέγω", "V-3IAI-P--", [la("λέγω", "V-1IAI-S--")]),
      context: la("λέγω", "V-3IAI-P--"),
      accepted: [la("λέγω", "V-3IAI-P--"), la("λέγω", "V-1IAI-S--")],
    );

    ParsingAnswer answer(String personNumber, {String lemma = "λεγω"}) => ParsingAnswer(
      lemma: lemma,
      mood: "Indikativ",
      tense: "Imperfekt",
      voice: "Aktiv",
      personNumber: personNumber,
    );

    test("jede formal mögliche Bestimmung gilt als richtig", () {
      final context = ExamAnswerCheck.checkVerb(item, answer("3. Pl."));
      expect(context.correct, isTrue);
      expect(context.onlyFormallyPossible, isFalse);

      final formalOnly = ExamAnswerCheck.checkVerb(item, answer("1. Sg."));
      expect(formalOnly.correct, isTrue);
      expect(formalOnly.onlyFormallyPossible, isTrue);
      expect(formalOnly.alsoPossible.single.analysis.code, "V-3IAI-P--");
    });

    test("falsche Bestimmung bleibt falsch, Einzelwertung je Feld", () {
      final result = ExamAnswerCheck.checkVerb(item, answer("2. Sg."));

      expect(result.correct, isFalse);
      expect(result.fields[ParsingField.personNumber], isFalse);
      expect(result.fields[ParsingField.tense], isTrue);
    });

    test("falsche Grundform macht die Antwort falsch", () {
      expect(ExamAnswerCheck.checkVerb(item, answer("3. Pl.", lemma: "λύω")).correct, isFalse);
    });

    test("Medium und Passiv sind im Präsens formgleich", () {
      final present = ParsingItem(
        tokenIndex: 0,
        token: ctx("λύεται", "λύω", "V-3PPI-S--"),
        context: la("λύω", "V-3PPI-S--"),
        accepted: [la("λύω", "V-3PPI-S--")],
      );

      for (final voice in ["Medium", "Passiv"]) {
        expect(
          ExamAnswerCheck.checkVerb(
            present,
            ParsingAnswer(
              lemma: "λύω",
              mood: "Indikativ",
              tense: "Präsens",
              voice: voice,
              personNumber: "3. Sg.",
            ),
          ).correct,
          isTrue,
        );
      }
    });

    test("Partizip: Kasus, Numerus, Genus statt Person", () {
      final participle = ParsingItem(
        tokenIndex: 0,
        token: ctx("λύσαντος", "λύω", "V--AAPGSM-", [la("λύω", "V--AAPGSN-")]),
        context: la("λύω", "V--AAPGSM-"),
        accepted: [la("λύω", "V--AAPGSM-"), la("λύω", "V--AAPGSN-")],
      );

      final result = ExamAnswerCheck.checkVerb(
        participle,
        const ParsingAnswer(
          lemma: "λύω",
          mood: "Partizip",
          tense: "Aorist",
          voice: "Aktiv",
          grammaticalCase: "Genitiv",
          number: "Sg.",
          gender: "n",
        ),
      );

      expect(result.correct, isTrue);
      expect(result.fields.keys, isNot(contains(ParsingField.personNumber)));
    });
  });

  // ---------------------------------------------------------------------------
  group("Aufgaben und Austausch", () {
    final passage = ExamPassage(
      ref: PassageRef.tryParse("nt:JHN.1.1-1")!,
      corpus: const TextCorpus(
        id: "nt",
        name: "NT",
        shortName: "NT",
        edition: "",
        bibleTranslation: null,
        analysis: CorpusAnalysisKind.contextual,
        analysisNote: "",
        text: CorpusSource(name: "", license: ""),
        sources: [],
        books: ["JHN"],
        analyzedShare: 1,
      ),
      verses: [
        CorpusVerse("1", "", [
          ctx("ἔλεγεν", "λέγω", "V-3IAI-S--"),
          ctx("ὁ", "ὁ", "RA----NSM-"),
          ctx("λόγος", "λόγος", "N-----NSM-"),
          ctx("ἐποίησεν", "ποιέω", "V-3AAI-S--"),
          ctx("λύσας", "λύω", "V--AAPNSM-"),
          ctx("ἄρτον", "ἄρτος", "N-----ASM-"),
        ]),
      ],
    );

    const detection = DetectionContext();

    test("Verbformen kommen aus dem Text; Austausch wählt andere", () {
      final task = ExamTaskTypes.verbParsing.create(
        ExamTaskContext(passage: passage, detection: detection, count: 2),
        Random(1),
      ) as VerbParsingTask;

      final first = {for (final i in task.items) i.tokenIndex};
      expect(first, hasLength(2));
      expect(first.every({0, 3, 4}.contains), isTrue);

      final next = ExamTaskTypes.verbParsing.create(
        ExamTaskContext(passage: passage, detection: detection, count: 2),
        Random(1),
        previous: task,
      ) as VerbParsingTask;

      expect(next.items.map((i) => i.tokenIndex), contains(isNot(isIn(first))));
    });

    test("ohne weitere Verben gibt es keinen Austausch", () {
      final all = VerbParsingTask([
        for (final i in [0, 3, 4])
          ParsingItem(
            tokenIndex: i,
            token: passage.tokens[i],
            context: passage.tokens[i].contextual,
            accepted: [passage.tokens[i].contextual!],
          ),
      ]);

      expect(
        ExamTaskTypes.verbParsing.create(
          ExamTaskContext(passage: passage, detection: detection),
          Random(1),
          previous: all,
        ),
        isNull,
      );
    });

    test("Formen finden: Ziel sind die sicheren Belege", () {
      final task = const FindFormsTaskType().create(
        ExamTaskContext(passage: passage, detection: detection),
        Random(3),
      ) as FindFormsTask;

      final phenomenon = GrammarPhenomena.byId(task.phenomenonId)!;
      expect(phenomenon.status, PhenomenonStatus.reliable);
      expect(task.targets, isNotEmpty);

      final result = ExamAnswerCheck.checkFindForms(task, {...task.targets, 1});
      expect(result.missed, isEmpty);
      expect(result.wrong, {1});
    });

    test("Nominalformen: nur Nomen, Adjektive und Pronomen", () {
      final task = const NounParsingTaskType().create(
        ExamTaskContext(passage: passage, detection: detection),
        Random(1),
      ) as NounParsingTask;

      expect(task.items.map((i) => i.tokenIndex).toSet(), {2, 5});
    });
  });

  // ---------------------------------------------------------------------------
  group("Speicher (Gast)", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Konfiguration bleibt erhalten", () async {
      final store = LocalExamStore();
      final config = const ExamConfig(minWords: 33, corpusIds: ["lxx"])
          .withRequirement("clause.relative", PhenomenonRequirement.required);

      await store.saveConfig(config);

      expect((await LocalExamStore().loadConfig()).toMap(), config.toMap());
    });

    test("bearbeitet nur nach Markierung, Entfernen möglich", () async {
      final store = LocalExamStore();
      final ref = PassageRef.tryParse("nt:MRK.4.1-9")!;

      expect(await store.loadDone(), isEmpty);

      await store.markDone(ref);
      expect((await LocalExamStore().loadDone()).keys, [ref]);

      await store.unmarkDone(ref);
      expect(await store.loadDone(), isEmpty);
    });

    test("ungültige gespeicherte Daten werden übergangen", () {
      expect(
        ExamStore.parseDone({"nt:JHN.1.1-5": 1000, "kaputt": 5, "nt:JHN.2.1-3": "x"}).keys
            .map((r) => r.id),
        ["nt:JHN.1.1-5"],
      );
    });
  });
}
