import '../bible/bible_reference.dart';

/// Datenmodell der Bibliothek „Kirchenväter & Schriften“.
///
/// Getrennt sind das vollständige Werk ([FathersWork] mit seinen Fassungen
/// [WorkVersion] und dem Text [WorkSection]) und die Zuordnung einzelner
/// Textabschnitte zu Bibelstellen ([PassageLink]). Ein Werk kann viele
/// Stellen behandeln, eine Stelle kann in vielen Werken vorkommen.
///
/// Alle Bibelstellen zählen wie die Perikopenliste (deutsche Zählung,
/// USFM-Buchkennungen); siehe `ListVersification`.

/// Historische Einordnung. Spätere Theologen sind keine Kirchenväter und
/// werden nicht so bezeichnet.
enum AuthorCategory {
  /// Kirchenväter und weitere Autoren der Alten Kirche (bis etwa 750).
  churchFather("Kirchenvater / Alte Kirche"),

  /// Theologen des Mittelalters.
  medieval("Mittelalterlicher Theologe"),

  /// Reformatoren des 16. Jahrhunderts.
  reformer("Reformator"),

  /// Lutherische Theologen nach der Reformation.
  lutheran("Lutherischer Theologe (nachreformatorisch)");

  final String label;

  const AuthorCategory(this.label);

  static AuthorCategory parse(String? value) {
    for (final c in values) {
      if (c.name == value) return c;
    }

    return AuthorCategory.churchFather;
  }
}

/// Epochen für Filter, aus dem Todesjahr bestimmt.
enum Epoch {
  apostolic("Apostolische Väter und 2. Jh.", 0, 200),
  preNicene("3. Jh. bis Nizäa (325)", 201, 325),
  fourthFifth("4.–5. Jahrhundert", 326, 500),
  late("6.–8. Jahrhundert", 501, 800),
  medieval("Mittelalter", 801, 1500),
  reformation("Reformation (16. Jh.)", 1501, 1600),
  modern("17. Jh. und später", 1601, 9999);

  final String label;
  final int from;
  final int to;

  const Epoch(this.label, this.from, this.to);

  static Epoch? ofYear(int? year) {
    if (year == null) return null;

    for (final e in values) {
      if (year >= e.from && year <= e.to) return e;
    }

    return null;
  }
}

class FathersAuthor {
  /// Stabile Kennung, z. B. `augustinus`.
  final String id;

  final String name;

  /// Weitere Namensformen für die Suche (lateinisch, griechisch, englisch).
  final List<String> aliases;

  final AuthorCategory category;

  /// „Ost“, „West“ oder „Syrisch“ – nur zur Orientierung.
  final String? tradition;

  /// Lebensdaten in Anzeigeform, z. B. „354–430“ oder „† um 107“.
  final String? lifeDates;

  /// Todesjahr (ungefähr) für Sortierung und Epochenfilter.
  final int? deathYear;

  /// Schreibsprache(n), z. B. `la`, `grc`, `syr`, `de`.
  final List<String> languages;

  /// Kurze Einordnung; redaktionelle Angabe von theologie.app, kein
  /// Quellentext.
  final String? note;

  const FathersAuthor({
    required this.id,
    required this.name,
    this.aliases = const [],
    required this.category,
    this.tradition,
    this.lifeDates,
    this.deathYear,
    this.languages = const [],
    this.note,
  });

  Epoch? get epoch => Epoch.ofYear(deathYear);

  factory FathersAuthor.fromJson(Map<String, dynamic> json) {
    return FathersAuthor(
      id: json["id"] as String,
      name: json["name"] as String,
      aliases: _strings(json["aliases"]),
      category: AuthorCategory.parse(json["category"] as String?),
      tradition: json["tradition"] as String?,
      lifeDates: json["lifeDates"] as String?,
      deathYear: (json["deathYear"] as num?)?.toInt(),
      languages: _strings(json["languages"]),
      note: json["note"] as String?,
    );
  }
}

/// Art des Textes, wie ihn die App zeigt. Historische Übersetzungen werden
/// nie als heutige Standardübersetzung ausgegeben.
enum TextKind {
  historicalTranslation("Historische deutsche Übersetzung"),
  original("Originaltext"),
  modernTranslation("Moderne Übersetzung");

  final String label;

  const TextKind(this.label);

  static TextKind parse(String? value) {
    for (final k in values) {
      if (k.name == value) return k;
    }

    return TextKind.historicalTranslation;
  }
}

/// Rechtestand einer konkreten Textfassung (nicht des Werks).
enum RightsStatus {
  /// Gemeinfrei: Übersetzer seit mehr als 70 Jahren verstorben (belegt).
  publicDomain("Gemeinfrei"),

