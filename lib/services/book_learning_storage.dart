import '../quiz/books/book_learning_status.dart';
import '../quiz/books/book_plan.dart';
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

  BookLearningData({
    Map<String, BookCard>? cards,
    Map<String, VersePrecision>? precisions,
    Map<String, BookPlan>? plans,
  }) : cards = cards ?? {},
       precisions = precisions ?? {},
       plans = plans ?? {};

  /// Liest die drei Dokumente; ungültige Einträge werden übergangen.
  factory BookLearningData.fromDocuments({
    Map<String, dynamic>? books,
    Map<String, dynamic>? precision,
    Map<String, dynamic>? plans,
  }) {
    final data = BookLearningData();

    final rawCards = books?["cards"];

    if (rawCards is Map) {
      for (final entry in rawCards.entries) {
        final value = entry.value;

        if (value is Map) {
          final id = entry.key.toString();

          data.cards[id] = BookCard.fromJson(
            id,
            Map<String, dynamic>.from(value),
          );
        }
      }
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
///   * `pericope_plans`     `{plans: {book: BookPlan}}`
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
    ]);

    return BookLearningData.fromDocuments(
      books: results[0],
      precision: results[1],
      plans: results[2],
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
