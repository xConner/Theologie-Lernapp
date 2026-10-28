import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/services/philosophy/greek_word_analyzer.dart';
import 'package:theologie_lernapp/services/philosophy/private_edition_store.dart';
import 'package:theologie_lernapp/services/philosophy/reading_export.dart';
import 'package:theologie_lernapp/services/philosophy/reading_repository.dart';
import 'package:theologie_lernapp/services/philosophy/reading_review.dart';
import 'package:theologie_lernapp/services/philosophy/reading_search.dart';
import 'package:theologie_lernapp/services/philosophy/reading_user_data.dart';
import 'package:theologie_lernapp/services/quiz_documents.dart';

import 'reading_fixture.dart';
import 'reading_text_test.dart' show fixtureText, testWork;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Suche", () {
    final text = fixtureText();

    test("Griechisch ohne Akzente und Hauchzeichen", () {
      final hits = ReadingSearch.search(text, "επισταςθαι".replaceAll("ς", "σ"));
      expect(hits.first.kind, ReadingHitKind.greek);
      expect(hits.first.sentenceId, "184a10");
      expect(
        ReadingSearch.search(text, "ΟΔΟΣ").map((h) => h.sentenceId),
        contains("184a16"),
      );
    });

    test("Deutsch, Anmerkungen, Einleitung, Glossar", () {
      final german = ReadingSearch.search(text, "übersetzung c");
      expect(german.single.kind, ReadingHitKind.german);
      expect(german.single.sentenceId, "184a16");

      final kinds = ReadingSearch.search(text, "Platzhalter").map((h) => h.kind).toSet();
      expect(kinds, containsAll([ReadingHitKind.german, ReadingHitKind.note]));
      expect(
        ReadingSearch.search(text, "Prinzipien").single.kind,
        ReadingHitKind.intro,
      );
      expect(
        ReadingSearch.search(text, "archê").first.glossaryId,
        "g1",
      );
      expect(ReadingSearch.search(text, "a"), isEmpty);
    });
  });

  group("Wortanalyse", () {
    test("Umschrift wie im Glossar der Ausgabe", () {
      expect(GreekWordAnalyzer.transliterate("ἀρχή"), "archê");
      expect(GreekWordAnalyzer.transliterate("ὕλη"), "hylê");
      expect(GreekWordAnalyzer.transliterate("τῇ"), "têi");
      expect(GreekWordAnalyzer.transliterate("αὑτό"), "hauto");
      expect(GreekWordAnalyzer.transliterate("ἐντελέχεια"), "entelecheia");
      expect(GreekWordAnalyzer.transliterate("ἄγγελος"), "angelos");
      expect(GreekWordAnalyzer.transliterate("ῥοπή"), "rhopê");
      expect(GreekWordAnalyzer.transliterate("οὐσία"), "ousia");
      expect(GreekWordAnalyzer.glossaryKey("to hou heneka"), "hou heneka");
    });

    test("mögliche Bestimmung, Glossar und Vorkommen", () async {
      final text = fixtureText();
      final analyzer = await GreekWordAnalyzer.load(ReadingRepository(), text);

      final archai = analyzer.analyze("ἀρχαὶ");
      expect(archai.isAnalyzed, isTrue);
      expect(archai.candidates.map((c) => c.lemma), contains("ἀρχή"));
      expect(archai.glossary.map((g) => g.id), ["g1"]);

      final unknown = analyzer.analyze("ἐπίστασθαι");
      // Nicht im Formenindex: keine geratene Bestimmung.
      if (!unknown.isAnalyzed) {
        expect(unknown.candidates, isEmpty);
        expect(unknown.certainLemma, isNull);
      }

      final hodos = analyzer.analyze("ὁδός");
      expect(hodos.certainLemma, "ὁδός");
      expect(
        analyzer.occurrences(text, lemma: "ὁδός", form: hodos.form).map((s) => s.id),
        ["184a16"],
      );
      // Satzzeichen bleiben am Wort; die Analyse sieht sie nicht.
      expect(GreekWordAnalyzer.words("ἡ ὁδός."), ["ἡ", "ὁδός."]);
      expect(analyzer.analyze("ὁδός.").certainLemma, "ὁδός");
    });
  });

  group("Persönliche Daten", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Modus, Position, Notizen, Wortliste, gelesene Kapitel", () async {
      final docs = QuizDocuments.forUser(null);
      final data = ReadingUserData(docs, "aristotle.physics");
      final other = ReadingUserData(docs, "aristotle.metaphysics");

      await data.setMode(ReadingMode.sideBySide);
      await data.setEdition("heinemann-2021");
      await data.setPosition("184a16");
      await data.saveMark("s:184a10", bookmark: true, note: "  Anfang  ");
      await data.saveMark("w:184a16:5:ὁδός", bookmark: false, note: "Weg");
      await data.addWord(form: "ἀρχαὶ", lemma: "ἀρχή", sentenceId: "184a10");
      await data.setChapterRead("1.1", true);
      await other.setMode(ReadingMode.german);

      final state = await data.load();
      expect(state.mode, ReadingMode.sideBySide);
      expect(state.edition, "heinemann-2021");
      expect(state.position, "184a16");
      expect(state.bookmarks.single.anchor, "s:184a10");
      expect(state.marks["s:184a10"]!.note, "Anfang");
      expect(state.marks["w:184a16:5:ὁδός"]!.word, "ὁδός");
      expect(state.marks["w:184a16:5:ὁδός"]!.sentenceId, "184a16");
      expect(state.marksOfSentence("184a16"), hasLength(1));
      expect(state.words["ἀρχή"]!.form, "ἀρχαὶ");
      expect(state.readChapters, {"1.1"});
      expect((await other.load()).mode, ReadingMode.german);

      // Leere Stelle wird entfernt; anderes bleibt erhalten.
      await data.saveMark("s:184a10", bookmark: false, note: " ");
      await data.removeWord("ἀρχή");
      await data.setChapterRead("1.1", false);
      final after = await data.load();
      expect(after.marks.keys, ["w:184a16:5:ὁδός"]);
      expect(after.words, isEmpty);
      expect(after.readChapters, isEmpty);
      expect(after.mode, ReadingMode.sideBySide);
    });

    test("unbekannte Felder älterer Fassungen stören nicht", () async {
      final docs = QuizDocuments.forUser(null);
      await docs.mergeEntries(ReadingUserData.document, "marks", {
        "aristotle.physics|s:184a10": "kaputt",
        "aristotle.physics|s:184a16": {"b": true},
      });
      await docs.mergeEntries(ReadingUserData.document, "settings", {
        "aristotle.physics|mode": "gibtsnicht",
        "aristotle.physics|scale": 9,
      });
      final state = await ReadingUserData(docs, "aristotle.physics").load();
      expect(state.marks.keys, ["s:184a16"]);
      expect(state.mode, isNull);
      expect(state.textScale, 1.6);
    });

    test("Ausfuhr enthält nur Stellen und eigene Texte", () async {
      final data = ReadingUserData(QuizDocuments.forUser(null), "aristotle.physics");
      await data.saveMark("s:184a16", bookmark: true, note: "Weg vom Bekannten");
      await data.saveMark("s:184a10", bookmark: true, note: "");
      await data.addWord(form: "ὁδός", lemma: "ὁδός", sentenceId: "184a16");
      final md = ReadingExport.markdown(
        testWork(),
        await data.load(),
        now: DateTime(2026, 10, 28),
      );
      expect(md, contains("Stand: 2026-10-28"));
      expect(md.indexOf("- 184a10"), lessThan(md.indexOf("- 184a16")));
      expect(md, contains("**184a16**: Weg vom Bekannten"));
      expect(md, contains("- ὁδός – 184a16"));
      expect(md, isNot(contains("πέφυκε")));
      expect(md, isNot(contains("Übersetzung C")));
    });
  });

  group("Wiederholung", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Karten aus Glossar, Wortliste, Lesezeichen und Textkritik", () async {
      final text = fixtureText();
      final state = ReadingUserState(
        marks: {
          "s:184a18": ReadingMark(
            anchor: "s:184a18",
            bookmark: true,
            note: "",
            updated: DateTime(2026),
          ),
        },
        words: {
          "ὁδός": WordListEntry(
            key: "ὁδός",
            form: "ὁδός",
            lemma: "ὁδός",
            sentenceId: "184a16",
            added: DateTime(2026),
          ),
        },
      );
      final items = ReadingReviewStore.items(text, state);
      expect(items.map((i) => i.id), [
        "aristotle.physics|term:g1",
        "aristotle.physics|word:ὁδός",
        "aristotle.physics|sent:184a18",
        "aristotle.physics|tc:tc1.1",
      ]);
      expect(items.last.sentence!.id, "184a16");

      final store = ReadingReviewStore(QuizDocuments.forUser(null));
      final cards = await store.load();
      final first = store.next(items, cards)!;
      await store.answer(first, cards, true);
      final reloaded = await ReadingReviewStore(QuizDocuments.forUser(null)).load();
      expect(reloaded[first.id]!.lastReviewed, isNotNull);
      expect(ReadingReviewStore.reviewedCount(items, reloaded), 1);
      expect(store.next(items, reloaded, exclude: {first.id})!.id, isNot(first.id));

      // Lernstand und Leseposition liegen in getrennten Dokumenten.
      final reading = await QuizDocuments.forUser(null).load(ReadingUserData.document);
      expect(reading, isEmpty);
    });
  });

  group("Privater Speicher", () {
    setUp(PrivateEditionStore.clearSession);

    test("prüft Importdateien", () {
      expect(
        () => PrivateEditionStore.validate("{", workId: "aristotle.physics", editionId: "heinemann-2021"),
        throwsFormatException,
      );
      expect(
        () => PrivateEditionStore.validate(
          '{"format":"x"}',
          workId: "aristotle.physics",
          editionId: "heinemann-2021",
        ),
        throwsFormatException,
      );
      expect(
        () => PrivateEditionStore.validate(
          privateEditionFixtureJson(),
          workId: "aristotle.physics",
          editionId: "andere",
        ),
        throwsFormatException,
      );
      final ok = PrivateEditionStore.validate(
        privateEditionFixtureJson(),
        workId: "aristotle.physics",
        editionId: "heinemann-2021",
      );
      expect((ok["books"] as List), hasLength(1));
    });

    test("zerlegt in Teile und setzt verlustfrei zusammen", () {
      final edition = privateEditionFixture();
      final parts = PrivateEditionStore.split(edition);
      expect(parts.keys, containsAll(["meta", "front", "book-1"]));
      final joined = PrivateEditionStore.join(parts);
      expect(joined, edition);
    });

    test("Konto und Gerät: Laden auch nach leerem Gerät", () async {
      final remote = MemoryPrivateEditionBackend();
      final local = MemoryPrivateEditionBackend();
      final store = PrivateEditionStore(uid: "u1", remote: remote, local: local);
      final where = await store.save("heinemann-2021", privateEditionFixture());
      expect(where.account, isTrue);
      expect(where.device, isTrue);

      PrivateEditionStore.clearSession();
      local.data.clear();
      final loaded = await store.load("heinemann-2021");
      expect(loaded, privateEditionFixture());
      expect(local.data.containsKey("heinemann-2021"), isTrue);

      await store.remove("heinemann-2021");
      expect(await store.has("heinemann-2021"), isFalse);
      expect(remote.data, isEmpty);
    });
  });
}