  /// Nicht gemeinfrei, aber mit Erlaubnis der Rechteinhaber ausgeliefert
  /// (Beleg in `tool/fathers/curation/rights.json`).
  permission("Mit Nutzungserlaubnis"),

  /// Nur Metadaten und Link; der Volltext wird nicht ausgeliefert, weil die
  /// Rechte an der Fassung nicht geklärt sind.
  unclear("Rechte ungeklärt – nur Verweis"),

  /// Geschützt; nur Metadaten und Link.
  protected("Geschützt – nur Verweis");

  final String label;

  const RightsStatus(this.label);

  static RightsStatus parse(String? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }

    return RightsStatus.unclear;
  }
}

/// Was die App von einer Fassung enthält.
enum Availability {
  full("Volltext"),
  partial("Teilweise"),
  external("Nur externer Link");

  final String label;

  const Availability(this.label);

  static Availability parse(String? value) {
    for (final a in values) {
      if (a.name == value) return a;
    }

    return Availability.external;
  }
}

/// Eine Fassung eines Werks: eine bestimmte Übersetzung oder Edition.
class WorkVersion {
  /// Stabile Kennung, zugleich Verzeichnis unter `assets/fathers/texts/`.
  final String id;

  final String title;

  /// Sprachcode des Textes, z. B. `de`.
  final String language;

  final TextKind kind;

  final String? translator;

  /// Reihe und Band, z. B. „Bibliothek der Kirchenväter, 1. Reihe, Band 8“.
  final String? series;

  final String? published;

  /// Erscheinungsjahr(e), wie die Quelle sie nennt.
  final String? year;

  /// Digitale Quelle, z. B. „BKV (Universität Freiburg/Schweiz)“.
  final String? sourceName;
  final String? sourceUrl;

  final RightsStatus rights;

  /// Begründung des Rechtestands (z. B. Lebensdaten des Übersetzers).
  final String? rightsNote;

  final Availability availability;

  final int sectionCount;
  final int linkCount;

  /// Bibelbücher (USFM), die die Zuordnungen dieser Fassung berühren.
  final List<String> books;

  /// Der Text steht in einem anderen Bereich der App, z. B.
  /// `confession:kleiner_katechismus` (Bekenntnisse).
  final String? appLink;

  const WorkVersion({
    required this.id,
    required this.title,
    this.language = "de",
    this.kind = TextKind.historicalTranslation,
    this.translator,
    this.series,
    this.published,
    this.year,
    this.sourceName,
    this.sourceUrl,
    this.rights = RightsStatus.unclear,
    this.rightsNote,
    this.availability = Availability.external,
    this.sectionCount = 0,
    this.linkCount = 0,
    this.books = const [],
    this.appLink,
  });

  /// Der Text liegt in der Bibliothek vor (und darf es).
  bool get hasText =>
      availability != Availability.external &&
      (rights == RightsStatus.publicDomain ||
          rights == RightsStatus.permission);

  factory WorkVersion.fromJson(Map<String, dynamic> json) {
    return WorkVersion(
      id: json["id"] as String,
      title: json["title"] as String,
      language: json["language"] as String? ?? "de",
      kind: TextKind.parse(json["kind"] as String?),
      translator: json["translator"] as String?,
      series: json["series"] as String?,
      published: json["published"] as String?,
      year: json["year"]?.toString(),
      sourceName: json["sourceName"] as String?,
      sourceUrl: json["sourceUrl"] as String?,
      rights: RightsStatus.parse(json["rights"] as String?),
      rightsNote: json["rightsNote"] as String?,
      availability: Availability.parse(json["availability"] as String?),
      sectionCount: (json["sections"] as num?)?.toInt() ?? 0,
      linkCount: (json["links"] as num?)?.toInt() ?? 0,
      books: _strings(json["books"]),
      appLink: json["appLink"] as String?,
    );
  }
}

class FathersWork {
  final String id;
  final String authorId;

  final String title;

  /// Titel im Original (lateinisch/griechisch), soweit belegt.
  final String? originalTitle;

  /// Clavis-Nummer, z. B. „CPL 278“ oder „CPG 4424“.
  final String? clavis;

  /// Gattung, z. B. „Kommentar“, „Homilien“, „Brief“.
  final String genre;

  final String? originalLanguage;

  final List<WorkVersion> versions;

  const FathersWork({
    required this.id,
    required this.authorId,
    required this.title,
    this.originalTitle,
    this.clavis,
    required this.genre,
    this.originalLanguage,
    this.versions = const [],
  });

