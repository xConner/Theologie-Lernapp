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

/// Art eines Termins. Eine einzige Einordnung für Wochenansicht, Filter,
/// Überschneidungen und PDF-Export ([classifyOccurrences]): aus der
/// Terminregel der Quelle und den tatsächlichen Daten, ohne einen Rhythmus
/// zu erfinden.
enum SessionKind {
  /// Jede Woche (Regel „wöchentlich“ bzw. Einzeltermine im Wochenabstand).
  weekly,

  /// Regelmäßig mit bekanntem Abstand von mehreren Wochen (z. B. 14-täglich).
  recurring,

  /// Mindestens drei Termine am selben Wochentag zur selben Uhrzeit in
  /// verschiedenen Wochen, aber ohne gleichmäßigen Abstand.
  series,

  /// Regel „alle n Wochen“ ohne Startwoche: Wochentag und Uhrzeit sind
  /// bekannt, die Wochen nicht. Die Termine stehen in jeder Vorlesungswoche
  /// als „unsicher“ und zählen nicht als Überschneidung.
  tentative,

  /// Blockveranstaltung (zusammenhängende Tage bzw. durchgehender Zeitraum).
  block,

  /// Einzeltermin ohne erkennbare Serie.
  single;

  /// Gehört zu den regelmäßigen Veranstaltungen (Wochenraster, Filter
  /// „Regelmäßige“); sonst Block- bzw. Einzeltermin.
  bool get regular => switch (this) {
    weekly || recurring || series || tentative => true,
    block || single => false,
  };
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

  final SessionKind kind;

  /// Abstand in Wochen ([SessionKind.weekly] 1, [SessionKind.recurring] und
  /// [SessionKind.tentative] laut Regel bzw. Daten); sonst null (unbekannt).
  final int? intervalWeeks;

  /// Termine derselben Serie (Regel, bzw. erkannte Serie aus Einzelterminen
  /// mehrerer Regeln).
  final String? series;

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
    this.kind = SessionKind.weekly,
    this.intervalWeeks,
    this.series,
    this.adjusted = false,
  });

  /// Kennung der Serie (ohne erkannte Serie: die Regel).
  String get seriesId => series ?? ruleId;

  /// Regelmäßig (auch nicht wöchentlich); sonst Block- bzw. Einzeltermin.
  bool get regular => kind.regular;

  /// Datum unbekannt (siehe [SessionKind.tentative]).
  bool get tentative => kind == SessionKind.tentative;

  PlanOccurrence copyWith({
    String? entryId,
    SessionKind? kind,
    int? intervalWeeks,
    String? series,
  }) => PlanOccurrence(
    id: id,
    entryId: entryId ?? this.entryId,
    ruleId: ruleId,
    start: start,
    end: end,
    room: room,
    cancelled: cancelled,
    kind: kind ?? this.kind,
    intervalWeeks: kind != null ? intervalWeeks : this.intervalWeeks,
    series: series ?? this.series,
    adjusted: adjusted,
  );

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
          intervalWeeks: 1,
          adjusted: true,
        ),
      );
    }
  }
  occurrences.sort((a, b) => a.start.instant.compareTo(b.start.instant));
  final classified = classifyOccurrences(occurrences, semester);

  final changed =
      source == PlanSource.catalog &&
      entry.scheduleSignature.isNotEmpty &&
      imported!.scheduleSignature != entry.scheduleSignature;

  return PlanCourse(
    entry: entry,
    source: source,
    imported: imported,
    rules: rules,
    occurrences: classified,
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
  final interval = regular ? (source.rule.intervalWeeks ?? 1) : null;
  final kind = switch (source.rule.kind) {
    RepeatKind.weekly =>
      interval == 1 ? SessionKind.weekly : SessionKind.recurring,
    RepeatKind.block => SessionKind.block,
    RepeatKind.single || RepeatKind.unknown => SessionKind.single,
  };
  final adjusted = o != null && !o.isEmpty;
  PlanOccurrence make(
    LocalDateTime start,
    LocalDateTime end, {
    String? occRoom,
    bool cancelled = false,
    SessionKind? as,
  }) => PlanOccurrence(
    id: "$entryId@${source.id}@${start.date}",
    entryId: entryId,
    ruleId: source.id,
    start: start,
    end: end,
    room: o?.room ?? occRoom ?? room,
    cancelled: cancelled,
    kind: as ?? kind,
    intervalWeeks: interval,
    adjusted: adjusted,
  );

  // „Alle n Wochen“ ohne Startwoche: Die Quelle liefert keine Termine. Der
  // Wochentag und die Uhrzeit sind bekannt; in welchen Wochen, nicht.
  // Daher in jeder Vorlesungswoche als unsicher – nie als feste Termine.
  if (imports.isEmpty && regular && interval! > 1) {
    if (rule.weekdays.isEmpty ||
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
              as: SessionKind.tentative,
            ),
    ];
  }

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

// --- Einordnung ---------------------------------------------------------------

