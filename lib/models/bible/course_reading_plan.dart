import 'reading_plan.dart';

/// Kalendertage als `yyyy-MM-dd` – wie Streak und Leseverlauf, ohne
/// Uhrzeit und Zeitzone.
class CourseDates {
  CourseDates._();

  static final RegExp _pattern = RegExp(r"^(\d{4})-(\d{2})-(\d{2})$");

  static DateTime? parse(Object? value) {
    if (value is! String) return null;

    final match = _pattern.firstMatch(value);

    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    final date = DateTime(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  static String key(DateTime date) {
    String two(int v) => v.toString().padLeft(2, "0");

    return "${date.year.toString().padLeft(4, "0")}-${two(date.month)}-"
        "${two(date.day)}";
  }

  /// Ohne Uhrzeit; Kalenderrechnung statt Stunden, damit die Umstellung
  /// auf Winter- bzw. Sommerzeit keinen Tag verschiebt.
  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// Kalendertage von [from] bis [to] (beide eingeschlossen); 0, wenn [to]
  /// vor [from] liegt.
  static int daysBetweenInclusive(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);

    final days = b.difference(a).inDays + 1;

    return days < 0 ? 0 : days;
  }

  static const List<String> _weekdays = [
    "Mo",
    "Di",
    "Mi",
    "Do",
    "Fr",
    "Sa",
    "So",
  ];

  /// Z. B. „Do, 29.10.2026“ bzw. ohne Jahr „Do, 29.10.“.
  static String label(DateTime date, {bool year = true}) {
    String two(int v) => v.toString().padLeft(2, "0");

    final text =
        "${_weekdays[date.weekday - 1]}, ${two(date.day)}."
        "${two(date.month)}.";

    return year ? "$text${date.year}" : text;
  }
}

/// Woher die Lesestellen einer Sitzung stammen.
enum CourseReadingSource {
  /// Die Stellen stehen in den Folien der Veranstaltung.
  slides("Nach den Folien"),

  /// Bekannt ist nur das Thema; bis der Bibelleseplan der Veranstaltung
  /// vorliegt, ist ein Umfang vorläufig angenommen.
  provisional("Vorläufig"),

  /// Für die Sitzung ist keine Lektüre vorgesehen.
  none("Keine Lektüre");

  final String label;

  const CourseReadingSource(this.label);

  static CourseReadingSource parse(Object? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }

    throw FormatException("Unbekannte Herkunft der Lesestellen: $value");
  }
}

/// Eine Sitzung einer Lehrveranstaltung mit den Texten, die bis zu ihr
/// gelesen sein sollen.
class CourseSession {
  /// Stabile Kennung, z. B. `bk.02` (= ID der Sitzung im Bereich Altes
  /// Testament, falls es dort Folien zu ihr gibt).
  final String id;

  final int number;

  final DateTime date;

  final String topic;

  final List<PlanReading> readings;

  final CourseReadingSource readingSource;

  /// Sitzung im Bereich Altes Testament (`OldTestamentUnit.id`), falls
  /// ihre Folien in der App sind.
  final String? unitId;

  /// Fundstelle bzw. Begründung, z. B. „Folie 7: Gen (ganz)“.
  final String? note;

  const CourseSession({
    required this.id,
    required this.number,
    required this.date,
    required this.topic,
    required this.readings,
    required this.readingSource,
    this.unitId,
    this.note,
  });

  /// Kennzeichnet die Empfehlung (Termin und Stellen). Weicht sie von der
  /// ab, auf der eine eigene Änderung beruht, wurde die Empfehlung
  /// inzwischen aktualisiert.
  String get fingerprint =>
      "${CourseDates.key(date)}|${readings.map((r) => r.key).join(";")}";

  CourseSession copyWith({DateTime? date, List<PlanReading>? readings}) {
    return CourseSession(
      id: id,
      number: number,
      date: date ?? this.date,
      topic: topic,
      readings: readings ?? this.readings,
      readingSource: readingSource,
      unitId: unitId,
      note: note,
    );
  }
}

/// Ein Termin ohne Lektüre, der für die Planung wichtig ist (z. B. ein
/// Zwischentest).
class CourseMilestone {
  final DateTime start;
  final DateTime? end;
  final String title;
  final String? note;

