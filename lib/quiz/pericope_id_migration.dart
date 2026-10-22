import '../models/greek/vocabulary/learning_card.dart';
import '../services/book_learning_storage.dart';
import 'books/book_learning_status.dart';

/// Perikopen, die in der Perikopenliste nachträglich eine eigene ID
/// bekommen haben, weil sich zwei Einträge eine ID teilten.
///
/// Gespeicherte Lernstände bleiben unter der früheren ID bzw. dem früheren
/// Schlüssel liegen. Solange die neue ID noch keine eigene Karte hat, gilt
/// eine Kopie der früheren Karte; geschrieben wird sie erst beim nächsten
/// Verbuchen. So geht kein Lernstand verloren und nichts wird gelöscht.
class PericopeIdMigration {
  PericopeIdMigration._();

  /// Neue ID → frühere ID (Endlos-Quiz, `learning_cards`).
  ///
  /// Gen 6,9-22 („Noahs Erwählung. Bau der Arche“) stand bis 22.10.2026
  /// unter `die_bosheit_der_menschen` wie Gen 6,1-8; das Endlos-Quiz fasste
  /// beide zu einer Frage zusammen.
  static const Map<String, String> renamedIds = {
    "noahs_erwaehlung_und_bau_der_arche": "die_bosheit_der_menschen",
  };

  /// Neuer → früherer Schlüssel einer Buch-Karte (`BookPericope.key`).
  static const Map<String, String> renamedKeys = {
    "Gen|noahs_erwaehlung_und_bau_der_arche|6,9":
        "Gen|die_bosheit_der_menschen|6,9",
  };

  /// Ergänzt die Karten des Endlos-Quiz um Kopien für umbenannte IDs.
  static Map<String, LearningCard> perikopeCards(
    Map<String, LearningCard> cards,
  ) {
    for (final e in renamedIds.entries) {
      final old = cards[e.value];
      if (old == null || cards.containsKey(e.key)) continue;
      cards[e.key] = LearningCard.fromJson(e.key, old.toJson());
    }
    return cards;
  }

  /// Ergänzt Buch-Karten und Präzisierungen um Kopien für umbenannte
  /// Schlüssel.
  static void bookData(BookLearningData data) {
    for (final e in renamedKeys.entries) {
      final card = data.cards[e.value];
      if (card != null && !data.cards.containsKey(e.key)) {
        data.cards[e.key] = BookCard.fromJson(e.key, card.toJson());
      }
      final precision = data.precisions[e.value];
      if (precision != null && !data.precisions.containsKey(e.key)) {
        data.precisions[e.key] = precision;
      }
    }
  }
}
