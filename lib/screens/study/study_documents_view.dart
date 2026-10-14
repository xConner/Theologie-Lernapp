import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/study/study_documents.dart';
import '../../services/timetable/course_labels.dart';
import '../../theme/app_theme.dart';

/// Sammlung offizieller Studienunterlagen der Theologischen Fakultät, nach
/// Themen gruppiert, mit Studiengang, Stand und Link zur Originalquelle.
class StudyDocumentsView extends StatefulWidget {
  final AssetBundle? bundle;

  const StudyDocumentsView({super.key, this.bundle});

  @override
  State<StudyDocumentsView> createState() => _StudyDocumentsViewState();
}

class _StudyDocumentsViewState extends State<StudyDocumentsView>
    with AutomaticKeepAliveClientMixin {
  late Future<StudyDocuments> _documents = StudyDocuments.load(widget.bundle);
  String? _program;
  bool _includeOlder = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StudyDocuments>(
      future: _documents,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Die Übersicht konnte nicht geladen werden."),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _documents = StudyDocuments.load(widget.bundle),
                    ),
                    child: const Text("Erneut versuchen"),
                  ),
                ],
              ),
            ),
          );
        }
        final docs = snapshot.data;
        if (docs == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = docs.filtered(
          program: _program,
          includeOlder: _includeOlder,
        );
        final mainPrograms = {
          for (final e in docs.programs.entries)
            if (const ["dka", "lehramt", "ma-re"].contains(e.key))
              e.key: e.value,
        };
        final colors = context.colors;

        return ListView(
          key: const ValueKey("documents-list"),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              "Offizielle Unterlagen der Theologischen Fakultät und der CAU "
              "Kiel. Die App verlinkt nur auf die Originalquellen; maßgeblich "
              "ist immer das Dokument dort.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Links und Stände geprüft am ${formatDate(docs.checkedAt)}.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const ValueKey("program-all"),
                  label: const Text("Alle Studiengänge"),
                  selected: _program == null,
                  onSelected: (_) => setState(() => _program = null),
                ),
                for (final e in mainPrograms.entries)
                  ChoiceChip(
                    key: ValueKey("program-${e.key}"),
                    label: Text(_shortProgram(e.key, e.value)),
                    tooltip: e.value,
                    selected: _program == e.key,
                    onSelected: (_) => setState(() => _program = e.key),
                  ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey("include-older"),
              contentPadding: EdgeInsets.zero,
              title: const Text("Ältere Fassungen anzeigen"),
              subtitle: const Text(
                "z. B. für Studierende nach einer früheren Prüfungsordnung",
              ),
              value: _includeOlder,
              onChanged: (v) => setState(() => _includeOlder = v),
            ),
            for (final g in groups)
              if (g.documents.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      g.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                for (final d in g.documents)
                  _DocumentCard(document: d, programs: docs.programs),
              ],
            if (groups.every((g) => g.documents.isEmpty))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Für diese Auswahl gibt es keine Dokumente.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _shortProgram(String key, String name) => switch (key) {
    "dka" => "Pfarramt / Diplom (DKA)",
    "lehramt" => "Lehramt Ev. Religion",
    "ma-re" => "Master Religion und Ethik",
    _ => name,
  };
}

class _DocumentCard extends StatelessWidget {
  final StudyDocument document;
  final Map<String, String> programs;

  const _DocumentCard({required this.document, required this.programs});

  @override
  Widget build(BuildContext context) {
    final d = document;
    final colors = context.colors;
    final statusColor = switch (d.status) {
      DocumentStatus.current => colors.success,
      DocumentStatus.older => colors.textSecondary,
      DocumentStatus.unclear => colors.error,
    };
    final programNames = [for (final p in d.programs) programs[p] ?? p];
    return Card(
      key: ValueKey("document-${d.id}"),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    d.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: "Status: ${d.status.label}",
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      d.status.label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: statusColor),
                    ),
                  ),
                ),
              ],
            ),
            if (d.officialTitle != null && d.officialTitle != d.title)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  d.officialTitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(d.description),
            const SizedBox(height: 6),
            Text(
              "Gilt für: ${programNames.join("; ")}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (d.version != null)
              Text(
                "Fassung: ${d.version}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (d.validity.isNotEmpty)
              Text(
                d.validity,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            Text(
              d.publisher,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      launchUrl(d.url, mode: LaunchMode.externalApplication),
                  icon: Icon(
                    d.isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.open_in_new_rounded,
                  ),
                  label: Text(d.isPdf ? "PDF öffnen" : "Seite öffnen"),
                ),
                if (d.sourcePage != null && d.sourcePage != d.url)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      d.sourcePage!,
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: const Text("Fundstelle"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
