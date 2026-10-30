import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/organizer/import_sources.dart';
import '../../services/organizer/learning_signals.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../services/organizer/organizer_store.dart';
import '../../services/organizer/reading_tasks.dart';
import '../../services/organizer/seminar_import.dart';
import '../../services/timetable/timetable_store.dart';
import '../study/study_organization_screen.dart';
import 'area_screen.dart';
import 'calendar_view.dart';
import 'import_screen.dart';
import 'notes_view.dart';
import 'org_open.dart';
import 'organizer_widgets.dart';
import 'overview_view.dart';
import 'tasks_view.dart';

/// Hauptbereich „Studiumsorganisation“: Übersicht, Aufgaben, Kalender und
/// Notizen in einer Leiste – jede Funktion mit einem Tipp erreichbar, Neues
/// über den Plus-Knopf der jeweiligen Ansicht. Stundenplan und
/// Studienunterlagen liegen eine Ebene tiefer (oben rechts).
///
/// [uid] == null → Gastmodus (lokal gespeichert). [controller] und
/// [importSources] sind für Tests austauschbar.
class OrganizerScreen extends StatefulWidget {
  final String? uid;
  final OrganizerController? controller;
  final Future<List<ImportSource>> Function()? importSources;
  final int initialTab;

  const OrganizerScreen({
    super.key,
    required this.uid,
    this.controller,
    this.importSources,
    this.initialTab = 0,
  });

