import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/pericope_id_migration.dart';
import 'package:theologie_lernapp/quiz/quiz_question.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';

/// Einträge von Exodus und Levitikus vor der Neugliederung am 30.10.2026
/// (`Buch|ID|Kapitel,Vers`), ohne die Kapitel-Platzhalter.
const _previousKeys = [
  "Ex|jakobs_nachkommen_in_aegypten|1,1",
  "Ex|die_jugend_des_mose|2,1",
  "Ex|mose_in_midian|2,15",
  "Ex|die_berufung_des_mose|2,23",
  "Ex|die_rueckkehr_des_mose_nach_aegypten|4,18",
  "Ex|die_erfolglosen_verhandlungen_mit_dem_pharao|5,1",
  "Ex|die_klage_des_mose_und_die_verheissung_gottes|5,20",
  "Ex|die_nachkommen_rubens_simeons_und_levis|6,14",
  "Ex|die_aegyptischen_plagen|7,1",
  "Ex|das_pascha|12,1",
  "Ex|die_rettung_am_schilfmeer|13,17",
  "Ex|das_lied_des_mose|15,1",
  "Ex|auf_dem_weg_zum_sinai|15,22",
  "Ex|jitros_rat_die_berufung_von_richtern|18,1",
  "Ex|das_bundesangebot_gottes|19,1",
  "Ex|die_zehn_gebote|20,1",
  "Ex|das_altargesetz|20,22",
  "Ex|hebraeische_sklaven|21,2",
  "Ex|totschlag_und_mord|21,12",
  "Ex|koerperverletzung_durch_menschen|21,18",
  "Ex|koerperverletzung_durch_haustiere|21,28",
  "Ex|ersatz_bei_schaedigung_fremden_viehs|21,33",
  "Ex|ersatz_bei_diebstahl|21,37",
  "Ex|ersatz_bei_fahrlaessigem_feldbrand|22,4",
  "Ex|haftung_fuer_fremdes_eigentum|22,6",
  "Ex|verfuehrung_einer_jungfrau|22,15",
  "Ex|schutz_vor_unterdrueckung_und_ausbeutung|22,20",
  "Ex|erstlingsopfer|22,28",
  "Ex|verhalten_im_rechtsverfahren|23,1",
  "Ex|verhalten_gegen_den_feind|23,4",
  "Ex|verbot_von_rechtsbeugung|23,6",
  "Ex|sabbatjahr_und_sabbatfeier|23,10",
  "Ex|die_drei_hauptfeste|23,14",
  "Ex|opfervorschriften|23,18",
  "Ex|der_bundesschluss|24,1",
  "Ex|das_heiligtum_und_seine_geraete|25,1",
  "Ex|die_priestergewaender|28,1",
  "Ex|die_weihe_der_priester|29,1",
  "Ex|vorschriften_fuer_den_kult|29,38",
  "Ex|die_beauftragung_von_kuenstlern_und_handwerkern|31,1",
  "Ex|die_feier_des_sabbat|31,12",
  "Ex|israels_abfall_das_goldene_kalb|32,1",
  "Ex|die_erneuerung_des_bundes|33,7",
  "Ex|das_gesetz_ueber_den_sabbat|35,1",
  "Ex|die_spenden_fuer_das_heiligtum|35,4",
  "Ex|die_beauftragung_von_kuenstlern_und_handwerkern|35,30",
  "Ex|die_ausstattung_des_heiligtums|36,8",
  "Ex|die_anfertigung_der_priestergewaender|39,1",
  "Ex|der_abschluss_der_arbeiten|39,32",
  "Ex|die_weihe_des_heiligtums|40,1",
  "Lev|das_brandopfer|1,1",
  "Lev|das_speiseopfer|2,1",
  "Lev|das_heilsopfer|3,1",
  "Lev|das_suendopfer_eines_priesters|4,1",
  "Lev|das_suendopfer_der_gemeinde|4,13",
  "Lev|das_suendopfer_eines_sippenhauptes|4,22",
  "Lev|das_suendopfer_eines_gewoehnlichen_israeliten|4,27",
  "Lev|die_schuld_und_suendopfer_fuer_einzelne_vergehen|5,1",
  "Lev|das_schuldopfer_fuer_sakrale_vergehen|5,14",
  "Lev|das_schuldopfer_fuer_unsoziales_verhalten|5,20",
  "Lev|das_brandopfer|6,1",
  "Lev|das_speiseopfer|6,7",
  "Lev|das_opfer_bei_der_priesterweihe|6,12",
  "Lev|das_suendopfer|6,17",
  "Lev|das_schuldopfer|7,1",
  "Lev|das_heilsopfer|7,11",
  "Lev|das_verbot_von_fett_und_blutgenuss|7,22",
  "Lev|die_feueropfer|7,28",
  "Lev|die_priesterweihe|8,1",
  "Lev|das_weiheopfer_des_hohenpriesters|9,1",
  "Lev|die_strafe_fuer_unrechtmaessiges_opfern|10,1",
  "Lev|der_dienst_im_heiligtum|10,6",
  "Lev|reine_und_unreine_tiere|11,1",
  "Lev|die_reinigung_der_woechnerin|12,1",
  "Lev|der_aussatz_an_menschen|13,1",
  "Lev|der_aussatz_an_kleidern|13,47",
  "Lev|die_reinigungsriten_fuer_vom_aussatz_geheilte|14,1",
  "Lev|der_aussatz_an_haeusern|14,33",
  "Lev|die_unreinheit_bei_maennern|15,1",
  "Lev|die_unreinheit_bei_frauen|15,19",
  "Lev|das_ritual_fuer_den_versoehnungstag|16,1",
  "Lev|schlachtungen_und_blutgenuss|17,1",
  "Lev|einleitung|18,1",
  "Lev|unzucht_unter_verwandten|18,6",
  "Lev|andere_unzuchtvergehen|18,19",
  "Lev|schlussmahnung|18,24",
  "Lev|einleitung|19,1",
  "Lev|die_ehrfurcht_gegenueber_den_eltern|19,3",
  "Lev|die_rechte_einstellung_zum_heilsopfer|19,5",
  "Lev|das_verbot_der_nachlese|19,9",
  "Lev|soziales_verhalten_und_naechstenliebe|19,11",
  "Lev|unzucht_mit_der_nebenfrau_eines_anderen|19,20",
  "Lev|die_erstlingsfruechte|19,23",
  "Lev|das_verbot_fremder_kultbraeuche|19,26",
  "Lev|verhalten_gegen_fremde|19,33",
  "Lev|uebervorteilung|19,35",
  "Lev|das_kinderopfer|20,1",
  "Lev|die_totenbeschwoerung_und_wahrsagerei|20,6",
  "Lev|unzuchtverbrechen|20,11",
  "Lev|die_unzucht_mit_verwandten|20,19",
  "Lev|schlussmahnung|20,22",
  "Lev|das_verhalten_beim_begraebnis_von_verwandten|21,1",
  "Lev|ehehindernisse_fuer_priester|21,7",
  "Lev|das_verhalten_des_hohenpriesters_bei_todesfaellen|21,10",
  "Lev|ehehindernisse_fuer_den_hohenpriester|21,13",
  "Lev|die_koerperliche_tauglichkeit_fuer_das_priesteramt|21,16",
  "Lev|der_ausschluss_von_priestern_vom_genuss_der_opfergaben|22,1",
  "Lev|der_ausschluss_der_laien_vom_genuss_der_opfergaben|22,10",
  "Lev|die_tauglichkeit_der_opfertiere|22,17",
  "Lev|einzelbestimmungen_ueber_opfertiere|22,26",
  "Lev|schlussmahnung|22,31",
  "Lev|einleitung|23,1",
  "Lev|das_pascha_und_das_fest_der_ungesaeuerten_brote|23,4",
  "Lev|die_erstlingsfruechte|23,9",
  "Lev|das_wochenfest_pfingstfest|23,15",
  "Lev|der_neujahrstag|23,23",
  "Lev|das_versoehnungsfest|23,26",
  "Lev|das_laubhuettenfest|23,33",
  "Lev|schlussbemerkung|23,37",
  "Lev|einzelbestimmung_fuer_das_laubhuettenfest|23,39",
  "Lev|einzelbestimmungen_ueber_den_leuchter_und_den_tisch_fuer_die_schaubrote|24,1",
  "Lev|einschub_die_laesterung_des_gottesnamens|24,10",
  "Lev|das_brachjahr|25,2",
  "Lev|das_jubeljahr|25,8",
  "Lev|sonderbestimmungen_fuer_die_leviten|25,32",
  "Lev|soziales_verhalten|25,35",
  "Lev|die_freilassung_israelitischer_sklaven|25,39",
  "Lev|die_sklaven_aus_fremden_voelkern|25,44",
  "Lev|das_loskaufrecht_israelitischer_sklaven_bei_fremden|25,47",
  "Lev|die_grundforderungen_gottes|26,1",
  "Lev|die_segenszusage_fuer_gehorsam|26,3",
  "Lev|strafandrohung_und_fluch_fuer_ungehorsam|26,14",
  "Lev|umkehr_und_vergebung|26,39",
  "Lev|bei_personen|27,1",
  "Lev|bei_tieren|27,9",
  "Lev|bei_haeusern|27,14",
  "Lev|bei_grundstuecken|27,16",
  "Lev|sonderfaelle|27,26",
];

