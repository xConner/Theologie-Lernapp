import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/prayer.dart';
import 'package:theologie_lernapp/screens/prayer_detail_screen.dart';
import 'package:theologie_lernapp/screens/prayers_screen.dart';
import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/services/prayer_service.dart';
import 'package:theologie_lernapp/widgets/settings_access.dart';

import 'test_asset_bundle.dart';

const initialPrayerIds = [
  "vaterunser",
  "jesusgebet",
  "magnificat",
  "benedictus",
  "nunc_dimittis",
  "gloria_patri",
  "kyrie",
  "gloria_in_excelsis",
  "trishagion",
  "agnus_dei",
  "verleih_uns_frieden",
  "luthers_morgensegen",
  "luthers_abendsegen",
  "tischgebet_benedicite",
  "tischgebet_gratias",
];

List<String> ids(List<Prayer> prayers) => prayers.map((p) => p.id).toList();

Prayer byId(List<Prayer> prayers, String id) =>
    prayers.firstWhere((p) => p.id == id);

Widget app(Widget home) => MaterialApp(home: home);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Prayer> prayers;

  setUpAll(() async {
    prayers = await PrayerService().loadPrayers();
  });

  group("Gebete: Daten", () {
    test("alle initialen Gebete werden aus dem App-Bundle geladen", () {
      expect(ids(prayers), containsAll(initialPrayerIds));
      expect(ids(prayers).toSet(), hasLength(prayers.length));
    });

    test("Datensätze sind vollständig und nutzen nur Standard-Tags", () {
      for (final prayer in prayers) {
        final reason = prayer.id;

        expect(prayer.title["de"], isNotEmpty, reason: reason);
        expect(prayer.source, isNotEmpty, reason: reason);
        expect(PrayerTypes.labels.keys, contains(prayer.type), reason: reason);
        expect(
          PrayerTraditions.labels.keys,
          contains(prayer.tradition),
          reason: reason,
        );
        expect(prayer.tags.length, greaterThanOrEqualTo(2), reason: reason);
        expect(PrayerTags.labels.keys, containsAll(prayer.tags));
        expect(prayer.versions, isNotEmpty, reason: reason);

        for (final version in prayer.versions) {
          final r = "${prayer.id}/${version.language}";

          expect(PrayerLanguages.order, contains(version.language), reason: r);
          expect(version.text.trim(), isNotEmpty, reason: r);
          expect(version.source, isNotEmpty, reason: r);

          // Nur die Originalsprache darf als Original gekennzeichnet sein.
          if (version.isOriginal) {
            expect(version.language, prayer.originalLanguage, reason: r);
          }

          if (version.status == PrayerVersionStatus.translation ||
              version.status == PrayerVersionStatus.paraphrase) {
            expect(version.translatedFrom, isNotNull, reason: r);
            expect(version.translatedFrom, isNot(version.language), reason: r);
          }
        }
      }
    });

    test("Luther-Gebete: Deutsch ist Original, andere Sprachen Übersetzung",
        () {
      for (final prayer in prayers.where((p) => p.author == "Martin Luther")) {
        expect(prayer.originalLanguage, "de");
        expect(prayer.versionFor("de")!.isOriginal, isTrue);
        expect(prayer.versionFor("en")!.isOriginal, isFalse);
      }
    });

    test("Vaterunser in vier Sprachen, griechisch als Original", () {
      final vaterunser = byId(prayers, "vaterunser");

      expect(vaterunser.languages, ["de", "en", "la", "gr"]);
      expect(vaterunser.versionFor("gr")!.isOriginal, isTrue);
      expect(vaterunser.versionFor("gr")!.text, startsWith("Πάτερ ἡμῶν"));
      expect(vaterunser.versionFor("la")!.text, contains("cotidianum"));
    });

    test("lutherische Gottesdienstgebete mit Agendenquelle", () {
      expect(
        ids(prayers),
        containsAll(["sanctus", "dankkollekte_abendmahl", "kollekte_um_frieden"]),
      );

      final sanctus = byId(prayers, "sanctus");
      expect(sanctus.languages, ["de", "en", "la"]);
      expect(sanctus.versionFor("de")!.text, startsWith("Heilig, heilig, heilig"));
      expect(sanctus.versionFor("la")!.source, contains("Missale Romanum"));

      final thanks = byId(prayers, "dankkollekte_abendmahl");
      expect(thanks.originalLanguage, "de");
      expect(thanks.versionFor("de")!.source, contains("Kirchenbuch"));
      expect(thanks.versionFor("en")!.source, contains("Common Service Book"));

      final peace = byId(prayers, "kollekte_um_frieden");
      expect(peace.versionFor("la")!.isOriginal, isTrue);
      expect(peace.versionFor("la")!.text, startsWith("Deus, a quo sancta desideria"));
    });

    test("nicht vorhandene Sprachfassungen werden nicht angeboten", () {
      expect(byId(prayers, "jesusgebet").languages, ["de", "en", "gr"]);
      expect(byId(prayers, "jesusgebet").versionFor("la"), isNull);
      expect(byId(prayers, "trishagion").languages, ["la", "gr"]);
      expect(byId(prayers, "luthers_morgensegen").versionFor("gr"), isNull);
    });
  });

  group("Gebete: Suche", () {
    test("leere Suche zeigt alle Gebete in Datenreihenfolge", () {
      expect(ids(PrayerSearch.filter(prayers)), ids(prayers));
      expect(ids(PrayerSearch.filter(prayers, query: "   ")), ids(prayers));
    });

    test("Suche nach Titel (auch in anderen Sprachen)", () {
      expect(ids(PrayerSearch.filter(prayers, query: "Vaterunser")), [
        "vaterunser",
      ]);
      expect(ids(PrayerSearch.filter(prayers, query: "pater noster")), [
        "vaterunser",
      ]);
      expect(
        ids(PrayerSearch.filter(prayers, query: "MAGNIFICAT")),
        contains("magnificat"),
      );
    });

    test("Suche nach Tag", () {
      final luther = ids(PrayerSearch.filter(prayers, query: "luther"));

      expect(
        luther,
        containsAll([
          "luthers_morgensegen",
          "luthers_abendsegen",
          "tischgebet_benedicite",
          "tischgebet_gratias",
          "verleih_uns_frieden",
          "agnus_dei",
        ]),
      );
      // Der Gebetstext und die Beschreibung werden nicht durchsucht.
      expect(luther, isNot(contains("magnificat")));

      expect(
        ids(PrayerSearch.filter(prayers, query: "abend")),
        containsAll(["luthers_abendsegen", "magnificat", "nunc_dimittis"]),
      );
      expect(
        ids(PrayerSearch.filter(prayers, query: "Altkirche")),
        containsAll(["kyrie", "gloria_patri"]),
      );
    });

    test("Umlaute und ß werden gleich behandelt", () {
      expect(
        ids(PrayerSearch.filter(prayers, query: "Buße")),
        ids(PrayerSearch.filter(prayers, query: "busse")),
      );
      expect(PrayerSearch.filter(prayers, query: "busse"), isNotEmpty);
    });

    test("mehrere Begriffe und Tag-Filter werden kombiniert", () {
      expect(ids(PrayerSearch.filter(prayers, query: "luther morgen")), [
        "luthers_morgensegen",
      ]);

      // „abend“ trifft auch das Tag „Abendmahl“ (Teilwortsuche).
      expect(
        ids(PrayerSearch.filter(prayers, query: "abend", tag: "lutherisch")),
        ["agnus_dei", "luthers_abendsegen", "dankkollekte_abendmahl"],
      );
      expect(
        ids(PrayerSearch.filter(prayers, query: "abend", tag: "katechismus")),
        ["luthers_abendsegen"],
      );

      final tischgebete = PrayerSearch.filter(prayers, tag: "tischgebet");
      expect(ids(tischgebete), [
        "tischgebet_benedicite",
        "tischgebet_gratias",
      ]);
    });

    test("unbekannte Tags und Begriffe erzeugen keinen Fehler", () {
      expect(PrayerSearch.filter(prayers, tag: "gibt_es_nicht"), isEmpty);
      expect(PrayerSearch.filter(prayers, query: "xyzxyz"), isEmpty);
      expect(PrayerTags.label("gibt_es_nicht"), "gibt_es_nicht");
    });
  });

  group("Gebete: Oberfläche", () {
    PrayersScreen screen() =>
        PrayersScreen(service: PrayerService(bundle: FileAssetBundle()));

    testWidgets("Liste zeigt Gebete, Suche filtert, leere Suche zeigt alle", (
      tester,
    ) async {
      await tester.pumpWidget(app(screen()));
      await tester.pumpAndSettle();

      expect(find.text("Gebete"), findsOneWidget);
      expect(find.byType(SettingsButton), findsOneWidget);
      expect(find.text("Vaterunser"), findsOneWidget);

      await tester.enterText(find.byType(TextField), "jesusgebet");
      await tester.pumpAndSettle();

      expect(find.text("Jesusgebet"), findsOneWidget);
      expect(find.text("Vaterunser"), findsNothing);

      await tester.enterText(find.byType(TextField), "gibt es nicht");
      await tester.pumpAndSettle();
      expect(find.text("Keine passenden Gebete gefunden."), findsOneWidget);

      await tester.enterText(find.byType(TextField), "");
      await tester.pumpAndSettle();
      expect(find.text("Vaterunser"), findsOneWidget);
    });

    testWidgets("Tag-Filter über Chips", (tester) async {
      await tester.pumpWidget(app(screen()));
      await tester.pumpAndSettle();

      final tischgebet = find.byKey(const Key("prayer_filter_tischgebet"));
      await tester.ensureVisible(tischgebet);
      await tester.pumpAndSettle();
      await tester.tap(tischgebet);
      await tester.pumpAndSettle();

      expect(find.text("Tischgebet vor dem Essen (Benedicite)"), findsOneWidget);
      expect(find.text("Vaterunser"), findsNothing);

      final alle = find.byKey(const Key("prayer_filter_alle"));
      await tester.ensureVisible(alle);
      await tester.pumpAndSettle();
      await tester.tap(alle);
      await tester.pumpAndSettle();
      expect(find.text("Vaterunser"), findsOneWidget);
    });

    testWidgets("Tippen öffnet die Detailansicht", (tester) async {
      await tester.pumpWidget(app(screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Vaterunser"));
      await tester.pumpAndSettle();

      expect(find.byType(PrayerDetailScreen), findsOneWidget);
      expect(find.byType(SettingsButton), findsOneWidget);
    });

    testWidgets("Detail: Sprachumschaltung, Quelle und Tags", (tester) async {
      await tester.pumpWidget(
        app(PrayerDetailScreen(prayer: byId(prayers, "vaterunser"))),
      );

      for (final language in ["de", "en", "la", "gr"]) {
        expect(find.byKey(Key("prayer_language_$language")), findsOneWidget);
      }

      SelectableText text() =>
          tester.widget<SelectableText>(find.byKey(const Key("prayer_text")));

      expect(text().data, startsWith("Vater unser im Himmel"));

      await tester.tap(find.byKey(const Key("prayer_language_gr")));
      await tester.pumpAndSettle();
      expect(text().data, startsWith("Πάτερ ἡμῶν"));

      await tester.tap(find.byKey(const Key("prayer_language_la")));
      await tester.pumpAndSettle();
      expect(text().data, startsWith("Pater noster"));

      await tester.scrollUntilVisible(
        find.text("Tags"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("Quelle"), findsOneWidget);
      expect(
        find.text("Matthäus 6,9–13 (kürzere Fassung: Lukas 11,2–4)"),
        findsOneWidget,
      );
      expect(find.widgetWithText(Chip, "Biblisch"), findsOneWidget);
      expect(find.widgetWithText(Chip, "Liturgie"), findsOneWidget);
    });

    testWidgets("Detail: keine leeren Sprach-Tabs", (tester) async {
      await tester.pumpWidget(
        app(PrayerDetailScreen(prayer: byId(prayers, "jesusgebet"))),
      );

      expect(find.byKey(const Key("prayer_language_de")), findsOneWidget);
      expect(find.byKey(const Key("prayer_language_en")), findsOneWidget);
      expect(find.byKey(const Key("prayer_language_gr")), findsOneWidget);
      expect(find.byKey(const Key("prayer_language_la")), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets("Detail: ohne Deutsch startet die erste vorhandene Sprache", (
      tester,
    ) async {
      await tester.pumpWidget(
        app(PrayerDetailScreen(prayer: byId(prayers, "trishagion"))),
      );

      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key("prayer_text")))
            .data,
        startsWith("Sanctus Deus"),
      );
    });

    testWidgets("Detail: eine einzige Fassung zeigt keine Umschaltung", (
      tester,
    ) async {
      final single = Prayer.fromJson({
        "id": "test",
        "title": {"de": "Testgebet"},
        "type": "gebet",
        "tradition": "lutherisch",
        "originalLanguage": "de",
        "source": "Testquelle",
        "tags": ["luther", "abend"],
        "versions": [
          {
            "language": "de",
            "status": "original",
            "source": "Testfassung",
            "text": "Amen.",
          },
          // Leere Fassung darf nicht als Tab erscheinen.
          {
            "language": "en",
            "status": "translation",
            "translatedFrom": "de",
            "source": "leer",
            "text": "  ",
          },
        ],
      });

      await tester.pumpWidget(app(PrayerDetailScreen(prayer: single)));

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text("Testquelle"), findsOneWidget);
      expect(find.widgetWithText(Chip, "Luther"), findsOneWidget);
      expect(find.widgetWithText(Chip, "Abend"), findsOneWidget);
    });

    test("Deep Link /prayers ist registriert", () {
      expect(AppDeepLink.parse("/prayers")?.path, AppDeepLink.prayers);
    });
  });
}
