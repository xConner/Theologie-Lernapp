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
    // Seit 30.10.2026 (Exodus, Levitikus, frühere Kapitel-Platzhalter,
    // allgemeine IDs wie „einleitung“): gleiche Stelle, eigene ID.
    // Ex
    "Ex|bezalel_und_oholiab_beginnen_das_werk|35,30":
        "Ex|die_beauftragung_von_kuenstlern_und_handwerkern|35,30",
    // Lev
    "Lev|anweisungen_zum_brandopfer|6,1": "Lev|das_brandopfer|6,1",
    "Lev|anweisungen_zum_speiseopfer|6,7": "Lev|das_speiseopfer|6,7",
    "Lev|anweisungen_zum_heilsopfer|7,11": "Lev|das_heilsopfer|7,11",
    "Lev|gegen_die_sitten_aegyptens_und_kanaans|18,1": "Lev|einleitung|18,1",
    "Lev|der_ruf_zur_heiligkeit|19,1": "Lev|einleitung|19,1",
    "Lev|mahnung_gottes_namen_nicht_zu_entweihen|22,31":
        "Lev|schlussmahnung|22,31",
    "Lev|die_erstlingsgarbe|23,9": "Lev|die_erstlingsfruechte|23,9",
    // Dtn
    "Dtn|gottes_kommen_vom_sinai|33,2": "Dtn|einleitung|33,2",
    // Koh
    "Koh|wer_weiss_was_gut_ist_fuer_den_menschen|6,11": "Koh|einleitung|6,11",
    // Bar
    "Bar|das_buch_baruch_wird_nach_jerusalem_gesandt|1,1": "Bar|einleitung|1,1",
    // Tob
    "Tob|die_herkunft_tobits|1,1": "Tob|einleitung|1,1",
    // Bar
    "Bar|der_brief_des_jeremia_warnung_vor_babels_goetzen|6,1":
        "Bar|einleitung|6,1",
    // Weish
    "Weish|salomo_will_das_wesen_der_weisheit_enthuellen|6,22":
        "Weish|einleitung|6,22",
    "Weish|weisheit_nur_als_gabe_gottes|8,19": "Weish|einleitung|8,19",
    "Weish|die_verwandelte_schoepfung|19,18": "Weish|schluss|19,18",
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
    // Seit 30.10.2026: Nur wo der frühere Schlüssel nicht mehr in der Liste
    // steht. Behält ein Teil Anfang und ID, bleibt der Lernstand dort, und die
    // übrigen Teile beginnen neu; sonst würde eine Kopie auch alles, was
    // künftig unter dem alten Schlüssel gelernt wird, in sie übertragen.
    // Ex
    "Ex|gott_hoert_das_seufzen_israels|2,23": "Ex|die_berufung_des_mose|2,23",
    "Ex|die_berufung_des_mose|3,1": "Ex|die_berufung_des_mose|2,23",
    "Ex|die_offenbarung_des_gottesnamens|3,13": "Ex|die_berufung_des_mose|2,23",
    "Ex|zeichen_zur_beglaubigung_des_mose|4,1": "Ex|die_berufung_des_mose|2,23",
    "Ex|aaron_als_sprecher_des_mose|4,10": "Ex|die_berufung_des_mose|2,23",
    "Ex|die_klage_des_mose_und_die_verheissung_gottes|5,22":
        "Ex|die_klage_des_mose_und_die_verheissung_gottes|5,20",
    "Ex|die_erneute_berufung_des_mose|6,2":
        "Ex|die_klage_des_mose_und_die_verheissung_gottes|5,20",
    "Ex|aaron_als_prophet_des_mose|6,28": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|aarons_stab_wird_zur_schlange|7,8": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_aegyptischen_plagen|7,14": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_zweite_plage_froesche|7,26": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_dritte_plage_stechmuecken|8,12": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_vierte_plage_bremsen|8,16": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_fuenfte_plage_viehpest|9,1": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_sechste_plage_geschwuere|9,8": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_siebte_plage_hagel|9,13": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_achte_plage_heuschrecken|10,1": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|die_neunte_plage_finsternis|10,21": "Ex|die_aegyptischen_plagen|7,1",
    "Ex|ankuendigung_der_toetung_der_erstgeborenen|11,1":
        "Ex|die_aegyptischen_plagen|7,1",
    "Ex|gottes_fuehrung_in_wolken_und_feuersaeule|13,17":
        "Ex|die_rettung_am_schilfmeer|13,17",
    "Ex|die_rettung_am_schilfmeer|14,1": "Ex|die_rettung_am_schilfmeer|13,17",
    "Ex|das_lied_des_mose_am_schilfmeer|15,1": "Ex|das_lied_des_mose|15,1",
    "Ex|das_lied_der_mirjam|15,19": "Ex|das_lied_des_mose|15,1",
    "Ex|jitros_besuch_bei_mose|18,1":
        "Ex|jitros_rat_die_berufung_von_richtern|18,1",
    "Ex|jitros_rat_die_berufung_von_richtern|18,13":
        "Ex|jitros_rat_die_berufung_von_richtern|18,1",
    "Ex|hebraeische_sklaven|21,1": "Ex|hebraeische_sklaven|21,2",
    "Ex|erstlingsopfer|22,27": "Ex|erstlingsopfer|22,28",
    "Ex|das_offenbarungszelt_ausserhalb_des_lagers|33,7":
        "Ex|die_erneuerung_des_bundes|33,7",
    "Ex|mose_bittet_gottes_herrlichkeit_zu_sehen|33,12":
        "Ex|die_erneuerung_des_bundes|33,7",
    "Ex|die_neuen_tafeln_und_die_gnadenformel|34,1":
        "Ex|die_erneuerung_des_bundes|33,7",
    "Ex|der_erneuerte_bundesschluss|34,10": "Ex|die_erneuerung_des_bundes|33,7",
    "Ex|das_strahlende_gesicht_des_mose|34,29":
        "Ex|die_erneuerung_des_bundes|33,7",
    // Lev
    "Lev|unzucht_mit_der_nebenfrau_eines_anderen|19,19":
        "Lev|unzucht_mit_der_nebenfrau_eines_anderen|19,20",
    "Lev|verhalten_gegen_fremde|19,32": "Lev|verhalten_gegen_fremde|19,33",
    "Lev|unzuchtverbrechen|20,9": "Lev|unzuchtverbrechen|20,11",
    "Lev|die_unzucht_mit_verwandten|20,18":
        "Lev|die_unzucht_mit_verwandten|20,19",
    "Lev|mahnung_zur_absonderung_von_den_voelkern|20,22":
        "Lev|schlussmahnung|20,22",
    "Lev|die_festzeiten_und_der_sabbat|23,1": "Lev|einleitung|23,1",
    "Lev|das_brachjahr|25,1": "Lev|das_brachjahr|25,2",
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
