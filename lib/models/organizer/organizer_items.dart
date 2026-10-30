import 'dart:math';

import '../../services/organizer/org_dates.dart';
import '../../services/organizer/recurrence.dart';

// Datenmodell der Studiumsorganisation (Notizen, Kalender, Aufgaben).
//
// Alles liegt als einzelne Dokumente in einer Sammlung
// (`users/{uid}/organizer/{id}`, Gast: lokal), getrennt von allen
// Lernständen. Jedes Dokument trägt seine Art (`kind`) und wird beim
// Speichern nur mit den geänderten Feldern geschrieben, damit gleichzeitige
// Änderungen verschiedener Felder auf zwei Geräten beide erhalten bleiben.

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

String _text(Object? v) => v is String ? v : "";

int? _int(Object? v) => v is num ? v.toInt() : null;

List<String> _strings(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is String && e.trim().isNotEmpty) e.trim(),
];

/// 32-Bit-Multiplikation, die im Web (JavaScript-Zahlen) und nativ
/// dasselbe ergibt – sonst hätten feste Kennungen je Plattform andere Werte.
int _mul32(int a, int b) {
  final high = (a >> 16) & 0xffff;
  final low = a & 0xffff;
  return (low * b + (((high * b) & 0xffff) << 16)) & 0xffffffff;
}

/// Neue, geräteübergreifend eindeutige Dokumentkennung.
class OrgIds {
  OrgIds._();

  static final Random _random = Random();

  static String create(String prefix, {DateTime? now}) {
    final time = (now ?? DateTime.now()).microsecondsSinceEpoch.toRadixString(
      36,
    );
    final rand = List.generate(
      6,
      (_) => "abcdefghijklmnopqrstuvwxyz0123456789"[_random.nextInt(36)],
    ).join();
    return "${prefix}_$time$rand";
  }

  /// Feste Kennung aus einem Schlüssel (z. B. übernommene Aufgaben): Zwei
  /// Geräte, die dieselbe Aufgabe übernehmen, schreiben dasselbe Dokument –
  /// so entstehen keine Duplikate.
  static String stable(String prefix, String key) {
    // FNV-1a 64 Bit, als zwei 32-Bit-Hälften (läuft auch im Web genau).
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    for (final unit in key.codeUnits) {
      h1 = _mul32(h1 ^ unit, 0x01000193);
      h2 = (_mul32(h2 ^ unit, 0x0100019d) + 0x9e37) & 0xffffffff;
    }
    final slug = key
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
        .replaceAll(RegExp(r"^-+|-+$"), "");
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    return "${prefix}_${short}_${h1.toRadixString(36)}${h2.toRadixString(36)}";
  }
}

/// Fingerabdruck eines Textes (für den Abgleich mit Seminarplänen).
String orgFingerprint(String text) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r"\s+"), " ").trim();
  var h = 0x811c9dc5;
  for (final unit in normalized.codeUnits) {
    h = _mul32(h ^ unit, 0x01000193);
  }
  return h.toRadixString(36);
}

/// Studium oder Privat – eine Unterscheidung, kein zweites System.
enum OrgGroup {
  study("Studium"),
  private("Privat");

  final String label;

  const OrgGroup(this.label);

  static OrgGroup parse(Object? value) =>
      value == "private" ? OrgGroup.private : OrgGroup.study;
}

enum OrgPriority {
  low("Niedrig"),
  normal("Normal"),
  high("Hoch");

  final String label;

  const OrgPriority(this.label);

  static OrgPriority parse(Object? value) => switch (value) {
    "low" => OrgPriority.low,
    "high" => OrgPriority.high,
    _ => OrgPriority.normal,
  };
}

/// Verknüpfung mit App-Inhalten oder einem anderen Eintrag.
class OrgLink {
  /// `bible` (Bibelstelle), `app` (Bereich der App, Pfad wie
  /// `AppDeepLink`), `task`, `event`, `note` (Eintrag der Organisation),
  /// `session` (Sitzung einer Lehrveranstaltung der App).
  final String type;
  final String target;
  final String label;

  const OrgLink({
    required this.type,
    required this.target,
    required this.label,
  });

