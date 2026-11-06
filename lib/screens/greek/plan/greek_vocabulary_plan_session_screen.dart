import 'package:flutter/material.dart';

import '../../../algorithms/vocabulary_plan.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_plan_service.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_plan_state.dart';
import '../../../services/greek/vocabulary/vocabulary_settings_service.dart';
import '../../../services/quiz_sound_settings.dart';
import '../../../services/statistics/learning_statistics.dart';
import '../../../services/streak/streak_track.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/self_assessment.dart';
import '../../../widgets/sound_volume_button.dart';
import '../../../widgets/trainer_widgets.dart';
import 'greek_vocabulary_introduction.dart';

/// Eine Lerneinheit des Griechisch-Lernplans: neue Vokabeln des Tages
/// vorstellen und abfragen, eingeführte wiederholen (siehe
/// [VocabularyPlanSession]).
///
/// Abgefragt wird mit Selbsteinschätzung („Im Kopf“): Griechisch zu
/// Deutsch, dann Lösung aufdecken und „Gewusst“ oder „Nicht gewusst“. Die
/// Eingabe mit griechischer Tastatur bleibt dem freien Vokabeltrainer
/// vorbehalten; beide teilen den Lernstand.
///
/// Jede Antwort wird sofort gespeichert; wird die Einheit abgebrochen, geht
/// nichts verloren.
class GreekVocabularyPlanSessionScreen extends StatefulWidget {
  final GreekVocabularyPlanState state;

  final GreekVocabularyPlanService service;

  const GreekVocabularyPlanSessionScreen({
    super.key,
    required this.state,
    required this.service,
  });

  @override
  State<GreekVocabularyPlanSessionScreen> createState() =>
      _GreekVocabularyPlanSessionScreenState();
}

class _GreekVocabularyPlanSessionScreenState
    extends State<GreekVocabularyPlanSessionScreen> {
  late VocabularyPlanSession<GreekVocabularyEntry> session =
      VocabularyPlanSession(state: state);

  PlanTask<GreekVocabularyEntry>? task;

  /// Zählt die Aufgaben, damit jede Abfrage eine eigene Instanz erhält.
  int taskNumber = 0;

  bool revealed = false;

  final GlobalKey<SelfAssessmentPanelState> _assessmentKey = GlobalKey();

  GreekVocabularyPlanState get state => widget.state;

  String? get uid => widget.service.uid;

  @override
  void initState() {
    super.initState();

    _next();
  }

  void _next() {
    final next = session.next();

    if (next is IntroduceTask<GreekVocabularyEntry>) {
      widget.service.introduce(state, next.entry);
    }

    setState(() {
      task = next;
      taskNumber++;
      revealed = false;
    });
  }

  void _restart() {
    setState(() => session = VocabularyPlanSession(state: state));

    _next();
  }

  void _assess(GreekVocabularyEntry entry, SelfAssessment assessment) {
    widget.service.saveCard(session.answer(entry, assessment.knew));

    reportTrainerAnswer(
      context,
      uid: uid,
      correct: assessment.knew,
      firstEvaluation: true,
      sound: SoundModule.greekVocabulary,
      trainer: StatisticsTrainer.greekVocabulary,
      track: StreakTrack.greek,
      source: StreakSource.vocabulary,
    );

    _next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Altgriechisch – Lerneinheit"),
        actions: const [SoundVolumeButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTask(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTask() {
    final current = task;

    return switch (current) {
      null => _buildSummary(),
      IntroduceTask<GreekVocabularyEntry>() => Column(
        children: [
          _header(current),
          GreekVocabularyIntroduction(
            entry: current.entry,
            mnemonic: _mnemonicOf(current.entry),
            onNext: _next,
          ),
        ],
      ),
      RecallTask<GreekVocabularyEntry>() => Column(
        key: ValueKey("greek-plan-task-$taskNumber"),
        children: [
          _header(current),
          GreekVocabularyLemma(entry: current.entry),
          const SizedBox(height: 20),
          SelfAssessmentPanel(
            key: _assessmentKey,
            revealed: revealed,
            onReveal: () => setState(() => revealed = true),
            onAssess: (a) => _assess(current.entry, a),
            solutionBuilder: (_) => Column(
              children: [
                GreekVocabularySolution(entry: current.entry),
                GreekVocabularyMnemonicText(text: _mnemonicOf(current.entry)),
              ],
            ),
            hint:
                "Übersetze im Kopf (mit Artikel, Genitiv bzw. Aorist) und "
                "decke dann die Lösung auf.",
          ),
        ],
      ),
    };
  }

  String? _mnemonicOf(GreekVocabularyEntry entry) =>
      state.cardOf(entry)?.mnemonic ?? entry.mnemonic;

  Widget _header(PlanTask<GreekVocabularyEntry> task) {
    final colors = context.colors;

    final label = switch (task) {
      IntroduceTask() => "Neue Vokabel",
      RecallTask(afterIntroduction: true) => "Neue Vokabel abfragen",
      RecallTask() => "Wiederholung",
    };

    final progress = session.questions == 0
        ? 0.0
        : (session.asked / session.questions).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "$label · ${VocabularySettings.stepLabel(task.entry.step)}",
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              Text(
                "${session.asked} / ${session.questions}",
                key: const ValueKey("greek-plan-session-count"),
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final colors = context.colors;

    final more = state.newToday.isNotEmpty || state.dueReviews.isNotEmpty;

    final nothingToDo = session.answered == 0 && session.introduced == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          nothingToDo ? Icons.inbox_rounded : Icons.check_circle_outline,
          size: 40,
          color: colors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          nothingToDo ? "Nichts zu lernen" : "Lerneinheit beendet",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          nothingToDo
              ? "Im Lernplan sind gerade keine neuen Vokabeln und keine "
                    "eingeführten Vokabeln zum Wiederholen."
              : "${session.answered} Antworten, davon ${session.correct} "
                    "gewusst. ${session.introduced} neue Vokabeln eingeführt.",
          key: const ValueKey("greek-plan-session-summary"),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (!nothingToDo)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey("greek-plan-session-again"),
              onPressed: _restart,
              child: Text(more ? "Weiterlernen" : "Freiwillig wiederholen"),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Zur Übersicht"),
          ),
        ),
      ],
    );
  }
}
