import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../info/app_info.dart';
import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_text.dart';
import '../../models/bible/bible_translation.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reader_settings.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/bible/pericope_headings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bible/bible_chapter_view.dart';
import '../../widgets/info_report.dart';
import 'bible_navigation_screen.dart';
import 'bible_search_screen.dart';
import 'bible_translation_sheet.dart';

/// Der Bibel-Reader: ein Kapitel der gewählten Ausgabe mit Navigation,
/// Suche und Übersetzungsauswahl.
///
/// Mit [passages] öffnet er eine Stelle hervorgehoben – so ruft ihn das
/// Perikopenquiz auf. Gehören mehrere Stellen zusammen, sind alle über die
/// Leiste am oberen Rand erreichbar. Ohne [passages] setzt er an der zuletzt
/// gelesenen Stelle fort.
class BibleReaderScreen extends StatefulWidget {
  final List<BiblePassage> passages;

  /// Überschrift zu [passages], z. B. der Titel der Perikope.
  final String? passageTitle;

  // Nur für Tests ersetzbar; standardmäßig die ausgelieferten Texte.
  final BibleRepository? repository;

  /// Perikopenüberschriften für den Text. Das Quiz übergibt die seiner
  /// Perikopenliste; ohne Angabe gilt die ausgelieferte Liste.
  final PericopeHeadings? pericopeHeadings;

  const BibleReaderScreen({
    super.key,
    this.passages = const [],
    this.passageTitle,
    this.repository,
    this.pericopeHeadings,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  late final BibleRepository repository =
      widget.repository ?? BibleRepository.instance;

  BibleReaderSettings settings = BibleReaderSettings();

  List<BibleTranslation> translations = const [];

  BibleTranslation? translation;

  // Aufgeschlagene Stelle. [bookId] ist das gewünschte Buch, auch wenn die
  // Ausgabe es nicht enthält ([chapterData] ist dann null).
  String bookId = "GEN";
  int chapter = 1;

  BibleChapter? chapterData;

  PericopeHeadings headings = PericopeHeadings.empty;

  // Perikopenüberschriften des aufgeschlagenen Kapitels (Vers → Titel).
  // Wird je Kapitel einmal bestimmt, damit die Darstellung stabil bleibt.
  Map<int, List<String>> chapterHeadings = const {};

  /// Die Perikopenliste kennt Überschriften für dieses Kapitel, die Ausgabe
  /// zählt es aber anders – sie werden nicht gezeigt.
  bool headingsOmitted = false;

  bool loading = true;

  /// Fehler beim Laden der Ausgaben oder des Buchs.
  bool failed = false;

  /// Hervorgehobene Stelle (Perikope oder Suchtreffer).
  BibleReference? highlight;

  int passageIndex = 0;

  // Verhindert, dass eine überholte Ladeanfrage die Anzeige überschreibt.
  int _request = 0;

  final ScrollController _scroll = ScrollController();

  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey<BibleChapterViewState> _chapterKey = GlobalKey();

  bool get _fromPassages => widget.passages.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      settings = await BibleReaderSettings.load();

      translations = await repository.translations();
    } catch (_) {
      translations = const [];
    }

    // Die Überschriften vor dem ersten Kapitel laden, damit sich der Text
    // nach dem Sprung zu einem Vers nicht mehr verschiebt. Ohne sie bleibt
    // der Reader benutzbar.
    try {
      headings = widget.pericopeHeadings ?? await PericopeHeadings.load();
    } catch (_) {
      headings = PericopeHeadings.empty;
    }

    if (!mounted) return;

    if (translations.isEmpty) {
      setState(() {
        loading = false;
        failed = true;
      });

      return;
    }

    translation = translations.firstWhere(
      (t) => t.id == settings.translationId,
      orElse: () => translations.first,
    );

    if (_fromPassages) {
      await _openPassage(0);
    } else {
      final position = settings.position;

      await _open(
        position ?? BibleReference.chapter(translation!.books.first.id, 1),
        scrollToVerse: position?.verse,
      );
    }
  }

