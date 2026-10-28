import 'dart:math';

import '../../algorithms/learning_selector.dart';
import '../../models/history/history_course.dart';
import 'history_cards.dart';

/// Fähigkeiten, die „Geschichte Schritt für Schritt“ einzeln übt. Jede hat
/// eigene Lernkarten (`<ID>|h.<Fähigkeit>`), damit z. B. eine sichere
/// Jahreszahl nicht verdeckt, dass die Beteiligten noch unsicher sind.
///
/// [stage] ist die Lernstufe eines Inhalts, ab der die Fähigkeit geübt wird
/// (siehe [HistoryStage]).
enum HistorySkill {
  intro("intro", "Einführung", HistoryStage.basics),
  who("who", "Person erkennen", HistoryStage.basics),
  year("year", "Datierung", HistoryStage.basics),
  when("when", "Was geschah wann?", HistoryStage.basics),
  life("life", "Lebens- und Wirkungszeit", HistoryStage.basics),
  actor("actor", "Beteiligte", HistoryStage.linking),
  deed("deed", "Person und Ereignis", HistoryStage.linking),
  effect("effect", "Folgen", HistoryStage.linking),
  period("period", "Zeitraum zuordnen", HistoryStage.linking),
  chrono("chrono", "Reihenfolge", HistoryStage.linking),
  next("next", "Was folgte?", HistoryStage.linking),
  recall("recall", "Jahreszahl ohne Auswahl", HistoryStage.free),
  span("span", "Zeitabstände", HistoryStage.free),
  explain("explain", "Bedeutung erklären", HistoryStage.free);

  final String key;
  final String label;
  final HistoryStage stage;

  const HistorySkill(this.key, this.label, this.stage);
}

/// Lernstufe eines Inhalts. Sie ergibt sich allein aus den Lernkarten und
/// sagt, welche Aufgaben schon passen – keine Aussage über „Beherrschung“.
///
/// * [none]: noch nicht im Lernschritt eingeführt.
/// * [basics]: eingeführt – einzelne Fakten (Person erkennen, Datierung).
/// * [linking]: Einführungsfrage und eine Grundlagenaufgabe zuletzt sicher –
///   Verknüpfungen, Zeiträume, Reihenfolgen.
/// * [free]: auch eine Verknüpfung zuletzt sicher – Abruf ohne Auswahl,
///   Zeitabstände, Bedeutung erklären.
enum HistoryStage {
  none("Noch nicht eingeführt"),
  basics("Grundlagen"),
  linking("Verknüpfen"),
  free("Ohne Hilfen");

  final String label;

  const HistoryStage(this.label);
}

/// Lernmodi des Bereichs: welche Fähigkeiten sie üben.
enum HistoryMode {
  people(
    "Personen und Ereignisse",
    "Personen erkennen, Beteiligte zuordnen, Bedeutung erklären.",
    {
      HistorySkill.who,
      HistorySkill.life,
      HistorySkill.actor,
      HistorySkill.deed,
      HistorySkill.explain,
    },
  ),
  dates(
    "Jahreszahlen und Zeiträume",
    "Datierungen, Lebens- und Wirkungszeiten, Zeiträume und Abstände.",
    {
      HistorySkill.year,
      HistorySkill.when,
      HistorySkill.life,
      HistorySkill.period,
      HistorySkill.recall,
      HistorySkill.span,
    },
  ),
  chronology(
    "Chronologie aufbauen",
    "Erst zwei Ereignisse vergleichen, dann kleine Gruppen ordnen und "
        "einordnen, zuletzt längere Folgen.",
    {HistorySkill.chrono, HistorySkill.next},
  ),
  connections(
    "Zusammenhänge",
    "Beteiligte, Folgen, Zeiträume und was in den Übersichten aufeinander "
        "folgt.",
    {
      HistorySkill.actor,
      HistorySkill.deed,
      HistorySkill.effect,
      HistorySkill.period,
      HistorySkill.next,
      HistorySkill.explain,
    },
  ),
  mixed(
    "Gemischte Wiederholung",
    "Alles bisher Gelernte gemischt; die Aufgaben richten sich nach deinem "
        "Lernstand.",
    {...HistorySkill.values},
  );

  final String label;
  final String description;
  final Set<HistorySkill> skills;

  const HistoryMode(this.label, this.description, this.skills);
}

// ==========================
// AUFGABEN
// ==========================

sealed class HistoryTask {
  final HistorySkill skill;
  final String prompt;

  /// Erklärung nach der Antwort.
  final String explanation;

  /// Fundstellen der Inhalte („VL 2, Folie 13“).
  final List<String> sources;

  /// Beteiligte Inhalte (zum Nachschlagen).
  final List<String> itemIds;

  const HistoryTask({
    required this.skill,
    required this.prompt,
    required this.explanation,
    this.sources = const [],
    this.itemIds = const [],
  });

  /// Karten, deren Stand eine Antwort verändert.
  List<String> get cardIds;
}

class HistoryChoiceTask extends HistoryTask {
  final List<String> options;
  final int correctIndex;

  @override
  final List<String> cardIds;

  /// Hinweis unter der Frage (z. B. „Die Angabe ist ungefähr.“).
  final String? hint;

  const HistoryChoiceTask({
    required super.skill,
    required super.prompt,
    required this.options,
    required this.correctIndex,
    required this.cardIds,
    required super.explanation,
    super.sources,
    super.itemIds,
    this.hint,
  });

  bool isCorrect(int index) => index == correctIndex;

  String get answer => options[correctIndex];
}

/// Inhalte in die zeitliche Reihenfolge bringen. Alle Paare lassen sich
/// sicher ordnen ([areOrderable]).
class HistoryOrderTask extends HistoryTask {
  /// In der angezeigten (gemischten) Reihenfolge.
  final List<HistoryItem> items;

