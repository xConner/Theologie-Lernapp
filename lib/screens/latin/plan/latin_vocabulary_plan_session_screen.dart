import 'package:flutter/material.dart';

import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../services/latin/vocabulary/latin_vocabulary_plan_service.dart';
import '../../../services/latin/vocabulary/latin_vocabulary_plan_state.dart';
import '../../../services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import '../../../services/quiz_sound_settings.dart';
import '../../../services/statistics/learning_statistics.dart';
import '../../../services/streak/streak_track.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/self_assessment.dart';
import '../../../widgets/settings_access.dart';
import '../../../widgets/sound_volume_button.dart';
import '../../../widgets/trainer_widgets.dart';
import '../latin_vocabulary_answer_view.dart';

/// Eine Lerneinheit des Latein-Lernplans: neue Vokabeln des Tages vorstellen
/// und abfragen, eingeführte wiederholen (siehe [LatinPlanSession]).
///
/// Jede Antwort wird sofort gespeichert; wird die Einheit abgebrochen, geht
/// nichts verloren, und die nächste Einheit setzt am gespeicherten Stand an.
class LatinVocabularyPlanSessionScreen extends StatefulWidget {
  final LatinVocabularyPlanState state;

  final LatinVocabularyPlanService service;

  final LatinVocabularySettingsService settingsService;

  LatinVocabularyPlanSessionScreen({
    super.key,
    required this.state,
    required this.service,
    LatinVocabularySettingsService? settingsService,
  }) : settingsService = settingsService ?? LatinVocabularySettingsService();

  @override
  State<LatinVocabularyPlanSessionScreen> createState() =>
      _LatinVocabularyPlanSessionScreenState();
}

