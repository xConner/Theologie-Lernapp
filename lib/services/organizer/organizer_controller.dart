import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/organizer/organizer_items.dart';
import '../../models/timetable/timetable_entry.dart';
import '../timetable/plan_schedule.dart';
import 'org_dates.dart';
import 'organizer_store.dart';
import 'recurrence.dart';
import 'reading_tasks.dart';

/// Lernfortschritt, der Aufgaben als erledigt anzeigen kann (Tagesziel
/// eines Lernbereichs). Liest nur – eine Aufgabe ändert nie Lernstände.
abstract class LearningSignals implements Listenable {
  bool goalReachedToday(String trackId);
}

/// Ein Termin an einem Tag: eigener Termin (auch ein Vorkommen eines
/// wiederkehrenden), Termin aus dem Stundenplan oder eine Sitzung aus einem
/// Leseplan.
class CalendarItem {
  /// Eindeutig je Vorkommen.
  final String key;
  final String title;
  final OrgDate date;
  final OrgDate endDate;
  final OrgTime? start;
  final OrgTime? end;
  final String location;
  final String typeId;
  final String? areaId;

  /// Eigener Termin (null bei Stundenplan).
  final OrgEvent? event;

  /// Kennung im Stundenplan (`TimetableEntry.courseId`).
  final String? timetableCourseId;

  final bool important;
  final bool cancelled;

  const CalendarItem({
    required this.key,
    required this.title,
    required this.date,
    required this.endDate,
    this.start,
    this.end,
    this.location = "",
    this.typeId = "other",
    this.areaId,
    this.event,
    this.timetableCourseId,
    this.important = false,
    this.cancelled = false,
  });

  bool get allDay => start == null;
  bool get fromTimetable => timetableCourseId != null;
  bool coversDay(OrgDate day) => !day.isBefore(date) && !day.isAfter(endDate);

  /// Zeitspanne als Text, z. B. „10:15–11:45“ oder „ganztägig“.
  String get timeLabel {
    if (start == null) {
      return endDate == date
          ? "ganztägig"
          : "${date.label(weekday: false)}–${endDate.label(weekday: false)}";
    }
    return end == null ? start!.key : "${start!.key}–${end!.key}";
  }

  static int compare(CalendarItem a, CalendarItem b) {
    final d = a.date.compareTo(b.date);
    if (d != 0) return d;
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    final t = (a.start?.minutes ?? 0).compareTo(b.start?.minutes ?? 0);
    if (t != 0) return t;
    return a.title.compareTo(b.title);
  }
}

/// Fällige Erinnerung an einen Termin.
class OrgReminder {
  final CalendarItem item;
  final DateTime at;

  /// Kennung zum Ausblenden (Termin + Tag).
  final String key;

  const OrgReminder(this.item, this.at, this.key);
}

/// Aufgabenansichten.
enum TaskView {
  today("Heute"),
  upcoming("Demnächst"),
  overdue("Überfällig"),
  open("Alle offenen"),
  done("Erledigt");

  final String label;

  const TaskView(this.label);
}

/// Filter nach Zuordnung oder Studium/Privat.
class OrgFilter {
  final String? areaId;
  final OrgGroup? group;

  const OrgFilter({this.areaId, this.group});

  static const OrgFilter none = OrgFilter();

  bool get isEmpty => areaId == null && group == null;
}

/// Zustand und Änderungen der Studiumsorganisation eines Nutzers.
///
/// Gespeichert wird jedes Element als eigenes Dokument; Änderungen werden
/// sofort angezeigt und im Hintergrund geschrieben (offline von Firestore
/// zurückgehalten). Geschrieben werden nur geänderte Felder: Hakt man auf
/// dem Handy eine Aufgabe ab, während man im Web ihre Beschreibung ändert,
/// bleibt beides erhalten. Übernommene Einträge (Seminarplan) haben feste
/// Kennungen aus ihrer Quelle, damit zwei Geräte nie zwei Kopien anlegen.
class OrganizerController extends ChangeNotifier {
  final OrganizerBackend backend;
  final DateTime Function() _clock;
  final LearningSignals? learning;
  final ReadingTaskSource? readingSource;
  final Stream<List<TimetableEntry>>? timetable;

  OrganizerController({
    required this.backend,
    DateTime Function()? clock,
    this.learning,
    this.readingSource,
    this.timetable,
  }) : _clock = clock ?? DateTime.now;

  StreamSubscription<Map<String, Map<String, dynamic>>>? _sub;
  StreamSubscription<List<TimetableEntry>>? _timetableSub;
  Timer? _midnight;

