import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../bible_structure.dart';
import '../pericope_reference.dart';
import 'verse_precision.dart';

enum AnswerVerdict {
  correct,

  /// Kapitel richtig, die erwarteten Verse fehlen.
  missingVerses,

  /// Kapitel richtig, Verse falsch.
  wrongVerses,

  wrongChapter,
  wrongBook,

  /// Keine lesbare Stelle.
  invalid,
}

class AnswerCheck {
  final AnswerVerdict verdict;

  /// Die eingegebene Stelle in kanonischer Schreibweise (falls lesbar).
  final String? given;

  /// Die Eingabe enthielt Verse, obwohl die Perikope nur kapitelgenau gilt;
  /// sie wurden nicht bewertet.
  final bool versesIgnored;

  const AnswerCheck(this.verdict, {this.given, this.versesIgnored = false});

  bool get correct => verdict == AnswerVerdict.correct;

  String get message {
    switch (verdict) {
      case AnswerVerdict.correct:
        return versesIgnored
            ? "Richtig – die Perikope gilt kapitelgenau, Verse werden nicht "
                  "bewertet."
            : "Richtig";
      case AnswerVerdict.missingVerses:
        return "Kapitel richtig, aber die Verse fehlen.";
      case AnswerVerdict.wrongVerses:
        return "Kapitel richtig, Verse falsch.";
      case AnswerVerdict.wrongChapter:
        return "Falsches Kapitel.";
      case AnswerVerdict.wrongBook:
        return "Falsches Buch.";
      case AnswerVerdict.invalid:
        return "Keine gültige Stellenangabe.";
    }
  }
}

/// Bewertet getippte Stellen gegen die maßgebliche Stelle einer Perikope.
///
/// * Kapitelgenaue Perikopen: Es zählt nur der Kapitelbereich. Zusätzlich
///   getippte Verse sind kein Fehler, solange sie in diesen Kapiteln liegen –
///   die Liste kennt dort keine verbindlichen Verse.
/// * Versgenaue Perikopen (global oder persönlich präzisiert): Kapitel und
///   Verse müssen der hinterlegten Stelle entsprechen.
///
/// Schreibweisen: neben der Quiz-Schreibweise („Mk 1,14-20“) auch
/// Gedankenstriche, Doppelpunkt, Leerzeichen („Mk 1, 14 – 20“) und alle
/// Buchnamen, die der Bibel-Reader versteht („Markus 1,14-20“).
class ReferenceAnswerChecker {
  ReferenceAnswerChecker._();

  /// Liest eine Eingabe. Mit [contextBook] (die Lerneinheit betrifft genau
  /// ein Buch) genügt die Kapitelangabe, z. B. „5“ für „Gen 5“; wer das
  /// Buch trotzdem mittippt, wird nicht bestraft. Ohne Buchkontext muss die
  /// Eingabe das Buch enthalten.
  static PericopeReference? read(String input, {String? contextBook}) {
    var text = clean(input);

    if (text.isEmpty) return null;

    if (contextBook != null &&
        RegExp(r'^\d').hasMatch(text) &&
        !_looksLikeBook(text)) {
      text = "$contextBook $text";
    }

    return parse(text);
  }

  /// Warum sich eine Eingabe nicht bewerten lässt – oder `null`, wenn sie
  /// eine lesbare Stelle ist (auch eine falsche) oder leer ist.
  ///
  /// Solche Eingaben zählen nicht als Antwort: Formfehler, unbekannte
  /// Bücher, fehlendes Buch ohne Buchkontext und Kapitel, zu denen es laut
  /// [structure] (aus denselben Perikopen wie die Schnelleingabe) keine
  /// Perikope gibt.
  static String? problem(
    String input, {
    String? contextBook,
    BibleStructure? structure,
  }) {
    final text = clean(input);

    if (text.isEmpty) return null;

    final example = contextBook == null
        ? "z. B. Gen 5 oder Mk 1,14-20"
        : "z. B. 5 oder 1,14-20";

    final given = read(text, contextBook: contextBook);

    if (given == null) {
      final digitsOnly = RegExp(r'^\d').hasMatch(text) && !_looksLikeBook(text);

      if (digitsOnly && contextBook == null) {
        return "Bitte auch das Buch angeben, z. B. Gen 5.";
      }

      final name = RegExp(
        r'^((?:[1-4]\.?\s?)?[^\d]+?)\s*(?:\d|$)',
      ).firstMatch(text)?.group(1)?.trim();

      if (!digitsOnly &&
          name != null &&
          name.isNotEmpty &&
          BibleBooks.find(name) == null &&
          BibleBooks.byAbbreviation(name) == null) {
        return "„$name“ ist kein bekanntes Bibelbuch.";
      }

      if (!digitsOnly && name != null && !RegExp(r'\d').hasMatch(text)) {
        return "Bitte auch das Kapitel angeben, $example.";
      }

      return "Ungültige Angabe, $example.";
    }

    final book = given.book!;

    if (structure != null) {
      if (!structure.hasBook(book)) {
        final known =
            BibleBooks.byAbbreviation(book) != null ||
            BibleBooks.find(book) != null;

        return known
            ? "Zu $book gibt es keine Perikopen."
            : "„$book“ ist kein bekanntes Bibelbuch.";
      }

      final max = structure.chapterCount(book);
      final end = given.endChapter ?? given.startChapter!;

      if (given.startChapter! < 1 || end > max) {
        return "In $book gibt es Perikopen nur bis Kapitel $max.";
      }
    }

    return null;
  }

