import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/greek/exam/corpus_token.dart';
import 'package:theologie_lernapp/models/greek/exam/exam_config.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_exam.dart';
import 'package:theologie_lernapp/models/greek/exam/passage_ref.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/services/greek/exam/corpus_codec.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_corpus_source.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_generator.dart';
import 'package:theologie_lernapp/services/greek/exam/grammar_phenomena.dart';
import 'package:theologie_lernapp/services/greek/exam/greek_form_key.dart';
import 'package:theologie_lernapp/services/greek/exam/phenomenon_detection.dart';
import 'package:theologie_lernapp/services/greek/exam/vocabulary_help.dart';

import 'test_asset_bundle.dart';

/// Prüft die ausgelieferten Korpora (assets/greek_corpus) und die
/// Generierung mit echten Texten aus beiden Testamenten.
void main() {
  final source = AssetExamCorpusSource(bundle: FileAssetBundle());

  final vocabulary = [
    for (final e in jsonDecode(
      File("assets/greek_vocabulary.json").readAsStringSync(),
    ) as List)
      GreekVocabularyEntry.fromJson(e as Map<String, dynamic>),
  ];

  late DetectionContext detection;

  setUpAll(() async {
    final lexicon = await source.loadLexicon();
    detection = DetectionContext(declensionOf: (l) => lexicon[l]?.declension);
  });

  Future<CorpusVerse> verseOf(String corpus, String book, int chapter, String label) async {
    final b = await source.loadBook(corpus, book);
    return b.chapters[chapter - 1].firstWhere((v) => v.label == label);
  }

  Future<List<String>> hits(String phenomenon, CorpusVerse verse) async {
    final detector = GrammarPhenomena.byId(phenomenon)!.detector!;
    return [
      for (final i in detector.detect(
        DetectionView(verse.tokens, DetectionMode.certain, context: detection),
      ))
        verse.tokens[i].word,
    ];
  }

  // ---------------------------------------------------------------------------
  group("Korpora", () {
    test("Verzeichnis nennt NT und LXX mit Herkunft und Lizenz", () async {
      final corpora = await source.loadCorpora();

      expect(corpora.map((c) => c.id), ["nt", "lxx"]);

      for (final corpus in corpora) {
        expect(corpus.text.license, isNotEmpty);
        expect(corpus.sources, isNotEmpty);
        expect(corpus.books, isNotEmpty);

        final index = await source.loadIndex(corpus.id);
        expect(index.books.map((b) => b.id), corpus.books);

        for (final book in corpus.books) {
          expect(
            File("assets/greek_corpus/${corpus.id}/$book.json").existsSync(),
            isTrue,
            reason: "${corpus.id}/$book",
          );
        }
      }

      expect(corpora.first.books, contains("JHN"));
      expect(corpora.last.books, containsAll(["GEN", "PSA", "ISA"]));
    });

    test("Index erfasst genau die erkennbaren Phänomene (sonst neu erzeugen)", () async {
      for (final id in ["nt", "lxx"]) {
        final index = await source.loadIndex(id);
        expect(
          index.phenomena,
          [for (final p in GrammarPhenomena.detectable) p.id],
          reason:
              "assets/greek_corpus/$id/index.json ist veraltet: "
              "dart run tool/greek_exam_corpus/build_corpus.dart",
        );
      }
    });

    // Der Index muss zu den Regeln passen; nach Änderungen an Regeln oder
    // Phänomenen den Import erneut ausführen.
    for (final (corpus, book) in [("nt", "JHN"), ("nt", "PHM"), ("lxx", "RUT")]) {
      test("Index von $corpus/$book entspricht den aktuellen Regeln", () async {
        final index = await source.loadIndex(corpus);
        final text = await source.loadBook(corpus, book);
        final info = index.book(book)!;

        for (final (c, chapter) in text.chapters.indexed) {
          final verses = info.chapters[c].verses;
          expect(verses.length, chapter.length);

          for (final (v, verse) in chapter.indexed) {
            final entry = verses[v];
            final certain = <int>[];
            final possible = <int>[];

            for (final (bit, p) in GrammarPhenomena.detectable.indexed) {
              if (p.detector!
                  .detect(DetectionView(verse.tokens, DetectionMode.certain, context: detection))
                  .isNotEmpty) {
                certain.add(bit);
              }
              if (p.detector!
                  .detect(DetectionView(verse.tokens, DetectionMode.possible, context: detection))
                  .isNotEmpty) {
                possible.add(bit);
              }
            }

            final where = "$corpus $book ${c + 1},${verse.label}";
            expect(entry.label, verse.label, reason: where);
            expect(entry.wordCount, verse.tokens.length, reason: where);
            expect(entry.certain, PhenomenonSet.of(certain), reason: where);
            expect(entry.possible, PhenomenonSet.of(possible), reason: where);
            expect(
              entry.unanalyzed,
              verse.tokens
                  .where((t) => t.reliability == AnalysisReliability.unanalyzed)
                  .length,
              reason: where,
            );
          }
        }
      });
    }

    test("NT: Wortlaut ohne textkritische Zeichen, jede Form im Kontext bestimmt", () async {
      final verse = await verseOf("nt", "JHN", 1, "1");

      expect(verse.text, "Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν, καὶ θεὸς ἦν ὁ λόγος.");
      expect(verse.tokens.every((t) => t.reliability == AnalysisReliability.contextual), isTrue);
      expect(verse.tokens[2].contextual!.analysis.code, "V-3IAI-S--");
      // ἦν ist formal auch 1. Sg.
      expect(verse.tokens[2].analyses.map((a) => a.analysis.code), contains("V-1IAI-S--"));

      final mt = await verseOf("nt", "MAT", 1, "18");
      expect(mt.text, isNot(contains("⸀")));
    });

    test("LXX: formale Bestimmung mit erhaltener Mehrdeutigkeit", () async {
      final verse = await verseOf("lxx", "GEN", 1, "1");

      final created = verse.tokens.firstWhere((t) => t.word == "ἐποίησεν");
      expect(created.reliability, AnalysisReliability.formal);
      expect(created.certainLemma, "ποιέω");
      expect(created.readings.single.analysis.code, "V-3AAI-S--");

      final light = (await verseOf("lxx", "GEN", 1, "3")).tokens
          .firstWhere((t) => greekFormKey(t.word) == greekFormKey("φῶς"));
      expect(light.readings.length, greaterThan(1));
      expect(light.certainLemma, "φῶς");
    });
  });

  // ---------------------------------------------------------------------------
  group("Konstruktionen in echten Texten", () {
    test("Genitivus absolutus", () async {
      expect(await hits("syntax.genitive_absolute", await verseOf("nt", "MAT", 2, "1")),
          containsAll(["γεννηθέντος", "Ἰησοῦ"]));
      expect(await hits("syntax.genitive_absolute", await verseOf("nt", "MAT", 1, "18")),
          contains("μνηστευθείσης"));
      // Objekt von ἀκούω, kein Genitivus absolutus
      expect(await hits("syntax.genitive_absolute", await verseOf("nt", "JHN", 1, "37")), isEmpty);
      // Attribut nach Präposition: διὰ Ἰερεμίου τοῦ προφήτου λέγοντος
      expect(await hits("syntax.genitive_absolute", await verseOf("nt", "MAT", 2, "17")), isEmpty);
    });

    test("AcI", () async {
      expect(await hits("syntax.aci", await verseOf("nt", "MAT", 14, "28")),
          containsAll(["με", "ἐλθεῖν"]));
      // Objekt hinter dem Infinitiv zählt nicht: ἦλθον καταλῦσαι τὸν νόμον
      expect(await hits("syntax.aci", await verseOf("nt", "MAT", 5, "17")), isEmpty);
    });

    test("Prohibitiv und verstärkte Verneinung", () async {
      final verse = await verseOf("nt", "LUK", 6, "37");

      expect(await hits("mood.prohibitive", verse), isEmpty);
      expect(await hits("mood.emphatic_negation", verse), isNotEmpty);
      expect(
        await hits("mood.prohibitive", await verseOf("nt", "MAT", 1, "20")),
        containsAll(["μὴ", "φοβηθῇς"]),
      );
    });

    test("Tempus und Modus aus der Bestimmung", () async {
      final john = await verseOf("nt", "JHN", 1, "1");
      expect(await hits("verb.tense.imperfect", john), ["ἦν", "ἦν", "ἦν"]);
      expect(await hits("verb.mood.participle", john), isEmpty);

      final genesis = await verseOf("lxx", "GEN", 1, "1");
      expect(await hits("verb.tense.aorist", genesis), ["ἐποίησεν"]);
    });
  });

  // ---------------------------------------------------------------------------
  group("Generierung mit echten Texten", () {
    ExamGenerator generator([int seed = 1]) =>
        ExamGenerator(source: source, random: Random(seed));

    test("NT: geforderter Genitivus absolutus ist im Text belegt", () async {
      final config = const ExamConfig(minWords: 40, maxWords: 120)
          .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required);

      final outcome = await generator().generate(
        config: config,
        done: const {},
        vocabulary: vocabulary,
      );

      final exam = (outcome as ExamCreated).exam;
      final evidence = exam.selection.required.single;

      expect(evidence.phenomenonId, "syntax.genitive_absolute");
      expect(evidence.tokens, isNotEmpty);
      expect(exam.passage.wordCount, inInclusiveRange(40, 120));
      expect(exam.selection.matchCount, greaterThan(100));

      final verbs = exam.verbs as VerbParsingTask;
      expect(verbs.items, hasLength(config.verbCount));
      for (final item in verbs.items) {
        expect(item.token.contextual!.analysis.isVerb, isTrue);
        expect(exam.passage.tokens[item.tokenIndex], same(item.token));
      }
    });

    test("Vokabelhilfen nur für Wörter außerhalb der gewählten Schritte", () async {
      final config = const ExamConfig(minWords: 40, maxWords: 80, knownSteps: [1, 2, 3]);
      final exam = ((await generator(3).generate(
        config: config,
        done: const {},
        vocabulary: vocabulary,
      )) as ExamCreated).exam;

      final knowledge = VocabularyKnowledge(VocabularyMatcher(vocabulary), [1, 2, 3]);

      for (final hint in exam.translation.hints) {
        for (final lemma in hint.lemmas) {
          expect(knowledge.isKnown(lemma.lemma), isFalse, reason: lemma.lemma);
        }
      }

      final hinted = {
        for (final hint in exam.translation.hints) ...hint.forms,
      };

      for (final token in exam.passage.tokens) {
        if (!knowledge.knowsToken(token)) {
          expect(hinted, contains(token.word), reason: token.word);
        }
      }
    });

    test("LXX: Klausur aus der Septuaginta", () async {
      final config = const ExamConfig(corpusIds: ["lxx"], minWords: 40, maxWords: 100);
      final exam = ((await generator(5).generate(
        config: config,
        done: const {},
        vocabulary: vocabulary,
      )) as ExamCreated).exam;

      expect(exam.passage.ref.corpusId, "lxx");
      expect(exam.passage.corpus.shortName, "LXX");
      expect(exam.translation.hints, isNotEmpty);
    });

    test("bearbeitete Texte werden ausgeschlossen, Austausch ändert sie nicht", () async {
      final gen = generator(9);
      final config = const ExamConfig(bookIds: ["PHM"], minWords: 40, maxWords: 120);

      final first = ((await gen.generate(
        config: config,
        done: const {},
        vocabulary: vocabulary,
      )) as ExamCreated).exam;

      final done = {first.passage.ref};

      for (var i = 0; i < 10; i++) {
        final outcome = await generator(i).generate(
          config: config,
          done: done,
          vocabulary: vocabulary,
        );

        if (outcome case ExamCreated(:final exam)) {
          expect(exam.passage.ref.overlaps(first.passage.ref), isFalse);
        }
      }

      final again = await generator(1).generate(
        config: config.copyWith(excludeDone: false),
        done: done,
        vocabulary: vocabulary,
      );
      expect(again, isA<ExamCreated>());
    });

    test("Austausch einzelner Aufgaben lässt die übrigen unverändert", () async {
      final gen = generator(11);
      final exam = ((await gen.generate(
        config: const ExamConfig(minWords: 80, maxWords: 150),
        done: const {},
        vocabulary: vocabulary,
      )) as ExamCreated).exam;

      final verbs = (await gen.replaceVerbs(exam))!;
      expect(verbs.passage, same(exam.passage));
      expect(verbs.translation, same(exam.translation));
      expect(verbs.extra, same(exam.extra));
      expect(verbs.verbs, isNot(same(exam.verbs)));

      final third = (await gen.replaceExtraTask(exam, 0))!;
      expect(third.verbs, same(exam.verbs));
      expect(third.extra[1], same(exam.extra[1]));
      expect(third.extra[0], isNot(same(exam.extra[0])));

      final switched = (await gen.replaceExtraTask(exam, 1, typeId: "find_forms"))!;
      expect(switched.extra[1].typeId, "find_forms");
      expect(switched.extra[0], same(exam.extra[0]));

      final text = await gen.replaceText(
        exam,
        done: const {},
        vocabulary: vocabulary,
      );
      final replaced = (text as ExamCreated).exam;
      expect(replaced.passage.ref, isNot(exam.passage.ref));
      expect(replaced.config.toMap(), exam.config.toMap());
      expect(replaced.extra.map((t) => t.typeId), exam.extra.map((t) => t.typeId));
    });

    test("ohne Alternative meldet der Textaustausch das", () async {
      final gen = generator(2);
      const fixed = "nt:JHN.11.35-35";
      final exam = ((await gen.generate(
        config: const ExamConfig(fixedPassage: fixed),
        done: const {},
        vocabulary: vocabulary,
      )) as ExamCreated).exam;

      expect(exam.passage.ref.id, fixed);
      expect(exam.selection.fixed, isTrue);

      // Nur ein einziger passender Abschnitt: Joh 11,35 als ganzes Buch-
      // kapitel-Filter mit genau dieser Länge.
      final narrow = exam.config.copyWith(
        fixedPassage: () => null,
        bookIds: ["JHN"],
        chapterFrom: () => 11,
        chapterTo: () => 11,
        minWords: 3,
        maxWords: 3,
      );
      final only = await gen.generate(config: narrow, done: const {}, vocabulary: vocabulary);
      final onlyExam = (only as ExamCreated).exam;

      final outcome = await gen.replaceText(onlyExam, done: const {}, vocabulary: vocabulary);
      expect(outcome, isA<ExamNotPossible>());
      expect((outcome as ExamNotPossible).noAlternative, isTrue);
    });

    test("nur Futur bei 100 Wörtern: begründete Absage aus den Daten", () async {
      var config = const ExamConfig(minWords: 100, maxWords: 120);

      for (final p in GrammarPhenomena.inCategory("tense")) {
        if (p.id != "verb.tense.future") {
          config = config.withRequirement(p.id, PhenomenonRequirement.excluded);
        }
      }

      final outcome = await generator().generate(
        config: config,
        done: const {},
        vocabulary: vocabulary,
      );

      final diagnosis = (outcome as ExamNotPossible).diagnosis;
      expect(diagnosis.contradictions, isEmpty);
      expect(diagnosis.suggestions, isNotEmpty);
      expect(
        diagnosis.suggestions.map((s) => s.message).join(" "),
        anyOf(contains("Präsens"), contains("Aorist"), contains("Mindestlänge")),
      );
      expect(outcome.unrestrictedMatches, isNotNull);
    });

    test("Beispiel: 100 Wörter, nur Präsens und Aorist, Genitivus absolutus", () async {
      var config = const ExamConfig(minWords: 90, maxWords: 110)
          .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required);

      for (final p in GrammarPhenomena.inCategory("tense")) {
        if (p.id != "verb.tense.present" && p.id != "verb.tense.aorist") {
          config = config.withRequirement(p.id, PhenomenonRequirement.excluded);
        }
      }

      final outcome = await generator().generate(
        config: config.copyWith(corpusIds: ["nt", "lxx"]),
        done: const {},
        vocabulary: vocabulary,
      );

      switch (outcome) {
        case ExamCreated(:final exam):
          for (final token in exam.passage.tokens) {
            for (final reading in token.readings) {
              if (reading.analysis.isVerb) {
                expect("PA", contains(reading.analysis.tense), reason: token.word);
              }
            }
          }
          expect(exam.passage.tokens.every((t) => t.isAnalyzed), isTrue);
        case ExamNotPossible(:final diagnosis):
          expect(diagnosis.suggestions, isNotEmpty);
      }
    });

    test("konkrete Stelle außerhalb des Textes wird gemeldet", () async {
      final outcome = await generator().generate(
        config: const ExamConfig(fixedPassage: "nt:JHN.99.1-3"),
        done: const {},
        vocabulary: vocabulary,
      );

      expect(
        (outcome as ExamNotPossible).diagnosis.suggestions.single.message,
        contains("gibt es"),
      );
    });

    test("PassageRef der gespeicherten Markierung bleibt lesbar", () {
      expect(PassageRef.tryParse("lxx:PSA.22.1-6")!.verseLabel, "22,1–6");
    });
  });
}
