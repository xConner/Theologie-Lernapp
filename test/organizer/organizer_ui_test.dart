import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/models/organizer/organizer_items.dart';
import 'package:theologie_lernapp/screens/organizer/organizer_screen.dart';
import 'package:theologie_lernapp/services/organizer/import_sources.dart';
import 'package:theologie_lernapp/services/organizer/org_dates.dart';
import 'package:theologie_lernapp/services/organizer/organizer_controller.dart';
import 'package:theologie_lernapp/services/organizer/seminar_import.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'organizer_test_support.dart';

/// Bedienung der Studiumsorganisation (siehe docs/study-organizer.md).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late MemoryOrganizerBackend backend;
  late OrganizerController c;

  Future<void> open(
    WidgetTester tester, {
    int tab = 0,
    List<ImportSource> sources = const [],
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = MemoryOrganizerBackend();
    c = OrganizerController(
      backend: backend,
      clock: TestClock(DateTime(2026, 10, 30, 12)).call,
    );
    c.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrganizerScreen(
          uid: null,
          controller: c,
          initialTab: tab,
          importSources: () async => sources,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Baum abbauen und den (von außen gereichten) Controller samt
  /// Mitternachts-Timer beenden, bevor der Test seine Timer prüft.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }

  List<Map<String, dynamic>> docsOf(String kind) => [
    for (final d in backend.docs.values)
      if (d["kind"] == kind) d,
  ];

  testWidgets("vier Bereiche mit je einem Tipp erreichbar", (tester) async {
    await open(tester);
    for (final t in ["Übersicht", "Aufgaben", "Kalender", "Notizen"]) {
      expect(find.widgetWithText(Tab, t), findsOneWidget);
    }
    expect(find.byKey(const ValueKey("quick-new-task")), findsOneWidget);
    // Standard-Zuordnungen für Studium und Privat sind angelegt.
    expect(c.area("area_bibelkunde"), isNotNull);
    expect(c.area("area_private")?.group, OrgGroup.private);
    await close(tester);
  });

  testWidgets("Aufgabe schnell anlegen und mit einem Tipp abhaken", (
    tester,
  ) async {
    await open(tester, tab: 1);
    await tester.enterText(
      find.byKey(const ValueKey("quick-task")),
      "Referat gliedern",
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text("Referat gliedern"), findsOneWidget);
    final task = c.tasks.single;
    expect(task.due, OrgDate(2026, 10, 30));

    await tester.tap(find.byKey(ValueKey("toggle-${task.id}")));
    await tester.pumpAndSettle();
    expect(c.task(task.id)!.done, isTrue);
    expect(docsOf("task").single["done"], isTrue);

    await tester.tap(find.byKey(const ValueKey("task-view-done")));
    await tester.pumpAndSettle();
    expect(find.text("Referat gliedern"), findsOneWidget);
    await close(tester);
  });

  testWidgets("Termin anlegen erscheint im Kalender", (tester) async {
    await open(tester, tab: 2);
    await tester.tap(find.byKey(const ValueKey("organizer-add")));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("event-title")),
      "Klausur Griechisch",
    );
    await tester.tap(find.byKey(const ValueKey("event-save")));
    await tester.pumpAndSettle();
    final event = c.events.single;
    expect(event.title, "Klausur Griechisch");
    expect(event.date, OrgDate(2026, 10, 30));
    expect(docsOf("event"), hasLength(1));

    for (final mode in ["month", "week", "day", "list"]) {
      await tester.tap(find.byKey(ValueKey("cal-$mode")));
      await tester.pumpAndSettle();
      expect(find.text("Klausur Griechisch"), findsWidgets, reason: mode);
    }
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets("Notiz speichert automatisch", (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey("quick-new-note")));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("note-title")),
      "Gedanken zu Cassian",
    );
    await tester.enterText(
      find.byKey(const ValueKey("note-body")),
      "- Askese\n- Gebet",
    );
    // Ohne Speichern-Knopf: nach kurzer Pause liegt die Notiz vor.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(docsOf("note").single["title"], "Gedanken zu Cassian");
    expect(docsOf("note").single["body"], "- Askese\n- Gebet");

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(c.recentNotes().single.title, "Gedanken zu Cassian");
    await close(tester);
  });

  testWidgets("Seminarplan: Vorschau, Auswahl, Übernahme ohne Duplikate", (
    tester,
  ) async {
    final source = ImportSource(
      sourceId: "test-seminar",
      title: "Proseminar Test",
      subtitle: "",
      build: (s) => ImportPlan(
        sourceId: "test-seminar",
        title: "Proseminar Test",
        areaId: "area_test",
        areaName: "Proseminar Test",
        candidates: [
          ImportCandidate(
            key: "s1",
            kind: ImportKind.event,
            title: "2. Sitzung",
            date: OrgDate(2026, 11, 5),
            typeId: "seminar",
            start: s.start,
            end: s.end,
          ),
          ImportCandidate(
            key: "s1-task",
            kind: ImportKind.task,
            title: "Lektüre: Inst. I",
            date: OrgDate(2026, 11, 5),
            eventKey: "s1",
          ),
        ],
      ),
    );
    await open(tester, sources: [source]);
    await tester.tap(find.byKey(const ValueKey("open-import")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("source-test-seminar")));
    await tester.pumpAndSettle();
    expect(find.text("Lektüre: Inst. I"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("import-apply")));
    await tester.pumpAndSettle();
    expect(c.events.single.title, "2. Sitzung");
    final task = c.tasks.single;
    expect(task.title, "Lektüre: Inst. I");
    expect(task.eventId, c.events.single.id);

    // Zweites Übernehmen: nichts Neues, nichts doppelt.
    final route = find.byKey(const ValueKey("source-test-seminar"));
    if (route.evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey("open-import")));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey("source-test-seminar")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("import-apply")));
    await tester.pumpAndSettle();
    expect(c.tasks, hasLength(1));
    expect(c.events, hasLength(1));
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
