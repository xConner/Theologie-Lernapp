import 'package:flutter/material.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/bible/course_reading_plan.dart';
import '../../models/bible/reading_plan.dart';
import '../../models/old_testament/old_testament.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/bible/course_reading_schedule.dart';
import '../../services/bible/reading_plan_text.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_input.dart';
import '../../widgets/bible/bible_reading_widgets.dart';
import '../old_testament/old_testament_widgets.dart';
import '../old_testament/unit_detail_screen.dart';
import 'bible_reader_screen.dart';

/// Leseplan zu einer Lehrveranstaltung: Was bis zur nächsten Sitzung zu
/// lesen ist, das heutige Pensum, alle Sitzungen mit Terminen und
/// Lesestellen sowie eigene Anpassungen.
class CourseReadingPlanScreen extends StatefulWidget {
  /// null = Gast.
  final String? uid;

  final String planId;

  // Nur für Tests ersetzbar.
  final BibleReadingService? service;
  final BibleRepository? repository;

  const CourseReadingPlanScreen({
    super.key,
    required this.uid,
    required this.planId,
    this.service,
    this.repository,
  });

  @override
  State<CourseReadingPlanScreen> createState() =>
      _CourseReadingPlanScreenState();
}

class _CourseReadingPlanScreenState extends State<CourseReadingPlanScreen> {
  late final BibleReadingService service =
      widget.service ?? BibleReadingService.instance;

  String? get uid => widget.uid;

  String get planId => widget.planId;

