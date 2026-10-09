import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import '../../models/greek/perikope.dart';
import '../../quiz/pericope_reference.dart';
import 'bible_books.dart';

/// Liest und schreibt Stellenangaben – für die Stelleneingabe des Readers
/// und für die Stellen der Perikopenliste.
class BibleReferenceParser {
  BibleReferenceParser._();

  // Buchname (ggf. mit führender Ordnungszahl), danach die Zahlenangabe.
  static final RegExp _pattern = RegExp(
    r'^((?:[1-4]\s*\.?\s*)?[^\d,;:]+?)\s*\.?\s*(\d[\d\s,\-f]*)?$',
    unicode: true,
  );

  static final RegExp _numbers = RegExp(
    r'^(\d+)(?:,(\d+)(ff|f)?)?(?:-(\d+)(?:,(\d+))?)?$',
  );

  /// Liest Angaben wie „Mk 4,35–41“, „Joh 3,16“, „1. Mose 1,1–2,4“,
  /// „Ps 23“, „Gen 1–3“, „Mk 4,35f“ oder „John 3:16“.
  ///
  /// Buchnamen werden deutsch, englisch, lateinisch und griechisch erkannt,
  /// außerdem unter dem Namen, den [translation] dem Buch gibt. Ergibt die
  /// Eingabe keine Stelle, ist das Ergebnis `null`.
  static BibleReference? parse(String input, {BibleTranslation? translation}) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[–—−‐‑]'), '-')
        .replaceAll(':', ',')
        .replaceAll(RegExp(r'\s+'), ' ');

    final match = _pattern.firstMatch(cleaned);

    if (match == null) return null;

    final bookId = BibleBooks.find(match.group(1)!, translation: translation);

    if (bookId == null) return null;

    final rest = match.group(2)?.replaceAll(' ', '');

    // Nur das Buch: erstes Kapitel.
    if (rest == null || rest.isEmpty) {
      return BibleReference.chapter(bookId, 1);
    }

    final numbers = _numbers.firstMatch(rest);

    if (numbers == null) return null;

    int? number(int group) {
      final value = numbers.group(group);

      return value == null ? null : int.tryParse(value);
    }

    final chapter = number(1);
    final verse = number(2);
    final suffix = numbers.group(3);
    final end = number(4);
    final endVerse = number(5);

    if (chapter == null || chapter < 1) return null;

    if (verse == null) {
      // „8“ oder „8-10“.
      if (endVerse != null) return null;
      if (end != null && end < chapter) return null;

      return BibleReference(bookId: bookId, chapter: chapter, endChapter: end);
    }

    if (verse < 1) return null;

    if (suffix != null) {
      if (end != null) return null;

      return suffix == "f"
          ? BibleReference(
              bookId: bookId,
              chapter: chapter,
              verse: verse,
              endVerse: verse + 1,
            )
          : BibleReference(
              bookId: bookId,
              chapter: chapter,
              verse: verse,
              openEnd: true,
            );
    }

    if (end == null) {
      return BibleReference(bookId: bookId, chapter: chapter, verse: verse);
    }

    if (endVerse == null) {
      // „4,35-41“: Ende im selben Kapitel.
      if (end < verse) return null;

      return BibleReference(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        endVerse: end,
      );
    }

    // „1,1-2,4“.
    if (end < chapter || (end == chapter && endVerse < verse)) return null;

    return BibleReference(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      endChapter: end,
      endVerse: endVerse,
    );
  }

  /// Die Stelle mit der Abkürzung der Perikopenliste, z. B. „Mk 4,35–41“.
  static String format(BibleReference reference) {
    final book = BibleBooks.abbreviationOf(reference.bookId);

    return "$book ${reference.rangeText}";
  }

  /// Die Stelle einer Perikope für den Reader.
  ///
  /// Die Liste führt zu jeder Perikope Anfangs- und Endvers, auch wenn das
  /// Quiz nur das Kapitel abfragt; hervorgehoben werden deshalb die Verse.
  /// Ist das Buch unbekannt (z. B. eine eigene Perikope mit abweichender
  /// Abkürzung), ist das Ergebnis `null`.
  static BiblePassage? passageOf(Perikope p) {
    final book = BibleBooks.byAbbreviation(p.book);

    if (book == null || p.startChapter < 1 || p.endChapter < p.startChapter) {
      return null;
    }

    final verses = p.startVerse >= 1 && p.endVerse >= 1;

    return BiblePassage(
      label:
          "${p.book} "
          "${PericopeReference.formatRange(precision: verses ? "verse" : "chapter", startChapter: p.startChapter, startVerse: p.startVerse, endChapter: p.endChapter, endVerse: p.endVerse)}",
      reference: BibleReference(
        bookId: book.id,
        chapter: p.startChapter,
        verse: verses ? p.startVerse : null,
        endChapter: p.endChapter,
        endVerse: verses ? p.endVerse : null,
      ),
    );
  }
}
