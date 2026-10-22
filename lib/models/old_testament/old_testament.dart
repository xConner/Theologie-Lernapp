/// Statische Inhalte des Lernbereichs „Altes Testament“ und der Grundlagen
/// der Bibelkunde (Übung „Bibelkunde Altes Testament“).
///
/// Alle Inhalte stehen in `assets/old_testament/` und werden über stabile
/// IDs verknüpft (siehe `docs/old-testament.md`). Jede Aussage gehört zu
/// genau einer Einheit (Vorlesung) bzw. Sitzung (Übung) und nennt ihre
/// Folien. Beide Veranstaltungen teilen Begriffe, geteilte Fragen und den
/// Lernstand (`OldTestamentStore`), der getrennt von den Inhalten liegt.
///
/// Drei Ebenen werden überall unterschieden:
/// * Folieninhalt: Abschrift ([UnitSlide.text]) und alles, was nur
///   wiedergibt, was auf den Folien steht (Kernpunkte, Gliederung,
///   Bibelstellen, Literatur).
/// * Didaktische Zusammenfassung: dieselben Aussagen, für das Lernen
///   geordnet und gekürzt – mit Folienangabe.
/// * Ergänzung: Erklärungen der App, die nicht auf den Folien stehen
///   (Felder `supplement`, Begriffserklärungen mit `fromSlides: false`).
library;

/// Kennzeichnung einer Aussage, die die Folie nicht eindeutig macht. Sie
/// wird angezeigt und nie abgefragt.
class Ambiguity {
  final String text;

  const Ambiguity(this.text);
}

class UnitSlide {
  final int number;
  final String title;

  /// Asset-Pfad des Folienbilds (Originalansicht).
  final String? image;

  /// Vollständiger Text der Folie (Abschrift).
  final String text;

  /// Auf der Folie hervorgehobene Stellen.
  final List<String> highlights;

  /// Beschreibung von Abbildungen, Tabellen oder Schaubildern, soweit sie
  /// nicht als Text in [text] stehen.
  final String? figure;

  const UnitSlide({
    required this.number,
    required this.title,
    this.image,
    required this.text,
    this.highlights = const [],
    this.figure,
  });
}

/// Eine zentrale Aussage der Folien.
class KeyPoint {
  final String text;
  final List<int> slides;

  const KeyPoint({required this.text, required this.slides});
}

/// Abschnitt der Gliederung: [points] geben die Folien wieder,
/// [supplement] ist eine gekennzeichnete Ergänzung der App, [unclear]
/// kennzeichnet Mehrdeutiges.
class UnitSection {
  final String title;
  final List<int> slides;
  final List<String> points;
  final String? supplement;
  final Ambiguity? unclear;

  const UnitSection({
    required this.title,
    required this.slides,
    required this.points,
    this.supplement,
    this.unclear,
  });
}

/// Fachbegriff. Ein Begriff hat einen Eintrag, auch wenn mehrere Einheiten
/// ihn behandeln; was eine Einheit über ihn sagt, steht in ihren
/// [TermMention]s.
class Term {
  final String id;
  final String name;

  /// Hebräische Schreibung und Umschrift, nur wenn die Folie sie nennt.
  final String? hebrew;
  final String? transliteration;

  final List<String> aliases;

  /// Kurze Erklärung. [fromSlides] sagt, ob sie die Folien wiedergibt oder
  /// eine Ergänzung der App ist.
  final String definition;
  final bool fromSlides;

  /// Weitere Erläuterung der App (Ergänzung).
  final String? supplement;

  /// Begriffe, deren Erklärung sich mit dieser überschneidet (z. B. Tora und
  /// Pentateuch). Sie sind gegenseitig nie Ablenker.
  final List<String> confusableIds;

  const Term({
    required this.id,
    required this.name,
    this.hebrew,
    this.transliteration,
    this.aliases = const [],
    required this.definition,
    required this.fromSlides,
    this.supplement,
    this.confusableIds = const [],
  });

  /// Name mit Umschrift bzw. hebräischer Schreibung, soweit vorhanden.
  String get display {
    final extra = [?transliteration, ?hebrew];
    return extra.isEmpty ? name : "$name (${extra.join(", ")})";
  }
}

/// Was eine Einheit über einen Begriff sagt.
class TermMention {
  final String termId;
  final List<int> slides;

