import '../../models/timetable/course_catalog.dart';
import 'plan_schedule.dart';

// Überschneidungen im persönlichen Plan, gezählt als Überschneidungsstellen
// statt als betroffene Termine:
//
// * Eine Stelle ist ein zusammenhängender Zeitraum, in dem mindestens zwei
//   verschiedene Veranstaltungen gleichzeitig stattfinden. Drei Veranstaltungen
//   zur selben Zeit bilden EINE Stelle (mit drei Beteiligten).
// * Intervalle sind halboffen [Beginn, Ende): Endet eine Veranstaltung um
//   10:00 und beginnt die nächste um 10:00, ist das keine Überschneidung.
// * Gerechnet wird mit konkreten Terminen (Datum + Uhrzeit), nicht mit
//   Wochenmustern: Ein einzelner Blocktermin überschneidet sich nur an seinem
//   Datum. Für die Übersicht werden Stellen mit gleichem Wochentag, gleicher
//   Uhrzeit und gleichen Veranstaltungen zu einer Gruppe zusammengefasst
//   (z. B. „jeden Dienstag 10:00–11:30, 14 Termine“).
// * Abgesagte Termine zählen nicht; zwei Termine derselben Veranstaltung
//   ebenfalls nicht.

class ConflictSpot {
  final LocalDateTime start;
  final LocalDateTime end;

  /// Alle Termine, die in diesem Zeitraum stattfinden.
  final List<PlanOccurrence> occurrences;

  const ConflictSpot(this.start, this.end, this.occurrences);

  /// Beteiligte Veranstaltungen (Eintragskennungen), sortiert.
  List<String> get entryIds =>
      {for (final o in occurrences) o.entryId}.toList()..sort();

  Duration get duration => end.instant.difference(start.instant);
  String get date => start.date;
  int get weekday => weekdayOf(start.date);
}

/// Überschneidungsstellen, nach Beginn sortiert.
List<ConflictSpot> conflictSpots(Iterable<PlanOccurrence> occurrences) {
  final items = [
    for (final o in occurrences)
      if (!o.cancelled) o,
  ];
  // Ereignisse: Beginn (+1) und Ende (−1). Bei gleichem Zeitpunkt zuerst die
  // Enden (halboffene Intervalle).
  final events =
      <(DateTime, int, PlanOccurrence)>[
        for (final o in items) ...[
          (o.start.instant, 1, o),
          (o.end.instant, -1, o),
        ],
      ]..sort((a, b) {
        final t = a.$1.compareTo(b.$1);
        return t != 0 ? t : a.$2.compareTo(b.$2);
      });

  final active = <PlanOccurrence>[];
  final spots = <ConflictSpot>[];
  LocalDateTime? openedAt;
  final involved = <PlanOccurrence>{};

  int distinct() => {for (final o in active) o.entryId}.length;

  for (final (_, kind, occurrence) in events) {
    if (kind == 1) {
      active.add(occurrence);
      if (openedAt == null && distinct() >= 2) {
        openedAt = occurrence.start;
        involved.addAll(active);
      } else if (openedAt != null) {
        involved.add(occurrence);
      }
    } else {
      active.remove(occurrence);
      if (openedAt != null && distinct() < 2) {
        spots.add(
          ConflictSpot(
            openedAt,
            occurrence.end,
            involved.toList()
              ..sort((a, b) => a.start.instant.compareTo(b.start.instant)),
          ),
        );
        openedAt = null;
        involved.clear();
      }
    }
  }
  return spots;
}

/// Gleichartige Stellen (Wochentag, Uhrzeit, Veranstaltungen).
class ConflictGroup {
  final List<ConflictSpot> spots;

  const ConflictGroup(this.spots);

  ConflictSpot get first => spots.first;
  int get weekday => first.weekday;
  String get startTime => first.start.time;
  String get endTime => first.end.time;
  List<String> get entryIds => first.entryIds;

  /// Wiederholt sich an mehreren Daten.
  bool get recurring => spots.length > 1;
  List<String> get dates => [for (final s in spots) s.date];
}

List<ConflictGroup> groupConflicts(List<ConflictSpot> spots) {
  final groups = <String, List<ConflictSpot>>{};
  for (final s in spots) {
    final key = [
      s.weekday,
      s.start.time,
      s.end.time,
      s.start.date == s.end.date ? "" : "mehrtägig",
      s.entryIds.join("|"),
    ].join("#");
    (groups[key] ??= []).add(s);
  }
  final result = [for (final g in groups.values) ConflictGroup(g)];
  result.sort((a, b) {
    final d = a.weekday.compareTo(b.weekday);
    if (d != 0) return d;
    final t = a.startTime.compareTo(b.startTime);
    return t != 0 ? t : a.first.start.instant.compareTo(b.first.start.instant);
  });
  return result;
}

/// Zusammenfassung für Hinweise: Stellen und betroffene Veranstaltungen.
class ConflictSummary {
  final int spots;
  final int courses;

  const ConflictSummary(this.spots, this.courses);

  factory ConflictSummary.of(Iterable<ConflictSpot> spots) => ConflictSummary(
    spots.length,
    {for (final s in spots) ...s.entryIds}.length,
  );

  bool get isEmpty => spots == 0;
}

/// Termine, die an einer Überschneidung beteiligt sind (Kennungen).
Set<String> conflictingOccurrenceIds(Iterable<ConflictSpot> spots) => {
  for (final s in spots)
    for (final o in s.occurrences) o.id,
};

/// Konfliktstellen eines Termins mit anderen Veranstaltungen (für die
/// Anzeige vor dem Hinzufügen): Stellen, an denen [candidate] beteiligt ist.
List<ConflictSpot> spotsInvolving(List<ConflictSpot> spots, String entryId) => [
  for (final s in spots)
    if (s.entryIds.contains(entryId)) s,
];
