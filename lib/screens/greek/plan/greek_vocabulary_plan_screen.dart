import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../algorithms/review_state.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_plan_service.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_plan_state.dart';
import '../../../services/greek/vocabulary/vocabulary_settings_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';
import '../../../widgets/progress_summary_tile.dart';
import 'greek_vocabulary_plan_dialog.dart';
import 'greek_vocabulary_plan_session_screen.dart';

/// Übersicht des Griechisch-Lernplans: Plan beginnen oder ändern, was heute
/// ansteht, Fortschritt im Plan und je Lernschritt.
///
/// Der Plan ist vom freien Vokabeltrainer unabhängig konfiguriert, teilt
/// aber dessen Lernstand je Vokabel (siehe docs/architecture.md).
class GreekVocabularyPlanScreen extends StatefulWidget {
  /// Nur für Tests; sonst für den angemeldeten Nutzer bzw. Gast.
  final GreekVocabularyPlanService? service;

  const GreekVocabularyPlanScreen({super.key, this.service});

  @override
  State<GreekVocabularyPlanScreen> createState() =>
      _GreekVocabularyPlanScreenState();
}

class _GreekVocabularyPlanScreenState extends State<GreekVocabularyPlanScreen> {
  late final GreekVocabularyPlanService service =
      widget.service ??
      GreekVocabularyPlanService(uid: FirebaseAuth.instance.currentUser?.uid);

  GreekVocabularyPlanState? state;

  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await service.load();

      if (mounted) {
        setState(() {
          state = loaded;
          failed = false;
        });
      }
    } catch (e) {
      debugPrint("Lernplan konnte nicht geladen werden: $e");

      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> _editPlan(GreekVocabularyPlanState state) async {
    final result = await showGreekPlanDialog(
      context,
      current: state.plan,
      steps: state.units,
      remainingNewOf: (disabled) => state
          .progressOf(state.entries.where((e) => !disabled.contains(e.step)))
          .fresh,
      now: state.now,
    );

    if (result == null) return;

    try {
      await service.savePlan(state, result.plan);
    } catch (e) {
      debugPrint("Lernplan konnte nicht gespeichert werden: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Der Lernplan konnte nicht gespeichert werden."),
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _startSession(GreekVocabularyPlanState state) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GreekVocabularyPlanSessionScreen(state: state, service: service),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = this.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Altgriechisch – Lernplan"),
        actions: [
          if (state?.plan != null)
            IconButton(
              key: const ValueKey("greek-plan-edit"),
              tooltip: "Lernplan ändern",
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => _editPlan(state!),
            ),
        ],
      ),
      body: failed
          ? _Message(
              icon: Icons.cloud_off_rounded,
              text:
                  "Der Lernplan konnte nicht geladen werden. Bitte prüfe "
                  "deine Internetverbindung und versuche es erneut.",
              action: TextButton(
                onPressed: () {
                  setState(() => failed = false);
                  _load();
                },
                child: const Text("Erneut versuchen"),
              ),
            )
          : state == null
          ? const Center(child: CircularProgressIndicator())
          : state.entries.isEmpty
          ? const _Message(
              icon: Icons.inbox_rounded,
              text:
                  "Noch keine Vokabeln vorhanden. Sobald Vokabeln ergänzt "
                  "sind, kann hier ein Lernplan beginnen.",
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: state.plan == null
                      ? _buildStart(state)
                      : _buildPlan(state),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildStart(GreekVocabularyPlanState state) {
    final known = state.entries.where(state.isIntroduced).length;

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Vokabeln nach Plan lernen",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                "Der Lernplan führt die Vokabeln Lernschritt für Lernschritt "
                "ein – "
                "so viele am Tag, wie du festlegst – und mischt fällige "
                "Wiederholungen dazu. Der freie Vokabeltrainer bleibt "
                "unabhängig nutzbar; beide teilen deinen Lernstand.",
              ),
              if (known > 0) ...[
                const SizedBox(height: 8),
                Text(
                  "$known Vokabeln hast du schon gelernt. Sie werden "
                  "übernommen und im Plan wiederholt.",
                  key: const ValueKey("greek-plan-known"),
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey("greek-plan-start"),
                onPressed: () => _editPlan(state),
                icon: const Icon(Icons.event_note_rounded),
                label: const Text("Lernplan beginnen"),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      ProgressSummaryTile(
        title: "Alle Vokabeln",
        summary: state.progressOf(state.entries),
      ),
    ];
  }

  List<Widget> _buildPlan(GreekVocabularyPlanState state) {
    final plan = state.plan!;
    final scope = state.scope;
    final summary = state.progressOf(scope);
    final current = state.currentUnit;

    final excluded = [
      for (final step in state.units)
        if (!plan.includesStep(step)) step,
    ];

    return [
      _TodayCard(state: state, onStart: () => _startSession(state)),
      const SizedBox(height: 12),
      ProgressSummaryTile(title: "Fortschritt im Plan", summary: summary),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(
          _planDescription(state, summary),
          key: const ValueKey("greek-plan-description"),
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ),
      const SizedBox(height: 16),
      Text("Lernschritte", style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      for (final step in state.planUnits)
        InkWell(
          key: ValueKey("greek-plan-step-$step"),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showStep(state, step),
          child: ProgressSummaryTile(
            title: step == current
                ? "${VocabularySettings.stepLabel(step)} · aktuell"
                : VocabularySettings.stepLabel(step),
            summary: state.progressOf(state.entriesOfUnit(step)),
          ),
        ),
      if (excluded.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "Nicht im Plan: "
            "${excluded.map(VocabularySettings.stepLabel).join(", ")}",
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
    ];
  }

  String _planDescription(
    GreekVocabularyPlanState state,
    ProgressSummary summary,
  ) {
    final plan = state.plan!;

    final introduced = summary.total - summary.fresh;

    final parts = [
      "Eingeführt: $introduced von ${summary.total}",
      plan.paused ? "pausiert" : "${plan.dailyNew} neue pro Tag",
      if (plan.targetDate != null) "Ziel ${formatDate(plan.targetDate!)}",
    ];

    final done = state.expectedCompletion;

    final tail = summary.fresh == 0
        ? "Alle Vokabeln des Plans sind eingeführt."
        : done == null
        ? ""
        : "Voraussichtlich alle eingeführt am ${formatDate(done)}.";

    return "${parts.join(" · ")}. $tail".trim();
  }

  void _showStep(GreekVocabularyPlanState state, int step) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) {
          final words = state.entriesOfUnit(step);

          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                VocabularySettings.stepLabel(step),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final e in words) _WordTile(entry: e, state: state),
            ],
          );
        },
      ),
    );
  }
}