  /// Wortlaut oder Wiedergabe der Folie; null, wenn der Begriff nur
  /// genannt wird.
  final String? text;

  const TermMention({required this.termId, required this.slides, this.text});
}

/// Bibelstelle auf den Folien.
class PassageRef {
  final String id;

  /// Angabe wie auf der Folie („Gen 12,1–3“).
  final String label;

  /// Aufschlagbare Form für den Bibel-Reader, falls [label] sich nicht
  /// lesen lässt (z. B. Halbverse „2,4a“). null: [label] wird gelesen.
  final String? open;

  /// Wofür die Folie die Stelle anführt.
  final String context;

  /// Eindeutige Beschreibung für die Abfrage; ohne sie wird die Stelle nicht
  /// abgefragt (der Kontext allein ist oft nicht eindeutig).
  final String? clue;

  final List<int> slides;

  /// Perikopen der Perikopenliste (`assets/perikopen.json`), die die Stelle
  /// umfasst oder anschneidet, als `Buch|ID|Kapitel,Vers` wie
  /// `BookPericope.key`. Die Folie kann gröber oder feiner teilen als die
  /// Liste; die Liste bleibt unverändert, die Zuordnung verweist nur.
  final List<String> pericopeKeys;

  const PassageRef({
    required this.id,
    required this.label,
    this.open,
    required this.context,
    this.clue,
    required this.slides,
    this.pericopeKeys = const [],
  });

  String get openText => open ?? label;
}

/// Historischer, literarischer oder theologischer Zusammenhang.
class Connection {
  final String text;
  final List<int> slides;

  /// true: Verknüpfung der App, nicht von den Folien.
  final bool supplement;

  const Connection({
    required this.text,
    this.slides = const [],
    this.supplement = false,
  });
}

/// Literatur- oder Quellenangabe der Folien (wörtlich).
class LiteratureRef {
  final String text;
  final List<int> slides;

  const LiteratureRef({required this.text, required this.slides});
}

/// Aufzählung oder Gliederung zum Abrufen aus dem Gedächtnis. Geordnete
/// Listen lassen sich zusätzlich in die richtige Reihenfolge bringen.
class RecallList {
  final String id;
  final String unitId;
  final String title;
  final String prompt;
  final List<int> slides;
  final List<String> items;

  /// Angaben zu den Punkten (z. B. Jahreszahlen), gleich lang wie [items]
  /// oder leer. Sie stehen in der Lösung, nicht in der Ordnen-Aufgabe.
  final List<String> details;

  final bool ordered;

  const RecallList({
    required this.id,
    required this.unitId,
    required this.title,
    required this.prompt,
    required this.slides,
    required this.items,
    this.details = const [],
    this.ordered = false,
  });

  /// Punkt mit Angabe, falls vorhanden.
  String full(int index) =>
      details.isEmpty ? items[index] : "${items[index]} (${details[index]})";
}

/// Von Hand formulierte Auswahlfrage mit Erklärung und Folienangabe.
class CuratedQuestion {
  final String id;
  final String unitId;
  final String prompt;
  final String answer;
  final List<String> distractors;
  final String explanation;
  final List<int> slides;
  final List<String> termIds;

  const CuratedQuestion({
    required this.id,
    required this.unitId,
    required this.prompt,
    required this.answer,
    required this.distractors,
    required this.explanation,
    required this.slides,
    this.termIds = const [],
  });
}

/// Veranstaltung, zu der eine Einheit gehört. Beide nutzen dieselben
/// Begriffe, Aufgaben und Lernkarten; ein Inhalt steht nur einmal in den
/// Daten.
enum OtCourseId {
  /// Vorlesung „Einführung in das Alte Testament“: Einheiten `unit.NN`.
  lecture(
    unitPrefix: "unit",
    shortPrefix: "u",
    unitName: "Einheit",
    shortLabel: "Vorlesung AT",
  ),

  /// Übung „Bibelkunde Altes Testament“ (Bereich Bibelkunde): Sitzungen
  /// `bk.NN`.
  bibelkunde(
    unitPrefix: "bk",
    shortPrefix: "bk",
    unitName: "Sitzung",
    shortLabel: "Bibelkunde AT",
  );

  /// ID einer Einheit: `<unitPrefix>.NN`.
  final String unitPrefix;