  /// Die Kennung von [id] in der gewählten Ausgabe, `null` wenn sie das
  /// Buch nicht enthält.
  String? _resolve(String id) {
    final t = translation;

    return t == null ? null : BibleBooks.resolveIn(t, id);
  }

  BibleBookInfo? get _book {
    final id = _resolve(bookId);

    return id == null ? null : translation!.book(id);
  }

  Future<void> _openPassage(int index) {
    final passage = widget.passages[index];

    passageIndex = index;

    return _open(
      passage.reference,
      highlighted: passage.reference,
      scrollToVerse: passage.reference.verse,
    );
  }

  /// Schlägt [target] auf. Gibt es das Kapitel in der Ausgabe nicht, wird
  /// das nächstliegende gezeigt; fehlt das Buch, erscheint ein Hinweis.
  Future<void> _open(
    BibleReference target, {
    BibleReference? highlighted,
    int? scrollToVerse,
  }) async {
    final request = ++_request;

    final t = translation!;

    final resolved = BibleBooks.resolveIn(t, target.bookId);

    setState(() {
      bookId = target.bookId;
      highlight = highlighted;
      loading = resolved != null;
      failed = false;

      if (resolved == null) {
        chapter = target.chapter;
        chapterData = null;
      }
    });

    if (resolved == null) return;

    final count = t.book(resolved)!.chapterCount;

    final number = target.chapter.clamp(1, count);

    BibleChapter? data;

    try {
      data = await repository.chapter(t, resolved, number);
    } catch (_) {
      data = null;
    }

    if (!mounted || request != _request) return;

    final pericopes = headings.forChapter(
      translation: t,
      translations: translations,
      bookId: resolved,
      chapter: number,
    );

    setState(() {
      chapter = number;
      chapterData = data;
      chapterHeadings = pericopes;
      headingsOmitted =
          pericopes.isEmpty &&
          data != null &&
          !data.isEmpty &&
          headings.hasAny(resolved, number);
      loading = false;
      failed = data == null;
    });

    _savePosition(scrollToVerse);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _request || !_scroll.hasClients) return;

      // Ein anderer Vers als der gewünschte steht nur oben, wenn das
      // gewünschte Kapitel selbst aufgeschlagen ist.
      final offset = scrollToVerse == null || number != target.chapter
          ? null
          : _offsetOfVerse(scrollToVerse);

