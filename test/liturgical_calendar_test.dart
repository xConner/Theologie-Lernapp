import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/bible/bible_reference.dart';
import 'package:theologie_lernapp/models/liturgical_day.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/liturgical_calendar_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/liturgical_reference_parser.dart';
import 'package:theologie_lernapp/services/bible/pericope_headings.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

/// Ob [text] im Kapitel hinterlegt (hervorgehoben) dargestellt wird.
bool isHighlighted(WidgetTester tester, String text) {
  bool found = false;

  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    widget.text.visitChildren((span) {
      if (span is TextSpan &&
          (span.text ?? "").contains(text) &&
          span.style?.backgroundColor != null) {
        found = true;
      }

      return true;
    });
  }

  return found;
}

/// Tippt genau auf [text] im Kapitel (ein Absatz enthält mehrere Verse).
Future<void> tapVerse(WidgetTester tester, String text) async {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final start = paragraph.text.toPlainText().indexOf(text);

    if (start < 0) continue;

    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + text.length),
        )
        .first;

    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.pumpAndSettle();

    return;
  }

  fail("„$text“ steht nicht im Kapitel.");
}

List<LiturgicalDay> loadDays() {
  final List<dynamic> data = json.decode(
    File("assets/liturgical_calendar_2026.json").readAsStringSync(),
  );

  return [for (final entry in data) LiturgicalDay.fromJson(entry)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Stellenangaben des Kalenders", () {
    BiblePassage single(String input) {
      final passages = LiturgicalReferenceParser.parse(input);

      expect(passages, hasLength(1), reason: input);

      return passages.single;
    }

    test("einfache Stelle: Buch, Kapitel und Versbereich", () {
      final passage = single("Matthäus 28,16-20");

      expect(passage.label, "Matthäus 28,16-20");
      expect(
        passage.reference,
        const BibleReference(
          bookId: "MAT",
          chapter: 28,
          verse: 16,
          endVerse: 20,
        ),
      );
      expect(passage.parts, isEmpty);

      expect(single("5. Mose 7,6-12").reference.bookId, "DEU");
      expect(single("Jesaja 43,1").reference.toString(), "ISA 43,1");
      expect(single("Offenbarung an Johannes 21,1-7").reference.bookId, "REV");
      expect(single("Sprüche Salomo 24,10-12").reference.bookId, "PRO");
      expect(single("Hoheslied 3,1-5").reference.bookId, "SNG");
    });

    test("Versteile und eingeklammerte Verse gehören zur Stelle", () {
      expect(single("Epheser 5,8b-14").reference.toString(), "EPH 5,8–14");
      expect(single("Römer 6,3-8 (9-11)").reference.toString(), "ROM 6,3–11");
      expect(
        single("Philipper 3,(4b-6)7-14").reference.toString(),
        "PHP 3,4–14",
      );

      // Zusammenhängende Verse sind eine Gruppe.
      expect(single("Lukas 13,(1-5) 6-9").parts, isEmpty);
      expect(single("1. Mose 28,10-19a (19b-22)").parts, isEmpty);
    });

    test("Lücken: nur die genannten Versgruppen werden hervorgehoben", () {
      final passage = single("Psalm 50,1-6.14-15.23");

      expect(passage.reference.toString(), "PSA 50,1–23");
      expect(passage.parts.map((p) => p.rangeText), [
        "50,1–6",
        "50,14–15",
        "50,23",
      ]);

      final lazarus = single("Johannes 11,1 (2) 3.17-27 (28-38a) 38b-45");

      expect(lazarus.reference.toString(), "JHN 11,1–45");
      expect(lazarus.parts.map((p) => p.rangeText), ["11,1–3", "11,17–45"]);
    });

    test("Stelle über mehrere Kapitel", () {
      final passage = single("Apostelgeschichte 11,27-12,5");

      expect(
        passage.reference,
        const BibleReference(
          bookId: "ACT",
          chapter: 11,
          verse: 27,
          endChapter: 12,
          endVerse: 5,
        ),
      );
      expect(passage.reference.containsVerse(11, 30), isTrue);
      expect(passage.reference.containsVerse(12, 5), isTrue);
      expect(passage.reference.containsVerse(12, 6), isFalse);
    });

    test("mehrere Stellen einer Angabe sind einzeln erreichbar", () {
      final flood = LiturgicalReferenceParser.parse("1. Mose 8,18-22; 9,12-17");

      expect(flood.map((p) => p.label), ["1. Mose 8,18-22", "1. Mose 9,12-17"]);
      expect(flood.map((p) => p.reference.toString()), [
        "GEN 8,18–22",
        "GEN 9,12–17",
      ]);

      final psalm = LiturgicalReferenceParser.parse(
        "Psalm 139,1-12 oder Psalm 139,13-16.23-24",
      );

      expect(psalm.map((p) => p.reference.toString()), [
        "PSA 139,1–12",
        "PSA 139,13–24",
      ]);
      expect(psalm.last.parts, hasLength(2));
    });

    test("Unlesbares ergibt keine Stelle, eine Kapitelangabe das Kapitel", () {
      expect(LiturgicalReferenceParser.parse("siehe Agende"), isEmpty);
      expect(LiturgicalReferenceParser.parse("Unbekannt 3,1-4"), isEmpty);
      expect(
        single("Psalm 23").reference,
        const BibleReference.chapter("PSA", 23),
      );
    });

    test("alle Stellen des ausgelieferten Kalenders lassen sich öffnen", () {
      final days = loadDays();

      expect(days, isNotEmpty);

      for (final day in days) {
        final references = [
          day.spruch.reference,
          day.psalm,
          day.readings.oldTestament,
          day.readings.epistle,
          ?day.readings.hallelujah,
          day.readings.gospel,
          day.readings.sermon,
        ];

        for (final reference in references) {
          final passages = LiturgicalReferenceParser.parse(reference);

          expect(passages, isNotEmpty, reason: reference);

          for (final passage in passages) {
            // Immer mit Versen – keine Angabe fällt auf das Kapitel zurück.
            expect(passage.reference.hasVerses, isTrue, reason: reference);
          }
        }
      }
    });
  });

  group("Kalender öffnet den Bibel-Reader", () {
    final source = AssetBibleTextSource(bundle: FileAssetBundle());

    final day = LiturgicalDay(
      date: DateTime(2026, 7, 12),
      title: "6. Sonntag nach Trinitatis",
      type: "sonntag",
      color: "grün",
      spruch: const BibleVerse(
        text: "Fürchte dich nicht.",
        reference: "Jesaja 43,1",
      ),
      psalm: "Psalm 139,1-12 oder Psalm 139,13-16.23-24",
      songs: const ["EG 200: Ich bin getauft auf deinen Namen"],
      readings: const Readings(
        oldTestament: "Jesaja 43,1-7",
        epistle: "Römer 6,3-8 (9-11)",
        hallelujah: "Psalm 22,23",
        gospel: "Matthäus 28,16-20",
        sermon: "Psalm 50,1-6.14-15.23",
      ),
    );

    late PericopeHeadings headings;

    setUpAll(() async {
      headings = await PericopeHeadings.load(bundle: FileAssetBundle());
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pumpCalendar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LiturgicalCalendarScreen(
            loadDays: () async => [day],
            bibleRepository: BibleRepository(source: source),
            pericopeHeadings: headings,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester, String id) async {
      await tester.ensureVisible(key("calendar-reference-$id"));
      await tester.tap(key("calendar-reference-$id"));
      await tester.pumpAndSettle();
    }

    testWidgets("jede Stelle des Tages ist einzeln antippbar", (tester) async {
      await pumpCalendar(tester);

      for (final id in [
        "spruch",
        "psalm",
        "old-testament",
        "epistle",
        "hallelujah",
        "gospel",
        "sermon",
      ]) {
        expect(key("calendar-reference-$id"), findsOneWidget, reason: id);
      }

      expect(find.text("Matthäus 28,16-20"), findsOneWidget);
    });

    testWidgets("Evangelium: Buch, Kapitel, Verse und Standardausgabe; die "
        "Hervorhebung lässt sich wegtippen", (tester) async {
      await pumpCalendar(tester);

      await open(tester, "gospel");

      expect(find.byType(BibleReaderScreen), findsOneWidget);
      expect(find.text("Matthäus 28"), findsOneWidget);
      expect(find.text("LUT 1912"), findsOneWidget);
      expect(
        find.text("6. Sonntag nach Trinitatis · Evangelium"),
        findsOneWidget,
      );

      expect(isHighlighted(tester, "Mir ist gegeben alle Gewalt"), isTrue);
      expect(isHighlighted(tester, "Fürchtet euch nicht"), isFalse);

      await tapVerse(tester, "Mir ist gegeben alle Gewalt");

      expect(isHighlighted(tester, "Mir ist gegeben alle Gewalt"), isFalse);

      // Zurück im Kalender ist die nächste Stelle erreichbar.
      await tester.pageBack();
      await tester.pumpAndSettle();

      await open(tester, "epistle");

      expect(find.text("Römer 6"), findsOneWidget);
    });

    testWidgets("die gewählte Ausgabe des Readers gilt auch hier", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({"bible_translation": "deuelbbk"});

      await pumpCalendar(tester);

      await open(tester, "gospel");

      expect(find.text("Matthäus 28"), findsOneWidget);
      expect(find.text("ELB-BK"), findsOneWidget);
    });

    testWidgets("Stelle mit Lücken: nur die genannten Verse hervorgehoben", (
      tester,
    ) async {
      await pumpCalendar(tester);

      await open(tester, "sermon");

      expect(find.text("Psalmen 50"), findsOneWidget);

      // Vers 14 gehört dazu, Vers 7 liegt in der Lücke.
      expect(isHighlighted(tester, "Opfere Gott Dank"), isTrue);
      expect(isHighlighted(tester, "Höre, mein Volk"), isFalse);
    });

    testWidgets("„oder“: beide Stellen stehen im Reader zur Wahl", (
      tester,
    ) async {
      await pumpCalendar(tester);

      await open(tester, "psalm");

      expect(find.text("Psalmen 139"), findsOneWidget);
      expect(key("bible-passage-0"), findsOneWidget);
      expect(key("bible-passage-1"), findsOneWidget);
      expect(find.text("Psalm 139,13-16.23-24"), findsOneWidget);
    });
  });
}
