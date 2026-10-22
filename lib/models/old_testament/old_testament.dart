/// Statische Inhalte des Lernbereichs „Altes Testament“.
///
/// Alle Inhalte stehen in `assets/old_testament/` und werden über stabile
/// IDs verknüpft (siehe `docs/old-testament.md`). Jede Aussage gehört zu
/// genau einer Vorlesungseinheit und nennt ihre Folien. Der Lernstand des
/// Nutzers liegt getrennt davon (`OldTestamentStore`).
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

  const PassageRef({
    required this.id,
    required this.label,
    this.open,
    required this.context,
    this.clue,
    required this.slides,
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

/// Eine Vorlesungseinheit: das Material einer hochgeladenen Foliendatei.
class LectureUnit {
  final String id;
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

  const LectureUnit({
    required this.id,
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
  });

  String get label => "Einheit $number";

  bool get hasLearningContent =>
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

/// Alle Inhalte mit Indizes.
class OldTestamentData {
  final OldTestamentCourse course;
  final List<Term> terms;
  final List<LectureUnit> units;

  late final Map<String, Term> _terms = {for (final t in terms) t.id: t};
  late final Map<String, LectureUnit> _units = {for (final u in units) u.id: u};

  OldTestamentData({
    required this.course,
    required this.terms,
    required this.units,
  });

  Term? term(String id) => _terms[id];
  LectureUnit? unit(String id) => _units[id];

  /// Einheiten, die einen Begriff behandeln.
  List<LectureUnit> unitsOfTerm(String termId) => [
    for (final u in units)
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

  /// Verwandte Einheiten in beide Richtungen.
  List<LectureUnit> relatedUnitsOf(String unitId) {
    final ids = <String>{
      ...?unit(unitId)?.relatedUnitIds,
      for (final u in units)
        if (u.relatedUnitIds.contains(unitId)) u.id,
    }..remove(unitId);

    return [
      for (final u in units)
        if (ids.contains(u.id)) u,
    ];
  }

  /// Fundstelle für die Anzeige: „Einheit 1, Folie 3“.
  String sourceLabel(String unitId, List<int> slides) {
    final u = unit(unitId);
    return [?u?.label, if (slides.isNotEmpty) slidesLabel(slides)].join(", ");
  }
}

String slidesLabel(List<int> slides) {
  if (slides.isEmpty) return "";
  return slides.length == 1
      ? "Folie ${slides.single}"
      : "Folien ${slides.join(", ")}";
}
