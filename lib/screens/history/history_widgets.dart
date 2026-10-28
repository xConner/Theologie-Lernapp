import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../info/module_info.dart';
import '../../models/history/history_course.dart';
import '../../services/history/history_trainer.dart';
import '../../services/quiz_sound_settings.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/content_page.dart';
import '../../widgets/quiz_option_button.dart';
import '../../widgets/self_assessment.dart';
import '../../widgets/trainer_widgets.dart';

export '../../widgets/content_page.dart';

/// Was „Geschichte Schritt für Schritt“ vom Bereich braucht: Statistik,
/// Serie, Sounds, Meldungen und (optional) die Detailansicht eines Inhalts.
class HistoryArea {
  final String title;
  final StatisticsTrainer trainer;
  final StreakTrack track;
  final SoundModule sound;
  final ModuleInfo module;

  /// Öffnet die Detailansicht des Bereichs (Kirchengeschichte: Eintrag).
  final void Function(BuildContext context, String itemId)? openDetail;

  const HistoryArea({
    required this.title,
    required this.trainer,
    required this.track,
    required this.sound,
    required this.module,
    this.openDetail,
  });
}

IconData historyKindIcon(HistoryItemKind kind) => switch (kind) {
  HistoryItemKind.period => Icons.date_range_rounded,
  HistoryItemKind.person => Icons.person_outline_rounded,
  HistoryItemKind.group => Icons.flag_outlined,
  HistoryItemKind.event => Icons.event_note_rounded,
};

/// Datierung mit Genauigkeit und Anmerkung.
class HistoryDatingText extends StatelessWidget {
  final HistoricalDating dating;

  const HistoryDatingText(this.dating, {super.key});

  @override
  Widget build(BuildContext context) {
    final hint = dating.precisionHint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              dating.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hint != null) Tag(hint, color: context.colors.accent),
          ],
        ),
        if (dating.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              dating.note!,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ein Inhalt mit allem, was die Veranstaltung über ihn sagt (Einführung im
/// Lernschritt und Infoblatt im Zeitstrahl).
class HistoryItemCard extends StatelessWidget {
  final HistoryCourse course;
  final HistoryItem item;
  final HistoryArea area;

  /// Schon gelernte verknüpfte Inhalte (hervorgehoben).
  final List<HistoryItem> knownRelated;

  const HistoryItemCard({
    super.key,
    required this.course,
    required this.item,
    required this.area,
    this.knownRelated = const [],
  });

  @override
  Widget build(BuildContext context) {
    final period = item.periodId == null ? null : course.item(item.periodId!);
    final track = course.tracks.length > 1 ? course.track(item.trackId) : null;
    final related = course.relatedOf(item.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Tag(item.kind.label, icon: historyKindIcon(item.kind)),
            if (item.role != null) Tag(item.role!),
            if (period != null) Tag(period.name, icon: Icons.date_range),
            if (track != null) Tag(track.title),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          item.name,
          key: ValueKey("history-item-name-${item.id}"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (item.dating != null) ...[
          const SizedBox(height: 4),
          HistoryDatingText(item.dating!),
        ],
        for (final s in item.statements)
          s.supplement
              ? SupplementBox(s.text, label: "Ergänzung der App")
              : LectureQuote(text: s.text, source: s.source),
        if (item.consequence != null)
          LectureQuote(
            text: "Folge: ${item.consequence!.text}",
            source: item.consequence!.source,
          ),
        if (item.significance != null &&
            item.kind != HistoryItemKind.period &&
            !item.statements.any((s) => s.text == item.significance))
          SupplementBox(item.significance!, label: "Bedeutung (Ergänzung)"),
        if (knownRelated.isNotEmpty) ...[
          const ContentSectionTitle("Verbindung zu bereits Gelerntem"),
          for (final k in knownRelated)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "• ${k.name}${k.dating == null ? "" : " (${k.dating!.label})"}",
              ),
            ),
        ] else if (related.isNotEmpty) ...[
          const ContentSectionTitle("Verknüpft mit"),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final r in related)
                ActionChip(
                  avatar: Icon(historyKindIcon(r.kind), size: 16),
                  label: Text(r.name),
                  onPressed: () =>
                      showHistoryItemSheet(context, course, r, area),
                ),
            ],
          ),
        ],
        if (item.hasDetail && area.openDetail != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text("Eintrag öffnen"),
              onPressed: () => area.openDetail!(context, item.id),
            ),
          ),
      ],
    );
  }
}

