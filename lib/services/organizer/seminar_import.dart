import '../../models/bible/course_reading_plan.dart';
import '../../models/church_history/church_history.dart';
import '../../models/organizer/organizer_items.dart';
import 'org_dates.dart';
import 'organizer_controller.dart';

// Übernahme von Seminarplänen in Aufgaben und Termine.
//
// Grundsätze:
// * Übernommen werden nur erkannte Vorbereitungsaufgaben, Abgaben,
//   Prüfungen und Sitzungstermine – nie der ganze Text.
// * Jeder erkannte Eintrag hat einen stabilen Schlüssel in seiner Quelle und
//   daraus eine feste Dokumentkennung. Ein erneuter Abgleich (auch auf einem
//   anderen Gerät) findet so denselben Eintrag wieder: keine Duplikate.
// * Erledigte und selbst bearbeitete Einträge werden nie überschrieben;
//   Änderungen des Plans erscheinen in der Vorschau als „geändert“ und
//   werden nur auf Wunsch übernommen. Gelöschte Übernahmen bleiben als
//   Markierung erhalten und kehren nicht ungefragt zurück.

enum ImportKind { task, event }

/// Ein erkannter Eintrag eines Seminarplans.
class ImportCandidate {
  final String key;
  final ImportKind kind;
  final String title;
  final String description;
  final OrgDate? date;
  final OrgDate? endDate;
  final OrgTime? start;
  final OrgTime? end;
  final String typeId;
  final OrgPriority priority;

  /// Sitzung, zu der der Eintrag gehört (Gruppierung in der Vorschau).
  final String? group;

  /// Bei Aufgaben: Schlüssel des Sitzungstermins, zu dem sie gehört.
  final String? eventKey;

  final List<OrgLink> links;

  const ImportCandidate({
    required this.key,
    required this.kind,
    required this.title,
    this.description = "",
    this.date,
    this.endDate,
    this.start,
    this.end,
    this.typeId = "other",
    this.priority = OrgPriority.normal,
    this.group,
    this.eventKey,
    this.links = const [],
  });

  /// Inhalt, an dem eine Änderung des Plans erkannt wird.
  String get fingerprint => orgFingerprint(
    [
      kind.name,
      title,
      description,
      date?.key,
      endDate?.key,
      start?.key,
      end?.key,
      typeId,
    ].join("|"),
  );

  ImportCandidate copyWith({
    String? title,
    OrgDate? date,
    bool clearDate = false,
    OrgTime? start,
    OrgTime? end,
    bool clearTimes = false,
  }) => ImportCandidate(
    key: key,
    kind: kind,
    title: title ?? this.title,
    description: description,
    date: clearDate ? null : (date ?? this.date),
    endDate: endDate,
    start: clearTimes ? null : (start ?? this.start),
    end: clearTimes ? null : (end ?? this.end),
    typeId: typeId,
    priority: priority,
    group: group,
    eventKey: eventKey,
    links: links,
  );
}

/// Ein Seminarplan, der sich übernehmen lässt.
class ImportPlan {
  /// Stabile Kennung der Quelle (Teil aller Dokumentkennungen).
  final String sourceId;
  final String title;
  final String? subtitle;

  /// Zuordnung, die beim ersten Übernehmen angelegt wird.
  final String areaId;
  final String areaName;

  final List<ImportCandidate> candidates;

  const ImportPlan({
    required this.sourceId,
    required this.title,
    this.subtitle,
    required this.areaId,
    required this.areaName,
    required this.candidates,
  });

  static String docId(String sourceId, ImportCandidate c) => OrgIds.stable(
    c.kind == ImportKind.task ? "t" : "e",
    "$sourceId|${c.key}",
  );
}

enum ImportStatus {
  added("Neu"),
  changed("Geändert"),
  conflict("Geändert – deine Fassung bleibt"),
  unchanged("Übernommen"),
  removed("Entfällt im Plan"),
  dismissed("Von dir gelöscht");

  final String label;

  const ImportStatus(this.label);
}

/// Unterschied zwischen Plan und Bestand für einen Eintrag.
class ImportChange {
  final ImportStatus status;
  final ImportCandidate? candidate;

  /// Vorhandener Eintrag (Aufgabe oder Termin).
  final OrgItem? existing;

  /// Vorschlag, ob die Änderung übernommen wird.
  final bool suggested;

