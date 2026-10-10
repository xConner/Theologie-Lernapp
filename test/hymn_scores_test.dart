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

/// Die Silben eines Notenbildes in Leserichtung (Text der `<text>`-Elemente).
List<String> syllablesIn(String svg) => RegExp(r"<text[^>]*>([^<]*)</text>")
    .allMatches(svg)
    .map(
      (m) => m
          .group(1)!
          .replaceAll("&quot;", '"')
          .replaceAll("&amp;", "&")
          .replaceAll("&lt;", "<")
          .replaceAll("&gt;", ">"),
    )
    .toList();

/// Systeme eines Notenbildes: je System die Silben mit ihrer x-Position.
Map<int, List<(double, String)>> systemsIn(String svg) {
  final systems = <int, List<(double, String)>>{};
  final pattern = RegExp(
    r'<text x="([\d.]+)" y="([\d.]+)"[^>]*>([^<]*)</text>',
  );
  for (final match in pattern.allMatches(svg)) {
    systems.putIfAbsent(double.parse(match.group(2)!).round(), () => []).add((
      double.parse(match.group(1)!),
      match.group(3)!,
    ));
  }
  return systems;
}

String withoutSpace(String text) => text.replaceAll(RegExp(r"\s+"), "");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hymns = loadHymns();
  Hymn hymn(int id) => hymns.firstWhere((h) => h.id == id);

  // EG 24: erste Strophe unter den Noten. EG 27: mit Melismen und Auftakt.
  // EG 321: zwei Fassungen. EG 1: Noten ohne gesicherte Silbenzuordnung.
  // EG 154: Noten, aber kein Liedtext in der App. EG 16: keine Noten.
  final withUnderlay = hymn(24);
  final withMelisma = hymn(27);
  final withTwoScores = hymn(321);
  final melodyOnly = hymn(1);
  final withoutLyrics = hymn(154);
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
        {
          "id": "text",
          "asset": "assets/hymn_scores/eg001_text.svg",
          "format": "svg",
          "underlay": {"stanza": 1},
        },
      ]);

      expect(scores.map((s) => s.id), ["gut", "text"]);
      expect(scores.first.source.license, "");
      // Noten ohne Angabe zur Unterlegung (Stand vor dieser Funktion)
      expect(scores.first.hasUnderlay, isFalse);
      expect(scores.last.underlayStanza, 1);
    });
  });

  group("Lieddaten", () {
    test("Testlieder haben die erwarteten Noten", () {
      expect(
        withUnderlay.scores.single.asset,
        "assets/hymn_scores/eg024_vom_himmel_hoch_da_komm_ich_her_eg.svg",
      );
      expect(withUnderlay.scores.single.underlayStanza, 1);
      expect(withMelisma.scores.single.hasUnderlay, isTrue);
      expect(withTwoScores.scores, hasLength(2));
      expect(melodyOnly.scores.single.hasUnderlay, isFalse);
      expect(
        melodyOnly.scores.single.asset,
        "assets/hymn_scores/macht_hoch_die_tuer_die_tor_macht_weit.svg",
      );
      expect(withoutLyrics.scores, isNotEmpty);
      expect(withoutLyrics.lyrics, isEmpty);
      expect(withoutScore.scores, isEmpty);
    });

    test("jede Notenreferenz zeigt auf ein darstellbares Bild", () {
      // Nur diese Elemente erzeugt der Notensatz; alles andere (CSS,
      // geschachtelte SVG, tspan) könnte flutter_svg nicht darstellen.
      const allowed = {
        "svg",
        "defs",
        "g",
        "path",
        "use",
        "polygon",
        "rect",
        "ellipse",
        "text",
      };
      final checked = <String>{};

      for (final hymn in hymns) {
        final number = hymn.id.toString().padLeft(3, "0");
        for (final score in hymn.scores) {
          final reason = "EG ${hymn.id}: ${score.asset}";
          expect(score.format, "svg", reason: reason);
          expect(score.label, isNotEmpty, reason: reason);
          expect(score.source.url, startsWith("https://"), reason: reason);
          expect(score.source.license, isNotEmpty, reason: reason);
          // Mit Text gehört das Bild genau diesem Lied, ohne Text der Melodie.
          expect(
            score.asset,
            score.hasUnderlay
                ? "assets/hymn_scores/eg${number}_${score.id}.svg"
                : "assets/hymn_scores/${score.id}.svg",
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
          expect(svg.contains("<text"), score.hasUnderlay, reason: reason);
        }
      }

      // Keine verwaisten Bilder im Asset-Ordner.
      final files = Directory(
        "assets/hymn_scores",
      ).listSync().map((f) => f.path.replaceAll("\\", "/")).toSet();
      expect(files, checked);
    });

    test("unter den Noten steht die erste Strophe vollständig und in "
        "ihrer Reihenfolge", () {
      var checked = 0;

      for (final hymn in hymns) {
        for (final score in hymn.scores.where((s) => s.hasUnderlay)) {
          final reason = "EG ${hymn.id}";
          final stanza = hymn.lyrics.firstWhere(
            (verse) => verse.stanza == score.underlayStanza,
          );
          expect(stanza, same(hymn.lyrics.first), reason: reason);

          final svg = File(score.asset).readAsStringSync();
          // Alle Silben hintereinander ergeben den Strophentext – keine
          // fehlt, keine ist doppelt oder vertauscht.
          expect(
            withoutSpace(syllablesIn(svg).join()),
            withoutSpace(stanza.text),
            reason: reason,
          );

          // Innerhalb eines Notensystems stehen die Silben von links nach
          // rechts in Textreihenfolge und überdecken sich nicht.
          for (final system in systemsIn(svg).values) {
            for (var i = 1; i < system.length; i++) {
              expect(
                system[i].$1,
                greaterThan(system[i - 1].$1),
                reason: "$reason: ${system[i - 1].$2} / ${system[i].$2}",
              );
            }
          }
          checked++;
        }
      }

      expect(checked, greaterThan(150));
    });

    test("kein Notensystem beginnt mitten im Wort", () {
      var systemsChecked = 0;

      for (final hymn in hymns) {
        for (final score in hymn.scores.where((s) => s.hasUnderlay)) {
          final text = hymn.lyrics.first.text;
          // Stellen im Text (ohne Leerraum gezählt), an denen ein Wort beginnt
          final wordStarts = <int>{0};
          var count = 0;
          for (var i = 0; i < text.length; i++) {
            if (text[i].trim().isEmpty) {
              wordStarts.add(count);
            } else {
              count++;
            }
          }

          final svg = File(score.asset).readAsStringSync();
          final systems = systemsIn(svg);
          var offset = 0;
          for (final y in systems.keys.toList()..sort()) {
            expect(
              wordStarts,
              contains(offset),
              reason:
                  "EG ${hymn.id}: System beginnt mit ${systems[y]!.first.$2}",
            );
            offset += systems[y]!.fold(
              0,
              (sum, s) => sum + withoutSpace(s.$2).length,
            );
            systemsChecked++;
          }
        }
      }

      expect(systemsChecked, greaterThan(600));
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
        final hymn = hymns[i];
        final reason = "EG ${hymn.id}";
        expect(row["eg_nummer"], hymn.id);
        expect(row["noten"], hymn.scores.map((s) => s.id), reason: reason);
        expect(
          row["unterlegt"],
          hymn.scores.where((s) => s.hasUnderlay).map((s) => s.id),
          reason: reason,
        );

        final expected = hymn.scores.any((s) => s.hasUnderlay)
            ? 1
            : hymn.scores.isEmpty
            ? anyOf(4, 5)
            : hymn.lyrics.isEmpty
            ? 3
            : 2;
        expect(row["kategorie"], expected, reason: reason);
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

    test("Schrift des unterlegten Textes ist eingebunden", () {
      final pubspec = File("pubspec.yaml").readAsStringSync();
      expect(pubspec, contains("family: $scoreTextFont"));
      expect(File("assets/fonts/Tinos-Regular.ttf").existsSync(), isTrue);

      final svg = File(withUnderlay.scores.single.asset).readAsStringSync();
      expect(svg, contains('font-family="$scoreTextFont"'));
    });
  });

  group("Liedansicht", () {
    testWidgets("zeigt zunächst nur den Text", (tester) async {
      await tester.pumpWidget(app(HymnDetailScreen(hymn: withUnderlay)));
      await tester.pumpAndSettle();

      expect(find.text("Nur Text"), findsOneWidget);
      expect(find.text("Text und Noten"), findsOneWidget);
      expect(find.byType(HymnScoreView), findsNothing);
      expect(find.text("Strophe 1"), findsOneWidget);
      expect(find.text(withUnderlay.lyrics.first.text), findsOneWidget);
    });

    testWidgets("Text und Noten: erste Strophe unter den Noten, die übrigen "
        "darunter", (tester) async {
      await tester.pumpWidget(app(HymnDetailScreen(hymn: withUnderlay)));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Text und Noten"));
      await tester.pumpAndSettle();

      expect(shownAssets(tester), [withUnderlay.scores.single.asset]);
      expect(find.byKey(const Key("hymn_score_error")), findsNothing);
      expect(find.byKey(const Key("hymn_score_no_underlay")), findsNothing);

      // Die erste Strophe steht im Notenbild und nicht noch einmal darunter.
      expect(
        find.text(withUnderlay.lyrics.first.text, skipOffstage: false),
        findsNothing,
      );
      for (final verse in withUnderlay.lyrics.skip(1)) {
        expect(find.text(verse.text, skipOffstage: false), findsOneWidget);
        expect(
          find.text("${verse.stanza}.", skipOffstage: false),
          findsOneWidget,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool("hymn_show_scores"), isTrue);

      // Zurück: der unveränderte Text mit allen Strophen.
      await tester.tap(find.text("Nur Text"));
      await tester.pumpAndSettle();

      expect(find.byType(HymnScoreView), findsNothing);
      for (final verse in withUnderlay.lyrics) {
        expect(find.text(verse.text, skipOffstage: false), findsOneWidget);
      }
      expect(prefs.getBool("hymn_show_scores"), isFalse);
    });

    testWidgets("ohne gesicherte Silbenzuordnung: Melodie, Hinweis und der "
        "ganze Text", (tester) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});

      await tester.pumpWidget(app(HymnDetailScreen(hymn: melodyOnly)));
      await tester.pumpAndSettle();

      expect(shownAssets(tester), [melodyOnly.scores.single.asset]);
      expect(find.byKey(const Key("hymn_score_no_underlay")), findsOneWidget);
      for (final verse in melodyOnly.lyrics) {
        expect(find.text(verse.text, skipOffstage: false), findsOneWidget);
      }
      expect(find.text("Strophe 1", skipOffstage: false), findsOneWidget);
    });

    testWidgets("Noten ohne Liedtext in der App: kein Hinweis auf fehlende "
        "Silben", (tester) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withoutLyrics)));
      await tester.pumpAndSettle();

      expect(shownAssets(tester), hasLength(withoutLyrics.scores.length));
      expect(find.byKey(const Key("hymn_score_no_underlay")), findsNothing);
      expect(
        find.textContaining("nicht verfügbar", skipOffstage: false),
        findsOneWidget,
      );
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
        expect(find.text(score.label, skipOffstage: false), findsOneWidget);
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
      expect(find.text("Strophe 1"), findsOneWidget);
      expect(find.text(withoutScore.lyrics.first.text), findsOneWidget);
    });

    testWidgets("beim Wechsel des Liedes erscheinen nur dessen Noten", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withUnderlay)));
      await tester.pumpAndSettle();
      expect(shownAssets(tester), [withUnderlay.scores.single.asset]);

      // Dieselbe Ansicht bekommt ein anderes Lied.
      await tester.pumpWidget(app(HymnDetailScreen(hymn: withMelisma)));
      await tester.pumpAndSettle();

      expect(shownAssets(tester), [withMelisma.scores.single.asset]);
      expect(find.text("EG 27"), findsOneWidget);
      expect(
        find.text(withMelisma.lyrics[1].text, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(withUnderlay.lyrics[1].text, skipOffstage: false),
        findsNothing,
      );

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
          {"stanza": 2, "text": "Zweite Zeile"},
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
      expect(find.text("Zweite Zeile"), findsOneWidget);
    });

    for (final width in [320.0, 412.0, 1280.0]) {
      testWidgets("bei $width Pixeln Breite sind Noten und Text nicht "
          "abgeschnitten", (tester) async {
        SharedPreferences.setMockInitialValues({"hymn_show_scores": true});
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(HymnDetailScreen(hymn: withTwoScores)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final available = width - 32;
        for (final element in find.byType(SvgPicture).evaluate()) {
          final size = element.size!;
          // Das Bild füllt die Breite (auf breiten Bildschirmen begrenzt)
          // und behält sein Seitenverhältnis: Silben und Noten wandern nie
          // gegeneinander.
          expect(size.width, available > 520 ? 520 : available);
          expect(size.height, greaterThan(100));

          final picture = element.widget as SvgPicture;
          expect(picture.fit, BoxFit.fitWidth);
        }
      });
    }

    testWidgets("Noten folgen der Textfarbe des dunklen Designs", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"hymn_show_scores": true});
      final dark = ThemeData.dark();

      await tester.pumpWidget(
        app(HymnDetailScreen(hymn: withUnderlay), theme: dark),
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

      await tester.pumpWidget(app(HymnDetailScreen(hymn: withUnderlay)));
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
      expect(find.text("EG 24"), findsOneWidget);
    });
  });
}