  Map<String, Map<String, dynamic>> _remote = {};

  // Noch nicht bestätigte eigene Änderungen, über den Stand gelegt, bis sie
  // geschrieben sind (sonst „springt“ ein Eintrag bei einem älteren Stand).
  final Map<String, Map<String, dynamic>?> _pending = {};
  final Map<String, int> _pendingCount = {};

  bool _loaded = false;
  Object? _loadError;
  bool _saveFailed = false;
  bool _disposed = false;

  Map<String, OrgTask> _tasks = {};
  Map<String, OrgEvent> _events = {};
  Map<String, OrgNote> _notes = {};
  Map<String, OrgArea> _areas = {};
  Map<String, Map<String, dynamic>> _imports = {};
  OrgConfig _config = const OrgConfig();
  Set<String> _dismissedReminders = {};
  List<PlanCourse> _timetableCourses = const [];

  bool get loaded => _loaded;
  Object? get loadError => _loadError;

  /// Eine Änderung konnte nicht gespeichert werden.
  bool get saveFailed => _saveFailed;

  OrgConfig get config => _config;

  OrgDate get today => OrgDate.of(_clock());

  DateTime get now => _clock();

  void start() {
    _sub ??= backend.watch().listen(
      _onRemote,
      onError: (Object e) {
        _loadError = e;
        _notify();
      },
    );
    _timetableSub ??= timetable?.listen((entries) {
      _timetableCourses = [for (final e in entries) resolvePlanCourse(e)];
      _notify();
    }, onError: (_) {});
    learning?.addListener(_onLearning);
    readingSource?.addListener(_notify);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _timetableSub?.cancel();
    _midnight?.cancel();
    learning?.removeListener(_onLearning);
    readingSource?.removeListener(_notify);
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Nach Mitternacht neu einordnen (Heute, Überfällig).
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _clock();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      _notify();
      _onLearning();
      _scheduleMidnight();
    });
  }

  void _onRemote(Map<String, Map<String, dynamic>> docs) {
    _remote = docs;
    _loadError = null;
    final first = !_loaded;
    _loaded = true;
    _rebuild();
    if (first && !_config.seeded) _seed();
    _onLearning();
    _notify();
  }

  void _rebuild() {
    final merged = <String, Map<String, dynamic>>{..._remote};
    for (final e in _pending.entries) {
      if (e.value == null) {
        merged.remove(e.key);
      } else {
        merged[e.key] = {...?merged[e.key], ...e.value!};
      }
    }
    final tasks = <String, OrgTask>{};
    final events = <String, OrgEvent>{};
    final notes = <String, OrgNote>{};
    final areas = <String, OrgArea>{};
    final imports = <String, Map<String, dynamic>>{};
    OrgConfig config = const OrgConfig();
    Set<String> dismissed = {};
    for (final e in merged.entries) {
      final data = e.value;
      switch (data["kind"]) {
        case "task":
          if (OrgTask.fromMap(e.key, data) case final t?) tasks[e.key] = t;
        case "event":
          if (OrgEvent.fromMap(e.key, data) case final ev?) events[e.key] = ev;
        case "note":
          notes[e.key] = OrgNote.fromMap(e.key, data);
        case "area":
          if (OrgArea.fromMap(e.key, data) case final a?) areas[e.key] = a;
        case "import":
          if (data["sourceId"] case final String id) imports[id] = data;
        case "config":
          config = OrgConfig.fromMap(data);
          dismissed = {
            if (data["dismissedReminders"] is List)
              for (final k in data["dismissedReminders"] as List)
                if (k is String) k,
          };
      }
    }
    _tasks = tasks;
    _events = events;
    _notes = notes;
    _areas = areas;
    _imports = imports;
    _config = config;
    _dismissedReminders = dismissed;
  }

  // ==========================
  // SCHREIBEN
  // ==========================

  int get _stamp => _clock().millisecondsSinceEpoch;

  /// Schreibt die Felder von [after], die sich gegenüber [before] geändert
  /// haben (alle bei neuen Dokumenten).
  Future<void> _write(
    String id,
    Map<String, dynamic> after, {
    Map<String, dynamic>? before,
  }) {
    final fields = <String, dynamic>{};
    for (final e in after.entries) {
      if (before == null) {
        if (e.value != null) fields[e.key] = e.value;
      } else if (!_same(before[e.key], e.value)) {
        fields[e.key] = e.value;
      }
    }
    if (fields.isEmpty) return Future.value();
    _pending[id] = {...?_pending[id], ...fields};
    _rebuild();
    _notify();
    return _track(id, backend.patch(id, fields));
  }

  Future<void> _remove(String id) {
    _pending[id] = null;
    _rebuild();
    _notify();
    return _track(id, backend.delete(id));
  }

  Future<void> _track(String id, Future<void> write) {
    _pendingCount[id] = (_pendingCount[id] ?? 0) + 1;
    return write
        .then((_) {
          _saveFailed = false;
        })
        .catchError((Object e) {
          debugPrint("Studiumsorganisation: Speichern fehlgeschlagen: $e");
          _saveFailed = true;
        })
        .whenComplete(() {
          final left = (_pendingCount[id] ?? 1) - 1;
          if (left <= 0) {
            _pendingCount.remove(id);
            _pending.remove(id);
          } else {
            _pendingCount[id] = left;
          }
          _rebuild();
          _notify();
        });
  }

  static bool _same(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_same(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_same(a[k], b[k])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Standardzuordnungen (feste Kennungen: auf zwei Geräten entsteht jede
  /// nur einmal).
  static const List<OrgArea> defaultAreas = [
    OrgArea(id: "area_general", name: "Allgemein", color: 0, order: 0),
    OrgArea(
      id: "area_courses",
      name: "Seminare & Vorlesungen",
      color: 1,
      order: 1,
    ),
    OrgArea(
      id: "area_bibelkunde",
      name: "Bibelkunde",
      color: 2,
      order: 2,
      appLink: "bibelkunde",
    ),
    OrgArea(
      id: "area_greek",
      name: "Griechisch",
      color: 3,
      order: 3,
      appLink: "/greek",
    ),
    OrgArea(
      id: "area_latin",
      name: "Latein",
      color: 4,
      order: 4,
      appLink: "/latin",
    ),
    OrgArea(
      id: "area_philosophy",
      name: "Philosophie",
      color: 5,
      order: 5,
      appLink: "philosophy",
    ),
    OrgArea(
      id: "area_church_history",
      name: "Kirchengeschichte",
      color: 6,
      order: 6,
      appLink: "/church-history",
    ),
    OrgArea(
      id: "area_private",
      name: "Privat",
      group: OrgGroup.private,
      color: 7,
      order: 20,
    ),
    OrgArea(
      id: "area_shopping",
      name: "Einkaufen",
      group: OrgGroup.private,
      color: 8,
      order: 21,
    ),
  ];

  void _seed() {
    for (final area in defaultAreas) {
      if (!_areas.containsKey(area.id)) {
        _write(area.id, area.copyWith(updatedAt: _stamp).toMap());
      }
    }
    _write("config", {"kind": "config", "seeded": true}, before: {});
  }

  // ==========================
  // LESEN
  // ==========================

  List<OrgArea> get areas =>
      _areas.values.where((a) => !a.archived).toList()..sort(_byOrder);

  List<OrgArea> get allAreas => _areas.values.toList()..sort(_byOrder);

  static int _byOrder(OrgArea a, OrgArea b) {
    final o = a.order.compareTo(b.order);
    return o != 0 ? o : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  OrgArea? area(String? id) => id == null ? null : _areas[id];

  OrgTask? task(String id) {
    final t = _tasks[id];
    return t == null || t.deleted ? null : t;
  }

  OrgEvent? event(String id) {
    final e = _events[id];
    return e == null || e.deleted ? null : e;
  }

  OrgNote? note(String id) => _notes[id];

  /// Alle Aufgaben einschließlich gelöschter Übernahmen (für den Abgleich).
  Iterable<OrgTask> get rawTasks => _tasks.values;
  Iterable<OrgEvent> get rawEvents => _events.values;

  List<OrgTask> get tasks => [
    for (final t in _tasks.values)
      if (!t.deleted) t,
  ];

  List<OrgEvent> get events => [
    for (final e in _events.values)
      if (!e.deleted) e,
  ];

  List<OrgNote> get notes => _notes.values.toList();

  bool _matches(String? areaId, OrgFilter filter) {
    if (filter.areaId != null && areaId != filter.areaId) return false;
    if (filter.group != null) {
      final group = area(areaId)?.group ?? OrgGroup.study;
      if (group != filter.group) return false;
    }
    return true;
  }

  /// Gilt als erledigt: abgehakt, oder (mit Lernbereich) das heutige
  /// Tagesziel dort ist erreicht.
  bool isDone(OrgTask t) =>
      t.done ||
      (t.trackId != null &&
          t.due != null &&
          !t.due!.isAfter(today) &&
          (learning?.goalReachedToday(t.trackId!) ?? false));

  static int _taskOrder(OrgTask a, OrgTask b) {
    final da = a.due?.key ?? "9999";
    final db = b.due?.key ?? "9999";
    final d = da.compareTo(db);
    if (d != 0) return d;
    final ta = a.dueTime?.minutes ?? 24 * 60;
    final tb = b.dueTime?.minutes ?? 24 * 60;
    if (ta != tb) return ta.compareTo(tb);
    final p = b.priority.index.compareTo(a.priority.index);
    if (p != 0) return p;
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Tage, die „Demnächst“ umfasst.
  static const int upcomingDays = 14;

  List<OrgTask> tasksFor(TaskView view, {OrgFilter filter = OrgFilter.none}) {
    final day = today;
    final list = [
      for (final t in tasks)
        if (_matches(t.areaId, filter) && _inView(t, view, day)) t,
    ];
    if (view == TaskView.done) {
      list.sort((a, b) => (b.doneAt ?? 0).compareTo(a.doneAt ?? 0));
    } else {
      list.sort(_taskOrder);
    }
    return list;
  }

  bool _inView(OrgTask t, TaskView view, OrgDate day) {
    final done = isDone(t);
    final due = t.due;
    return switch (view) {
      // Heute: heute fällig (auch heute erledigt, damit nichts beim Abhaken
      // verschwindet).
      TaskView.today =>
        due == day && (!t.done || OrgDate.of(_doneTime(t)) == day),
      TaskView.upcoming =>
        !done &&
            due != null &&
            due.isAfter(day) &&
            day.daysUntil(due) <= upcomingDays,
      TaskView.overdue => !done && due != null && due.isBefore(day),
      TaskView.open => !done,
      TaskView.done => t.done,
    };
  }

  DateTime _doneTime(OrgTask t) =>
      DateTime.fromMillisecondsSinceEpoch(t.doneAt ?? _stamp);

  /// Aufgaben eines Tages (Kalender-Tagesansicht).
  List<OrgTask> tasksDueOn(OrgDate day) => [
    for (final t in tasks)
      if (t.due == day) t,
  ]..sort(_taskOrder);

  List<OrgTask> tasksOfEvent(String eventId) => [
    for (final t in tasks)
      if (t.eventId == eventId) t,
  ]..sort(_taskOrder);

  int countFor(TaskView view, {OrgFilter filter = OrgFilter.none}) =>
      tasksFor(view, filter: filter).where((t) => !isDone(t)).length;

  /// Heutiges Pensum der Lesepläne (nicht gespeichert, aus dem
  /// Lesefortschritt berechnet).
  List<ReadingTask> get readingTasks => _config.readingTasks
      ? (readingSource?.tasks(today) ?? const [])
      : const [];

  // ---------- Kalender ----------

  /// Alle Termine, die sich mit [from]–[to] überschneiden.
  List<CalendarItem> itemsBetween(
    OrgDate from,
    OrgDate to, {
    OrgFilter filter = OrgFilter.none,
  }) {
    final result = <CalendarItem>[];
    for (final e in events) {
      if (!_matches(e.areaId, filter)) continue;
      final span = e.spanDays;
      final starts = e.recurrence == null
          ? [
              if (!e.date.addDays(span).isBefore(from) && !e.date.isAfter(to))
                e.date,
            ]
          : e.recurrence!.occurrences(
              e.date,
              from: from,
              to: to,
              spanDays: span,
            );
      for (final d in starts) {
        final type = _config.type(e.typeId);
        result.add(
          CalendarItem(
            key: "${e.id}@${d.key}",
            title: e.title,
            date: d,
            endDate: d.addDays(span),
            start: e.allDay ? null : e.start,
            end: e.allDay ? null : e.end,
            location: e.location,
            typeId: e.typeId,
            areaId: e.areaId,
            event: e,
            important: type.important,
          ),
        );
      }
    }
    if (_config.showTimetable && (filter.group != OrgGroup.private)) {
      for (final course in _timetableCourses) {
        final areaId = _areaOfTimetable(course.id);
        if (filter.areaId != null && filter.areaId != areaId) continue;
        for (final o in course.occurrences) {
          final date = OrgDate.tryParse(o.start.date);
          if (date == null || date.isBefore(from) || date.isAfter(to)) {
            continue;
          }
          if (o.tentative) continue;
          result.add(
            CalendarItem(
              key: "tt:${o.id}",
              title: course.title,
              date: date,
              endDate: OrgDate.tryParse(o.end.date) ?? date,
              start: OrgTime.tryParse(o.start.time),
              end: OrgTime.tryParse(o.end.time),
              location: o.room ?? "",
              typeId: "lecture",
              areaId: areaId,
              timetableCourseId: course.id,
              cancelled: o.cancelled,
            ),
          );
        }
      }
    }
    result.sort(CalendarItem.compare);
    return result;
  }

  String? _areaOfTimetable(String courseId) {
    for (final a in _areas.values) {
      if (a.timetableCourseId == courseId && !a.archived) return a.id;
    }
    return null;
  }

  List<CalendarItem> itemsOn(
    OrgDate day, {
    OrgFilter filter = OrgFilter.none,
  }) => itemsBetween(day, day, filter: filter);

  /// Nächste Termine ab heute (laufende mehrtägige eingeschlossen).
  List<CalendarItem> upcomingItems({
    int days = 60,
    int? limit,
    OrgFilter filter = OrgFilter.none,
    bool importantOnly = false,
  }) {
    final day = today;
    final nowTime = OrgTime.hm(_clock().hour, _clock().minute);
    final items = itemsBetween(day, day.addDays(days), filter: filter).where((
      i,
    ) {
      if (importantOnly && !i.important) return false;
      if (i.cancelled) return false;
      // Heute schon vorbei.
      if (i.endDate == day && i.date == day && i.end != null) {
        return i.end!.minutes > nowTime.minutes;
      }
      return true;
    }).toList();
    return limit == null ? items : items.take(limit).toList();
  }

  /// Termine, an die jetzt erinnert wird (in der App, siehe
  /// docs/study-organizer.md).
  List<OrgReminder> get dueReminders {
    final now = _clock();
    final day = today;
    final result = <OrgReminder>[];
    for (final item in itemsBetween(day, day.addDays(8))) {
      final minutes = item.event?.reminderMinutes;
      if (minutes == null) continue;
      final begin = wallClock(item.date, item.start ?? OrgTime.hm(8, 0));
      final at = begin.subtract(Duration(minutes: minutes));
      final key = item.key;
      if (_dismissedReminders.contains(key)) continue;
      final over = item.start == null
          ? item.endDate.isBefore(day)
          : now.isAfter(wallClock(item.endDate, item.end ?? item.start));
      if (!now.isBefore(at) && !over) result.add(OrgReminder(item, at, key));
    }
    return result;
  }

  Future<void> dismissReminder(String key) {
    final cutoff = today.addDays(-30).key;
    final keep = [
      for (final k in _dismissedReminders)
        if ((k.split("@").last).compareTo(cutoff) >= 0) k,
      key,
    ];
    return _write("config", {
      "kind": "config",
      "dismissedReminders": keep,
    }, before: {});
  }

  // ---------- Notizen ----------

  /// Neueste zuerst; angeheftete vorn.
  List<OrgNote> notesFor({
    String query = "",
    OrgFilter filter = OrgFilter.none,
    bool archived = false,
    String? tag,
  }) {
    final q = query.trim().toLowerCase();
    final list = [
      for (final n in _notes.values)
        if (n.archived == archived &&
            !n.isEmpty &&
            _matches(n.areaId, filter) &&
            (tag == null || n.tags.contains(tag)) &&
            (q.isEmpty || _noteMatches(n, q)))
          n,
    ];
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  bool _noteMatches(OrgNote n, String q) {
    final words = q.split(RegExp(r"\s+"));
    final text = [
      n.title,
      n.body,
      ...n.tags,
      area(n.areaId)?.name ?? "",
      for (final l in n.links) l.label,
    ].join(" ").toLowerCase();
    return words.every(text.contains);
  }

  List<OrgNote> recentNotes({int limit = 3}) {
    final list = notesFor()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(limit).toList();
  }

  List<String> get allTags {
    final tags = <String>{
      for (final n in _notes.values)
        if (!n.archived) ...n.tags,
    };
    return tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Einträge, die auf [type]/[id] verweisen (Rückverweise).
  List<OrgItem> backlinks(String type, String id) => [
    for (final t in tasks)
      if (t.links.any((l) => l.type == type && l.target == id)) t,
    for (final e in events)
      if (e.links.any((l) => l.type == type && l.target == id)) e,
    for (final n in _notes.values)
      if (n.links.any((l) => l.type == type && l.target == id)) n,
  ];

  /// Notizen, die mit einem Eintrag verknüpft sind (in beide Richtungen).
  List<OrgNote> notesLinkedTo(String type, String id, {List<OrgLink>? own}) {
    final result = <String, OrgNote>{};
    for (final n in _notes.values) {
      if (n.links.any((l) => l.type == type && l.target == id)) {
        result[n.id] = n;
      }
    }
    for (final l in own ?? const <OrgLink>[]) {
      if (l.type == "note" && _notes[l.target] != null) {
        result[l.target] = _notes[l.target]!;
      }
    }
    return result.values.toList();
  }

  // ==========================
  // ÄNDERN
  // ==========================

  // ---------- Aufgaben ----------

  OrgTask newTask({
    required String title,
    OrgDate? due,
    OrgTime? dueTime,
    String? areaId,
    OrgPriority priority = OrgPriority.normal,
    String notes = "",
    String? eventId,
    List<OrgLink> links = const [],
    TaskRepeat? repeat,
    String? trackId,
  }) {
    final stamp = _stamp;
    final task = OrgTask(
      id: OrgIds.create("t", now: _clock()),
      title: title.trim(),
      notes: notes,
      due: due,
      dueTime: due == null ? null : dueTime,
      areaId: areaId,
      priority: priority,
      eventId: eventId,
      links: links,
      repeat: repeat,
      trackId: trackId,
      createdAt: stamp,
      updatedAt: stamp,
    );
    _write(task.id, task.toMap());
    return task;
  }

  /// Speichert eine geänderte Aufgabe. Ändert man bei einer übernommenen
  /// Aufgabe Inhalt oder Termin, gilt sie als bearbeitet und wird von
  /// einem erneuten Abgleich nicht mehr überschrieben.
  Future<void> saveTask(OrgTask updated) {
    final before = _tasks[updated.id];
    var task = updated.copyWith(updatedAt: _stamp);
    final source = task.source;
    if (before != null &&
        source != null &&
        !source.edited &&
        (before.title != task.title ||
            before.notes != task.notes ||
            before.due != task.due ||
            before.dueTime != task.dueTime)) {
      task = task.copyWith(source: source.copyWith(edited: true));
    }
    return _write(task.id, task.toMap(), before: before?.toMap());
  }

  /// Abhaken bzw. wieder öffnen – ein Tipp. Wiederkehrende Aufgaben legen
  /// beim Abhaken die nächste an (feste Kennung: nie doppelt).
  Future<void> toggleTask(OrgTask task) async {
    final current = _tasks[task.id] ?? task;
    final done = !current.done;
    final stamp = _stamp;
    await saveTask(current.copyWith(done: done, doneAt: done ? stamp : null));
    final repeat = current.repeat;
    if (repeat == null) return;
    final nextId = OrgIds.stable("t", "${current.id}|next");
    if (done) {
      if (_tasks.containsKey(nextId)) return;
      final base = current.due ?? today;
      final next = OrgTask(
        id: nextId,
        title: current.title,
        notes: current.notes,
        due: repeat.next(base, today),
        dueTime: current.dueTime,
        areaId: current.areaId,
        priority: current.priority,
        links: current.links,
        repeat: repeat,
        trackId: current.trackId,
        createdAt: stamp,
        updatedAt: stamp,
      );
      await _write(nextId, next.toMap());
    } else {
      // Wieder geöffnet: die eben angelegte nächste Aufgabe entfällt, wenn
      // sie unberührt ist.
      final next = _tasks[nextId];
      if (next != null && !next.done && next.updatedAt == next.createdAt) {
        await _remove(nextId);
      }
    }
  }

  /// Verschieben (ein Tipp: heute, morgen, nächste Woche, ohne Datum).
  Future<void> moveTask(OrgTask task, OrgDate? due) => saveTask(
    due == null ? task.copyWith(clearDue: true) : task.copyWith(due: due),
  );

  Future<void> deleteTask(OrgTask task) {
    if (task.source != null) {
      // Markierung bleibt: Ein erneuter Abgleich legt sie nicht wieder an.
      return _write(
        task.id,
        task.copyWith(deleted: true, updatedAt: _stamp).toMap(),
        before: _tasks[task.id]?.toMap(),
      );
    }
    return _remove(task.id);
  }

  /// Gelöschte Aufgabe zurückholen (Rückgängig).
  Future<void> restoreTask(OrgTask task) => _write(
    task.id,
    task.copyWith(deleted: false).toMap(),
    before: _tasks[task.id]?.toMap(),
  );

  /// Aufgaben mit erreichtem Tagesziel ihres Lernbereichs dauerhaft
  /// abhaken (damit wiederkehrende Routinen weiterrücken). Läuft nur in
  /// diese Richtung: Lernfortschritt → Aufgabe.
  void _onLearning() {
    final signals = learning;
    if (signals == null || !_loaded) return;
    final day = today;
    for (final t in tasks) {
      if (t.done || t.trackId == null || t.due == null) continue;
      if (t.due!.isAfter(day)) continue;
      if (signals.goalReachedToday(t.trackId!)) toggleTask(t);
    }
    _notify();
  }

  // ---------- Termine ----------

  OrgEvent newEvent({
    required String title,
    required OrgDate date,
    OrgDate? endDate,
    OrgTime? start,
    OrgTime? end,
    String location = "",
    String description = "",
    String typeId = "other",
    String? areaId,
    int? reminderMinutes,
    Recurrence? recurrence,
    List<OrgLink> links = const [],
  }) {
    final stamp = _stamp;
    final event = OrgEvent(
      id: OrgIds.create("e", now: _clock()),
      title: title.trim(),
      date: date,
      endDate: endDate,
      allDay: start == null,
      start: start,
      end: start == null ? null : end,
      location: location,
      description: description,
      typeId: typeId,
      areaId: areaId,
      reminderMinutes: reminderMinutes,
      recurrence: recurrence,
      links: links,
      createdAt: stamp,
      updatedAt: stamp,
    );
    _write(event.id, event.toMap());
    return event;
  }

  Future<void> saveEvent(OrgEvent updated) {
    final before = _events[updated.id];
    var event = updated.copyWith(updatedAt: _stamp);
    final source = event.source;
    if (before != null &&
        source != null &&
        !source.edited &&
        (before.title != event.title ||
            before.date != event.date ||
            before.endDate != event.endDate ||
            before.start != event.start ||
            before.end != event.end ||
            before.description != event.description)) {
      event = event.copyWith(source: source.copyWith(edited: true));
    }
    return _write(event.id, event.toMap(), before: before?.toMap());
  }

  Future<void> deleteEvent(OrgEvent event) async {
    // Zugehörige Aufgaben bleiben, verlieren aber den Termin.
    for (final t in tasksOfEvent(event.id)) {
      await saveTask(t.copyWith(clearEvent: true));
    }
    if (event.source != null) {
      await _write(
        event.id,
        event.copyWith(deleted: true, updatedAt: _stamp).toMap(),
        before: _events[event.id]?.toMap(),
      );
      return;
    }
    await _remove(event.id);
  }

  /// Ein Vorkommen eines wiederkehrenden Termins auslassen.
  Future<void> skipOccurrence(OrgEvent event, OrgDate date) {
    final r = event.recurrence;
    if (r == null) return deleteEvent(event);
    return saveEvent(
      event.copyWith(
        recurrence: r.copyWith(exceptions: {...r.exceptions, date.key}),
      ),
    );
  }

  /// Nur dieses Vorkommen ändern: Es wird ausgelassen und als eigener
  /// Termin angelegt.
  OrgEvent detachOccurrence(OrgEvent event, OrgDate date) {
    skipOccurrence(event, date);
    final stamp = _stamp;
    final copy = OrgEvent(
      id: OrgIds.create("e", now: _clock()),
      title: event.title,
      date: date,
      endDate: event.spanDays == 0 ? null : date.addDays(event.spanDays),
      allDay: event.allDay,
      start: event.start,
      end: event.end,
      location: event.location,
      description: event.description,
      typeId: event.typeId,
      areaId: event.areaId,
      reminderMinutes: event.reminderMinutes,
      links: event.links,
      createdAt: stamp,
      updatedAt: stamp,
    );
    _write(copy.id, copy.toMap());
    return copy;
  }

  /// Serie ab [date] beenden (dieses und alle folgenden löschen).
  Future<void> endSeriesBefore(OrgEvent event, OrgDate date) {
    final r = event.recurrence;
    if (r == null || !date.isAfter(event.date)) return deleteEvent(event);
    return saveEvent(
      event.copyWith(recurrence: r.copyWith(until: date.addDays(-1))),
    );
  }

  // ---------- Notizen ----------

  OrgNote newNote({
    String title = "",
    String body = "",
    String? areaId,
    List<String> tags = const [],
    List<OrgLink> links = const [],
  }) {
    final stamp = _stamp;
    final note = OrgNote(
      id: OrgIds.create("n", now: _clock()),
      title: title,
      body: body,
      areaId: areaId,
      tags: tags,
      links: links,
      createdAt: stamp,
      updatedAt: stamp,
    );
    // Leere Notizen werden erst beim ersten Text gespeichert.
    if (!note.isEmpty) _write(note.id, note.toMap());
    return note;
  }

  Future<void> saveNote(OrgNote updated) {
    final before = _notes[updated.id];
    if (before == null && updated.isEmpty) return Future.value();
    final note = updated.copyWith(updatedAt: _stamp);
    return _write(note.id, note.toMap(), before: before?.toMap());
  }

  Future<void> deleteNote(OrgNote note) => _remove(note.id);

  // ---------- Zuordnungen und Einstellungen ----------

  OrgArea newArea({
    required String name,
    OrgGroup group = OrgGroup.study,
    String? timetableCourseId,
    String? appLink,
    String? id,
  }) {
    final used = {for (final a in _areas.values) a.color};
    var color = 0;
    while (used.contains(color) && color < OrgPalette.size - 1) {
      color++;
    }
    final area = OrgArea(
      id: id ?? OrgIds.create("area", now: _clock()),
      name: name.trim(),
      group: group,
      color: color,
      timetableCourseId: timetableCourseId,
      appLink: appLink,
      order: 50,
      updatedAt: _stamp,
    );
    _write(area.id, area.toMap(), before: _areas[area.id]?.toMap());
    return area;
  }

  Future<void> saveArea(OrgArea area) => _write(
    area.id,
    area.copyWith(updatedAt: _stamp).toMap(),
    before: _areas[area.id]?.toMap(),
  );

  /// Zuordnung zu einer Veranstaltung des Stundenplans (feste Kennung).
  OrgArea areaForTimetable(String courseId, String title) {
    for (final a in _areas.values) {
      if (a.timetableCourseId == courseId) {
        if (a.archived) saveArea(a.copyWith(archived: false));
        return a;
      }
    }
    return newArea(
      id: OrgIds.stable("area", "tt:$courseId"),
      name: title,
      timetableCourseId: courseId,
    );
  }

  /// Veranstaltungen des Stundenplans (für „Aus dem Stundenplan“).
  List<PlanCourse> get timetableCourses => _timetableCourses;

  Future<void> saveConfig(OrgConfig config) =>
      _write("config", config.toMap(), before: _config.toMap());

  /// Eigene Terminart anlegen.
  OrgEventType addEventType(String label) {
    final type = OrgEventType(
      OrgIds.create("type", now: _clock()),
      label.trim(),
    );
    saveConfig(_config.copyWith(customTypes: [..._config.customTypes, type]));
    return type;
  }

  // ---------- Übernahmen ----------

  /// Gespeicherte Angaben einer Quelle (eingefügter Text, Uhrzeit der
  /// Sitzungen, erste Sitzung).
  Map<String, dynamic>? importSettings(String sourceId) => _imports[sourceId];

  /// Eingefügte Seminarpläne.
  List<Map<String, dynamic>> get textImports => [
    for (final d in _imports.values)
      if (d["text"] is String) d,
  ]..sort((a, b) => "${a["title"]}".compareTo("${b["title"]}"));

  Future<void> saveImportSettings(String sourceId, Map<String, dynamic> data) {
    final id = OrgIds.stable("import", sourceId);
    return _write(id, {
      "kind": "import",
      "sourceId": sourceId,
      ...data,
    }, before: _imports[sourceId]);
  }

  Future<void> deleteImportSettings(String sourceId) =>
      _remove(OrgIds.stable("import", sourceId));

  /// Schreibt einen übernommenen Eintrag unter seiner festen Kennung.
  Future<void> writeImported(OrgItem item) {
    final before = switch (item) {
      OrgTask() => _tasks[item.id]?.toMap(),
      OrgEvent() => _events[item.id]?.toMap(),
      _ => null,
    };
    return _write(item.id, item.toMap(), before: before);
  }
}

/// Farben der Zuordnungen (gedeckt, in hellem und dunklem Design lesbar).
class OrgPalette {
  OrgPalette._();

  static const List<int> light = [
    0xFF5A6E92, // Blau
    0xFF8A6D3B, // Ocker
    0xFF3F7D58, // Grün
    0xFF7A4E8C, // Violett
    0xFFAE5A3A, // Rost
    0xFF3D7F86, // Petrol
    0xFF8C4A5C, // Weinrot
    0xFF6B6A6E, // Grau
    0xFF9A7F2E, // Senf
    0xFF4E6E3A, // Oliv
  ];

  static const List<int> dark = [
    0xFFA9BBDD,
    0xFFD6B67E,
    0xFF82C99C,
    0xFFC7A2D6,
    0xFFF0A487,
    0xFF8FCDD3,
    0xFFE09AAD,
    0xFFBDBCC2,
    0xFFE2CB7A,
    0xFFA9C98F,
  ];

  static int get size => light.length;
}
