import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/bible/course_reading_plan.dart';
import 'package:theologie_lernapp/models/organizer/organizer_items.dart';
import 'package:theologie_lernapp/services/church_history/church_history_loader.dart';
import 'package:theologie_lernapp/services/organizer/org_dates.dart';
import 'package:theologie_lernapp/services/organizer/organizer_controller.dart';
import 'package:theologie_lernapp/services/organizer/seminar_import.dart';

import 'organizer_test_support.dart';

OrgDate d(String key) => OrgDate.tryParse(key)!;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

ImportPlan cassian({OrgDate? today}) {
  final data = ChurchHistoryLoader.parse(
    epochs: json("assets/church_history/epochs.json"),
    themes: json("assets/church_history/themes.json"),
    entries: json("assets/church_history/entries.json"),
    lectures: json("assets/church_history/lectures.json"),
    seminar: json("assets/church_history/seminar.json"),
  );
  return ChurchHistorySeminarImport.plan(
    data,
    today: today ?? d("2026-10-30"),
  )!;
}

ImportDiff diffOf(OrganizerController c, ImportPlan plan) =>
    SeminarImporter.diff(
      plan,
      tasks: c.rawTasks,
      events: c.rawEvents,
      today: c.today,
    );

Set<String> suggested(ImportDiff diff) => {
  for (final ch in diff.changes)
    if (ch.suggested) SeminarImporter.selectionKey(ch),
};

