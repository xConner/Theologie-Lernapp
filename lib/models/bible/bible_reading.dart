import 'reading_plan.dart';

/// Eine vom Nutzer bestätigte Lesung im Leseverlauf.
class BibleReadingEntry {
  /// Eindeutig innerhalb eines Tages; dieselbe Lesung wird nicht doppelt
  /// eingetragen (siehe [free] und [plan]).
  final String id;

  /// Was gelesen wurde, z. B. „Mk 4“; leer, wenn nichts angegeben wurde.
  final String text;

  /// Bei einer Planlesung: Plan, Tag (ab 1) und Position der Lesung.
  final String? planId;
  final int? day;
  final int? reading;

  const BibleReadingEntry({
    required this.id,
    required this.text,
    this.planId,
    this.day,
    this.reading,
  });

  static const int maxTextLength = 120;

  /// Frei bestätigte Lesung. Dieselbe Angabe am selben Tag ergibt dieselbe
  /// ID und damit nur einen Eintrag.
  factory BibleReadingEntry.free(String? text) {
    var cleaned = (text ?? "").trim().replaceAll(RegExp(r'\s+'), " ");

    if (cleaned.length > maxTextLength) {
      cleaned = cleaned.substring(0, maxTextLength);
    }

    return BibleReadingEntry(
      id: "free:${cleaned.toLowerCase()}",
      text: cleaned,
    );
  }

  factory BibleReadingEntry.plan({
    required String planId,
    required int day,
    required int reading,
    required String text,
  }) {
    return BibleReadingEntry(
      id: planEntryId(planId, day, reading),
      text: text,
      planId: planId,
      day: day,
      reading: reading,
    );
  }

  static String planEntryId(String planId, int day, int reading) {
    return "plan:$planId:$day:$reading";
  }

  bool get fromPlan => planId != null;

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "text": text,
      "plan": ?planId,
      "day": ?day,
      "reading": ?reading,
    };
  }

  static BibleReadingEntry? fromMap(Object? data) {
    if (data is! Map) return null;

    final id = data["id"];
    final text = data["text"];

    if (id is! String || id.isEmpty) return null;

    final plan = data["plan"];
    final day = data["day"];
    final reading = data["reading"];

    return BibleReadingEntry(
      id: id,
      text: text is String ? text : "",
      planId: plan is String ? plan : null,
      day: day is num ? day.toInt() : null,
      reading: reading is num ? reading.toInt() : null,
    );
  }
}

/// Fortschritt eines begonnenen Leseplans – getrennt von der
/// Bibellese-Streak gespeichert.
///
/// Der Plan richtet sich nicht nach dem Kalender: „Aktueller Tag“ ist der
/// erste Plantag mit einer offenen Lesung. Wer pausiert oder einen Tag
/// auslässt, gerät dadurch nicht in Rückstand.
class ReadingPlanProgress {
  final String planId;

  /// Lokaler Kalendertag (`yyyy-MM-dd`), an dem der Plan begonnen wurde.
  final String startedOn;

  final bool paused;

  /// Erledigte Lesungen: Plantag (ab 1) → Positionen der Lesungen (ab 0).
  final Map<int, Set<int>> done;

  const ReadingPlanProgress({
    required this.planId,
    required this.startedOn,
    this.paused = false,
    this.done = const {},
  });

  ReadingPlanProgress copyWith({bool? paused, Map<int, Set<int>>? done}) {
    return ReadingPlanProgress(
      planId: planId,
      startedOn: startedOn,
      paused: paused ?? this.paused,
      done: done ?? this.done,
    );
  }

  bool isDone(int day, int reading) => done[day]?.contains(reading) ?? false;

  /// Der Stand mit geänderter Lesung.
  ReadingPlanProgress withReading(int day, int reading, bool value) {
    final changed = {
      for (final entry in done.entries) entry.key: {...entry.value},
    };

    final set = changed.putIfAbsent(day, () => {});

    if (value) {
      set.add(reading);
    } else {
      set.remove(reading);
    }

    if (set.isEmpty) changed.remove(day);

    return copyWith(done: changed);
  }

  /// Erledigte Lesungen von Tag [day], soweit es sie im [plan] gibt.
  int doneOn(ReadingPlan plan, int day) {
    final count = plan.readingsOn(day).length;

    return done[day]?.where((i) => i >= 0 && i < count).length ?? 0;
  }

  bool isDayComplete(ReadingPlan plan, int day) {
    final count = plan.readingsOn(day).length;

    return count > 0 && doneOn(plan, day) == count;
  }

  int doneReadings(ReadingPlan plan) {
    var count = 0;

    for (final day in done.keys) {
      count += doneOn(plan, day);
    }

    return count;
  }

  int completedDays(ReadingPlan plan) {
    var count = 0;

    for (final day in done.keys) {
      if (isDayComplete(plan, day)) count++;
    }

    return count;
  }

  /// Erster Plantag mit einer offenen Lesung; `null`, wenn alles gelesen ist.
  int? currentDay(ReadingPlan plan) {
    for (var day = 1; day <= plan.dayCount; day++) {
      if (!isDayComplete(plan, day)) return day;
    }

    return null;
  }

  bool isComplete(ReadingPlan plan) => currentDay(plan) == null;

  /// Anteil der erledigten Lesungen (0–1).
  double fraction(ReadingPlan plan) {
    final total = plan.readingCount;

    return total == 0 ? 0 : doneReadings(plan) / total;
  }

  Map<String, dynamic> toMap() {
    return {
      "planId": planId,
      "startedOn": startedOn,
      "paused": paused,
      "done": {
        for (final entry in done.entries)
          "${entry.key}": entry.value.toList()..sort(),
      },
    };
  }

  static final RegExp _datePattern = RegExp(r"^\d{4}-\d{2}-\d{2}$");

  /// Liest gespeicherte Daten; ungültige Einträge werden übergangen.
  static ReadingPlanProgress? fromMap(Map<dynamic, dynamic> data) {
    final planId = data["planId"];
    final startedOn = data["startedOn"];

    if (planId is! String || planId.isEmpty) return null;

    final done = <int, Set<int>>{};

    final rawDone = data["done"];

    if (rawDone is Map) {
      for (final entry in rawDone.entries) {
        final day = int.tryParse(entry.key.toString());
        final value = entry.value;

        if (day == null || day < 1 || value is! List) continue;

        final readings = {
          for (final i in value)
            if (i is num && i >= 0) i.toInt(),
        };

        if (readings.isNotEmpty) done[day] = readings;
      }
    }

    return ReadingPlanProgress(
      planId: planId,
      startedOn: startedOn is String && _datePattern.hasMatch(startedOn)
          ? startedOn
          : "",
      paused: data["paused"] == true,
      done: done,
    );
  }
}
