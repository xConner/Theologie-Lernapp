import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/church_history/church_history.dart';
import 'package:theologie_lernapp/services/church_history/church_history_loader.dart';

import 'church_history_test_data.dart';
import '../lecture_materials_test_support.dart';

void main() {
  // Echte Inhalte: geschützte Vorlesungsunterlagen, nicht im Repository.
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials("Kirchengeschichte (Daten)");
    return;
  }

  final data = loadChurchHistory();

  group("Inhalte", () {
    test("die Assets sind gültig", () {
      expect(ChurchHistoryLoader.validate(data), isEmpty);
    });

    test("Daten und Folien sind nicht im öffentlichen Bundle", () {
      final pubspec = File("pubspec.yaml").readAsStringSync();
      expect(pubspec, isNot(contains("- assets/church_history/")));
      expect(Directory("assets/church_history").existsSync(), isFalse);
      // Auch Inhalte aus dem Proseminarmaterial stehen nur in den
      // geschützten Unterlagen, nicht in öffentlichen Dateien.
      for (final dir in ["assets", "lib", "web"]) {
        for (final f in Directory(
          dir,
        ).listSync(recursive: true).whereType<File>()) {
          if (!RegExp(r"\.(json|dart|html|js|txt)$").hasMatch(f.path)) continue;
          final text = f.readAsStringSync();
          for (final marker in [
            "material.zelzer",
            "material.bkv_incarnation",
          ]) {
            expect(text, isNot(contains(marker)), reason: f.path);
          }
        }
      }
    });

    test("IDs sind eindeutig und tragen das Präfix ihres Typs", () {
      final ids = [
        ...data.epochs.map((e) => e.id),
        ...data.themes.map((t) => t.id),
        ...data.entries.map((e) => e.id),
        ...data.units.map((l) => l.id),
        ...data.courses.map((c) => c.id),
        for (final c in data.courses) ...c.materials.map((m) => m.id),
      ];
      expect(ids.toSet().length, ids.length);

      for (final e in data.entries) {
        expect(e.id, startsWith("${e.type.name}."), reason: e.id);
      }
      for (final e in data.epochs) {
        expect(e.id, startsWith("epoch."));
      }
      for (final t in data.themes) {
        expect(t.id, startsWith("theme."));
      }
    });

    test("stabile IDs, auf die Lernstände verweisen", () {
      for (final id in [
        "epoch.antiquity",
        "epoch.contemporary",
        "lecture.01",
        "lecture.02",
        "person.decius",
        "event.decian_persecution",
        "term.lapsi",
        "source.pliny_letters",
        "seminar.01",
        "seminar.14",
        "person.cassian",
        "source.de_incarnatione",
        "term.theotokos",
      ]) {
        expect(
          data.entry(id) ?? data.epoch(id) ?? data.lecture(id),
          isNotNull,
          reason: id,
        );
      }
    });
  });

  group("Epochen", () {
    test("fünf Epochen nach Folie 4, lückenlos aufeinander folgend", () {
      expect(data.epochs.map((e) => e.id), [
        "epoch.antiquity",
        "epoch.middle_ages",
        "epoch.reformation",
        "epoch.modern",
        "epoch.contemporary",
      ]);

      for (var i = 1; i < data.epochs.length; i++) {
        expect(data.epochs[i].dating.from, data.epochs[i - 1].dating.to);
      }

      expect(data.epochs.last.dating.to, isNull);
      expect(data.epochs.every((e) => e.dating.approx), isTrue);
      expect(data.epochs.every((e) => e.lectureSlides.contains(4)), isTrue);
    });

    test("Ereignisse liegen in der Epoche, der sie zugeordnet sind", () {
      // Die Grenzen sind Richtwerte; das 1. Jahrhundert liegt vor dem
      // ersten Richtwert (100) und gehört zur ersten Epoche.
      final first = data.epochs.first;

      for (final e in data.entries.where((e) => e.type == EntryType.event)) {
        for (final epochId in e.epochIds) {
          final epoch = data.epoch(epochId)!;
          final before = epoch == first && e.dating!.from < first.dating.from;
          expect(
            before || e.dating!.overlaps(epoch.dating),
            isTrue,
            reason: "${e.id} / $epochId",
          );
        }
      }
    });

    test("Forscher ohne Epoche, Ereignisse der Antike in der Antike", () {
      expect(data.entry("person.karl_holl")!.epochIds, isEmpty);
      expect(
        data.entriesOfEpoch("epoch.antiquity").map((e) => e.id),
        contains("event.decian_persecution"),
      );
    });
  });

  group("Vorlesungen und Folien", () {
    test("Folien 1–7 gehören zu VL 1, 8–15 zu VL 2", () {
      expect(data.lectures.map((l) => l.id), ["lecture.01", "lecture.02"]);
      expect(data.lecture("lecture.01")!.slides.map((s) => s.number), [
        for (var i = 1; i <= 7; i++) i,
      ]);
      expect(data.lecture("lecture.02")!.slides.map((s) => s.number), [
        for (var i = 8; i <= 15; i++) i,
      ]);
    });

    test("jede Folie hat ein vorhandenes Bild und eine Abschrift", () {
      for (final l in data.lectures) {
        for (final s in l.slides) {
          expect(s.image, isNotNull, reason: "${l.id} Folie ${s.number}");
          expect(
            File(lectureMaterialsFile(s.image!)!).existsSync(),
            isTrue,
            reason: s.image,
          );
          expect(s.text.trim(), isNotEmpty);
        }
      }
    });

    test("Abschrift bewahrt den Wortlaut der Folie", () {
      // Schreibfehler der Originalfolie bleibt erhalten.
      expect(
        data.lecture("lecture.02")!.slide(12)!.text,
        contains("Matryrium Polycarpi"),
      );
    });

    test("Gliederung verweist auf vorhandene Vorlesungen", () {
      final linked = [
        for (final p in data.course.outline)
          for (final t in p.topics)
            if (t.lectureId != null) t.lectureId!,
      ];
      expect(linked, isNotEmpty);
      for (final id in linked) {
        expect(data.lecture(id), isNotNull);
      }
    });

    test("Erwähnungen verknüpfen Einträge mit ihren Vorlesungen", () {
      expect(data.isFromLecture("event.decian_persecution"), isTrue);
      expect(
        data.lecturesOf("term.periodization").map((l) => l.id),
        contains("lecture.01"),
      );

      final mentions = data.mentionsOf("event.decian_persecution");
      expect(mentions, isNotEmpty);
      for (final m in mentions) {
        final lecture = data.lecture(m.lectureId)!;
        for (final n in m.slides) {
          expect(lecture.slide(n), isNotNull);
        }
      }
    });

    test("Manuskript zu Vorlesung 2: Abschnitte mit Seitenangabe", () {
      final course = data.course;
      expect(
        course.materials.map((m) => m.id),
        contains("material.lecture_manuscript"),
      );
      final lecture = data.lecture("lecture.02")!;
      final fromManuscript = lecture.sections.where(
        (s) => s.ref?.materialId == "material.lecture_manuscript",
      );
      // Gliederung des Manuskripts: 2. Mission, 3. Christenverfolgungen.
      expect(fromManuscript.length, greaterThanOrEqualTo(8));
      final pages = <int>{};
      for (final s in fromManuscript) {
        expect(s.slides, isNotEmpty, reason: s.title);
        final m = RegExp(r"^S\. (\d+)(?:–(\d+))?$").firstMatch(s.ref!.at!)!;
        final from = int.parse(m[1]!), to = int.parse(m[2] ?? m[1]!);
        pages.addAll([for (var p = from; p <= to; p++) p]);
      }
      expect(pages, {for (var p = 1; p <= 12; p++) p});
      // Folieninhalt bleibt unverändert neben dem Manuskript stehen.
      expect(
        lecture.sections.where((s) => s.ref == null).map((s) => s.title),
        contains("Geschichtlicher Überblick der Verfolgungen"),
      );
      final questions = lecture.questions.where(
        (q) => q.id.startsWith("q.l02.ms_"),
      );
      expect(questions.length, greaterThanOrEqualTo(20));
      for (final q in questions) {
        expect(q.ref?.materialId, "material.lecture_manuscript", reason: q.id);
        expect(
          data.sourceLabel(q.lectureId, q.slides, q.ref),
          startsWith("Vorlesung 2 · Manuskript, S. "),
        );
      }
    });

    test(
      "Eintrag je Vorlesung einmal aus Folien, einmal aus dem Manuskript",
      () {
        final mentions = data
            .mentionsOf("event.diocletian_persecution")
            .where((m) => m.lectureId == "lecture.02")
            .toList();
        expect(mentions, hasLength(2));
        expect(mentions.first.slides, [13]);
        expect(mentions.last.ref?.materialId, "material.lecture_manuscript");
        expect(mentions.last.text, contains("1. Mai 305"));
        // Neue Einträge aus dem Manuskript gehören zur Vorlesung.
        for (final id in [
          "person.fabian",
          "person.tertullian",
          "event.armenia_christianization",
        ]) {
          expect(data.contextOf(id), CourseContext.lecture, reason: id);
        }
      },
    );

    test("kuratierte Fragen haben eindeutige Antwortmöglichkeiten", () {
      for (final l in data.units) {
        for (final q in l.questions) {
          final options = [q.answer, ...q.distractors];
          expect(options.toSet().length, options.length, reason: q.id);
          expect(q.distractors, isNotEmpty, reason: q.id);
        }
      }
    });
  });

  group("Verknüpfungen", () {
    test("Verknüpfungen sind symmetrisch und ohne Doppelungen", () {
      for (final e in data.entries) {
        final related = data.relatedOf(e.id);
        expect(related.map((r) => r.id).toSet().length, related.length);
        for (final r in related) {
          expect(
            data.relatedOf(r.id).map((x) => x.id),
            contains(e.id),
            reason: "${e.id} ↔ ${r.id}",
          );
        }
      }
    });

    test("nur genutzte Themen werden angeboten", () {
      for (final t in data.usedThemes) {
        expect(data.entriesOfTheme(t.id), isNotEmpty);
      }
    });

    test("Zeitleiste ist chronologisch", () {
      final timeline = data.timeline;
      for (var i = 1; i < timeline.length; i++) {
        expect(
          timeline[i].dating!.from,
          greaterThanOrEqualTo(timeline[i - 1].dating!.from),
        );
      }
    });
  });

  group("Prüfung fehlerhafter Daten", () {
    test("unbekannte Verknüpfung", () {
      final json = churchHistoryJson();
      final entries = json["entries"]!["entries"] as List;
      (entries.first as Map)["related"] = ["person.unknown"];

      expect(() => parseChurchHistory(json), throwsFormatException);
    });

    test("doppelte ID", () {
      final json = churchHistoryJson();
      final entries = json["entries"]!["entries"] as List;
      entries.add(Map<String, dynamic>.from(entries.first as Map));

      expect(() => parseChurchHistory(json), throwsFormatException);
    });

    test("Erwähnung einer Folie, die es nicht gibt", () {
      final json = churchHistoryJson();
      final lecture = (json["lectures"]!["lectures"] as List).first as Map;
      ((lecture["mentions"] as List).first as Map)["slides"] = [99];

      expect(() => parseChurchHistory(json), throwsFormatException);
    });

    test("unbekannte Epoche", () {
      final json = churchHistoryJson();
      final entries = json["entries"]!["entries"] as List;
      (entries.first as Map)["epochs"] = ["epoch.unknown"];

      expect(() => parseChurchHistory(json), throwsFormatException);
    });

    test("Datierung, die vor ihrem Beginn endet", () {
      expect(
        () => HistoricalDating.fromJson({"from": 300, "to": 200, "label": "x"}),
        throwsFormatException,
      );
    });
  });

  group("Datierungen", () {
    test("ungefähre und umstrittene Angaben haben Spielraum", () {
      const exact = HistoricalDating(from: 64, to: 64, label: "64");
      const approx = HistoricalDating(
        from: 140,
        to: 140,
        label: "um 140",
        approx: true,
      );
      const disputed = HistoricalDating(
        from: 49,
        to: 49,
        label: "49 (?)",
        disputed: true,
      );

      expect(exact.tolerance, 0);
      expect(approx.tolerance, greaterThan(0));
      expect(disputed.precisionHint, "umstritten");
      expect(approx.precisionHint, "ungefähr");
      expect(exact.precisionHint, isNull);

      // 49 (?) reicht mit Spielraum von 39 bis 59, also nicht bis 64.
      expect(disputed.overlaps(exact), isFalse);
      expect(
        disputed.overlaps(
          const HistoricalDating(from: 55, to: 55, label: "55"),
        ),
        isTrue,
      );
    });

    test("umstrittene Datierung der Claudius-Ausweisung ist markiert", () {
      expect(data.entry("event.claudius_49")!.dating!.disputed, isTrue);
    });

    test("offenes Ende reicht bis heute", () {
      final last = data.epochs.last.dating;
      expect(last.end, DateTime.now().year);
    });
  });

  group("Proseminar", () {
    final seminar = data.seminar!;

    test("eigene Veranstaltung mit 14 Sitzungen ohne Folien", () {
      expect(seminar.kind, CourseKind.seminar);
      expect(data.course.kind, CourseKind.lecture);
      expect(data.lectures.map((l) => l.id), ["lecture.01", "lecture.02"]);
      expect(data.sessions.map((s) => s.id), [
        for (var i = 1; i <= 14; i++) "seminar.${i.toString().padLeft(2, "0")}",
      ]);
      for (final s in data.sessions) {
        expect(s.courseId, seminar.id);
        expect(s.slides, isEmpty);
        expect(s.date, isNotNull);
      }
    });

    test("offensichtlicher Jahresfehler im Seminarplan ist berichtigt", () {
      expect(data.lecture("seminar.09")!.date, contains("2026"));
      for (final n in ["10", "11", "12", "13", "14"]) {
        final session = data.lecture("seminar.$n")!;
        expect(session.date, contains("2027"), reason: n);
        expect(session.sections.first.supplement, contains("2027"));
      }
    });

    test("Kennzeichnung: Vorlesung, Proseminar oder beide", () {
      expect(data.contextOf("event.decian_persecution"), CourseContext.lecture);
      expect(data.contextOf("person.cassian"), CourseContext.seminar);
      expect(data.contextOf("term.theotokos"), CourseContext.seminar);
      expect(data.contextOf("term.periodization"), CourseContext.both);
      expect(data.contextOf("term.church_history"), CourseContext.both);

      // Die Bibliographie nennt Ebeling nur; das macht ihn nicht gemeinsam.
      expect(data.contextOf("person.gerhard_ebeling"), CourseContext.lecture);
    });

    test("gemeinsame Inhalte haben einen Eintrag mit Erwähnungen beider", () {
      final mentions = data.mentionsOf("term.periodization");
      expect(mentions.map((m) => data.lecture(m.lectureId)!.kind).toSet(), {
        CourseKind.lecture,
        CourseKind.seminar,
      });
      expect(
        data.entries.where((e) => e.plainName == "Periodisierung"),
        hasLength(1),
      );
      expect(
        data.entriesOfCourseKind(CourseKind.seminar).map((e) => e.id),
        containsAll(["term.periodization", "person.cassian"]),
      );
      expect(
        data.entriesOfCourseKind(CourseKind.lecture).map((e) => e.id),
        allOf(
          contains("term.periodization"),
          isNot(contains("person.cassian")),
        ),
      );
    });

    test("jeder Inhalt einer Sitzung nennt seine Fundstelle", () {
      final materials = {for (final m in seminar.materials) m.id};
      final refs = [
        for (final s in data.sessions) ...[
          for (final x in s.sections) x.ref,
          for (final x in s.mentions) x.ref,
          for (final x in s.lists) x.ref,
          for (final x in s.questions) x.ref,
        ],
        for (final x in seminar.sections) x.ref,
      ];
      expect(refs, isNotEmpty);
      for (final ref in refs) {
        expect(ref, isNotNull);
        expect(materials, contains(ref!.materialId));
        expect(data.materialLabel(ref), isNotNull);
      }
      expect(
        data.sourceLabel(
          "seminar.02",
          const [],
          const MaterialRef("material.schwartz", "S. 7"),
        ),
        "Proseminar, Sitzung 2 · Schwartz 1939, S. 7",
      );
      expect(
        data.sourceLabel("lecture.02", const [9], null),
        "Vorlesung 2, Folie 9",
      );
    });

    test("Forschungspositionen sind belegt und als solche gekennzeichnet", () {
      for (final e in data.entries) {
        for (final n in e.notes.where((n) => n.kind == NoteKind.research)) {
          expect(n.ref, isNotNull, reason: e.id);
        }
      }
      final cassian = data.entry("person.cassian")!;
      expect(
        cassian.notes.map((n) => n.ref?.materialId),
        containsAll(["material.schwartz", "material.paucker"]),
      );
      // Umstrittene Herkunft und Lebensdaten werden nicht als sicher geführt.
      expect(cassian.dating!.disputed, isTrue);
      expect(data.entry("source.de_incarnatione")!.dating!.disputed, isTrue);
    });

    test("Übersetzung der Quelle: Lesestellen der Sitzungen 2–9", () {
      expect(
        seminar.materials.map((m) => m.id),
        containsAll(["material.zelzer", "material.bkv_incarnation"]),
      );
      var lastPage = 0;
      for (var n = 2; n <= 9; n++) {
        final session = data.lecture("seminar.0$n")!;
        final reading = session.sections.where(
          (s) => s.ref?.materialId == "material.bkv_incarnation",
        );
        expect(reading, hasLength(1), reason: session.id);
        // Praefatio und Bücher I–VII folgen lückenlos aufeinander.
        final pages = RegExp(
          r"S\. (\d+)–(\d+)",
        ).firstMatch(reading.single.ref!.at!)!;
        final from = int.parse(pages[1]!), to = int.parse(pages[2]!);
        if (lastPage > 0) expect(from, lastPage + 1, reason: session.id);
        expect(to, greaterThan(from));
        lastPage = to;
        expect(reading.single.supplement, contains("CSEL 17"));
      }
      expect(lastPage, 631);
    });

    test("offene Aufgaben künftiger Sitzungen werden nicht abgefragt", () {
      // Stellen, zu denen der Seminarplan Aufgaben ab der 3. Sitzung stellt.
      final openTasks = RegExp(
        r"\b(I,[126]|III,3,5|IV,1,1|V,1[1-3]|VI,3|VII,(2[4-9]|30))\b|Hydra|Antiochia",
      );
      for (final s in data.sessions.where((s) => s.number >= 3)) {
        for (final q in s.questions) {
          final text = [q.prompt, q.answer, q.explanation].join(" ");
          expect(openTasks.hasMatch(text), isFalse, reason: q.id);
        }
        for (final l in s.lists) {
          final text = [l.prompt, ...l.items].join(" ");
          expect(openTasks.hasMatch(text), isFalse, reason: l.id);
        }
      }
    });

    test("Belege aus der Übersetzung und aus Zelzer", () {
      for (final id in [
        "q.ps02.zelzer_ordination",
        // Aufgaben zur 2. Sitzung (26.10.2026), nach der Sitzung aufgenommen.
        "q.ps02.zelzer_sketis",
        "q.ps02.zelzer_serta",
        "q.ps02.zelzer_landscape",
        "q.ps02.praef_collationes",
        "q.ps02.praef_leo",
        "q.ps03.leporius",
        "q.ps03.two_christs",
        "q.ps07.nestorius_pelagius",
        "q.ps09.constantinople",
      ]) {
        final q = data.sessions
            .expand((s) => s.questions)
            .where((q) => q.id == id)
            .single;
        expect(
          ["material.zelzer", "material.bkv_incarnation"],
          contains(q.ref!.materialId),
          reason: id,
        );
        expect(q.ref!.at, startsWith("S. "), reason: id);
      }
      final cassian = data.entry("person.cassian")!;
      expect(
        cassian.notes.map((n) => n.ref?.materialId),
        contains("material.zelzer"),
      );
      // Was Cassian Nestorius zuschreibt, bleibt als seine Darstellung
      // gekennzeichnet.
      final nestorius = data.sessions
          .expand((s) => s.questions)
          .singleWhere((q) => q.id == "q.ps07.nestorius_pelagius");
      expect(nestorius.prompt, contains("schreibt Cassian"));
      expect(nestorius.explanation, contains("polemische Darstellung"));
    });

    test("Gliederung der Vorlesung verweist auf Themen des Proseminars", () {
      final topics = {
        for (final p in data.course.outline)
          for (final t in p.topics) t.title: t,
      };
      expect(
        topics["Der christologische Streit"]!.themeId,
        "theme.christology",
      );
      expect(
        data.entriesOfTheme("theme.christology").map((e) => e.id),
        contains("event.nestorian_controversy"),
      );
      expect(
        data.entriesOfTheme("theme.judaism").map((e) => e.id),
        containsAll(["term.anti_judaism", "term.jewish_christians"]),
      );
    });

    test("ohne Proseminar-Datei bleibt die Vorlesung allein", () {
      final json = churchHistoryJsonWithoutSeminar();
      final only = parseChurchHistory(json);

      expect(only.seminar, isNull);
      expect(only.courses, hasLength(1));
      expect(only.contextOf("term.periodization"), CourseContext.lecture);
    });

    test("Sitzung ohne Fundstelle wird abgelehnt", () {
      final json = churchHistoryJson();
      final session = (json["seminar"]!["sessions"] as List)[1] as Map;
      ((session["mentions"] as List).first as Map).remove("ref");

      expect(() => parseChurchHistory(json), throwsFormatException);
    });

    test("Fundstelle in unbekanntem Material wird abgelehnt", () {
      final json = churchHistoryJson();
      final session = (json["seminar"]!["sessions"] as List)[1] as Map;
      ((session["mentions"] as List).first as Map)["ref"] = {
        "material": "material.unknown",
      };

      expect(() => parseChurchHistory(json), throwsFormatException);
    });

    test("doppelte Erwähnung und doppelter Name werden abgelehnt", () {
      final json = churchHistoryJson();
      final session = (json["seminar"]!["sessions"] as List)[1] as Map;
      final mentions = session["mentions"] as List;
      mentions.add(Map<String, dynamic>.from(mentions.first as Map));
      expect(() => parseChurchHistory(json), throwsFormatException);

      final json2 = churchHistoryJson();
      final entries = json2["entries"]!["entries"] as List;
      entries.add(
        Map<String, dynamic>.from(
          entries.firstWhere((e) => e["id"] == "person.cassian") as Map,
        )..["id"] = "person.cassian_copy",
      );
      expect(() => parseChurchHistory(json2), throwsFormatException);
    });
  });
}
