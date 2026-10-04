import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../info/app_info.dart';
import '../info/module_info.dart';
import '../screens/about_screen.dart';
import '../services/reports/report.dart';
import '../services/reports/report_service.dart';
import '../theme/app_theme.dart';
import 'button_progress_indicator.dart';

/// Einheitlicher Zugang zu Informationen, Quellen und Fehlermeldungen:
///
/// * Screens mit freiem Platz in der AppBar zeigen [InfoButton] (ⓘ).
/// * Trainer, deren AppBar bereits voll ist, zeigen [InfoReportFooter] am
///   Ende ihres Inhalts.
///
/// Beide öffnen dasselbe Info-Blatt ([showModuleInfo]) und dasselbe
/// Meldeformular ([showReportDialog]). Der Inhalt je Bereich steht
/// deklarativ in `AppModules`.

/// Liefert beim Öffnen des Meldeformulars den aktuellen Kontext des Screens
/// (z. B. angezeigter Eintrag). Siehe [ReportContext.details].
typedef ReportDetails = Map<String, String> Function();

int _openOverlays = 0;

/// true, solange ein Info-Blatt, ein Meldeformular oder die daraus geöffnete
/// Seite „Über die App“ über dem Screen liegt. Trainer mit globalem
/// Tastatur-Listener ignorieren währenddessen die Enter-Taste, damit eine
/// Eingabe im Formular nicht die Frage dahinter auswertet.
bool get infoReportOverlayOpen => _openOverlays > 0;

/// Zählt sich über den Widget-Lebenszyklus mit, damit die Sperre auch dann
/// endet, wenn die Route ohne `pop` abgebaut wird.
class _OverlayScope extends StatefulWidget {
  final Widget child;

  const _OverlayScope({required this.child});

  @override
  State<_OverlayScope> createState() => _OverlayScopeState();
}

class _OverlayScopeState extends State<_OverlayScope> {
  @override
  void initState() {
    super.initState();
    _openOverlays++;
  }

  @override
  void dispose() {
    _openOverlays--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Zeigt die Informationen zu [module] als Bottom Sheet.
Future<void> showModuleInfo(
  BuildContext context,
  ModuleInfo module, {
  ReportDetails? reportDetails,
  bool showAboutLink = true,
}) async {
  final action = await showModalBottomSheet<_InfoAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _OverlayScope(
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: _ModuleInfoView(module: module, showAboutLink: showAboutLink),
        ),
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _InfoAction.report:
      await showReportDialog(
        context,
        module: module,
        reportDetails: reportDetails,
      );
    case _InfoAction.about:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => const _OverlayScope(child: AboutScreen()),
        ),
      );
  }
}

/// Öffnet das Meldeformular. Ohne [module] entsteht eine allgemeine Meldung.
Future<void> showReportDialog(
  BuildContext context, {
  ModuleInfo module = AppModules.general,
  ReportDetails? reportDetails,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  final reportContext = ReportContext(
    module: module,
    details: reportDetails?.call() ?? const {},
  );

  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _OverlayScope(child: ReportDialog(reportContext: reportContext)),
  );

  if (sent == true) {
    messenger?.showSnackBar(
      const SnackBar(content: Text("Danke! Deine Meldung wurde gesendet.")),
    );
  }
}

/// ⓘ für die AppBar: Informationen und Quellen zum Bereich, von dort aus
/// auch „Fehler melden“.
class InfoButton extends StatelessWidget {
  final ModuleInfo module;
  final ReportDetails? reportDetails;

  const InfoButton({super.key, required this.module, this.reportDetails});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      tooltip: "Info, Quellen und Fehler melden",
      onPressed: () =>
          showModuleInfo(context, module, reportDetails: reportDetails),
    );
  }
}

/// Dezente Fußzeile für Trainer: „Info & Quellen“ und „Fehler melden“.
class InfoReportFooter extends StatelessWidget {
  final ModuleInfo module;
  final ReportDetails? reportDetails;

  const InfoReportFooter({super.key, required this.module, this.reportDetails});

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: context.colors.textSecondary,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      visualDensity: VisualDensity.compact,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          TextButton.icon(
            style: style,
            icon: const Icon(Icons.info_outline_rounded, size: 16),
            label: const Text("Info & Quellen"),
            onPressed: () =>
                showModuleInfo(context, module, reportDetails: reportDetails),
          ),
          TextButton.icon(
            style: style,
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text("Fehler melden"),
            onPressed: () => showReportDialog(
              context,
              module: module,
              reportDetails: reportDetails,
            ),
          ),
        ],
      ),
    );
  }
}

enum _InfoAction { report, about }

class _ModuleInfoView extends StatelessWidget {
  final ModuleInfo module;
  final bool showAboutLink;

  const _ModuleInfoView({required this.module, required this.showAboutLink});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(module.title, style: textTheme.titleLarge),

          if (module.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(module.description),
          ],

          if (module.sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text("Daten und Quellen", style: textTheme.titleMedium),
            for (final source in module.sources) SourceInfoView(source: source),
          ],

          if (module.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text("Hinweise", style: textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final note in module.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("•  "),
                    Expanded(child: Text(note)),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 16),

          Text(
            "Die App wurde mit KI-Unterstützung entwickelt. Inhalte können "
            "Fehler enthalten.",
            style: secondary,
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: const Text("Fehler in diesem Bereich melden"),
            onPressed: () => Navigator.pop(context, _InfoAction.report),
          ),

          if (showAboutLink)
            TextButton(
              onPressed: () => Navigator.pop(context, _InfoAction.about),
              child: const Text("Über die App"),
            ),
        ],
      ),
    );
  }
}

