import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/timetable_entry.dart';
import 'course_catalog_source.dart';
import 'timetable_schedule.dart';
import 'timetable_store.dart';

/// Zustand der Stundenplan-Funktion: Katalog des gewählten Semesters
/// (zentral, nur lesend) und persönliche Einträge (je Nutzer, alle Semester).
/// Beide bleiben getrennt; der Controller verbindet sie nur für die Anzeige.
/// Ein Semesterwechsel lädt nur einen anderen Katalog – Einträge werden dabei
/// nie verändert.
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

  bool isPending(String courseId) => _pending.contains(courseId);

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Semester und Katalog laden, persönlichen Stundenplan beobachten.
  Future<void> start() async {
    _watchEntries();
    await loadCatalog();
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

  bool isPlanned(String courseId) => plannedIds.contains(courseId);

  /// Einträge des angezeigten Semesters.
  List<TimetableEntry> get entriesOfSemester {
    final id = catalog?.semester.id;
    return [
      for (final e in _entries)
        if (e.semesterId.isEmpty || e.semesterId == id) e,
    ];
  }

  /// Einträge anderer Semester, nach Semester gruppiert.
  Map<String, List<TimetableEntry>> get entriesOfOtherSemesters {
    final id = catalog?.semester.id;
    final result = <String, List<TimetableEntry>>{};
    for (final e in _entries) {
      if (e.semesterId.isNotEmpty && e.semesterId != id) {
        (result[e.semesterId] ??= []).add(e);
      }
    }
    return result;
  }

  String semesterLabel(String id) =>
      _semesters.where((s) => s.id == id).firstOrNull?.label ?? id;

  TimetableEntryState? stateFor(TimetableEntry entry) {
    final catalog = this.catalog;
    return catalog == null ? null : stateOf(entry, catalog);
  }

  /// Überschneidungen innerhalb des Stundenplans: Veranstaltung →
  /// (andere Veranstaltung → Anzahl Termine).
  Map<String, Map<String, int>> get planConflicts {
    final catalog = this.catalog;
    if (catalog == null) return const {};
    return conflictsByCourse(catalog, plannedIds);
  }

  /// Überschneidungen von [courseId] mit dem bestehenden Stundenplan.
  Map<String, int> conflictsFor(String courseId) {
    final catalog = this.catalog;
    if (catalog == null) return const {};
    return conflictsWithPlan(
      catalog,
      courseId,
      plannedIds.where((id) => id != courseId),
    );
  }

  Future<void> add(CatalogCourse course) =>
      _run(course.id, () => store.add(TimetableEntry.fromCourse(course)));

  Future<void> remove(String courseId) =>
      _run(courseId, () => store.remove(courseId));

  /// Fügt hinzu oder entfernt; liefert true, wenn danach geplant.
  Future<bool> toggle(CatalogCourse course) async {
    if (isPlanned(course.id)) {
      await remove(course.id);
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