  /// Der Termin liegt schon in der Vergangenheit.
  final bool past;

  const ImportChange({
    required this.status,
    this.candidate,
    this.existing,
    required this.suggested,
    this.past = false,
  });

  String get key => candidate?.key ?? _sourceOf(existing)?.key ?? "";

  ImportKind get kind =>
      candidate?.kind ??
      (existing is OrgEvent ? ImportKind.event : ImportKind.task);

  /// Etwas zu tun (nicht nur „schon übernommen“).
  bool get actionable => status != ImportStatus.unchanged;
}

OrgSource? _sourceOf(OrgItem? item) => switch (item) {
  OrgTask() => item.source,
  OrgEvent() => item.source,
  _ => null,
};

class ImportDiff {
  final ImportPlan plan;
  final List<ImportChange> changes;

  const ImportDiff(this.plan, this.changes);

  int count(ImportStatus status) =>
      changes.where((c) => c.status == status).length;

  /// Vorgeschlagene Änderungen (Neues, Geändertes, Entfallenes).
  bool get hasUpdates => changes.any(
    (c) =>
        c.suggested &&
        (c.status == ImportStatus.added ||
            c.status == ImportStatus.changed ||
            c.status == ImportStatus.removed),
  );
}

/// Vergleich und Übernahme.
class SeminarImporter {
  SeminarImporter._();

  static ImportDiff diff(
    ImportPlan plan, {
    required Iterable<OrgTask> tasks,
    required Iterable<OrgEvent> events,
    required OrgDate today,
  }) {
    final existing = <String, OrgItem>{};
    for (final t in tasks) {
      final s = t.source;
      if (s != null && s.sourceId == plan.sourceId) {
        existing["task|${s.key}"] = t;
      }
    }
    for (final e in events) {
      final s = e.source;
      if (s != null && s.sourceId == plan.sourceId) {
        existing["event|${s.key}"] = e;
      }
    }

    final changes = <ImportChange>[];
    final seen = <String>{};
    for (final c in plan.candidates) {
      final k = "${c.kind.name}|${c.key}";
      if (!seen.add(k)) continue;
      final item = existing[k];
      final past = c.date != null && (c.endDate ?? c.date!).isBefore(today);
      if (item == null) {
        changes.add(
          ImportChange(
            status: ImportStatus.added,
            candidate: c,
            suggested: !past,
            past: past,
          ),
        );
        continue;
      }
      final source = _sourceOf(item)!;
      final deleted = item is OrgTask
          ? item.deleted
          : (item as OrgEvent).deleted;
      if (deleted) {
        changes.add(
          ImportChange(
            status: ImportStatus.dismissed,
            candidate: c,
            existing: item,
            suggested: false,
            past: past,
          ),
        );
        continue;
      }
      if (source.fingerprint == c.fingerprint) {
        changes.add(
          ImportChange(
            status: ImportStatus.unchanged,
            candidate: c,
            existing: item,
            suggested: false,
            past: past,
          ),
        );
        continue;
      }
      final done = item is OrgTask && item.done;
      final protected = source.edited || done;
      changes.add(
        ImportChange(
          status: protected ? ImportStatus.conflict : ImportStatus.changed,
          candidate: c,
          existing: item,
          suggested: !protected,
          past: past,
        ),
      );
    }

    for (final e in existing.entries) {
      if (seen.contains(e.key)) continue;
      final item = e.value;
      final deleted = item is OrgTask
          ? item.deleted
          : (item as OrgEvent).deleted;
      if (deleted) continue;
      final source = _sourceOf(item)!;
      final done = item is OrgTask && item.done;
      changes.add(
        ImportChange(
          status: ImportStatus.removed,
          existing: item,
          suggested: !source.edited && !done,
        ),
      );
    }
    return ImportDiff(plan, changes);
  }

