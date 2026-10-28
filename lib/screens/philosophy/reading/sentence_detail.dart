import 'package:flutter/material.dart';

import '../../../models/philosophy/reading_text.dart';
import '../../../services/philosophy/greek_word_analyzer.dart';
import '../../../services/philosophy/reading_repository.dart';
import '../../../theme/app_theme.dart';
import 'edition_screens.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';

/// Detail zu einem griechischen Satz: Wortlaut mit antippbaren Wörtern,
/// Übersetzung des Abschnitts, Anmerkungen der Ausgabe, Verweise in die
/// Einleitung, Begriffe, Seminarbezug und eigene Notiz.
class SentenceDetail extends StatefulWidget {
  final ReadingSession session;
  final String sentenceId;

  /// Springt im Leser zu einem anderen Satz.
  final void Function(String sentenceId) onJump;
  final VoidCallback? onClose;

  const SentenceDetail({
    super.key,
    required this.session,
    required this.sentenceId,
    required this.onJump,
    this.onClose,
  });

  @override
  State<SentenceDetail> createState() => _SentenceDetailState();
}

class _SentenceDetailState extends State<SentenceDetail> {
  late TextEditingController _note;
  String? _noteFor;
  List<GlossaryEntry>? _terms;
  String? _termsFor;

  ReadingSession get session => widget.session;
  ReadingText get text => session.text!;

  String get _anchor => "s:${widget.sentenceId}";

  @override
  void initState() {
    super.initState();
    _note = TextEditingController();
    _sync();
  }

  @override
  void didUpdateWidget(SentenceDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_noteFor != widget.sentenceId) {
      _noteFor = widget.sentenceId;
      _note.text = session.user.marks[_anchor]?.note ?? "";
    }
    if (_termsFor != widget.sentenceId) {
      _termsFor = widget.sentenceId;
      _terms = null;
      _loadTerms();
    }
  }

  Future<void> _loadTerms() async {
    final id = widget.sentenceId;
    final sentence = text.sentence(id);
    if (sentence == null) return;
    final analyzer = await session.analyzer();
    final seen = <String>{};
    final terms = <GlossaryEntry>[];
    for (final w in GreekWordAnalyzer.words(sentence.text)) {
      for (final g in analyzer.analyze(w).glossary) {
        if (seen.add(g.id)) terms.add(g);
      }
    }
    if (mounted && _termsFor == id) setState(() => _terms = terms);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _openIntro(String section) =>
      openIntroSection(context, session, section, onJump: widget.onJump);

  void _openNoteRef(BekkerRef ref) {
    final note = text.editorNoteAt(ref);
    if (note == null) return;
    showEditionNote(context, session, note, onJump: widget.onJump);
  }

  Future<void> _saveMark({bool? bookmark}) async {
    final current = session.user.marks[_anchor];
    await session.saveMark(
      _anchor,
      bookmark: bookmark ?? current?.bookmark ?? false,
      note: _note.text,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sentence = text.sentence(widget.sentenceId);
    if (sentence == null) {
      return const Center(child: Text("Stelle nicht gefunden."));
    }
    final unit = text.unitOfSentence(sentence.id)!;
    final chapter = text.chapterOfUnit(unit.id)!;
    final all = chapter.sentences.toList();
    final index = all.indexWhere((s) => s.id == sentence.id);
    final notes = text.notesForSentence(sentence);
    final citations = text.citationsFor(sentence);
    final mark = session.user.marks[_anchor];
    final wordMarks = [
      for (final m in session.user.marksOfSentence(sentence.id))
        if (m.kind == "w") m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${session.work!.title} ${session.work!.bookLabel(chapter.book)} "
                  "${chapter.number}, ${sentence.range.label}",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: "Voriger Satz",
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: index > 0 ? () => widget.onJump(all[index - 1].id) : null,
              ),
              IconButton(
                tooltip: "Nächster Satz",
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: index < all.length - 1
                    ? () => widget.onJump(all[index + 1].id)
                    : null,
              ),
              IconButton(
                tooltip: mark?.bookmark == true
                    ? "Lesezeichen entfernen"
                    : "Lesezeichen setzen",
                icon: Icon(
                  mark?.bookmark == true
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                onPressed: () => _saveMark(bookmark: !(mark?.bookmark ?? false)),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: "Schließen",
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _WordWrap(
                session: session,
                sentence: sentence,
                onJump: widget.onJump,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Wort antippen für Bestimmung und Bedeutung",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              if (unit.hasGerman) ...[
                const DetailHeading("ÜBERSETZUNG"),
                if (!unit.oneToOne || !unit.exact) ApproxHint(unit),
                const SizedBox(height: 4),
                for (final d in unit.german)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "${d.ref}  ",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          TextSpan(text: d.text),
                        ],
                      ),
                      style: germanStyle(context),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Übersetzung: ${text.edition.short}",
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
              for (final kind in EditionNoteKind.values)
                if (notes.any((n) => n.kind == kind)) ...[
                  DetailHeading(switch (kind) {
                    EditionNoteKind.textCritical => "TEXTKRITIK",
                    EditionNoteKind.editor => "ANMERKUNGEN DES HERAUSGEBERS",
                    EditionNoteKind.translator => "FUSSNOTEN ZUR ÜBERSETZUNG",
                  }),
                  for (final n in notes.where((n) => n.kind == kind))
                    EditionNoteCard(
                      n,
                      onIntro: _openIntro,
                      onNoteRef: _openNoteRef,
                    ),
                ],
              if (citations.isNotEmpty) ...[
                const DetailHeading("IN DER EINLEITUNG"),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final c in citations)
                      ActionChip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 15),
                        label: Text(
                          "Einl. ${c.section}"
                          "${text.front.section(c.section) == null ? "" : " – ${text.front.section(c.section)!.title}"}",
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _openIntro(c.section),
                      ),
                  ],
                ),
              ],
              if (_terms != null && _terms!.isNotEmpty) ...[
                const DetailHeading("BEGRIFFE IN DIESEM SATZ"),
                for (final g in _terms!)
                  GlossaryCard(g, onIntro: _openIntro, onNoteRef: _openNoteRef),
              ],
              const DetailHeading("MEINE NOTIZ"),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey("reading-note"),
                controller: _note,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: "Eigene Notiz zu diesem Satz",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text("Notiz speichern"),
                  onPressed: () async {
                    await _saveMark();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notiz gespeichert")),
                    );
                  },
                ),
              ),
              for (final m in wordMarks)
                if (m.note.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sticky_note_2_outlined, size: 18),
                    title: Text(m.word ?? "", style: greekStyle(context, scale: 0.8)),
                    subtitle: Text(m.note),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wörter des Satzes als antippbare Einheiten.
