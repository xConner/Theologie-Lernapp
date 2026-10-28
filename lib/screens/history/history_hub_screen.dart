import 'dart:math';

import 'package:flutter/material.dart';

import '../../algorithms/review_state.dart';
import '../../models/history/history_course.dart';
import '../../services/history/history_cards.dart';
import '../../services/history/history_lesson.dart';
import '../../services/history/history_trainer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import 'history_lesson_screen.dart';
import 'history_practice_screen.dart';
import 'history_timeline_screen.dart';
import 'history_widgets.dart';

/// Startseite von „Geschichte Schritt für Schritt“ in einem Bereich
/// (Kirchengeschichte oder Altes Testament): wo es weitergeht, der
/// Lernpfad in kleinen Schritten, die Übungsmodi und der Zeitstrahl.
///
/// Alle Ansichten teilen ein [HistoryCardBook], das beim Öffnen geladen
/// wird; nur sie schreiben die Karten `…|h.…`, daher genügt nach jeder
/// Rückkehr ein Neuzeichnen (kein Neuladen, das gerade verbuchte Antworten
/// überholen könnte).
class HistoryHubScreen extends StatefulWidget {
  final HistoryArea area;
  final Future<HistoryCourse> Function() loadCourse;
  final HistoryCardStore store;
  final String? uid;

  /// Nur für Tests: feste Zufallsquelle.
  final Random? random;

  const HistoryHubScreen({
    super.key,
    required this.area,
    required this.loadCourse,
    required this.store,
    this.uid,
    this.random,
  });

  @override
  State<HistoryHubScreen> createState() => _HistoryHubScreenState();
}

