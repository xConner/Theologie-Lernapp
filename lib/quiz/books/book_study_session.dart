import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../algorithms/spaced_repetition.dart';
import '../../services/book_learning_storage.dart';
import 'adaptive_study_queue.dart';
import 'book_catalog.dart';
import 'book_learning.dart';
import 'book_learning_status.dart';
import 'reference_answer.dart';

/// Ergebnis einer bewerteten Aufgabe.
class StudyResult {
  final StudyTask task;

  final bool correct;

  /// Die Eingabe bzw. gewählte Antwort in lesbarer Form.
  final String given;

  /// Die richtige Antwort in lesbarer Form.
  final String expected;

  /// Zusätzliche Erklärung (z. B. „Kapitel richtig, Verse falsch.“).
  final String? note;

  const StudyResult({
    required this.task,
    required this.correct,
    required this.given,
    required this.expected,
    this.note,
  });
}

/// Ablauf einer Lerneinheit: Aufgaben der Reihe nach, Bewertung und
/// Verbuchen des Lernstands.
///
/// Verbucht wird nur in die Karten von „Bücher systematisch lernen“; die
/// Karten des Endlos-Quiz bleiben unverändert. Reihenfolge-Aufgaben zählen
/// getrennt (siehe [BookLearningRules.recordOrder]).
///
/// Im Prüfungsmodus ([exam]) gibt es während der Bearbeitung keine Lösung;
/// die Ergebnisse stehen am Ende in [results].
class StudySession {
  final BookLearningState state;

  final BookLearningStorage storage;

  final List<StudyTask> tasks;

  final StudyMode mode;

  final SpacedRepetition algorithm;

  final List<StudyResult> results = [];

  int _index = 0;

  /// Bücher, die die Lerneinheit betrifft (in Buchreihenfolge).
  final List<String> contextBooks;

  /// Bildet die Aufgaben fortlaufend (Buch, Abschnitt, Kapitel); sonst
  /// steht die Folge in [tasks] von vornherein fest.
  final AdaptiveStudyQueue? queue;

  StudySession({
    required this.state,
    required this.storage,
    List<StudyTask> tasks = const [],
    required this.mode,
    this.queue,
    SpacedRepetition? algorithm,
  }) : tasks = [...tasks],
       algorithm = algorithm ?? SpacedRepetition(clock: state.clock),
       contextBooks = _booksOf(
         state,
         tasks,
         queue?.scope.map((p) => p.book) ?? const [],
       ) {
    _fill();
  }

  static List<String> _booksOf(
    BookLearningState state,
    List<StudyTask> tasks,
    Iterable<String> scopeBooks,
  ) {
    final books = {
      ...scopeBooks,
      for (final t in tasks)
        ...switch (t) {
          ArrangeTask() => t.ordered.map((p) => p.book),
          ChoiceTask() => [t.target.book, ...t.options.map((p) => p.book)],
          _ => [t.target.book],
        },
    };

    return [
      for (final b in state.catalog.books)
        if (books.contains(b)) b,
    ];
  }

  /// Der Buchkontext der Lerneinheit – die eine Quelle für Eingabefeld,
  /// Schnelleingabe, Validierung und Auswertung: Betrifft die Einheit genau
  /// ein Buch, ist es vorgegeben und es genügt die Kapitelangabe („5“);
  /// sonst muss die Eingabe das Buch nennen („Gen 5“).
  String? get contextBook =>
      contextBooks.length == 1 ? contextBooks.single : null;

  /// Warum sich [input] nicht bewerten lässt (siehe
  /// [ReferenceAnswerChecker.problem]); `null`, wenn die Eingabe bewertbar
  /// oder leer ist.
  String? inputProblem(String input) {
    return ReferenceAnswerChecker.problem(
      input,
      contextBook: contextBook,
      structure: state.catalog.structure,
    );
  }

  bool get exam => mode == StudyMode.exam;

  int get index => _index;

  bool get finished => _index >= tasks.length;

  StudyTask? get current => finished ? null : tasks[_index];

  /// Fortschritt der Einheit (0–1) und Beschriftung, z. B. „Abfrage 3 von
  /// 15“. Bei fortlaufend gebildeten Einheiten zählen nur Abfragen.
  double get progress {
    final q = queue;

    if (q == null) return tasks.isEmpty ? 1 : _index / tasks.length;

    return q.questions == 0 ? 1 : min(1.0, answered / q.questions);
  }

  String get progressLabel {
    final q = queue;

    if (q == null) return "Aufgabe ${_index + 1} von ${tasks.length}";

    if (current is IntroduceTask) {
      return "Einführung · ${q.asked} von ${q.questions} Abfragen erledigt";
    }

    if (q.lastWasRetry) return "Noch einmal nach einem Fehler";

    // Die aktuelle Abfrage ist die zuletzt ausgegebene.
    return "Abfrage ${q.asked} von ${q.questions}";
  }

