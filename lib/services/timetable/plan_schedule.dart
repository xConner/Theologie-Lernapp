import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/course_snapshot.dart';
import '../../models/timetable/timetable_entry.dart';
import 'timetable_schedule.dart';

// Persönlicher Stundenplan als Termine: Je Eintrag werden die importierten
// Daten (aktueller Fakultätskatalog, sonst der gespeicherte Import) mit den
// persönlichen Anpassungen zusammengeführt. Rein und ohne Flutter – getestet
// in test/study_organization_logic_test.dart.

/// Woher die Termine eines Eintrags stammen.
enum PlanSource {
  /// Aktueller Fakultätskatalog (bei jedem Laden abgeglichen).
  catalog,

  /// Gespeicherter Import (z. B. aus der fakultätsübergreifenden Suche).
  snapshot,

  /// Keine Daten: alter Eintrag, dessen Veranstaltung im Katalog fehlt.
  missing,
}

/// Ein Termin im persönlichen Plan.
class PlanOccurrence {
  final String id;

  /// Kennung des Eintrags (= `TimetableEntry.courseId`).
  final String entryId;
  final String ruleId;
  final LocalDateTime start;
  final LocalDateTime end;
  final String? room;
  final bool cancelled;

  /// Wöchentlich wiederkehrend (sonst Einzel- bzw. Blocktermin).
  final bool regular;

  /// Durch eine persönliche Anpassung entstanden oder verändert.
  final bool adjusted;

  const PlanOccurrence({
    required this.id,
    required this.entryId,
    required this.ruleId,
    required this.start,
    required this.end,
    this.room,
    this.cancelled = false,
    this.regular = true,
    this.adjusted = false,
  });

  String get date => start.date;
  bool get spansDays => end.date != start.date;
  Duration get duration => end.instant.difference(start.instant);
}

/// Eine Terminregel, wie sie (nach Anpassung) gilt.
class PlanRule {
  final String id;
  final SessionRule rule;
  final String? room;
  final RuleOverride? override;

  /// Selbst ergänzt ([ExtraSession]).
  final bool extra;

  const PlanRule(
    this.id,
    this.rule, {
    this.room,
    this.override,
    this.extra = false,
  });

  bool get removed => override?.removed ?? false;
}

/// Eine Veranstaltung des Plans mit allen angezeigten Angaben.
class PlanCourse {
  final TimetableEntry entry;
  final PlanSource source;

  /// Importierte Daten (aktueller Katalog bzw. gespeicherter Import).
  final CourseSnapshot? imported;
  final List<PlanRule> rules;
  final List<PlanOccurrence> occurrences;

  /// Die Quelle hat Termine oder Räume geändert, seit der Eintrag gespeichert
  /// bzw. zuletzt übernommen wurde.
  final bool sourceChanged;

  const PlanCourse({
    required this.entry,
    required this.source,
    required this.imported,
    required this.rules,
    required this.occurrences,
    this.sourceChanged = false,
  });

  String get id => entry.courseId;
  String get title => entry.overrides.title ?? imported?.title ?? entry.title;
  String? get number => imported?.number ?? entry.number;
  List<String> get lecturers {
    final custom = entry.overrides.lecturers;
    if (custom != null) return [custom];
    return imported?.lecturers ?? const [];
  }

  String? get faculty => imported?.faculty;
  String? get institute => imported?.institute;
  bool get hasOverrides => !entry.overrides.isEmpty;
  bool get hasRegular => occurrences.any((o) => o.regular);
  bool get hasSpecial => occurrences.any((o) => !o.regular);
}

