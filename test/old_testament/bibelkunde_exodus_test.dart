import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/services/memorization/bible_passages.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/pericope_links.dart';

import 'old_testament_test_data.dart';

final _allKinds = OtQuizKind.values.toSet();

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r"\W"), "");

/// Sitzung 3 der Übung Bibelkunde AT (Exodus und Levitikus) und das
/// Extra-Material der Sitzung 2 (Folien 17–26).
void main() {
  final all = loadOldTestament();
  final bk = all.forCourse(OtCourseId.bibelkunde);
  final session = bk.unit("bk.03")!;
  final genesis = bk.unit("bk.02")!;

  final perikopen = [
    for (final entry
        in jsonDecode(File("assets/perikopen.json").readAsStringSync()) as List)
      Perikope.fromJson(Map<String, dynamic>.from(entry)),
  ];
  final links = OtPericopeLinks.fromPerikopen(perikopen);

  group("Sitzung 3: Exodus und Levitikus", () {
    test("ist eingebunden, mit allen 9 Folien", () {
      expect(session.label, "Sitzung 3");
      expect(session.file, "Ex-Lev.pdf");
      expect(session.relatedUnitIds, ["bk.02"]);
      expect(
        [for (final s in session.slides) s.number],
        [for (var i = 1; i <= 9; i++) i],
      );
      for (final s in session.slides) {
        if (s.number == 1) {
          expect(s.image, isNull);
          expect(s.text, isNot(contains("@")));
        } else {
          expect(File(s.image!).existsSync(), isTrue, reason: s.image);
          expect(s.image, contains("bk03-folie-"));
        }
      }
    });

    test("neue Begriffe stehen einmal und nur in der Übung", () {
      const added = [
        "term.dekalog",
        "term.apodiktisches_recht",
        "term.theophanie",
        "term.stiftshuette",
        "term.passa",
        "term.gnadenformel",
        "term.jom_kippur",
      ];
      final ids = all.allTerms.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in added) {
        expect(all.unitsOfTerm(id).map((u) => u.id), ["bk.03"], reason: id);
      }
      // Die Rechtscorpora kennt schon Sitzung 2: genannt, nicht neu angelegt.
      for (final id in [
        "term.bundesbuch",
        "term.heiligkeitsgesetz",
        "term.deuteronomisches_gesetz",
      ]) {
        expect(session.mentionOf(id), isNotNull, reason: id);
        expect(all.unitsOfTerm(id).map((u) => u.id), ["bk.02", "bk.03"]);
      }
      expect(all.term("term.bundesbuch")!.definition, contains("23,33"));
      expect(
        all.term("term.deuteronomisches_gesetz")!.aliases,
        contains("Urdeuteronomium"),
      );
    });

    test("Bundesbuch einheitlich: abgefragt wird nur Ex 20,22-23,33", () {
      final clues = [
        for (final unit in bk.units)
          for (final p in unit.passages)
            if (p.clue != null && p.clue!.contains("Bundesbuch")) p.label,
      ];
      expect(clues, ["Ex 20,22-23,33"]);
      final rechtstexte = genesis.lists.firstWhere(
        (l) => l.id == "list.bk02.rechtstexte",
      );
      expect(rechtstexte.details.first, startsWith("Ex 20,22-23,33"));
    });

    test("Perikopenverweise treffen Einträge, die sich überschneiden", () {
      final linked = [
        for (final p in session.passages)
          if (p.pericopeKeys.isNotEmpty) p,
      ];
      expect(linked.length, greaterThanOrEqualTo(15));
      for (final p in linked) {
        for (final key in p.pericopeKeys) {
          expect(links.byKey(key), isNotNull, reason: "${p.id}: $key");
        }
      }
      // Ex 32 hat jetzt eine Überschrift nach der Folie.
      expect(
        perikopen.where((p) => p.title == "Israels Abfall: Das Goldene Kalb"),
        hasLength(1),
      );
    });

    test("Gliederungen von Exodus und Levitikus nach den Folien", () {
      final catalog = BookCatalog.fromPerikopen(perikopen);
      final outlines = BookOutlines.fromJson(
        jsonDecode(File(BookOutlines.asset).readAsStringSync())
            as Map<String, dynamic>,
      );
      for (final book in ["Ex", "Lev"]) {
        final outline = outlines.outlineFor(catalog, book);
        expect(outline.automatic, isFalse, reason: book);
        expect(outline.note, contains("Folie"), reason: book);
        final inOrder = [
          for (final s in outline.sections) ...pericopesOfSection(catalog, s),
        ];
        // Jede Perikope genau einmal, keine „Weiteren Perikopen“.
        expect(inOrder, catalog.pericopesOf(book), reason: book);
        expect(
          outline.sections.map((s) => s.id),
          isNot(contains("$book-uncovered")),
        );
      }
    });

    test("Lernen: alle Aufgabenarten, eindeutige Karten und Optionen", () {
      final quiz = OldTestamentQuiz(data: bk);
      final candidates = quiz.candidates(
        const OtScope.unit("bk.03"),
        _allKinds,
      );
      final ids = candidates.map((c) => c.cardId).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains("passage.bk02.lev_17_26|passage"));
      final questions = [
        for (var seed = 0; seed < 5; seed++)
          for (final c in candidates) ?c.build(Random(seed)),
      ];
      expect(questions.map((q) => q.kind).toSet(), OtQuizKind.values.toSet());
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        final normalized = q.options.map((o) => o.trim().toLowerCase());
        expect(normalized.toSet().length, q.options.length, reason: q.prompt);
      }
      for (final q in session.questions) {
        expect(q.explanation, contains("Folie"), reason: q.id);
      }
      final asked = [
        for (final p in session.passages)
          if (p.clue != null) _norm(p.clue!),
      ];
      expect(asked.toSet().length, asked.length);
    });
  });

  group("Sitzung 2: Extra-Material", () {
    test("Folien 17–26 mit Bild, Titelfolie ohne Kontaktdaten", () {
      expect(genesis.slide(17)!.image, isNull);
      expect(genesis.slide(17)!.text, isNot(contains("@")));
      expect(genesis.slide(23)!.text, contains("weitestgehend aufgehoben"));
      expect(genesis.slide(26)!.text, contains("Jabbok"));
    });

    test("Pentateuchkritik: gleiche Karten wie die Vorlesung", () {
      expect(
        genesis.sharedIds,
        containsAll(["list.u02.modelle", "list.u02.quellen"]),
      );
      final ids = OldTestamentQuiz(data: bk)
          .candidates(const OtScope.unit("bk.02"), _allKinds)
          .map((c) => c.cardId)
          .toSet();
      expect(ids, contains("list.u02.quellen|order"));
      expect(ids, contains("passage.bk02.gen_12_1_3|passage"));
      expect(ids, contains("list.bk02.zentral_josef|order"));
    });

    test("offene Gruppenfrage wird nicht abgefragt", () {
      final unclear = genesis.sections.map((s) => s.unclear?.text ?? "").join();
      expect(unclear, contains("Zwei Schwestern"));
      for (final q in genesis.questions) {
        expect(q.prompt, isNot(contains("Schwestern")), reason: q.id);
      }
    });
  });

  test("Merkverse aus Genesis, Exodus und Levitikus zum Auswendiglernen", () {
    final ids = BiblePassage.all.map((p) => p.id).toSet();
    expect(
      ids,
      containsAll([
        "1_mose_12_1_3",
        "2_mose_3_14",
        "2_mose_34_6",
        "3_mose_19_2",
        "3_mose_19_18",
      ]),
    );
  });
}