  const HistoryOrderTask({
    required super.prompt,
    required this.items,
    required super.explanation,
    super.sources,
    super.itemIds,
  }) : super(skill: HistorySkill.chrono);

  List<HistoryItem> get correctOrder => sortChronologically(items);

  List<bool> evaluate(List<HistoryItem> answer) {
    final correct = correctOrder;
    return [for (var i = 0; i < answer.length; i++) answer[i] == correct[i]];
  }

  @override
  List<String> get cardIds => [
    for (final i in items) HistoryTrainer.cardId(i.id, HistorySkill.chrono),
  ];
}

/// Jahreszahl ohne Auswahl eingeben; nur für genaue Datierungen.
class HistoryYearTask extends HistoryTask {
  final HistoryItem item;

  /// Gültige Eingaben als Betrag (ohne „v. Chr.“).
  final int min;
  final int max;
  final bool beforeChrist;

  const HistoryYearTask({
    required this.item,
    required super.prompt,
    required this.min,
    required this.max,
    required this.beforeChrist,
    required super.explanation,
    super.sources,
    super.itemIds,
  }) : super(skill: HistorySkill.recall);

  /// Ob die Eingabe passt; null, wenn sie keine Zahl ist.
  bool? check(String input) {
    final match = RegExp(r'\d+').firstMatch(input);
    if (match == null) return null;
    final year = int.parse(match.group(0)!);
    return year >= min && year <= max;
  }

  @override
  List<String> get cardIds => [
    HistoryTrainer.cardId(item.id, HistorySkill.recall),
  ];
}

/// Im Kopf erklären und selbst bewerten. Als Einführungsfrage
/// ([HistorySkill.intro]), wenn sich keine eindeutige Auswahlfrage bilden
/// lässt (z. B. der einzige Zeitraum einer Veranstaltung).
class HistoryExplainTask extends HistoryTask {
  final HistoryItem item;
  final List<String> solution;

  const HistoryExplainTask({
    required this.item,
    required super.prompt,
    required this.solution,
    required super.explanation,
    super.sources,
    super.itemIds,
    super.skill = HistorySkill.explain,
  });

  @override
  List<String> get cardIds => [HistoryTrainer.cardId(item.id, skill)];
}

/// Chronologisch sortiert (Beginn, dann Ende).
List<HistoryItem> sortChronologically(Iterable<HistoryItem> items) {
  return items.toList()..sort((a, b) {
    final from = a.dating!.from.compareTo(b.dating!.from);
    return from != 0 ? from : a.dating!.end.compareTo(b.dating!.end);
  });
}

/// Ein möglicher Aufgabeninhalt: Lernkarte und Bauanleitung.
class HistoryCandidate {
  final String cardId;
  final HistorySkill skill;
  final HistoryTask? Function(Random random) build;

  const HistoryCandidate({
    required this.cardId,
    required this.skill,
    required this.build,
  });
}

/// Erzeugt Aufgaben aus der Sicht [course] und wählt sie nach Lernbedarf
/// und Lernstufe aus.
///
/// Grundsätze:
/// * Neues zuerst einzeln: Aufgaben zu einem Inhalt passen zu seiner
///   Lernstufe ([stageOf]); Verknüpfungen erst, wenn die Grundlagen zuletzt
///   sicher waren.
/// * Eindeutig: Datierungen von Antwort und Ablenkern überschneiden sich
///   auch mit Unschärfe nicht; verknüpfte Inhalte sind nie Ablenker;
///   Fragen verraten die Antwort nicht.
/// * Ablenker kommen bevorzugt aus schon Gelerntem, damit eine Aufgabe nicht
///   viele unbekannte Namen auf einmal voraussetzt.
/// * Auswahl wie in den übrigen Trainern ([LearningSelector]: Lernbedarf ×
///   Fälligkeit, Sperre für gerade gestellte Aufgaben).
class HistoryTrainer {
  final HistoryCourse course;
  final HistoryCardBook book;
  final LearningSelector selector;
  final Random random;

  HistoryTrainer({required this.course, required this.book, Random? random})
    : random = random ?? Random(),
      selector = LearningSelector(algorithm: book.algorithm, random: random);

  static String cardId(String itemId, HistorySkill skill) =>
      "$itemId|h.${skill.key}";

  static String nextCardId(String sequenceId, String itemId) =>
      "$sequenceId/$itemId|h.${HistorySkill.next.key}";

  /// Alle Karten eines Inhalts (für Fortschritt und Zurücksetzen).
  Iterable<String> cardsOf(String itemId) => book.cards.keys.where(
    (id) =>
        id.startsWith("$itemId|h.") ||
        (id.contains("/$itemId|h.") && id.startsWith("seq.")),
  );

  bool isIntroduced(String itemId) =>
      book.answered(cardId(itemId, HistorySkill.intro));

  // ==========================
  // LERNSTUFEN
  // ==========================

  static const Map<HistoryStage, List<HistorySkill>> _skillsOf = {
    HistoryStage.basics: [
      HistorySkill.who,
      HistorySkill.year,
      HistorySkill.when,
      HistorySkill.life,
    ],
    HistoryStage.linking: [
      HistorySkill.actor,
      HistorySkill.deed,
      HistorySkill.effect,
      HistorySkill.period,
      HistorySkill.chrono,
    ],
  };

  /// Lernstufe von [item]. [assumeIntroduced]: im Umfang „Alle Inhalte“
  /// zählt ein Inhalt auch ohne Lernschritt als eingeführt; die weiteren
  /// Stufen ergeben sich auch dann nur aus den Antworten.
  HistoryStage stageOf(HistoryItem item, {bool assumeIntroduced = false}) {
    final introduced = isIntroduced(item.id);
    if (!introduced && !assumeIntroduced) return HistoryStage.none;

    bool anySolid(HistoryStage stage) =>
        _skillsOf[stage]!.any((s) => book.solid(cardId(item.id, s)));

    final basicsDone =
        (book.solid(cardId(item.id, HistorySkill.intro)) || !introduced) &&
        anySolid(HistoryStage.basics);
    if (!basicsDone) return HistoryStage.basics;

    final linkingDone =
        anySolid(HistoryStage.linking) ||
        course.sequences.any((s) => book.solid(nextCardId(s.id, item.id)));
    return linkingDone ? HistoryStage.free : HistoryStage.linking;
  }

