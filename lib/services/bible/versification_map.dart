import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import 'bible_books.dart';

/// Ein Versbereich, den die englische Zählung an anderer Stelle führt als
/// die deutsche.
class _Shift {
  final String bookId;

  // Deutsche Zählung.
  final int chapter;
  final int from;
  final int to;

  // Englische Zählung: Stelle des ersten Verses.
  final int toChapter;
  final int toVerse;

  const _Shift(
    this.bookId,
    this.chapter,
    this.from,
    this.to,
    this.toChapter,
    this.toVerse,
  );
}

/// Überträgt Stellen der Perikopenliste (deutsche Zählung) in die Zählung
/// einer Ausgabe.
///
/// Im Alten Testament setzen englisch gezählte Ausgaben (auch Luther 1912
/// und Schlachter 1951) einige Kapitelgrenzen anders: 1. Mose 32,1 ist dort
/// 31,55, Joel 3 und 4 sind Joel 2,28–32 und 3. Diese Verschiebungen stehen
/// in [_shifts]. Jede Übertragung wird an den Verszahlen der Ausgabe
/// geprüft; passt sie nicht, gilt die Stelle als nicht sicher übertragbar
/// (`null`), statt an einer falschen Stelle zu landen.
///
/// Nicht übertragen werden die Psalmen (Überschriften zählen dort
/// unterschiedlich), Septuaginta und Vulgata.
class ListVersification {
  ListVersification._();

