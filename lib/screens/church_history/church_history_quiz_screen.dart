import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../info/app_info.dart';
import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../services/church_history/church_history_store.dart';
import '../../services/quiz_sound_settings.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quiz_option_button.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/info_report.dart';
import '../../widgets/self_assessment.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/settings_selection.dart';
import '../../widgets/sound_volume_button.dart';
import '../../widgets/statistics_widgets.dart';
import '../../widgets/trainer_widgets.dart';
import 'church_history_progress_screen.dart';
import 'church_history_widgets.dart';
import 'lecture_detail_screen.dart';

/// Wissensquiz und Chronologietrainer: dieselbe Oberfläche, verschiedene
/// Aufgabenarten (siehe [QuizMode]).
class ChurchHistoryQuizScreen extends StatefulWidget {
  final ChurchHistoryData data;
  final QuizMode mode;

  /// Umfang beim Öffnen (z. B. aus einer Vorlesung); sonst der zuletzt
  /// gewählte.
  final LearningScope? scope;

  /// Nur für Tests: Speicher (sonst nach Anmeldung) und Zufall.
  final ChurchHistoryStore? store;
  final Random? random;

  const ChurchHistoryQuizScreen({
    super.key,
    required this.data,
    required this.mode,
    this.scope,
    this.store,
    this.random,
  });

  @override
  State<ChurchHistoryQuizScreen> createState() =>
      _ChurchHistoryQuizScreenState();
}

class _ChurchHistoryQuizScreenState extends State<ChurchHistoryQuizScreen> {
  String? uid;
  late final ChurchHistoryStore store;

  bool loading = true;
  String? loadError;

  ChurchHistorySettings settings = ChurchHistorySettings();
  late LearningScope scope;
  late ChurchHistoryQuiz quiz;

  QuizQuestion? question;
  bool answered = false;
  bool correct = false;
  bool firstEvaluation = true;

  // Auswahlfrage
  int? selected;

  // Reihenfolge
  List<HistoryEntry> order = [];
  List<bool>? orderResult;

  // Merkliste
  bool revealed = false;

  final FocusNode keyboardFocusNode = FocusNode();

  ChurchHistoryData get data => widget.data;

  Set<QuizKind> get kinds {
    final chosen = settings.kinds.intersection(widget.mode.kinds);
    return chosen.isEmpty ? widget.mode.kinds : chosen;
  }

  @override
  void initState() {
    super.initState();

    if (widget.store != null) {
      store = widget.store!;
    } else {
      // uid == null: Gastmodus, gespeichert wird dann lokal.
      uid = FirebaseAuth.instance.currentUser?.uid;
      store = ChurchHistoryStore.forUser(uid);
    }

    scope = widget.scope ?? LearningScope.all;
    quiz = ChurchHistoryQuiz(data: data, random: widget.random);

    _load();
  }

  @override
  void dispose() {
    keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      settings = await store.loadSettings();
      final cards = await store.loadCards();

      quiz = ChurchHistoryQuiz(data: data, cards: cards, random: widget.random);
    } catch (_) {
      loadError =
          "Der Lernstand konnte nicht geladen werden. Antworten werden "
          "trotzdem gewertet.";
    }

    scope = widget.scope ?? LearningScope.parse(settings.scope, data);

    if (!mounted) return;

    setState(() => loading = false);