  /// Bester Zugang: zuerst eine Fassung mit Text in der App.
  Availability get availability {
    if (versions.any((v) => v.hasText && v.availability == Availability.full)) {
      return Availability.full;
    }

    if (versions.any((v) => v.hasText)) return Availability.partial;

    if (versions.any((v) => v.appLink != null)) return Availability.full;

    return Availability.external;
  }

  WorkVersion? get readableVersion {
    for (final v in versions) {
      if (v.hasText) return v;
    }

    return null;
  }

  int get linkCount => versions.fold(0, (sum, v) => sum + v.linkCount);

  factory FathersWork.fromJson(Map<String, dynamic> json) {
    return FathersWork(
      id: json["id"] as String,
      authorId: json["author"] as String,
      title: json["title"] as String,
      originalTitle: json["originalTitle"] as String?,
      clavis: json["clavis"] as String?,
      genre: json["genre"] as String? ?? "Schrift",
      originalLanguage: json["originalLanguage"] as String?,
      versions: [
        for (final v in json["versions"] as List? ?? const [])
          WorkVersion.fromJson(Map<String, dynamic>.from(v as Map)),
      ],
    );
  }
}

/// Wie ein Textabschnitt mit einer Bibelstelle zusammenhängt.
enum LinkKind {
  quotation("Bibelzitat"),
  verseCommentary("Auslegung dieses Verses"),
  sectionCommentary("Auslegung des Abschnitts"),
  reference("Verweis im Text"),
  suggested("Automatischer Vorschlag");

  final String label;

  const LinkKind(this.label);

  static LinkKind parse(String? value) {
    for (final k in values) {
      if (k.name == value) return k;
    }

    return LinkKind.suggested;
  }
}

/// Woher die Zuordnung stammt.
enum AlignmentMethod {
  /// Die Ausgabe nennt die Stelle in der Überschrift des Abschnitts.
  editionHeading("Überschrift der Ausgabe"),

  /// Die Ausgabe nennt die Stelle im Text oder in einer Anmerkung.
  editionCitation("Stellenangabe der Ausgabe"),

  /// Von Hand geprüft und eingetragen.
  manual("Redaktionell zugeordnet");

  final String label;

  const AlignmentMethod(this.label);

  static AlignmentMethod parse(String? value) {
    for (final m in values) {
      if (m.name == value) return m;
    }

    return AlignmentMethod.editionCitation;
  }
}

enum Confidence {
  high("sicher"),
  medium("wahrscheinlich"),
  low("unsicher");

  final String label;

  const Confidence(this.label);

  static Confidence parse(String? value) {
    for (final c in values) {
      if (c.name == value) return c;
    }

    return Confidence.low;
  }
}

/// Zuordnung eines Textabschnitts zu einer Bibelstelle.
class PassageLink {
  /// Stabile Kennung (bleibt bei erneutem Import gleich).
  final String id;

  final String versionId;
  final String workId;
  final String authorId;

  /// Abschnitt im Werk und Absätze darin (0-basiert, einschließlich).
  final int section;
  final int firstParagraph;
  final int lastParagraph;

  final BibleReference reference;

  final LinkKind kind;
  final AlignmentMethod method;
  final Confidence confidence;

  /// Die Stellenangabe, wie sie in der Ausgabe steht, z. B. „Joh. 1, 1“.
  final String? citedAs;

  /// Hinweis zur Zuordnung (z. B. abweichende Psalmenzählung).
  final String? note;

  /// `unreviewed` (automatisch aus der Ausgabe) oder `checked`.
  final String review;

  const PassageLink({
    required this.id,
    required this.versionId,
    required this.workId,
    required this.authorId,
    required this.section,
    this.firstParagraph = 0,
    this.lastParagraph = 0,
    required this.reference,
    required this.kind,
    required this.method,
    required this.confidence,
    this.citedAs,
    this.note,
    this.review = "unreviewed",
  });

  /// Ob die Zuordnung den Vers [verse] in Kapitel [chapter] berührt.
  bool touches(int chapter, int verse) =>
      reference.containsVerse(chapter, verse);

  /// Ob sich die Stelle mit [other] (gleiches Buch) überschneidet.
  bool overlaps(BibleReference other) {
    if (other.bookId != reference.bookId) return false;

    int start(BibleReference r) => r.chapter * 1000 + (r.verse ?? 0);
    int end(BibleReference r) {
      if (r.verse == null || r.openEnd) return r.endChapter * 1000 + 999;

      return r.endChapter * 1000 + (r.endVerse ?? r.verse!);
    }

    return start(reference) <= end(other) && start(other) <= end(reference);
  }

