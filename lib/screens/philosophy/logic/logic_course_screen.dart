import 'package:flutter/material.dart';

import '../../../info/app_info.dart';
import '../../../models/logic/lesson_text.dart';
import '../../../models/logic/logic_course.dart';
import '../../../models/logic/logic_exercise.dart';
import '../../../services/logic/logic_course_loader.dart';
import '../../../services/logic/logic_progress_store.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_report.dart';
import '../../../widgets/logic/lesson_blocks.dart';
import 'logic_exercise_screen.dart';
import 'logic_lesson_screen.dart';

/// Übersicht des Lernbereichs „Einführung in die Logik“: Lektionen mit
/// Fortschritt, Einführung, Regelübersicht, Wiederholung, Übungsklausur.
class LogicCourseScreen extends StatefulWidget {
  // null = Gastmodus (lokale Speicherung).
  final String? uid;

  /// Für Tests: eigener Inhalt und Speicher.
  final Future<LogicCourse> Function()? loadCourse;
  final LogicProgressStore? store;

  const LogicCourseScreen({
    super.key,
    required this.uid,
    this.loadCourse,
    this.store,
  });

  @override
  State<LogicCourseScreen> createState() => _LogicCourseScreenState();
}

class _LogicCourseScreenState extends State<LogicCourseScreen> {
  late final LogicProgressStore store =
      widget.store ?? LogicProgressStore.forUser(widget.uid);

  LogicCourse? course;
  LogicProgress progress = const LogicProgress();
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await (widget.loadCourse?.call() ?? LogicCourseLoader.load());
      final p = await _loadProgress();
      if (!mounted) return;
      setState(() {
        course = c;
        progress = p;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<LogicProgress> _loadProgress() async {
    try {
      return await store.load();
    } catch (_) {
      // Ohne Verbindung: Inhalte trotzdem zeigen.
      return const LogicProgress();
    }
  }

  Future<void> _refresh() async {
    final p = await _loadProgress();
    if (mounted) setState(() => progress = p);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = course;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Einführung in die Logik"),
        actions: const [InfoButton(module: AppModules.logic)],
      ),
      body: error != null
          ? const Center(child: Text("Die Inhalte konnten nicht geladen werden."))
          : c == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(c.description, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    _actions(context, c),
                    const SizedBox(height: 16),
                    Text("Lektionen", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    for (final lesson in c.lessons) _lessonCard(context, c, lesson),
                    const SizedBox(height: 12),
                    const InfoReportFooter(module: AppModules.logic),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _actions(BuildContext context, LogicCourse c) {
    final wrong = [
      for (final e in c.allExercises)
        if (e.id != null && progress.task(e.id!).lastCorrect == false) e,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey("logic-intro"),
          onPressed: () => _open(
            LogicTextScreen(title: "Worum es geht", sections: c.introduction),
          ),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text("Worum es geht"),
        ),
        OutlinedButton.icon(
          key: const ValueKey("logic-rules"),
          onPressed: () => _open(LogicRulesScreen(course: c)),
          icon: const Icon(Icons.rule_rounded, size: 18),
          label: const Text("Regelübersicht"),
        ),
        OutlinedButton.icon(
          key: const ValueKey("logic-review"),
          onPressed: wrong.isEmpty
              ? null
              : () => _open(
                  LogicExerciseScreen(
                    title: "Wiederholen",
                    exercises: wrong,
                    store: store,
                  ),
                ),
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: Text(
            wrong.isEmpty ? "Wiederholen" : "Wiederholen (${wrong.length})",
          ),
        ),
        if (c.exam != null)
          OutlinedButton.icon(
            key: const ValueKey("logic-exam"),
            onPressed: () => _open(LogicExamScreen(exam: c.exam!, store: store)),
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: Text(c.exam!.title),
          ),
      ],
    );
  }

  Widget _lessonCard(BuildContext context, LogicCourse c, LogicLesson lesson) {
    final colors = context.colors;
    final state = progress.lesson(lesson.id);
    final ids = [for (final e in lesson.exercises) if (e.id != null) e.id!];
    final answered = ids.where((id) => progress.task(id).attempts > 0).length;
    final right = ids.where((id) => progress.task(id).lastCorrect == true).length;
    final wrong = ids.where((id) => progress.task(id).lastCorrect == false).length;

    final (String label, Color color, IconData icon) = state.isDone
        ? ("als bearbeitet markiert", colors.success, Icons.check_circle_outline_rounded)
        : state.isStarted
        ? ("begonnen", colors.primary, Icons.timelapse_rounded)
        : ("offen", colors.textSecondary, Icons.radio_button_unchecked);

    return Card(
      key: ValueKey("logic-lesson-${lesson.id}"),
      child: InkWell(
        onTap: () => _open(
          LogicLessonScreen(course: c, lesson: lesson, store: store),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  "${lesson.number}",
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.chapter, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                    Text(lesson.title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 3),
                            Text(label, style: TextStyle(fontSize: 12.5, color: color)),
                          ],
                        ),
                        if (ids.isNotEmpty)
                          Text(
                            "Übungen: $answered/${ids.length} bearbeitet"
                            "${answered > 0 ? " · zuletzt $right richtig, $wrong falsch" : ""}",
                            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ein Lehrtext ohne Übungen (Einführung, Hinweise zur Klausur).
class LogicTextScreen extends StatelessWidget {
  final String title;
  final List<LessonSection> sections;

  const LogicTextScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              for (final s in sections) LessonSectionView(section: s),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abschnitt mit Überschrift und Blöcken.
class LessonSectionView extends StatelessWidget {
  final LessonSection section;

  const LessonSectionView({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            ),
          LessonBlocksView(blocks: section.blocks),
        ],
      ),
    );
  }
}

/// Alle Argumente auf einen Blick – wie das Regelblatt der Klausur.
class LogicRulesScreen extends StatelessWidget {
  final LogicCourse course;

  const LogicRulesScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    Iterable<BoxBlock> boxes(LogicLesson l) sync* {
      for (final s in l.sections) {
        for (final b in s.blocks) {
          if (b is BoxBlock && b.kind == BoxKind.rules) yield b;
        }
      }
    }

    final rules = [
      for (final id in ["l6", "l9"])
        if (course.lesson(id) != null) ...boxes(course.lesson(id)!),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Regelübersicht")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                "Die Argumente aus den Lektionen 6 und 9 – sie entsprechen dem "
                "Regelblatt, das in der Klausur zur Verfügung steht.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final b in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LessonBox(kind: b.kind, title: b.title, children: b.children),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Übungsklausur: Hinweise und Beweisaufgaben.
class LogicExamScreen extends StatelessWidget {
  final LogicMockExam exam;
  final LogicProgressStore store;

  const LogicExamScreen({super.key, required this.exam, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exam.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              for (final s in exam.instructions) LessonSectionView(section: s),
              Text("Aufgaben", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "Fertige formale Beweise an (je 4 Punkte). Wähle ${exam.choose} "
                "der ${exam.tasks.length} Aufgaben; Zeitrahmen: ${exam.minutes} Minuten.",
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < exam.tasks.length; i++)
                Card(
                  child: ListTile(
                    title: Text("Aufgabe ${i + 1}"),
                    subtitle: Text(
                      (exam.tasks[i] as ProofExercise).theorem,
                      style: const TextStyle(fontFamily: "LogicSymbols"),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogicExerciseScreen(
                          title: exam.title,
                          exercises: exam.tasks,
                          initialIndex: i,
                          store: store,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
