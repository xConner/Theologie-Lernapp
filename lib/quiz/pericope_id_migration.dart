import '../models/greek/vocabulary/learning_card.dart';
import '../services/book_learning_storage.dart';
import 'books/book_learning_status.dart';

/// Perikopen, die in der Perikopenliste nachträglich eine eigene ID oder
/// einen anderen Anfang bekommen haben.
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
  ///
  /// Seit 24.10.2026 teilt die Liste einige Genesis-Perikopen nach der
  /// Übung Bibelkunde AT (Sitzung 2, Folien 8–14); die neuen Teile
  /// übernehmen den Stand der bisherigen Perikope.
  static const Map<String, String> renamedIds = {
    "noahs_erwaehlung_und_bau_der_arche": "die_bosheit_der_menschen",
    // Gen 6,1-8 → 6,1-4 und 6,5-8
    "engelehen_und_goettersoehne": "die_bosheit_der_menschen",
    // Gen 11,10-32 → 11,10-26 und 11,27-32
    "uebergang_zur_erzelterngeschichte": "die_vorfahren_abrahams",
    // Gen 18 → 18,1-15 und 18,16-33
    "fuerbitte_abrahams_fuer_sodom": "gott_zu_gast_bei_abraham",
    // Gen 27,41–28,22 → 27,46–28,5, 28,6-9 und 28,10-22
    "esaus_frauen": "jakobs_flucht_nach_haran",
    "jakobs_traum": "jakobs_flucht_nach_haran",
    // Gen 29,1–30,24 → 29,1-30 und 29,31–30,24
    "jakobs_kinder": "jakobs_frauen_und_soehne",
  };

  /// Neuer → früherer Schlüssel einer Buch-Karte (`BookPericope.key`) für
  /// dieselbe Stelle unter neuer ID: Karte und Präzisierung gelten weiter.
  static const Map<String, String> renamedKeys = {
    "Gen|noahs_erwaehlung_und_bau_der_arche|6,9":
        "Gen|die_bosheit_der_menschen|6,9",
  };

  /// Neuer → früherer Schlüssel einer Buch-Karte, deren Stelle sich
  /// geändert hat (Teilung oder verschobene Grenze). Die Karte gilt weiter,
  /// eine persönliche Präzisierung nicht: Sie beschrieb die frühere Stelle.
  static const Map<String, String> movedKeys = {
    "Gen|engelehen_und_goettersoehne|6,1": "Gen|die_bosheit_der_menschen|6,1",
    "Gen|die_bosheit_der_menschen|6,5": "Gen|die_bosheit_der_menschen|6,1",
    "Gen|uebergang_zur_erzelterngeschichte|11,27":
        "Gen|die_vorfahren_abrahams|11,10",
    "Gen|fuerbitte_abrahams_fuer_sodom|18,16":
        "Gen|gott_zu_gast_bei_abraham|18,1",
    "Gen|verkauf_des_erstgeburtsrechts_an_jakob|25,29":
        "Gen|verkauf_des_erstgeburtsrechts_an_jakob|25,27",
    "Gen|jakobs_flucht_nach_haran|27,46": "Gen|jakobs_flucht_nach_haran|27,41",
    "Gen|esaus_frauen|28,6": "Gen|jakobs_flucht_nach_haran|27,41",
    "Gen|jakobs_traum|28,10": "Gen|jakobs_flucht_nach_haran|27,41",
    "Gen|jakobs_kinder|29,31": "Gen|jakobs_frauen_und_soehne|29,1",
    "Gen|die_soehne_jakobs_und_der_tod_isaaks|35,27":
        "Gen|die_soehne_jakobs_und_der_tod_isaaks|35,21",
    "Gen|josef_im_gefaengnis|39,20": "Gen|josef_im_gefaengnis|39,22",
    "Gen|jakobs_tod_und_begraebnis|49,29":
        "Gen|jakobs_tod_und_begraebnis|49,28",
    "Gen|josefs_letzte_lebensjahre_und_sein_tod|50,15":
        "Gen|josefs_letzte_lebensjahre_und_sein_tod|50,14",
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
    void copyCard(String key, String from) {
      final card = data.cards[from];
      if (card != null && !data.cards.containsKey(key)) {
        data.cards[key] = BookCard.fromJson(key, card.toJson());
      }
    }

    for (final e in renamedKeys.entries) {
      copyCard(e.key, e.value);
      final precision = data.precisions[e.value];
      if (precision != null && !data.precisions.containsKey(e.key)) {
        data.precisions[e.key] = precision;
      }
    }

    for (final e in movedKeys.entries) {
      copyCard(e.key, e.value);
    }
  }
}