class _WordWrap extends StatelessWidget {
  final ReadingSession session;
  final GreekSentence sentence;
  final void Function(String sentenceId) onJump;

  const _WordWrap({
    required this.session,
    required this.sentence,
    required this.onJump,
  });

  static final RegExp _letter = RegExp(r'[Ͱ-Ͽἀ-῿]');

  /// Wortform ohne anhängende Satzzeichen (Elisionszeichen bleiben).
  static String clean(String word) =>
      word.replaceAll(RegExp(r"[^\p{L}\p{M}’ʼ']", unicode: true), "");

  @override
  Widget build(BuildContext context) {
    final words = GreekWordAnalyzer.words(sentence.text);
    final style = greekStyle(context, scale: session.user.textScale * 1.05);
    final wordAnchors = {
      for (final m in session.user.marksOfSentence(sentence.id))
        if (m.kind == "w") m.anchor,
    };
    return Wrap(
      children: [
        for (var i = 0; i < words.length; i++)
          if (!_letter.hasMatch(words[i]))
            Text("${words[i]} ", style: style)
          else
            InkWell(
              key: ValueKey("word-$i"),
              borderRadius: BorderRadius.circular(4),
              onTap: () => showWordDetail(
                context,
                session,
                sentence: sentence,
                index: i,
                surface: clean(words[i]),
                onJump: onJump,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  "${words[i]} ",
                  style: style.copyWith(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: context.colors.divider,
                    backgroundColor:
                        wordAnchors.any((a) => a.startsWith("w:${sentence.id}:$i:"))
                        ? context.colors.accent.withValues(alpha: 0.15)
                        : null,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Öffnet das Wortdetail (Blatt am unteren Rand).
Future<void> showWordDetail(
  BuildContext context,
  ReadingSession session, {
  required GreekSentence sentence,
  required int index,
  required String surface,
  required void Function(String sentenceId) onJump,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => WordDetail(
        session: session,
        sentence: sentence,
        index: index,
        surface: surface,
        scrollController: controller,
        onJump: (id) {
          Navigator.pop(context);
          onJump(id);
        },
      ),
    ),
  );
}

/// Wortdetail: Form, Umschrift, mögliche Bestimmungen mit Bedeutungen,
/// Glossar der Ausgabe, weitere Vorkommen, Wortliste und Notiz.
class WordDetail extends StatefulWidget {
  final ReadingSession session;
  final GreekSentence sentence;
  final int index;
  final String surface;
  final ScrollController? scrollController;
  final void Function(String sentenceId) onJump;

  const WordDetail({
    super.key,
    required this.session,
    required this.sentence,
    required this.index,
    required this.surface,
    required this.onJump,
    this.scrollController,
  });

  @override
  State<WordDetail> createState() => _WordDetailState();
}

class _WordDetailState extends State<WordDetail> {
  GreekWordAnalyzer? _analyzer;
  WordAnalysis? _analysis;
  List<GreekSentence>? _occurrences;
  final TextEditingController _note = TextEditingController();

  ReadingSession get session => widget.session;

  String get _anchor =>
      "w:${widget.sentence.id}:${widget.index}:${widget.surface}";

  @override
  void initState() {
    super.initState();
    _note.text = session.user.marks[_anchor]?.note ?? "";
    session.analyzer().then((a) {
      if (!mounted) return;
      setState(() {
        _analyzer = a;
        _analysis = a.analyze(widget.surface);
      });
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _findOccurrences() {
    final a = _analysis!;
    setState(() {
      _occurrences = _analyzer!.occurrences(
        session.text!,
        lemma: a.certainLemma,
        form: a.form,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final inList = session.user.words.containsKey(
      analysis?.certainLemma ?? analysis?.form,
    );
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(widget.surface, style: greekStyle(context, scale: 1.4)),
        Text(
          "Umschrift: ${GreekWordAnalyzer.transliterate(widget.surface)}"
          "  ·  ${widget.sentence.range.label}",
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        if (analysis == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          const DetailHeading("BESTIMMUNG"),
          if (!analysis.isAnalyzed)
            Text(
              "Diese Form steht nicht im Formenindex (NT/LXX). Es wird keine "
              "Bestimmung geraten.",
              style: TextStyle(color: context.colors.textSecondary),
            )
          else ...[
            Text(
              analysis.ambiguous
                  ? "Mögliche Bestimmungen – mehrdeutig, im Kontext prüfen."
                  : "Mögliche Bestimmung – nicht für diese Stelle geprüft.",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: context.colors.textSecondary,
              ),
            ),
            for (final c in analysis.candidates)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.lemma, style: greekStyle(context, scale: 0.95)),
                    for (final a in c.analyses)
                      Text("• ${a.describe()}", style: const TextStyle(fontSize: 13.5)),
                    if (c.lexicon != null && c.lexicon!.german.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Bedeutung (allgemein): ${c.lexicon!.german.join("; ")}",
                          style: TextStyle(color: context.colors.primary),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "Quelle: Formenindex aus NT und LXX der App; Bedeutungen aus "
                "dem Lexikon der App, nicht speziell für Aristoteles.",
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
          if (analysis.glossary.isNotEmpty) ...[
            const DetailHeading("GLOSSAR DER AUSGABE"),
            for (final g in analysis.glossary)
              GlossaryCard(
                g,
                onIntro: (s) => openIntroSection(
                  context,
                  session,
                  s,
                  onJump: widget.onJump,
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: Icon(inList ? Icons.check_rounded : Icons.playlist_add),
                label: Text(inList ? "In der Wortliste" : "Zur Wortliste"),
                onPressed: inList
                    ? null
                    : () async {
                        await session.addWord(
                          form: widget.surface,
                          lemma: analysis.certainLemma,
                          sentenceId: widget.sentence.id,
                        );
                        if (mounted) setState(() {});
                      },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.travel_explore_outlined),
                label: Text(
                  analysis.certainLemma != null
                      ? "Vorkommen von ${analysis.certainLemma}"
                      : "Vorkommen dieser Form",
                ),
                onPressed: _findOccurrences,
              ),
            ],
          ),
          if (_occurrences != null) ...[
            DetailHeading("VORKOMMEN (${_occurrences!.length})"),
            if (_occurrences!.isEmpty) const Text("Keine weiteren Vorkommen."),
            for (final s in _occurrences!)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: s.id == widget.sentence.id,
                title: Text(
                  s.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: greekStyle(context, scale: 0.8),
                ),
                leading: RefLabel("${s.ref}"),
                onTap: () => widget.onJump(s.id),
              ),
          ],
          const DetailHeading("NOTIZ ZUM WORT"),
          const SizedBox(height: 4),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: "z. B. eigene Übersetzung an dieser Stelle",
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await session.saveMark(
                  _anchor,
                  bookmark: false,
                  note: _note.text,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Speichern"),
            ),
          ),
        ],
      ],
    );
  }
}

/// Satz eines Treffers auflösen und eine kurze Vorschau liefern.
String sentencePreview(ReadingText text, String sentenceId, {int max = 90}) {
  final s = text.resolveSentence(sentenceId);
  if (s == null) return sentenceId;
  return s.text.length > max ? "${s.text.substring(0, max)}…" : s.text;
}
