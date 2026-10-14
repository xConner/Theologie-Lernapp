import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/screens/timetable/timetable_home_screen.dart';
import 'package:theologie_lernapp/services/timetable/course_catalog_source.dart';
import 'package:theologie_lernapp/services/timetable/timetable_feature.dart';
import 'package:theologie_lernapp/services/timetable/timetable_store.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';
import 'timetable_test_support.dart';

void main() {
  late CourseCatalog catalog;
  String id(String key) => "synthetic:2026w:$key";

  setUpAll(() async {
    catalog = await SyntheticCourseCatalogSource(bundle: FileAssetBundle()).load();
  });

  InMemoryTimetableBackend backendWith(List<String> keys) {
    final backend = InMemoryTimetableBackend();
    for (final key in keys) {
      final entry = TimetableEntry.fromCourse(catalog.courseById(id(key))!);
      backend.docs[timetableDocId(entry.courseId)] = entry.toMap();
    }
    return backend;
  }

  Future<void> open(
    WidgetTester tester, {
    InMemoryTimetableBackend? backend,
    CourseCatalogSource? source,
    Size size = const Size(420, 900),
    String? uid = "nutzer",
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TimetableHomeScreen(
          uid: uid,
          source: source ?? SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
          store: BackendTimetableStore(backend ?? InMemoryTimetableBackend()),
          today: DateTime(2026, 11, 4),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.text("Veranstaltungen"));
    await tester.pumpAndSettle();
  }

  testWidgets("Vorschau-Hinweis, leerer Stundenplan führt zur Suche", (tester) async {
    await open(tester);
    expect(find.textContaining("synthetischen Testdaten"), findsOneWidget);
    expect(find.textContaining("noch leer"), findsOneWidget);
    await tester.tap(find.text("Veranstaltungen suchen"));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("course-search-field")), findsOneWidget);
    expect(find.text("17 Veranstaltungen"), findsOneWidget);
  });

  testWidgets("Suche und Filter grenzen die Treffer ein", (tester) async {
    await open(tester);
    await openSearch(tester);

    await tester.enterText(find.byKey(const ValueKey("course-search-field")), "bibelkunde");
    await tester.pumpAndSettle();
    expect(find.text("1 Veranstaltung"), findsOneWidget);
    expect(find.textContaining("Bibelkunde Altes Testament"), findsOneWidget);

    await tester.tap(find.text("Filter zurücksetzen"));
    await tester.pumpAndSettle();
    expect(find.text("17 Veranstaltungen"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("filter-type")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Sprachkurs").last);
    await tester.pumpAndSettle();
    expect(find.text("2 Veranstaltungen"), findsOneWidget);
    expect(find.text("Testsprachkurs: Hebräisch I"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("filter-weekday")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Montag").last);
    await tester.pumpAndSettle();
    expect(find.text("1 Veranstaltung"), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey("course-search-field")), "nichts dergleichen");
    await tester.pumpAndSettle();
    expect(find.textContaining("Keine Veranstaltung passt"), findsOneWidget);
  });

  testWidgets("Hinzufügen in der Suche, Anzeige in der Woche, Entfernen", (tester) async {
    final backend = InMemoryTimetableBackend();
    await open(tester, backend: backend);
    await openSearch(tester);
    await tester.enterText(find.byKey(const ValueKey("course-search-field")), "Einführung in das Neue");
    await tester.pumpAndSettle();

    final toggle = find.byKey(ValueKey("toggle-${id("Lecture.test.nt.einf")}"));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text("Zum Stundenplan hinzugefügt."), findsOneWidget);
    expect(backend.docs.values.single["courseId"], id("Lecture.test.nt.einf"));
    expect(tester.widget<IconButton>(toggle).isSelected, isTrue);

    await tester.tap(find.text("Mein Stundenplan"));
    await tester.pumpAndSettle();
    expect(find.text("Woche 2.11.–8.11.2026"), findsOneWidget);
    expect(find.text("10:15–11:45"), findsOneWidget);
    expect(find.text("Test-HS 1"), findsOneWidget);

    await tester.tap(find.byTooltip("Nächste Woche"));
    await tester.pumpAndSettle();
    expect(find.text("Woche 9.11.–15.11.2026"), findsOneWidget);

    await openSearch(tester);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text("Aus dem Stundenplan entfernt."), findsOneWidget);
    expect(backend.docs, isEmpty);
  });

  testWidgets("Überschneidungen sind in der Woche erkennbar, Anschluss nicht", (tester) async {
    await open(
      tester,
      backend: backendWith([
        "Lecture.test.nt.einf",
        "Lecture.test.nt.gr",
        "Lecture.test.kg.einf",
        "Lecture.test.kg.ue",
      ]),
    );
    expect(find.text("2 Termine in dieser Woche überschneiden sich."), findsOneWidget);
    expect(find.textContaining("Überschneidung mit"), findsNWidgets(2));
    // Mi 8:30–10:00 und 10:00–11:30: keine Überschneidung.
    expect(
      find.bySemanticsLabel(RegExp(r"^08:30–10:00, Testvorlesung: Kirchengeschichte.*Überschneidung")),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp(r"^10:15–11:45, .*Überschneidung mit Testkurs: Griechische Lektüre")),
      findsOneWidget,
    );
  });

  testWidgets("Ausfall und unterrichtsfreie Zeit werden angezeigt", (tester) async {
    await open(tester, backend: backendWith(["Lecture.test.at.einf"]));
    await tester.tap(find.byTooltip("Nächste Woche"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Nächste Woche"));
    await tester.pumpAndSettle();
    expect(find.text("Woche 16.11.–22.11.2026"), findsOneWidget);
    expect(find.text("fällt aus"), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip("Nächste Woche"));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining("unterrichtsfrei"), findsOneWidget);
    await tester.tap(find.text("Heute"));
    await tester.pumpAndSettle();
    expect(find.text("Woche 2.11.–8.11.2026"), findsOneWidget);
  });

  testWidgets("Detailseite: Angaben, Konflikthinweis, Hinzufügen und Entfernen", (tester) async {
    final backend = backendWith(["Lecture.test.nt.einf"]);
    await open(tester, backend: backend);
    await openSearch(tester);
    await tester.enterText(find.byKey(const ValueKey("course-search-field")), "Lektüre");
    await tester.pumpAndSettle();
    await tester.tap(find.text("Testkurs: Griechische Lektüre zum Neuen Testament"));
    await tester.pumpAndSettle();

    expect(find.text("Dozent"), findsOneWidget);
    expect(find.text("Dr. Jonas Muster"), findsOneWidget);
    expect(find.text("Ort"), findsOneWidget);
    expect(find.text("Test-SR 3"), findsOneWidget);
    expect(find.text("Übung"), findsOneWidget);
    expect(find.textContaining("wöchentlich Di 11:00–12:30"), findsOneWidget);
    expect(find.textContaining("Überschneidet sich mit deinem Stundenplan: Testvorlesung"), findsOneWidget);
    await tester.scrollUntilVisible(find.text("Nächste Termine"), 200);
    // Ab „heute“ (Mi 4.11.2026): nächster Termin Di 10.11.
    expect(find.textContaining("Di 10.11.2026 · 11:00–12:30"), findsOneWidget);
    expect(find.textContaining("Di 3.11.2026"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("detail-toggle")));
    await tester.pumpAndSettle();
    expect(find.text("Aus dem Stundenplan entfernen"), findsOneWidget);
    expect(backend.docs, hasLength(2));

    await tester.tap(find.byKey(const ValueKey("detail-toggle")));
    await tester.pumpAndSettle();
    expect(find.text("Zum Stundenplan hinzufügen"), findsOneWidget);
    expect(backend.docs, hasLength(1));
  });

  testWidgets("Speicherfehler wird gemeldet, Stundenplan bleibt unverändert", (tester) async {
    final backend = InMemoryTimetableBackend(failWrites: true);
    await open(tester, backend: backend);
    await openSearch(tester);
    final toggle = find.byKey(ValueKey("toggle-${id("Lecture.test.at.einf")}"));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining("konnte nicht gespeichert werden"), findsOneWidget);
    expect(backend.docs, isEmpty);
  });

  testWidgets("Ladefehler des Katalogs mit erneutem Versuch", (tester) async {
    final source = FailingCatalogSource(
      recoverWith: SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
    );
    await open(tester, source: source);
    expect(find.textContaining("konnten nicht geladen werden"), findsOneWidget);
    await tester.tap(find.text("Erneut versuchen"));
    await tester.pumpAndSettle();
    expect(find.textContaining("synthetischen Testdaten"), findsOneWidget);
  });

  testWidgets("Gastmodus weist auf lokale Speicherung hin", (tester) async {
    await open(tester, uid: null);
    expect(find.textContaining("nur auf diesem Gerät gespeichert"), findsOneWidget);
  });

  testWidgets("kleiner Bildschirm (320 px) und große Schrift ohne Überlauf", (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(
      tester,
      size: const Size(320, 640),
      backend: backendWith(["Lecture.test.nt.einf", "Lecture.test.nt.gr", "Lecture.test.pt.exk"]),
    );
    expect(tester.takeException(), isNull);
    await openSearch(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("Testvorlesung: Dogmatik – Schöpfung und Erlösung (TEST-ST2-V)"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("breiter Bildschirm: Wochentage nebeneinander", (tester) async {
    await open(tester, size: const Size(1280, 900), backend: backendWith(["Lecture.test.at.einf"]));
    final monday = tester.getTopLeft(find.text("Montag, 2.11."));
    final tuesday = tester.getTopLeft(find.text("Dienstag, 3.11."));
    expect(monday.dy, tuesday.dy);
    expect(tuesday.dx, greaterThan(monday.dx));
  });

  test("Vorschau ist in Entwicklungs-Builds (Tests) sichtbar", () {
    expect(timetablePreviewEnabled, isTrue);
  });
}
