import 'package:flutter/material.dart';

import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/course_snapshot.dart';
import '../../services/timetable/course_catalog_source.dart';
import '../../services/timetable/course_labels.dart';
import '../../services/timetable/course_search.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';
import 'catalog_status.dart';
import 'course_detail_screen.dart';
import 'course_editor_screen.dart';

/// Wo gesucht wird: vollständiges Verzeichnis der Theologischen Fakultät
/// (lokal gefiltert, auch offline) oder UnivIS-Titelsuche über alle bzw. eine
/// bestimmte Fakultät.
const String localScope = "local";
const String allFacultiesScope = "all";

/// Zentrale Veranstaltungssuche über Fakultätsgrenzen hinweg; jeder Treffer
/// lässt sich direkt (mit Vorschau) zum Stundenplan hinzufügen.
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
  String _scope = localScope;
  List<FacultyOption> _faculties = const [];

  CourseSearchResult? _result;
  Object? _error;
  bool _searching = false;
  int _token = 0;
  String? _validation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final search = widget.controller.searchSource;
    if (search != null) {
      search.faculties().then((list) {
        if (mounted) setState(() => _faculties = list);
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _update(CourseFilter filter) => setState(() => _filter = filter);

  bool get _remote => _scope != localScope;

  void _setScope(String scope) {
    setState(() {
      _scope = scope;
      _filter = CourseFilter(query: _remote ? "" : _query.text);
      _result = null;
      _error = null;
      _validation = null;
    });
    if (_remote && _query.text.trim().isNotEmpty) _runSearch();
  }

  /// Sucheingabe prüfen: sechsstellige Nummer oder mindestens drei Zeichen.
  static ({String? text, String? number, String? problem}) parseQuery(
    String raw,
  ) {
    final q = raw.trim().replaceAll(RegExp(r"\s+"), " ");
    if (RegExp(r"^\d{6}$").hasMatch(q)) {
      return (text: null, number: q, problem: null);
    }
    if (q.length < 3) {
      return (
        text: null,
        number: null,
        problem:
            "Bitte mindestens drei Zeichen oder eine sechsstellige "
            "Veranstaltungsnummer eingeben.",
      );
    }
    if (q.length > 80) {
      return (
        text: null,
        number: null,
        problem:
            "Bitte einen kürzeren Suchbegriff eingeben (höchstens 80 Zeichen).",
      );
    }
    return (text: q, number: null, problem: null);
  }

  Future<void> _runSearch() async {
    final search = widget.controller.searchSource;
    final semesterId = widget.controller.semesterId;
    if (search == null || semesterId == null) return;
    final parsed = parseQuery(_query.text);
    if (parsed.problem != null) {
      setState(() {
        _validation = parsed.problem;
        _result = null;
      });
      return;
    }
    final token = ++_token;
    setState(() {
      _searching = true;
      _error = null;
      _validation = null;
      _filter = const CourseFilter();
    });
    try {
      final result = await search.search(
        semesterId: semesterId,
        text: parsed.text,
        number: parsed.number,
        facultyId: _scope == allFacultiesScope ? null : _scope,
      );
      if (!mounted || token != _token) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = e;
        _result = null;
      });
    } finally {
      if (mounted && token == _token) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final local = controller.catalog;
    final canSearchRemote =
        controller.searchSource != null && controller.semesterId != null;

    final scopes = <String, String>{
      localScope: "Theologische Fakultät (vollständiges Verzeichnis)",
      if (canSearchRemote) ...{
        allFacultiesScope: "Alle Fakultäten (UnivIS-Suche)",
        for (final f in _faculties) f.id: f.name,
      },
    };

    // Ergebnisse gelten nur für das Semester, in dem gesucht wurde.
    if (_result != null &&
        _result!.catalog.semester.id != controller.semesterId) {
      _result = null;
    }
    final CourseCatalog? catalog = _remote ? _result?.catalog : local;
    final results = catalog == null
        ? const <CatalogCourse>[]
        : filterCourses(catalog, _filter);
    final facets = catalog == null ? null : CourseFacets.of(catalog);

    return ListView(
      key: const ValueKey("search-list"),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey("search-scope"),
          initialValue: _scope,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: "Suchen in",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          items: [
            for (final e in scopes.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) _setScope(v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey("course-search-field"),
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: _remote
                ? "Titel, Titelbestandteil oder Veranstaltungsnummer"
                : "Suche nach Titel, Nummer, Modul oder Dozent",
            helperText: _remote
                ? "Wie in UnivIS, z. B. „Einführung in die Ethik“ oder „050123“"
                : null,
            prefixIcon: const Icon(Icons.search_rounded),
            border: const OutlineInputBorder(),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: "Suche leeren",
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _query.clear();
                      setState(() {
                        _filter = const CourseFilter();
                        if (_remote) _result = null;
                      });
                    },
                  ),
          ),
          onChanged: (value) {
            if (_remote) {
              setState(() => _validation = null);
            } else {
              _update(_filter.copyWith(query: value));
            }
          },
          onSubmitted: (_) {
            if (_remote) _runSearch();
          },
        ),
        if (_remote) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey("remote-search-button"),
              onPressed: _searching ? null : _runSearch,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text("In UnivIS suchen"),
            ),
          ),
        ],
        if (_validation != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _validation!,
              key: const ValueKey("search-validation"),
              style: TextStyle(color: context.colors.error),
            ),
          ),
        const SizedBox(height: 12),
        if (_remote && _searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(semanticsLabel: "Suche läuft"),
            ),
          )
        else if (_remote && _error != null)
          _SearchError(error: _error!, onRetry: _runSearch)
        else if (_remote && _result == null)
          _Hint(
            text:
                "Suche über das Vorlesungsverzeichnis UnivIS der CAU – auch "
                "nach Veranstaltungen anderer Fakultäten, etwa für "
                "Wahlpflichtbereiche. Bereits gespeicherte Veranstaltungen "
                "bleiben auch ohne Verbindung erhalten.",
          )
        else if (!_remote && local == null)
          _Hint(
            text: controller.catalogLoading
                ? "Das Verzeichnis der Theologischen Fakultät wird geladen …"
                : "Das Verzeichnis der Theologischen Fakultät ist derzeit "
                      "nicht verfügbar. Die UnivIS-Suche über alle Fakultäten "
                      "kannst du oben auswählen.",
          )
        else if (!_remote && local!.courses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Für das ${local.semester.label} sind noch keine Veranstaltungen "
              "veröffentlicht.",
              key: const ValueKey("empty-catalog"),
              textAlign: TextAlign.center,
            ),
          )
        else if (catalog != null && facets != null) ...[
          if (_remote && _result!.stale)
            _Notice(
              icon: Icons.cloud_off_rounded,
              text:
                  "UnivIS ist derzeit nicht erreichbar – gezeigt wird ein "
                  "gespeichertes Ergebnis"
                  "${_result!.fetchedAt == null ? "" : " vom ${formatDateTime(_result!.fetchedAt!)}"}.",
            ),
          if (_remote && _result!.truncated)
            _Notice(
              icon: Icons.filter_list_rounded,
              text:
                  "${_result!.total} Treffer – angezeigt werden die "
                  "${_result!.catalog.courses.length} passendsten. Für weitere "
                  "bitte genauer suchen oder eine Fakultät wählen.",
            ),
          if (catalog.synthetic) const SyntheticDataBanner(),
          _Filters(
            facets: facets,
            filter: _filter,
            showFaculty: _remote && facets.faculties.length > 1,
            onChanged: _update,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  results.length == 1
                      ? "1 Veranstaltung"
                      : "${results.length} Veranstaltungen",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_remote ? !_filterOnlyQuery : !_filter.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    if (!_remote) _query.clear();
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
                _remote && _result!.catalog.courses.isEmpty
                    ? "UnivIS hat zu dieser Suche im ${catalog.semester.label} "
                          "nichts gefunden. Tipp: einen Titelbestandteil "
                          "verwenden (z. B. „Ethik“ statt des vollen Titels)."
                    : "Keine Veranstaltung passt zu Suche und Filtern.",
                key: const ValueKey("no-results"),
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
                    CourseListTile(
                      controller: controller,
                      catalog: catalog,
                      course: course,
                      fromFacultyCatalog: !_remote,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  bool get _filterOnlyQuery =>
      _filter.lecturerId == null &&
      _filter.organization == null &&
      _filter.faculty == null &&
      _filter.type == null &&
      _filter.weekday == null;
}

class _Filters extends StatelessWidget {
  final CourseFacets facets;
  final CourseFilter filter;
  final bool showFaculty;
  final ValueChanged<CourseFilter> onChanged;

  const _Filters({
    required this.facets,
    required this.filter,
    required this.showFaculty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (showFaculty)
          _FilterDropdown<String>(
            key: const ValueKey("filter-faculty"),
            label: "Fakultät",
            value: filter.faculty,
            options: {for (final f in facets.faculties) f: f},
            onChanged: (v) => onChanged(filter.copyWith(faculty: () => v)),
          ),
        _FilterDropdown<String>(
          key: const ValueKey("filter-organization"),
          label: "Institut / Fachbereich",
          value: filter.organization,
          options: {for (final o in facets.organizations) o: o},
          onChanged: (v) => onChanged(filter.copyWith(organization: () => v)),
        ),
        _FilterDropdown<String>(
          key: const ValueKey("filter-lecturer"),
          label: "Dozent",
          value: filter.lecturerId,
          options: {for (final p in facets.lecturers) p.id: p.displayName!},
          onChanged: (v) => onChanged(filter.copyWith(lecturerId: () => v)),
        ),
        _FilterDropdown<String>(
          key: const ValueKey("filter-type"),
          label: "Veranstaltungstyp",
          value: filter.type,
          options: {for (final t in facets.types) t: courseTypeLabel(t)},
          onChanged: (v) => onChanged(filter.copyWith(type: () => v)),
        ),
        _FilterDropdown<int>(
          key: const ValueKey("filter-weekday"),
          label: "Wochentag",
          value: filter.weekday,
          options: {for (final d in facets.weekdays) d: weekdayName(d)},
          onChanged: (v) => onChanged(filter.copyWith(weekday: () => v)),
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
        // Neu aufbauen, wenn der Filter von außen zurückgesetzt wird.
        key: ValueKey("$label=$value"),
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
        onChanged: options.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.colors.textSecondary),
    ),
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SearchError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is CatalogUnavailableException
        ? error.toString()
        : "Die Suche ist fehlgeschlagen. Bitte später erneut versuchen.";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: context.colors.error),
          const SizedBox(height: 8),
          Text(
            message,
            key: const ValueKey("search-error"),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "Deine gespeicherten Veranstaltungen sind davon nicht betroffen.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Erneut suchen"),
          ),
        ],
      ),
    );
  }
}

