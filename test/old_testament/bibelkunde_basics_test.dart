import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_widgets.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';

import 'old_testament_test_data.dart';

final _allKinds = OtQuizKind.values.toSet();

Set<String> _cardIds(OldTestamentData data, [OtScope scope = OtScope.all]) =>
    OldTestamentQuiz(
      data: data,
    ).candidates(scope, _allKinds).map((c) => c.cardId).toSet();

/// Grundlagen der Bibelkunde (Übung Bibelkunde AT, Sitzung 1): eigene Sicht
/// auf die Daten des Alten Testaments mit gemeinsamen Begriffen und
/// geteilten Inhalten.
void main() {
  final all = loadOldTestament();
  final lecture = all.forCourse(OtCourseId.lecture);
  final bk = all.forCourse(OtCourseId.bibelkunde);
  final session = bk.unit("bk.01")!;

  group("Sitzung 1 der Übung", () {
    test("ist eingebunden und von der Vorlesung getrennt", () {
      expect(bk.course.title, contains("Bibelkunde"));
      expect(bk.course.lecturer, "Louisa Thomsen");
      expect(bk.units.map((u) => u.id), ["bk.01", "bk.02"]);
      expect(session.course, OtCourseId.bibelkunde);
      expect(session.label, "Sitzung 1");
      expect(session.file, contains("Einfuhrung erste Sitzung"));
      expect(
        [for (final s in session.slides) s.number],
        [for (var i = 1; i <= 28; i++) i],
      );

      // Die Vorlesung sieht nur ihre eigenen Einheiten.
      expect(lecture.units.map((u) => u.id), everyElement(startsWith("unit.")));
      expect(lecture.course.lecturer, "Prof. Dr. Christoph Berner");
    });

    test("Folienbilder liegen vor, ohne Kontaktdaten der Titelfolie", () {
      for (final s in session.slides) {
        expect(s.text.trim(), isNotEmpty, reason: "Folie ${s.number}");
        if (s.number == 1) {
          expect(s.image, isNull);
          expect(s.text, isNot(contains("@")));
        } else {
          expect(File(s.image!).existsSync(), isTrue, reason: s.image);
          expect(s.image, contains("bk01-folie-"));
        }
      }
    });

    test("Tabellen und Schaubilder sind abgeschrieben", () {
      expect(session.slide(17)!.text, contains("Megillot"));
      expect(session.slide(17)!.text, contains("Bammidbar"));
      expect(session.slide(18)!.text, contains("Bel und der Drache"));
      expect(session.slide(26)!.text, contains("Katalysator"));
      expect(session.slide(27)!.text, contains("Merenptah"));
      for (final n in [7, 17, 18, 26]) {
        expect(session.slide(n)!.figure, isNotNull, reason: "Folie $n");
      }
    });

    test("Überblick, Begriffe, Merklisten und Literatur sind gefüllt", () {
      expect(session.keyPoints, isNotEmpty);
      expect(session.sections.length, greaterThanOrEqualTo(10));
      expect(session.terms.length, greaterThanOrEqualTo(25));
      expect(session.lists, isNotEmpty);
      expect(session.literature.map((l) => l.text).join(), contains("Rösel"));
      expect(session.relatedUnitIds, ["unit.01"]);
    });

    test("keine systematische Übersicht aller Bücher", () {
      // Buchlisten gehören in spätere Ausbaustufen (Bücher systematisch
      // lernen); die Sitzung hat nur Grundlagen.
      for (final l in session.lists) {
        expect(l.items.length, lessThanOrEqualTo(12), reason: l.id);
        expect(l.items, isNot(contains("Genesis")), reason: l.id);
      }
    });
  });

  group("Gemeinsame Datenbasis mit der Vorlesung", () {
    test("Begriffe stehen einmal und nennen beide Veranstaltungen", () {
      final ids = all.allTerms.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);

      expect(all.unitsOfTerm("term.kanon").map((u) => u.id), [
        "unit.01",
        "bk.01",
      ]);
      expect(
        bk.sourceLabel("unit.01", [6]),
        "Vorlesung AT · Einheit 1, Folie 6",
      );
      expect(lecture.sourceLabel("unit.01", [6]), "Einheit 1, Folie 6");
    });

    test("neue Begriffe der Übung erscheinen nicht in der Vorlesung", () {
      final lectureTerms = lecture.terms.map((t) => t.id).toSet();
      expect(lecture.unit("unit.01")!.terms, hasLength(25));
      expect(lectureTerms, isNot(contains("term.megillot")));
      expect(bk.terms.map((t) => t.id), contains("term.megillot"));
      // Nur in der Vorlesung: steht nicht im Glossar der Übung.
      expect(bk.terms.map((t) => t.id), isNot(contains("term.masoreten")));
    });

    test("geteilte Inhalte haben dieselbe Karte wie in der Vorlesung", () {
      final shared = _cardIds(bk, const OtScope.unit("bk.01"));
      final lectureIds = _cardIds(lecture);

      for (final id in [
        "q.u01.luther|lecture",
        "list.u01.tanak|recall",
        "list.u01.tanak|order",
        "term.kanon|term",
      ]) {
        expect(shared, contains(id));
        expect(lectureIds, contains(id));
      }
      // Was nur die Übung hat, bleibt bei ihr.
      expect(shared, contains("q.bk01.ziel|lecture"));
      expect(lectureIds, isNot(contains("q.bk01.ziel|lecture")));
    });

    test("Vorlesung bleibt unverändert", () {
      // Alle Karten der Vorlesung stammen aus Einheit 1.
      for (final id in _cardIds(lecture)) {
        expect(id, isNot(contains("bk01")), reason: id);
      }
    });

    test("eine Antwort zählt für beide Veranstaltungen", () {
      final cards = <String, LearningCard>{};
      final quiz = OldTestamentQuiz(data: bk, cards: cards);
      final candidate = quiz
          .candidates(OtScope.all, {OtQuizKind.lecture})
          .firstWhere((c) => c.cardId == "q.u01.luther|lecture");
      quiz.record(candidate.build(Random(1))!, false);

      // Falsch beantwortet in der Übung: auch in der Vorlesung schwierig.
      final lectureQuiz = OldTestamentQuiz(data: lecture, cards: cards);
      expect(lectureQuiz.isDifficult("q.u01.luther|lecture"), isTrue);
      expect(cards["q.u01.luther|lecture"]!.lastReviewed, isNotNull);
    });

    test("keine Frage der Übung wiederholt eine Frage der Vorlesung", () {
      String norm(String s) => s.toLowerCase().replaceAll(RegExp(r"\W"), "");
      final lecturePrompts = {
        for (final q in all.unit("unit.01")!.questions) norm(q.prompt),
      };
      final lectureAnswers = {
        for (final q in all.unit("unit.01")!.questions) norm(q.answer),
      };
      for (final q in session.questions) {
        expect(lecturePrompts, isNot(contains(norm(q.prompt))), reason: q.id);
        expect(lectureAnswers, isNot(contains(norm(q.answer))), reason: q.id);
      }
      final lectureLists = {
        for (final l in all.unit("unit.01")!.lists) l.items.join("|"),
      };
      for (final l in session.lists) {
        expect(lectureLists, isNot(contains(l.items.join("|"))), reason: l.id);
      }
    });

    test("geteilte IDs zeigen auf Inhalte einer anderen Einheit", () {
      expect(session.sharedIds, isNotEmpty);
      for (final id in session.sharedIds) {
        expect(all.isShareable(id), isTrue, reason: id);
        expect(id, isNot(contains("bk01")));
      }
    });
  });

  group("Prüfung der Daten", () {
    ({
      Map<String, dynamic> course,
      Map<String, dynamic> terms,
      List<Map<String, dynamic>> units,
    })
    withSession(void Function(Map<String, dynamic> unit) change) {
      final json = oldTestamentJson();
      change(json.units.firstWhere((u) => u["id"] == "bk.01"));
      return json;
    }

    test("Daten sind gültig, IDs mit Präfix der Sitzung", () {
      for (final q in session.questions) {
        expect(q.id, startsWith("q.bk01."));
      }
      for (final l in session.lists) {
        expect(l.id, startsWith("list.bk01."));
      }
      for (final p in session.passages) {
        expect(p.id, startsWith("passage.bk01."));
      }
      final ids = OldTestamentQuiz(
        data: bk,
      ).candidates(OtScope.all, _allKinds).map((c) => c.cardId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test("unbekannter geteilter Inhalt wird abgelehnt", () {
      final json = withSession(
        (u) => u["shared"] = [...u["shared"] as List, "q.u01.gibtsnicht"],
      );
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("eigener Inhalt als geteilt wird abgelehnt", () {
      final json = withSession(
        (u) => u["shared"] = [...u["shared"] as List, "q.bk01.ziel"],
      );
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("ID passt nicht zur Veranstaltung", () {
      final json = withSession((u) => u.remove("course"));
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("Fragen-ID mit Präfix der Vorlesung wird abgelehnt", () {
      final json = withSession((u) {
        final questions = u["questions"] as List;
        (questions.first as Map)["id"] = "q.u01.neu";
      });
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("unbekannte Veranstaltung wird abgelehnt", () {
      final json = withSession((u) => u["course"] = "seminar");
      expect(() => parseOldTestament(json), throwsFormatException);
    });
  });

  group("Lernfragen der Übung", () {
    final quiz = OldTestamentQuiz(data: bk);
    final questions = [
      for (var seed = 0; seed < 5; seed++)
        for (final c in quiz.candidates(OtScope.all, _allKinds))
          ?c.build(Random(seed)),
    ];

    test("Auswahlfragen, Begriffe, Merklisten und Ordnen kommen vor", () {
      final kinds = questions.map((q) => q.kind).toSet();
      expect(
        kinds,
        containsAll([
          OtQuizKind.lecture,
          OtQuizKind.term,
          OtQuizKind.recall,
          OtQuizKind.order,
        ]),
      );
    });

    test("Auswahlfragen: eindeutige Optionen, genau eine richtig", () {
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        final normalized = q.options.map((o) => o.trim().toLowerCase());
        expect(normalized.toSet().length, q.options.length, reason: q.prompt);
        expect(q.options[q.correctIndex], q.answer);
        expect(q.explanation.trim(), isNotEmpty);
      }
    });

    test("Fragen verraten die Antwort nicht", () {
      for (final q in session.questions) {
        expect(
          q.prompt.toLowerCase(),
          isNot(contains(q.answer.toLowerCase())),
          reason: q.id,
        );
      }
    });

    test("Erklärungen nennen die Folie und kennzeichnen Ergänzungen", () {
      for (final q in session.questions) {
        expect(q.explanation, contains("Folie"), reason: q.id);
        final extra = q.explanation.split("Ergänzung: ");
        // Eine Ergänzung steht am Ende, nach dem Folieninhalt.
        expect(extra.length, lessThanOrEqualTo(2), reason: q.id);
      }
    });

    test("Umstrittenes ist als Position der Folie gekennzeichnet", () {
      final texte = session.questions.firstWhere(
        (q) => q.id == "q.bk01.zeit_der_texte",
      );
      expect(texte.prompt, contains("die Folie"));
      expect(texte.explanation, contains("umstritten"));
      final kathedrale = session.questions.firstWhere(
        (q) => q.id == "q.bk01.kathedrale",
      );
      expect(kathedrale.answer, contains("nach dieser Sicht"));
      expect(kathedrale.explanation, contains("konservative"));
      final entstehung = session.sections.firstWhere(
        (s) => s.title.contains("Entstehung"),
      );
      expect(entstehung.supplement, contains("umstritten"));
    });

    test("Unklares wird angezeigt, aber nicht abgefragt", () {
      final unclear = [
        for (final s in session.sections)
          if (s.unclear != null) s.unclear!.text,
      ];
      expect(unclear.join(), contains("200 - 70 n. Chr."));
      expect(unclear.join(), contains("45"));
      for (final q in session.questions) {
        final text = "${q.prompt} ${q.answer}";
        expect(text, isNot(contains("200")), reason: q.id);
        expect(text, isNot(contains("15 zusätzliche")), reason: q.id);
      }
    });

    test("Ordnen: Erzählbogen und Eckdaten", () {
      final order = questions.whereType<OtOrderQuestion>().map(
        (q) => q.list.id,
      );
      expect(
        order,
        containsAll([
          "list.bk01.erzaehlbogen",
          "list.bk01.eckdaten_bis_exil",
          "list.bk01.uebersetzungen",
          "list.u01.lxx_teile",
        ]),
      );
    });

    test(
      "Umfang: gespeicherte Einheit der anderen Veranstaltung gilt nicht",
      () {
        expect(OtScope.parse("unit:bk.01", bk), const OtScope.unit("bk.01"));
        expect(OtScope.parse("unit:unit.01", bk), OtScope.all);
        expect(OtScope.parse("unit:bk.01", lecture), OtScope.all);
        expect(OtScope.all.label(bk), "Alle Sitzungen");
        expect(OtScope.all.label(lecture), "Alle Einheiten");
        expect(
          OtQuizKind.lecture.labelIn(OtCourseId.bibelkunde),
          "Wissensfragen",
        );
        expect(
          OtQuizKind.lecture.labelIn(OtCourseId.lecture),
          "Fragen zur Vorlesung",
        );
      },
    );
  });

  group("Bibelstellen der Sitzung", () {
    test("lassen sich aufschlagen", () {
      for (final p in session.passages) {
        expect(biblePassageOf(p), isNotNull, reason: p.label);
      }
      final gen = biblePassageOf(
        session.passages.firstWhere((p) => p.label == "Num 6,22-26"),
      )!.reference;
      expect((gen.bookId, gen.chapter, gen.verse), ("NUM", 6, 22));
    });
  });

  group("Speicherung", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("eigene Einstellungen, gemeinsamer Lernstand", () async {
      final store = LocalOldTestamentStore();
      await store.saveSettings(
        const OldTestamentSettings(scope: "unit:unit.01", onlyDifficult: true),
      );
      await store.saveSettings(
        const OldTestamentSettings(scope: "unit:bk.01", inOrder: true),
        course: OtCourseId.bibelkunde,
      );

      final a = await LocalOldTestamentStore().loadSettings();
      final b = await LocalOldTestamentStore().loadSettings(
        course: OtCourseId.bibelkunde,
      );
      expect(
        (a.scope, a.onlyDifficult, a.inOrder),
        ("unit:unit.01", true, false),
      );
      expect(
        (b.scope, b.onlyDifficult, b.inOrder),
        ("unit:bk.01", false, true),
      );

      await store.saveCards([LearningCard(id: "term.kanon|term")]);
      expect((await store.loadCards()).keys, ["term.kanon|term"]);
    });

    test("Einstellungen der Übung werden bei der Anmeldung übernommen", () {
      expect(
        LocalLearningStore.quizDocuments,
        contains(LocalLearningStore.bibelkundeBasicsSettings),
      );
      // Einstellungen sind kein Lernfortschritt.
      expect(
        LocalLearningStore.progressDocuments,
        isNot(contains(LocalLearningStore.bibelkundeBasicsSettings)),
      );
      expect(
        OldTestamentStore.settingsDocument(OtCourseId.lecture),
        LocalLearningStore.oldTestamentSettings,
      );
    });
  });
}
