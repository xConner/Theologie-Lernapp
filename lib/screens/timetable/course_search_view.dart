import 'package:flutter/material.dart';

import '../../models/timetable/course_catalog.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/course_search.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';
import 'course_detail_screen.dart';
import 'timetable_home_screen.dart';

/// Veranstaltungen suchen und filtern; Treffer direkt hinzufügen.
class CourseSearchView extends StatefulWidget {
  final TimetableController controller;

  const CourseSearchView({super.key, required this.controller});

  @override
  State<CourseSearchView> createState() => _CourseSearchViewState();
}

class _CourseSearchViewState extends State<CourseSearchView>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _query = TextEditingController();
  CourseFilter _filter = const CourseFilter();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _update(CourseFilter filter) => setState(() => _filter = filter);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final catalog = controller.catalog!;
    final facets = CourseFacets.of(catalog);
    final results = filterCourses(catalog, _filter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          key: const ValueKey("course-search-field"),
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: "Suche nach Titel, Nummer, Modul oder Dozent",
            prefixIcon: const Icon(Icons.search_rounded),
            border: const OutlineInputBorder(),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: "Suche leeren",
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _query.clear();
                      _update(_filter.copyWith(query: ""));
                    },
                  ),
          ),
          onChanged: (value) => _update(_filter.copyWith(query: value)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FilterDropdown<String>(
              key: const ValueKey("filter-lecturer"),
              label: "Dozent",
              value: _filter.lecturerId,
              options: {for (final p in facets.lecturers) p.id: p.displayName!},
              onChanged: (v) => _update(_filter.copyWith(lecturerId: () => v)),
            ),
            _FilterDropdown<String>(
              key: const ValueKey("filter-organization"),
              label: "Fachbereich",
              value: _filter.organization,
              options: {for (final o in facets.organizations) o: o},
              onChanged: (v) =>
                  _update(_filter.copyWith(organization: () => v)),
            ),
            _FilterDropdown<String>(
              key: const ValueKey("filter-type"),
              label: "Veranstaltungstyp",
              value: _filter.type,
              options: {for (final t in facets.types) t: courseTypeLabel(t)},
              onChanged: (v) => _update(_filter.copyWith(type: () => v)),
            ),
            _FilterDropdown<int>(
              key: const ValueKey("filter-weekday"),
              label: "Wochentag",
              value: _filter.weekday,
              options: {for (final d in facets.weekdays) d: weekdayName(d)},
              onChanged: (v) => _update(_filter.copyWith(weekday: () => v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  results.length == 1
                      ? "1 Veranstaltung"
                      : "${results.length} Veranstaltungen",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            if (!_filter.isEmpty)
              TextButton.icon(
                onPressed: () {
                  _query.clear();
                  _update(const CourseFilter());
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text("Filter zurücksetzen"),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              "Keine Veranstaltung passt zu Suche und Filtern.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          )
        else
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                for (final course in results)
                  CourseListTile(controller: controller, course: course),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      // Zwei Filter je Zeile auf kleinen Bildschirmen, sonst feste Breite.
      width: width < 560 ? (width - 32 - 12) / 2 : 240,
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          DropdownMenuItem<T?>(value: null, child: const Text("Alle")),
          for (final e in options.entries)
            DropdownMenuItem<T?>(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Eine Veranstaltung in Listen: Titel, Typ, Termine, Hinzufügen-Knopf.
class CourseListTile extends StatelessWidget {
  final TimetableController controller;
  final CatalogCourse course;

  const CourseListTile({
    super.key,
    required this.controller,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog!;
    final planned = controller.isPlanned(course.id);
    final pending = controller.isPending(course.id);
    final conflicts = planned
        ? const <String, int>{}
        : controller.conflictsFor(course.id);
    final lecturers = catalog.lecturerNames(course).join(", ");
    final rules = course.rules.map((r) => describeRule(r, catalog)).join("\n");
    final colors = context.colors;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: ValueKey("course-${course.id}"),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(course.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              [
                courseTypeLabel(course.type),
                if (lecturers.isNotEmpty) lecturers,
              ].join(" · "),
            ),
            if (rules.isNotEmpty) Text(rules),
            if (conflicts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: colors.error,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Überschneidet sich mit deinem Stundenplan",
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CourseDetailScreen(controller: controller, courseId: course.id),
          ),
        ),
        trailing: pending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : IconButton(
                key: ValueKey("toggle-${course.id}"),
                tooltip: planned
                    ? "„${course.title}“ aus dem Stundenplan entfernen"
                    : "„${course.title}“ zum Stundenplan hinzufügen",
                isSelected: planned,
                icon: const Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                ),
                onPressed: () =>
                    toggleWithFeedback(context, controller, course.id),
              ),
      ),
    );
  }
}