/// Darstellung einer Quellenangabe. Fehlt die Herkunft, wird das offen
/// gesagt.
class SourceInfoView extends StatelessWidget {
  final SourceInfo source;

  const SourceInfoView({super.key, required this.source});

  static const String undocumented =
      "Die Herkunft dieses Datensatzes ist derzeit im Projekt nicht "
      "dokumentiert.";

  Widget _line(BuildContext context, String label, String text) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: text),
          ],
        ),
        style: style,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = source.url;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(source.title, style: Theme.of(context).textTheme.titleSmall),

          _line(context, "Quelle", source.origin ?? undocumented),

          if (source.processing != null)
            _line(context, "Aufbereitung", source.processing!),

          if (source.aiNote != null)
            _line(context, "KI-Unterstützung", source.aiNote!),

          if (source.license != null) _line(context, "Lizenz", source.license!),

          if (url != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(Uri.parse(url).host),
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

/// Meldeformular. Schließt mit `true`, wenn die Meldung gesendet wurde.
class ReportDialog extends StatefulWidget {
  final ReportContext reportContext;

  const ReportDialog({super.key, required this.reportContext});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final TextEditingController descriptionController = TextEditingController();

  ReportCategory? category;

  bool sending = false;

  String? error;

  /// Nach einem fehlgeschlagenen Senden: Meldung zum Kopieren anbieten.
  Report? failedReport;

  bool copied = false;

  final GlobalKey _errorKey = GlobalKey();

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  /// Der Dialog scrollt auf kleinen Displays; eine neue Fehlermeldung soll
  /// nicht unterhalb des sichtbaren Bereichs landen.
  void _showError(String message, {Report? failed}) {
    setState(() {
      sending = false;
      error = message;
      failedReport = failed;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final errorContext = _errorKey.currentContext;

      if (errorContext != null) {
        // Nur so weit scrollen wie nötig, damit die Auswahl oben sichtbar
        // bleibt.
        Scrollable.ensureVisible(
          errorContext,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  Future<void> _submit() async {
    final selected = category;
    final description = descriptionController.text.trim();

    if (selected == null) {
      _showError("Bitte wähle aus, worum es geht.");
      return;
    }

    if (description.length < Report.minDescriptionLength) {
      _showError("Bitte beschreibe kurz, was falsch ist.");
      return;
    }

    final report = Report(
      category: selected,
      description: description,
      context: widget.reportContext,
    );

    setState(() {
      sending = true;
      error = null;
      failedReport = null;
      copied = false;
    });

    try {
      await ReportService.instance.submit(report);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ReportThrottledException catch (e) {
      if (!mounted) return;

      _showError(
        "Du hast gerade erst eine Meldung gesendet. Bitte warte noch "
        "${e.retryAfter.inSeconds + 1} Sekunden.",
      );
    } catch (_) {
      if (!mounted) return;

      _showError(
        "Die Meldung konnte nicht gesendet werden. Bitte versuche es später "
        "erneut.",
        failed: report,
      );
    }
  }

  Future<void> _copy(Report report) async {
    await Clipboard.setData(ClipboardData(text: report.toPlainText()));

    if (mounted) {
      setState(() {
        copied = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportContext = widget.reportContext;
    final contextText = reportContext.text;

    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

    final narrow = MediaQuery.of(context).size.width < 480;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 40,
        vertical: 24,
      ),
      scrollable: true,
      title: const Text("Fehler melden"),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in ReportCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: category == c,
                    onSelected: sending
                        ? null
                        : (_) {
                            setState(() {
                              category = c;
                              error = null;
                            });
                          },
                  ),
              ],
            ),

            const SizedBox(height: 14),

            TextField(
              controller: descriptionController,
              enabled: !sending,
              minLines: 4,
              maxLines: 8,
              maxLength: Report.maxDescriptionLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Beschreibung",
                hintText: "Was ist falsch bzw. was ist passiert?",
                alignLabelWithHint: true,
              ),
              onChanged: (_) {
                if (error != null) {
                  setState(() {
                    error = null;
                  });
                }
              },
            ),

            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Wird mitgesendet",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      "Bereich: ${reportContext.module.title}",
                      if (contextText.isNotEmpty) contextText,
                      "Version: ${AppInfo.version} · ${Report.platform}",
                    ].join("\n"),
                    style: secondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Name, E-Mail-Adresse und Konto werden nicht "
                    "übertragen. Bitte schreibe auch keine persönlichen "
                    "Daten in die Beschreibung.",
                    style: secondary,
                  ),
                ],
              ),
            ),

            if (error != null)
              Padding(
                key: _errorKey,
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error!, style: TextStyle(color: context.colors.error)),

                    if (failedReport != null)
                      TextButton.icon(
                        icon: Icon(
                          copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 18,
                        ),
                        label: Text(
                          copied ? "Kopiert" : "Meldung als Text kopieren",
                        ),
                        onPressed: () => _copy(failedReport!),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: sending ? null : () => Navigator.pop(context, false),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: sending ? null : _submit,
          child: sending
              ? const ButtonProgressIndicator()
              : const Text("Senden"),
        ),
      ],
    );
  }
}
