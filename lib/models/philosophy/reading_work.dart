/// Werkverzeichnis des Lesebereichs (`assets/philosophy/works.json`).
library;

enum EditionKind {
  /// Mit der App ausgeliefert (Rechte geklärt, z. B. CC BY-SA).
  bundled,

  /// Geschützte Ausgabe: wird aus der eigenen Kopie erzeugt, vom Nutzer
  /// importiert und nur in seinem Konto bzw. auf seinem Gerät gespeichert.
  private,
}

class ReadingEdition {
  final String id;
  final EditionKind kind;

  /// Vollständige Angabe der Ausgabe.
  final String title;

  /// Kurzbezeichnung für Auswahl und Kennzeichnung („Ross 1950“).
  final String short;

  /// Sprachen des Texts („grc“, „de“).
  final List<String> languages;

  /// Rechte und Lizenz in Worten.
  final String rights;

  /// Quelle (URL), falls vorhanden.
  final String? source;

  /// Hinweise zur Qualität und zu Grenzen der Ausgabe.
  final String? note;

  /// Nur [EditionKind.bundled]: Verzeichnis der Buchdateien.
  final String? path;

  /// Nur [EditionKind.private]: so wird die Datei erzeugt.
  final String? importHint;

  /// Bücher, die die Ausgabe enthält.
  final List<int> books;

  const ReadingEdition({
    required this.id,
    required this.kind,
    required this.title,
    required this.short,
    required this.languages,
    required this.rights,
    required this.books,
    this.source,
    this.note,
    this.path,
    this.importHint,
  });

  bool get hasGerman => languages.contains("de");

  factory ReadingEdition.fromJson(Map<String, dynamic> json) {
    return ReadingEdition(
      id: json["id"] as String,
      kind: json["kind"] == "private" ? EditionKind.private : EditionKind.bundled,
      title: json["title"] as String,
      short: json["short"] as String,
      languages: List<String>.from(json["languages"] as List),
      rights: json["rights"] as String,
      books: [for (final b in json["books"] as List) (b as num).toInt()],
      source: json["source"] as String?,
      note: json["note"] as String?,
      path: json["path"] as String?,
      importHint: json["importHint"] as String?,
    );
  }
}

class ReadingWorkBook {
  final int number;

  /// Buchzählung des Werks („I“).
  final String label;

  const ReadingWorkBook(this.number, this.label);
}

/// Ein Werk mit seinen Ausgaben. Weitere Werke (andere Schriften des
/// Aristoteles, andere Autoren) werden als weiterer Eintrag in
/// `works.json` ergänzt.
class ReadingWork {
  final String id;
  final String author;
  final String title;
  final String originalTitle;

  /// Kurze Einführung der App (eigener Text, als solcher gekennzeichnet).
  final List<String> description;

  /// Zählung, nach der zitiert wird („Bekker-Zählung …“).
  final String citation;

  final List<ReadingWorkBook> books;
  final List<ReadingEdition> editions;

  /// Formenindex für die Wortanalyse.
  final String? formsAsset;

  /// Seminarplan (Sitzungen mit Textstellen), sobald vorhanden.
  final String? seminarAsset;

  const ReadingWork({
    required this.id,
    required this.author,
    required this.title,
    required this.originalTitle,
    required this.description,
    required this.citation,
    required this.books,
    required this.editions,
    this.formsAsset,
    this.seminarAsset,
  });

  String get displayTitle => "$author: $title";

  ReadingEdition? edition(String id) {
    for (final e in editions) {
      if (e.id == id) return e;
    }
    return null;
  }

  String bookLabel(int number) {
    for (final b in books) {
      if (b.number == number) return b.label;
    }
    return "$number";
  }

  factory ReadingWork.fromJson(Map<String, dynamic> json) {
    return ReadingWork(
      id: json["id"] as String,
      author: json["author"] as String,
      title: json["title"] as String,
      originalTitle: json["originalTitle"] as String,
      description: List<String>.from(json["description"] as List),
      citation: json["citation"] as String,
      books: [
        for (final b in json["books"] as List)
          ReadingWorkBook(
            ((b as Map)["n"] as num).toInt(),
            b["label"] as String,
          ),
      ],
      editions: [
        for (final e in json["editions"] as List)
          ReadingEdition.fromJson(e as Map<String, dynamic>),
      ],
      formsAsset: json["formsAsset"] as String?,
      seminarAsset: json["seminarAsset"] as String?,
    );
  }
}

/// Eine Sitzung des Seminarplans mit den vorgesehenen Textstellen.
class SeminarSession {
  final String id;
  final DateTime? date;
  final String title;

  /// Stellen als Bekker-Bereiche („184a10–185a20“).
  final List<String> passages;
  final List<String> materials;
  final List<String> tasks;

  const SeminarSession({
    required this.id,
    required this.date,
    required this.title,
    required this.passages,
    required this.materials,
    required this.tasks,
  });

  factory SeminarSession.fromJson(Map<String, dynamic> json) {
    return SeminarSession(
      id: json["id"] as String,
      date: DateTime.tryParse((json["date"] as String?) ?? ""),
      title: json["title"] as String,
      passages: List<String>.from((json["passages"] as List?) ?? const []),
      materials: List<String>.from((json["materials"] as List?) ?? const []),
      tasks: List<String>.from((json["tasks"] as List?) ?? const []),
    );
  }
}
