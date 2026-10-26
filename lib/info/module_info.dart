/// Herkunft eines Datenbestands oder Inhalts.
///
/// Trennt bewusst zwischen „worauf beruht der Inhalt?“ ([origin]) und „wie
/// wurde er für die App erstellt bzw. aufbereitet?“ ([processing], [aiNote]).
/// Alle Angaben außer [title] sind optional: Ein Feld wird nur gesetzt, wenn
/// die Angabe im Projekt belegt ist. Ist [origin] null, zeigt die App an,
/// dass die Herkunft nicht dokumentiert ist – niemals eine Vermutung.
class SourceInfo {
  /// Was beschrieben wird, z. B. „Vokabelliste“.
  final String title;

  /// Quelle, auf der der Inhalt beruht (Werk, Ausgabe, Dienst, Institution).
  final String? origin;

  /// Wie der Inhalt für die App übernommen, abgerufen oder bearbeitet wurde.
  final String? processing;

  /// Rolle von KI bei Erstellung oder Aufbereitung, soweit bekannt.
  final String? aiNote;

  final String? license;
  final String? url;

  const SourceInfo({
    required this.title,
    this.origin,
    this.processing,
    this.aiNote,
    this.license,
    this.url,
  });
}

/// Informationen zu einem Bereich der App: was er tut, woher seine Daten
/// stammen und welche Einschränkungen gelten. Dient zugleich als Bereich für
/// kontextbezogene Fehlermeldungen (siehe `ReportContext`).
///
/// Neuer Bereich → Eintrag in `AppModules` (app_info.dart) anlegen und im
/// Screen `InfoButton(module: …)` bzw. `InfoReportFooter(module: …)` einbauen.
class ModuleInfo {
  /// Stabile Kennung, wird mit Fehlermeldungen gespeichert.
  final String id;

  final String title;
  final String description;
  final List<SourceInfo> sources;

  /// Besonderheiten und Einschränkungen.
  final List<String> notes;

  const ModuleInfo({
    required this.id,
    required this.title,
    required this.description,
    this.sources = const [],
    this.notes = const [],
  });
}