  /// Kompakte Form der Daten (eine Zeile je Zuordnung, siehe
  /// `tool/fathers/README.md`).
  factory PassageLink.fromJson(String bookId, Map<String, dynamic> json) {
    final r = (json["r"] as List).cast<num>().map((n) => n.toInt()).toList();
    final p = (json["p"] as List? ?? const [0, 0])
        .cast<num>()
        .map((n) => n.toInt())
        .toList();

    return PassageLink(
      id: json["id"] as String,
      versionId: json["v"] as String,
      workId: json["w"] as String,
      authorId: json["a"] as String,
      section: (json["s"] as num).toInt(),
      firstParagraph: p.first,
      lastParagraph: p.last,
      reference: BibleReference(
        bookId: bookId,
        chapter: r[0],
        verse: r.length > 1 && r[1] > 0 ? r[1] : null,
        endChapter: r.length > 2 ? r[2] : r[0],
        endVerse: r.length > 3 && r[3] > 0 ? r[3] : null,
      ),
      kind: LinkKind.parse(json["k"] as String?),
      method: AlignmentMethod.parse(json["m"] as String?),
      confidence: Confidence.parse(json["c"] as String?),
      citedAs: json["cited"] as String?,
      note: json["note"] as String?,
      review: json["review"] as String? ?? "unreviewed",
    );
  }
}

/// Inhaltsverzeichnis einer Fassung mit Text.
class WorkTableOfContents {
  final String versionId;
  final List<SectionEntry> sections;

  const WorkTableOfContents(this.versionId, this.sections);

  SectionEntry? entry(int number) {
    for (final s in sections) {
      if (s.number == number) return s;
    }

    return null;
  }

  factory WorkTableOfContents.fromJson(
    String versionId,
    Map<String, dynamic> json,
  ) {
    return WorkTableOfContents(versionId, [
      for (final s in json["sections"] as List)
        SectionEntry.fromJson(Map<String, dynamic>.from(s as Map)),
    ]);
  }
}

class SectionEntry {
  /// Stabile Nummer des Abschnitts innerhalb der Fassung.
  final int number;

  final String title;

  /// Übergeordnete Gliederung (z. B. „Erstes Buch“), sonst leer.
  final List<String> path;

  /// Datei unter `assets/fathers/texts/<version>/`, die den Text enthält.
  final int chunk;

  /// Fundstelle in der Quelle (Kapitel/Abschnitt bzw. Seite).
  final String? sourceRef;
  final String? sourceUrl;

  const SectionEntry({
    required this.number,
    required this.title,
    this.path = const [],
    required this.chunk,
    this.sourceRef,
    this.sourceUrl,
  });

  factory SectionEntry.fromJson(Map<String, dynamic> json) {
    return SectionEntry(
      number: (json["n"] as num).toInt(),
      title: json["t"] as String,
      path: _strings(json["path"]),
      chunk: (json["c"] as num).toInt(),
      sourceRef: json["ref"] as String?,
      sourceUrl: json["url"] as String?,
    );
  }
}

/// Text eines Abschnitts: Absätze und Anmerkungen der Ausgabe.
class WorkSection {
  final int number;
  final List<String> paragraphs;

  /// Anmerkungen der Ausgabe (Fußnoten), in der Reihenfolge der Quelle.
  final List<String> notes;

  const WorkSection({
    required this.number,
    required this.paragraphs,
    this.notes = const [],
  });

  factory WorkSection.fromJson(Map<String, dynamic> json) {
    return WorkSection(
      number: (json["n"] as num).toInt(),
      paragraphs: _strings(json["p"]),
      notes: _strings(json["notes"]),
    );
  }
}

/// Art eines Querverweises.
enum CrossRefKind {
  /// Gleiche Perikope in einem anderen Evangelium (Perikopen-Datensatz).
  parallel("Parallelstelle"),

  /// Verwandte Stelle nach OpenBible.info (aus dem Treasury of Scripture
  /// Knowledge und Nutzerbewertungen; ohne Angabe der Art des Bezugs).
  related("Verwandte Stelle");

  final String label;

  const CrossRefKind(this.label);
}

class CrossReference {
  final BibleReference target;
  final CrossRefKind kind;

  /// Bewertung bei OpenBible.info (höher = von mehr Nutzern bestätigt).
  final int? votes;

  /// Begründung, soweit die Quelle eine liefert (z. B. Perikopentitel).
  final String? reason;

  final String source;

  const CrossReference({
    required this.target,
    required this.kind,
    this.votes,
    this.reason,
    required this.source,
  });
}

List<String> _strings(Object? value) => [
  for (final v in value as List? ?? const []) v.toString(),
];
