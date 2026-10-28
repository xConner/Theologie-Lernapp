import 'package:flutter/material.dart';

import '../../models/history/history_course.dart';
import '../../services/history/history_lesson.dart';
import '../../services/history/history_trainer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import 'history_widgets.dart';

/// Ein Lernschritt: neue Inhalte einzeln kennenlernen, gleich abrufen,
/// festigen und mit Gelerntem verknüpfen (siehe [HistoryLessonSession]).
class HistoryLessonScreen extends StatefulWidget {
  final HistoryTrainer trainer;
  final HistoryLesson lesson;
  final HistoryArea area;
  final String? uid;

  /// Öffnet den nächsten Lernschritt (vom Ende aus).
  final void Function(HistoryLesson next)? onOpenLesson;

  const HistoryLessonScreen({
    super.key,
    required this.trainer,
    required this.lesson,
    required this.area,
    this.uid,
    this.onOpenLesson,
  });

  @override
  State<HistoryLessonScreen> createState() => _HistoryLessonScreenState();
}

class _HistoryLessonScreenState extends State<HistoryLessonScreen> {
  late final HistoryLessonSession session;
  late final int total;
  int stepNumber = 0;

  HistoryTrainer get trainer => widget.trainer;
  HistoryCourse get course => trainer.course;

  @override
  void initState() {
    super.initState();
    session = HistoryLessonSession(
      lesson: widget.lesson,
      trainer: trainer,
      known: [
        for (final i in course.items)
          if (trainer.isIntroduced(i.id)) i,
      ],
    );
    total = session.remaining;
  }

  void _answered(Map<String, bool> results, bool ok) {
    trainer.book.record(results);
    reportHistoryAnswer(
      context,
      area: widget.area,
      uid: widget.uid,
      correct: ok,
    );
    _lastResult = ok;
  }

  bool _lastResult = false;

  void _next() {
    setState(() {
      final step = session.current;
      if (step is LessonIntroStep) {
        session.advance();
      } else if (step is LessonTaskStep) {
        session.complete(_lastResult);
      }
      stepNumber++;
    });
  }

  HistoryLesson? get _nextLesson {
    final index = course.lessons.indexOf(widget.lesson);
    for (final l in course.lessons.skip(index + 1)) {
      if (course.itemsOfLesson(l).any((i) => !trainer.isIntroduced(i.id))) {
        return l;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = session.current;
    final done = total - session.remaining;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 1 : done / (done + session.remaining),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: switch (step) {
                null => _summary(context),
                LessonIntroStep() => _intro(context, step),
                LessonTaskStep() => HistoryTaskView(
                  key: ValueKey("lesson-task-$stepNumber"),
                  course: course,
                  area: widget.area,
                  task: step.task,
                  label: step.attempt > 0
                      ? "Noch einmal · ${step.task.skill.label}"
                      : "${step.phase.label} · ${step.task.skill.label}",
                  onAnswered: _answered,
                  onNext: _next,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context, LessonIntroStep step) {
    final index = session.items.indexOf(step.item) + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Neu ($index von ${session.items.length}) · ${widget.lesson.part}",
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HistoryItemCard(
              course: course,
              item: step.item,
              area: widget.area,
              knownRelated: step.knownRelated,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const ValueKey("history-intro-next"),
          onPressed: _next,
          child: const Text("Verstanden – abfragen"),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final next = _nextLesson;
    final secondary = TextStyle(color: context.colors.textSecondary);

    return Column(
      key: const ValueKey("history-lesson-summary"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 48,
          color: context.colors.success,
        ),
        const SizedBox(height: 8),
        Text(
          "Lernschritt durchgearbeitet",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          "${session.correct} von ${session.answered} Aufgaben beim ersten "
          "Versuch richtig. Eingeführt heißt nicht „sicher gelernt“: Die "
          "Inhalte kommen in den Übungen und der gemischten Wiederholung "
          "wieder.",
          textAlign: TextAlign.center,
          style: secondary,
        ),
        const ContentSectionTitle("Neu in diesem Schritt"),
        for (final item in session.items)
          ListTile(
            dense: true,
            leading: Icon(historyKindIcon(item.kind)),
            title: Text(item.name),
            subtitle: item.dating == null ? null : Text(item.dating!.label),
            trailing: session.mistakes.contains(item.id)
                ? Tag("wiederholen", color: context.colors.accent)
                : null,
            onTap: () =>
                showHistoryItemSheet(context, course, item, widget.area),
          ),
        const SizedBox(height: 16),
        if (next != null && widget.onOpenLesson != null)
          ElevatedButton.icon(
            key: const ValueKey("history-lesson-next"),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text("Nächster Schritt: ${next.title}"),
            onPressed: () => widget.onOpenLesson!(next),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey("history-lesson-close"),
          onPressed: () => Navigator.pop(context),
          child: const Text("Zur Übersicht"),
        ),
        InfoReportFooter(module: widget.area.module),
      ],
    );
  }
}
