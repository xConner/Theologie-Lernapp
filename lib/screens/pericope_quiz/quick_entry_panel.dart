import 'package:flutter/material.dart';

import '../../quiz/bible_structure.dart';
import '../../quiz/pericope_reference.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_selection.dart';

enum _Stage { book, chapter, verse, endChapter, endVerse }

/// Schnelleingabe des Perikopenquiz: stellt eine Bibelstelle durch Antippen
/// von Buch, Kapitel und ggf. Versen zusammen.
///
/// Das Panel hält keine eigene Antwort. Es zeigt [value] an und meldet jede
/// Auswahl über [onChanged]; angeboten wird nur, was laut [books] und
/// [structure] möglich ist.
class QuickEntryPanel extends StatefulWidget {
  /// Auswählbare Bücher in Anzeigereihenfolge.
  final List<String> books;

  /// Zuletzt verwendete Bücher, neuestes zuerst.
  final List<String> recentBooks;

  final BibleStructure structure;

  /// Genauigkeit der aktuellen Frage: "chapter" oder versgenau.
  final String precision;

  final PericopeReference value;

  final ValueChanged<PericopeReference> onChanged;

  /// Welche Eingabe gerade bearbeitet wird, z.B. „Stelle 2 von 3“.
  final String? label;

  const QuickEntryPanel({
    super.key,
    required this.books,
    this.recentBooks = const [],
    required this.structure,
    required this.precision,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  State<QuickEntryPanel> createState() => _QuickEntryPanelState();
}

class _QuickEntryPanelState extends State<QuickEntryPanel> {
  // Vom Nutzer gewählter Schritt; null = der nächste offene Schritt.
  _Stage? _override;

  // Endkapitel einer kapitelübergreifenden Versangabe, solange der Endvers
  // noch fehlt.
  int? _pendingEndChapter;

  PericopeReference? _emitted;

  bool get _chapterPrecision => widget.precision == "chapter";

  PericopeReference get _value => widget.value;

  @override
  void didUpdateWidget(QuickEntryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Von außen geändert (anderes Feld, getippt, neue Frage, Einstellungen):
    // wieder beim nächsten offenen Schritt beginnen.
    final changedOutside =
        widget.value != oldWidget.value && widget.value != _emitted;

    if (changedOutside || widget.precision != oldWidget.precision) {
      _override = null;
      _pendingEndChapter = null;
    }
  }

  _Stage get _stage {
    final v = _value;

    final _Stage natural;

    if (v.book == null) {
      natural = _Stage.book;
    } else if (v.startChapter == null || _chapterPrecision) {
      natural = _Stage.chapter;
    } else {
      natural = _Stage.verse;
    }

    switch (_override) {
      case null:
        return natural;
      case _Stage.book:
        return _Stage.book;
      case _Stage.chapter:
        return v.book == null ? natural : _Stage.chapter;
      case _Stage.verse:
        return natural;
      case _Stage.endChapter:
        return v.startVerse == null ? natural : _Stage.endChapter;
      case _Stage.endVerse:
        return v.startVerse == null || _pendingEndChapter == null
            ? natural
            : _Stage.endVerse;
    }
  }

  void _emit(PericopeReference reference) {
    _emitted = reference;

    setState(() {
      _override = null;
      _pendingEndChapter = null;
    });

    widget.onChanged(reference);
  }

  void _goTo(_Stage? stage) {
    setState(() {
      _override = stage;
      _pendingEndChapter = null;
    });
  }

  void _selectBook(String book) {
    if (book == _value.book) {
      _goTo(null);
      return;
    }

    // Buchwechsel verwirft Kapitel und Verse. Bei Büchern mit nur einem
    // Kapitel ist dieses gleich mit ausgewählt.
    _emit(
      PericopeReference(
        book: book,
        startChapter: widget.structure.chapterCount(book) == 1 ? 1 : null,
      ),
    );
  }

  void _selectChapter(int chapter) {
    final v = _value;
    final start = v.startChapter;

    if (!_chapterPrecision) {
      if (chapter == start) {
        _goTo(null);
      } else {
        // Kapitelwechsel verwirft die Verse.
        _emit(PericopeReference(book: v.book, startChapter: chapter));
      }

      return;
    }

    final hasRange = v.endChapter != null && v.endChapter != start;

    if (start == null || hasRange || chapter < start) {
      _emit(PericopeReference(book: v.book, startChapter: chapter));
    } else if (chapter == start) {
      _emit(PericopeReference(book: v.book));
    } else {
      _emit(
        PericopeReference(
          book: v.book,
          startChapter: start,
          endChapter: chapter,
        ),
      );
    }
  }

  bool get _crossesChapter {
    final v = _value;
    return v.endChapter != null && v.endChapter != v.startChapter;
  }

  void _selectVerse(int verse) {
    final v = _value;
    final start = v.startVerse;

    final hasRange =
        _crossesChapter || (v.endVerse != null && v.endVerse != start);

    if (start == null || hasRange || verse < start) {
      _emit(
        PericopeReference(
          book: v.book,
          startChapter: v.startChapter,
          startVerse: verse,
        ),
      );
    } else if (verse == start) {
      _emit(PericopeReference(book: v.book, startChapter: v.startChapter));
    } else {
      _emit(
        PericopeReference(
          book: v.book,
          startChapter: v.startChapter,
          startVerse: start,
          endVerse: verse,
        ),
      );
    }
  }

  void _selectEndChapter(int chapter) {
    setState(() {
      _pendingEndChapter = chapter;
      _override = _Stage.endVerse;
    });
  }

  void _selectEndVerse(int verse) {
    final v = _value;

    _emit(
      PericopeReference(
        book: v.book,
        startChapter: v.startChapter,
        startVerse: v.startVerse,
        endChapter: _pendingEndChapter,
        endVerse: verse,
      ),
    );
  }

  String get _chapterLabel {
    final v = _value;

    if (v.startChapter == null) return "Kapitel";

    if (_chapterPrecision && _crossesChapter) {
      return "Kap. ${v.startChapter}–${v.endChapter}";
    }

    return "Kap. ${v.startChapter}";
  }

  String get _verseLabel {
    final v = _value;

    if (v.startVerse == null) return "Verse";

    if (_crossesChapter) {
      return "V. ${v.startVerse} – ${v.endChapter},${v.endVerse}";
    }

    if (v.endVerse != null && v.endVerse != v.startVerse) {
      return "V. ${v.startVerse}–${v.endVerse}";
    }

    return "V. ${v.startVerse}";
  }

  String _prompt(_Stage stage) {
    final v = _value;

    switch (stage) {
      case _Stage.book:
        return "Buch wählen";
      case _Stage.chapter:
        if (!_chapterPrecision || v.startChapter == null) {
          return "Kapitel wählen";
        }
        return "Bereich: letztes Kapitel antippen";
      case _Stage.verse:
        if (v.startVerse == null) {
          return "Vers wählen";
        }
        return "Bereich: letzten Vers antippen";
      case _Stage.endChapter:
        return "Endkapitel wählen";
      case _Stage.endVerse:
        return "Letzten Vers in Kapitel $_pendingEndChapter wählen";
    }
  }

  Widget _header(_Stage stage) {
    final v = _value;
    final label = widget.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [
                  SelectionChip(
                    key: const ValueKey("quick-step-book"),
                    label: v.book ?? "Buch",
                    selected: stage == _Stage.book,
                    showCheckmark: false,
                    onSelected: (_) => _goTo(_Stage.book),
                  ),
                  SelectionChip(
                    key: const ValueKey("quick-step-chapter"),
                    label: _chapterLabel,
                    selected: stage == _Stage.chapter,
                    showCheckmark: false,
                    onSelected: v.book == null
                        ? null
                        : (_) => _goTo(_Stage.chapter),
                  ),
                  if (!_chapterPrecision)
                    SelectionChip(
                      key: const ValueKey("quick-step-verse"),
                      label: _verseLabel,
                      selected: stage.index >= _Stage.verse.index,
                      showCheckmark: false,
                      onSelected: v.startChapter == null
                          ? null
                          : (_) => _goTo(null),
                    ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey("quick-reset"),
              tooltip: "Zurücksetzen",
              icon: const Icon(Icons.backspace_outlined),
              onPressed: v.book == null
                  ? null
                  : () => _emit(PericopeReference.empty),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
          child: Text(
            label == null ? _prompt(stage) : "$label · ${_prompt(stage)}",
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _numbers({
    required String keyPrefix,
    required int from,
    required int to,
    required bool Function(int) isSelected,
    required ValueChanged<int> onTap,
    required String emptyText,
  }) {
    if (to < from) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          emptyText,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      children: [
        for (var n = from; n <= to; n++)
          SelectionChip(
            key: ValueKey("$keyPrefix-$n"),
            label: "$n",
            selected: isSelected(n),
            showCheckmark: false,
            onSelected: (_) => onTap(n),
          ),
      ],
    );
  }

  Widget _bookChips(Iterable<String> books, String keyPrefix) {
    return Wrap(
      spacing: 6,
      children: [
        for (final book in books)
          SelectionChip(
            key: ValueKey("$keyPrefix-$book"),
            label: book,
            selected: book == _value.book,
            showCheckmark: false,
            onSelected: (_) => _selectBook(book),
          ),
      ],
    );
  }

  Widget _options(_Stage stage) {
    final v = _value;
    final structure = widget.structure;

    const noVerses =
        "Für dieses Kapitel sind keine Verse hinterlegt – bitte oben "
        "eintippen.";

    switch (stage) {
      case _Stage.book:
        final recent = widget.recentBooks.where(widget.books.contains).toList();

        // Bei wenigen Büchern bringt die Abkürzung nichts.
        if (recent.isEmpty || widget.books.length <= 12) {
          return _bookChips(widget.books, "quick-book");
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bookChips(recent, "quick-recent"),
            const Divider(height: 12),
            _bookChips(widget.books, "quick-book"),
          ],
        );

      case _Stage.chapter:
        final start = v.startChapter;
        final end = _chapterPrecision ? v.endChapter ?? start : start;

        return _numbers(
          keyPrefix: "quick-chapter",
          from: 1,
          to: structure.chapterCount(v.book!),
          isSelected: (n) => start != null && n >= start && n <= end!,
          onTap: _selectChapter,
          emptyText: "Für dieses Buch sind keine Kapitel hinterlegt.",
        );

      case _Stage.verse:
        final start = v.startVerse;
        final count = structure.verseCount(v.book!, v.startChapter!);
        final end = _crossesChapter ? count : v.endVerse ?? start;

        final canCross =
            start != null && v.startChapter! < structure.chapterCount(v.book!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _numbers(
              keyPrefix: "quick-verse",
              from: 1,
              to: count,
              isSelected: (n) => start != null && n >= start && n <= end!,
              onTap: _selectVerse,
              emptyText: noVerses,
            ),
            if (canCross)
              TextButton.icon(
                key: const ValueKey("quick-end-chapter"),
                icon: const Icon(Icons.arrow_forward),
                label: const Text("Endet in späterem Kapitel"),
                onPressed: () => _goTo(_Stage.endChapter),
              ),
          ],
        );

      case _Stage.endChapter:
        return _numbers(
          keyPrefix: "quick-chapter",
          from: v.startChapter! + 1,
          to: structure.chapterCount(v.book!),
          isSelected: (n) => n == v.endChapter,
          onTap: _selectEndChapter,
          emptyText: "Es gibt kein späteres Kapitel.",
        );

      case _Stage.endVerse:
        final chapter = _pendingEndChapter!;

        return _numbers(
          keyPrefix: "quick-verse",
          from: 1,
          to: structure.verseCount(v.book!, chapter),
          isSelected: (n) => v.endChapter == chapter && n <= v.endVerse!,
          onTap: _selectEndVerse,
          emptyText: noVerses,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;

    final header = _header(stage);
    final options = _options(stage);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppColors.divider),
      ),
      // Eigenes Material, damit Hover/Ink der Chips nicht vom farbigen
      // Container verdeckt werden.
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Bei sehr wenig Platz (kleines Display mit Tastatur) scrollt
            // das ganze Panel, sonst bleiben die Schritte oben stehen.
            if (constraints.maxHeight < 200) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [header, options],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Flexible(
                  child: SingleChildScrollView(
                    key: ValueKey(stage),
                    child: options,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