  @override
  void initState() {
    super.initState();

    service.load(uid);
    service.loadCourseExtent();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final plan = service.coursePlan(planId);

        return Scaffold(
          appBar: AppBar(title: Text(plan?.name ?? "Leseplan")),
          body: plan == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("Dieser Leseplan ist nicht verfügbar."),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _content(context, plan),
                  ),
                ),
        );
      },
    );
  }

  Widget _content(BuildContext context, CourseReadingPlan plan) {
    final progress = service.courseProgressOf(uid, planId);
    final schedule = service.courseSchedule(uid, planId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _header(context, plan),
        const SizedBox(height: 16),
        if (!service.isLoaded(uid))
          Text(
            "Dein Fortschritt konnte nicht geladen werden.",
            style: TextStyle(color: context.colors.textSecondary),
          )
        else if (progress == null) ...[
          FilledButton.icon(
            key: const ValueKey("course-plan-start"),
            onPressed: () => service.startCoursePlan(uid, planId),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text("Plan beginnen"),
          ),
          const SizedBox(height: 24),
          _preview(context, plan),
        ] else if (schedule == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _today(context, schedule),
          const SizedBox(height: 12),
          if (schedule.next case final next?) _next(context, next),
          if (schedule.overdue.isNotEmpty) ...[
            const SizedBox(height: 12),
            _overdue(context, schedule),
          ],
          const SizedBox(height: 4),
          _ScopeSwitch(
            schedule: schedule,
            value: progress.wholeBooks,
            onChanged: (value) => _setWholeBooks(value),
          ),
          SwitchListTile(
            key: const ValueKey("course-finish-eve"),
            contentPadding: EdgeInsets.zero,
            title: const Text("Bis zum Vorabend fertig lesen"),
            subtitle: const Text(
              "Sonst wird bis zum Sitzungstag geplant. Spätester Termin ist "
              "immer der Sitzungstag.",
            ),
            value: progress.finishEve,
            onChanged: (value) =>
                service.setCourseFinishEve(uid, planId, value),
          ),
          const Divider(height: 32),
          Text("Sitzungen", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._sessions(context, schedule),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey("course-plan-pause"),
                onPressed: () =>
                    service.setCoursePaused(uid, planId, !progress.paused),
                icon: Icon(
                  progress.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
                label: Text(progress.paused ? "Fortsetzen" : "Pausieren"),
              ),
              OutlinedButton.icon(
                key: const ValueKey("course-plan-end"),
                onPressed: () => _end(plan),
                icon: const Icon(Icons.stop_rounded),
                label: const Text("Plan beenden"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progress.paused
                ? "Pausiert: Der Plan erscheint nicht mehr mit einem "
                      "Tagespensum auf der Startseite der Bibel. Dein "
                      "Fortschritt bleibt erhalten."
                : "Pausieren blendet das Tagespensum auf der Startseite aus "
                      "und behält den Fortschritt; Beenden löscht ihn.",
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, CourseReadingPlan plan) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [plan.course, ?plan.lecturer, ?plan.semester].join(" · "),
          style: textTheme.titleSmall,
        ),
        if (plan.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(plan.description),
        ],
        const SizedBox(height: 8),
        Text("Quelle: ${plan.source}", style: secondary),
      ],
    );
  }

  /// Vor dem Start: Termine und Stellen.
  Widget _preview(BuildContext context, CourseReadingPlan plan) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Sitzungen", style: textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final s in plan.sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${CourseDates.label(s.date)} · ${s.topic}",
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SourceBadge(source: s.readingSource),
                    Text(
                      s.readings.isEmpty
                          ? "Keine Lesestellen"
                          : s.readings.map((r) => r.label).join("; "),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================
  // HEUTE
  // ==========================

  Widget _today(BuildContext context, CourseSchedule schedule) {
    final textTheme = Theme.of(context).textTheme;
    final pieces = schedule.todayPieces;
    final open = pieces.where((p) => !p.done).toList();

    final next = schedule.next;
    final ahead = next == null
        ? null
        : next.open.isEmpty
        ? schedule.after(next)
        : null;

    return Card(
      key: const ValueKey("course-today"),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Heute · ${CourseDates.label(schedule.today, year: false)}",
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (pieces.isEmpty)
              Text(
                next == null
                    ? "Für die kommenden Sitzungen ist nichts mehr offen."
                    : next.open.isEmpty
                    ? "Für die nächste Sitzung ist alles gelesen."
                    : "Heute ist nichts eingeplant. Der Lesezeitraum für "
                          "„${next.session.topic}“ beginnt am "
                          "${CourseDates.label(next.windowStart, year: false)}.",
                key: const ValueKey("course-today-empty"),
              )
            else ...[
              Text(
                "${compactLabel([for (final p in pieces) p.piece])} · "
                "${ReadingPlanExtent.formatMinutes(_minutes(pieces))}",
                key: const ValueKey("course-today-summary"),
              ),
              const SizedBox(height: 8),
              _PieceChips(
                pieces: pieces,
                onChanged: (piece, value) => _setPieces([piece], value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey("course-today-read"),
                    onPressed: () =>
                        _read(open.isEmpty ? pieces : open, "Heute"),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text("Lesen"),
                  ),
                  if (open.isNotEmpty)
                    OutlinedButton.icon(
                      key: const ValueKey("course-today-done"),
                      onPressed: () =>
                          _setPieces([for (final p in open) p.piece], true),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text("Alles gelesen"),
                    ),
                ],
              ),
            ],
            if (ahead != null) ...[
              const SizedBox(height: 12),
              Text(
                "Vorauslesen für „${ahead.session.topic}“ "
                "(${CourseDates.label(ahead.date, year: false)}): "
                "${compactLabel([for (final p in ahead.open.take(3)) p.piece])}"
                "${ahead.open.length > 3 ? " …" : ""}",
                key: const ValueKey("course-read-ahead"),
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================
  // NÄCHSTE SITZUNG
  // ==========================

  Widget _next(BuildContext context, SessionSchedule next) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = TextStyle(color: context.colors.textSecondary);

    final chapters = next.required.length;
    final doneChapters = next.required.where((p) => p.done).length;

    return Card(
      key: const ValueKey("course-next"),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Nächste Sitzung: ${next.session.topic}",
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "${CourseDates.label(next.date)}"
              "${next.dateChanged ? " (eigener Termin)" : ""}",
            ),
            const SizedBox(height: 8),
            _PaceRow(session: next),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: next.fraction,
                minHeight: 8,
                backgroundColor: context.colors.surfaceMuted,
                color: next.open.isEmpty
                    ? context.colors.success
                    : context.colors.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "$doneChapters von $chapters Lesestücken"
              "${next.open.isEmpty ? "" : " · noch ${ReadingPlanExtent.formatMinutes(next.openMinutes)}"}",
              key: const ValueKey("course-next-progress"),
              style: secondary,
            ),
            if (next.open.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Bis ${CourseDates.label(next.target, year: false)}"
                "${next.target != next.date ? " (Vorabend)" : " (Sitzungstag)"}"
                " lesen: ${compactLabel([for (final p in next.open) p.piece])}",
                key: const ValueKey("course-next-open"),
              ),
              const SizedBox(height: 4),
              Text(
                next.daysLeft <= 1
                    ? "Noch 1 Lesetag."
                    : "Noch ${next.daysLeft} Lesetage · etwa "
                          "${ReadingPlanExtent.formatMinutes(next.minutesPerDay)} "
                          "am Tag.",
                style: secondary,
              ),
              if (next.tight) ...[
                const SizedBox(height: 8),
                _TightNote(session: next),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _overdue(BuildContext context, CourseSchedule schedule) {
    final pieces = schedule.overdue;

    return Card(
      key: const ValueKey("course-overdue"),
      margin: EdgeInsets.zero,
      color: context.colors.errorBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Aus vergangenen Sitzungen offen",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: context.colors.error),
            ),
            const SizedBox(height: 4),
            Text(
              "Nicht in den Tagesplan eingerechnet, damit die nächste Sitzung "
              "nicht leidet. ${ReadingPlanExtent.formatMinutes(_minutes(pieces))} "
              "insgesamt.",
            ),
            const SizedBox(height: 8),
            _PieceChips(
              pieces: pieces,
              onChanged: (piece, value) => _setPieces([piece], value),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================
  // ALLE SITZUNGEN
  // ==========================

  List<Widget> _sessions(BuildContext context, CourseSchedule schedule) {
    final items = <(DateTime, Widget)>[
      for (final s in schedule.sessions) (s.date, _session(context, s)),
      for (final m in schedule.milestones) (m.start, _milestone(context, m)),
    ];

    // Stabil sortieren: Sitzungen vor Terminen am selben Tag.
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.$1.compareTo(b.$2.$1);

        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });

    return [for (final (_, (_, widget)) in indexed) widget];
  }

  Widget _milestone(BuildContext context, CourseMilestone m) {
    final end = m.end;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_note_outlined, color: context.colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  [
                    end == null
                        ? CourseDates.label(m.start)
                        : "${CourseDates.label(m.start, year: false)} – "
                              "${CourseDates.label(end)}",
                    ?m.note,
                  ].join(" · "),
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _session(BuildContext context, SessionSchedule s) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = TextStyle(color: context.colors.textSecondary);
    final session = s.session;

    final past = s.date.isBefore(service.courseSchedule(uid, planId)!.today);

    final summary = [
      CourseDates.label(s.date),
      if (s.hasReading)
        "${s.required.where((p) => p.done).length}/${s.required.length} "
            "gelesen",
      if (s.hasReading) s.pace.label,
      if (s.extras.isNotEmpty) "${s.extras.length} ergänzend",
    ].join(" · ");

    return Card(
      key: ValueKey("course-session-${session.id}"),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey("course-session-tile-${session.id}"),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text("${session.number}. ${session.topic}"),
        subtitle: Text(summary, style: secondary),
        leading: Icon(
          !s.hasReading
              ? Icons.info_outline_rounded
              : s.open.isEmpty
              ? Icons.check_circle_rounded
              : past
              ? Icons.error_outline_rounded
              : Icons.radio_button_unchecked_rounded,
          color: s.hasReading && s.open.isEmpty
              ? context.colors.success
              : past && s.open.isNotEmpty
              ? context.colors.error
              : context.colors.textSecondary,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (s.readingsChanged)
                const _Badge(text: "Eigene Stellen")
              else
                _SourceBadge(source: session.readingSource),
              if (s.dateChanged) const _Badge(text: "Eigener Termin"),
            ],
          ),
          if (session.note case final note?) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
          if (s.dateChanged || s.readingsChanged) ...[
            const SizedBox(height: 6),
            Text(
              "Empfehlung: ${CourseDates.label(s.recommended.date)} · "
              "${s.recommended.readings.isEmpty ? "keine Lesestellen" : s.recommended.readings.map((r) => r.label).join("; ")}",
              style: textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
          if (s.recommendationChanged) ...[
            const SizedBox(height: 8),
            _RecommendationChanged(
              onAdopt: () =>
                  service.clearCourseOverride(uid, planId, session.id),
              onKeep: () => service.keepCourseOverride(uid, planId, session.id),
            ),
          ],
          if (s.hasReading) ...[
            const SizedBox(height: 10),
            Text(
              "Bis ${CourseDates.label(s.target, year: false)} lesen"
              "${s.target != s.date ? " (Vorabend; spätestens am Sitzungstag)" : " (Sitzungstag)"}",
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final group in _byReading(s.required))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      group.$2.first.extra
                          ? "${group.$1.label}: übrige Kapitel (alle Kapitel)"
                          : group.$1.label,
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    _PieceChips(
                      pieces: group.$2,
                      onChanged: (piece, value) => _setPieces([piece], value),
                    ),
                  ],
                ),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text("Für diese Sitzung ist keine Lektüre vorgesehen."),
            ),
          if (s.repeats.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("Gezielt wiederholen (optional)", style: textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              "Diese Texte sind schon für eine frühere Sitzung eingeplant und "
              "zählen hier nicht noch einmal.",
              style: secondary,
            ),
            const SizedBox(height: 4),
            _PieceChips(
              pieces: s.repeats,
              review: true,
              onChanged: (piece, value) =>
                  service.setCourseReview(uid, planId, piece, value),
            ),
          ],
          if (s.days.isNotEmpty && s.open.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("Tagesplan", style: textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final entry in s.days.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  "${CourseDates.label(entry.key, year: false)}: "
                  "${compactLabel([for (final p in entry.value) p.piece])}",
                  style: entry.value.every((p) => p.done) ? secondary : null,
                ),
              ),
            if (s.tight) ...[const SizedBox(height: 6), _TightNote(session: s)],
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.hasReading)
                OutlinedButton.icon(
                  key: ValueKey("course-session-read-${session.id}"),
                  onPressed: () => _read(
                    s.open.isEmpty ? s.required : s.open,
                    session.topic,
                  ),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text("Lesen"),
                ),
              OutlinedButton.icon(
                key: ValueKey("course-session-edit-${session.id}"),
                onPressed: () => _edit(s),
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text("Anpassen"),
              ),
              if (session.unitId case final unitId?)
                TextButton.icon(
                  key: ValueKey("course-session-unit-${session.id}"),
                  onPressed: () => _openUnit(unitId),
                  icon: const Icon(Icons.slideshow_rounded),
                  label: const Text("Folien der Sitzung"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static List<(PlanReading, List<ScheduledPiece>)> _byReading(
    List<ScheduledPiece> pieces,
  ) {
    final result = <(PlanReading, List<ScheduledPiece>)>[];

    for (final p in pieces) {
      if (result.isNotEmpty &&
          result.last.$1 == p.reading &&
          result.last.$2.last.extra == p.extra) {
        result.last.$2.add(p);
      } else {
        result.add((p.reading, [p]));
      }
    }

    return result;
  }

  // ==========================
  // AKTIONEN
  // ==========================

  Future<void> _setPieces(List<PlanReading> pieces, bool value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final result = await service.setCoursePieces(
      uid: uid,
      planId: planId,
      pieces: pieces,
      done: value,
    );

    if (value) {
      showReadingFeedback(
        messenger,
        result,
        confirmation: "Als gelesen markiert.",
      );
    }
  }

  Future<void> _read(List<ScheduledPiece> pieces, String title) {
    return openCourseReading(
      context,
      uid: uid,
      planId: planId,
      pieces: pieces,
      title: title,
      service: service,
      repository: widget.repository,
    );
  }

  Future<void> _openUnit(String unitId) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OldTestamentDataBuilder(
          title: "Sitzung",
          course: OtCourseId.bibelkunde,
          builder: (context, data) => data.unit(unitId) == null
              ? Scaffold(
                  appBar: AppBar(title: const Text("Sitzung")),
                  body: const Center(
                    child: Text("Zu dieser Sitzung gibt es noch keine Folien."),
                  ),
                )
              : UnitDetailScreen(data: data, unitId: unitId),
        ),
      ),
    );
  }

  /// Schaltet den Umfang um und sagt, was sich dadurch ändert – der Plan
  /// wird sofort neu berechnet, Gelesenes bleibt.
  Future<void> _setWholeBooks(bool value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final before = service.courseSchedule(uid, planId);

    await service.setCourseWholeBooks(uid, planId, value);

    final after = service.courseSchedule(uid, planId);

    if (messenger == null || before == null || after == null) return;

    final open =
        after.sessions.fold(0, (sum, s) => sum + s.open.length) -
        before.sessions.fold(0, (sum, s) => sum + s.open.length);

    final text = value
        ? "Alle Kapitel: ${after.extraCount} Kapitel ergänzt, davon "
              "$open noch offen. Gelesenes bleibt erhalten; das Offene ist "
              "neu verteilt."
        : "Nur vorgesehene Kapitel: ${before.extraCount} ergänzende "
              "Kapitel entfallen, der ursprüngliche Plan gilt wieder. Was du "
              "davon gelesen hast, bleibt gespeichert und zählt wieder, wenn "
              "du alle Kapitel einschaltest.";

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey("course-scope-changed"),
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  Future<void> _end(CourseReadingPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Plan beenden?"),
        content: Text(
          "Dein Fortschritt in „${plan.name}“ und deine eigenen Termine und "
          "Stellen werden gelöscht. Leseverlauf und Bibellese-Streak bleiben "
          "erhalten.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            key: const ValueKey("course-plan-end-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Beenden"),
          ),
        ],
      ),
    );

    if (confirmed == true) await service.endCoursePlan(uid, planId);
  }

  Future<void> _edit(SessionSchedule s) async {
    final result = await showDialog<_SessionEdit>(
      context: context,
      builder: (_) =>
          _SessionEditDialog(schedule: s, extentOf: service.courseExtent),
    );

    if (result == null) return;

    if (result.reset) {
      await service.clearCourseOverride(uid, planId, s.id);
    } else {
      await service.setCourseOverride(
        uid,
        planId,
        s.id,
        date: result.date,
        readings: result.readings,
      );
    }
  }

  static int _minutes(List<ScheduledPiece> pieces) {
    final verses = pieces.fold(0, (sum, p) => sum + p.verses);

    return (verses / ReadingPlanExtent.versesPerMinute).round();
  }
}

/// Öffnet Lesestücke eines Leseplans zur Lehrveranstaltung im Reader; dort
/// lässt sich jedes Stück abhaken.
Future<void> openCourseReading(
  BuildContext context, {
  required String? uid,
  required String planId,
  required List<ScheduledPiece> pieces,
  required String title,
  BibleReadingService? service,
  BibleRepository? repository,
}) {
  final reading = service ?? BibleReadingService.instance;
  final plan = reading.coursePlan(planId);

  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BibleReaderScreen(
        uid: uid,
        readingService: reading,
        repository: repository,
        passages: [
          for (final p in pieces)
            BiblePassage(label: p.label, reference: p.piece.reference),
        ],
        passageTitle: "${plan?.name ?? "Leseplan"} · $title",
        coursePlan: (planId: planId, pieces: [for (final p in pieces) p.piece]),
      ),
    ),
  );
}

