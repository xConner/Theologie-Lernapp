import 'package:flutter/material.dart';

import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_study_session.dart';
import '../../../quiz/books/reference_answer.dart';
import '../../../services/quiz_sound_settings.dart';
import '../../../services/statistics/learning_statistics.dart';
import '../../../services/streak/streak_track.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/self_assessment.dart';
import '../../../widgets/trainer_widgets.dart';

/// Startet eine Lerneinheit; ohne Aufgaben erscheint nur ein Hinweis.
Future<void> startStudy(
  BuildContext context, {
  required BookLearningController controller,
  required StudyMode mode,
  required List<StudyTask> tasks,
  String? title,
}) async {
  if (tasks.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == StudyMode.order
              ? "Für Reihenfolge-Aufgaben braucht es mindestens drei "
                    "Perikopen mit verschiedenen Titeln."
              : "Hierfür gibt es gerade nichts zu lernen.",
        ),
      ),
    );
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BookStudyScreen(
        controller: controller,
        session: StudySession(
          state: controller.state,
          storage: controller.storage,
          tasks: tasks,
          mode: mode,
        ),
        title: title,
      ),
    ),
  );

  controller.refresh();
}

class BookStudyScreen extends StatefulWidget {
  final BookLearningController controller;
  final StudySession session;
  final String? title;

  const BookStudyScreen({
    super.key,
    required this.controller,
    required this.session,
    this.title,
  });

  @override
  State<BookStudyScreen> createState() => _BookStudyScreenState();
}

class _BookStudyScreenState extends State<BookStudyScreen> {
  StudySession get session => widget.session;

  final TextEditingController input = TextEditingController();
  final FocusNode inputFocus = FocusNode();

  AnswerMethod method = AnswerMethod.typing;

  // Nach der Bewertung: Rückmeldung bis „Weiter“.
  bool answered = false;
  bool? lastCorrect;
  String? feedback;

  bool revealed = false;

  int? chosenOption;

  final List<BookPericope> arranged = [];

  @override
  void initState() {
    super.initState();

    AnswerMethodPreference.load(AnswerMethodPreference.pericopeQuiz).then((m) {
      if (mounted && !session.exam) setState(() => method = m);
    });
  }

  @override
  void dispose() {
    input.dispose();
    inputFocus.dispose();

    // Übersichten auf den neuen Lernstand bringen – auch wenn diese Einheit
    // durch „Fehler wiederholen“ ersetzt wurde.
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.refresh());