/// Infoblatt zu einem Inhalt (Zeitstrahl, Auswertung).
Future<void> showHistoryItemSheet(
  BuildContext context,
  HistoryCourse course,
  HistoryItem item,
  HistoryArea area,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentPage.maxWidth),
            child: HistoryItemCard(course: course, item: item, area: area),
          ),
        ),
      ),
    ),
  );
}

/// Zeigt eine Aufgabe, wertet sie einmal aus und meldet das Ergebnis
/// ([onAnswered]: Karte → richtig, insgesamt richtig). Danach Erklärung
/// und „Weiter“ ([onNext]).
class HistoryTaskView extends StatefulWidget {
  final HistoryCourse course;
  final HistoryArea area;
  final HistoryTask task;

  /// Zeile über der Frage (z. B. „Festigen · Datierung“).
  final String? label;

  final void Function(Map<String, bool> results, bool correct) onAnswered;
  final VoidCallback onNext;

  const HistoryTaskView({
    super.key,
    required this.course,
    required this.area,
    required this.task,
    required this.onAnswered,
    required this.onNext,
    this.label,
  });

  @override
  State<HistoryTaskView> createState() => _HistoryTaskViewState();
}

class _HistoryTaskViewState extends State<HistoryTaskView> {
  bool answered = false;
  bool correct = false;
  int? selected;
  List<HistoryItem> order = [];
  List<bool>? orderResult;
  bool revealed = false;
  final TextEditingController yearController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  HistoryTask get task => widget.task;

  @override
  void initState() {
    super.initState();
    final t = task;
    if (t is HistoryOrderTask) order = [...t.items];
  }

  @override
  void dispose() {
    yearController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _finish(Map<String, bool> results, bool ok) {
    if (answered) return;
    setState(() {
      answered = true;
      correct = ok;
    });
    widget.onAnswered(results, ok);
  }

  void choose(int index) {
    final t = task;
    if (t is! HistoryChoiceTask || answered) return;
    selected = index;
    final ok = t.isCorrect(index);
    _finish({for (final id in t.cardIds) id: ok}, ok);
  }

  void checkOrder() {
    final t = task;
    if (t is! HistoryOrderTask || answered) return;
    final result = t.evaluate(order);
    orderResult = result;
    _finish({
      for (var i = 0; i < order.length; i++)
        HistoryTrainer.cardId(order[i].id, HistorySkill.chrono): result[i],
    }, result.every((x) => x));
  }

  void checkYear() {
    final t = task;
    if (t is! HistoryYearTask || answered) return;
    final ok = t.check(yearController.text);
    if (ok == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bitte eine Jahreszahl eingeben.")),
      );
      return;
    }
    _finish({t.cardIds.single: ok}, ok);
  }

  void assess(SelfAssessment assessment) {
    final t = task;
    if (t is! HistoryExplainTask || answered) return;
    _finish({t.cardIds.single: assessment.knew}, assessment.knew);
  }