  /// Inhalte im Umfang: eingeführte bzw. alle.
  List<HistoryItem> pool({required bool onlyIntroduced}) => [
    for (final i in course.items)
      if (!onlyIntroduced || isIntroduced(i.id)) i,
  ];

  /// Stufe des Chronologie-Aufbaus im Umfang: 1 Paare, 2 Dreiergruppen,
  /// 3 Vierergruppen und Einordnen, 4 längere Folgen. Sie steigt mit der
  /// Zahl der Inhalte, deren Reihenfolge zuletzt sicher war.
  int chronologyLevel(List<HistoryItem> pool) {
    final solid = pool
        .where((i) => book.solid(cardId(i.id, HistorySkill.chrono)))
        .length;
    if (solid < 3) return 1;
    if (solid < 6) return 2;
    if (solid < 10) return 3;
    return 4;
  }

  static const List<String> chronologyLevels = [
    "Zwei Ereignisse vergleichen",
    "Drei Ereignisse ordnen",
    "Vier Ereignisse ordnen und einordnen",
    "Längere Folgen ordnen",
  ];

  // ==========================
  // POOL
  // ==========================

  List<HistoryCandidate> candidates(
    HistoryMode mode, {
    required bool onlyIntroduced,
  }) {
    final items = pool(onlyIntroduced: onlyIntroduced);
    final result = <HistoryCandidate>[];
    final chronoLevel = chronologyLevel(items);

    for (final item in items) {
      final stage = stageOf(item, assumeIntroduced: !onlyIntroduced);
      if (stage == HistoryStage.none) continue;

      for (final skill in mode.skills) {
        // Wer ausdrücklich Reihenfolgen übt, beginnt mit Paaren schon nach
        // der Einführung; sonst kommen Reihenfolgen erst nach den Grundlagen.
        final needed =
            mode == HistoryMode.chronology && skill == HistorySkill.chrono
            ? HistoryStage.basics
            : skill.stage;
        if (needed.index > stage.index) continue;
        if (skill == HistorySkill.intro && !isIntroduced(item.id)) continue;
        if (skill == HistorySkill.next) continue;
        if (!applies(item, skill, items)) continue;

        result.add(
          HistoryCandidate(
            cardId: cardId(item.id, skill),
            skill: skill,
            build: skill == HistorySkill.chrono
                ? (r) => chronology(item, items, chronoLevel, r)
                : (r) => build(item, skill, r, known: items),
          ),
        );
      }

      if (mode.skills.contains(HistorySkill.next) &&
          stage.index >= HistorySkill.next.stage.index) {
        for (final s in course.sequences) {
          final next = s.next(item.id);
          if (next == null || !items.any((i) => i.id == next)) continue;
          result.add(
            HistoryCandidate(
              cardId: nextCardId(s.id, item.id),
              skill: HistorySkill.next,
              build: (r) => nextInSequence(s, item, r),
            ),
          );
        }
      }
    }

    return result;
  }

  /// Nächste Aufgabe; null, wenn der Umfang keine hergibt.
  HistoryTask? next(HistoryMode mode, {required bool onlyIntroduced}) {
    var pool = candidates(mode, onlyIntroduced: onlyIntroduced);

    while (pool.isNotEmpty) {
      final pick = selector.select(
        candidates: pool,
        idOf: (c) => c.cardId,
        cards: book.cards,
      );
      if (pick == null) return null;

      final task = pick.build(random);
      if (task != null) return task;

      // Zu wenige eindeutige Ablenker: für diese Sitzung überspringen.
      pool = [...pool]..remove(pick);
    }

    return null;
  }

  /// Ob es für [item] Aufgaben der Fähigkeit [skill] geben kann (ohne sie
  /// zu bauen).
  bool applies(HistoryItem item, HistorySkill skill, List<HistoryItem> pool) {
    final dating = item.dating;
    switch (skill) {
      case HistorySkill.intro:
        return true;
      case HistorySkill.who:
        return item.kind == HistoryItemKind.person && item.clue != null;
      case HistorySkill.year:
        return dating != null && item.kind != HistoryItemKind.person;
      case HistorySkill.when:
        return dating != null && item.kind == HistoryItemKind.event;
      case HistorySkill.life:
        return dating != null && item.kind == HistoryItemKind.person;
      case HistorySkill.actor:
        return item.kind == HistoryItemKind.event &&
            _actors(item).any(pool.contains);
      case HistorySkill.deed:
        return (item.kind == HistoryItemKind.person ||
                item.kind == HistoryItemKind.group) &&
            _deeds(item).any(pool.contains);
      case HistorySkill.effect:
        return item.consequence != null;
      case HistorySkill.period:
        return item.kind == HistoryItemKind.event &&
            ((_periodOptions(item) != null &&
                    pool.any((p) => p.id == item.periodId)) ||
                (_periodOptions(item) == null && _century(item) != null));
      case HistorySkill.chrono:
        return dating != null &&
            item.kind != HistoryItemKind.person &&
            item.kind != HistoryItemKind.group &&
            pool.any((o) => o != item && _chronoPartner(item, o));
      case HistorySkill.next:
        return course.sequences.any((s) => s.next(item.id) != null);
      case HistorySkill.recall:
        return _exactYear(item);
      case HistorySkill.span:
        return _exactYear(item) &&
            pool.any((o) => o != item && _spanPartner(item, o));
      case HistorySkill.explain:
        return item.courseStatements.isNotEmpty;
    }
  }

  // ==========================
  // BAUSTEINE
  // ==========================

