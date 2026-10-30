import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/greek/perikope.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/bible/versification_map.dart';
import '../../services/book_learning_storage.dart';
import '../../services/learning_service.dart';
import '../../services/lecture_materials/lecture_materials.dart';
import '../../services/settings_service.dart';
import '../../settings/quiz_settings.dart';
import 'book_catalog.dart';
import 'adaptive_study_queue.dart';
import 'book_learning.dart';
import 'book_study_session.dart';
import 'book_outline.dart';
import 'book_plan.dart';
import 'knowledge.dart';
import 'reading_plan_path.dart';
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

  /// Freigabe der Vorlesungsunterlagen: Nur mit ihr gibt es die
  /// Musterantworten der Übung (siehe [KnowledgeBank.load]).
  final LectureMaterials lectures;

  /// Lädt die Wissensfragen (Tests ersetzen es).
  final Future<KnowledgeBank> Function(LectureMaterials lectures)
  knowledgeLoader;

  BookLearningController._({
    required this.uid,
    required this.storage,
    required this.state,
    required this.bibleRepository,
    required this.outlines,
    required this.learningService,
    required this.settingsService,
    required this.lectures,
    required this.knowledgeLoader,
  }) {
    lectures.addListener(_lecturesChanged);
    _loadKnowledge();
  }

  int? _knowledgeGeneration;

  /// Abgeschlossen, sobald die Wissensfragen (zuletzt) geladen sind. Die
  /// Übersicht wartet nicht darauf: Perikopen sind sofort da, die Fragen
  /// erscheinen, sobald sie gelesen sind.
  Future<void> get knowledgeReady => _knowledgeReady;
  Future<void> _knowledgeReady = Future.value();

  /// Freigabe geändert (z. B. Prüfung nach dem Start abgeschlossen):
  /// Musterantworten nachladen bzw. verwerfen. Lernstände bleiben.
  void _lecturesChanged() {
    if (_disposed || _knowledgeGeneration == lectures.generation) return;

    _loadKnowledge();
  }

  void _loadKnowledge() {
    final generation = _knowledgeGeneration = lectures.generation;

    _knowledgeReady = knowledgeLoader(lectures).then(
      (bank) {
        // Inzwischen geschlossen oder die Freigabe hat erneut gewechselt.
        if (_disposed || generation != lectures.generation) return;

        state.knowledge = bank;
        refresh();
      },
      onError: (Object e) {
        debugPrint("Wissensfragen nicht geladen: $e");
      },
    );
  }

  static Future<KnowledgeBank> defaultKnowledge(LectureMaterials lectures) {
    return KnowledgeBank.load(
      lectureBundle: lectures.available ? lectures.bundle : null,
      lectureFiles: lectures.files(prefix: KnowledgeBank.modelAnswerPrefix),
    );
  }

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
    LectureMaterials? lectureMaterials,
    Future<KnowledgeBank> Function(LectureMaterials lectures)? loadKnowledge,
  }) async {
    final store = storage ?? BookLearningStorage.forUser(uid);

    final lectures = lectureMaterials ?? LectureMaterials.instance;
    final knowledgeLoader = loadKnowledge ?? defaultKnowledge;

    final learning = learningService ?? LearningService();
    final settings = settingsService ?? SettingsService();

    final data = await store.load();

    final legacy = await _loadLegacy(uid, learning, settings);

    return BookLearningController._(
      uid: uid,
      storage: store,
      learningService: learning,
      settingsService: settings,
      lectures: lectures,
      knowledgeLoader: knowledgeLoader,
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
    lectures.removeListener(_lecturesChanged);
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
    bool paceNew = false,
    List<KnowledgeQuestion> knowledge = const [],
    int knowledgeQuestions = AdaptiveStudyQueue.defaultKnowledge,
    int maxNewKnowledge = AdaptiveStudyQueue.defaultNewKnowledge,
  }) {
    return StudySession(
      state: state,
      storage: storage,
      mode: mode,
      queue: AdaptiveStudyQueue(
        state: state,
        scope: scope,
        maxNew: maxNew,
        paceNew: paceNew,
        // Ausgeschaltet: keine Wissensfragen, Lernstände bleiben.
        knowledge: state.active(knowledge),
        knowledgeQuestions: knowledgeQuestions,
        maxNewKnowledge: maxNewKnowledge,
      ),
    );
  }

  /// Das ganze Buch; neue Perikopen nach Lernplan (Tagesmenge), dazu
  /// Wissensfragen zum ganzen Buch.
  StudySession bookSession(String book) {
    return adaptiveSession(
      StudyMode.learnBook,
      catalog.pericopesOf(book),
      maxNew: state.newQuotaToday(book),
      knowledge: state.knowledge.ofBook(book),
    );
  }

  /// Abschnitt, Kapitel oder Bereich; Wissensfragen nur, wenn
  /// [knowledge] sie nennt (siehe [knowledgeOfChapters],
  /// [knowledgeOfSection]).
  StudySession scopeSession(
    StudyMode mode,
    List<BookPericope> scope, {
    List<KnowledgeQuestion> knowledge = const [],
  }) {
    return adaptiveSession(
      mode,
      scope,
      maxNew: scopeNewPerSession,
      knowledge: knowledge,
    );
  }

  // ---------- Wissensfragen ----------

  /// Fragen, die ganz in den Kapiteln liegen; das ganze Buch auch mit den
  /// Fragen ohne Bereich.
  List<KnowledgeQuestion> knowledgeOfChapters(String book, int from, int to) {
    final chapters = catalog.chaptersOf(book);

    final whole =
        chapters.isNotEmpty && from <= chapters.first && to >= chapters.last;

    return state.knowledge.inChapters(book, from, to, wholeBook: whole);
  }

  List<KnowledgeQuestion> knowledgeOfSection(OutlineSection section) =>
      state.knowledge.inSection(section);

  /// Nur Wissensfragen: dieselbe fortlaufende Auswahl, bis zu
  /// [knowledgeOnlyQuestions] Fragen, davon bis zu [knowledgeOnlyNew] neue.
  /// Ausgeschaltet: leer.
  StudySession knowledgeSession(List<KnowledgeQuestion> questions) {
    return adaptiveSession(
      StudyMode.knowledge,
      const [],
      maxNew: 0,
      knowledge: questions,
      knowledgeQuestions: knowledgeOnlyQuestions,
      maxNewKnowledge: knowledgeOnlyNew,
    );
  }

  static const int knowledgeOnlyQuestions = 12;
  static const int knowledgeOnlyNew = 6;

  /// Schaltet die Wissensfragen ein oder aus. Lernstände bleiben in beiden
  /// Fällen unverändert gespeichert.
  Future<void> setKnowledgeEnabled(bool enabled) async {
    if (state.data.knowledgeEnabled == enabled) return;

    state.data.knowledgeEnabled = enabled;

    refresh();

    try {
      await storage.saveKnowledgeEnabled(enabled);
    } catch (e) {
      debugPrint("Einstellung Wissensfragen nicht gespeichert: $e");
    }
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

  // ---------- Lernpfad nach Bibelleseplan ----------

  /// Eine Lerneinheit des Lernpfads: neue Perikopen nach der Tagesmenge der
  /// laufenden Woche (Rückstand zuerst), dazu Wiederholungen aller schon
  /// begonnenen Perikopen des Plans und die Wissensfragen der Wochen.
  /// Verbucht wird in dieselben Karten wie beim Lernen einzelner Bücher.
  ///
  /// [ahead]: Ist die Tagesmenge erreicht, führt die Einheit Perikopen
  /// dieser späteren Woche ein ([ReadingPlanPath.aheadPerUnit]).
  StudySession readingPathSession(ReadingPlanPath path, {PathWeek? ahead}) {
    final maxNew = ahead != null
        ? ReadingPlanPath.aheadPerUnit
        : min(path.newToday(state), ReadingPlanPath.maxNewPerUnit);

    return adaptiveSession(
      StudyMode.readingPlan,
      path.scope(state, ahead: ahead),
      maxNew: maxNew,
      // Wiederholungen sollen die Einführung nicht verdrängen.
      paceNew: true,
      knowledge: ReadingPlanPath.knowledgeOf(state, [...path.dueWeeks, ?ahead]),
    );
  }

  /// Eine Lerneinheit über die Perikopen einer Woche (frei gewählt, wie ein
  /// Abschnitt).
  StudySession readingPathWeekSession(PathWeek week) {
    return scopeSession(
      StudyMode.readingPlan,
      week.pericopes,
      knowledge: ReadingPlanPath.knowledgeOf(state, [week]),
    );
  }

  /// Beginnt den Lernpfad (bzw. beendet ihn mit `null`; Lernstände
  /// bleiben).
  Future<void> setReadingPath(
    String planId,
    ReadingPathSettings? settings,
  ) async {
    if (settings == null) {
      state.data.readingPaths.remove(planId);
    } else {
      state.data.readingPaths[planId] = settings;
    }

    refresh();

    await storage.saveReadingPath(planId, settings);
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
