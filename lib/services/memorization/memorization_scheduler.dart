import 'dart:math' as math;

import '../../algorithms/spaced_repetition.dart';
import '../../models/memorization/memorization_card.dart';
import '../../models/memorization/memorization_text.dart';
import 'hint_generator.dart';
import 'text_evaluator.dart';

/// Lernstand eines Abschnitts in verständlichen Stufen.
enum SegmentStatus {
  /// Noch nicht begonnen.
  fresh,

  /// Begonnen, aber noch nie frei wiedergegeben.
  learning,

  /// Gelernt, nach einem Fehler aber noch nicht wieder bestätigt.
  shaky,

  /// Frei wiedergegeben; der Wiederholungsabstand liegt noch unter einem Tag.
  recent,

  /// Gelernt, mit einem Wiederholungsabstand von mindestens einem Tag.
  stable,

  /// Über Wochen hinweg an verschiedenen Tagen sicher wiedergegeben.
  secure,
}

extension SegmentStatusLabel on SegmentStatus {
  String get label {
    switch (this) {
      case SegmentStatus.fresh:
        return "Neu";
      case SegmentStatus.learning:
        return "In Arbeit";
      case SegmentStatus.shaky:
        return "Unsicher";
      case SegmentStatus.recent:
        return "Frisch gelernt";
      case SegmentStatus.stable:
        return "Gefestigt";
      case SegmentStatus.secure:
        return "Langfristig sicher";
    }
  }
}

enum UnitKind {
  /// Ein einzelner Abschnitt.
  segment,

  /// Mehrere aufeinanderfolgende Abschnitte (Übergänge üben).
  chain,

  /// Der gesamte Text.
  full,
}

/// Eine Übung: die Abschnitte [from]–[to] eines Textes auf einer Hilfestufe.
class PracticeUnit {
  final MemorizationText text;
  final int from;
  final int to;
  final UnitKind kind;

  /// Vorgeschlagene Hilfestufe; der Nutzer kann sie jederzeit wechseln.
  final HintLevel level;

  /// Zweiter Anlauf einer Verbindungsübung (wird nicht nochmals angehängt).
  final bool retry;

  const PracticeUnit({
    required this.text,
    required this.from,
    required this.to,
    required this.kind,
    required this.level,
    this.retry = false,
  });

  PracticeUnit.segment(this.text, int index, this.level)
    : from = index,
      to = index,
      kind = UnitKind.segment,
      retry = false;

  List<MemorizationSegment> get segments => text.segments.sublist(from, to + 1);

  String get key => "${text.id}:$from-$to";

  PracticeUnit withLevel(HintLevel level, {bool? retry}) {
    return PracticeUnit(
      text: text,
      from: from,
      to: to,
      kind: kind,
      level: level,
      retry: retry ?? this.retry,
    );
  }
}

/// Zusammenfassung des Lernstands eines Textes.
class TextProgress {
  final Map<SegmentStatus, int> counts;
  final int total;

  /// Letztes vollständiges Aufsagen (auch mit Fehlern); null = noch nie.
  final DateTime? lastFullRecitation;

  const TextProgress({
    required this.counts,
    required this.total,
    required this.lastFullRecitation,
  });

  int count(SegmentStatus status) => counts[status] ?? 0;

  int get learned =>
      count(SegmentStatus.shaky) +
      count(SegmentStatus.recent) +
      count(SegmentStatus.stable) +
      count(SegmentStatus.secure);

  double get fraction => total == 0 ? 0 : learned / total;

  bool get isComplete => total > 0 && learned == total;
}

/// Was für einen Text heute ansteht.
class TextPlan {
  final MemorizationText text;
  final List<PracticeUnit> units;

  /// Neue Abschnitte in [units].
  final int newSegments;

  /// Abschnitte in Arbeit und fällige Wiederholungen in [units].
  final int reviewSegments;

  /// Steht das Aufsagen des ganzen Textes an?
  final bool fullDue;

  const TextPlan({
    required this.text,
    required this.units,
    required this.newSegments,
    required this.reviewSegments,
    required this.fullDue,
  });

  bool get isEmpty => units.isEmpty;