  @override
  State<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends State<OrganizerScreen>
    with SingleTickerProviderStateMixin {
  CourseReadingTaskSource? _reading;
  StreakLearningSignals? _learning;
  late final OrganizerController c = widget.controller ?? _create();
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 3),
  )..addListener(() => setState(() {}));

  final GlobalKey<TasksViewState> _tasksKey = GlobalKey();
  final GlobalKey<CalendarViewState> _calendarKey = GlobalKey();
  final GlobalKey<NotesViewState> _notesKey = GlobalKey();

  String? _importHint;
  bool _autoChecked = false;

  OrganizerController _create() {
    final uid = widget.uid;
    _reading = CourseReadingTaskSource(uid: uid);
    _learning = StreakLearningSignals(uid: uid);
    return OrganizerController(
      backend: OrganizerBackend.forUser(uid),
      learning: _learning,
      readingSource: _reading,
      timetable: TimetableStore.forUser(uid).watch(),
    );
  }

  @override
  void initState() {
    super.initState();
    c.start();
    _reading?.load();
    _learning?.load();
    c.addListener(_onLoaded);
  }

  @override
  void dispose() {
    c.removeListener(_onLoaded);
    _tabs.dispose();
    if (widget.controller == null) {
      c.dispose();
      _reading?.dispose();
    }
    super.dispose();
  }

  /// Einmal nach dem Laden: automatische Übernahmen und Hinweis auf Neues.
  void _onLoaded() {
    if (_autoChecked || !c.loaded) return;
    _autoChecked = true;
    unawaited(_checkImports());
  }

  Future<void> _checkImports() async {
    try {
      final sources =
          await (widget.importSources?.call() ??
              ImportSources.load(c, uid: widget.uid));
      final n = await ImportSources.runAutomatic(c, sources);
      if (!mounted) return;
      if (n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 1
                  ? "1 Eintrag aus einem Seminarplan übernommen."
                  : "$n Einträge aus Seminarplänen übernommen.",
            ),
          ),
        );
      }
      // Nur für Pläne, die schon einmal übernommen wurden.
      var news = 0;
      for (final s in sources) {
        if (c.importSettings(s.sourceId) == null) continue;
        final diff = SeminarImporter.diff(
          s.build(ImportSettings.fromMap(c.importSettings(s.sourceId))),
          tasks: c.rawTasks,
          events: c.rawEvents,
          today: c.today,
        );
        news += diff.changes
            .where(
              (x) =>
                  x.suggested &&
                  (x.status == ImportStatus.added ||
                      x.status == ImportStatus.changed ||
                      x.status == ImportStatus.removed),
            )
            .length;
      }
      if (mounted) {
        setState(
          () => _importHint = news == 0
              ? null
              : news == 1
              ? "1 Änderung in einem Seminarplan"
              : "$news Änderungen in Seminarplänen",
        );
      }
    } catch (_) {
      // Ohne Seminarpläne funktioniert alles andere weiter.
    }
  }

  void _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportScreen(
          controller: c,
          uid: widget.uid,
          sources: widget.importSources,
        ),
      ),
    );
    _checkImports();
  }

  void _openTimetable() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyOrganizationScreen(uid: widget.uid),
      ),
    );
  }

  void _showTasks(TaskView view) {
    _tabs.animateTo(1);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tasksKey.currentState?.show(view),
    );
  }

  void _add() {
    switch (_tabs.index) {
      case 1:
        openTaskEditor(
          context,
          c,
          uid: widget.uid,
          due: _tasksKey.currentState?.view == TaskView.open ? null : c.today,
          areaId: _tasksKey.currentState?.filter.areaId,
        );
      case 2:
        openEventEditor(
          context,
          c,
          uid: widget.uid,
          date: _calendarKey.currentState?.selected,
        );
      case 3:
        openNoteEditor(
          context,
          c,
          uid: widget.uid,
          areaId: _notesKey.currentState?.areaId,
        );
      default:
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (sheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_task_rounded),
                title: const Text("Neue Aufgabe"),
                onTap: () {
                  Navigator.pop(sheet);
                  openTaskEditor(context, c, uid: widget.uid, due: c.today);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text("Neuer Termin"),
                onTap: () {
                  Navigator.pop(sheet);
                  openEventEditor(context, c, uid: widget.uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text("Neue Notiz"),
                onTap: () {
                  Navigator.pop(sheet);
                  openNoteEditor(context, c, uid: widget.uid);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 420;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Studiumsorganisation"),
        actions: [
          IconButton(
            key: const ValueKey("open-timetable"),
            tooltip: "Stundenplan und Studienunterlagen",
            icon: const Icon(Icons.view_week_rounded),
            onPressed: _openTimetable,
          ),
          IconButton(
            key: const ValueKey("open-import"),
            tooltip: "Seminarpläne übernehmen",
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: _openImport,
          ),
          IconButton(
            tooltip: "Einrichten",
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrganizerSettingsScreen(controller: c),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: narrow,
          tabAlignment: narrow ? TabAlignment.start : TabAlignment.fill,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: "Übersicht"),
            Tab(icon: Icon(Icons.checklist_rounded), text: "Aufgaben"),
            Tab(icon: Icon(Icons.calendar_month_rounded), text: "Kalender"),
            Tab(icon: Icon(Icons.sticky_note_2_outlined), text: "Notizen"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey("organizer-add"),
        tooltip: switch (_tabs.index) {
          1 => "Neue Aufgabe",
          2 => "Neuer Termin",
          3 => "Neue Notiz",
          _ => "Neu",
        },
        onPressed: _add,
        child: const Icon(Icons.add_rounded),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.loaded) {
            return Center(
              child: c.loadError == null
                  ? const CircularProgressIndicator(
                      semanticsLabel: "Wird geladen",
                    )
                  : const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Die Studiumsorganisation konnte nicht geladen werden. "
                        "Bitte prüfe die Verbindung.",
                        textAlign: TextAlign.center,
                      ),
                    ),
            );
          }
          return Column(
            children: [
              SaveFailedBanner(controller: c),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        OverviewView(
                          controller: c,
                          uid: widget.uid,
                          onShowTasks: _showTasks,
                          onShowCalendar: () => _tabs.animateTo(2),
                          onShowNotes: () => _tabs.animateTo(3),
                          onOpenImport: _openImport,
                          importHint: _importHint,
                        ),
                        TasksView(
                          key: _tasksKey,
                          controller: c,
                          uid: widget.uid,
                        ),
                        CalendarView(
                          key: _calendarKey,
                          controller: c,
                          uid: widget.uid,
                          onOpenTimetable: _openTimetable,
                        ),
                        NotesView(
                          key: _notesKey,
                          controller: c,
                          uid: widget.uid,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
