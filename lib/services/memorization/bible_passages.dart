/// Kuratierte Bibelstellen für „Texte auswendig lernen“.
///
/// Wortlaut aus der mitgelieferten Lutherbibel 1912 (`deu1912`, gemeinfrei,
/// siehe docs/bible-sources.md), unverändert; je Vers ein Abschnitt. Die
/// Verszahlen folgen der Zählung dieser Ausgabe (bei Psalmen wie in den
/// englischen Bibeln, Überschrift im ersten Vers).
///
/// Die [id] ist stabil und Teil der Lernstand-IDs
/// (`bible.<id>.de.v<Vers>`): nie umbenennen. Neue Stellen dürfen
/// hinzukommen; der Test `memorization_bible_test.dart` prüft jede Stelle
/// gegen den Text.
class BiblePassage {
  final String id;
  final String title;

  /// Buch-ID wie in `assets/bible/<Ausgabe>/<Buch>.json`, z. B. `PSA`.
  final String bookId;
  final int chapter;
  final int fromVerse;
  final int toVerse;
  final bool oldTestament;

  const BiblePassage({
    required this.id,
    required this.title,
    required this.bookId,
    required this.chapter,
    required this.fromVerse,
    required this.toVerse,
    required this.oldTestament,
  });

  static const String translationId = "deu1912";
  static const String languageCode = "de";
  static const String edition = "Lutherbibel 1912";

  static const List<BiblePassage> all = [
    BiblePassage(
      id: "1_mose_12_1_3",
      title: "1. Mose 12,1–3",
      bookId: "GEN",
      chapter: 12,
      fromVerse: 1,
      toVerse: 3,
      oldTestament: true,
    ),
    BiblePassage(
      id: "2_mose_3_14",
      title: "2. Mose 3,14",
      bookId: "EXO",
      chapter: 3,
      fromVerse: 14,
      toVerse: 14,
      oldTestament: true,
    ),
    BiblePassage(
      id: "2_mose_34_6",
      title: "2. Mose 34,6",
      bookId: "EXO",
      chapter: 34,
      fromVerse: 6,
      toVerse: 6,
      oldTestament: true,
    ),
    BiblePassage(
      id: "3_mose_19_2",
      title: "3. Mose 19,2",
      bookId: "LEV",
      chapter: 19,
      fromVerse: 2,
      toVerse: 2,
      oldTestament: true,
    ),
    BiblePassage(
      id: "3_mose_19_18",
      title: "3. Mose 19,18",
      bookId: "LEV",
      chapter: 19,
      fromVerse: 18,
      toVerse: 18,
      oldTestament: true,
    ),
    BiblePassage(
      id: "psalm_1",
      title: "Psalm 1",
      bookId: "PSA",
      chapter: 1,
      fromVerse: 1,
      toVerse: 6,
      oldTestament: true,
    ),
    BiblePassage(
      id: "psalm_23",
      title: "Psalm 23",
      bookId: "PSA",
      chapter: 23,
      fromVerse: 1,
      toVerse: 6,
      oldTestament: true,
    ),
    BiblePassage(
      id: "psalm_121",
      title: "Psalm 121",
      bookId: "PSA",
      chapter: 121,
      fromVerse: 1,
      toVerse: 8,
      oldTestament: true,
    ),
    BiblePassage(
      id: "jesaja_53_4_5",
      title: "Jesaja 53,4–5",
      bookId: "ISA",
      chapter: 53,
      fromVerse: 4,
      toVerse: 5,
      oldTestament: true,
    ),
    BiblePassage(
      id: "micha_6_8",
      title: "Micha 6,8",
      bookId: "MIC",
      chapter: 6,
      fromVerse: 8,
      toVerse: 8,
      oldTestament: true,
    ),
    BiblePassage(
      id: "matthaeus_11_28_30",
      title: "Matthäus 11,28–30",
      bookId: "MAT",
      chapter: 11,
      fromVerse: 28,
      toVerse: 30,
      oldTestament: false,
    ),
    BiblePassage(
      id: "matthaeus_28_18_20",
      title: "Matthäus 28,18–20",
      bookId: "MAT",
      chapter: 28,
      fromVerse: 18,
      toVerse: 20,
      oldTestament: false,
    ),
    BiblePassage(
      id: "johannes_1_1_14",
      title: "Johannes 1,1–14",
      bookId: "JHN",
      chapter: 1,
      fromVerse: 1,
      toVerse: 14,
      oldTestament: false,
    ),
    BiblePassage(
      id: "johannes_3_16",
      title: "Johannes 3,16",
      bookId: "JHN",
      chapter: 3,
      fromVerse: 16,
      toVerse: 16,
      oldTestament: false,
    ),
    BiblePassage(
      id: "roemer_1_16_17",
      title: "Römer 1,16–17",
      bookId: "ROM",
      chapter: 1,
      fromVerse: 16,
      toVerse: 17,
      oldTestament: false,
    ),
    BiblePassage(
      id: "roemer_3_21_28",
      title: "Römer 3,21–28",
      bookId: "ROM",
      chapter: 3,
      fromVerse: 21,
      toVerse: 28,
      oldTestament: false,
    ),
    BiblePassage(
      id: "roemer_8_38_39",
      title: "Römer 8,38–39",
      bookId: "ROM",
      chapter: 8,
      fromVerse: 38,
      toVerse: 39,
      oldTestament: false,
    ),
    BiblePassage(
      id: "1_korinther_13",
      title: "1. Korinther 13",
      bookId: "1CO",
      chapter: 13,
      fromVerse: 1,
      toVerse: 13,
      oldTestament: false,
    ),
    BiblePassage(
      id: "epheser_2_8_9",
      title: "Epheser 2,8–9",
      bookId: "EPH",
      chapter: 2,
      fromVerse: 8,
      toVerse: 9,
      oldTestament: false,
    ),
    BiblePassage(
      id: "philipper_2_5_11",
      title: "Philipper 2,5–11",
      bookId: "PHP",
      chapter: 2,
      fromVerse: 5,
      toVerse: 11,
      oldTestament: false,
    ),
  ];
}
