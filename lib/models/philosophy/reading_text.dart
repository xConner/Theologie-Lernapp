/// Datenmodell des Lesebereichs für philosophische Texte (zuerst
/// Aristoteles, Physik). Format und Herkunft: `docs/philosophy-reader.md`.
///
/// Unterschieden werden Werk ([ReadingWork]) und Ausgabe ([ReadingEdition]),
/// Abschnitt ([ReadingUnit]) und Satz ([GreekSentence]), Original und
/// Übersetzung ([GermanSegment]), Anmerkungen der Ausgabe ([EditionNote]) und
/// die Vorrede der Ausgabe ([EditionFront]). Stellen werden in der
/// Standardzählung des Werks angegeben ([BekkerRef]); daraus entstehen die
/// stabilen Kennungen, an denen persönliche Notizen und Lernstände hängen –
/// unabhängig davon, welche Ausgabe gerade gelesen wird.
library;

/// Stelle nach der Bekker-Zählung: Seite, Spalte, Zeile (z. B. 184a10).
class BekkerRef implements Comparable<BekkerRef> {
  final int page;
  final String column;
  final int line;

  const BekkerRef(this.page, this.column, this.line);

  static final RegExp _pattern = RegExp(r'^(\d{2,4})([ab])(\d{1,2})$');

  static BekkerRef? tryParse(String? text) {
    if (text == null) return null;
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return BekkerRef(int.parse(m[1]!), m[2]!, int.parse(m[3]!));
  }

  static BekkerRef parse(String text) {
    final ref = tryParse(text);
    if (ref == null) throw FormatException("Keine Bekker-Stelle: $text");
    return ref;
  }

  /// Fortlaufende Ordnungszahl (eine Spalte hat weniger als 100 Zeilen).
  int get order => page * 200 + (column == "a" ? 0 : 100) + line;

  @override
  int compareTo(BekkerRef other) => order.compareTo(other.order);

  bool operator <(BekkerRef other) => order < other.order;
  bool operator >(BekkerRef other) => order > other.order;
  bool operator <=(BekkerRef other) => order <= other.order;
  bool operator >=(BekkerRef other) => order >= other.order;

  @override
  bool operator ==(Object other) =>
      other is BekkerRef && other.order == order;

  @override
  int get hashCode => order;

  @override
  String toString() => "$page$column$line";
}

/// Bereich zweier Bekker-Stellen (einschließlich).
class BekkerRange {
  final BekkerRef from;
  final BekkerRef to;

  const BekkerRange(this.from, this.to);

  factory BekkerRange.single(BekkerRef ref) => BekkerRange(ref, ref);

  static BekkerRange? tryParse(String? from, String? to) {
    final a = BekkerRef.tryParse(from);
    if (a == null) return null;
    final b = BekkerRef.tryParse(to) ?? a;
    return b < a ? BekkerRange(a, a) : BekkerRange(a, b);
  }

  bool contains(BekkerRef ref) => ref >= from && ref <= to;

  bool overlaps(BekkerRange other) => from <= other.to && other.from <= to;

  /// Kurzform wie in den Ausgaben: 184a10–16, 184a16–b14, 191b35–192a1.
  String get label {
    if (from == to) return "$from";
    if (from.page != to.page) return "$from–$to";
    if (from.column != to.column) return "$from–${to.column}${to.line}";
    return "$from–${to.line}";
  }

  @override
  String toString() => label;
}

/// Ein griechischer Satz (bzw. Satzteil bis zum nächsten Punkt, Kolon oder
/// Fragezeichen). [id] ist die Bekker-Stelle seines Anfangs, bei mehreren
/// Sätzen auf derselben Zeile mit Zusatz („185b25.2“).
class GreekSentence {
  final String id;
  final BekkerRef ref;
  final BekkerRef to;
  final String text;

  const GreekSentence({
    required this.id,
    required this.ref,
    required this.to,
    required this.text,
  });

  BekkerRange get range => BekkerRange(ref, to < ref ? ref : to);

  factory GreekSentence.fromJson(Map<String, dynamic> json) {
    final ref = BekkerRef.parse(json["r"] as String);
    return GreekSentence(
      id: json["id"] as String,
      ref: ref,
      to: BekkerRef.tryParse(json["to"] as String?) ?? ref,
      text: json["t"] as String,
    );
  }
}

