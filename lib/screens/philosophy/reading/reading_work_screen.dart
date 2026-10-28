import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/philosophy/reading_work.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/text_file.dart';
import '../../../widgets/content_page.dart';
import 'edition_screens.dart';
import 'my_passages_view.dart';
import 'reader_screen.dart';
import 'reading_search_screen.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';
import 'review_view.dart';

/// Startseite eines Werks im Lesebereich (z. B. Aristoteles, Physik).
/// Reiter erscheinen nur, wenn die gewählte Ausgabe dafür Inhalt hat.
class ReadingWorkScreen extends StatefulWidget {
  final String? uid;
  final String workId;

  /// Für Tests: vorbereitete Sitzung.
  final ReadingSession? session;

  const ReadingWorkScreen({
    super.key,
    required this.uid,
    required this.workId,
    this.session,
  });

  @override
  State<ReadingWorkScreen> createState() => _ReadingWorkScreenState();
}

class _ReadingWorkScreenState extends State<ReadingWorkScreen> {
  late final ReadingSession _session =
      widget.session ?? ReadingSession(uid: widget.uid, workId: widget.workId);
  List<SeminarSession> _seminar = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_session.text == null) await _session.load();
    final work = _session.work;
    if (work != null) {
      try {
        final seminar = await _session.repository.seminar(work);
        if (mounted) setState(() => _seminar = seminar);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final session = _session;
        if (session.loading && session.text == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Philosophie")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (session.text == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Philosophie")),
            body: EmptyHint("Der Text ließ sich nicht laden.\n${session.error ?? ""}"),
          );
        }
        final text = session.text!;
        final tabs = <(String, Widget)>[
          ("Übersicht", _Overview(session: session, seminar: _seminar)),
          if (text.allNotes.isNotEmpty) ("Kommentar", CommentaryView(session: session)),
          if (!text.front.isEmpty) ("Ausgabe", EditionFrontView(session: session)),
          if (_seminar.isNotEmpty) ("Seminar", _SeminarView(session: session, sessions: _seminar)),
          ("Meine Stellen", MyPassagesView(session: session)),
          ("Lernen", ReviewView(session: session)),
        ];
        return DefaultTabController(
          key: ValueKey("tabs-${tabs.length}"),
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(session.work!.displayTitle),
              actions: [
                IconButton(
                  tooltip: "Suchen",
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () async {
                    final id = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadingSearchScreen(session: session),
                      ),
                    );
                    if (id != null && context.mounted) {
                      openReader(context, session, sentenceId: id);
                    }
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in tabs) Tab(text: t.$1)],
              ),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  TabBarView(children: [for (final t in tabs) t.$2]),
                  if (session.loading) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  final ReadingSession session;
  final List<SeminarSession> seminar;

  const _Overview({required this.session, required this.seminar});

  @override
  Widget build(BuildContext context) {
    final work = session.work!;
    final text = session.text!;
    final chapters = text.chapters;
    final read = chapters.where((c) => session.user.readChapters.contains(c.id)).length;
    final position = session.user.position == null
        ? null
        : text.resolveSentence(session.user.position!);

    return ContentBody(
      children: [
        Text(work.originalTitle, style: greekStyle(context, scale: 1.1)),
        const SizedBox(height: 8),
        for (final p in work.description)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p),
          ),
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const ValueKey("open-reader"),
          icon: const Icon(Icons.chrome_reader_mode_outlined),
          label: Text(
            position == null
                ? "Lektüre beginnen"
                : "Weiterlesen bei ${position.ref}",
          ),
          onPressed: () => openReader(context, session),
        ),
        const SizedBox(height: 12),
        Text("Gelesen: $read von ${chapters.length} Kapiteln"),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: chapters.isEmpty ? 0 : read / chapters.length,
        ),
        const ContentSectionTitle("Ausgaben"),
        for (final e in work.editions) _EditionTile(session: session, edition: e),
        const ContentSectionTitle("Inhalt"),
        for (final book in text.books) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              "Buch ${work.bookLabel(book.number)}",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final c in book.chapters)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4),
              leading: Icon(
                session.user.readChapters.contains(c.id)
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 18,
                color: session.user.readChapters.contains(c.id)
                    ? context.colors.success
                    : context.colors.textSecondary,
              ),
              title: Text(
                "Kapitel ${c.number}${c.title == null ? "" : ": ${c.title}"}",
              ),
              trailing: RefLabel(c.range.label),
              onTap: () => openReader(context, session, chapterId: c.id),
            ),
        ],
        const ContentSectionTitle("Material"),
        _MaterialStatus(session: session, seminar: seminar),
      ],
    );
  }
}

