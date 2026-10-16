import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/verse_precision.dart';
import '../../../quiz/pericope_reference.dart';
import '../../../theme/app_theme.dart';

/// Ergebnis des Dialogs: neue Präzisierung, Zurücksetzen oder nichts.
class PrecisionDialogResult {
  final VersePrecision? precision;

  /// true: Präzisierung entfernen (wieder die Genauigkeit der Liste).
  final bool reset;

  const PrecisionDialogResult.save(VersePrecision this.precision)
    : reset = false;

  const PrecisionDialogResult.reset() : precision = null, reset = true;
}

/// Persönliche Verspräzisierung festlegen, bearbeiten oder zurücksetzen.
///
/// [verseCount] liefert die Verszahl eines Kapitels (deutsche Zählung) oder
/// `null`, wenn die Bibeldaten das Buch nicht enthalten.
Future<PrecisionDialogResult?> showPrecisionDialog(
  BuildContext context, {
  required BookPericope pericope,
  required VersePrecision? current,
  required int? Function(int chapter) verseCount,
}) {
  return showDialog<PrecisionDialogResult>(
    context: context,
    builder: (_) => PrecisionDialog(
      pericope: pericope,
      current: current,
      verseCount: verseCount,
    ),
  );
}

class PrecisionDialog extends StatefulWidget {
  final BookPericope pericope;
  final VersePrecision? current;
  final int? Function(int chapter) verseCount;

  const PrecisionDialog({
    super.key,
    required this.pericope,
    required this.current,
    required this.verseCount,
  });

  @override
  State<PrecisionDialog> createState() => _PrecisionDialogState();
}

class _PrecisionDialogState extends State<PrecisionDialog> {
  late bool enabled;

  late int startChapter;
  late int endChapter;

  final startVerse = TextEditingController();
  final endVerse = TextEditingController();

  String? error;

  @override
  void initState() {
    super.initState();

    final p = widget.pericope.perikope;

    // Startwert: die eigene Präzisierung, sonst die in der Liste
    // hinterlegten Verse (nur als Vorschlag, frei änderbar).
    final initial = widget.current ?? VersePrecisionValidator.suggestionOf(p);

    enabled = widget.current != null;

    startChapter = initial?.startChapter ?? p.startChapter;
    endChapter = initial?.endChapter ?? p.endChapter;

    startVerse.text = initial == null ? "" : "${initial.startVerse}";
    endVerse.text = initial == null ? "" : "${initial.endVerse}";
  }

  @override
  void dispose() {
    startVerse.dispose();
    endVerse.dispose();
    super.dispose();
  }

  List<int> get _chapters => widget.pericope.chapters.toList();

  VersePrecision? _read() {
    final sv = int.tryParse(startVerse.text.trim());
    final ev = int.tryParse(endVerse.text.trim());

    if (sv == null || ev == null) return null;

    return VersePrecision(
      startChapter: startChapter,
      startVerse: sv,
      endChapter: endChapter,
      endVerse: ev,
    );
  }

  void _save() {
    if (!enabled) {
      // Versgenauigkeit ausgeschaltet = zurücksetzen.
      Navigator.pop(
        context,
        widget.current == null ? null : const PrecisionDialogResult.reset(),
      );
      return;
    }

    final precision = _read();

    if (precision == null) {
      setState(() => error = "Bitte Anfangs- und Endvers angeben.");
      return;
    }

    final problem = VersePrecisionValidator.validate(
      widget.pericope.perikope,
      precision,
      verseCount: widget.verseCount,
    );

    if (problem != null) {
      setState(() => error = problem);
      return;
    }

    Navigator.pop(context, PrecisionDialogResult.save(precision));
  }

  String _maxHint(int chapter) {
    final max = widget.verseCount(chapter);
    return max == null ? "" : " (1–$max)";
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pericope.perikope;

    final listReference = PericopeReference.of(p).text;

    final stored = VersePrecisionValidator.suggestionOf(p);

    final multiChapter = _chapters.length > 1;

    Widget chapterField(int value, ValueChanged<int> onChanged, String label) {
      if (!multiChapter) {
        return InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text("$value"),
        );
      }

      return DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final c in _chapters)
            DropdownMenuItem(value: c, child: Text("$c")),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null) setState(() => onChanged(v));
              }
            : null,
      );
    }

    Widget verseField(
      TextEditingController controller,
      String label,
      int chapter,
      Key key,
    ) {
      return TextField(
        key: key,
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: "$label${_maxHint(chapter)}"),
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
      );
    }

    return AlertDialog(
      title: const Text("Versgenau lernen"),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pericope.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                "Perikopenliste: $listReference "
                "(${p.precision == "chapter" ? "kapitelgenau" : "versgenau"})",
                style: TextStyle(color: context.colors.textSecondary),
              ),
              if (p.precision == "chapter" && stored != null)
                Text(
                  "Dort hinterlegte Verse: "
                  "${PericopeReference.formatRange(precision: "verse", startChapter: stored.startChapter, startVerse: stored.startVerse, endChapter: stored.endChapter, endVerse: stored.endVerse)}"
                  " – nur ein Vorschlag.",
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey("precision-enabled"),
                contentPadding: EdgeInsets.zero,
                title: const Text("Für mich versgenau abfragen"),
                subtitle: const Text(
                  "Gilt nur für dich und nur beim systematischen Lernen.",
                ),
                value: enabled,
                onChanged: (v) => setState(() {
                  enabled = v;
                  error = null;
                }),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: chapterField(
                      startChapter,
                      (v) => startChapter = v,
                      "Kapitel",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: verseField(
                      startVerse,
                      "Anfangsvers",
                      startChapter,
                      const ValueKey("precision-start-verse"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: chapterField(
                      endChapter,
                      (v) => endChapter = v,
                      "Kapitel",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: verseField(
                      endVerse,
                      "Endvers",
                      endChapter,
                      const ValueKey("precision-end-verse"),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  key: const ValueKey("precision-error"),
                  style: TextStyle(color: context.colors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            key: const ValueKey("precision-reset"),
            onPressed: () =>
                Navigator.pop(context, const PrecisionDialogResult.reset()),
            child: const Text("Zurücksetzen"),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("precision-save"),
          onPressed: _save,
          child: const Text("Speichern"),
        ),
      ],
    );
  }
}
