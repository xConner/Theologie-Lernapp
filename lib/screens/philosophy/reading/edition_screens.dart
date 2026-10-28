import 'package:flutter/material.dart';

import '../../../models/philosophy/reading_text.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/content_page.dart';
import 'reader_screen.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';

typedef JumpTo = void Function(String sentenceId);

/// Sprung zum Text: im Leser über [onJump], sonst öffnet sich der Leser.
JumpTo _jumpOr(BuildContext context, ReadingSession session, JumpTo? onJump) =>
    onJump ?? (id) => openReader(context, session, sentenceId: id);

/// Öffnet einen Abschnitt der Einleitung.
void openIntroSection(
  BuildContext context,
  ReadingSession session,
  String id, {
  JumpTo? onJump,
}) {
  final section = session.text?.front.section(id);
  if (section == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Einleitung $id ist in dieser Ausgabe nicht enthalten.")),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          IntroSectionScreen(session: session, section: section, onJump: onJump),
    ),
  );
}

/// Zeigt eine Anmerkung (z. B. nach „Anm. zu 184a21“) in einem Dialog.
Future<void> showEditionNote(
  BuildContext context,
  ReadingSession session,
  EditionNote note, {
  JumpTo? onJump,
}) {
  final text = session.text!;
  final jump = _jumpOr(context, session, onJump);
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SingleChildScrollView(
        child: EditionNoteCard(
          note,
          onIntro: (s) {
            Navigator.pop(dialogContext);
            openIntroSection(context, session, s, onJump: onJump);
          },
          onNoteRef: (r) {
            final target = text.editorNoteAt(r);
            if (target == null) return;
            Navigator.pop(dialogContext);
            showEditionNote(context, session, target, onJump: onJump);
          },
          onJump: note.range == null
              ? null
              : () {
                  final s = text.sentenceAt(note.range!.from);
                  if (s == null) return;
                  Navigator.pop(dialogContext);
                  jump(s.id);
                },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Schließen"),
        ),
      ],
    ),
  );
}

/// Ausgabe: Vorwort, Einleitung, Glossar, Siglen, Literatur – nur, was die
/// Ausgabe enthält.
class EditionFrontView extends StatelessWidget {
  final ReadingSession session;

