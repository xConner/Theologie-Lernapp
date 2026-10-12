/// Herkunft eines Bestandteils (Text, Morphologie, Wörterbuch).
class CorpusSource {
  final String name;
  final String? url;
  final String license;
  final String? licenseUrl;
  final String? copyright;

  const CorpusSource({
    required this.name,
    this.url,
    required this.license,
    this.licenseUrl,
    this.copyright,
  });

  factory CorpusSource.fromJson(Map<String, dynamic> json) {
    return CorpusSource(
      name: json["name"] as String,
      url: json["url"] as String?,
      license: json["license"] as String,
      licenseUrl: json["licenseUrl"] as String?,
      copyright: json["copyright"] as String?,
    );
  }
}

/// Wie die Wortformen eines Korpus bestimmt sind.
enum CorpusAnalysisKind {
  /// Jede Form im Kontext bestimmt.
  contextual,

  /// Formen über einen Formenindex ohne Kontext bestimmt.
  formal,
}

/// Ein Textkorpus des Klausurerstellers (Neues Testament, Septuaginta,
/// später weitere Autoren). Die Liste steht allein in
/// `assets/greek_corpus/corpora.json`; die Oberfläche entsteht daraus.
class TextCorpus {
  final String id;
  final String name;
  final String shortName;
  final String edition;

  /// Zugehörige Ausgabe des Bibel-Readers (für „im Reader öffnen“), sonst
  /// `null`.
  final String? bibleTranslation;

  final CorpusAnalysisKind analysis;
  final String analysisNote;
  final CorpusSource text;
  final List<CorpusSource> sources;

  /// Bücher bzw. Werke in ihrer Reihenfolge.
  final List<String> books;

  /// Anteil der Wörter mit Bestimmung (0–1), aus der Importstatistik.
  final double analyzedShare;

  const TextCorpus({
    required this.id,
    required this.name,
    required this.shortName,
    required this.edition,
    required this.bibleTranslation,
    required this.analysis,
    required this.analysisNote,
    required this.text,
    required this.sources,
    required this.books,
    required this.analyzedShare,
  });

  factory TextCorpus.fromJson(Map<String, dynamic> json) {
    final stats = (json["stats"] as Map?) ?? const {};
    final words = (stats["words"] as num?)?.toInt() ?? 0;
    final unanalyzed = (stats["unanalyzed"] as num?)?.toInt() ?? 0;

    return TextCorpus(
      id: json["id"] as String,
      name: json["name"] as String,
      shortName: json["shortName"] as String,
      edition: json["edition"] as String,
      bibleTranslation: json["bibleTranslation"] as String?,
      analysis: json["analysis"] == "contextual"
          ? CorpusAnalysisKind.contextual
          : CorpusAnalysisKind.formal,
      analysisNote: json["analysisNote"] as String? ?? "",
      text: CorpusSource.fromJson(json["text"] as Map<String, dynamic>),
      sources: [
        for (final s in (json["sources"] as List?) ?? const [])
          CorpusSource.fromJson(s as Map<String, dynamic>),
      ],
      books: List<String>.from(json["books"] as List),
      analyzedShare: words == 0 ? 0 : 1 - unanalyzed / words,
    );
  }
}