  const CourseMilestone({
    required this.start,
    required this.title,
    this.end,
    this.note,
  });
}

/// Ein vorlesungs- bzw. übungsbegleitender Leseplan: Sitzungen mit Termin
/// und Lesestellen statt fortlaufender Plantage.
///
/// Integrierte Pläne liegen unter `assets/reading_plans/` und stehen in
/// `index.json` unter `coursePlans` (Format: `docs/reading-plans.md`).
class CourseReadingPlan {
  static const String format = "theologie.app/course-reading-plan";

  final String id;
  final String name;
  final String description;

  /// Veranstaltung, z. B. „Bibelkunde Altes Testament (Übung)“.
  final String course;
  final String? lecturer;
  final String? semester;

  /// Woher Termine und Stellen stammen.
  final String source;

  /// Nach Termin geordnet.
  final List<CourseSession> sessions;

  final List<CourseMilestone> milestones;

  const CourseReadingPlan({
    required this.id,
    required this.name,
    required this.course,
    required this.source,
    required this.sessions,
    this.description = "",
    this.lecturer,
    this.semester,
    this.milestones = const [],
  });

  CourseSession? session(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }

    return null;
  }

  /// Liest eine Plandatei. Wirft [FormatException] bei ungültigen Angaben,
  /// damit kein fehlerhafter Plan ausgeliefert wird (Test).
  static CourseReadingPlan fromJson(Map<String, dynamic> json) {
    if (json["format"] != format) {
      throw FormatException("Kein Leseplan zur Lehrveranstaltung.");
    }

    String text(String key, {bool required = true}) {
      final value = json[key];

      if (value is String && value.trim().isNotEmpty) return value.trim();

      if (required) throw FormatException("Feld „$key“ fehlt.");

      return "";
    }

    final sessions = <CourseSession>[];
    final ids = <String>{};

    for (final raw in (json["sessions"] as List? ?? const [])) {
      final data = Map<String, dynamic>.from(raw as Map);

      final id = data["id"];
      final date = CourseDates.parse(data["date"]);
      final topic = data["topic"];

      if (id is! String || id.isEmpty || !ids.add(id)) {
        throw FormatException("Ungültige oder doppelte Sitzung „$id“.");
      }

      if (date == null) throw FormatException("$id: ungültiges Datum.");

      if (topic is! String || topic.isEmpty) {
        throw FormatException("$id: Thema fehlt.");
      }

      final readings = <PlanReading>[];

      for (final key in (data["readings"] as List? ?? const [])) {
        final reading = PlanReading.parse(key.toString());

        if (reading == null) throw FormatException("$id: Stelle „$key“.");

        readings.add(reading);
      }

      final source = CourseReadingSource.parse(data["readingSource"]);

      if ((source == CourseReadingSource.none) != readings.isEmpty) {
        throw FormatException("$id: Lesestellen passen nicht zur Herkunft.");
      }

      sessions.add(
        CourseSession(
          id: id,
          number: (data["number"] as num?)?.toInt() ?? sessions.length + 1,
          date: date,
          topic: topic,
          readings: readings,
          readingSource: source,
          unitId: data["unit"] as String?,
          note: data["note"] as String?,
        ),
      );
    }

    if (sessions.isEmpty) throw FormatException("Der Plan hat keine Sitzung.");

    sessions.sort((a, b) => a.date.compareTo(b.date));

    final milestones = <CourseMilestone>[];

    for (final raw in (json["milestones"] as List? ?? const [])) {
      final data = Map<String, dynamic>.from(raw as Map);
      final start = CourseDates.parse(data["start"]);
      final title = data["title"];

      if (start == null || title is! String) {
        throw FormatException("Ungültiger Termin: $data");
      }

      milestones.add(
        CourseMilestone(
          start: start,
          end: CourseDates.parse(data["end"]),
          title: title,
          note: data["note"] as String?,
        ),
      );
    }

    return CourseReadingPlan(
      id: text("id"),
      name: text("name"),
      description: text("description", required: false),
      course: text("course"),
      lecturer: json["lecturer"] as String?,
      semester: json["semester"] as String?,
      source: text("source"),
      sessions: sessions,
      milestones: milestones,
    );
  }
}

