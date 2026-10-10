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

  /// Strophe, deren Text im Bild unter den Noten steht (wie im Gesangbuch);
  /// `null`, wenn das Bild nur die Melodie zeigt.
  final dynamic underlayStanza;

  /// Wie die Unterlegung gesichert ist: `verified` (stimmt mit einer Vorlage
  /// überein) oder `syllabic` (jede Silbe genau ein Ton, ohne Vorlage).
  final String underlayStatus;

  /// Herkunft der Unterlegung als Satz für die Quellenzeile; leer, wenn sie
  /// ohne Vorlage feststeht.
  final String underlayCredit;

  const HymnScore({
    required this.id,
    required this.asset,
    required this.format,
    required this.kind,
    required this.label,
    required this.source,
    this.underlayStanza,
    this.underlayStatus = '',
    this.underlayCredit = '',
  });

  bool get hasUnderlay => underlayStanza != null;

  bool get isDisplayable => format == 'svg' && asset.isNotEmpty;

  factory HymnScore.fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    final underlay = json['underlay'];

    return HymnScore(
      id: json['id'] ?? '',
      asset: json['asset'] ?? '',
      format: json['format'] ?? '',
      kind: json['kind'] ?? '',
      label: json['label'] ?? '',
      source: HymnScoreSource.fromJson(
        source is Map<String, dynamic> ? source : const {},
      ),
      underlayStanza: underlay is Map<String, dynamic>
          ? underlay['stanza']
          : null,
      underlayStatus: underlay is Map<String, dynamic>
          ? underlay['status'] ?? ''
          : '',
      underlayCredit: underlay is Map<String, dynamic>
          ? underlay['credit'] ?? ''
          : '',
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
