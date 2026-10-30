import '../quiz/books/book_learning_status.dart';
import '../quiz/books/book_plan.dart';
import '../quiz/books/reading_plan_path.dart';
import '../quiz/books/verse_precision.dart';
import '../quiz/pericope_id_migration.dart';
import 'local_learning_store.dart';
import 'quiz_documents.dart';

/// Gespeicherte Daten von „Bücher systematisch lernen“.
class BookLearningData {
  /// Lernstand je Perikope (Schlüssel: `BookPericope.key`).
  final Map<String, BookCard> cards;

  /// Persönliche Verspräzisierungen (Schlüssel: `BookPericope.key`).
  final Map<String, VersePrecision> precisions;

  /// Lernpläne je Buch (Schlüssel: Buchabkürzung der Perikopenliste).
  final Map<String, BookPlan> plans;

  /// Lernstand je Wissensfrage (Schlüssel: ID der Frage). Gleiches Format
  /// und gleiche Regeln wie bei den Perikopen.
  final Map<String, BookCard> knowledgeCards;

  /// Wissensfragen einbeziehen (Standard: ja). Ausgeschaltet bleiben die
  /// Lernstände in [knowledgeCards] unverändert erhalten.
  bool knowledgeEnabled;

  /// Lernpfade nach Bibelleseplan (Schlüssel: ID des Leseplans). Nur der
  /// Beginn; der Lernstand steht in [cards].
  final Map<String, ReadingPathSettings> readingPaths;

  BookLearningData({
    Map<String, BookCard>? cards,
    Map<String, VersePrecision>? precisions,
    Map<String, BookPlan>? plans,
    Map<String, BookCard>? knowledgeCards,
    this.knowledgeEnabled = true,
    Map<String, ReadingPathSettings>? readingPaths,
  }) : cards = cards ?? {},
       readingPaths = readingPaths ?? {},
       precisions = precisions ?? {},
       plans = plans ?? {},
       knowledgeCards = knowledgeCards ?? {};

  static void _readCards(Object? raw, Map<String, BookCard> into) {
    if (raw is! Map) return;

    for (final entry in raw.entries) {
      final value = entry.value;

      if (value is Map) {
        final id = entry.key.toString();

        into[id] = BookCard.fromJson(id, Map<String, dynamic>.from(value));
      }
    }
  }

  /// Feld im Dokument `pericope_plans` für die Lernpfade nach Bibelleseplan
  /// (neben `plans`; kein neues Dokument).
  static const String readingPathsField = "readingPaths";

  /// Liest die Dokumente; ungültige Einträge werden übergangen.
  factory BookLearningData.fromDocuments({
    Map<String, dynamic>? books,
    Map<String, dynamic>? precision,
    Map<String, dynamic>? plans,
    Map<String, dynamic>? knowledge,
    Map<String, dynamic>? knowledgeSettings,
  }) {
    final data = BookLearningData();

    _readCards(books?["cards"], data.cards);
    _readCards(knowledge?["cards"], data.knowledgeCards);

    final settings = knowledgeSettings?["settings"];

    if (settings is Map && settings["enabled"] is bool) {
      data.knowledgeEnabled = settings["enabled"] as bool;
    }

    final rawPrecisions = precision?["items"];

    if (rawPrecisions is Map) {
      for (final entry in rawPrecisions.entries) {
        final value = VersePrecision.fromJson(entry.value);

        if (value != null) data.precisions[entry.key.toString()] = value;
      }
    }

    final rawPlans = plans?["plans"];

    if (rawPlans is Map) {
      for (final entry in rawPlans.entries) {
        final value = BookPlan.fromJson(entry.key.toString(), entry.value);

        if (value != null) data.plans[value.book] = value;
      }
    }

    final rawPaths = plans?[readingPathsField];

    if (rawPaths is Map) {
      for (final entry in rawPaths.entries) {
        final value = ReadingPathSettings.fromJson(entry.value);

        if (value != null) data.readingPaths[entry.key.toString()] = value;
      }
    }

    PericopeIdMigration.bookData(data);

    return data;
  }
}

/// Speicherort von „Bücher systematisch lernen“.
///
/// Kein neues Speichersystem: angemeldete Nutzer speichern unter
/// `users/{uid}/quiz_settings/…` (dieselbe, bereits freigegebene Collection
/// wie die Buchauswahl des Endlos-Quiz), Gäste lokal über den
/// [LocalLearningStore]. Die Dokumente:
///
///   * `pericope_books`     `{cards: {key: BookCard}}`
///   * `pericope_precision` `{items: {key: VersePrecision}}`
///   * `pericope_plans`     `{plans: {book: BookPlan},
///                           readingPaths: {planId: ReadingPathSettings}}`
///   * `bible_knowledge`    `{cards: {frageId: BookCard}}` (Wissensfragen)
///   * `bible_knowledge_settings` `{settings: {enabled: bool}}`
///
/// Geschrieben werden immer nur die geänderten Einträge (Merge), damit
/// gleichzeitige Änderungen anderer Einträge erhalten bleiben. Die Karten
/// des Endlos-Quiz (`learning_cards`) werden nie geschrieben.
class BookLearningStorage {
  final QuizDocuments documents;

  BookLearningStorage(this.documents);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory BookLearningStorage.forUser(String? uid) => uid == null
      ? LocalBookLearningStorage()
      : BookLearningStorage(FirestoreQuizDocuments(uid));

  Future<BookLearningData> load() async {
    final results = await Future.wait([
      documents.load(LocalLearningStore.pericopeBooks),
      documents.load(LocalLearningStore.pericopePrecision),
      documents.load(LocalLearningStore.pericopePlans),
      documents.load(LocalLearningStore.bibleKnowledge),
      documents.load(LocalLearningStore.bibleKnowledgeSettings),
    ]);

    return BookLearningData.fromDocuments(
      books: results[0],
      precision: results[1],
      plans: results[2],
      knowledge: results[3],
      knowledgeSettings: results[4],
    );
  }

  Future<void> saveKnowledgeCards(List<BookCard> cards) {
    return documents.mergeEntries(LocalLearningStore.bibleKnowledge, "cards", {
      for (final card in cards) card.id: card.toJson(),
    });
  }

  Future<void> saveKnowledgeEnabled(bool enabled) {
    return documents.replaceField(
      LocalLearningStore.bibleKnowledgeSettings,
      "settings",
      {"enabled": enabled},
    );
  }

  Future<void> saveCards(List<BookCard> cards) {
    return documents.mergeEntries(LocalLearningStore.pericopeBooks, "cards", {
      for (final card in cards) card.id: card.toJson(),
    });
  }

  /// `null` entfernt die Präzisierung.
  Future<void> savePrecision(String key, VersePrecision? precision) {
    return documents.mergeEntries(
      LocalLearningStore.pericopePrecision,
      "items",
      {key: precision?.toJson()},
    );
  }

  /// `null` beendet den Lernpfad (Lernstände bleiben).
  Future<void> saveReadingPath(String planId, ReadingPathSettings? settings) {
    return documents.mergeEntries(
      LocalLearningStore.pericopePlans,
      BookLearningData.readingPathsField,
      {planId: settings?.toJson()},
    );
  }

  /// `null` entfernt den Plan des Buchs.
  Future<void> savePlan(String book, BookPlan? plan) {
    return documents.mergeEntries(LocalLearningStore.pericopePlans, "plans", {
      book: plan?.toJson(),
    });
  }
}

/// Gastmodus (lokale Speicherung).
class LocalBookLearningStorage extends BookLearningStorage {
  LocalBookLearningStorage() : super(LocalQuizDocuments());
}
