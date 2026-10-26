import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/fathers/fathers_home_screen.dart';
import 'package:theologie_lernapp/screens/fathers/verse_detail_sheet.dart';
import 'package:theologie_lernapp/screens/fathers/work_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/pericope_headings.dart';
import 'package:theologie_lernapp/services/fathers/fathers_repository.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import '../test_asset_bundle.dart';
import 'fathers_fixture.dart';

Finder key(String value) => find.byKey(ValueKey(value));

/// Tippt im Kapiteltext auf das Textstück [text] (z. B. eine Versnummer).
bool tapSpan(WidgetTester tester, bool Function(String text) matches) {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    bool tapped = false;

    widget.text.visitChildren((span) {
      if (!tapped &&
          span is TextSpan &&
          matches(span.text ?? "") &&
          span.recognizer is TapGestureRecognizer) {
        (span.recognizer as TapGestureRecognizer).onTap!();
        tapped = true;
      }

      return !tapped;
    });

    if (tapped) return true;
  }

  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PericopeHeadings headings;
  late FixtureBundle bundle;
  late FathersRepository repo;

  setUpAll(() async {
    headings = await PericopeHeadings.load(bundle: FileAssetBundle());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bundle = FixtureBundle();
    repo = FathersRepository(bundle: bundle);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  Widget verse(
    int chapter,
    int verse, {
    void Function(BibleReference)? onOpen,
  }) => Scaffold(
    body: VerseDetailView(
      bookId: "JHN",
      chapter: chapter,
      verse: verse,
      headings: headings,
      repository: repo,
      onOpenReference: onOpen ?? (_) {},
    ),
  );

  group("Versdetailansicht", () {
    testWidgets("zeigt Abschnitte mit Autor, Werk, Art und Ausgabe", (
      tester,
    ) async {
      await pump(tester, verse(1, 1));

      expect(find.text("Joh 1,1"), findsOneWidget);
      expect(find.text("Testautor A"), findsWidgets);
      expect(find.text("Vorträge über Johannes"), findsWidgets);
      expect(find.text("Auslegung des Abschnitts"), findsOneWidget);
      expect(find.textContaining("Historische Übersetzung"), findsWidgets);
      expect(find.textContaining("Übers. Ü. Bersetzer"), findsWidgets);
      expect(find.textContaining("Im Anfang war das Wort"), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets("ohne Zuordnung kein erfundener Kommentar", (tester) async {
      await pump(tester, verse(2, 1));

      expect(find.textContaining("noch kein Abschnitt"), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets("Kommentar → vollständiges Werk an der Stelle", (tester) async {
      await pump(tester, verse(1, 3));

      await tester.tap(key("open-work-l1"));
      await tester.pumpAndSettle();

      expect(find.byType(SectionReaderScreen), findsOneWidget);
      expect(key("section-title"), findsOneWidget);
      expect(find.text("Dritter Absatz."), findsOneWidget);

      // Weiter zum nächsten Abschnitt (andere Textdatei bei Abschnitt 3).
      await tester.tap(key("section-next"));
      await tester.pumpAndSettle();
      expect(find.text("Also hat Gott die Welt geliebt."), findsOneWidget);
    });

    testWidgets("verwandte Stellen führen zur Stelle", (tester) async {
      BibleReference? opened;

      await pump(tester, verse(1, 1, onOpen: (r) => opened = r));

      await tester.tap(find.text("Verwandte Stellen").first);
      await tester.pumpAndSettle();

      expect(key("xref-Gen 1,1"), findsOneWidget);
      expect(find.textContaining("Bewertung 59"), findsOneWidget);

      await tester.tap(key("xref-Gen 1,1"));
      expect(opened.toString(), "GEN 1,1");
    });

    testWidgets("Ladefehler zeigt „Erneut laden“", (tester) async {
      bundle.failing.add("$root/links/JHN.json");

      await pump(tester, verse(1, 1));

      expect(key("verse-detail-retry"), findsOneWidget);

      bundle.failing.clear();
      await tester.tap(key("verse-detail-retry"));
      await tester.pumpAndSettle();

      expect(find.textContaining("Im Anfang war das Wort"), findsWidgets);
    });
  });

  group("Bibliothek", () {
    testWidgets("Suche nach Werk und Öffnen des Werks", (tester) async {
      await pump(tester, FathersHomeScreen(repository: repo));

      expect(key("work-werk_a"), findsOneWidget);
      expect(key("work-werk_b"), findsOneWidget);

      // Volltexte werden erst beim Öffnen eines Werks geladen.
      expect(bundle.requests, ["$root/library.json"]);

      await tester.enterText(key("fathers-search"), "Homilien über");
      await tester.pumpAndSettle();

      expect(key("work-werk_a"), findsNothing);
      expect(key("work-werk_b"), findsOneWidget);

      await tester.enterText(key("fathers-search"), "keinwerk");
      await tester.pumpAndSettle();
      expect(find.textContaining("0 Werke"), findsOneWidget);

      await tester.enterText(key("fathers-search"), "");
      await tester.pumpAndSettle();
      await tester.tap(key("work-werk_a"));
      await tester.pumpAndSettle();

      expect(key("version-card"), findsOneWidget);
      expect(find.text("Ü. Bersetzer"), findsOneWidget);
      expect(find.text("Übersetzer † 1918"), findsOneWidget);
      expect(key("section-1"), findsOneWidget);
    });

    testWidgets("Bibelstelle in der Suche zeigt die Kirchenväter dazu", (
      tester,
    ) async {
      await pump(tester, FathersHomeScreen(repository: repo));

      await tester.enterText(key("fathers-search"), "Joh 3,16");
      await tester.pumpAndSettle();

      expect(key("ref-hit-l3"), findsOneWidget);
      expect(key("ref-hit-l1"), findsNothing);

      await tester.enterText(key("fathers-search"), "Röm 1,1");
      await tester.pumpAndSettle();
      expect(find.textContaining("noch kein Abschnitt"), findsOneWidget);
    });

    testWidgets("Werk ohne freien Text: nur Angaben und Link", (tester) async {
      await pump(tester, WorkScreen(workId: "werk_b", repository: repo));

      expect(find.textContaining("nicht enthalten"), findsOneWidget);
      expect(find.text("Bei der Quelle öffnen"), findsOneWidget);
      expect(find.text("Rechte ungeklärt – nur Verweis"), findsOneWidget);
      expect(bundle.requests.where((r) => r.contains("/texts/")), isEmpty);
    });

    testWidgets("Werk → Bibelstellen → Abschnitt", (tester) async {
      await pump(tester, WorkScreen(workId: "werk_a", repository: repo));

      await tester.tap(find.text("Bibelstellen"));
      await tester.pumpAndSettle();
      await tester.tap(key("refs-JHN"));
      await tester.pumpAndSettle();

      expect(find.text("Joh 1,1–5"), findsOneWidget);
      expect(find.text("Joh 3,16"), findsOneWidget);

      await tester.tap(find.text("Joh 3,16"));
      await tester.pumpAndSettle();

      expect(find.text("Also hat Gott die Welt geliebt."), findsOneWidget);
      expect(key("ref-chip-l3"), findsOneWidget);
    });
  });

  group("Bibel-Reader", () {
    testWidgets("Antippen der Versnummer öffnet die Versdetailansicht", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"bible_position": "JHN|1|0"});
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleReaderScreen(
            repository: BibleRepository(
              source: AssetBibleTextSource(bundle: FileAssetBundle()),
            ),
            pericopeHeadings: headings,
            fathersRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Johannes 1"), findsOneWidget);

      // Kirchenväter-Daten erst beim Antippen.
      expect(bundle.requests, isEmpty);

      // Die Versnummer endet mit einem geschützten Leerzeichen.
      expect(tapSpan(tester, (t) => t.trim() == "1"), isTrue);
      await tester.pumpAndSettle();

      expect(key("verse-detail-title"), findsOneWidget);
      expect(find.text("Joh 1,1"), findsOneWidget);
      expect(find.textContaining("Im Anfang war das Wort"), findsWidgets);

      // Verwandte Stelle → Reader springt dorthin.
      await tester.tap(find.text("Verwandte Stellen").first);
      await tester.pumpAndSettle();
      await tester.tap(key("xref-Gen 1,1"));
      await tester.pumpAndSettle();

      expect(find.text("1. Mose 1"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