  const EditionFrontView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final text = session.text!;
    final front = text.front;
    final edition = text.edition;
    return ContentBody(
      children: [
        Text(edition.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          edition.rights,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        if (front.preface.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: const Text("Vorwort"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentPage(
                  title: "Vorwort",
                  children: [
                    for (final p in front.preface)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelectableText(p, style: germanStyle(context)),
                      ),
                    if (front.prefacePages != null)
                      Text(
                        "S. ${front.prefacePages}",
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (front.intro.isNotEmpty) ...[
          const ContentSectionTitle("Einleitung"),
          for (final s in front.intro)
            ListTile(
              dense: s.depth > 1,
              contentPadding: EdgeInsets.only(left: 16.0 * (s.depth - 1)),
              title: Text("${s.id} ${s.title}"),
              trailing: s.page == null ? null : RefLabel("S. ${s.page}"),
              onTap: () => openIntroSection(context, session, s.id),
            ),
        ],
        if (front.glossary.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate_rounded),
            title: const Text("Glossar"),
            subtitle: Text("${front.glossary.length} Einträge"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GlossaryScreen(session: session),
              ),
            ),
          ),
        if (front.sigla.isNotEmpty)
          _ListPageTile(title: "Siglen und Abkürzungen", lines: front.sigla),
        if (front.bibliography.isNotEmpty)
          _ListPageTile(title: "Literatur", lines: front.bibliography),
        if (front.isEmpty)
          const EmptyHint(
            "Diese Ausgabe enthält nur den Text – ohne Vorwort, Einleitung "
            "oder Glossar.",
          ),
      ],
    );
  }
}

class _ListPageTile extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _ListPageTile({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.list_alt_rounded),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentPage(
          title: title,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(l),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Abschnitt der Einleitung mit Fußnoten und Verweisen auf den Text.
class IntroSectionScreen extends StatelessWidget {
  final ReadingSession session;
  final IntroSection section;
  final JumpTo? onJump;

  const IntroSectionScreen({
    super.key,
    required this.session,
    required this.section,
    this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final text = session.text!;
    final front = text.front;
    final index = front.intro.indexWhere((s) => s.id == section.id);
    final prev = index > 0 ? front.intro[index - 1] : null;
    final next = index >= 0 && index < front.intro.length - 1
        ? front.intro[index + 1]
        : null;
    final cited = [
      for (final c in front.citations)
        if (c.section == section.id) c,
    ];
    final jump = _jumpOr(context, session, onJump);

    void open(IntroSection s) => Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            IntroSectionScreen(session: session, section: s, onJump: onJump),
      ),
    );

    return ContentPage(
      title: "Einleitung ${section.id}",
      children: [
        Text(section.title, style: Theme.of(context).textTheme.titleLarge),
        if (section.page != null) RefLabel("S. ${section.page}"),
        const SizedBox(height: 12),
        for (final b in section.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText.rich(
              TextSpan(
                children: [
                  if (b.number != null)
                    TextSpan(
                      text: "(${b.number}) ",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: b.text),
                ],
              ),
              style: germanStyle(context),
            ),
          ),
        if (cited.isNotEmpty) ...[
          const DetailHeading("ZITIERTE STELLEN DER PHYSIK"),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final c in cited)
                ActionChip(
                  label: Text(c.range.label),
                  onPressed: () {
                    final s = text.sentenceAt(c.range.from);
                    if (s != null) jump(s.id);
                  },
                ),
            ],
          ),
        ],
        if (section.footnotes.isNotEmpty) ...[
          const DetailHeading("FUSSNOTEN"),
          for (final f in section.footnotes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(
                "[${f.number}] ${f.text}",
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (prev != null)
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: Text(prev.id, overflow: TextOverflow.ellipsis),
                  onPressed: () => open(prev),
                ),
              ),
            if (next != null)
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextButton.icon(
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(next.id, overflow: TextOverflow.ellipsis),
                    onPressed: () => open(next),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Glossar der Ausgabe mit Filter.
class GlossaryScreen extends StatefulWidget {
  final ReadingSession session;

  const GlossaryScreen({super.key, required this.session});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _filter = "";
  bool _technicalOnly = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final q = _filter.toLowerCase();
    final entries = [
      for (final g in session.text!.front.glossary)
        if ((!_technicalOnly || g.technical) &&
            (q.isEmpty ||
                g.term.toLowerCase().contains(q) ||
                g.renderings.any((r) => r.toLowerCase().contains(q))))
          g,
    ];
    return ContentPage(
      title: "Glossar",
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Begriff oder Übersetzung",
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _filter = v),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _technicalOnly,
          title: const Text("Nur Fachausdrücke (t. t.)"),
          onChanged: (v) => setState(() => _technicalOnly = v ?? false),
        ),
        for (final g in entries)
          GlossaryCard(
            g,
            onIntro: (s) => openIntroSection(context, session, s),
            onNoteRef: (r) {
              final note = session.text!.editorNoteAt(r);
              if (note != null) showEditionNote(context, session, note);
            },
          ),
        if (entries.isEmpty) const EmptyHint("Kein Eintrag gefunden."),
      ],
    );
  }
}

/// Kommentar: Anmerkungen, Textkritik und Fußnoten eines Buchs mit Sprung
/// zum Text.
class CommentaryView extends StatefulWidget {
  final ReadingSession session;

  const CommentaryView({super.key, required this.session});

  @override
  State<CommentaryView> createState() => _CommentaryViewState();
}

class _CommentaryViewState extends State<CommentaryView> {
  int _book = 1;
  EditionNoteKind? _kind;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final text = session.text!;
    final books = [for (final b in text.books) if (b.notes.isNotEmpty) b];
    if (books.isEmpty) {
      return const EmptyHint("Diese Ausgabe hat keine Anmerkungen.");
    }
    final book = books.firstWhere((b) => b.number == _book, orElse: () => books.first);
    final kinds = {for (final n in book.notes) n.kind};
    final notes = [
      for (final n in book.notes)
        if (_kind == null || n.kind == _kind) n,
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: notes.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final b in books)
                ChoiceChip(
                  label: Text("Buch ${session.work!.bookLabel(b.number)}"),
                  selected: b.number == book.number,
                  onSelected: (_) => setState(() => _book = b.number),
                ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Alle"),
                selected: _kind == null,
                onSelected: (_) => setState(() => _kind = null),
              ),
              for (final k in EditionNoteKind.values)
                if (kinds.contains(k))
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
            ],
          );
        }
        final n = notes[i - 1];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentPage.maxWidth),
            child: EditionNoteCard(
              n,
              onIntro: (s) => openIntroSection(context, session, s),
              onNoteRef: (r) {
                final target = text.editorNoteAt(r);
                if (target != null) showEditionNote(context, session, target);
              },
              onJump: () {
                final s = n.range != null
                    ? text.sentenceAt(n.range!.from)
                    : (n.unitId == null ? null : text.unit(n.unitId!)?.greek.first);
                if (s != null) openReader(context, session, sentenceId: s.id);
              },
            ),
          ),
        );
      },
    );
  }
}

/// Rahmen für die Zeile „Quelle“ unter eigenen Ergänzungen.
class OwnAdditionNote extends StatelessWidget {
  final String text;

  const OwnAdditionNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Text(text, style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary)),
  );
}