  int get segmentCount => newSegments + reviewSegments;
}

/// Planung und Bewertung für „Texte auswendig lernen“ – reine Logik ohne UI und
/// Speicherzugriff.
///
/// Die Wiederholungsabstände führt die gemeinsame [SpacedRepetition]
/// (`stability` in Stunden). Sie wird nur bei freier Wiedergabe angewendet:
/// Übungen mit sichtbaren Hilfen verändern allein die Hilfestufe.
///
/// Jede Übung – tägliche Wiederholung, Schwachstellen, ein gezielt
/// gewählter Abschnitt, der ganze Text – wird über [apply] verbucht. Dabei
/// werden zwei Dinge getrennt geführt:
///
///   * Kurzfristig (`relearn`, `streak`): Nach einem Fehler ist der
///     Abschnitt unsicher, bis er wieder fehlerfrei frei wiedergegeben
///     wurde ([lapseSteps] bzw. [slipSteps] Mal). Das gelingt auch durch
///     mehrfaches Üben in einer Sitzung.
///   * Langfristig (`stability`): Der Abstand wächst nur mit der Zeit, die
///     zwischen zwei Wiedergaben vergangen ist. Mehrere richtige Antworten
///     kurz hintereinander verlängern ihn daher nicht; nach bestätigtem
///     Lernen steht die nächste Wiederholung frühestens nach
///     [minReviewHours] an.
class MemorizationScheduler {
  /// Neue Abschnitte je Text und Tag in der automatischen Auswahl.
  static const int dailyNew = 2;

  /// Höchstens so viele begonnene, noch nicht gelernte Abschnitte je Text,
  /// bevor weitere neue dazukommen.
  static const int maxOpen = 3;

  /// Längste Verbindungsübung (Abschnitte).
  static const int maxChain = 4;

  /// Fehlerfreie freie Wiedergaben, die nach einem Fehler nötig sind.
  static const int lapseSteps = 2;

  /// … nach einer kleinen Abweichung ([RecallOutcome.almost]).
  static const int slipSteps = 1;

  /// Kürzester Abstand (Stunden) eines gelernten, bestätigten Abschnitts:
  /// Er kommt am nächsten Tag wieder, nicht noch am selben.
  static const double minReviewHours = 16;

  /// Anteil des bisherigen Abstands, der einen Fehler übersteht. Wer einen
  /// lange sicheren Abschnitt vergisst, fängt nicht ganz von vorn an.
  static const double lapseRetention = 0.1;

  /// … eine kleine Abweichung.
  static const double slipRetention = 0.5;

  static const double _slipDifficulty = 0.25;

  static const double _stableHours = 24;
  static const double _secureHours = 24 * 21;

  /// Ab diesem Wert ([weakness]) zählt ein Abschnitt zu den Schwachstellen.
  static const double weakThreshold = 1.5;

  final SpacedRepetition srs;
  final DateTime Function() clock;

