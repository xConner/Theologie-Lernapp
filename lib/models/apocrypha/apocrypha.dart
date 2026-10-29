/// Datenmodell des Bereichs „Apokryphen & außerkanonische Schriften“
/// (`assets/apocrypha/`, erzeugt von `tool/apocrypha`, beschrieben in
/// `docs/apocrypha.md`).
///
/// Ein antikes Werk ([ApocryphaWork]) hat beliebig viele Fassungen
/// ([ApocryphaVersion]): Originaltext, alte Übersetzungen (Latein, Ge'ez,
/// Koptisch) und neuzeitliche Übersetzungen. Rechte, Umfang und Herkunft
/// stehen bei jeder Fassung, nicht beim Werk. Ein Werk kann mehreren
/// Kategorien angehören, der Text liegt trotzdem nur einmal vor.
library;

/// Sprachen der Fassungen.
const Map<String, String> apocryphaLanguages = {
  "de": "Deutsch",
  "grc": "Griechisch",
  "la": "Latein",
  "cop": "Koptisch",
  "gez": "Ge'ez (Altäthiopisch)",
  "syr": "Syrisch",
  "en": "Englisch",
};

String languageName(String code) => apocryphaLanguages[code] ?? code;

enum Tradition {
  juedisch("jüdisch"),
  christlich("christlich"),
  juedischChristlich("jüdisch, christlich überarbeitet");

  final String label;

  const Tradition(this.label);

  static Tradition parse(String? value) => switch (value) {
    "juedisch" => juedisch,
    "juedisch_christlich" => juedischChristlich,
    _ => christlich,
  };
}

/// Wie viel vom Werk überhaupt erhalten ist (unabhängig von der App).
enum Preservation {
  complete("vollständig erhalten"),
  partial("nur teilweise erhalten"),
  fragmentary("nur fragmentarisch erhalten"),
  lost("verloren, nur in Zitaten bezeugt");

  final String label;

  const Preservation(this.label);

  static Preservation parse(String? value) => values.firstWhere(
    (p) => p.name == value,
    orElse: () => Preservation.complete,
  );
}

/// Wie viel vom Werk eine Fassung enthält.
enum Coverage {
  full("vollständig"),
  partial("unvollständig"),
  fragments("Fragmente"),
  excerpt("Auszug"),
  external("nur Verweis");

  final String label;

  const Coverage(this.label);

  static Coverage parse(String? value) => values.firstWhere(
    (c) => c.name == value,
    orElse: () => Coverage.external,
  );
}

enum Rights {
  publicDomain("gemeinfrei"),
  openLicense("offene Lizenz"),
  permission("mit Erlaubnis"),
  protected("urheberrechtlich geschützt"),
  unclear("Rechte ungeklärt");

  final String label;

  const Rights(this.label);

  /// Nur mit diesen Rechten darf der Text in der App stehen.
  bool get allowsText =>
      this == publicDomain || this == openLicense || this == permission;

  static Rights parse(String? value) =>
      values.firstWhere((r) => r.name == value, orElse: () => Rights.unclear);
}

enum VersionKind {
  original("Originalsprache"),
  ancientVersion("Alte Übersetzung"),
  translation("Neuere Übersetzung");

  final String label;

  const VersionKind(this.label);

  static VersionKind parse(String? value) => values.firstWhere(
    (k) => k.name == value,
    orElse: () => VersionKind.translation,
  );
}

/// Grobe Epochen für den Filter. Ein Werk gehört zu jeder Epoche, mit der
/// sich sein Datierungsrahmen überschneidet.
enum ApocryphaEpoch {
  hellenistic("Hellenistische Zeit (bis 63 v. Chr.)", -400, -63),
  earlyRoman("Römische Zeit bis 70 n. Chr.", -63, 70),
  secondCentury("Spätes 1. und 2. Jh. n. Chr.", 70, 200),
  thirdFourth("3. und 4. Jh.", 200, 400),
  lateAntiquity("Spätantike und später", 400, 2000);