/// Daten eines Eintrags: aktueller Fakultätskatalog, sonst gespeicherter
/// Import.
PlanCourse resolvePlanCourse(TimetableEntry entry, {CourseCatalog? catalog}) {
  final inCatalog = catalog == null ? null : catalogCourseFor(entry, catalog);
  final CourseSnapshot? imported;
  final PlanSource source;
  if (inCatalog != null) {
    imported = CourseSnapshot.fromCatalog(
      catalog!,
      inCatalog,
      fromFacultyCatalog: true,
    );
    source = PlanSource.catalog;
  } else if (entry.snapshot != null) {
    imported = entry.snapshot;
    source = PlanSource.snapshot;
  } else {
    imported = null;
    source = PlanSource.missing;
  }
  final semester =
      imported?.semester ??
      entry.snapshot?.semester ??
      (catalog != null &&
              (entry.semesterId.isEmpty ||
                  entry.semesterId == catalog.semester.id)
          ? catalog.semester
          : null);

  final overrides = entry.overrides;
  final rules = <PlanRule>[];
  final occurrences = <PlanOccurrence>[];
  for (final r in imported?.rules ?? const <SnapshotRule>[]) {
    final o = overrides.rules[r.id];
    final rule = _applyRule(r.rule, o);
    final room = o?.room ?? r.room;
    rules.add(PlanRule(r.id, rule, room: room, override: o));
    if (o?.removed ?? false) continue;
    final imports = [
      for (final occ in imported!.occurrences)
        if (occ.ruleId == r.id) occ,
    ];
    occurrences.addAll(
      _occurrencesOf(entry.courseId, r, rule, o, imports, room, semester),
    );
  }
  for (final x in overrides.extraSessions) {
    final rule = SessionRule(
      id: "extra:${x.id}",
      kind: RepeatKind.weekly,
      intervalWeeks: 1,
      weekdays: [x.weekday],
      startTime: x.startTime,
      endTime: x.endTime,
    );
    rules.add(PlanRule(rule.id, rule, room: x.room, extra: true));
    if (semester == null) continue;
    for (final date in weeklyDates(semester, x.weekday)) {
      occurrences.add(
        PlanOccurrence(
          id: "${entry.courseId}@${rule.id}@$date",
          entryId: entry.courseId,
          ruleId: rule.id,
          start: berlinLocal(date, x.startTime),
          end: berlinLocal(date, x.endTime),
          room: x.room,
          adjusted: true,
        ),
      );
    }
  }
  occurrences.sort((a, b) => a.start.instant.compareTo(b.start.instant));

  final changed =
      source == PlanSource.catalog &&
      entry.scheduleSignature.isNotEmpty &&
      imported!.scheduleSignature != entry.scheduleSignature;

  return PlanCourse(
    entry: entry,
    source: source,
    imported: imported,
    rules: rules,
    occurrences: occurrences,
    sourceChanged: changed,
  );
}

SessionRule _applyRule(SessionRule rule, RuleOverride? o) {
  if (o == null || o.isEmpty) return rule;
  return SessionRule(
    id: rule.id,
    kind: rule.kind,
    intervalWeeks: rule.intervalWeeks,
    weekdays: o.weekday != null && rule.kind == RepeatKind.weekly
        ? [o.weekday!]
        : rule.weekdays,
    startTime: o.startTime ?? rule.startTime,
    endTime: o.endTime ?? rule.endTime,
    startDate: rule.startDate,
    endDate: rule.endDate,
    excludedDates: rule.excludedDates,
    roomId: rule.roomId,
  );
}

