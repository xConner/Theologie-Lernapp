import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/algorithms/review_state.dart';
import 'package:theologie_lernapp/algorithms/spaced_repetition.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_widgets.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';
import 'package:theologie_lernapp/services/church_history/church_history_quiz.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_loader.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';

import 'old_testament_test_data.dart';

final _allKinds = OtQuizKind.values.toSet();

List<OtQuestion> _build(
  OldTestamentQuiz quiz, {
  OtScope scope = OtScope.all,
  Set<OtQuizKind>? kinds,
  int seeds = 5,
}) => [
  for (var seed = 0; seed < seeds; seed++)
    for (final c in quiz.candidates(scope, kinds ?? _allKinds))
      ?c.build(Random(seed)),
];

void main() {
  final data = loadOldTestament();
  final unit = data.unit("unit.01")!;

  group("Erste Einheit", () {
    test("ist vollständig eingebunden", () {
      expect(data.course.title, "Einführung in das Alte Testament");
      expect(data.course.lecturer, "Prof. Dr. Christoph Berner");
      expect(data.units, hasLength(1));
      expect(unit.number, 1);
      expect(unit.title, contains("Kanon"));
      expect(unit.file, contains("Berner_EinfuehrungAT_01"));
      // Teil einer größeren Vorlesung, nicht die ganze Vorlesung.
      expect(unit.scope, contains("Einheit I"));
      expect(
        [for (final s in unit.slides) s.number],
        [for (var i = 1; i <= 21; i++) i],
      );
    });

    test("jede Folie hat Bild und Abschrift", () {
      for (final s in unit.slides) {
        expect(s.text.trim(), isNotEmpty, reason: "Folie ${s.number}");
        expect(s.image, isNotNull, reason: "Folie ${s.number}");
        expect(File(s.image!).existsSync(), isTrue, reason: s.image);
        expect(s.image, contains("e01-folie-"), reason: s.image);
      }
    });

    test("Tabellen und Schaubild sind abgeschrieben", () {
      expect(unit.slide(7)!.text, contains("Berešit"));
      expect(unit.slide(7)!.text, contains("Dibre ha-Jammim"));
      expect(unit.slide(9)!.text, contains("Bel Kai Drakon"));
      expect(unit.slide(11)!.text, contains("Lehrbücher und Psalmen"));
      expect(unit.slide(16)!.text, contains("Gegenstand der Textkritik"));
      expect(unit.slide(20)!.text, contains("Psalter (Ps 1-150)"));
    });

    test("Bestandteile der Detailansicht sind gefüllt", () {
      expect(unit.keyPoints, isNotEmpty);
      expect(unit.sections, isNotEmpty);
      expect(unit.terms, isNotEmpty);
      expect(unit.passages, isNotEmpty);
      expect(unit.connections, isNotEmpty);
      expect(unit.literature.length, greaterThanOrEqualTo(7));
      expect(unit.lists, isNotEmpty);
      expect(unit.questions, isNotEmpty);
    });

    test("Mehrdeutiges ist gekennzeichnet (fehlendes Samuel in Folie 7)", () {
      final unclear = [
        for (final s in unit.sections)
          if (s.unclear != null) s,
      ];
      expect(unclear.any((s) => s.unclear!.text.contains("Samuel")), isTrue);
    });

    test("keine hebräische Schrift erfunden", () {
      // Die Folien nennen nur Umschriften.
      expect(data.terms.where((t) => t.hebrew != null), isEmpty);
    });
  });

  group("Stabile IDs und Zuordnung", () {
    test("Daten sind gültig", () {
      expect(OldTestamentLoader.validate(data), isEmpty);
    });

    test("IDs folgen dem Schema und gehören zu ihrer Einheit", () {
      for (final q in unit.questions) {
        expect(q.id, startsWith("q.u01."));
        expect(q.unitId, unit.id);
      }
      for (final l in unit.lists) {
        expect(l.id, startsWith("list.u01."));
      }
      for (final p in unit.passages) {
        expect(p.id, startsWith("passage.u01."));
      }
      for (final t in data.terms) {
        expect(t.id, startsWith("term."));
      }
    });

    test("Kartenschlüssel sind <ID>|<Art> und eindeutig", () {
      final quiz = OldTestamentQuiz(data: data);
      final ids = quiz.candidates(OtScope.all, _allKinds).map((c) => c.cardId);
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(id.split("|"), hasLength(2), reason: id);
      }
    });

    test("doppelte ID wird abgelehnt", () {
      final json = oldTestamentJson();
      final questions = json.units.first["questions"] as List;
      questions.add(Map<String, dynamic>.from(questions.first as Map));
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("Folie, die es nicht gibt, wird abgelehnt", () {
      final json = oldTestamentJson();
      ((json.units.first["keyPoints"] as List).first as Map)["slides"] = [99];
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("ID mit falscher Einheit wird abgelehnt", () {
      final json = oldTestamentJson();
      ((json.units.first["questions"] as List).first as Map)["id"] = "q.u02.x";
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    test("unbekannter Begriff wird abgelehnt", () {
      final json = oldTestamentJson();
      (json.units.first["terms"] as List).add({
        "term": "term.unbekannt",
        "slides": [1],
      });
      expect(() => parseOldTestament(json), throwsFormatException);
    });
  });

  group("Erweiterung um weitere Einheiten", () {
    final json = oldTestamentJson()..units.add(fakeSecondUnit());
    final extended = parseOldTestament(json);

    test("zweite Einheit wird geladen und verknüpft", () {
      expect(extended.units.map((u) => u.id), ["unit.01", "unit.02"]);
      expect(extended.relatedUnitsOf("unit.01").map((u) => u.id), ["unit.02"]);
      // Ein Begriff, zwei Einheiten – kein doppelter Eintrag.
      expect(extended.unitsOfTerm("term.tora").map((u) => u.id), [
        "unit.01",
        "unit.02",
      ]);
    });

    test("bestehende Karten bleiben gültig, Begriffe nicht doppelt", () {
      final before = OldTestamentQuiz(
        data: data,
      ).candidates(OtScope.all, _allKinds).map((c) => c.cardId).toSet();
      final after = OldTestamentQuiz(
        data: extended,
      ).candidates(OtScope.all, _allKinds).map((c) => c.cardId).toList();

      expect(after.toSet().containsAll(before), isTrue);
      expect(after.toSet().length, after.length);
      expect(after, contains("q.u02.test|lecture"));
    });

    test("gespeicherter Umfang einer Einheit bleibt lesbar", () {
      expect(OtScope.parse("unit:unit.02", extended), OtScope.unit("unit.02"));
      // Unbekannte Einheit: zurück auf alle.
      expect(OtScope.parse("unit:unit.02", data), OtScope.all);
      expect(OtScope.parse(null, data), OtScope.all);
    });
  });

  group("Lernfragen", () {
    final quiz = OldTestamentQuiz(data: data);
    final questions = _build(quiz);

    test("jede Aufgabenart außer Bibelstellen kommt vor", () {
      // Nur zwei Bibelstellen auf den Folien: zu wenige für eindeutige
      // Ablenker, deshalb keine automatisch erzeugten Stellenfragen.
      expect(questions.map((q) => q.kind).toSet(), {
        OtQuizKind.lecture,
        OtQuizKind.term,
        OtQuizKind.recall,
        OtQuizKind.order,
      });
    });

    test("Auswahlfragen: eindeutige Optionen, genau eine richtig", () {
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        expect(q.options.length, greaterThanOrEqualTo(3), reason: q.prompt);
        expect(q.options.toSet().length, q.options.length, reason: q.prompt);
        expect(q.isCorrect(q.correctIndex), isTrue);
        expect(q.explanation.trim(), isNotEmpty, reason: q.prompt);
        expect(q.slides, isNotEmpty, reason: q.prompt);
      }
    });

    test("Begriffsfragen verraten den Begriff nicht", () {
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        if (q.kind != OtQuizKind.term) continue;
        final term = data.term(q.termIds.single)!;
        if (q.cardId.endsWith("|name")) {
          expect(
            q.prompt.toLowerCase(),
            isNot(contains(term.name.toLowerCase())),
            reason: q.prompt,
          );
        } else {
          for (final o in q.options) {
            expect(
              o.toLowerCase(),
              isNot(contains(term.name.toLowerCase())),
              reason: o,
            );
          }
        }
      }
    });

    test("verwechselbare Begriffe sind keine Ablenker", () {
      final tora = data.term("term.tora")!;
      final pentateuch = data.term("term.pentateuch")!;
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        if (q.cardId == "term.tora|name") {
          expect(q.options, isNot(contains(pentateuch.display)));
        }
        if (q.cardId == "term.pentateuch|name") {
          expect(q.options, isNot(contains(tora.display)));
        }
      }
    });

    test("Ordnen: nie schon richtig sortiert, Bewertung je Punkt", () {
      for (final q in questions.whereType<OtOrderQuestion>()) {
        expect(q.items, isNot(orderedEquals(q.list.items)));
        expect(q.isCorrect(q.list.items), isTrue);
        expect(q.isCorrect(q.items), isFalse);
      }
      // Jahreszahlen stehen nicht in den zu ordnenden Punkten.
      final history = unit.lists.firstWhere(
        (l) => l.id == "list.u01.geschichte",
      );
      for (final item in history.items) {
        expect(RegExp(r'\d').hasMatch(item), isFalse, reason: item);
      }
    });

    test("umstrittene Datierung ist als Position gekennzeichnet", () {
      final q = unit.questions.firstWhere(
        (q) => q.id == "q.u01.pentateuch_zeit",
      );
      expect(q.prompt, contains("die Vorlesung"));
      expect(q.explanation, contains("nicht unumstritten"));
    });

    test("Umfang einer Einheit enthält nur ihre Inhalte", () {
      final extended = parseOldTestament(
        oldTestamentJson()..units.add(fakeSecondUnit()),
      );
      final q = OldTestamentQuiz(data: extended);
      final ids = q
          .candidates(const OtScope.unit("unit.02"), _allKinds)
          .map((c) => c.cardId);
      expect(ids, containsAll(["q.u02.test|lecture", "term.tora|term"]));
      expect(ids.where((id) => id.startsWith("q.u01.")), isEmpty);
    });

    test("Antworten verändern die Karte, schwierige Inhalte", () {
      var now = DateTime(2026, 10, 22, 8);
      final q = OldTestamentQuiz(
        data: data,
        random: Random(1),
        algorithm: SpacedRepetition(clock: () => now),
      );
      final question = q.next(OtScope.all, {OtQuizKind.lecture})!;

      q.record(question, false);
      expect(q.isDifficult(question.cardId), isTrue);
      expect(
        q.next(OtScope.all, {OtQuizKind.lecture}, onlyDifficult: true)!.cardId,
        question.cardId,
      );

      // Sichere Antworten mit Abstand nehmen den Inhalt wieder heraus.
      now = now.add(const Duration(days: 1));
      q.record(question, true);
      now = now.add(const Duration(days: 3));
      q.record(question, true);
      expect(q.isDifficult(question.cardId), isFalse);
      expect(
        q.next(OtScope.all, {OtQuizKind.lecture}, onlyDifficult: true),
        isNull,
      );
    });

    test("gemeinsame Schwelle mit der Kirchengeschichte", () {
      expect(ChurchHistoryQuiz.difficultThreshold, difficultThreshold);
    });

    test("Fortschritt ohne Punkte: nur drei Zustände", () {
      final algorithm = SpacedRepetition();
      final card = LearningCard(id: "x");
      expect(ReviewState.of(card, algorithm), ReviewState.fresh);
      algorithm.answer(card, true);
      expect(ReviewState.of(card, algorithm), ReviewState.stable);
    });
  });

  group("Bibelstellen", () {
    test("alle Stellen der Folien lassen sich aufschlagen", () {
      for (final u in data.units) {
        for (final p in u.passages) {
          final passage = biblePassageOf(p);
          expect(passage, isNotNull, reason: p.label);
          expect(BibleBooks.byId(passage!.reference.bookId), isNotNull);
        }
      }
    });

    test("2 Kor 3,14 und 1 Makk 12,9 werden richtig gelesen", () {
      final kor = unit.passages.firstWhere((p) => p.label == "2 Kor 3,14");
      final makk = unit.passages.firstWhere((p) => p.label == "1 Makk 12,9");

      final a = biblePassageOf(kor)!.reference;
      expect((a.bookId, a.chapter, a.verse), ("2CO", 3, 14));
      final b = biblePassageOf(makk)!.reference;
      expect((b.bookId, b.chapter, b.verse), ("1MA", 12, 9));
    });
  });

  group("Speicherung", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Lernstand und Einstellungen überstehen einen Neustart", () async {
      final card = LearningCard(id: "q.u01.luther|lecture");
      SpacedRepetition().answer(card, false);

      await LocalOldTestamentStore().saveCards([card]);
      await LocalOldTestamentStore().saveSettings(
        const OldTestamentSettings(
          scope: "unit:unit.01",
          disabledKinds: {OtQuizKind.order},
          onlyDifficult: true,
        ),
      );

      // Neuer Store = neuer App-Start; gelesen wird aus shared_preferences.
      final cards = await LocalOldTestamentStore().loadCards();
      expect(cards[card.id]!.difficulty, card.difficulty);
      expect(cards[card.id]!.lastReviewed, isNotNull);

      final settings = await LocalOldTestamentStore().loadSettings();
      expect(settings.scope, "unit:unit.01");
      expect(settings.kinds, _allKinds.difference({OtQuizKind.order}));
      expect(settings.onlyDifficult, isTrue);
    });

    test("neue Aufgabenarten sind von selbst aktiv", () {
      final s = OldTestamentSettings.fromMap({
        "disabledKinds": ["recall", "unbekannt"],
      });
      expect(s.kinds, _allKinds.difference({OtQuizKind.recall}));
    });

    test("kaputte Einstellungen fallen auf die Vorgaben zurück", () {
      final s = OldTestamentSettings.fromMap({
        "scope": 3,
        "disabledKinds": [for (final k in OtQuizKind.values) k.name],
      });
      expect(s.scope, "all");
      expect(s.kinds, _allKinds);
      expect(OldTestamentSettings.fromMap(null).onlyDifficult, isFalse);
    });

    test("Zurücksetzen einzelner Karten", () async {
      final store = LocalOldTestamentStore();
      await store.saveCards([LearningCard(id: "a"), LearningCard(id: "b")]);
      await store.resetCards(["a"]);
      expect((await store.loadCards()).keys, ["b"]);
    });

    test(
      "Bereich zurücksetzen löscht Lernstand, nicht Einstellungen",
      () async {
        final store = LocalOldTestamentStore();
        await store.saveCards([LearningCard(id: "a")]);
        await store.saveSettings(
          const OldTestamentSettings(onlyDifficult: true),
        );

        await ProgressDataService().resetArea(null, ProgressArea.oldTestament);

        expect(await store.loadCards(), isEmpty);
        expect((await store.loadSettings()).onlyDifficult, isTrue);
      },
    );

    test("Kirchengeschichte bleibt beim Zurücksetzen unberührt", () async {
      await LocalLearningStore.instance.mergeQuizDocument(
        LocalLearningStore.churchHistory,
        "cards",
        {"x|lecture": LearningCard(id: "x|lecture").toJson()},
      );
      await ProgressDataService().resetArea(null, ProgressArea.oldTestament);

      final doc = await LocalLearningStore.instance.loadQuizDocument(
        LocalLearningStore.churchHistory,
      );
      expect((doc["cards"] as Map).keys, ["x|lecture"]);
    });

    test("ohne Anmeldung lokal, Gastdaten werden übernommen", () {
      expect(OldTestamentStore.forUser(null), isA<LocalOldTestamentStore>());
      expect(
        LocalLearningStore.quizDocuments,
        containsAll([
          LocalLearningStore.oldTestament,
          LocalLearningStore.oldTestamentSettings,
        ]),
      );
    });
  });

  group("Einbindung", () {
    test("Statistik, Serie, Deep Link und bestehende Bereiche", () {
      expect(StatisticsTrainer.all, contains(StatisticsTrainer.oldTestament));
      expect(StreakTrack.all, contains(StreakTrack.oldTestament));
      expect(StreakTrack.all, contains(StreakTrack.churchHistory));
      expect(StreakTrack.oldTestament.sources, [StreakSource.oldTestamentQuiz]);
      expect(AppDeepLink.oldTestament, "/old-testament");
      expect(AppDeepLink.churchHistory, "/church-history");
      expect(
        StatisticsTrainer.all.map((t) => t.id).toSet().length,
        StatisticsTrainer.all.length,
      );
    });
  });
}