  final String label;
  final int from;
  final int to;

  const ApocryphaEpoch(this.label, this.from, this.to);

  bool overlaps(Dating d) => d.from < to && d.to > from;
}

class Dating {
  final String label;
  final int from;
  final int to;

  const Dating(this.label, this.from, this.to);

  factory Dating.fromJson(Map<String, dynamic> json) =>
      Dating(json["label"] as String, json["from"] as int, json["to"] as int);
}

enum AttributionKind {
  pseudepigraph("pseudepigraph"),
  traditionell("traditionelle Zuschreibung"),
  umstritten("Verfasserschaft umstritten"),
  anonym("anonym");

  final String label;

  const AttributionKind(this.label);

  static AttributionKind parse(String? value) => values.firstWhere(
    (a) => a.name == value,
    orElse: () => AttributionKind.anonym,
  );
}

/// Zuschreibung eines Werks. Bei Pseudepigraphen ist [name] der Name, unter
/// dem das Werk überliefert ist – nicht der Verfasser.
class Attribution {
  final String name;
  final AttributionKind kind;
  final String? note;

  const Attribution(this.name, this.kind, this.note);

  factory Attribution.fromJson(Map<String, dynamic> json) => Attribution(
    json["name"] as String? ?? "",
    AttributionKind.parse(json["assessment"] as String?),
    json["note"] as String?,
  );
}

enum AssessmentLevel {
  secure("Gesichert"),
  likely("Wahrscheinlich"),
  disputed("Umstritten");

  final String label;

  const AssessmentLevel(this.label);

  static AssessmentLevel parse(String? value) => values.firstWhere(
    (a) => a.name == value,
    orElse: () => AssessmentLevel.disputed,
  );
}

class Assessment {
  final AssessmentLevel level;
  final String text;

  const Assessment(this.level, this.text);
}

/// Kirchen und Traditionen der Kanontabelle in Anzeigereihenfolge.
const Map<String, String> canonTraditions = {
  "judentum": "Judentum (Tanach)",
  "lutherisch": "Lutherisch",
  "reformiert": "Reformiert",
  "anglikanisch": "Anglikanisch",
  "katholisch": "Römisch-katholisch",
  "orthodox": "Orthodox (byzantinisch)",
  "aethiopisch": "Äthiopisch-orthodox",
};

/// Bezeichnung, die eine Tradition selbst verwendet.
const Map<String, String> canonStatuses = {
  "kanonisch": "kanonisch",
  "deuterokanonisch": "deuterokanonisch (kanonisch)",
  "apokryph": "Apokryphen (lesenswert, nicht kanonisch)",
  "anagignoskomena": "Anagignoskomena (zu lesende Bücher)",
  "anhang": "Anhang der Bibel",
  "nichtkanonisch": "nicht kanonisch",
};

class CanonEntry {
  final String tradition;
  final String status;
  final String? note;

  const CanonEntry(this.tradition, this.status, this.note);

  String get traditionLabel => canonTraditions[tradition] ?? tradition;

  String get statusLabel => canonStatuses[status] ?? status;
}

class ApocryphaCategory {
  final String id;
  final String label;

  const ApocryphaCategory(this.id, this.label);
}

/// Herkunft eines Digitalisats (Repository und Stand).
class ApocryphaSource {
  final String id;
  final String name;
  final String repo;
  final String commit;

  const ApocryphaSource({
    required this.id,
    required this.name,
    required this.repo,
    required this.commit,
  });

  String get url => "$repo/tree/$commit";
}

class ApocryphaVersion {
  final String id;
  final String workId;
  final String language;
  final VersionKind kind;
  final String label;
  final String? translator;
  final String? editor;

  /// Druckausgabe bzw. Edition, der der Text folgt.
  final String? edition;
  final String? year;

