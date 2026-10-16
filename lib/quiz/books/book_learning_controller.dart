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
import 'adaptive_study_queue.dart';
import 'book_learning.dart';
import 'book_study_session.dart';
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

  final LearningService learningService;
  final SettingsService settingsService;

  BookLearningController._({
    required this.uid,
    required this.storage,
    required this.state,
    required this.bibleRepository,
    required this.outlines,
    required this.learningService,
    required this.settingsService,
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

    final learning = learningService ?? LearningService();
    final settings = settingsService ?? SettingsService();

    final data = await store.load();

    final legacy = await _loadLegacy(uid, learning, settings);

    return BookLearningController._(
      uid: uid,
      storage: store,
      learningService: learning,
      settingsService: settings,
      bibleRepository: bibleRepository ?? BibleRepository.instance,
      outlines: outlines ?? await BookOutlines.load(),
      state: BookLearningState(
        catalog: BookCatalog.fromPerikopen(perikopen),
        data: data,
        legacyCards: legacy.cards,
        legacyBooks: legacy.books,
        clock: clock,
      ),
    );
  }

  /// Der Stand des Endlos-Quiz ist nur ein Startwert; fehlt er (z. B.
  /// offline), funktioniert alles andere trotzdem.
  static Future<({Map<String, LearningCard> cards, Set<String> books})>
  _loadLegacy(
    String? uid,
    LearningService learning,
    SettingsService settings,
  ) async {
    try {
      final cards = await learning.loadPerikopeCards(uid);

      final books = await settings.loadBooks(uid);

      return (
        cards: cards,
        books: books.isEmpty ? {...QuizSettings.allBooks} : books,
      );
    } catch (e) {
      debugPrint("Lernstand des Endlos-Quiz nicht verfügbar: $e");
      return (cards: <String, LearningCard>{}, books: <String>{});
    }
  }

  /// Lädt alle Lernstände neu – nach einem Zurücksetzen in den allgemeinen
  /// Einstellungen. Ersetzt die Daten an Ort und Stelle, sodass eine offene
  /// Lerneinheit nichts Altes zurückschreibt.
  Future<void> reload() async {
    final data = await storage.load();

    final legacy = await _loadLegacy(uid, learningService, settingsService);

    state.replaceWith(
      data,
      legacyCards: legacy.cards,
      legacyBooks: legacy.books,
    );

    refresh();
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

  /// Neue Perikopen je Einheit in Abschnitt oder Kapitel.
  static const int scopeNewPerSession = 6;

  /// Eine Lerneinheit mit fester Aufgabenfolge (Reihenfolge, Prüfung,
  /// einzelne Perikope, Wiederholungslisten).
  StudySession fixedSession(StudyMode mode, List<StudyTask> tasks) {
    return StudySession(
      state: state,
      storage: storage,
      mode: mode,
      tasks: tasks,
    );
  }

  /// Eine fortlaufend ausgewählte Lerneinheit über [scope] (siehe
  /// [AdaptiveStudyQueue]).
  StudySession adaptiveSession(
    StudyMode mode,
    List<BookPericope> scope, {
    required int maxNew,
  }) {
    return StudySession(
      state: state,
      storage: storage,
      mode: mode,
      queue: AdaptiveStudyQueue(state: state, scope: scope, maxNew: maxNew),
    );
  }

  /// Das ganze Buch; neue Perikopen nach Lernplan (Tagesmenge).
  StudySession bookSession(String book) {
    return adaptiveSession(
      StudyMode.learnBook,
      catalog.pericopesOf(book),
      maxNew: state.newQuotaToday(book),
    );
  }

  /// Abschnitt, Kapitel oder Bereich.
  StudySession scopeSession(StudyMode mode, List<BookPericope> scope) {
    return adaptiveSession(mode, scope, maxNew: scopeNewPerSession);
  }

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