  MemorizationScheduler({DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      srs = SpacedRepetition(clock: clock);

  // ==========================
  // STATUS
  // ==========================

  SegmentStatus status(MemorizationCard? card) {
    if (card == null || !card.isStarted) {
      return SegmentStatus.fresh;
    }

    if (!card.learned) {
      return SegmentStatus.learning;
    }

    if (card.level < MemorizationCard.maxLevel || card.relearn > 0) {
      return SegmentStatus.shaky;
    }

    if (card.stability >= _secureHours) return SegmentStatus.secure;

    return card.stability >= _stableHours
        ? SegmentStatus.stable
        : SegmentStatus.recent;
  }

  /// Wie dringend ein gelernter Abschnitt zusätzliche Übung braucht
  /// (0 = gar nicht). Unsichere Abschnitte stehen immer vorn; sonst zählen
  /// ein kürzlicher Fehler (verblasst mit der Zeit und mit jeder
  /// fehlerfreien Wiedergabe), wiederholte Fehler und eine lange
  /// überfällige Wiederholung. Ein einzelner, längst ausgebügelter Fehler
  /// macht keinen Abschnitt dauerhaft zur Schwachstelle.
  double weakness(MemorizationCard? card) {
    if (card == null || !card.learned) return 0;

    if (status(card) == SegmentStatus.shaky) {
      return 10.0 + card.relearn + card.failures / 10;
    }

    var score = math.max(0.0, card.difficulty - 5) * 0.6;

    final lapse = card.lastLapse;

    if (lapse != null) {
      final days = math.max(0, clock().difference(lapse).inHours) / 24;

      score += 3 * math.exp(-days / 4) / (1 + card.streak);
    }

    if (card.failures >= 2) {
      score += 2 * card.failures / (card.failures + card.successes);
    }

    if (card.lastReviewed != null) {
      // Allein reicht das nicht: Überfällige stehen ohnehin im Tagesplan.
      score += (srs.timeFactor(card) - 1.5).clamp(0.0, 1.0).toDouble();
    }

    return score;
  }

  /// Zeitpunkt der nächsten Wiederholung; null vor der ersten freien
  /// Wiedergabe.
  DateTime? dueAt(MemorizationCard card) {
    final last = card.lastReviewed;

    if (last == null) return null;

    return last.add(Duration(minutes: (card.stability * 60).round()));
  }

  bool isDue(MemorizationCard card) {
    final due = dueAt(card);

    return due == null || !clock().isBefore(due);
  }

  TextProgress progress(
    MemorizationText text,
    Map<String, MemorizationCard> cards,
  ) {
    final counts = <SegmentStatus, int>{};

    for (final segment in text.segments) {
      final s = status(cards[segment.id]);
      counts[s] = (counts[s] ?? 0) + 1;
    }

    return TextProgress(
      counts: counts,
      total: text.segments.length,
      lastFullRecitation: cards[text.fullCardId]?.lastReviewed,
    );
  }

  // ==========================
  // PLANUNG
  // ==========================

  /// Was für [text] jetzt ansteht: zuerst Wiederholungen (benachbarte
  /// fällige Abschnitte gemeinsam), dann begonnene, dann neue Abschnitte in
  /// Textreihenfolge, zuletzt der ganze Text.
  ///
  /// [extraNew] nimmt zusätzliche neue Abschnitte über die Tagesmenge
  /// hinaus auf (ausdrücklicher Wunsch des Nutzers).
  TextPlan planFor(
    MemorizationText text,
    Map<String, MemorizationCard> cards, {
    int extraNew = 0,
  }) {
    final now = clock();

    final reviews = <PracticeUnit>[];
    final learning = <PracticeUnit>[];
    final freshIndices = <int>[];

    var reviewSegments = 0;
    var startedToday = 0;
    var allLearned = true;

    final group = <int>[];

    void flushGroup() {
      if (group.isEmpty) return;

      reviews.add(
        group.length == 1
            ? PracticeUnit.segment(text, group.first, HintLevel.free)
            : PracticeUnit(
                text: text,
                from: group.first,
                to: group.last,
                kind: UnitKind.chain,
                level: HintLevel.free,
              ),
      );

      group.clear();
    }

    for (var i = 0; i < text.segments.length; i++) {
      final card = cards[text.segments[i].id];
      final started = card?.startedAt;

      if (started != null && _sameDay(started, now)) {
        startedToday++;
      }

      switch (status(card)) {
        case SegmentStatus.fresh:
          allLearned = false;
          flushGroup();
          freshIndices.add(i);

        case SegmentStatus.learning:
          allLearned = false;
          flushGroup();
          learning.add(PracticeUnit.segment(text, i, _level(card!)));

        case SegmentStatus.shaky:
        case SegmentStatus.recent:
        case SegmentStatus.stable:
        case SegmentStatus.secure:
          if (card!.level < MemorizationCard.maxLevel || card.relearn > 0) {
            // Nach einem Fehler: einzeln, mit der passenden Hilfe – auch
            // wenn der Abschnitt zeitlich noch nicht wieder fällig wäre.
            flushGroup();
            reviews.add(PracticeUnit.segment(text, i, _level(card)));
            reviewSegments++;
          } else if (isDue(card)) {
            if (group.length == maxChain) flushGroup();
            group.add(i);
            reviewSegments++;
          } else {
            flushGroup();
          }
      }
    }

    flushGroup();

    final allowance =
        math.max(
          0,
          math.min(dailyNew - startedToday, maxOpen - learning.length),
        ) +
        extraNew;

    final fresh = [
      for (final i in freshIndices.take(allowance))
        PracticeUnit.segment(text, i, HintLevel.read),
    ];

    final fullCard = cards[text.fullCardId];

    final fullDue =
        allLearned &&
        text.segments.length > 1 &&
        (fullCard == null || isDue(fullCard));

    return TextPlan(
      text: text,
      units: [
        ...reviews,
        ...learning,
        ...fresh,
        if (fullDue) fullUnit(text),
      ],
      newSegments: fresh.length,
      reviewSegments: reviewSegments + learning.length,
      fullDue: fullDue,
    );
  }

  /// Abschnitte, die zusätzliche Übung am meisten brauchen ([weakness]),
  /// die dringendsten zuerst, jeweils auf ihrer aktuellen Hilfestufe.
  List<PracticeUnit> weakUnits(
    MemorizationText text,
    Map<String, MemorizationCard> cards,
  ) {
    final weak = [
      for (var i = 0; i < text.segments.length; i++)
        (i, weakness(cards[text.segments[i].id])),
    ].where((entry) => entry.$2 >= weakThreshold).toList();

    // Bei gleichem Wert in Textreihenfolge (List.sort ist nicht stabil).
    weak.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);

      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });

    return [
      for (final (i, _) in weak)
        PracticeUnit.segment(text, i, _level(cards[text.segments[i].id]!)),
    ];
  }

  PracticeUnit fullUnit(MemorizationText text) {
    return PracticeUnit(
      text: text,
      from: 0,
      to: text.segments.length - 1,
      kind: text.segments.length == 1 ? UnitKind.segment : UnitKind.full,
      level: HintLevel.free,
    );
  }

  /// Verbindungsübung, die mit Abschnitt [index] endet und die davor
  /// liegenden gelernten Abschnitte einschließt (A+B, dann A+B+C …);
  /// null, wenn es nichts zu verbinden gibt.
  PracticeUnit? chainEndingAt(
    MemorizationText text,
    int index,
    Map<String, MemorizationCard> cards,
  ) {
    var start = index;

    while (start > 0 &&
        index - start + 1 < maxChain &&
        (cards[text.segments[start - 1].id]?.learned ?? false)) {
      start--;
    }

    if (start == index) return null;

    final whole = start == 0 && index == text.segments.length - 1;

    return PracticeUnit(
      text: text,
      from: start,
      to: index,
      kind: whole ? UnitKind.full : UnitKind.chain,
      level: HintLevel.free,
    );
  }

  static HintLevel _level(MemorizationCard card) {
    return HintLevel.values[card.level.clamp(0, MemorizationCard.maxLevel)];
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ==========================
  // BEWERTUNG
  // ==========================

  /// Verbucht das Ergebnis einer Übung und liefert die geänderten Karten
  /// (zum Speichern). Fehlende Karten werden in [cards] angelegt.
  ///
  /// [practiced] ist die tatsächlich geübte Hilfestufe. [errorSegments]
  /// nennt bei verbundenen Abschnitten die Abschnitte (Index im Text) mit
  /// Abweichungen; ist die Menge bei einem Fehler leer, lässt sich der
  /// Fehler keinem Abschnitt zuordnen (Selbsteinschätzung).
  List<MemorizationCard> apply({
    required PracticeUnit unit,
    required HintLevel practiced,
    required RecallOutcome outcome,
    required Map<String, MemorizationCard> cards,
    Set<int> errorSegments = const {},
  }) {
    MemorizationCard cardOf(String id) {
      return cards.putIfAbsent(id, () => MemorizationCard(id: id));
    }

    if (unit.kind == UnitKind.segment) {
      final card = cardOf(unit.text.segments[unit.from].id);

      _applySegment(card, practiced, outcome);

      return [card];
    }

    // Verbundene Abschnitte zählen nur bei freier Wiedergabe.
    if (practiced != HintLevel.free) {
      return [];
    }

    final changed = <MemorizationCard>[];
    final correct = outcome == RecallOutcome.correct;

    if (correct || errorSegments.isNotEmpty) {
      for (var i = unit.from; i <= unit.to; i++) {
        final card = cardOf(unit.text.segments[i].id);

        if (!correct && errorSegments.contains(i)) {
          _lapse(card, outcome: RecallOutcome.almost);
        } else {
          _success(card);
        }

        changed.add(card);
      }
    }

    if (unit.kind == UnitKind.full) {
      final card = cardOf(unit.text.fullCardId);

      // Der ganze Text wird nach einem Fehler nicht mehrfach in Folge
      // verlangt; die betroffenen Abschnitte tragen das Nachlernen.
      if (correct) {
        _success(card);
      } else {
        _lapse(card, outcome: outcome, relearn: false);
      }

      changed.add(card);
    }

    return changed;
  }

  void _applySegment(
    MemorizationCard card,
    HintLevel practiced,
    RecallOutcome outcome,
  ) {
    final base = practiced.index;

    if (practiced == HintLevel.read) {
      card.startedAt ??= clock();
      card.level = math.max(card.level, 1);
      return;
    }

    if (practiced == HintLevel.free) {
      if (outcome == RecallOutcome.correct) {
        _success(card);
      } else {
        _lapse(card, outcome: outcome);
      }
      return;
    }

    card.startedAt ??= clock();
    card.attempts++;

    switch (outcome) {
      case RecallOutcome.correct:
        card.level = math.min(
          MemorizationCard.maxLevel,
          math.max(card.level, base + 1),
        );

      case RecallOutcome.almost:
        card.level = math.max(card.level, base);

      case RecallOutcome.incorrect:
        // Wer freiwillig eine leichtere Stufe übt, wird nicht zurückgestuft.
        if (card.level <= base) {
          card.level = math.max(1, base - 1);
        }
    }
  }

  /// Fehlerfreie freie Wiedergabe.
  void _success(MemorizationCard card) {
    final wasLearned = card.learned;

    card.startedAt ??= clock();
    card.attempts++;
    card.successes++;
    card.streak++;
    card.learned = true;
    card.level = MemorizationCard.maxLevel;

    // Kurzfristig: ein Schritt des Nachlernens ist geschafft. Wer den
    // Abschnitt zum ersten Mal frei kann, hat nichts nachzuholen.
    card.relearn = wasLearned ? math.max(0, card.relearn - 1) : 0;

    // Langfristig: Der Abstand wächst mit der seit der letzten Wiedergabe
    // vergangenen Zeit – kurz hintereinander also praktisch nicht.
    srs.answer(card, true);

    if (card.relearn == 0) {
      card.stability = math.max(card.stability, minReviewHours);
    }
  }

  /// Fehler bei freier Wiedergabe: Der Abschnitt wird mit etwas mehr Hilfe
  /// neu aufgebaut und ist unsicher, bis er wieder fehlerfrei gelingt.
  ///
  /// Eine kleine Abweichung ([RecallOutcome.almost]) kostet nur einen Teil
  /// des Abstands und eine Bestätigung; echtes Vergessen setzt den Abstand
  /// weit zurück und verlangt mehrere.
  void _lapse(
    MemorizationCard card, {
    required RecallOutcome outcome,
    bool relearn = true,
  }) {
    final slip = outcome == RecallOutcome.almost;
    final previous = card.stability;

    card.startedAt ??= clock();
    card.attempts++;
    card.failures++;
    card.streak = 0;
    card.lastLapse = clock();
    card.level = math.min(
      card.level,
      slip ? HintLevel.minimal.index : HintLevel.firstLetters.index,
    );

    if (relearn) {
      card.relearn = math.max(card.relearn, slip ? slipSteps : lapseSteps);
    }

    if (slip) {
      card.difficulty = (card.difficulty + _slipDifficulty)
          .clamp(1, 10)
          .toDouble();
      card.lastReviewed = clock();
    } else {
      srs.answer(card, false);
    }

    // Was vorher langfristig saß, ist nicht vollständig verloren.
    if (card.learned) {
      card.stability = math.max(
        slip ? srs.minStability : card.stability,
        previous * (slip ? slipRetention : lapseRetention),
      );
    }
  }
}