  /// Übernimmt die gewählten Änderungen. [edited]: in der Vorschau
  /// geänderte Fassungen (Schlüssel → Eintrag); sie gelten als bearbeitet.
  /// Liefert die Anzahl geschriebener Einträge.
  static Future<int> apply(
    OrganizerController controller,
    ImportDiff diff, {
    required Set<String> selected,
    Map<String, ImportCandidate> edited = const {},
    String? areaId,
  }) async {
    final plan = diff.plan;
    final area = areaId ?? plan.areaId;
    if (controller.area(area) == null) {
      controller.newArea(name: plan.areaName, id: area);
    }

    // Kennungen der Sitzungstermine, die es nach der Übernahme gibt.
    final eventIds = <String, String>{};
    for (final change in diff.changes) {
      final c = change.candidate;
      if (c == null || c.kind != ImportKind.event) continue;
      final willExist =
          change.status == ImportStatus.unchanged ||
          change.status == ImportStatus.conflict ||
          change.status == ImportStatus.changed ||
          selected.contains(_selKey(change));
      if (willExist) eventIds[c.key] = ImportPlan.docId(plan.sourceId, c);
    }

    var written = 0;
    // Termine zuerst, damit Aufgaben auf sie verweisen können.
    final ordered = [
      ...diff.changes.where((c) => c.kind == ImportKind.event),
      ...diff.changes.where((c) => c.kind == ImportKind.task),
    ];
    for (final change in ordered) {
      if (!selected.contains(_selKey(change))) continue;
      final original = change.candidate;
      final candidate = edited[_selKey(change)] ?? original;
      final wasEdited =
          original != null &&
          candidate != null &&
          candidate.fingerprint != original.fingerprint;
      switch (change.status) {
        case ImportStatus.unchanged:
          continue;
        case ImportStatus.removed:
          final item = change.existing;
          if (item is OrgTask) await controller.deleteTask(item);
          if (item is OrgEvent) await controller.deleteEvent(item);
          written++;
        case ImportStatus.added ||
            ImportStatus.dismissed ||
            ImportStatus.changed ||
            ImportStatus.conflict:
          final source = OrgSource(
            sourceId: plan.sourceId,
            key: original!.key,
            fingerprint: original.fingerprint,
            edited: wasEdited,
          );
          await controller.writeImported(
            _build(
              controller,
              candidate!,
              source: source,
              id: ImportPlan.docId(plan.sourceId, original),
              existing: change.existing,
              areaId: area,
              eventId: candidate.eventKey == null
                  ? null
                  : eventIds[candidate.eventKey],
            ),
          );
          written++;
      }
    }
    return written;
  }

  /// Schlüssel einer Änderung für Auswahl und Bearbeitung.
  static String selectionKey(ImportChange change) => _selKey(change);

  static String _selKey(ImportChange c) => "${c.kind.name}|${c.key}";

  static OrgItem _build(
    OrganizerController controller,
    ImportCandidate c, {
    required OrgSource source,
    required String id,
    required OrgItem? existing,
    required String areaId,
    required String? eventId,
  }) {
    final stamp = controller.now.millisecondsSinceEpoch;
    if (c.kind == ImportKind.task) {
      final old = existing is OrgTask ? existing : null;
      return OrgTask(
        id: id,
        title: c.title,
        notes: c.description,
        due: c.date,
        dueTime: c.date == null ? null : c.start,
        // Eigene Einordnung und Status bleiben.
        areaId: old?.areaId ?? areaId,
        priority: old?.priority ?? c.priority,
        done: old?.done ?? false,
        doneAt: old?.doneAt,
        eventId: eventId ?? old?.eventId,
        links: old?.links ?? c.links,
        repeat: old?.repeat,
        trackId: old?.trackId,
        source: source,
        createdAt: old?.createdAt ?? stamp,
        updatedAt: stamp,
      );
    }
    final old = existing is OrgEvent ? existing : null;
    return OrgEvent(
      id: id,
      title: c.title,
      date: c.date ?? controller.today,
      endDate: c.endDate,
      allDay: c.start == null,
      start: c.start,
      end: c.start == null ? null : c.end,
      location: old?.location ?? "",
      description: c.description,
      typeId: c.typeId,
      areaId: old?.areaId ?? areaId,
      reminderMinutes: old?.reminderMinutes,
      links: old?.links ?? c.links,
      source: source,
      createdAt: old?.createdAt ?? stamp,
      updatedAt: stamp,
    );
  }

  /// Automatische Übernahme: nur Neues (nicht Vergangenes) und Änderungen
  /// unberührter Einträge; nie Löschungen, nie Bearbeitetes.
  static Future<int> applyAutomatic(
    OrganizerController controller,
    ImportDiff diff, {
    String? areaId,
  }) {
    final selected = {
      for (final c in diff.changes)
        if ((c.status == ImportStatus.added && c.suggested) ||
            c.status == ImportStatus.changed)
          _selKey(c),
    };
    if (selected.isEmpty) return Future.value(0);
    return apply(controller, diff, selected: selected, areaId: areaId);
  }
}

