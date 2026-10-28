import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/philosophy/reading_text.dart';
import 'package:theologie_lernapp/models/philosophy/reading_work.dart';
import 'package:theologie_lernapp/services/philosophy/reading_repository.dart';

import 'reading_fixture.dart';

ReadingWork testWork() => ReadingWork.fromJson({
  "id": "aristotle.physics",
  "author": "Aristoteles",
  "title": "Physik",
  "originalTitle": "Φυσικὴ ἀκρόασις",
  "description": ["Test"],
  "citation": "Bekker",
  "formsAsset": "assets/philosophy/aristotle_physics/forms.json",
  "books": [
    {"n": 1, "label": "I"},
  ],
  "editions": [
    {
      "id": "heinemann-2021",
      "kind": "private",
      "title": "Testausgabe",
      "short": "Test",
      "languages": ["grc", "de"],
      "books": [1],
      "rights": "privat",
    },
  ],
});

ReadingText fixtureText() {
  final work = testWork();
  return ReadingText.fromEditionJson(
    work,
    work.edition("heinemann-2021")!,
    privateEditionFixture(),
  );
}

void main() {
  group("BekkerRef", () {
    test("liest und ordnet Stellen", () {
      final a = BekkerRef.parse("184a10");
      expect(a.page, 184);
      expect(a.column, "a");
      expect(a.line, 10);
      expect("$a", "184a10");
      expect(BekkerRef.parse("184a35") < BekkerRef.parse("184b1"), isTrue);
      expect(BekkerRef.parse("184b30") < BekkerRef.parse("185a1"), isTrue);
      expect(BekkerRef.tryParse("Kapitel 1"), isNull);
      expect(BekkerRef.parse("184a10"), BekkerRef.parse("184a10"));
    });

    test("Bereiche: enthält, überschneidet, Kurzform", () {
      final r = BekkerRange(BekkerRef.parse("184a10"), BekkerRef.parse("184a16"));
      expect(r.contains(BekkerRef.parse("184a12")), isTrue);
      expect(r.contains(BekkerRef.parse("184a17")), isFalse);
      expect(
        r.overlaps(BekkerRange.single(BekkerRef.parse("184a16"))),
        isTrue,
      );
      expect(r.label, "184a10–16");
      expect(
        BekkerRange(BekkerRef.parse("184a30"), BekkerRef.parse("184b2")).label,
        "184a30–b2",
      );
    });
  });

  group("Private Ausgabe", () {
    final text = fixtureText();

    test("Abschnitte, Sätze und Kapitel sind verknüpft", () {
      expect(text.chapters, hasLength(1));
      expect(text.chapters.first.id, "1.1");
      expect(text.sentence("184a18")!.text, startsWith("οὐ γὰρ"));
      expect(text.unitOfSentence("184a18")!.id, "184a16");
      expect(text.chapterOfSentence("184a18")!.id, "1.1");
    });

    test("ungefähre Zuordnung bleibt gekennzeichnet", () {
      final exact = text.unit("184a10")!;
      final approx = text.unit("184a16")!;
      expect(exact.exact, isTrue);
      expect(approx.exact, isFalse);
      expect(approx.oneToOne, isFalse);
      expect(approx.german.single.text, contains("C"));
    });

    test("Anmerkungen hängen an überlappenden Sätzen", () {
      final first = text.notesForSentence(text.sentence("184a10")!);
      expect(first.map((n) => n.id), ["n1.1"]);
      expect(first.single.introSections, ["1.1"]);

      final second = text.notesForSentence(text.sentence("184a16")!);
      expect(second.map((n) => n.kind), [
        EditionNoteKind.textCritical,
        EditionNoteKind.editor,
        EditionNoteKind.translator,
      ]);
      // Fußnote zur Übersetzung nur am ersten Satz des Abschnitts.
      final third = text.notesForSentence(text.sentence("184a18")!);
      expect(third.where((n) => n.kind == EditionNoteKind.translator), isEmpty);

      final tc = text.note("tc1.1")!;
      expect(tc.noteRefs, [BekkerRef.parse("184a10")]);
      expect(text.editorNoteAt(tc.noteRefs.single)!.id, "n1.1");
      expect(text.hasTextCritical(text.sentence("184a16")!), isTrue);
      expect(text.hasTextCritical(text.sentence("184a10")!), isFalse);
    });

    test("Einleitung: Zitate, Abschnitte, Fußnoten", () {
      expect(
        text.citationsFor(text.sentence("184a10")!).single.section,
        "1",
      );
      expect(text.front.section("1.1.1")!.id, "1.1");
      expect(text.front.section("9"), isNull);
      expect(text.front.intro.first.footnotes.single.number, 1);
      expect(text.front.glossary.first.renderings, ["Prinzip", "Anfang"]);
    });

    test("gespeicherte Stellen lösen sich auch ohne genaue Kennung auf", () {
      expect(text.resolveSentence("184a17")!.id, "184a16");
      expect(text.resolveSentence("184a10")!.id, "184a10");
      expect(text.sentenceAt(BekkerRef.parse("184a20"))!.id, "184a18");
      expect(
        text.sentencesIn(
          BekkerRange(BekkerRef.parse("184a15"), BekkerRef.parse("184a17")),
        ).map((s) => s.id),
        ["184a10", "184a16"],
      );
    });
  });
}
