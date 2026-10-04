import 'dart:math' as math;

import '../../models/memorization/memorization_card.dart';
import 'hint_generator.dart';
import 'memorization_scheduler.dart';
import 'text_evaluator.dart';

/// Eine Lernrunde: eine Warteschlange von Übungen, die sich aus den
/// Ergebnissen weiterentwickelt.
///
///   * Ein Abschnitt bleibt in der Runde, bis er frei wiedergegeben wurde –
///     nach einem Fehler, bis er wieder bestätigt ist; dazwischen liegen
///     nach Möglichkeit andere Übungen.
///   * Ist ein in dieser Runde erarbeiteter Abschnitt frei gelungen, folgt
///     die Verbindung mit den vorangehenden gelernten Abschnitten.
///   * Fehler in einer Verbindung bringen die betroffenen Abschnitte einzeln
///     zurück, danach einmal die Verbindung.
///   * Sind alle Abschnitte eines Textes gelernt, steht am Ende der ganze
///     Text.
class MemorizationSession {
  /// Schutz vor Endlosschleifen: so oft kommt eine Übung höchstens wieder.
  static const int maxRepeats = 8;

  final MemorizationScheduler scheduler;
  final Map<String, MemorizationCard> cards;

  final List<PracticeUnit> _queue;

  final Map<String, int> _repeats = {};

  /// Abschnitte, die in dieser Runde mit Hilfen oder nach einem Fehler
  /// geübt wurden.
  final Set<String> _worked = {};

  final Set<String> _chained = {};

  /// IDs aller Abschnitte, die in der Runde vorkamen (für den Rückblick).
  final Set<String> touched = {};

  MemorizationSession({
    required this.scheduler,
    required this.cards,
    required List<PracticeUnit> units,
  }) : _queue = List.of(units) {
    // Schon geplante Verbindungen werden nicht ein zweites Mal angehängt.
    _chained.addAll(
      units.where((u) => u.kind != UnitKind.segment).map((u) => u.key),
    );
  }

  PracticeUnit? get current => _queue.isEmpty ? null : _queue.first;

  bool get isFinished => _queue.isEmpty;

  int get remaining => _queue.length;

  /// Überspringt die aktuelle Übung ohne Bewertung.
  void skip() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
    }
  }

  /// Verbucht das Ergebnis der aktuellen Übung, plant die Folgeübungen und
  /// liefert die geänderten Karten zum Speichern.
  List<MemorizationCard> complete({
    required HintLevel practiced,
    required RecallOutcome outcome,
    Set<int> errorSegments = const {},
  }) {
    final unit = _queue.removeAt(0);

    final changed = scheduler.apply(
      unit: unit,
      practiced: practiced,
      outcome: outcome,
      cards: cards,
      errorSegments: errorSegments,
    );

    touched.addAll(unit.segments.map((s) => s.id));

    final mastered =
        practiced == HintLevel.free && outcome == RecallOutcome.correct;

    if (unit.kind == UnitKind.segment) {
      _afterSegment(unit, practiced, mastered);
    } else {
      _afterCombined(unit, practiced, outcome, mastered, errorSegments);
    }

    return changed;
  }

  void _afterSegment(PracticeUnit unit, HintLevel practiced, bool mastered) {
    final id = unit.text.segments[unit.from].id;

    // Nach einem Fehler reicht eine einzelne gelungene Wiedergabe nicht:
    // Der Abschnitt kommt wieder, bis er bestätigt ist.
    if (!mastered || (cards[id]?.relearn ?? 0) > 0) {
      _worked.add(id);

      // Nach dem Mitlesen direkt weiter, sonst mit etwas Abstand.
      final gap = practiced == HintLevel.read ? 1 : 2;

      // Nicht hinter eine wartende Verbindung, die den Abschnitt enthält.
      final blocking = _queue.indexWhere(
        (u) =>
            u.kind != UnitKind.segment &&
            u.text.id == unit.text.id &&
            u.from <= unit.from &&
            unit.from <= u.to,
      );

      _requeue(
        PracticeUnit.segment(unit.text, unit.from, _cardLevel(id)),
        gap: blocking >= 0 ? math.min(gap, blocking) : gap,
      );
      return;
    }

    if (!_worked.contains(id)) {
      // Routine-Wiederholung: keine zusätzliche Verbindungsübung.
      return;
    }

    final chain = scheduler.chainEndingAt(unit.text, unit.from, cards);

    if (chain != null && _chained.add(chain.key)) {
      _queue.insert(0, chain);
    } else {
      _queueFullIfReady(unit);
    }
  }

  void _afterCombined(
    PracticeUnit unit,
    HintLevel practiced,
    RecallOutcome outcome,
    bool mastered,
    Set<int> errorSegments,
  ) {
    if (mastered) {
      if (unit.kind == UnitKind.chain) {
        _queueFullIfReady(unit);
      }
      return;
    }

    // Mit Hilfen geübt: bei Erfolg eine Stufe weiter, sonst noch einmal.
    if (practiced != HintLevel.free) {
      final next = outcome == RecallOutcome.correct
          ? HintLevel.values[practiced.index + 1]
          : practiced;

      _requeue(unit.withLevel(next), gap: 0);
      return;
    }

    var position = 0;

    for (var i = unit.from; i <= unit.to; i++) {
      if (!errorSegments.contains(i)) continue;

      final id = unit.text.segments[i].id;

      _worked.add(id);

      if (_bump("${unit.text.id}:$i-$i")) {
        _queue.insert(
          position++,
          PracticeUnit.segment(unit.text, i, _cardLevel(id)),
        );
      }
    }

    if (unit.kind == UnitKind.chain && !unit.retry) {
      _queue.insert(position, unit.withLevel(HintLevel.free, retry: true));
    }
  }

  /// Hängt das Aufsagen des ganzen Textes an, sobald alle Abschnitte gelernt
  /// sind und es noch nie stattgefunden hat.
  void _queueFullIfReady(PracticeUnit unit) {
    final text = unit.text;

    if (text.segments.length < 2) return;
    if (cards[text.fullCardId]?.lastReviewed != null) return;

    final allLearned = text.segments.every(
      (s) => cards[s.id]?.learned ?? false,
    );

    if (!allLearned) return;

    final full = scheduler.fullUnit(text);

    final queued = _queue.any((u) => u.key == full.key);

    if (!queued && _chained.add(full.key)) {
      _queue.add(full);
    }
  }

  void _requeue(PracticeUnit unit, {required int gap}) {
    if (_bump(unit.key)) {
      _queue.insert(math.min(gap, _queue.length), unit);
    }
  }

  bool _bump(String key) {
    final count = (_repeats[key] ?? 0) + 1;

    _repeats[key] = count;

    return count <= maxRepeats;
  }

  HintLevel _cardLevel(String id) {
    final level = cards[id]?.level ?? 0;

    return HintLevel.values[level.clamp(0, MemorizationCard.maxLevel)];
  }
}
