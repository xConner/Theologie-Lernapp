import 'dart:math';

import '../../algorithms/review_state.dart';
import '../../models/history/history_course.dart';
import 'history_trainer.dart';

/// Ein Schritt eines Lernschritts: Einführung lesen oder eine Aufgabe.
sealed class LessonStep {
  const LessonStep();
}

/// Ein neuer Inhalt wird vorgestellt: Datierung, was die Veranstaltung
/// sagt, und womit er mit schon Gelerntem verbunden ist.
class LessonIntroStep extends LessonStep {
  final HistoryItem item;

  /// Schon gelernte Inhalte, mit denen [item] verknüpft ist.
  final List<HistoryItem> knownRelated;

  const LessonIntroStep(this.item, this.knownRelated);
}

enum LessonPhase {
  check("Gleich prüfen"),
  consolidate("Festigen"),
  connect("Verknüpfen");

  final String label;

  const LessonPhase(this.label);
}

class LessonTaskStep extends LessonStep {
  final HistoryTask task;
  final LessonPhase phase;

  /// Zweiter oder dritter Anlauf nach einem Fehler.
  final int attempt;

  const LessonTaskStep(this.task, this.phase, {this.attempt = 0});
}

/// Ablauf eines Lernschritts (nach dem Vorbild der Lernrunden unter „Texte
/// auswendig lernen“):
///
/// 1. Jeder neue Inhalt wird einzeln vorgestellt und gleich mit einer
///    einfachen Frage abgerufen (Einführungsfrage, Karte `…|h.intro`).
/// 2. Festigen: je Inhalt eine weitere Grundlagenaufgabe (Datierung,
///    Lebenszeit, Beteiligte innerhalb des Lernschritts).
/// 3. Verknüpfen: höchstens zwei Aufgaben, die das Neue mit schon
///    Gelerntem verbinden (Reihenfolge, Beteiligte, Folge in einer
///    Übersicht).
///
/// Falsch beantwortete Aufgaben kommen mit etwas Abstand wieder
/// (Einführungsfragen bis zu zweimal, andere einmal). Jede Antwort wird auf
/// den Karten verbucht; als eingeführt gilt ein Inhalt, sobald seine
/// Einführungsfrage beantwortet ist.
class HistoryLessonSession {
  final HistoryLesson lesson;
  final HistoryTrainer trainer;

  final List<LessonStep> _queue = [];

  /// Neue Inhalte (ohne schon eingeführte des Lernschritts).
  final List<HistoryItem> items;

  int correct = 0;
  int answered = 0;
  final Set<String> mistakes = {};

  HistoryLessonSession({
    required this.lesson,
    required this.trainer,
    required List<HistoryItem> known,
    Random? random,
  }) : items = trainer.course.itemsOfLesson(lesson) {
    final r = random ?? trainer.random;
    final course = trainer.course;
    final lessonIds = {for (final i in items) i.id};
    final knownItems = [
      for (final k in known)
        if (!lessonIds.contains(k.id)) k,
    ];
    final context = [...knownItems, ...items];

    // 1. Vorstellen und gleich abrufen.
    for (final item in items) {
      _queue.add(
        LessonIntroStep(item, [
          for (final rel in course.relatedOf(item.id))
            if (knownItems.contains(rel)) rel,
        ]),
      );
      final check = trainer.build(item, HistorySkill.intro, r, known: context);
      if (check != null) _queue.add(LessonTaskStep(check, LessonPhase.check));
    }

    // 2. Festigen: eine weitere Grundlage je Inhalt.
    for (final item in items) {
      for (final skill in _consolidation(item)) {
        if (!trainer.applies(item, skill, context)) continue;
        final task = trainer.build(item, skill, r, known: context);
        if (task == null || _sameAsIntro(task)) continue;
        _queue.add(LessonTaskStep(task, LessonPhase.consolidate));
        break;
      }
    }

    // 3. Verknüpfen mit Gelerntem (oder innerhalb des Lernschritts).
    final linked = <String>{};
    for (final item in items) {
      if (linked.length >= 2) break;
      final task = _link(item, knownItems, context, r);
      if (task == null) continue;
      // Dieselbe Verknüpfung nicht zweimal (z. B. beide Seiten eines Paars).
      final key = ([...task.itemIds]..sort()).join("+");
      if (!linked.add(key)) continue;
      _queue.add(LessonTaskStep(task, LessonPhase.connect));
    }
  }

