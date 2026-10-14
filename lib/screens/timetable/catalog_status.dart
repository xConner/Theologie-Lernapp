import 'package:flutter/material.dart';

import '../../services/timetable/course_catalog_source.dart';
import '../../services/timetable/timetable_controller.dart';
import '../../theme/app_theme.dart';

// Gemeinsame Bausteine der Studiumsorganisation: Semesterwahl und Stand des
// Katalogs, Hinweise, Fehleranzeige.

String formatDateTime(DateTime t) {
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
          "${updated == null ? "" : " vom ${formatDateTime(updated)}"}. "
          "Aktuelle Änderungen fehlen möglicherweise.";
    } else if (load.sourceStale) {
      warning = true;
      status =
          "UnivIS ist derzeit nicht erreichbar – Stand"
          "${updated == null ? "" : " vom ${formatDateTime(updated)}"}.";
    } else if (load.origin == CatalogOrigin.synthetic) {
      status = "Synthetische Testdaten";
    } else {
      status =
          "Stand: ${updated == null ? "unbekannt" : formatDateTime(updated)} · "
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

class GuestHint extends StatelessWidget {
  const GuestHint({super.key});

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

class CatalogErrorView extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const CatalogErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

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

/// Kurze Rückmeldung nach dem Speichern (auch bei Fehlern).
void showSaveFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

const String saveFailedMessage =
    "Der Stundenplan konnte nicht gespeichert werden. Bitte später erneut "
    "versuchen.";
