import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/screens/study/study_organization_screen.dart';
import 'package:theologie_lernapp/services/timetable/course_catalog_source.dart';
import 'package:theologie_lernapp/services/timetable/timetable_controller.dart';
import 'package:theologie_lernapp/services/timetable/timetable_migration.dart';
import 'package:theologie_lernapp/services/timetable/timetable_store.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'timetable_test_support.dart';

const semestersJson = {
  "version": 1,
  "semesters": [
    {"id": "2026w", "label": "Wintersemester 2026/27"},
    {"id": "2027s", "label": "Sommersemester 2027"},
  ],
};

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {"content-type": "application/json; charset=utf-8"},
    );

void main() {
  final w = CourseCatalog.fromJson(catalogJson(asApi: true));
  final s = CourseCatalog.fromJson(catalogJson(asApi: true, semester: "2027s"));
  String id(String key, [String sem = "2026w"]) => "synthetic:$sem:$key";

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("ApiCourseCatalogSource", () {
    test(
      "lädt Semester und Katalog vom Endpunkt und speichert offline",
      () async {
        final requests = <Uri>[];
        final client = MockClient((r) async {
          requests.add(r.url);
          return r.url.queryParameters["semester"] == "2026w"
              ? jsonResponse(catalogJson(asApi: true))
              : jsonResponse(semestersJson);
        });
        final source = ApiCourseCatalogSource(
          client: client,
          baseUrl: "https://example.test",
        );
        final semesters = await source.semesters();
        expect(semesters.map((s) => s.id), ["2026w", "2027s"]);
        final load = await source.load("2026w");
        expect(load.origin, CatalogOrigin.network);
        expect(load.catalog.courses, hasLength(17));
        expect(load.updatedAt, DateTime.utc(2026, 10, 14, 6));
        expect(load.sourceStale, isFalse);
        expect(requests.map((u) => u.toString()), [
          "https://example.test/api/catalog",
          "https://example.test/api/catalog?semester=2026w",
        ]);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(CatalogOfflineCache.catalogKey("2026w")),
          isNotNull,
        );
      },
    );

    test(
      "ohne Verbindung: gespeicherter Stand mit Herkunft offlineCache",
      () async {
        final online = ApiCourseCatalogSource(
          client: MockClient(
            (r) async => jsonResponse(catalogJson(asApi: true)),
          ),
          baseUrl: "https://example.test",
        );
        await online.load("2026w");

        final offline = ApiCourseCatalogSource(
          client: MockClient(
            (r) async => throw http.ClientException("offline"),
          ),
          baseUrl: "https://example.test",
        );
        final load = await offline.load("2026w");
        expect(load.origin, CatalogOrigin.offlineCache);
        expect(load.refreshError, isA<http.ClientException>());
        expect(load.catalog.courses, hasLength(17));
        // Semesterliste offline ohne gespeicherten Stand: Fehler.
        await expectLater(
          offline.semesters(),
          throwsA(isA<http.ClientException>()),
        );
      },
    );

    test(
      "ohne Verbindung und ohne Speicher: verständlicher Fehler, keine Daten",
      () async {
        final source = ApiCourseCatalogSource(
          client: MockClient(
            (r) async => throw http.ClientException("offline"),
          ),
          baseUrl: "https://example.test",
        );
        await expectLater(
          source.load("2026w"),
          throwsA(
            isA<CatalogUnavailableException>().having(
              (e) => e.message,
              "message",
              contains("Keine Verbindung"),
            ),
          ),
        );
      },
    );

    test("Fehlerantwort des Servers wird verständlich weitergegeben", () async {
      final source = ApiCourseCatalogSource(
        client: MockClient(
          (r) async => jsonResponse({
            "error":
                "Der Veranstaltungskatalog ist derzeit nicht verfügbar. Bitte später erneut versuchen.",
            "code": "source-unavailable",
          }, 503),
        ),
        baseUrl: "https://example.test",
      );
      await expectLater(
        source.load("2026w"),
        throwsA(
          isA<CatalogUnavailableException>().having(
            (e) => e.message,
            "message",
            contains("derzeit nicht verfügbar"),
          ),
        ),
      );
    });

    test("ungültige oder unpassende Antworten werden abgelehnt", () async {
      Future<void> expectRejected(Object body) async {
        final source = ApiCourseCatalogSource(
          client: MockClient(
            (r) async =>
                body is String ? http.Response(body, 200) : jsonResponse(body),
          ),
          baseUrl: "https://example.test",
        );
        await expectLater(source.load("2026w"), throwsA(anything));
      }

      await expectRejected("<html>kein JSON</html>");
      // Synthetische Daten dürfen nie als echte erscheinen.
      await expectRejected({...catalogJson(asApi: true), "synthetic": true});
      // Falsches Semester.
      await expectRejected(catalogJson(asApi: true, semester: "2027s"));
      await expectRejected({
        "semester": {"id": "2026w"},
      });
    });

    test("Server meldet veralteten Stand", () async {
      final source = ApiCourseCatalogSource(
        client: MockClient(
          (r) async =>
              jsonResponse(catalogJson(asApi: true, cacheState: "stale")),
        ),
        baseUrl: "https://example.test",
      );
      expect((await source.load("2026w")).sourceStale, isTrue);
    });

    test("leerer Katalog ist gültig", () async {
      final empty = {
        ...catalogJson(asApi: true),
        "courses": [],
        "occurrences": [],
      };
      final source = ApiCourseCatalogSource(
        client: MockClient((r) async => jsonResponse(empty)),
        baseUrl: "https://example.test",
      );
      expect((await source.load("2026w")).catalog.courses, isEmpty);
    });

    test(
      "nicht mehr angebotene Semester werden aus dem Speicher entfernt",
      () async {
        SharedPreferences.setMockInitialValues({
          CatalogOfflineCache.catalogKey("2025w"): "{}",
          CatalogOfflineCache.catalogKey("2026w"): "{}",
          "fremder.schluessel": "bleibt",
        });
        final source = ApiCourseCatalogSource(
          client: MockClient((r) async => jsonResponse(semestersJson)),
          baseUrl: "https://example.test",
        );
        await source.semesters();
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(CatalogOfflineCache.catalogKey("2025w")),
          isNull,
        );
        expect(prefs.getString(CatalogOfflineCache.catalogKey("2026w")), "{}");
        expect(prefs.getString("fremder.schluessel"), "bleibt");
      },
    );

    test("Standardadresse außerhalb des Webs ist die Produktion", () {
      expect(
        ApiCourseCatalogSource.defaultBaseUrl(),
        "https://www.theologie.app",
      );
    });
  });

  group("Gast-Migration", () {
    Map<String, dynamic> entryMap(String key, {String sem = "2026w"}) {
      final catalog = sem == "2026w" ? w : s;
      final entry = TimetableEntry.fromCourse(
        catalog.courseById(id(key, sem))!,
      );
      return {...entry.toMap(), "addedAt": 5};
    }

    InMemoryTimetableBackend localWith(List<String> keys) {
      final local = InMemoryTimetableBackend();
      for (final k in keys) {
        local.docs[timetableDocId(id(k))] = entryMap(k);
      }
      return local;
    }

    test(
      "übernimmt alle Einträge und löscht lokal erst nach Bestätigung",
      () async {
        final local = localWith([
          "Lecture.test.at.einf",
          "Lecture.test.nt.einf",
        ]);
        final account = InMemoryTimetableBackend();
        final result = await TimetableGuestMigration(
          local: local,
          account: account,
        ).run();
        expect(
          [result.copied, result.alreadyPresent, result.removedLocally],
          [2, 0, 2],
        );
        expect(
          account.docs.keys,
          unorderedEquals(
            local.docs.keys.toList()..addAll([
              timetableDocId(id("Lecture.test.at.einf")),
              timetableDocId(id("Lecture.test.nt.einf")),
            ]),
          ),
        );
        expect(local.docs, isEmpty);
        expect(account.docs.values.first.keys, isNot(contains("email")));
      },
    );

    test("Duplikate: vorhandene Kontoeinträge bleiben unverändert", () async {
      final local = localWith(["Lecture.test.at.einf", "Lecture.test.nt.einf"]);
      final account = InMemoryTimetableBackend();
      final existingId = timetableDocId(id("Lecture.test.at.einf"));
      account.docs[existingId] = {
        ...entryMap("Lecture.test.at.einf"),
        "title": "Konto-Fassung",
      };
      final result = await TimetableGuestMigration(
        local: local,
        account: account,
      ).run();
      expect(
        [result.copied, result.alreadyPresent, result.removedLocally],
        [1, 1, 2],
      );
      expect(account.docs, hasLength(2));
      expect(account.docs[existingId]!["title"], "Konto-Fassung");
      expect(local.docs, isEmpty);
    });

    test(
      "Teilfehler: nichts wird lokal gelöscht, erneuter Lauf setzt fort",
      () async {
        final local = localWith([
          "Lecture.test.at.einf",
          "Lecture.test.nt.einf",
          "Lecture.test.kg.ue",
        ]);
        final account = InMemoryTimetableBackend()..failPutsAfter = 1;
        await expectLater(
          TimetableGuestMigration(local: local, account: account).run(),
          throwsA(isA<StateError>()),
        );
        expect(account.docs, hasLength(1));
        expect(local.docs, hasLength(3));

        account.failPutsAfter = null;
        final result = await TimetableGuestMigration(
          local: local,
          account: account,
        ).run();
        expect(
          [result.copied, result.alreadyPresent, result.removedLocally],
          [2, 1, 3],
        );
        expect(account.docs, hasLength(3));
        expect(local.docs, isEmpty);
      },
    );

    test("nicht bestätigte Einträge bleiben lokal", () async {
      final local = localWith(["Lecture.test.at.einf", "Lecture.test.nt.einf"]);
      final account = InMemoryTimetableBackend()
        ..unconfirmed.add(timetableDocId(id("Lecture.test.nt.einf")));
      final result = await TimetableGuestMigration(
        local: local,
        account: account,
      ).run();
      expect(result.removedLocally, 1);
      expect(local.docs.keys, [timetableDocId(id("Lecture.test.nt.einf"))]);
    });

    test("Lesefehler des Kontos: lokale Daten bleiben", () async {
      final local = localWith(["Lecture.test.at.einf"]);
      final account = InMemoryTimetableBackend(failReads: true);
      await expectLater(
        TimetableGuestMigration(local: local, account: account).run(),
        throwsA(isA<StateError>()),
      );
      expect(local.docs, hasLength(1));
    });

    test(
      "erneute Ausführung und gleichzeitige Läufe sind idempotent",
      () async {
        final local = localWith([
          "Lecture.test.at.einf",
          "Lecture.test.nt.einf",
        ]);
        final account = InMemoryTimetableBackend();
        final migration = TimetableGuestMigration(
          local: local,
          account: account,
        );
        final results = await Future.wait([
          migration.runOnce("u1"),
          migration.runOnce("u1"),
        ]);
        expect(identical(results[0], results[1]), isTrue);
        expect(account.puts, 2);
        final again = await migration.run();
        expect(again.nothingToDo, isTrue);
        expect(account.docs, hasLength(2));
      },
    );

    test(
      "unlesbare lokale Einträge werden weder übernommen noch gelöscht",
      () async {
        final local = localWith(["Lecture.test.at.einf"]);
        local.docs["kaputt"] = {"title": "ohne Kennung"};
        final account = InMemoryTimetableBackend();
        final result = await TimetableGuestMigration(
          local: local,
          account: account,
        ).run();
        expect([result.copied, result.invalid], [1, 1]);
        expect(local.docs.keys, ["kaputt"]);
        expect(account.docs.keys, isNot(contains("kaputt")));
      },
    );

    test("lokaler Gastspeicher als Quelle (shared_preferences)", () async {
      final store = BackendTimetableStore(LocalTimetableBackend());
      await store.add(
        TimetableEntry.fromCourse(w.courseById(id("Lecture.test.at.einf"))!),
      );
      final account = InMemoryTimetableBackend();
      final result = await TimetableGuestMigration(
        local: LocalTimetableBackend(),
        account: account,
      ).run();
      expect(result.copied, 1);
      expect(await LocalTimetableBackend().read(), isEmpty);
    });
  });

  group("Semesterwahl", () {
    test(
      "Wechsel lädt den passenden Katalog, Einträge bleiben erhalten",
      () async {
        final backend = InMemoryTimetableBackend();
        final store = BackendTimetableStore(backend);
        final source = FakeCatalogSource({"2026w": w, "2027s": s});
        final controller = TimetableController(source: source, store: store);
        await controller.start();
        await pumpEventQueue();
        expect(controller.semesterId, "2026w");
        await controller.add(w.courseById(id("Lecture.test.at.einf"))!);
        await pumpEventQueue();

        await controller.selectSemester("2027s");
        await pumpEventQueue();
        expect(controller.catalog!.semester.id, "2027s");
        expect(source.loads, ["2026w", "2027s"]);
        expect(controller.entries, hasLength(1));
        expect(controller.entriesOfSemester, isEmpty);
        expect(controller.entriesOfOtherSemesters.keys, ["2026w"]);
        expect(
          controller.stateFor(controller.entries.single),
          TimetableEntryState.otherSemester,
        );
        expect(backend.docs, hasLength(1));

        await controller.add(
          s.courseById(id("Lecture.test.nt.einf", "2027s"))!,
        );
        await pumpEventQueue();
        expect(controller.entriesOfSemester.map((e) => e.semesterId), [
          "2027s",
        ]);
        await controller.selectSemester("2026w");
        await pumpEventQueue();
        expect(controller.entriesOfSemester.map((e) => e.semesterId), [
          "2026w",
        ]);
        expect(backend.docs, hasLength(2));
        controller.dispose();
      },
    );

    test("keine Semester angeboten → Fehlerzustand", () async {
      final controller = TimetableController(
        source: FakeCatalogSource(const {}, options: const []),
        store: BackendTimetableStore(InMemoryTimetableBackend()),
      );
      await controller.start();
      expect(controller.catalog, isNull);
      expect(controller.catalogError, isA<CatalogUnavailableException>());
      controller.dispose();
    });
  });

  group("Oberfläche im Produktivbetrieb", () {
    Future<void> open(
      WidgetTester tester,
      CourseCatalogSource source, {
      InMemoryTimetableBackend? backend,
    }) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudyOrganizationScreen(
            uid: "nutzer",
            source: source,
            store: BackendTimetableStore(backend ?? InMemoryTimetableBackend()),
            today: DateTime(2026, 11, 4),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      "echte Daten: Stand und Quelle, kein Testdaten-Hinweis, Semesterwechsel",
      (tester) async {
        final backend = InMemoryTimetableBackend();
        final entry = TimetableEntry.fromCourse(
          w.courseById(id("Lecture.test.at.einf"))!,
        );
        backend.docs[timetableDocId(entry.courseId)] = entry.toMap();
        await open(
          tester,
          FakeCatalogSource({"2026w": w, "2027s": s}),
          backend: backend,
        );

        expect(find.textContaining("synthetischen Testdaten"), findsNothing);
        expect(
          find.textContaining("Quelle: UnivIS der CAU Kiel"),
          findsOneWidget,
        );
        expect(find.textContaining("Stand: 14.10.2026"), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey("semester-select")));
        await tester.pumpAndSettle();
        await tester.tap(find.text("Sommersemester 2027").last);
        await tester.pumpAndSettle();
        expect(
          find.textContaining("1 Veranstaltung im Wintersemester 2026/27"),
          findsOneWidget,
        );
        expect(backend.docs, hasLength(1));

        await tester.tap(find.text("Anzeigen"));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(RegExp(r"^10:15–11:45, Testvorlesung")),
          findsOneWidget,
        );
      },
    );

    testWidgets("offline: gespeicherter Stand mit Zeitpunkt", (tester) async {
      await open(
        tester,
        FakeCatalogSource({"2026w": w}, origin: CatalogOrigin.offlineCache),
      );
      expect(
        find.textContaining("Offline – gespeicherter Stand vom 14.10.2026"),
        findsOneWidget,
      );
    });

    testWidgets("Quelle nicht erreichbar: Server liefert alten Stand", (
      tester,
    ) async {
      await open(tester, FakeCatalogSource({"2026w": w}, stale: true));
      expect(
        find.textContaining("UnivIS ist derzeit nicht erreichbar"),
        findsOneWidget,
      );
    });

    testWidgets(
      "Ausfall ohne Daten: verständlicher Fehler, keine Veranstaltungen",
      (tester) async {
        await open(tester, FailingCatalogSource());
        expect(
          find.text("Die Veranstaltungen konnten nicht geladen werden."),
          findsOneWidget,
        );
        expect(find.textContaining("derzeit nicht verfügbar"), findsOneWidget);
        expect(find.byKey(const ValueKey("course-search-field")), findsNothing);
      },
    );

    testWidgets("leerer Katalog eines Semesters", (tester) async {
      final empty = CourseCatalog.fromJson({
        ...catalogJson(asApi: true, semester: "2027s"),
        "courses": [],
        "occurrences": [],
      });
      await open(tester, FakeCatalogSource({"2027s": empty}));
      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text("Veranstaltungen suchen"),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("empty-catalog")), findsOneWidget);
    });

    testWidgets("Aktualisieren lädt erneut", (tester) async {
      final source = FakeCatalogSource({"2026w": w});
      await open(tester, source);
      await tester.tap(find.byTooltip("Katalog aktualisieren"));
      await tester.pumpAndSettle();
      expect(source.loads, ["2026w", "2026w"]);
    });
  });
}
