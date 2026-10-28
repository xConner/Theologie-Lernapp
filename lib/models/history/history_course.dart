/// Gemeinsame Sicht der historischen Lernbereiche für „Geschichte Schritt
/// für Schritt“: Zeiträume, Personen, Mächte und Ereignisse mit Datierung,
/// Aussagen aus den Veranstaltungen und Verknüpfungen, dazu der Lernpfad
/// (kleine Lernschritte) und Folgen aus den Folien.
///
/// Die Inhalte entstehen aus den Daten der Bereiche (Kirchengeschichte:
/// Epochen und Einträge, Altes Testament: `history.json` mit Folienangaben);
/// die Sicht selbst enthält keine eigenen Fakten. Siehe
/// `docs/history-learning.md`.
library;

import 'historical_dating.dart';

export 'historical_dating.dart';

enum HistoryItemKind {
  period("Zeitraum", "Zeiträume"),
  person("Person", "Personen"),
  group("Macht", "Mächte und Gruppen"),
  event("Ereignis", "Ereignisse");

  final String label;
  final String plural;

  const HistoryItemKind(this.label, this.plural);

  static HistoryItemKind parse(Object? name) {
    return HistoryItemKind.values.firstWhere(
      (k) => k.name == name,
      orElse: () => throw FormatException("Unbekannte Art: $name"),
    );
  }
}

/// Eine Aussage über einen Inhalt mit Fundstelle („VL 2, Folie 13“).
/// [supplement]: Erläuterung der App, nicht aus der Veranstaltung.
class HistoryStatement {
  final String text;
  final String source;
  final bool supplement;

  const HistoryStatement({
    required this.text,
    required this.source,
    this.supplement = false,
  });
}

/// Zeitraum, Person, Macht oder Ereignis.
class HistoryItem {
  final String id;
  final HistoryItemKind kind;
  final String name;

  /// Bezeichnung in Aufgaben, die nach der Zeit fragen: der Name, außer er
  /// verrät schon die Datierung („Mission im 1. Jahrhundert …“).
  final String timelessName;

  final HistoricalDating? dating;

  /// Zeitraum der Veranstaltung, zu dem der Inhalt gehört.
  final String? periodId;

  /// Spur des Zeitstrahls (z. B. Geschichte bzw. Textüberlieferung).
  final String? trackId;

  /// Rolle einer Person, wie die Veranstaltung sie nennt („Perserkönig“).
  final String? role;

  /// Kennzeichnung einer Person ohne ihren Namen.
  final String? clue;

  /// Was Vorlesung bzw. Übung sagen (mit Fundstelle), danach Ergänzungen.
  final List<HistoryStatement> statements;

  /// Bedeutung für „Bedeutung erklären“; null: die Aussagen reichen.
  final String? significance;

  /// Folge, die die Veranstaltung ausdrücklich nennt („danach
  /// hasmonäisches Königtum“).
  final HistoryStatement? consequence;

  /// Verknüpfte Inhalte, wie in den Daten angegeben (Gegenrichtung ergänzt
  /// [HistoryCourse.relatedOf]).
  final List<String> relatedIds;

  /// Öffnet weitere Angaben im Bereich (Kirchengeschichte: Eintrag).
  final bool hasDetail;

  const HistoryItem({
    required this.id,
    required this.kind,
    required this.name,
    String? timelessName,
    this.dating,
    this.periodId,
    this.trackId,
    this.role,
    this.clue,
    this.statements = const [],
    this.significance,
    this.consequence,
    this.relatedIds = const [],
    this.hasDetail = false,
  }) : timelessName = timelessName ?? name;

  bool get dated => dating != null;

  /// Aussagen der Veranstaltungen (ohne Ergänzungen).
  List<HistoryStatement> get courseStatements => [
    for (final s in statements)
      if (!s.supplement) s,
  ];

  /// Fundstelle der ersten Aussage aus einer Veranstaltung.
  String? get source => courseStatements.firstOrNull?.source;

  /// Ob ein Name Jahreszahlen oder Jahrhunderte enthält (Prozentangaben
  /// zählen nicht).
  static bool revealsDate(String text) =>
      RegExp(r'\d{2,}(?![\d\s]*%)|\d+\.\s*(Jh|Jahrhundert)').hasMatch(text);
}

/// Ein Lernschritt: wenige neue Inhalte mit einem klaren Thema.
class HistoryLesson {
  final String id;

  /// Abschnitt des Lernpfads (z. B. „Martyrium und Verfolgungen (VL 2)“).
  final String part;
  final String title;
  final List<String> itemIds;

  const HistoryLesson({
    required this.id,
    required this.part,
    required this.title,
    required this.itemIds,
  });
}

/// Eine Folge auf einer Folie (Eckdaten, Phasen) in ihrer Reihenfolge.
class HistorySequence {
  final String id;
  final String title;
  final String source;
  final List<String> itemIds;