  /// Teil der Inhalts-IDs: `q.<shortPrefix>NN.…`.
  final String shortPrefix;

  /// „Einheit“ bzw. „Sitzung“.
  final String unitName;

  /// Kurzname für Fundstellen aus der jeweils anderen Veranstaltung.
  final String shortLabel;

  const OtCourseId({
    required this.unitPrefix,
    required this.shortPrefix,
    required this.unitName,
    required this.shortLabel,
  });

  static OtCourseId? tryParse(Object? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// Eine Vorlesungseinheit bzw. Sitzung der Übung: das Material einer
/// hochgeladenen Foliendatei.
class LectureUnit {
  final String id;
  final OtCourseId course;
  final int number;
  final String title;

  /// Einordnung, z. B. „Folien 1–12 der Sitzung vom …“ – damit ein Teil
  /// einer Vorlesung nicht als vollständige Vorlesung erscheint.
  final String? scope;

  /// Name der Originaldatei.
  final String? file;

  final List<UnitSlide> slides;
  final List<KeyPoint> keyPoints;
  final List<UnitSection> sections;
  final List<TermMention> terms;
  final List<PassageRef> passages;
  final List<Connection> connections;
  final List<LiteratureRef> literature;
  final List<RecallList> lists;
  final List<CuratedQuestion> questions;

  /// Einheiten, die dasselbe Thema behandeln (in beide Richtungen, siehe
  /// [OldTestamentData.relatedUnitsOf]).
  final List<String> relatedUnitIds;

  /// IDs von Fragen, Merklisten und Bibelstellen einer anderen Einheit, die
  /// diese Einheit ebenso behandelt. Sie werden nicht kopiert, sondern
  /// mitgelernt: gleiche Lernkarte, Fundstelle bleibt die Herkunft.
  final List<String> sharedIds;

  const LectureUnit({
    required this.id,
    this.course = OtCourseId.lecture,
    required this.number,
    required this.title,
    this.scope,
    this.file,
    this.slides = const [],
    this.keyPoints = const [],
    this.sections = const [],
    this.terms = const [],
    this.passages = const [],
    this.connections = const [],
    this.literature = const [],
    this.lists = const [],
    this.questions = const [],
    this.relatedUnitIds = const [],
    this.sharedIds = const [],
  });

  String get label => "${course.unitName} $number";

  bool get hasLearningContent =>
      sharedIds.isNotEmpty ||
      questions.isNotEmpty ||
      lists.isNotEmpty ||
      terms.isNotEmpty ||
      passages.any((p) => p.clue != null);

  UnitSlide? slide(int number) {
    for (final s in slides) {
      if (s.number == number) return s;
    }
    return null;
  }

  TermMention? mentionOf(String termId) {
    for (final m in terms) {
      if (m.termId == termId) return m;
    }
    return null;
  }
}

class OldTestamentCourse {
  final String title;
  final String? lecturer;
  final String? semester;

  const OldTestamentCourse({required this.title, this.lecturer, this.semester});

  String get subtitle => [title, ?lecturer, ?semester].join(" · ");
}

/// Alle Inhalte mit Indizes, gesehen aus einer Veranstaltung ([courseId]).
///
/// [units] und [terms] enthalten nur, was zu dieser Veranstaltung gehört;
/// Nachschlagen ([unit], [term], [question] …), Begriffsherkunft und
/// verwandte Einheiten reichen über beide Veranstaltungen, damit geteilte
/// Inhalte und Verweise funktionieren. [forCourse] wechselt die Sicht.
class OldTestamentData {
  final OtCourseId courseId;
  final Map<OtCourseId, OldTestamentCourse> courses;

  /// Alle Begriffe und Einheiten beider Veranstaltungen.
  final List<Term> allTerms;
  final List<LectureUnit> allUnits;

  late final List<LectureUnit> units = [
    for (final u in allUnits)
      if (u.course == courseId) u,
  ];

  /// Begriffe, die eine Einheit dieser Veranstaltung nennt.
  late final List<Term> terms = [
    for (final t in allTerms)
      if (units.any((u) => u.mentionOf(t.id) != null)) t,
  ];

  late final Map<String, Term> _terms = {for (final t in allTerms) t.id: t};
  late final Map<String, LectureUnit> _units = {
    for (final u in allUnits) u.id: u,
  };
  late final Map<String, CuratedQuestion> _questions = {
    for (final u in allUnits)
      for (final q in u.questions) q.id: q,
  };
  late final Map<String, RecallList> _lists = {
    for (final u in allUnits)
      for (final l in u.lists) l.id: l,
  };
  late final Map<String, (LectureUnit, PassageRef)> _passages = {
    for (final u in allUnits)
      for (final p in u.passages) p.id: (u, p),
  };

  OldTestamentData({
    required OldTestamentCourse course,
    required List<Term> terms,
    required List<LectureUnit> units,
    Map<OtCourseId, OldTestamentCourse> otherCourses = const {},
  }) : this._(
         courseId: OtCourseId.lecture,
         courses: {...otherCourses, OtCourseId.lecture: course},
         allTerms: terms,
         allUnits: units,
       );

  OldTestamentData._({
    required this.courseId,
    required this.courses,
    required this.allTerms,
    required this.allUnits,
  });

  /// Dieselben Inhalte aus Sicht der Veranstaltung [id].
  OldTestamentData forCourse(OtCourseId id) => id == courseId
      ? this
      : OldTestamentData._(
          courseId: id,
          courses: courses,
          allTerms: allTerms,
          allUnits: allUnits,
        );

  /// Die Veranstaltung dieser Sicht.
  OldTestamentCourse get course =>
      courses[courseId] ?? courses[OtCourseId.lecture]!;

  OldTestamentCourse courseOf(LectureUnit unit) =>
      courses[unit.course] ?? course;

  Term? term(String id) => _terms[id];
  LectureUnit? unit(String id) => _units[id];
  CuratedQuestion? question(String id) => _questions[id];
  RecallList? list(String id) => _lists[id];
  PassageRef? passage(String id) => _passages[id]?.$2;

  /// Einheit, zu der eine Bibelstelle gehört.
  LectureUnit? unitOfPassage(String id) => _passages[id]?.$1;

  /// Ob es zu der ID eine Frage, Merkliste oder Bibelstelle gibt.
  bool isShareable(String id) =>
      _questions.containsKey(id) ||
      _lists.containsKey(id) ||
      _passages.containsKey(id);

  /// Einheiten, die einen Begriff behandeln (beide Veranstaltungen).
  List<LectureUnit> unitsOfTerm(String termId) => [
    for (final u in allUnits)
      if (u.mentionOf(termId) != null) u,
  ];

  /// Begriffe einer Einheit in der Reihenfolge der Folien.
  List<Term> termsOfUnit(String unitId) => [
    for (final m in unit(unitId)?.terms ?? const <TermMention>[])
      ?term(m.termId),
  ];

  /// Ob [a] und [b] nicht als Ablenker füreinander taugen.
  bool confusable(Term a, Term b) =>
      a.confusableIds.contains(b.id) || b.confusableIds.contains(a.id);

  /// Alle Begriffe alphabetisch (für das Glossar).
  List<Term> get sortedTerms =>
      [...terms]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Verwandte Einheiten in beide Richtungen, auch aus der anderen
  /// Veranstaltung.
  List<LectureUnit> relatedUnitsOf(String unitId) {
    final ids = <String>{
      ...?unit(unitId)?.relatedUnitIds,
      for (final u in allUnits)
        if (u.relatedUnitIds.contains(unitId)) u.id,
    }..remove(unitId);

    return [
      for (final u in allUnits)
        if (ids.contains(u.id)) u,
    ];
  }

  /// Bezeichnung einer Einheit; aus der anderen Veranstaltung mit deren
  /// Kurznamen („Bibelkunde AT · Sitzung 1“).
  String unitLabel(LectureUnit u) =>
      u.course == courseId ? u.label : "${u.course.shortLabel} · ${u.label}";

  /// Fundstelle für die Anzeige: „Einheit 1, Folie 3“.
  String sourceLabel(String unitId, List<int> slides) {
    final u = unit(unitId);
    return [
      if (u != null) unitLabel(u),
      if (slides.isNotEmpty) slidesLabel(slides),
    ].join(", ");
  }
}

String slidesLabel(List<int> slides) {
  if (slides.isEmpty) return "";
  return slides.length == 1
      ? "Folie ${slides.single}"
      : "Folien ${slides.join(", ")}";
}
