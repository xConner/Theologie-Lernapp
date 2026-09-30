/// Ein Gebet (bzw. Hymnus, Canticum, Akklamation …) mit einer oder mehreren
/// Sprachfassungen. Aufbau analog zu `Confession`: Titel je Sprachcode
/// ("de", "en", "la", "gr"), die Texte liegen in [versions].
class Prayer {
  final String id;
  final Map<String, String> title;

  /// Gattung, siehe [PrayerTypes].
  final String type;

  /// Herkunft/Epoche, siehe [PrayerTraditions].
  final String tradition;

  final String? author;

  /// Sprachcode der ursprünglichen Fassung.
  final String originalLanguage;

  /// Herkunft des Gebets (Bibelstelle, Werk, liturgische Tradition).
  final String source;

  final String? dating;
  final String description;

  /// Standardisierte Tag-IDs, siehe [PrayerTags].
  final List<String> tags;

  final List<PrayerVersion> versions;

  Prayer({
    required this.id,
    required this.title,
    required this.type,
    required this.tradition,
    this.author,
    required this.originalLanguage,
    required this.source,
    this.dating,
    required this.description,
    required this.tags,
    required this.versions,
  });

  factory Prayer.fromJson(Map<String, dynamic> json) {
    return Prayer(
      id: json["id"],
      title: Map<String, String>.from(json["title"]),
      type: json["type"],
      tradition: json["tradition"],
      author: json["author"],
      originalLanguage: json["originalLanguage"],
      source: json["source"],
      dating: json["dating"],
      description: json["description"] ?? "",
      tags: List<String>.from(json["tags"] ?? const []),
      versions: (json["versions"] as List)
          .map((v) => PrayerVersion.fromJson(v))
          .toList(),
    );
  }

  /// Anzeigetitel in [language], sonst deutsch.
  String titleFor(String language) =>
      title[language] ?? title["de"] ?? title.values.first;

  String get displayTitle => titleFor("de");

  /// Nur Sprachen mit tatsächlich vorhandenem Text, in fester Reihenfolge.
  List<String> get languages {
    final available = {
      for (final v in versions)
        if (v.text.trim().isNotEmpty) v.language,
    };

    return [
      ...PrayerLanguages.order.where(available.contains),
      ...available.where((l) => !PrayerLanguages.order.contains(l)),
    ];
  }

  PrayerVersion? versionFor(String language) {
    for (final v in versions) {
      if (v.language == language && v.text.trim().isNotEmpty) return v;
    }
    return null;
  }
}

/// Eine Sprachfassung mit Herkunftsangabe.
class PrayerVersion {
  final String language;

  /// Verhältnis zur Originalfassung, siehe [PrayerVersionStatus].
  final String status;

  /// Sprachcode der Vorlage bei Übersetzungen/Nachdichtungen.
  final String? translatedFrom;

  /// Konkret verwendete Fassung/Edition/Übersetzung.
  final String source;

  final String? note;
  final String text;

  PrayerVersion({
    required this.language,
    required this.status,
    this.translatedFrom,
    required this.source,
    this.note,
    required this.text,
  });

  factory PrayerVersion.fromJson(Map<String, dynamic> json) {
    return PrayerVersion(
      language: json["language"],
      status: json["status"],
      translatedFrom: json["translatedFrom"],
      source: json["source"],
      note: json["note"],
      text: json["text"],
    );
  }

  bool get isOriginal => status == PrayerVersionStatus.original;
}

class PrayerLanguages {
  PrayerLanguages._();

  static const List<String> order = ["de", "en", "la", "gr"];

  static const Map<String, String> names = {
    "de": "Deutsch",
    "en": "Englisch",
    "la": "Latein",
    "gr": "Griechisch",
  };

  static String name(String code) => names[code] ?? code;
}

class PrayerVersionStatus {
  PrayerVersionStatus._();

  static const String original = "original";
  static const String translation = "translation";
  static const String liturgical = "liturgical";
  static const String paraphrase = "paraphrase";

  static String label(PrayerVersion version) {
    final from = version.translatedFrom;
    final fromText = from == null ? "" : " aus dem ${_dative(from)}";

    switch (version.status) {
      case original:
        return "Originalsprache";
      case translation:
        return "Übersetzung$fromText";
      case liturgical:
        return "Eigenständige liturgische Fassung";
      case paraphrase:
        return "Nachdichtung$fromText";
      default:
        return version.status;
    }
  }

  static String _dative(String code) {
    switch (code) {
      case "de":
        return "Deutschen";
      case "en":
        return "Englischen";
      case "la":
        return "Lateinischen";
      case "gr":
        return "Griechischen";
      default:
        return code;
    }
  }
}

/// Gattungen – bewusst getrennt, damit nicht alles pauschal „Gebet“ heißt.
class PrayerTypes {
  PrayerTypes._();

  static const Map<String, String> labels = {
    "gebet": "Gebet",
    "biblisches_gebet": "Biblisches Gebet",
    "canticum": "Biblischer Lobgesang (Canticum)",
    "hymnus": "Hymnus",
    "akklamation": "Liturgische Akklamation",
    "doxologie": "Doxologie",
    "antiphon": "Antiphon / Gebetslied",
  };

  static String label(String type) => labels[type] ?? type;
}

class PrayerTraditions {
  PrayerTraditions._();

  static const Map<String, String> labels = {
    "biblisch": "Biblisch",
    "altkirchlich": "Alte Kirche",
    "ostkirchlich": "Ostkirchliche Tradition",
    "mittelalterlich": "Mittelalter",
    "lutherisch": "Lutherische Reformation",
  };

  static String label(String tradition) => labels[tradition] ?? tradition;
}

/// Standardisiertes Tag-Vokabular (ID → Anzeigename).
class PrayerTags {
  PrayerTags._();

  static const Map<String, String> labels = {
    "biblisch": "Biblisch",
    "altkirchlich": "Altkirchlich",
    "ostkirchlich": "Ostkirchlich",
    "mittelalterlich": "Mittelalterlich",
    "lutherisch": "Lutherisch",
    "luther": "Luther",
    "katechismus": "Katechismus",
    "liturgie": "Liturgie",
    "abendmahl": "Abendmahl",
    "stundengebet": "Stundengebet",
    "morgen": "Morgen",
    "abend": "Abend",
    "tischgebet": "Tischgebet",
    "lobpreis": "Lobpreis",
    "danksagung": "Danksagung",
    "bitte": "Bitte",
    "busse": "Buße",
    "frieden": "Frieden",
    "christusgebet": "Christusgebet",
    "trinitaet": "Trinität",
  };

  /// Zusätzliche Suchbegriffe je Tag (werden nicht angezeigt).
  static const Map<String, List<String>> searchAliases = {
    "altkirchlich": ["altkirche", "alte kirche", "patristik"],
    "ostkirchlich": ["ostkirche", "orthodox", "byzantinisch"],
    "lutherisch": ["reformation", "evangelisch"],
    "tischgebet": ["essen", "mahlzeit"],
    "trinitaet": ["dreieinigkeit"],
  };

  static String label(String tag) => labels[tag] ?? tag;
}
