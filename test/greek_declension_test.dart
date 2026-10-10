import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/greek/grammar/greek_declension.dart';
import 'package:theologie_lernapp/utils/greek_accents.dart';

/// Formen eines Genus in Tabellenreihenfolge: Nom., Gen., Dat., Akk.
/// Singular, dann Plural.
List<String> _column(DeclensionParadigm paradigm, String gender) {
  return [
    for (final number in declensionNumbers)
      for (final grammaticalCase in declensionCases)
        paradigm.form(grammaticalCase, number, gender)!,
  ];
}

void _expectTable(
  DeclensionParadigm? paradigm, {
  required List<String> masculine,
  required List<String> feminine,
  required List<String> neuter,
}) {
  expect(paradigm, isNotNull);
  expect(_column(paradigm!, "m"), masculine);
  expect(_column(paradigm, "f"), feminine);
  expect(_column(paradigm, "n"), neuter);
}

void main() {
  group("Akzente", () {
    test("Akzent fällt weg, Spiritus und Iota subscriptum bleiben", () {
      expect(stripGreekAccent("παύ"), "παυ");
      expect(stripGreekAccent("ἄγ"), "ἀγ");
      expect(stripGreekAccent("εὕρ"), "εὑρ");
      expect(stripGreekAccent("πλεῖστ"), "πλειστ");
      expect(stripGreekAccent("ᾄδ"), "ᾀδ");
      expect(stripGreekAccent("τῷ"), "τῳ");
      expect(stripGreekAccent("ἰδ"), "ἰδ");
    });

    test("erkennt, ob ein Akzent vorhanden ist", () {
      expect(hasGreekAccent("παύ"), isTrue);
      expect(hasGreekAccent("ἰδ"), isFalse);
    });
  });

  // Die Tabellen der Folien „Griechisch 1 – Partizipien“.
  group("Partizipien nach den Folien", () {
    test("Präsens Aktiv von εἰμί", () {
      _expectTable(
        declineParticiple(masculine: "ὤν", feminine: "οὖσα", neuter: "ὄν"),
        masculine: [
          "ὤν",
          "ὄντος",
          "ὄντι",
          "ὄντα",
          "ὄντες",
          "ὄντων",
          "οὖσι(ν)",
          "ὄντας",
        ],
        feminine: [
          "οὖσα",
          "οὔσης",
          "οὔσῃ",
          "οὖσαν",
          "οὖσαι",
          "οὐσῶν",
          "οὔσαις",
          "οὔσας",
        ],
        neuter: [
          "ὄν",
          "ὄντος",
          "ὄντι",
          "ὄν",
          "ὄντα",
          "ὄντων",
          "οὖσι(ν)",
          "ὄντα",
        ],
      );
    });

    test("Präsens Aktiv: παύων, παύουσα, παῦον", () {
      _expectTable(
        declineParticiple(
          masculine: "παύων",
          feminine: "παύουσα",
          neuter: "παῦον",
        ),
        masculine: [
          "παύων",
          "παύοντος",
          "παύοντι",
          "παύοντα",
          "παύοντες",
          "παυόντων",
          "παύουσι(ν)",
          "παύοντας",
        ],
        feminine: [
          "παύουσα",
          "παυούσης",
          "παυούσῃ",
          "παύουσαν",
          "παύουσαι",
          "παυουσῶν",
          "παυούσαις",
          "παυούσας",
        ],
        neuter: [
          "παῦον",
          "παύοντος",
          "παύοντι",
          "παῦον",
          "παύοντα",
          "παυόντων",
          "παύουσι(ν)",
          "παύοντα",
        ],
      );
    });

    test("Präsens Medium/Passiv: παυόμενος, παυομένη, παυόμενον", () {
      _expectTable(
        declineParticiple(
          masculine: "παυόμενος",
          feminine: "παυομένη",
          neuter: "παυόμενον",
        ),
        masculine: [
          "παυόμενος",
          "παυομένου",
          "παυομένῳ",
          "παυόμενον",
          "παυόμενοι",
          "παυομένων",
          "παυομένοις",
          "παυομένους",
        ],
        feminine: [
          "παυομένη",
          "παυομένης",
          "παυομένῃ",
          "παυομένην",
          "παυόμεναι",
          "παυομένων",
          "παυομέναις",
          "παυομένας",
        ],
        neuter: [
          "παυόμενον",
          "παυομένου",
          "παυομένῳ",
          "παυόμενον",
          "παυόμενα",
          "παυομένων",
          "παυομένοις",
          "παυόμενα",
        ],
      );
    });

    test("Aorist Aktiv: παύσας, παύσασα, παῦσαν", () {
      _expectTable(
        declineParticiple(
          masculine: "παύσας",
          feminine: "παύσασα",
          neuter: "παῦσαν",
        ),
        masculine: [
          "παύσας",
          "παύσαντος",
          "παύσαντι",
          "παύσαντα",
          "παύσαντες",
          "παυσάντων",
          "παύσασι(ν)",
          "παύσαντας",
        ],
        feminine: [
          "παύσασα",
          "παυσάσης",
          "παυσάσῃ",
          "παύσασαν",
          "παύσασαι",
          "παυσασῶν",
          "παυσάσαις",
          "παυσάσας",
        ],
        neuter: [
          "παῦσαν",
          "παύσαντος",
          "παύσαντι",
          "παῦσαν",
          "παύσαντα",
          "παυσάντων",
          "παύσασι(ν)",
          "παύσαντα",
        ],
      );
    });

    test("Aorist Medium: παυσάμενος, παυσαμένη, παυσάμενον", () {
      _expectTable(
        declineParticiple(
          masculine: "παυσάμενος",
          feminine: "παυσαμένη",
          neuter: "παυσάμενον",
        ),
        masculine: [
          "παυσάμενος",
          "παυσαμένου",
          "παυσαμένῳ",
          "παυσάμενον",
          "παυσάμενοι",
          "παυσαμένων",
          "παυσαμένοις",
          "παυσαμένους",
        ],
        feminine: [
          "παυσαμένη",
          "παυσαμένης",
          "παυσαμένῃ",
          "παυσαμένην",
          "παυσάμεναι",
          "παυσαμένων",
          "παυσαμέναις",
          "παυσαμένας",
        ],
        neuter: [
          "παυσάμενον",
          "παυσαμένου",
          "παυσαμένῳ",
          "παυσάμενον",
          "παυσάμενα",
          "παυσαμένων",
          "παυσαμένοις",
          "παυσάμενα",
        ],
      );
    });

    test("starker Aorist: ἰδών, ἰδοῦσα, ἰδόν", () {
      _expectTable(
        declineParticiple(
          masculine: "ἰδών",
          feminine: "ἰδοῦσα",
          neuter: "ἰδόν",
        ),
        masculine: [
          "ἰδών",
          "ἰδόντος",
          "ἰδόντι",
          "ἰδόντα",
          "ἰδόντες",
          "ἰδόντων",
          "ἰδοῦσι(ν)",
          "ἰδόντας",
        ],
        feminine: [
          "ἰδοῦσα",
          "ἰδούσης",
          "ἰδούσῃ",
          "ἰδοῦσαν",
          "ἰδοῦσαι",
          "ἰδουσῶν",
          "ἰδούσαις",
          "ἰδούσας",
        ],
        neuter: [
          "ἰδόν",
          "ἰδόντος",
          "ἰδόντι",
          "ἰδόν",
          "ἰδόντα",
          "ἰδόντων",
          "ἰδοῦσι(ν)",
          "ἰδόντα",
        ],
      );
    });

    // Belegt in den Beispielsätzen der Folien.
    test("Formen der Beispielsätze", () {
      final paideuomenos = declineParticiple(
        masculine: "παιδευόμενος",
        feminine: "παιδευομένη",
        neuter: "παιδευόμενον",
      )!;
      final poreuomenos = declineParticiple(
        masculine: "πορευόμενος",
        feminine: "πορευομένη",
        neuter: "πορευόμενον",
      )!;
      final thyon = declineParticiple(
        masculine: "θύων",
        feminine: "θύουσα",
        neuter: "θῦον",
      )!;

      expect(paideuomenos.form("Nominativ", "Sg", "m"), "παιδευόμενος");
      expect(poreuomenos.form("Akkusativ", "Pl", "m"), "πορευομένους");
      expect(thyon.form("Nominativ", "Pl", "m"), "θύοντες");
    });
  });

  group("Weitere Partiziptypen", () {
    test("Spiritus bleibt, wenn der Akzent wandert: ἄγων → ἀγόντων", () {
      final agon = declineParticiple(
        masculine: "ἄγων",
        feminine: "ἄγουσα",
        neuter: "ἄγον",
      )!;

      expect(agon.form("Genitiv", "Pl", "m"), "ἀγόντων");
      expect(agon.form("Genitiv", "Sg", "f"), "ἀγούσης");
      expect(agon.form("Akkusativ", "Sg", "n"), "ἄγον");
    });

    test("kurzer Stammvokal: Neutrum ohne Zirkumflex (βάλλον)", () {
      final ballon = declineParticiple(
        masculine: "βάλλων",
        feminine: "βάλλουσα",
        neuter: "βάλλον",
      )!;

      expect(ballon.form("Nominativ", "Sg", "n"), "βάλλον");
      expect(ballon.form("Nominativ", "Pl", "n"), "βάλλοντα");
    });

    test("Verba contracta: ποιῶν und τιμῶν", () {
      final poion = declineParticiple(
        masculine: "ποιῶν",
        feminine: "ποιοῦσα",
        neuter: "ποιοῦν",
      )!;
      final timon = declineParticiple(
        masculine: "τιμῶν",
        feminine: "τιμῶσα",
        neuter: "τιμῶν",
      )!;

      expect(poion.form("Genitiv", "Sg", "m"), "ποιοῦντος");
      expect(poion.form("Genitiv", "Pl", "m"), "ποιούντων");
      expect(poion.form("Dativ", "Pl", "n"), "ποιοῦσι(ν)");
      expect(poion.form("Dativ", "Sg", "f"), "ποιούσῃ");
      expect(timon.form("Akkusativ", "Sg", "m"), "τιμῶντα");
      expect(timon.form("Genitiv", "Pl", "f"), "τιμωσῶν");
      expect(timon.form("Akkusativ", "Pl", "f"), "τιμώσας");
    });

    test("Wurzelaorist: βάς und γνούς", () {
      final bas = declineParticiple(
        masculine: "βάς",
        feminine: "βᾶσα",
        neuter: "βάν",
      )!;
      final gnous = declineParticiple(
        masculine: "γνούς",
        feminine: "γνοῦσα",
        neuter: "γνόν",
      )!;

      expect(bas.form("Genitiv", "Sg", "m"), "βάντος");
      expect(bas.form("Dativ", "Pl", "m"), "βᾶσι(ν)");
      expect(bas.form("Genitiv", "Sg", "f"), "βάσης");
      expect(gnous.form("Akkusativ", "Sg", "m"), "γνόντα");
      expect(gnous.form("Nominativ", "Pl", "f"), "γνοῦσαι");
    });
  });

  group("Unzuverlässige Partizipien", () {
    test("unbekannter Typ wird nicht dekliniert (παυθείς)", () {
      expect(
        declineParticiple(
          masculine: "παυθείς",
          feminine: "παυθεῖσα",
          neuter: "παυθέν",
        ),
        isNull,
      );
      expect(
        declineParticiple(
          masculine: "τιθείς",
          feminine: "τιθεῖσα",
          neuter: "τιθέν",
        ),
        isNull,
      );
    });

    test("Femininum oder Neutrum passt nicht zur Bildung", () {
      expect(
        declineParticiple(
          masculine: "παύων",
          feminine: "παύσασα",
          neuter: "παῦον",
        ),
        isNull,
      );
      expect(
        declineParticiple(
          masculine: "παύων",
          feminine: "παύουσα",
          neuter: "παῦσαν",
        ),
        isNull,
      );
      expect(
        declineParticiple(
          masculine: "παυόμενος",
          feminine: "παυομένη",
          neuter: "παυόμενα",
        ),
        isNull,
      );
    });

    test("Maskulinum ohne Akzent oder ohne Stamm", () {
      expect(
        declineParticiple(
          masculine: "παυων",
          feminine: "παυουσα",
          neuter: "παυον",
        ),
        isNull,
      );
      expect(
        declineParticiple(masculine: "ών", feminine: "οῦσα", neuter: "όν"),
        isNull,
      );
    });
  });

  // Folien „Griechisch 1 – Steigerung der Adjektive“.
  group("Steigerungsformen", () {
    test("-τερος, -τέρα, -τερον", () {
      final sophoteros = declineRecessive(
        short: "σοφώτερ",
        long: "σοφωτέρ",
        alphaFeminine: true,
      );

      expect(_column(sophoteros, "m"), [
        "σοφώτερος",
        "σοφωτέρου",
        "σοφωτέρῳ",
        "σοφώτερον",
        "σοφώτεροι",
        "σοφωτέρων",
        "σοφωτέροις",
        "σοφωτέρους",
      ]);
      expect(_column(sophoteros, "f"), [
        "σοφωτέρα",
        "σοφωτέρας",
        "σοφωτέρᾳ",
        "σοφωτέραν",
        "σοφώτεραι",
        "σοφωτέρων",
        "σοφωτέραις",
        "σοφωτέρας",
      ]);
      expect(sophoteros.form("Akkusativ", "Pl", "n"), "σοφώτερα");
    });

    test("-ιστος, -ίστη, -ιστον", () {
      final kakistos = declineRecessive(
        short: "κάκιστ",
        long: "κακίστ",
        alphaFeminine: false,
      );

      expect(kakistos.form("Nominativ", "Sg", "f"), "κακίστη");
      expect(kakistos.form("Nominativ", "Sg", "n"), "κάκιστον");
      expect(kakistos.form("Nominativ", "Pl", "f"), "κάκισται");
    });

    test("-ίων, -ιον, Gen. -ίονος", () {
      final kakion = declineComparative(masculine: "κακίων", neuter: "κάκιον")!;
      final meizon = declineComparative(masculine: "μείζων", neuter: "μεῖζον")!;

      expect(_column(kakion, "m"), [
        "κακίων",
        "κακίονος",
        "κακίονι",
        "κακίονα",
        "κακίονες",
        "κακιόνων",
        "κακίοσι(ν)",
        "κακίονας",
      ]);
      expect(_column(kakion, "f"), _column(kakion, "m"));
      expect(kakion.form("Akkusativ", "Sg", "n"), "κάκιον");
      expect(meizon.form("Nominativ", "Sg", "n"), "μεῖζον");
      expect(meizon.form("Genitiv", "Sg", "n"), "μείζονος");
      expect(meizon.form("Nominativ", "Pl", "n"), "μείζονα");
    });

    test("Komparativ: unpassendes Neutrum wird nicht dekliniert", () {
      expect(declineComparative(masculine: "κακίων", neuter: "μεῖζον"), isNull);
      expect(
        declineComparative(masculine: "μικρότερος", neuter: "μικρότερον"),
        isNull,
      );
    });

    test("Positiv mit Endbetonung: σοφός, σοφή, σοφόν", () {
      final sophos = declineOxytone(stem: "σοφ", alphaFeminine: false);
      final mikros = declineOxytone(stem: "μικρ", alphaFeminine: true);

      expect(_column(sophos, "m"), [
        "σοφός",
        "σοφοῦ",
        "σοφῷ",
        "σοφόν",
        "σοφοί",
        "σοφῶν",
        "σοφοῖς",
        "σοφούς",
      ]);
      expect(sophos.form("Genitiv", "Sg", "f"), "σοφῆς");
      expect(mikros.form("Nominativ", "Sg", "f"), "μικρά");
      expect(mikros.form("Dativ", "Sg", "f"), "μικρᾷ");
    });
  });
}