  /// Textgrundlage einer Übersetzung.
  final String? basis;

  /// Digitalisat (Schlüssel in [ApocryphaCatalog.sources]) oder `app`
  /// (Text aus dem Bibelbereich).
  final String? source;
  final String? sourceNote;
  final Rights rights;
  final String? license;
  final String? rightsNote;

  /// Pflichtangabe der Lizenz.
  final String? attribution;
  final Coverage coverage;
  final String? coverageNote;
  final String? transcriptionNote;

  /// Externer Link (bei Verweisen der einzige Zugang).
  final String? url;

  /// Zahl der Einheiten (Kapitel, Briefe …); 0 ohne Text in der App.
  final int units;

  /// Der Text steht schon unter `assets/bible/` und wird von dort gelesen.
  final bool fromBible;
  final int chars;

  const ApocryphaVersion({
    required this.id,
    required this.workId,
    required this.language,
    required this.kind,
    required this.label,
    required this.rights,
    required this.coverage,
    this.translator,
    this.editor,
    this.edition,
    this.year,
    this.basis,
    this.source,
    this.sourceNote,
    this.license,
    this.rightsNote,
    this.attribution,
    this.coverageNote,
    this.transcriptionNote,
    this.url,
    this.units = 0,
    this.fromBible = false,
    this.chars = 0,
  });

  bool get hasText => coverage != Coverage.external && units > 0;

  bool get isTranslation => kind == VersionKind.translation;

  factory ApocryphaVersion.fromJson(Map<String, dynamic> json) =>
      ApocryphaVersion(
        id: json["id"] as String,
        workId: json["work"] as String,
        language: json["language"] as String,
        kind: VersionKind.parse(json["kind"] as String?),
        label: json["label"] as String,
        translator: json["translator"] as String?,
        editor: json["editor"] as String?,
        edition: json["edition"] as String?,
        year: json["year"]?.toString(),
        basis: json["basis"] as String?,
        source: json["source"] as String?,
        sourceNote: json["sourceNote"] as String?,
        rights: Rights.parse(json["rights"] as String?),
        license: json["license"] as String?,
        rightsNote: json["rightsNote"] as String?,
        attribution: json["attribution"] as String?,
        coverage: Coverage.parse(json["coverage"] as String?),
        coverageNote: json["coverageNote"] as String?,
        transcriptionNote: json["transcriptionNote"] as String?,
        url: json["url"] as String?,
        units: json["units"] as int? ?? 0,
        fromBible: json["fromBible"] == true,
        chars: json["chars"] as int? ?? 0,
      );
}

class ApocryphaWork {
  final String id;
  final String title;
  final List<String> altTitles;
  final List<String> categories;
  final Tradition tradition;
  final String genre;
  final Dating dating;
  final String? place;
  final String? originalLanguage;
  final String? transmission;
  final Preservation preservation;
  final String? preservationNote;
  final Attribution? attribution;
  final String summary;
  final List<Assessment> assessments;
  final String? significance;
  final List<CanonEntry> canon;
  final String? canonNote;
  final String? versification;

  /// Buch-ID im Bibelbereich, falls das Buch dort (LXX, Vulgata) steht.
  final String? bibleBook;
  final List<(String, String)> links;
  final String? noTextReason;
  final String? noTranslationReason;
  final String? translationNote;
  final List<ApocryphaVersion> versions;

  const ApocryphaWork({
    required this.id,
    required this.title,
    required this.categories,
    required this.tradition,
    required this.genre,
    required this.dating,
    required this.preservation,
    required this.summary,
    this.altTitles = const [],
    this.place,
    this.originalLanguage,
    this.transmission,
    this.preservationNote,
    this.attribution,
    this.assessments = const [],
    this.significance,
    this.canon = const [],
    this.canonNote,
    this.versification,
    this.bibleBook,
    this.links = const [],
    this.noTextReason,
    this.noTranslationReason,
    this.translationNote,
    this.versions = const [],
  });

