import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

      expect(confessions.map((c) => c.id), [
        "apostolicum",
        "nicenum",
        "athanasianum",
        "augsburger_konfession",
      ]);

      final ca = confessions.firstWhere((c) => c.id == "augsburger_konfession");
      expect(ca.sections, hasLength(21));
      expect(ca.languages, containsAll(["de", "la"]));

      final nicenum = confessions.firstWhere((c) => c.id == "nicenum");
      expect(nicenum.languages, contains("gr"));
      expect(nicenum.sections.first.texts["gr"], isNotEmpty);

      // Deutsch liegt überall vor, die CA zusätzlich vollständig auf Latein.
      // (Die englische CA ist in den Daten angelegt, aber noch ohne Text.)
      for (final confession in confessions) {
        for (final section in confession.sections) {
          expect(
            section.texts["de"],
            isNotEmpty,
            reason: "${confession.id}/${section.id}/de",
          );
        }
      }
      for (final section in ca.sections) {
        expect(section.texts["la"], isNotEmpty, reason: "CA/${section.id}/la");
      }
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