void main() {
  group("Proseminar Kirchengeschichte (Seminarplan der App)", () {
    test("erkennt Sitzungen und nur die Vorbereitungsaufgaben", () {
      final plan = cassian();
      final events = plan.candidates.where((c) => c.kind == ImportKind.event);
      final tasks = plan.candidates.where((c) => c.kind == ImportKind.task);
      expect(events.length, 14);
      expect(events.first.date!.key, "2026-10-19");
      // Tippfehler „2026“ ab Sitzung 10 ist in den Daten schon berichtigt.
      expect(events.elementAt(9).date!.key, "2027-01-04");
      expect(events.every((e) => e.typeId == "seminar"), isTrue);

      // „Aufgaben zur 3. Sitzung“ stehen bei Sitzung 2, fällig zur 3.
      final forThird = tasks.where((t) => t.key.startsWith("seminar.03:task"));
      expect(forThird.length, 4);
      expect(forThird.every((t) => t.date!.key == "2026-11-02"), isTrue);
      expect(forThird.first.title, startsWith("Lektüre: Inc. Buch I"));
      expect(forThird.first.eventKey, "seminar.03:event");

      // Kein Referat, keine Literatur, keine Formalia als Aufgabe.
      for (final t in tasks) {
        expect(t.title, isNot(startsWith("Referat")));
        expect(t.title, isNot(contains("Kieler Richtlinien")));
      }
      final allPoints = tasks.length;
      expect(allPoints, 5 + 4 + 4 + 4 + 3 + 4 + 4 + 4 + 1);
    });

    test("Vorschau: Vergangenes nicht vorausgewählt; Übernahme ohne "
        "Duplikate bei erneutem Abgleich", () async {
      final server = MemoryOrganizerBackend();
      final c = await startController(server);
      addTearDown(c.dispose);
      final plan = cassian();
      final diff = diffOf(c, plan);
      expect(diff.count(ImportStatus.added), plan.candidates.length);
      final past = diff.changes.where((ch) => ch.past).toList();
      expect(past, isNotEmpty);
      expect(past.every((ch) => !ch.suggested), isTrue);

      final n = await SeminarImporter.apply(c, diff, selected: suggested(diff));
      await settle();
      expect(n, diff.changes.where((x) => x.suggested).length);
      expect(
        c.area(ChurchHistorySeminarImport.areaId)?.name,
        startsWith("Proseminar"),
      );
      final task = c.tasks.firstWhere(
        (t) => t.source?.key == "seminar.03:task:0",
      );
      expect(task.eventId, isNotNull);
      expect(c.event(task.eventId!)?.date.key, "2026-11-02");

      // Erneut: alles unverändert, nichts Neues.
      final again = diffOf(c, plan);
      expect(again.hasUpdates, isFalse);
      final before = server.docs.length;
      await SeminarImporter.applyAutomatic(c, again);
      await settle();
      expect(server.docs.length, before);

      // Zweites Gerät übernimmt gleichzeitig: dieselben Dokumente.
      final other = await startController(server);
      addTearDown(other.dispose);
      final d2 = SeminarImporter.diff(
        plan,
        tasks: const [],
        events: const [],
        today: other.today,
      );
      await SeminarImporter.apply(other, d2, selected: suggested(d2));
      await settle();
      expect(server.docs.length, before);
    });

    test("Erledigtes und Bearbeitetes wird bei Planänderung nicht "
        "überschrieben", () async {
      final c = await startController(MemoryOrganizerBackend());
      addTearDown(c.dispose);
      final plan = cassian();
      final diff = diffOf(c, plan);
      await SeminarImporter.apply(c, diff, selected: suggested(diff));
      await settle();

      final doneTask = c.tasks.firstWhere(
        (t) => t.source?.key == "seminar.04:task:0",
      );
      final editedTask = c.tasks.firstWhere(
        (t) => t.source?.key == "seminar.04:task:1",
      );
      final untouched = c.tasks.firstWhere(
        (t) => t.source?.key == "seminar.04:task:2",
      );
      await c.toggleTask(doneTask);
      await c.saveTask(
        editedTask.copyWith(title: "Inc. II gliedern (eigene Notiz)"),
      );
      await settle();
      expect(c.task(editedTask.id)!.source!.edited, isTrue);

      // Der Seminarplan verschiebt Sitzung 4 um eine Woche.
      final changed = ImportPlan(
        sourceId: plan.sourceId,
        title: plan.title,
        areaId: plan.areaId,
        areaName: plan.areaName,
        candidates: [
          for (final cand in plan.candidates)
            cand.key.startsWith("seminar.04:")
                ? cand.copyWith(date: d("2026-11-16"))
                : cand,
        ],
      );
      final d2 = diffOf(c, changed);
      ImportChange of(String key) => d2.changes.firstWhere(
        (x) => x.key == key && x.kind == ImportKind.task,
      );
      expect(of("seminar.04:task:0").status, ImportStatus.conflict);
      expect(of("seminar.04:task:1").status, ImportStatus.conflict);
      expect(of("seminar.04:task:2").status, ImportStatus.changed);
      expect(of("seminar.04:task:2").suggested, isTrue);

      await SeminarImporter.applyAutomatic(c, d2);
      await settle();
      expect(c.task(doneTask.id)!.done, isTrue);
      expect(c.task(doneTask.id)!.due!.key, "2026-11-09");
      expect(c.task(editedTask.id)!.title, "Inc. II gliedern (eigene Notiz)");
      expect(c.task(untouched.id)!.due!.key, "2026-11-16");
      expect(
        c.tasks.length,
        plan.candidates
            .where(
              (x) => x.kind == ImportKind.task && !x.date!.isBefore(c.today),
            )
            .length,
      );
    });

    test(
      "gelöschte Übernahme kehrt nicht zurück; entfallene wird gemeldet",
      () async {
        final c = await startController(MemoryOrganizerBackend());
        addTearDown(c.dispose);
        final plan = cassian();
        final diff = diffOf(c, plan);
        await SeminarImporter.apply(c, diff, selected: suggested(diff));
        await settle();
        final t = c.tasks.firstWhere(
          (t) => t.source?.key == "seminar.05:task:0",
        );
        await c.deleteTask(t);
        await settle();
        expect(c.task(t.id), isNull);

        final reduced = ImportPlan(
          sourceId: plan.sourceId,
          title: plan.title,
          areaId: plan.areaId,
          areaName: plan.areaName,
          candidates: [
            for (final cand in plan.candidates)
              if (cand.key != "seminar.06:task:0") cand,
          ],
        );
        final d2 = diffOf(c, reduced);
        final dismissed = d2.changes.firstWhere(
          (x) => x.key == "seminar.05:task:0",
        );
        expect(dismissed.status, ImportStatus.dismissed);
        expect(dismissed.suggested, isFalse);
        final removed = d2.changes.firstWhere(
          (x) => x.status == ImportStatus.removed,
        );
        expect(removed.key, "seminar.06:task:0");

        await SeminarImporter.applyAutomatic(c, d2);
        await settle();
        // Automatisch weder zurückgeholt noch gelöscht.
        expect(c.task(t.id), isNull);
        expect(
          c.tasks.any((x) => x.source?.key == "seminar.06:task:0"),
          isTrue,
        );
      },
    );
  });

  group("Übung Bibelkunde (Leseplan zur Lehrveranstaltung)", () {
    test(
      "Sitzungen und Zwischentests als Termine, Prüfungen hervorgehoben",
      () {
        final plan = CourseReadingPlan.fromJson(
          json("assets/reading_plans/course-bibelkunde-at-wise-2026.json"),
        );
        final import = BibelkundeCourseImport.plan(
          plan,
          start: OrgTime.hm(14, 15),
          end: OrgTime.hm(15, 45),
        );
        final sessions = import.candidates.where(
          (c) => c.typeId == "bibelkunde",
        );
        final exams = import.candidates.where((c) => c.typeId == "exam");
        expect(sessions.length, 14);
        expect(sessions.elementAt(1).date!.key, "2026-10-29");
        expect(sessions.elementAt(1).start!.key, "14:15");
        expect(exams.length, 4);
        expect(exams.first.date!.key, "2026-11-13");
        expect(exams.first.endDate!.key, "2026-11-16");
        expect(exams.first.start, isNull);
        // Lektüre nicht als gespeicherte Aufgabe (kommt aus dem Leseplan).
        expect(
          import.candidates.where((c) => c.kind == ImportKind.task),
          isEmpty,
        );
      },
    );
  });

  group("Eingefügter Seminarplan", () {
    const example = """
Seminar „Gottes Wort in deinem Ohr“ – Seminarplan

Sitzung 1 (21.10.): Einführung
Sitzung 2: Text von Ebeling lesen
Sitzung 3: Vorbereitung eines Referats
Sitzung 4: Hausarbeit besprechen

Literatur:
Gerhard Ebeling, Wort und Glaube, Tübingen 1960.
Abgabe der Hausarbeit bis 15.03.2027
""";

    test("erkennt Sitzungen, Vorbereitungsaufgaben und Abgaben", () {
      final result = SeminarTextParser.parse(example, today: d("2026-10-30"));
      final events = result.where((c) => c.kind == ImportKind.event).toList();
      final tasks = result.where((c) => c.kind == ImportKind.task).toList();

      expect(
        [for (final e in events) e.title],
        [
          "Sitzung 1: Einführung",
          "Sitzung 2: Text von Ebeling lesen",
          "Sitzung 3: Vorbereitung eines Referats",
          "Sitzung 4: Hausarbeit besprechen",
          "Abgabe der Hausarbeit",
        ],
      );
      // Wöchentlich ab dem ersten Datum.
      expect(
        [for (final e in events.take(4)) e.date!.key],
        ["2026-10-21", "2026-10-28", "2026-11-04", "2026-11-11"],
      );
      expect(events.last.typeId, "deadline");
      expect(events.last.date!.key, "2027-03-15");

      expect(
        [for (final t in tasks) t.title],
        [
          "Text von Ebeling lesen",
          "Vorbereitung eines Referats",
          "Abgabe der Hausarbeit",
        ],
      );
      expect(tasks[0].date!.key, "2026-10-28");
      expect(tasks[0].eventKey, "s2:event");
      expect(tasks[2].priority, OrgPriority.high);
      // Literatur, Einführung und „besprechen“ sind keine Aufgaben.
      expect(tasks.any((t) => t.title.contains("Wort und Glaube")), isFalse);
    });

    test("Aufgabenblöcke „zur n. Sitzung“, Datumszeilen, erste Sitzung", () {
      const text = """
1. Sitzung – Einführung in die Fragestellung
Aufgaben zur 2. Sitzung:
- Luther, De servo arbitrio, S. 1–20 lesen
- Thesen notieren
2. Sitzung – Freiheit und Gnade
3. Sitzung – Referate
Klausur am 10.02.2027
""";
      final result = SeminarTextParser.parse(
        text,
        today: d("2026-10-30"),
        firstSession: d("2026-10-22"),
        start: OrgTime.hm(10, 15),
        end: OrgTime.hm(11, 45),
      );
      final tasks = result.where((c) => c.kind == ImportKind.task).toList();
      expect(tasks.length, 2);
      expect(tasks.every((t) => t.date!.key == "2026-10-29"), isTrue);
      expect(tasks.every((t) => t.key.startsWith("s2:")), isTrue);
      final exam = result.firstWhere((c) => c.typeId == "exam");
      expect(exam.date!.key, "2027-02-10");
      final third = result.firstWhere((c) => c.key == "s3:event");
      expect(third.date!.key, "2026-11-05");
      expect(third.start!.key, "10:15");
    });

    test(
      "geänderter Text: Änderungen nachvollziehbar, keine Duplikate",
      () async {
        final c = await startController(MemoryOrganizerBackend());
        addTearDown(c.dispose);
        ImportPlan planOf(String text) => ImportPlan(
          sourceId: "text_ebeling",
          title: "Gottes Wort in deinem Ohr",
          areaId: "area_ebeling",
          areaName: "Seminar „Gottes Wort in deinem Ohr“",
          candidates: SeminarTextParser.parse(text, today: d("2026-10-01")),
        );
        final first = diffOf(c, planOf(example));
        await SeminarImporter.apply(
          c,
          first,
          selected: {
            for (final ch in first.changes) SeminarImporter.selectionKey(ch),
          },
        );
        await settle();
        final count = c.tasks.length + c.events.length;

        final changedText = example.replaceFirst(
          "Text von Ebeling lesen",
          "Text von Ebeling lesen (Wort und Glaube I, S. 1–15)",
        );
        final second = diffOf(c, planOf(changedText));
        final changed = second.changes.where(
          (x) => x.status == ImportStatus.changed,
        );
        expect(changed.length, 2); // Sitzungstermin und Aufgabe
        expect(second.count(ImportStatus.added), 0);
        await SeminarImporter.apply(c, second, selected: suggested(second));
        await settle();
        expect(c.tasks.length + c.events.length, count);
        expect(c.tasks.any((t) => t.title.contains("S. 1–15")), isTrue);
      },
    );
  });
}