  // Abweichungen der englischen von der deutschen (hebräischen) Zählung
  // außerhalb der Psalmen. Wo eine Zählung einen Vers teilt, den die andere
  // als einen führt, stehen beide Hälften beim selben Vers
  // (1Sam 21,1; 1Kön 22,44; 1Chr 12,5).
  static const List<_Shift> _shifts = [
    _Shift("GEN", 32, 1, 1, 31, 55),
    _Shift("GEN", 32, 2, 33, 32, 1),
    _Shift("EXO", 7, 26, 29, 8, 1),
    _Shift("EXO", 8, 1, 28, 8, 5),
    _Shift("EXO", 21, 37, 37, 22, 1),
    _Shift("EXO", 22, 1, 30, 22, 2),
    _Shift("LEV", 5, 20, 26, 6, 1),
    _Shift("LEV", 6, 1, 23, 6, 8),
    _Shift("NUM", 17, 1, 15, 16, 36),
    _Shift("NUM", 17, 16, 28, 17, 1),
    _Shift("NUM", 30, 1, 1, 29, 40),
    _Shift("NUM", 30, 2, 17, 30, 1),
    _Shift("DEU", 13, 1, 1, 12, 32),
    _Shift("DEU", 13, 2, 19, 13, 1),
    _Shift("DEU", 23, 1, 1, 22, 30),
    _Shift("DEU", 23, 2, 26, 23, 1),
    _Shift("DEU", 28, 69, 69, 29, 1),
    _Shift("DEU", 29, 1, 28, 29, 2),
    _Shift("1SA", 21, 1, 1, 20, 42),
    _Shift("1SA", 21, 2, 16, 21, 1),
    _Shift("1SA", 24, 1, 1, 23, 29),
    _Shift("1SA", 24, 2, 23, 24, 1),
    _Shift("2SA", 19, 1, 1, 18, 33),
    _Shift("2SA", 19, 2, 44, 19, 1),
    _Shift("1KI", 5, 1, 14, 4, 21),
    _Shift("1KI", 5, 15, 32, 5, 1),
    _Shift("1KI", 22, 44, 44, 22, 43),
    _Shift("1KI", 22, 45, 54, 22, 44),
    _Shift("2KI", 12, 1, 1, 11, 21),
    _Shift("2KI", 12, 2, 22, 12, 1),
    _Shift("1CH", 5, 27, 41, 6, 1),
    _Shift("1CH", 6, 1, 66, 6, 16),
    _Shift("1CH", 12, 5, 5, 12, 4),
    _Shift("1CH", 12, 6, 41, 12, 5),
    _Shift("2CH", 1, 18, 18, 2, 1),
    _Shift("2CH", 2, 1, 17, 2, 2),
    _Shift("2CH", 13, 23, 23, 14, 1),
    _Shift("2CH", 14, 1, 14, 14, 2),
    _Shift("NEH", 3, 33, 38, 4, 1),
    _Shift("NEH", 4, 1, 17, 4, 7),
    _Shift("NEH", 10, 1, 1, 9, 38),
    _Shift("NEH", 10, 2, 40, 10, 1),
    _Shift("JOB", 40, 25, 32, 41, 1),
    _Shift("JOB", 41, 1, 26, 41, 9),
    _Shift("ECC", 4, 17, 17, 5, 1),
    _Shift("ECC", 5, 1, 19, 5, 2),
    _Shift("SNG", 7, 1, 1, 6, 13),
    _Shift("SNG", 7, 2, 14, 7, 1),
    _Shift("ISA", 8, 23, 23, 9, 1),
    _Shift("ISA", 9, 1, 20, 9, 2),
    _Shift("ISA", 64, 1, 11, 64, 2),
    _Shift("JER", 8, 23, 23, 9, 1),
    _Shift("JER", 9, 1, 25, 9, 2),
    _Shift("EZK", 21, 1, 5, 20, 45),
    _Shift("EZK", 21, 6, 37, 21, 1),
    _Shift("DAN", 3, 31, 33, 4, 1),
    _Shift("DAN", 4, 1, 34, 4, 4),
    _Shift("DAN", 6, 1, 1, 5, 31),
    _Shift("DAN", 6, 2, 29, 6, 1),
    _Shift("HOS", 2, 1, 2, 1, 10),
    _Shift("HOS", 2, 3, 25, 2, 1),
    _Shift("HOS", 12, 1, 1, 11, 12),
    _Shift("HOS", 12, 2, 15, 12, 1),
    _Shift("HOS", 14, 1, 1, 13, 16),
    _Shift("HOS", 14, 2, 10, 14, 1),
    _Shift("JOL", 3, 1, 5, 2, 28),
    _Shift("JOL", 4, 1, 21, 3, 1),
    _Shift("JON", 2, 1, 1, 1, 17),
    _Shift("JON", 2, 2, 11, 2, 1),
    _Shift("MIC", 4, 14, 14, 5, 1),
    _Shift("MIC", 5, 1, 14, 5, 2),
    _Shift("NAM", 2, 1, 1, 1, 15),
    _Shift("NAM", 2, 2, 14, 2, 1),
    _Shift("ZEC", 2, 1, 4, 1, 18),
    _Shift("ZEC", 2, 5, 17, 2, 1),
    _Shift("MAL", 3, 19, 24, 4, 1),
  ];

  static final Map<String, List<_Shift>> _byBook = () {
    final result = <String, List<_Shift>>{};

    for (final shift in _shifts) {
      result.putIfAbsent(shift.bookId, () => []).add(shift);
    }

    return result;
  }();

  // Bücher, die eine Zählung durchgehend anders ordnet als die Liste.
  static const Map<BibleVersification, Set<String>> _reordered = {
    BibleVersification.lxx: {"PSA", "PRO", "JER"},
    BibleVersification.vulgate: {"PSA"},
  };

  /// Die Stelle der deutschen Zählung in englischer Zählung, ohne Prüfung
  /// an einer Ausgabe. Gilt nicht für die Psalmen.
  static ({int chapter, int verse}) germanToEnglish(
    String bookId,
    int chapter,
    int verse,
  ) {
    for (final shift in _byBook[bookId] ?? const <_Shift>[]) {
      if (shift.chapter == chapter &&
          verse >= shift.from &&
          verse <= shift.to) {
        return (
          chapter: shift.toChapter,
          verse: shift.toVerse + verse - shift.from,
        );
      }
    }

    return (chapter: chapter, verse: verse);
  }

  /// Das Buch in einer deutsch gezählten Ausgabe aus [translations].
  static BibleBookInfo? germanBook(
    List<BibleTranslation> translations,
    String bookId,
  ) {
    for (final t in translations) {
      if (t.versification == BibleVersification.german) {
        final book = t.book(bookId);

        if (book != null) return book;
      }
    }

    return null;
  }