/// Was heute ansteht.
class _TodayCard extends StatelessWidget {
  final GreekVocabularyPlanState state;
  final VoidCallback onStart;

  const _TodayCard({required this.state, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final plan = state.plan!;

    final newToday = state.newToday;
    final doneToday = state.introducedOn(state.now);
    final due = state.dueReviews;

    final started = state.scope.where(state.isIntroduced).length;

    final open = newToday.isNotEmpty || due.isNotEmpty;

    Widget chips(List<GreekVocabularyEntry> words, {bool done = false}) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in words)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: done
                  ? Icon(Icons.check_rounded, size: 16, color: colors.success)
                  : null,
              label: Text(e.lemma),
            ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Heute", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (plan.paused)
              Text(
                "Der Plan ist pausiert: keine neuen Vokabeln. "
                "Wiederholungen sind weiter möglich.",
                style: TextStyle(color: colors.textSecondary),
              )
            else ...[
              Text(
                "Neue Vokabeln: ${newToday.length}"
                "${doneToday.isEmpty ? "" : " (schon eingeführt: ${doneToday.length})"}",
                key: const ValueKey("greek-plan-new-today"),
              ),
              if (newToday.isNotEmpty) ...[
                const SizedBox(height: 6),
                chips(newToday),
              ],
              if (doneToday.isNotEmpty) ...[
                const SizedBox(height: 6),
                chips(doneToday, done: true),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              "Fällige Wiederholungen: ${due.length}",
              key: const ValueKey("greek-plan-due"),
            ),
            if (due.isNotEmpty) ...[
              const SizedBox(height: 6),
              chips(due.take(12).toList()),
              if (due.length > 12)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "und ${due.length - 12} weitere",
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (!open)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  started == 0
                      ? "Gerade steht nichts an."
                      : "Für heute ist alles erledigt. Du kannst trotzdem "
                            "wiederholen.",
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ElevatedButton.icon(
              key: const ValueKey("greek-plan-session"),
              onPressed: open || started > 0 ? onStart : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(open ? "Lerneinheit starten" : "Wiederholen"),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  final GreekVocabularyEntry entry;
  final GreekVocabularyPlanState state;

  const _WordTile({required this.entry, required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = state.statusOf(entry);

    final label = status == ReviewState.fresh
        ? "Noch nicht eingeführt"
        : status.label;

    final color = switch (status) {
      ReviewState.fresh => colors.textSecondary,
      ReviewState.due => colors.accent,
      ReviewState.stable => colors.success,
    };

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(entry.lemma),
      subtitle: Text(entry.translations.join(", ")),
      trailing: Text(label, style: TextStyle(color: color, fontSize: 12.5)),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }
}