/// Erkennt Serien in Block- und Einzelterminen einer Veranstaltung: Liegen
/// mindestens drei Termine am selben Wochentag zur selben Uhrzeit in
/// verschiedenen Wochen, sind sie regelmäßig – wöchentlich bzw. alle n
/// Wochen, wenn der Abstand (ohne unterrichtsfreie Wochen) immer gleich ist,
/// sonst „nicht wöchentlich“ ohne Angabe eines Rhythmus. Zwei Termine
/// genügen nicht für einen Rhythmus; zusammenhängende Blocktage (drei und
/// mehr Tage in Folge, auch über mehrere Wochen) bleiben ein Block. Wöchentliche Regeln der Quelle bleiben unverändert.
List<PlanOccurrence> classifyOccurrences(
  List<PlanOccurrence> occurrences,
  CatalogSemester? semester,
) {
  // Tage in einer Folge von mindestens drei aufeinanderfolgenden Tagen
  // gehören zu einem Block (z. B. Mo–Fr über mehrere Wochen), nicht zu einer
  // Wochenserie.
  final days = <String, Set<String>>{};
  for (final o in occurrences) {
    if (!o.regular && !o.spansDays) (days[o.entryId] ??= {}).add(o.date);
  }
  bool inRun(PlanOccurrence o) {
    final d = days[o.entryId]!;
    bool has(int offset) => d.contains(addDays(o.date, offset));
    return (has(-1) && has(1)) || (has(-2) && has(-1)) || (has(1) && has(2));
  }

  final groups = <String, List<PlanOccurrence>>{};
  for (final o in occurrences) {
    if (o.regular || o.spansDays || inRun(o)) continue;
    final key = [
      o.entryId,
      weekdayOf(o.date),
      o.start.time,
      o.end.time,
    ].join("|");
    (groups[key] ??= []).add(o);
  }
  final replaced = <String, PlanOccurrence>{};
  for (final MapEntry(key: key, value: list) in groups.entries) {
    final dates = {for (final o in list) o.date}.toList()..sort();
    if (dates.length < 3) continue;
    // Höchstens ein Termin je Woche, sonst eher Blocktage.
    if ({for (final d in dates) mondayOf(d)}.length != dates.length) continue;
    final gaps = {
      for (var i = 1; i < dates.length; i++)
        _lectureWeeksBetween(dates[i - 1], dates[i], semester),
    };
    // Einen Abstand nennen erst ab vier Terminen (drei gleiche Abstände
    // wären ein schwacher Beleg).
    final interval = gaps.length == 1 && dates.length >= 4 ? gaps.single : null;
    final kind = switch (interval) {
      1 => SessionKind.weekly,
      final int n when n > 1 => SessionKind.recurring,
      _ => SessionKind.series,
    };
    final seriesId = "series:$key";
    for (final o in list) {
      replaced[o.id] = o.copyWith(
        kind: kind,
        intervalWeeks: kind == SessionKind.series ? null : interval,
        series: seriesId,
      );
    }
  }
  if (replaced.isEmpty) return occurrences;
  return [for (final o in occurrences) replaced[o.id] ?? o];
}

/// Abstand zweier Daten desselben Wochentags in Wochen, ohne Wochen, in
/// denen dieser Wochentag unterrichtsfrei ist.
int _lectureWeeksBetween(String a, String b, CatalogSemester? semester) {
  var weeks = 0;
  for (var d = addDays(a, 7); d.compareTo(b) <= 0; d = addDays(d, 7)) {
    if (d != b && semester != null && breakOn(semester, d) != null) continue;
    weeks++;
  }
  return weeks;
}

/// Kurzer Hinweis auf den Rhythmus, z. B. „14-täglich“; null bei
/// wöchentlichen Terminen. Nennt nie einen Abstand, den die Daten nicht
/// hergeben.
String? rhythmLabel(PlanOccurrence o) {
  String every(int? n) => switch (n) {
    2 => "14-täglich",
    final int n when n > 2 => "alle $n Wochen",
    _ => "nicht wöchentlich",
  };
  return switch (o.kind) {
    SessionKind.weekly => null,
    SessionKind.recurring => every(o.intervalWeeks),
    SessionKind.series => "nicht wöchentlich",
    SessionKind.tentative => "${every(o.intervalWeeks)}, Wochen unbekannt",
    SessionKind.block => "Blocktermin",
    SessionKind.single => "Einzeltermin",
  };
}

/// Art eines Termins in Worten (Detailansicht).
String sessionKindDescription(PlanOccurrence o) => switch (o.kind) {
  SessionKind.weekly => "regelmäßiger Termin, wöchentlich",
  SessionKind.recurring => "regelmäßiger Termin, ${rhythmLabel(o)}",
  SessionKind.series =>
    "wiederkehrender Termin, nicht wöchentlich (Rhythmus nicht angegeben)",
  SessionKind.tentative => "regelmäßiger Termin, ${rhythmLabel(o)}",
  SessionKind.block => "Blockveranstaltung",
  SessionKind.single => "Einzeltermin",
};

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
