import 'package:flutter/material.dart';

import '../../../models/logic/logic_exercise.dart';
import '../../../services/logic/exercise_generator.dart';
import '../../../services/logic/logic_progress_store.dart';
import '../../../services/logic/logic_streak_rule.dart';
import '../../../services/streak/streak_track.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/streak_widgets.dart';
import 'exercise_views.dart';

/// Übungen nacheinander bearbeiten. Mit [generatorKind] werden neue,
/// geprüfte Aufgaben erzeugt, solange man weitermacht.
class LogicExerciseScreen extends StatefulWidget {
  /// null = Gastmodus; bestimmt, wessen Streak eine gelöste Übung zählt.
  final String? uid;
  final String title;
  final List<LogicExercise> exercises;
  final int initialIndex;
  final LogicProgressStore store;
  final String? lessonId;
  final String? generatorKind;
  final List<ProofExercise> proofPool;

  const LogicExerciseScreen({
    super.key,
    required this.uid,
    required this.title,
    required this.exercises,
    required this.store,
    this.initialIndex = 0,
    this.lessonId,
    this.generatorKind,
    this.proofPool = const [],
  });

  @override
  State<LogicExerciseScreen> createState() => _LogicExerciseScreenState();
}

class _LogicExerciseScreenState extends State<LogicExerciseScreen> {
  late final List<LogicExercise> items = [...widget.exercises];
  late int index = widget.initialIndex;
  final ExerciseGenerator generator = ExerciseGenerator();
  int correct = 0;
  int answered = 0;
  bool generationFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.generatorKind != null && items.isEmpty) _generate();
  }

  void _generate() {
    final e = generator.generate(widget.generatorKind!, proofPool: widget.proofPool);
    if (e == null) {
      generationFailed = true;
    } else {
      items.add(e);
    }
  }

  /// Übungen dieser Runde, die schon für die Streak gezählt haben. Wer mit
  /// „Zurück“ zu einer gelösten Übung geht und sie erneut löst, zählt sie
  /// nicht noch einmal.
  final Set<int> _streakCounted = {};

  Future<void> _record(int index, LogicExercise e, bool ok) async {
    setState(() {
      answered++;
      if (ok) correct++;
    });
    if (LogicStreakRule.counts(e, correct: ok) && _streakCounted.add(index)) {
      recordStreakAnswer(
        context,
        uid: widget.uid,
        track: StreakTrack.logic,
        source: StreakSource.logicExercise,
      );
    }
    try {
      final id = e.id;
      if (id != null) {
        await widget.store.recordTask(id, ok);
      } else if (widget.lessonId != null && widget.generatorKind != null) {
        await widget.store.recordGenerated("${widget.lessonId}:${widget.generatorKind}", ok);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Die Antwort konnte nicht gespeichert werden.")),
        );
      }
    }
  }

  void _next() {
    setState(() {
      if (index + 1 >= items.length && widget.generatorKind != null) _generate();
      if (index + 1 < items.length) index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasItem = index < items.length;
    final generated = widget.generatorKind != null;
    final isLast = index + 1 >= items.length && !generated;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                generated ? "${index + 1}" : "${index + 1}/${items.length}",
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: !hasItem
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  generationFailed
                      ? "Es konnte keine weitere geprüfte Aufgabe erzeugt werden."
                      : "Keine Übungen.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    LogicExerciseView(
                      key: ValueKey("exercise-view-$index"),
                      exercise: items[index],
                      onResult: (ok) => _record(index, items[index], ok),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (index > 0)
                          TextButton.icon(
                            onPressed: () => setState(() => index--),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text("Zurück"),
                          ),
                        const Spacer(),
                        if (!isLast)
                          ElevatedButton.icon(
                            key: const ValueKey("exercise-next"),
                            onPressed: _next,
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: Text(generated ? "Neue Aufgabe" : "Weiter"),
                          )
                        else
                          ElevatedButton(
                            key: const ValueKey("exercise-finish"),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Fertig"),
                          ),
                      ],
                    ),
                    if (answered > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          "In dieser Runde: $correct von $answered richtig",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