  static const Set<String> types = {
    "bible",
    "app",
    "task",
    "event",
    "note",
    "session",
  };

  bool sameTarget(OrgLink other) =>
      other.type == type && other.target == target;

  Map<String, dynamic> toMap() => {
    "type": type,
    "target": target,
    "label": label,
  };

  static OrgLink? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = _str(raw["type"]);
    final target = _str(raw["target"]);
    if (type == null || target == null || !types.contains(type)) return null;
    return OrgLink(
      type: type,
      target: target,
      label: _str(raw["label"]) ?? target,
    );
  }

  static List<OrgLink> listFrom(Object? raw) => [
    if (raw is List)
      for (final l in raw) ?OrgLink.fromMap(l),
  ];
}

/// Herkunft eines übernommenen Eintrags (Seminarplan, Leseplan).
class OrgSource {
  /// Quelle, z. B. `ch-seminar` (Proseminar) oder `text_…` (eingefügter
  /// Seminarplan).
  final String sourceId;

  /// Stabiler Schlüssel innerhalb der Quelle, z. B. `seminar.03:task:1`.
  final String key;

  /// Fingerabdruck der übernommenen Fassung.
  final String fingerprint;

  /// Vom Nutzer bearbeitet: Ein erneuter Abgleich überschreibt nichts.
  final bool edited;

  const OrgSource({
    required this.sourceId,
    required this.key,
    required this.fingerprint,
    this.edited = false,
  });

  OrgSource copyWith({String? fingerprint, bool? edited}) => OrgSource(
    sourceId: sourceId,
    key: key,
    fingerprint: fingerprint ?? this.fingerprint,
    edited: edited ?? this.edited,
  );

  Map<String, dynamic> toMap() => {
    "sourceId": sourceId,
    "key": key,
    "fingerprint": fingerprint,
    "edited": edited,
  };

  static OrgSource? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final sourceId = _str(raw["sourceId"]);
    final key = _str(raw["key"]);
    if (sourceId == null || key == null) return null;
    return OrgSource(
      sourceId: sourceId,
      key: key,
      fingerprint: _text(raw["fingerprint"]),
      edited: raw["edited"] == true,
    );
  }
}

/// Gemeinsame Felder aller Einträge.
abstract class OrgItem {
  String get id;
  String get kind;
  int get updatedAt;
  Map<String, dynamic> toMap();
}

/// Zuordnung: eine Lehrveranstaltung oder ein Lebensbereich. Eine Liste
/// für Aufgaben, Termine und Notizen, damit nichts doppelt angelegt wird.
class OrgArea implements OrgItem {
  @override
  final String id;
  final String name;
  final OrgGroup group;

  /// Index in [OrgPalette].
  final int color;

  /// Veranstaltung im Stundenplan (`TimetableEntry.courseId`).
  final String? timetableCourseId;

  /// Zugehöriger Bereich der App (Pfad wie `AppDeepLink` oder ein
  /// Bereich ohne Deep Link, siehe `OrgAppTargets`).
  final String? appLink;

  final bool archived;
  final int order;
  @override
  final int updatedAt;

  const OrgArea({
    required this.id,
    required this.name,
    this.group = OrgGroup.study,
    this.color = 0,
    this.timetableCourseId,
    this.appLink,
    this.archived = false,
    this.order = 100,
    this.updatedAt = 0,
  });

  @override
  String get kind => "area";

