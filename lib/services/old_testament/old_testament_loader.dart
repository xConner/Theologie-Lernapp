import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/old_testament/old_testament.dart';

/// Lädt die Inhalte aus `assets/old_testament/` und prüft sie.
///
/// Aufbau:
/// * `course.json`: Vorlesung (`course`), weitere Veranstaltungen
///   (`courses`, z. B. die Übung Bibelkunde) und Liste der Einheiten-Dateien
///   (`units/einheit-NN.json` bzw. `units/bibelkunde-NN.json`, eine je
///   hochgeladener Foliendatei)
/// * `terms.json`: Fachbegriffe aller Einheiten (je Begriff ein Eintrag)
///
/// Ein Fehler in den Daten (doppelte oder falsch gebildete ID, Folie, die es
/// in der Einheit nicht gibt, unbekannter Begriff) führt zu einer
/// [FormatException] mit allen gefundenen Problemen.
class OldTestamentLoader {
  OldTestamentLoader._();

  static const String dir = "assets/old_testament";

  static Future<OldTestamentData>? _cached;

  /// Einmal je App-Start geladen; ein fehlgeschlagener Versuch wird nicht
  /// gemerkt, damit „Erneut versuchen“ wirkt.
  static Future<OldTestamentData> load({AssetBundle? bundle}) {
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

  static Future<OldTestamentData> _load(AssetBundle bundle) async {
    Future<Map<String, dynamic>> read(String name) async {
      final raw = await bundle.loadString("$dir/$name");
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final course = await read("course.json");

    return parse(
      course: course,
      terms: await read("terms.json"),
      units: [for (final file in _strings(course["units"])) await read(file)],
    );
  }

  static OldTestamentData parse({
    required Map<String, dynamic> course,
    required Map<String, dynamic> terms,
    required List<Map<String, dynamic>> units,
  }) {
    OldTestamentCourse info(Map<String, dynamic> c) => OldTestamentCourse(
      title: c["title"] as String,
      lecturer: c["lecturer"] as String?,
      semester: c["semester"] as String?,
    );

    final others = <OtCourseId, OldTestamentCourse>{};
    final errors = <String>[];
    final rawCourses = course["courses"] as Map<String, dynamic>? ?? const {};
    for (final e in rawCourses.entries) {
      final id = OtCourseId.tryParse(e.key);
      if (id == null || id == OtCourseId.lecture) {
        errors.add("Unbekannte Veranstaltung: ${e.key}");
        continue;
      }
      others[id] = info(e.value as Map<String, dynamic>);
    }

    final data = OldTestamentData(
      course: info(course["course"] as Map<String, dynamic>),
      otherCourses: others,
      terms: [for (final t in _list(terms["terms"])) _term(t)],
      units: [for (final u in units) _unit(u, errors)],
    );

    errors.addAll(validate(data));

    if (errors.isNotEmpty) {
      throw FormatException(
        "Inhalte zum Alten Testament fehlerhaft:\n${errors.join("\n")}",
      );
    }

    return data;
  }

  static final RegExp _unitId = RegExp(r'^([a-z]+)\.(\d{2})$');
  static final RegExp _termId = RegExp(r'^term\.[a-z0-9_]+$');

  /// Verweis auf eine Perikope der Perikopenliste (`BookPericope.key`).
  static final RegExp _pericopeKey = RegExp(
    r'^[1-4]?[A-Za-z]+\|[a-z0-9_]+\|\d+,\d+$',
  );

  /// Alle Probleme der Daten (leer = in Ordnung).
  static List<String> validate(OldTestamentData data) {
    final errors = <String>[];
    final ids = <String>{};

    void unique(String id) {
      if (!ids.add(id)) errors.add("Doppelte ID: $id");
    }

    for (final t in data.allTerms) {
      unique(t.id);
      if (!_termId.hasMatch(t.id)) errors.add("Ungültige Begriffs-ID: ${t.id}");
      if (t.definition.trim().isEmpty) errors.add("${t.id}: ohne Erklärung");
      for (final c in t.confusableIds) {
        if (data.term(c) == null) errors.add("${t.id}: unbekannter $c");
      }
      if (data.unitsOfTerm(t.id).isEmpty) {
        errors.add("${t.id}: in keiner Einheit genannt");
      }
    }

    final numbers = <(OtCourseId, int)>{};

    for (final u in data.allUnits) {
      unique(u.id);

      final match = _unitId.firstMatch(u.id);
      if (match == null ||
          match.group(1) != u.course.unitPrefix ||
          int.parse(match.group(2)!) != u.number) {
        errors.add("${u.id}: ID passt nicht zu Nummer ${u.number}");
      }
      if (!data.courses.containsKey(u.course)) {
        errors.add("${u.id}: Veranstaltung ${u.course.name} fehlt");
      }
      if (!numbers.add((u.course, u.number))) {
        errors.add("Doppelte ${u.course.unitName} ${u.number}");
      }

      final short =
          "${u.course.shortPrefix}${u.number.toString().padLeft(2, "0")}";
      final slideNumbers = {for (final s in u.slides) s.number};

      if (slideNumbers.length != u.slides.length) {
        errors.add("${u.id}: doppelte Foliennummer");
      }

      void slides(String what, List<int> list, {bool required = true}) {
        if (required && list.isEmpty) errors.add("$what: ohne Folienangabe");
        for (final n in list) {
          if (!slideNumbers.contains(n)) {
            errors.add("$what: Folie $n gibt es in ${u.id} nicht");
          }
        }
      }

      void prefixed(String id, String kind) {
        unique(id);
        if (!id.startsWith("$kind.$short.")) {
          errors.add("$id: muss mit „$kind.$short.“ beginnen");
        }
      }

      for (final k in u.keyPoints) {
        slides("${u.id} Kernpunkt „${k.text}“", k.slides);
      }
      for (final s in u.sections) {
        slides("${u.id} Abschnitt „${s.title}“", s.slides);
      }
      for (final c in u.connections) {
        slides(
          "${u.id} Zusammenhang „${c.text}“",
          c.slides,
          required: !c.supplement,
        );
      }
      for (final l in u.literature) {
        slides("${u.id} Literatur „${l.text}“", l.slides);
      }

      final mentioned = <String>{};
      for (final m in u.terms) {
        if (data.term(m.termId) == null) {
          errors.add("${u.id}: unbekannter Begriff ${m.termId}");
        }
        if (!mentioned.add(m.termId)) {
          errors.add("${u.id}: Begriff ${m.termId} doppelt");
        }
        slides("${u.id} ${m.termId}", m.slides);
      }

      for (final p in u.passages) {
        prefixed(p.id, "passage");
        slides(p.id, p.slides);
        for (final k in p.pericopeKeys) {
          if (!_pericopeKey.hasMatch(k)) {
            errors.add("${p.id}: ungültiger Perikopenverweis $k");
          }
        }
        if (p.pericopeKeys.toSet().length != p.pericopeKeys.length) {
          errors.add("${p.id}: Perikope doppelt zugeordnet");
        }
      }

      for (final l in u.lists) {
        prefixed(l.id, "list");
        slides(l.id, l.slides);
        if (l.details.isNotEmpty && l.details.length != l.items.length) {
          errors.add("${l.id}: Angaben passen nicht zu den Punkten");
        }
        if (l.items.length < 2) errors.add("${l.id}: weniger als zwei Punkte");
        if (l.items.toSet().length != l.items.length) {
          errors.add("${l.id}: doppelter Punkt");
        }
      }

      for (final q in u.questions) {
        prefixed(q.id, "q");
        slides(q.id, q.slides);
        final options = [
          q.answer,
          ...q.distractors,
        ].map((o) => o.trim().toLowerCase()).toSet();
        if (q.distractors.length < 2) {
          errors.add("${q.id}: weniger als zwei Ablenker");
        }
        if (options.length != q.distractors.length + 1) {
          errors.add("${q.id}: Antwortmöglichkeiten nicht verschieden");
        }
        if (q.explanation.trim().isEmpty) {
          errors.add("${q.id}: ohne Erklärung");
        }
        for (final t in q.termIds) {
          if (data.term(t) == null) errors.add("${q.id}: unbekannter $t");
        }
      }

      for (final r in u.relatedUnitIds) {
        if (data.unit(r) == null || r == u.id) {
          errors.add("${u.id}: unbekannte verwandte Einheit $r");
        }
      }

      // Geteilt wird nur, was eine andere Einheit selbst enthält.
      final shared = <String>{};
      for (final id in u.sharedIds) {
        if (!shared.add(id)) errors.add("${u.id}: $id doppelt geteilt");
        if (!data.isShareable(id)) {
          errors.add("${u.id}: unbekannter geteilter Inhalt $id");
        } else if (_ownerOf(data, id) == u.id) {
          errors.add("${u.id}: $id gehört zur Einheit selbst");
        }
      }
    }

    return errors;
  }

  static String? _ownerOf(OldTestamentData data, String id) =>
      data.question(id)?.unitId ??
      data.list(id)?.unitId ??
      data.unitOfPassage(id)?.id;

  // ==========================
  // EINLESEN
  // ==========================

  static List<Map<String, dynamic>> _list(Object? raw) {
    if (raw == null) return const [];
    return [for (final e in raw as List) e as Map<String, dynamic>];
  }

  static List<String> _strings(Object? raw) =>
      raw == null ? const [] : [for (final e in raw as List) e as String];

  static List<int> _ints(Object? raw) =>
      raw == null ? const [] : [for (final e in raw as List) e as int];

  static Ambiguity? _unclear(Object? raw) =>
      raw is String ? Ambiguity(raw) : null;

  static Term _term(Map<String, dynamic> json) {
    return Term(
      id: json["id"] as String,
      name: json["name"] as String,
      hebrew: json["hebrew"] as String?,
      transliteration: json["transliteration"] as String?,
      aliases: _strings(json["aliases"]),
      definition: json["definition"] as String,
      fromSlides: json["fromSlides"] == true,
      supplement: json["supplement"] as String?,
      confusableIds: _strings(json["confusable"]),
    );
  }

  static LectureUnit _unit(Map<String, dynamic> json, List<String> errors) {
    final id = json["id"] as String;
    final course = json["course"] == null
        ? OtCourseId.lecture
        : OtCourseId.tryParse(json["course"]);
    if (course == null) errors.add("$id: unbekannte Veranstaltung");

    return LectureUnit(
      id: id,
      course: course ?? OtCourseId.lecture,
      number: json["number"] as int,
      title: json["title"] as String,
      scope: json["scope"] as String?,
      file: json["file"] as String?,
      slides: [
        for (final s in _list(json["slides"]))
          UnitSlide(
            number: s["number"] as int,
            title: s["title"] as String,
            image: s["image"] as String?,
            text: s["text"] as String,
            highlights: _strings(s["highlights"]),
            figure: s["figure"] as String?,
          ),
      ],
      keyPoints: [
        for (final k in _list(json["keyPoints"]))
          KeyPoint(text: k["text"] as String, slides: _ints(k["slides"])),
      ],
      sections: [
        for (final s in _list(json["sections"]))
          UnitSection(
            title: s["title"] as String,
            slides: _ints(s["slides"]),
            points: _strings(s["points"]),
            supplement: s["supplement"] as String?,
            unclear: _unclear(s["unclear"]),
          ),
      ],
      terms: [
        for (final m in _list(json["terms"]))
          TermMention(
            termId: m["term"] as String,
            slides: _ints(m["slides"]),
            text: m["text"] as String?,
          ),
      ],
      passages: [
        for (final p in _list(json["passages"]))
          PassageRef(
            id: p["id"] as String,
            label: p["label"] as String,
            open: p["open"] as String?,
            context: p["context"] as String,
            clue: p["clue"] as String?,
            slides: _ints(p["slides"]),
            pericopeKeys: _strings(p["pericopes"]),
          ),
      ],
      connections: [
        for (final c in _list(json["connections"]))
          Connection(
            text: c["text"] as String,
            slides: _ints(c["slides"]),
            supplement: c["supplement"] == true,
          ),
      ],
      literature: [
        for (final l in _list(json["literature"]))
          LiteratureRef(text: l["text"] as String, slides: _ints(l["slides"])),
      ],
      lists: [
        for (final l in _list(json["lists"]))
          RecallList(
            id: l["id"] as String,
            unitId: id,
            title: l["title"] as String,
            prompt: l["prompt"] as String,
            slides: _ints(l["slides"]),
            items: _strings(l["items"]),
            details: _strings(l["details"]),
            ordered: l["ordered"] == true,
          ),
      ],
      questions: [
        for (final q in _list(json["questions"]))
          CuratedQuestion(
            id: q["id"] as String,
            unitId: id,
            prompt: q["prompt"] as String,
            answer: q["answer"] as String,
            distractors: _strings(q["distractors"]),
            explanation: q["explanation"] as String,
            slides: _ints(q["slides"]),
            termIds: _strings(q["terms"]),
          ),
      ],
      relatedUnitIds: _strings(json["related"]),
      sharedIds: _strings(json["shared"]),
    );
  }
}