      _scroll.jumpTo(
        offset == null
            ? 0
            : (offset - 12).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  double? _offsetOfVerse(int verse) {
    final content = _contentKey.currentContext?.findRenderObject();

    if (content == null) return null;

    return _chapterKey.currentState?.offsetOfVerse(verse, content);
  }

  /// Merkt die Stelle für das nächste Öffnen – nur beim freien Lesen, nicht
  /// wenn das Quiz eine Perikope zeigt.
  void _savePosition(int? verse) {
    if (_fromPassages || chapterData == null) return;

    settings.savePosition(
      BibleReference(bookId: bookId, chapter: chapter, verse: verse),
    );
  }

  int? _topVerse() {
    final content = _contentKey.currentContext?.findRenderObject();

    if (content == null || !_scroll.hasClients) return null;

    return _chapterKey.currentState?.verseAt(_scroll.offset, content);
  }

  /// Vorheriges bzw. nächstes Kapitel, auch über Buchgrenzen hinweg.
  BibleReference? _neighbour(int step) {
    final t = translation;
    final book = _book;

    if (t == null || book == null) return null;

    final next = chapter + step;

    if (next >= 1 && next <= book.chapterCount) {
      return BibleReference.chapter(book.id, next);
    }

    final index = t.books.indexOf(book) + step;

    if (index < 0 || index >= t.books.length) return null;

    final other = t.books[index];

    return BibleReference.chapter(other.id, step > 0 ? 1 : other.chapterCount);
  }

  void _step(int step) {
    final target = _neighbour(step);

    if (target != null) _open(target, highlighted: highlight);
  }

  Future<void> _chooseTranslation() async {
    final current = translation;

    if (current == null) return;

    final chosen = await showBibleTranslationSheet(
      context,
      translations: translations,
      selected: current,
      containsBook: (t) => BibleBooks.resolveIn(t, bookId) != null,
    );

    if (chosen == null || chosen.id == current.id || !mounted) return;

    final verse = _topVerse();

    translation = chosen;

    settings.saveTranslation(chosen.id);

    await _open(
      BibleReference(bookId: bookId, chapter: chapter, verse: verse),
      highlighted: highlight,
      scrollToVerse: highlight?.firstVerseIn(chapter) ?? verse,
    );
  }

  Future<void> _chooseReference() async {
    final t = translation;

    if (t == null) return;

    final reference = await Navigator.push<BibleReference>(
      context,
      MaterialPageRoute(
        builder: (_) => BibleNavigationScreen(
          translation: t,
          currentBookId: _resolve(bookId),
          currentChapter: chapter,
        ),
      ),
    );

    if (reference != null && mounted) _openChosen(reference);
  }

  Future<void> _search() async {
    final t = translation;

    if (t == null) return;

    final reference = await Navigator.push<BibleReference>(
      context,
      MaterialPageRoute(
        builder: (_) => BibleSearchScreen(
          repository: repository,
          translation: t,
          currentBookId: _resolve(bookId),
        ),
      ),
    );

    if (reference != null && mounted) _openChosen(reference);
  }

  /// Öffnet eine gewählte oder gefundene Stelle; Versangaben werden
  /// hervorgehoben.
  void _openChosen(BibleReference reference) {
    _open(
      reference,
      highlighted: reference.hasVerses ? reference : null,
      scrollToVerse: reference.verse,
    );
  }

  void _showTextSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Darstellung",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text("Schriftgröße"),
                Row(
                  children: [
                    const Text("A", style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Slider(
                        value: settings.fontScale,
                        min: BibleReaderSettings.minFontScale,
                        max: BibleReaderSettings.maxFontScale,
                        divisions: 9,
                        onChanged: (value) {
                          setSheetState(() {});
                          setState(() => settings.fontScale = value);
                        },
                        onChangeEnd: settings.saveFontScale,
                      ),
                    ),
                    const Text("A", style: TextStyle(fontSize: 24)),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Anmerkungen der Ausgabe anzeigen"),
                  subtitle: const Text(
                    "Fußnoten bzw. textkritischer Apparat, soweit die "
                    "Ausgabe sie enthält",
                  ),
                  value: settings.showNotes,
                  onChanged: (value) {
                    setSheetState(() {});
                    setState(() => settings.showNotes = value);
                    settings.saveShowNotes(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isHighlighted(int verse) {
    final h = highlight;

    if (h == null || _resolve(h.bookId) != _resolve(bookId)) return false;

    // Eine Kapitelangabe hebt nichts hervor: Das Kapitel ist die Stelle.
    return h.hasVerses && h.containsVerse(chapter, verse);
  }

  /// Hinweis, wenn sich eine Stelle in der gewählten Ausgabe nicht sicher
  /// zuordnen lässt. Die App rechnet Zählungen nicht ineinander um.
  String? _passageHint(BiblePassage passage) {
    final t = translation;

    if (t == null) return null;

    final reference = passage.reference;

    final resolved = BibleBooks.resolveIn(t, reference.bookId);

    if (resolved == null) return null;

    final book = t.book(resolved)!;

    final missing =
        reference.endChapter > book.chapterCount ||
        (reference.verse ?? 1) > book.verseCount(reference.chapter) ||
        (reference.endVerse ?? 1) > book.verseCount(reference.endChapter);

    if (missing) {
      return "Diese Ausgabe zählt Kapitel und Verse hier anders als die "
          "Perikopenliste; die Stelle lässt sich nicht genau zuordnen.";
    }

    if (t.versification == BibleVersification.german ||
        BibleBooks.byId(reference.bookId)?.testament ==
            BibleTestament.newTestament) {
      return null;
    }

    final psalms = reference.bookId == "PSA";

    switch (t.versification) {
      case BibleVersification.lxx:
      case BibleVersification.vulgate:
        return psalms
            ? "Diese Ausgabe zählt die Psalmen anders (meist eine Nummer "
                  "niedriger). Die Angabe folgt der Zählung der "
                  "Perikopenliste und trifft hier nicht sicher zu."
            : "Die Angabe folgt der Zählung der Perikopenliste. Diese "
                  "Ausgabe zählt Kapitel und Verse im Alten Testament "
                  "teilweise anders; die Hervorhebung kann abweichen.";
      case BibleVersification.english:
        return "Die Angabe folgt der Zählung der Perikopenliste. Diese "
            "Ausgabe zählt im Alten Testament teilweise anders (z. B. "
            "Psalmüberschriften); die Hervorhebung kann um einzelne Verse "
            "abweichen.";
      case BibleVersification.german:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = translation;
    final book = _book;

    final title = t == null
        ? "Bibel"
        : "${book?.name ?? BibleBooks.nameOf(bookId)} $chapter";

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: t == null
                ? const Text("Bibel")
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey("bible-reference-button"),
                      onPressed: _chooseReference,
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
            actions: [
              if (t != null) ...[
                TextButton(
                  key: const ValueKey("bible-translation-button"),
                  onPressed: _chooseTranslation,
                  child: Text(t.shortName),
                ),
                IconButton(
                  key: const ValueKey("bible-search-button"),
                  icon: const Icon(Icons.search),
                  tooltip: "Suchen",
                  onPressed: _search,
                ),
              ],
              // Selten gebrauchte Aktionen im Menü, damit die Leiste auch auf
              // schmalen Displays Platz hat.
              PopupMenuButton<String>(
                key: const ValueKey("bible-menu"),
                tooltip: "Mehr",
                onSelected: (value) {
                  switch (value) {
                    case "display":
                      _showTextSettings();
                    case "edition":
                      if (t != null) showBibleTranslationInfo(context, t);
                    case "info":
                      showModuleInfo(
                        context,
                        AppModules.bible,
                        reportDetails: () => {
                          if (t != null) "Ausgabe": "${t.name} (${t.id})",
                          "Stelle": "$bookId $chapter",
                        },
                      );
                  }
                },
                itemBuilder: (_) => [
                  if (t != null) ...const [
                    PopupMenuItem(value: "display", child: Text("Darstellung")),
                    PopupMenuItem(
                      value: "edition",
                      child: Text("Über diese Ausgabe"),
                    ),
                  ],
                  const PopupMenuItem(
                    value: "info",
                    child: Text("Informationen und Fehler melden"),
                  ),
                ],
              ),
            ],
          ),

          body: Column(
            children: [
              if (_fromPassages && t != null) _passageBar(t),

              Expanded(child: _body(t, book)),
            ],
          ),

          bottomNavigationBar: t == null || book == null
              ? null
              : _chapterBar(book),
        ),
      ),
    );
  }

  Widget _body(BibleTranslation? t, BibleBookInfo? book) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (t == null) {
      return const _Message(
        icon: Icons.error_outline,
        text: "Es sind keine Bibeltexte verfügbar.",
      );
    }

    if (book == null) return _missingBook(t);

    final data = chapterData;

    if (failed || data == null) {
      return const _Message(
        icon: Icons.error_outline,
        text: "Der Text dieses Kapitels konnte nicht geladen werden.",
      );
    }

    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        _savePosition(_topVerse());

        return false;
      },
      child: SelectionArea(
        child: SingleChildScrollView(
          controller: _scroll,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                key: _contentKey,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "Dieses Kapitel enthält in dieser Ausgabe keinen "
                          "Text.",
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      )
                    else
                      BibleChapterView(
                        key: _chapterKey,
                        chapter: data,
                        isHighlighted: _isHighlighted,
                        // Die Hervorhebung dient der Orientierung; beim
                        // Weiterlesen lässt sie sich wegtippen. Die Stelle
                        // in der Leiste des Quiz hebt sie erneut hervor.
                        onHighlightTap: () => setState(() => highlight = null),
                        fontScale: settings.fontScale,
                        showNotes: settings.showNotes,
                        pericopeHeadings: chapterHeadings,
                      ),

                    const SizedBox(height: 20),

                    if (chapterHeadings.isNotEmpty || headingsOmitted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          headingsOmitted
                              ? "Diese Ausgabe zählt Kapitel oder Verse hier "
                                    "anders als der Perikopen-Datensatz von "
                                    "theologie.app. Die Perikopenüberschriften "
                                    "werden deshalb in diesem Kapitel nicht "
                                    "angezeigt."
                              : PericopeHeadings.explanation,
                          key: const ValueKey("bible-pericope-note"),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ),

                    // Quellenangabe beim Text, wie es die Lizenzen der
                    // Ausgaben verlangen.
                    Text(
                      "${t.name} · ${t.copyright} · ${t.licenseType}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Das Buch fehlt in der gewählten Ausgabe: Ausgaben anbieten, die es
  /// enthalten.
  Widget _missingBook(BibleTranslation t) {
    final others = translations
        .where((o) => BibleBooks.resolveIn(o, bookId) != null)
        .toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                "„${BibleBooks.nameOf(bookId)}“ ist in der Ausgabe "
                "„${t.name}“ nicht enthalten.",
                textAlign: TextAlign.center,
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  "In diesen Ausgaben lesen:",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final other in others)
                      OutlinedButton(
                        onPressed: () {
                          translation = other;

                          settings.saveTranslation(other.id);

                          _open(
                            BibleReference.chapter(bookId, chapter),
                            highlighted: highlight,
                            scrollToVerse: highlight?.firstVerseIn(chapter),
                          );
                        },
                        child: Text(other.shortName),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Leiste zur Perikope: Titel, alle zugehörigen Stellen und ggf. ein
  /// Hinweis zur Zählung.
  Widget _passageBar(BibleTranslation t) {
    final colors = context.colors;

    final passage = widget.passages[passageIndex];

    final hint = _passageHint(passage);

    return Material(
      color: colors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.passageTitle != null)
                  Text(
                    widget.passageTitle!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),

                const SizedBox(height: 6),

                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (int i = 0; i < widget.passages.length; i++)
                      ChoiceChip(
                        key: ValueKey("bible-passage-$i"),
                        label: Text(widget.passages[i].label),
                        // Ausgewählt, solange die Stelle aufgeschlagen
                        // und hervorgehoben ist; erneutes Antippen blendet
                        // die Hervorhebung aus, sonst führt es zur Stelle.
                        selected:
                            i == passageIndex &&
                            highlight != null &&
                            _resolve(highlight!.bookId) == _resolve(bookId) &&
                            chapter >= highlight!.chapter &&
                            chapter <= highlight!.endChapter,
                        onSelected: (selected) {
                          if (selected) {
                            _openPassage(i);
                          } else {
                            setState(() => highlight = null);
                          }
                        },
                      ),
                  ],
                ),

                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      hint,
                      key: const ValueKey("bible-passage-hint"),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chapterBar(BibleBookInfo book) {
    final previous = _neighbour(-1);
    final next = _neighbour(1);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey("bible-previous-chapter"),
              icon: const Icon(Icons.chevron_left),
              tooltip: "Vorheriges Kapitel",
              onPressed: previous == null ? null : () => _step(-1),
            ),
            Expanded(
              child: Text(
                "Kapitel $chapter von ${book.chapterCount}",
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            IconButton(
              key: const ValueKey("bible-next-chapter"),
              icon: const Icon(Icons.chevron_right),
              tooltip: "Nächstes Kapitel",
              onPressed: next == null ? null : () => _step(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.colors.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