    super.dispose();
  }

  void _report(bool correct) {
    // Die Prüfung verrät während der Bearbeitung nichts – auch keinen Ton.
    if (session.exam) return;

    reportTrainerAnswer(
      context,
      uid: widget.controller.uid,
      correct: correct,
      firstEvaluation: true,
      sound: SoundModule.pericopeQuiz,
      trainer: StatisticsTrainer.perikopenQuiz,
      track: StreakTrack.perikope,
      source: StreakSource.perikopenQuiz,
    );
  }

  void _next() {
    setState(() {
      session.advance();

      input.clear();
      answered = false;
      lastCorrect = null;
      feedback = null;
      revealed = false;
      chosenOption = null;
      arranged.clear();
    });

    if (session.current is RecallTask && method == AnswerMethod.typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) inputFocus.requestFocus();
      });
    }
  }

  Future<void> _introduced() async {
    await session.completeIntroduction();
    _next();
  }

  Future<void> _submitRecall() async {
    if (answered || input.text.trim().isEmpty) return;

    final check = await session.answerRecall(input.text);

    if (!mounted) return;

    _report(check.correct);

    if (session.exam) {
      _next();
      return;
    }

    final task = session.results.last;

    setState(() {
      answered = true;
      lastCorrect = check.correct;
      feedback = check.correct
          ? "✔ ${check.message}"
          : "✘ ${check.message}\nRichtig: ${task.expected}";
    });
  }

  Future<void> _skipRecall() async {
    // Überspringen in der Prüfung = nicht gewusst.
    await session.assessRecall(false);
    if (mounted) _next();
  }

  Future<void> _assess(SelfAssessment assessment) async {
    await session.assessRecall(assessment.knew);

    if (!mounted) return;

    _report(assessment.knew);
    _next();
  }

  Future<void> _choose(int option) async {
    if (answered) return;

    final correct = await session.answerChoice(option);

    if (!mounted) return;

    _report(correct);

    setState(() {
      answered = true;
      chosenOption = option;
      lastCorrect = correct;
    });
  }

  Future<void> _checkArrange() async {
    final correct = await session.answerArrange(List.of(arranged));

    if (!mounted) return;

    _report(correct);

    setState(() {
      answered = true;
      lastCorrect = correct;
    });
  }

  String _modeTitle() => widget.title ?? session.mode.label;

  @override
  Widget build(BuildContext context) {
    final task = session.current;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeTitle()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: session.tasks.isEmpty
                ? 1
                : session.index / session.tasks.length,
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: task == null
            ? _ResultView(
                session: session,
                controller: widget.controller,
                title: _modeTitle(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Aufgabe ${session.index + 1} von "
                          "${session.tasks.length}"
                          "${session.exam ? " · Prüfung ohne Lösungshinweise" : ""}",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        _buildTask(task),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTask(StudyTask task) {
    switch (task) {
      case IntroduceTask():
        return _buildIntroduction(task);
      case RecallTask():
        return _buildRecall(task);
      case ChoiceTask():
        return _buildChoice(task);
      case ArrangeTask():
        return _buildArrange(task);
    }
  }

  // ---------- Einführung ----------

  Widget _buildIntroduction(IntroduceTask task) {
    final expected = widget.controller.state.expectedOf(task.target);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Neue Perikope",
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              task.target.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            SelectableText(
              expected.text,
              key: const ValueKey("intro-reference"),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _PrecisionNote(
              personal: expected.personal,
              verse: expected.versePrecise,
            ),
            const SizedBox(height: 18),
            Text(
              "Präge dir die Stelle ein. Sie wird gleich abgefragt.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey("intro-continue"),
              onPressed: _introduced,
              child: const Text("Weiter"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Stelle abrufen ----------

  Widget _buildRecall(RecallTask task) {
    final state = widget.controller.state;

    final expected = state.expectedOf(task.target);

    final reference = expected.reference;

    final prefix = switch (task.prompt) {
      ReferencePrompt.none => null,
      ReferencePrompt.book => "${reference.book} ",
      ReferencePrompt.bookAndChapter =>
        "${reference.book} ${reference.startChapter},",
    };

    final question = switch (task.prompt) {
      ReferencePrompt.none => "Wo steht die Perikope?",
      ReferencePrompt.book =>
        expected.versePrecise
            ? "Kapitel und Verse in ${BookCatalog.nameOf(reference.book!)}?"
            : "Welches Kapitel in ${BookCatalog.nameOf(reference.book!)}?",
      ReferencePrompt.bookAndChapter =>
        "Welche Verse in ${reference.book} ${reference.startChapter}?",
    };

    final hint = switch (task.prompt) {
      ReferencePrompt.none =>
        expected.versePrecise ? "z. B. Mk 1,14-20" : "z. B. Mk 1 oder Mk 8-10",
      ReferencePrompt.book =>
        expected.versePrecise ? "z. B. 1,14-20" : "z. B. 1",
      ReferencePrompt.bookAndChapter => "z. B. 14-20",
    };

    final recall = method == AnswerMethod.recall && !session.exam;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          task.target.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Center(
          child: _PrecisionNote(
            personal: expected.personal,
            verse: expected.versePrecise,
          ),
        ),
        const SizedBox(height: 12),
        Text(question, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        if (!session.exam)
          Center(
            child: AnswerMethodSelector(
              method: method,
              onChanged: answered || revealed
                  ? null
                  : (m) {
                      setState(() => method = m);
                      AnswerMethodPreference.save(
                        AnswerMethodPreference.pericopeQuiz,
                        m,
                      );
                    },
            ),
          ),
        const SizedBox(height: 12),
        if (recall)
          SelfAssessmentPanel(
            revealed: revealed,
            onReveal: () => setState(() => revealed = true),
            onAssess: _assess,
            hint: "Rufe die Stelle im Kopf ab und decke dann die Lösung auf.",
            solutionBuilder: (_) => SelectableText(
              expected.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          )
        else ...[
          TextField(
            key: const ValueKey("recall-input"),
            controller: input,
            focusNode: inputFocus,
            autofocus: true,
            enabled: !answered,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              prefixText: prefix,
              hintText: hint,
              enabledBorder: answered
                  ? answerResultBorder(context, lastCorrect)
                  : null,
              disabledBorder: answered
                  ? answerResultBorder(context, lastCorrect)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => answered ? _next() : _submitRecall(),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (session.exam)
                TextButton(
                  key: const ValueKey("recall-skip"),
                  onPressed: _skipRecall,
                  child: const Text("Weiß ich nicht"),
                ),
              ElevatedButton(
                key: const ValueKey("recall-submit"),
                onPressed: answered
                    ? _next
                    : (input.text.trim().isEmpty ? null : _submitRecall),
                child: Text(answered ? "Weiter" : "Prüfen"),
              ),
            ],
          ),
          if (feedback != null)
            _Feedback(text: feedback!, correct: lastCorrect!),
        ],
      ],
    );
  }

  // ---------- Auswahl ----------

  Widget _buildChoice(ChoiceTask task) {
    final state = widget.controller.state;

    final String question;
    final List<String> context0;

    switch (task.kind) {
      case ChoiceKind.next:
        question = "Welche Perikope folgt als Nächstes?";
        context0 = [task.context[0].title];
      case ChoiceKind.between:
        question = "Welche Perikope steht dazwischen?";
        context0 = [task.context[0].title, "…", task.context[1].title];
      case ChoiceKind.compare:
        question = "Welche Stelle gehört zu dieser Perikope?";
        context0 = [task.target.title];
    }

    String label(BookPericope p) =>
        task.kind == ChoiceKind.compare ? state.expectedOf(p).text : p.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final line in context0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: line == "…" ? FontWeight.normal : FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        const SizedBox(height: 16),
        for (int i = 0; i < task.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              key: ValueKey("option-$i"),
              label: label(task.options[i]),
              state: !answered
                  ? null
                  : i == task.correctIndex
                  ? true
                  : i == chosenOption
                  ? false
                  : null,
              onPressed: answered ? null : () => _choose(i),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton(
              key: const ValueKey("choice-next"),
              onPressed: _next,
              child: const Text("Weiter"),
            ),
          ),
        ],
      ],
    );
  }

  // ---------- Reihenfolge ordnen ----------

  Widget _buildArrange(ArrangeTask task) {
    final remaining = [
      for (final p in task.shuffled)
        if (!arranged.contains(p)) p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Tippe die Perikopen in der Reihenfolge an, in der sie im Buch "
          "stehen.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < arranged.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _OptionButton(
              key: ValueKey("arranged-$i"),
              label: "${i + 1}. ${arranged[i].title}",
              state: answered ? arranged[i] == task.ordered[i] : null,
              onPressed: answered
                  ? null
                  : () => setState(
                      () => arranged.removeRange(i, arranged.length),
                    ),
            ),
          ),
        if (remaining.isNotEmpty) ...[
          if (arranged.isNotEmpty) const Divider(height: 24),
          for (final p in remaining)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                key: ValueKey("arrange-${task.shuffled.indexOf(p)}"),
                onPressed: answered
                    ? null
                    : () => setState(() => arranged.add(p)),
                child: Text(p.title, textAlign: TextAlign.center),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (answered) ...[
          _Feedback(
            correct: lastCorrect!,
            text: lastCorrect!
                ? "✔ Richtige Reihenfolge"
                : "✘ Richtige Reihenfolge:\n"
                      "${[for (int i = 0; i < task.ordered.length; i++) "${i + 1}. ${task.ordered[i].title}"].join("\n")}",
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              key: const ValueKey("arrange-next"),
              onPressed: _next,
              child: const Text("Weiter"),
            ),
          ),
        ] else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                onPressed: arranged.isEmpty
                    ? null
                    : () => setState(() => arranged.clear()),
                child: const Text("Neu ordnen"),
              ),
              ElevatedButton(
                key: const ValueKey("arrange-check"),
                onPressed: remaining.isEmpty ? _checkArrange : null,
                child: const Text("Prüfen"),
              ),
            ],
          ),
      ],
    );
  }
}