/// Eine Veranstaltung in Listen: Titel, Einordnung, Termine,
/// Hinzufügen-Knopf (mit Vorschau).
class CourseListTile extends StatelessWidget {
  final TimetableController controller;
  final CourseCatalog catalog;
  final CatalogCourse course;
  final bool fromFacultyCatalog;

  const CourseListTile({
    super.key,
    required this.controller,
    required this.catalog,
    required this.course,
    this.fromFacultyCatalog = true,
  });

  CourseSnapshot get snapshot => CourseSnapshot.fromCatalog(
    catalog,
    course,
    fromFacultyCatalog: fromFacultyCatalog,
  );

  @override
  Widget build(BuildContext context) {
    final entry = controller.entryFor(course.id, course.sources);
    final planned = entry != null;
    final pending = controller.isPending(entry?.courseId ?? course.id);
    final lecturers = catalog.lecturerNames(course).join(", ");
    final rules = course.rules.map((r) => describeRule(r, catalog)).join("\n");
    final colors = context.colors;
    final where = [
      if (!fromFacultyCatalog) ?course.faculty,
      ?course.institute,
    ].join(" · ");

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
                if (course.number != null) "Nr. ${course.number}",
                if (lecturers.isNotEmpty) lecturers,
              ].join(" · "),
            ),
            if (where.isNotEmpty)
              Text(where, style: TextStyle(color: colors.textSecondary)),
            if (rules.isNotEmpty)
              Text(rules)
            else
              Text(
                "Keine Termine angegeben",
                style: TextStyle(color: colors.textSecondary),
              ),
            if (planned && entry.semesterId != catalog.semester.id)
              Text(
                "Bereits geplant im ${controller.semesterLabel(entry.semesterId)}",
                style: TextStyle(color: colors.textSecondary),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              controller: controller,
              snapshot: snapshot,
              synthetic: catalog.synthetic,
            ),
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
            : planned
            ? IconButton(
                key: ValueKey("toggle-${course.id}"),
                tooltip:
                    "„${course.title}“ ist im Stundenplan – Angaben ansehen",
                isSelected: true,
                icon: const Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(
                      controller: controller,
                      snapshot: snapshot,
                      synthetic: catalog.synthetic,
                    ),
                  ),
                ),
              )
            : IconButton(
                key: ValueKey("toggle-${course.id}"),
                tooltip: "„${course.title}“ zum Stundenplan hinzufügen",
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () => openCourseEditor(
                  context,
                  controller: controller,
                  snapshot: snapshot,
                ),
              ),
      ),
    );
  }
}
