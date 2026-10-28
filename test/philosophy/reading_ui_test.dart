import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/screens/philosophy/philosophy_home_screen.dart';
import 'package:theologie_lernapp/screens/philosophy/reading/reader_screen.dart';
import 'package:theologie_lernapp/screens/philosophy/reading/reading_session.dart';
import 'package:theologie_lernapp/screens/philosophy/reading/reading_work_screen.dart';
import 'package:theologie_lernapp/screens/philosophy/reading/sentence_detail.dart';
import 'package:theologie_lernapp/services/philosophy/private_edition_store.dart';
import 'package:theologie_lernapp/services/philosophy/reading_user_data.dart';
import 'package:theologie_lernapp/services/quiz_documents.dart';

import 'reading_fixture.dart';

/// Sitzung mit importierter Testausgabe; Laden außerhalb der Testuhr, weil
/// große Assets im Hintergrund dekodiert werden.
Future<ReadingSession> preparedSession(WidgetTester tester) async {
  late ReadingSession session;
  await tester.runAsync(() async {
    PrivateEditionStore.clearSession();
    final store = PrivateEditionStore(
      uid: null,
      local: MemoryPrivateEditionBackend(),
    );
    await store.save("heinemann-2021", privateEditionFixture());
    session = ReadingSession(
      uid: null,
      workId: "aristotle.physics",
      documents: QuizDocuments.forUser(null),
      privateStore: store,
    );
    await session.load();
    await session.analyzer();
  });
  return session;
}

Future<ReaderScreenState> openReaderAt(
  WidgetTester tester,
  ReadingSession session, {
  String? sentenceId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReaderScreen(session: session, sentenceId: sentenceId),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<ReaderScreenState>(find.byType(ReaderScreen));
}

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("Bereich ist unter Philosophie eingetragen", () {
    expect(
      PhilosophyHomeScreen.areas.map((a) => a.key),
      contains("aristotle-physics"),
    );
  });

  testWidgets("Werkseite zeigt nur Reiter mit Inhalt", (tester) async {
    setSize(tester, const Size(1200, 900));
    final session = await preparedSession(tester);
    expect(session.edition!.id, "heinemann-2021");
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingWorkScreen(
          uid: null,
          workId: "aristotle.physics",
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ["Übersicht", "Kommentar", "Ausgabe", "Meine Stellen", "Lernen"]) {
      expect(find.widgetWithText(Tab, tab), findsOneWidget);
    }
    expect(find.widgetWithText(Tab, "Seminar"), findsNothing);
    expect(find.textContaining("Seminarplan und Sitzungen – noch nicht"), findsOneWidget);

    // Wechsel auf den freien Text: ohne Übersetzung, Anmerkungen, Einleitung.
    await tester.runAsync(() async {
      await session.switchEdition(session.work!.edition("ross-first1k")!);
    });
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, "Kommentar"), findsNothing);
    expect(find.widgetWithText(Tab, "Ausgabe"), findsNothing);
    expect(session.mode, ReadingMode.greek);
  });

  testWidgets("Modi, Umschalter je Abschnitt und Position", (tester) async {
    setSize(tester, const Size(1200, 900));
    final session = await preparedSession(tester);
    final reader = await openReaderAt(tester, session, sentenceId: "184a18");

    // Voreinstellung bei zweisprachiger Ausgabe: untereinander.
    expect(session.mode, ReadingMode.interlinear);
    expect(find.byKey(const ValueKey("german-184a10")), findsOneWidget);
    expect(reader.anchorUnit, "184a16");

    await reader.setMode(ReadingMode.greek);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("german-184a10")), findsNothing);
    expect(reader.anchorUnit, "184a16");

    // Übersetzung nur für einen Abschnitt einblenden.
    await tester.tap(find.byKey(const ValueKey("toggle-184a10")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("german-184a10")), findsOneWidget);
    expect(find.byKey(const ValueKey("german-184a16")), findsNothing);

    await reader.setMode(ReadingMode.sideBySide);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("german-184a16")), findsOneWidget);
    await reader.setMode(ReadingMode.german);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("greek-184a16")), findsNothing);
    expect(find.byKey(const ValueKey("german-184a16")), findsOneWidget);
    expect(find.text("≈"), findsOneWidget);

    // Gespeichert: Modus und Leseposition.
    await tester.pump(const Duration(seconds: 3));
    late ReadingUserState stored;
    await tester.runAsync(() async => stored = await session.userData.load());
    expect(stored.mode, ReadingMode.german);
    expect(stored.position, "184a18");
  });

  testWidgets("Satzdetail als Seitenleiste mit Anmerkungen und Lesezeichen", (
    tester,
  ) async {
    setSize(tester, const Size(1400, 900));
    final session = await preparedSession(tester);
    final reader = await openReaderAt(tester, session);

    reader.select("184a16");
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey("sentence-detail-panel"));
    expect(panel, findsOneWidget);
    for (final heading in [
      "TEXTKRITIK",
      "ANMERKUNGEN DES HERAUSGEBERS",
      "FUSSNOTEN ZUR ÜBERSETZUNG",
      "ÜBERSETZUNG",
    ]) {
      expect(
        find.descendant(of: panel, matching: find.text(heading)),
        findsOneWidget,
      );
    }
    expect(find.textContaining("Zuordnung ungefähr"), findsOneWidget);

    await tester.tap(find.byTooltip("Lesezeichen setzen"));
    await tester.pumpAndSettle();
    expect(session.user.bookmarks.single.sentenceId, "184a16");

    // Nächster Satz im selben Abschnitt.
    await tester.tap(find.byTooltip("Nächster Satz"));
    await tester.pumpAndSettle();
    expect(reader.selectedSentence, "184a18");
    expect(
      find.descendant(of: panel, matching: find.text("FUSSNOTEN ZUR ÜBERSETZUNG")),
      findsNothing,
    );

    // Wort antippen: mögliche Bestimmung und Glossar.
    await tester.tap(
      find.descendant(of: panel, matching: find.byKey(const ValueKey("word-0"))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WordDetail), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("schmal: Satzdetail als Blatt, Begriffe aus dem Glossar", (
    tester,
  ) async {
    setSize(tester, const Size(420, 860));
    final session = await preparedSession(tester);
    final reader = await openReaderAt(tester, session);
    reader.select("184a10");
    await tester.pumpAndSettle();
    expect(find.byType(SentenceDetail), findsOneWidget);
    expect(find.byKey(const ValueKey("sentence-detail-panel")), findsNothing);
    await tester.scrollUntilVisible(
      find.text("BEGRIFFE IN DIESEM SATZ"),
      200,
      scrollable: find.descendant(
        of: find.byType(SentenceDetail),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.textContaining("archê", findRichText: true), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });
}