  // „1Kor 3“ bzw. „1.Makk 2“ beginnen mit einer Ziffer, sind aber Bücher.
  static bool _looksLikeBook(String text) {
    return RegExp(r'^\d\.?\s?[A-Za-zÄÖÜäöü]').hasMatch(text);
  }

  /// Einheitliche Schreibweise: Striche, Doppelpunkt und Leerzeichen.
  static String clean(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[–—−‐‑]'), '-')
        .replaceAll(':', ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ',')
        .replaceAll(RegExp(r'\s*-\s*'), '-')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Eine vollständige Stelle (mit Buch und Kapitel) in Quiz-Schreibweise.
  static PericopeReference? parse(String input) {
    final text = clean(input);

    if (text.isEmpty) return null;

    // Zuerst die Schreibweise des Quiz (auch Abkürzungen eigener Perikopen).
    final direct = PericopeReference.parse(text);

    if (direct != null &&
        direct.startChapter != null &&
        (direct.book == null ||
            BibleBooks.byAbbreviation(direct.book!) != null)) {
      return _normalized(direct);
    }

    // Dann alle Buchnamen, die der Bibel-Reader kennt. Nur das Buch ohne
    // Kapitel ist keine Antwort.
    if (!RegExp(r'[^\d\s.,\-]\s*\.?\s*\d').hasMatch(text)) {
      return null;
    }

    final parsed = BibleReferenceParser.parse(text);

    if (parsed != null && !parsed.openEnd) {
      final verse = parsed.verse;

      return _normalized(
        PericopeReference(
          book: BibleBooks.abbreviationOf(parsed.bookId),
          startChapter: parsed.chapter,
          startVerse: verse,
          endChapter: parsed.endChapter,
          endVerse: verse == null ? null : (parsed.endVerse ?? verse),
        ),
      );
    }

    if (direct != null && direct.startChapter != null) {
      return _normalized(direct);
    }

    return null;
  }

  // Ende immer gesetzt: „Mk 1“ = „Mk 1-1“, „Mk 1,3“ = „Mk 1,3-3“.
  static PericopeReference _normalized(PericopeReference r) {
    final endChapter = r.endChapter ?? r.startChapter;

    return PericopeReference(
      book: r.book,
      startChapter: r.startChapter,
      startVerse: r.startVerse,
      endChapter: endChapter,
      endVerse: r.startVerse == null ? null : (r.endVerse ?? r.startVerse),
    );
  }

  static AnswerCheck check(
    String input,
    ExpectedReference expected, {
    String? contextBook,
  }) {
    final given = read(input, contextBook: contextBook);

    if (given == null) {
      return const AnswerCheck(AnswerVerdict.invalid);
    }

    return compare(given, expected);
  }

  static AnswerCheck compare(PericopeReference given, ExpectedReference e) {
    final want = _normalized(e.reference);

    final text = given.text;

    if (given.book != want.book) {
      return AnswerCheck(AnswerVerdict.wrongBook, given: text);
    }

    final sameChapters =
        given.startChapter == want.startChapter &&
        given.endChapter == want.endChapter;

    if (!e.versePrecise) {
      if (!sameChapters) {
        return AnswerCheck(AnswerVerdict.wrongChapter, given: text);
      }

      return AnswerCheck(
        AnswerVerdict.correct,
        given: text,
        versesIgnored: given.startVerse != null,
      );
    }

    if (!sameChapters) {
      // „Mk 1“ für „Mk 1,14-20“: Kapitel stimmt, Verse fehlen.
      return AnswerCheck(AnswerVerdict.wrongChapter, given: text);
    }

    if (given.startVerse == null) {
      return AnswerCheck(AnswerVerdict.missingVerses, given: text);
    }

    if (given.startVerse != want.startVerse ||
        given.endVerse != want.endVerse) {
      return AnswerCheck(AnswerVerdict.wrongVerses, given: text);
    }

    return AnswerCheck(AnswerVerdict.correct, given: text);
  }
}
