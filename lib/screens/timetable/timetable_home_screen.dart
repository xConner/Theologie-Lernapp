import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../services/timetable/course_catalog_source.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../services/timetable/timetable_feature.dart';
import '../../services/timetable/timetable_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import 'course_search_view.dart';
import 'timetable_week_view.dart';

/// Stundenplan: eigener Wochenplan und Veranstaltungssuche.
///
/// [uid] == null → Gastmodus (lokal gespeichert). [source] und [store] sind
/// für Tests austauschbar; Standard sind der Katalog der CAU über
/// `/api/catalog` (siehe timetable_feature.dart) und der Speicher des
/// Nutzers.
class TimetableHomeScreen extends StatefulWidget {
  final String? uid;
  final CourseCatalogSource? source;
  final TimetableStore? store;
  final DateTime? today;

  const TimetableHomeScreen({
    super.key,
    required this.uid,
    this.source,
    this.store,
    this.today,
  });

  @override
  State<TimetableHomeScreen> createState() => _TimetableHomeScreenState();
}

class _TimetableHomeScreenState extends State<TimetableHomeScreen> {
  late final TimetableController controller = TimetableController(
    source: widget.source ?? defaultCourseCatalogSource(),
    store: widget.store ?? TimetableStore.forUser(widget.uid),
    now: widget.today == null ? null : () => widget.today!,
  );

  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Stundenplan"),
          actions: const [InfoButton(module: AppModules.timetable)],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.view_week_rounded),
                text: "Mein Stundenplan",
              ),
              Tab(icon: Icon(Icons.search_rounded), text: "Veranstaltungen"),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final catalog = controller.catalog;
            final Widget body;
            if (catalog == null) {
              body =
                  controller.catalogError != null && !controller.catalogLoading
                  ? _CatalogError(
                      error: controller.catalogError!,
                      onRetry: controller.loadCatalog,
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: "Veranstaltungen werden geladen",
                      ),
                    );
            } else {
              body = TabBarView(
                children: [
                  TimetableWeekView(controller: controller),
                  CourseSearchView(controller: controller),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (catalog?.synthetic ?? false) const SyntheticDataBanner(),
                if (controller.semesters.isNotEmpty)
                  CatalogStatusBar(controller: controller),
                if (widget.uid == null) const _GuestHint(),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _dateTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, "0");
  return "${l.day}.${l.month}.${l.year}, ${two(l.hour)}:${two(l.minute)} Uhr";
}

/// Semesterwahl, Stand und Herkunft des Katalogs, Aktualisieren.
class CatalogStatusBar extends StatelessWidget {
  final TimetableController controller;

  const CatalogStatusBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final load = controller.catalogLoad;
    final small = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    final updated = load?.updatedAt;
    final String? status;
    var warning = false;
    if (load == null) {
      status = controller.catalogLoading ? "Wird geladen …" : null;
    } else if (load.origin == CatalogOrigin.offlineCache) {
      warning = true;
      status =
          "Offline – gespeicherter Stand"
          "${updated == null ? "" : " vom ${_dateTime(updated)}"}. "
          "Aktuelle Änderungen fehlen möglicherweise.";
    } else if (load.sourceStale) {
      warning = true;
      status =
          "UnivIS ist derzeit nicht erreichbar – Stand"
          "${updated == null ? "" : " vom ${_dateTime(updated)}"}.";
    } else if (load.origin == CatalogOrigin.synthetic) {
      status = "Synthetische Testdaten";
    } else {
      status =
          "Stand: ${updated == null ? "unbekannt" : _dateTime(updated)} · "
          "Quelle: UnivIS der CAU Kiel";
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  key: const ValueKey("semester-select"),
                  value: controller.semesterId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text("Semester"),
                  items: [
                    for (final s in controller.semesters)
                      DropdownMenuItem(value: s.id, child: Text(s.label)),
                  ],
                  onChanged: controller.catalogLoading
                      ? null
                      : (id) {
                          if (id != null) controller.selectSemester(id);
                        },
                ),
                if (status != null)
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (warning) ...[
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 16,
                            color: colors.error,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            status,
                            key: const ValueKey("catalog-status"),
                            style: warning
                                ? small?.copyWith(color: colors.error)
                                : small,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          controller.catalogLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      semanticsLabel: "Katalog wird aktualisiert",
                    ),
                  ),
                )
              : IconButton(
                  tooltip: "Katalog aktualisieren",
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: controller.loadCatalog,
                ),
        ],
      ),
    );
  }
}

/// Unübersehbarer Hinweis auf erfundene Veranstaltungen.
class SyntheticDataBanner extends StatelessWidget {
  const SyntheticDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label:
          "Hinweis: Vorschau mit synthetischen Testdaten. "
          "Die Veranstaltungen sind erfunden.",
      excludeSemantics: true,
      child: Container(
        color: colors.accent.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.science_outlined, color: colors.textPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Vorschau mit synthetischen Testdaten – die Veranstaltungen "
                "sind erfunden.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestHint extends StatelessWidget {
  const _GuestHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        "Gastmodus: Dein Stundenplan wird nur auf diesem Gerät gespeichert. "
        "Melde dich an, um ihn auf allen Geräten zu nutzen.",
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _CatalogError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: context.colors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              "Die Veranstaltungen konnten nicht geladen werden.",
              textAlign: TextAlign.center,
            ),
            if (error is CatalogUnavailableException) ...[
              const SizedBox(height: 4),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Erneut versuchen"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fügt hinzu bzw. entfernt und meldet das Ergebnis (auch Fehler).
Future<void> toggleWithFeedback(
  BuildContext context,
  TimetableController controller,
  String courseId,
) async {
  final course = controller.catalog?.courseById(courseId);
  if (course == null) {
    await controller.remove(courseId);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    final added = await controller.toggle(course);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added
                ? "Zum Stundenplan hinzugefügt."
                : "Aus dem Stundenplan entfernt.",
          ),
        ),
      );
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Der Stundenplan konnte nicht gespeichert werden. "
            "Bitte später erneut versuchen.",
          ),
        ),
      );
  }
}
