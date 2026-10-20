import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/church_history/church_history.dart';
import 'package:theologie_lernapp/services/church_history/church_history_loader.dart';

import 'church_history_test_data.dart';

void main() {
  final data = loadChurchHistory();

  group("Inhalte", () {
    test("die Assets sind gültig", () {
      expect(ChurchHistoryLoader.validate(data), isEmpty);
    });

    test("pubspec bindet Daten und Folien ein", () {
      final pubspec = File("pubspec.yaml").readAsStringSync();
      expect(pubspec, contains("assets/church_history/"));
      expect(pubspec, contains("assets/church_history/slides/"));
    });

    test("IDs sind eindeutig und tragen das Präfix ihres Typs", () {
      final ids = [
        ...data.epochs.map((e) => e.id),
        ...data.themes.map((t) => t.id),
        ...data.entries.map((e) => e.id),
        ...data.lectures.map((l) => l.id),
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
          expect(File(s.image!).existsSync(), isTrue, reason: s.image);
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

    test("kuratierte Fragen haben eindeutige Antwortmöglichkeiten", () {
      for (final l in data.lectures) {
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
}
