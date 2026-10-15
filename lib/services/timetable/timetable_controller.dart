import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/course_snapshot.dart';
import '../../models/timetable/timetable_entry.dart';
import 'course_catalog_source.dart';
import 'plan_conflicts.dart';
import 'plan_schedule.dart';
import 'timetable_store.dart';
import 'week_layout.dart';

/// Ergebnis eines Abgleichs mit der Quelle.
enum RefreshOutcome { unchanged, updated, notFound }

/// Zustand der Studiumsorganisation: Katalog des gewählten Semesters
/// (zentral, nur lesend), persönliche Einträge (je Nutzer, alle Semester)
/// und der daraus aufgelöste Plan. Katalog und Einträge bleiben getrennt;
/// ein Semesterwechsel lädt nur einen anderen Katalog – Einträge werden
/// dabei nie verändert.
class TimetableController extends ChangeNotifier {
  final CourseCatalogSource source;
  final TimetableStore store;

  /// Heutiges Datum für Startwoche und „nächste Termine“ (in Tests fest).
  final DateTime Function() now;

  TimetableController({
    required this.source,
    required this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// Fakultätsübergreifende Suche, falls die Quelle sie anbietet.
  CourseSearchSource? get searchSource =>
      source is CourseSearchSource ? source as CourseSearchSource : null;

  static const String filterKey = "timetable.v1.kindFilter";

  List<SemesterOption> _semesters = const [];
  String? _semesterId;
  CatalogLoad? _load;
  Object? _catalogError;
  bool _catalogLoading = false;
  int _loadToken = 0;

  List<TimetableEntry> _entries = const [];
  bool _entriesLoaded = false;
  Object? _entriesError;
  StreamSubscription<List<TimetableEntry>>? _subscription;

  SessionKindFilter _filter = SessionKindFilter.all;

  /// Kennungen mit laufendem Speichervorgang (für Ladeanzeigen an Buttons).
  final Set<String> _pending = {};

  List<SemesterOption> get semesters => _semesters;
  String? get semesterId => _semesterId;
  CatalogLoad? get catalogLoad => _load;
  CourseCatalog? get catalog => _load?.catalog;
  Object? get catalogError => _catalogError;
  bool get catalogLoading => _catalogLoading;

  List<TimetableEntry> get entries => _entries;
  bool get entriesLoaded => _entriesLoaded;
  Object? get entriesError => _entriesError;

  SessionKindFilter get filter => _filter;

  bool isPending(String courseId) => _pending.contains(courseId);

  bool _disposed = false;

  void _notify() {
    _planCache = null;
    if (!_disposed) notifyListeners();
  }

  /// Semester und Katalog laden, persönlichen Stundenplan beobachten.
  Future<void> start() async {
    _watchEntries();
    unawaited(_restoreFilter());
    await loadCatalog();
  }

  Future<void> _restoreFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final restored = SessionKindFilter.fromName(prefs.getString(filterKey));
      if (restored != _filter) {
        _filter = restored;
        _notify();
      }
    } catch (_) {
      // Ohne gespeicherte Einstellung: alle Veranstaltungen.
    }
  }

