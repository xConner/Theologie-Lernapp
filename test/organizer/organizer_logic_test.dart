import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/organizer/organizer_items.dart';
import 'package:theologie_lernapp/services/organizer/org_dates.dart';
import 'package:theologie_lernapp/services/organizer/organizer_controller.dart';
import 'package:theologie_lernapp/services/organizer/recurrence.dart';

import 'organizer_test_support.dart';

OrgDate d(String key) => OrgDate.tryParse(key)!;

void main() {
  group("Datum und Uhrzeit", () {
    test("Kalendertage ohne Zeitzonenfehler über die Zeitumstellung", () {
      // 25.10.2026: Ende der Sommerzeit in Deutschland.
      expect(d("2026-10-24").addDays(1).key, "2026-10-25");
      expect(d("2026-10-25").addDays(1).key, "2026-10-26");
      expect(d("2026-03-28").addDays(2).key, "2026-03-30");
      expect(d("2026-10-20").daysUntil(d("2026-10-27")), 7);
      expect(d("2026-03-25").daysUntil(d("2026-04-01")), 7);
      expect(d("2026-10-26").weekday, 1);
      expect(d("2026-10-29").startOfWeek.key, "2026-10-26");
    });

    test("ungültige Tage werden abgelehnt, Monatsenden korrekt", () {
      expect(OrgDate.tryParse("2026-02-30"), isNull);
      expect(OrgDate.tryParse("2026-13-01"), isNull);
      expect(OrgDate.tryParse("26-1-1"), isNull);
      expect(d("2027-01-31").addMonths(1).key, "2027-02-28");
      expect(d("2028-01-31").addMonths(1).key, "2028-02-29");
      expect(d("2026-12-31").addDays(1).key, "2027-01-01");
    });

    test("Heute ist der lokale Kalendertag, auch kurz vor Mitternacht", () {
      expect(OrgDate.of(DateTime(2026, 10, 30, 23, 59)).key, "2026-10-30");
      expect(OrgDate.of(DateTime(2026, 10, 31, 0, 1)).key, "2026-10-31");
      // UTC-Zeitpunkte werden erst in Ortszeit umgerechnet.
      final utc = DateTime.utc(2026, 10, 30, 12);
      expect(OrgDate.of(utc), OrgDate.of(utc.toLocal()));
    });

    test("Wanduhrzeit bleibt über die Zeitumstellung gleich", () {
      final before = wallClock(d("2026-10-23"), OrgTime.hm(10, 15));
      final after = wallClock(d("2026-10-30"), OrgTime.hm(10, 15));
      expect(before.hour, 10);
      expect(after.hour, 10);
      expect(after.minute, 15);
    });

    test("Uhrzeiten", () {
      expect(OrgTime.tryParse("9:05")?.key, "09:05");
      expect(OrgTime.tryParse("14.30")?.key, "14:30");
      expect(OrgTime.tryParse("24:00"), isNull);
    });

    test("deutsche Datumsangaben aus Seminarplänen", () {
      final ref = d("2026-10-30");
      expect(
        GermanDateParser.parse("19. Oktober 2026", reference: ref)?.key,
        "2026-10-19",
      );
      expect(
        GermanDateParser.parse("am 4. Jan.", reference: ref)?.key,
        "2027-01-04",
      );
      expect(
        GermanDateParser.parse("15.02.", reference: ref)?.key,
        "2027-02-15",
      );
      expect(
        GermanDateParser.parse("01.09.", reference: ref)?.key,
        "2026-09-01",
      );
      expect(
        GermanDateParser.parse("3.11.26", reference: ref)?.key,
        "2026-11-03",
      );
      expect(GermanDateParser.parse("Kapitel 3", reference: ref), isNull);
    });
  });

  group("Wiederkehrende Termine", () {
    test("wöchentlich mit Ende und ausgelassenem Termin", () {
      final r = Recurrence(
        freq: RecurrenceFreq.weekly,
        until: d("2026-11-30"),
        exceptions: {"2026-11-09"},
      );
      final dates = r.occurrences(
        d("2026-10-19"),
        from: d("2026-10-01"),
        to: d("2027-01-31"),
      );
      expect(
        [for (final x in dates) x.key],
        [
          "2026-10-19",
          "2026-10-26",
          "2026-11-02",
          "2026-11-16",
          "2026-11-23",
          "2026-11-30",
        ],
      );
    });

    test("14-täglich und Abfrage mitten in der Serie", () {
      const r = Recurrence(freq: RecurrenceFreq.weekly, interval: 2);
      final dates = r.occurrences(
        d("2026-10-20"),
        from: d("2027-01-01"),
        to: d("2027-01-31"),
      );
      expect([for (final x in dates) x.key], ["2027-01-12", "2027-01-26"]);
      expect(r.describe(), "14-täglich");
    });

    test(
      "monatlich am 31. fällt auf das Monatsende, dann wieder auf den 31.",
      () {
        const r = Recurrence(freq: RecurrenceFreq.monthly);
        final dates = r.occurrences(
          d("2027-01-31"),
          from: d("2027-01-01"),
          to: d("2027-04-30"),
        );
        expect(
          [for (final x in dates) x.key],
          ["2027-01-31", "2027-02-28", "2027-03-31", "2027-04-30"],
        );
      },
    );

    test("mehrtägiges Vorkommen wird auch im Folgezeitraum gefunden", () {
      const r = Recurrence(freq: RecurrenceFreq.weekly);
      final dates = r.occurrences(
        d("2026-11-06"),
        from: d("2026-11-08"),
        to: d("2026-11-08"),
        spanDays: 2,
      );
      expect([for (final x in dates) x.key], ["2026-11-06"]);
    });

    test("über Sommer- und Winterzeit bleibt der Wochentag", () {
      const r = Recurrence(freq: RecurrenceFreq.weekly);
      final dates = r.occurrences(
        d("2026-03-23"),
        from: d("2026-03-23"),
        to: d("2026-04-06"),
      );
      expect([for (final x in dates) x.weekday], [1, 1, 1]);
    });

    test("Serie im Controller: auslassen, einzeln ändern, beenden", () async {
      final backend = MemoryOrganizerBackend();
      final c = await startController(backend);
      addTearDown(c.dispose);
      final e = c.newEvent(
        title: "Griechisch",
        date: d("2026-10-26"),
        start: OrgTime.hm(10, 15),
        end: OrgTime.hm(11, 45),
        typeId: "lecture",
        recurrence: const Recurrence(freq: RecurrenceFreq.weekly),
      );
      await settle();
      expect(c.itemsBetween(d("2026-10-26"), d("2026-11-15")).length, 3);

      await c.skipOccurrence(c.event(e.id)!, d("2026-11-02"));
      await settle();
      expect(
        [
          for (final i in c.itemsBetween(d("2026-10-26"), d("2026-11-15")))
            i.date.key,
        ],
        ["2026-10-26", "2026-11-09"],
      );

      final single = c.detachOccurrence(c.event(e.id)!, d("2026-11-09"));
      await c.saveEvent(single.copyWith(location: "Hörsaal 2"));
      await settle();
      final items = c.itemsBetween(d("2026-11-09"), d("2026-11-09"));
      expect(items.single.location, "Hörsaal 2");
      expect(items.single.event!.recurrence, isNull);

      await c.endSeriesBefore(c.event(e.id)!, d("2026-11-16"));
      await settle();
      expect(c.itemsBetween(d("2026-11-16"), d("2027-01-31")), isEmpty);
    });
  });

  group("Aufgaben", () {
    test("anlegen, bearbeiten, verschieben, abhaken, löschen", () async {
      final backend = MemoryOrganizerBackend();
      final c = await startController(backend);
      addTearDown(c.dispose);

      final t = c.newTask(title: "Ebeling-Text lesen", due: d("2026-10-30"));
      await settle();
      expect(backend.docs[t.id]!["title"], "Ebeling-Text lesen");
      expect(c.tasksFor(TaskView.today).single.id, t.id);

      await c.saveTask(
        c.task(t.id)!.copyWith(notes: "Kapitel 1", priority: OrgPriority.high),
      );
      await c.moveTask(c.task(t.id)!, d("2026-11-02"));
      await settle();
      expect(c.tasksFor(TaskView.today), isEmpty);
      expect(c.tasksFor(TaskView.upcoming).single.notes, "Kapitel 1");

      await c.toggleTask(c.task(t.id)!);
      await settle();
      expect(c.tasksFor(TaskView.open), isEmpty);
      expect(c.tasksFor(TaskView.done).single.id, t.id);
      expect(backend.docs[t.id]!["done"], true);

      await c.deleteTask(c.task(t.id)!);
      await settle();
      expect(c.task(t.id), isNull);
      expect(backend.docs.containsKey(t.id), isFalse);
    });

    test("ohne Datum, überfällig, Filter Studium/Privat", () async {
      final c = await startController(MemoryOrganizerBackend());
      addTearDown(c.dispose);
      c.newTask(title: "Milch kaufen", areaId: "area_shopping");
      c.newTask(title: "Vokabeln", due: d("2026-10-28"), areaId: "area_greek");
      c.newTask(title: "Referat", due: d("2026-11-20"));
      await settle();
      expect(c.tasksFor(TaskView.overdue).single.title, "Vokabeln");
      expect(c.tasksFor(TaskView.open).length, 3);
      // Mehr als 14 Tage: nicht „Demnächst“.
      expect(c.tasksFor(TaskView.upcoming), isEmpty);
      expect(
        c
            .tasksFor(
              TaskView.open,
              filter: const OrgFilter(group: OrgGroup.private),
            )
            .single
            .title,
        "Milch kaufen",
      );
      expect(
        c
            .tasksFor(
              TaskView.open,
              filter: const OrgFilter(areaId: "area_greek"),
            )
            .single
            .title,
        "Vokabeln",
      );
    });

    test("nach Mitternacht wird eine heutige Aufgabe überfällig", () async {
      final clock = TestClock(DateTime(2026, 10, 30, 23, 50));
      final c = await startController(MemoryOrganizerBackend(), clock: clock);
      addTearDown(c.dispose);
      c.newTask(title: "Abgabe", due: d("2026-10-30"));
      await settle();
      expect(c.tasksFor(TaskView.today).length, 1);
      clock.now = DateTime(2026, 10, 31, 0, 10);
      expect(c.tasksFor(TaskView.today), isEmpty);
      expect(c.tasksFor(TaskView.overdue).length, 1);
    });

    test("wiederkehrende Aufgabe: nächste entsteht genau einmal", () async {
      final backend = MemoryOrganizerBackend();
      final c = await startController(backend);
      addTearDown(c.dispose);
      final t = c.newTask(
        title: "Vokabeln wiederholen",
        due: d("2026-10-30"),
        repeat: TaskRepeat.daily,
      );
      await settle();
      await c.toggleTask(c.task(t.id)!);
      await settle();
      final open = c.tasksFor(TaskView.open);
      expect(open.single.due!.key, "2026-10-31");
      // Wieder öffnen: die unberührte Folgeaufgabe entfällt.
      await c.toggleTask(c.task(t.id)!);
      await settle();
      expect(c.tasksFor(TaskView.open).single.id, t.id);
      // Werktags: Freitag → Montag.
      expect(
        TaskRepeat.weekdays.next(d("2026-10-30"), d("2026-10-30")).key,
        "2026-11-02",
      );
      // Lange nicht erledigt: nicht in die Vergangenheit.
      expect(
        TaskRepeat.weekly.next(d("2026-10-01"), d("2026-10-30")).key,
        "2026-11-05",
      );
    });

    test(
      "Lernbereich: Tagesziel erreicht → Aufgabe erledigt, nie umgekehrt",
      () async {
        final learning = FakeLearningSignals();
        final backend = MemoryOrganizerBackend();
        final c = await startController(backend, learning: learning);
        addTearDown(c.dispose);
        final t = c.newTask(
          title: "Griechisch üben",
          due: d("2026-10-30"),
          trackId: "greek",
          repeat: TaskRepeat.daily,
        );
        final manual = c.newTask(
          title: "Latein",
          due: d("2026-10-30"),
          trackId: "latin",
        );
        await settle();
        expect(c.isDone(c.task(t.id)!), isFalse);

        learning.reach("greek");
        await settle();
        expect(c.task(t.id)!.done, isTrue);
        expect(
          c.tasksFor(TaskView.open).map((t) => t.title),
          containsAll(["Griechisch üben", "Latein"]),
        );
        expect(
          c
              .tasksFor(TaskView.open)
              .firstWhere((x) => x.title == "Griechisch üben")
              .due!
              .key,
          "2026-10-31",
        );

        // Abhaken ändert keine Lernstände.
        await c.toggleTask(c.task(manual.id)!);
        await settle();
        expect(learning.goalReachedToday("latin"), isFalse);
      },
    );

    test("Lernaufgaben zu einer Klausur", () async {
      final c = await startController(MemoryOrganizerBackend());
      addTearDown(c.dispose);
      final exam = c.newEvent(
        title: "Griechisch-Klausur",
        date: d("2027-02-15"),
        typeId: OrgEventType.exam.id,
      );
      for (final title in ["Vokabeln wiederholen", "Grammatik wiederholen"]) {
        c.newTask(title: title, due: d("2027-02-10"), eventId: exam.id);
      }
      await settle();
      expect(c.tasksOfEvent(exam.id).length, 2);
      final item = c.upcomingItems(days: 200, importantOnly: true).single;
      expect(item.important, isTrue);
      // Termin löschen: Aufgaben bleiben, ohne Verweis.
      await c.deleteEvent(c.event(exam.id)!);
      await settle();
      expect(c.tasksOfEvent(exam.id), isEmpty);
      expect(c.tasksFor(TaskView.open).length, 2);
    });
  });

  group("Termine und Notizen", () {
    test(
      "Termin anlegen, bearbeiten, löschen; ganztägig und mehrtägig",
      () async {
        final backend = MemoryOrganizerBackend();
        final c = await startController(backend);
        addTearDown(c.dispose);
        final e = c.newEvent(
          title: "Zwischentest",
          date: d("2026-11-13"),
          endDate: d("2026-11-16"),
          typeId: "exam",
          reminderMinutes: 24 * 60,
        );
        await settle();
        expect(c.itemsOn(d("2026-11-15")).single.title, "Zwischentest");
        expect(c.itemsOn(d("2026-11-17")), isEmpty);
        await c.saveEvent(
          c
              .event(e.id)!
              .copyWith(
                allDay: false,
                start: OrgTime.hm(8, 0),
                end: OrgTime.hm(8, 30),
                clearEndDate: true,
                location: "OLAT",
              ),
        );
        await settle();
        final item = c.itemsOn(d("2026-11-13")).single;
        expect(item.timeLabel, "08:00–08:30");
        expect(backend.docs[e.id]!["location"], "OLAT");
        await c.deleteEvent(c.event(e.id)!);
        await settle();
        expect(c.events, isEmpty);
      },
    );

    test("Erinnerung in der App: ab dem Zeitpunkt bis zum Ende", () async {
      final clock = TestClock(DateTime(2026, 11, 12, 7, 0));
      final c = await startController(MemoryOrganizerBackend(), clock: clock);
      addTearDown(c.dispose);
      c.newEvent(
        title: "Klausur",
        date: d("2026-11-12"),
        start: OrgTime.hm(10, 0),
        end: OrgTime.hm(12, 0),
        reminderMinutes: 60,
      );
      await settle();
      expect(c.dueReminders, isEmpty);
      clock.now = DateTime(2026, 11, 12, 9, 5);
      expect(c.dueReminders.single.item.title, "Klausur");
      await c.dismissReminder(c.dueReminders.single.key);
      await settle();
      expect(c.dueReminders, isEmpty);
    });

    test("Notizen: anlegen, suchen, Tags, archivieren, löschen", () async {
      final backend = MemoryOrganizerBackend();
      final clock = TestClock(DateTime(2026, 10, 30, 12));
      final c = await startController(backend, clock: clock);
      addTearDown(c.dispose);
      // Leere Notiz wird nicht gespeichert.
      final empty = c.newNote();
      await c.saveNote(empty);
      await settle();
      expect(backend.docs.containsKey(empty.id), isFalse);

      final a = c.newNote(
        title: "Ebeling",
        body: "# Gottes Wort\n- Wort und Glaube",
        areaId: "area_courses",
        tags: ["Seminar"],
      );
      clock.now = DateTime(2026, 10, 30, 13);
      final b = c.newNote(
        body: "Einkaufsliste\n[ ] Brot",
        areaId: "area_private",
      );
      await settle();
      expect(c.recentNotes().first.id, b.id);
      expect(c.notesFor(query: "glaube").single.id, a.id);
      expect(c.notesFor(query: "seminar").single.id, a.id);
      expect(c.notesFor(tag: "Seminar").single.id, a.id);
      expect(c.note(b.id)!.displayTitle, "Einkaufsliste");

      await c.saveNote(c.note(a.id)!.copyWith(archived: true));
      await settle();
      expect(c.notesFor().single.id, b.id);
      expect(c.notesFor(archived: true).single.id, a.id);

      await c.deleteNote(c.note(b.id)!);
      await settle();
      expect(backend.docs.containsKey(b.id), isFalse);
    });

    test("Verknüpfungen in beide Richtungen", () async {
      final c = await startController(MemoryOrganizerBackend());
      addTearDown(c.dispose);
      final t = c.newTask(title: "Referat vorbereiten");
      final n = c.newNote(
        title: "Gliederung",
        links: [OrgLink(type: "task", target: t.id, label: t.title)],
      );
      await settle();
      expect(c.notesLinkedTo("task", t.id).single.id, n.id);
      expect(c.backlinks("task", t.id).single.id, n.id);
    });
  });

  group("Synchronisierung zwischen Geräten", () {
    test("Änderungen erscheinen auf dem zweiten Gerät", () async {
      final server = MemoryOrganizerBackend();
      final web = await startController(server);
      final phone = await startController(server);
      addTearDown(web.dispose);
      addTearDown(phone.dispose);

      final t = web.newTask(title: "Probeklausur");
      await settle();
      expect(phone.task(t.id)?.title, "Probeklausur");
      await phone.toggleTask(phone.task(t.id)!);
      await settle();
      expect(web.task(t.id)!.done, isTrue);
    });

    test("verschiedene Felder gleichzeitig geändert: beides bleibt", () async {
      final server = MemoryOrganizerBackend();
      final web = await startController(server);
      final phone = await startController(server);
      addTearDown(web.dispose);
      addTearDown(phone.dispose);
      final t = web.newTask(title: "Hausarbeit");
      await settle();

      // Beide Geräte haben denselben alten Stand.
      final onWeb = web.task(t.id)!;
      final onPhone = phone.task(t.id)!;
      final a = web.saveTask(onWeb.copyWith(notes: "Gliederung bis Freitag"));
      final b = phone.toggleTask(onPhone);
      await Future.wait([a, b]);
      await settle();
      for (final c in [web, phone]) {
        expect(c.task(t.id)!.done, isTrue);
        expect(c.task(t.id)!.notes, "Gliederung bis Freitag");
      }
    });

    test("offline: Änderung sofort sichtbar, später übertragen", () async {
      final server = MemoryOrganizerBackend()..offline = true;
      final phone = await startController(server);
      addTearDown(phone.dispose);
      final t = phone.newTask(title: "Im Zug notiert");
      await settle();
      expect(phone.task(t.id)?.title, "Im Zug notiert");
      expect(server.docs.containsKey(t.id), isFalse);
      server.goOnline();
      await settle();
      expect(server.docs[t.id]!["title"], "Im Zug notiert");
      expect(phone.task(t.id)?.title, "Im Zug notiert");
    });

    test("fehlgeschlagenes Speichern wird gemeldet", () async {
      final server = MemoryOrganizerBackend();
      final c = await startController(server);
      addTearDown(c.dispose);
      server.failWrites = true;
      c.newTask(title: "x");
      await settle();
      expect(c.saveFailed, isTrue);
    });

    test("Standardzuordnungen entstehen auf zwei Geräten nur einmal", () async {
      final server = MemoryOrganizerBackend();
      final a = await startController(server);
      final b = await startController(server);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await settle();
      final areas = server.docs.values.where((d) => d["kind"] == "area");
      expect(areas.length, OrganizerController.defaultAreas.length);
      expect(a.areas.map((x) => x.name), contains("Bibelkunde"));
      expect(a.area("area_private")!.group, OrgGroup.private);
    });

    test("feste Kennungen sind plattformunabhängig", () {
      // Wert festgeschrieben: Web (JavaScript-Zahlen) muss dasselbe liefern.
      // (mit dart2js geprüft, siehe docs/study-organizer.md).
      expect(
        OrgIds.stable("t", "ch-seminar|seminar.03:task:0"),
        "t_ch-seminar-seminar-03-task-0_2z1jsv1ern75p",
      );
      expect(
        orgFingerprint("Lektüre: Inc. Buch I; Stegmann, Proseminar"),
        "ulzxtr",
      );
      expect(OrgIds.stable("t", "a"), isNot(OrgIds.stable("t", "b")));
      expect(
        OrgIds.stable("t", "ch-seminar|seminar.03:task:0"),
        matches(RegExp(r"^t_ch-seminar-seminar-03-task-0_[0-9a-z]+$")),
      );
    });
  });
}