  OrgArea copyWith({
    String? name,
    OrgGroup? group,
    int? color,
    String? appLink,
    bool clearAppLink = false,
    bool? archived,
    int? order,
    int? updatedAt,
  }) => OrgArea(
    id: id,
    name: name ?? this.name,
    group: group ?? this.group,
    color: color ?? this.color,
    timetableCourseId: timetableCourseId,
    appLink: clearAppLink ? null : (appLink ?? this.appLink),
    archived: archived ?? this.archived,
    order: order ?? this.order,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  Map<String, dynamic> toMap() => {
    "kind": kind,
    "name": name,
    "group": group.name,
    "color": color,
    "timetableCourseId": timetableCourseId,
    "appLink": appLink,
    "archived": archived,
    "order": order,
    "updatedAt": updatedAt,
  };

  static OrgArea? fromMap(String id, Map<String, dynamic> map) {
    final name = _str(map["name"]);
    if (name == null) return null;
    return OrgArea(
      id: id,
      name: name,
      group: OrgGroup.parse(map["group"]),
      color: _int(map["color"]) ?? 0,
      timetableCourseId: _str(map["timetableCourseId"]),
      appLink: _str(map["appLink"]),
      archived: map["archived"] == true,
      order: _int(map["order"]) ?? 100,
      updatedAt: _int(map["updatedAt"]) ?? 0,
    );
  }
}

/// Wiederholung einer Aufgabe: Beim Abhaken entsteht die nächste.
enum TaskRepeat {
  daily("Täglich"),
  weekdays("Werktags (Mo–Fr)"),
  weekly("Wöchentlich"),
  monthly("Monatlich");

  final String label;

  const TaskRepeat(this.label);

  static TaskRepeat? parse(Object? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }
    return null;
  }

  /// Nächste Fälligkeit nach [due], frühestens morgen (vom Tag des
  /// Abhakens aus), damit nachgeholte Routinen nicht als überfällig
  /// nachrücken.
  OrgDate next(OrgDate due, OrgDate today) {
    OrgDate step(OrgDate d) => switch (this) {
      daily => d.addDays(1),
      weekdays => d.addDays(
        d.weekday == 5
            ? 3
            : d.weekday == 6
            ? 2
            : 1,
      ),
      weekly => d.addDays(7),
      monthly => d.addMonths(1),
    };
    var next = step(due);
    var guard = 0;
    while (!next.isAfter(today) && guard++ < 1000) {
      next = step(next);
    }
    return next;
  }
}

class OrgTask implements OrgItem {
  @override
  final String id;
  final String title;
  final String notes;
  final OrgDate? due;
  final OrgTime? dueTime;
  final String? areaId;
  final OrgPriority priority;
  final bool done;

  /// Zeitpunkt des Abhakens (ms seit 1970).
  final int? doneAt;

  /// Zugehöriger Termin (z. B. Lernaufgabe zu einer Klausur).
  final String? eventId;
  final List<OrgLink> links;
  final TaskRepeat? repeat;

  /// Lernbereich (Streak-Track, z. B. `greek`): Ist das Tagesziel dort
  /// erreicht, gilt eine heute fällige Aufgabe als erledigt.
  final String? trackId;

  final OrgSource? source;

  /// Gelöschte übernommene Aufgabe (bleibt als Markierung, damit ein
  /// erneuter Abgleich sie nicht wieder anlegt).
  final bool deleted;
  final int createdAt;
  @override
  final int updatedAt;

