import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../algorithms/review_state.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../services/latin/vocabulary/latin_vocabulary_plan_service.dart';
import '../../../services/latin/vocabulary/latin_vocabulary_plan_state.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';
import '../../../widgets/progress_summary_tile.dart';
import 'latin_vocabulary_plan_dialog.dart';
import 'latin_vocabulary_plan_session_screen.dart';

/// Übersicht des Latein-Lernplans: Plan beginnen oder ändern, was heute
/// ansteht, Fortschritt im Plan und je Lektion.
///
/// Der Plan ist vom freien Vokabeltrainer unabhängig konfiguriert, teilt
/// aber dessen Lernstand je Vokabel (siehe docs/latin.md).
class LatinVocabularyPlanScreen extends StatefulWidget {
  /// Nur für Tests; sonst für den angemeldeten Nutzer bzw. Gast.
  final LatinVocabularyPlanService? service;

  const LatinVocabularyPlanScreen({super.key, this.service});

  @override
  State<LatinVocabularyPlanScreen> createState() =>
      _LatinVocabularyPlanScreenState();
}

class _LatinVocabularyPlanScreenState extends State<LatinVocabularyPlanScreen> {
  late final LatinVocabularyPlanService service =
      widget.service ??
      LatinVocabularyPlanService(uid: FirebaseAuth.instance.currentUser?.uid);

  LatinVocabularyPlanState? state;

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

  Future<void> _editPlan(LatinVocabularyPlanState state) async {
    final result = await showLatinPlanDialog(
      context,
      current: state.plan,
      lessons: state.lessons,
      remainingNewOf: (disabled) => state
          .progressOf(state.entries.where((e) => !disabled.contains(e.lesson)))
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

  Future<void> _startSession(LatinVocabularyPlanState state) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LatinVocabularyPlanSessionScreen(state: state, service: service),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = this.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Latein – Lernplan"),
        actions: [
          if (state?.plan != null)
            IconButton(
              key: const ValueKey("latin-plan-edit"),
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

  List<Widget> _buildStart(LatinVocabularyPlanState state) {
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
                "Der Lernplan führt die Vokabeln Lektion für Lektion ein – "
                "so viele am Tag, wie du festlegst – und mischt fällige "
                "Wiederholungen dazu. Der freie Vokabeltrainer bleibt "
                "unabhängig nutzbar; beide teilen deinen Lernstand.",
              ),
              if (known > 0) ...[
                const SizedBox(height: 8),
                Text(
                  "$known Vokabeln hast du schon gelernt. Sie werden "
                  "übernommen und im Plan wiederholt.",
                  key: const ValueKey("latin-plan-known"),
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey("latin-plan-start"),
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

  List<Widget> _buildPlan(LatinVocabularyPlanState state) {
    final plan = state.plan!;
    final scope = state.scope;
    final summary = state.progressOf(scope);
    final current = state.currentLesson;

    final excluded = [
      for (final lesson in state.lessons)
        if (!plan.includesLesson(lesson)) lesson,
    ];

    return [
      _TodayCard(state: state, onStart: () => _startSession(state)),
      const SizedBox(height: 12),
      ProgressSummaryTile(title: "Fortschritt im Plan", summary: summary),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(
          _planDescription(state, summary),
          key: const ValueKey("latin-plan-description"),
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ),
      const SizedBox(height: 16),
      Text("Lektionen", style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      for (final lesson in state.planLessons)
        InkWell(
          key: ValueKey("latin-plan-lesson-$lesson"),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showLesson(state, lesson),
          child: ProgressSummaryTile(
            title: lesson == current
                ? "Lektion $lesson · aktuell"
                : "Lektion $lesson",
            summary: state.progressOf(state.entriesOfLesson(lesson)),
          ),
        ),
      if (excluded.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "Nicht im Plan: ${excluded.map((l) => "Lektion $l").join(", ")}",
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
    ];
  }

  String _planDescription(
    LatinVocabularyPlanState state,
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

  void _showLesson(LatinVocabularyPlanState state, int lesson) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) {
          final words = state.entriesOfLesson(lesson);

          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                "Lektion $lesson",
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
  final LatinVocabularyPlanState state;
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

    Widget chips(List<LatinVocabularyEntry> words, {bool done = false}) {
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
                key: const ValueKey("latin-plan-new-today"),
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
              key: const ValueKey("latin-plan-due"),
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
              key: const ValueKey("latin-plan-session"),
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
  final LatinVocabularyEntry entry;
  final LatinVocabularyPlanState state;

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
