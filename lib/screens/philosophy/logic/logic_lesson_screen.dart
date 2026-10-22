import 'package:flutter/material.dart';

import '../../../models/logic/logic_course.dart';
import '../../../models/logic/logic_exercise.dart';
import '../../../services/logic/exercise_generator.dart';
import '../../../services/logic/logic_progress_store.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/logic/logic_text.dart';
import 'logic_course_screen.dart';
import 'logic_exercise_screen.dart';

/// Eine Lektion: Lehrtext (mit Lernzielen und typischen Fehlern) und
/// Übungen (Kursübungen, Zusatzübungen, erzeugte Übungen).
class LogicLessonScreen extends StatefulWidget {
  final String? uid;
  final LogicCourse course;
  final LogicLesson lesson;
  final LogicProgressStore store;

  const LogicLessonScreen({
    super.key,
    required this.uid,
    required this.course,
    required this.lesson,
    required this.store,
  });

  @override
  State<LogicLessonScreen> createState() => _LogicLessonScreenState();
}

class _LogicLessonScreenState extends State<LogicLessonScreen> {
  LogicProgress progress = const LogicProgress();

  LogicLesson get lesson => widget.lesson;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await widget.store.markOpened(lesson.id);
    } catch (_) {
      // Fortschritt ist optional; die Lektion bleibt nutzbar.
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final p = await widget.store.load();
      if (mounted) setState(() => progress = p);
    } catch (_) {}
  }

  Future<void> _toggleDone(bool done) async {
    try {
      await widget.store.setDone(lesson.id, done);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Der Fortschritt konnte nicht gespeichert werden.")),
        );
      }
    }
    await _refresh();
  }

  Future<void> _run(String title, List<LogicExercise> exercises, {int initial = 0, String? generatorKind}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogicExerciseScreen(
          uid: widget.uid,
          title: title,
          exercises: exercises,
          initialIndex: initial,
          store: widget.store,
          lessonId: lesson.id,
          generatorKind: generatorKind,
          proofPool: lesson.exercises.whereType<ProofExercise>().toList(),
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Lektion ${lesson.number}"),
          bottom: const TabBar(
            tabs: [
              Tab(key: ValueKey("tab-text"), text: "Lehrtext"),
              Tab(key: ValueKey("tab-exercises"), text: "Übungen"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_textTab(context), _exerciseTab(context)],
        ),
      ),
    );
  }

  Widget _frame(List<Widget> children) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      ),
    ),
  );

  Widget _textTab(BuildContext context) {
    final colors = context.colors;
    final done = progress.lesson(lesson.id).isDone;
    final prerequisites = [
      for (final id in lesson.prerequisites) widget.course.lesson(id),
    ].whereType<LogicLesson>();

    return _frame([
      Text(lesson.chapter, style: TextStyle(color: colors.textSecondary)),
      Text(lesson.title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Lernziele", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final g in lesson.goals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: LogicText("• $g", style: Theme.of(context).textTheme.bodyMedium),
                ),
              if (prerequisites.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "Setzt voraus: ${prerequisites.map((l) => "Lektion ${l.number} (${l.title})").join(", ")}",
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final s in lesson.sections) LessonSectionView(section: s),
      if (lesson.pitfalls.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Typische Fehler", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final p in lesson.pitfalls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: LogicText("• $p", style: Theme.of(context).textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
      if (lesson.literature.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text("Weiterführende Literatur", style: Theme.of(context).textTheme.titleSmall),
        for (final l in lesson.literature)
          Text(l, style: TextStyle(fontSize: 13.5, color: colors.textSecondary)),
      ],
      const SizedBox(height: 16),
      SwitchListTile(
        key: const ValueKey("lesson-done"),
        value: done,
        onChanged: _toggleDone,
        title: const Text("Lektion als bearbeitet markieren"),
        subtitle: const Text(
          "Nur eine Markierung für dich – sie sagt nicht, dass der Stoff "
          "sicher beherrscht wird.",
        ),
      ),
    ]);
  }

  Widget _exerciseTab(BuildContext context) {
    final colors = context.colors;
    final exercises = lesson.exercises;
    final groups = <String, List<LogicExercise>>{};
    for (final e in exercises) {
      groups.putIfAbsent(e.group, () => []).add(e);
    }
    final wrong = [
      for (final e in exercises)
        if (progress.task(e.id!).lastCorrect == false) e,
    ];

    return _frame([
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            key: const ValueKey("run-all"),
            onPressed: exercises.isEmpty ? null : () => _run("Lektion ${lesson.number}: Übungen", exercises),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text("Alle der Reihe nach"),
          ),
          OutlinedButton.icon(
            onPressed: wrong.isEmpty ? null : () => _run("Wiederholen", wrong),
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: Text("Falsch beantwortete (${wrong.length})"),
          ),
        ],
      ),
      if (lesson.generators.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text("Weitere Übungen erzeugen", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          "Neue Aufgaben zum Stoff dieser Lektion. Jede wird vor der Anzeige "
          "automatisch geprüft.",
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in lesson.generators)
              OutlinedButton.icon(
                key: ValueKey("generate-$kind"),
                onPressed: () => _run(
                  ExerciseGenerator.titles[kind] ?? kind,
                  const [],
                  generatorKind: kind,
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(ExerciseGenerator.titles[kind] ?? kind),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(entry.key, style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final e in entry.value) _exerciseTile(context, e, exercises),
      ],
    ]);
  }

  Widget _exerciseTile(BuildContext context, LogicExercise e, List<LogicExercise> all) {
    final colors = context.colors;
    final t = progress.task(e.id!);
    final (IconData icon, Color color) = switch (t.lastCorrect) {
      true => (Icons.check_circle_rounded, colors.success),
      false => (Icons.cancel_rounded, colors.error),
      null => (Icons.radio_button_unchecked, colors.textSecondary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        key: ValueKey("exercise-${e.id}"),
        leading: Icon(icon, color: color),
        title: FormulaText(e.summary, fontSize: 14.5),
        subtitle: Text(
          [
            e.origin.label,
            if (e is OpenExercise) "offene Aufgabe",
            if (t.attempts > 0) "${t.correct}× richtig, ${t.wrong}× falsch",
          ].join(" · "),
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
        ),
        onTap: () => _run("Lektion ${lesson.number}: Übungen", all, initial: all.indexOf(e)),
      ),
    );
  }
}
