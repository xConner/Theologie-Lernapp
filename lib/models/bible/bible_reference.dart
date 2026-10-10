/// Eine Bibelstelle: ein Kapitel, ein Kapitelbereich oder ein Versbereich
/// innerhalb eines Buchs.
///
/// Ohne [verse] ist das ganze Kapitel gemeint (bzw. die Kapitel bis
/// [endChapter]). Die Stelle sagt nichts darüber, ob es sie in einer
/// bestimmten Ausgabe gibt – das prüft der Reader an der Ausgabe.
class BibleReference {
  /// Buchkennung nach USFM (siehe `BibleBooks`).
  final String bookId;

  final int chapter;
  final int? verse;

  final int endChapter;

  /// Letzter Vers; `null` bei Kapitelangaben und bei „bis Kapitelende“.
  final int? endVerse;

  /// Ein Versbereich ohne festes Ende („Mk 4,35ff“).
  final bool openEnd;

  const BibleReference({
    required this.bookId,
    required this.chapter,
    this.verse,
    int? endChapter,
    this.endVerse,
    this.openEnd = false,
  }) : endChapter = endChapter ?? chapter;

  const BibleReference.chapter(this.bookId, this.chapter)
    : verse = null,
      endChapter = chapter,
      endVerse = null,
      openEnd = false;

  bool get hasVerses => verse != null;

  bool get spansChapters => endChapter != chapter;

  /// Ob Vers [number] in Kapitel [inChapter] zur Stelle gehört.
  bool containsVerse(int inChapter, int number) {
    if (inChapter < chapter || inChapter > endChapter) return false;

    final start = verse;

    if (start == null) return true;

    if (inChapter == chapter && number < start) return false;

    if (inChapter == endChapter && !openEnd) {
      final end = endVerse ?? start;

      if (number > end) return false;
    }

    return true;
  }

  /// Erster Vers der Stelle in [inChapter], `null` wenn das Kapitel als
  /// Ganzes dazugehört.
  int? firstVerseIn(int inChapter) {
    if (verse == null) return null;

    return inChapter == chapter ? verse : 1;
  }

  /// Kapitel und Verse in deutscher Schreibweise, z. B. „4,35–41“.
  String get rangeText {
    final start = verse;

    if (start == null) {
      return spansChapters ? "$chapter–$endChapter" : "$chapter";
    }

    if (openEnd) return "$chapter,${start}ff";

    final end = endVerse ?? start;

    if (spansChapters) return "$chapter,$start–$endChapter,$end";

    return end == start ? "$chapter,$start" : "$chapter,$start–$end";
  }

  @override
  bool operator ==(Object other) {
    return other is BibleReference &&
        other.bookId == bookId &&
        other.chapter == chapter &&
        other.verse == verse &&
        other.endChapter == endChapter &&
        other.endVerse == endVerse &&
        other.openEnd == openEnd;
  }

  @override
  int get hashCode =>
      Object.hash(bookId, chapter, verse, endChapter, endVerse, openEnd);

  @override
  String toString() => "$bookId $rangeText";
}

/// Eine Stelle, die der Reader hervorgehoben öffnen soll, z. B. eine
/// Perikope aus dem Quiz.
class BiblePassage {
  /// Angabe, wie sie dem Nutzer bekannt ist, z. B. „Mk 4,35-41“.
  final String label;

  final BibleReference reference;

  /// Versgruppen einer Stelle mit Lücken, z. B. „Ps 50,1-6.14-15.23“.
  /// [reference] reicht dann vom ersten bis zum letzten Vers; hervorgehoben
  /// werden nur diese Gruppen. Leer bei einer zusammenhängenden Stelle.
  final List<BibleReference> parts;

  const BiblePassage({
    required this.label,
    required this.reference,
    this.parts = const [],
  });
}
