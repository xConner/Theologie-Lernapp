import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/course_snapshot.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/plan_schedule.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';
import 'catalog_status.dart';
import 'conflict_views.dart';
import 'course_editor_screen.dart';

/// Alle verfügbaren Angaben zu einer Veranstaltung. Nicht geplant:
/// Überschneidungen und Hinzufügen (mit Vorschau). Geplant: angepasste
/// Angaben, Bearbeiten, Entfernen, Abgleich mit der Quelle.
class CourseDetailScreen extends StatefulWidget {
  final TimetableController controller;
  final CourseSnapshot snapshot;
  final bool synthetic;

  const CourseDetailScreen({
    super.key,
    required this.controller,
    required this.snapshot,
    this.synthetic = false,
  });

  /// Aus dem Stundenplan (auch für Einträge ohne gespeicherten Import).
  factory CourseDetailScreen.forPlan({
    Key? key,
    required TimetableController controller,
    required PlanCourse plan,
  }) => CourseDetailScreen(
    key: key,
    controller: controller,
    snapshot:
        plan.imported ??
        CourseSnapshot(
          courseId: plan.entry.courseId,
          semesterId: plan.entry.semesterId,
          sources: plan.entry.sources,
          title: plan.entry.title,
          number: plan.entry.number,
        ),
    synthetic: controller.catalog?.synthetic ?? false,
  );

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _showAllDates = false;
  bool _refreshing = false;

  TimetableController get controller => widget.controller;

  Future<void> _remove(String entryId) async {
    try {
      await controller.remove(entryId);
      if (mounted) showSaveFeedback(context, "Aus dem Stundenplan entfernt.");
    } catch (_) {
      if (mounted) showSaveFeedback(context, saveFailedMessage);
    }
  }