/// Ein begonnener Leseplan zur Lehrveranstaltung in den Listen der
/// normalen Lesepläne: Stand, Fortschritt und (mit [showToday]) das heutige
/// Pensum zum Abhaken und Lesen – wie die Karte eines Plans mit Plantagen.
class CoursePlanCard extends StatelessWidget {
  final String? uid;
  final CourseReadingPlan plan;
  final CourseReadingProgress progress;
  final BibleReadingService service;
  final BibleRepository? repository;

  /// Heutiges Pensum zeigen (Startseite der Bibel).
  final bool showToday;

  const CoursePlanCard({
    super.key,
    required this.uid,
    required this.plan,
    required this.progress,
    required this.service,
    this.repository,
    this.showToday = false,
  });

  void _openPlan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseReadingPlanScreen(
          uid: uid,
          planId: plan.id,
          service: service,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    List<PlanReading> pieces,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final result = await service.setCoursePieces(
      uid: uid,
      planId: plan.id,
      pieces: pieces,
      done: value,
    );

    if (value) {
      showReadingFeedback(
        messenger,
        result,
        confirmation: "Als gelesen markiert.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    final schedule = service.courseSchedule(uid, plan.id);
    final next = schedule?.next;

    final status = progress.paused
        ? "Pausiert"
        : schedule == null
        ? plan.course
        : next == null
        ? "Alle Sitzungen gelesen"
        : "Nächste Sitzung ${CourseDates.label(next.date, year: false)}: "
              "${next.session.topic} · ${next.pace.label}";

    final today = schedule?.todayPieces ?? const <ScheduledPiece>[];
    final open = today.where((p) => !p.done).toList();

    return Card(
      key: ValueKey("course-plan-card-${plan.id}"),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: showToday ? null : () => _openPlan(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name, style: textTheme.titleMedium),
                        Text(status, style: secondary),
                      ],
                    ),
                  ),
                  if (showToday)
                    TextButton(
                      key: ValueKey("course-plan-open-${plan.id}"),
                      onPressed: () => _openPlan(context),
                      child: const Text("Plan öffnen"),
                    ),
                ],
              ),
              if (schedule != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: schedule.fraction,
                          minHeight: 8,
                          backgroundColor: context.colors.surfaceMuted,
                          color: schedule.fraction >= 1
                              ? context.colors.success
                              : context.colors.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${(schedule.fraction * 100).floor()} % gelesen · "
                        "${progress.wholeBooks ? "alle Kapitel der Bücher" : "nur vorgesehene Kapitel"}",
                        key: ValueKey("course-plan-progress-${plan.id}"),
                        style: secondary,
                      ),
                    ],
                  ),
                ),
                if (showToday && !progress.paused) ...[
                  const SizedBox(height: 6),
                  if (today.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        next == null
                            ? "Für die kommenden Sitzungen ist nichts mehr offen."
                            : next.open.isEmpty
                            ? "Für die nächste Sitzung ist alles gelesen."
                            : "Heute ist nichts eingeplant.",
                        style: secondary,
                      ),
                    )
                  else ...[
                    Text(
                      "Heute: ${compactLabel([for (final p in today) p.piece])}",
                      key: ValueKey("course-plan-today-${plan.id}"),
                    ),
                    const SizedBox(height: 6),
                    _PieceChips(
                      pieces: today,
                      onChanged: (piece, value) =>
                          _set(context, [piece], value),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: ValueKey("course-plan-read-${plan.id}"),
                        onPressed: () => openCourseReading(
                          context,
                          uid: uid,
                          planId: plan.id,
                          pieces: open.isEmpty ? today : open,
                          title: "Heute",
                          service: service,
                          repository: repository,
                        ),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text("Lesen"),
                      ),
                    ),
                  ],
                ],
              ] else if (showToday)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Umfang des Plans: „Nur vorgesehene Kapitel“ (Standard, aus) oder „Alle
