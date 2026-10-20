import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/church_history/church_history.dart';

/// Lädt die Inhalte aus `assets/church_history/` und prüft ihre
/// Verknüpfungen. Ein Fehler in den Daten (unbekannte ID, doppelte ID,
/// Folie ohne Vorlesung) führt zu einer [FormatException] mit allen
/// gefundenen Problemen, damit kein halb verknüpfter Bestand angezeigt wird.
class ChurchHistoryLoader {
  ChurchHistoryLoader._();

  static const String _dir = "assets/church_history";

  static Future<ChurchHistoryData>? _cached;

  /// Einmal je App-Start geladen; ein fehlgeschlagener Versuch wird nicht
  /// gemerkt, damit „Erneut versuchen“ wirkt.
  static Future<ChurchHistoryData> load({AssetBundle? bundle}) {
    final cached = _cached;
    if (cached != null && bundle == null) return cached;

    final future = _load(bundle ?? rootBundle);

    if (bundle == null) {
      _cached = future;
      future.then(
        (_) {},
        onError: (Object _) {
          if (identical(_cached, future)) _cached = null;
        },
      );
    }

    return future;
  }

  static Future<ChurchHistoryData> _load(AssetBundle bundle) async {
    Future<Map<String, dynamic>> read(String name) async {
      final raw = await bundle.loadString("$_dir/$name");
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    return parse(
      epochs: await read("epochs.json"),
      themes: await read("themes.json"),
      entries: await read("entries.json"),
      lectures: await read("lectures.json"),
    );
  }

  static ChurchHistoryData parse({
    required Map<String, dynamic> epochs,
    required Map<String, dynamic> themes,
    required Map<String, dynamic> entries,
    required Map<String, dynamic> lectures,
  }) {
    final data = ChurchHistoryData(
      course: _course(lectures["course"] as Map<String, dynamic>),
      epochs: [for (final e in _list(epochs["epochs"])) _epoch(e)],
      epochNote: epochs["note"] as String?,
      themes: [for (final t in _list(themes["themes"])) _theme(t)],
      entries: [for (final e in _list(entries["entries"])) _entry(e)],
      lectures: [for (final l in _list(lectures["lectures"])) _lecture(l)],
    );

    final problems = validate(data);

    if (problems.isNotEmpty) {
      throw FormatException(
        "Kirchengeschichte: ungültige Daten\n${problems.join("\n")}",
      );
    }

    return data;
  }

  /// Prüft IDs und Verknüpfungen; leer, wenn alles stimmt.
  static List<String> validate(ChurchHistoryData data) {
    final problems = <String>[];

    final ids = <String>{};

    void unique(String id) {
      if (!ids.add(id)) problems.add("Doppelte ID: $id");
    }

    for (final e in data.epochs) {
      unique(e.id);
    }
    for (final t in data.themes) {
      unique(t.id);
    }
    for (final e in data.entries) {
      unique(e.id);
    }
    for (final l in data.lectures) {
      unique(l.id);
      for (final list in l.lists) {
        unique(list.id);
      }
      for (final q in l.questions) {
        unique(q.id);
      }
    }

    final idPattern = RegExp(r'^[a-z]+(\.[a-z0-9_]+)+$');

    for (final id in ids) {
      if (!idPattern.hasMatch(id)) problems.add("Ungültige ID: $id");
    }

    for (final e in data.entries) {
      if (!e.id.startsWith("${e.type.name}.")) {
        problems.add("${e.id}: Präfix passt nicht zum Typ ${e.type.name}");
      }
      for (final id in e.epochIds) {
        if (data.epoch(id) == null) problems.add("${e.id}: Epoche $id fehlt");
      }
      for (final id in e.themeIds) {
        if (data.theme(id) == null) problems.add("${e.id}: Thema $id fehlt");
      }
      for (final id in e.relatedIds) {
        if (data.entry(id) == null) problems.add("${e.id}: Verweis $id fehlt");
      }
      if (e.type == EntryType.event && e.dating == null) {
        problems.add("${e.id}: Ereignis ohne Datierung");
      }
      if (e.type == EntryType.person && e.clue == null) {
        problems.add("${e.id}: Person ohne Kennzeichnung (clue)");
      }
    }

    for (final l in data.lectures) {
      final slideNumbers = {for (final s in l.slides) s.number};

      void slidesExist(String where, List<int> slides) {
        for (final n in slides) {
          if (!slideNumbers.contains(n)) {
            problems.add("${l.id} $where: Folie $n fehlt");
          }
        }
      }

      for (final id in [...l.epochIds]) {
        if (data.epoch(id) == null) problems.add("${l.id}: Epoche $id fehlt");
      }
      for (final id in l.themeIds) {
        if (data.theme(id) == null) problems.add("${l.id}: Thema $id fehlt");
      }
      for (final s in l.sections) {
        slidesExist(s.title, s.slides);
      }
      for (final m in l.mentions) {
        if (data.entry(m.entryId) == null) {
          problems.add("${l.id}: erwähnter Eintrag ${m.entryId} fehlt");
        }
        slidesExist(m.entryId, m.slides);
      }
      for (final list in l.lists) {
        slidesExist(list.id, list.slides);
        if (list.items.length < 2) problems.add("${list.id}: zu kurz");
      }
      for (final q in l.questions) {
        slidesExist(q.id, q.slides);
        for (final id in q.entryIds) {
          if (data.entry(id) == null) {
            problems.add("${q.id}: Eintrag $id fehlt");
          }
        }
        final options = {q.answer, ...q.distractors};
        if (options.length != q.distractors.length + 1 ||
            q.distractors.isEmpty) {
          problems.add("${q.id}: Antwortmöglichkeiten doppelt oder fehlend");
        }
      }
    }

    for (final part in data.course.outline) {
      if (part.epochId != null && data.epoch(part.epochId!) == null) {
        problems.add("Gliederung ${part.part}: Epoche fehlt");
      }
      for (final topic in part.topics) {
        if (topic.lectureId != null && data.lecture(topic.lectureId!) == null) {
          problems.add("Gliederung ${topic.title}: Vorlesung fehlt");
        }
      }
    }

    return problems;
  }

  // ==========================
  // EINZELNE TEILE
  // ==========================

  static List<Map<String, dynamic>> _list(Object? raw) {
    if (raw == null) return const [];
    return [for (final item in raw as List) item as Map<String, dynamic>];
  }

  static List<String> _strings(Object? raw) =>
      raw == null ? const [] : [for (final s in raw as List) s as String];

  static List<int> _ints(Object? raw) =>
      raw == null ? const [] : [for (final n in raw as List) n as int];

  static Course _course(Map<String, dynamic> json) {
    return Course(
      id: json["id"] as String,
      title: json["title"] as String,
      lecturer: json["lecturer"] as String,
      outline: [
        for (final p in _list(json["outline"]))
          OutlinePart(
            part: p["part"] as String,
            title: p["title"] as String,
            epochId: p["epoch"] as String?,
            slide: p["slide"] as int?,
            topics: [
              for (final t in _list(p["topics"]))
                OutlineTopic(
                  number: t["number"] as int,
                  title: t["title"] as String,
                  lectureId: t["lecture"] as String?,
                ),
            ],
          ),
      ],
    );
  }

  static Epoch _epoch(Map<String, dynamic> json) {
    return Epoch(
      id: json["id"] as String,
      title: json["title"] as String,
      dating: HistoricalDating.fromJson(json["dating"])!,
      characterization: json["characterization"] as String,
      summary: json["summary"] as String,
      lectureSlides: _ints(json["lectureSlides"]),
    );
  }

  static HistoryTheme _theme(Map<String, dynamic> json) {
    return HistoryTheme(
      id: json["id"] as String,
      title: json["title"] as String,
      description: json["description"] as String,
    );
  }

  static HistoryEntry _entry(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json["id"] as String,
      type: EntryType.parse(json["type"]),
      name: json["name"] as String,
      aliases: _strings(json["aliases"]),
      category: (json["role"] ?? json["category"]) as String?,
      dating: HistoricalDating.fromJson(json["dating"]),
      epochIds: _strings(json["epochs"]),
      themeIds: _strings(json["themes"]),
      clue: json["clue"] as String?,
      summary: json["summary"] as String,
      significance: json["significance"] as String,
      relatedIds: _strings(json["related"]),
      notes: [
        for (final n in _list(json["notes"]))
          EntryNote(kind: NoteKind.parse(n["kind"]), text: n["text"] as String),
      ],
      references: _strings(json["references"]),
    );
  }

