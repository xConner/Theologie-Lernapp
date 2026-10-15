import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/screens/study/study_organization_screen.dart';
import 'package:theologie_lernapp/screens/timetable/timetable_week_view.dart';
import 'package:theologie_lernapp/services/timetable/course_catalog_source.dart';
import 'package:theologie_lernapp/services/timetable/timetable_controller.dart';
import 'package:theologie_lernapp/services/timetable/timetable_feature.dart';
import 'package:theologie_lernapp/services/timetable/timetable_store.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';
import 'timetable_test_support.dart';

void main() {
  late CourseCatalog catalog;
  String id(String key) => "synthetic:2026w:$key";

  setUpAll(() async {
    catalog = (await SyntheticCourseCatalogSource(
      bundle: FileAssetBundle(),
    ).load("2026w")).catalog;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    int tab = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StudyOrganizationScreen(
          uid: uid,
          source:
              source ?? SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
          store: BackendTimetableStore(backend ?? InMemoryTimetableBackend()),
          today: DateTime(2026, 11, 4),
          documentsBundle: FileAssetBundle(),
          initialTab: tab,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tab(String label) =>
      find.descendant(of: find.byType(TabBar), matching: find.text(label));

  Future<void> showTab(WidgetTester tester, String label) async {
    await tester.ensureVisible(tab(label));
    await tester.pumpAndSettle();
    await tester.tap(tab(label));
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.ensureVisible(tab("Veranstaltungen suchen"));
    await tester.pumpAndSettle();
    await tester.tap(tab("Veranstaltungen suchen"));
    await tester.pumpAndSettle();
  }

  Future<void> openPlan(WidgetTester tester) async {
    await tester.ensureVisible(tab("Stundenplan"));
    await tester.pumpAndSettle();
    await tester.tap(tab("Stundenplan"));
    await tester.pumpAndSettle();
  }

  Finder block(RegExp label) => find.bySemanticsLabel(label);

  testWidgets("Druck/PDF-Export nur im Stundenplan-Reiter", (tester) async {
    await open(tester);
    final button = find.byKey(const ValueKey("timetable-export"));
    expect(button, findsOneWidget);
    expect(find.byTooltip("Drucken / als PDF exportieren"), findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    await tester.tap(tab("Veranstaltungen suchen"));
    await tester.pumpAndSettle();
    expect(button, findsNothing);
  });

  testWidgets("drei Bereiche; leerer Stundenplan führt zur Suche", (
    tester,
  ) async {
    await open(tester);
    expect(find.text("Studiumsorganisation"), findsOneWidget);
    expect(tab("Stundenplan"), findsOneWidget);
    expect(tab("Veranstaltungen suchen"), findsOneWidget);
    expect(tab("Studienunterlagen"), findsOneWidget);
    expect(find.textContaining("synthetischen Testdaten"), findsOneWidget);
    expect(find.textContaining("noch leer"), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, "Veranstaltungen suchen"),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("course-search-field")), findsOneWidget);
    expect(find.text("17 Veranstaltungen"), findsOneWidget);
  });

  testWidgets(
    "Suche und Filter im Fakultätsverzeichnis grenzen die Treffer ein",
    (tester) async {
      await open(tester, tab: 1);

      await tester.enterText(
        find.byKey(const ValueKey("course-search-field")),
        "bibelkunde",
      );
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

      await tester.tap(find.byKey(const ValueKey("filter-weekday")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Montag").last);
      await tester.pumpAndSettle();
      expect(find.text("1 Veranstaltung"), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey("course-search-field")),
        "nichts dergleichen",
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("Keine Veranstaltung passt"), findsOneWidget);
    },
  );

  testWidgets("Hinzufügen mit Vorschau, Block im Wochenraster, Entfernen", (
    tester,
  ) async {
    final backend = InMemoryTimetableBackend();
    await open(tester, backend: backend, tab: 1);
    await tester.enterText(
      find.byKey(const ValueKey("course-search-field")),
      "Einführung in das Neue",
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(ValueKey("toggle-${id("Lecture.test.nt.einf")}"));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    // Vorschau mit den übernommenen Angaben.
    expect(find.text("Vorschau und Korrektur"), findsOneWidget);
    expect(find.text("Übernommen aus UnivIS"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("editor-save")));
    await tester.pumpAndSettle();
    expect(find.text("Zum Stundenplan hinzugefügt."), findsOneWidget);
    final stored = backend.docs.values.single;
    expect(stored["courseId"], id("Lecture.test.nt.einf"));
    expect(stored["snapshot"], isA<Map>());
    expect(stored.containsKey("overrides"), isFalse);
    expect(tester.widget<IconButton>(toggle).isSelected, isTrue);

    await openPlan(tester);
    expect(find.text("Woche 2.11.–8.11.2026"), findsOneWidget);
    expect(find.text("Di 3.11."), findsOneWidget);
    expect(
      block(
        RegExp(
          r"^10:15–11:45, Testvorlesung: Einführung in das Neue Testament.*Test-HS 1",
        ),
      ),
      findsOneWidget,
    );
    expect(find.text("08:00"), findsOneWidget);

    await tester.tap(block(RegExp(r"^10:15–11:45, Testvorlesung: Einführung")));
    await tester.pumpAndSettle();
    expect(find.text("1 Std. 30 Min."), findsOneWidget);
    await tester.tap(find.text("Alle Angaben"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("detail-toggle")));
    await tester.pumpAndSettle();
    expect(find.text("Aus dem Stundenplan entfernt."), findsOneWidget);
    expect(backend.docs, isEmpty);
  });

  testWidgets(
    "Überschneidungen: Stellen statt Termine, antippen zeigt Details",
    (tester) async {
      await open(
        tester,
        backend: backendWith([
          "Lecture.test.nt.einf",
          "Lecture.test.nt.gr",
          "Lecture.test.kg.einf",
          "Lecture.test.kg.ue",
        ]),
      );
      // Di 10:15–11:45 und 11:00–12:30 überschneiden sich; Mi 8:30–10:00 und
      // 10:00–11:30 schließen nur an.
      expect(
        find.text(
          "1 Überschneidung in dieser Woche – 2 Veranstaltungen betroffen",
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          "Im ganzen Semester: 1 Überschneidungsstelle (16 Termine)",
        ),
        findsOneWidget,
      );
      expect(block(RegExp(r"^10:15–11:45, .*Überschneidung$")), findsOneWidget);
      expect(
        block(
          RegExp(
            r"^08:30–10:00, Testvorlesung: Kirchengeschichte.*Überschneidung",
          ),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey("week-conflicts")));
      await tester.pumpAndSettle();
      expect(
        find.text("Dienstag, 11:00–11:45 · 45 Min. gleichzeitig"),
        findsOneWidget,
      );
      expect(find.text("am 3.11.2026"), findsOneWidget);
      expect(
        find.textContaining("10:15–11:45 (1 Std. 30 Min.)"),
        findsOneWidget,
      );
      expect(
        find.textContaining("11:00–12:30 (1 Std. 30 Min.)"),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.text("Überschneidungen in dieser Woche")),
      ).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("semester-conflicts")));
      await tester.pumpAndSettle();
      expect(find.textContaining("an 16 Terminen"), findsOneWidget);
    },
  );

  testWidgets("gleichzeitige Termine liegen nebeneinander im Raster", (
    tester,
  ) async {
    await open(
      tester,
      backend: backendWith(["Lecture.test.nt.einf", "Lecture.test.nt.gr"]),
    );
    final a = tester.getRect(block(RegExp(r"^10:15–11:45")));
    final b = tester.getRect(block(RegExp(r"^11:00–12:30")));
    expect(a.overlaps(b), isFalse);
    expect(b.left, greaterThan(a.left));
    expect(b.top, greaterThan(a.top));
  });

  testWidgets(
    "Filter Block-/regelmäßige Veranstaltungen, gemerkt auf dem Gerät",
    (tester) async {
      await open(
        tester,
        backend: backendWith(["Lecture.test.at.einf", "Lecture.test.pt.exk"]),
      );
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip("Nächste Woche"));
        await tester.pumpAndSettle();
      }
      expect(find.text("Woche 25.1.–31.1.2027"), findsOneWidget);
      final exkursion = block(
        RegExp(r"Testexkursion.*Block- bzw. Einzeltermin"),
      );
      final weekly = block(
        RegExp(
          r"^10:15–11:45, Testvorlesung: Einführung in das Alte Testament",
        ),
      );
      expect(exkursion, findsWidgets);
      expect(weekly, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("kind-filter-regular")));
      await tester.pumpAndSettle();
      expect(exkursion, findsNothing);
      expect(weekly, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("kind-filter-special")));
      await tester.pumpAndSettle();
      expect(exkursion, findsWidgets);
      expect(weekly, findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(TimetableController.filterKey), "special");
    },
  );

  testWidgets("Ausfall und unterrichtsfreie Zeit werden angezeigt", (
    tester,
  ) async {
    await open(tester, backend: backendWith(["Lecture.test.at.einf"]));
    await tester.tap(find.byTooltip("Nächste Woche"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Nächste Woche"));
    await tester.pumpAndSettle();
    expect(find.text("Woche 16.11.–22.11.2026"), findsOneWidget);
    expect(block(RegExp(r"fällt aus")), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip("Nächste Woche"));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining("unterrichtsfrei"), findsOneWidget);
    final weekList = find
        .descendant(
          of: find.byKey(const ValueKey("week-list")),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey("week-empty")),
      300,
      scrollable: weekList,
    );
    expect(find.byKey(const ValueKey("week-empty")), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("Heute"),
      -300,
      scrollable: weekList,
    );
    await tester.tap(find.text("Heute"));
    await tester.pumpAndSettle();
    expect(find.text("Woche 2.11.–8.11.2026"), findsOneWidget);
  });

  testWidgets("Detailseite: Angaben, Konflikthinweis, Hinzufügen und Entfernen", (
    tester,
  ) async {
    final backend = backendWith(["Lecture.test.nt.einf"]);
    await open(tester, backend: backend, tab: 1);
    await tester.enterText(
      find.byKey(const ValueKey("course-search-field")),
      "Lektüre",
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text("Testkurs: Griechische Lektüre zum Neuen Testament"),
    );
    await tester.pumpAndSettle();

    expect(find.text("Dozent"), findsOneWidget);
    expect(find.text("Dr. Jonas Muster"), findsOneWidget);
    expect(find.text("Ort"), findsOneWidget);
    expect(find.text("Test-SR 3"), findsOneWidget);
    expect(find.text("Übung"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining("wöchentlich Di 11:00–12:30"),
      200,
    );
    expect(find.textContaining("wöchentlich Di 11:00–12:30"), findsOneWidget);
    expect(
      find.textContaining(
        "1 Überschneidungsstelle mit Testvorlesung: Einführung in das Neue Testament",
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text("Nächste Termine"), 200);
    // Ab „heute“ (Mi 4.11.2026): nächster Termin Di 10.11.
    expect(find.textContaining("Di 10.11.2026 · 11:00–12:30"), findsOneWidget);
    expect(find.textContaining("Di 3.11.2026"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("detail-toggle")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("editor-save")));
    await tester.pumpAndSettle();
    expect(find.text("Aus dem Stundenplan entfernen"), findsOneWidget);
    expect(backend.docs, hasLength(2));

    await tester.tap(find.byKey(const ValueKey("detail-toggle")));
    await tester.pumpAndSettle();
    expect(find.text("Zum Stundenplan hinzufügen"), findsOneWidget);
    expect(backend.docs, hasLength(1));
  });

  testWidgets(
    "Korrektur vor dem Speichern: getrennt gespeichert, im Raster sichtbar",
    (tester) async {
      final backend = InMemoryTimetableBackend();
      await open(tester, backend: backend, tab: 1);
      await tester.enterText(
        find.byKey(const ValueKey("course-search-field")),
        "Einführung in das Neue",
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey("toggle-${id("Lecture.test.nt.einf")}")),
      );
      await tester.pumpAndSettle();

      final rule = find.byKey(const ValueKey("rule-0"));
      await tester.enterText(
        find.descendant(
          of: rule,
          matching: find.widgetWithText(TextFormField, "Beginn"),
        ),
        "12:15",
      );
      await tester.enterText(
        find.descendant(
          of: rule,
          matching: find.widgetWithText(TextFormField, "Ende"),
        ),
        "13:45",
      );
      await tester.enterText(
        find.descendant(
          of: rule,
          matching: find.widgetWithText(TextFormField, "Raum"),
        ),
        "Ausweichraum 7",
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("editor-save")));
      await tester.pumpAndSettle();

      final stored = TimetableEntry.tryFromMap(backend.docs.values.single)!;
      final ruleId = stored.snapshot!.rules.single.id;
      expect(stored.overrides.rules[ruleId]!.startTime, "12:15");
      expect(stored.overrides.rules[ruleId]!.room, "Ausweichraum 7");
      // Importierte Daten unverändert.
      expect(stored.snapshot!.rules.single.rule.startTime, "10:15");

      await openPlan(tester);
      expect(
        block(
          RegExp(
            r"^12:15–13:45, Testvorlesung: Einführung in das Neue Testament.*, Ausweichraum 7",
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets("ungültige Uhrzeit wird vor dem Speichern abgefangen", (
    tester,
  ) async {
    final backend = InMemoryTimetableBackend();
    await open(tester, backend: backend, tab: 1);
    await tester.ensureVisible(
      find.byKey(ValueKey("toggle-${id("Lecture.test.at.einf")}")),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey("toggle-${id("Lecture.test.at.einf")}")),
    );
    await tester.pumpAndSettle();
    final rule = find.byKey(const ValueKey("rule-0"));
    await tester.enterText(
      find.descendant(
        of: rule,
        matching: find.widgetWithText(TextFormField, "Ende"),
      ),
      "25:99",
    );
    await tester.tap(find.byKey(const ValueKey("editor-save")));
    await tester.pumpAndSettle();
    expect(find.text("Format HH:MM, z. B. 10:15"), findsOneWidget);
    expect(backend.docs, isEmpty);
  });

  testWidgets(
    "UnivIS-Suche über Fakultäten: Treffer ergänzen, hinzufügen, offline erhalten",
    (tester) async {
      final backend = InMemoryTimetableBackend();
      final source = SearchingCatalogSource(
        SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
      );
      await open(tester, backend: backend, source: source, tab: 1);

      await tester.tap(find.byKey(const ValueKey("search-scope")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Philosophische Fakultät").last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey("course-search-field")),
        "Et",
      );
      await tester.tap(find.byKey(const ValueKey("remote-search-button")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("search-validation")), findsOneWidget);
      expect(source.searches, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey("course-search-field")),
        "Ethik",
      );
      await tester.tap(find.byKey(const ValueKey("remote-search-button")));
      await tester.pumpAndSettle();
      expect(source.searches.single, {
        "text": "Ethik",
        "number": null,
        "faculty": "050000000",
      });
      expect(find.text("Testseminar: Einführung in die Ethik"), findsOneWidget);
      expect(
        find.textContaining(
          "Philosophische Fakultät · Testseminar Philosophie",
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey("toggle-cau-univis:2026w:Lecture.phil.test.ethik"),
        ),
      );
      await tester.pumpAndSettle();
      // Fehlende Uhrzeit der Quelle wird angezeigt und kann ergänzt werden.
      expect(
        find.textContaining("fehlt in der Quelle die Uhrzeit"),
        findsOneWidget,
      );
      final second = find.byKey(const ValueKey("rule-1"));
      await tester.scrollUntilVisible(
        second,
        200,
        scrollable: find
            .ancestor(
              of: find.byKey(const ValueKey("edit-title")),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.enterText(
        find.descendant(
          of: second,
          matching: find.widgetWithText(TextFormField, "Beginn"),
        ),
        "16:15",
      );
      await tester.enterText(
        find.descendant(
          of: second,
          matching: find.widgetWithText(TextFormField, "Ende"),
        ),
        "17:45",
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("editor-save")));
      await tester.pumpAndSettle();

      final stored = TimetableEntry.tryFromMap(backend.docs.values.single)!;
      expect(stored.snapshot!.faculty, "Philosophische Fakultät");
      expect(stored.snapshot!.fromFacultyCatalog, isFalse);
      expect(stored.overrides.rules["phil-r2"]!.startTime, "16:15");

      // Kein doppelter Eintrag: erneut als „bereits geplant“ markiert.
      final toggle = find.byKey(
        const ValueKey("toggle-cau-univis:2026w:Lecture.phil.test.ethik"),
      );
      expect(tester.widget<IconButton>(toggle).isSelected, isTrue);

      await openPlan(tester);
      expect(
        block(
          RegExp(
            r"^11:15–12:45, Testseminar: Einführung in die Ethik, Test-PH 1, Dr\. Test Philosoph",
          ),
        ),
        findsOneWidget,
      );
      expect(
        block(RegExp(r"^16:15–17:45, Testseminar: Einführung in die Ethik")),
        findsOneWidget,
      );

      // Suche fällt aus: verständliche Meldung, gespeicherte Veranstaltung bleibt.
      source.failWith = const CatalogUnavailableException(
        "Die Suche in UnivIS ist derzeit nicht verfügbar.",
      );
      await openSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey("course-search-field")),
        "Logik",
      );
      await tester.tap(find.byKey(const ValueKey("remote-search-button")));
      await tester.pumpAndSettle();
      expect(
        find.text("Die Suche in UnivIS ist derzeit nicht verfügbar."),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          "gespeicherten Veranstaltungen sind davon nicht betroffen",
        ),
        findsOneWidget,
      );
      expect(backend.docs, hasLength(1));
    },
  );

  testWidgets("Speicherfehler wird gemeldet, Stundenplan bleibt unverändert", (
    tester,
  ) async {
    final backend = InMemoryTimetableBackend(failWrites: true);
    await open(tester, backend: backend, tab: 1);
    final toggle = find.byKey(ValueKey("toggle-${id("Lecture.test.at.einf")}"));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("editor-save")));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("konnte nicht gespeichert werden"),
      findsOneWidget,
    );
    expect(backend.docs, isEmpty);
  });

  testWidgets(
    "Ladefehler des Katalogs mit erneutem Versuch; Unterlagen bleiben nutzbar",
    (tester) async {
      final source = FailingCatalogSource(
        recoverWith: SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
      );
      await open(tester, source: source);
      expect(
        find.textContaining("konnten nicht geladen werden"),
        findsOneWidget,
      );
      await showTab(tester, "Studienunterlagen");
      await tester.scrollUntilVisible(
        find.text("Prüfungen und Ordnungen"),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey("documents-list")),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text("Prüfungen und Ordnungen"), findsOneWidget);
      await openPlan(tester);
      await tester.tap(find.text("Erneut versuchen"));
      await tester.pumpAndSettle();
      expect(find.textContaining("synthetischen Testdaten"), findsOneWidget);
    },
  );

  testWidgets("Gastmodus weist auf lokale Speicherung hin", (tester) async {
    await open(tester, uid: null);
    expect(
      find.textContaining("nur auf diesem Gerät gespeichert"),
      findsOneWidget,
    );
  });

  testWidgets("Studienunterlagen: Gruppen, Studiengang, ältere Fassungen", (
    tester,
  ) async {
    await open(tester, tab: 2);
    final list = find
        .descendant(
          of: find.byKey(const ValueKey("documents-list")),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(find.text("Studienstruktur"), findsOneWidget);
    expect(
      find.byKey(const ValueKey("document-dka-modulhandbuch-2023")),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey("program-lehramt")));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey("document-dka-modulhandbuch-2023")),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey("document-lehramt-modulhandbuch-ba-2023")),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey("include-older")));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey("document-lehramt-modulhandbuch-ba-2018")),
      300,
      scrollable: list,
    );
    expect(find.text("Ältere Fassung"), findsWidgets);
    // Übergreifende Ordnungen der CAU gehören zum Lehramt dazu.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey("document-pvo-2019")),
      300,
      scrollable: list,
    );
    expect(find.byKey(const ValueKey("document-pvo-2019")), findsOneWidget);
  });

  testWidgets("kleiner Bildschirm (320 px) und große Schrift ohne Überlauf", (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(
      tester,
      size: const Size(320, 640),
      backend: backendWith([
        "Lecture.test.nt.einf",
        "Lecture.test.nt.gr",
        "Lecture.test.pt.exk",
      ]),
    );
    expect(tester.takeException(), isNull);
    // Das Raster ist waagerecht scrollbar.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey("week-grid-scroll")),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey("week-list")),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey("week-grid-scroll")), findsOneWidget);
    await tester.ensureVisible(block(RegExp(r"^10:15–11:45")).first);
    await tester.pumpAndSettle();
    await tester.tap(block(RegExp(r"^10:15–11:45")).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text("Alle Angaben"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Alle Angaben"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text("Veranstaltung"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("detail-edit")));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openSearch(tester);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey("course-search-field")),
      "Dogmatik",
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dogmatik = find.text(
      "Testvorlesung: Dogmatik – Schöpfung und Erlösung (TEST-ST2-V)",
    );
    await tester.scrollUntilVisible(
      dogmatik,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey("search-list")),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(dogmatik);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await showTab(tester, "Studienunterlagen");
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "breiter Bildschirm: Wochentage nebeneinander, ohne Querscrollen",
    (tester) async {
      await open(
        tester,
        size: const Size(1280, 900),
        backend: backendWith(["Lecture.test.at.einf"]),
      );
      final monday = tester.getTopLeft(find.text("Mo 2.11."));
      final tuesday = tester.getTopLeft(find.text("Di 3.11."));
      expect(monday.dy, tuesday.dy);
      expect(tuesday.dx, greaterThan(monday.dx));
      expect(find.byKey(const ValueKey("week-grid-scroll")), findsNothing);
      // Der Platz wird genutzt: fünf Spalten über die volle Breite.
      final friday = tester.getTopLeft(find.text("Fr 6.11."));
      expect(friday.dx, greaterThan(900));
    },
  );

  testWidgets("Startbildschirm: ein Knopf führt direkt zum Stundenplan", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: StudyOrganizationButton(uid: null)),
      ),
    );
    expect(find.text("Studiumsorganisation"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("open-study-organization")));
    // Echte Quelle ohne Netz (Testumgebung): Fehlerzustand statt Absturz.
    await tester.pumpAndSettle();
    expect(find.byType(StudyOrganizationScreen), findsOneWidget);
    expect(tab("Stundenplan"), findsOneWidget);
    expect(find.byType(TimetableWeekView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    "ohne ausdrücklichen Entwicklungsmodus: echte Quelle, nie synthetisch",
    () {
      expect(timetableSyntheticMode, isFalse);
      expect(defaultCourseCatalogSource(), isA<ApiCourseCatalogSource>());
    },
  );
}
