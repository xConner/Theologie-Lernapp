import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/greek/exam/corpus_token.dart';
import 'package:theologie_lernapp/models/greek/exam/exam_config.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_exam.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_morph_analysis.dart';
import 'package:theologie_lernapp/models/greek/exam/passage_ref.dart';
import 'package:theologie_lernapp/models/greek/exam/text_corpus.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/screens/greek/exam/exam_task_widgets.dart';
import 'package:theologie_lernapp/services/greek/exam/assumed_vocabulary.dart';
import 'package:theologie_lernapp/services/greek/exam/corpus_codec.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_corpus_source.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_generator.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_task_types.dart';
import 'package:theologie_lernapp/services/greek/exam/gloss_shortener.dart';
import 'package:theologie_lernapp/services/greek/exam/grammar_phenomena.dart';
import 'package:theologie_lernapp/services/greek/exam/passage_finder.dart';
import 'package:theologie_lernapp/services/greek/exam/phenomenon_detection.dart';
import 'package:theologie_lernapp/services/greek/exam/vocabulary_help.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

/// Überarbeitung des Klausurerstellers: Filter nach Lernstufen statt nach
/// einzelnen Personen/Kasus, vorausgesetzte Funktionswörter und Eigennamen,
/// deutsche und kurze Vokabelhilfen, Aufgaben 3/4 nach den Kursklausuren.

LemmaAnalysis la(String lemma, String code) =>
    LemmaAnalysis(lemma, GreekMorphAnalysis(code));

CorpusToken ctx(String surface, String lemma, String code) =>
    CorpusToken(surface, [la(lemma, code)], AnalysisReliability.contextual);

CorpusToken formal(String surface, List<LemmaAnalysis> analyses) =>
    CorpusToken(surface, analyses, AnalysisReliability.formal);

CorpusToken guess(String surface) => CorpusToken(surface, [
  la(surface, CorpusCodec.properNameCode),
], AnalysisReliability.properNameGuess);

GreekVocabularyEntry vocab(int step, String lemma, List<String> translations) =>
    GreekVocabularyEntry(
      id: lemma.hashCode,
      step: step,
      type: "noun",
      lemma: lemma,
      translations: translations,
    );

const TextCorpus corpus = TextCorpus(
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
);

ExamPassage passageOf(List<CorpusToken> tokens) => ExamPassage(
  ref: PassageRef.tryParse("nt:JHN.1.1-1")!,
  corpus: corpus,
  verses: [CorpusVerse("1", "", tokens)],
);

