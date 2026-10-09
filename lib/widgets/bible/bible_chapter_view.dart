import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/bible/bible_text.dart';
import '../../theme/app_theme.dart';

/// Der Text eines Kapitels als Fließtext in den Absätzen der Ausgabe, mit
/// Versnummern, Zwischenüberschriften und Anmerkungen.
///
/// Der Wortlaut wird unverändert gezeigt. [isHighlighted] bestimmt, welche
/// Verse hinterlegt werden (z. B. eine Perikope aus dem Quiz).
class BibleChapterView extends StatefulWidget {
  final BibleChapter chapter;

  final bool Function(int verse) isHighlighted;

  final double fontScale;

  /// Anmerkungszeichen im Text und Liste der Anmerkungen am Kapitelende.
  final bool showNotes;

  const BibleChapterView({
    super.key,
    required this.chapter,
    required this.isHighlighted,
    this.fontScale = 1,
    this.showNotes = true,
  });

  @override
  State<BibleChapterView> createState() => BibleChapterViewState();
}

/// Ein zusammenhängender Absatz aus Versen.
class _TextBlock {
  final List<BibleVerse> verses = [];

  final bool gapBefore;

  final GlobalKey key = GlobalKey();

  // Versnummer → Position im dargestellten Absatz; beim Aufbau gefüllt.
  final List<({int verse, int offset})> starts = [];

  _TextBlock({required this.gapBefore});
}

class BibleChapterViewState extends State<BibleChapterView> {
  // Überschriften und Absätze in Lesereihenfolge.
  List<Object> _blocks = const [];

  static const String _indent = "  ";

  @override
  void initState() {
    super.initState();

    _blocks = _layout(widget.chapter);
  }

