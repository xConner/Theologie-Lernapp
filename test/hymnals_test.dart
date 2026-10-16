import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/hymn.dart';
import 'package:theologie_lernapp/models/hymnal.dart';
import 'package:theologie_lernapp/screens/hymn_detail_screen.dart';
import 'package:theologie_lernapp/screens/hymn_screen.dart';
import 'package:theologie_lernapp/screens/hymnals_screen.dart';
import 'package:theologie_lernapp/services/hymn_search.dart';
import 'package:theologie_lernapp/services/hymnal_service.dart';
import 'package:theologie_lernapp/widgets/hymn_score_view.dart';

import 'test_asset_bundle.dart';

/// Wie [FileAssetBundle], aber einzelne Dateien fehlen.
class _MissingAssetBundle extends FileAssetBundle {
  final Set<String> missing;

  _MissingAssetBundle(this.missing);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (missing.contains(key)) throw FlutterError("Asset fehlt: $key");
    return super.loadString(key, cache: cache);
  }
}

Widget app(Widget home) => DefaultAssetBundle(
  bundle: FileAssetBundle(),
  child: MaterialApp(home: home),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HymnalLibrary library;
  late List<Hymn> stammteil;

  setUpAll(() async {
    library = await HymnalService(bundle: FileAssetBundle()).load();
    stammteil =
        (jsonDecode(File("assets/eg_lieder.json").readAsStringSync()) as List)
            .map((e) => Hymn.fromJson(e as Map<String, dynamic>))
            .toList();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Hymn find_(String collection, String number) =>
      library.hymnsOf(collection).firstWhere((hymn) => hymn.number == number);

  List<String> keys(List<HymnSearchHit> hits) => [
    for (final hit in hits) hit.hymn.key,
  ];

  group("Katalog", () {
    test("jede Sammlung hat eine eindeutige Kennung und gültige Angaben", () {
      final ids = library.hymnals.map((h) => h.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(library.failed, isEmpty);

      final groups = library.groups.map((g) => g.id).toSet();
      for (final hymnal in library.hymnals) {
        expect(groups, contains(hymnal.group), reason: hymnal.id);
        expect(hymnal.title, isNotEmpty, reason: hymnal.id);
        if (hymnal.asset != null) {
          expect(File(hymnal.asset!).existsSync(), isTrue, reason: hymnal.id);
        }
      }
    });

    test("Gesangbücher, Regionalteile, Ergänzungsheft und Liederschatz "
        "sind verzeichnet", () {
      expect(library.hymnal("eg")!.part, HymnalPart.core);
      expect(library.inGroup("eg", HymnalPart.regional).length, greaterThan(1));
      expect(library.inGroup("eg", HymnalPart.supplement), isNotEmpty);
      expect(library.hymnal("geistlicher_liederschatz")!.group, "other");
      // Der norddeutsche Kontext ist eigens vertreten.
      expect(library.hymnal("eg_nordelbien"), isNotNull);
      expect(library.hymnal("eg_mecklenburg_pommern"), isNotNull);
    });

    test("der Stand jeder Sammlung entspricht ihren Daten", () {
      for (final hymnal in library.hymnals) {
        final hymns = library.hymnsOf(hymnal.id);
        final expected = hymnal.expectedCount;

        switch (hymnal.status) {
          case HymnalStatus.complete:
            expect(hymns.length, expected, reason: hymnal.id);
          case HymnalStatus.partial:
            expect(hymns, isNotEmpty, reason: hymnal.id);
            if (expected != null) {
              expect(hymns.length, lessThan(expected), reason: hymnal.id);
            }
            expect(hymnal.statusNote, isNotEmpty, reason: hymnal.id);
          case HymnalStatus.notIntegrated:
            expect(hymnal.asset, isNull, reason: hymnal.id);
            expect(hymns, isEmpty, reason: hymnal.id);
            expect(hymnal.statusNote, isNotEmpty, reason: hymnal.id);
        }
      }
    });

    test("Nummern sind je Sammlung eindeutig, Kennungen über alle", () {
      for (final hymnal in library.hymnals) {
        final numbers = library.hymnsOf(hymnal.id).map((h) => h.number);
        expect(numbers.toSet().length, numbers.length, reason: hymnal.id);
      }
      final all = library.allHymns.map((h) => h.key).toList();
      expect(all.toSet().length, all.length);
    });

    test("fehlt eine Sammlung, bleiben die übrigen nutzbar", () async {
      final partial = await HymnalService(
        bundle: _MissingAssetBundle({
          "assets/hymnals/eg_bayern_thueringen.json",
        }),
      ).load();

      expect(partial.failed, {"eg_bayern_thueringen"});
      expect(partial.hymnsOf("eg_bayern_thueringen"), isEmpty);
      expect(partial.hymnsOf("eg"), hasLength(535));
      expect(keys(partial.index.search("Bevor des Tages Licht")), [
        "eg_niedersachsen_bremen:786.5",
      ]);
    });

    test("ohne Katalog schlägt das Laden fehl", () async {
      expect(
        HymnalService(
          bundle: _MissingAssetBundle({HymnalService.catalogAsset}),
        ).load(),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group("Stammteil bleibt unverändert", () {
    test("dieselben Lieder, Nummern, Texte und Noten wie bisher", () {
      final loaded = library.hymnsOf("eg");
      expect(loaded.length, stammteil.length);

      for (final (i, hymn) in loaded.indexed) {
        final old = stammteil[i];
        expect(hymn.id, old.id);
        expect(hymn.number, old.id.toString());
        expect(hymn.key, "eg:${old.id}");
        expect(hymn.displayNumber, "EG ${old.id}");
        expect(hymn.title, old.title);
        expect(hymn.author, old.author);
        expect(hymn.melody, old.melody);
        expect(
          hymn.lyrics.map((l) => "${l.stanza}|${l.text}"),
          old.lyrics.map((l) => "${l.stanza}|${l.text}"),
        );
        expect(hymn.scores.map((s) => s.asset), old.scores.map((s) => s.asset));
      }
    });

    test("alte Datensätze ohne neue Felder bleiben lesbar", () {
      final hymn = Hymn.fromJson({"id": 7, "title": "T"});
      expect(hymn.collectionId, "eg");
      expect(hymn.number, "7");
      expect(hymn.displayNumber, "EG 7");
      expect(hymn.workId, isEmpty);
      expect(hymn.source, isNull);
    });
  });

  group("Neue Sammlungen", () {
    test("Regionalteile: Nummer belegt, kein Text, keine Noten", () {
      for (final hymnal in library.inGroup("eg", HymnalPart.regional)) {
        for (final hymn in library.hymnsOf(hymnal.id)) {
          expect(hymn.lyrics, isEmpty, reason: hymn.key);
          expect(hymn.scores, isEmpty, reason: hymn.key);
          expect(hymn.source, isNotNull, reason: hymn.key);
          expect(hymn.source!.statement, contains(hymn.number));
          expect(hymn.lyricsNote, isNotEmpty);
          // Regionalteile beginnen nach dem Stammteil.
          expect(double.parse(hymn.number), greaterThan(535));
        }
      }
    });

    test("Ergänzungsheft: genau die Lieder des liturgischen Kalenders", () {
      final calendar = File(
        "assets/liturgical_calendar_2026.json",
      ).readAsStringSync();
      final named = {
        for (final match in RegExp(
          r'"EG\.E (\d+):\s*([^"]+)"',
        ).allMatches(calendar))
          match.group(1)!: match.group(2)!.trim(),
      };

      final hymns = library.hymnsOf("eg_ergaenzungsheft");
      expect({for (final h in hymns) h.number: h.title}, named);
      for (final hymn in hymns) {
        expect(hymn.displayNumber, "EG.E ${hymn.number}");
        expect(hymn.lyrics, isEmpty);
      }
    });

    test("Geistlicher Liederschatz ist beschrieben, aber ohne Lieder", () {
      final hymnal = library.hymnal("geistlicher_liederschatz")!;
      expect(hymnal.status, HymnalStatus.notIntegrated);
      expect(hymnal.year, "1832");
      expect(hymnal.sources, isNotEmpty);
      expect(library.hymnsOf(hymnal.id), isEmpty);
    });
  });

  group("Suche", () {
    test("Titel: der Stammteil findet sein Lied zuerst", () {
      final hits = library.index.search("Macht hoch die Tür");
      expect(hits.first.hymn.key, "eg:1");
      expect(hits.first.snippet, isNull);
    });

    test("Nummer: genaue Nummer vor Teiltreffern", () {
      final hits = library.index.search("23");
      expect(hits.first.hymn.key, "eg:23");
      expect(keys(hits), contains("eg:123"));
    });

    test("Nummer mit Vorsatz grenzt auf die Sammlung ein", () {
      expect(
        library.index.search("EG.E 10").first.hymn.key,
        "eg_ergaenzungsheft:10",
      );
      expect(library.index.search("EG 10").first.hymn.key, "eg:10");
      expect(keys(library.index.search("EG 786,5")), [
        "eg_niedersachsen_bremen:786.5",
      ]);
    });

    test("Liedtext: Fundstelle mit Strophe", () {
      final hits = library.index.search("o wohl dem Land");
      expect(hits.first.hymn.key, "eg:1");
      expect(hits.first.snippet, startsWith("Str. 3: O wohl dem Land"));
    });

    test("Umlaute und Satzzeichen spielen keine Rolle", () {
      expect(
        keys(library.index.search("macht hoch die tur")),
        contains("eg:1"),
      );
      expect(
        keys(library.index.search("Macht hoch die Tuer")),
        contains("eg:1"),
      );
      expect(
        keys(library.index.search("harre meine seele")),
        contains("eg_niedersachsen_bremen:593"),
      );
    });

    test("mehrere Wörter in verschiedenen Feldern", () {
      // „Weissel“ steht in der Textangabe, „Herrlichkeit“ im Liedtext.
      expect(keys(library.index.search("Weissel Herrlichkeit")), ["eg:1"]);
    });

    test("Dichter und Bibelstellen", () {
      final tersteegen = keys(library.index.search("Tersteegen"));
      expect(tersteegen, contains("eg_rheinland_westfalen_lippe:661"));
      expect(tersteegen.where((k) => k.startsWith("eg:")), isNotEmpty);
      expect(keys(library.index.search("Psalm 24,7")), contains("eg:1"));
    });

    test("gleiche Nummer in mehreren Sammlungen: jede mit ihrer Quelle", () {
      final hits = library.index.search("593");
      expect(keys(hits).take(2), [
        "eg_niedersachsen_bremen:593",
        "eg_bayern_thueringen:593",
      ]);
      expect(hits[0].hymn.title, "Harre, meine Seele");
      expect(hits[1].hymn.title, "Weil ich Jesu Schäflein bin");
    });

    test("Eingrenzung auf eine Sammlung", () {
      final hits = library.index.search(
        "Bevor des Tages",
        where: (h) => h.collectionId == "eg_bayern_thueringen",
      );
      expect(keys(hits), ["eg_bayern_thueringen:665"]);
      expect(
        library.index.search(
          "Macht hoch",
          where: (h) => h.collectionId != "eg",
        ),
        isEmpty,
      );
    });

    test("leere Suche ergibt keine Treffer", () {
      expect(library.index.search("  "), isEmpty);
    });
  });

  group("Fassungen", () {
    test("dasselbe Lied in zwei Regionalteilen bleibt zweimal erhalten und "
        "ist verknüpft", () {
      final hits = library.index.search("Bevor des Tages Licht vergeht");
      expect(keys(hits), [
        "eg_niedersachsen_bremen:786.5",
        "eg_bayern_thueringen:665",
      ]);

      final nds = find_("eg_niedersachsen_bremen", "786.5");
      final bay = find_("eg_bayern_thueringen", "665");
      expect(library.versionsOf(nds).map((h) => h.key), [bay.key]);
      expect(library.versionsOf(bay).map((h) => h.key), [nds.key]);
    });

    test("Lieder ohne gesicherte Zuordnung werden nicht verknüpft", () {
      expect(library.versionsOf(find_("eg", "1")), isEmpty);
      // Gleiche Nummer ist keine gleiche Fassung.
      expect(library.versionsOf(find_("eg_bayern_thueringen", "593")), isEmpty);
    });
  });

  group("Ansichten", () {
    Future<void> pumpHub(WidgetTester tester) async {
      await tester.pumpWidget(
        app(HymnalsScreen(loadLibrary: () async => library)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("Übersicht: alle Sammlungen mit ihrem Stand", (tester) async {
      await pumpHub(tester);

      expect(find.text("Gesangbücher"), findsOneWidget);
      expect(find.text("Evangelisches Gesangbuch"), findsWidgets);
      expect(find.byKey(const ValueKey("hymnal-eg")), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey("hymnal-eg")),
          matching: find.text("vollständig"),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey("hymnal-geistlicher_liederschatz")),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key("hymnals_overview")),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey("hymnal-geistlicher_liederschatz")),
          matching: find.text("noch nicht integriert"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("globale Suche zeigt die Sammlung jedes Treffers", (
      tester,
    ) async {
      await pumpHub(tester);

      await tester.enterText(find.byKey(const Key("hymnals_search")), "593");
      await tester.pumpAndSettle();

      expect(find.text("EG 593 · Harre, meine Seele"), findsOneWidget);
      expect(find.text("EG 593 · Weil ich Jesu Schäflein bin"), findsOneWidget);
      expect(find.textContaining("EG Niedersachsen/Bremen"), findsWidgets);
      expect(find.textContaining("EG Bayern/Thüringen"), findsWidgets);
    });

    Future<void> tapScope(WidgetTester tester, String id) async {
      final chip = find.byKey(ValueKey("hymnal-scope-$id"));
      await tester.scrollUntilVisible(
        chip,
        150,
        scrollable: find.descendant(
          of: find.byKey(const Key("hymnal_scopes")),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets("Filter grenzen die Suche ein", (tester) async {
      await pumpHub(tester);

      await tester.enterText(find.byKey(const Key("hymnals_search")), "593");
      await tester.pumpAndSettle();
      await tapScope(tester, "hymnal:eg_bayern_thueringen");

      expect(find.text("EG 593 · Weil ich Jesu Schäflein bin"), findsOneWidget);
      expect(find.text("EG 593 · Harre, meine Seele"), findsNothing);

      // Ohne Lieder: ein Hinweis statt einer leeren Liste.
      await tapScope(tester, "hymnal:geistlicher_liederschatz");
      expect(find.byKey(const Key("hymnals_no_results")), findsOneWidget);
      expect(
        find.textContaining("Noch ohne Lieder in der App: Geistlicher"),
        findsOneWidget,
      );
    });

    testWidgets("Filter ohne Suchbegriff listet die Sammlung", (tester) async {
      await pumpHub(tester);

      await tapScope(tester, "part:eg:regional");
      expect(find.byKey(const Key("hymnals_overview")), findsNothing);
      expect(
        find.text("EG 543 · Es ist für uns eine Zeit angekommen"),
        findsOneWidget,
      );
      expect(find.textContaining("EG 1 ·"), findsNothing);
    });

    testWidgets("Treffer im Liedtext zeigt die Fundstelle", (tester) async {
      await pumpHub(tester);

      await tester.enterText(
        find.byKey(const Key("hymnals_search")),
        "o wohl dem Land",
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Str. 3: O wohl dem Land"), findsOneWidget);
    });

    testWidgets("vom Treffer ins Lied und zurück", (tester) async {
      await pumpHub(tester);

      await tester.enterText(
        find.byKey(const Key("hymnals_search")),
        "Bevor des Tages",
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("EG 665 · Bevor des Tages Licht vergeht"));
      await tester.pumpAndSettle();

      expect(find.byType(HymnDetailScreen), findsOneWidget);
      expect(find.text("EG 665"), findsOneWidget);
      expect(find.byKey(const Key("hymn_collection")), findsOneWidget);
      expect(find.text("Regionalteil Bayern und Thüringen"), findsOneWidget);
      expect(find.byKey(const Key("hymn_lyrics_note")), findsOneWidget);
      expect(find.byKey(const Key("hymn_source")), findsOneWidget);
      // Ohne Noten keine Umschaltung und kein Notenbild.
      expect(find.byKey(const Key("hymn_view_mode")), findsNothing);
      expect(find.byType(HymnScoreView), findsNothing);

      // Verknüpfte Fassung im anderen Regionalteil.
      final version = find.byKey(
        const ValueKey("hymn_version_eg_niedersachsen_bremen:786.5"),
      );
      await tester.scrollUntilVisible(version, 200);
      await tester.tap(version);
      await tester.pumpAndSettle();
      expect(find.text("EG 786.5"), findsOneWidget);
      expect(
        find.text("Regionalteil Niedersachsen und Bremen"),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HymnalsScreen), findsOneWidget);
      expect(
        find.text("EG 665 · Bevor des Tages Licht vergeht"),
        findsOneWidget,
      );
    });

    testWidgets("Stammteil im Lied: wie bisher, mit Noten", (tester) async {
      await tester.pumpWidget(
        app(HymnDetailScreen(hymn: find_("eg", "24"), library: library)),
      );
      await tester.pumpAndSettle();

      expect(find.text("EG 24"), findsOneWidget);
      expect(find.byKey(const Key("hymn_collection")), findsNothing);
      expect(find.byKey(const Key("hymn_source")), findsNothing);

      await tester.tap(find.text("Text und Noten"));
      await tester.pumpAndSettle();
      expect(find.byType(HymnScoreView), findsOneWidget);
      // Die erste Strophe steht unter den Noten, nicht noch einmal darunter.
      expect(find.byKey(const ValueKey("hymn_book_stanza_1")), findsNothing);
      expect(
        find.byKey(const ValueKey("hymn_book_stanza_2"), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets("Sammlung öffnen: Stand, Quellen und eigene Suche", (
      tester,
    ) async {
      await pumpHub(tester);

      await tester.tap(
        find.byKey(const ValueKey("hymnal-eg_bayern_thueringen")),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HymnScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey("hymnal-info-eg_bayern_thueringen")),
        findsOneWidget,
      );
      expect(find.text("Quellen"), findsOneWidget);

      await tester.enterText(find.byType(TextField), "Augen");
      await tester.pumpAndSettle();
      expect(find.text("Herr, gib du uns Augen"), findsOneWidget);
      expect(find.text("Weil ich Jesu Schäflein bin"), findsNothing);

      await tester.enterText(find.byType(TextField), "Macht hoch");
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("hymn_list_no_results")), findsOneWidget);
    });

    testWidgets("Sammlung ohne Lieder: Beschreibung statt leerer Liste", (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          HymnScreen(
            hymnalId: "geistlicher_liederschatz",
            loadLibrary: () async => library,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Geistlicher Liederschatz"), findsOneWidget);
      expect(find.text("noch nicht integriert"), findsOneWidget);
      expect(find.text("Noch keine Lieder in der App"), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets("Stammteil-Liste: Suche auch im Liedtext", (tester) async {
      await tester.pumpWidget(
        app(HymnScreen(loadLibrary: () async => library)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Gesangbuch"), findsOneWidget);
      expect(find.text("Macht hoch die Tür"), findsOneWidget);

      await tester.enterText(find.byType(TextField), "o wohl dem Land");
      await tester.pumpAndSettle();
      expect(find.text("Macht hoch die Tür"), findsOneWidget);
      expect(find.textContaining("Str. 3: O wohl dem Land"), findsOneWidget);
    });

    testWidgets("Ladefehler: Hinweis und erneuter Versuch", (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        app(
          HymnalsScreen(
            loadLibrary: () async {
              attempts++;
              if (attempts == 1) throw Exception("kaputt");
              return library;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("hymnals_error")), findsOneWidget);

      await tester.tap(find.text("Erneut versuchen"));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("hymnals_overview")), findsOneWidget);
    });

    testWidgets("nicht geladene Sammlung wird genannt", (tester) async {
      final partial = await tester.runAsync(
        () => HymnalService(
          bundle: _MissingAssetBundle({
            "assets/hymnals/eg_bayern_thueringen.json",
          }),
        ).load(),
      );

      await tester.pumpWidget(
        app(HymnalsScreen(loadLibrary: () async => partial!)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("hymnals_failed")), findsOneWidget);
      expect(
        find.textContaining("Regionalteil Bayern und Thüringen"),
        findsWidgets,
      );
      expect(find.text("Konnte nicht geladen werden"), findsOneWidget);
    });

    testWidgets("schmaler Bildschirm: kein Überlauf", (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpHub(tester);
      await tester.enterText(find.byKey(const Key("hymnals_search")), "Lob");
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
