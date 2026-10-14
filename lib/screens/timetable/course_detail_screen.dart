import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/timetable/course_catalog.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';
import 'timetable_home_screen.dart';

/// Alle verfügbaren Angaben zu einer Veranstaltung, Hinzufügen/Entfernen
/// und Überschneidungen mit dem eigenen Stundenplan.
class CourseDetailScreen extends StatefulWidget {
  final TimetableController controller;
  final String courseId;

  const CourseDetailScreen({
    super.key,
    required this.controller,
    required this.courseId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _showAllDates = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final catalog = controller.catalog;
        final course = catalog?.courseById(widget.courseId);
        if (catalog == null || course == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Veranstaltung")),
            body: const Center(
              child: Text(
                "Diese Veranstaltung ist im Katalog nicht vorhanden.",
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text("Veranstaltung")),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (catalog.synthetic) ...[
                  const SyntheticDataBanner(),
                  const SizedBox(height: 16),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    course.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 16),
                ..._facts(context, catalog, course),
                const SizedBox(height: 8),
                _ConflictNotice(controller: controller, course: course),
                _Section(
                  title: "Termine",
                  children: [
                    if (course.rules.isEmpty)
                      const Text("Keine festen Termine angegeben.")
                    else
                      for (final rule in course.rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(describeRule(rule, catalog)),
                        ),
                    for (final note in catalog.notesOf(course.id))
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
                                  ? context.colors.error
                                  : context.colors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(describeNote(note))),
                          ],
                        ),
                      ),
                  ],
                ),
                _dates(context, catalog, course),
                if (course.detailUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(course.detailUrl!)),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text(
                        "Anmeldung und Beschreibung in der Quelle",
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  catalog.synthetic
                      ? "Quelle: synthetische Testdaten"
                      : "Quelle: UnivIS – ${catalog.provenance.institution}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _ToggleButton(controller: controller, course: course),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _facts(
    BuildContext context,
    CourseCatalog catalog,
    CatalogCourse course,
  ) {
    final lecturers = catalog.lecturerNames(course);
    final rooms = {
      for (final r in course.rules)
        if (r.roomId != null) ?catalog.rooms[r.roomId]?.label,
    };
    final facts = <(String, String)>[
      ("Typ", courseTypeLabel(course.type)),
      if (lecturers.isNotEmpty)
        (lecturers.length == 1 ? "Dozent" : "Dozenten", lecturers.join(", ")),
      if (rooms.isNotEmpty)
        (rooms.length == 1 ? "Ort" : "Orte", rooms.join(", ")),
      if (course.number != null) ("Nummer", course.number!),
      if (course.sws != null) ("SWS", _number(course.sws!)),
      if (course.ects != null) ("ECTS", _number(course.ects!)),
      if (course.organizations.isNotEmpty)
        ("Fachbereich", course.organizations.join(", ")),
      if (course.classification.isNotEmpty)
        ("Einordnung", course.classification.join(", ")),
      if (course.moduleCodes.isNotEmpty)
        ("Module", course.moduleCodes.join(", ")),
    ];
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
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
                Expanded(child: Text(value)),
              ],
            ),
          ),
        ),
    ];
  }

  static String _number(num n) => n == n.roundToDouble()
      ? n.toInt().toString()
      : n.toString().replaceAll(".", ",");

  Widget _dates(
    BuildContext context,
    CourseCatalog catalog,
    CatalogCourse course,
  ) {
    final all = catalog.occurrencesOf(course.id);
    if (all.isEmpty) return const SizedBox.shrink();
    final today = widget.controller.now();
    final todayIso =
        "${today.year.toString().padLeft(4, "0")}-${today.month.toString().padLeft(2, "0")}-${today.day.toString().padLeft(2, "0")}";
    final upcoming = all
        .where((o) => o.end.date.compareTo(todayIso) >= 0)
        .toList();
    final shown = _showAllDates ? all : upcoming.take(6).toList();
    final colors = context.colors;

    return _Section(
      title: _showAllDates ? "Alle Termine (${all.length})" : "Nächste Termine",
      children: [
        if (shown.isEmpty)
          const Text("Keine weiteren Termine in diesem Semester."),
        for (final o in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              [
                "${weekdayName(weekdayOf(o.date), short: true)} ${formatDate(o.date)}",
                o.spansDays
                    ? "${o.start.time} bis ${formatDate(o.end.date)} ${o.end.time}"
                    : timeRange(o.start.time, o.end.time),
                if (o.roomId != null) ?catalog.rooms[o.roomId]?.label,
                if (o.cancelled) "fällt aus",
              ].join(" · "),
              style: o.cancelled
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

class _ConflictNotice extends StatelessWidget {
  final TimetableController controller;
  final CatalogCourse course;

  const _ConflictNotice({required this.controller, required this.course});

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog!;
    final conflicts = controller.conflictsFor(course.id);
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Überschneidet sich mit deinem Stundenplan: ${[for (final e in conflicts.entries) "${catalog.courseById(e.key)?.title ?? "Veranstaltung"} "
                    "(${e.value == 1 ? "1 Termin" : "${e.value} Termine"})"].join("; ")}",
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final TimetableController controller;
  final CatalogCourse course;

  const _ToggleButton({required this.controller, required this.course});

  @override
  Widget build(BuildContext context) {
    final planned = controller.isPlanned(course.id);
    final pending = controller.isPending(course.id);
    final onPressed = pending
        ? null
        : () => toggleWithFeedback(context, controller, course.id);
    final icon = pending
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            planned ? Icons.remove_circle_outline_rounded : Icons.add_rounded,
          );
    return planned
        ? OutlinedButton.icon(
            key: const ValueKey("detail-toggle"),
            onPressed: onPressed,
            icon: icon,
            label: const Text("Aus dem Stundenplan entfernen"),
          )
        : FilledButton.icon(
            key: const ValueKey("detail-toggle"),
            onPressed: onPressed,
            icon: icon,
            label: const Text("Zum Stundenplan hinzufügen"),
          );
  }
}
