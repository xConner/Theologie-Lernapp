import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_controller.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/quiz/books/knowledge.dart';
import 'package:theologie_lernapp/quiz/books/outline_questions.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';

/// Gemeinsamer Lernmodus der Bibelkunde: Grobgliederung (Ebene A) mit den
/// Feinperikopen (Ebene B), Gliederungsaufgaben, freie Eingabe, die beiden
/// Schalter und die gemischten Einheiten.

class _Settings implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Gen", "Ex", "Lev"};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Learning implements LearningService {
  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _json(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Perikope> perikopen;
  late BookOutlines outlines;
  late BookCatalog catalog;
  late KnowledgeBank fileBank;

  setUpAll(() {
    perikopen = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        if (const {"Gen", "Ex", "Lev"}.contains(entry["book"]))
          Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];
    outlines = BookOutlines.fromJson(_json(BookOutlines.asset));
    catalog = BookCatalog.fromPerikopen(perikopen);

    final index = _json("${KnowledgeBank.root}/index.json");
    fileBank = KnowledgeBank.merge([
      for (final file in index["files"] as List)
        KnowledgeBank.parse(_json("${KnowledgeBank.root}/$file")),
    ]);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 11, 2, 8);

  Future<BookLearningController> load([BookLearningStorage? storage]) async {
    final c = await BookLearningController.load(
      perikopen: perikopen,
      uid: null,
      storage: storage ?? LocalBookLearningStorage(),
      learningService: _Learning(),
      settingsService: _Settings(),
      outlines: outlines,
      clock: () => now,
      loadKnowledge: (_) async => fileBank,
    );
    await c.knowledgeReady;
    return c;
  }

  group("Grobgliederung (Ebene A) und Feinperikopen (Ebene B)", () {
    test("Gen, Ex und Lev haben die Hauptabschnitte der Folien", () {
      String titles(String book) => [
        for (final p in outlines.outlineFor(catalog, book).parts) p.label,
      ].join(" | ");

      expect(titles("Gen"), "1–11 | 12–36 (+38) | 37–50 (ohne 38)");
      expect(titles("Ex"), "1–18 | 19–24 | 25–31 | 32–34 | 35–40");
      expect(titles("Lev"), "1–7 | 8–10 | 11–15 | 16 | 17–26 | 27");
    });

    test("jede Feinperikope gehört zu genau einem Hauptabschnitt", () {
      for (final book in const ["Gen", "Ex", "Lev"]) {
        final outline = outlines.outlineFor(catalog, book);

        for (final p in catalog.pericopesOf(book)) {
          final parts = outline.parts.where((part) => part.contains(p));
          expect(parts.length, 1, reason: "${p.key} in ${parts.length}");
        }
      }
    });

    test("Gen 38 gehört zur Erzelterngeschichte, nicht zu Joseph", () {
      final outline = outlines.outlineFor(catalog, "Gen");
      final tamar = catalog
          .pericopesOf("Gen")
          .firstWhere((p) => p.chapter == 38);

      expect(outline.partOfPericope(tamar)!.id, "gen-teil-erzeltern");
      // Nicht zusammenhängend: kein durchgehender Kapitelbereich.
      expect(outline.parts[1].span, isNull);
      expect(outline.parts[0].span, isNotNull);
    });

    test("Feinperikopen bleiben unverändert erhalten", () {
      // Die Grobgliederung ersetzt keine Perikope (Zahlen wie in der
      // Perikopenliste).
      expect(catalog.pericopesOf("Ex").length, 111);
      expect(catalog.pericopesOf("Lev").length, 91);
    });
  });

  group("Gliederungsaufgaben", () {
    late KnowledgeBank structure;

    setUpAll(() => structure = OutlineQuestions.build(outlines, catalog));

    test("gültig, eindeutig, als Gliederung gekennzeichnet", () {
      final ids = [for (final q in structure.questions) q.id];

      expect(ids.toSet().length, ids.length);
      expect(ids, contains("go.ex.teile.reihenfolge"));
      expect(ids, contains("go.lev.teile.kapitel"));
      expect(ids, contains("go.gen.gliederung"));
      expect(ids, contains("go.ex.ex-bundesbuch.kapitel"));

      for (final q in structure.questions) {
        expect(q.isStructure, isTrue, reason: q.id);
        expect(q.basis, KnowledgeBasis.slide, reason: q.id);
        expect(q.origin, isNotEmpty, reason: q.id);
      }

      // Kein Konflikt mit den Wissensfragen.
      expect(() => KnowledgeBank.merge([fileBank, structure]), returnsNormally);
    });

    test("Reihenfolge der Hauptabschnitte wie im Buch", () {
      final order = structure.question("go.ex.teile.reihenfolge")!;

      expect(order.items.first, startsWith("Israel in Ägypten"));
      expect(order.items[3], contains("Goldene Kalb"));
      expect(order.items.last, "Die Ausführung der Vorschriften");
    });

    test("Zuordnung Perikope → Hauptabschnitt stimmt mit der Gliederung", () {
      for (final book in const ["Gen", "Ex", "Lev"]) {
        final outline = outlines.outlineFor(catalog, book);
        final sets = structure.questions.where(
          (q) => q.book == book && q.id.contains(".zuordnung."),
        );

        expect(sets.length, OutlineQuestions.assignmentSets, reason: book);

        for (final q in sets) {
          for (final pair in q.pairs) {
            final p = catalog
                .pericopesOf(book)
                .firstWhere(
                  (p) =>
                      p.title == pair.left ||
                      pair.left.startsWith("$book ${p.chapter}"),
                );
            final part = outline.parts.firstWhere(
              (part) => part.title == pair.right,
            );

            // Stellenangaben: die erste passende Perikope liegt im Kapitel;
            // ihr Hauptabschnitt muss stimmen, wenn der Titel passt.
            if (p.title == pair.left) {
              expect(part.contains(p), isTrue, reason: "${q.id} ${p.key}");
            }
          }
        }
      }
    });

    test("Kapitelbereiche werden frei eingegeben erkannt", () {
      final sinai = structure.question("go.ex.ex-teil-sinai.kapitel")!;

      expect(sinai.format, KnowledgeFormat.input);
      for (final ok in ["19-24", "19–24", "Ex 19-24", "Kapitel 19 - 24"]) {
        expect(KnowledgeAnswerMatcher.matches(sinai, ok), isTrue, reason: ok);
      }
      for (final no in ["19-25", "20-24", "19", "Sinai"]) {
        expect(KnowledgeAnswerMatcher.matches(sinai, no), isFalse, reason: no);
      }

      final bundesbuch = structure.question("go.ex.ex-bundesbuch.kapitel")!;
      for (final ok in ["20,22-23,33", "21-23", "20-23", "Ex 20,22–23,19"]) {
        expect(
          KnowledgeAnswerMatcher.matches(bundesbuch, ok),
          isTrue,
          reason: ok,
        );
      }
      expect(KnowledgeAnswerMatcher.matches(bundesbuch, "20,1-17"), isFalse);
    });

    test("Titel eines Hauptabschnitts über Stichwörter erkannt", () {
      final kalb = structure.question("go.ex.ex-teil-kalb.titel")!;
      final vorschriften = structure.question(
        "go.ex.ex-teil-stiftshuette.titel",
      )!;

      expect(KnowledgeAnswerMatcher.matches(kalb, "das goldene Kalb"), isTrue);
      expect(KnowledgeAnswerMatcher.matches(kalb, "Goldenes Kalp"), isTrue);
      expect(
        KnowledgeAnswerMatcher.matches(
          vorschriften,
          "Vorschriften für die Stiftshütte",
        ),
        isTrue,
      );
      // Nur „Stiftshütte“ passt auch auf 35–40: nicht erkannt, nicht falsch
      // – die Selbsteinschätzung entscheidet.
      expect(
        KnowledgeAnswerMatcher.matches(vorschriften, "Stiftshütte"),
        isFalse,
      );
    });
  });

  group("Freie Eingabe", () {
    const q = KnowledgeQuestion(
      id: "t.hebammen",
      book: "Ex",
      format: KnowledgeFormat.input,
      prompt: "Wie heißen die Hebammen?",
      answer: "Schifra und Pua",
      accept: ["Schifra + Pua"],
    );

    test(
      "verlangt alle Teile, verzeiht Groß-/Kleinschreibung und Tippfehler",
      () {
        expect(KnowledgeAnswerMatcher.matches(q, "Schifra und Pua"), isTrue);
        expect(KnowledgeAnswerMatcher.matches(q, "pua, schiffra"), isTrue);
        expect(KnowledgeAnswerMatcher.matches(q, "Schifra"), isFalse);
        expect(KnowledgeAnswerMatcher.matches(q, ""), isFalse);
      },
    );

    test("Umlaute und Artikel", () {
      const tag = KnowledgeQuestion(
        id: "t.tag",
        book: "Lev",
        format: KnowledgeFormat.input,
        prompt: "?",
        accept: ["Versöhnungstag"],
      );

      expect(
        KnowledgeAnswerMatcher.matches(tag, "der Versoehnungstag"),
        isTrue,
      );
      expect(KnowledgeAnswerMatcher.matches(tag, "Laubhüttenfest"), isFalse);
    });

    test("ungültig ohne akzeptierte Antworten", () {
      expect(
        () => KnowledgeQuestion.fromJson({
          "id": "x",
          "format": "input",
          "prompt": "?",
        }, book: "Ex"),
        throwsFormatException,
      );
    });
  });

  group("Gemeinsamer Lernmodus", () {
    Future<List<StudyTask>> run(
      BookLearningController c, {
      bool correct = true,
    }) async {
      final session = c.bookSession("Ex");
      final tasks = <StudyTask>[];
      var guard = 0;

      while (!session.finished && guard++ < 200) {
        final task = session.current!;
        tasks.add(task);

        switch (task) {
          case KnowledgeTask():
            await session.answerKnowledge(correct, given: "");
          case IntroduceTask():
            await session.completeIntroduction();
          case RecallTask():
            await session.assessRecall(correct);
          default:
            break;
        }

        session.advance();
      }

      await session.flush();
      return tasks;
    }

    test("beide an (Standard): Perikopen, Gliederung und Wissensfragen "
        "gemischt, keine langen Serien", () async {
      final c = await load();

      expect(c.state.knowledgeEnabled, isTrue);
      expect(c.state.pericopesEnabled, isTrue);

      final tasks = await run(c);

      expect(tasks.whereType<PericopeTask>(), isNotEmpty);
      expect(tasks.whereType<KnowledgeTask>(), isNotEmpty);

      // Die Wissensfragen stehen nicht am Stück.
      var run_ = 0, longest = 0;
      for (final t in tasks) {
        run_ = t is KnowledgeTask ? run_ + 1 : 0;
        if (run_ > longest) longest = run_;
      }
      expect(longest, lessThanOrEqualTo(3));
    });

    test("nur Wissensfragen: keine Perikopen, aber mehr Fragen", () async {
      final c = await load();

      await c.setPericopesEnabled(false);

      final tasks = await run(c);

      expect(tasks.whereType<PericopeTask>(), isEmpty);
      expect(tasks, isNotEmpty);
      for (final t in tasks.cast<KnowledgeTask>()) {
        expect(t.question.isStructure, isFalse, reason: t.question.id);
      }
    });

    test(
      "nur Perikopen und Gliederung: keine inhaltlichen Wissensfragen",
      () async {
        final c = await load();

        await c.setKnowledgeEnabled(false);

        final tasks = await run(c);

        expect(tasks.whereType<PericopeTask>(), isNotEmpty);
        for (final t in tasks.whereType<KnowledgeTask>()) {
          expect(t.question.isStructure, isTrue, reason: t.question.id);
        }
      },
    );

    test("beide aus geht nicht; Schalter werden gespeichert", () async {
      final storage = LocalBookLearningStorage();
      final c = await load(storage);

      await c.setKnowledgeEnabled(false);
      await c.setPericopesEnabled(false);

      // Der letzte bleibt an: Wissensfragen gehen wieder an.
      expect(c.state.pericopesEnabled, isFalse);
      expect(c.state.knowledgeEnabled, isTrue);

      final reloaded = await load(LocalBookLearningStorage());
      expect(reloaded.state.pericopesEnabled, isFalse);
      expect(reloaded.state.knowledgeEnabled, isTrue);
    });

    test("Lernstand gilt in allen Lernwegen (eine Karte je Frage)", () async {
      final c = await load();
      final structure = c.structureOf("Ex");

      // Gliederung über die Gliederungs-Einheit lernen …
      final session = c.knowledgeSession(structure);
      final seen = <String>{};
      while (!session.finished) {
        final t = session.current as KnowledgeTask;
        seen.add(t.question.id);
        await session.answerKnowledge(true, given: "");
        session.advance();
      }
      await session.flush();

      // … dieselbe Karte in der Buch-Einheit und nach dem Neuladen.
      final reloaded = await load(c.storage);
      for (final id in seen) {
        final q = reloaded.state.knowledge.question(id)!;
        expect(reloaded.state.knowledgeCardOf(q)?.correctCount, 1);
      }
    });

    test(
      "falsch beantwortete Wissensfrage kommt genau einmal wieder",
      () async {
        final c = await load();
        await c.setPericopesEnabled(false);

        final tasks = await run(c, correct: false);
        final ids = [
          for (final t in tasks.cast<KnowledgeTask>()) t.question.id,
        ];

        for (final id in ids.toSet()) {
          expect(ids.where((i) => i == id).length, 2, reason: id);
        }

        // Frühestens einige Aufgaben später.
        for (final id in ids.toSet()) {
          final first = ids.indexOf(id);
          final second = ids.lastIndexOf(id);
          expect(second - first, greaterThan(1), reason: id);
        }
      },
    );

    test("Wiederholungslisten mischen gleichmäßig", () {
      final a = [
        for (var i = 0; i < 9; i++) IntroduceTask(catalog.pericopesOf("Ex")[i]),
      ];
      final b = [for (var i = 0; i < 3; i++) const KnowledgeTask(_q, [])];

      final mixed = interleaveTasks(a, b);

      expect(mixed.length, 12);
      final positions = [
        for (var i = 0; i < mixed.length; i++)
          if (mixed[i] is KnowledgeTask) i,
      ];
      expect(positions, [3, 7, 11]);
    });
  });

  group("Quellen", () {
    test("Ergänzungen werden nicht als Vorlesungsstoff ausgegeben", () {
      final lecture = [
        for (final f in Directory(
          "assets/old_testament/model_answers",
        ).listSync())
          if (f.path.endsWith(".json")) KnowledgeBank.parse(_json(f.path)),
      ];
      final all = KnowledgeBank.merge([fileBank, ...lecture]);

      for (final q in all.questions) {
        // Lernfragen aus Musterantworten verweisen über ihre Aufgabe.
        if (q.basis == KnowledgeBasis.modelAnswer) {
          expect(q.taskId, isNotNull, reason: q.id);
          continue;
        }

        if (q.basis == KnowledgeBasis.supplement) {
          expect(q.fromLecture, isFalse, reason: q.id);
          expect(q.relevance, isNot(KnowledgeRelevance.focus), reason: q.id);
        } else {
          expect(q.origin, isNotEmpty, reason: "${q.id} ohne Fundstelle");
        }
      }

      // Fragen nach den Folien: Multiple Choice mit genau drei Ablenkern.
      for (final q in all.questions) {
        if (q.id.startsWith("vl.") && q.format == KnowledgeFormat.choice) {
          expect(q.distractors.length, 3, reason: q.id);
        }
      }
    });

    test("richtige Antwort ist nicht auffällig länger als die Ablenker", () {
      final lecture = [
        for (final f in Directory(
          "assets/old_testament/model_answers",
        ).listSync())
          if (f.path.endsWith(".json")) KnowledgeBank.parse(_json(f.path)),
      ];
      final all = KnowledgeBank.merge([fileBank, ...lecture]);
      var tooLong = <String>[];

      for (final q in all.questions) {
        if (q.format != KnowledgeFormat.choice) continue;

        final longest = q.distractors
            .map((d) => d.length)
            .reduce((a, b) => a > b ? a : b);

        if (q.correct.single.length > longest * 1.8 + 10) tooLong.add(q.id);
      }

      expect(tooLong, isEmpty);
    });

    test("mündlicher Vorlesungsstoff nennt die Zeitstelle im Audio", () {
      final lecture = [
        for (final f in Directory(
          "assets/old_testament/model_answers",
        ).listSync())
          if (f.path.endsWith(".json")) KnowledgeBank.parse(_json(f.path)),
      ];
      final all = KnowledgeBank.merge([fileBank, ...lecture]);
      final audio = [
        for (final q in all.questions)
          if (q.basis == KnowledgeBasis.audio) q,
      ];

      expect(audio.length, greaterThanOrEqualTo(20));

      for (final q in audio) {
        expect(q.fromLecture, isTrue, reason: q.id);
        expect(
          q.origin.any((o) => RegExp(r"Folie \d+, Audio \d+:\d\d").hasMatch(o)),
          isTrue,
          reason: q.id,
        );
      }
    });
  });
}

const KnowledgeQuestion _q = KnowledgeQuestion(
  id: "t",
  book: "Ex",
  format: KnowledgeFormat.reveal,
  prompt: "?",
  answer: "!",
);
