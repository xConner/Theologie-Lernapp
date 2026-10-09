import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import 'bible_books.dart';
import 'bible_search_folding.dart';

/// Eine Suchanfrage: Alle Begriffe müssen im selben Vers vorkommen. Ein
/// Ausdruck in Anführungszeichen zählt als Ganzes.
class BibleSearchQuery {
  /// Begriffe in Vergleichsform.
  final List<String> terms;

  const BibleSearchQuery(this.terms);

  bool get isEmpty => terms.isEmpty;

  static final RegExp _quoted = RegExp('["„“”«»]([^"„“”«»]*)["„“”«»]');

  factory BibleSearchQuery.parse(String input, {required bool keepUmlauts}) {
    final terms = <String>[];

    void add(String raw, {required bool split}) {
      final folded = foldForSearch(raw, keepUmlauts: keepUmlauts);

      if (folded.isEmpty) return;

      if (split) {
        terms.addAll(folded.split(" "));
      } else {
        terms.add(folded);
      }
    }

    int position = 0;

    for (final match in _quoted.allMatches(input)) {
      add(input.substring(position, match.start), split: true);
      add(match.group(1)!, split: false);

      position = match.end;
    }

    add(input.substring(position), split: true);

    return BibleSearchQuery(terms.toSet().toList());
  }
}

/// Auf welchen Teil der Ausgabe sich die Suche beschränkt.
enum BibleSearchScope { all, oldTestament, newTestament, book }

class BibleSearchHit {
  final String bookId;
  final int chapter;
  final int verse;

  /// Versbezeichnung der Ausgabe (z. B. „22a“).
  final String verseLabel;

  /// Unveränderter Verstext.
  final String text;

  const BibleSearchHit({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.verseLabel,
    required this.text,
  });

  BibleReference get reference =>
      BibleReference(bookId: bookId, chapter: chapter, verse: verse);
}

class BibleSearchResult {
  /// Die ersten Treffer in der Reihenfolge der Ausgabe.
  final List<BibleSearchHit> hits;

  /// Anzahl aller Treffer, auch der nicht aufgeführten.
  final int total;

  const BibleSearchResult(this.hits, this.total);

  static const BibleSearchResult empty = BibleSearchResult([], 0);
}

class _IndexedVerse {
  final int chapter;
  final int verse;
  final String label;
  final String text;
  final String folded;

  const _IndexedVerse(
    this.chapter,
    this.verse,
    this.label,
    this.text,
    this.folded,
  );
}

/// Alle Verse einer Ausgabe in Vergleichsform. Wird je Ausgabe einmal
/// aufgebaut (`BibleRepository.searchIndex`) und danach für jede Eingabe nur
/// noch durchlaufen – die Texte werden nicht erneut eingelesen.
class BibleSearchIndex {
  final BibleTranslation translation;

  // Buch → Verse, in der Reihenfolge der Ausgabe.
  final Map<String, List<_IndexedVerse>> _books = {};

  BibleSearchIndex(this.translation);

  /// Deutsche Texte unterscheiden ä/ö/ü von a/o/u.
  bool get keepUmlauts => translation.language == "de";

  int get verseCount => _books.values.fold(0, (sum, v) => sum + v.length);

  /// Nimmt die Verse eines Buchs auf; `\n` und Einrückungen des Textes
  /// zählen als Leerraum.
  void addBook(
    String bookId,
    Iterable<({int chapter, int verse, String label, String text})> verses,
  ) {
    final list = _books.putIfAbsent(bookId, () => []);

    for (final v in verses) {
      list.add(
        _IndexedVerse(
          v.chapter,
          v.verse,
          v.label,
          v.text,
          foldForSearch(v.text, keepUmlauts: keepUmlauts),
        ),
      );
    }
  }

  BibleSearchQuery parse(String input) {
    return BibleSearchQuery.parse(input, keepUmlauts: keepUmlauts);
  }

  BibleSearchResult search(
    BibleSearchQuery query, {
    BibleSearchScope scope = BibleSearchScope.all,
    String? bookId,
    int limit = 300,
  }) {
    if (query.isEmpty) return BibleSearchResult.empty;

    // Der längste Begriff schließt die meisten Verse am schnellsten aus.
    final terms = [...query.terms]
      ..sort((a, b) => b.length.compareTo(a.length));

    final hits = <BibleSearchHit>[];
    int total = 0;

    for (final book in translation.books) {
      if (!_inScope(book.id, scope, bookId)) continue;

      for (final v in _books[book.id] ?? const <_IndexedVerse>[]) {
        if (!terms.every(v.folded.contains)) continue;

        total++;

        if (hits.length < limit) {
          hits.add(
            BibleSearchHit(
              bookId: book.id,
              chapter: v.chapter,
              verse: v.verse,
              verseLabel: v.label,
              text: v.text,
            ),
          );
        }
      }
    }

    return BibleSearchResult(hits, total);
  }

  bool _inScope(String id, BibleSearchScope scope, String? bookId) {
    switch (scope) {
      case BibleSearchScope.all:
        return true;
      case BibleSearchScope.book:
        return id == bookId;
      case BibleSearchScope.oldTestament:
        return BibleBooks.byId(id)?.testament != BibleTestament.newTestament;
      case BibleSearchScope.newTestament:
        return BibleBooks.byId(id)?.testament == BibleTestament.newTestament;
    }
  }

  /// Bereiche in [text], die einem Begriff der Anfrage entsprechen – für
  /// die Hervorhebung im unveränderten Verstext.
  List<({int start, int end})> matchRanges(
    String text,
    BibleSearchQuery query,
  ) {
    final folded = foldWithOffsets(text, keepUmlauts: keepUmlauts);

    final ranges = <({int start, int end})>[];

    for (final term in query.terms) {
      int from = 0;

      while (true) {
        final index = folded.text.indexOf(term, from);

        if (index < 0) break;

        final last = index + term.length - 1;

        ranges.add((
          start: folded.offsets[index],
          end: folded.offsets[last] + 1,
        ));

        from = index + term.length;
      }
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));

    // Überlappende Bereiche zusammenfassen.
    final merged = <({int start, int end})>[];

    for (final r in ranges) {
      if (merged.isNotEmpty && r.start <= merged.last.end) {
        final previous = merged.removeLast();

        merged.add((
          start: previous.start,
          end: r.end > previous.end ? r.end : previous.end,
        ));
      } else {
        merged.add(r);
      }
    }

    return merged;
  }
}
