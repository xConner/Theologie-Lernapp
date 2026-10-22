import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/bible/bible_text.dart';
import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/memorization/bible_passages.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';

/// Bibelstellen in „Texte auswendig lernen“: jede kuratierte Stelle ist im
/// Katalog, Wortlaut aus der Lutherbibel 1912, je Vers ein Abschnitt mit
/// stabiler ID.

class _FailingSource implements BibleTextSource {
  @override
  Future<BibleBookText> loadBook(String translationId, String bookId) =>
      Future.error(StateError("kein Text"));

  @override
  Future<Never> loadTranslations() => Future.error(StateError("nichts"));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorizationCatalog catalog;

  setUpAll(() async {
    catalog = await MemorizationCatalog.load(
      bible: const AssetBibleTextSource(),
    );
  });

  test("IDs der Stellen sind eindeutig und gültig", () {
    final ids = BiblePassage.all.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final p in BiblePassage.all) {
      expect(p.id, matches(RegExp(r"^[a-z0-9_]+$")), reason: p.id);
      expect(p.fromVerse, lessThanOrEqualTo(p.toVerse), reason: p.id);
    }
  });

  test("jede Stelle ist im Katalog, wortgetreu und vollständig", () async {
    const source = AssetBibleTextSource();

    for (final passage in BiblePassage.all) {
      final work = catalog.work("bible.${passage.id}");
      expect(work, isNotNull, reason: passage.id);
      expect(work!.type, MemorizationTextType.bible);
      expect(work.versions, hasLength(1));

      final text = work.versions.single;
      expect(text.id, "bible.${passage.id}.de");
      expect(text.languageCode, "de");

      final book = await source.loadBook("deu1912", passage.bookId);
      final verses = book.chapter(passage.chapter)!.verses;

      expect(
        [for (final s in text.segments) s.id],
        [
          for (var v = passage.fromVerse; v <= passage.toVerse; v++)
            "bible.${passage.id}.de.v$v",
        ],
      );

      for (final segment in text.segments) {
        final number = int.parse(segment.id.split(".v").last);
        final original = verses
            .where((v) => v.number == number)
            .map((v) => v.text)
            .join(" ")
            .replaceAll(RegExp(r"\s+"), " ")
            .trim();
        expect(segment.text, original, reason: segment.id);
        expect(segment.text, isNotEmpty);
      }
    }
  });

  test("Stichproben des Wortlauts", () {
    final psalm = catalog.text("bible.psalm_23.de")!;
    expect(
      psalm.segments.first.text,
      "Ein Psalm Davids. Der HERR ist mein Hirte; mir wird nichts mangeln.",
    );
    expect(psalm.segments, hasLength(6));

    final romans = catalog.text("bible.roemer_3_21_28.de")!;
    expect(romans.segments.last.text, endsWith("allein durch den Glauben."));

    expect(
      catalog.work("bible.johannes_3_16")!.group,
      "Neues Testament (Lutherbibel 1912)",
    );
  });

  test("fehlender Vers: Stelle entfällt; Teile eines Verses werden "
      "zusammengeführt", () {
    const passage = BiblePassage(
      id: "test",
      title: "Test",
      bookId: "TST",
      chapter: 1,
      fromVerse: 1,
      toVerse: 2,
      oldTestament: false,
    );

    const split = BibleBookText("TST", [
      BibleChapter(1, [
        BibleVerse(number: 1, text: "Erster Teil"),
        BibleVerse(number: 1, text: "zweiter\n\tTeil.", continuation: true),
        BibleVerse(number: 2, text: "Zwei."),
      ]),
    ]);

    final work = MemorizationCatalog.fromBiblePassage(passage, split)!;
    expect(
      [for (final s in work.versions.single.segments) s.text],
      ["Erster Teil zweiter Teil.", "Zwei."],
    );

    const missing = BibleBookText("TST", [
      BibleChapter(1, [BibleVerse(number: 1, text: "Eins.")]),
    ]);
    expect(MemorizationCatalog.fromBiblePassage(passage, missing), isNull);
  });

  test("ohne Bibeltexte bleiben Gebete und Bekenntnisse nutzbar", () async {
    final withoutBible = await MemorizationCatalog.load(
      bible: _FailingSource(),
    );

    expect(
      withoutBible.works.where((w) => w.type == MemorizationTextType.bible),
      isEmpty,
    );
    expect(
      withoutBible.works.where((w) => w.type == MemorizationTextType.prayer),
      isNotEmpty,
    );
  });
}
