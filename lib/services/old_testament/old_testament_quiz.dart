import 'dart:math';

import '../../algorithms/learning_selector.dart';
import '../../algorithms/ordered_introduction.dart';
import '../../algorithms/review_state.dart';
import '../../algorithms/spaced_repetition.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../models/old_testament/old_testament.dart';

/// Aufgabenarten. Jede hat eigene Lernkarten (`<Inhalt>|<Art>`), damit neue
/// Arten oder Einheiten bestehende Lernstände nicht berühren.
enum OtQuizKind {
  lecture("Fragen zur Vorlesung"),
  term("Fachbegriffe"),
  passage("Bibelstellen"),
  recall("Merklisten"),
  order("Gliederungen ordnen");

  final String label;

  const OtQuizKind(this.label);

  static OtQuizKind? tryParse(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Lernumfang: alle Einheiten oder eine Einheit.
class OtScope {
  /// null: alle Einheiten.
  final String? unitId;

  const OtScope._(this.unitId);

  static const OtScope all = OtScope._(null);

  const OtScope.unit(String id) : this._(id);

  /// Gespeicherte Form: `all` bzw. `unit:unit.01`.
  String get key => unitId == null ? "all" : "unit:$unitId";

  /// Unbekannte oder entfernte Einheiten fallen auf „alle“ zurück.
  static OtScope parse(String? key, OldTestamentData data) {
    if (key != null && key.startsWith("unit:")) {
      final id = key.substring(5);
      if (data.unit(id) != null) return OtScope.unit(id);
    }
    return all;
  }

  String label(OldTestamentData data) {
    final u = unitId == null ? null : data.unit(unitId!);
    return u == null ? "Alle Einheiten" : "${u.label}: ${u.title}";
  }

  @override
  bool operator ==(Object other) => other is OtScope && other.unitId == unitId;

  @override
  int get hashCode => unitId.hashCode;
}

// ==========================
// AUFGABEN
// ==========================

sealed class OtQuestion {
  final OtQuizKind kind;
  final String prompt;

  /// Erklärung nach der Antwort.
  final String explanation;

  /// Einheit und Folien, aus denen die Aufgabe stammt.
  final String unitId;
  final List<int> slides;

  /// Ob die Erklärung (teilweise) eine Ergänzung der App ist.
  final bool supplement;

  final List<String> termIds;

  /// Bibelstelle, die sich aus der Auswertung heraus öffnen lässt.
  final PassageRef? passage;

  const OtQuestion({
    required this.kind,
    required this.prompt,
    required this.explanation,
    required this.unitId,
    required this.slides,
    this.supplement = false,
    this.termIds = const [],
    this.passage,
  });

  String get cardId;
}

class OtChoiceQuestion extends OtQuestion {
  @override
  final String cardId;
  final List<String> options;
  final int correctIndex;

  const OtChoiceQuestion({
    required super.kind,
    required this.cardId,
    required super.prompt,
    required this.options,
    required this.correctIndex,
    required super.explanation,
    required super.unitId,
    required super.slides,
    super.supplement,
    super.termIds,
    super.passage,
  });

  bool isCorrect(int index) => index == correctIndex;

  String get answer => options[correctIndex];
}

/// Aufzählung aus dem Gedächtnis abrufen und selbst bewerten – für Inhalte,
/// die sich nicht zuverlässig automatisch bewerten lassen.
class OtRecallQuestion extends OtQuestion {
  final RecallList list;

  OtRecallQuestion(this.list)
    : super(
        kind: OtQuizKind.recall,
        prompt: list.prompt,
        explanation: list.ordered
            ? "Die Reihenfolge gehört dazu."
            : "Die Reihenfolge spielt keine Rolle.",
        unitId: list.unitId,
        slides: list.slides,
      );

  @override
  String get cardId => OldTestamentQuiz.cardId(list.id, kind);
}

/// Die Punkte einer geordneten Liste (Gliederung, Abfolge) in die
/// Reihenfolge der Folie bringen.
class OtOrderQuestion extends OtQuestion {
  final RecallList list;

  /// In der angezeigten (gemischten) Reihenfolge.
  final List<String> items;

  OtOrderQuestion(this.list, this.items)
    : super(
        kind: OtQuizKind.order,
        prompt:
            "${list.title}: Bringe die Punkte in die Reihenfolge der Folie.",
        explanation:
            "Reihenfolge auf der Folie: "
            "${[for (var i = 0; i < list.items.length; i++) list.full(i)].join(" → ")}",
        unitId: list.unitId,
        slides: list.slides,
      );

  /// Je Punkt, ob er an der richtigen Stelle steht.
  List<bool> evaluate(List<String> answer) => [
    for (var i = 0; i < answer.length; i++) answer[i] == list.items[i],
  ];

  bool isCorrect(List<String> answer) => evaluate(answer).every((x) => x);

  @override
  String get cardId => OldTestamentQuiz.cardId(list.id, kind);
}

/// Möglicher Aufgabeninhalt im Pool; die Frage (mit zufälligen Ablenkern)
/// entsteht erst bei der Auswahl.
class OtCandidate {
  final String cardId;
  final OtQuizKind kind;
  final OtQuestion? Function(Random random) build;

  const OtCandidate({
    required this.cardId,
    required this.kind,
    required this.build,
  });
}

/// Erzeugt Aufgaben aus den Inhalten und wählt sie nach Lernbedarf aus.
///
/// Grundsätze:
/// * Nur Aufgaben, die sich aus den Daten eindeutig bewerten lassen:
///   kuratierte Fragen, Begriffe mit Erklärung, Bibelstellen mit eigener
///   eindeutiger Beschreibung (`clue`), geordnete Listen. Aufzählungen ohne
///   eindeutige Form werden selbst bewertet.
/// * Ablenker stammen aus demselben Bestand; Fragen verraten die Antwort
///   nicht im Fragetext.
/// * Auswahl wie in den übrigen Trainern ([LearningSelector]).
class OldTestamentQuiz {
  final OldTestamentData data;
  final Map<String, LearningCard> cards;
  final LearningSelector selector;
  final Random random;

  OldTestamentQuiz({
    required this.data,
    Map<String, LearningCard>? cards,
    Random? random,
    SpacedRepetition? algorithm,
  }) : cards = cards ?? {},
       random = random ?? Random(),
       selector = LearningSelector(algorithm: algorithm, random: random);

  static String cardId(String itemId, OtQuizKind kind) =>
      "$itemId|${kind.name}";

  /// Zweite Karte eines Begriffs: Begriff zur Erklärung finden.
  static String termNameCardId(String termId) => "$termId|name";

  bool isDifficult(String id) => isDifficultCard(cards[id]);

  List<LectureUnit> unitsIn(OtScope scope) =>
      scope.unitId == null ? data.units : [?data.unit(scope.unitId!)];

  /// Mindestzahl eindeutiger Ablenker für automatisch erzeugte Fragen.
  static const int minDistractors = 2;

  /// Alle Aufgabeninhalte im Umfang für die gewählten Arten.
  List<OtCandidate> candidates(OtScope scope, Set<OtQuizKind> kinds) {
    final result = <OtCandidate>[];
    final seenTerms = <String>{};

    for (final u in unitsIn(scope)) {
      if (kinds.contains(OtQuizKind.lecture)) {
        for (final q in u.questions) {
          result.add(
            OtCandidate(
              cardId: cardId(q.id, OtQuizKind.lecture),
              kind: OtQuizKind.lecture,
              build: (r) => _curated(q, r),
            ),
          );
        }
      }

      if (kinds.contains(OtQuizKind.term)) {
        for (final m in u.terms) {
          final t = data.term(m.termId);
          // Ein Begriff mehrerer Einheiten hat nur eine Karte.
          if (t == null || !seenTerms.add(t.id)) continue;

          result.add(
            OtCandidate(
              cardId: cardId(t.id, OtQuizKind.term),
              kind: OtQuizKind.term,
              build: (r) => _meaning(t, m, u, r),
            ),
          );
          if (!_revealsName(t)) {
            result.add(
              OtCandidate(
                cardId: termNameCardId(t.id),
                kind: OtQuizKind.term,
                build: (r) => _termByMeaning(t, m, u, r),
              ),
            );
          }
        }
      }

      if (kinds.contains(OtQuizKind.passage)) {
        for (final p in u.passages) {
          if (p.clue == null) continue;
          result.add(
            OtCandidate(
              cardId: cardId(p.id, OtQuizKind.passage),
              kind: OtQuizKind.passage,
              build: (r) => _passage(p, u, r),
            ),
          );
        }
      }

      for (final l in u.lists) {
        if (kinds.contains(OtQuizKind.recall)) {
          result.add(
            OtCandidate(
              cardId: cardId(l.id, OtQuizKind.recall),
              kind: OtQuizKind.recall,
              build: (_) => OtRecallQuestion(l),
            ),
          );
        }
        if (kinds.contains(OtQuizKind.order) && _orderable(l)) {
          result.add(
            OtCandidate(
              cardId: cardId(l.id, OtQuizKind.order),
              kind: OtQuizKind.order,
              build: (r) => _order(l, r),
            ),
          );
        }
      }
    }

    // Nur Inhalte, für die sich auch eine Aufgabe bilden lässt (genug
    // Ablenker); so zeigt der Fortschritt keine unerreichbaren Karten.
    final probe = Random(0);
    result.removeWhere((c) => c.build(probe) == null);

    return result;
  }

  /// Nächste Aufgabe; null, wenn der Umfang keine Aufgabe hergibt.
  /// [inOrder]: neue Inhalte nur in Lehrreihenfolge ([orderedIntroduction]);
  /// [candidates] liefert die Inhalte bereits nach Einheiten geordnet.
  OtQuestion? next(
    OtScope scope,
    Set<OtQuizKind> kinds, {
    bool onlyDifficult = false,
    bool inOrder = false,
  }) {
    var pool = candidates(scope, kinds);

    if (onlyDifficult) {
      pool = pool.where((c) => isDifficult(c.cardId)).toList();
    } else if (inOrder) {
      // Die Liste ist schon in Lehrreihenfolge (Einheit für Einheit, ein
      // Begriff bei seiner ersten Einheit).
      final position = {for (var i = 0; i < pool.length; i++) pool[i]: i};
      pool = orderedIntroduction(
        pool,
        idOf: (c) => c.cardId,
        cards: cards,
        positionOf: (c) => position[c]!,
      );
    }

    while (pool.isNotEmpty) {
      final pick = selector.select(
        candidates: pool,
        idOf: (c) => c.cardId,
        cards: cards,
      );

      if (pick == null) return null;

      final question = pick.build(random);
      if (question != null) return question;

      pool = [...pool]..remove(pick);
    }

    return null;
  }

  /// Verbucht eine Antwort und liefert die geänderte Karte.
  LearningCard record(OtQuestion question, bool correct) {
    final card = cards.putIfAbsent(
      question.cardId,
      () => LearningCard(id: question.cardId),
    );
    selector.algorithm.answer(card, correct);
    return card;
  }

  // ==========================
  // BAUSTEINE
  // ==========================

  /// Mischt richtige Antwort und Ablenker; null bei zu wenigen Ablenkern.
  ({List<String> options, int correct})? _mix(
    String answer,
    Iterable<String> distractors,
    Random r, {
    int count = 3,
    int minimum = minDistractors,
  }) {
    final pool = {
      for (final d in distractors)
        if (d.trim().toLowerCase() != answer.trim().toLowerCase()) d,
    }.toList()..shuffle(r);

    if (pool.length < minimum) return null;

    final options = [answer, ...pool.take(count)]..shuffle(r);
    return (options: options, correct: options.indexOf(answer));
  }

  OtQuestion? _curated(CuratedQuestion q, Random r) {
    final mix = _mix(q.answer, q.distractors, r, count: q.distractors.length);
    if (mix == null) return null;

    return OtChoiceQuestion(
      kind: OtQuizKind.lecture,
      cardId: cardId(q.id, OtQuizKind.lecture),
      prompt: q.prompt,
      options: mix.options,
      correctIndex: mix.correct,
      explanation: q.explanation,
      unitId: q.unitId,
      slides: q.slides,
      termIds: q.termIds,
    );
  }

  List<String> _names(Term t) => [t.name, ?t.transliteration, ...t.aliases];

  /// Ersetzt die Namen von [t] in [text] durch „…“.
  String _mask(String text, Term t) {
    final names = _names(t)..sort((a, b) => b.length.compareTo(a.length));

    for (final n in names) {
      if (n.length < 3) continue;
      text = text.replaceAll(
        RegExp(RegExp.escape(n), caseSensitive: false),
        "…",
      );
    }
    return text;
  }

  /// Erklärung ohne den eigenen Begriff.
  String _masked(Term t) => _mask(t.definition, t);

  bool _revealsName(Term t) {
    final text = t.definition.toLowerCase();
    return _names(t).any((n) => n.length > 2 && text.contains(n.toLowerCase()));
  }

  /// Mögliche Ablenker: alle anderen Begriffe außer verwechselbaren.
  Iterable<Term> _otherTerms(Term t) =>
      data.terms.where((o) => o.id != t.id && !data.confusable(t, o));

  String _termExplanation(Term t, TermMention m) {
    return [
      "${t.display}: ${t.definition}",
      if (m.text != null && m.text != t.definition) "Folie: „${m.text}“",
    ].join("\n\n");
  }

  OtQuestion? _meaning(Term t, TermMention m, LectureUnit u, Random r) {
    // Auch Ablenker nennen den gefragten Begriff nicht (sonst wirken sie
    // richtig, z. B. „… des jüdischen Kanons“ bei „Kanon“).
    final others = _otherTerms(t).map((o) => _mask(_masked(o), t));

    final mix = _mix(_masked(t), others, r);
    if (mix == null) return null;

    return OtChoiceQuestion(
      kind: OtQuizKind.term,
      cardId: cardId(t.id, OtQuizKind.term),
      prompt: "Was bedeutet „${t.display}“?",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: _termExplanation(t, m),
      unitId: u.id,
      slides: m.slides,
      supplement: !t.fromSlides,
      termIds: [t.id],
    );
  }

  OtQuestion? _termByMeaning(Term t, TermMention m, LectureUnit u, Random r) {
    final others = _otherTerms(t).map((o) => o.display);

    final mix = _mix(t.display, others, r);
    if (mix == null) return null;

    return OtChoiceQuestion(
      kind: OtQuizKind.term,
      cardId: termNameCardId(t.id),
      prompt: "Welcher Begriff ist gemeint?\n${t.definition}",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: _termExplanation(t, m),
      unitId: u.id,
      slides: m.slides,
      supplement: !t.fromSlides,
      termIds: [t.id],
    );
  }

  OtQuestion? _passage(PassageRef p, LectureUnit u, Random r) {
    final others = [
      for (final o in data.units)
        for (final q in o.passages)
          if (q.id != p.id) q.label,
    ];

    final mix = _mix(p.label, others, r);
    if (mix == null) return null;

    return OtChoiceQuestion(
      kind: OtQuizKind.passage,
      cardId: cardId(p.id, OtQuizKind.passage),
      prompt: "Welche Bibelstelle ist gemeint?\n${p.clue}",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: "${p.label}: ${p.context}",
      unitId: u.id,
      slides: p.slides,
      passage: p,
    );
  }

  /// Geordnete Listen mit drei bis sieben Punkten lassen sich ordnen.
  static bool _orderable(RecallList l) =>
      l.ordered && l.items.length >= 3 && l.items.length <= 7;

  OtQuestion? _order(RecallList l, Random r) {
    final items = [...l.items];
    // Nie schon richtig sortiert anzeigen.
    for (var i = 0; i < 10 && _same(items, l.items); i++) {
      items.shuffle(r);
    }
    if (_same(items, l.items)) return null;
    return OtOrderQuestion(l, items);
  }

  static bool _same(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
