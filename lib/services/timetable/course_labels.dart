import '../../models/timetable/course_catalog.dart';

/// Anzeigenamen für Veranstaltungstypen (Kürzel der Quelle). Unbekannte
/// Kürzel werden unverändert angezeigt.
const Map<String, String> courseTypeLabels = {
  "V": "Vorlesung",
  "S": "Seminar",
  "PS": "Proseminar",
  "HS": "Hauptseminar",
  "OS": "Oberseminar",
  "UE": "Übung",
  "K": "Kolloquium",
  "RV": "Ringvorlesung",
  "BS": "Blockseminar",
  "TUT": "Tutorium",
  "EX": "Exkursion",
  "SK": "Sprachkurs",
};

String courseTypeLabel(String? type) =>
    type == null ? "ohne Typ" : courseTypeLabels[type] ?? type;

const List<String> weekdayShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
const List<String> weekdayLong = [
  "Montag",
  "Dienstag",
  "Mittwoch",
  "Donnerstag",
  "Freitag",
  "Samstag",
  "Sonntag",
];

String weekdayName(int isoWeekday, {bool short = false}) =>
    (short ? weekdayShort : weekdayLong)[(isoWeekday - 1).clamp(0, 6)];

/// `2026-10-22` → `22.10.2026` (bzw. `22.10.` mit [withYear] = false).
String formatDate(String date, {bool withYear = true}) {
  final parts = date.split("-");
  if (parts.length != 3) return date;
  final d = int.tryParse(parts[2]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return withYear ? "$d.$m.${parts[0]}" : "$d.$m.";
}

/// Zeitspanne mit Halbgeviertstrich, z. B. `10:15–11:45`.
String timeRange(String? start, String? end) =>
    start == null || end == null ? "Uhrzeit offen" : "$start–$end";

/// Lesbare Beschreibung einer Terminregel, z. B.
/// „wöchentlich Mo 10:15–11:45 · Test-HS 1“.
String describeRule(SessionRule rule, CourseCatalog catalog) {
  final days = rule.weekdays.map((d) => weekdayName(d, short: true)).join(", ");
  final time = timeRange(rule.startTime, rule.endTime);
  final when = switch (rule.kind) {
    RepeatKind.weekly when (rule.intervalWeeks ?? 1) == 1 =>
      "wöchentlich $days $time",
    RepeatKind.weekly => "alle ${rule.intervalWeeks} Wochen $days $time",
    RepeatKind.single when rule.startDate != null =>
      "einmalig ${formatDate(rule.startDate!)} $time",
    RepeatKind.block when rule.startDate != null && rule.endDate != null =>
      rule.weekdays.isEmpty
          ? "Block ${formatDate(rule.startDate!)} ${rule.startTime ?? ""} bis "
                "${formatDate(rule.endDate!)} ${rule.endTime ?? ""}"
          : "Block ${formatDate(rule.startDate!, withYear: false)}–"
                "${formatDate(rule.endDate!)} ($days) $time",
    _ => "Termin ohne eindeutige Angabe",
  };
  final room = rule.roomId == null ? null : catalog.rooms[rule.roomId]?.label;
  return room == null ? when.trim() : "${when.trim()} · $room";
}

/// Hinweise der Verarbeitung in verständlicher Sprache.
String describeNote(ScheduleNote note) => switch (note.code) {
  "no-rules" => "Keine festen Termine (z. B. nach Vereinbarung).",
  "biweekly-phase-unknown" =>
    "14-täglicher Termin ohne Angabe der Startwoche – Termine bitte in der "
        "Quelle prüfen.",
  "block-continuous" => "Durchgehende Blockveranstaltung über mehrere Tage.",
  "missing-time" => "Für einen Termin fehlt die Uhrzeit.",
  "missing-date" => "Für einen Termin fehlt das Datum.",
  "unknown-pattern" || "block-pattern-unclear" =>
    "Eine Terminangabe ist nicht eindeutig und wird nicht angezeigt.",
  "outside-semester" => "Ein Termin liegt außerhalb des Semesters.",
  _ => note.detail,
};