  const OrgTask({
    required this.id,
    required this.title,
    this.notes = "",
    this.due,
    this.dueTime,
    this.areaId,
    this.priority = OrgPriority.normal,
    this.done = false,
    this.doneAt,
    this.eventId,
    this.links = const [],
    this.repeat,
    this.trackId,
    this.source,
    this.deleted = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  @override
  String get kind => "task";

  bool isOverdue(OrgDate today) => !done && due != null && due!.isBefore(today);

  OrgTask copyWith({
    String? title,
    String? notes,
    OrgDate? due,
    bool clearDue = false,
    OrgTime? dueTime,
    bool clearDueTime = false,
    String? areaId,
    bool clearArea = false,
    OrgPriority? priority,
    bool? done,
    int? doneAt,
    String? eventId,
    bool clearEvent = false,
    List<OrgLink>? links,
    TaskRepeat? repeat,
    bool clearRepeat = false,
    String? trackId,
    bool clearTrack = false,
    OrgSource? source,
    bool? deleted,
    int? updatedAt,
  }) {
    final isDone = done ?? this.done;
    return OrgTask(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      due: clearDue ? null : (due ?? this.due),
      dueTime: clearDue || clearDueTime ? null : (dueTime ?? this.dueTime),
      areaId: clearArea ? null : (areaId ?? this.areaId),
      priority: priority ?? this.priority,
      done: isDone,
      doneAt: isDone ? (doneAt ?? this.doneAt) : null,
      eventId: clearEvent ? null : (eventId ?? this.eventId),
      links: links ?? this.links,
      repeat: clearRepeat ? null : (repeat ?? this.repeat),
      trackId: clearTrack ? null : (trackId ?? this.trackId),
      source: source ?? this.source,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    "kind": kind,
    "title": title,
    "notes": notes,
    "due": due?.key,
    "dueTime": dueTime?.key,
    "areaId": areaId,
    "priority": priority.name,
    "done": done,
    "doneAt": doneAt,
    "eventId": eventId,
    "links": [for (final l in links) l.toMap()],
    "repeat": repeat?.name,
    "trackId": trackId,
    "source": source?.toMap(),
    "deleted": deleted,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
  };

  static OrgTask? fromMap(String id, Map<String, dynamic> map) {
    final title = _str(map["title"]);
    if (title == null) return null;
    final due = OrgDate.tryParse(map["due"]);
    return OrgTask(
      id: id,
      title: title,
      notes: _text(map["notes"]),
      due: due,
      dueTime: due == null ? null : OrgTime.tryParse(map["dueTime"]),
      areaId: _str(map["areaId"]),
      priority: OrgPriority.parse(map["priority"]),
      done: map["done"] == true,
      doneAt: _int(map["doneAt"]),
      eventId: _str(map["eventId"]),
      links: OrgLink.listFrom(map["links"]),
      repeat: TaskRepeat.parse(map["repeat"]),
      trackId: _str(map["trackId"]),
      source: OrgSource.fromMap(map["source"]),
      deleted: map["deleted"] == true,
      createdAt: _int(map["createdAt"]) ?? 0,
      updatedAt: _int(map["updatedAt"]) ?? 0,
    );
  }
}

/// Art eines Termins (Kategorie). Eigene Arten stehen in den Einstellungen.
class OrgEventType {
  final String id;
  final String label;

  /// Besonders hervorgehoben (Prüfungen, Abgaben).
  final bool important;

  const OrgEventType(this.id, this.label, {this.important = false});

  static const OrgEventType lecture = OrgEventType("lecture", "Vorlesung");
  static const OrgEventType seminar = OrgEventType("seminar", "Seminar");
  static const OrgEventType exam = OrgEventType(
    "exam",
    "Prüfung/Klausur",
    important: true,
  );
  static const OrgEventType deadline = OrgEventType(
    "deadline",
    "Abgabe",
    important: true,
  );
  static const OrgEventType bibelkunde = OrgEventType(
    "bibelkunde",
    "Bibelkunde",
  );
  static const OrgEventType worship = OrgEventType("worship", "Gottesdienst");
  static const OrgEventType private = OrgEventType("private", "Privat");
  static const OrgEventType other = OrgEventType("other", "Sonstiges");

  static const List<OrgEventType> builtIn = [
    lecture,
    seminar,
    exam,
    deadline,
    bibelkunde,
    worship,
    private,
    other,
  ];
}

class OrgEvent implements OrgItem {
  @override
  final String id;
  final String title;
  final OrgDate date;

  /// Letzter Tag mehrtägiger Termine (z. B. Zwischentest 13.–16.11.).
  final OrgDate? endDate;
  final bool allDay;
  final OrgTime? start;
  final OrgTime? end;
  final String location;
  final String description;
  final String typeId;
  final String? areaId;

  /// Minuten vor Beginn (ganztägig: vor 8 Uhr des Tages); null = keine.
  final int? reminderMinutes;
  final Recurrence? recurrence;
  final List<OrgLink> links;
  final OrgSource? source;
  final bool deleted;
  final int createdAt;
  @override
  final int updatedAt;

  const OrgEvent({
    required this.id,
    required this.title,
    required this.date,
    this.endDate,
    this.allDay = true,
    this.start,
    this.end,
    this.location = "",
    this.description = "",
    this.typeId = "other",
    this.areaId,
    this.reminderMinutes,
    this.recurrence,
    this.links = const [],
    this.source,
    this.deleted = false,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  @override
  String get kind => "event";

  /// Zusätzliche Tage über den Beginn hinaus.
  int get spanDays {
    final last = endDate;
    if (last == null || !last.isAfter(date)) return 0;
    return date.daysUntil(last);
  }

  OrgEvent copyWith({
    String? title,
    OrgDate? date,
    OrgDate? endDate,
    bool clearEndDate = false,
    bool? allDay,
    OrgTime? start,
    OrgTime? end,
    bool clearTimes = false,
    String? location,
    String? description,
    String? typeId,
    String? areaId,
    bool clearArea = false,
    int? reminderMinutes,
    bool clearReminder = false,
    Recurrence? recurrence,
    bool clearRecurrence = false,
    List<OrgLink>? links,
    OrgSource? source,
    bool? deleted,
    int? updatedAt,
  }) => OrgEvent(
    id: id,
    title: title ?? this.title,
    date: date ?? this.date,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    allDay: allDay ?? this.allDay,
    start: clearTimes ? null : (start ?? this.start),
    end: clearTimes ? null : (end ?? this.end),
    location: location ?? this.location,
    description: description ?? this.description,
    typeId: typeId ?? this.typeId,
    areaId: clearArea ? null : (areaId ?? this.areaId),
    reminderMinutes: clearReminder
        ? null
        : (reminderMinutes ?? this.reminderMinutes),
    recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
    links: links ?? this.links,
    source: source ?? this.source,
    deleted: deleted ?? this.deleted,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  Map<String, dynamic> toMap() => {
    "kind": kind,
    "title": title,
    "date": date.key,
    "endDate": endDate?.key,
    "allDay": allDay,
    "start": allDay ? null : start?.key,
    "end": allDay ? null : end?.key,
    "location": location,
    "description": description,
    "typeId": typeId,
    "areaId": areaId,
    "reminderMinutes": reminderMinutes,
    "recurrence": recurrence?.toMap(),
    "links": [for (final l in links) l.toMap()],
    "source": source?.toMap(),
    "deleted": deleted,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
  };

  static OrgEvent? fromMap(String id, Map<String, dynamic> map) {
    final title = _str(map["title"]);
    final date = OrgDate.tryParse(map["date"]);
    if (title == null || date == null) return null;
    final start = OrgTime.tryParse(map["start"]);
    final allDay = map["allDay"] != false || start == null;
    var end = OrgTime.tryParse(map["end"]);
    if (start != null && end != null && end.minutes <= start.minutes) {
      end = null;
    }
    final endDate = OrgDate.tryParse(map["endDate"]);
    final reminder = _int(map["reminderMinutes"]);
    return OrgEvent(
      id: id,
      title: title,
      date: date,
      endDate: endDate != null && endDate.isAfter(date) ? endDate : null,
      allDay: allDay,
      start: allDay ? null : start,
      end: allDay ? null : end,
      location: _text(map["location"]),
      description: _text(map["description"]),
      typeId: _str(map["typeId"]) ?? "other",
      areaId: _str(map["areaId"]),
      reminderMinutes: reminder != null && reminder >= 0 ? reminder : null,
      recurrence: Recurrence.fromMap(map["recurrence"]),
      links: OrgLink.listFrom(map["links"]),
      source: OrgSource.fromMap(map["source"]),
      deleted: map["deleted"] == true,
      createdAt: _int(map["createdAt"]) ?? 0,
      updatedAt: _int(map["updatedAt"]) ?? 0,
    );
  }
}

class OrgNote implements OrgItem {
  @override
  final String id;
  final String title;

  /// Einfach strukturierter Text: `# Überschrift`, `- Liste`,
  /// `[ ] Aufgabe`/`[x] erledigt`, `**fett**`.
  final String body;
  final String? areaId;
  final List<String> tags;
  final bool pinned;
  final bool archived;
  final List<OrgLink> links;
  final int createdAt;
  @override
  final int updatedAt;

  const OrgNote({
    required this.id,
    this.title = "",
    this.body = "",
    this.areaId,
    this.tags = const [],
    this.pinned = false,
    this.archived = false,
    this.links = const [],
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  @override
  String get kind => "note";

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Titel, sonst die erste Textzeile.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    for (final line in body.split("\n")) {
      final text = line.replaceAll(RegExp(r"^\s*(#+|-|\*|\[[ xX]\])\s*"), "");
      if (text.trim().isNotEmpty) return text.trim();
    }
    return "Neue Notiz";
  }

  OrgNote copyWith({
    String? title,
    String? body,
    String? areaId,
    bool clearArea = false,
    List<String>? tags,
    bool? pinned,
    bool? archived,
    List<OrgLink>? links,
    int? updatedAt,
  }) => OrgNote(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    areaId: clearArea ? null : (areaId ?? this.areaId),
    tags: tags ?? this.tags,
    pinned: pinned ?? this.pinned,
    archived: archived ?? this.archived,
    links: links ?? this.links,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  Map<String, dynamic> toMap() => {
    "kind": kind,
    "title": title,
    "body": body,
    "areaId": areaId,
    "tags": tags,
    "pinned": pinned,
    "archived": archived,
    "links": [for (final l in links) l.toMap()],
    "createdAt": createdAt,
    "updatedAt": updatedAt,
  };

  static OrgNote fromMap(String id, Map<String, dynamic> map) => OrgNote(
    id: id,
    title: _text(map["title"]),
    body: _text(map["body"]),
    areaId: _str(map["areaId"]),
    tags: _strings(map["tags"]),
    pinned: map["pinned"] == true,
    archived: map["archived"] == true,
    links: OrgLink.listFrom(map["links"]),
    createdAt: _int(map["createdAt"]) ?? 0,
    updatedAt: _int(map["updatedAt"]) ?? 0,
  );
}

/// Einstellungen der Studiumsorganisation (Dokument `config`).
class OrgConfig {
  /// Eigene Terminarten.
  final List<OrgEventType> customTypes;

  /// Heutiges Pensum der Lesepläne zur Lehrveranstaltung als Aufgabe.
  final bool readingTasks;

  /// Termine des Stundenplans im Kalender.
  final bool showTimetable;

  /// Standardbereiche angelegt (einmalig).
  final bool seeded;

  /// Quellen mit automatischer Übernahme (Seminarpläne).
  final Set<String> autoImports;

  const OrgConfig({
    this.customTypes = const [],
    this.readingTasks = true,
    this.showTimetable = true,
    this.seeded = false,
    this.autoImports = const {},
  });

  List<OrgEventType> get types => [...OrgEventType.builtIn, ...customTypes];

  OrgEventType type(String id) {
    for (final t in types) {
      if (t.id == id) return t;
    }
    return OrgEventType.other;
  }

  OrgConfig copyWith({
    List<OrgEventType>? customTypes,
    bool? readingTasks,
    bool? showTimetable,
    bool? seeded,
    Set<String>? autoImports,
  }) => OrgConfig(
    customTypes: customTypes ?? this.customTypes,
    readingTasks: readingTasks ?? this.readingTasks,
    showTimetable: showTimetable ?? this.showTimetable,
    seeded: seeded ?? this.seeded,
    autoImports: autoImports ?? this.autoImports,
  );

  Map<String, dynamic> toMap() => {
    "kind": "config",
    "customTypes": [
      for (final t in customTypes) {"id": t.id, "label": t.label},
    ],
    "readingTasks": readingTasks,
    "showTimetable": showTimetable,
    "seeded": seeded,
    "autoImports": autoImports.toList()..sort(),
  };

  static OrgConfig fromMap(Map<String, dynamic>? map) {
    if (map == null) return const OrgConfig();
    return OrgConfig(
      customTypes: [
        if (map["customTypes"] is List)
          for (final t in map["customTypes"] as List)
            if (t is Map && _str(t["id"]) != null && _str(t["label"]) != null)
              OrgEventType(_str(t["id"])!, _str(t["label"])!),
      ],
      readingTasks: map["readingTasks"] != false,
      showTimetable: map["showTimetable"] != false,
      seeded: map["seeded"] == true,
      autoImports: _strings(map["autoImports"]).toSet(),
    );
  }
}