/// Ein Stück der Übersetzung, beginnend an einer Zeilenmarke der Ausgabe.
class GermanSegment {
  final BekkerRef ref;
  final String text;

  const GermanSegment(this.ref, this.text);

  factory GermanSegment.fromJson(Map<String, dynamic> json) =>
      GermanSegment(BekkerRef.parse(json["r"] as String), json["t"] as String);
}

/// Abschnitt: griechische Sätze und die zugehörige Übersetzung. Die Grenzen
/// stammen aus den Zeilenmarken der Übersetzung. [exact] ist false, wenn die
/// Marke nicht genau auf den Anfang eines griechischen Satzes fiel (die
/// Zuordnung ist dann abschnittsweise, nicht satzgenau gesichert).
class ReadingUnit {
  final String id;
  final List<GreekSentence> greek;
  final List<GermanSegment> german;
  final bool exact;

  /// Druckseiten (griechisch / deutsch), soweit bekannt.
  final int? greekPage;
  final int? germanPage;

  const ReadingUnit({
    required this.id,
    required this.greek,
    required this.german,
    required this.exact,
    this.greekPage,
    this.germanPage,
  });

  BekkerRef get ref => greek.first.ref;

  BekkerRange get range {
    var end = greek.last.to;
    for (final s in greek) {
      if (s.to > end) end = s.to;
    }
    return BekkerRange(ref, end < ref ? ref : end);
  }

  bool get hasGerman => german.isNotEmpty;

  /// Ein Satz entspricht genau einem Übersetzungsstück.
  bool get oneToOne => greek.length == 1 && german.length == 1;

  factory ReadingUnit.fromJson(Map<String, dynamic> json) {
    return ReadingUnit(
      id: json["id"] as String,
      greek: [
        for (final g in json["g"] as List)
          GreekSentence.fromJson(g as Map<String, dynamic>),
      ],
      german: [
        for (final d in (json["d"] as List?) ?? const [])
          GermanSegment.fromJson(d as Map<String, dynamic>),
      ],
      exact: json["fit"] == "exact",
      greekPage: (json["pg"] as num?)?.toInt(),
      germanPage: (json["pd"] as num?)?.toInt(),
    );
  }
}

class ReadingChapter {
  final int book;
  final int number;
  final String? title;
  final List<ReadingUnit> units;

  const ReadingChapter({
    required this.book,
    required this.number,
    required this.title,
    required this.units,
  });

  /// Stabile Kennung „Buch.Kapitel“ (z. B. „1.7“).
  String get id => "$book.$number";

  BekkerRange get range =>
      BekkerRange(units.first.ref, units.last.range.to);

  Iterable<GreekSentence> get sentences => units.expand((u) => u.greek);

  factory ReadingChapter.fromJson(int book, Map<String, dynamic> json) {
    return ReadingChapter(
      book: book,
      number: (json["n"] as num).toInt(),
      title: json["title"] as String?,
      units: [
        for (final u in json["units"] as List)
          ReadingUnit.fromJson(u as Map<String, dynamic>),
      ],
    );
  }
}

enum EditionNoteKind {
  /// Fußnote unter dem griechischen Text: Abweichung vom Text von Ross,
  /// Lesarten, Tilgungen.
  textCritical("Textkritik"),

  /// „Anmerkungen des Herausgebers“ (Sach- und Übersetzungskommentar).
  editor("Anmerkung"),

  /// Fußnote zur Übersetzung.
  translator("Fußnote zur Übersetzung");

  final String label;

  const EditionNoteKind(this.label);
}

/// Anmerkung der Ausgabe zu einer Stelle. Sie gilt für alle Sätze, deren
/// Zeilenbereich [range] berührt; ein Satz kann so mehrere Anmerkungen
/// haben und eine Anmerkung mehrere Sätze.
class EditionNote {
  final String id;
  final EditionNoteKind kind;
  final BekkerRange? range;

  /// Stellenangabe wie in der Ausgabe („184a10–16“, „Z. 7–10“).
  final String refLabel;
  final String text;

  /// Druckseite der Ausgabe.
  final int? page;

  /// false: Die Stelle ist nur ungefähr bestimmt (z. B. eine seitenbezogene
  /// Zeilenzahl auf einer Seite mit zwei Bekker-Spalten).
  final bool exact;

