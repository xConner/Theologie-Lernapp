import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/timetable/course_catalog.dart';
import '../../models/timetable/timetable_entry.dart';
import 'course_catalog_source.dart';
import 'timetable_schedule.dart';
import 'timetable_store.dart';

/// Zustand der Stundenplan-Funktion: Katalog (zentral, nur lesend) und
/// persönliche Einträge (je Nutzer). Beide bleiben getrennt; der Controller
/// verbindet sie nur für die Anzeige.
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

  CourseCatalog? _catalog;
  Object? _catalogError;
  bool _catalogLoading = false;

  List<TimetableEntry> _entries = const [];
  bool _entriesLoaded = false;
  Object? _entriesError;
  StreamSubscription<List<TimetableEntry>>? _subscription;

  /// Kennungen mit laufendem Speichervorgang (für Ladeanzeigen an Buttons).
  final Set<String> _pending = {};

  CourseCatalog? get catalog => _catalog;
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

  /// Lädt den Katalog und beobachtet den persönlichen Stundenplan.
  Future<void> start() async {
    _watchEntries();
    await loadCatalog();
  }

  Future<void> loadCatalog() async {
    _catalogLoading = true;
    _catalogError = null;
    _notify();
    try {
      _catalog = await source.load();
    } catch (e) {
      _catalogError = e;
    } finally {
      _catalogLoading = false;
      _notify();
    }
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

  /// Gewählte Veranstaltungen, die im aktuellen Katalog vorhanden sind.
  List<CatalogCourse> get plannedCourses {
    final catalog = _catalog;
    if (catalog == null) return const [];
    return [for (final e in _entries) ?catalog.courseById(e.courseId)];
  }

  TimetableEntryState? stateFor(TimetableEntry entry) {
    final catalog = _catalog;
    return catalog == null ? null : stateOf(entry, catalog);
  }

  /// Überschneidungen innerhalb des Stundenplans: Veranstaltung →
  /// (andere Veranstaltung → Anzahl Termine).
  Map<String, Map<String, int>> get planConflicts {
    final catalog = _catalog;
    if (catalog == null) return const {};
    return conflictsByCourse(catalog, plannedIds);
  }

  /// Überschneidungen von [courseId] mit dem bestehenden Stundenplan.
  Map<String, int> conflictsFor(String courseId) {
    final catalog = _catalog;
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
