/// Ein Gesangbuch oder eine Liedsammlung aus `assets/hymnals/catalog.json`:
/// der Stammteil des Evangelischen Gesangbuchs, ein Regionalteil, ein
/// Ergänzungsheft oder eine weitere Sammlung.
///
/// Die Lieder einer Sammlung liegen in [asset] im Format von
/// `assets/eg_lieder.json`. Sammlungen ohne [asset] sind verzeichnet, aber
/// (noch) ohne Lieder.
class Hymnal {
  final String id;

  /// Kennung der Gruppe (siehe [HymnalGroup]), z. B. `eg`.
  final String group;

  final HymnalPart part;

  /// Bezeichnung in Listen, z. B. „Regionalteil Bayern und Thüringen“.
  final String title;

  /// Vollständiger Titel; leer, wenn er [title] entspricht.
  final String fullTitle;

  /// Kurzform für Suchergebnisse und Filter, z. B. „EG Bayern/Thüringen“.
  final String shortTitle;

  /// Vorsatz der Liednummer, z. B. „EG“ oder „EG.E“.
  final String numberPrefix;

  final String region;
  final String edition;
  final String year;
  final String? asset;
  final HymnalStatus status;

  /// Zahl der Lieder der gedruckten Ausgabe, soweit belegt.
  final int? expectedCount;

  final String description;

  /// Warum die Sammlung nur teilweise oder gar nicht integriert ist.
  final String statusNote;

  /// Hinweis bei Liedern ohne Text; ein Lied kann einen eigenen haben.
  final String lyricsNote;

  final List<HymnalSource> sources;

  const Hymnal({
    required this.id,
    required this.group,
    required this.part,
    required this.title,
    this.fullTitle = '',
    this.shortTitle = '',
    this.numberPrefix = '',
    this.region = '',
    this.edition = '',
    this.year = '',
    this.asset,
    this.status = HymnalStatus.notIntegrated,
    this.expectedCount,
    this.description = '',
    this.statusNote = '',
    this.lyricsNote = '',
    this.sources = const [],
  });

  String get label => shortTitle.isNotEmpty ? shortTitle : title;

  factory Hymnal.fromJson(Map<String, dynamic> json) {
    final asset = json['asset'];

    return Hymnal(
      id: json['id'] ?? '',
      group: json['group'] ?? '',
      part: HymnalPart.fromName(json['part']),
      title: json['title'] ?? '',
      fullTitle: json['fullTitle'] ?? '',
      shortTitle: json['shortTitle'] ?? '',
      numberPrefix: json['numberPrefix'] ?? '',
      region: json['region'] ?? '',
      edition: json['edition'] ?? '',
      year: json['year']?.toString() ?? '',
      asset: asset is String && asset.isNotEmpty ? asset : null,
      status: HymnalStatus.fromName(json['status']),
      expectedCount: json['expectedCount'] as int?,
      description: json['description'] ?? '',
      statusNote: json['statusNote'] ?? '',
      lyricsNote: json['lyricsNote'] ?? '',
      sources: (json['sources'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HymnalSource.fromJson)
          .toList(),
    );
  }
}

/// Art einer Sammlung innerhalb ihrer Gruppe.
enum HymnalPart {
  core("Stammteil"),
  regional("Regionalteile"),
  supplement("Ergänzungshefte"),
  collection("Sammlungen");

  final String label;

  const HymnalPart(this.label);

  static HymnalPart fromName(dynamic name) => HymnalPart.values.firstWhere(
    (part) => part.name == name,
    orElse: () => HymnalPart.collection,
  );
}

/// Wie weit eine Sammlung in der App enthalten ist.
enum HymnalStatus {
  /// Alle Lieder sind verzeichnet (Text und Noten soweit rechtlich möglich).
  complete("vollständig"),

  /// Nur ein Teil der Lieder oder nur Verzeichnisangaben.
  partial("teilweise"),

  /// Verzeichnet, aber ohne Lieder.
  notIntegrated("noch nicht integriert");

  final String label;

  const HymnalStatus(this.label);

  static HymnalStatus fromName(dynamic name) => HymnalStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => HymnalStatus.notIntegrated,
  );
}

class HymnalGroup {
  final String id;
  final String title;

  const HymnalGroup({required this.id, required this.title});

  factory HymnalGroup.fromJson(Map<String, dynamic> json) =>
      HymnalGroup(id: json['id'] ?? '', title: json['title'] ?? '');
}

/// Quelle oder Digitalisat einer Sammlung.
class HymnalSource {
  final String title;
  final String url;
  final String license;

  const HymnalSource({required this.title, this.url = '', this.license = ''});

  factory HymnalSource.fromJson(Map<String, dynamic> json) => HymnalSource(
    title: json['title'] ?? '',
    url: json['url'] ?? '',
    license: json['license'] ?? '',
  );
}