  static Lecture _lecture(Map<String, dynamic> json) {
    final id = json["id"] as String;

    return Lecture(
      id: id,
      number: json["number"] as int,
      title: json["title"] as String,
      file: json["file"] as String?,
      epochIds: _strings(json["epochs"]),
      themeIds: _strings(json["themes"]),
      slides: [
        for (final s in _list(json["slides"]))
          Slide(
            number: s["number"] as int,
            title: s["title"] as String,
            image: s["image"] as String?,
            text: s["text"] as String,
            highlights: _strings(s["highlights"]),
          ),
      ],
      sections: [
        for (final s in _list(json["sections"]))
          LectureSection(
            title: s["title"] as String,
            slides: _ints(s["slides"]),
            points: _strings(s["points"]),
            supplement: s["supplement"] as String?,
          ),
      ],
      mentions: [
        for (final m in _list(json["mentions"]))
          LectureMention(
            lectureId: id,
            entryId: m["entry"] as String,
            slides: _ints(m["slides"]),
            text: m["text"] as String,
          ),
      ],
      lists: [
        for (final l in _list(json["lists"]))
          RecallList(
            id: l["id"] as String,
            lectureId: id,
            title: l["title"] as String,
            prompt: l["prompt"] as String,
            slides: _ints(l["slides"]),
            items: _strings(l["items"]),
            ordered: l["ordered"] == true,
          ),
      ],
      questions: [
        for (final q in _list(json["questions"]))
          CuratedQuestion(
            id: q["id"] as String,
            lectureId: id,
            prompt: q["prompt"] as String,
            answer: q["answer"] as String,
            distractors: _strings(q["distractors"]),
            explanation: q["explanation"] as String,
            slides: _ints(q["slides"]),
            entryIds: _strings(q["entries"]),
          ),
      ],
    );
  }
}