void main() {
  final source = AssetExamCorpusSource(bundle: FileAssetBundle());

  final vocabulary = [
    for (final e in jsonDecode(
      File("assets/greek_vocabulary.json").readAsStringSync(),
    ) as List)
      GreekVocabularyEntry.fromJson(e as Map<String, dynamic>),
  ];

  // ---------------------------------------------------------------------------
  group("Filter bilden Lernstufen ab", () {
    test("keine Filter für einzelne Personen, Numeri, Kasus oder Genera", () {
      for (final id in GrammarPhenomena.retiredFilters) {
        expect(GrammarPhenomena.byId(id), isNull, reason: id);
      }

      expect(GrammarPhenomena.category("person"), isNull);
      expect(GrammarPhenomena.category("participle"), isNull);

      // Auch kein verbliebener Filter greift nur über eine dieser
      // Dimensionen zu.
      for (final p in GrammarPhenomena.all) {
        final detector = p.detector;
        if (detector is! MorphDetector) continue;

        final pattern = detector.pattern;
        expect(pattern.person, isNull, reason: p.id);
        expect(pattern.grammaticalCase, isNull, reason: p.id);
        expect(pattern.number, isNull, reason: p.id);
        expect(pattern.gender, isNull, reason: p.id);
      }
    });

    test("Modus, Tempus, Genus Verbi und Konstruktionen bleiben wählbar", () {
      for (final id in [
        "verb.mood.indicative",
        "verb.mood.imperative",
        "verb.mood.infinitive",
        "verb.mood.participle",
        "verb.tense.present",
        "verb.tense.imperfect",
        "verb.tense.aorist",
        "verb.tense.perfect",
        "verb.tense.future",
        "verb.voice.active",
        "verb.voice.middle",
        "verb.voice.passive",
        "verb.aorist.strong",
        "noun.declension.third",
        "pronoun.relative",
        "syntax.genitive_absolute",
        "syntax.aci",
      ]) {
        expect(GrammarPhenomena.byId(id), isNotNull, reason: id);
      }
    });

    test("alte Einstellungen: entfallene Filter fallen weg, der Rest bleibt", () {
      final stored = {
        "corpusIds": ["nt"],
        "bookIds": ["MRK"],
        "minWords": 40,
        "maxWords": 90,
        "knownSteps": [1, 2],
        "verbCount": 7,
        "extraTaskTypes": ["noun_parsing", "find_forms"],
        "requirements": {
          "verb.person.first": "excluded",
          "verb.number.plural": "excluded",
          "participle.case.g": "required",
          "participle.gender.f": "excluded",
          "case.vocative": "excluded",
          "pronoun.article": "excluded",
          "negation.me": "required",
          "preposition.dative": "required",
          "verb.tense.future": "excluded",
          "syntax.genitive_absolute": "required",
        },
      };

      final config = ExamConfig.fromMap(stored);

      expect(config.requirements, {
        "verb.tense.future": PhenomenonRequirement.excluded,
        "syntax.genitive_absolute": PhenomenonRequirement.required,
      });
      expect(config.bookIds, ["MRK"]);
      expect(config.minWords, 40);
      expect(config.maxWords, 90);
      expect(config.knownSteps, [1, 2]);
      expect(config.verbCount, 7);
      // Fassung 1 kannte nur zwei Aufgabenarten: neue Standardformate.
      expect(config.extraTaskTypes, ExamConfig.defaultExtraTasks);

      // Die neue Fassung behält eine ausdrückliche Wahl.
      final chosen = config.copyWith(extraTaskTypes: ["noun_parsing", "find_forms"]);
      expect(ExamConfig.fromMap(chosen.toMap()).extraTaskTypes, [
        "noun_parsing",
        "find_forms",
      ]);
      expect(chosen.toMap()["version"], ExamConfig.formatVersion);
    });

    test("ein entfallener Ausschluss schränkt die Textsuche nicht mehr ein", () async {
      final index = await source.loadIndex("nt");

      int matches(ExamConfig config) => PassageFinder(
        indexes: {"nt": index},
        config: config,
      ).search().matches.length;

      final plain = const ExamConfig(bookIds: ["PHM"], minWords: 20, maxWords: 60);
      final migrated = ExamConfig.fromMap({
        ...plain.toMap(),
        "version": 1,
        "requirements": {
          "verb.person.second": "excluded",
          "participle.case.d": "excluded",
          "pronoun.article": "excluded",
        },
      });

      expect(matches(plain), greaterThan(0));
      expect(matches(migrated), matches(plain));
    });
  });

  // ---------------------------------------------------------------------------
  group("Alle Formen innerhalb des gewählten Stoffs", () {
    const detection = DetectionContext();

    test("Verbformen: jede Person und jeder Numerus kommt in Frage", () {
      final forms = {
        "λύω": "V-1PAI-S--",
        "λύεις": "V-2PAI-S--",
        "λύει": "V-3PAI-S--",
        "λύομεν": "V-1PAI-P--",
        "λύετε": "V-2PAI-P--",
        "λύουσιν": "V-3PAI-P--",
      };

      final passage = passageOf([
        for (final MapEntry(key: form, value: code) in forms.entries)
          ctx(form, "λύω", code),
      ]);

      expect(VerbParsingTaskType.candidates(passage), [0, 1, 2, 3, 4, 5]);

      final task = ExamTaskTypes.verbParsing.create(
        ExamTaskContext(passage: passage, detection: detection, count: 6),
        Random(1),
      ) as VerbParsingTask;

      expect(
        {
          for (final item in task.items)
            "${item.context!.analysis.person}${item.context!.analysis.number}",
        },
        {"1S", "2S", "3S", "1P", "2P", "3P"},
      );
    });

    test("Nominalformen: jeder Kasus, Numerus und jedes Genus kommt in Frage", () {
      final passage = passageOf([
        ctx("λόγος", "λόγος", "N-----NSM-"),
        ctx("ἀρχῆς", "ἀρχή", "N-----GSF-"),
        ctx("ἔργῳ", "ἔργον", "N-----DSN-"),
        ctx("λόγους", "λόγος", "N-----APM-"),
        ctx("ἀγαθαί", "ἀγαθός", "A-----NPF-"),
        ctx("ἔργων", "ἔργον", "N-----GPN-"),
      ]);

      expect(NounParsingTaskType.candidates(passage), [0, 1, 2, 3, 4, 5]);
    });

    test("NT: Im Markusevangelium kommen alle Dimensionen als Aufgabe vor", () async {
      final corpora = await source.loadCorpora();
      final book = await source.loadBook("nt", "MRK");

      final persons = <String>{};
      final cases = <String>{};
      final numbers = <String>{};
      final genders = <String>{};
      final nominalCases = <String>{};
      final nominalGenders = <String>{};

      for (final chapter in book.chapters.take(4)) {
        final passage = ExamPassage(
          ref: PassageRef.tryParse("nt:MRK.1.1-1")!,
          corpus: corpora.first,
          verses: chapter,
        );

        for (final i in VerbParsingTaskType.candidates(passage)) {
          final a = passage.tokens[i].contextual!.analysis;
          if (a.isFinite) persons.add("${a.person}${a.number}");
          if (a.isParticiple) {
            cases.add(a.grammaticalCase);
            numbers.add(a.number);
            genders.add(a.gender);
          }
        }

        for (final i in NounParsingTaskType.candidates(passage)) {
          final a = passage.tokens[i].contextual!.analysis;
          nominalCases.add(a.grammaticalCase);
          nominalGenders.add(a.gender);
        }
      }

      expect(persons, {"1S", "2S", "3S", "1P", "2P", "3P"});
      expect(cases, containsAll(["N", "G", "D", "A"]));
      expect(numbers, {"S", "P"});
      expect(genders, {"M", "F", "N"});
      expect(nominalCases, containsAll(["N", "G", "D", "A"]));
      expect(nominalGenders, containsAll(["M", "F", "N"]));
    });
  });

  // ---------------------------------------------------------------------------
  group("Vorausgesetzte Wörter", () {
    final empty = VocabularyMatcher(const []);

    List<VocabularyHint> hintsFor(
      List<CorpusToken> tokens, {
      VocabularyMatcher? matcher,
      List<int> steps = const [],
      GreekLexicon? lexicon,
    }) => VocabularyHelpBuilder(
      VocabularyKnowledge(matcher ?? empty, steps),
      lexicon ?? GreekLexicon.empty,
    ).build(tokens);

    test("Artikel, Pronomen und Grundpartikeln erhalten keine Hilfe", () {
      // Auch ohne jeden Eintrag in der Vokabelliste.
      final hints = hintsFor([
        ctx("τοῦ", "ὁ", "RA----GSM-"),
        ctx("ταῖς", "ὁ", "RA----DPF-"),
        ctx("ἡμῶν", "ἐγώ", "RP----GP--"),
        ctx("αὐτῷ", "αὐτός", "RP----DSM-"),
        ctx("ταύτης", "οὗτος", "RD----GSF-"),
        ctx("ἅ", "ὅς", "RR----APN-"),
        ctx("ἑαυτόν", "ἑαυτοῦ", "RP----ASM-"),
        ctx("ἀλλήλους", "ἀλλήλων", "RP----APM-"),
        ctx("τινες", "τις", "RI----NPM-"),
        ctx("καὶ", "καί", "C---------"),
        ctx("οὐκ", "οὐ", "D---------"),
      ]);

      expect(hints, isEmpty);
    });

    test("ein Pronomen der Vokabelliste folgt seinem Lernschritt", () {
      final matcher = VocabularyMatcher([vocab(4, "ἐκεῖνος", ["jener"])]);
      final tokens = [
        ctx("ἐκείνου", "ἐκεῖνος", "RD----GSM-"),
        ctx("ὁ", "ὁ", "RA----NSM-"),
      ];

      // Schritt 4 noch nicht gelernt: Hilfe aus der Vokabelliste.
      final early = hintsFor(tokens, matcher: matcher, steps: [1, 2]);
      expect(early.single.lemmas.single.meanings, ["jener"]);
      expect(early.single.lemmas.single.source, MeaningSource.vocabulary);

      expect(hintsFor(tokens, matcher: matcher, steps: [1, 2, 3, 4]), isEmpty);
    });

    test("gängige biblische Eigennamen erhalten keine Hilfe", () {
      final hints = hintsFor([
        ctx("Ἰησοῦς", "Ἰησοῦς", "N-----NSM-"),
        ctx("Μαρίας", "Μαρία", "N-----GSF-"),
        ctx("Ἰωσὴφ", "Ἰωσήφ", "N-----NSM-"),
        ctx("Πέτρον", "Πέτρος", "N-----ASM-"),
        ctx("Παῦλος", "Παῦλος", "N-----NSM-"),
        ctx("Δαυὶδ", "Δαυίδ", "N-----GSM-"),
        ctx("Ἀβραάμ", "Ἀβραάμ", "N-----NSM-"),
        ctx("Ἰερουσαλήμ", "Ἰερουσαλήμ", "N-----ASF-"),
        // Septuaginta: unbestimmte Form eines Namens der Liste.
        guess("Μωυσῆν"),
        guess("Ἰσραήλ"),
      ]);

      expect(hints, isEmpty);
    });

    test("seltene Eigennamen werden weiterhin erklärt", () {
      final hints = hintsFor([
        ctx("Ἐπαφρόδιτον", "Ἐπαφρόδιτος", "N-----ASM-"),
        guess("Ζοροβαβελ"),
      ]);

      expect(hints, hasLength(2));
      expect(hints[0].lemmas.single.properName, isTrue);
      expect(VocabularyHintList.meaningText(hints[0].lemmas.single), "Eigenname");
      expect(hints[1].properNameGuess, isTrue);
    });

    test("die Schreibweise allein macht kein Wort zum bekannten Namen", () {
      // Großgeschriebenes Adjektiv, großgeschriebenes Nomen am Satzanfang,
      // gewöhnliches Nomen, das wie ein Name aussieht.
      expect(BiblicalNames.containsLemma("Ἰουδαϊκός"), isFalse);
      expect(BiblicalNames.containsLemma("πέτρα"), isFalse);
      expect(BiblicalNames.containsForm("Πέτρα"), isFalse);
      expect(BiblicalNames.containsForm("Πέτρου"), isTrue);

      final hints = hintsFor([
        ctx("Ἰουδαϊκοῖς", "Ἰουδαϊκός", "A-----DPM-"),
        ctx("Πέτρα", "πέτρα", "N-----NSF-"),
      ]);

      expect(hints, hasLength(2));
      // Kein Nomen: kein „Eigenname“, sondern ungelöst.
      expect(hints[0].lemmas.single.properName, isFalse);
      expect(hints[0].unresolved, isTrue);
      expect(hints[1].lemmas.single.lemma, "πέτρα");
    });

    test("Schwierigkeitsgrenze zählt vorausgesetzte Wörter nicht mit", () {
      final knowledge = VocabularyKnowledge(empty, const []);

      for (final lemma in ["ὁ", "αὐτός", "ὅς", "Ἰησοῦς", "Μωϋσῆς"]) {
        expect(knowledge.isKnown(lemma), isTrue, reason: lemma);
      }

      expect(knowledge.isKnown("θυσία"), isFalse);
      expect(knowledge.isKnown("Ἐπαφρόδιτος"), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group("Deutsche, kurze Vokabelhilfen", () {
    final knowledge = VocabularyKnowledge(VocabularyMatcher(vocabulary), const []);

    test("Übersetzung aus der Vokabelliste, höchstens drei Bedeutungen", () {
      final entry = vocabulary.firstWhere((e) => e.lemma == "ἀρχή");

      final hint = VocabularyHelpBuilder(knowledge, GreekLexicon.empty).build([
        ctx("ἀρχῇ", "ἀρχή", "N-----DSF-"),
      ]).single.lemmas.single;

      expect(hint.source, MeaningSource.vocabulary);
      expect(hint.step, entry.step);
      expect(hint.headword, "ἀρχή, ἀρχῆς, ἡ");
      expect(hint.meanings, isNotEmpty);
      expect(hint.meanings.length, lessThanOrEqualTo(maxGlossesPerHint));
      expect(entry.translations, containsAll(hint.meanings));
    });

    test("Kürzung: Klammern, Erklärungen und seltene Bedeutungen entfallen", () {
      expect(shortGlosses(["finden, entdecken (auch übertragen); antreffen; erfinden"]), [
        "finden",
        "entdecken",
        "antreffen",
      ]);
      expect(shortGlosses(["nehmen", "nehmen", "Nehmen"]), ["nehmen"]);
      expect(shortGlosses(["ab-, weg-, zurückwenden"]), ["zurückwenden"]);
      expect(shortGlosses(["übertragen: Anfang"]), ["Anfang"]);

      // Eine Erklärung in Satzlänge weicht den kurzen Bedeutungen …
      expect(
        shortGlosses([
          "die Vereinigung Einzelner zu einer Gemeinde, einem Staate",
          "Volksstamm, Klasse",
        ]),
        ["Volksstamm", "Klasse"],
      );

      // … bleibt aber, wenn es sonst nichts gibt.
      expect(
        shortGlosses(["die Kardinalzahl zwischen sechs und acht, heilige Zahl"]),
        ["die Kardinalzahl zwischen sechs und acht, heilige Zahl"],
      );
    });

    test("ohne deutsche Quelle bleibt die Grundform ungelöst", () {
      // Ein Eintrag früherer Fassungen mit englischer Bedeutung.
      final lexicon = GreekLexicon.fromJson({
        "entries": {
          "σκότος": {
            "en": ["darkness"],
            "decl": 3,
          },
          "θυσία": {
            "de": ["Opfer"],
            "src": "e",
          },
        },
      });

      expect(lexicon["σκότος"]!.german, isEmpty);
      expect(lexicon["σκότος"]!.source, MeaningSource.none);
      expect(lexicon["σκότος"]!.declension, 3);

      final hints = VocabularyHelpBuilder(
        VocabularyKnowledge(VocabularyMatcher(const []), const []),
        lexicon,
      ).build([
        ctx("σκότος", "σκότος", "N-----NSN-"),
        ctx("θυσίαν", "θυσία", "N-----ASF-"),
      ]);

      expect(hints[0].unresolved, isTrue);
      expect(hints[0].lemmas.single.meanings, isEmpty);
      expect(hints[1].lemmas.single.meanings, ["Opfer"]);
      expect(hints[1].lemmas.single.headword, "θυσία, ἡ");
      expect(hints[1].lemmas.single.source, MeaningSource.editorial);
    });

    testWidgets("die Anzeige nennt keine englische Ersatzangabe", (tester) async {
      final lexicon = GreekLexicon.fromJson({
        "entries": {
          "σκότος": {
            "en": ["darkness"],
          },
          "θυσία": {
            "de": ["Opfer"],
            "src": "p",
          },
        },
      });

      final hints = VocabularyHelpBuilder(
        VocabularyKnowledge(VocabularyMatcher(const []), const []),
        lexicon,
      ).build([
        ctx("σκότος", "σκότος", "N-----NSN-"),
        ctx("θυσίαν", "θυσία", "N-----ASF-"),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: VocabularyHintList(hints: hints)),
        ),
      );

      expect(find.textContaining("darkness", findRichText: true), findsNothing);
      expect(
        find.textContaining(VocabularyHintList.unresolvedText, findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining("θυσία, ἡ – Opfer", findRichText: true), findsOneWidget);
    });

    test("das ausgelieferte Lexikon ist deutsch, kurz und nennt seine Quelle", () {
      final raw = File("assets/greek_corpus/lexicon.json").readAsStringSync();
      final entries = (jsonDecode(raw) as Map)["entries"] as Map<String, dynamic>;

      expect(raw.contains('"en"'), isFalse);

      var german = 0;

      for (final MapEntry(key: lemma, value: entry) in entries.entries) {
        final glosses = (entry["de"] as List?)?.cast<String>();
        if (glosses == null) continue;

        german++;
        expect(glosses, isNotEmpty, reason: lemma);
        expect(glosses.length, lessThanOrEqualTo(maxGlossesPerHint), reason: lemma);
        expect(LexiconEntry.sourceCodes, contains(entry["src"]), reason: lemma);

        for (final gloss in glosses) {
          expect(gloss.trim(), isNotEmpty, reason: lemma);
          expect(
            gloss.length,
            lessThanOrEqualTo(maxExplanationLength),
            reason: "$lemma: $gloss",
          );
        }
      }

      expect(german, greaterThan(1000));

      // Stichproben: Bedeutung des biblischen Griechisch, kein Englisch.
      expect(entries["δόξα"]["de"], contains("Herrlichkeit"));
      expect(entries["θυσία"]["de"], contains("Opfer"));
      expect(entries["ἀποκρίνομαι"]["de"], ["antworten"]);
    });

    test("mehrdeutige Form: jede Grundform mit ihrer eigenen Bedeutung", () {
      final lexicon = GreekLexicon({
        "ἄρα": const LexiconEntry(german: ["also"], source: MeaningSource.pape),
        "αἴρω": const LexiconEntry(
          german: ["aufheben", "tragen"],
          source: MeaningSource.editorial,
        ),
        "ἀρά": const LexiconEntry(german: ["Fluch"], source: MeaningSource.pape),
      });

      final builder = VocabularyHelpBuilder(
        VocabularyKnowledge(VocabularyMatcher(const []), const []),
        lexicon,
      );

      final hints = builder.build([
        formal("ἄρα", [la("ἄρα", "X---------"), la("αἴρω", "V-2AAD-S--")]),
        // Dieselben Grundformen noch einmal: keine zweite Hilfe.
        formal("ἆρα", [la("ἄρα", "X---------"), la("αἴρω", "V-2AAD-S--")]),
        // Im Kontext eindeutig: nur diese Grundform.
        ctx("ἀράν", "ἀρά", "N-----ASF-"),
        ctx("ἀρᾶς", "ἀρά", "N-----GSF-"),
      ]);

      expect(hints, hasLength(2));
      expect(hints[0].ambiguous, isTrue);
      expect(hints[0].forms, ["ἄρα", "ἆρα"]);
      expect(
        {for (final l in hints[0].lemmas) l.lemma: l.meanings},
        {
          "ἄρα": ["also"],
          "αἴρω": ["aufheben", "tragen"],
        },
      );

      // Akzent unterscheidet die Grundformen (ἄρα ≠ ἀρά).
      expect(hints[1].lemmas.single.meanings, ["Fluch"]);
      expect(hints[1].forms, ["ἀράν", "ἀρᾶς"]);

      // Ist eine der möglichen Grundformen bekannt, gibt es keine Hilfe.
      final known = VocabularyHelpBuilder(
        VocabularyKnowledge(VocabularyMatcher([vocab(1, "ἄρα", ["also"])]), [1]),
        lexicon,
      ).build([
        formal("ἄρα", [la("ἄρα", "X---------"), la("αἴρω", "V-2AAD-S--")]),
      ]);

      expect(known, isEmpty);
    });

    test("NT-Klausuren: nur nötige, kurze, deutsche Hilfen ohne Doppelungen", () async {
      for (final seed in [1, 2, 3, 4, 5]) {
        final exam = ((await ExamGenerator(
          source: source,
          random: Random(seed),
        ).generate(
          config: const ExamConfig(minWords: 60, maxWords: 110),
          done: const {},
          vocabulary: vocabulary,
        )) as ExamCreated).exam;

        final lemmas = <String>[];

        for (final hint in exam.translation.hints) {
          for (final lemma in hint.lemmas) {
            lemmas.add(lemma.lemma);

            expect(ElementaryWords.contains(lemma.lemma), isFalse, reason: lemma.lemma);
            expect(BiblicalNames.containsLemma(lemma.lemma), isFalse, reason: lemma.lemma);
            expect(lemma.meanings.length, lessThanOrEqualTo(maxGlossesPerHint));
            expect(lemma.source, isNot(MeaningSource.vocabulary), reason: lemma.lemma);
          }
        }

        expect(lemmas.toSet(), hasLength(lemmas.length), reason: "doppelte Hilfe");

        // Keine Hilfe für Artikel und Pronomen des Textes.
        for (final token in exam.passage.tokens) {
          final pos = token.contextual!.analysis.pos;
          if (pos == "RA" || pos == "RP" || pos == "RD" || pos == "RR") {
            expect(lemmas, isNot(contains(token.contextual!.lemma)), reason: token.word);
          }
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  group("Aufgaben 3 und 4 nach den Kursklausuren", () {
    late DetectionContext detection;
    late TextCorpus nt;

    setUpAll(() async {
      final lexicon = await source.loadLexicon();
      detection = DetectionContext(declensionOf: (l) => lexicon[l]?.declension);
      nt = (await source.loadCorpora()).firstWhere((c) => c.id == "nt");
    });

    Future<ExamPassage> verses(String book, int chapter, List<String> labels) async {
      final loaded = await source.loadBook("nt", book);

      return ExamPassage(
        ref: PassageRef.tryParse("nt:$book.$chapter.${labels.first}-${labels.last}")!,
        corpus: nt,
        verses: [
          for (final verse in loaded.chapters[chapter - 1])
            if (labels.contains(verse.label)) verse,
        ],
      );
    }

    List<String> words(ExamPassage passage, Iterable<int> indices) => [
      for (final i in indices) passage.tokens[i].word,
    ];

    test("Standard sind die Formate der Klausuren; alle Arten sind wählbar", () {
      expect(const ExamConfig().extraTaskTypes, [
        "construction_marking",
        "construction_naming",
      ]);

      for (final type in ExamTaskTypes.extra) {
        expect(ExamTaskTypes.byId(type.id), same(type));
      }

      expect(ExamTaskTypes.extra.map((t) => t.id), containsAll(["find_forms", "noun_parsing"]));
    });

    test("Genitivus absolutus markieren: gefragt ist das Partizip", () async {
      // Mt 9,33: καὶ ἐκβληθέντος τοῦ δαιμονίου ἐλάλησεν ὁ κωφός.
      final passage = await verses("MAT", 9, ["33"]);
      final context = ExamTaskContext(passage: passage, detection: detection);

      FindFormsTask? task;
      for (var seed = 0; seed < 40 && task == null; seed++) {
        final created = const ConstructionMarkingTaskType().create(
          context,
          Random(seed),
        ) as FindFormsTask;

        if (created.phenomenonId == "syntax.genitive_absolute") task = created;
      }

      expect(task, isNotNull);
      expect(task!.typeId, "construction_marking");
      expect(task.instruction, contains("Genitivus absolutus"));
      expect(words(passage, task.targets), ["ἐκβληθέντος"]);
      expect(words(passage, task.tolerated), contains("δαιμονίου"));
    });

    test("Konstruktion benennen: Genitivus absolutus und PC", () async {
      // Mt 9,32–33: Αὐτῶν δὲ ἐξερχομένων … ἐκβληθέντος τοῦ δαιμονίου.
      final passage = await verses("MAT", 9, ["32", "33"]);

      final task = const ConstructionNamingTaskType().create(
        ExamTaskContext(passage: passage, detection: detection),
        Random(1),
      ) as ChoiceTask;

      final answers = {
        for (final item in task.items)
          passage.tokens[item.tokenIndex].word: item.answer,
      };

      expect(answers["ἐκβληθέντος"], "Genitivus absolutus");
      expect(answers["ἐξερχομένων"], "Genitivus absolutus");

      for (final item in task.items) {
        expect(item.options, contains(item.answer));
        expect(item.options, ExamConstruction.names);
      }
    });

    test("AcI hat Vorrang vor dem bloßen Ergänzungsinfinitiv", () async {
      // Lk 24,26: οὐχὶ ταῦτα ἔδει παθεῖν τὸν χριστὸν …; Mk 8,31: δεῖ τὸν
      // υἱὸν τοῦ ἀνθρώπου πολλὰ παθεῖν.
      final passage = await verses("MRK", 8, ["31"]);

      // Der Vers hat mehr Infinitive als Fragen: mehrere Ziehungen.
      final answers = <String, String>{
        for (var seed = 0; seed < 8; seed++)
          for (final item
              in (const ConstructionNamingTaskType().create(
                        ExamTaskContext(passage: passage, detection: detection),
                        Random(seed),
                      )
                      as ChoiceTask)
                  .items)
            passage.tokens[item.tokenIndex].word: item.answer,
      };

      expect(answers["παθεῖν"], "AcI");
    });

    test("AcP nach einem Verb des Findens ist kein Participium coniunctum", () async {
      // Mt 26,43: καὶ ἐλθὼν πάλιν εὗρεν αὐτοὺς καθεύδοντας.
      final passage = await verses("MAT", 26, ["43"]);

      final task = const ConstructionNamingTaskType().create(
        ExamTaskContext(passage: passage, detection: detection),
        Random(1),
      ) as ChoiceTask;

      final byWord = {
        for (final item in task.items) passage.tokens[item.tokenIndex].word: item,
      };

      expect(byWord["καθεύδοντας"]!.answer, "AcP (Akkusativ mit Partizip)");
      expect(words(passage, byWord["καθεύδοντας"]!.related), ["εὗρεν", "αὐτοὺς"]);
      expect(byWord["ἐλθὼν"]!.answer, "Participium coniunctum");
    });

    test("Kasus nach Präposition; ὑπό beim Passiv nennt den Urheber", () async {
      // Mt 3,6: ἐβαπτίζοντο ἐν τῷ Ἰορδάνῃ ποταμῷ ὑπ’ αὐτοῦ.
      final passage = await verses("MAT", 3, ["6"]);

      final task = const PrepositionCaseTaskType().create(
        ExamTaskContext(passage: passage, detection: detection),
        Random(1),
      ) as ChoiceTask;

      final byWord = {
        for (final item in task.items)
          passage.tokens[item.tokenIndex].contextual!.lemma: item,
      };

      expect(byWord["ἐν"]!.answer, "Dativ");
      expect(byWord["ὑπό"]!.answer, "Genitiv");
      expect(byWord["ὑπό"]!.explanation, contains("Genitivus auctoris"));
      expect(words(passage, byWord["ὑπό"]!.related), ["αὐτοῦ"]);
    });

    test("gibt der Text eine Aufgabe nicht her, tritt eine andere ein", () async {
      // Ein Vers ohne Partizip und Infinitiv: keine Konstruktion.
      final passage = await verses("JHN", 1, ["1"]);
      final context = ExamTaskContext(passage: passage, detection: detection);

      expect(const ConstructionMarkingTaskType().create(context, Random(1)), isNull);
      expect(const ConstructionNamingTaskType().create(context, Random(1)), isNull);

      final exam = ((await ExamGenerator(source: source, random: Random(1)).generate(
        config: const ExamConfig(fixedPassage: "nt:JHN.1.1-1"),
        done: const {},
        vocabulary: vocabulary,
      )) as ExamCreated).exam;

      expect(exam.extra, hasLength(2));
      expect(exam.extra.whereType<UnavailableTask>(), isEmpty);
      expect(exam.extra[0].typeId, isNot(exam.extra[1].typeId));
    });

    testWidgets("Auswahlfrage: prüfen, Lösung und Begründung", (tester) async {
      final passage = passageOf([
        ctx("ἐβαπτίσθη", "βαπτίζω", "V-3API-S--"),
        ctx("ὑπὸ", "ὑπό", "P---------"),
        ctx("Ἰωάννου.", "Ἰωάννης", "N-----GSM-"),
      ]);

      final task = const PrepositionCaseTaskType().create(
        ExamTaskContext(passage: passage, detection: const DetectionContext()),
        Random(1),
      ) as ChoiceTask;

      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChoiceTaskView(passage: passage, task: task),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Dativ"));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey("check-choice-1")));
      await tester.pump();

      expect(find.text("Nicht ganz. Lösung: Genitiv"), findsOneWidget);
      expect(find.textContaining("Genitivus auctoris"), findsOneWidget);
    });
  });
}
