import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/church_history/church_history.dart';
import '../lecture_materials/lecture_materials.dart';

/// Lädt die Inhalte aus `assets/church_history/` (geschützte
/// Vorlesungsunterlagen, geliefert von `LectureMaterials`) und prüft ihre
/// Verknüpfungen. Ein Fehler in den Daten (unbekannte ID, doppelte ID,
/// Folie ohne Vorlesung) führt zu einer [FormatException] mit allen
/// gefundenen Problemen, damit kein halb verknüpfter Bestand angezeigt wird.
class ChurchHistoryLoader {
  ChurchHistoryLoader._();

  static const String _dir = "assets/church_history";

  static (int, Future<ChurchHistoryData>)? _cached;

  /// Einmal je Freigabe geladen (geschützte Vorlesungsunterlagen, siehe
  /// `LectureMaterials`); ein fehlgeschlagener Versuch wird nicht gemerkt,
  /// damit „Erneut versuchen“ wirkt. Ohne Freigabe schlägt das Laden fehl.
  static Future<ChurchHistoryData> load({AssetBundle? bundle}) {
    final materials = LectureMaterials.instance;
    final generation = materials.generation;
    final cached = _cached;
    if (cached != null && cached.$1 == generation && bundle == null) {
      return cached.$2;
    }

    final future = _load(bundle ?? materials.bundle);

    if (bundle == null) {
      _cached = (generation, future);
      future.then(
        (_) {},
        onError: (Object _) {
          if (identical(_cached?.$2, future)) _cached = null;
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
      seminar: await read("seminar.json"),
    );
  }

  /// [lectures] und [seminar] beschreiben je eine Veranstaltung (`course`)
  /// mit ihren Vorlesungen (`lectures`) bzw. Sitzungen (`sessions`).
  static ChurchHistoryData parse({
    required Map<String, dynamic> epochs,
    required Map<String, dynamic> themes,
    required Map<String, dynamic> entries,
    required Map<String, dynamic> lectures,
    Map<String, dynamic>? seminar,
  }) {
    final courses = <Course>[];
    final units = <Lecture>[];

    for (final file in [lectures, ?seminar]) {
      final course = _course(file["course"] as Map<String, dynamic>);
      courses.add(course);
      for (final l in _list(file["lectures"] ?? file["sessions"])) {
        units.add(_lecture(l, course));
      }
    }

    final data = ChurchHistoryData(
      courses: courses,
      epochs: [for (final e in _list(epochs["epochs"])) _epoch(e)],
      epochNote: epochs["note"] as String?,
      themes: [for (final t in _list(themes["themes"])) _theme(t)],
      entries: [for (final e in _list(entries["entries"])) _entry(e)],
      units: units,
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
    for (final c in data.courses) {
      unique(c.id);
      for (final m in c.materials) {
        unique(m.id);
      }
    }
    for (final l in data.units) {
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
      for (final n in e.notes) {
        if (n.ref != null && data.material(n.ref!.materialId) == null) {
          problems.add("${e.id}: Material ${n.ref!.materialId} fehlt");
        }
      }
    }

    // Gleicher Name oder Alias bei zwei Einträgen deutet auf eine Doppelung.
    final names = <String, String>{};
    for (final e in data.entries) {
      for (final n in {e.plainName, ...e.aliases}) {
        final key = "${e.type.name}:${n.toLowerCase()}";
        final other = names[key];
        if (other != null && other != e.id) {
          problems.add("${e.id}: Name „$n“ auch bei $other");
        }
        names[key] = e.id;
      }
    }

    for (final l in data.units) {
      final slideNumbers = {for (final s in l.slides) s.number};
      final course = data.courseById(l.courseId);

      if (course == null) {
        problems.add("${l.id}: Veranstaltung ${l.courseId} fehlt");
      }

      // Fundstelle: in Vorlesungen die Folie, sonst ein Material der
      // eigenen Veranstaltung.
      void slidesExist(
        String where,
        List<int> slides, [
        MaterialRef? ref,
        bool required = false,
      ]) {
        for (final n in slides) {
          if (!slideNumbers.contains(n)) {
            problems.add("${l.id} $where: Folie $n fehlt");
          }
        }
        if (ref != null &&
            !(course?.materials.any((m) => m.id == ref.materialId) ?? false)) {
          problems.add("${l.id} $where: Material ${ref.materialId} fehlt");
        }
        if (required && slides.isEmpty && ref == null) {
          problems.add("${l.id} $where: ohne Fundstelle");
        }
      }

      for (final id in [...l.epochIds]) {
        if (data.epoch(id) == null) problems.add("${l.id}: Epoche $id fehlt");
      }
      for (final id in l.themeIds) {
        if (data.theme(id) == null) problems.add("${l.id}: Thema $id fehlt");
      }
      for (final s in l.sections) {
        slidesExist(s.title, s.slides, s.ref, true);
      }
      final mentioned = <String>{};
      for (final m in l.mentions) {
        if (data.entry(m.entryId) == null) {
          problems.add("${l.id}: erwähnter Eintrag ${m.entryId} fehlt");
        }
        if (!mentioned.add(m.entryId)) {
          problems.add("${l.id}: ${m.entryId} doppelt erwähnt");
        }
        slidesExist(m.entryId, m.slides, m.ref, true);
      }
      for (final list in l.lists) {
        slidesExist(list.id, list.slides, list.ref, true);
        if (list.items.length < 2) problems.add("${list.id}: zu kurz");
      }
      for (final q in l.questions) {
        slidesExist(q.id, q.slides, q.ref, true);
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

    if (!data.courses.any((c) => c.kind == CourseKind.lecture)) {
      problems.add("Keine Vorlesung vorhanden");
    }

    for (final course in data.courses) {
      for (final s in course.sections) {
        if (s.ref == null ||
            !course.materials.any((m) => m.id == s.ref!.materialId)) {
          problems.add("${course.id} ${s.title}: Material fehlt");
        }
      }
      for (final part in course.outline) {
        if (part.epochId != null && data.epoch(part.epochId!) == null) {
          problems.add("Gliederung ${part.part}: Epoche fehlt");
        }
        for (final topic in part.topics) {
          if (topic.lectureId != null &&
              data.lecture(topic.lectureId!) == null) {
            problems.add("Gliederung ${topic.title}: Vorlesung fehlt");
          }
          if (topic.themeId != null && data.theme(topic.themeId!) == null) {
            problems.add("Gliederung ${topic.title}: Thema fehlt");
          }
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

  static MaterialRef? _ref(Object? raw) {
    if (raw is! Map) return null;
    return MaterialRef(raw["material"] as String, raw["at"] as String?);
  }

  static LectureSection _section(Map<String, dynamic> s) {
    return LectureSection(
      title: s["title"] as String,
      slides: _ints(s["slides"]),
      ref: _ref(s["ref"]),
      points: _strings(s["points"]),
      supplement: s["supplement"] as String?,
    );
  }

  static Course _course(Map<String, dynamic> json) {
    return Course(
      id: json["id"] as String,
      kind: CourseKind.parse(json["kind"]),
      title: json["title"] as String,
      lecturer: json["lecturer"] as String?,
      semester: json["semester"] as String?,
      sections: [for (final s in _list(json["sections"])) _section(s)],
      materials: [
        for (final m in _list(json["materials"]))
          CourseMaterial(
            id: m["id"] as String,
            short: m["short"] as String,
            title: m["title"] as String,
            category: m["category"] as String,
            description: m["description"] as String,
          ),
      ],
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
                  themeId: t["theme"] as String?,
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
          EntryNote(
            kind: NoteKind.parse(n["kind"]),
            text: n["text"] as String,
            ref: _ref(n["ref"]),
          ),
      ],
      references: _strings(json["references"]),
    );
  }

  static Lecture _lecture(Map<String, dynamic> json, Course course) {
    final id = json["id"] as String;

    return Lecture(
      id: id,
      courseId: course.id,
      kind: course.kind,
      number: json["number"] as int,
      title: json["title"] as String,
      date: json["date"] as String?,
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
      sections: [for (final s in _list(json["sections"])) _section(s)],
      mentions: [
        for (final m in _list(json["mentions"]))
          LectureMention(
            lectureId: id,
            entryId: m["entry"] as String,
            slides: _ints(m["slides"]),
            ref: _ref(m["ref"]),
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
            ref: _ref(l["ref"]),
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
            ref: _ref(q["ref"]),
            entryIds: _strings(q["entries"]),
          ),
      ],
    );
  }
}
