import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/confession.dart';
import 'package:theologie_lernapp/screens/confession_detail_screen.dart';
import 'package:theologie_lernapp/screens/confessions_screen.dart';
import 'package:theologie_lernapp/services/confession_service.dart';
import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/widgets/settings_access.dart';

import 'test_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Bekenntnisse: Daten", () {
    test("werden aus dem App-Bundle geladen (ohne localhost)", () async {
      final confessions = await ConfessionService().loadConfessions();

      // Reihenfolge des Konkordienbuchs.
      expect(confessions.map((c) => c.id), [
        "apostolicum",
        "nicenum",
        "athanasianum",
        "augsburger_konfession",
        "apologie",
        "schmalkaldische_artikel",
        "kleiner_katechismus",
        "grosser_katechismus",
        "konkordienformel_epitome",
      ]);
      expect(confessions.map((c) => c.id).toSet(), hasLength(9));

      final ca = confessions.firstWhere((c) => c.id == "augsburger_konfession");
      expect(ca.sections, hasLength(21));
      expect(ca.languages, containsAll(["de", "la", "en"]));

      final nicenum = confessions.firstWhere((c) => c.id == "nicenum");
      expect(nicenum.languages, contains("gr"));
      expect(nicenum.sections.first.texts["gr"], isNotEmpty);

      // Deutsch liegt überall vor; jede angebotene Sprache hat in jedem
      // Abschnitt Text (keine leeren Auswahlpunkte in der Detailansicht).
      for (final confession in confessions) {
        for (final section in confession.sections) {
          for (final language in confession.languages) {
            expect(
              section.texts[language],
              isNotEmpty,
              reason: "${confession.id}/${section.id}/$language",
            );
          }
          expect(section.texts.keys, everyElement(isIn(confession.languages)));
        }
      }
    });

    test("lutherische Symbole: Kleiner Katechismus und Auswahltexte", () async {
      final confessions = await ConfessionService().loadConfessions();

      Confession byId(String id) => confessions.firstWhere((c) => c.id == id);

      final lutheran = confessions
          .where((c) => c.category == "lutherische_symbole")
          .map((c) => c.id);
      expect(lutheran, hasLength(6));

      final sc = byId("kleiner_katechismus");
      expect(sc.languages, ["de", "la", "en"]);
      expect(sc.sections.map((s) => s.id), [
        for (var i = 1; i <= 6; i++) "hauptstueck_$i",
      ]);

      String sct(int part, String language) =>
          sc.sections[part - 1].texts[language]!;

      expect(sct(1, "de"), startsWith("Das erste Gebot.\nDu sollst nicht"));
      expect(sct(1, "de"), contains("über alle Dinge fürchten, lieben und vertrauen"));
      expect(sct(2, "de"), contains("Das ist gewißlich wahr."));
      expect(sct(3, "la"), startsWith("Pater noster, qui es in coelis."));
      expect(sct(4, "en"), startsWith("First.\nWhat is Baptism?"));
      expect(sct(6, "de"), endsWith("fordert eitel gläubige Herzen."));

      // Keine Absatzzähler, Herausgeberklammern oder Antwortzeilen.
      for (final confession in confessions.where(
        (c) => c.category == "lutherische_symbole",
      )) {
        for (final section in confession.sections) {
          for (final entry in section.texts.entries) {
            final r = "${confession.id}/${section.id}/${entry.key}";
            expect(entry.value, isNot(contains("[")), reason: r);
            expect(entry.value, isNot(matches(RegExp(r"\d+\]"))), reason: r);
            expect(entry.value, isNot(matches(RegExp(r"^(Antwort|Responsio|Answer)\.?$", multiLine: true))), reason: r);
          }
        }
      }

      // Originalsprache: Apologie lateinisch, Schmalkaldische Artikel deutsch.
      expect(byId("apologie").sources["la"], contains("Originaltext"));
      expect(byId("apologie").sources["de"], contains("Justus Jonas"));
      expect(byId("schmalkaldische_artikel").sources["de"], contains("Originaltext"));
      expect(
        byId("schmalkaldische_artikel").sections.single.texts["de"],
        contains("Von diesem Artikel kann man nichts weichen"),
      );
    });

    test("jede Textfassung hat eine Quellenangabe", () async {
      final confessions = await ConfessionService().loadConfessions();

      for (final confession in confessions) {
        final withText = {
          for (final section in confession.sections)
            for (final entry in section.texts.entries)
              if (entry.value.trim().isNotEmpty) entry.key,
        };

        for (final language in withText) {
          expect(
            confession.sources[language],
            isNotEmpty,
            reason: "${confession.id}/$language",
          );
        }
      }
    });

    test("Symbola stehen in der jeweils eigenen Textfassung", () async {
      final confessions = await ConfessionService().loadConfessions();

      String text(String id, String language) => confessions
          .firstWhere((c) => c.id == id)
          .sections
          .first
          .texts[language]!;

      // Lateinisch (westliche Liturgie) und griechisch (byzantinische
      // Liturgie) im Singular, die ökumenische deutsche Fassung im Plural.
      final nicenumLa = text("nicenum", "la");
      expect(nicenumLa, startsWith("Credo in unum Deum,"));
      expect(nicenumLa, contains("Confiteor unum baptisma"));
      expect(nicenumLa, contains("Et exspecto resurrectionem mortuorum"));
      expect(nicenumLa, isNot(contains("Credimus")));

      expect(text("nicenum", "gr"), startsWith("Πιστεύω εἰς ἕνα Θεόν"));
      expect(text("nicenum", "gr"), contains("καθεζόμενον ἐκ δεξιῶν"));
      expect(text("nicenum", "de"), startsWith("Wir glauben an den einen Gott"));
      expect(text("nicenum", "en"), startsWith("I believe in one God"));

      final apostolicumLa = text("apostolicum", "la");
      expect(apostolicumLa, startsWith("Credo in Deum"));
      expect(apostolicumLa, contains("descendit ad inferos"));
      expect(apostolicumLa, contains("carnis resurrectionem,\nvitam aeternam."));
    });

    test("keine Entwicklungs-Sonderlösung mehr", () {
      final service = File(
        "lib/services/confession_service.dart",
      ).readAsStringSync();

      expect(service, isNot(contains("localhost")));
      expect(service, isNot(contains("package:http")));
      expect(Directory("dev_data").existsSync(), isFalse);

      // Asset ist für alle Builds (Web/Android) deklariert.
      final pubspec = File("pubspec.yaml").readAsStringSync();
      expect(pubspec, contains("- assets/confessions.json"));
    });
  });

  group("Bekenntnisse: Oberfläche", () {
    testWidgets("Liste, Detail und globaler Einstellungszugang", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConfessionsScreen(
            service: ConfessionService(bundle: FileAssetBundle()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Altkirchliche Symbole"), findsOneWidget);
      expect(find.text("Lutherische Symbole"), findsOneWidget);
      expect(find.byType(SettingsButton), findsOneWidget);

      await tester.tap(find.text("Apostolisches Glaubensbekenntnis"));
      await tester.pumpAndSettle();

      expect(find.byType(ConfessionDetailScreen), findsOneWidget);
      expect(find.byType(SettingsButton), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(
        find.textContaining("Ich glaube an Gott", findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets("Fehler beim Laden zeigt Hinweis statt Endlos-Ladeanzeige", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConfessionsScreen(
            service: ConfessionService(bundle: _FailingBundle()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text("Die Bekenntnisse konnten nicht geladen werden."),
        findsOneWidget,
      );
    });

    test("Deep Link /confessions bleibt gültig", () {
      expect(AppDeepLink.parse("/confessions")?.path, AppDeepLink.confessions);
    });
  });
}

class _FailingBundle extends FileAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw Exception("nicht verfügbar");
  }
}
