import 'package:cloud_firestore/cloud_firestore.dart';

import '../quiz/books/book_learning_status.dart';
import '../quiz/books/book_plan.dart';
import '../quiz/books/verse_precision.dart';
import 'local_learning_store.dart';

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
abstract class BookLearningStorage {
  Future<BookLearningData> load();

  Future<void> saveCards(List<BookCard> cards);

  /// `null` entfernt die Präzisierung.
  Future<void> savePrecision(String key, VersePrecision? precision);

  /// `null` entfernt den Plan des Buchs.
  Future<void> savePlan(String book, BookPlan? plan);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory BookLearningStorage.forUser(String? uid) {
    return uid == null
        ? LocalBookLearningStorage()
        : FirestoreBookLearningStorage(uid);
  }
}

class LocalBookLearningStorage implements BookLearningStorage {
  LocalLearningStore get _store => LocalLearningStore.instance;

  @override
  Future<BookLearningData> load() async {
    return BookLearningData.fromDocuments(
      books: await _store.loadQuizDocument(LocalLearningStore.pericopeBooks),
      precision: await _store.loadQuizDocument(
        LocalLearningStore.pericopePrecision,
      ),
      plans: await _store.loadQuizDocument(LocalLearningStore.pericopePlans),
    );
  }

  @override
  Future<void> saveCards(List<BookCard> cards) {
    return _store.mergeQuizDocument(LocalLearningStore.pericopeBooks, "cards", {
      for (final card in cards) card.id: card.toJson(),
    });
  }

  @override
  Future<void> savePrecision(String key, VersePrecision? precision) {
    return _store.mergeQuizDocument(
      LocalLearningStore.pericopePrecision,
      "items",
      {key: precision?.toJson()},
    );
  }

  @override
  Future<void> savePlan(String book, BookPlan? plan) {
    return _store.mergeQuizDocument(LocalLearningStore.pericopePlans, "plans", {
      book: plan?.toJson(),
    });
  }
}

class FirestoreBookLearningStorage implements BookLearningStorage {
  final String uid;

  FirestoreBookLearningStorage(this.uid);

  DocumentReference<Map<String, dynamic>> _doc(String name) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("quiz_settings")
        .doc(name);
  }

  @override
  Future<BookLearningData> load() async {
    final results = await Future.wait([
      _doc(LocalLearningStore.pericopeBooks).get(),
      _doc(LocalLearningStore.pericopePrecision).get(),
      _doc(LocalLearningStore.pericopePlans).get(),
    ]);

    return BookLearningData.fromDocuments(
      books: results[0].data(),
      precision: results[1].data(),
      plans: results[2].data(),
    );
  }

  @override
  Future<void> saveCards(List<BookCard> cards) {
    if (cards.isEmpty) return Future.value();

    return _doc(LocalLearningStore.pericopeBooks).set({
      "cards": {for (final card in cards) card.id: card.toJson()},
    }, SetOptions(merge: true));
  }

  @override
  Future<void> savePrecision(String key, VersePrecision? precision) {
    return _doc(LocalLearningStore.pericopePrecision).set({
      "items": {key: precision?.toJson() ?? FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  @override
  Future<void> savePlan(String book, BookPlan? plan) {
    return _doc(LocalLearningStore.pericopePlans).set({
      "plans": {book: plan?.toJson() ?? FieldValue.delete()},
    }, SetOptions(merge: true));
  }
}