  static List<HistorySkill> _consolidation(HistoryItem item) =>
      switch (item.kind) {
        HistoryItemKind.person => [HistorySkill.life, HistorySkill.deed],
        HistoryItemKind.event => [
          HistorySkill.when,
          HistorySkill.effect,
          HistorySkill.actor,
        ],
        HistoryItemKind.group => [HistorySkill.deed],
        HistoryItemKind.period => [HistorySkill.year],
      };

  bool _sameAsIntro(HistoryTask task) => task.skill == HistorySkill.intro;

  HistoryTask? _link(
    HistoryItem item,
    List<HistoryItem> known,
    List<HistoryItem> context,
    Random r,
  ) {
    final course = trainer.course;

    // Folge in einer Übersicht, wenn der Nachbar schon bekannt ist.
    for (final s in course.sequences) {
      final next = s.next(item.id);
      final previous = s.itemIds.indexOf(item.id) > 0
          ? s.itemIds[s.itemIds.indexOf(item.id) - 1]
          : null;
      final prevItem = previous == null ? null : course.item(previous);
      if (prevItem != null && known.contains(prevItem)) {
        return trainer.nextInSequence(s, prevItem, r);
      }
      if (next != null && known.any((k) => k.id == next)) {
        return trainer.nextInSequence(s, item, r);
      }
    }

    // Reihenfolge mit einem bekannten (sonst einem neuen) Inhalt.
    final partners = known.isNotEmpty ? known : context;
    if (trainer.applies(item, HistorySkill.chrono, partners)) {
      final pair = trainer.chronology(item, partners, 1, r);
      if (pair != null) return pair;
    }

    return null;
  }

  LessonStep? get current => _queue.isEmpty ? null : _queue.first;

  bool get isFinished => _queue.isEmpty;

  /// Noch offene Schritte (für die Fortschrittsanzeige).
  int get remaining => _queue.length;

  /// Einführung gelesen.
  void advance() {
    if (_queue.isNotEmpty && _queue.first is LessonIntroStep) {
      _queue.removeAt(0);
    }
  }

  /// Ergebnis der aktuellen Aufgabe (bereits verbucht). Falsche Antworten
  /// kommen mit etwas Abstand wieder.
  void complete(bool ok) {
    if (_queue.isEmpty || _queue.first is! LessonTaskStep) return;
    final step = _queue.removeAt(0) as LessonTaskStep;

    if (step.attempt == 0) {
      answered++;
      if (ok) correct++;
    }

    if (ok) return;

    mistakes.addAll(step.task.itemIds);
    final retries = step.phase == LessonPhase.check ? 2 : 1;
    if (step.attempt >= retries) return;

    final gap = min(2, _queue.length);
    _queue.insert(
      gap,
      LessonTaskStep(step.task, step.phase, attempt: step.attempt + 1),
    );
  }
}

/// Stand eines Lernschritts, nur aus den Karten abgeleitet.
enum LessonStatus {
  fresh("Neu"),
  started("Begonnen"),
  introduced("Eingeführt");

  final String label;

  const LessonStatus(this.label);
}

/// Fortschritt eines Lernschritts bzw. des Lernpfads – ohne Punkte oder
/// Behauptungen über Beherrschung: eingeführte Inhalte und der Stand ihrer
/// Karten („Zum Wiederholen“, „Zuletzt sicher“).
class HistoryLessonProgress {
  final int total;
  final int introduced;
  final ProgressSummary cards;

  const HistoryLessonProgress({
    required this.total,
    required this.introduced,
    required this.cards,
  });

  LessonStatus get status => introduced == 0
      ? LessonStatus.fresh
      : introduced < total
      ? LessonStatus.started
      : LessonStatus.introduced;

  static HistoryLessonProgress of(
    HistoryTrainer trainer,
    Iterable<HistoryItem> items,
  ) {
    final list = items.toList();
    final ids = <String>[
      for (final i in list)
        if (trainer.isIntroduced(i.id)) ...trainer.cardsOf(i.id),
    ];
    return HistoryLessonProgress(
      total: list.length,
      introduced: list.where((i) => trainer.isIntroduced(i.id)).length,
      cards: ProgressSummary.of(
        ids,
        trainer.book.cards,
        trainer.book.algorithm,
      ),
    );
  }
}