/// Eigene Änderung einer Sitzung: Termin und/oder Lesestellen. Sie hat
/// Vorrang vor der Empfehlung, bis der Nutzer sie zurücknimmt.
class CourseSessionOverride {
  final DateTime? date;
  final List<PlanReading>? readings;

  /// [CourseSession.fingerprint] der Empfehlung zum Zeitpunkt der Änderung.
  final String basedOn;

  const CourseSessionOverride({
    required this.basedOn,
    this.date,
    this.readings,
  });

  bool get isEmpty => date == null && readings == null;

  Map<String, dynamic> toMap() {
    return {
      "basedOn": basedOn,
      if (date case final date?) "date": CourseDates.key(date),
      if (readings case final readings?)
        "readings": [for (final r in readings) r.key],
    };
  }

  static CourseSessionOverride? fromMap(Object? data) {
    if (data is! Map) return null;

    final basedOn = data["basedOn"];

    List<PlanReading>? readings;

    final raw = data["readings"];

    if (raw is List) {
      readings = [for (final key in raw) ?PlanReading.parse(key.toString())];
    }

    final result = CourseSessionOverride(
      basedOn: basedOn is String ? basedOn : "",
      date: CourseDates.parse(data["date"]),
      readings: readings,
    );

    return result.isEmpty ? null : result;
  }
}

/// Fortschritt in einem Leseplan zur Lehrveranstaltung.
///
/// Erledigt wird je Lesestück (ein Kapitel oder ein Versbereich innerhalb
/// eines Kapitels, Schlüssel wie im Planformat: `GEN 3`, `NUM 6:22-26`) –
/// nicht je Plantag. Ändern sich Termine oder Stellen, bleibt erledigte
/// Lektüre deshalb erhalten; nur das Offene wird neu verteilt.
class CourseReadingProgress {
  final String planId;

  /// Kalendertag (`yyyy-MM-dd`), an dem der Plan begonnen wurde.
  final String startedOn;

  /// Lesestoff bis zum Vorabend der Sitzung einplanen (sonst bis zum
  /// Sitzungstag). Spätester Termin bleibt in beiden Fällen der
  /// Sitzungstag.
  final bool finishEve;

  /// Erledigte Lesestücke → Kalendertag der Erledigung.
  final Map<String, String> done;

  /// Gezielt wiederholte Lesestücke (eine spätere Sitzung behandelt einen
  /// schon eingeplanten Text erneut) → Kalendertag.
  final Map<String, String> reviewed;

  /// Eigene Änderungen je Sitzung.
  final Map<String, CourseSessionOverride> overrides;

  /// Pausiert: Der Plan bleibt mit allem Fortschritt erhalten, erscheint
  /// aber nicht mit einem Tagespensum auf der Startseite der Bibel.
  final bool paused;

  /// Umfang „ganze Bücher“: Zu den Stellen einer Sitzung kommen die übrigen
  /// Kapitel der Bücher, die sie behandelt (siehe `CourseSchedule`). Sonst
  /// nur die benötigten Kapitel.
  final bool wholeBooks;

  /// Kalendertag, an dem [wholeBooks] eingeschaltet wurde. Sitzungen, die
  /// davor stattfanden, werden nicht nachträglich erweitert – sonst stünden
  /// sofort viele Kapitel als „Nachholen“ da.
  final String? wholeBooksSince;

  const CourseReadingProgress({
    required this.planId,
    required this.startedOn,
    this.finishEve = true,
    this.done = const {},
    this.reviewed = const {},
    this.overrides = const {},
    this.paused = false,
    this.wholeBooks = false,
    this.wholeBooksSince,
  });

  CourseReadingProgress copyWith({
    bool? finishEve,
    Map<String, String>? done,
    Map<String, String>? reviewed,
    Map<String, CourseSessionOverride>? overrides,
    bool? paused,
  }) {
    return CourseReadingProgress(
      planId: planId,
      startedOn: startedOn,
      finishEve: finishEve ?? this.finishEve,
      done: done ?? this.done,
      reviewed: reviewed ?? this.reviewed,
      overrides: overrides ?? this.overrides,
      paused: paused ?? this.paused,
      wholeBooks: wholeBooks,
      wholeBooksSince: wholeBooksSince,
    );
  }