  void primaryAction() {
    if (answered) {
      widget.onNext();
      return;
    }
    switch (task) {
      case HistoryOrderTask():
        checkOrder();
      case HistoryYearTask():
        checkYear();
      case HistoryExplainTask():
        if (!revealed) setState(() => revealed = true);
      case HistoryChoiceTask():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = task;
    final secondary = TextStyle(color: context.colors.textSecondary);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): primaryAction,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): primaryAction,
        for (var i = 0; i < 4; i++)
          SingleActivator(LogicalKeyboardKey(0x31 + i)): () {
            if (t is HistoryChoiceTask && i < t.options.length) choose(i);
          },
      },
      child: Focus(
        autofocus: t is! HistoryYearTask,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.label ?? t.skill.label,
              textAlign: TextAlign.center,
              style: secondary,
            ),
            const SizedBox(height: 12),
            Text(
              t.prompt,
              key: const ValueKey("history-prompt"),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (t is HistoryChoiceTask && t.hint != null) ...[
              const SizedBox(height: 8),
              Text(t.hint!, textAlign: TextAlign.center, style: secondary),
            ],
            const SizedBox(height: 20),
            ..._answer(t),
            if (answered) ...[
              const SizedBox(height: 20),
              Center(
                child: AnswerFeedbackBadge(
                  correct: correct,
                  label: correct ? "Richtig" : "Falsch",
                ),
              ),
              const SizedBox(height: 12),
              _explanation(t),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey("history-next"),
                onPressed: widget.onNext,
                child: const Text("Weiter"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _answer(HistoryTask t) {
    switch (t) {
      case HistoryChoiceTask():
        return [
          for (var i = 0; i < t.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizOptionButton(
                key: ValueKey("history-option-$i"),
                text: t.options[i],
                state: !answered
                    ? null
                    : i == t.correctIndex
                    ? true
                    : i == selected
                    ? false
                    : null,
                onPressed: answered ? null : () => choose(i),
              ),
            ),
        ];

      case HistoryOrderTask():
        return [
          Text(
            answered
                ? "Deine Reihenfolge:"
                : "Ziehe die Einträge am Griff an die richtige Stelle.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              if (answered) return;
              setState(() => order.insert(to, order.removeAt(from)));
            },
            children: [
              for (var i = 0; i < order.length; i++)
                _orderTile(t, order[i], i, orderResult?[i]),
            ],
          ),
          if (!answered) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey("history-order-check"),
              onPressed: checkOrder,
              child: const Text("Prüfen"),
            ),
          ],
        ];

      case HistoryYearTask():
        return [
          TextField(
            key: const ValueKey("history-year-input"),
            controller: yearController,
            focusNode: focusNode,
            autofocus: true,
            enabled: !answered,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "Jahr",
              suffixText: t.beforeChrist ? "v. Chr." : null,
              border: answerResultBorder(context, answered ? correct : null),
              enabledBorder: answerResultBorder(
                context,
                answered ? correct : null,
              ),
              disabledBorder: answerResultBorder(
                context,
                answered ? correct : null,
              ),
            ),
            onSubmitted: (_) => checkYear(),
          ),
          if (!answered) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey("history-year-check"),
              onPressed: checkYear,
              child: const Text("Prüfen"),
            ),
          ],
        ];

      case HistoryExplainTask():
        return [
          SelfAssessmentPanel(
            revealed: revealed,
            onReveal: () => setState(() => revealed = true),
            onAssess: assess,
            hint:
                "Erkläre es dir selbst (oder laut) und decke dann die "
                "Lösung auf.",
            solutionBuilder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in t.solution)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(line),
                  ),
              ],
            ),
          ),
        ];
    }
  }

  Widget _orderTile(HistoryOrderTask t, HistoryItem e, int index, bool? ok) {
    final colors = context.colors;
    return Card(
      key: ValueKey("history-order-${e.id}"),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: ok == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              side: BorderSide(
                color: ok ? colors.success : colors.error,
                width: 2,
              ),
            ),
      child: ListTile(
        leading: Text("${index + 1}.", style: const TextStyle(fontSize: 16)),
        title: Text(e.timelessName),
        subtitle: answered
            ? Text(
                "${e.dating!.label}"
                "${ok == false ? " · richtig: Platz ${t.correctOrder.indexOf(e) + 1}" : ""}",
              )
            : null,
        trailing: answered
            ? Icon(
                ok == true ? Icons.check_rounded : Icons.close_rounded,
                color: ok == true ? colors.success : colors.error,
              )
            : ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle_rounded),
              ),
      ),
    );
  }

  Widget _explanation(HistoryTask t) {
    final items = [for (final id in t.itemIds) ?widget.course.item(id)];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!correct && t is HistoryChoiceTask) ...[
            Text(
              "Richtig: ${t.answer}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          if (!correct && t is HistoryYearTask) ...[
            Text(
              "Richtig: ${t.item.dating!.label}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          Text(t.explanation, key: const ValueKey("history-explanation")),
          if (t.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t.sources.join(" · "),
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (items.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final i in items.take(4))
                  ActionChip(
                    avatar: Icon(historyKindIcon(i.kind), size: 16),
                    label: Text(i.name),
                    onPressed: () => showHistoryItemSheet(
                      context,
                      widget.course,
                      i,
                      widget.area,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Verbucht Sound, Statistik und Serie für eine Antwort (wie in den
/// übrigen Trainern).
void reportHistoryAnswer(
  BuildContext context, {
  required HistoryArea area,
  required String? uid,
  required bool correct,
}) {
  reportTrainerAnswer(
    context,
    uid: uid,
    correct: correct,
    firstEvaluation: true,
    sound: area.sound,
    trainer: area.trainer,
    track: area.track,
    source: StreakSource.historySteps,
  );
}
