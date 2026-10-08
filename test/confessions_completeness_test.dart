import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/confession.dart';
import 'package:theologie_lernapp/services/confession_service.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';

/// Erwartete Gliederung des Konkordienbuchs: jede Schrift mit allen
/// Abschnitten in der Reihenfolge der Ausgabe. Fehlt ein Artikel oder kommt
/// einer doppelt vor, schlägt der Test fehl.
final Map<String, List<String>> expectedSections = {
  "apostolicum": ["full"],
  "nicenum": ["full"],
  "athanasianum": ["full"],
  "konkordienbuch_vorrede": ["full"],
  "augsburger_konfession": [
    "vorrede",
    for (var i = 1; i <= 21; i++) "art_$i",
    "beschluss_teil_1",
    for (var i = 22; i <= 28; i++) "art_$i",
    "beschluss",
  ],
  "apologie": [
    "vorrede",
    "art_1",
    "art_2",
    "art_3",
    "art_4",
    "art_4_liebe",
    "art_7_8",
    for (var i = 9; i <= 12; i++) "art_$i",
    "art_12_beichte",
    for (var i = 13; i <= 24; i++) "art_$i",
    "art_27",
    "art_28",
  ],
  "schmalkaldische_artikel": [
    "vorrede",
    "teil_1",
    for (var i = 1; i <= 4; i++) "teil_2_art_$i",
    for (var i = 1; i <= 15; i++) "teil_3_art_$i",
  ],
  "traktat": ["papst", "bischoefe"],
  "kleiner_katechismus": [
    "vorrede",
    for (var i = 1; i <= 6; i++) "hauptstueck_$i",
    "gebete",
    "haustafel",
  ],
  "grosser_katechismus": [
    "vorrede",
    "kurze_vorrede",
    for (var i = 1; i <= 8; i++) "gebot_$i",
    "gebot_9_10",
    "beschluss_gebote",
    "glaube",
    for (var i = 1; i <= 3; i++) "glaube_art_$i",
    "vaterunser",
    for (var i = 1; i <= 7; i++) "bitte_$i",
    "taufe",
    "kindertaufe",
    "abendmahl",
  ],
  "konkordienformel_epitome": [
    "regel_und_richtschnur",
    for (var i = 1; i <= 12; i++) "art_$i",
  ],
  "konkordienformel_solida_declaratio": [
    "vorrede",
    "regel_und_richtschnur",
    for (var i = 1; i <= 12; i++) "art_$i",
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Confession> confessions;

  setUpAll(() async {
    confessions = await ConfessionService().loadConfessions();
  });

  Confession byId(String id) => confessions.firstWhere((c) => c.id == id);

  String text(String id, String section, String language) =>
      byId(id).sections.firstWhere((s) => s.id == section).texts[language]!;

  group("Konkordienbuch: Vollständigkeit", () {
    test("alle Schriften mit allen Abschnitten, in der Reihenfolge der Ausgabe",
        () {
      expect(confessions.map((c) => c.id), expectedSections.keys);

      for (final confession in confessions) {
        expect(
          confession.sections.map((s) => s.id),
          expectedSections[confession.id],
          reason: confession.id,
        );
      }
    });

    test("jeder Abschnitt hat Titel und Text in allen Sprachen der Schrift",
        () {
      for (final confession in confessions) {
        expect(confession.title["de"], isNotEmpty, reason: confession.id);

        for (final section in confession.sections) {
          final r = "${confession.id}/${section.id}";

          expect(section.title["de"], isNotEmpty, reason: r);
          expect(section.texts.keys.toSet(), confession.languages.toSet(),
              reason: r);

          for (final language in confession.languages) {
            final t = section.texts[language]!;

            expect(t.trim(), isNotEmpty, reason: "$r/$language");
            expect(t, t.trim(), reason: "$r/$language: Leerraum am Rand");
            // Ein Abschnitt endet mit einem Satzzeichen, nicht mitten im Satz.
            expect(
              t,
              matches(RegExp(r'''[.!?:;“”"')]$''')),
              reason: "$r/$language: abgeschnitten?",
            );
          }
        }
      }
    });

    test("die Sprachfassungen eines Abschnitts sind ähnlich lang", () {
      // Eine Zusammenfassung oder ein abgeschnittener Text fiele hier auf.
      // Die Apologie ist ausgenommen: Justus Jonas' deutsche Fassung ist eine
      // freie, teils viel längere Bearbeitung des lateinischen Originals.
      for (final confession in confessions) {
        if (confession.id == "apologie") continue;

        for (final section in confession.sections) {
          final lengths = [
            for (final l in ["de", "la", "en"]) section.texts[l]!.length,
          ]..sort();

          expect(
            lengths.last / lengths.first,
            lessThan(2.2),
            reason: "${confession.id}/${section.id}: $lengths",
          );
        }
      }
    });

    test("keine Reste der Vorlagen im Text", () {
      final leftovers = RegExp(
        r"\[|\]|\d+\]|\(\(greek|https?:|Lutheran Church\. Missouri|@@PAGE|\*\*",
      );
      // Fehlerhaft kodiertes Griechisch der elektronischen Ausgabe:
      // verdoppelter Vokal mit Leerzeichen ("εε πιειί κειαν").
      final mangledGreek = RegExp(r"(αα|εε|ηη|οο|υυ|ωω) [α-ω]");

      for (final confession in confessions.where(
        (c) => c.category == "lutherische_symbole",
      )) {
        for (final section in confession.sections) {
          for (final entry in section.texts.entries) {
            final r = "${confession.id}/${section.id}/${entry.key}";

            expect(leftovers.hasMatch(entry.value), isFalse, reason: r);
            expect(mangledGreek.hasMatch(entry.value), isFalse, reason: r);
            expect(entry.value, isNot(contains("  ")), reason: r);
          }
        }
      }
    });

    test("kein Text kommt doppelt vor", () {
      final seen = <String, String>{};

      for (final confession in confessions) {
        for (final section in confession.sections) {
          for (final entry in section.texts.entries) {
            final where = "${confession.id}/${section.id}/${entry.key}";
            final previous = seen[entry.value];

            expect(previous, isNull, reason: "$where = $previous");
            seen[entry.value] = where;
          }
        }
      }
    });

    test("Anfang und Ende der großen Schriften stimmen", () {
      expect(
        text("augsburger_konfession", "vorrede", "de"),
        startsWith("Allerdurchlauchtigster, großmächtigster"),
      );
      expect(
        text("augsburger_konfession", "art_28", "de"),
        contains("Von der Bischöfe Gewalt ist vorzeiten viel"),
      );
      expect(
        text("augsburger_konfession", "beschluss", "la"),
        contains("Hi sunt praecipui articuli, qui videntur habere controversiam"),
      );
      expect(
        text("apologie", "art_4", "la"),
        contains("sola fide"),
      );
      expect(
        text("schmalkaldische_artikel", "teil_3_art_15", "de"),
        contains("Dies sind die Artikel, darauf ich stehen muß"),
      );
      expect(
        text("traktat", "papst", "la"),
        startsWith("Romanus pontifex arrogat sibi"),
      );
      expect(
        text("grosser_katechismus", "abendmahl", "de"),
        contains("Sakrament des Altars"),
      );
      expect(
        text("konkordienformel_epitome", "art_12", "en"),
        contains("Anabaptists"),
      );
      expect(
        text("konkordienformel_solida_declaratio", "art_1", "de"),
        startsWith("Und erstlich hat sich"),
      );
      expect(
        text("konkordienformel_solida_declaratio", "art_12", "de"),
        endsWith("unterschrieben."),
      );
    });

    test("Großer Katechismus: der geprüfte Anfang des ersten Gebots bleibt",
        () {
      // §§ 1–4 standen schon vorher in der App; ihre Abschnitte (und damit
      // gespeicherte Lernstände) dürfen sich nicht verschieben.
      final de = text("grosser_katechismus", "gebot_1", "de");

      expect(de, startsWith("Das erste Gebot.\nDu sollst nicht andere Götter"));
      expect(
        de,
        contains("laß nur dein Herz an keinem andern hangen noch ruhen.\n\n"),
      );
      expect(de.length, greaterThan(10000));
    });
  });

  group("Konkordienbuch: Lerntexte", () {
    test("jeder Abschnitt ist ein Werk mit stabiler, eindeutiger ID", () async {
      final catalog = await MemorizationCatalog.load();

      final ids = <String>{};

      for (final confession in confessions) {
        for (final section in confession.sections) {
          for (final language in confession.languages) {
            final id = "confession.${confession.id}.${section.id}.$language";

            expect(catalog.text(id), isNotNull, reason: id);
            expect(ids.add(id), isTrue, reason: id);
          }
        }
      }

      // Früher vergebene IDs bleiben gültig.
      for (final id in [
        "confession.apostolicum.full.de",
        "confession.augsburger_konfession.art_4.de",
        "confession.apologie.art_9.la",
        "confession.schmalkaldische_artikel.teil_2_art_1.de",
        "confession.kleiner_katechismus.hauptstueck_3.de",
        "confession.grosser_katechismus.gebot_1.de",
        "confession.konkordienformel_epitome.regel_und_richtschnur.en",
      ]) {
        expect(catalog.text(id), isNotNull, reason: id);
      }
    });

    test("lange Abschnitte werden erst bei Bedarf und vollständig zerlegt",
        () async {
      final catalog = await MemorizationCatalog.load();

      final article = catalog.text(
        "confession.konkordienformel_solida_declaratio.art_7.de",
      )!;
      final source = text("konkordienformel_solida_declaratio", "art_7", "de");

      String squash(String s) => s.replaceAll(RegExp(r"\s+"), " ").trim();

      expect(article.segments.length, greaterThan(500));
      expect(
        squash(article.segments.map((s) => s.text).join(" ")),
        squash(source),
      );
      expect(article.segments.first.id, "${article.id}.s0");

      final work = catalog.workOf(article)!;
      expect(work.group, "Konkordienformel: Solida Declaratio");
      expect(work.shortTitle, "Artikel VII: Vom heiligen Abendmahl");
    });
  });
}
