import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/hymn.dart';
import 'package:theologie_lernapp/models/hymn_score.dart';
import 'package:theologie_lernapp/screens/hymn_detail_screen.dart';
import 'package:theologie_lernapp/widgets/hymn_score_view.dart';

import 'test_asset_bundle.dart';

List<Hymn> loadHymns() {
  final json =
      jsonDecode(File("assets/eg_lieder.json").readAsStringSync())
          as List<dynamic>;
  return json.map((e) => Hymn.fromJson(e as Map<String, dynamic>)).toList();
}

Widget app(Widget home, {ThemeData? theme}) => DefaultAssetBundle(
  bundle: FileAssetBundle(),
  child: MaterialApp(theme: theme, home: home),
);

/// Pfade der gerade dargestellten Notenbilder.
List<String> shownAssets(WidgetTester tester) {
  final images = tester.widgetList<ScoreImage>(find.byType(ScoreImage));
  // Jedes Bild ist tatsächlich gezeichnet, nicht nur vorgesehen.
  expect(find.byType(SvgPicture), findsNWidgets(images.length));
  return images.map((image) => image.score.asset).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hymns = loadHymns();
  Hymn hymn(int id) => hymns.firstWhere((h) => h.id == id);

  // EG 1 hat ein Notenbild, EG 321 zwei Fassungen, EG 16 keines.
  final withScore = hymn(1);
  final withTwoScores = hymn(321);
  final withoutScore = hymn(16);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Datenmodell", () {
    test("alte Datensätze ohne Notenreferenz bleiben lesbar", () {
      final old = Hymn.fromJson({
        "id": 7,
        "title": "Titel",
        "text": "Autor",
        "melody": "Melodie",
        "lyrics": [
          {"stanza": 1, "text": "Zeile"},
        ],
      });

      expect(old.scores, isEmpty);
      expect(old.lyrics.single.text, "Zeile");
    });

    test("fehlerhafte Notenangaben werden übergangen", () {
      expect(HymnScore.listFromJson("kaputt"), isEmpty);
      expect(HymnScore.listFromJson(null), isEmpty);

      final scores = HymnScore.listFromJson([
        "kein Objekt",
        {"id": "ohne_pfad", "format": "svg"},
        {"id": "pdf", "asset": "assets/hymn_scores/x.pdf", "format": "pdf"},
        {"id": "gut", "asset": "assets/hymn_scores/gut.svg", "format": "svg"},
      ]);

      expect(scores.map((s) => s.id), ["gut"]);
      expect(scores.single.source.license, "");
    });
  });

  group("Lieddaten", () {
    test("Testlieder haben die erwarteten Noten", () {
      expect(
        withScore.scores.single.asset,
        "assets/hymn_scores/macht_hoch_die_tuer_die_tor_macht_weit.svg",
      );
      expect(withTwoScores.scores, hasLength(2));
      expect(withoutScore.scores, isEmpty);
    });

    test("jede Notenreferenz zeigt auf ein darstellbares Bild", () {
      // Nur diese Elemente erzeugt der Notensatz; alles andere (Text, CSS,
      // geschachtelte SVG) könnte flutter_svg nicht darstellen.
      const allowed = {
        "svg",
        "defs",
        "g",
        "path",
        "use",
        "polygon",
        "rect",
        "ellipse",
      };
      final checked = <String>{};

      for (final hymn in hymns) {
        for (final score in hymn.scores) {
          final reason = "EG ${hymn.id}: ${score.asset}";
          expect(score.format, "svg", reason: reason);
          expect(score.label, isNotEmpty, reason: reason);
          expect(score.source.url, startsWith("https://"), reason: reason);
          expect(score.source.license, isNotEmpty, reason: reason);
          expect(
            score.asset,
            "assets/hymn_scores/${score.id}.svg",
            reason: reason,
          );

          if (!checked.add(score.asset)) continue;

          final file = File(score.asset);
          expect(file.existsSync(), isTrue, reason: reason);

          final svg = file.readAsStringSync();
          expect(svg, startsWith("<svg "), reason: reason);
          expect(svg, contains('viewBox="0 0 '), reason: reason);

          final tags = RegExp(
            r"<([a-zA-Z]+)",
          ).allMatches(svg).map((m) => m.group(1)).toSet();
          expect(allowed.containsAll(tags), isTrue, reason: "$reason: $tags");
        }
      }

      // Keine verwaisten Bilder im Asset-Ordner.
      final files = Directory(
        "assets/hymn_scores",
      ).listSync().map((f) => f.path.replaceAll("\\", "/")).toSet();
      expect(files, checked);
    });

    testWidgets("flutter_svg kann jedes Notenbild lesen", (tester) async {
      await tester.runAsync(() async {
        for (final file in Directory("assets/hymn_scores").listSync()) {
          final info = await vg.loadPicture(
            SvgStringLoader(File(file.path).readAsStringSync()),
            null,
          );
          expect(info.size.width, greaterThan(0), reason: file.path);
          expect(info.size.height, greaterThan(0), reason: file.path);
          info.picture.dispose();
        }
      });
    });

    test("Übersicht der Integration stimmt mit den Lieddaten überein", () {
      final report =
          jsonDecode(
                File("docs/hymn-scores/integration.json").readAsStringSync(),
              )
              as List<dynamic>;

      expect(report.length, hymns.length);
      for (var i = 0; i < hymns.length; i++) {
        final row = report[i];
        final reason = "EG ${hymns[i].id}";
        expect(row["eg_nummer"], hymns[i].id);
        expect(row["kategorie"], inInclusiveRange(1, 5), reason: reason);
        expect(row["noten"], hymns[i].scores.map((s) => s.id), reason: reason);
        // Kategorie 1 heißt genau: Das Lied hat Noten in der App.
        expect(
          row["kategorie"] == 1,
          hymns[i].scores.isNotEmpty,
          reason: reason,
        );
      }
    });

    test("ein Bild gehört überall zu derselben Vorlage", () {
      final sources = <String, String>{};

      for (final hymn in hymns) {
        for (final score in hymn.scores) {
          final known = sources.putIfAbsent(
            score.asset,
            () => score.source.file,
          );
          expect(score.source.file, known, reason: "EG ${hymn.id}");
        }
      }
    });
  });

  group("Liedansicht", () {
    testWidgets("zeigt zunächst nur den Text", (tester) async {
      await tester.pumpWidget(app(HymnDetailScreen(hymn: withScore)));
      await tester.pumpAndSettle();

      expect(find.text("Nur Text"), findsOneWidget);
      expect(find.text("Text und Noten"), findsOneWidget);
      expect(find.byType(HymnScoreView), findsNothing);
      expect(find.text(withScore.lyrics.first.text), findsOneWidget);
    });

    testWidgets("Umschalten zeigt Noten zusätzlich zum unveränderten Text", (
      tester,
    ) async {
      await tester.pumpWidget(app(HymnDetailScreen(hymn: withScore)));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Text und Noten"));
      await tester.pumpAndSettle();

      expect(shownAssets(tester), [withScore.scores.single.asset]);
      expect(find.byKey(const Key("hymn_score_error")), findsNothing);
      for (final verse in withScore.lyrics) {
        expect(find.text(verse.text, skipOffstage: false), findsOneWidget);
      }

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool("hymn_show_scores"), isTrue);

      await tester.tap(find.text("Nur Text"));
      await tester.pumpAndSettle();

      expect(find.byType(HymnScoreView), findsNothing);
      expect(find.text(withScore.lyrics.first.text), findsOneWidget);
      expect(prefs.getBool("hymn_show_scores"), isFalse);
    });

    testWidgets("gespeicherte Wahl gilt beim nächsten Lied", (tester) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withTwoScores)));
      await tester.pumpAndSettle();

      expect(
        shownAssets(tester),
        withTwoScores.scores.map((s) => s.asset).toList(),
      );
      // Mehrere Fassungen sind beschriftet.
      for (final score in withTwoScores.scores) {
        expect(find.text(score.label), findsOneWidget);
      }
    });

    testWidgets("Lied ohne Noten: Text vollständig, kein leerer Platzhalter", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withoutScore)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("hymn_view_mode")), findsNothing);
      expect(find.byType(HymnScoreView), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text(withoutScore.lyrics.first.text), findsOneWidget);
    });

    testWidgets("beim Wechsel des Liedes erscheinen nur dessen Noten", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});
      final other = hymn(24);

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withScore)));
      await tester.pumpAndSettle();
      expect(shownAssets(tester), [withScore.scores.single.asset]);

      // Dieselbe Ansicht bekommt ein anderes Lied.
      await tester.pumpWidget(app(HymnDetailScreen(hymn: other)));
      await tester.pumpAndSettle();

      expect(other.scores.single.asset, isNot(withScore.scores.single.asset));
      expect(shownAssets(tester), [other.scores.single.asset]);
      expect(find.text("EG 24"), findsOneWidget);

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withoutScore)));
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets("fehlende Notendatei führt zu einem Hinweis statt Absturz", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});
      final broken = Hymn.fromJson({
        "id": 999,
        "title": "Testlied",
        "text": "Autor",
        "melody": "Melodie",
        "lyrics": [
          {"stanza": 1, "text": "Erste Zeile"},
        ],
        "scores": [
          {
            "id": "fehlt",
            "asset": "assets/hymn_scores/fehlt.svg",
            "format": "svg",
            "label": "Fehlt",
          },
        ],
      });

      await tester.pumpWidget(app(HymnDetailScreen(hymn: broken)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key("hymn_score_error")), findsOneWidget);
      expect(find.text("Erste Zeile"), findsOneWidget);
    });

    testWidgets("auf schmalem Bildschirm passen Noten in die Breite", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withTwoScores)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final element in find.byType(SvgPicture).evaluate()) {
        final size = element.size!;
        // 16 Pixel Rand links und rechts; die Noten füllen die Breite und
        // sind hoch genug, um lesbar zu sein.
        expect(size.width, 288);
        expect(size.height, greaterThan(100));
      }
    });

    testWidgets("Noten folgen der Textfarbe des dunklen Designs", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});
      final dark = ThemeData.dark();

      await tester.pumpWidget(
        app(HymnDetailScreen(hymn: withScore), theme: dark),
      );
      await tester.pumpAndSettle();

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        ColorFilter.mode(dark.colorScheme.onSurface, BlendMode.srcIn),
      );
    });

    testWidgets("Tipp auf die Noten öffnet die vergrößerbare Ansicht", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withScore)));
      await tester.pumpAndSettle();

      // Das Bild reicht über den Bildschirm hinaus; getippt wird oben.
      await tester.tapAt(
        tester.getTopLeft(find.byType(SvgPicture)) + const Offset(40, 40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HymnScoreZoomScreen), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HymnScoreZoomScreen), findsNothing);
      expect(find.text("EG 1"), findsOneWidget);
    });
  });
}
