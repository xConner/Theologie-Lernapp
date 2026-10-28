import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../models/philosophy/reading_text.dart';
import '../../../services/philosophy/reading_repository.dart';
import '../../../services/philosophy/reading_user_data.dart';
import '../../../theme/app_theme.dart';
import 'reading_search_screen.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';
import 'sentence_detail.dart';

/// Öffnet den Leser an einem Satz bzw. Kapitel (sonst an der zuletzt
/// gelesenen Stelle).
Future<void> openReader(
  BuildContext context,
  ReadingSession session, {
  String? sentenceId,
  String? chapterId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ReaderScreen(
      session: session,
      sentenceId: sentenceId,
      chapterId: chapterId,
    ),
  ),
);

/// Leser eines Werks: ein Kapitel je Ansicht, vier Darstellungen, Detail
/// zum Satz als Seitenleiste (breit) bzw. Blatt (schmal).
class ReaderScreen extends StatefulWidget {
  final ReadingSession session;
  final String? sentenceId;
  final String? chapterId;

  const ReaderScreen({
    super.key,
    required this.session,
    this.sentenceId,
    this.chapterId,
  });

  /// Ab dieser Breite steht das Satzdetail neben dem Text.
  static const double sidePanelWidth = 1000;

  @override
  State<ReaderScreen> createState() => ReaderScreenState();
}

