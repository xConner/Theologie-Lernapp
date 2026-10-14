import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/timetable/course_catalog.dart';
import 'package:theologie_lernapp/models/timetable/course_snapshot.dart';
import 'package:theologie_lernapp/models/timetable/timetable_entry.dart';
import 'package:theologie_lernapp/services/timetable/course_catalog_source.dart';
import 'package:theologie_lernapp/services/timetable/course_search.dart';
import 'package:theologie_lernapp/services/timetable/plan_conflicts.dart';
import 'package:theologie_lernapp/services/timetable/plan_schedule.dart';
import 'package:theologie_lernapp/services/timetable/timetable_controller.dart';
import 'package:theologie_lernapp/services/timetable/timetable_schedule.dart';
import 'package:theologie_lernapp/services/timetable/timetable_store.dart';
import 'package:theologie_lernapp/services/timetable/week_layout.dart';

import 'test_asset_bundle.dart';
import 'timetable_test_support.dart';

void main() {
  late CourseCatalog catalog;
  String id(String key) => "synthetic:2026w:$key";
  CatalogCourse course(String key) => catalog.courseById(id(key))!;

  setUpAll(() async {
    catalog = (await SyntheticCourseCatalogSource(
      bundle: FileAssetBundle(),
    ).load("2026w")).catalog;
  });

  group("Katalog", () {
    test("synthetischer Katalog ist gekennzeichnet und vollständig lesbar", () {
      expect(catalog.synthetic, isTrue);
      expect(catalog.provenance.sourceId, "synthetic");
      expect(catalog.semester.id, "2026w");
      expect(catalog.courses, hasLength(17));
      expect(
        catalog.courses.every((c) => c.id.startsWith("synthetic:")),
        isTrue,
      );
      // Dublette (Import) wurde serverseitig zusammengeführt, Quellen bleiben.
      expect(course("Lecture.test.at.bibelk").sources.map((s) => s.key), [
        "Lecture.test.at.bibelk",
        "Lecture.test.erg._bibelk",
      ]);
    });

    test(
      "Termine tragen die Kieler Ortszeit, unabhängig von der Gerätezeitzone",
      () {
        final first = catalog.occurrencesOf(id("Lecture.test.at.einf")).first;
        expect(first.date, "2026-10-12");
        expect(first.start.time, "10:15");
        expect(first.start.instant, DateTime.utc(2026, 10, 12, 8, 15));
        final winter = catalog
            .occurrencesOf(id("Lecture.test.at.einf"))
            .firstWhere((o) => o.date == "2026-11-02");
        expect(winter.start.instant, DateTime.utc(2026, 11, 2, 9, 15));
      },
    );

    test("Asset ohne Kennzeichnung als synthetisch wird abgelehnt", () async {
      final bundle = MemoryAssetBundle({
        SyntheticCourseCatalogSource.asset: jsonEncode({
          "semester": {"id": "2026w"},
          "courses": [],
        }),
      });
      expect(
        SyntheticCourseCatalogSource(bundle: bundle).load("2026w"),
        throwsA(isA<CatalogFormatException>()),
      );
    });

    test(
      "unvollständige Einträge werden übergangen, fehlende Struktur abgelehnt",
      () {
        final parsed = CourseCatalog.fromJson({
          "synthetic": true,
          "semester": {
            "id": "2026w",
            "start": "2026-10-01",
            "end": "2027-03-31",
          },
          "courses": [
            {"id": "a", "title": "A"},
            {"id": "ohne Titel"},
            "kein Objekt",
          ],
          "occurrences": [
            {
              "id": "o1",
              "courseId": "a",
              "start": "2026-10-12T10:00:00+02:00",
              "end": "2026-10-12T11:00:00+02:00",
            },
            {
              "id": "o2",
              "courseId": "a",
              "start": "kaputt",
              "end": "2026-10-12T11:00:00+02:00",
            },
            {
              "id": "o3",
              "courseId": "a",
              "start": "2026-10-12T11:00:00+02:00",
              "end": "2026-10-12T10:00:00+02:00",
            },
          ],
        });
        expect(parsed.courses.map((c) => c.id), ["a"]);
        expect(parsed.occurrencesOf("a").map((o) => o.id), ["o1"]);
        expect(
          () => CourseCatalog.fromJson({"courses": []}),
          throwsA(isA<CatalogFormatException>()),
        );
      },
    );
  });

  group("Suche und Filter", () {
    List<String> keys(CourseFilter f) =>
        filterCourses(catalog, f).map((c) => c.id.split(":").last).toList();

    test(
      "Titel, Nummer, Modulkürzel und Dozent; Umlaute und Groß/Klein egal",
      () {
        expect(keys(const CourseFilter(query: "bibelkunde")), [
          "Lecture.test.at.bibelk",
        ]);
        expect(keys(const CourseFilter(query: "990011")), [
          "Lecture.test.nt.einf",
        ]);
        expect(keys(const CourseFilter(query: "TEST-ST3-S")), [
          "Lecture.test.st.ethik",
        ]);
        expect(keys(const CourseFilter(query: "uebung bibel")), [
          "Lecture.test.at.bibelk",
        ]);
        expect(keys(const CourseFilter(query: "Übung Bibel")), [
          "Lecture.test.at.bibelk",
        ]);
        expect(
          keys(const CourseFilter(query: "Entwurf")),
          containsAll(["Lecture.test.kg.einf", "Lecture.test.pt.rv"]),
        );
        expect(keys(const CourseFilter(query: "gibt es nicht")), isEmpty);
        expect(keys(const CourseFilter()), hasLength(17));
      },
    );

    test(
      "Filter nach Dozent, Fachbereich, Typ und Wochentag, auch kombiniert",
      () {
        expect(
          keys(const CourseFilter(lecturerId: "synthetic:Person.test.muster")),
          // alphabetisch nach Titel
          [
            "Lecture.test.pt.exk",
            "Lecture.test.nt.gr",
            "Lecture.test.at.bibelk",
          ],
        );
        expect(
          keys(
            const CourseFilter(
              organization: "Testinstitut für Kirchengeschichte",
            ),
          ),
          hasLength(3),
        );
        expect(keys(const CourseFilter(type: "SK")), [
          "Lecture.test.spr.gr",
          "Lecture.test.spr.hebr",
        ]);
        final tuesday = keys(const CourseFilter(weekday: 2));
        expect(
          tuesday,
          containsAll([
            "Lecture.test.nt.einf",
            "Lecture.test.nt.gr",
            "Lecture.test.spr.gr",
          ]),
        );
        expect(tuesday, isNot(contains("Lecture.test.at.einf")));
        expect(keys(const CourseFilter(weekday: 2, type: "V")), [
          "Lecture.test.nt.einf",
        ]);
        // Ohne Termine kein Wochentag.
        expect(
          keys(const CourseFilter(weekday: 1)),
          isNot(contains("Lecture.test.os")),
        );
      },
    );

    test("Filterwerte stammen aus dem Katalog", () {
      final facets = CourseFacets.of(catalog);
      expect(facets.lecturers.map((p) => p.displayName), [
        "Prof. Dr. Lea Beispiel",
        "PD Dr. Anna Entwurf",
        "Dr. Jonas Muster",
        "Mira Probe",
        "Prof. Dr. Karl Vorlage",
      ]);
      expect(facets.types, containsAll(["V", "UE", "SK", "BS"]));
      // Die Exkursion (Fr–So) zählt mit ihrem Beginn am Freitag.
      expect(facets.weekdays, [1, 2, 3, 4, 5]);
      expect(facets.organizations, contains("Testbereich Fachergänzung"));
    });

    test("copyWith setzt Filter gezielt zurück", () {
      const f = CourseFilter(query: "x", type: "V", weekday: 2);
      final g = f.copyWith(type: () => null);
      expect([g.query, g.type, g.weekday], ["x", null, 2]);
      expect(const CourseFilter().isEmpty, isTrue);
    });
  });

  group("Überschneidungen", () {
    PlanOccurrence occ(
      String id,
      String course,
      String start,
      String end, {
      bool cancelled = false,
    }) => PlanOccurrence(
      id: id,
      entryId: course,
      ruleId: "$course#r",
      start: LocalDateTime.tryParse("2026-11-03T$start:00+01:00")!,
      end: LocalDateTime.tryParse("2026-11-03T$end:00+01:00")!,
      cancelled: cancelled,
    );

    List<PlanOccurrence> planned(Iterable<String> keys) => [
      for (final key in keys)
        ...resolvePlanCourse(
          TimetableEntry.fromCourse(course(key)),
          catalog: catalog,
        ).occurrences,
    ];

    test(
      "teilweise, enthalten, direkt anschließend, abgesagt, gleiche Veranstaltung",
      () {
        final spots = conflictSpots([
          occ("a", "A", "10:00", "12:00"),
          occ("b", "B", "11:30", "13:00"),
          occ("c", "C", "10:30", "11:00"),
          occ("d", "D", "12:00", "12:30"), // berührt a, überschneidet b
          occ("e", "E", "10:00", "12:00", cancelled: true),
          occ("a2", "A", "11:00", "11:15"), // gleiche Veranstaltung wie a
        ]);
        // a2 berührt c nur (11:00) und gehört zur selben Veranstaltung wie a;
        // d berührt a nur (12:00); e ist abgesagt.
        expect(
          [
            for (final s in spots)
              "${s.entryIds.join("-")}:${s.duration.inMinutes}",
          ],
          ["A-C:30", "A-B:30", "B-D:30"],
        );
      },
    );

    test(
      "Katalog: Überschneidung NT-Vorlesung/Lektüre, kein Konflikt bei Anschluss",
      () {
        final spots = conflictSpots(
          planned(["Lecture.test.nt.einf", "Lecture.test.nt.gr"]),
        );
        expect(spots, hasLength(16));
        final groups = groupConflicts(spots);
        expect(groups, hasLength(1));
        expect(groups.single.recurring, isTrue);
        expect(
          groups.single.entryIds,
          [id("Lecture.test.nt.einf"), id("Lecture.test.nt.gr")]..sort(),
        );
        expect(
          conflictSpots(
            planned(["Lecture.test.kg.einf", "Lecture.test.kg.ue"]),
          ),
          isEmpty,
        );
      },
    );

    test(
      "Wochenraster: Termine je Tag, gleichzeitige nebeneinander, Block an jedem Tag",
      () {
        final week = layoutWeek(
          planned([
            "Lecture.test.nt.einf",
            "Lecture.test.nt.gr",
            "Lecture.test.at.einf",
          ]),
          "2026-11-02",
        );
        expect(week.days[1]!.map((b) => b.occurrence.entryId), [
          id("Lecture.test.at.einf"),
        ]);
        expect(
          week.days[2]!.map((b) => b.occurrence.start.time).toList()..sort(),
          ["10:15", "11:00"],
        );
        expect(week.days[2]!.every((b) => b.lanes == 2), isTrue);
        expect(week.days[1]!.single.lanes, 1);

        final cancelledWeek = layoutWeek(
          planned(["Lecture.test.at.einf"]),
          "2026-11-16",
        );
        expect(cancelledWeek.days[1]!.single.occurrence.cancelled, isTrue);

        final block = layoutWeek(
          planned(["Lecture.test.pt.exk"]),
          "2027-01-25",
        );
        expect(
          [for (var d = 1; d <= 7; d++) block.days[d]!.length],
          [0, 0, 0, 0, 1, 1, 1],
        );
        expect(block.days[5]!.single.occurrence.regular, isFalse);

        final christmas = layoutWeek(
          planned(["Lecture.test.at.einf"]),
          "2026-12-21",
        );
        expect(christmas.isEmpty, isTrue);
        expect(
          breakOn(catalog.semester, "2026-12-23")?.label,
          contains("unterrichtsfrei"),
        );
      },
    );

    test("Wochen: Montag, Semesterwochen, Startwoche", () {
      expect(mondayOf("2026-10-18"), "2026-10-12");
      expect(mondayOf("2026-10-12"), "2026-10-12");
      final weeks = semesterWeeks(catalog.semester);
      expect(weeks.first, "2026-09-28");
      expect(weeks.last, "2027-03-29");
      expect(
        initialWeek(catalog.semester, DateTime(2026, 11, 4)),
        "2026-11-02",
      );
      expect(initialWeek(catalog.semester, DateTime(2026, 6, 1)), "2026-10-12");
    });
  });

  group("Stundenplan-Einträge", () {
    test(
      "Abgleich mit dem Katalog: aktuell, geändert, fehlt, anderes Semester",
      () {
        final c = course("Lecture.test.at.einf");
        final entry = TimetableEntry.fromCourse(c, now: DateTime(2026));
        expect(stateOf(entry, catalog), TimetableEntryState.current);
        final changed = TimetableEntry(
          courseId: c.id,
          semesterId: "2026w",
          title: c.title,
          scheduleSignature: "alt",
        );
        expect(stateOf(changed, catalog), TimetableEntryState.changed);
        final missing = TimetableEntry(
          courseId: "synthetic:2026w:weg",
          semesterId: "2026w",
          title: "Weg",
          scheduleSignature: "",
        );
        expect(stateOf(missing, catalog), TimetableEntryState.missing);
        final other = TimetableEntry(
          courseId: c.id,
          semesterId: "2027s",
          title: c.title,
          scheduleSignature: "",
        );
        expect(stateOf(other, catalog), TimetableEntryState.otherSemester);
      },
    );

    test("Speicherformat hin und zurück, Ungültiges wird verworfen", () {
      final entry = TimetableEntry.fromCourse(course("Lecture.test.at.bibelk"));
      final back = TimetableEntry.tryFromMap({
        ...entry.toMap(),
        "addedAt": 1000,
      });
      expect(back!.courseId, entry.courseId);
      expect(back.sources, entry.sources);
      expect(back.scheduleSignature, entry.scheduleSignature);
      expect(back.addedAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(entry.toMap().containsKey("addedAt"), isFalse);
      expect(TimetableEntry.tryFromMap({"title": "ohne Kennung"}), isNull);
      expect(TimetableEntry.tryFromMap({"courseId": "x"}), isNull);
    });

    test("Dokumentkennung ist gültig und eindeutig", () {
      final a = timetableDocId("synthetic:2026w:Lecture.test.at.einf");
      final b = timetableDocId("synthetic:2026w:Lecture.test.at.einf2");
      expect(a, isNot(b));
      expect(a, matches(RegExp(r"^[A-Za-z0-9_-]+$")));
      expect(timetableDocId("a/b"), isNot(contains("/")));
    });
  });

  group("Speicherung und Synchronisierung", () {
    test(
      "Hinzufügen und Entfernen; zwei Geräte sehen dieselben Einträge",
      () async {
        final cloud = InMemoryTimetableBackend();
        final phone = BackendTimetableStore(cloud);
        final laptop = BackendTimetableStore(cloud);
        final seen = <List<String>>[];
        final sub = laptop.watch().listen(
          (e) => seen.add([for (final x in e) x.courseId]),
        );
        await pumpEventQueue();

        await phone.add(
          TimetableEntry.fromCourse(course("Lecture.test.nt.einf")),
        );
        await phone.add(
          TimetableEntry.fromCourse(course("Lecture.test.at.einf")),
        );
        await pumpEventQueue();
        expect(seen.last, [
          id("Lecture.test.at.einf"),
          id("Lecture.test.nt.einf"),
        ]);

        await laptop.remove(id("Lecture.test.nt.einf"));
        await pumpEventQueue();
        expect(seen.last, [id("Lecture.test.at.einf")]);
        expect(
          await phone.watch().first.then((e) => e.map((x) => x.courseId)),
          [id("Lecture.test.at.einf")],
        );

        // Doppeltes Hinzufügen erzeugt keinen zweiten Eintrag.
        await phone.add(
          TimetableEntry.fromCourse(course("Lecture.test.at.einf")),
        );
        expect(cloud.docs, hasLength(1));
        await sub.cancel();
      },
    );

    test(
      "Gastmodus: lokal gespeichert, mehrere Instanzen synchron, defekte Daten ignoriert",
      () async {
        SharedPreferences.setMockInitialValues({});
        final a = BackendTimetableStore(LocalTimetableBackend());
        final b = BackendTimetableStore(LocalTimetableBackend());
        final updates = <int>[];
        final sub = b.watch().listen((e) => updates.add(e.length));
        await pumpEventQueue();

        await a.add(TimetableEntry.fromCourse(course("Lecture.test.at.einf")));
        await pumpEventQueue();
        expect(updates.last, 1);

        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString(LocalTimetableBackend.storageKey)!)
                as Map;
        expect(stored.values.single["courseId"], id("Lecture.test.at.einf"));
        expect(stored.values.single["addedAt"], isA<int>());

        await b.remove(id("Lecture.test.at.einf"));
        await pumpEventQueue();
        expect(updates.last, 0);
        await sub.cancel();

        SharedPreferences.setMockInitialValues({
          LocalTimetableBackend.storageKey: "{kaputt",
        });
        expect(
          await BackendTimetableStore(LocalTimetableBackend()).watch().first,
          isEmpty,
        );
      },
    );

    test("TimetableStore.forUser: Gast lokal", () {
      final store = TimetableStore.forUser(null);
      expect(
        (store as BackendTimetableStore).backend,
        isA<LocalTimetableBackend>(),
      );
    });
  });

  group("Controller", () {
    test(
      "lädt Katalog und Einträge, fügt hinzu/entfernt, meldet Konflikte",
      () async {
        final backend = InMemoryTimetableBackend();
        final controller = TimetableController(
          source: SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
          store: BackendTimetableStore(backend),
        );
        await controller.start();
        await pumpEventQueue();
        expect(controller.catalog, isNotNull);
        expect(controller.entriesLoaded, isTrue);
        expect(controller.entries, isEmpty);

        expect(await controller.toggle(course("Lecture.test.nt.einf")), isTrue);
        await pumpEventQueue();
        expect(controller.isPlanned(id("Lecture.test.nt.einf")), isTrue);
        final cat = controller.catalog!;
        expect(
          controller.conflictsFor(
            CourseSnapshot.fromCatalog(cat, course("Lecture.test.nt.gr")),
          ),
          hasLength(16),
        );
        expect(
          controller.conflictsFor(
            CourseSnapshot.fromCatalog(cat, course("Lecture.test.at.einf")),
          ),
          isEmpty,
        );

        await controller.add(course("Lecture.test.nt.gr"));
        await pumpEventQueue();
        expect(controller.conflicts, hasLength(16));
        expect(groupConflicts(controller.conflicts), hasLength(1));

        expect(
          await controller.toggle(course("Lecture.test.nt.einf")),
          isFalse,
        );
        await pumpEventQueue();
        expect(controller.plannedIds, {id("Lecture.test.nt.gr")});
        expect(controller.conflicts, isEmpty);
        controller.dispose();
      },
    );

    test(
      "Speicherfehler werden weitergereicht, Ladefehler des Katalogs gemeldet",
      () async {
        final failing = TimetableController(
          source: FailingCatalogSource(),
          store: BackendTimetableStore(
            InMemoryTimetableBackend(failWrites: true),
          ),
        );
        await failing.start();
        expect(failing.catalog, isNull);
        expect(failing.catalogError, isNotNull);
        final c = course("Lecture.test.at.einf");
        await expectLater(failing.add(c), throwsA(isA<StateError>()));
        expect(failing.isPending(c.id), isFalse);
        failing.dispose();
      },
    );

    test(
      "Fehler beim Beobachten des Stundenplans wird angezeigt und lässt sich wiederholen",
      () async {
        final backend = InMemoryTimetableBackend(failWatch: true);
        final controller = TimetableController(
          source: SyntheticCourseCatalogSource(bundle: FileAssetBundle()),
          store: BackendTimetableStore(backend),
        );
        await controller.start();
        await pumpEventQueue();
        expect(controller.entriesError, isNotNull);
        backend.failWatch = false;
        controller.retryEntries();
        await pumpEventQueue();
        expect(controller.entriesError, isNull);
        expect(controller.entriesLoaded, isTrue);
        controller.dispose();
      },
    );
  });

  test(
    "Firestore-Regeln: timetable mit eigener Regel, nicht in der allgemeinen Liste",
    () {
      final rules = File("firestore.rules").readAsStringSync();
      expect(rules, contains("match /timetable/{entryId}"));
      expect(rules, contains("isValidTimetableEntry(request.resource.data)"));
      final generic = RegExp(
        r"collection in \[([^\]]*)\]",
      ).firstMatch(rules)!.group(1)!;
      // Sonst würde die allgemeine Regel die Feldprüfung aushebeln (ODER).
      expect(generic, isNot(contains("'timetable'")));
      expect(FirestoreTimetableBackend.collection, "timetable");
      // Felder der Regel = Felder von TimetableEntry.toMap() + addedAt.
      final fields = RegExp(
        r"hasOnly\(\['courseId'[^\]]*\]",
      ).firstMatch(rules)!.group(0)!;
      final entry = TimetableEntry.fromCourse(course("Lecture.test.at.einf"));
      for (final key in [...entry.toMap().keys, "addedAt"]) {
        expect(fields, contains("'$key'"));
      }
    },
  );

  test("Katalog-Asset ist ausschließlich synthetisch", () {
    final raw = File(SyntheticCourseCatalogSource.asset).readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json["synthetic"], isTrue);
    expect(raw, isNot(contains("uni-kiel.de/prg")));
    expect(raw, isNot(contains("cau-univis")));
  });
}