  const HistorySequence({
    required this.id,
    required this.title,
    required this.source,
    required this.itemIds,
  });

  /// Inhalt, der in der Folge auf [itemId] folgt; null am Ende.
  String? next(String itemId) {
    final i = itemIds.indexOf(itemId);
    return i < 0 || i + 1 >= itemIds.length ? null : itemIds[i + 1];
  }
}

class HistoryTrack {
  final String id;
  final String title;

  const HistoryTrack({required this.id, required this.title});
}

/// Alle Inhalte einer Veranstaltungssicht mit Indizes.
class HistoryCourse {
  /// Bereich (für Texte): „Kirchengeschichte“, „Altes Testament“ …
  final String title;

  /// Bezeichnung der Datengrundlage in Hinweisen („Vorlesung“, „Übung“).
  final String sourceName;

  final List<HistoryItem> items;
  final List<HistoryLesson> lessons;
  final List<HistorySequence> sequences;
  final List<HistoryTrack> tracks;

  late final Map<String, HistoryItem> _items = {for (final i in items) i.id: i};

  late final Map<String, Set<String>> _related = () {
    final related = <String, Set<String>>{};
    for (final item in items) {
      for (final other in item.relatedIds) {
        if (other == item.id || !_items.containsKey(other)) continue;
        related.putIfAbsent(item.id, () => {}).add(other);
        related.putIfAbsent(other, () => {}).add(item.id);
      }
    }
    return related;
  }();

  late final Map<String, HistoryLesson> _lessonOf = {
    for (final l in lessons)
      for (final id in l.itemIds) id: l,
  };

  HistoryCourse({
    required this.title,
    required this.sourceName,
    required this.items,
    required this.lessons,
    this.sequences = const [],
    this.tracks = const [],
  });

  HistoryItem? item(String id) => _items[id];

  HistoryLesson? lessonOf(String itemId) => _lessonOf[itemId];

  HistoryLesson? lesson(String id) =>
      lessons.where((l) => l.id == id).firstOrNull;

  HistoryTrack? track(String? id) =>
      tracks.where((t) => t.id == id).firstOrNull;

  List<HistoryItem> get periods => [
    for (final i in items)
      if (i.kind == HistoryItemKind.period) i,
  ];

  List<HistoryItem> itemsOfLesson(HistoryLesson lesson) => [
    for (final id in lesson.itemIds) ?_items[id],
  ];

  /// Verknüpfte Inhalte in beide Richtungen, in der Reihenfolge der Daten.
  List<HistoryItem> relatedOf(String id) {
    final ids = _related[id] ?? const <String>{};
    return [
      for (final i in items)
        if (ids.contains(i.id)) i,
    ];
  }

  bool areRelated(String a, String b) => _related[a]?.contains(b) ?? false;

  List<HistoryItem> itemsOfPeriod(String periodId) => [
    for (final i in items)
      if (i.periodId == periodId) i,
  ];

  /// Position im Lernpfad (Lernschritte in Reihenfolge); ohne Lernschritt
  /// hinten.
  int positionOf(String itemId) {
    final lesson = _lessonOf[itemId];
    return lesson == null ? lessons.length : lessons.indexOf(lesson);
  }
}

/// Ob [a] sicher vor [b] liegt. Zeiträume liegen vor einem anderen, wenn
/// Beginn und Ende deutlich früher liegen (benachbarte Epochen teilen ihre
/// Grenze); sonst darf sich die Datierung auch mit Unschärfe nicht
/// überschneiden.
bool isClearlyBefore(HistoryItem a, HistoryItem b) {
  final da = a.dating, db = b.dating;
  if (da == null || db == null) return false;

  if (a.kind == HistoryItemKind.period && b.kind == HistoryItemKind.period) {
    final margin = da.tolerance + db.tolerance;
    return da.from + margin < db.from && da.end + margin < db.end;
  }

  return da.latest < db.earliest;
}

/// Ob sich die Reihenfolge von [a] und [b] eindeutig sagen lässt.
bool areOrderable(HistoryItem a, HistoryItem b) =>
    isClearlyBefore(a, b) || isClearlyBefore(b, a);

/// Jahrhundert eines Jahres („1. Jh.“, „8. Jh. v. Chr.“).
String centuryLabel(int century) =>
    century < 0 ? "${-century}. Jh. v. Chr." : "$century. Jh.";

/// Jahrhundert (negativ v. Chr.) eines Jahres.
int centuryOf(int year) =>
    year < 0 ? -((-year - 1) ~/ 100 + 1) : (year - 1) ~/ 100 + 1;

/// Jahre zwischen zwei Jahresangaben (ohne Jahr 0).
int yearsBetween(int a, int b) {
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  return lo < 0 && hi > 0 ? hi - lo - 1 : hi - lo;
}