  List<ApocryphaVersion> get readableVersions => [
    for (final v in versions)
      if (v.hasText) v,
  ];

  bool get hasText => versions.any((v) => v.hasText);

  /// Text in der Originalsprache bzw. der ältesten erhaltenen Sprache.
  bool get hasOriginalText =>
      versions.any((v) => v.hasText && v.kind == VersionKind.original);

  /// Neuzeitliche Übersetzungen mit Text in der App.
  int get translationCount =>
      versions.where((v) => v.hasText && v.isTranslation).length;

  bool get hasGermanText =>
      versions.any((v) => v.hasText && v.language == "de");

  /// Mindestens eine Fassung enthält das ganze erhaltene Werk.
  bool get hasCompleteText =>
      versions.any((v) => v.hasText && v.coverage == Coverage.full);

  Set<String> get textLanguages => {
    for (final v in versions)
      if (v.hasText) v.language,
  };

  /// Die Fassung, die der Leser ohne gespeicherte Wahl öffnet: Deutsch vor
  /// Original, vollständige vor unvollständigen.
  ApocryphaVersion? get defaultVersion {
    final readable = readableVersions;
    if (readable.isEmpty) return null;
    int rank(ApocryphaVersion v) =>
        (v.language == "de" ? 0 : (v.kind == VersionKind.original ? 1 : 2)) *
            2 +
        (v.coverage == Coverage.full ? 0 : 1);
    return ([...readable]..sort((a, b) => rank(a).compareTo(rank(b)))).first;
  }

  factory ApocryphaWork.fromJson(Map<String, dynamic> json) {
    final attribution = json["attribution"];
    return ApocryphaWork(
      id: json["id"] as String,
      title: json["title"] as String,
      altTitles: [...?(json["altTitles"] as List?)?.cast<String>()],
      categories: [...(json["categories"] as List).cast<String>()],
      tradition: Tradition.parse(json["tradition"] as String?),
      genre: json["genre"] as String,
      dating: Dating.fromJson(Map<String, dynamic>.from(json["dating"] as Map)),
      place: json["place"] as String?,
      originalLanguage: json["originalLanguage"] as String?,
      transmission: json["transmission"] as String?,
      preservation: Preservation.parse(json["preservation"] as String?),
      preservationNote: json["preservationNote"] as String?,
      attribution: attribution is Map
          ? Attribution.fromJson(Map<String, dynamic>.from(attribution))
          : null,
      summary: json["summary"] as String,
      assessments: [
        for (final a in json["assessments"] as List? ?? const [])
          Assessment(
            AssessmentLevel.parse((a as List)[0] as String),
            a[1] as String,
          ),
      ],
      significance: json["significance"] as String?,
      canon: [
        for (final c in json["canon"] as List? ?? const [])
          CanonEntry(
            (c as List)[0] as String,
            c[1] as String,
            c.length > 2 ? c[2] as String? : null,
          ),
      ],
      canonNote: json["canonNote"] as String?,
      versification: json["versification"] as String?,
      bibleBook: json["bible"] as String?,
      links: [
        for (final l in json["links"] as List? ?? const [])
          ((l as List)[0] as String, l[1] as String),
      ],
      noTextReason: json["noTextReason"] as String?,
      noTranslationReason: json["noTranslationReason"] as String?,
      translationNote: json["translationNote"] as String?,
      versions: [
        for (final v in json["versions"] as List? ?? const [])
          ApocryphaVersion.fromJson(Map<String, dynamic>.from(v as Map)),
      ],
    );
  }
}

class ApocryphaCatalog {
  final List<ApocryphaCategory> categories;
  final Map<String, ApocryphaSource> sources;
  final List<ApocryphaWork> works;

  late final Map<String, ApocryphaWork> _works = {
    for (final w in works) w.id: w,
  };

