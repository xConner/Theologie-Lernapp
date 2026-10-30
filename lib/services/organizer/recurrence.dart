import 'org_dates.dart';

/// Rhythmus eines wiederkehrenden Termins.
enum RecurrenceFreq {
  daily("täglich", "Tag", "Tage"),
  weekly("wöchentlich", "Woche", "Wochen"),
  monthly("monatlich", "Monat", "Monate"),
  yearly("jährlich", "Jahr", "Jahre");

  final String label;
  final String unit;
  final String units;

  const RecurrenceFreq(this.label, this.unit, this.units);

  static RecurrenceFreq? parse(Object? value) {
    for (final f in values) {
      if (f.name == value) return f;
    }
    return null;
  }
}

/// Bewusst einfache Wiederholung: Rhythmus, Abstand, optional ein Ende und
/// einzelne ausgelassene Tage (z. B. ein ausfallendes Seminar). Keine
/// Regeln wie „jeder zweite Dienstag im Monat“ – die braucht der
/// Studienalltag kaum, und jede weitere Regel macht das Formular schwerer.
class Recurrence {
  final RecurrenceFreq freq;

  /// Alle n Tage/Wochen/Monate/Jahre (mindestens 1).
  final int interval;

  /// Letzter möglicher Tag (eingeschlossen); null = ohne Ende.
  final OrgDate? until;

  /// Ausgelassene Tage (Beginn des jeweiligen Vorkommens).
  final Set<String> exceptions;

  const Recurrence({
    required this.freq,
    this.interval = 1,
    this.until,
    this.exceptions = const {},
  });

  /// Obergrenze je Abfrage, damit eine fehlerhafte Regel nie hängt.
  static const int _maxSteps = 5000;

  Recurrence copyWith({
    RecurrenceFreq? freq,
    int? interval,
    OrgDate? until,
    bool clearUntil = false,
    Set<String>? exceptions,
  }) => Recurrence(
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    until: clearUntil ? null : (until ?? this.until),
    exceptions: exceptions ?? this.exceptions,
  );

  /// Kurzbeschreibung, z. B. „wöchentlich bis 1.2.2027“.
  String describe() {
    final base = interval == 1
        ? freq.label
        : (freq == RecurrenceFreq.weekly && interval == 2
              ? "14-täglich"
              : "alle $interval ${freq.units}");
    final end = until;
    return end == null
        ? base
        : "$base bis ${end.label(year: true, weekday: false)}";
  }

  /// [n]-tes Vorkommen ab [start] (n = 0 ist [start] selbst). Monate und
  /// Jahre werden immer vom Beginn aus gerechnet, damit ein Termin am 31.
  /// im Februar auf den 28./29. fällt und danach wieder auf den 31.
  OrgDate nth(OrgDate start, int n) => switch (freq) {
    RecurrenceFreq.daily => start.addDays(n * interval),
    RecurrenceFreq.weekly => start.addDays(7 * n * interval),
    RecurrenceFreq.monthly => start.addMonths(n * interval),
    RecurrenceFreq.yearly => start.addMonths(12 * n * interval),
  };

  /// Beginntage aller Vorkommen, deren Zeitraum
  /// ([Beginn, Beginn + [spanDays]]) sich mit [from]–[to] überschneidet.
  List<OrgDate> occurrences(
    OrgDate start, {
    required OrgDate from,
    required OrgDate to,
    int spanDays = 0,
  }) {
    final result = <OrgDate>[];
    final step = interval < 1 ? 1 : interval;
    final rule = step == interval ? this : copyWith(interval: step);

    // Erstes in Frage kommendes Vorkommen grob überspringen.
    var n = 0;
    final skipTo = from.addDays(-spanDays);
    if (start.isBefore(skipTo)) {
      final days = start.daysUntil(skipTo);
      n = switch (freq) {
        RecurrenceFreq.daily => days ~/ step,
        RecurrenceFreq.weekly => days ~/ (7 * step),
        RecurrenceFreq.monthly => days ~/ (31 * step),
        RecurrenceFreq.yearly => days ~/ (366 * step),
      };
      if (n > 0) n -= 1;
    }

    for (var i = 0; i < _maxSteps; i++, n++) {
      final date = rule.nth(start, n);
      if (date.isAfter(to)) break;
      final last = until;
      if (last != null && date.isAfter(last)) break;
      if (date.addDays(spanDays).isBefore(from)) continue;
      if (exceptions.contains(date.key)) continue;
      result.add(date);
    }
    return result;
  }

  /// Nächstes Vorkommen ab [day] (eingeschlossen) oder null.
  OrgDate? nextFrom(OrgDate start, OrgDate day) {
    final found = occurrences(start, from: day, to: day.addDays(366 * 2));
    return found.isEmpty ? null : found.first;
  }

  Map<String, dynamic> toMap() => {
    "freq": freq.name,
    "interval": interval,
    "until": until?.key,
    "exceptions": exceptions.toList()..sort(),
  };

  static Recurrence? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final freq = RecurrenceFreq.parse(raw["freq"]);
    if (freq == null) return null;
    final interval = raw["interval"];
    return Recurrence(
      freq: freq,
      interval: interval is num && interval >= 1 && interval <= 99
          ? interval.toInt()
          : 1,
      until: OrgDate.tryParse(raw["until"]),
      exceptions: {
        if (raw["exceptions"] is List)
          for (final e in raw["exceptions"] as List)
            if (OrgDate.tryParse(e) != null) e as String,
      },
    );
  }
}