// ==========================
// QUELLEN
// ==========================

/// Kurzer Titel aus einem Satz des Seminarplans (voller Text bleibt in der
/// Beschreibung).
String shortTaskTitle(String text, {int max = 90}) {
  var t = text.trim().replaceAll(RegExp(r"\s+"), " ");
  if (t.endsWith(".")) t = t.substring(0, t.length - 1);
  if (t.length <= max) return t;
  final cut = t.lastIndexOf(" ", max - 1);
  return "${t.substring(0, cut > 40 ? cut : max - 1)} …";
}

/// Proseminar der Kirchengeschichte (assets/church_history/seminar.json):
/// Sitzungen als Termine, „Aufgaben zur n. Sitzung“ als Aufgaben, fällig
/// zur n. Sitzung. Referate anderer, Literaturlisten und Formalia werden
/// nicht zu Aufgaben.
class ChurchHistorySeminarImport {
  ChurchHistorySeminarImport._();

  static const String sourceId = "ch-seminar";
  static const String areaId = "area_ch_seminar";

  static final RegExp _tasksFor = RegExp(
    r"^Aufgaben zur (\d+)\. Sitzung",
    caseSensitive: false,
  );

  static ImportPlan? plan(
    ChurchHistoryData data, {
    required OrgDate today,
    OrgTime? start,
    OrgTime? end,
    bool sessions = true,
  }) {
    Course? course;
    for (final c in data.courses) {
      if (c.kind == CourseKind.seminar) course = c;
    }
    if (course == null) return null;
    final units = [
      for (final u in data.units)
        if (u.courseId == course.id) u,
    ]..sort((a, b) => a.number.compareTo(b.number));
    final byNumber = {for (final u in units) u.number: u};
    final dates = {
      for (final u in units)
        u.number: u.date == null
            ? null
            : GermanDateParser.parse(u.date!, reference: today),
    };

    final shortName = course.title.contains(":")
        ? course.title.split(":").last.trim()
        : course.title;
    const link = OrgLink(
      type: "app",
      target: "/church-history",
      label: "Kirchengeschichte: Proseminar",
    );

    final candidates = <ImportCandidate>[];
    for (final u in units) {
      final group = "Sitzung ${u.number} · ${u.title}";
      if (sessions) {
        final topic = [
          for (final s in u.sections)
            if (!_tasksFor.hasMatch(s.title)) ...[
              "${s.title}:",
              for (final p in s.points) "– $p",
            ],
        ].join("\n");
        candidates.add(
          ImportCandidate(
            key: "${u.id}:event",
            kind: ImportKind.event,
            title: "Proseminar · Sitzung ${u.number}: ${u.title}",
            description: topic,
            date: dates[u.number],
            start: start,
            end: start == null ? null : end,
            typeId: OrgEventType.seminar.id,
            group: group,
            links: const [link],
          ),
        );
      }
      for (final s in u.sections) {
        final m = _tasksFor.firstMatch(s.title);
        if (m == null) continue;
        final target = int.parse(m.group(1)!);
        final targetUnit = byNumber[target];
        final ref = s.ref?.at == null ? "" : " (Seminarplan, ${s.ref!.at})";
        for (final (i, point) in s.points.indexed) {
          final title = shortTaskTitle(point);
          candidates.add(
            ImportCandidate(
              key: "${targetUnit?.id ?? "seminar.$target"}:task:$i",
              kind: ImportKind.task,
              title: title,
              description: title == point.trim().replaceAll(RegExp(r"\.$"), "")
                  ? "Zur $target. Sitzung$ref"
                  : "$point\n\nZur $target. Sitzung$ref",
              date: dates[target],
              typeId: "task",
              group: targetUnit == null
                  ? group
                  : "Sitzung ${targetUnit.number} · ${targetUnit.title}",
              eventKey: targetUnit == null || !sessions
                  ? null
                  : "${targetUnit.id}:event",
              links: const [link],
            ),
          );
        }
      }
    }
    return ImportPlan(
      sourceId: sourceId,
      title: "Proseminar Kirchengeschichte",
      subtitle: [shortName, ?course.semester].join(" · "),
      areaId: areaId,
      areaName: "Proseminar: $shortName",
      candidates: candidates,
    );
  }
}

