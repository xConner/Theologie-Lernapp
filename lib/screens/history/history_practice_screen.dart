import 'package:flutter/material.dart';

import '../../models/history/history_course.dart';
import '../../services/history/history_trainer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import 'history_widgets.dart';

/// Übungsmodi von „Geschichte Schritt für Schritt“ (Personen und
/// Ereignisse, Jahreszahlen, Chronologie, Zusammenhänge) und die gemischte
/// Wiederholung als Runde mit Rückblick.
///
/// Geübt wird, was im Lernpfad eingeführt ist; „Alle Inhalte“ nimmt den
/// ganzen Stoff dazu, ohne die Lernstufen zu überspringen.
class HistoryPracticeScreen extends StatefulWidget {
  final HistoryTrainer trainer;
  final HistoryMode mode;
  final HistoryArea area;
  final String? uid;

  /// Länge einer Runde der gemischten Wiederholung.
  static const int roundLength = 10;

  const HistoryPracticeScreen({
    super.key,
    required this.trainer,
    required this.mode,
    required this.area,
    this.uid,
  });

  @override
  State<HistoryPracticeScreen> createState() => _HistoryPracticeScreenState();
}

class _HistoryPracticeScreenState extends State<HistoryPracticeScreen> {
  late bool onlyIntroduced;
  HistoryTask? task;
  int number = 0;
  int correct = 0;
  final List<HistoryTask> mistakes = [];
  bool finished = false;

  /// Zählt die gezeigten Aufgaben (Schlüssel der Aufgabenansicht).
  int serial = 0;

  /// Wiederholt nach einer Runde die falsch beantworteten Aufgaben.
  List<HistoryTask>? retry;

  HistoryTrainer get trainer => widget.trainer;
  HistoryCourse get course => trainer.course;
  bool get round => widget.mode == HistoryMode.mixed;

  @override
  void initState() {
    super.initState();
    onlyIntroduced = course.items.any((i) => trainer.isIntroduced(i.id));
    _nextTask();
  }

  void _nextTask() {
    serial++;
    final queue = retry;
    if (queue != null) {
      task = queue.isEmpty ? null : queue.removeAt(0);
      if (task == null) {
        retry = null;
        finished = true;
      }
      return;
    }
    if (round && number >= HistoryPracticeScreen.roundLength) {
      finished = true;
      task = null;
      return;
    }
    task = trainer.next(widget.mode, onlyIntroduced: onlyIntroduced);
  }

  void _answered(Map<String, bool> results, bool ok) {
    trainer.book.record(results);
    reportHistoryAnswer(
      context,
      area: widget.area,
      uid: widget.uid,
      correct: ok,
    );
    if (retry == null) {
      number++;
      if (ok) {
        correct++;
      } else if (task != null) {
        mistakes.add(task!);
      }
    }
  }

  void _next() => setState(_nextTask);

  void _restart({bool? all}) {
    setState(() {
      if (all != null) onlyIntroduced = !all;
      number = 0;
      correct = 0;
      mistakes.clear();
      finished = false;
      retry = null;
      _nextTask();
    });
  }

  void _retryMistakes() {
    setState(() {
      retry = [...mistakes];
      mistakes.clear();
      finished = false;
      _nextTask();
    });
  }

  String get _scopeLabel =>
      onlyIntroduced ? "Eingeführte Inhalte" : "Alle Inhalte";

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final pool = trainer.pool(onlyIntroduced: onlyIntroduced);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode.label),
        actions: [
          PopupMenuButton<bool>(
            key: const ValueKey("history-scope"),
            tooltip: "Umfang",
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (all) => _restart(all: all),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: false,
                checked: onlyIntroduced,
                child: const Text("Eingeführte Inhalte"),
              ),
              CheckedPopupMenuItem(
                key: const ValueKey("history-scope-all"),
                value: true,
                checked: !onlyIntroduced,
                child: const Text("Alle Inhalte"),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      _scopeLabel,
                      if (widget.mode == HistoryMode.chronology)
                        "Stufe ${trainer.chronologyLevel(pool)} von 4: "
                            "${HistoryTrainer.chronologyLevels[trainer.chronologyLevel(pool) - 1]}",
                      if (round && !finished && retry == null)
                        "Aufgabe ${number + 1} von ${HistoryPracticeScreen.roundLength}",
                      if (retry != null) "Fehler wiederholen",
                    ].join(" · "),
                    key: const ValueKey("history-practice-status"),
                    textAlign: TextAlign.center,
                    style: secondary.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  if (finished)
                    _summary(context)
                  else if (task == null)
                    _empty(context)
                  else
                    HistoryTaskView(
                      key: ValueKey("practice-task-$serial"),
                      course: course,
                      area: widget.area,
                      task: task!,
                      label:
                          "${task!.skill.label} · "
                          "${task!.skill.stage.label}",
                      onAnswered: _answered,
                      onNext: _next,
                    ),
                  InfoReportFooter(
                    module: widget.area.module,
                    reportDetails: task == null
                        ? null
                        : () => {
                            "Modus": widget.mode.label,
                            "Aufgabe": task!.prompt,
                            "Karten": task!.cardIds.join(", "),
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final nothingIntroduced = !course.items.any(
      (i) => trainer.isIntroduced(i.id),
    );
    return Column(
      key: const ValueKey("history-practice-empty"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          nothingIntroduced && onlyIntroduced
              ? "Noch ist nichts eingeführt. Beginne mit dem ersten "
                    "Lernschritt – oder übe gleich mit allen Inhalten."
              : "Für diesen Modus passt gerade keine Aufgabe. Manche "
                    "Aufgaben (Zusammenhänge, Reihenfolgen, freie Abfrage) "
                    "kommen erst, wenn die Grundlagen eines Inhalts zuletzt "
                    "sicher waren.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (onlyIntroduced)
          OutlinedButton(
            key: const ValueKey("history-practice-all"),
            onPressed: () => _restart(all: true),
            child: const Text("Mit allen Inhalten üben"),
          ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    return Column(
      key: const ValueKey("history-round-summary"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          "Runde beendet",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          "$correct von $number Aufgaben richtig.",
          textAlign: TextAlign.center,
        ),
        if (mistakes.isNotEmpty) ...[
          const ContentSectionTitle("Noch unsicher"),
          for (final m in mistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "• ${[for (final id in m.itemIds.take(2)) ?course.item(id)?.name].join(" / ")}"
                " (${m.skill.label})",
              ),
            ),
          const SizedBox(height: 8),
          Text(
            "Falsch beantwortete Inhalte kommen in den nächsten Runden "
            "früher wieder.",
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const ValueKey("history-retry-mistakes"),
            onPressed: _retryMistakes,
            child: const Text("Fehler gleich wiederholen"),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey("history-next-round"),
          onPressed: () => _restart(),
          child: const Text("Neue Runde"),
        ),
      ],
    );
  }
}