class _PrecisionNote extends StatelessWidget {
  final bool personal;
  final bool verse;

  const _PrecisionNote({required this.personal, required this.verse});

  @override
  Widget build(BuildContext context) {
    final text = !verse
        ? "Kapitelgenau"
        : personal
        ? "Versgenau (eigene Präzisierung)"
        : "Versgenau";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  final String text;
  final bool correct;

  const _Feedback({required this.text, required this.correct});

  @override
  Widget build(BuildContext context) {
    final color = correct ? context.colors.success : context.colors.error;

    return Container(
      key: const ValueKey("study-feedback"),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct
            ? context.colors.successBackground
            : context.colors.errorBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: SelectableText(text, textAlign: TextAlign.center),
    );
  }
}

/// Antwortknopf; [state] true/false färbt ihn nach der Auswertung.
class _OptionButton extends StatelessWidget {
  final String label;
  final bool? state;
  final VoidCallback? onPressed;

  const _OptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = state == null
        ? null
        : state!
        ? context.colors.success
        : context.colors.error;

    return OutlinedButton(
      style: color == null
          ? null
          : OutlinedButton.styleFrom(
              side: BorderSide(color: color, width: 2),
              backgroundColor: state!
                  ? context.colors.successBackground
                  : context.colors.errorBackground,
              disabledForegroundColor: context.colors.textPrimary,
            ),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (state != null) ...[
              Icon(
                state! ? Icons.check_rounded : Icons.close_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// Auswertung am Ende, im Prüfungsmodus mit allen Fehlern.
class _ResultView extends StatelessWidget {
  final StudySession session;
  final BookLearningController controller;
  final String title;

  const _ResultView({
    required this.session,
    required this.controller,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final mistakes = session.mistakes;

    // Nur Fehler beim Abrufen der Stelle; Reihenfolge-Fehler werden nicht
    // als Stellenabfrage wiederholt.
    final retry = {
      for (final r in mistakes)
        if (r.task is RecallTask ||
            (r.task is ChoiceTask && !(r.task as ChoiceTask).isOrder))
          r.task.target,
    }.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  mistakes.isEmpty
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  size: 48,
                  color: mistakes.isEmpty
                      ? context.colors.success
                      : context.colors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  session.answered == 0
                      ? "Lerneinheit abgeschlossen"
                      : "${session.correctCount} von ${session.answered} richtig",
                  key: const ValueKey("study-result"),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (session.exam)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Prüfung: $title",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (retry.isNotEmpty)
                      OutlinedButton.icon(
                        key: const ValueKey("retry-mistakes"),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text("Fehler wiederholen"),
                        onPressed: () {
                          final tasks = controller.planner().review(retry);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookStudyScreen(
                                controller: controller,
                                session: StudySession(
                                  state: controller.state,
                                  storage: controller.storage,
                                  tasks: tasks,
                                  mode: StudyMode.review,
                                ),
                                title: "Fehler wiederholen",
                              ),
                            ),
                          );
                        },
                      ),
                    ElevatedButton(
                      key: const ValueKey("study-done"),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Fertig"),
                    ),
                  ],
                ),
                if (mistakes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    "Fehler",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final r in mistakes)
                    Card(
                      child: ListTile(
                        title: Text(
                          r.task is ArrangeTask
                              ? "Reihenfolge"
                              : r.task.target.title,
                        ),
                        subtitle: Text(
                          "Deine Antwort: ${r.given}\n"
                          "Richtig: ${r.expected}"
                          "${r.note == null ? "" : "\n${r.note}"}",
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
