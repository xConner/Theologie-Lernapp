import 'dart:math';

import '../../algorithms/learning_selector.dart';
import '../../algorithms/spaced_repetition.dart';
import '../../models/church_history/church_history.dart';
import '../../models/greek/vocabulary/learning_card.dart';

/// Aufgabenarten. Jede Art fragt eine eigene Fähigkeit ab und hat eigene
/// Lernkarten (`<Inhalt>|<Art>`), damit z. B. eine sichere Datierung nicht
/// verdeckt, dass die Bedeutung eines Ereignisses noch unsicher ist.
enum QuizKind {
  lecture("Fragen zur Vorlesung"),
  recall("Merklisten"),
  person("Personen"),
  term("Begriffe und Quellen"),
  epoch("Epochen"),
  date("Datierungen"),
  order("Reihenfolge");

  final String label;

  const QuizKind(this.label);

  static QuizKind? tryParse(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Die beiden Lernmodi des Bereichs.
enum QuizMode {
  knowledge("Wissensquiz", {
    QuizKind.lecture,
    QuizKind.recall,
    QuizKind.person,
    QuizKind.term,
    QuizKind.epoch,
  }),
  chronology("Chronologietrainer", {
    QuizKind.order,
    QuizKind.date,
    QuizKind.epoch,
  });

  final String label;

  /// Aufgabenarten, die in diesem Modus wählbar sind.
  final Set<QuizKind> kinds;

  const QuizMode(this.label, this.kinds);
}

enum ScopeKind { all, lectures, lecture, epoch, theme }

/// Lernumfang: alles, alle Vorlesungen, eine Vorlesung, eine Epoche oder ein
/// Thema.
class LearningScope {
  final ScopeKind kind;
  final String? id;

  const LearningScope._(this.kind, [this.id]);

  static const LearningScope all = LearningScope._(ScopeKind.all);
  static const LearningScope allLectures = LearningScope._(ScopeKind.lectures);

  const LearningScope.lecture(String lectureId)
    : this._(ScopeKind.lecture, lectureId);
  const LearningScope.epoch(String epochId) : this._(ScopeKind.epoch, epochId);
  const LearningScope.theme(String themeId) : this._(ScopeKind.theme, themeId);

  /// Gespeicherte Form, z. B. `lecture:lecture.01`.
  String get key => id == null ? kind.name : "${kind.name}:$id";

  static LearningScope parse(String? key, ChurchHistoryData data) {
    if (key == null) return all;

    final split = key.indexOf(":");
    final kindName = split < 0 ? key : key.substring(0, split);
    final id = split < 0 ? null : key.substring(split + 1);

    switch (kindName) {
      case "lectures":
        return allLectures;
      case "lecture" when id != null && data.lecture(id) != null:
        return LearningScope.lecture(id);
      case "epoch" when id != null && data.epoch(id) != null:
        return LearningScope.epoch(id);
      case "theme" when id != null && data.theme(id) != null:
        return LearningScope.theme(id);
    }

    return all;
  }

  String label(ChurchHistoryData data) {
    switch (kind) {
      case ScopeKind.all:
        return "Alle Inhalte";
      case ScopeKind.lectures:
        return "Alle bisherigen Vorlesungen";
      case ScopeKind.lecture:
        final l = data.lecture(id!);
        return l == null ? "Vorlesung" : "${l.label}: ${l.title}";
      case ScopeKind.epoch:
        return data.epoch(id!)?.title ?? "Epoche";
      case ScopeKind.theme:
        return data.theme(id!)?.title ?? "Thema";
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LearningScope && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

// ==========================
// AUFGABEN
// ==========================

sealed class QuizQuestion {
  final QuizKind kind;
  final String prompt;

  /// Erklärung nach der Antwort.
  final String explanation;

  /// Bezug zur Vorlesung (null: Ergänzung ohne Folienbezug).
  final String? lectureId;
  final List<int> slides;

  /// Einträge, die sich aus der Auswertung heraus öffnen lassen.
  final List<String> entryIds;

  const QuizQuestion({
    required this.kind,
    required this.prompt,
    required this.explanation,
    this.lectureId,
    this.slides = const [],
    this.entryIds = const [],
  });

  /// Lernkarten, deren Stand eine Antwort verändert.
  List<String> get cardIds;
}

class ChoiceQuestion extends QuizQuestion {
  final String cardId;
  final List<String> options;
  final int correctIndex;

  const ChoiceQuestion({
    required super.kind,
    required this.cardId,
    required super.prompt,
    required this.options,
    required this.correctIndex,
    required super.explanation,
    super.lectureId,
    super.slides,
    super.entryIds,
  });

  bool isCorrect(int index) => index == correctIndex;

  String get answer => options[correctIndex];

  @override
  List<String> get cardIds => [cardId];
}

/// Ereignisse in die zeitliche Reihenfolge bringen. Die Ereignisse sind so
/// gewählt, dass sich ihre Datierungen auch mit Unschärfe nicht überschneiden
/// – die richtige Reihenfolge ist eindeutig.
class OrderQuestion extends QuizQuestion {
  /// In der angezeigten (gemischten) Reihenfolge.
  final List<HistoryEntry> items;

  const OrderQuestion({
    required super.prompt,
    required this.items,
    required super.explanation,
    super.entryIds,
  }) : super(kind: QuizKind.order);

  List<HistoryEntry> get correctOrder =>
      [...items]..sort((a, b) => a.dating!.from.compareTo(b.dating!.from));

  /// Je Ereignis, ob es an der richtigen Stelle steht.
  List<bool> evaluate(List<HistoryEntry> answer) {
    final correct = correctOrder;
    return [for (var i = 0; i < answer.length; i++) answer[i] == correct[i]];
  }

  bool isCorrect(List<HistoryEntry> answer) => evaluate(answer).every((x) => x);

  @override
  List<String> get cardIds => [
    for (final e in items) ChurchHistoryQuiz.cardId(e.id, QuizKind.order),
  ];
}

/// Merkliste aus dem Gedächtnis abrufen und selbst bewerten.
class RecallQuestion extends QuizQuestion {
  final RecallList list;

  RecallQuestion(this.list)
    : super(
        kind: QuizKind.recall,
        prompt: list.prompt,
        explanation: list.ordered
            ? "Die Reihenfolge gehört dazu."
            : "Die Reihenfolge spielt keine Rolle.",
        lectureId: list.lectureId,
        slides: list.slides,
      );

  @override
  List<String> get cardIds => [ChurchHistoryQuiz.cardId(list.id, kind)];
}

/// Ein möglicher Aufgabeninhalt im Pool: Lernkarte und Bauanleitung. Die
/// Frage selbst (mit zufälligen Ablenkern) entsteht erst bei der Auswahl.
class QuizCandidate {
  final String cardId;
  final QuizKind kind;
  final QuizQuestion? Function(Random random) build;

  const QuizCandidate({
    required this.cardId,
    required this.kind,
    required this.build,
  });
}

/// Erzeugt Aufgaben aus den Inhalten und wählt sie nach Lernbedarf aus.
///
/// Grundsätze:
/// * Ablenker stammen aus demselben Bestand und sind eindeutig falsch:
///   Datierungen überschneiden sich nicht (auch nicht mit ihrer Unschärfe),
///   verknüpfte Personen sind nie Ablenker, Begriffe verraten sich nicht
///   über ihre Erklärung.
/// * Die Auswahl gewichtet wie die übrigen Trainer ([LearningSelector]):
///   Lernbedarf × Fälligkeit, neue Inhalte begrenzt, kurze Sperre für
///   gerade gestellte Fragen.
class ChurchHistoryQuiz {
  final ChurchHistoryData data;
  final Map<String, LearningCard> cards;
  final LearningSelector selector;
  final Random random;

  ChurchHistoryQuiz({
    required this.data,
    Map<String, LearningCard>? cards,
    Random? random,
    SpacedRepetition? algorithm,
  }) : cards = cards ?? {},
       random = random ?? Random(),
       selector = LearningSelector(algorithm: algorithm, random: random);

  static String cardId(String itemId, QuizKind kind) => "$itemId|${kind.name}";

  /// Ab dieser Schwierigkeit gilt ein Inhalt als „schwierig“ (mehr Fehler
  /// als sichere Antworten in letzter Zeit). Eine einzelne falsche Antwort
  /// hebt sie von 5 auf 6; richtige Antworten senken sie wieder.
  static const double difficultThreshold = 5.5;

  bool isDifficult(String id) {
    final card = cards[id];
    return card != null && card.difficulty >= difficultThreshold;
  }

  // ==========================
  // UMFANG
  // ==========================

  List<Lecture> lecturesIn(LearningScope scope) {
    switch (scope.kind) {
      case ScopeKind.all || ScopeKind.lectures:
        return data.lectures;
      case ScopeKind.lecture:
        return [?data.lecture(scope.id!)];
      case ScopeKind.epoch:
        return [
          for (final l in data.lectures)
            if (l.epochIds.contains(scope.id)) l,
        ];
      case ScopeKind.theme:
        return [
          for (final l in data.lectures)
            if (l.themeIds.contains(scope.id)) l,
        ];
    }
  }

  List<HistoryEntry> entriesIn(LearningScope scope) {
    switch (scope.kind) {
      case ScopeKind.all:
        return data.entries;
      case ScopeKind.lectures:
        final ids = {for (final l in data.lectures) ...l.entryIds};
        return [
          for (final e in data.entries)
            if (ids.contains(e.id)) e,
        ];
      case ScopeKind.lecture:
        return data.entriesOfLecture(scope.id!);
      case ScopeKind.epoch:
        return data.entriesOfEpoch(scope.id!);
      case ScopeKind.theme:
        return data.entriesOfTheme(scope.id!);
    }
  }

  List<Epoch> epochsIn(LearningScope scope) {
    switch (scope.kind) {
      case ScopeKind.all || ScopeKind.lectures:
        return data.epochs;
      case ScopeKind.epoch:
        return [?data.epoch(scope.id!)];
      case ScopeKind.lecture:
        final lecture = data.lecture(scope.id!);
        final slides = {for (final s in lecture?.slides ?? <Slide>[]) s.number};
        return [
          for (final e in data.epochs)
            if (e.lectureSlides.any(slides.contains)) e,
        ];
      case ScopeKind.theme:
        return const [];
    }
  }

  // ==========================
  // POOL
  // ==========================

  /// Alle Aufgabeninhalte im Umfang für die gewählten Arten.
  List<QuizCandidate> candidates(LearningScope scope, Set<QuizKind> kinds) {
    final result = <QuizCandidate>[];
    final entries = entriesIn(scope);
    final lectures = lecturesIn(scope);

    final themeEntries = scope.kind == ScopeKind.theme
        ? {for (final e in entries) e.id}
        : null;

    if (kinds.contains(QuizKind.lecture)) {
      for (final l in lectures) {
        for (final q in l.questions) {
          // Bei einem Thema nur Fragen, die Einträge des Themas betreffen.
          if (themeEntries != null && !q.entryIds.any(themeEntries.contains)) {
            continue;
          }
          result.add(
            QuizCandidate(
              cardId: cardId(q.id, QuizKind.lecture),
              kind: QuizKind.lecture,
              build: (r) => _curated(q, r),
            ),
          );
        }
      }
    }

    if (kinds.contains(QuizKind.recall) && themeEntries == null) {
      for (final l in lectures) {
        for (final list in l.lists) {
          result.add(
            QuizCandidate(
              cardId: cardId(list.id, QuizKind.recall),
              kind: QuizKind.recall,
              build: (_) => RecallQuestion(list),
            ),
          );
        }
      }
    }

    for (final e in entries) {
      if (kinds.contains(QuizKind.person)) {
        if (e.type == EntryType.person && e.clue != null) {
          result.add(
            QuizCandidate(
              cardId: cardId(e.id, QuizKind.person),
              kind: QuizKind.person,
              build: (r) => _personByClue(e, r),
            ),
          );
        }
        if (e.type == EntryType.event &&
            _persons(e).any((p) => !_names(_display(e), p))) {
          result.add(
            QuizCandidate(
              cardId: "${e.id}|actor",
              kind: QuizKind.person,
              build: (r) => _personForEvent(e, r),
            ),
          );
        }
      }

      if (kinds.contains(QuizKind.term) &&
          (e.type == EntryType.term || e.type == EntryType.source)) {
        result.add(
          QuizCandidate(
            cardId: cardId(e.id, QuizKind.term),
            kind: QuizKind.term,
            build: (r) => _meaning(e, r),
          ),
        );

        if (e.type == EntryType.term && !_revealsName(e)) {
          result.add(
            QuizCandidate(
              cardId: "${e.id}|name",
              kind: QuizKind.term,
              build: (r) => _termByMeaning(e, r),
            ),
          );
        }
      }

      if (kinds.contains(QuizKind.date) &&
          e.type == EntryType.event &&
          e.dating != null) {
        if (!_hasDigits(e.name)) {
          result.add(
            QuizCandidate(
              cardId: cardId(e.id, QuizKind.date),
              kind: QuizKind.date,
              build: (r) => _dateOf(e, r),
            ),
          );
        }
        result.add(
          QuizCandidate(
            cardId: "${e.id}|when",
            kind: QuizKind.date,
            build: (r) => _eventAt(e, r),
          ),
        );
      }

      if (kinds.contains(QuizKind.epoch) &&
          e.type == EntryType.event &&
          e.epochIds.length == 1 &&
          _eventEpochs.length > 1) {
        result.add(
          QuizCandidate(
            cardId: "${e.id}|epoch",
            kind: QuizKind.epoch,
            build: (r) => _epochOfEvent(e, r),
          ),
        );
      }

      if (kinds.contains(QuizKind.order) && _orderable(e)) {
        result.add(
          QuizCandidate(
            cardId: cardId(e.id, QuizKind.order),
            kind: QuizKind.order,
            build: (r) => _order(e, entries, r),
          ),
        );
      }
    }

    if (kinds.contains(QuizKind.epoch)) {
      for (final epoch in epochsIn(scope)) {
        result.add(
          QuizCandidate(
            cardId: "${epoch.id}|dates",
            kind: QuizKind.epoch,
            build: (r) => _epochDates(epoch, r),
          ),
        );
        result.add(
          QuizCandidate(
            cardId: "${epoch.id}|character",
            kind: QuizKind.epoch,
            build: (r) => _epochByCharacter(epoch, r),
          ),
        );
      }
    }

    // Reihenfolge nur, wenn sich im Umfang genug Ereignisse sicher
    // unterscheiden lassen.
    result.removeWhere(
      (c) => c.kind == QuizKind.order && _orderPartners(c, entries) < 2,
    );

    return result;
  }

  int _orderPartners(QuizCandidate c, List<HistoryEntry> entries) {
    final id = c.cardId.split("|").first;
    final e = data.entry(id)!;
    return entries
        .where((o) => o != e && _orderable(o) && !o.dating!.overlaps(e.dating!))
        .length;
  }

  /// Nächste Aufgabe; null, wenn der Umfang keine Aufgabe hergibt.
  QuizQuestion? next(
    LearningScope scope,
    Set<QuizKind> kinds, {
    bool onlyDifficult = false,
  }) {
    var pool = candidates(scope, kinds);

    if (onlyDifficult) {
      pool = pool.where((c) => isDifficult(c.cardId)).toList();
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

      // Zu wenige eindeutige Ablenker: Inhalt für diese Sitzung überspringen.
      pool = [...pool]..remove(pick);
    }

    return null;
  }

  /// Verbucht eine Antwort und liefert die geänderten Karten.
  List<LearningCard> record(QuizQuestion question, Map<String, bool> results) {
    final changed = <LearningCard>[];

    for (final entry in results.entries) {
      final card = cards.putIfAbsent(
        entry.key,
        () => LearningCard(id: entry.key),
      );
      selector.algorithm.answer(card, entry.value);
      changed.add(card);
    }

    return changed;
  }

  // ==========================
  // BAUSTEINE
  // ==========================

  static bool _hasDigits(String text) => RegExp(r'\d').hasMatch(text);

  /// Text, mit dem ein Eintrag als Antwortmöglichkeit erscheint: der Name,
  /// außer er verrät schon die Datierung (dann die Kurzbeschreibung).
  static String _display(HistoryEntry e) =>
      _hasDigits(e.name) ? e.summary : e.name;

  bool _orderable(HistoryEntry e) =>
      e.type == EntryType.event && e.dating != null;

  Set<String> get _eventEpochs => {
    for (final e in data.entries)
      if (e.type == EntryType.event) ...e.epochIds,
  };

  List<HistoryEntry> _persons(HistoryEntry e) => [
    for (final r in data.relatedOf(e.id))
      if (r.type == EntryType.person) r,
  ];

  /// Ob [text] die Person bzw. den Eintrag [e] beim Namen nennt.
  static bool _names(String text, HistoryEntry e) {
    final lower = text.toLowerCase();
    final first = e.plainName.split(" ").first;

    return [
      e.plainName,
      ...e.aliases,
      if (first.length > 3) first,
    ].any((n) => lower.contains(n.toLowerCase()));
  }

  /// Ersetzt den eigenen Namen eines Eintrags in seiner Erklärung durch „…“,
  /// damit die richtige Antwort sich nicht durch das Fragewort verrät.
  static String _masked(HistoryEntry e) {
    var text = e.summary;

    final names = [e.plainName, ...e.aliases]
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final n in names) {
      if (n.length < 3) continue;
      text = text.replaceAll(
        RegExp(RegExp.escape(n), caseSensitive: false),
        "…",
      );
    }

    return text;
  }

  bool _revealsName(HistoryEntry e) {
    final text = e.summary.toLowerCase();
    return [
      e.plainName,
      ...e.aliases,
    ].any((n) => n.length > 2 && text.contains(n.toLowerCase()));
  }

  /// Mischt richtige Antwort und Ablenker; null bei zu wenigen Ablenkern.
  ({List<String> options, int correct})? _mix(
    String answer,
    Iterable<String> distractors,
    Random r, {
    int count = 3,
    int minimum = 1,
  }) {
    final pool = {
      for (final d in distractors)
        if (d.trim().toLowerCase() != answer.trim().toLowerCase()) d,
    }.toList()..shuffle(r);

    if (pool.length < minimum) return null;

    final options = [answer, ...pool.take(count)]..shuffle(r);
    return (options: options, correct: options.indexOf(answer));
  }

  String _withNote(String text, HistoricalDating? dating) {
    final note = dating?.note;
    return note == null ? text : "$text\n\n$note";
  }

  QuizQuestion? _curated(CuratedQuestion q, Random r) {
    final mix = _mix(q.answer, q.distractors, r, count: q.distractors.length);
    if (mix == null) return null;

    return ChoiceQuestion(
      kind: QuizKind.lecture,
      cardId: cardId(q.id, QuizKind.lecture),
      prompt: q.prompt,
      options: mix.options,
      correctIndex: mix.correct,
      explanation: q.explanation,
      lectureId: q.lectureId,
      slides: q.slides,
      entryIds: q.entryIds,
    );
  }

  ({String? lectureId, List<int> slides}) _source(String entryId) {
    final mentions = data.mentionsOf(entryId);
    if (mentions.isEmpty) return (lectureId: null, slides: const []);
    return (lectureId: mentions.first.lectureId, slides: mentions.first.slides);
  }

  QuizQuestion? _personByClue(HistoryEntry person, Random r) {
    final others = data.entries.where(
      (e) =>
          e.type == EntryType.person &&
          e.id != person.id &&
          !_names(person.clue!, e),
    );

    // Ablenker bevorzugt mit derselben Rolle (Kaiser zu Kaiser).
    final same = others.where((e) => e.category == person.category).toList()
      ..shuffle(r);
    final rest = others.where((e) => e.category != person.category).toList()
      ..shuffle(r);

    final mix = _mix(person.name, [
      for (final e in [...same, ...rest].take(3)) e.name,
    ], r);
    if (mix == null) return null;

    final source = _source(person.id);

    return ChoiceQuestion(
      kind: QuizKind.person,
      cardId: cardId(person.id, QuizKind.person),
      prompt: "Wer ist gemeint?\n${person.clue}",
      options: mix.options,
      correctIndex: mix.correct,
      explanation:
          "${person.name} (${person.dating?.label ?? person.category})"
          ": ${person.significance}",
      lectureId: source.lectureId,
      slides: source.slides,
      entryIds: [person.id],
    );
  }

  QuizQuestion? _personForEvent(HistoryEntry event, Random r) {
    final actors = _persons(event);
    final shown = _display(event);

    // Personen, die schon im angezeigten Text stehen, wären geschenkt.
    final answerable = [
      for (final a in actors)
        if (!_names(shown, a)) a,
    ];
    if (answerable.isEmpty) return null;

    final answer = answerable[r.nextInt(answerable.length)];
    final linked = {for (final a in actors) a.id};

    final others = data.entries
        .where((e) => e.type == EntryType.person && !linked.contains(e.id))
        .toList();

    final same = others.where((e) => e.category == answer.category).toList()
      ..shuffle(r);
    final rest = others.where((e) => e.category != answer.category).toList()
      ..shuffle(r);

    final mix = _mix(answer.name, [
      for (final e in [...same, ...rest].take(3)) e.name,
    ], r);
    if (mix == null) return null;

    final source = _source(event.id);

    return ChoiceQuestion(
      kind: QuizKind.person,
      cardId: "${event.id}|actor",
      prompt: "Welche Person ist mit diesem Geschehen verbunden?\n$shown",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: "${event.name} (${event.dating?.label}): ${event.summary}",
      lectureId: source.lectureId,
      slides: source.slides,
      entryIds: [event.id, answer.id],
    );
  }

  QuizQuestion? _meaning(HistoryEntry e, Random r) {
    final others = data.entries
        .where((o) => o.type == e.type && o.id != e.id)
        .map(_masked);

    final mix = _mix(_masked(e), others, r);
    if (mix == null) return null;

    final source = _source(e.id);

    return ChoiceQuestion(
      kind: QuizKind.term,
      cardId: cardId(e.id, QuizKind.term),
      prompt: e.type == EntryType.source
          ? "Was ist „${e.plainName}“?"
          : "Was bedeutet „${e.plainName}“?",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: e.significance,
      lectureId: source.lectureId,
      slides: source.slides,
      entryIds: [e.id],
    );
  }

  QuizQuestion? _termByMeaning(HistoryEntry e, Random r) {
    final others = data.entries
        .where((o) => o.type == EntryType.term && o.id != e.id)
        .map((o) => o.plainName);

    final mix = _mix(e.plainName, others, r);
    if (mix == null) return null;

    final source = _source(e.id);

    return ChoiceQuestion(
      kind: QuizKind.term,
      cardId: "${e.id}|name",
      prompt: "Welcher Begriff ist gemeint?\n${e.summary}",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: e.significance,
      lectureId: source.lectureId,
      slides: source.slides,
      entryIds: [e.id],
    );
  }

  /// Datierte Einträge, deren Angabe sich sicher von [dating] unterscheidet,
  /// zeitlich nächste zuerst (plausible Ablenker).
  List<HistoryEntry> _distinctDated(HistoricalDating dating, String exclude) {
    final list = [
      for (final o in data.entries)
        if (o.id != exclude &&
            o.type == EntryType.event &&
            o.dating != null &&
            !o.dating!.overlaps(dating))
          o,
    ];

    list.sort(
      (a, b) => (a.dating!.sortKey - dating.sortKey).abs().compareTo(
        (b.dating!.sortKey - dating.sortKey).abs(),
      ),
    );

    return list;
  }

  /// Wählt bis zu [count] Einträge, deren Datierungen sich auch
  /// untereinander nicht überschneiden.
  List<HistoryEntry> _pairwiseDistinct(
    List<HistoryEntry> pool,
    int count,
    Random r, {
    List<HistoryEntry> fixed = const [],
  }) {
    final chosen = <HistoryEntry>[...fixed];
    final shuffled = [...pool]..shuffle(r);

    for (final o in shuffled) {
      if (chosen.length >= fixed.length + count) break;
      if (chosen.every((c) => !c.dating!.overlaps(o.dating!))) chosen.add(o);
    }

    return chosen.sublist(fixed.length);
  }

  QuizQuestion? _dateOf(HistoryEntry e, Random r) {
    final dating = e.dating!;
    final near = _distinctDated(dating, e.id).take(8).toList();
    final picks = _pairwiseDistinct(near, 3, r);

    final mix = _mix(dating.label, [for (final p in picks) p.dating!.label], r);
    if (mix == null) return null;

    final hint = dating.precisionHint;
    final source = _source(e.id);

    return ChoiceQuestion(
      kind: QuizKind.date,
      cardId: cardId(e.id, QuizKind.date),
      prompt:
          "Welche Datierung gehört zu „${e.plainName}“?"
          "${hint == null ? "" : "\n(Die Angabe ist $hint.)"}",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: _withNote("${e.dating!.label}: ${e.summary}", dating),
      lectureId: source.lectureId,
      slides: source.slides,
      entryIds: [e.id],
    );
  }

  QuizQuestion? _eventAt(HistoryEntry e, Random r) {
    final dating = e.dating!;
    final near = _distinctDated(dating, e.id).take(8).toList();

    final mix = _mix(_display(e), [
      for (final p in near.take(3)) _display(p),
    ], r);
    if (mix == null) return null;

    final source = _source(e.id);

    return ChoiceQuestion(
      kind: QuizKind.date,
      cardId: "${e.id}|when",
      prompt: "Was gehört in die Zeit „${dating.label}“?",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: _withNote("${e.name}: ${e.significance}", dating),
      lectureId: source.lectureId,
      slides: source.slides,
      entryIds: [e.id],
    );
  }

  QuizQuestion? _epochOfEvent(HistoryEntry e, Random r) {
    final epoch = data.epoch(e.epochIds.single)!;
    final mix = _mix(epoch.title, [
      for (final o in data.epochs)
        if (o.id != epoch.id) o.title,
    ], r);
    if (mix == null) return null;

    return ChoiceQuestion(
      kind: QuizKind.epoch,
      cardId: "${e.id}|epoch",
      prompt: "In welche Epoche gehört „${e.plainName}“ (${e.dating!.label})?",
      options: mix.options,
      correctIndex: mix.correct,
      explanation:
          "${epoch.title} (${epoch.dating.label}): ${epoch.characterization}",
      entryIds: [e.id],
    );
  }

  ({String? lectureId, List<int> slides}) _epochSource(Epoch epoch) {
    for (final l in data.lectures) {
      if (l.slides.any((s) => epoch.lectureSlides.contains(s.number))) {
        return (lectureId: l.id, slides: epoch.lectureSlides);
      }
    }
    return (lectureId: null, slides: const []);
  }

  QuizQuestion? _epochDates(Epoch epoch, Random r) {
    final mix = _mix(epoch.dating.label, [
      for (final o in data.epochs)
        if (o.id != epoch.id) o.dating.label,
    ], r);
    if (mix == null) return null;

    final source = _epochSource(epoch);

    return ChoiceQuestion(
      kind: QuizKind.epoch,
      cardId: "${epoch.id}|dates",
      prompt:
          "Welche Richtwerte nennt die Vorlesung für die Epoche "
          "„${epoch.title}“?",
      options: mix.options,
      correctIndex: mix.correct,
      explanation:
          "${epoch.title}: ${epoch.dating.label}. "
                  "${data.epochNote ?? ""}"
              .trim(),
      lectureId: source.lectureId,
      slides: source.slides,
    );
  }

  QuizQuestion? _epochByCharacter(Epoch epoch, Random r) {
    final mix = _mix(epoch.title, [
      for (final o in data.epochs)
        if (o.id != epoch.id) o.title,
    ], r);
    if (mix == null) return null;

    final source = _epochSource(epoch);

    return ChoiceQuestion(
      kind: QuizKind.epoch,
      cardId: "${epoch.id}|character",
      prompt:
          "Welche Epoche kennzeichnet die Vorlesung so?\n"
          "„${epoch.characterization}“",
      options: mix.options,
      correctIndex: mix.correct,
      explanation: "${epoch.title} (${epoch.dating.label}): ${epoch.summary}",
      lectureId: source.lectureId,
      slides: source.slides,
    );
  }

  QuizQuestion? _order(HistoryEntry seed, List<HistoryEntry> scope, Random r) {
    final pool = [
      for (final o in scope)
        if (o != seed && _orderable(o) && !o.dating!.overlaps(seed.dating!)) o,
    ];

    // Schwache Ereignisse bevorzugt mitnehmen.
    pool.sort((a, b) {
      final da = cards[cardId(a.id, QuizKind.order)]?.difficulty ?? 5;
      final db = cards[cardId(b.id, QuizKind.order)]?.difficulty ?? 5;
      return db.compareTo(da);
    });

    final partners = _pairwiseDistinct(
      pool.take(10).toList(),
      3,
      r,
      fixed: [seed],
    );

    if (partners.length < 2) return null;

    final items = [seed, ...partners];

    // Nie in richtiger Reihenfolge vorlegen.
    do {
      items.shuffle(r);
    } while (_inOrder(items));

    final sorted = [...items]
      ..sort((a, b) => a.dating!.from.compareTo(b.dating!.from));

    return OrderQuestion(
      prompt: "Bringe in die zeitliche Reihenfolge (früheste oben).",
      items: items,
      explanation: [
        for (final e in sorted) "${e.dating!.label}: ${e.plainName}",
      ].join("\n"),
      entryIds: [for (final e in sorted) e.id],
    );
  }

  static bool _inOrder(List<HistoryEntry> items) {
    for (var i = 1; i < items.length; i++) {
      if (items[i - 1].dating!.from > items[i].dating!.from) return false;
    }
    return true;
  }
}