/// Kapitel der behandelten Bücher“ (ein).
class _ScopeSwitch extends StatelessWidget {
  final CourseSchedule schedule;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ScopeSwitch({
    required this.schedule,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final extras = schedule.extraCount;

    return SwitchListTile(
      key: const ValueKey("course-whole-books"),
      contentPadding: EdgeInsets.zero,
      title: const Text("Alle Kapitel der behandelten Bücher"),
      subtitle: Text(
        value
            ? "Ein: Zu den Stellen jeder Sitzung kommen die übrigen Kapitel "
                  "der behandelten Bücher ($extras ergänzende Kapitel), in "
                  "biblischer Reihenfolge auf die Lesetage verteilt. Gilt für "
                  "die Sitzungen ab dem Einschalten; frühere bleiben, wie "
                  "sie waren. Ausschalten stellt den ursprünglichen Plan "
                  "wieder her."
            : "Aus: nur vorgesehene Kapitel – die Stellen des "
                  "Bibelkunde-Plans (Standard). Ein: zusätzlich alle übrigen "
                  "Kapitel der behandelten Bücher. Gelesenes und eigene "
                  "Änderungen bleiben in beiden Fällen erhalten.",
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Fasst Lesestücke kurz zusammen: aufeinanderfolgende ganze Kapitel eines
/// Buchs als Bereich, z. B. „Gen 1–9; Num 6,22–26“.
String compactLabel(List<PlanReading> pieces) {
  final parts = <String>[];

  var i = 0;

  while (i < pieces.length) {
    final first = pieces[i];
    var last = first;

    if (first.verse == null && first.chapter != null) {
      while (i + 1 < pieces.length) {
        final candidate = pieces[i + 1];

        if (candidate.bookId != first.bookId ||
            candidate.verse != null ||
            candidate.chapter != last.chapter! + 1) {
          break;
        }

        last = candidate;
        i++;
      }
    }

    parts.add(
      last == first
          ? first.label
          : PlanReading(
              bookId: first.bookId,
              chapter: first.chapter,
              endChapter: last.chapter,
            ).label,
    );

    i++;
  }

  return parts.join("; ");
}

class _Badge extends StatelessWidget {
  final String text;
  final bool warning;

  const _Badge({required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: warning
            ? context.colors.errorBackground
            : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: warning ? context.colors.error : context.colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final CourseReadingSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    return _Badge(
      text: source.label,
      warning: source == CourseReadingSource.provisional,
    );
  }
}

class _PaceRow extends StatelessWidget {
  final SessionSchedule session;

  const _PaceRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final pace = session.pace;

    final (text, warning) = switch (pace) {
      CoursePace.onTrack when session.tight => ("Im Plan, aber knapp", true),
      CoursePace.onTrack => ("Im Plan", false),
      CoursePace.behind => ("Rückstand – das Offene ist neu verteilt", true),
      CoursePace.done => ("Alles gelesen", false),
      CoursePace.upcoming => (
        "Lesezeitraum ab ${CourseDates.label(session.windowStart, year: false)}",
        false,
      ),
      _ => (pace.label, pace == CoursePace.missed),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: KeyedSubtree(
        key: ValueKey("course-pace-${pace.name}"),
        child: _Badge(text: text, warning: warning),
      ),
    );
  }
}

class _TightNote extends StatelessWidget {
  final SessionSchedule session;

  const _TightNote({required this.session});

  @override
  Widget build(BuildContext context) {
    final minutes = ReadingPlanExtent.formatMinutes(session.minutesPerDay);

    return Container(
      key: const ValueKey("course-tight"),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        session.veryTight
            ? "Sehr knapp: Bis ${CourseDates.label(session.target, year: false)} "
                  "wären täglich $minutes nötig. Die Aufteilung oben "
                  "verteilt den Stoff trotzdem gleichmäßig; lies zuerst die "
                  "Kapitel, die die Sitzung voraussetzt, oder passe die "
                  "Stellen an."
            : "Knapper Zeitraum: täglich $minutes Lesezeit.",
        style: TextStyle(color: context.colors.error),
      ),
    );
  }
}

class _RecommendationChanged extends StatelessWidget {
  final VoidCallback onAdopt;
  final VoidCallback onKeep;

  const _RecommendationChanged({required this.onAdopt, required this.onKeep});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey("course-recommendation-changed"),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Die Empfehlung für diese Sitzung wurde aktualisiert (neue Folien "
            "oder Termine). Deine Änderung gilt weiter, bis du sie "
            "übernimmst.",
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey("course-recommendation-adopt"),
                onPressed: onAdopt,
                child: const Text("Empfehlung übernehmen"),
              ),
              TextButton(
                key: const ValueKey("course-recommendation-keep"),
                onPressed: onKeep,
                child: const Text("Meine Änderung behalten"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lesestücke zum Abhaken.
class _PieceChips extends StatelessWidget {
  final List<ScheduledPiece> pieces;

  /// Wiederholungen: Haken = wiederholt.
  final bool review;

  final void Function(PlanReading piece, bool value) onChanged;

  const _PieceChips({
    required this.pieces,
    required this.onChanged,
    this.review = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in pieces)
          FilterChip(
            key: ValueKey(
              "course-piece-${review ? "review-" : ""}${p.sessionId}-${p.key}",
            ),
            label: Text(
              review && p.done && !p.reviewed
                  ? "${p.label} (gelesen)"
                  : p.label,
            ),
            selected: review ? p.reviewed : p.done,
            onSelected: (value) => onChanged(p.piece, value),
          ),
      ],
    );
  }
}

class _SessionEdit {
  final bool reset;
  final DateTime? date;
  final List<PlanReading>? readings;

  const _SessionEdit({this.reset = false, this.date, this.readings});
}

class _SessionEditDialog extends StatefulWidget {
  final SessionSchedule schedule;

  final BibleExtent? Function() extentOf;

  const _SessionEditDialog({required this.schedule, required this.extentOf});

  @override
  State<_SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends State<_SessionEditDialog> {
  late final TextEditingController _date = TextEditingController(
    text: formatDate(widget.schedule.date),
  );

  late final TextEditingController _readings = TextEditingController(
    text: [
      for (final r in widget.schedule.session.readings) editText(r),
    ].join("; "),
  );

  String? _error;

  @override
  void dispose() {
    _date.dispose();
    _readings.dispose();
    super.dispose();
  }

  void _save() {
    final date = parseDate(_date.text);

    if (date == null) {
      setState(() => _error = "Bitte das Datum als TT.MM.JJJJ angeben.");

      return;
    }

    final parsed = parseReadings(_readings.text, widget.extentOf());

    if (parsed.problems.isNotEmpty) {
      setState(() => _error = parsed.problems.join("\n"));

      return;
    }

    Navigator.pop(context, _SessionEdit(date: date, readings: parsed.readings));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;

    return AlertDialog(
      title: Text("${s.session.number}. ${s.session.topic}"),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Empfehlung: ${CourseDates.label(s.recommended.date)} · "
                "${s.recommended.readings.isEmpty ? "keine Lesestellen" : s.recommended.readings.map((r) => r.label).join("; ")}",
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey("course-edit-date"),
                controller: _date,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: "Sitzungstermin",
                  hintText: "TT.MM.JJJJ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey("course-edit-readings"),
                controller: _readings,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Lesestellen",
                  hintText: "z. B. Ex 1-5; Ex 7-24; Lev 16",
                  helperText: "Mit Semikolon getrennt; leer = keine Lektüre",
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  key: const ValueKey("course-edit-error"),
                  style: TextStyle(color: context.colors.error),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                "Bereits Gelesenes bleibt erhalten; nur das Offene wird neu "
                "verteilt.",
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (s.override != null)
          TextButton(
            key: const ValueKey("course-edit-reset"),
            onPressed: () =>
                Navigator.pop(context, const _SessionEdit(reset: true)),
            child: const Text("Empfehlung"),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        FilledButton(
          key: const ValueKey("course-edit-save"),
          onPressed: _save,
          child: const Text("Speichern"),
        ),
      ],
    );
  }
}

/// Lesung zum Bearbeiten: ganze Bücher mit Abkürzung, sonst wie angezeigt.
String editText(PlanReading reading) => reading.wholeBook
    ? BibleBooks.abbreviationOf(reading.bookId)
    : reading.label;

/// Liest eigene Lesestellen („Ex 1-5; Lev 16“) und prüft sie gegen
/// [extent] (falls geladen).
({List<PlanReading> readings, List<String> problems}) parseReadings(
  String input,
  BibleExtent? extent,
) {
  final readings = <PlanReading>[];
  final problems = <String>[];

  for (final part in input.split(";")) {
    final text = part.trim();

    if (text.isEmpty) continue;

    final reading = ReadingPlanText.parseReading(text);

    if (reading == null) {
      problems.add("„$text“ ist keine lesbare Stelle.");
      continue;
    }

    if (extent != null) {
      final chapters = extent.chapterCount(reading.bookId);
      final last = reading.endChapter ?? reading.chapter;

      if (chapters == null) {
        problems.add("„$text“: Das Buch fehlt in den Bibelausgaben.");
        continue;
      }

      if (last != null && last > chapters) {
        problems.add("„$text“: Das Buch hat nur $chapters Kapitel.");
        continue;
      }

      final verse = reading.endVerse ?? reading.verse;

      if (verse != null && verse > extent.verseCount(reading.bookId, last!)) {
        problems.add("„$text“: Den Vers gibt es nicht.");
        continue;
      }
    }

    readings.add(reading);
  }

  return (readings: readings, problems: problems);
}
