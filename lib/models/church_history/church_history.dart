/// Statische Inhalte des Lernbereichs „Kirchengeschichte“.
///
/// Alle Inhalte stehen in `assets/church_history/` und werden über stabile
/// IDs verknüpft (siehe `docs/church-history.md`). Der Lernstand des Nutzers
/// liegt getrennt davon (`ChurchHistoryStore`).
library;

/// Datierung mit fachlich angemessener Genauigkeit.
///
/// [from] und [to] sind Jahre (negativ = v. Chr.), [to] null bedeutet „bis
/// heute“. [label] ist die angezeigte Form („um 140“, „112/113“, „3. Jh.“).
/// [approx] kennzeichnet ungefähre, [disputed] umstrittene Angaben; beide
/// dürfen im Quiz nicht wie exakte Jahre behandelt werden.
class HistoricalDating {
  final int from;
  final int? to;
  final String label;
  final bool approx;
  final bool disputed;
  final String? note;

  const HistoricalDating({
    required this.from,
    required this.to,
    required this.label,
    this.approx = false,
    this.disputed = false,
    this.note,
  });

  /// Spielraum in Jahren, um den eine ungefähre oder umstrittene Angabe
  /// unscharf ist.
  int get tolerance => approx || disputed ? 10 : 0;

  int get end => to ?? DateTime.now().year;

  /// Frühestes und spätestes Jahr, das mit der Angabe vereinbar ist.
  int get earliest => from - tolerance;
  int get latest => end + tolerance;

  /// Ob die beiden Angaben sich zeitlich nicht sicher unterscheiden lassen.
  /// Solche Paare stehen nie zusammen in einer Reihenfolge-Aufgabe und nie
  /// als richtige Antwort und Ablenker in derselben Datierungsfrage.
  bool overlaps(HistoricalDating other) {
    return earliest <= other.latest && other.earliest <= latest;
  }

  /// Sortierschlüssel (Mitte des Zeitraums, bei Gleichstand Beginn).
  double get sortKey => (from + end) / 2;

  /// Hinweis zur Genauigkeit für die Anzeige.
  String? get precisionHint {
    if (disputed) return "umstritten";
    if (approx) return "ungefähr";
    return null;
  }

  static HistoricalDating? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final from = raw["from"];
    final to = raw["to"];
    final label = raw["label"];

    if (from is! int || (to != null && to is! int) || label is! String) {
      throw FormatException("Ungültige Datierung: $raw");
    }

    if (to != null && (to as int) < from) {
      throw FormatException("Datierung endet vor ihrem Beginn: $label");
    }

    return HistoricalDating(
      from: from,
      to: to as int?,
      label: label,
      approx: raw["approx"] == true,
      disputed: raw["disputed"] == true,
      note: raw["note"] as String?,
    );
  }
}

enum EntryType {
  person("Person", "Personen"),
  event("Ereignis", "Ereignisse"),
  term("Begriff", "Begriffe"),
  source("Quelle", "Quellen");

  final String label;
  final String plural;

  const EntryType(this.label, this.plural);

  static EntryType parse(Object? name) {
    return EntryType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => throw FormatException("Unbekannter Eintragstyp: $name"),
    );
  }
}

/// Art einer Anmerkung: Forschungsdiskussion, konfessionelle Perspektive
/// oder Begriffsklärung.
enum NoteKind {
  debate("Forschungsdiskussion"),
  perspective("Konfessionelle Perspektive"),
  terminology("Zum Begriff");

  final String label;

  const NoteKind(this.label);

  static NoteKind parse(Object? name) {
    return NoteKind.values.firstWhere(
      (k) => k.name == name,
      orElse: () => throw FormatException("Unbekannte Anmerkung: $name"),
    );
  }
}

class EntryNote {
  final NoteKind kind;
  final String text;

  const EntryNote({required this.kind, required this.text});
}

/// Person, Ereignis, Begriff oder Quelle – ein einheitliches Modell.
///
/// [summary] und [significance] sind Erläuterungen der App. Was die
/// Vorlesung selbst sagt, steht in den [LectureMention]s der Vorlesungen.
class HistoryEntry {
  final String id;
  final EntryType type;
  final String name;
  final List<String> aliases;

  /// Rolle einer Person („Römischer Kaiser“) bzw. Kategorie eines Ereignisses,
  /// Begriffs oder einer Quelle.
  final String? category;

  final HistoricalDating? dating;
  final List<String> epochIds;
  final List<String> themeIds;

  /// Kennzeichnung einer Person ohne ihren Namen (für Quizfragen).
  final String? clue;

  final String summary;
  final String significance;