/// Übung Bibelkunde AT (Leseplan zur Lehrveranstaltung): Sitzungen und
/// Zwischentests als Termine. Die Lektüre selbst erscheint nicht als
/// gespeicherte Aufgabe, sondern täglich aus dem Leseplan (siehe
/// `ReadingTask`).
class BibelkundeCourseImport {
  BibelkundeCourseImport._();

  static String sourceIdOf(CourseReadingPlan plan) => "course:${plan.id}";

  static const String areaId = "area_bibelkunde";

  static ImportPlan plan(
    CourseReadingPlan plan, {
    OrgTime? start,
    OrgTime? end,
    bool sessions = true,
  }) {
    final link = OrgLink(
      type: "app",
      target: "/bible/plan/${plan.id}",
      label: plan.name,
    );
    final candidates = <ImportCandidate>[
      if (sessions)
        for (final s in plan.sessions)
          ImportCandidate(
            key: "${s.id}:event",
            kind: ImportKind.event,
            title: "${plan.course.split("(").first.trim()}: ${s.topic}",
            description: [
              "Sitzung ${s.number}",
              if (s.readings.isNotEmpty)
                "Lektüre: ${[for (final r in s.readings) r.label].join("; ")}",
              ?s.note,
            ].join("\n"),
            date: OrgDate.of(s.date),
            start: start,
            end: start == null ? null : end,
            typeId: OrgEventType.bibelkunde.id,
            group: "Sitzungen",
            links: [link],
          ),
      for (final (i, m) in plan.milestones.indexed)
        ImportCandidate(
          key: "milestone:$i",
          kind: ImportKind.event,
          title: m.title,
          description: m.note ?? "",
          date: OrgDate.of(m.start),
          endDate: m.end == null ? null : OrgDate.of(m.end!),
          typeId: OrgEventType.exam.id,
          group: "Prüfungen und Zwischentests",
          links: [link],
        ),
    ];
    return ImportPlan(
      sourceId: sourceIdOf(plan),
      title: plan.course,
      subtitle: [?plan.lecturer, ?plan.semester].join(" · "),
      areaId: areaId,
      areaName: "Bibelkunde",
      candidates: candidates,
    );
  }
}

/// Eingefügter Seminarplan (Text, z. B. aus einem PDF kopiert).
///
/// Erkannt werden:
/// * Sitzungen: Zeilen wie „Sitzung 3 (4.11.): Thema“, „3. Sitzung – Thema“,
///   „04.11.2026: Thema“. Ohne Datum: erste Sitzung + Abstand.
/// * Vorbereitungsaufgaben: Zeilen mit einem Arbeitsauftrag (lesen,
///   vorbereiten, bearbeiten, übersetzen, lernen, …), fällig zur Sitzung, in
///   deren Block sie stehen – oder zur genannten („Aufgaben zur 4. Sitzung“,
///   „bis zur 4. Sitzung“) bzw. zum genannten Datum („bis 15.1.“).
/// * Abgaben und Prüfungen mit Datum: als hervorgehobener Termin, Abgaben
///   zusätzlich als Aufgabe.
/// Alles andere (Literatur, Formalia, Themen) wird nicht übernommen.
class SeminarTextParser {
  SeminarTextParser._();

  static final RegExp _session = RegExp(
    r"^(?:[-–•*]\s*)?(?:(\d{1,2})\.\s*(?:Sitzung|Termin|Woche)|(?:Sitzung|Termin|Woche)\s*(\d{1,2})\.?)\s*(.*)$",
    caseSensitive: false,
  );

  static final RegExp _datedLine = RegExp(
    r"^(?:[-–•*]\s*)?(?:(?:Mo|Di|Mi|Do|Fr|Sa|So)\.?,?\s*)?(\d{1,2}\.\s?\d{1,2}\.(?:\d{2,4})?)\s*[:\-–]?\s*(.*)$",
  );

  static final RegExp _forSession = RegExp(
    r"(?:Aufgaben?|Vorbereitung|Lektüre)?\s*(?:zur|für die|auf die|bis zur)\s+(\d{1,2})\.\s*Sitzung",
    caseSensitive: false,
  );

  static final RegExp _task = RegExp(
    r"(lesen|lies\b|lektüre|vorbereit|bearbeit|übersetz|lernen|wiederhol|"
    r"notier|zusammenfass|recherchier|exzerp|schreib|formulier|mitbring|"
    r"\berstell|\bausarbeit|abgeben|abgabe|einreich|anschau|ansehen|hören|"
    r"anhören|referat halten|überleg|beantwort)",
    caseSensitive: false,
  );

