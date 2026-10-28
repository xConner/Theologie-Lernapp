import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/church_history/church_history.dart' as ch;
import '../../models/history/history_course.dart';
import '../../models/old_testament/old_testament.dart';
import '../lecture_materials/lecture_materials.dart';

/// Baut die Sicht „Geschichte Schritt für Schritt“ aus den Daten der
/// Bereiche und prüft sie.
///
/// * Kirchengeschichte: `assets/church_history/learning_path.json` ordnet
///   vorhandene Epochen, Personen und Ereignisse in Lernschritte. Alle
///   Angaben kommen aus den Einträgen und den Erwähnungen der
///   Veranstaltungen.
/// * Altes Testament: `assets/old_testament/history.json` enthält Eckdaten,
///   Zeiträume, Personen und Mächte, jede Aussage mit Einheit bzw. Sitzung
///   und Folie. Die Sicht einer Veranstaltung enthält nur, was deren Folien
///   sagen; abweichende Angaben der anderen stehen in der Anmerkung.
class HistoryCourseLoader {
  HistoryCourseLoader._();

  static const String churchHistoryPath =
      "assets/church_history/learning_path.json";
  static const String oldTestamentPath = "assets/old_testament/history.json";

  static Future<Map<String, dynamic>> _read(
    String path,
    AssetBundle? bundle,
  ) async {
    final raw = await (bundle ?? LectureMaterials.instance.bundle).loadString(
      path,
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<HistoryCourse> loadChurchHistory(
    ch.ChurchHistoryData data, {
    AssetBundle? bundle,
  }) async => churchHistory(data, await _read(churchHistoryPath, bundle));

  static Future<HistoryCourse> loadOldTestament(
    OldTestamentData data, {
    AssetBundle? bundle,
  }) async => oldTestament(data, await _read(oldTestamentPath, bundle));

  // ==========================
  // KIRCHENGESCHICHTE
  // ==========================

  static HistoryCourse churchHistory(
    ch.ChurchHistoryData data,
    Map<String, dynamic> json,
  ) {
    final problems = <String>[];
    final items = <HistoryItem>[];
    final sources = data.seminar == null
        ? "Vorlesung"
        : "Vorlesung und Proseminar";

    String sourceOf(ch.LectureMention m) =>
        data.sourceLabel(m.lectureId, m.slides, m.ref);

    for (final epoch in data.epochs) {
      final lecture = data.lectures
          .where(
            (l) => l.slides.any((s) => epoch.lectureSlides.contains(s.number)),
          )
          .firstOrNull;
      items.add(
        HistoryItem(
          id: epoch.id,
          kind: HistoryItemKind.period,
          name: epoch.title,
          dating: epoch.dating,
          statements: [
            HistoryStatement(
              text:
                  "${epoch.dating.label}: ${epoch.characterization}"
                  "${data.epochNote == null ? "" : " (nur grobe Richtwerte)"}",
              source: lecture == null
                  ? "Vorlesung"
                  : data.sourceLabel(lecture.id, epoch.lectureSlides, null),
            ),
            HistoryStatement(
              text: epoch.summary,
              source: "Ergänzung",
              supplement: true,
            ),
          ],
          significance: epoch.characterization,
        ),
      );
    }

    for (final e in data.entries) {
      final kind = switch (e.type) {
        ch.EntryType.person => HistoryItemKind.person,
        ch.EntryType.event => HistoryItemKind.event,
        _ => null,
      };
      if (kind == null) continue;

      final mentions = [
        for (final m in data.mentionsOf(e.id))
          if (m.text.trim().isNotEmpty) m,
      ];

      items.add(
        HistoryItem(
          id: e.id,
          kind: kind,
          name: e.name,
          timelessName: HistoryItem.revealsDate(e.name) ? e.summary : e.name,
          dating: e.dating,
          periodId: e.epochIds.length == 1 ? e.epochIds.single : null,
          clue: e.clue,
          statements: [
            for (final m in mentions)
              HistoryStatement(text: m.text, source: sourceOf(m)),
            HistoryStatement(
              text: e.summary,
              source: "Ergänzung",
              supplement: true,
            ),
          ],
          significance: e.significance,
          relatedIds: [
            for (final r in data.relatedOf(e.id))
              if (r.type == ch.EntryType.person || r.type == ch.EntryType.event)
                r.id,
          ],
          hasDetail: true,
        ),
      );
    }

    final byId = {for (final i in items) i.id: i};

    final lessons = _lessons(json, byId, problems);
    final sequences = _sequences(
      json,
      byId,
      problems,
      sourceOf: (raw) {
        final unit = raw["unit"] as String?;
        if (unit == null || data.lecture(unit) == null) {
          problems.add("Folge ${raw["id"]}: unbekannte Vorlesung $unit");
          return "";
        }
        return data.sourceLabel(unit, _ints(raw["slides"]), null);
      },
    );

    for (final l in json["lessons"] as List? ?? const []) {
      final unit = (l as Map)["unit"];
      if (unit != null && data.lecture(unit as String) == null) {
        problems.add("Lernschritt ${l["id"]}: unbekannte Vorlesung $unit");
      }
    }

    _requireComplete(items, lessons, problems);

    return _checked(
      HistoryCourse(
        title: "Kirchengeschichte",
        sourceName: sources,
        items: items,
        lessons: lessons,
        sequences: sequences,
      ),
      problems,
    );
  }

  // ==========================
  // ALTES TESTAMENT
  // ==========================

  /// Sicht der Veranstaltung von [data] (`data.courseId`).
  static HistoryCourse oldTestament(
    OldTestamentData data,
    Map<String, dynamic> json,
  ) {
    final problems = <String>[];
    final course = data.courseId;
    final items = <HistoryItem>[];

    final tracks = [
      for (final t in _list(json["tracks"]))
        HistoryTrack(id: t["id"] as String, title: t["title"] as String),
    ];

    final allIds = <String>{};

    for (final raw in _list(json["items"])) {
      final id = raw["id"] as String? ?? "";
      if (!allIds.add(id)) problems.add("Doppelte ID: $id");
      if (!RegExp(r'^(period|person|group|event)\.[a-z0-9_]+$').hasMatch(id)) {
        problems.add("Ungültige ID: $id");
      }
      if (data.term(id) != null || data.isShareable(id)) {
        problems.add("ID schon vergeben: $id");
      }

      final statements = <HistoryStatement>[];
      var inCourse = false;

      for (final s in _list(raw["statements"])) {
        final unit = data.unit(s["unit"] as String? ?? "");
        final slides = _ints(s["slides"]);
        if (unit == null) {
          problems.add("$id: unbekannte Einheit ${s["unit"]}");
          continue;
        }
        if (slides.isEmpty || slides.any((n) => unit.slide(n) == null)) {
          problems.add("$id: Folie fehlt in ${unit.id}: $slides");
        }
        if (unit.course != course) continue;
        inCourse = true;
        statements.add(
          HistoryStatement(
            text: s["text"] as String,
            source: data.sourceLabel(unit.id, slides),
          ),
        );
      }

      if (statements.isEmpty && _list(raw["statements"]).isEmpty) {
        problems.add("$id: ohne Folienangabe");
      }

      HistoricalDating? dating;
      try {
        final byCourse = raw["datingBy"];
        dating = byCourse is Map && byCourse[course.name] != null
            ? HistoricalDating.fromJson(byCourse[course.name])
            : HistoricalDating.fromJson(raw["dating"]);
      } on FormatException catch (e) {
        problems.add("$id: ${e.message}");
      }

      final names = raw["nameBy"];
      final name = names is Map && names[course.name] is String
          ? names[course.name] as String
          : raw["name"] as String;

      HistoryStatement? consequence;
      final byCourse = raw["consequenceBy"];
      final rawConsequence = byCourse is Map && byCourse[course.name] is Map
          ? byCourse[course.name] as Map
          : raw["consequence"] as Map?;
      if (rawConsequence != null) {
        final unit = data.unit(rawConsequence["unit"] as String? ?? "");
        final slides = _ints(rawConsequence["slides"]);
        if (unit == null || slides.any((n) => unit.slide(n) == null)) {
          problems.add("$id: Folge ohne gültige Folie");
        } else if (unit.course == course) {
          consequence = HistoryStatement(
            text: rawConsequence["text"] as String,
            source: data.sourceLabel(unit.id, slides),
          );
        }
      }

      final track = raw["track"] as String?;
      if (track != null && !tracks.any((t) => t.id == track)) {
        problems.add("$id: unbekannte Spur $track");
      }

      if (!inCourse) continue;

      items.add(
        HistoryItem(
          id: id,
          kind: HistoryItemKind.parse(raw["kind"]),
          name: name,
          dating: dating,
          periodId: raw["period"] as String?,
          trackId: track,
          role: raw["role"] as String?,
          clue: raw["clue"] as String?,
          statements: statements,
          consequence: consequence,
          relatedIds: _strings(raw["related"]),
        ),
      );
    }

    for (final raw in _list(json["items"])) {
      for (final r in [
        ..._strings(raw["related"]),
        ?raw["period"] as String?,
      ]) {
        if (!allIds.contains(r)) problems.add("${raw["id"]}: unbekannt $r");
      }
    }

    // Zeiträume und Verknüpfungen nur innerhalb der Sicht.
    final inView = {for (final i in items) i.id};
    final viewItems = [
      for (final i in items)
        HistoryItem(
          id: i.id,
          kind: i.kind,
          name: i.name,
          dating: i.dating,
          periodId: inView.contains(i.periodId) ? i.periodId : null,
          trackId: i.trackId,
          role: i.role,
          clue: i.clue,
          statements: i.statements,
          consequence: i.consequence,
          relatedIds: [
            for (final r in i.relatedIds)
              if (inView.contains(r)) r,
          ],
        ),
    ];

    final byId = {for (final i in viewItems) i.id: i};

    final lessons = _lessons(json, byId, problems, skipMissing: allIds);
    final sequences = [
      for (final s in _sequences(
        json,
        byId,
        problems,
        skipMissing: allIds,
        sourceOf: (raw) {
          final unit = data.unit(raw["unit"] as String? ?? "");
          if (unit == null) {
            problems.add("Folge ${raw["id"]}: unbekannte Einheit");
            return "";
          }
          return unit.course == course
              ? data.sourceLabel(unit.id, _ints(raw["slides"]))
              : "";
        },
      ))
        if (s.source.isNotEmpty) s,
    ];

    final allLessonItems = {
      for (final l in _list(json["lessons"])) ..._strings(l["items"]),
    };
    for (final id in allIds) {
      if (!allLessonItems.contains(id)) {
        problems.add("$id gehört zu keinem Lernschritt");
      }
    }

    return _checked(
      HistoryCourse(
        title: data.courseId == OtCourseId.lecture
            ? "Altes Testament"
            : "Grundlagen der Bibelkunde",
        sourceName: data.courseId == OtCourseId.lecture ? "Vorlesung" : "Übung",
        items: viewItems,
        lessons: lessons,
        sequences: sequences,
        tracks: [
          for (final t in tracks)
            if (viewItems.any((i) => i.trackId == t.id)) t,
        ],
      ),
      problems,
    );
  }

  // ==========================
  // GEMEINSAM
  // ==========================

  /// Lernschritte; Inhalte, die in dieser Sicht fehlen ([skipMissing] =
  /// bekannte IDs der anderen Veranstaltung), fallen heraus, leere
  /// Lernschritte ganz.
  static List<HistoryLesson> _lessons(
    Map<String, dynamic> json,
    Map<String, HistoryItem> byId,
    List<String> problems, {
    Set<String> skipMissing = const {},
  }) {
    final lessons = <HistoryLesson>[];
    final lessonIds = <String>{};
    final seen = <String>{};

    for (final raw in _list(json["lessons"])) {
      final id = raw["id"] as String? ?? "";
      if (!RegExp(r'^lesson\.[a-z0-9_]+$').hasMatch(id)) {
        problems.add("Ungültige ID: $id");
      }
      if (!lessonIds.add(id)) problems.add("Doppelter Lernschritt: $id");

      final itemIds = <String>[];
      for (final itemId in _strings(raw["items"])) {
        if (!seen.add(itemId)) {
          problems.add("$itemId steht in mehreren Lernschritten");
        }
        if (byId.containsKey(itemId)) {
          itemIds.add(itemId);
        } else if (!skipMissing.contains(itemId)) {
          problems.add("Lernschritt $id: unbekannter Inhalt $itemId");
        }
      }

      if (_strings(raw["items"]).length > 4) {
        problems.add("Lernschritt $id: mehr als vier neue Inhalte");
      }

      if (itemIds.isEmpty) continue;

      lessons.add(
        HistoryLesson(
          id: id,
          part: raw["part"] as String? ?? "",
          title: raw["title"] as String? ?? id,
          itemIds: itemIds,
        ),
      );
    }

    return lessons;
  }

  static List<HistorySequence> _sequences(
    Map<String, dynamic> json,
    Map<String, HistoryItem> byId,
    List<String> problems, {
    required String Function(Map<String, dynamic> raw) sourceOf,
    Set<String> skipMissing = const {},
  }) {
    final result = <HistorySequence>[];

    for (final raw in _list(json["sequences"])) {
      final id = raw["id"] as String? ?? "";
      final ids = <String>[];
      for (final itemId in _strings(raw["items"])) {
        final item = byId[itemId];
        if (item != null) {
          ids.add(itemId);
        } else if (!skipMissing.contains(itemId)) {
          problems.add("Folge $id: unbekannter Inhalt $itemId");
        }
      }

      // Die Folge muss zur Datierung passen, sonst wäre „folgt auf“ falsch.
      for (var i = 1; i < ids.length; i++) {
        if (isClearlyBefore(byId[ids[i]]!, byId[ids[i - 1]]!)) {
          problems.add("Folge $id: ${ids[i]} liegt vor ${ids[i - 1]}");
        }
      }

      final source = sourceOf(raw);
      if (ids.length < 3) continue;

      result.add(
        HistorySequence(
          id: id,
          title: raw["title"] as String? ?? id,
          source: source,
          itemIds: ids,
        ),
      );
    }

    return result;
  }

  static void _requireComplete(
    List<HistoryItem> items,
    List<HistoryLesson> lessons,
    List<String> problems,
  ) {
    final inLessons = {for (final l in lessons) ...l.itemIds};
    for (final i in items) {
      if (!inLessons.contains(i.id)) {
        problems.add("${i.id} gehört zu keinem Lernschritt");
      }
    }
  }

  static HistoryCourse _checked(HistoryCourse course, List<String> problems) {
    for (final item in course.items) {
      if (item.periodId != null && course.item(item.periodId!) == null) {
        problems.add("${item.id}: unbekannter Zeitraum ${item.periodId}");
      }
      if (item.kind == HistoryItemKind.person && item.clue == null) {
        problems.add("${item.id}: Person ohne Kennzeichnung (clue)");
      }
    }

    if (problems.isNotEmpty) {
      throw FormatException(
        "Geschichte Schritt für Schritt: ungültige Daten\n"
        "${problems.join("\n")}",
      );
    }

    return course;
  }

  static List<Map<String, dynamic>> _list(Object? raw) => [
    for (final e in raw as List? ?? const []) Map<String, dynamic>.from(e),
  ];

  static List<String> _strings(Object? raw) => [
    for (final e in raw as List? ?? const []) e as String,
  ];

  static List<int> _ints(Object? raw) => [
    for (final e in raw as List? ?? const []) e as int,
  ];
}