    nextQuestion();
  }

  Future<void> _reloadProgress() async {
    try {
      final cards = await store.loadCards();
      quiz = ChurchHistoryQuiz(data: data, cards: cards, random: widget.random);
    } catch (_) {}

    if (mounted) nextQuestion();
  }

  // ==========================
  // ABLAUF
  // ==========================

  void nextQuestion() {
    final next = quiz.next(scope, kinds, onlyDifficult: settings.onlyDifficult);

    setState(() {
      question = next;
      answered = false;
      correct = false;
      firstEvaluation = true;
      selected = null;
      revealed = false;
      orderResult = null;
      order = next is OrderQuestion ? [...next.items] : [];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) keyboardFocusNode.requestFocus();
    });
  }

  void _finish(Map<String, bool> results, bool ok) {
    final q = question;
    if (q == null) return;

    final changed = quiz.record(q, results);

    store.saveCards(changed).catchError((Object _) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Der Lernstand konnte nicht gespeichert werden."),
        ),
      );
    });

    reportTrainerAnswer(
      context,
      uid: uid,
      correct: ok,
      firstEvaluation: firstEvaluation,
      sound: SoundModule.churchHistory,
      trainer: StatisticsTrainer.churchHistory,
      track: StreakTrack.churchHistory,
      source: widget.mode == QuizMode.chronology
          ? StreakSource.chronology
          : StreakSource.knowledgeQuiz,
    );

    setState(() {
      answered = true;
      correct = ok;
      firstEvaluation = false;
    });
  }

  void choose(int index) {
    final q = question;
    if (q is! ChoiceQuestion || answered) return;

    selected = index;
    final ok = q.isCorrect(index);
    _finish({q.cardId: ok}, ok);
  }

  void checkOrder() {
    final q = question;
    if (q is! OrderQuestion || answered) return;

    final result = q.evaluate(order);
    orderResult = result;

    _finish({
      for (var i = 0; i < order.length; i++)
        ChurchHistoryQuiz.cardId(order[i].id, QuizKind.order): result[i],
    }, result.every((x) => x));
  }

  void assess(SelfAssessment assessment) {
    final q = question;
    if (q is! RecallQuestion || answered) return;

    _finish({q.cardIds.single: assessment.knew}, assessment.knew);
  }

  /// Enter: prüfen bzw. weiter.
  void primaryAction() {
    final q = question;
    if (q == null) return;

    if (answered) {
      nextQuestion();
    } else if (q is OrderQuestion) {
      checkOrder();
    } else if (q is RecallQuestion && !revealed) {
      setState(() => revealed = true);
    }
  }

  void _openProgress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChurchHistoryProgressScreen(
          data: data,
          store: store,
          onChanged: _reloadProgress,
        ),
      ),
    );
  }

  // ==========================
  // EINSTELLUNGEN
  // ==========================

  List<LearningScope> get _scopes => [
    LearningScope.all,
    if (data.lectures.length > 1 || data.seminar != null)
      LearningScope.allLectures,
    if (data.seminar != null) LearningScope.seminar,
    for (final l in data.units)
      if (l.hasLearningContent) LearningScope.lecture(l.id),
    for (final e in data.epochs)
      if (data.entriesOfEpoch(e.id).isNotEmpty) LearningScope.epoch(e.id),
    for (final t in data.usedThemes) LearningScope.theme(t.id),
  ];

  void openSettings() {
    var draftScope = scope;
    var draftKinds = {...kinds};
    var draftDifficult = settings.onlyDifficult;

    final options = QuizKind.values.where(widget.mode.kinds.contains).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ModuleSettingsDialog(
              moduleLabel: widget.mode.label,
              onProgressReset: _reloadProgress,
              title: Row(
                children: [
                  const Expanded(child: Text("Einstellungen")),
                  IconButton(
                    key: const ValueKey("church-history-settings-save"),
                    icon: const Icon(Icons.check),
                    tooltip: "Speichern",
                    onPressed: () async {
                      if (draftKinds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Mindestens eine Aufgabenart muss ausgewählt "
                              "sein.",
                            ),
                          ),
                        );
                        return;
                      }

                      // Arten des anderen Modus bleiben, wie sie waren.
                      final saved = settings.copyWith(
                        scope: draftScope.key,
                        kinds: {
                          ...settings.kinds.difference(widget.mode.kinds),
                          ...draftKinds,
                        },
                        onlyDifficult: draftDifficult,
                      );

                      try {
                        await store.saveSettings(saved);
                      } catch (_) {
                        // Die Auswahl gilt trotzdem für diese Sitzung.
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      settings = saved;
                      scope = draftScope;
                      nextQuestion();
                    },
                  ),
                ],
              ),
              moduleSettings: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsSection(
                      title: "Umfang",
                      hint: "Was abgefragt wird.",
                      child: RadioGroup<LearningScope>(
                        groupValue: draftScope,
                        onChanged: (v) => setDialogState(() {
                          if (v != null) draftScope = v;
                        }),
                        child: Column(
                          children: [
                            for (final s in _scopes)
                              RadioListTile<LearningScope>(
                                key: ValueKey("scope-${s.key}"),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.label(data)),
                                value: s,
                              ),
                          ],
                        ),
                      ),
                    ),
                    MultiSelectSection<QuizKind>(
                      title: "Aufgabenarten",
                      options: options,
                      isSelected: draftKinds.contains,
                      labelOf: (k) => k.label,
                      emptyError:
                          "Mindestens eine Aufgabenart muss ausgewählt sein.",
                      onToggleAll: () => setDialogState(() {
                        draftKinds = draftKinds.length == options.length
                            ? {}
                            : options.toSet();
                      }),
                      onChanged: (k, v) => setDialogState(() {
                        draftKinds = {...draftKinds};
                        v ? draftKinds.add(k) : draftKinds.remove(k);
                      }),
                    ),
                    SettingsSection(
                      title: "Schwierige Inhalte",
                      child: SettingsSwitchGroup(
                        children: [
                          SwitchListTile(
                            key: const ValueKey("only-difficult"),
                            title: const Text("Nur schwierige Inhalte üben"),
                            subtitle: const Text(
                              "Inhalte, die zuletzt öfter falsch als sicher "
                              "beantwortet wurden. Richtige Antworten nehmen "
                              "sie wieder heraus.",
                            ),
                            value: draftDifficult,
                            onChanged: (v) =>
                                setDialogState(() => draftDifficult = v),
                          ),
                        ],
                      ),
                    ),
                    const SoundSettingsSection(
                      module: SoundModule.churchHistory,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================
  // OBERFLÄCHE
  // ==========================

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text(widget.mode.label),
      actions: [
        IconButton(
          icon: const Icon(Icons.insights_rounded),
          tooltip: "Fortschritt",
          onPressed: loading ? null : _openProgress,
        ),
        StatisticsButton(uid: uid, trainer: StatisticsTrainer.churchHistory),
        const SoundVolumeButton(),
        IconButton(
          key: const ValueKey("church-history-settings"),
          icon: const Icon(Icons.settings),
          tooltip: "Einstellungen",
          onPressed: loading ? null : openSettings,
        ),
      ],
    );

    if (loading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = question;

    if (q == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.onlyDifficult
                      ? "In „${scope.label(data)}“ gibt es zurzeit keine "
                            "schwierigen Inhalte. Schalte „Nur schwierige "
                            "Inhalte üben“ aus, um alles zu wiederholen."
                      : "Für „${scope.label(data)}“ gibt es mit den gewählten "
                            "Aufgabenarten keine Aufgaben.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: openSettings,
                  child: const Text("Einstellungen ändern"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): primaryAction,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): primaryAction,
          for (var i = 0; i < 4; i++)
            SingleActivator(LogicalKeyboardKey(0x31 + i)): () {
              if (q is ChoiceQuestion && i < q.options.length) choose(i);
            },
        },
        child: Focus(
          focusNode: keyboardFocusNode,
          autofocus: true,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loadError != null) ...[
                        Text(
                          loadError!,
                          style: TextStyle(color: context.colors.error),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        "${scope.label(data)} · ${q.kind.label}",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.prompt,
                        key: const ValueKey("quiz-prompt"),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      ..._buildAnswer(q),
                      if (answered) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: AnswerFeedbackBadge(
                            correct: correct,
                            label: correct ? "Richtig" : "Falsch",
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildExplanation(q),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          key: const ValueKey("quiz-next"),
                          onPressed: nextQuestion,
                          child: const Text("Weiter"),
                        ),
                      ],
                      InfoReportFooter(
                        module: AppModules.churchHistory,
                        reportDetails: () => {
                          "Modus": widget.mode.label,
                          "Aufgabe": q.prompt,
                          "Karten": q.cardIds.join(", "),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnswer(QuizQuestion q) {
    switch (q) {
      case ChoiceQuestion():
        return [
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizOptionButton(
                key: ValueKey("option-$i"),
                text: q.options[i],
                state: !answered
                    ? null
                    : i == q.correctIndex
                    ? true
                    : i == selected
                    ? false
                    : null,
                onPressed: answered ? null : () => choose(i),
              ),
            ),
        ];

      case OrderQuestion():
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
                _orderTile(order[i], i, orderResult?[i]),
            ],
          ),
          if (!answered) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey("order-check"),
              onPressed: checkOrder,
              child: const Text("Prüfen"),
            ),
          ],
        ];

      case RecallQuestion():
        final list = q.list;
        return [
          SelfAssessmentPanel(
            revealed: revealed,
            onReveal: () => setState(() => revealed = true),
            onAssess: assess,
            hint:
                "Rufe die ${list.items.length} Punkte im Kopf ab und decke "
                "dann die Lösung auf.",
            parts: [
              for (var i = 0; i < list.items.length; i++)
                SelfAssessmentPart(
                  id: "$i",
                  label: "${i + 1}",
                  value: list.items[i],
                ),
            ],
            solutionBuilder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < list.items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("${i + 1}. ${list.items[i]}"),
                  ),
              ],
            ),
          ),
        ];
    }
  }

  Widget _orderTile(HistoryEntry e, int index, bool? ok) {
    final colors = context.colors;
    final q = question as OrderQuestion;

    final text = RegExp(r'\d').hasMatch(e.name) ? e.summary : e.name;

    return Card(
      key: ValueKey("order-${e.id}"),
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
        title: Text(text),
        subtitle: answered
            ? Text(
                "${e.dating!.label}"
                "${ok == false ? " · richtig: Platz ${q.correctOrder.indexOf(e) + 1}" : ""}",
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

  Widget _buildExplanation(QuizQuestion q) {
    final lecture = q.lectureId == null ? null : data.lecture(q.lectureId!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q is ChoiceQuestion && !correct) ...[
            Text(
              "Richtig: ${q.answer}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          Text(q.explanation, key: const ValueKey("quiz-explanation")),
          const SizedBox(height: 8),
          if (lecture != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.school_outlined, size: 18),
              label: Text(data.sourceLabel(lecture.id, q.slides, q.ref)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LectureDetailScreen(
                    data: data,
                    lectureId: lecture.id,
                    initialSlide: q.slides.firstOrNull,
                  ),
                ),
              ),
            )
          else
            Text(
              data.seminar == null
                  ? "Ergänzung – nicht aus den Vorlesungsfolien"
                  : "Ergänzung – nicht aus Vorlesung oder Proseminar",
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          if (q.entryIds.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final id in q.entryIds.take(4))
                  if (data.entry(id) != null)
                    ActionChip(
                      avatar: Icon(entryIcon(data.entry(id)!.type), size: 16),
                      label: Text(data.entry(id)!.name),
                      onPressed: () => openEntry(context, data, id),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}