  /// Filter wählen und auf dem Gerät merken.
  Future<void> setFilter(SessionKindFilter filter) async {
    if (filter == _filter) return;
    _filter = filter;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(filterKey, filter.name);
    } catch (_) {
      // Nicht speicherbar (z. B. privates Fenster): gilt für diese Sitzung.
    }
  }

  /// Lädt (bzw. aktualisiert) Semesterliste und Katalog des gewählten
  /// Semesters. Ohne Wahl: das erste angebotene (laufende) Semester.
  Future<void> loadCatalog() async {
    final token = ++_loadToken;
    _catalogLoading = true;
    _catalogError = null;
    _notify();
    try {
      final semesters = await source.semesters();
      if (token != _loadToken) return;
      _semesters = semesters;
      if (semesters.isEmpty) {
        throw const CatalogUnavailableException(
          "Derzeit wird kein Semester angeboten.",
        );
      }
      final ids = {for (final s in semesters) s.id};
      if (_semesterId == null || !ids.contains(_semesterId)) {
        _semesterId = semesters.first.id;
      }
      final load = await source.load(_semesterId!);
      if (token != _loadToken) return;
      _load = load;
    } catch (e) {
      if (token != _loadToken) return;
      _catalogError = e;
    } finally {
      if (token == _loadToken) {
        _catalogLoading = false;
        _notify();
      }
    }
  }

  /// Wechselt das Semester. Einträge anderer Semester bleiben erhalten.
  Future<void> selectSemester(String semesterId) async {
    if (semesterId == _semesterId && _load != null) return;
    _semesterId = semesterId;
    _load = null;
    await loadCatalog();
  }

  void _watchEntries() {
    _subscription?.cancel();
    _entriesError = null;
    _subscription = store.watch().listen(
      (entries) {
        _entries = entries;
        _entriesLoaded = true;
        _entriesError = null;
        _notify();
      },
      onError: (Object e) {
        _entriesError = e;
        _entriesLoaded = true;
        _notify();
      },
    );
  }

  /// Erneut verbinden, z. B. nach einem Fehler.
  void retryEntries() => _watchEntries();

  Set<String> get plannedIds => {for (final e in _entries) e.courseId};

  /// Eintrag zu einer Veranstaltung: gleiche Kennung oder gemeinsame
  /// Quellkennung (dieselbe Veranstaltung aus Fakultätskatalog und Suche).
  TimetableEntry? entryFor(
    String courseId, [
    List<SourceRef> sources = const [],
  ]) {
    for (final e in _entries) {
      if (e.courseId == courseId) return e;
    }
    if (sources.isEmpty) return null;
    for (final e in _entries) {
      if (e.sources.any(sources.contains)) return e;
    }
    return null;
  }

  bool isPlanned(String courseId, [List<SourceRef> sources = const []]) =>
      entryFor(courseId, sources) != null;

  /// Name des Semesters, in dem die Veranstaltung schon geplant ist.
  String semesterLabel(String id) =>
      _semesters.where((s) => s.id == id).firstOrNull?.label ?? id;

  /// Einträge des angezeigten Semesters.
  List<TimetableEntry> get entriesOfSemester {
    final id = _semesterId ?? catalog?.semester.id;
    return [
      for (final e in _entries)
        if (e.semesterId.isEmpty || e.semesterId == id) e,
    ];
  }

  /// Einträge anderer Semester, nach Semester gruppiert.
  Map<String, List<TimetableEntry>> get entriesOfOtherSemesters {
    final id = _semesterId ?? catalog?.semester.id;
    final result = <String, List<TimetableEntry>>{};
    for (final e in _entries) {
      if (e.semesterId.isNotEmpty && e.semesterId != id) {
        (result[e.semesterId] ??= []).add(e);
      }
    }
    return result;
  }

  TimetableEntryState? stateFor(TimetableEntry entry) {
    final catalog = this.catalog;
    return catalog == null ? null : stateOf(entry, catalog);
  }

  // --- Plan --------------------------------------------------------------------

  List<PlanCourse>? _planCache;

  /// Veranstaltungen des angezeigten Semesters mit ihren Terminen.
  List<PlanCourse> get plan => _planCache ??= [
    for (final e in entriesOfSemester) resolvePlanCourse(e, catalog: catalog),
  ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  PlanCourse? planCourse(String entryId) =>
      plan.where((p) => p.id == entryId).firstOrNull;

  /// Semesterrahmen der Anzeige: aus dem Katalog, sonst (offline ohne
  /// gespeicherten Katalog) aus einem gespeicherten Import.
  CatalogSemester? get semesterInfo {
    final fromCatalog = catalog?.semester;
    if (fromCatalog != null) return fromCatalog;
    for (final e in entriesOfSemester) {
      final s = e.snapshot?.semester;
      if (s != null && (_semesterId == null || s.id == _semesterId)) return s;
    }
    return null;
  }

  /// Termine des Plans nach dem gewählten Filter.
  List<PlanOccurrence> get visibleOccurrences => [
    for (final p in plan)
      for (final o in p.occurrences)
        if (_filter.accepts(o)) o,
  ];

  /// Überschneidungsstellen der angezeigten Termine (ganzes Semester).
  List<ConflictSpot> get conflicts => conflictSpots(visibleOccurrences);

  /// Überschneidungen, die eine (noch nicht geplante) Veranstaltung mit dem
  /// Plan hätte – vor dem Hinzufügen.
  List<ConflictSpot> conflictsFor(
    CourseSnapshot candidate, {
    EntryOverrides overrides = EntryOverrides.none,
  }) {
    const candidateId = "\u0000kandidat";
    final existing = entryFor(candidate.courseId, candidate.sources);
    final others = [
      for (final p in plan)
        if (p.id != existing?.courseId) ...p.occurrences,
    ];
    final mine = resolvePlanCourse(
      TimetableEntry.fromSnapshot(candidate),
    ).occurrences.map((o) => o.copyWith(entryId: candidateId));
    return spotsInvolving(conflictSpots([...others, ...mine]), candidateId);
  }

  // --- Ändern ----------------------------------------------------------------

  /// Fügt eine Veranstaltung des Fakultätskatalogs hinzu.
  Future<void> add(CatalogCourse course, {EntryOverrides? overrides}) {
    final catalog = this.catalog;
    if (catalog == null) {
      return Future.error(StateError("Kein Katalog geladen"));
    }
    return addSnapshot(
      CourseSnapshot.fromCatalog(catalog, course, fromFacultyCatalog: true),
      overrides: overrides,
    );
  }

  /// Fügt eine Veranstaltung hinzu (oder ersetzt den bestehenden Eintrag
  /// derselben Veranstaltung – keine Duplikate).
  Future<void> addSnapshot(
    CourseSnapshot snapshot, {
    EntryOverrides? overrides,
  }) {
    final existing = entryFor(snapshot.courseId, snapshot.sources);
    final entry = TimetableEntry.fromSnapshot(
      snapshot,
      overrides: overrides ?? existing?.overrides ?? EntryOverrides.none,
    );
    final stored = existing == null
        ? entry
        : TimetableEntry(
            courseId: existing.courseId,
            semesterId: entry.semesterId,
            sources: {...existing.sources, ...entry.sources}.toList(),
            title: entry.title,
            number: entry.number,
            scheduleSignature: entry.scheduleSignature,
            snapshot: snapshot,
            overrides: entry.overrides,
          );
    return _run(
      stored.courseId,
      () => store.add(stored, legacyFallback: snapshot.fromFacultyCatalog),
    );
  }

  /// Persönliche Anpassungen speichern (Import bleibt unverändert).
  Future<void> updateOverrides(
    TimetableEntry entry,
    EntryOverrides overrides,
  ) => _run(
    entry.courseId,
    () => store.add(entry.copyWith(overrides: overrides)),
  );

  /// Geänderte Termine der Quelle übernehmen: Der Eintrag merkt sich den
  /// neuen Stand. Mit [discardOverrides] werden auch die persönlichen
  /// Anpassungen der Termine verworfen.
  Future<void> acceptSourceChanges(
    PlanCourse course, {
    bool discardOverrides = false,
  }) {
    final imported = course.imported;
    if (imported == null) return Future.value();
    final o = course.entry.overrides;
    return _run(
      course.id,
      () => store.add(
        course.entry.copyWith(
          snapshot: imported,
          scheduleSignature: imported.scheduleSignature,
          overrides: discardOverrides
              ? EntryOverrides(
                  title: o.title,
                  lecturers: o.lecturers,
                  note: o.note,
                )
              : o,
        ),
        legacyFallback: imported.fromFacultyCatalog,
      ),
    );
  }

  /// Gespeicherten Import einer Veranstaltung aus der Suche erneut bei der
  /// Quelle abfragen. Persönliche Anpassungen bleiben erhalten.
  Future<RefreshOutcome> refreshFromSource(TimetableEntry entry) async {
    final search = searchSource;
    final number = entry.snapshot?.number ?? entry.number;
    if (search == null || number == null || entry.semesterId.isEmpty) {
      return RefreshOutcome.notFound;
    }
    final result = await search.search(
      semesterId: entry.semesterId,
      number: number,
    );
    final match = result.catalog.courses
        .where(
          (c) =>
              c.id == entry.courseId || c.sources.any(entry.sources.contains),
        )
        .firstOrNull;
    if (match == null) return RefreshOutcome.notFound;
    final fresh = CourseSnapshot.fromCatalog(result.catalog, match);
    final before = entry.snapshot?.scheduleSignature;
    await _run(
      entry.courseId,
      () => store.add(
        entry.copyWith(
          snapshot: fresh,
          scheduleSignature: fresh.scheduleSignature,
        ),
      ),
    );
    return before == fresh.scheduleSignature
        ? RefreshOutcome.unchanged
        : RefreshOutcome.updated;
  }

  Future<void> remove(String courseId) =>
      _run(courseId, () => store.remove(courseId));

  /// Fügt hinzu oder entfernt; liefert true, wenn danach geplant.
  Future<bool> toggle(CatalogCourse course) async {
    final existing = entryFor(course.id, course.sources);
    if (existing != null) {
      await remove(existing.courseId);
      return false;
    }
    await add(course);
    return true;
  }

  Future<void> _run(String courseId, Future<void> Function() action) async {
    _pending.add(courseId);
    _notify();
    try {
      await action();
    } finally {
      _pending.remove(courseId);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