  static final RegExp _deadline = RegExp(
    r"(abgabe|abgeben|einreich|deadline|frist)",
    caseSensitive: false,
  );

  static final RegExp _exam = RegExp(
    r"(klausur|prüfung|zwischentest|test\b|examen)",
    caseSensitive: false,
  );

  static final RegExp _until = RegExp(
    r"\b(?:bis|bis zum|spätestens|am)\s+",
    caseSensitive: false,
  );

  static List<ImportCandidate> parse(
    String text, {
    required OrgDate today,
    OrgDate? firstSession,
    int intervalDays = 7,
    OrgTime? start,
    OrgTime? end,
    bool sessions = true,
    List<OrgLink> links = const [],
  }) {
    final reference = firstSession ?? today;
    final result = <ImportCandidate>[];
    final sessionDates = <int, OrgDate?>{};
    final sessionTitles = <int, String>{};
    final taskCounts = <int, int>{};
    var deadlineCount = 0;
    var looseCount = 0;

    // Erster Durchgang: Sitzungen und ihre Termine.
    final lines = [
      for (final l in text.split(RegExp(r"\r?\n")))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    final parsed = <(int?, String, bool)>[]; // (Sitzung, Text, Kopfzeile)
    int? current;
    var lastNumber = 0;
    for (final line in lines) {
      final header = _header(line, reference);
      if (header != null) {
        final number = header.number ?? lastNumber + 1;
        lastNumber = number;
        current = number;
        sessionDates[number] =
            header.date ?? firstSession?.addDays(intervalDays * (number - 1));
        sessionTitles[number] = header.rest;
        parsed.add((number, header.rest, true));
      } else {
        parsed.add((current, line, false));
      }
    }

    // Termine ohne Datum hinter datierten Sitzungen weiterzählen.
    final numbers = sessionDates.keys.toList()..sort();
    for (final n in numbers) {
      if (sessionDates[n] != null) continue;
      for (final m in numbers.reversed) {
        if (m < n && sessionDates[m] != null) {
          sessionDates[n] = sessionDates[m]!.addDays(intervalDays * (n - m));
          break;
        }
      }
    }

    if (sessions) {
      for (final n in numbers) {
        final title = sessionTitles[n]!;
        result.add(
          ImportCandidate(
            key: "s$n:event",
            kind: ImportKind.event,
            title: title.isEmpty
                ? "Sitzung $n"
                : "Sitzung $n: ${shortTaskTitle(title, max: 70)}",
            description: title.length > 70 ? title : "",
            date: sessionDates[n],
            start: start,
            end: start == null ? null : end,
            typeId: OrgEventType.seminar.id,
            group: "Sitzung $n",
            links: links,
          ),
        );
      }
    }

    // Zweiter Durchgang: Aufgaben, Abgaben, Prüfungen.
    int? target;
    int? targetBlock;
    for (final (session, line, isHeader) in parsed) {
      if (isHeader) {
        target = null;
        targetBlock = session;
      }
      final body = line.replaceFirst(RegExp(r"^[-–•*]\s*"), "");
      final forSession = _forSession.firstMatch(body);
      if (forSession != null) {
        final n = int.parse(forSession.group(1)!);
        final rest = body
            .substring(forSession.end)
            .replaceFirst(RegExp(r"^\s*[:\-–]\s*"), "");
        if (rest.trim().isEmpty || !_task.hasMatch(rest)) {
          // Überschrift wie „Aufgaben zur 4. Sitzung:“ – gilt für die
          // folgenden Zeilen dieses Blocks.
          target = n;
          if (rest.trim().isEmpty) continue;
        }
      }
      if (body.isEmpty || !_task.hasMatch(body) && !_exam.hasMatch(body)) {
        continue;
      }
      // Datum in der Zeile (nur bei Nicht-Kopfzeilen bzw. mit „bis“).
      final found = GermanDateParser.find(body, reference: reference);
      final explicit =
          found != null &&
          (!isHeader || _until.hasMatch(body.substring(0, found.start)));
      final isExam =
          _exam.hasMatch(body) && !_task.hasMatch(body.replaceAll(_exam, ""));
      final isDeadline = _deadline.hasMatch(body) && explicit;

      if (isExam && explicit && !isHeader) {
        result.add(
          ImportCandidate(
            key: "x${deadlineCount++}:event",
            kind: ImportKind.event,
            title: shortTaskTitle(_strip(body, found), max: 70),
            description: body,
            date: found.date,
            typeId: OrgEventType.exam.id,
            group: "Prüfungen und Abgaben",
            links: links,
          ),
        );
        continue;
      }
      if (isExam && !_task.hasMatch(body)) continue;

      if (isDeadline) {
        final key = "d${deadlineCount++}";
        result.add(
          ImportCandidate(
            key: "$key:event",
            kind: ImportKind.event,
            title: shortTaskTitle(_strip(body, found), max: 70),
            description: body,
            date: found.date,
            typeId: OrgEventType.deadline.id,
            group: "Prüfungen und Abgaben",
            links: links,
          ),
        );
        result.add(
          ImportCandidate(
            key: "$key:task",
            kind: ImportKind.task,
            title: shortTaskTitle(_strip(body, found)),
            description: body,
            date: found.date,
            priority: OrgPriority.high,
            group: "Prüfungen und Abgaben",
            eventKey: "$key:event",
            links: links,
          ),
        );
        continue;
      }

      final n = target ?? targetBlock;
      final title = shortTaskTitle(explicit ? _strip(body, found) : body);
      if (n == null) {
        result.add(
          ImportCandidate(
            key: "l${looseCount++}:task",
            kind: ImportKind.task,
            title: title,
            description: title == body ? "" : body,
            date: explicit ? found.date : null,
            group: "Ohne Sitzung",
            links: links,
          ),
        );
        continue;
      }
      final i = taskCounts[n] = (taskCounts[n] ?? 0) + 1;
      result.add(
        ImportCandidate(
          key: "s$n:t$i",
          kind: ImportKind.task,
          title: title,
          description: title == body
              ? "Zur $n. Sitzung"
              : "$body\n\nZur $n. Sitzung",
          date: explicit ? found.date : sessionDates[n],
          group: "Sitzung $n",
          eventKey: sessions && sessionDates.containsKey(n)
              ? "s$n:event"
              : null,
          links: links,
        ),
      );
    }
    return result;
  }

  static ({int? number, OrgDate? date, String rest})? _header(
    String line,
    OrgDate reference,
  ) {
    final m = _session.firstMatch(line);
    if (m != null) {
      final number = int.tryParse(m.group(1) ?? m.group(2) ?? "");
      var rest = m.group(3)!.trim();
      final found = GermanDateParser.find(rest, reference: reference);
      OrgDate? date;
      if (found != null && found.start <= 3) {
        date = found.date;
        rest = rest.substring(found.end);
      } else if (found != null && rest.startsWith("(")) {
        date = found.date;
        rest = rest.substring(found.end);
      }
      rest = rest
          .replaceFirst(RegExp(r"^[\s)\]]*"), "")
          .replaceFirst(RegExp(r"^[:\-–,.]\s*"), "")
          .trim();
      return (number: number, date: date, rest: rest);
    }
    final d = _datedLine.firstMatch(line);
    if (d != null && !_until.hasMatch(line.substring(0, d.start))) {
      final date = GermanDateParser.parse(d.group(1)!, reference: reference);
      if (date == null) return null;
      // Datierte Zeilen mit Abgabe/Prüfung sind keine Sitzung.
      final rest = d.group(2)!.trim();
      if (_deadline.hasMatch(rest) || _exam.hasMatch(rest)) return null;
      return (number: null, date: date, rest: rest);
    }
    return null;
  }

  /// Text ohne „bis 15.1.“.
  static String _strip(
    String body,
    ({OrgDate date, int start, int end})? found,
  ) {
    if (found == null) return body;
    final before = body
        .substring(0, found.start)
        .replaceFirst(
          RegExp(
            r"\s*\(?\s*(?:bis zum|bis|spätestens|am)?\s*$",
            caseSensitive: false,
          ),
          "",
        );
    final after = body
        .substring(found.end)
        .replaceFirst(RegExp(r"^\s*\)?"), "");
    final joined = "$before $after".trim().replaceAll(RegExp(r"\s+"), " ");
    return joined.replaceAll(RegExp(r"^[:\-–,]\s*|[:\-–,]\s*$"), "").trim();
  }
}