  /// Abschnitte der Einleitung, auf die die Anmerkung verweist („Einl. 2.3“).
  final List<String> introSections;

  /// Andere Anmerkungen, auf die verwiesen wird („Anm. zu 185a9–12“),
  /// als Anfangsstelle.
  final List<BekkerRef> noteRefs;

  /// Nur Fußnoten zur Übersetzung: der Abschnitt der Seite.
  final String? unitId;

  const EditionNote({
    required this.id,
    required this.kind,
    required this.range,
    required this.refLabel,
    required this.text,
    this.page,
    this.exact = true,
    this.introSections = const [],
    this.noteRefs = const [],
    this.unitId,
  });

  factory EditionNote.editor(Map<String, dynamic> json) {
    final range = BekkerRange.tryParse(
      json["from"] as String?,
      json["to"] as String?,
    );
    return EditionNote(
      id: json["id"] as String,
      kind: EditionNoteKind.editor,
      range: range,
      refLabel: (json["ref"] as String?) ?? range?.label ?? "",
      text: json["text"] as String,
      page: (json["page"] as num?)?.toInt(),
      introSections: List<String>.from((json["intro"] as List?) ?? const []),
      noteRefs: [
        for (final r in (json["notes"] as List?) ?? const [])
          ?BekkerRef.tryParse(r as String),
      ],
    );
  }

  factory EditionNote.textCritical(Map<String, dynamic> json) {
    final range = BekkerRange.tryParse(
      json["from"] as String?,
      json["to"] as String?,
    );
    return EditionNote(
      id: json["id"] as String,
      kind: EditionNoteKind.textCritical,
      range: range,
      refLabel: range?.label ?? "",
      text: json["text"] as String,
      page: (json["page"] as num?)?.toInt(),
      exact: json["fit"] != "approx",
      noteRefs: [
        for (final m in RegExp(
          r'Anm\. zu (\d{3}[ab]\d{1,2})',
        ).allMatches(json["text"] as String))
          ?BekkerRef.tryParse(m[1]),
      ],
    );
  }

  factory EditionNote.translator(Map<String, dynamic> json) {
    return EditionNote(
      id: json["id"] as String,
      kind: EditionNoteKind.translator,
      range: null,
      refLabel: "S. ${json["page"]}",
      text: json["text"] as String,
      page: (json["page"] as num?)?.toInt(),
      unitId: json["unit"] as String?,
      introSections: [
        for (final m in RegExp(
          r'(?:Einleitung|Einl\.)\s+(\d(?:\.\d+)+)',
        ).allMatches(json["text"] as String))
          m[1]!,
      ],
    );
  }
}

class ReadingBook {
  final int number;
  final String? title;
  final List<ReadingChapter> chapters;
  final List<EditionNote> notes;

  const ReadingBook({
    required this.number,
    required this.title,
    required this.chapters,
    required this.notes,
  });

