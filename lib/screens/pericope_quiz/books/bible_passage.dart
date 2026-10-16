import 'package:flutter/material.dart';

import '../../../models/bible/bible_reference.dart';
import '../../../models/greek/perikope.dart';
import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_outline.dart';
import '../../../services/bible/bible_books.dart';
import '../../../services/bible/bible_reference_parser.dart';
import '../../../services/bible/pericope_headings.dart';
import '../../bible/bible_reader_screen.dart';

/// Bibeltext zu Perikopen, Abschnitten und Büchern im vorhandenen
/// Bibel-Reader – wie „Bibelstelle lesen“ im Perikopenquiz. Der Reader wird
/// über die laufende Ansicht gelegt; nach dem Schließen geht es dort weiter,
/// wo man war (auch mitten in einer Lerneinheit).
///
/// Nur eine Lernhilfe: Bewertet wird weiterhin allein die Stelle.

/// Die Stelle einer Perikope für den Reader – mit persönlicher
/// Verspräzisierung, sonst wie im Perikopenquiz (Verse der Liste).
BiblePassage? passageOfPericope(
  BookLearningController controller,
  BookPericope p,
) {
  final precision = controller.state.precisionOf(p);

  final perikope = precision == null
      ? p.perikope
      : Perikope(
          id: p.perikope.id,
          title: p.perikope.title,
          book: p.perikope.book,
          startChapter: precision.startChapter,
          startVerse: precision.startVerse,
          endChapter: precision.endChapter,
          endVerse: precision.endVerse,
          required: p.perikope.required,
          precision: "verse",
        );

  return BibleReferenceParser.passageOf(perikope);
}

/// Ein Abschnitt der Gliederung, kapitel- oder versgenau.
BiblePassage? passageOfSection(OutlineSection section) {
  final book = BibleBooks.byAbbreviation(section.book);

  if (book == null) return null;

  final start = section.start;
  final end = section.end;

  final verses = start.verse != null || end.verse != null;

  return BiblePassage(
    label: "${section.book} ${section.rangeText}",
    reference: BibleReference(
      bookId: book.id,
      chapter: start.chapter,
      verse: verses ? (start.verse ?? 1) : null,
      endChapter: end.chapter,
      // Ohne Endvers bis zum Kapitelende.
      endVerse: verses ? end.verse : null,
      openEnd: verses && end.verse == null,
    ),
  );
}

/// Ein ganzes Buch: der Reader öffnet bei Kapitel 1.
BiblePassage? passageOfBook(String book) {
  final known = BibleBooks.byAbbreviation(book);

  if (known == null) return null;

  return BiblePassage(
    label: BookCatalog.nameOf(book),
    reference: BibleReference.chapter(known.id, 1),
  );
}

Future<void> openPassage(
  BuildContext context,
  BookLearningController controller,
  BiblePassage passage, {
  required String title,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BibleReaderScreen(
        passages: [passage],
        passageTitle: title,
        repository: controller.bibleRepository,
        // Dieselben Perikopen, aus denen gelernt wird.
        pericopeHeadings: PericopeHeadings.fromPerikopen(
          controller.catalog.all.map((p) => p.perikope),
        ),
      ),
    ),
  );
}

/// Knopf „Bibelstelle lesen“; ausgeblendet, wenn sich die Stelle nicht
/// aufschlagen lässt (z. B. eigene Perikope mit unbekanntem Buch).
class ReadPassageButton extends StatelessWidget {
  final BookLearningController controller;
  final BiblePassage? passage;
  final String title;
  final String label;

  const ReadPassageButton({
    super.key,
    required this.controller,
    required this.passage,
    required this.title,
    this.label = "Bibelstelle lesen",
  });

  @override
  Widget build(BuildContext context) {
    final p = passage;

    if (p == null) return const SizedBox.shrink();

    return OutlinedButton.icon(
      icon: const Icon(Icons.auto_stories_rounded),
      label: Text(label),
      onPressed: () => openPassage(context, controller, p, title: title),
    );
  }
}

/// Kurzform für eine Perikope.
Widget readPericopeButton(
  BookLearningController controller,
  BookPericope p, {
  Key? key,
}) {
  return ReadPassageButton(
    key: key,
    controller: controller,
    passage: passageOfPericope(controller, p),
    title: p.title,
  );
}