  /// Verknüpfte Einträge, wie in den Daten angegeben. Die Gegenrichtung
  /// ergänzt [ChurchHistoryData.relatedOf].
  final List<String> relatedIds;

  final List<EntryNote> notes;
  final List<String> references;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.name,
    this.aliases = const [],
    this.category,
    this.dating,
    this.epochIds = const [],
    this.themeIds = const [],
    this.clue,
    required this.summary,
    required this.significance,
    this.relatedIds = const [],
    this.notes = const [],
    this.references = const [],
  });

  /// Name ohne typografische Anführungszeichen (für Sortierung und Suche).
  String get plainName => name.replaceAll(RegExp(r'[„“"]'), "");
}

class Epoch {
  final String id;
  final String title;
  final HistoricalDating dating;

  /// Kennzeichnung der Epoche wörtlich nach der Vorlesung.
  final String characterization;

  /// Erläuterung der App.
  final String summary;

  final List<int> lectureSlides;

  const Epoch({
    required this.id,
    required this.title,
    required this.dating,
    required this.characterization,
    required this.summary,
    this.lectureSlides = const [],
  });
}

class HistoryTheme {
  final String id;
  final String title;
  final String description;

  const HistoryTheme({
    required this.id,
    required this.title,
    required this.description,
  });
}

class Slide {
  final int number;
  final String title;

  /// Asset-Pfad des Folienbilds (Originalfolie).
  final String? image;

  /// Vollständiger Text der Folie (Abschrift).
  final String text;

  /// Auf der Folie farbig hervorgehobene Stellen.
  final List<String> highlights;

  const Slide({
    required this.number,
    required this.title,
    this.image,
    required this.text,
    this.highlights = const [],
  });
}

/// Abschnitt der strukturierten Zusammenfassung: [points] geben den Inhalt
/// der Folien wieder, [supplement] ist eine gekennzeichnete Ergänzung.
class LectureSection {
  final String title;
  final List<int> slides;
  final List<String> points;
  final String? supplement;

  const LectureSection({
    required this.title,
    required this.slides,
    required this.points,
    this.supplement,
  });
}

/// Was eine Vorlesung über einen Eintrag sagt (mit Folien).
class LectureMention {
  final String lectureId;
  final String entryId;
  final List<int> slides;
  final String text;

  const LectureMention({
    required this.lectureId,
    required this.entryId,
    required this.slides,
    required this.text,
  });
}

/// Aufzählung der Vorlesung zum Abrufen aus dem Gedächtnis („Merkliste“).
class RecallList {
  final String id;
  final String lectureId;
  final String title;
  final String prompt;
  final List<int> slides;
  final List<String> items;
  final bool ordered;

  const RecallList({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.prompt,
    required this.slides,
    required this.items,
    this.ordered = false,
  });
}

/// Von Hand gepflegte Auswahlfrage zu einer Vorlesung.
class CuratedQuestion {
  final String id;
  final String lectureId;
  final String prompt;
  final String answer;
  final List<String> distractors;
  final String explanation;
  final List<int> slides;
  final List<String> entryIds;

  const CuratedQuestion({
    required this.id,
    required this.lectureId,
    required this.prompt,
    required this.answer,
    required this.distractors,
    required this.explanation,
    required this.slides,
    this.entryIds = const [],
  });
}

class Lecture {
  final String id;
  final int number;
  final String title;

  /// Name der Originaldatei der Folien.
  final String? file;

  final List<String> epochIds;
  final List<String> themeIds;
  final List<Slide> slides;
  final List<LectureSection> sections;
  final List<LectureMention> mentions;
  final List<RecallList> lists;
  final List<CuratedQuestion> questions;

  const Lecture({
    required this.id,
    required this.number,
    required this.title,
    this.file,
    this.epochIds = const [],
    this.themeIds = const [],
    this.slides = const [],
    this.sections = const [],
    this.mentions = const [],
    this.lists = const [],
    this.questions = const [],
  });

  String get label => "Vorlesung $number";

  /// Einträge, die die Vorlesung erwähnt (ohne Doppelungen, in Reihenfolge).
  List<String> get entryIds => {
    for (final m in mentions) m.entryId,
    for (final q in questions) ...q.entryIds,
  }.toList();

  Slide? slide(int number) {
    for (final s in slides) {
      if (s.number == number) return s;
    }
    return null;
  }
}

class OutlineTopic {
  final int number;
  final String title;

  /// Vorlesung, deren Folien das Thema behandeln (null: noch keine).
  final String? lectureId;

  const OutlineTopic({
    required this.number,
    required this.title,
    this.lectureId,
  });
}

class OutlinePart {
  final String part;
  final String title;
  final String? epochId;
  final int? slide;
  final List<OutlineTopic> topics;