  // Holt bei fortlaufenden Einheiten die nächste Aufgabe – erst nach der
  // vorigen Antwort, damit die Auswahl den neuen Stand kennt.
  void _fill() {
    final q = queue;

    if (q != null && _index >= tasks.length) {
      final next = q.next();

      if (next != null) tasks.add(next);
    }
  }

  /// Bewertete Aufgaben (Einführungen zählen nicht).
  int get answered => results.length;

  int get correctCount => results.where((r) => r.correct).length;

  List<StudyResult> get mistakes => [
    for (final r in results)
      if (!r.correct) r,
  ];

  void advance() {
    if (!finished) _index++;

    _fill();
  }

  /// Einführung gesehen: zählt nicht als Abruf, markiert die Perikope aber
  /// als begonnen (für die Tagesmenge des Lernplans).
  Future<void> completeIntroduction() async {
    final task = current;

    if (task is! IntroduceTask) return;

    final card = state.cardFor(task.target);

    card.introducedAt ??= state.now;

    await _save(card);
  }

  /// Getippte Antwort auf eine [RecallTask]. Vorher [inputProblem] prüfen:
  /// Nicht bewertbare Eingaben sollen nicht als Fehler zählen.
  Future<AnswerCheck> answerRecall(String input) async {
    final task = current as RecallTask;

    final expected = state.expectedOf(task.target);

    final check = ReferenceAnswerChecker.check(
      input,
      expected,
      contextBook: contextBook,
    );

    await _recordRecall(
      task,
      check.correct,
      given: check.given ?? input.trim(),
      note: check.correct && !check.versesIgnored ? null : check.message,
    );

    return check;
  }

  /// Selbsteinschätzung („Im Kopf“) einer [RecallTask].
  Future<void> assessRecall(bool knew) async {
    final task = current as RecallTask;

    await _recordRecall(task, knew, given: knew ? "gewusst" : "nicht gewusst");
  }

  Future<void> _recordRecall(
    RecallTask task,
    bool correct, {
    required String given,
    String? note,
  }) async {
    final card = state.cardFor(task.target);

    BookLearningRules.recordRecall(
      card,
      correct,
      algorithm,
      state.now,
      revealed: task.afterIntroduction,
    );

    results.add(
      StudyResult(
        task: task,
        correct: correct,
        given: given,
        expected: state.expectedOf(task.target).text,
        note: note,
      ),
    );

    await _save(card);
  }

  /// Auswahl bei einer [ChoiceTask].
  Future<bool> answerChoice(int option) async {
    final task = current as ChoiceTask;

    final chosen = task.options[option];

    final correct = chosen == task.target;

    String label(BookPericope p) =>
        task.kind == ChoiceKind.compare ? state.expectedOf(p).text : p.title;

    final card = state.cardFor(task.target);

    if (task.isOrder) {
      BookLearningRules.recordOrder(card, correct);
    } else {
      // Vergleich: Abruf mit Auswahlhilfe – zählt für die Wiederholung, aber
      // nie als freier, zeitlich getrennter Abruf.
      BookLearningRules.recordRecall(
        card,
        correct,
        algorithm,
        state.now,
        revealed: true,
      );
    }

    results.add(
      StudyResult(
        task: task,
        correct: correct,
        given: label(chosen),
        expected: label(task.target),
      ),
    );

    await _save(card);

    return correct;
  }

  /// Reihenfolge einer [ArrangeTask]; richtig nur, wenn alle Positionen
  /// stimmen.
  Future<bool> answerArrange(List<BookPericope> order) async {
    final task = current as ArrangeTask;

    bool correct = order.length == task.ordered.length;

    for (int i = 0; correct && i < order.length; i++) {
      if (order[i] != task.ordered[i]) correct = false;
    }

    final changed = <BookCard>[];

    for (int i = 0; i < task.ordered.length; i++) {
      final p = task.ordered[i];
      final card = state.cardFor(p);

      BookLearningRules.recordOrder(card, i < order.length && order[i] == p);

      changed.add(card);
    }

    results.add(
      StudyResult(
        task: task,
        correct: correct,
        given: order.map((p) => p.title).join(" → "),
        expected: task.ordered.map((p) => p.title).join(" → "),
      ),
    );

    await _saveAll(changed);

    return correct;
  }

  Future<void> _save(BookCard card) => _saveAll([card]);

  Future<void> _pending = Future.value();

  /// Wartet, bis alle bisherigen Speichervorgänge abgeschlossen sind.
  Future<void> flush() => _pending;

  // Nicht auf den Server warten (Firestore bestätigt offline erst später),
  // wie im Endlos-Quiz. Fehler werden protokolliert; der Lernstand bleibt im
  // Speicher und wird mit der nächsten Änderung derselben Karte geschrieben.
  Future<void> _saveAll(List<BookCard> cards) async {
    final save = storage.saveCards(cards).catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });

    _pending = Future.wait([_pending, save]);
  }
}
