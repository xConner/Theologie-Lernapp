import 'logic_exercise.dart';
import 'lesson_text.dart';

/// Der Lernbereich „Einführung in die Logik“: Lektionen mit Lehrtext,
/// Kursübungen und Zusatzübungen. Inhalte liegen getrennt von der Oberfläche
/// unter `assets/logic/` (siehe docs/logic-course.md).
class LogicCourse {
  final String id;
  final String title;
  final String description;

  /// Einführung („Worum es geht“), als Lehrtext.
  final List<LessonSection> introduction;

  final List<LogicLesson> lessons;

  /// Übungsklausur (Beweisaufgaben nach dem Regelblatt).
  final LogicMockExam? exam;

  const LogicCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.introduction,
    required this.lessons,
    this.exam,
  });

  LogicLesson? lesson(String id) =>
      lessons.where((l) => l.id == id).firstOrNull;

  /// Alle Kursübungen mit stabiler ID (für Fortschritt und Wiederholung).
  Iterable<LogicExercise> get allExercises => [
    for (final l in lessons) ...l.exercises,
    ...?exam?.tasks,
  ];

  LogicExercise? exercise(String id) =>
      allExercises.where((e) => e.id == id).firstOrNull;

  /// Lektion, zu der eine Übung gehört (Klausuraufgaben: null).
  LogicLesson? lessonOf(String exerciseId) => lessons
      .where((l) => l.exercises.any((e) => e.id == exerciseId))
      .firstOrNull;
}

class LogicLesson {
  /// Stabile ID, z. B. `l1` – wird mit dem Lernfortschritt gespeichert.
  final String id;

  final int number;
  final String title;

  /// Kapitel des Kurses, z. B. „Aussagenlogische Beweise I“.
  final String chapter;

  final List<String> goals;

  /// IDs der Lektionen, deren Inhalte vorausgesetzt werden.
  final List<String> prerequisites;

  /// Typische Fehler und Missverständnisse.
  final List<String> pitfalls;

  /// Argumente, die in Beweisen dieser Lektion zur Verfügung stehen
  /// (`ProofSystem.id`), oder null ohne Beweise.
  final String? proofSystem;

  /// Arten von Zusatzübungen, die erzeugt werden können.
  final List<String> generators;

  final List<LessonSection> sections;
  final List<LogicExercise> exercises;

  /// Weiterführende Literatur (allgemein, ohne Seitenangaben).
  final List<String> literature;

  const LogicLesson({
    required this.id,
    required this.number,
    required this.title,
    required this.chapter,
    required this.goals,
    required this.prerequisites,
    required this.pitfalls,
    required this.proofSystem,
    required this.generators,
    required this.sections,
    required this.exercises,
    this.literature = const [],
  });
}

class LogicMockExam {
  final String title;
  final List<LessonSection> instructions;
  final String proofSystem;

  /// Wie viele der Aufgaben in der Klausur bearbeitet werden.
  final int choose;

  final int minutes;
  final List<LogicExercise> tasks;

  const LogicMockExam({
    required this.title,
    required this.instructions,
    required this.proofSystem,
    required this.choose,
    required this.minutes,
    required this.tasks,
  });
}