  const OutlinePart({
    required this.part,
    required this.title,
    this.epochId,
    this.slide,
    required this.topics,
  });
}

class Course {
  final String id;
  final String title;
  final String lecturer;
  final List<OutlinePart> outline;

  const Course({
    required this.id,
    required this.title,
    required this.lecturer,
    this.outline = const [],
  });
}

/// Alle Inhalte mit Indizes für die Verknüpfungen.
class ChurchHistoryData {
  final Course course;
  final List<Epoch> epochs;
  final String? epochNote;
  final List<HistoryTheme> themes;
  final List<HistoryEntry> entries;
  final List<Lecture> lectures;

  late final Map<String, HistoryEntry> _entries = {
    for (final e in entries) e.id: e,
  };
  late final Map<String, Epoch> _epochs = {for (final e in epochs) e.id: e};
  late final Map<String, HistoryTheme> _themes = {
    for (final t in themes) t.id: t,
  };
  late final Map<String, Lecture> _lectures = {
    for (final l in lectures) l.id: l,
  };

  late final Map<String, Set<String>> _related = _buildRelated();

  ChurchHistoryData({
    required this.course,
    required this.epochs,
    this.epochNote,
    required this.themes,
    required this.entries,
    required this.lectures,
  });

  HistoryEntry? entry(String id) => _entries[id];
  Epoch? epoch(String id) => _epochs[id];
  HistoryTheme? theme(String id) => _themes[id];
  Lecture? lecture(String id) => _lectures[id];

  Map<String, Set<String>> _buildRelated() {
    final related = <String, Set<String>>{};

    for (final e in entries) {
      for (final other in e.relatedIds) {
        if (other == e.id) continue;
        related.putIfAbsent(e.id, () => {}).add(other);
        related.putIfAbsent(other, () => {}).add(e.id);
      }
    }

    return related;
  }

  /// Verknüpfte Einträge in beide Richtungen, nach Typ und Datierung.
  List<HistoryEntry> relatedOf(String id) {
    final list = [
      for (final other in _related[id] ?? const <String>{})
        if (_entries[other] != null) _entries[other]!,
    ];

    list.sort(compareEntries);
    return list;
  }

  /// Was die Vorlesungen über einen Eintrag sagen.
  List<LectureMention> mentionsOf(String entryId) => [
    for (final l in lectures)
      for (final m in l.mentions)
        if (m.entryId == entryId) m,
  ];

  /// Vorlesungen, die einen Eintrag behandeln.
  List<Lecture> lecturesOf(String entryId) => [
    for (final l in lectures)
      if (l.entryIds.contains(entryId)) l,
  ];

  /// Ob der Eintrag in einer Vorlesung vorkommt (sonst: Ergänzung).
  bool isFromLecture(String entryId) => lecturesOf(entryId).isNotEmpty;

  List<HistoryEntry> entriesOfEpoch(String epochId) =>
      _sorted(entries.where((e) => e.epochIds.contains(epochId)));

  List<HistoryEntry> entriesOfTheme(String themeId) =>
      _sorted(entries.where((e) => e.themeIds.contains(themeId)));

  List<HistoryEntry> entriesOfLecture(String lectureId) {
    final ids = lecture(lectureId)?.entryIds ?? const <String>[];
    return _sorted(ids.map(entry).whereType<HistoryEntry>());
  }

  List<HistoryEntry> entriesOfType(EntryType type) =>
      _sorted(entries.where((e) => e.type == type));

  /// Themen mit mindestens einem Eintrag – leere Kategorien werden nie
  /// angezeigt.
  List<HistoryTheme> get usedThemes => [
    for (final t in themes)
      if (entries.any((e) => e.themeIds.contains(t.id))) t,
  ];

  /// Datierte Einträge nach ihrem Beginn (für die Zeitleiste).
  List<HistoryEntry> get timeline {
    final list = entries.where((e) => e.dating != null).toList();
    list.sort((a, b) {
      final from = a.dating!.from.compareTo(b.dating!.from);
      if (from != 0) return from;
      final end = a.dating!.end.compareTo(b.dating!.end);
      if (end != 0) return end;
      return a.plainName.compareTo(b.plainName);
    });
    return list;
  }

  static int compareEntries(HistoryEntry a, HistoryEntry b) {
    final type = a.type.index.compareTo(b.type.index);
    if (type != 0) return type;

    final da = a.dating?.sortKey;
    final db = b.dating?.sortKey;

    if (da != null && db != null && da != db) return da.compareTo(db);
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;

    return a.plainName.toLowerCase().compareTo(b.plainName.toLowerCase());
  }

  static List<HistoryEntry> _sorted(Iterable<HistoryEntry> entries) {
    return entries.toList()..sort(compareEntries);
  }
}
