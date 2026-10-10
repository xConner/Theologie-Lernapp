import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';

import 'perikopen_validator.dart';
import 'test_asset_bundle.dart';

Map<String, dynamic> entry(
  String book,
  int startChapter,
  int startVerse,
  int endChapter,
  int endVerse, {
  String? id,
  String? title,
}) {
  return {
    "id": id ?? "${book}_${startChapter}_$startVerse",
    "title": title ?? "Titel $book $startChapter,$startVerse",
    "book": book,
    "startChapter": startChapter,
    "startVerse": startVerse,
    "endChapter": endChapter,
    "endVerse": endVerse,
    "required": true,
    "precision": "chapter",
  };
}

void main() {
  late List<BibleTranslation> translations;
  late PericopeValidator validator;
  late List<dynamic> list;

  List<String> codes(List<Map<String, dynamic>> entries) =>
      validator.validate(entries).map((i) => i.code).toList();

  Map<String, dynamic> byId(String id, {String? book}) =>
      list
              .where(
                (e) => e["id"] == id && (book == null || e["book"] == book),
              )
              .single
          as Map<String, dynamic>;

  setUpAll(() async {
    translations = await AssetBibleTextSource(
      bundle: FileAssetBundle(),
    ).loadTranslations();

    validator = PericopeValidator(translations: translations);

    list = jsonDecode(File("assets/perikopen.json").readAsStringSync());
  });

  group("Ausgelieferte Perikopenliste", () {
    test("Jede Stelle ist gültig, widerspruchsfrei und steht in der "
        "Reihenfolge der Bücher", () {
      final issues = validator.validate(list);

      expect(issues, isEmpty, reason: issues.join("\n"));
    });

    test("Die bekannten Ausnahmen sind genau die, die die Liste braucht", () {
      final strict = PericopeValidator(
        translations: translations,
        exceptions: const [],
      );

      expect(
        {for (final i in strict.validate(list)) "${i.id}|${i.code}"},
        {
          for (final e in PericopeValidator.knownExceptions)
            "${e.id}|${e.code}",
        },
      );
    });

    test("Lücken werden nur aufgelistet, nicht geschlossen", () {
      final gaps = validator.gaps(list);

      // Verse ohne eigene Perikope: Überleitung und Buchüberschrift.
      expect(gaps["Mt"], contains("11,1"));
      expect(gaps["Hos"], contains("1,1"));

      // Lückenlos eingeteilte Bücher.
      expect(gaps.containsKey("Gen"), isFalse);
      expect(gaps.containsKey("Röm"), isFalse);
    });

    test("Berichtigte Stellen", () {
      String at(String id) => PericopeValidator.referenceOf(byId(id));

      // 1. Mose 31 hat in deutscher Zählung 54 Verse; 31,55 der englischen
      // Zählung ist dort 32,1 und gehört zur nächsten Perikope.
      expect(at("jakobs_trennung_von_laban"), "Gen 31,1–31,54");
      expect(at("die_boten_und_geschenke_fuer_esau"), "Gen 32,1–32,22");

      // Stand im falschen Kapitel (Am 1,10–15).
      expect(at("die_beugung_des_rechts"), "Am 5,10–5,15");

      // Endete einen Vers vor dem Psalmende.
      expect(at("klage_und_vertrauen_eines_alleingelassenen"), "Ps 55,1–55,24");

      // Kapitelfragen umfassen ihr Kapitel – einmal, nicht in mehreren
      // widersprüchlichen Fassungen.
      expect(at("1sam_1"), "1Sam 1,1–1,28");
      expect(at("2sam_2"), "2Sam 2,1–2,32");
      expect(at("2koen_2"), "2Kön 2,1–2,25");
      expect(at("2chr_2"), "2Chr 2,1–2,17");
      expect(at("1kor_1"), "1Kor 1,1–1,31");
    });

    test("Perikopen über eine Kapitelgrenze bleiben vollständig", () {
      expect(
        PericopeValidator.referenceOf(
          byId("der_krieg_zwischen_david_und_ischbaal"),
        ),
        "2Sam 2,12–3,1",
      );
      expect(
        PericopeValidator.referenceOf(byId("das_gastmahl_belschazzars")),
        "Dan 5,1–6,1",
      );
    });

    test("Parallelstellen und übergeordnete Abschnitte bleiben erhalten", () {
      expect(
        list.where((e) => e["id"] == "speisung5000").map((e) => e["book"]),
        ["Mt", "Mk", "Lk"],
      );

      // Die Bergpredigt umfasst ihre Unterabschnitte.
      expect(
        PericopeValidator.referenceOf(
          byId("die_bergpredigt_die_rede_von_der_wahren_gerechtigkeit"),
        ),
        "Mt 5,1–7,29",
      );
      expect(
        PericopeValidator.referenceOf(byId("die_seligpreisungen", book: "Mt")),
        "Mt 5,3–5,12",
      );
    });
  });

  group("Prüfregeln", () {
    test("Richtige Anfangs- und Endverse, lückenloser Anschluss", () {
      expect(
        codes([
          entry("Mk", 4, 35, 4, 41),
          entry("Mk", 5, 1, 5, 20),
          entry("Mk", 5, 21, 5, 43),
          entry("Mk", 6, 1, 6, 6),
        ]),
        isEmpty,
      );
    });

    test("Zu kurzer Endvers: Psalm und Kapitelfrage", () {
      expect(codes([entry("Ps", 55, 1, 55, 23)]), ["psalm"]);
      expect(codes([entry("Ps", 55, 1, 55, 24)]), isEmpty);

      expect(codes([entry("1Kor", 1, 1, 1, 13, title: "1Kor 1")]), [
        "kapitelfrage",
      ]);
      expect(codes([entry("1Kor", 1, 1, 1, 31, title: "1Kor 1")]), isEmpty);

      final issue = validator.validate([entry("Ps", 55, 1, 55, 23)]).single;

      expect(issue.message, contains("24 Verse"));
      expect(issue.message, contains("Vers 23"));
    });

    test("Kapitelgrenze: Anfangs- und Endkapitel zählen je für sich", () {
      // 1. Mose 31 hat 54, Kapitel 32 hat 33 Verse.
      expect(codes([entry("Gen", 31, 1, 32, 1)]), isEmpty);
      expect(codes([entry("Gen", 31, 44, 32, 33)]), isEmpty);
      expect(codes([entry("Gen", 31, 1, 32, 34)]), ["vers-fehlt"]);
      expect(codes([entry("Gen", 31, 55, 32, 3)]), ["vers-fehlt"]);

      // Anschluss über die Kapitelgrenze.
      expect(
        codes([entry("Gen", 31, 1, 31, 54), entry("Gen", 32, 1, 32, 22)]),
        isEmpty,
      );
    });

    test("Ungültige Stellen mit Datei, ID und Stelle in der Meldung", () {
      final issue = validator.validate([
        entry("Gen", 31, 1, 31, 55, id: "jakobs_trennung_von_laban"),
      ]).single;

      expect(issue.code, "vers-fehlt");
      expect(
        "$issue",
        allOf(
          contains("assets/perikopen.json"),
          contains("jakobs_trennung_von_laban"),
          contains("Gen 31,1–31,55"),
          contains("Vers 55 gibt es in Gen 31 nicht (54 Verse)"),
        ),
      );

      expect(codes([entry("Gen", 51, 1, 51, 3)]), ["kapitel-fehlt"]);
      expect(codes([entry("Gen", 3, 10, 3, 4)]), ["reihenfolge-in-stelle"]);
      expect(codes([entry("Gen", 4, 1, 3, 4)]), ["reihenfolge-in-stelle"]);
      expect(codes([entry("Gen", 3, 0, 3, 4)]), ["reihenfolge-in-stelle"]);
      expect(codes([entry("Evangelium", 1, 1, 1, 2)]), ["buch"]);

      expect(codes([entry("Gen", 1, 1, 1, 5)..remove("endVerse")]), ["schema"]);
      expect(codes([entry("Gen", 1, 1, 1, 5)..["startVerse"] = "1"]), [
        "schema",
      ]);
      expect(codes([entry("Gen", 1, 1, 1, 5)..["precision"] = "wort"]), [
        "schema",
      ]);
    });

    test("Zusätze zu Daniel und Ester gelten in der Zählung der Vulgata", () {
      expect(codes([entry("Dan", 3, 24, 3, 50)]), isEmpty);
      expect(codes([entry("Dan", 13, 1, 13, 64)]), isEmpty);
      expect(codes([entry("Est", 10, 4, 10, 13)]), isEmpty);
      expect(codes([entry("Dan", 15, 1, 15, 2)]), ["kapitel-fehlt"]);

      // Apokryphen: nur die Kapitel sind prüfbar.
      expect(codes([entry("Sir", 51, 1, 51, 30)]), isEmpty);
      expect(codes([entry("Sir", 52, 1, 52, 3)]), ["kapitel-fehlt"]);
    });

    test("Eine Lücke zwischen zwei Perikopen ist kein Fehler", () {
      final entries = [
        entry("Mt", 10, 40, 10, 42),
        entry("Mt", 11, 2, 11, 6),
        entry("Mt", 11, 7, 11, 19),
      ];

      expect(codes(entries), isEmpty);

      // Aufgelistet wird sie trotzdem (zusammen mit dem Rest des Buchs).
      expect(validator.gaps(entries)["Mt"], contains("11,1"));
    });

    test("Zulässige Überschneidungen: Parallelen, Grenze im Vers, "
        "Unterabschnitte, dieselbe ID an getrennten Stellen", () {
      expect(
        codes([
          // Mk 6,6a endet, 6,6b beginnt.
          entry("Mk", 6, 1, 6, 6),
          entry("Mk", 6, 6, 6, 13),
          // Synoptische Parallelen unter einer ID.
          entry("Mt", 14, 13, 14, 21, id: "speisung5000"),
          entry("Mk", 6, 30, 6, 44, id: "speisung5000"),
          entry("Lk", 9, 10, 9, 17, id: "speisung5000"),
          // Übergeordneter Abschnitt mit Unterabschnitten.
          entry("Dtn", 28, 69, 32, 52),
          entry("Dtn", 29, 1, 29, 8),
          entry("Dtn", 33, 1, 33, 29),
          entry("Dtn", 33, 2, 33, 5),
          entry("Dtn", 33, 6, 33, 25),
          // Dieselbe ID zweimal im selben Buch, ohne Überschneidung.
          entry("Lev", 1, 1, 1, 17, id: "das_brandopfer"),
          entry("Lev", 6, 1, 6, 6, id: "das_brandopfer"),
          // Kapitelfrage neben der Einteilung des Kapitels.
          entry("Ex", 3, 1, 3, 22, id: "ex_3", title: "Ex 3"),
          entry("Ex", 3, 1, 3, 12),
          entry("Ex", 3, 13, 3, 22),
        ]),
        isEmpty,
      );
    });

    test("Unzulässig: widersprüchliche Doppeleinträge und Perikopen "
        "außerhalb der Reihenfolge", () {
      expect(
        codes([
          entry("2Chr", 2, 1, 2, 17, id: "2chr_2", title: "2Chr 2"),
          entry("2Chr", 2, 1, 2, 17, id: "2chr_2", title: "2Chr 2"),
        ]),
        ["doppelt"],
      );

      // Beginnt mitten in der vorigen Perikope und reicht über sie hinaus.
      expect(codes([entry("Mk", 4, 1, 4, 20), entry("Mk", 4, 10, 4, 25)]), [
        "ueberschneidung",
      ]);

      // Der frühere Fehler: Am 5,10–15 stand als Am 1,10–15 mitten in
      // „Über die Nachbarvölker“.
      expect(codes([entry("Am", 1, 2, 2, 3), entry("Am", 1, 10, 1, 15)]), [
        "ueberschneidung",
      ]);

      // Zurück hinter die vorige Perikope.
      expect(codes([entry("Am", 5, 10, 5, 15), entry("Am", 2, 4, 2, 16)]), [
        "ueberschneidung",
      ]);
    });

    test("Eine Ausnahme gilt nur für ihren Datensatz und ihre Regel", () {
      final own = PericopeValidator(
        translations: translations,
        exceptions: const [
          PericopeException("a", "psalm", "Schlussnotiz ohne eigene Perikope."),
        ],
      );

      expect(own.validate([entry("Ps", 72, 1, 72, 19, id: "a")]), isEmpty);
      expect(own.validate([entry("Ps", 72, 1, 72, 19, id: "b")]), hasLength(1));
      expect(own.validate([entry("Ps", 72, 1, 72, 21, id: "a")]), hasLength(1));
    });
  });
}
