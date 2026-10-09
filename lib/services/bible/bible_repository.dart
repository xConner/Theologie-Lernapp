import '../../models/bible/bible_text.dart';
import '../../models/bible/bible_translation.dart';
import 'bible_search.dart';
import 'bible_text_source.dart';

/// Zentraler Zugriff auf die Bibeltexte: Verzeichnis der Ausgaben, Bücher
/// und Kapitel sowie der Suchindex.
///
/// Die Texte kommen aus einer [BibleTextSource]; das Repository hält nur
/// Zwischenspeicher, damit beim Blättern und Suchen nichts doppelt geladen
/// wird.
class BibleRepository {
  final BibleTextSource source;

  BibleRepository({BibleTextSource? source})
    : source = source ?? const AssetBibleTextSource();

  /// Gemeinsame Instanz der App mit den ausgelieferten Texten.
  static final BibleRepository instance = BibleRepository();

  // Zuletzt gelesene Bücher; ein Buch hat wenige hundert Kilobyte.
  static const int _cachedBooks = 6;

  Future<List<BibleTranslation>>? _translations;

  final Map<String, Future<BibleBookText>> _books = {};

  BibleSearchIndex? _index;
  Future<BibleSearchIndex>? _indexLoading;
  String? _indexLoadingId;

  /// Die verfügbaren Ausgaben; wird einmal geladen.
  Future<List<BibleTranslation>> translations() {
    return _translations ??= _loadTranslations();
  }

  Future<List<BibleTranslation>> _loadTranslations() async {
    try {
      return await source.loadTranslations();
    } catch (_) {
      // Nach einem Fehler beim nächsten Öffnen erneut versuchen.
      _translations = null;

      rethrow;
    }
  }

  Future<BibleBookText> book(BibleTranslation translation, String bookId) {
    final key = "${translation.id}/$bookId";

    final cached = _books.remove(key);

    if (cached != null) {
      // Wieder ans Ende: zuletzt benutzt.
      _books[key] = cached;

      return cached;
    }

    final loading = _loadBook(key, translation.id, bookId);

    _books[key] = loading;

    while (_books.length > _cachedBooks) {
      _books.remove(_books.keys.first);
    }

    return loading;
  }

  Future<BibleBookText> _loadBook(
    String key,
    String translationId,
    String bookId,
  ) async {
    try {
      return await source.loadBook(translationId, bookId);
    } catch (_) {
      _books.remove(key);

      rethrow;
    }
  }

  Future<BibleChapter?> chapter(
    BibleTranslation translation,
    String bookId,
    int chapter,
  ) async {
    return (await book(translation, bookId)).chapter(chapter);
  }

  /// Der Suchindex der Ausgabe, falls er schon aufgebaut ist.
  BibleSearchIndex? cachedSearchIndex(BibleTranslation translation) {
    final index = _index;

    return index != null && index.translation.id == translation.id
        ? index
        : null;
  }

  /// Baut den Suchindex der Ausgabe auf bzw. liefert den vorhandenen.
  ///
  /// Dazu wird jedes Buch einmal gelesen; [onProgress] meldet den Stand
  /// (0–1). Es bleibt nur der Index der zuletzt durchsuchten Ausgabe im
  /// Speicher.
  Future<BibleSearchIndex> searchIndex(
    BibleTranslation translation, {
    void Function(double progress)? onProgress,
  }) {
    final ready = cachedSearchIndex(translation);

    if (ready != null) return Future.value(ready);

    final loading = _indexLoading;

    if (loading != null && _indexLoadingId == translation.id) return loading;

    final future = _buildIndex(translation, onProgress);

    _indexLoading = future;
    _indexLoadingId = translation.id;

    return future.whenComplete(() {
      if (identical(_indexLoading, future)) {
        _indexLoading = null;
        _indexLoadingId = null;
      }
    });
  }

  Future<BibleSearchIndex> _buildIndex(
    BibleTranslation translation,
    void Function(double progress)? onProgress,
  ) async {
    final index = BibleSearchIndex(translation);

    final books = translation.books;

    for (int i = 0; i < books.length; i++) {
      // Direkt von der Quelle: Die Bücher sollen den Lese-Zwischenspeicher
      // nicht verdrängen.
      final text = await source.loadBook(translation.id, books[i].id);

      index.addBook(books[i].id, [
        for (final chapter in text.chapters)
          for (final verse in chapter.verses)
            (
              chapter: chapter.number,
              verse: verse.number,
              label: verse.displayNumber,
              text: verse.text,
            ),
      ]);

      onProgress?.call((i + 1) / books.length);
    }

    _index = index;

    return index;
  }
}
