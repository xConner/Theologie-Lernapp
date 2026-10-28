/// Datierungen für die historischen Lernbereiche (Kirchengeschichte, Altes
/// Testament). Jahre v. Chr. sind negativ (−722 = 722 v. Chr.); ein Jahr 0
/// gibt es nicht.
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
