import 'plan_schedule.dart';
import 'timetable_schedule.dart';

// Anordnung der Termine einer Woche im Raster (Tage als Spalten, Zeit von
// oben nach unten). Gleichzeitige Termine liegen nebeneinander in Spuren
// derselben Gruppe, damit alle sichtbar bleiben. Rein (ohne Flutter).

/// Welche Termine angezeigt werden.
enum SessionKindFilter {
  all("Alle Veranstaltungen"),
  regular("Regelmäßige Veranstaltungen"),
  special("Block- und Einzeltermine");

  final String label;
  const SessionKindFilter(this.label);

  /// Gefiltert wird je Termin nach [SessionKind.regular]: Regelmäßig sind
  /// wöchentliche und nicht wöchentliche Serien (z. B. 14-täglich), auch
  /// wenn die Quelle sie als Einzeltermine führt; Block- und Einzeltermine
  /// sind der Rest. Eine Veranstaltung mit beidem erscheint je Filter mit
  /// den passenden Terminen.
  bool accepts(PlanOccurrence o) => switch (this) {
    SessionKindFilter.all => true,
    SessionKindFilter.regular => o.regular,
    SessionKindFilter.special => !o.regular,
  };

  static SessionKindFilter fromName(String? name) => SessionKindFilter.values
      .firstWhere((f) => f.name == name, orElse: () => SessionKindFilter.all);
}

/// Ein Termin an einem Tag des Rasters.
class DayBlock {
  final PlanOccurrence occurrence;

  /// Minuten seit Mitternacht (an diesem Tag, für mehrtägige Blöcke
  /// abgeschnitten).
  final int startMinute;
  final int endMinute;

  /// Spur innerhalb der Gruppe gleichzeitiger Termine und deren Anzahl.
  final int lane;
  final int lanes;

  /// Beginnt vor bzw. endet nach diesem Tag (mehrtägiger Block).
  final bool continuesBefore;
  final bool continuesAfter;

  const DayBlock({
    required this.occurrence,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.lanes,
    this.continuesBefore = false,
    this.continuesAfter = false,
  });
}

class WeekLayout {
  /// ISO-Wochentag → Blöcke.
  final Map<int, List<DayBlock>> days;

  /// Angezeigter Zeitraum in Minuten (ganze Stunden).
  final int firstMinute;
  final int lastMinute;

  const WeekLayout(this.days, this.firstMinute, this.lastMinute);

  /// Spalten: Montag bis Freitag, Wochenende nur mit Terminen.
  List<int> get visibleWeekdays => [
    for (var d = 1; d <= 7; d++)
      if (d <= 5 || (days[d]?.isNotEmpty ?? false)) d,
  ];

  bool get isEmpty => days.values.every((l) => l.isEmpty);
}

const int _dayEnd = 24 * 60;

/// Raster der Woche ab [monday] (`YYYY-MM-DD`).
WeekLayout layoutWeek(
  Iterable<PlanOccurrence> occurrences,
  String monday, {
  int defaultFirstHour = 8,
  int defaultLastHour = 18,
}) {
  final sunday = addDays(monday, 6);
  final segments = <int, List<DayBlock>>{for (var d = 1; d <= 7; d++) d: []};
  var first = defaultFirstHour * 60;
  var last = defaultLastHour * 60;

  for (final o in occurrences) {
    if (o.end.date.compareTo(monday) < 0 ||
        o.start.date.compareTo(sunday) > 0) {
      continue;
    }
    for (var d = 0; d < 7; d++) {
      final date = addDays(monday, d);
      if (o.start.date.compareTo(date) > 0 || o.end.date.compareTo(date) < 0) {
        continue;
      }
      final before = o.start.date.compareTo(date) < 0;
      final after = o.end.date.compareTo(date) > 0;
      final start = before ? 0 : o.start.minuteOfDay;
      final end = after ? _dayEnd : o.end.minuteOfDay;
      if (end <= start) continue;
      if (!before) first = start < first ? start : first;
      if (!after) last = end > last ? end : last;
      segments[d + 1]!.add(
        DayBlock(
          occurrence: o,
          startMinute: start,
          endMinute: end,
          lane: 0,
          lanes: 1,
          continuesBefore: before,
          continuesAfter: after,
        ),
      );
    }
  }
  first = (first ~/ 60) * 60;
  last = ((last + 59) ~/ 60) * 60;
  if (last > _dayEnd) last = _dayEnd;

  final days = <int, List<DayBlock>>{};
  for (final e in segments.entries) {
    // Mehrtägige Abschnitte auf den angezeigten Zeitraum begrenzen.
    final clipped = [
      for (final b in e.value)
        if ((b.endMinute < last ? b.endMinute : last) >
            (b.startMinute > first ? b.startMinute : first))
          DayBlock(
            occurrence: b.occurrence,
            startMinute: b.startMinute > first ? b.startMinute : first,
            endMinute: b.endMinute < last ? b.endMinute : last,
            lane: 0,
            lanes: 1,
            continuesBefore: b.continuesBefore || b.startMinute < first,
            continuesAfter: b.continuesAfter || b.endMinute > last,
          ),
    ];
    days[e.key] = assignLanes(clipped);
  }
  return WeekLayout(days, first, last);
}

/// Spuren für gleichzeitige Blöcke eines Tages: Gruppen zusammenhängend
/// überlappender Blöcke; innerhalb einer Gruppe nimmt jeder Block die erste
/// freie Spur, alle Blöcke der Gruppe teilen sich die Breite.
List<DayBlock> assignLanes(List<DayBlock> blocks) {
  final sorted = [...blocks]
    ..sort((a, b) {
      final s = a.startMinute.compareTo(b.startMinute);
      return s != 0 ? s : b.endMinute.compareTo(a.endMinute);
    });
  final result = <DayBlock>[];
  var group = <(DayBlock, int)>[];
  var laneEnds = <int>[];
  var groupEnd = -1;

  void flush() {
    final lanes = laneEnds.isEmpty ? 1 : laneEnds.length;
    for (final (b, lane) in group) {
      result.add(
        DayBlock(
          occurrence: b.occurrence,
          startMinute: b.startMinute,
          endMinute: b.endMinute,
          lane: lane,
          lanes: lanes,
          continuesBefore: b.continuesBefore,
          continuesAfter: b.continuesAfter,
        ),
      );
    }
    group = [];
    laneEnds = [];
  }

  for (final b in sorted) {
    if (b.startMinute >= groupEnd && group.isNotEmpty) flush();
    var lane = laneEnds.indexWhere((end) => end <= b.startMinute);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(b.endMinute);
    } else {
      laneEnds[lane] = b.endMinute;
    }
    group.add((b, lane));
    if (b.endMinute > groupEnd) groupEnd = b.endMinute;
  }
  if (group.isNotEmpty) flush();
  return result;
}
