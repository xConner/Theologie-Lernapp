import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/course_snapshot.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/services/study/study_documents.dart';
import 'package:theologie_lernapp/services/timetable/course_catalog_source.dart';
import 'package:theologie_lernapp/services/timetable/timetable_controller.dart';
import 'package:theologie_lernapp/services/timetable/timetable_store.dart';

import 'test_asset_bundle.dart';
import 'timetable_test_support.dart';

/// Backend, das wie Firestore mit den alten Regeln (Version 1) Einträge mit
/// den neuen Feldern ablehnt.
class OldRulesBackend extends InMemoryTimetableBackend {
  @override
  Future<void> put(String id, Map<String, dynamic> data) async {
    if (data.containsKey("snapshot") || data.containsKey("overrides")) {
      throw const TimetablePermissionDenied();
    }
    return super.put(id, data);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Suche über /api/catalog", () {
    test(
      "Anfrage mit Suchtext, Fakultät und Semester; Ergebnis mit Einordnung",
      () async {
        final requests = <Uri>[];
        final source = ApiCourseCatalogSource(
          baseUrl: "https://www.theologie.app",
          client: MockClient((r) async {
            requests.add(r.url);
            return http.Response(
              jsonEncode({
                ...foreignSearchJson(),
                "search": {"total": 140, "returned": 100, "truncated": true},
                "cache": {
                  "state": "stale",
                  "fetchedAt": "2026-10-13T06:00:00.000Z",
                },
              }),
              200,
              headers: {"content-type": "application/json; charset=utf-8"},
            );
          }),
        );
        final result = await source.search(
          semesterId: "2026w",
          text: "Ethik",
          facultyId: "050000000",
        );
        expect(requests.single.path, "/api/catalog");
        expect(requests.single.queryParameters, {
          "semester": "2026w",
          "q": "Ethik",
          "faculty": "050000000",
        });
        expect(result.total, 140);
        expect(result.truncated, isTrue);
        expect(result.stale, isTrue);
        expect(result.fetchedAt, DateTime.utc(2026, 10, 13, 6));
        final course = result.catalog.courses.single;
        expect(course.faculty, "Philosophische Fakultät");
        expect(course.institute, "Testseminar Philosophie");

        // Gleiche Suche in derselben Sitzung: kein erneuter Abruf.
        await source.search(
          semesterId: "2026w",
          text: "Ethik",
          facultyId: "050000000",
        );
        expect(requests, hasLength(1));

        await source.search(semesterId: "2026w", number: "050999");
        expect(requests.last.queryParameters, {
          "semester": "2026w",
          "number": "050999",
        });
      },
    );

    test(
      "Fehler des Servers als verständliche Meldung, synthetische Daten abgelehnt",
      () async {
        ApiCourseCatalogSource answering(int status, Object body) =>
            ApiCourseCatalogSource(
              baseUrl: "https://www.theologie.app",
              client: MockClient(
                (_) async =>
                    http.Response.bytes(utf8.encode(jsonEncode(body)), status),
              ),
            );
        await expectLater(
          answering(422, {
            "error": "Zu viele Treffer – bitte den Suchbegriff genauer fassen.",
            "code": "too-many-results",
          }).search(semesterId: "2026w", text: "Einf"),
          throwsA(
            isA<CatalogUnavailableException>().having(
              (e) => e.message,
              "message",
              contains("Zu viele Treffer"),
            ),
          ),
        );
        await expectLater(
          answering(503, {
            "error": "Die Suche in UnivIS ist derzeit nicht verfügbar.",
            "code": "source-unavailable",
          }).search(semesterId: "2026w", text: "Ethik"),
          throwsA(isA<CatalogUnavailableException>()),
        );
        await expectLater(
          answering(200, {
            ...foreignSearchJson(),
            "synthetic": true,
          }).search(semesterId: "2026w", text: "Ethik"),
          throwsA(isA<CatalogFormatException>()),
        );
        final offline = ApiCourseCatalogSource(
          baseUrl: "https://www.theologie.app",
          client: MockClient(
            (_) async => throw http.ClientException("offline"),
          ),
        );
        await expectLater(
          offline.search(semesterId: "2026w", text: "Ethik"),
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

    test("Fakultäten aus der Semesterliste", () async {
      final source = ApiCourseCatalogSource(
        baseUrl: "https://www.theologie.app",
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                "semesters": [
                  {"id": "2026w", "label": "Wintersemester 2026/27"},
                ],
                "faculties": [
                  {"id": "010000000", "name": "Theologische Fakultät"},
                  {"id": "050000000", "name": "Philosophische Fakultät"},
                ],
              }),
            ),
            200,
          ),
        ),
      );
      final faculties = await source.faculties();
      expect([for (final f in faculties) f.id], ["010000000", "050000000"]);
    });
  });

  group("Hinzufügen, Duplikate, Abgleich", () {
    Future<TimetableController> controllerWith(
      TimetableBackend backend, {
      CourseCatalogSource? source,
    }) async {
      final controller = TimetableController(
        source:
            source ??
            SearchingCatalogSource(
              SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
            ),
        store: BackendTimetableStore(backend),
      );
      await controller.start();
      await pumpEventQueue();
      return controller;
    }

    CourseSnapshot foreign() {
      final catalog = CourseCatalog.fromJson(foreignSearchJson());
      return CourseSnapshot.fromCatalog(catalog, catalog.courses.single);
    }

    test(
      "dieselbe Veranstaltung über eine andere Kennung: kein zweiter Eintrag",
      () async {
        final backend = InMemoryTimetableBackend();
        final controller = await controllerWith(backend);
        final first = foreign();
        await controller.addSnapshot(first);
        await pumpEventQueue();
        // Dieselbe Quellkennung, aber anders zusammengeführt (andere Kennung).
        final again = CourseSnapshot(
          courseId: "cau-univis:2026w:Lecture.phil.anders",
          semesterId: "2026w",
          sources: const [SourceRef("cau-univis", "Lecture.phil.test.ethik")],
          title: first.title,
          rules: first.rules,
          occurrences: first.occurrences,
          semester: first.semester,
        );
        expect(controller.isPlanned(again.courseId, again.sources), isTrue);
        await controller.addSnapshot(again);
        await pumpEventQueue();
        expect(backend.docs, hasLength(1));
        expect(controller.entries.single.courseId, first.courseId);
        controller.dispose();
      },
    );

    test("erneutes Hinzufügen behält persönliche Anpassungen", () async {
      final backend = InMemoryTimetableBackend();
      final controller = await controllerWith(backend);
      await controller.addSnapshot(
        foreign(),
        overrides: const EntryOverrides(title: "Eigener Titel"),
      );
      await pumpEventQueue();
      await controller.addSnapshot(foreign());
      await pumpEventQueue();
      expect(controller.entries.single.overrides.title, "Eigener Titel");
      controller.dispose();
    });

    test(
      "alte Firestore-Regeln: Fakultätskatalog in alter Form, Suche mit Fehler",
      () async {
        final backend = OldRulesBackend();
        final controller = await controllerWith(backend);
        final course = controller.catalog!.courseById(
          "synthetic:2026w:Lecture.test.at.einf",
        )!;
        await controller.add(course);
        await pumpEventQueue();
        expect(backend.docs.values.single.containsKey("snapshot"), isFalse);
        expect(controller.plan.single.occurrences, isNotEmpty);

        await expectLater(
          controller.addSnapshot(foreign()),
          throwsA(isA<TimetablePermissionDenied>()),
        );
        expect(backend.docs, hasLength(1));
        controller.dispose();
      },
    );

    test(
      "Abgleich mit der Quelle: neue Termine übernommen, Anpassungen bleiben",
      () async {
        final backend = InMemoryTimetableBackend();
        final controller = await controllerWith(backend);
        final old = foreign();
        final outdated = CourseSnapshot(
          courseId: old.courseId,
          semesterId: old.semesterId,
          sources: old.sources,
          title: old.title,
          number: old.number,
          rules: [old.rules.first],
          occurrences: old.occurrences,
          semester: old.semester,
        );
        await controller.addSnapshot(
          outdated,
          overrides: const EntryOverrides(note: "Wahlpflicht"),
        );
        await pumpEventQueue();
        final outcome = await controller.refreshFromSource(
          controller.entries.single,
        );
        await pumpEventQueue();
        expect(outcome, RefreshOutcome.updated);
        final entry = controller.entries.single;
        expect(entry.snapshot!.rules, hasLength(2));
        expect(entry.overrides.note, "Wahlpflicht");
        expect(
          await controller.refreshFromSource(entry),
          RefreshOutcome.unchanged,
        );
        controller.dispose();
      },
    );

    test("gespeicherte Form passt zu den Firestore-Regeln", () {
      final entry = TimetableEntry.fromSnapshot(
        foreign(),
        overrides: const EntryOverrides(
          title: "x",
          rules: {"phil-r2": RuleOverride(startTime: "16:15")},
        ),
      );
      final map = entry.toMap();
      const allowed = {
        "courseId",
        "semesterId",
        "sources",
        "title",
        "number",
        "scheduleSignature",
        "addedAt",
        "snapshot",
        "overrides",
      };
      expect(allowed.containsAll(map.keys), isTrue);
      final snapshot = map["snapshot"] as Map;
      expect(snapshot.length, lessThanOrEqualTo(25));
      expect(snapshot.keys, containsAll(["title", "rules", "occurrences"]));
      expect(
        {
          "title",
          "lecturers",
          "note",
          "rules",
          "extraSessions",
        }.containsAll((map["overrides"] as Map).keys),
        isTrue,
      );
    });
  });

  group("Studienunterlagen", () {
    late StudyDocuments docs;
    late Map<String, dynamic> raw;

    setUpAll(() async {
      raw =
          jsonDecode(File(StudyDocuments.asset).readAsStringSync())
              as Map<String, dynamic>;
      docs = await StudyDocuments.load(FileAssetBundle());
    });

    test(
      "jeder Eintrag vollständig, offizielle HTTPS-Quelle, eindeutige Kennung",
      () {
        final ids = <String>{};
        var count = 0;
        for (final g in raw["groups"] as List) {
          for (final d in (g as Map)["documents"] as List) {
            count++;
            final doc = d as Map;
            for (final field in [
              "id",
              "title",
              "description",
              "programs",
              "publisher",
              "url",
              "sourcePage",
              "status",
              "validity",
            ]) {
              expect(
                doc[field],
                isNotNull,
                reason: "${doc["id"]}: $field fehlt",
              );
            }
            expect(
              ids.add(doc["id"] as String),
              isTrue,
              reason: "doppelte Kennung ${doc["id"]}",
            );
            expect(
              isOfficialUrl(Uri.parse(doc["url"] as String)),
              isTrue,
              reason: doc["url"] as String,
            );
            expect(
              isOfficialUrl(Uri.parse(doc["sourcePage"] as String)),
              isTrue,
              reason: doc["sourcePage"] as String,
            );
            expect(["current", "older", "unclear"], contains(doc["status"]));
            for (final p in doc["programs"] as List) {
              expect(
                (raw["programs"] as Map).containsKey(p),
                isTrue,
                reason: "${doc["id"]}: Studiengang $p",
              );
            }
          }
        }
        // Kein Eintrag geht beim Einlesen verloren.
        expect(docs.groups.expand((g) => g.documents).length, count);
        expect(
          [for (final g in docs.groups) g.title],
          [
            "Studienstruktur",
            "Prüfungen und Ordnungen",
            "Anerkennung und Studienorganisation",
          ],
        );
      },
    );

    test("fremde Adressen werden nicht übernommen", () {
      expect(isOfficialUrl(Uri.parse("https://www.uni-kiel.de/x.pdf")), isTrue);
      expect(
        isOfficialUrl(
          Uri.parse("https://www.studservice.uni-kiel.de/sta/x.pdf"),
        ),
        isTrue,
      );
      expect(isOfficialUrl(Uri.parse("http://www.uni-kiel.de/x.pdf")), isFalse);
      expect(
        isOfficialUrl(Uri.parse("https://uni-kiel.de.example.com/x.pdf")),
        isFalse,
      );
      expect(
        StudyDocument.tryFromJson({
          "id": "x",
          "title": "x",
          "url": "https://example.com/x.pdf",
        }),
        isNull,
      );
    });

    test("Filter: Studiengang und ältere Fassungen", () {
      final current = docs
          .filtered(program: "lehramt", includeOlder: false)
          .expand((g) => g.documents)
          .toList();
      expect(current.every((d) => d.status != DocumentStatus.older), isTrue);
      expect(current.map((d) => d.id), contains("pvo-2019"));
      expect(current.map((d) => d.id), contains("zfpo-2027"));
      expect(current.map((d) => d.id), isNot(contains("dka-dpo-2023")));
      final dka = docs
          .filtered(program: "dka")
          .expand((g) => g.documents)
          .map((d) => d.id)
          .toList();
      expect(
        dka,
        containsAll(["dka-dpo-2023", "dka-dpo-2012", "faq-studieneinstieg"]),
      );
      expect(dka, isNot(contains("pvo-2019")));
    });
  });
}