  /// Ob die Verse, die [_shifts] aus der deutschen Zählung nach Kapitel
  /// [chapter] der englisch gezählten Ausgabe überträgt, dort genau bis zum
  /// letzten Vers reichen. Zählt die Ausgabe das Kapitel anders (etwa weil
  /// sie Verse zusammenzieht), ist die Übertragung nicht verlässlich.
  static bool _fits(
    BibleBookInfo german,
    BibleBookInfo book,
    String bookId,
    int chapter,
  ) {
    int last = 0;

    // Eine Verschiebung reicht höchstens ins Nachbarkapitel.
    for (int c = chapter - 1; c <= chapter + 1; c++) {
      for (int v = 1; v <= german.verseCount(c); v++) {
        final target = germanToEnglish(bookId, c, v);

        if (target.chapter == chapter && target.verse > last) {
          last = target.verse;
        }
      }
    }

    return last > 0 && last == book.verseCount(chapter);
  }

  /// Wo Vers [verse] in Kapitel [chapter] der Perikopenliste in
  /// [translation] steht; `null`, wenn sich das nicht sicher sagen lässt.
  ///
  /// Im Neuen Testament und in Ausgaben mit deutscher Zählung gilt die
  /// Stelle unmittelbar. Englisch gezählte Ausgaben werden über [_shifts]
  /// umgerechnet; in ihren Psalmen (Überschrift in Vers 1) ist nur der
  /// Psalmanfang sicher. Sonst gilt die Stelle nur, wenn Buch und Kapitel
  /// so viele Kapitel bzw. Verse haben wie in einer deutsch gezählten
  /// Ausgabe aus [translations].
  ///
  /// [bookId] ist die Kennung des Buchs in [translation].
  static ({int chapter, int verse})? locate({
    required BibleTranslation translation,
    required List<BibleTranslation> translations,
    required String bookId,
    required int chapter,
    required int verse,
  }) {
    final book = translation.book(bookId);

    if (book == null) return null;

    final same = (chapter: chapter, verse: verse);

    if (translation.versification == BibleVersification.german ||
        BibleBooks.byId(bookId)?.testament == BibleTestament.newTestament) {
      return same;
    }

    if (_reordered[translation.versification]?.contains(bookId) ?? false) {
      return null;
    }

    final german = germanBook(translations, bookId);

    if (german == null) return null;

    final english = translation.versification == BibleVersification.english;

    if (english && bookId != "PSA") {
      final target = germanToEnglish(bookId, chapter, verse);

      return _fits(german, book, bookId, target.chapter) ? target : null;
    }

    if (german.chapterCount != book.chapterCount) return null;

    if (german.verseCount(chapter) == book.verseCount(chapter)) return same;

    if (english && verse == 1) return same;

    return null;
  }

  /// [reference] (Zählung der Perikopenliste) in der Zählung von
  /// [translation]; `null`, wenn sich die Stelle nicht sicher übertragen
  /// lässt. Kapitelangaben ohne Verse werden nicht übertragen.
  static BibleReference? convert(
    BibleReference reference, {
    required BibleTranslation translation,
    required List<BibleTranslation> translations,
  }) {
    final start = reference.verse;

    final bookId = BibleBooks.resolveIn(translation, reference.bookId);

    if (start == null || bookId == null) return null;

    final from = locate(
      translation: translation,
      translations: translations,
      bookId: bookId,
      chapter: reference.chapter,
      verse: start,
    );

    final to = locate(
      translation: translation,
      translations: translations,
      bookId: bookId,
      chapter: reference.endChapter,
      verse: reference.endVerse ?? start,
    );

    if (from == null || to == null) return null;

    final converted = BibleReference(
      bookId: reference.bookId,
      chapter: from.chapter,
      verse: from.verse,
      endChapter: to.chapter,
      endVerse: reference.endVerse == null ? null : to.verse,
      openEnd: reference.openEnd,
    );

    return converted == reference ? reference : converted;
  }
}