  /// Schaltet den Umfang „ganze Bücher“ ein (ab [today]) oder aus. Erledigte
  /// Lesestücke bleiben in beiden Fällen gespeichert.
  CourseReadingProgress withWholeBooks(bool value, String today) {
    return CourseReadingProgress(
      planId: planId,
      startedOn: startedOn,
      finishEve: finishEve,
      done: done,
      reviewed: reviewed,
      overrides: overrides,
      paused: paused,
      wholeBooks: value,
      wholeBooksSince: value ? today : null,
    );
  }

  /// Ist [piece] gelesen – selbst oder als Teil eines ganzen Kapitels?
  bool isDone(PlanReading piece) => doneOn(piece) != null;

  /// Tag, an dem [piece] (bzw. sein ganzes Kapitel) erledigt wurde.
  String? doneOn(PlanReading piece) {
    final own = done[piece.key];

    if (own != null) return own;

    if (piece.verse == null) return null;

    return done["${piece.bookId} ${piece.chapter}"];
  }

  bool isReviewed(PlanReading piece) => reviewed.containsKey(piece.key);

  CourseReadingProgress withPieces(
    Iterable<PlanReading> pieces,
    bool value,
    String today,
  ) {
    final changed = {...done};

    for (final piece in pieces) {
      if (value) {
        changed.putIfAbsent(piece.key, () => today);
      } else {
        changed.remove(piece.key);

        // Ein Versbereich gilt über sein Kapitel als gelesen; „offen“
        // nimmt dann auch das Kapitel zurück.
        if (piece.verse != null) {
          changed.remove("${piece.bookId} ${piece.chapter}");
        }
      }
    }

    return copyWith(done: changed);
  }

  CourseReadingProgress withReview(
    PlanReading piece,
    bool value,
    String today,
  ) {
    final changed = {...reviewed};

    if (value) {
      changed.putIfAbsent(piece.key, () => today);
    } else {
      changed.remove(piece.key);
    }

    return copyWith(reviewed: changed);
  }

  CourseReadingProgress withOverride(
    String sessionId,
    CourseSessionOverride? value,
  ) {
    final changed = {...overrides};

    if (value == null || value.isEmpty) {
      changed.remove(sessionId);
    } else {
      changed[sessionId] = value;
    }

    return copyWith(overrides: changed);
  }

  Map<String, dynamic> toMap() {
    return {
      "planId": planId,
      "startedOn": startedOn,
      "finishEve": finishEve,
      "done": done,
      "reviewed": reviewed,
      "overrides": {
        for (final entry in overrides.entries) entry.key: entry.value.toMap(),
      },
      "paused": paused,
      "wholeBooks": wholeBooks,
      "wholeBooksSince": ?wholeBooksSince,
    };
  }

  /// Liest gespeicherte Daten; ungültige Einträge werden übergangen.
  static CourseReadingProgress? fromMap(Map<dynamic, dynamic> data) {
    final planId = data["planId"];

    if (planId is! String || planId.isEmpty) return null;

    Map<String, String> dates(Object? raw) {
      if (raw is! Map) return {};

      return {
        for (final entry in raw.entries)
          if (PlanReading.parse(entry.key.toString()) != null &&
              CourseDates.parse(entry.value) != null)
            entry.key.toString(): entry.value as String,
      };
    }

    final overrides = <String, CourseSessionOverride>{};

    final rawOverrides = data["overrides"];

    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final parsed = CourseSessionOverride.fromMap(entry.value);

        if (parsed != null) overrides[entry.key.toString()] = parsed;
      }
    }

    final startedOn = data["startedOn"];
    final wholeBooks = data["wholeBooks"] == true;
    final since = data["wholeBooksSince"];

    return CourseReadingProgress(
      planId: planId,
      startedOn: CourseDates.parse(startedOn) != null
          ? startedOn as String
          : "",
      finishEve: data["finishEve"] != false,
      done: dates(data["done"]),
      reviewed: dates(data["reviewed"]),
      overrides: overrides,
      paused: data["paused"] == true,
      wholeBooks: wholeBooks,
      wholeBooksSince: wholeBooks && CourseDates.parse(since) != null
          ? since as String
          : null,
    );
  }
}
