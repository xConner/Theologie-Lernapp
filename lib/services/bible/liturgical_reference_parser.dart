import '../../models/bible/bible_reference.dart';
import 'bible_books.dart';

/// Liest die Stellenangaben des liturgischen Kalenders für den Reader.
///
/// Die Angaben folgen der Schreibweise der Perikopenordnung, z. B.
/// „Römer 6,3-8 (9-11)“, „Psalm 50,1-6.14-15.23“, „1. Mose 8,18-22; 9,12-17“
/// oder „Psalm 139,1-12 oder Psalm 139,13-16.23-24“:
///   * „;“ und „oder“ trennen Stellen, die einzeln geöffnet werden;
///   * „.“ trennt Versgruppen derselben Stelle;
///   * eingeklammerte Verse dürfen entfallen, gehören aber zur Stelle;
///   * Buchstaben nach einer Verszahl („4b“) bezeichnen Versteile.
class LiturgicalReferenceParser {
  LiturgicalReferenceParser._();

  static final RegExp _alternatives = RegExp(r"\s+oder\s+");

  // Buchname (ggf. mit Ordnungszahl), Kapitel und die Versangabe.
  static final RegExp _withBook = RegExp(
    r"^((?:\d\.\s*)?[^\d,;]+?)\s+(\d+)(?:\s*,\s*(.+))?$",
    unicode: true,
  );

  // Weitere Stelle im selben Buch: „9,12-17“.
  static final RegExp _sameBook = RegExp(r"^(\d+)(?:\s*,\s*(.+))?$");

  static final RegExp _verses = RegExp(r"^(\d+)(?:-(\d+)(?:,(\d+))?)?$");

  /// Die Stellen einer Angabe in der Reihenfolge des Textes. Angaben, deren
  /// Buch unbekannt ist, entfallen.
  static List<BiblePassage> parse(String input) {
    final result = <BiblePassage>[];

    for (final alternative in input.split(_alternatives)) {
      String? bookName;
      String? bookId;

      for (final raw in alternative.split(";")) {
        final group = raw.trim();

        int chapter;
        String? verses;
        String label;

        final own = _withBook.firstMatch(group);
        final more = _sameBook.firstMatch(group);

        if (own != null) {
          bookName = own.group(1)!.trim();
          bookId = BibleBooks.find(bookName);
          chapter = int.parse(own.group(2)!);
          verses = own.group(3);
          label = group;
        } else if (more != null && bookName != null) {
          chapter = int.parse(more.group(1)!);
          verses = more.group(2);
          label = "$bookName $group";
        } else {
          continue;
        }

        if (bookId == null || chapter < 1) continue;

        final parts = verses == null ? null : _parts(bookId, chapter, verses);

        // Unlesbare Versangabe: wenigstens das Kapitel aufschlagen.
        if (parts == null || parts.isEmpty) {
          result.add(
            BiblePassage(
              label: label,
              reference: BibleReference.chapter(bookId, chapter),
            ),
          );
          continue;
        }

        final first = parts.first;
        final last = parts.last;

        result.add(
          BiblePassage(
            label: label,
            reference: BibleReference(
              bookId: bookId,
              chapter: first.chapter,
              verse: first.verse,
              endChapter: last.endChapter,
              endVerse: last.endVerse ?? last.verse,
            ),
            parts: parts.length > 1 ? parts : const [],
          ),
        );
      }
    }

    return result;
  }

  /// Die Versgruppen einer Angabe wie „1 (2) 3.17-27 (28-38a) 38b-45“,
  /// aneinandergrenzende zusammengefasst; `null`, wenn sie sich nicht lesen
  /// lässt.
  static List<BibleReference>? _parts(String bookId, int chapter, String text) {
    final tokens = text
        .replaceAll(RegExp(r"[–—−‐‑]"), "-")
        .replaceAll(RegExp(r"[()]"), " ")
        .replaceAllMapped(RegExp(r"(\d)[a-z]+"), (m) => m.group(1)!)
        .split(RegExp(r"[.\s]+"))
        .where((token) => token.isNotEmpty);

    final result = <BibleReference>[];

    for (final token in tokens) {
      final match = _verses.firstMatch(token);

      if (match == null) return null;

      final start = int.parse(match.group(1)!);
      final end = match.group(2) == null ? null : int.parse(match.group(2)!);
      final endVerse = match.group(3) == null
          ? null
          : int.parse(match.group(3)!);

      if (start < 1) return null;

      if (endVerse != null) {
        // „27-12,5“: bis in ein späteres Kapitel.
        if (end! <= chapter || endVerse < 1) return null;

        result.add(
          BibleReference(
            bookId: bookId,
            chapter: chapter,
            verse: start,
            endChapter: end,
            endVerse: endVerse,
          ),
        );

        chapter = end;
        continue;
      }

      if (end != null && end < start) return null;

      final previous = result.lastOrNull;

      // „1 (2) 3“ und „28-38a 38b-45“ sind zusammenhängende Verse.
      if (previous != null &&
          previous.endChapter == chapter &&
          start <= (previous.endVerse ?? previous.verse!) + 1) {
        final previousEnd = previous.endVerse ?? previous.verse!;
        final newEnd = end ?? start;

        result[result.length - 1] = BibleReference(
          bookId: bookId,
          chapter: previous.chapter,
          verse: previous.verse,
          endChapter: previous.endChapter,
          endVerse: newEnd > previousEnd ? newEnd : previousEnd,
        );
        continue;
      }

      result.add(
        BibleReference(
          bookId: bookId,
          chapter: chapter,
          verse: start,
          endVerse: end ?? start,
        ),
      );
    }

    return result;
  }
}
