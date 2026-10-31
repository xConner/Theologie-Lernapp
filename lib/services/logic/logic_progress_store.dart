import 'package:cloud_firestore/cloud_firestore.dart';

import '../local_learning_store.dart';
import 'proof_draft.dart';

/// Stand einer Lektion. „Bearbeitet“ setzt man selbst – es heißt nicht,
/// dass der Stoff sicher beherrscht wird.
class LessonProgress {
  final DateTime? opened;
  final DateTime? done;

  const LessonProgress({this.opened, this.done});

  bool get isDone => done != null;
  bool get isStarted => opened != null || done != null;

  static LessonProgress fromJson(Object? raw) {
    if (raw is! Map) return const LessonProgress();
    return LessonProgress(
      opened: _time(raw["opened"]),
      done: _time(raw["done"]),
    );
  }
}

/// Antworten zu einer Übung (bzw. einer Art erzeugter Übungen).
class TaskProgress {
  final int correct;
  final int wrong;

  /// Ergebnis der letzten Antwort.
  final bool? lastCorrect;

  final DateTime? at;

  const TaskProgress({
    this.correct = 0,
    this.wrong = 0,
    this.lastCorrect,
    this.at,
  });

  int get attempts => correct + wrong;

  static TaskProgress fromJson(Object? raw) {
    if (raw is! Map) return const TaskProgress();
    final last = raw["last"];
    return TaskProgress(
      correct: (raw["c"] as num?)?.toInt() ?? 0,
      wrong: (raw["w"] as num?)?.toInt() ?? 0,
      lastCorrect: last is bool ? last : null,
      at: _time(raw["at"]),
    );
  }

  TaskProgress record(bool ok, DateTime now) => TaskProgress(
    correct: correct + (ok ? 1 : 0),
    wrong: wrong + (ok ? 0 : 1),
    lastCorrect: ok,
    at: now,
  );

  Map<String, dynamic> toJson() => {
    "c": correct,
    "w": wrong,
    if (lastCorrect != null) "last": lastCorrect,
    if (at != null) "at": at!.millisecondsSinceEpoch,
  };
}

DateTime? _time(Object? raw) {
  if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  if (raw is Timestamp) return raw.toDate();
  return null;
}

/// Gespeicherter Fortschritt im Lernbereich „Einführung in die Logik“.
class LogicProgress {
  /// Lektion-ID → Stand.
  final Map<String, LessonProgress> lessons;

  /// Übungs-ID → Antworten (Kurs- und Zusatzübungen mit stabiler ID).
  final Map<String, TaskProgress> tasks;

  /// „Lektion:Art“ → Antworten auf erzeugte Übungen.
  final Map<String, TaskProgress> generated;

  /// Übungs-ID → zuletzt
  /// bearbeiteter Beweis samt Reihenfolge der Zeilen.
  final Map<String, ProofDraft> proofs;

  const LogicProgress({
    this.lessons = const {},
    this.tasks = const {},
    this.generated = const {},
    this.proofs = const {},
  });

  factory LogicProgress.fromJson(Map<String, dynamic>? doc) {
    Map<String, T> read<T>(String field, T Function(Object?) parse) {
      final raw = doc?[field];
      if (raw is! Map) return {};
      return {for (final e in raw.entries) e.key.toString(): parse(e.value)};
    }

    return LogicProgress(
      lessons: read("lessons", LessonProgress.fromJson),
      tasks: read("tasks", TaskProgress.fromJson),
      generated: read("generated", TaskProgress.fromJson),
      proofs: {
        for (final e in read("proofs", ProofDraft.fromJson).entries)
          if (e.value != null) e.key: e.value!,
      },
    );
  }

  LessonProgress lesson(String id) => lessons[id] ?? const LessonProgress();

  TaskProgress task(String id) => tasks[id] ?? const TaskProgress();

  ProofDraft? proof(String key) => proofs[key];
}

/// Speicherort des Logik-Fortschritts.
///
/// Kein neues Speichersystem: angemeldete Nutzer speichern im Dokument
/// `users/{uid}/quiz_settings/logic_course` (dieselbe, bereits freigegebene
/// Collection wie „Bücher systematisch lernen“), Gäste lokal über den
/// [LocalLearningStore]. Struktur:
///
/// ```text
/// lessons:   {lessonId: {opened: ms, done: ms}}
/// tasks:     {exerciseId: {c: richtig, w: falsch, last: bool, at: ms}}
/// generated: {"lessonId:art": {c, w, last, at}}
/// proofs:    {key: {lines: [{id, rule, f, r, d, c}], at: ms}}
/// ```
///
/// `proofs` hält den zuletzt bearbeiteten Beweis je Übung (Zeilen mit
/// stabiler ID in ihrer Reihenfolge). Ältere Dokumente ohne dieses Feld
/// bleiben gültig.
///
/// Zurückgesetzt wird über `ProgressArea.logic` (Einstellungen).
abstract class LogicProgressStore {
  Future<LogicProgress> load();

