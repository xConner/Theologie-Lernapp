import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';

import '../history/history_test_support.dart';
import 'old_testament_test_data.dart';

final _allKinds = OtQuizKind.values.toSet();

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß0-9]'), "");

/// Einheit 2 der Vorlesung: Pentateuch, Teil 1–2a (Grundlagen der
/// Pentateuchkritik bis Urgeschichte).
void main() {
  final all = loadOldTestament();
  final lecture = all.forCourse(OtCourseId.lecture);
  final bk = all.forCourse(OtCourseId.bibelkunde);
  final unit = lecture.unit("unit.02")!;

  group("Einheit 2 der Vorlesung", () {
    test("ist eingebunden, mit allen 22 Folien", () {
      expect(lecture.units.map((u) => u.id), ["unit.01", "unit.02"]);
      expect(unit.label, "Einheit 2");
      expect(unit.title, contains("Pentateuch"));
      expect(unit.file, contains("Berner_EinfuehrungAT_02"));
      expect(unit.scope, contains("Einheit II"));
      expect(
        [for (final s in unit.slides) s.number],
        [for (var i = 1; i <= 22; i++) i],
      );
      // Die Übung sieht die Einheit nur als verwandte Einheit.
      expect(bk.units.map((u) => u.id), isNot(contains("unit.02")));
    });

    test("jede Folie hat Bild und Abschrift", () {
      for (final s in unit.slides) {
        expect(s.text.trim(), isNotEmpty, reason: "Folie ${s.number}");
        expect(s.image, startsWith("assets/old_testament/slides/e02-folie-"));
        expect(File(s.image!).existsSync(), isTrue, reason: s.image);
      }
    });

    test("ist mit Einheit 1 und der Genesis-Sitzung der Übung verknüpft", () {
      expect(unit.relatedUnitIds, containsAll(["unit.01", "bk.02"]));
      expect(
        all.relatedUnitsOf("unit.01").map((u) => u.id),
        contains("unit.02"),
      );
      expect(all.relatedUnitsOf("bk.02").map((u) => u.id), contains("unit.02"));
    });

    test(
      "Unklares ist markiert, Ergänzungen zu umstrittenen Positionen da",
      () {
        final unclear = [
          for (final s in unit.sections)
            if (s.unclear != null) s.title,
        ];
        expect(unclear, isNotEmpty);
        // Folie 10 wiederholt Folie 7.
        expect(
          unit.sections.firstWhere((s) => s.slides.contains(10)).unclear!.text,
          contains("Folie 10"),
        );
        for (final slide in [4, 8, 20]) {
          final section = unit.sections.firstWhere(
            (s) => s.slides.contains(slide),
          );
          expect(section.supplement, isNotNull, reason: "Folie $slide");
        }
      },
    );
  });

  group("Begriffe", () {
    test("neue Begriffe stehen einmal, eingeführt in der Vorlesung", () {
      const added = [
        "term.tetrateuch",
        "term.hexateuch",
        "term.enneateuch",
        "term.urkundenhypothese",
        "term.fragmentenhypothese",
        "term.ergaenzungshypothese",
        "term.neuere_urkundenhypothese",
        "term.jahwist",
        "term.elohist",
        "term.priesterschrift",
        "term.kompositionsschicht",
        "term.theokratische_bearbeitungen",
      ];
      final ids = all.allTerms.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      // Das Extra-Material der Übung (Sitzung 2, Folien 21–24) nennt die
      // Erklärungsmodelle und Quellen erneut – derselbe Eintrag, dieselbe
      // Karte.
      const alsoExercise = {
        "term.urkundenhypothese",
        "term.fragmentenhypothese",
        "term.ergaenzungshypothese",
        "term.neuere_urkundenhypothese",
        "term.jahwist",
        "term.elohist",
        "term.priesterschrift",
      };
      final bkTerms = bk.terms.map((t) => t.id).toSet();
      for (final id in added) {
        expect(all.unitsOfTerm(id).map((u) => u.id), [
          "unit.02",
          if (alsoExercise.contains(id)) "bk.02",
        ], reason: id);
        expect(bkTerms.contains(id), alsoExercise.contains(id), reason: id);
      }
    });

    test("vorhandene Begriffe werden nur genannt", () {
      for (final id in [
        "term.pentateuch",
        "term.tora",
        "term.urgeschichte",
        "term.erzelterngeschichte",
        "term.josephsgeschichte",
      ]) {
        expect(
          all.unitsOfTerm(id).map((u) => u.id),
          contains("unit.02"),
          reason: id,
        );
      }
      // Die Buchgruppen sind keine Ablenker für den Pentateuch.
      expect(
        all.term("term.pentateuch")!.confusableIds,
        containsAll(["term.tetrateuch", "term.hexateuch", "term.enneateuch"]),
      );
    });
  });

  group("Lernfragen", () {
    final quiz = OldTestamentQuiz(data: lecture);
    final questions = [
      for (var seed = 0; seed < 5; seed++)
        for (final c in quiz.candidates(
          const OtScope.unit("unit.02"),
          _allKinds,
        ))
          ?c.build(Random(seed)),
    ];

    test("alle Aufgabenarten kommen vor, auch Bibelstellen", () {
      expect(questions.map((q) => q.kind).toSet(), _allKinds);
    });

    test("Auswahlfragen: eindeutige Optionen, genau eine richtig", () {
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        final normalized = q.options.map((o) => o.trim().toLowerCase());
        expect(normalized.toSet().length, q.options.length, reason: q.prompt);
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
      }
    });

    test("keine Frage wiederholt eine Frage der Übung oder von Einheit 1", () {
      final others = {
        for (final u in all.allUnits)
          if (u.id != "unit.02")
            for (final q in u.questions) _norm(q.prompt),
      };
      for (final q in unit.questions) {
        expect(others, isNot(contains(_norm(q.prompt))), reason: q.id);
      }
    });

    test("Fragen zu Positionen der Vorlesung nennen andere Sichten", () {
      for (final id in [
        "q.u02.fuenf_buecher_mose",
        "q.u02.kritik_seit",
        "q.u02.gen1_uebersetzung",
        "q.u02.aelteste_fassung",
      ]) {
        expect(
          all.question(id)!.explanation,
          contains("Ergänzung"),
          reason: id,
        );
      }
    });
  });

  group("Bibelstellen", () {
    final perikopen = {
      for (final p
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        "${p["book"]}|${p["id"]}|${p["startChapter"]},${p["startVerse"]}",
    };

    test("Verweise auf die Perikopenliste gibt es", () {
      final linked = [
        for (final p in unit.passages)
          if (p.pericopeKeys.isNotEmpty) p,
      ];
      expect(linked.length, greaterThanOrEqualTo(10));
      for (final p in linked) {
        for (final k in p.pericopeKeys) {
          expect(perikopen, contains(k), reason: "${p.id}: $k");
        }
      }
    });

    test("Beschreibungen sind eindeutig", () {
      final clues = [
        for (final p in unit.passages)
          if (p.clue != null) _norm(p.clue!),
      ];
      expect(clues.length, greaterThanOrEqualTo(3));
      expect(clues.toSet().length, clues.length);
    });
  });

  group("Geschichte Schritt für Schritt", () {
    test("Pentateuchforschung nur in der Vorlesung", () {
      final course = oldTestamentCourse(OtCourseId.lecture);
      expect(course.tracks.map((t) => t.id), contains("pentateuch"));
      expect(course.item("person.wellhausen"), isNotNull);
      expect(
        course.sequences.map((s) => s.id),
        containsAll(["seq.urkundenhypothese", "seq.pentateuch_heute"]),
      );

      final other = oldTestamentCourse(OtCourseId.bibelkunde);
      expect(other.item("person.wellhausen"), isNull);
      expect(other.tracks.map((t) => t.id), isNot(contains("pentateuch")));
    });
  });
}
