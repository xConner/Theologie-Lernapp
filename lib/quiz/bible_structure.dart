import 'dart:math';

import '../models/greek/perikope.dart';

import 'pericope_reference.dart';

/// Kapitel- und Versumfang der Bücher, abgeleitet aus den geladenen
/// Perikopen. Es gibt keine eigene Bibeltabelle: Die Perikopen sind die
/// einzige Quelle, damit die Grenzen immer zu den Quizfragen passen.
///
/// Die Kapitelzahl ist das höchste Kapitel, das in einer Perikope des Buchs
/// vorkommt. Die Verszahl eines Kapitels ist der höchste dort belegte Vers.
/// Sie kann unter der tatsächlichen Verszahl liegen, wenn die letzte Perikope
/// eines Kapitels ins nächste hineinreicht; jede erwartete Antwort bleibt
/// aber auswählbar, weil sie aus denselben Perikopen stammt.
class BibleStructure {
  // Buch → Kapitel → höchster belegter Vers.
  final Map<String, Map<int, int>> _verses = {};

  final Map<String, int> _chapters = {};

  BibleStructure.fromPerikopen(Iterable<Perikope> perikopen) {
    for (final p in perikopen) {
      _chapters[p.book] = max(
        _chapters[p.book] ?? 0,
        max(p.startChapter, p.endChapter),
      );

      final verses = _verses.putIfAbsent(p.book, () => {});

      verses[p.startChapter] = max(verses[p.startChapter] ?? 0, p.startVerse);
      verses[p.endChapter] = max(verses[p.endChapter] ?? 0, p.endVerse);
    }
  }

  bool hasBook(String book) => _chapters.containsKey(book);

  /// Anzahl der Kapitel des Buchs, 0 bei unbekanntem Buch.
  int chapterCount(String book) => _chapters[book] ?? 0;

  /// Höchster belegter Vers des Kapitels, 0 wenn keiner belegt ist.
  int verseCount(String book, int chapter) => _verses[book]?[chapter] ?? 0;

  /// Ob [reference] vollständig innerhalb der bekannten Grenzen und der
  /// erlaubten [books] liegt und Anfang und Ende in der richtigen
  /// Reihenfolge stehen.
  bool allows(PericopeReference reference, Iterable<String> books) {
    final book = reference.book;

    if (book == null) return true;
    if (!books.contains(book) || !hasBook(book)) return false;

    final startChapter = reference.startChapter;

    if (startChapter == null) return true;

    final endChapter = reference.endChapter ?? startChapter;

    if (startChapter < 1 ||
        endChapter < startChapter ||
        endChapter > chapterCount(book)) {
      return false;
    }

    final startVerse = reference.startVerse;

    if (startVerse == null) return true;

    final endVerse = reference.endVerse ?? startVerse;

    if (startVerse < 1 ||
        startVerse > verseCount(book, startChapter) ||
        endVerse < 1 ||
        endVerse > verseCount(book, endChapter)) {
      return false;
    }

    return endChapter > startChapter || endVerse >= startVerse;
  }
}
