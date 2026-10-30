import 'package:flutter/material.dart';

import '../../../models/bible/course_reading_plan.dart';
import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/reading_plan_path.dart';
import '../../../services/bible/bible_reading_service.dart';
import '../../../services/bible/course_reading_schedule.dart';
import '../../../theme/app_theme.dart';
import 'book_study_screen.dart';
import 'book_widgets.dart';
import 'review_overview_screen.dart';

/// Lädt die Planung des Leseplans zum Stichtag; `null`, wenn der Plan nicht
/// verfügbar ist (keine Freigabe der Vorlesungsunterlagen).
typedef ReadingPathScheduleLoader =
    Future<CourseSchedule?> Function(String? uid, DateTime today);

/// Standard: der Leseplan aus dem [BibleReadingService] – mit eigenen
/// Änderungen (Termine, Stellen, Umfang „ganze Bücher“), sofern er dort
/// begonnen wurde, sonst die Empfehlung.
Future<CourseSchedule?> loadReadingPathSchedule(
  String? uid,
  DateTime today,
) async {
  final service = BibleReadingService.instance;

  await service.load(uid);
  await service.loadCourseExtent();

  final plan = service.coursePlan(ReadingPlanPath.defaultPlanId);
  final extent = service.courseExtent();

  if (plan == null || extent == null) return null;

  final progress =
      service.courseProgressOf(uid, plan.id) ??
      CourseReadingProgress(planId: plan.id, startedOn: CourseDates.key(today));

  return CourseSchedule.compute(
    plan: plan,
    progress: progress,
    today: today,
    extent: extent,
  );
}

/// „Nach Bibelleseplan lernen“: Übersicht des Lernpfads und Start der
/// Lerneinheiten. Gelernt wird mit denselben Lerneinheiten und Karten wie
/// beim Lernen einzelner Bücher.
class ReadingPathView extends StatelessWidget {
  final BookLearningController controller;

  final CourseSchedule schedule;

  const ReadingPathView({
    super.key,
    required this.controller,
    required this.schedule,
  });

  /// Mit dem aktuellen Lernstand (nach jeder Einheit neu).
  ReadingPlanPath _path() => ReadingPlanPath.build(
    planId: ReadingPlanPath.defaultPlanId,
    schedule: schedule,
    catalog: controller.catalog,
    settings: controller.state.data.readingPaths[ReadingPlanPath.defaultPlanId],
  );

