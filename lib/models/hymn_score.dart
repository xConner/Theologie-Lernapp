/// Ein Notenbild zu einem Lied (Feld `scores` in `assets/eg_lieder.json`,
/// erzeugt von `tool/hymn_scores/build_scores.py`).
///
/// Mehrere Lieder können auf dasselbe Bild zeigen, wenn sie dieselbe Melodie
/// haben; ein Lied kann mehrere Fassungen einer Melodie haben.
class HymnScore {
  /// Kennung der Melodie, unabhängig von der EG-Nummer.
  final String id;

  /// Pfad des Bildes im App-Bundle.
  final String asset;

  /// Dateiformat; dargestellt wird derzeit nur `svg`.
  final String format;

  /// Umfang der Noten, derzeit `melody` (einstimmige Melodie).
  final String kind;

  /// Bezeichnung der Fassung, z. B. „Ein feste Burg 1529 (EG 362)“.
  final String label;

  final HymnScoreSource source;

  const HymnScore({
    required this.id,
    required this.asset,
    required this.format,
    required this.kind,
    required this.label,
    required this.source,
  });

  bool get isDisplayable => format == 'svg' && asset.isNotEmpty;

  factory HymnScore.fromJson(Map<String, dynamic> json) {
    final source = json['source'];

    return HymnScore(
      id: json['id'] ?? '',
      asset: json['asset'] ?? '',
      format: json['format'] ?? '',
      kind: json['kind'] ?? '',
      label: json['label'] ?? '',
      source: HymnScoreSource.fromJson(
        source is Map<String, dynamic> ? source : const {},
      ),
    );
  }

  /// Liest das optionale Feld `scores`. Ältere Datensätze ohne das Feld und
  /// Einträge, die nicht darstellbar sind, ergeben eine leere Liste.
  static List<HymnScore> listFromJson(dynamic json) {
    if (json is! List) return const [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(HymnScore.fromJson)
        .where((score) => score.isDisplayable)
        .toList();
  }
}

/// Herkunft eines Notenbildes: Vorlage, Urheber der Vorlage und Lizenz.
class HymnScoreSource {
  final String name;
  final String file;
  final String url;
  final String author;
  final String license;
  final String licenseUrl;

  const HymnScoreSource({
    this.name = '',
    this.file = '',
    this.url = '',
    this.author = '',
    this.license = '',
    this.licenseUrl = '',
  });

  factory HymnScoreSource.fromJson(Map<String, dynamic> json) {
    return HymnScoreSource(
      name: json['name'] ?? '',
      file: json['file'] ?? '',
      url: json['url'] ?? '',
      author: json['author'] ?? '',
      license: json['license'] ?? '',
      licenseUrl: json['licenseUrl'] ?? '',
    );
  }
}