class _HistoryHubScreenState extends State<HistoryHubScreen> {
  HistoryTrainer? trainer;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final course = await widget.loadCourse();
      final book = HistoryCardBook(
        store: widget.store,
        cards: await widget.store.load(),
      );
      book.onSaveError = (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Der Lernstand konnte nicht gespeichert werden."),
          ),
        );
      };
      if (!mounted) return;
      setState(
        () => trainer = HistoryTrainer(
          course: course,
          book: book,
          random: widget.random,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _open(Widget Function(HistoryTrainer trainer) screen) async {
    final t = trainer!;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen(t)));
    if (mounted) setState(() {});
  }

  void _openLesson(HistoryLesson lesson) {
    _open(
      (t) => HistoryLessonScreen(
        trainer: t,
        lesson: lesson,
        area: widget.area,
        uid: widget.uid,
        onOpenLesson: (next) {
          Navigator.pop(context);
          _openLesson(next);
        },
      ),
    );
  }

  void _openMode(HistoryMode mode) {
    _open(
      (t) => HistoryPracticeScreen(
        trainer: t,
        mode: mode,
        area: widget.area,
        uid: widget.uid,
      ),
    );
  }

  Future<void> _reset() async {
    final t = trainer!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lernpfad zurücksetzen?"),
        content: const Text(
          "Der Lernstand von „Geschichte Schritt für Schritt“ in diesem "
          "Bereich wird gelöscht. Wissensquiz, Lernmodus, Einstellungen und "
          "Favoriten bleiben unverändert.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            key: const ValueKey("history-reset-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Zurücksetzen"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = {
      for (final item in t.course.items) ...t.cardsOf(item.id),
      for (final id in t.book.cards.keys)
        if (HistoryCardBook.isHistoryCard(id) &&
            t.course.sequences.any((s) => id.startsWith("${s.id}/")))
          id,
    };
    try {
      await t.book.reset(ids);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Zurücksetzen fehlgeschlagen.")),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = trainer;
    final title = "Geschichte Schritt für Schritt";

    if (t == null) {
      return ContentPage(
        title: title,
        children: [
          error != null
              ? const EmptyHint("Der Lernpfad konnte nicht geladen werden.")
              : const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
        ],
      );
    }

    final course = t.course;
    final secondary = TextStyle(color: context.colors.textSecondary);
    final overall = HistoryLessonProgress.of(t, course.items);
    final next = course.lessons
        .where((l) => course.itemsOfLesson(l).any((i) => !t.isIntroduced(i.id)))
        .firstOrNull;
    final parts = <String, List<HistoryLesson>>{};
    for (final l in course.lessons) {
      parts.putIfAbsent(l.part, () => []).add(l);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey("history-menu"),
            onSelected: (_) => _reset(),
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const ValueKey("history-reset"),
                value: "reset",
                enabled: t.book.cards.keys.any(HistoryCardBook.isHistoryCard),
                child: const Text("Lernpfad zurücksetzen"),
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
                    "${widget.area.title}: Zeiträume, Personen und Ereignisse "
                    "in kleinen Schritten – erst kennenlernen, dann abrufen, "
                    "dann verknüpfen. Quelle: ${course.sourceName}.",
                    style: secondary,
                  ),
                  const SizedBox(height: 12),
                  _ProgressLine(progress: overall),
                  const SizedBox(height: 12),
                  _continueCard(context, t, next, overall),

                  const ContentSectionTitle("Üben"),
                  for (final mode in HistoryMode.values)
                    _ModeTile(mode: mode, onTap: () => _openMode(mode)),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      key: const ValueKey("history-open-timeline"),
                      leading: const Icon(Icons.timeline_rounded),
                      title: const Text("Zeitstrahl"),
                      subtitle: const Text(
                        "Überblick und Einzelheiten; filtern, Jahreszahlen "
                        "verdecken. Nichts ist gesperrt.",
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(
                        (t) => HistoryTimelineScreen(
                          trainer: t,
                          area: widget.area,
                          uid: widget.uid,
                        ),
                      ),
                    ),
                  ),

                  const ContentSectionTitle("Lernpfad"),
                  Text(
                    "Jeder Schritt stellt höchstens vier Inhalte vor. Die "
                    "Reihenfolge ist ein Vorschlag; jeder Schritt lässt sich "
                    "jederzeit öffnen oder wiederholen.",
                    style: secondary.copyWith(fontSize: 12.5),
                  ),
                  for (final part in parts.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        part.key,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final lesson in part.value)
                      _LessonTile(
                        lesson: lesson,
                        progress: HistoryLessonProgress.of(
                          t,
                          course.itemsOfLesson(lesson),
                        ),
                        isNext: lesson == next,
                        onTap: () => _openLesson(lesson),
                      ),
                  ],
                  InfoReportFooter(module: widget.area.module),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _continueCard(
    BuildContext context,
    HistoryTrainer t,
    HistoryLesson? next,
    HistoryLessonProgress overall,
  ) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final due = overall.cards.due;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (next != null) ...[
              Text(
                overall.introduced == 0 ? "Hier beginnen" : "Weiter mit",
                style: secondary,
              ),
              const SizedBox(height: 4),
              Text(next.title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                [
                  for (final i in t.course.itemsOfLesson(next)) i.name,
                ].join(" · "),
                style: secondary.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const ValueKey("history-continue"),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  overall.introduced == 0
                      ? "Ersten Lernschritt starten"
                      : "Nächsten Lernschritt starten",
                ),
                onPressed: () => _openLesson(next),
              ),
            ] else
              Text(
                "Alle Lernschritte sind eingeführt. Weiter geht es mit der "
                "gemischten Wiederholung und den Übungsmodi.",
                style: secondary,
              ),
            if (overall.introduced > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey("history-review"),
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  due > 0
                      ? "Wiederholen ($due ${due == 1 ? "Karte" : "Karten"} fällig)"
                      : "Gemischt wiederholen",
                ),
                onPressed: () => _openMode(HistoryMode.mixed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final HistoryLessonProgress progress;

  const _ProgressLine({required this.progress});

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(
      color: context.colors.textSecondary,
      fontSize: 12.5,
    );
    final cards = progress.cards;

    return Column(
      key: const ValueKey("history-progress"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress.total == 0 ? 0 : progress.introduced / progress.total,
        ),
        const SizedBox(height: 6),
        Text(
          [
            "${progress.introduced} von ${progress.total} Inhalten eingeführt",
            if (!cards.isEmpty) ...[
              "${cards.stable} ${ReviewState.stable.label.toLowerCase()}",
              "${cards.due} ${ReviewState.due.label.toLowerCase()}",
            ],
          ].join(" · "),
          style: secondary,
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  final HistoryMode mode;
  final VoidCallback onTap;

  const _ModeTile({required this.mode, required this.onTap});

  IconData get _icon => switch (mode) {
    HistoryMode.people => Icons.person_search_rounded,
    HistoryMode.dates => Icons.event_rounded,
    HistoryMode.chronology => Icons.swap_vert_rounded,
    HistoryMode.connections => Icons.hub_outlined,
    HistoryMode.mixed => Icons.shuffle_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: ValueKey("history-mode-${mode.name}"),
        leading: Icon(_icon),
        title: Text(mode.label),
        subtitle: Text(mode.description),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final HistoryLesson lesson;
  final HistoryLessonProgress progress;
  final bool isNext;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.progress,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = progress.status;
    final colors = context.colors;
    final icon = switch (status) {
      LessonStatus.fresh => Icons.radio_button_unchecked_rounded,
      LessonStatus.started => Icons.timelapse_rounded,
      LessonStatus.introduced => Icons.check_circle_outline_rounded,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        key: ValueKey("history-lesson-${lesson.id}"),
        leading: Icon(
          icon,
          color: status == LessonStatus.introduced
              ? colors.success
              : isNext
              ? colors.primary
              : colors.textSecondary,
        ),
        title: Text(lesson.title),
        subtitle: Text(
          [
            "${status.label} · ${progress.introduced}/${progress.total} Inhalte",
            if (progress.cards.due > 0) "${progress.cards.due} zum Wiederholen",
          ].join(" · "),
        ),
        trailing: isNext ? Tag("weiter", color: colors.primary) : null,
        onTap: onTap,
      ),
    );
  }
}