  factory ReadingBook.fromJson(Map<String, dynamic> json) {
    final n = (json["n"] as num).toInt();
    return ReadingBook(
      number: n,
      title: json["title"] as String?,
      chapters: [
        for (final c in json["chapters"] as List)
          ReadingChapter.fromJson(n, c as Map<String, dynamic>),
      ],
      notes: [
        for (final t in (json["textcrit"] as List?) ?? const [])
          EditionNote.textCritical(t as Map<String, dynamic>),
        for (final t in (json["notes"] as List?) ?? const [])
          EditionNote.editor(t as Map<String, dynamic>),
        for (final t in (json["translatorNotes"] as List?) ?? const [])
          EditionNote.translator(t as Map<String, dynamic>),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vorwort, Einleitung, Glossar
// ---------------------------------------------------------------------------

class IntroBlock {
  final String text;

  /// Druckseite (römisch).
  final String? page;

  /// Absatznummer der Einleitung („1.1.1.1“), falls der Absatz eine trägt.
  final String? number;

  const IntroBlock(this.text, {this.page, this.number});
}

class IntroFootnote {
  final int number;
  final String text;

  const IntroFootnote(this.number, this.text);
}

class IntroSection {
  final String id;
  final String title;
  final String? page;
  final List<IntroBlock> blocks;
  final List<IntroFootnote> footnotes;

  const IntroSection({
    required this.id,
    required this.title,
    required this.page,
    required this.blocks,
    required this.footnotes,
  });

  /// Gliederungstiefe (1 = „2“, 2 = „2.1“, 3 = „2.1.1“).
  int get depth => id.split(".").length;

  factory IntroSection.fromJson(Map<String, dynamic> json) {
    return IntroSection(
      id: json["id"] as String,
      title: json["title"] as String,
      page: json["page"] as String?,
      blocks: [
        for (final b in (json["blocks"] as List?) ?? const [])
          IntroBlock(
            (b as Map)["text"] as String,
            page: b["page"] as String?,
            number: b["n"] as String?,
          ),
      ],
      footnotes: [
        for (final f in (json["footnotes"] as List?) ?? const [])
          IntroFootnote(
            ((f as Map)["n"] as num).toInt(),
            f["text"] as String,
          ),
      ],
    );
  }
}

class GlossaryEntry {
  final String id;

  /// Stichwort in der Umschrift der Ausgabe („archê“, „to hou heneka“).
  final String term;
  final String? grammar;

  /// Übersetzungen der Ausgabe (die Wendungen in »…«).
  final List<String> renderings;
  final String text;

  /// Als Fachterminus (t.t.) gekennzeichnet.
  final bool technical;
  final List<String> introSections;
  final List<BekkerRef> noteRefs;

  const GlossaryEntry({
    required this.id,
    required this.term,
    required this.grammar,
    required this.renderings,
    required this.text,
    required this.technical,
    required this.introSections,
    required this.noteRefs,
  });

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    return GlossaryEntry(
      id: json["id"] as String,
      term: json["term"] as String,
      grammar: json["gram"] as String?,
      renderings: List<String>.from((json["de"] as List?) ?? const []),
      text: json["text"] as String,
      technical: json["tt"] == true,
      introSections: List<String>.from((json["intro"] as List?) ?? const []),
      noteRefs: [
        for (final r in (json["notes"] as List?) ?? const [])
          ?BekkerRef.tryParse(r as String),
      ],
    );
  }
}

/// Stelle der Physik, die die Einleitung ausdrücklich zitiert.
class IntroCitation {
  final String section;
  final BekkerRange range;
  final String? page;

  const IntroCitation(this.section, this.range, this.page);
}

class EditionFront {
  final List<String> preface;
  final String? prefacePages;
  final List<IntroSection> intro;
  final List<IntroCitation> citations;
  final List<GlossaryEntry> glossary;
  final List<String> sigla;
  final List<String> bibliography;

  const EditionFront({
    this.preface = const [],
    this.prefacePages,
    this.intro = const [],
    this.citations = const [],
    this.glossary = const [],
    this.sigla = const [],
    this.bibliography = const [],
  });

  static const EditionFront empty = EditionFront();

  bool get isEmpty => preface.isEmpty && intro.isEmpty && glossary.isEmpty;

  IntroSection? section(String id) {
    for (final s in intro) {
      if (s.id == id) return s;
    }
    // Absatznummern („2.2.1.2“) gehören zum übergeordneten Abschnitt.
    final parts = id.split(".");
    for (var n = parts.length - 1; n > 0; n--) {
      final prefix = parts.take(n).join(".");
      for (final s in intro) {
        if (s.id == prefix) return s;
      }
    }
    return null;
  }

  factory EditionFront.fromJson(Map<String, dynamic> json) {
    final preface = json["preface"] as Map<String, dynamic>?;
    return EditionFront(
      preface: List<String>.from(
        (preface?["paragraphs"] as List?) ?? const [],
      ),
      prefacePages: preface?["pages"] as String?,
      intro: [
        for (final s in (json["intro"] as List?) ?? const [])
          IntroSection.fromJson(s as Map<String, dynamic>),
      ],
      citations: [
        for (final c in (json["introCitations"] as List?) ?? const [])
          if (BekkerRange.tryParse(
                (c as Map)["from"] as String?,
                c["to"] as String?,
              )
              case final range?)
            IntroCitation(c["section"] as String, range, c["page"] as String?),
      ],
      glossary: [
        for (final g in (json["glossary"] as List?) ?? const [])
          GlossaryEntry.fromJson(g as Map<String, dynamic>),
      ],
      sigla: List<String>.from((json["sigla"] as List?) ?? const []),
      bibliography: List<String>.from(
        (json["bibliography"] as List?) ?? const [],
      ),
    );
  }
}