  /// Baut eine Aufgabe der Fähigkeit [skill] zu [item]. [known]: schon
  /// gelernte Inhalte, aus denen Ablenker bevorzugt stammen.
  HistoryTask? build(
    HistoryItem item,
    HistorySkill skill,
    Random r, {
    List<HistoryItem> known = const [],
  }) {
    final knownIds = {for (final k in known) k.id};
    switch (skill) {
      case HistorySkill.intro:
        return _intro(item, r, knownIds);
      case HistorySkill.who:
        return _who(item, r, knownIds, skill: HistorySkill.who);
      case HistorySkill.year:
        return _year(item, r, knownIds, skill: HistorySkill.year);
      case HistorySkill.when:
        return _when(item, r, knownIds);
      case HistorySkill.life:
        return _year(item, r, knownIds, skill: HistorySkill.life);
      case HistorySkill.actor:
        return _actor(item, r, knownIds);
      case HistorySkill.deed:
        return _deed(item, r, knownIds);
      case HistorySkill.effect:
        return _effect(item, r);
      case HistorySkill.period:
        return _period(item, r, knownIds);
      case HistorySkill.chrono:
        return chronology(item, known.isEmpty ? course.items : known, 1, r);
      case HistorySkill.next:
        final s = course.sequences
            .where((s) => s.next(item.id) != null)
            .firstOrNull;
        return s == null ? null : nextInSequence(s, item, r);
      case HistorySkill.recall:
        return _recall(item);
      case HistorySkill.span:
        return _span(item, known.isEmpty ? course.items : known, r);
      case HistorySkill.explain:
        return _explain(item);
    }
  }

  /// Einführungsfrage im Lernschritt: Personen nach ihrer Kennzeichnung,
  /// Ereignisse nach ihrer Datierung, Zeiträume und Mächte nach der Aussage
  /// der Folie (ohne ihren Namen).
  HistoryTask? _intro(HistoryItem item, Random r, Set<String> known) {
    switch (item.kind) {
      case HistoryItemKind.person:
        return _who(item, r, known, skill: HistorySkill.intro) ??
            _year(item, r, known, skill: HistorySkill.intro) ??
            _selfCheck(item);
      case HistoryItemKind.event:
        return _year(item, r, known, skill: HistorySkill.intro) ??
            _masked(item, r, known) ??
            _selfCheck(item);
      case HistoryItemKind.period:
      case HistoryItemKind.group:
        return _masked(item, r, known) ??
            _year(item, r, known, skill: HistorySkill.intro) ??
            _selfCheck(item);
    }
  }

  /// Einführungsfrage zur Selbstprüfung, wenn keine Auswahl eindeutig wäre.
  HistoryTask? _selfCheck(HistoryItem item) {
    final explain = _explain(item);
    if (explain is! HistoryExplainTask) return null;
    return HistoryExplainTask(
      skill: HistorySkill.intro,
      item: item,
      prompt: item.dating == null
          ? "Was sagt die ${course.sourceName} über ${_q(item.name)}?"
          : "Wann liegt ${_q(item.name)}, und was sagt die "
                "${course.sourceName} darüber?",
      solution: explain.solution,
      explanation: explain.explanation,
      sources: explain.sources,
      itemIds: explain.itemIds,
    );
  }

  String _explanationOf(HistoryItem item) {
    final dating = item.dating;
    final statement =
        item.courseStatements.firstOrNull?.text ??
        item.statements.firstOrNull?.text;
    final lines = [
      dating == null ? item.name : "${item.name} (${dating.label})",
      ?statement,
      ?dating?.note,
    ];
    return lines.join("\n");
  }

  List<String> _sourcesOf(Iterable<HistoryItem> items) =>
      {for (final i in items) ?i.source}.toList();

  /// Mischt Antwort und Ablenker; null bei weniger als [minimum] Ablenkern.
  ({List<String> options, int correct})? _mix(
    String answer,
    Iterable<String> distractors,
    Random r, {
    int count = 3,
    int minimum = 2,
  }) {
    final seen = {answer.trim().toLowerCase()};
    final pool = <String>[];
    for (final d in distractors) {
      if (seen.add(d.trim().toLowerCase())) pool.add(d);
      if (pool.length >= count) break;
    }
    if (pool.length < minimum) return null;
    final options = [answer, ...pool]..shuffle(r);
    return (options: options, correct: options.indexOf(answer));
  }

  /// Schon eingeführte Inhalte im Umfang [known] zuerst, dann der übrige
  /// Umfang, dann alles andere; innerhalb der Gruppen zufällig.
  List<HistoryItem> _preferKnown(
    Iterable<HistoryItem> items,
    Set<String> known,
    Random r,
  ) {
    int rank(HistoryItem i) => !known.contains(i.id)
        ? 2
        : isIntroduced(i.id)
        ? 0
        : 1;
    final groups = [<HistoryItem>[], <HistoryItem>[], <HistoryItem>[]];
    for (final i in items) {
      groups[rank(i)].add(i);
    }
    return [for (final g in groups) ...(g..shuffle(r))];
  }

  /// Ob [text] den Inhalt [item] beim Namen nennt.
  static bool _names(String text, HistoryItem item) {
    final lower = text.toLowerCase();
    final plain = item.name.replaceAll(RegExp(r'[„“"]'), "");
    final first = plain.split(" ").first;
    return [
      plain,
      if (first.length > 3) first,
      _stem(plain),
    ].any((n) => n.length > 2 && lower.contains(n.toLowerCase()));
  }

  /// Name in Anführungszeichen; ist er schon ganz zitiert, bleibt er so,
  /// innere Anführungszeichen werden halbe („‚Israel‘ auf der Stele …“).
  static String _q(String name) {
    final inner = name.substring(1, name.length > 1 ? name.length - 1 : 1);
    if (name.startsWith("„") && name.endsWith("“") && !inner.contains("„")) {
      return name;
    }
    return "„${name.replaceAll("„", "‚").replaceAll("“", "‘")}“";
  }