  Future<void> _refresh(PlanCourse plan) async {
    setState(() => _refreshing = true);
    try {
      final outcome = await controller.refreshFromSource(plan.entry);
      if (!mounted) return;
      showSaveFeedback(context, switch (outcome) {
        RefreshOutcome.unchanged => "Die Angaben in UnivIS sind unverändert.",
        RefreshOutcome.updated =>
          plan.hasOverrides
              ? "Neue Angaben aus UnivIS übernommen. Deine Anpassungen bleiben bestehen."
              : "Neue Angaben aus UnivIS übernommen.",
        RefreshOutcome.notFound =>
          "Die Veranstaltung wurde in UnivIS nicht (mehr) gefunden. Deine gespeicherten Angaben bleiben erhalten.",
      });
    } catch (e) {
      if (mounted) {
        showSaveFeedback(
          context,
          "Abgleich nicht möglich: ${e is Exception ? e.toString().replaceFirst("Exception: ", "") : "Fehler"}",
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = widget.snapshot;
        final entry = controller.entryFor(s.courseId, s.sources);
        final plan = entry == null
            ? null
            : controller.planCourse(entry.courseId);
        final shown = plan?.imported ?? s;
        final colors = context.colors;
        final conflicts = entry == null ? controller.conflictsFor(s) : null;
        final planConflicts = plan == null
            ? null
            : [
                for (final spot in controller.conflicts)
                  if (spot.entryIds.contains(plan.id)) spot,
              ];

        return Scaffold(
          appBar: AppBar(title: const Text("Veranstaltung")),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (widget.synthetic) ...[
                  const SyntheticDataBanner(),
                  const SizedBox(height: 16),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    plan?.title ?? s.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (plan != null && plan.title != shown.title)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "In UnivIS: ${shown.title}",
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 12),
                if (entry != null &&
                    entry.semesterId !=
                        (controller.semesterId ?? entry.semesterId))
                  _Banner(
                    icon: Icons.swap_horiz_rounded,
                    text:
                        "Im Stundenplan für das ${controller.semesterLabel(entry.semesterId)}.",
                  ),
                if (plan != null && plan.hasOverrides)
                  _Banner(
                    icon: Icons.edit_note_rounded,
                    text:
                        "Von dir angepasst. Die Angaben aus UnivIS bleiben "
                        "unverändert gespeichert.",
                  ),
                if (plan != null && plan.sourceChanged)
                  _Banner(
                    key: const ValueKey("source-changed"),
                    icon: Icons.update_rounded,
                    warning: true,
                    text: plan.hasOverrides
                        ? "UnivIS hat Termine oder Räume geändert. Deine "
                              "Anpassungen gelten weiter – prüfe, ob sie noch passen."
                        : "UnivIS hat Termine oder Räume geändert; angezeigt "
                              "wird der neue Stand.",
                    actions: [
                      TextButton(
                        onPressed: () => controller.acceptSourceChanges(plan),
                        child: const Text("Zur Kenntnis genommen"),
                      ),
                      if (plan.entry.overrides.changesSchedule)
                        TextButton(
                          onPressed: () => controller.acceptSourceChanges(
                            plan,
                            discardOverrides: true,
                          ),
                          child: const Text(
                            "Eigene Termin-Anpassungen verwerfen",
                          ),
                        ),
                    ],
                  ),
                if (plan != null && plan.source == PlanSource.missing)
                  _Banner(
                    icon: Icons.info_outline_rounded,
                    warning: true,
                    text:
                        "Diese Veranstaltung ist im Verzeichnis nicht mehr "
                        "vorhanden. Es sind keine weiteren Angaben gespeichert.",
                  ),
                ..._facts(context, shown, plan),
                if (conflicts != null && conflicts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConflictNotice(
                    controller: controller,
                    spots: conflicts,
                    candidateTitle: s.title,
                  ),
                ],
                if (planConflicts != null && planConflicts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Banner(
                    icon: Icons.warning_amber_rounded,
                    warning: true,
                    text:
                        "${planConflicts.length == 1 ? "1 Überschneidung" : "${planConflicts.length} Überschneidungen"} "
                        "in deinem Stundenplan.",
                    actions: [
                      TextButton(
                        onPressed: () => showConflictSheet(
                          context,
                          controller: controller,
                          spots: planConflicts,
                          grouped: true,
                          title: "Überschneidungen von „${plan!.title}“",
                        ),
                        child: const Text("Anzeigen"),
                      ),
                    ],
                  ),
                ],
                _Section(
                  title: "Termine",
                  children: [
                    if (plan != null && plan.rules.isNotEmpty)
                      for (final r in plan.rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            [
                              describeSessionRule(r.rule),
                              ?r.room,
                              if (r.removed) "ausgeblendet",
                              if (r.extra)
                                "eigener Termin"
                              else if (r.override != null &&
                                  !r.override!.isEmpty &&
                                  !r.removed)
                                "angepasst",
                            ].join(" · "),
                            style: r.removed
                                ? TextStyle(
                                    color: colors.textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        )
                    else if (shown.rules.isEmpty)
                      const Text("Keine festen Termine angegeben.")
                    else
                      for (final r in shown.rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            [describeSessionRule(r.rule), ?r.room].join(" · "),
                          ),
                        ),
                    for (final note in shown.notes)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              note.warning
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: note.warning
                                  ? colors.error
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                describeNote(
                                  note.asScheduleNote(shown.courseId),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                _dates(context, shown, plan),
                if (entry != null && entry.overrides.note != null)
                  _Section(
                    title: "Eigene Notiz",
                    children: [Text(entry.overrides.note!)],
                  ),
                if (shown.detailUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(shown.detailUrl!)),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text(
                        "In UnivIS ansehen (Beschreibung, Anmeldung)",
                      ),
                    ),
                  ),
                if (plan != null &&
                    plan.source == PlanSource.snapshot &&
                    controller.searchSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: const ValueKey("refresh-from-source"),
                      onPressed: _refreshing ? null : () => _refresh(plan),
                      icon: _refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: const Text("Mit UnivIS abgleichen"),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  widget.synthetic
                      ? "Quelle: synthetische Testdaten"
                      : [
                          "Quelle: UnivIS – Christian-Albrechts-Universität zu Kiel",
                          if (plan?.source == PlanSource.snapshot &&
                              shown.fetchedAt != null)
                            "gespeicherter Stand vom ${formatDateTime(shown.fetchedAt!)}",
                        ].join(" · "),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: entry == null
                  ? FilledButton.icon(
                      key: const ValueKey("detail-toggle"),
                      onPressed: () => openCourseEditor(
                        context,
                        controller: controller,
                        snapshot: s,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Zum Stundenplan hinzufügen"),
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey("detail-edit"),
                          onPressed:
                              plan == null || plan.source == PlanSource.missing
                              ? null
                              : () => openCourseEditor(
                                  context,
                                  controller: controller,
                                  snapshot: plan.imported!,
                                ),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text("Bearbeiten"),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey("detail-toggle"),
                          onPressed: controller.isPending(entry.courseId)
                              ? null
                              : () => _remove(entry.courseId),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          label: const Text("Aus dem Stundenplan entfernen"),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _facts(
    BuildContext context,
    CourseSnapshot s,
    PlanCourse? plan,
  ) {
    final lecturers = plan?.lecturers ?? s.lecturers;
    final rooms = plan == null
        ? s.rooms
        : {
            for (final r in plan.rules)
              if (!r.removed) ?r.room,
          }.toList();
    final facts = <(String, String)>[
      ("Typ", courseTypeLabel(s.type)),
      (
        lecturers.length > 1 ? "Dozenten" : "Dozent",
        lecturers.isEmpty ? "nicht angegeben" : lecturers.join(", "),
      ),
      if (rooms.isNotEmpty)
        (rooms.length == 1 ? "Ort" : "Orte", rooms.join(", ")),
      ("Nummer", s.number ?? "nicht angegeben"),
      if (s.faculty != null) ("Fakultät", s.faculty!),
      if (s.organizationPath.length > 1)
        ("Einrichtung", s.organizationPath.skip(1).join(" › "))
      else if (s.organizations.isNotEmpty)
        ("Einrichtung", s.organizations.join(", ")),
      if (s.semester != null) ("Semester", s.semester!.label),
      if (s.sws != null) ("SWS", _number(s.sws!)),
      if (s.ects != null) ("ECTS", _number(s.ects!)),
      if (s.classification.isNotEmpty)
        ("Einordnung", s.classification.join(", ")),
      if (s.moduleCodes.isNotEmpty) ("Module", s.moduleCodes.join(", ")),
    ];
    final colors = context.colors;
    return [
      for (final (label, value) in facts)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: value == "nicht angegeben"
                        ? TextStyle(
                            color: colors.textSecondary,
                            fontStyle: FontStyle.italic,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  static String _number(num n) => n == n.roundToDouble()
      ? n.toInt().toString()
      : n.toString().replaceAll(".", ",");

  Widget _dates(BuildContext context, CourseSnapshot s, PlanCourse? plan) {
    final all = plan != null
        ? [
            for (final o in plan.occurrences)
              (o.start, o.end, o.room, o.cancelled, o.adjusted),
          ]
        : [
            for (final o in s.occurrences)
              (o.start, o.end, o.room, o.cancelled, false),
          ];
    if (all.isEmpty) return const SizedBox.shrink();
    final today = controller.now();
    final todayIso =
        "${today.year.toString().padLeft(4, "0")}-${today.month.toString().padLeft(2, "0")}-${today.day.toString().padLeft(2, "0")}";
    final upcoming = all
        .where((o) => o.$2.date.compareTo(todayIso) >= 0)
        .toList();
    final shown = _showAllDates ? all : upcoming.take(6).toList();
    final colors = context.colors;

    return _Section(
      title: _showAllDates ? "Alle Termine (${all.length})" : "Nächste Termine",
      children: [
        if (shown.isEmpty)
          const Text("Keine weiteren Termine in diesem Semester."),
        for (final (start, end, room, cancelled, adjusted) in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              [
                "${weekdayName(weekdayOf(start.date), short: true)} ${formatDate(start.date)}",
                start.date != end.date
                    ? "${start.time} bis ${formatDate(end.date)} ${end.time}"
                    : timeRange(start.time, end.time),
                ?room,
                if (cancelled) "fällt aus",
                if (adjusted) "angepasst",
              ].join(" · "),
              style: cancelled
                  ? TextStyle(
                      color: colors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    )
                  : null,
            ),
          ),
        if (all.length > shown.length || _showAllDates)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAllDates = !_showAllDates),
              child: Text(
                _showAllDates
                    ? "Weniger anzeigen"
                    : "Alle ${all.length} Termine anzeigen",
              ),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;
  final List<Widget> actions;

  const _Banner({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: warning ? colors.errorBackground : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: warning ? colors.error : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(alignment: WrapAlignment.end, children: actions)
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
