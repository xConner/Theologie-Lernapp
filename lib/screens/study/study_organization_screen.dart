import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../services/timetable/course_catalog_source.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../services/timetable/timetable_export.dart';
import '../../services/timetable/timetable_feature.dart';
import '../../services/timetable/timetable_store.dart';
import '../../widgets/info_report.dart';
import '../timetable/catalog_status.dart';
import '../timetable/course_search_view.dart';
import '../timetable/timetable_export_screen.dart';
import '../timetable/timetable_week_view.dart';
import 'study_documents_view.dart';

/// Hauptbereich „Studiumsorganisation“: Stundenplan (Wochenübersicht,
/// Filter, Überschneidungen), fakultätsübergreifende Veranstaltungssuche und
/// offizielle Studienunterlagen. Stundenplan und Suche teilen sich einen
/// Zustand ([TimetableController]); die Unterlagen funktionieren auch ohne
/// Verbindung zum Veranstaltungskatalog.
///
/// [uid] == null → Gastmodus (lokal gespeichert). [source], [store] und
/// [documentsBundle] sind für Tests austauschbar.
class StudyOrganizationScreen extends StatefulWidget {
  final String? uid;
  final CourseCatalogSource? source;
  final TimetableStore? store;
  final DateTime? today;
  final AssetBundle? documentsBundle;

  /// Zuerst gezeigter Bereich (0 Stundenplan, 1 Suche, 2 Unterlagen).
  final int initialTab;

  const StudyOrganizationScreen({
    super.key,
    required this.uid,
    this.source,
    this.store,
    this.today,
    this.documentsBundle,
    this.initialTab = 0,
  });

  @override
  State<StudyOrganizationScreen> createState() =>
      _StudyOrganizationScreenState();
}

class _StudyOrganizationScreenState extends State<StudyOrganizationScreen>
    with SingleTickerProviderStateMixin {
  late final TimetableController controller = TimetableController(
    source: widget.source ?? defaultCourseCatalogSource(),
    store: widget.store ?? TimetableStore.forUser(widget.uid),
    now: widget.today == null ? null : () => widget.today!,
  );
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 2),
  )..addListener(() => setState(() {}));

  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    _tabs.dispose();
    controller.dispose();
    super.dispose();
  }

  Widget _catalogTab(Widget Function() child, {bool needsCatalog = true}) {
    if (controller.semesterInfo != null ||
        (!needsCatalog && controller.semesterId != null)) {
      return child();
    }
    if (controller.catalogError != null && !controller.catalogLoading) {
      return CatalogErrorView(
        error: controller.catalogError!,
        onRetry: controller.loadCatalog,
      );
    }
    return const Center(
      child: CircularProgressIndicator(
        semanticsLabel: "Veranstaltungen werden geladen",
      ),
    );
  }

  /// Druck/PDF mit dem aktuellen Plan und Filter als Voreinstellung.
  void _openExport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimetableExportScreen(
          plan: controller.plan,
          semester: controller.semesterInfo,
          initialOptions: TimetableExportOptions(
            content: ExportContent.fromFilter(controller.filter),
          ),
          now: widget.today == null ? null : () => widget.today!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Studiumsorganisation"),
        actions: [
          if (_tabs.index == 0)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => IconButton(
                key: const ValueKey("timetable-export"),
                tooltip: "Drucken / als PDF exportieren",
                icon: const Icon(Icons.print_rounded),
                onPressed: controller.entriesLoaded ? _openExport : null,
              ),
            ),
          const InfoButton(module: AppModules.timetable),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: MediaQuery.sizeOf(context).width < 420,
          tabAlignment: MediaQuery.sizeOf(context).width < 420
              ? TabAlignment.start
              : TabAlignment.fill,
          tabs: const [
            Tab(icon: Icon(Icons.view_week_rounded), text: "Stundenplan"),
            Tab(
              icon: Icon(Icons.search_rounded),
              text: "Veranstaltungen suchen",
            ),
            Tab(
              icon: Icon(Icons.description_outlined),
              text: "Studienunterlagen",
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final catalog = controller.catalog;
          final catalogTab = _tabs.index < 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (catalogTab && (catalog?.synthetic ?? false))
                const SyntheticDataBanner(),
              if (catalogTab && controller.semesters.isNotEmpty)
                CatalogStatusBar(controller: controller),
              if (catalogTab && widget.uid == null) const GuestHint(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _catalogTab(
                      () => TimetableWeekView(
                        controller: controller,
                        onSearch: () => _tabs.animateTo(1),
                      ),
                    ),
                    _catalogTab(
                      () => CourseSearchView(controller: controller),
                      needsCatalog: false,
                    ),
                    StudyDocumentsView(bundle: widget.documentsBundle),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Einstieg auf dem Startbildschirm.
class StudyOrganizationButton extends StatelessWidget {
  final String? uid;

  const StudyOrganizationButton({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: const ValueKey("open-study-organization"),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudyOrganizationScreen(uid: uid)),
        ),
        icon: const Icon(Icons.school_rounded),
        label: const Text("Studiumsorganisation"),
      ),
    );
  }
}
