import '../../models/greek/perikope.dart';
import '../../services/bible/bible_books.dart';
import '../../settings/quiz_settings.dart';
import '../bible_structure.dart';

/// Eine Perikope innerhalb eines Bibelbuchs, wie sie die Perikopenliste
/// führt – Grundlage von „Bücher systematisch lernen“.
///
/// Das Endlos-Quiz fasst alle Stellen mit derselben ID zu einer Frage
/// zusammen (synoptische Parallelen, mehrteilige Abschnitte). Beim
/// systematischen Lernen eines Buchs zählt dagegen jeder Eintrag der Liste
/// einzeln: „Berufung der Jünger“ steht in Mk 1 dreimal, jedes Mal an
/// anderer Stelle.
///
/// [key] identifiziert den Eintrag dauerhaft, ohne die IDs der Liste zu
/// verändern: Buch, ID und Anfang der Stelle aus den globalen Daten
/// (persönliche Präzisierungen ändern ihn nicht).
class BookPericope {
  final Perikope perikope;

  /// Position im Buch (0 = erste Perikope), nach Anfangsstelle geordnet.
  final int index;

  const BookPericope(this.perikope, this.index);

  String get id => perikope.id;
  String get title => perikope.title;
  String get book => perikope.book;

  /// Kapitel, unter dem die Perikope in der Übersicht steht (Anfangskapitel).
  int get chapter => perikope.startChapter;

  /// Alle Kapitel, die die Perikope berührt.
  Iterable<int> get chapters sync* {
    for (int c = perikope.startChapter; c <= perikope.endChapter; c++) {
      yield c;
    }
  }

  String get key => keyOf(perikope);

  static String keyOf(Perikope p) =>
      "${p.book}|${p.id}|${p.startChapter},${p.startVerse}";

  @override
  bool operator ==(Object other) => other is BookPericope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Alle Bücher mit ihren Perikopen in biblischer Reihenfolge – ausschließlich
/// aus den geladenen Perikopen (`assets/perikopen.json` samt eventueller
/// Nutzer-Overrides), ohne zusätzliche oder erfundene Einträge.
class BookCatalog {
  final Map<String, List<BookPericope>> _books;

  final Map<String, BookPericope> _byKey;

  BookCatalog._(this._books)
    : _byKey = {
        for (final list in _books.values)
          for (final p in list) p.key: p,
      };

  factory BookCatalog.fromPerikopen(Iterable<Perikope> perikopen) {
    final grouped = <String, List<Perikope>>{};

    final seen = <String>{};

    for (final p in perikopen) {
      // Wie im Endlos-Quiz (QuizQuestion.forBooks) nur die abzufragenden.
      if (!p.required) continue;

      // Ein exakt doppelter Eintrag wäre nicht unterscheidbar.
      if (!seen.add(BookPericope.keyOf(p))) continue;

      grouped.putIfAbsent(p.book, () => []).add(p);
    }

    final books = grouped.keys.toList()..sort(_compareBooks);

    final result = <String, List<BookPericope>>{};

    for (final book in books) {
      final list = grouped[book]!;

      // Stabil sortieren: gleiche Anfänge behalten die Reihenfolge der Liste.
      final indexed = list.asMap().entries.toList()
        ..sort((a, b) {
          final byChapter = a.value.startChapter.compareTo(
            b.value.startChapter,
          );
          if (byChapter != 0) return byChapter;

          final byVerse = a.value.startVerse.compareTo(b.value.startVerse);
          if (byVerse != 0) return byVerse;

          return a.key.compareTo(b.key);
        });

      result[book] = [
        for (int i = 0; i < indexed.length; i++)
          BookPericope(indexed[i].value, i),
      ];
    }

    return BookCatalog._(result);
  }

  static int _rank(String book) {
    final quizIndex = QuizSettings.allBooks.indexOf(book);

    final known = BibleBooks.byAbbreviation(book);

    if (known != null) return BibleBooks.order(known.id);

    // Unbekannte Abkürzung (eigene Perikopen): hinter alle bekannten Bücher.
    return 1000 + (quizIndex < 0 ? 0 : quizIndex);
  }

  static int _compareBooks(String a, String b) {
    final byRank = _rank(a).compareTo(_rank(b));

    return byRank != 0 ? byRank : a.compareTo(b);
  }

  /// Kapitel- und Versumfang aus denselben Perikopen – wie im Endlos-Quiz
  /// Grundlage der Schnelleingabe und der Prüfung von Kapitelzahlen.
  late final BibleStructure structure = BibleStructure.fromPerikopen(
    all.map((p) => p.perikope),
  );

  /// Die Bücher, zu denen Perikopen vorliegen, in biblischer Reihenfolge.
  List<String> get books => _books.keys.toList();

  bool hasBook(String book) => _books.containsKey(book);

  List<BookPericope> pericopesOf(String book) => _books[book] ?? const [];

  BookPericope? byKey(String key) => _byKey[key];

  Iterable<BookPericope> get all => _byKey.values;

  /// Kapitel des Buchs, unter denen Perikopen stehen (aufsteigend).
  List<int> chaptersOf(String book) {
    final chapters = {for (final p in pericopesOf(book)) p.chapter}.toList()
      ..sort();

    return chapters;
  }

  /// Perikopen, deren Anfangskapitel im Bereich [from]–[to] liegt.
  List<BookPericope> inChapters(String book, int from, int to) {
    return [
      for (final p in pericopesOf(book))
        if (p.chapter >= from && p.chapter <= to) p,
    ];
  }

  /// Ausgeschriebener Buchname, falls bekannt (sonst die Abkürzung).
  static String nameOf(String book) {
    final known = BibleBooks.byAbbreviation(book);

    return known == null ? book : BibleBooks.nameOf(known.id);
  }
}
