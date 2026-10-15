import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../services/timetable/plan_schedule.dart';
import '../../models/timetable/course_catalog.dart';
import '../../services/timetable/timetable_export.dart';
import '../../services/timetable/timetable_pdf.dart';

/// Druck und PDF-Export des Stundenplans: ein kompakter Dialog mit den
/// wichtigsten Einstellungen und einer Vorschau des fertigen PDFs.
///
/// Das PDF entsteht lokal aus demselben aufgelösten Plan wie die
/// Wochenansicht ([plan]); der Export liest nur und speichert nichts.
/// Drucken öffnet den Druckdialog des Systems (im Web den des Browsers),
/// „Teilen / Speichern“ den Teilen- bzw. Speichern-Dialog (im Web einen
/// Download).
class TimetableExportScreen extends StatefulWidget {
  final List<PlanCourse> plan;
  final CatalogSemester? semester;
  final TimetableExportOptions initialOptions;

  /// Vorschau im Dialog (Rasterung über das Plugin). Im Web nie: dort
  /// bräuchte sie pdf.js von einem fremden Server; stattdessen zeigt der
  /// Browser beim Drucken seine eigene Vorschau. In Tests abschaltbar.
  final bool showPreview;

  /// Für Tests austauschbar.
  final Future<TimetablePdfFonts> Function()? loadFonts;
  final DateTime Function()? now;

  const TimetableExportScreen({
    super.key,
    required this.plan,
    required this.semester,
    this.initialOptions = const TimetableExportOptions(),
    this.showPreview = true,
    this.loadFonts,
    this.now,
  });

  @override
  State<TimetableExportScreen> createState() => _TimetableExportScreenState();
}

class _TimetableExportScreenState extends State<TimetableExportScreen> {
  late TimetableExportOptions options = widget.initialOptions;
  late final Future<TimetablePdfFonts> fonts =
      (widget.loadFonts ?? TimetablePdfFonts.load)();
  late final TextEditingController titleField = TextEditingController(
    text: options.title,
  );
  late final TextEditingController subtitleField = TextEditingController(
    text: options.subtitle,
  );
  Timer? _textDebounce;
  bool _busy = false;

  @override
  void dispose() {
    _textDebounce?.cancel();
    titleField.dispose();
    subtitleField.dispose();
    super.dispose();
  }

  TimetableExport get export => buildTimetableExport(
    plan: widget.plan,
    options: options,
    semester: widget.semester,
    now: widget.now?.call(),
  );

  Future<Uint8List> _pdf() async => buildTimetablePdf(export, await fonts);

  void _set(TimetableExportOptions next) => setState(() => options = next);

  void _textChanged() {
    _textDebounce?.cancel();
    _textDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _set(
        options.copyWith(title: titleField.text, subtitle: subtitleField.text),
      );
    });
  }

  /// Texteingaben sofort übernehmen (vor Druck/Teilen).
  void _flushText() {
    if (_textDebounce?.isActive ?? false) {
      _textDebounce!.cancel();
      options = options.copyWith(
        title: titleField.text,
        subtitle: subtitleField.text,
      );
    }
  }

  Future<void> _run(
    Future<void> Function(Uint8List bytes, String name) action,
  ) async {
    if (_busy) return;
    _flushText();
    setState(() => _busy = true);
    try {
      final current = export;
      final bytes = await buildTimetablePdf(current, await fonts);
      await action(bytes, exportFileName(current));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Das PDF konnte nicht erstellt oder weitergegeben werden.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() => _run(
    (bytes, name) => Printing.layoutPdf(
      name: name,
      format: exportPageFormat(options),
      onLayout: (_) async => bytes,
    ),
  );

  Future<void> _share() =>
      _run((bytes, name) => Printing.sharePdf(bytes: bytes, filename: name));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final settings = _Settings(
      options: options,
      titleField: titleField,
      subtitleField: subtitleField,
      defaultTitle: buildTimetableExport(
        plan: const [],
        options: const TimetableExportOptions(),
        semester: widget.semester,
      ).title,
      onChanged: _set,
      onTextChanged: _textChanged,
    );
    final summary = _Summary(export: export);
    final inAppPreview = widget.showPreview && !kIsWeb;
    final preview = inAppPreview
        ? PdfPreview(
            key: const ValueKey("export-preview"),
            build: (_) => _pdf(),
            initialPageFormat: exportPageFormat(options),
            useActions: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: exportFileName(export),
            loadingWidget: const CircularProgressIndicator(
              semanticsLabel: "Vorschau wird erstellt",
            ),
            onError: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Die Vorschau ist hier nicht verfügbar. Drucken und "
                  "Teilen funktionieren trotzdem.",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stundenplan drucken"),
        actions: [
          IconButton(
            key: const ValueKey("export-share"),
            tooltip: kIsWeb
                ? "Als PDF herunterladen"
                : "Als PDF teilen oder speichern",
            icon: Icon(
              kIsWeb ? Icons.download_rounded : Icons.ios_share_rounded,
            ),
            onPressed: _busy ? null : _share,
          ),
          IconButton(
            key: const ValueKey("export-print"),
            tooltip: "Drucken",
            icon: const Icon(Icons.print_rounded),
            onPressed: _busy ? null : _print,
          ),
        ],
      ),
      body: !inAppPreview
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                summary,
                const SizedBox(height: 12),
                settings,
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey("export-print-button"),
                      onPressed: _busy ? null : _print,
                      icon: const Icon(Icons.print_rounded),
                      label: Text(kIsWeb ? "Druckvorschau öffnen" : "Drucken"),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey("export-share-button"),
                      onPressed: _busy ? null : _share,
                      icon: Icon(
                        kIsWeb
                            ? Icons.download_rounded
                            : Icons.ios_share_rounded,
                      ),
                      label: Text(
                        kIsWeb ? "PDF herunterladen" : "PDF teilen / speichern",
                      ),
                    ),
                  ],
                ),
              ],
            )
          : wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [summary, const SizedBox(height: 12), settings],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: preview),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpansionTile(
                  key: const ValueKey("export-settings"),
                  title: const Text("Einstellungen"),
                  subtitle: Text(_optionsLine(options)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: SingleChildScrollView(child: settings),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: summary,
                ),
                const Divider(height: 16),
                Expanded(child: preview),
              ],
            ),
    );
  }
}