class _LatinVocabularyPlanSessionScreenState
    extends State<LatinVocabularyPlanSessionScreen> {
  late LatinPlanSession session;

  LatinPlanTask? task;

  /// Zählt die Aufgaben, damit jede Abfrage eine eigene Instanz erhält.
  int taskNumber = 0;

  bool loading = true;

  LatinVocabularySettings settings = const LatinVocabularySettings();

  AnswerMethod method = AnswerMethod.typing;

  LatinVocabularyPlanState get state => widget.state;

  String? get uid => widget.service.uid;

  @override
  void initState() {
    super.initState();

    _start();
  }

  Future<void> _start() async {
    try {
      final results = await Future.wait<Object>([
        widget.settingsService.load(uid),
        AnswerMethodPreference.load(AnswerMethodPreference.latinVocabulary),
      ]);

      settings = results[0] as LatinVocabularySettings;
      method = results[1] as AnswerMethod;
    } catch (e) {
      // Ohne gespeicherte Abfrage-Einstellungen gelten die Vorgaben.
      debugPrint("Einstellungen konnten nicht geladen werden: $e");
    }

    if (!mounted) return;

    session = LatinPlanSession(state: state);

    setState(() => loading = false);

    _next();
  }

  void _next() {
    final next = session.next();

    if (next is LatinIntroduceTask) {
      widget.service.introduce(state, next.entry);
    }

    setState(() {
      task = next;
      taskNumber++;
    });
  }

  void _restart() {
    setState(() => session = LatinPlanSession(state: state));

    _next();
  }

  void _evaluated(
    LatinVocabularyEntry entry,
    bool correct, {
    required bool firstEvaluation,
  }) {
    // Je Abfrage zählt nur die erste Bewertung.
    if (firstEvaluation) {
      widget.service.saveCard(session.answer(entry, correct));
    }

    reportTrainerAnswer(
      context,
      uid: uid,
      correct: correct,
      firstEvaluation: firstEvaluation,
      sound: SoundModule.latinVocabulary,
      trainer: StatisticsTrainer.latinVocabulary,
      track: StreakTrack.latin,
      source: StreakSource.vocabulary,
    );
  }

  Future<void> _saveMnemonic(LatinVocabularyEntry entry, String? text) async {
    final card = state.cardFor(entry);

    card.mnemonic = text;

    await widget.service.learning.saveLatinCard(uid, card);

    if (mounted) setState(() {});
  }

  void _setMethod(AnswerMethod value) {
    if (value == method) return;

    setState(() => method = value);

    AnswerMethodPreference.save(AnswerMethodPreference.latinVocabulary, value);
  }

  void _openSettings() {
    var draft = settings;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ModuleSettingsDialog(
              moduleLabel: "Lernplan",
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Einstellungen"),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      // Gleiche Abfrage-Einstellungen wie im Vokabeltrainer;
                      // dessen Lektions- und Wortartfilter bleiben unberührt.
                      await widget.settingsService.save(uid, draft);

                      if (!context.mounted) return;

                      Navigator.pop(context);

                      setState(() => settings = draft);
                    },
                  ),
                ],
              ),
              moduleSettings: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LatinQuerySettingsSection(
                      settings: draft,
                      onChanged: (value) => setDialogState(() => draft = value),
                    ),
                    const SoundSettingsSection(
                      module: SoundModule.latinVocabulary,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Latein – Lerneinheit"),
        actions: [
          const SoundVolumeButton(),
          IconButton(
            tooltip: "Einstellungen",
            icon: const Icon(Icons.settings),
            onPressed: loading ? null : _openSettings,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
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
      LatinIntroduceTask() => Column(
        children: [
          _header(current),
          _IntroductionCard(
            key: ValueKey("intro-$taskNumber"),
            entry: current.entry,
            mnemonic: state.cardOf(current.entry)?.mnemonic,
            onNext: _next,
          ),
        ],
      ),
      LatinRecallTask() => Column(
        children: [
          _header(current),
          LatinVocabularyAnswerView(
            key: ValueKey("task-$taskNumber"),
            entry: current.entry,
            settings: settings,
            method: method,
            onMethodChanged: _setMethod,
            onEvaluated: (correct, {required firstEvaluation}) => _evaluated(
              current.entry,
              correct,
              firstEvaluation: firstEvaluation,
            ),
            onNext: _next,
            mnemonic: state.cardOf(current.entry)?.mnemonic,
            onSaveMnemonic: (text) => _saveMnemonic(current.entry, text),
            extraReportDetails: const {"Modus": "Lernplan"},
          ),
        ],
      ),
    };
  }

  Widget _header(LatinPlanTask task) {
    final colors = context.colors;

    final label = switch (task) {
      LatinIntroduceTask() => "Neue Vokabel",
      LatinRecallTask(afterIntroduction: true) => "Neue Vokabel abfragen",
      LatinRecallTask() => "Wiederholung",
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
                  "$label · Lektion ${task.entry.lesson}",
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              Text(
                "${session.asked} / ${session.questions}",
                key: const ValueKey("latin-plan-session-count"),
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
                    "richtig. ${session.introduced} neue Vokabeln eingeführt.",
          key: const ValueKey("latin-plan-session-summary"),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (!nothingToDo)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey("latin-plan-session-again"),
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

/// Vorstellung einer neuen Vokabel mit allen Angaben.
class _IntroductionCard extends StatelessWidget {
  final LatinVocabularyEntry entry;
  final String? mnemonic;
  final VoidCallback onNext;

  const _IntroductionCard({
    super.key,
    required this.entry,
    required this.mnemonic,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          entry.lemma,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        if (entry.form != null) ...[
          const SizedBox(height: 4),
          Text(
            entry.form!,
            style: TextStyle(fontSize: 18, color: colors.textSecondary),
          ),
        ],
        if (entry.gender != null) Text("Genus: ${entry.gender}"),
        const SizedBox(height: 16),
        SelectableText(
          entry.translations.join(", "),
          key: const ValueKey("latin-plan-intro-translation"),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (entry.note != null) ...[
          const SizedBox(height: 12),
          Text(
            entry.note!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
        if (mnemonic != null && mnemonic!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Eselsbrücke: $mnemonic",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          "Gleich wird die Vokabel abgefragt.",
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey("latin-plan-intro-next"),
            onPressed: onNext,
            child: const Text("Weiter"),
          ),
        ),
      ],
    );
  }
}