  /// Erst Inhalte derselben Spur (z. B. Geschichte, nicht Textgeschichte),
  /// sonst die Reihenfolge von [items] unverändert.
  static List<HistoryItem> _sameTrackFirst(
    Iterable<HistoryItem> items,
    String? trackId,
  ) {
    final list = items.toList();
    return [
      ...list.where((i) => i.trackId == trackId),
      ...list.where((i) => i.trackId != trackId),
    ];
  }

  /// Wortstamm für Namen von Mächten („Assyrer“ → „assyr“, findet auch
  /// „Neuassyrer“, „hasmonäischen“).
  static String _stem(String name) {
    final word = name.split(" ").last;
    return word.length <= 4 ? word : word.substring(0, word.length - 2);
  }

  HistoryTask? _who(
    HistoryItem person,
    Random r,
    Set<String> known, {
    required HistorySkill skill,
  }) {
    final clue = person.clue;
    if (person.kind != HistoryItemKind.person || clue == null) return null;

    final others = course.items.where(
      (o) =>
          o.kind == HistoryItemKind.person &&
          o.id != person.id &&
          !course.areRelated(o.id, person.id) &&
          !_names(clue, o),
    );

    final mix = _mix(person.name, [
      for (final o in _preferKnown(others, known, r)) o.name,
    ], r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: skill,
      prompt: "Wer ist gemeint?\n$clue",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(person.id, skill)],
      explanation: _explanationOf(person),
      sources: _sourcesOf([person]),
      itemIds: [person.id],
    );
  }

  /// Datierte Inhalte derselben Art, deren Angabe sich sicher von [item]
  /// unterscheidet und untereinander nicht überschneidet; bekannte und
  /// zeitlich nahe zuerst.
  List<HistoryItem> _distinctDated(
    HistoryItem item,
    Set<String> known,
    Random r, {
    int count = 3,
    bool sameKind = true,
  }) {
    final dating = item.dating!;
    final candidates = [
      for (final o in course.items)
        if (o.id != item.id &&
            o.dating != null &&
            (sameKind
                ? o.kind == item.kind
                : (o.kind == HistoryItemKind.person) ==
                      (item.kind == HistoryItemKind.person)) &&
            !o.dating!.overlaps(dating) &&
            o.dating!.label != dating.label)
          o,
    ];

    double distance(HistoryItem o) =>
        (o.dating!.sortKey - dating.sortKey).abs();

    int rank(HistoryItem o) => !known.contains(o.id)
        ? 2
        : isIntroduced(o.id)
        ? 0
        : 1;

    int track(HistoryItem o) => o.trackId == item.trackId ? 0 : 1;

    candidates.sort((a, b) {
      final ta = track(a);
      final tb = track(b);
      if (ta != tb) return ta.compareTo(tb);
      final ka = rank(a);
      final kb = rank(b);
      if (ka != kb) return ka.compareTo(kb);
      return distance(a).compareTo(distance(b));
    });

    // Etwas Abwechslung unter den nächsten. Ablenker dürfen sich
    // untereinander berühren (aneinandergrenzende Zeiträume), nie aber mit
    // der Antwort.
    final near = candidates.take(8).toList()..shuffle(r);
    final chosen = <HistoryItem>[];
    for (final o in [...near, ...candidates.skip(8)]) {
      if (chosen.length >= count) break;
      if (chosen.every((c) => c.dating!.label != o.dating!.label)) {
        chosen.add(o);
      }
    }
    return chosen;
  }

  HistoryTask? _year(
    HistoryItem item,
    Random r,
    Set<String> known, {
    required HistorySkill skill,
  }) {
    final dating = item.dating;
    if (dating == null) return null;

    // Zeiträume nur mit Zeiträumen vergleichen (zur Not mit zwei
    // Antwortmöglichkeiten), sonst notfalls auch andere Arten.
    var picks = _distinctDated(item, known, r);
    final periods = item.kind == HistoryItemKind.period;
    if (picks.length < 2 && !periods) {
      picks = _distinctDated(item, known, r, sameKind: false);
    }

    final mix = _mix(
      dating.label,
      [for (final p in picks) p.dating!.label],
      r,
      minimum: periods ? 1 : 2,
    );
    if (mix == null) return null;

    final hint = dating.precisionHint;
    final prompt = switch (item.kind) {
      HistoryItemKind.person =>
        "Welche Lebens- bzw. Wirkungszeit gehört zu ${item.name}?",
      HistoryItemKind.period => "Welche Datierung gehört zu ${_q(item.name)}?",
      _ => "Wann? ${_q(item.timelessName)}",
    };

    return HistoryChoiceTask(
      skill: skill,
      prompt: prompt,
      hint: hint == null ? null : "Die Angabe ist $hint.",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(item.id, skill)],
      explanation: _explanationOf(item),
      sources: _sourcesOf([item]),
      itemIds: [item.id],
    );
  }

  HistoryTask? _when(HistoryItem event, Random r, Set<String> known) {
    final dating = event.dating;
    if (dating == null || event.kind != HistoryItemKind.event) return null;

    final picks = _distinctDated(event, known, r);
    final mix = _mix(event.timelessName, [
      for (final p in picks) p.timelessName,
    ], r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.when,
      prompt: "Was gehört in die Zeit „${dating.label}“?",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(event.id, HistorySkill.when)],
      explanation: _explanationOf(event),
      sources: _sourcesOf([event]),
      itemIds: [event.id],
    );
  }

  /// Aussage der Folie mit „…“ statt des Namens.
  HistoryTask? _masked(HistoryItem item, Random r, Set<String> known) {
    final stem = _stem(item.name.replaceAll(RegExp(r'[„“"]'), ""));
    String? masked;

    for (final s in item.courseStatements) {
      var text = s.text.replaceAll(item.name, "…");
      text = text.replaceAllMapped(RegExp(r'[\wäöüÄÖÜß]+'), (m) {
        final word = m.group(0)!;
        return word.toLowerCase().contains(stem.toLowerCase()) ? "…" : word;
      });
      if (text.contains("…") && !_names(text, item)) {
        masked = text;
        break;
      }
    }
    if (masked == null) return null;

    final others = course.items.where(
      (o) =>
          o.kind == item.kind &&
          o.id != item.id &&
          !course.areRelated(o.id, item.id) &&
          !_names(masked!, o),
    );
    final mix = _mix(item.name, [
      for (final o in _preferKnown(others, known, r)) o.name,
    ], r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.intro,
      prompt: item.kind == HistoryItemKind.period
          ? "Welcher Zeitraum ist gemeint?\n$masked"
          : item.kind == HistoryItemKind.group
          ? "Welche Macht ist gemeint?\n$masked"
          : "Was ist gemeint?\n$masked",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(item.id, HistorySkill.intro)],
      explanation: _explanationOf(item),
      sources: _sourcesOf([item]),
      itemIds: [item.id],
    );
  }

  /// Beteiligte Personen bzw. Mächte, die der Name des Ereignisses nicht
  /// schon nennt.
  List<HistoryItem> _actors(HistoryItem event) => [
    for (final o in course.relatedOf(event.id))
      if ((o.kind == HistoryItemKind.person ||
              o.kind == HistoryItemKind.group) &&
          !_names(event.name, o))
        o,
  ];

  /// Verknüpfte Ereignisse, deren Name die Person bzw. Macht nicht nennt.
  List<HistoryItem> _deeds(HistoryItem actor) => [
    for (final o in course.relatedOf(actor.id))
      if (o.kind == HistoryItemKind.event && !_names(o.name, actor)) o,
  ];

  HistoryTask? _actor(HistoryItem event, Random r, Set<String> known) {
    // Gefragt wird nur nach Beteiligten, die im Umfang schon vorkommen.
    final actors = [
      for (final a in _actors(event))
        if (known.isEmpty || known.contains(a.id)) a,
    ];
    if (actors.isEmpty) return null;
    final answer = actors[r.nextInt(actors.length)];

    final others = course.items.where(
      (o) =>
          o.kind == answer.kind &&
          !course.areRelated(o.id, event.id) &&
          o.id != answer.id &&
          !_names(event.name, o),
    );
    final mix = _mix(answer.name, [
      for (final o in _preferKnown(others, known, r)) o.name,
    ], r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.actor,
      prompt: answer.kind == HistoryItemKind.group
          ? "Welche Macht war beteiligt?\n${event.name}"
          : "Welche Person war beteiligt?\n${event.name}",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(event.id, HistorySkill.actor)],
      explanation: "${_explanationOf(event)}\n\n${_explanationOf(answer)}",
      sources: _sourcesOf([event, answer]),
      itemIds: [event.id, answer.id],
    );
  }

  HistoryTask? _deed(HistoryItem actor, Random r, Set<String> known) {
    final deeds = [
      for (final d in _deeds(actor))
        if (known.isEmpty || known.contains(d.id)) d,
    ];
    if (deeds.isEmpty) return null;

    final answer = deeds[r.nextInt(deeds.length)];
    final others = course.items.where(
      (o) =>
          o.kind == HistoryItemKind.event &&
          !course.areRelated(o.id, actor.id) &&
          !_names(o.name, actor),
    );
    final mix = _mix(answer.name, [
      for (final o in _sameTrackFirst(
        _preferKnown(others, known, r),
        answer.trackId,
      ))
        o.name,
    ], r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.deed,
      prompt: "Mit welchem Ereignis ist ${actor.name} verbunden?",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(actor.id, HistorySkill.deed)],
      explanation: "${_explanationOf(answer)}\n\n${_explanationOf(actor)}",
      sources: _sourcesOf([answer, actor]),
      itemIds: [actor.id, answer.id],
    );
  }

  HistoryTask? _effect(HistoryItem event, Random r) {
    final consequence = event.consequence;
    if (consequence == null) return null;

    final others = [
      for (final o in _sameTrackFirst(
        course.items.toList()..shuffle(r),
        event.trackId,
      ))
        if (o.id != event.id && o.consequence != null) o.consequence!.text,
    ];
    final mix = _mix(consequence.text, others, r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.effect,
      prompt:
          "Was folgte nach der ${course.sourceName} auf dieses Ereignis?\n"
          "${event.name}",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(event.id, HistorySkill.effect)],
      explanation: "${_explanationOf(event)}\n\nFolge: ${consequence.text}",
      sources: [consequence.source],
      itemIds: [event.id],
    );
  }

  /// Zeiträume der Sicht, falls mindestens zwei Ereignisse enthalten und
  /// [event] einem davon angehört.
  List<HistoryItem>? _periodOptions(HistoryItem event) {
    if (event.periodId == null) return null;
    final used = [
      for (final p in course.periods)
        if (course
            .itemsOfPeriod(p.id)
            .any((i) => i.kind == HistoryItemKind.event))
          p,
    ];
    return used.length < 2 ? null : course.periods;
  }

  /// Jahrhundert, wenn die Datierung (mit Unschärfe) sicher in einem liegt.
  int? _century(HistoryItem event) {
    final d = event.dating;
    if (d == null || d.disputed) return null;
    final c = centuryOf(d.earliest);
    return centuryOf(d.latest) == c ? c : null;
  }

  HistoryTask? _period(HistoryItem event, Random r, Set<String> known) {
    final periods = _periodOptions(event);
    if (periods != null) {
      final period = course.item(event.periodId!)!;
      if (known.isNotEmpty && !known.contains(period.id)) return null;
      final mix = _mix(
        period.name,
        [
          for (final p in periods)
            if (p.id != period.id) p.name,
        ],
        r,
        minimum: 1,
      );
      if (mix == null) return null;

      return HistoryChoiceTask(
        skill: HistorySkill.period,
        prompt:
            "In welchen Zeitraum ordnet die ${course.sourceName} dieses "
            "Ereignis ein?\n${event.timelessName}",
        options: mix.options,
        correctIndex: mix.correct,
        cardIds: [cardId(event.id, HistorySkill.period)],
        explanation: "${_explanationOf(event)}\n\n${_explanationOf(period)}",
        sources: _sourcesOf([period, event]),
        itemIds: [event.id, period.id],
      );
    }

    final century = _century(event);
    if (century == null) return null;

    final options = <int>[
      for (final d in [-2, -1, 1, 2]) century + d,
    ].where((c) => c != 0).toList()..shuffle(r);
    final mix = _mix(centuryLabel(century), [
      for (final c in options) centuryLabel(c),
    ], r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.period,
      prompt: "In welches Jahrhundert gehört das?\n${event.timelessName}",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(event.id, HistorySkill.period)],
      explanation: _explanationOf(event),
      sources: _sourcesOf([event]),
      itemIds: [event.id],
    );
  }

  HistoryTask? nextInSequence(
    HistorySequence sequence,
    HistoryItem item,
    Random r,
  ) {
    final nextId = sequence.next(item.id);
    final next = nextId == null ? null : course.item(nextId);
    if (next == null) return null;

    // Schon eingeführte Ablenker zuerst.
    final rest = [
      for (final id in sequence.itemIds)
        if (id != item.id && id != next.id) course.item(id)!,
    ]..shuffle(r);
    final others = [
      for (final o in [
        ...rest.where((o) => isIntroduced(o.id)),
        ...rest.where((o) => !isIntroduced(o.id)),
      ])
        o.timelessName,
    ];
    final mix = _mix(next.timelessName, others, r);
    if (mix == null) return null;

    return HistoryChoiceTask(
      skill: HistorySkill.next,
      prompt:
          "Was folgt in der Übersicht „${sequence.title}“ unmittelbar auf "
          "dieses Ereignis?\n${item.timelessName}",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [nextCardId(sequence.id, item.id)],
      explanation: [
        for (final id in sequence.itemIds)
          "${course.item(id)!.dating?.label ?? ""}: ${course.item(id)!.name}",
      ].join("\n"),
      sources: [sequence.source],
      itemIds: [item.id, next.id],
    );
  }

  bool _chronoPartner(HistoryItem a, HistoryItem b) {
    if (b.dating == null || a.dating == null) return false;
    if ((a.kind == HistoryItemKind.period) !=
        (b.kind == HistoryItemKind.period)) {
      return false;
    }
    if (b.kind == HistoryItemKind.person || b.kind == HistoryItemKind.group) {
      return false;
    }
    return areOrderable(a, b);
  }

  /// Reihenfolge-Aufgabe mit [seed] auf Stufe [level] (siehe
  /// [chronologyLevel]). Partner stammen aus [pool], bevorzugt aus derselben
  /// Spur und mit schon geübter Reihenfolge; ab Stufe 3 auch Einordnen.
  HistoryTask? chronology(
    HistoryItem seed,
    List<HistoryItem> pool,
    int level,
    Random r,
  ) {
    var partners = [
      for (final o in pool)
        if (o != seed && _chronoPartner(seed, o)) o,
    ];
    final sameTrack = [
      for (final o in partners)
        if (o.trackId == seed.trackId) o,
    ];
    if (sameTrack.length >= min(level, partners.length)) partners = sameTrack;
    if (partners.isEmpty) return null;

    final chrono = HistorySkill.chrono;
    partners.sort((a, b) {
      final ka = book.answered(cardId(a.id, chrono)) ? 0 : 1;
      final kb = book.answered(cardId(b.id, chrono)) ? 0 : 1;
      return ka.compareTo(kb);
    });
    // Abwechslung innerhalb der Bevorzugung.
    final head = partners.take(6).toList()..shuffle(r);
    partners = [...head, ...partners.skip(6)];

    if (level >= 3 && r.nextInt(3) == 0) {
      final insert = _insert(seed, partners, r);
      if (insert != null) return insert;
    }

    final size = switch (level) {
      1 => 2,
      2 => 3,
      3 => 4,
      _ => 5,
    };

    final chosen = <HistoryItem>[seed];
    for (final o in partners) {
      if (chosen.length >= size) break;
      if (chosen.every((c) => _chronoPartner(c, o))) chosen.add(o);
    }
    if (chosen.length < 2) return null;

    final sorted = sortChronologically(chosen);
    final explanation = [
      for (final e in sorted) "${e.dating!.label}: ${e.name}",
    ].join("\n");

    if (chosen.length == 2) {
      final options = [seed.timelessName, chosen[1].timelessName]..shuffle(r);
      return HistoryChoiceTask(
        skill: chrono,
        prompt: "Was war früher?",
        options: options,
        correctIndex: options.indexOf(sorted.first.timelessName),
        cardIds: [for (final c in chosen) cardId(c.id, chrono)],
        explanation: explanation,
        sources: _sourcesOf(sorted),
        itemIds: [for (final c in sorted) c.id],
      );
    }

    final shown = [...chosen];
    do {
      shown.shuffle(r);
    } while (_inOrder(shown));

    return HistoryOrderTask(
      prompt: "Bringe in die zeitliche Reihenfolge (früheste oben).",
      items: shown,
      explanation: explanation,
      sources: _sourcesOf(sorted),
      itemIds: [for (final c in sorted) c.id],
    );
  }

  static bool _inOrder(List<HistoryItem> items) {
    for (var i = 1; i < items.length; i++) {
      if (items[i - 1].dating!.from > items[i].dating!.from) return false;
    }
    return true;
  }

  /// „Wo gehört X hin?“ zwischen bis zu drei geordneten Ankern.
  HistoryTask? _insert(HistoryItem seed, List<HistoryItem> partners, Random r) {
    final anchors = <HistoryItem>[];
    for (final o in partners) {
      if (anchors.length >= 3) break;
      if (!book.answered(cardId(o.id, HistorySkill.chrono))) continue;
      if (anchors.every((a) => _chronoPartner(a, o))) anchors.add(o);
    }
    if (anchors.length < 2) return null;

    final sorted = sortChronologically(anchors);
    final options = <String>[
      "vor ${_q(sorted.first.timelessName)}",
      for (var i = 1; i < sorted.length; i++)
        "zwischen ${_q(sorted[i - 1].timelessName)} und "
            "${_q(sorted[i].timelessName)}",
      "nach ${_q(sorted.last.timelessName)}",
    ];
    final position = sorted.where((a) => isClearlyBefore(a, seed)).length;

    return HistoryChoiceTask(
      skill: HistorySkill.chrono,
      prompt: "Wo gehört das hin?\n${seed.timelessName}",
      hint: [for (final a in sorted) "• ${a.timelessName}"].join("\n"),
      options: options,
      correctIndex: position,
      cardIds: [cardId(seed.id, HistorySkill.chrono)],
      explanation: [
        for (final e in sortChronologically([...sorted, seed]))
          "${e.dating!.label}: ${e.name}",
      ].join("\n"),
      sources: _sourcesOf([seed, ...sorted]),
      itemIds: [seed.id, for (final a in sorted) a.id],
    );
  }

  /// Genaue Jahresangabe (höchstens zwei Jahre wie „722/20“).
  static bool _exactYear(HistoryItem item) {
    final d = item.dating;
    if (d == null || d.approx || d.disputed || d.to == null) return false;
    if (item.kind != HistoryItemKind.event) return false;
    return d.to! - d.from <= 2;
  }

  HistoryTask? _recall(HistoryItem item) {
    if (!_exactYear(item)) return null;
    final d = item.dating!;
    final bc = d.from < 0;
    final a = d.from.abs(), b = d.to!.abs();

    return HistoryYearTask(
      item: item,
      prompt: "In welchem Jahr${bc ? " v. Chr." : ""}?\n${item.timelessName}",
      min: a < b ? a : b,
      max: a < b ? b : a,
      beforeChrist: bc,
      explanation: _explanationOf(item),
      sources: _sourcesOf([item]),
      itemIds: [item.id],
    );
  }

  bool _spanPartner(HistoryItem a, HistoryItem b) =>
      _exactYear(b) &&
      a.trackId == b.trackId &&
      yearsBetween(a.dating!.from, b.dating!.from) >= 30;

  HistoryTask? _span(HistoryItem item, List<HistoryItem> pool, Random r) {
    if (!_exactYear(item)) return null;
    final partners = [
      for (final o in pool)
        if (o != item && _spanPartner(item, o)) o,
    ];
    if (partners.isEmpty) return null;
    final other = partners[r.nextInt(partners.length)];

    final years = yearsBetween(item.dating!.from, other.dating!.from);
    int round(num n) => (n / 10).round() * 10;
    final answer = round(years);

    final step = max(30, round(answer * 0.4));
    final candidates =
        <int>{
            answer + step,
            answer - step,
            answer + 2 * step,
            answer * 2,
            answer - 2 * step,
          }.map(round).where((n) => n > 0 && (n - answer).abs() >= 30).toList()
          ..shuffle(r);

    final distractors = <int>[];
    for (final c in candidates) {
      if (distractors.length >= 3) break;
      if (distractors.every((d) => (d - c).abs() >= 30)) distractors.add(c);
    }

    final mix = _mix("etwa $answer Jahre", [
      for (final d in distractors) "etwa $d Jahre",
    ], r);
    if (mix == null) return null;

    final sorted = sortChronologically([item, other]);

    return HistoryChoiceTask(
      skill: HistorySkill.span,
      prompt:
          "Wie viele Jahre liegen ungefähr zwischen diesen Ereignissen?\n"
          "${_q(sorted.first.timelessName)} und ${_q(sorted.last.timelessName)}",
      options: mix.options,
      correctIndex: mix.correct,
      cardIds: [cardId(item.id, HistorySkill.span)],
      explanation:
          "${sorted.first.dating!.label}: ${sorted.first.name}\n"
          "${sorted.last.dating!.label}: ${sorted.last.name}\n"
          "Abstand: $years Jahre"
          "${sorted.first.dating!.from < 0 && sorted.last.dating!.from > 0 ? " (ohne ein Jahr 0)" : ""}",
      sources: _sourcesOf(sorted),
      itemIds: [for (final s in sorted) s.id],
    );
  }

  HistoryTask? _explain(HistoryItem item) {
    final statements = item.courseStatements;
    if (statements.isEmpty) return null;

    final related = course.relatedOf(item.id);

    return HistoryExplainTask(
      item: item,
      prompt: switch (item.kind) {
        HistoryItemKind.person =>
          "Erkläre: Wer war ${item.name}, wann wirkte er bzw. sie, und womit "
              "ist die Person verbunden?",
        HistoryItemKind.period =>
          "Erkläre: Wann liegt ${_q(item.name)} und was kennzeichnet den "
              "Zeitraum?",
        _ =>
          "Erkläre: Was geschah bei ${_q(item.timelessName)}, wann, wer war beteiligt, "
              "und welche Bedeutung hat es?",
      },
      solution: [
        if (item.dating != null) "Zeit: ${item.dating!.label}",
        for (final s in statements) "${s.text} (${s.source})",
        if (item.consequence != null) "Folge: ${item.consequence!.text}",
        if (related.isNotEmpty)
          "Verbunden mit: ${related.map((r) => r.name).join(", ")}",
        if (item.significance != null &&
            !statements.any((s) => s.text.contains(item.significance!)))
          "Ergänzung: ${item.significance}",
      ],
      explanation: _explanationOf(item),
      sources: _sourcesOf([item]),
      itemIds: [item.id],
    );
  }
}