@visibleForTesting
class ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewport = GlobalKey();
  final Map<String, GlobalKey> _unitKeys = {};
  final Map<String, TapGestureRecognizer> _recognizers = {};

  /// Abschnitte, deren Übersetzung abweichend vom Modus ein- bzw.
  /// ausgeblendet ist.
  final Set<String> _toggled = {};
  Set<String> _textCritical = {};

  late ReadingChapter _chapter;
  String? _selected;

  /// Abschnitt oben im Bild – bleibt beim Wechsel des Modus stehen.
  String? _anchorUnit;
  bool _sheetOpen = false;

  ReadingSession get session => widget.session;
  ReadingText get text => session.text!;

  ReadingChapter get chapter => _chapter;
  String? get selectedSentence => _selected;
  String? get anchorUnit => _anchorUnit;

  @override
  void initState() {
    super.initState();
    final start = widget.sentenceId ?? session.user.position;
    final fromSentence = start == null ? null : text.resolveSentence(start);
    _chapter =
        (widget.chapterId == null ? null : text.chapter(widget.chapterId!)) ??
        (fromSentence == null ? null : text.chapterOfSentence(fromSentence.id)) ??
        text.chapters.first;
    _prepareChapter();
    if (fromSentence != null && text.chapterOfSentence(fromSentence.id) == _chapter) {
      _anchorUnit = text.unitOfSentence(fromSentence.id)?.id;
      if (widget.sentenceId != null) {
        _selected = fromSentence.id;
        session.setPosition(fromSentence.id);
      }
      _scrollToUnitAfterBuild(_anchorUnit!);
    }
    _scroll.addListener(_onScroll);
    session.addListener(_onSession);
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    session.flushPosition();
    _scroll.dispose();
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    // Nach einem Wechsel der Ausgabe kann das Kapitel ein anderes Objekt sein.
    final same = text.chapter(_chapter.id);
    if (same != null && !identical(same, _chapter)) {
      _chapter = same;
      _prepareChapter();
    }
    setState(() {});
  }

  void _prepareChapter() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
    _unitKeys.clear();
    _toggled.clear();
    _textCritical = {
      for (final s in _chapter.sentences)
        if (text.hasTextCritical(s)) s.id,
    };
  }

  GlobalKey _keyOf(String unitId) => _unitKeys[unitId] ??= GlobalKey();

  TapGestureRecognizer _tap(String sentenceId) =>
      _recognizers[sentenceId] ??= TapGestureRecognizer()
        ..onTap = () => select(sentenceId);

  void _scrollToUnitAfterBuild(String unitId, {double alignment = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _unitKeys[unitId]?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(ctx, alignment: alignment);
    });
  }

  /// Ermittelt den obersten sichtbaren Abschnitt und merkt die Stelle.
  void _onScroll() {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    for (final unit in _chapter.units) {
      final ctx = _unitKeys[unit.id]?.currentContext;
      final unitBox = ctx?.findRenderObject() as RenderBox?;
      if (unitBox == null || !unitBox.attached) continue;
      final y = unitBox.localToGlobal(Offset.zero).dy;
      if (y + unitBox.size.height > top + 8) {
        if (_anchorUnit != unit.id) {
          _anchorUnit = unit.id;
          session.setPosition(unit.greek.first.id);
        }
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Springt zu einem Satz (auch in ein anderes Kapitel) und wählt ihn aus.
  void jumpTo(String sentenceId, {bool select = true}) {
    final sentence = text.resolveSentence(sentenceId);
    if (sentence == null) return;
    final target = text.chapterOfSentence(sentence.id)!;
    setState(() {
      if (target != _chapter) {
        _chapter = target;
        _prepareChapter();
      }
      if (select) _selected = sentence.id;
      _anchorUnit = text.unitOfSentence(sentence.id)!.id;
    });
    session.setPosition(sentence.id);
    _scrollToUnitAfterBuild(_anchorUnit!, alignment: 0.2);
  }

  void openChapter(ReadingChapter chapter) {
    setState(() {
      _chapter = chapter;
      _selected = null;
      _anchorUnit = chapter.units.first.id;
      _prepareChapter();
    });
    session.setPosition(chapter.units.first.greek.first.id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> setMode(ReadingMode mode) async {
    final anchor = _anchorUnit;
    _toggled.clear();
    await session.setMode(mode);
    if (anchor != null) _scrollToUnitAfterBuild(anchor);
  }

  void select(String sentenceId) {
    setState(() => _selected = sentenceId);
    session.setPosition(sentenceId);
    final wide = MediaQuery.sizeOf(context).width >= ReaderScreen.sidePanelWidth;
    if (!wide && !_sheetOpen) _openSheet();
  }

  Future<void> _openSheet() async {
    _sheetOpen = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (sheetContext, controller) => StatefulBuilder(
          builder: (sheetContext, setSheet) => ListenableBuilder(
            listenable: session,
            builder: (_, _) => PrimaryScrollController(
              controller: controller,
              child: SentenceDetail(
                session: session,
                sentenceId: _selected ?? _chapter.units.first.greek.first.id,
                onJump: (id) {
                  jumpTo(id);
                  setSheet(() {});
                },
                onClose: () => Navigator.pop(sheetContext),
              ),
            ),
          ),
        ),
      ),
    );
    _sheetOpen = false;
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _pickChapter() async {
    final picked = await showModalBottomSheet<ReadingChapter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            for (final book in text.books) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  "Buch ${session.work!.bookLabel(book.number)}"
                  "${book.title == null ? "" : " – ${book.title}"}",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final c in book.chapters)
                ListTile(
                  dense: true,
                  selected: c == _chapter,
                  leading: Icon(
                    session.user.readChapters.contains(c.id)
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                  ),
                  title: Text(
                    "Kapitel ${c.number}${c.title == null ? "" : ": ${c.title}"}",
                  ),
                  trailing: RefLabel(c.range.label),
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ],
        ),
      ),
    );
    if (picked != null) openChapter(picked);
  }

  Future<void> _search() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ReadingSearchScreen(session: session)),
    );
    if (id != null) jumpTo(id);
  }

  // ---------------------------------------------------------------------------
  // Darstellung
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= ReaderScreen.sidePanelWidth;
    final index = text.indexOfChapter(_chapter);
    final work = session.work!;
    final mode = session.mode;

    final reader = SingleChildScrollView(
      key: _viewport,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: mode == ReadingMode.sideBySide ? 1100 : 760,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChapterHeader(
                title:
                    "Buch ${work.bookLabel(_chapter.book)}, Kapitel ${_chapter.number}",
                subtitle: _chapter.title,
                range: _chapter.range.label,
                edition: text.edition.short,
              ),
              for (final unit in _chapter.units) _unit(unit, mode),
              const SizedBox(height: 16),
              CheckboxListTile(
                key: const ValueKey("chapter-read"),
                contentPadding: EdgeInsets.zero,
                value: session.user.readChapters.contains(_chapter.id),
                title: const Text("Kapitel gelesen"),
                onChanged: (v) => session.setChapterRead(_chapter, v ?? false),
              ),
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text("Voriges Kapitel"),
                        onPressed: () => openChapter(text.chapters[index - 1]),
                      ),
                    ),
                  if (index > 0 && index < text.chapters.length - 1)
                    const SizedBox(width: 12),
                  if (index < text.chapters.length - 1)
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey("next-chapter"),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text("Nächstes Kapitel"),
                        onPressed: () => openChapter(text.chapters[index + 1]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          key: const ValueKey("chapter-picker"),
          onTap: _pickChapter,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  "${work.bookLabel(_chapter.book)} ${_chapter.number}",
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Suchen",
            icon: const Icon(Icons.search_rounded),
            onPressed: _search,
          ),
          PopupMenuButton<Object>(
            key: const ValueKey("reading-mode-menu"),
            tooltip: "Darstellung",
            icon: const Icon(Icons.view_agenda_outlined),
            onSelected: (v) {
              if (v is ReadingMode) setMode(v);
              if (v is double) session.setTextScale(v);
            },
            itemBuilder: (_) => [
              for (final m in ReadingMode.values)
                CheckedPopupMenuItem(
                  key: ValueKey("mode-${m.name}"),
                  value: m,
                  checked: m == mode,
                  enabled: m == ReadingMode.greek || text.hasGerman,
                  child: Text(m.label),
                ),
              const PopupMenuDivider(),
              for (final (label, scale) in const [
                ("Schrift klein", 0.9),
                ("Schrift normal", 1.0),
                ("Schrift groß", 1.2),
                ("Schrift sehr groß", 1.4),
              ])
                CheckedPopupMenuItem(
                  value: scale,
                  checked: (session.user.textScale - scale).abs() < 0.01,
                  child: Text(label),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: wide && _selected != null
            ? Row(
                children: [
                  Expanded(child: reader),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 440,
                    child: SentenceDetail(
                      key: const ValueKey("sentence-detail-panel"),
                      session: session,
                      sentenceId: _selected!,
                      onJump: jumpTo,
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
                ],
              )
            : reader,
      ),
    );
  }

  bool _showGerman(ReadingUnit unit, ReadingMode mode) {
    if (!unit.hasGerman) return false;
    final byMode = mode != ReadingMode.greek;
    return _toggled.contains(unit.id) ? !byMode : byMode;
  }

  Widget _unit(ReadingUnit unit, ReadingMode mode) {
    final scale = session.user.textScale;
    final showGerman = _showGerman(unit, mode);
    final showGreek = mode != ReadingMode.german;
    final bookmarked = unit.greek.any(
      (s) => session.user.marks["s:${s.id}"]?.bookmark == true,
    );
    final greek = _greekParagraph(unit, scale);
    final german = _germanParagraph(unit, scale);

    Widget body;
    if (!showGreek) {
      body = german;
    } else if (!showGerman) {
      body = greek;
    } else if (mode == ReadingMode.sideBySide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: greek),
          const SizedBox(width: 20),
          Expanded(child: german),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          greek,
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: context.colors.divider, width: 2),
              ),
            ),
            child: german,
          ),
        ],
      );
    }

    return Container(
      key: _keyOf(unit.id),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RefLabel(unit.range.label),
              if (unit.hasGerman && !unit.exact && (showGerman || !showGreek))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message:
                        "Übersetzung und Original sind hier nur ungefähr "
                        "zugeordnet.",
                    child: Text(
                      "≈",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              if (bookmarked)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.bookmark_rounded,
                    size: 14,
                    color: context.colors.accent,
                  ),
                ),
              const Spacer(),
              if (unit.hasGerman && showGreek && mode != ReadingMode.sideBySide)
                SizedBox(
                  height: 28,
                  child: TextButton(
                    key: ValueKey("toggle-${unit.id}"),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => setState(() {
                      _toggled.contains(unit.id)
                          ? _toggled.remove(unit.id)
                          : _toggled.add(unit.id);
                    }),
                    child: Text(showGerman ? "Übersetzung aus" : "Übersetzung"),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          body,
        ],
      ),
    );
  }

  Widget _greekParagraph(ReadingUnit unit, double scale) {
    final base = greekStyle(context, scale: scale);
    final highlight = context.colors.primary.withValues(alpha: 0.14);
    return Text.rich(
      TextSpan(
        children: [
          for (final s in unit.greek) ...[
            TextSpan(
              text: s.text,
              recognizer: _tap(s.id),
              style: TextStyle(
                backgroundColor: s.id == _selected ? highlight : null,
              ),
              semanticsLabel: s.text,
            ),
            if (_textCritical.contains(s.id))
              TextSpan(
                text: "°",
                style: TextStyle(
                  fontSize: base.fontSize! * 0.7,
                  color: context.colors.accent,
                ),
              ),
            if ((session.user.marks["s:${s.id}"]?.note ?? "").isNotEmpty)
              TextSpan(
                text: " ✎",
                style: TextStyle(
                  fontSize: base.fontSize! * 0.6,
                  color: context.colors.textSecondary,
                ),
              ),
            const TextSpan(text: " "),
          ],
        ],
      ),
      key: ValueKey("greek-${unit.id}"),
      style: base,
    );
  }

  Widget _germanParagraph(ReadingUnit unit, double scale) {
    final color = session.mode == ReadingMode.german
        ? null
        : context.colors.textPrimary.withValues(alpha: 0.85);
    return InkWell(
      key: ValueKey("german-${unit.id}"),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      onTap: () => select(unit.greek.first.id),
      child: Text.rich(
        TextSpan(
          children: [
            for (final (i, d) in unit.german.indexed) ...[
              if (i > 0)
                TextSpan(
                  text: " ${d.ref.line} ",
                  style: TextStyle(
                    fontSize: 10.5 * scale,
                    color: context.colors.textSecondary,
                  ),
                ),
              TextSpan(text: d.text),
            ],
          ],
        ),
        style: germanStyle(context, scale: scale, color: color),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String range;
  final String edition;

  const _ChapterHeader({
    required this.title,
    required this.subtitle,
    required this.range,
    required this.edition,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!, style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 2),
        Text(
          "$range · $edition",
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
      ],
    ),
  );
}