/// Frühere Kapitel-Platzhalter („Ex 8“) aller Bücher; Ps 43 hatte keine
/// andere Perikope und heißt jetzt „Bitte um Gottes Licht und Wahrheit“.
const _placeholders = [
  "ex_3",
  "ex_8",
  "ex_9",
  "ex_10",
  "ex_11",
  "ex_14",
  "ex_16",
  "ex_17",
  "ex_26",
  "ex_27",
  "ex_30",
  "ex_32",
  "ex_34",
  "ex_37",
  "ex_38",
  "num_4",
  "num_14",
  "num_17",
  "num_23",
  "num_24",
  "num_26",
  "num_29",
  "num_34",
  "jos_12",
  "jos_17",
  "jos_19",
  "1sam_1",
  "2sam_2",
  "2koen_2",
  "2chr_2",
  "ijob_39",
  "ijob_41",
  "spr_2",
  "spr_3",
  "spr_7",
  "spr_9",
  "spr_11",
  "spr_12",
  "spr_13",
  "spr_14",
  "spr_15",
  "spr_16",
  "spr_17",
  "spr_18",
  "spr_19",
  "spr_20",
  "spr_21",
  "spr_26",
  "spr_27",
  "spr_28",
  "spr_29",
  "hld_1",
  "hld_2",
  "hld_3",
  "hld_4",
  "hld_5",
  "hld_6",
  "hld_7",
  "hld_8",
  "jes_16",
  "jes_53",
  "jes_64",
  "dan_4",
  "dan_11",
  "dan_12",
  "apg_26",
  "1kor_1",
  "weish_2",
  "bar_5",
  "weish_5",
  "sir_12",
  "weish_12",
  "weish_14",
  "weish_15",
];