  @override
  Widget build(BuildContext context) {
    final path = _path();
    final state = controller.state;

    final current = path.current;

    final children = <Widget>[];

    if (!path.started) {
      children.add(_StartCard(controller: controller, path: path));
    } else {
      children.add(
        _TodayCard(controller: controller, path: path, rebuild: _path),
      );
    }

    final progress = path.progress(state);

    final introduced = progress.total - progress.fresh;

    children.addAll([
      const SectionTitle("Gesamtfortschritt"),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "$introduced von ${progress.total} Perikopen eingeführt · "
                "${progress.secure} sicher",
                key: const ValueKey("path-progress"),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              LearningProgressBar(progress: progress, height: 8),
              const SizedBox(height: 8),
              Text(
                _targetText(path),
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
      const SectionTitle("Wochen"),
      for (final w in path.weeks)
        _WeekTile(
          controller: controller,
          path: path,
          week: w,
          current: current != null && w.id == current.id,
        ),
      const SizedBox(height: 12),
      Text(
        "Die Wochen folgen dem Leseplan zur Übung: Termine, Stellen und dein "
        "Umfang („ganze Bücher“) samt eigener Änderungen. Eine Perikope gehört "
        "zur ersten Woche, deren Stellen sie berührt. Der Lernstand ist "
        "derselbe wie bei „Einzelne Bücher“.",
        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  static String _targetText(ReadingPlanPath path) {
    final last = path.last;

    if (last == null) return "Der Plan hat keine Wochen mit Lektüre.";

    final days = path.daysLeftInPlan;

    final label = CourseDates.label(last.target);

    if (days == 0) return "Zieldatum $label – der Plan ist abgelaufen.";

    return "Zieldatum $label · noch $days ${days == 1 ? "Tag" : "Tage"}";
  }
}

String _books(List<String> books) => books.map(bookName).join(", ");

Future<void> _startPath(
  BuildContext context,
  BookLearningController controller,
  ReadingPlanPath Function() path, {
  PathWeek? ahead,
}) {
  return startStudy(
    context,
    controller: controller,
    session: controller.readingPathSession(path(), ahead: ahead),
    title: ahead == null ? "Nach Bibelleseplan" : "Vorauslernen",
    followUps: () => _followUps(controller, path),
  );
}

List<StudyFollowUp> _followUps(
  BookLearningController controller,
  ReadingPlanPath Function() path,
) {
  final now = path();
  final state = controller.state;

  final result = <StudyFollowUp>[];

  if (now.newToday(state) > 0 || now.dueReviews(state).isNotEmpty) {
    result.add(
      StudyFollowUp(
        label: "Weiterlernen",
        title: "Nach Bibelleseplan",
        session: () => controller.readingPathSession(path()),
        followUps: () => _followUps(controller, path),
      ),
    );
  }

  return result;
}

class _StartCard extends StatelessWidget {
  final BookLearningController controller;
  final ReadingPlanPath path;

  const _StartCard({required this.controller, required this.path});

  Future<void> _start(String startedOn) {
    return controller.setReadingPath(
      path.planId,
      ReadingPathSettings(startedOn: startedOn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = path.current;
    final first = path.weeks.isEmpty ? null : path.weeks.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Lernpfad nach Bibelleseplan",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              "Jede Woche führt die Perikopen der Bibelstellen ein, die der "
              "Leseplan für die nächste Sitzung vorsieht – verteilt auf die "
              "Tage bis zum Termin, dazu Wiederholungen. Was du schon gelernt "
              "hast, zählt mit.",
              style: TextStyle(color: context.colors.textSecondary),
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              Text(
                "Diese Woche: ${current.topic} (${_books(current.books)}), "
                "${current.pericopes.length} Perikopen bis "
                "${CourseDates.label(current.target, year: false)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey("path-begin"),
              onPressed: () => _start(CourseDates.key(path.today)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Ab dieser Woche beginnen"),
            ),
            if (first != null && first.date.isBefore(path.today))
              TextButton(
                key: const ValueKey("path-begin-all"),
                onPressed: () => _start(CourseDates.key(first.date)),
                child: const Text("Ab der ersten Woche (frühere nachholen)"),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final BookLearningController controller;
  final ReadingPlanPath path;

  final ReadingPlanPath Function() rebuild;

  const _TodayCard({
    required this.controller,
    required this.path,
    required this.rebuild,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final current = path.current;

    final newToday = path.newToday(state);
    final perDay = path.perDay(state);
    final backlog = path.backlog(state);
    final reviews = path.dueReviews(state);
    final ahead = path.aheadWeek(state);
    final learnedAhead = path.learnedAhead(state);

    final lines = <String>[
      if (newToday > 0)
        "Heute neu: $newToday ${newToday == 1 ? "Perikope" : "Perikopen"}"
      else if (path.freshDue(state).isEmpty)
        "Alle Perikopen bis zu dieser Woche sind eingeführt."
      else
        "Heutige Menge geschafft ($perDay neue am Tag).",
      if (backlog.isNotEmpty)
        "Rückstand aus früheren Wochen: ${backlog.length} – wird zuerst "
            "eingeführt.",
      reviews.isEmpty
          ? "Keine Wiederholung fällig."
          : "Wiederholungen fällig: ${reviews.length}",
      if (learnedAhead.isNotEmpty)
        "Schon gelernt aus späteren Wochen: ${learnedAhead.length}",
    ];

    return Card(
      key: const ValueKey("path-today"),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              current == null
                  ? "Der Leseplan ist abgeschlossen"
                  : "Woche ${current.number}: ${current.topic}",
              key: const ValueKey("path-current"),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (current != null) ...[
              const SizedBox(height: 2),
              Text(
                "${_books(current.books)} · bis "
                "${CourseDates.label(current.target, year: false)} · noch "
                "${path.daysLeftInWeek} "
                "${path.daysLeftInWeek == 1 ? "Tag" : "Tage"}",
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const ValueKey("path-start"),
              onPressed: () => _startPath(context, controller, rebuild),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(newToday > 0 ? "Lerneinheit starten" : "Wiederholen"),
            ),
            if (newToday == 0 && ahead != null)
              TextButton.icon(
                key: const ValueKey("path-ahead"),
                onPressed: () =>
                    _startPath(context, controller, rebuild, ahead: ahead),
                icon: const Icon(Icons.fast_forward_rounded),
                label: Text("Vorauslernen: Woche ${ahead.number}"),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  final BookLearningController controller;
  final ReadingPlanPath path;
  final PathWeek week;
  final bool current;

  const _WeekTile({
    required this.controller,
    required this.path,
    required this.week,
    required this.current,
  });

  Color _color(BuildContext context, PathWeekState s) => switch (s) {
    PathWeekState.done => context.colors.success,
    PathWeekState.current => context.colors.primary,
    PathWeekState.behind => context.colors.accent,
    PathWeekState.upcoming ||
    PathWeekState.beforeStart => context.colors.textSecondary,
  };

  Future<void> _open(BuildContext context) async {
    final learn = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _WeekSheet(controller: controller, week: week),
    );

    if (learn != true || !context.mounted) return;

    await startStudy(
      context,
      controller: controller,
      session: controller.readingPathWeekSession(week),
      title: "Woche ${week.number}",
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final s = path.stateOf(week, state);
    final progress = state.progressOf(week.pericopes);

    return Card(
      key: ValueKey("path-week-${week.id}"),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: current
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              side: BorderSide(color: context.colors.primary, width: 1.5),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Woche ${week.number}: ${week.topic}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusPill(label: s.label, color: _color(context, s)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "bis ${CourseDates.label(week.target, year: false)} · "
                "${week.pericopes.length} Perikopen"
                "${week.books.isEmpty ? "" : " · ${_books(week.books)}"}",
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              if (week.pericopes.isNotEmpty) ...[
                const SizedBox(height: 8),
                LearningProgressBar(progress: progress, height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekSheet extends StatelessWidget {
  final BookLearningController controller;
  final PathWeek week;

  const _WeekSheet({required this.controller, required this.week});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            "Woche ${week.number}: ${week.topic}",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            "Sitzung am ${CourseDates.label(week.date)}",
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (week.pericopes.isNotEmpty)
            ElevatedButton.icon(
              key: const ValueKey("path-week-learn"),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Diese Woche lernen"),
            ),
          const SizedBox(height: 8),
          for (final p in week.pericopes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.title),
              subtitle: Text(_reference(p)),
              trailing: PericopeStatusPills(status: state.statusOf(p)),
            ),
          if (week.pericopes.isEmpty)
            Text(
              "Zu den Stellen dieser Woche gibt es keine Perikopen in der "
              "Perikopenliste.",
              style: TextStyle(color: context.colors.textSecondary),
            ),
        ],
      ),
    );
  }

  static String _reference(BookPericope p) {
    final x = p.perikope;

    final start = "${x.startChapter},${x.startVerse}";

    final end = x.endChapter == x.startChapter
        ? "${x.endVerse}"
        : "${x.endChapter},${x.endVerse}";

    return "${p.book} $start–$end";
  }
}