  Future<void> markOpened(String lessonId);

  Future<void> setDone(String lessonId, bool done);

  Future<void> recordTask(String exerciseId, bool correct);

  Future<void> recordGenerated(String key, bool correct);

  /// Speichert den Beweis unter [key]; null entfernt ihn.
  Future<void> saveProof(String key, ProofDraft? draft);

  factory LogicProgressStore.forUser(String? uid) => uid == null
      ? LocalLogicProgressStore()
      : FirestoreLogicProgressStore(uid);
}

class LocalLogicProgressStore implements LogicProgressStore {
  LocalLearningStore get _store => LocalLearningStore.instance;

  static const String _doc = LocalLearningStore.logicCourse;

  @override
  Future<LogicProgress> load() async =>
      LogicProgress.fromJson(await _store.loadQuizDocument(_doc));

  Future<Map<String, dynamic>> _entry(String field, String key) async {
    final doc = await _store.loadQuizDocument(_doc);
    final raw = doc[field];
    final value = raw is Map ? raw[key] : null;
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  @override
  Future<void> markOpened(String lessonId) async {
    final entry = await _entry("lessons", lessonId);
    if (entry["opened"] != null) return;
    entry["opened"] = DateTime.now().millisecondsSinceEpoch;
    await _store.mergeQuizDocument(_doc, "lessons", {lessonId: entry});
  }

  @override
  Future<void> setDone(String lessonId, bool done) async {
    final entry = await _entry("lessons", lessonId);
    final now = DateTime.now().millisecondsSinceEpoch;
    entry["opened"] ??= now;
    if (done) {
      entry["done"] = now;
    } else {
      entry.remove("done");
    }
    await _store.mergeQuizDocument(_doc, "lessons", {lessonId: entry});
  }

  Future<void> _record(String field, String key, bool correct) async {
    final current = TaskProgress.fromJson(await _entry(field, key));
    await _store.mergeQuizDocument(_doc, field, {
      key: current.record(correct, DateTime.now()).toJson(),
    });
  }

  @override
  Future<void> recordTask(String exerciseId, bool correct) =>
      _record("tasks", exerciseId, correct);

  @override
  Future<void> recordGenerated(String key, bool correct) =>
      _record("generated", key, correct);

  @override
  Future<void> saveProof(String key, ProofDraft? draft) =>
      _store.mergeQuizDocument(_doc, "proofs", {key: draft?.toJson()});
}

class FirestoreLogicProgressStore implements LogicProgressStore {
  final String uid;

  FirestoreLogicProgressStore(this.uid);

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .collection("quiz_settings")
      .doc(LocalLearningStore.logicCourse);

  @override
  Future<LogicProgress> load() async =>
      LogicProgress.fromJson((await _doc.get()).data());

  @override
  Future<void> markOpened(String lessonId) async {
    final current = await load();
    if (current.lesson(lessonId).isStarted) return;
    await _doc.set({
      "lessons": {
        lessonId: {"opened": DateTime.now().millisecondsSinceEpoch},
      },
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setDone(String lessonId, bool done) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _doc.set({
      "lessons": {
        lessonId: {"done": done ? now : FieldValue.delete()},
      },
    }, SetOptions(merge: true));
  }

  Future<void> _record(String field, String key, bool correct) {
    return _doc.set({
      field: {
        key: {
          correct ? "c" : "w": FieldValue.increment(1),
          "last": correct,
          "at": DateTime.now().millisecondsSinceEpoch,
        },
      },
    }, SetOptions(merge: true));
  }

  @override
  Future<void> recordTask(String exerciseId, bool correct) =>
      _record("tasks", exerciseId, correct);

  @override
  Future<void> recordGenerated(String key, bool correct) =>
      _record("generated", key, correct);

  @override
  Future<void> saveProof(String key, ProofDraft? draft) => _doc.set({
    "proofs": {key: draft == null ? FieldValue.delete() : draft.toJson()},
  }, SetOptions(merge: true));
}