/// Termine einer Regel. Ohne Anpassung: die importierten. Mit Anpassung:
/// dieselben Daten (Ferien und Ausfälle bleiben), verschoben auf den neuen
/// Wochentag bzw. die neue Uhrzeit. Hat die Quelle keine Termine (z. B.
/// fehlende Uhrzeit), entstehen sie aus der ergänzten Angabe neu – nur für
/// wöchentliche Regeln mit eindeutigem Rhythmus.
List<PlanOccurrence> _occurrencesOf(
  String entryId,
  SnapshotRule source,
  SessionRule rule,
  RuleOverride? o,
  List<SnapshotOccurrence> imports,
  String? room,
  CatalogSemester? semester,
) {
  final regular = source.rule.kind == RepeatKind.weekly;
  final adjusted = o != null && !o.isEmpty;
  PlanOccurrence make(
    LocalDateTime start,
    LocalDateTime end, {
    String? occRoom,
    bool cancelled = false,
  }) => PlanOccurrence(
    id: "$entryId@${source.id}@${start.date}",
    entryId: entryId,
    ruleId: source.id,
    start: start,
    end: end,
    room: o?.room ?? occRoom ?? room,
    cancelled: cancelled,
    regular: regular,
    adjusted: adjusted,
  );

  if (o == null ||
      !adjusted ||
      (o.weekday == null && o.startTime == null && o.endTime == null)) {
    return [
      for (final i in imports)
        make(i.start, i.end, occRoom: i.room, cancelled: i.cancelled),
    ];
  }

  if (imports.isNotEmpty) {
    final shift =
        regular && o.weekday != null && source.rule.weekdays.length == 1
        ? o.weekday! - source.rule.weekdays.first
        : 0;
    final result = <PlanOccurrence>[];
    for (final i in imports) {
      final startDate = addDays(i.start.date, shift);
      final endDate = addDays(i.end.date, shift);
      if (shift != 0 &&
          semester != null &&
          breakOn(semester, startDate) != null) {
        continue;
      }
      final start = berlinLocal(startDate, o.startTime ?? i.start.time);
      final end = berlinLocal(endDate, o.endTime ?? i.end.time);
      if (!end.instant.isAfter(start.instant)) continue;
      result.add(make(start, end, occRoom: i.room, cancelled: i.cancelled));
    }
    return result;
  }

  // Keine importierten Termine: nur eindeutige wöchentliche Regeln ergänzen.
  if (!regular ||
      (rule.intervalWeeks ?? 1) != 1 ||
      rule.weekdays.isEmpty ||
      rule.startTime == null ||
      rule.endTime == null ||
      semester == null ||
      rule.startTime!.compareTo(rule.endTime!) >= 0) {
    return const [];
  }
  return [
    for (final weekday in rule.weekdays)
      for (final date in weeklyDates(
        semester,
        weekday,
        from: rule.startDate,
        to: rule.endDate,
      ))
        if (!rule.excludedDates.contains(date))
          make(
            berlinLocal(date, rule.startTime!),
            berlinLocal(date, rule.endTime!),
          ),
  ];
}

// --- Termine aus eigenen Angaben ----------------------------------------------

/// Daten eines Wochentags in der Vorlesungszeit (optional eingegrenzt),
/// ohne unterrichtsfreie Tage.
List<String> weeklyDates(
  CatalogSemester semester,
  int weekday, {
  String? from,
  String? to,
}) {
  var first = semester.lectureStart;
  if (from != null && from.compareTo(first) > 0) first = from;
  var last = semester.lectureEnd;
  if (to != null && to.compareTo(last) < 0) last = to;
  if (first.isEmpty || last.isEmpty) return const [];
  final delta = (weekday - weekdayOf(first) + 7) % 7;
  final dates = <String>[];
  for (
    var d = addDays(first, delta);
    d.compareTo(last) <= 0;
    d = addDays(d, 7)
  ) {
    if (breakOn(semester, d) == null) dates.add(d);
  }
  return dates;
}

/// Letzter Sonntag eines Monats (`YYYY-MM-DD`).
String _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  return last
      .subtract(Duration(days: last.weekday % 7))
      .toIso8601String()
      .substring(0, 10);
}

/// Ortszeit in Kiel (Europe/Berlin) mit passendem Offset: Sommerzeit vom
/// letzten Sonntag im März (02:00) bis zum letzten Sonntag im Oktober (03:00).
LocalDateTime berlinLocal(String date, String time) {
  final year = int.parse(date.substring(0, 4));
  final dstStart = "${_lastSunday(year, 3)}T02:00";
  final dstEnd = "${_lastSunday(year, 10)}T03:00";
  final local = "${date}T$time";
  final summer = local.compareTo(dstStart) >= 0 && local.compareTo(dstEnd) < 0;
  final offset = summer ? "+02:00" : "+01:00";
  return LocalDateTime.tryParse("$local:00$offset")!;
}