/// Was vorhanden ist und was noch fehlt – ohne Lücken zu füllen.
class _MaterialStatus extends StatelessWidget {
  final ReadingSession session;
  final List<SeminarSession> seminar;

  const _MaterialStatus({required this.session, required this.seminar});

  @override
  Widget build(BuildContext context) {
    final text = session.text!;
    final rows = <(bool, String)>[
      (true, "Griechischer Text: ${text.edition.short}"),
      (text.hasGerman, "Deutsche Übersetzung"),
      (text.allNotes.isNotEmpty, "Anmerkungen und textkritische Fußnoten"),
      (text.front.intro.isNotEmpty, "Einleitung und Glossar"),
      (seminar.isNotEmpty, "Seminarplan und Sitzungen"),
      (false, "Kommentare und weitere Seminarmaterialien"),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (ok, label) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_rounded : Icons.hourglass_empty_rounded,
                  size: 16,
                  color: ok ? context.colors.success : context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok ? label : "$label – noch nicht vorhanden",
                    style: TextStyle(
                      color: ok ? null : context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!text.hasGerman)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Übersetzung, Anmerkungen und Einleitung kommen mit der privat "
              "importierten Ausgabe (siehe „Ausgaben“).",
              style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _EditionTile extends StatelessWidget {
  final ReadingSession session;
  final ReadingEdition edition;

  const _EditionTile({required this.session, required this.edition});

  Future<void> _import(BuildContext context) async {
    String? raw;
    if (textFilesSupported) {
      raw = await pickTextFile(maxLength: 4000000);
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Ausgabe importieren"),
          content: const Text(
            "Auf dem Handy lässt sich die Lesedatei aus der Zwischenablage "
            "einfügen. Einfacher: einmal in der Web-Version mit demselben "
            "Konto importieren – dann lädt die App die Ausgabe aus dem Konto.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Abbrechen"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Aus Zwischenablage"),
            ),
          ],
        ),
      );
      if (ok == true) raw = (await Clipboard.getData("text/plain"))?.text;
    }
    if (raw == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final where = await session.importEdition(edition, raw);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            where.account
                ? "Importiert und im eigenen Konto gespeichert."
                : where.device
                ? "Importiert und auf diesem Gerät gespeichert."
                : "Importiert – nur für diese Sitzung (zu wenig Speicher).",
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Import fehlgeschlagen: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = session.edition?.id == edition.id;
    final available =
        edition.kind == EditionKind.bundled ||
        session.importedEditions.contains(edition.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: current ? context.colors.primary : context.colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  edition.short,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Tag(edition.hasGerman ? "Griechisch–Deutsch" : "Griechisch"),
            ],
          ),
          const SizedBox(height: 4),
          Text(edition.title, style: const TextStyle(fontSize: 13)),
          if (edition.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(edition.note!, style: const TextStyle(fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              edition.rights,
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
          ),
          if (!available && edition.importHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                edition.importHint!,
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (available && !current)
                FilledButton.tonal(
                  key: ValueKey("use-${edition.id}"),
                  onPressed: () => session.switchEdition(edition),
                  child: const Text("Diese Ausgabe lesen"),
                ),
              if (current) const Tag("wird gelesen", icon: Icons.check_rounded),
              if (edition.kind == EditionKind.private && !available)
                OutlinedButton.icon(
                  key: ValueKey("import-${edition.id}"),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text("Lesedatei importieren"),
                  onPressed: () => _import(context),
                ),
              if (edition.kind == EditionKind.private && available)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        content: const Text(
                          "Die importierte Ausgabe aus Konto und Gerät "
                          "entfernen? Notizen und Lesezeichen bleiben.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Abbrechen"),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Entfernen"),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await session.removeEdition(edition);
                  },
                  child: const Text("Entfernen"),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeminarView extends StatelessWidget {
  final ReadingSession session;
  final List<SeminarSession> sessions;

  const _SeminarView({required this.session, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return ContentBody(
      children: [
        for (final s in sessions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (s.date != null)
                    Text(
                      "${s.date!.day}.${s.date!.month}.${s.date!.year}",
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  if (s.passages.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final p in s.passages)
                          ActionChip(
                            label: Text(p),
                            onPressed: () {
                              final ref = p.split(RegExp(r'[–-]')).first;
                              final sentence = session.text!.resolveSentence(ref);
                              if (sentence != null) {
                                openReader(context, session, sentenceId: sentence.id);
                              }
                            },
                          ),
                      ],
                    ),
                  for (final m in s.materials) Text("• $m"),
                  for (final t in s.tasks) Text("Aufgabe: $t"),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
