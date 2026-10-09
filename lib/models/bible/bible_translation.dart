/// Ein Buch, wie es eine Ausgabe führt: mit dem Namen dieser Ausgabe und
/// ihrer eigenen Kapitel- und Verszählung.
class BibleBookInfo {
  /// Buchkennung nach USFM, z. B. `GEN`, `MRK` (siehe `BibleBooks`).
  final String id;

  /// Kurzer Buchname der Ausgabe, z. B. „1. Mose“ oder „ΚΑΤΑ ΜΑΡΚΟΝ“.
  final String name;

  final String longName;

  /// Höchste Versnummer je Kapitel; Index 0 ist Kapitel 1. Ein Kapitel
  /// ohne Text (kommt in der Septuaginta vor) hat den Wert 0.
  final List<int> verseCounts;

  const BibleBookInfo({
    required this.id,
    required this.name,
    required this.longName,
    required this.verseCounts,
  });

  int get chapterCount => verseCounts.length;

  /// Höchste Versnummer des Kapitels, 0 wenn es das Kapitel nicht gibt.
  int verseCount(int chapter) {
    if (chapter < 1 || chapter > verseCounts.length) return 0;

    return verseCounts[chapter - 1];
  }

  factory BibleBookInfo.fromJson(Map<String, dynamic> json) {
    return BibleBookInfo(
      id: json["id"],
      name: json["name"],
      longName: json["longName"] ?? json["name"],
      verseCounts: List<int>.from(json["chapters"]),
    );
  }
}

/// Wie eine Ausgabe Kapitel und Verse zählt. Die Zählungen weichen vor
/// allem im Alten Testament voneinander ab; die App rechnet sie nicht
/// ineinander um, sondern weist auf mögliche Abweichungen hin.
enum BibleVersification {
  /// Deutsche Zählung (Psalmüberschriften als eigene Verse, Joel 4, Mal 3).
  german,

  /// Englische Zählung (Psalmüberschrift in Vers 1, Joel 3, Mal 4).
  english,

  /// Septuaginta (eigene Psalmenzählung, andere Kapitelfolge).
  lxx,

  /// Vulgata (Psalmenzählung der Septuaginta).
  vulgate;

  static BibleVersification parse(String? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }

    return BibleVersification.english;
  }
}

/// Eine integrierte Bibelausgabe mit Herkunfts- und Lizenzangaben.
///
/// Die Angaben stammen aus `assets/bible/translations.json`, das der Import
/// (`tool/bible_import`) aus `sources.json` und den Quelldateien erzeugt.
class BibleTranslation {
  /// Stabile Kennung; zugleich das Verzeichnis unter `assets/bible/`.
  final String id;

  final String name;
  final String shortName;

  /// Sprachcode: `de`, `en`, `grc`, `la`.
  final String language;

  /// Genaue Bezeichnung der Edition.
  final String edition;

  final String sourceName;
  final String sourceUrl;

  /// Stand der Quelldatei (ISO-Datum).
  final String sourceUpdated;

  final String licenseType;
  final String licenseUrl;

  /// Lizenzhinweis der Quelle im Wortlaut.
  final String licenseNotice;

  final String copyright;

  /// Bekannte Nutzungseinschränkungen.
  final List<String> restrictions;

  /// Jede Abweichung von der Quelldatei (Ausgelassenes, Berichtigungen).
  final List<String> deviations;

  final BibleVersification versification;

  final bool supportsSearch;
  final bool availableOffline;
  final bool hasFootnotes;

  /// Bücher in der Reihenfolge der Ausgabe.
  final List<BibleBookInfo> books;

  final Map<String, BibleBookInfo> _byId;

  BibleTranslation({
    required this.id,
    required this.name,
    required this.shortName,
    required this.language,
    required this.edition,
    required this.sourceName,
    required this.sourceUrl,
    required this.sourceUpdated,
    required this.licenseType,
    required this.licenseUrl,
    required this.licenseNotice,
    required this.copyright,
    required this.restrictions,
    required this.deviations,
    required this.versification,
    required this.supportsSearch,
    required this.availableOffline,
    required this.hasFootnotes,
    required this.books,
  }) : _byId = {for (final b in books) b.id: b};

  BibleBookInfo? book(String id) => _byId[id];

  bool hasBook(String id) => _byId.containsKey(id);

  /// Ob Suchbegriffe griechisch eingegeben werden.
  bool get isGreek => language == "grc";

  factory BibleTranslation.fromJson(Map<String, dynamic> json) {
    final source = Map<String, dynamic>.from(json["source"] ?? const {});
    final license = Map<String, dynamic>.from(json["license"] ?? const {});
    final features = Map<String, dynamic>.from(json["features"] ?? const {});

    return BibleTranslation(
      id: json["id"],
      name: json["name"],
      shortName: json["shortName"] ?? json["name"],
      language: json["language"],
      edition: json["edition"] ?? "",
      sourceName: source["name"] ?? "",
      sourceUrl: source["url"] ?? "",
      sourceUpdated: source["updated"] ?? "",
      licenseType: license["type"] ?? "",
      licenseUrl: license["url"] ?? "",
      licenseNotice: license["notice"] ?? "",
      copyright: json["copyright"] ?? "",
      restrictions: List<String>.from(json["restrictions"] ?? const []),
      deviations: List<String>.from(json["deviations"] ?? const []),
      versification: BibleVersification.parse(json["versification"]),
      supportsSearch: features["search"] ?? true,
      availableOffline: features["offline"] ?? true,
      hasFootnotes: features["footnotes"] ?? false,
      books: [
        for (final b in json["books"] as List)
          BibleBookInfo.fromJson(Map<String, dynamic>.from(b)),
      ],
    );
  }
}

/// Sprachen der Übersetzungsauswahl in ihrer festen Reihenfolge. Ausgaben
/// in einer hier nicht genannten Sprache erscheinen danach unter ihrem
/// Sprachcode.
class BibleLanguages {
  BibleLanguages._();

  static const Map<String, String> labels = {
    "de": "Deutsch",
    "en": "Englisch",
    "grc": "Griechisch",
    "la": "Latein",
  };

  static String label(String code) => labels[code] ?? code;

  /// Gruppiert nach Sprache; die Reihenfolge innerhalb bleibt erhalten.
  static Map<String, List<BibleTranslation>> group(
    List<BibleTranslation> translations,
  ) {
    final result = <String, List<BibleTranslation>>{};

    for (final code in labels.keys) {
      final matching = translations.where((t) => t.language == code).toList();

      if (matching.isNotEmpty) result[code] = matching;
    }

    for (final t in translations) {
      if (!labels.containsKey(t.language)) {
        result.putIfAbsent(t.language, () => []).add(t);
      }
    }

    return result;
  }
}
