// Datum und Uhrzeit der Studiumsorganisation.
//
// Termine und Fälligkeiten sind „Wanduhrzeiten“: ein Kalendertag
// `yyyy-MM-dd` und optional eine Uhrzeit `HH:MM`, ohne Zeitzone – wie im
// Papierkalender. Eine Vorlesung um 10:15 bleibt auf jedem Gerät und nach
// jeder Zeitumstellung um 10:15. Gerechnet wird nur mit Kalendertagen
// (UTC-Daten ohne Uhrzeit), nie mit Stunden, damit die Umstellung auf
// Sommer- bzw. Winterzeit keinen Tag verschiebt. „Heute“ ist immer der
// lokale Kalendertag des Geräts.

/// Kalendertag `yyyy-MM-dd`.
class OrgDate implements Comparable<OrgDate> {
  final int year;
  final int month;
  final int day;

  const OrgDate._(this.year, this.month, this.day);

  /// Normalisiert (31.11. → 1.12.).
  factory OrgDate(int year, int month, int day) {
    final d = DateTime.utc(year, month, day);
    return OrgDate._(d.year, d.month, d.day);
  }

  /// Lokaler Kalendertag eines Zeitpunkts.
  factory OrgDate.of(DateTime time) {
    final local = time.isUtc ? time.toLocal() : time;
    return OrgDate._(local.year, local.month, local.day);
  }

  static final RegExp _pattern = RegExp(r"^(\d{4})-(\d{2})-(\d{2})$");