  late final Map<String, ApocryphaVersion> _versions = {
    for (final w in works)
      for (final v in w.versions) v.id: v,
  };

  late final Map<String, String> _categoryLabels = {
    for (final c in categories) c.id: c.label,
  };

  ApocryphaCatalog({
    required this.categories,
    required this.sources,
    required this.works,
  });

  ApocryphaWork? work(String id) => _works[id];

  ApocryphaVersion? version(String id) => _versions[id];

  String categoryLabel(String id) => _categoryLabels[id] ?? id;

  List<ApocryphaWork> worksIn(String categoryId) => [
    for (final w in works)
      if (w.categories.contains(categoryId)) w,
  ];

  factory ApocryphaCatalog.fromJson(Map<String, dynamic> json) {
    final sources = Map<String, dynamic>.from(json["sources"] as Map);
    return ApocryphaCatalog(
      categories: [
        for (final c in json["categories"] as List)
          ApocryphaCategory((c as List)[0] as String, c[1] as String),
      ],
      sources: {
        for (final e in sources.entries)
          e.key: ApocryphaSource(
            id: e.key,
            name: (e.value as Map)["name"] as String,
            repo: (e.value as Map)["repo"] as String,
            commit: (e.value as Map)["commit"] as String,
          ),
      },
      works: [
        for (final w in json["works"] as List)
          ApocryphaWork.fromJson(Map<String, dynamic>.from(w as Map)),
      ],
    );
  }
}

/// Fundstelle einer Einheit im Bibelbereich (Septuaginta, Vulgata).
class BibleSpan {
  final String translation;
  final String book;
  final int chapter;
  final int firstVerse;
  final int lastVerse;

  const BibleSpan(
    this.translation,
    this.book,
    this.chapter,
    this.firstVerse,
    this.lastVerse,
  );
}

/// Eintrag im Inhaltsverzeichnis einer Fassung.
class TocUnit {
  /// Gleiche Kennung in allen Fassungen eines Werks (für den Vergleich).
  final String id;
  final String label;

  /// Übergeordnete Gliederung, z. B. `["Visionen"]`.
  final List<String> path;
  final String? title;

  /// Textdatei (`<fassung>.<chunk>.json`); null bei [bible].
  final int? chunk;

  /// Zahl der Verse bzw. Absätze.
  final int count;
  final BibleSpan? bible;

  const TocUnit({
    required this.id,
    required this.label,
    this.path = const [],
    this.title,
    this.chunk,
    this.count = 0,
    this.bible,
  });

  String get fullLabel => [...path, label].join(" · ");

  factory TocUnit.fromJson(Map<String, dynamic> json) {
    final src = json["src"] as List?;
    return TocUnit(
      id: json["id"] as String,
      label: json["label"] as String,
      path: [...?(json["path"] as List?)?.cast<String>()],
      title: json["title"] as String?,
      chunk: json["c"] as int?,
      count: (json["n"] ?? json["count"]) as int? ?? 0,
      bible: src == null
          ? null
          : BibleSpan(
              src[0] as String,
              src[1] as String,
              src[2] as int,
              src[3] as int,
              src[4] as int,
            ),
    );
  }
}

/// Vers oder Absatz: Nummer der Ausgabe (kann leer sein) und Wortlaut.
/// Anmerkungszeichen stehen als `[n]` im Text.
class TextBlock {
  final String number;
  final String text;

  const TextBlock(this.number, this.text);
}

class UnitText {
  final String id;
  final List<TextBlock> blocks;
  final List<String> notes;

  const UnitText(this.id, this.blocks, {this.notes = const []});

  factory UnitText.fromJson(Map<String, dynamic> json) => UnitText(
    json["id"] as String,
    [
      for (final b in json["b"] as List)
        TextBlock((b as List)[0] as String, b[1] as String),
    ],
    notes: [...?(json["notes"] as List?)?.cast<String>()],
  );
}