String _optionsLine(TimetableExportOptions o) =>
    ["A4 ${o.orientation.label}", o.detail.label, o.colors.label].join(" · ");

/// Kurze Inhaltsangabe über der Vorschau (auch für Hinweise bei leerem Plan).
class _Summary extends StatelessWidget {
  final TimetableExport export;

  const _Summary({required this.export});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (export.isEmpty) {
      return Text(
        "Für diese Auswahl sind keine Veranstaltungen im Plan. Das PDF "
        "enthält dann nur einen Hinweis.",
        key: const ValueKey("export-summary"),
        style: style,
      );
    }
    final parts = [
      "${export.courses.length} "
          "${export.courses.length == 1 ? "Veranstaltung" : "Veranstaltungen"}",
      if (export.slots.isNotEmpty)
        "${export.slots.length} wöchentliche "
            "${export.slots.length == 1 ? "Termin" : "Termine"}",
      if (export.specials.isNotEmpty)
        "${export.specials.length} Block- und Sondertermine",
      if (export.conflicts.isNotEmpty)
        "${export.conflicts.length} "
            "${export.conflicts.length == 1 ? "Überschneidung" : "Überschneidungen"}",
    ];
    return Text(
      parts.join(" · "),
      key: const ValueKey("export-summary"),
      style: style,
    );
  }
}

class _Settings extends StatelessWidget {
  final TimetableExportOptions options;
  final TextEditingController titleField;
  final TextEditingController subtitleField;
  final String defaultTitle;
  final ValueChanged<TimetableExportOptions> onChanged;
  final VoidCallback onTextChanged;

  const _Settings({
    required this.options,
    required this.titleField,
    required this.subtitleField,
    required this.defaultTitle,
    required this.onChanged,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelLarge;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: label),
    );
    Widget segments<T extends Enum>(
      String key,
      List<T> values,
      T selected,
      String Function(T) labelOf,
      ValueChanged<T> onSelected,
    ) => SegmentedButton<T>(
      key: ValueKey(key),
      showSelectedIcon: false,
      segments: [
        for (final v in values)
          ButtonSegment(
            value: v,
            label: Text(labelOf(v), key: ValueKey("$key-${v.name}")),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onSelected(s.first),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading("Inhalt"),
        DropdownButtonFormField<ExportContent>(
          key: const ValueKey("export-content"),
          initialValue: options.content,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final c in ExportContent.values)
              DropdownMenuItem(value: c, child: Text(c.label)),
          ],
          onChanged: (c) {
            if (c != null) onChanged(options.copyWith(content: c));
          },
        ),
        heading("Seite"),
        segments(
          "export-orientation",
          ExportOrientation.values,
          options.orientation,
          (o) => o.label,
          (o) => onChanged(options.copyWith(orientation: o)),
        ),
        heading("Darstellung"),
        segments(
          "export-detail",
          ExportDetail.values,
          options.detail,
          (d) => d.label,
          (d) => onChanged(options.copyWith(detail: d)),
        ),
        const SizedBox(height: 8),
        segments(
          "export-colors",
          ExportColors.values,
          options.colors,
          (c) => c == ExportColors.color ? "Farbig" : c.label,
          (c) => onChanged(options.copyWith(colors: c)),
        ),
        heading("Beschriftung"),
        TextField(
          key: const ValueKey("export-title"),
          controller: titleField,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: "Titel",
            hintText: defaultTitle,
            border: const OutlineInputBorder(),
            isDense: true,
            counterText: "",
          ),
          onChanged: (_) => onTextChanged(),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey("export-subtitle"),
          controller: subtitleField,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: "Zusatzzeile (optional)",
            hintText: "z. B. Studiengang oder Planname",
            border: OutlineInputBorder(),
            isDense: true,
            counterText: "",
          ),
          onChanged: (_) => onTextChanged(),
        ),
        SwitchListTile(
          key: const ValueKey("export-date"),
          contentPadding: EdgeInsets.zero,
          title: const Text("Exportdatum zeigen"),
          value: options.showExportDate,
          onChanged: (v) => onChanged(options.copyWith(showExportDate: v)),
        ),
        SwitchListTile(
          key: const ValueKey("export-legend"),
          contentPadding: EdgeInsets.zero,
          title: const Text("Legende zeigen"),
          value: options.showLegend,
          onChanged: (v) => onChanged(options.copyWith(showLegend: v)),
        ),
        Text(
          "Das PDF wird auf diesem Gerät erzeugt; dein Plan wird dabei "
          "nicht verändert.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
