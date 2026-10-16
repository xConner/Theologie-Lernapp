import 'package:flutter/foundation.dart';

import '../../models/greek/perikope.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/bible/versification_map.dart';
import '../../services/book_learning_storage.dart';
import '../../services/learning_service.dart';
import '../../services/settings_service.dart';
import '../../settings/quiz_settings.dart';
import 'book_catalog.dart';
import 'book_learning.dart';
import 'book_outline.dart';
import 'book_plan.dart';
import 'verse_precision.dart';

/// Gemeinsamer Zustand der Ansichten von „Bücher systematisch lernen“:
/// lädt einmal, speichert Änderungen und benachrichtigt die Ansichten.
class BookLearningController extends ChangeNotifier {
  final String? uid;

  final BookLearningStorage storage;

  final BookLearningState state;

  final BibleRepository bibleRepository;

  /// Hinterlegte Buchgliederungen (`assets/book_outlines.json`).
  final BookOutlines outlines;

  BookLearningController._({
    required this.uid,
    required this.storage,
    required this.state,
    required this.bibleRepository,
    required this.outlines,
  });

  BookCatalog get catalog => state.catalog;

  /// Gliederung eines Buchs; ohne hinterlegte automatisch nach Kapiteln.
  BookOutline outlineFor(String book) => outlines.outlineFor(catalog, book);

  /// Lädt Lernstände, Präzisierungen und Pläne sowie – nur lesend – die
  /// Karten und die Buchauswahl des Endlos-Quiz als Startwerte.
  static Future<BookLearningController> load({
    required List<Perikope> perikopen,
    required String? uid,
    BookLearningStorage? storage,
    LearningService? learningService,
    SettingsService? settingsService,
    BibleRepository? bibleRepository,
    BookOutlines? outlines,
    DateTime Function()? clock,
  }) async {
    final store = storage ?? BookLearningStorage.forUser(uid);

    final data = await store.load();

    Map<String, LearningCard> legacy = {};
    Set<String> legacyBooks = {};

    // Der Stand des Endlos-Quiz ist nur ein Startwert; fehlt er (z. B.
    // offline), funktioniert alles andere trotzdem.
    try {
      legacy = await (learningService ?? LearningService()).loadPerikopeCards(
        uid,
      );

      final books = await (settingsService ?? SettingsService()).loadBooks(uid);

      legacyBooks = books.isEmpty ? {...QuizSettings.allBooks} : books;
    } catch (e) {
      debugPrint("Lernstand des Endlos-Quiz nicht verfügbar: $e");
    }

    return BookLearningController._(
      uid: uid,
      storage: store,
      bibleRepository: bibleRepository ?? BibleRepository.instance,
      outlines: outlines ?? await BookOutlines.load(),
      state: BookLearningState(
        catalog: BookCatalog.fromPerikopen(perikopen),
        data: data,
        legacyCards: legacy,
        legacyBooks: legacyBooks,
        clock: clock,
      ),
    );
  }

  bool _disposed = false;

  /// Nach einer Lerneinheit: Die Karten wurden direkt im [state] geändert.
  /// Nach dem Schließen der Übersicht ohne Wirkung.
  void refresh() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  StudyPlanner planner() => StudyPlanner(state);

  // ---------- Verspräzisierung ----------

  /// Speichert (oder entfernt mit `null`) die persönliche Präzisierung.
  Future<void> setPrecision(BookPericope p, VersePrecision? precision) async {
    if (precision == null) {
      state.data.precisions.remove(p.key);
    } else {
      state.data.precisions[p.key] = precision;
    }

    refresh();

    await storage.savePrecision(p.key, precision);
  }

  /// Verszahlen der Kapitel eines Buchs in deutscher Zählung, soweit eine
  /// deutsch gezählte Ausgabe das Buch enthält; sonst `null` je Kapitel.
  Future<int? Function(int chapter)> verseCounter(String book) async {
    final known = BibleBooks.byAbbreviation(book);

    if (known == null) return (_) => null;

    try {
      final translations = await bibleRepository.translations();

      final info = ListVersification.germanBook(translations, known.id);

      if (info == null) return (_) => null;

      return (chapter) {
        final count = info.verseCount(chapter);
        return count > 0 ? count : null;
      };
    } catch (_) {
      return (_) => null;
    }
  }

  // ---------- Lernplan ----------

  Future<void> setPlan(String book, BookPlan? plan) async {
    if (plan == null) {
      state.data.plans.remove(book);
    } else {
      state.data.plans[book] = plan;
    }

    refresh();

    await storage.savePlan(book, plan);
  }
}