(int, int) _start(Perikope p) => (p.startChapter, p.startVerse);
(int, int) _end(Perikope p) => (p.endChapter, p.endVerse);

// Titel, der nur eine Stelle nennt: „Ex 8“, „Lev 3,1-5“.
final _bareReference = RegExp(r'^\S+ \d+([,.\-–]\d+)*$');

void main() {
  final perikopen = [
    for (final e
        in jsonDecode(File("assets/perikopen.json").readAsStringSync()) as List)
      Perikope.fromJson(Map<String, dynamic>.from(e)),
  ];
  final catalog = BookCatalog.fromPerikopen(perikopen);
  final keys = {for (final p in perikopen) BookPericope.keyOf(p)};

  List<Perikope> book(String b) =>
      catalog.pericopesOf(b).map((p) => p.perikope).toList();

  group("Überschriften der ganzen Liste", () {
    test("kein Titel ist nur eine Bibelstelle", () {
      final bare = [
        for (final p in perikopen)
          if (_bareReference.hasMatch(p.title.trim())) "${p.book} ${p.id}",
      ];
      expect(bare, isEmpty);
    });

    test("die früheren Kapitel-Platzhalter sind entfernt", () {
      final ids = {for (final p in perikopen) p.id};
      for (final id in _placeholders) {
        expect(ids.contains(id), isFalse, reason: id);
      }
    });

    test("allgemeine IDs fassen keine fremden Texte mehr zusammen", () {
      for (final id in ["einleitung", "schlussmahnung", "schluss"]) {
        final places = perikopen.where((p) => p.id == id).toList();
        expect(places, hasLength(1), reason: id);
      }
    });
  });

  for (final (b, last, count) in [
    ("Ex", (40, 38), 111),
    ("Lev", (27, 34), 91),
  ]) {
    group(b, () {
      final list = book(b);

      test("lückenlos und ohne Überschneidung von 1,1 bis $last", () {
        expect(list, hasLength(count));
        expect(_start(list.first), (1, 1));
        expect(_end(list.last), last);
        for (var i = 1; i < list.length; i++) {
          final prev = _end(list[i - 1]);
          final next = _start(list[i]);
          final following =
              next == (prev.$1, prev.$2 + 1) ||
              (next.$1 == prev.$1 + 1 && next.$2 == 1);
          expect(following, isTrue, reason: list[i].id);
        }
      });

      test("eindeutige Überschriften und IDs, keine Sammeltitel", () {
        final titles = list.map((p) => p.title).toList();
        expect(titles.toSet(), hasLength(titles.length));
        for (final p in list) {
          // Eine ID nur an dieser Stelle: Das Endlos-Quiz fasst gleiche IDs
          // zu einer Frage zusammen.
          // Ausnahme: Laubhüttenfest Lev 23,33-36 und Dtn 16,13-15 sind
          // dieselbe Festordnung (Parallele).
          if (p.id != "das_laubhuettenfest") {
            expect(
              perikopen.where((o) => o.id == p.id),
              hasLength(1),
              reason: p.id,
            );
          }
          expect(
            p.title,
            isNot(
              anyOf(
                "Einleitung",
                "Schlussmahnung",
                "Schlussbemerkung",
                "Bei Personen",
                "Sonderfälle",
              ),
            ),
          );
          expect((p.required, p.precision), (true, "chapter"), reason: p.id);
        }
      });
    });
  }

  test("Exodus: die zehn Plagen einzeln, wie auf der Folie", () {
    final plagen = [
      for (final p in book("Ex"))
        if (RegExp(r'^\d+\. Plage: ').hasMatch(p.title)) p.title,
    ];
    expect(plagen, [
      "1. Plage: Das Nilwasser wird zu Blut",
      "2. Plage: Frösche",
      "3. Plage: Stechmücken",
      "4. Plage: Bremsen",
      "5. Plage: Viehpest",
      "6. Plage: Beulen und Geschwüre",
      "7. Plage: Hagel",
      "8. Plage: Heuschrecken",
      "9. Plage: Finsternis",
      "10. Plage: Tötung der Erstgeburt",
    ]);
    String at(String title) {
      final p = book("Ex").singleWhere((p) => p.title == title);
      return "${p.startChapter},${p.startVerse}-${p.endChapter},${p.endVerse}";
    }

    expect(at("2. Plage: Frösche"), "7,26-8,11");
    expect(at("Das Lied der Mirjam"), "15,19-15,21");
    expect(at("Die neuen Tafeln und die Gnadenformel"), "34,1-34,9");
    expect(at("Die Offenbarung des Gottesnamens"), "3,13-3,22");
  });

  group("Lernstand bleibt", () {
    test(
      "jeder frühere Schlüssel besteht weiter oder hat einen Nachfolger",
      () {
        final successors = {
          ...PericopeIdMigration.renamedKeys.values,
          ...PericopeIdMigration.movedKeys.values,
        };
        for (final key in PericopeIdMigration.renamedKeys.values) {
          expect(keys, isNot(contains(key)), reason: key);
        }
        for (final key in _previousKeys) {
          expect(
            keys.contains(key) || successors.contains(key),
            isTrue,
            reason: key,
          );
        }
      },
    );

    test("alle neuen Schlüssel und IDs der Übernahme stehen in der Liste", () {
      final ids = {for (final p in perikopen) p.id};
      for (final id in PericopeIdMigration.renamedIds.keys) {
        expect(ids, contains(id));
      }
      for (final key in [
        ...PericopeIdMigration.renamedKeys.keys,
        ...PericopeIdMigration.movedKeys.keys,
      ]) {
        expect(keys, contains(key));
      }
    });

    test("übernommen wird nur von Schlüsseln, die es nicht mehr gibt", () {
      // Sonst bekäme ein neuer Teil auch alles, was künftig unter dem
      // weiter bestehenden Schlüssel gelernt wird.
      final ids = {for (final p in perikopen) p.id};
      for (final from in PericopeIdMigration.renamedIds.values) {
        expect(ids, isNot(contains(from)), reason: from);
      }
      for (final key in [
        ...PericopeIdMigration.renamedKeys.values,
        ...PericopeIdMigration.movedKeys.values,
      ]) {
        expect(keys, isNot(contains(key)), reason: key);
      }
    });

    test("Endlos-Quiz: jede Frage hat eine Stelle, alte Karte bleibt", () {
      final cards = {
        "die_aegyptischen_plagen": LearningCard(
          id: "die_aegyptischen_plagen",
          stability: 8,
        ),
      };
      PericopeIdMigration.perikopeCards(cards);
      expect(cards.keys, ["die_aegyptischen_plagen"]);
      final questions = QuizQuestion.fromPerikopen(perikopen);
      for (final id in ["die_aegyptischen_plagen", "das_lied_des_mose"]) {
        expect(
          questions.singleWhere((q) => q.id == id).variants,
          hasLength(1),
          reason: id,
        );
      }
    });

    test("Bücher lernen: Karte ja, Präzisierung der alten Stelle nein", () {
      final old = {"s": 9.0, "d": 3.0, "n": 2};
      final data = BookLearningData.fromDocuments(
        books: {
          "cards": {
            "Ex|die_berufung_des_mose|2,23": old,
            "Lev|einleitung|19,1": old,
            "Ex|die_aegyptischen_plagen|7,1": old,
            "Ex|jakobs_nachkommen_in_aegypten|1,1": old,
          },
        },
        precision: {
          "items": {
            "Ex|die_berufung_des_mose|2,23": {
              "startChapter": 3,
              "startVerse": 1,
              "endChapter": 4,
              "endVerse": 17,
            },
            "Lev|einleitung|19,1": {
              "startChapter": 19,
              "startVerse": 2,
              "endChapter": 19,
              "endVerse": 2,
            },
          },
        },
      );
      for (final key in [
        "Ex|die_berufung_des_mose|3,1",
        "Ex|die_offenbarung_des_gottesnamens|3,13",
        "Ex|aaron_als_sprecher_des_mose|4,10",
        "Ex|die_aegyptischen_plagen|7,14",
        "Ex|die_achte_plage_heuschrecken|10,1",
      ]) {
        expect(data.cards[key]!.stability, 9, reason: key);
        expect(data.precisions.containsKey(key), isFalse, reason: key);
      }
      // Der erste Teil behält Anfang und ID, die übrigen beginnen neu.
      expect(data.cards["Ex|jakobs_nachkommen_in_aegypten|1,1"], isNotNull);
      expect(
        data.cards.containsKey(
          "Ex|die_unterdrueckung_israels_durch_fronarbeit|1,8",
        ),
        isFalse,
      );
      // Gleiche Stelle unter neuer ID: Präzisierung gilt weiter.
      expect(data.cards["Lev|der_ruf_zur_heiligkeit|19,1"]!.stability, 9);
      expect(data.precisions["Lev|der_ruf_zur_heiligkeit|19,1"], isNotNull);
    });
  });
}