  @override
  void didUpdateWidget(BibleChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.chapter, widget.chapter)) {
      _blocks = _layout(widget.chapter);
    }
  }

  static List<Object> _layout(BibleChapter chapter) {
    final blocks = <Object>[];

    _TextBlock? current;

    for (final item in chapter.items) {
      if (item is! BibleVerse) {
        blocks.add(item);
        current = null;
        continue;
      }

      final newBlock =
          current == null ||
          item.gapBefore ||
          item.breakBefore == BibleBreak.paragraph;

      if (newBlock) {
        current = _TextBlock(gapBefore: item.gapBefore);
        blocks.add(current);
      }

      current.verses.add(item);
    }

    return blocks;
  }

  RenderParagraph? _paragraphOf(_TextBlock block) {
    RenderParagraph? find(RenderObject? object) {
      if (object == null || object is RenderParagraph) {
        return object as RenderParagraph?;
      }

      RenderParagraph? result;

      object.visitChildren((child) => result ??= find(child));

      return result;
    }

    return find(block.key.currentContext?.findRenderObject());
  }

  /// Abstand des Verses vom oberen Rand von [ancestor], `null` solange das
  /// Kapitel nicht dargestellt ist oder den Vers nicht enthält.
  double? offsetOfVerse(int verse, RenderObject ancestor) {
    for (final block in _blocks.whereType<_TextBlock>()) {
      for (final start in block.starts) {
        if (start.verse != verse) continue;

        final paragraph = _paragraphOf(block);

        if (paragraph == null || !paragraph.hasSize) return null;

        final caret = paragraph.getOffsetForCaret(
          TextPosition(offset: start.offset),
          Rect.zero,
        );

        return paragraph.localToGlobal(caret, ancestor: ancestor).dy;
      }
    }

    return null;
  }

  /// Der Vers, der [y] unterhalb des oberen Rands von [ancestor] steht –
  /// für den Lesestand der oberste sichtbare Vers.
  int? verseAt(double y, RenderObject ancestor) {
    int? last;

    for (final block in _blocks.whereType<_TextBlock>()) {
      final paragraph = _paragraphOf(block);

      if (paragraph == null || !paragraph.hasSize || block.starts.isEmpty) {
        continue;
      }

      final top = paragraph.localToGlobal(Offset.zero, ancestor: ancestor).dy;

      if (top > y) return last ?? block.starts.first.verse;

      if (top + paragraph.size.height <= y) {
        last = block.starts.last.verse;
        continue;
      }

      final position = paragraph.getPositionForOffset(Offset(0, y - top + 1));

      int verse = block.starts.first.verse;

      for (final start in block.starts) {
        // Eine Zeile, die mitten im Vers beginnt, gehört zum nächsten Vers
        // erst, wenn dessen Anfang oben steht.
        if (start.offset <= position.offset) verse = start.verse;
      }

      return verse;
    }

    return last;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: 17 * widget.fontScale,
      height: 1.6,
      color: colors.textPrimary,
    );

    final notes = <({String verse, String text})>[];

    final children = <Widget>[];

    for (final block in _blocks) {
      if (block is BibleHeading) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 14 * widget.fontScale,
              bottom: 6 * widget.fontScale,
            ),
            child: Text(
              block.text,
              style: base.copyWith(
                fontSize: (block.level <= 1 ? 18 : 16) * widget.fontScale,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: block.level <= 1 ? colors.primary : colors.textSecondary,
              ),
            ),
          ),
        );
      } else if (block is BibleDescription) {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: 6 * widget.fontScale),
            child: Text(
              block.text,
              style: base.copyWith(
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
          ),
        );
      } else if (block is _TextBlock) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: block.gapBefore ? 10 * widget.fontScale : 0,
              bottom: 10 * widget.fontScale,
            ),
            child: Text.rich(_span(block, base, colors, notes), key: block.key),
          ),
        );
      }
    }

    if (widget.showNotes && notes.isNotEmpty) {
      children.add(_notes(notes, base, colors));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  TextSpan _span(
    _TextBlock block,
    TextStyle base,
    AppColors colors,
    List<({String verse, String text})> notes,
  ) {
    final spans = <InlineSpan>[];

    int offset = 0;

    void add(String text, [TextStyle? style]) {
      if (text.isEmpty) return;

      spans.add(TextSpan(text: text, style: style));

      offset += text.length;
    }

    final highlight = TextStyle(
      backgroundColor: colors.accent.withValues(alpha: 0.24),
    );

    final marker = TextStyle(
      fontSize: base.fontSize! * 0.72,
      fontWeight: FontWeight.w700,
      color: colors.accent,
    );

    block.starts.clear();

    for (int i = 0; i < block.verses.length; i++) {
      final verse = block.verses[i];

      final highlighted = widget.isHighlighted(verse.number);

      final style = highlighted ? highlight : null;

      if (i > 0) {
        switch (verse.breakBefore) {
          case BibleBreak.line:
          case BibleBreak.indentedLine:
            add("\n");
          case BibleBreak.none:
          case BibleBreak.paragraph:
            add(" ");
        }
      }

      if (verse.breakBefore == BibleBreak.indentedLine) add(_indent);

      if (!block.starts.any((s) => s.verse == verse.number)) {
        block.starts.add((verse: verse.number, offset: offset));
      }

      if (!verse.continuation) {
        add(
          "${verse.displayNumber} ",
          TextStyle(
            fontSize: base.fontSize! * 0.68,
            fontWeight: FontWeight.w700,
            color: highlighted ? colors.primary : colors.textSecondary,
            backgroundColor: style?.backgroundColor,
          ),
        );
      }

      // Text mit Anmerkungszeichen an den Stellen der Quelle.
      int position = 0;

      String shown(String text) => text.replaceAll("\t", _indent);

      for (final note in verse.notes) {
        if (!widget.showNotes) break;

        add(shown(verse.text.substring(position, note.offset)), style);

        position = note.offset;

        add("*", marker);

        notes.add((verse: verse.displayNumber, text: note.text));
      }

      add(shown(verse.text.substring(position)), style);
    }

    return TextSpan(style: base, children: spans);
  }

  Widget _notes(
    List<({String verse, String text})> notes,
    TextStyle base,
    AppColors colors,
  ) {
    final small = base.copyWith(
      fontSize: 14 * widget.fontScale,
      height: 1.45,
      color: colors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Theme(
        // Ohne Trennlinien des ExpansionTile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey("bible-notes-${widget.chapter.number}"),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: Text(
            "Anmerkungen der Ausgabe (${notes.length})",
            style: small.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "V. ${note.verse}  ",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: note.text),
                    ],
                  ),
                  style: small,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