  /// `null` bei ungültigen Angaben (auch 2026-02-30).
  static OrgDate? tryParse(Object? value) {
    if (value is! String) return null;
    final m = _pattern.firstMatch(value.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final date = OrgDate(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) return null;
    return date;
  }

  DateTime get _utc => DateTime.utc(year, month, day);

  /// Mitternacht in Ortszeit (für Anzeige und DatePicker).
  DateTime get local => DateTime(year, month, day);

  /// 1 = Montag … 7 = Sonntag.
  int get weekday => _utc.weekday;

  OrgDate addDays(int days) => OrgDate(year, month, day + days);

  /// Gleicher Tag [months] Monate später; gibt es ihn nicht (31.), der
  /// letzte Tag des Monats.
  OrgDate addMonths(int months) {
    final first = DateTime.utc(year, month + months, 1);
    final last = DateTime.utc(first.year, first.month + 1, 0).day;
    return OrgDate(first.year, first.month, day > last ? last : day);
  }

  /// Tage von hier bis [other] (negativ, wenn [other] früher liegt).
  int daysUntil(OrgDate other) => other._utc.difference(_utc).inDays;

  /// Montag derselben Woche.
  OrgDate get startOfWeek => addDays(1 - weekday);

  OrgDate get startOfMonth => OrgDate(year, month, 1);

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  bool isBefore(OrgDate other) => compareTo(other) < 0;
  bool isAfter(OrgDate other) => compareTo(other) > 0;

  String get key {
    String two(int v) => v.toString().padLeft(2, "0");
    return "${year.toString().padLeft(4, "0")}-${two(month)}-${two(day)}";
  }

  static const List<String> weekdayShort = [
    "Mo",
    "Di",
    "Mi",
    "Do",
    "Fr",
    "Sa",
    "So",
  ];

  static const List<String> weekdayLong = [
    "Montag",
    "Dienstag",
    "Mittwoch",
    "Donnerstag",
    "Freitag",
    "Samstag",
    "Sonntag",
  ];

  static const List<String> monthNames = [
    "Januar",
    "Februar",
    "März",
    "April",
    "Mai",
    "Juni",
    "Juli",
    "August",
    "September",
    "Oktober",
    "November",
    "Dezember",
  ];

  /// „Mo, 2.11.“ bzw. mit Jahr „Mo, 2.11.2026“.
  String label({bool year = false, bool weekday = true}) {
    final text = "$day.$month.${year ? this.year : ""}";
    return weekday ? "${weekdayShort[this.weekday - 1]}, $text" : text;
  }

  /// „Heute“, „Morgen“, „Gestern“ oder [label].
  String relativeLabel(OrgDate today, {bool year = false}) {
    final diff = today.daysUntil(this);
    if (diff == 0) return "Heute";
    if (diff == 1) return "Morgen";
    if (diff == -1) return "Gestern";
    return label(year: year || this.year != today.year);
  }

  @override
  int compareTo(OrgDate other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) => other is OrgDate && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// Uhrzeit `HH:MM` (00:00–23:59).
class OrgTime implements Comparable<OrgTime> {
  final int minutes;

  const OrgTime(this.minutes);

  factory OrgTime.hm(int hour, int minute) => OrgTime(hour * 60 + minute);

  static final RegExp _pattern = RegExp(r"^([01]?\d|2[0-3])[:.]([0-5]\d)$");

  static OrgTime? tryParse(Object? value) {
    if (value is! String) return null;
    final m = _pattern.firstMatch(value.trim());
    if (m == null) return null;
    return OrgTime.hm(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  String get key =>
      "${hour.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")}";

  @override
  int compareTo(OrgTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is OrgTime && other.minutes == minutes;

  @override
  int get hashCode => minutes;

  @override
  String toString() => key;
}

/// Wanduhrzeit (Tag + Uhrzeit) als lokaler Zeitpunkt, z. B. für die
/// Erinnerung. Gibt es die Uhrzeit wegen der Zeitumstellung nicht, nimmt
/// [DateTime] die nächste gültige.
DateTime wallClock(OrgDate date, OrgTime? time) => DateTime(
  date.year,
  date.month,
  date.day,
  time?.hour ?? 0,
  time?.minute ?? 0,
);

/// Deutsche Datumsangaben aus Seminarplänen: „19. Oktober 2026“,
/// „19.10.2026“, „19.10.26“, „19.10.“ (Jahr aus [reference]: das Datum
/// innerhalb von ±6 Monaten um den Bezugstag).
class GermanDateParser {
  GermanDateParser._();

  static final Map<String, int> _months = {
    for (final (i, name) in OrgDate.monthNames.indexed)
      name.toLowerCase(): i + 1,
    "jan": 1,
    "feb": 2,
    "mär": 3,
    "maerz": 3,
    "märz": 3,
    "apr": 4,
    "jun": 6,
    "jul": 7,
    "aug": 8,
    "sep": 9,
    "sept": 9,
    "okt": 10,
    "nov": 11,
    "dez": 12,
  };

  static final RegExp numeric = RegExp(
    r"(?<!\d)(\d{1,2})\.\s?(\d{1,2})\.(?:\s?(\d{4}|\d{2})(?!\d))?",
  );

  static final RegExp named = RegExp(
    r"(?<!\d)(\d{1,2})\.\s*(Januar|Februar|März|Maerz|April|Mai|Juni|Juli|"
    r"August|September|Oktober|November|Dezember|Jan|Feb|Mär|Apr|Jun|Jul|Aug|"
    r"Sept?|Okt|Nov|Dez)\.?(?:\s+(\d{4}))?",
    caseSensitive: false,
  );

  /// Erstes Datum in [text] mit seiner Position, sonst null.
  static ({OrgDate date, int start, int end})? find(
    String text, {
    required OrgDate reference,
  }) {
    final candidates = <({OrgDate date, int start, int end})>[];
    for (final m in named.allMatches(text)) {
      final month = _months[m.group(2)!.toLowerCase()];
      final date = _build(int.parse(m.group(1)!), month, m.group(3), reference);
      if (date != null) {
        candidates.add((date: date, start: m.start, end: m.end));
      }
    }
    for (final m in numeric.allMatches(text)) {
      final date = _build(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        m.group(3),
        reference,
      );
      if (date != null) {
        candidates.add((date: date, start: m.start, end: m.end));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.start.compareTo(b.start));
    return candidates.first;
  }

  static OrgDate? parse(String text, {required OrgDate reference}) =>
      find(text, reference: reference)?.date;

  static OrgDate? _build(int day, int? month, String? year, OrgDate ref) {
    if (month == null || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    int y;
    if (year == null) {
      // Jahr so wählen, dass das Datum nah am Bezugstag liegt.
      y = ref.year;
      final candidate = OrgDate(y, month, day);
      final diff = ref.daysUntil(candidate);
      if (diff > 183) y -= 1;
      if (diff < -183) y += 1;
    } else {
      y = int.parse(year);
      if (year.length == 2) y += 2000;
    }
    final date = OrgDate(y, month, day);
    return date.day == day && date.month == month ? date : null;
  }
}
