import 'package:flutter/material.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../theme/app_theme.dart';

/// Buch und Kapitel wählen oder eine Stelle direkt eingeben. Schließt mit
/// der gewählten [BibleReference].
class BibleNavigationScreen extends StatefulWidget {
  final BibleTranslation translation;

  /// Aufgeschlagenes Buch; seine Kapitel werden zuerst angeboten.
  final String? currentBookId;
  final int? currentChapter;

  const BibleNavigationScreen({
    super.key,
    required this.translation,
    this.currentBookId,
    this.currentChapter,
  });

  @override
  State<BibleNavigationScreen> createState() => _BibleNavigationScreenState();
}

class _BibleNavigationScreenState extends State<BibleNavigationScreen> {
  final TextEditingController _input = TextEditingController();

  String? _error;

  late String? _bookId = widget.currentBookId;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text.trim();

    if (text.isEmpty) return;

    final reference = BibleReferenceParser.parse(
      text,
      translation: widget.translation,
    );

    if (reference == null) {
      setState(() {
        _error = "Keine Stelle erkannt. Beispiel: Mk 4,35–41";
      });

      return;
    }

    Navigator.pop(context, reference);
  }

  @override
  Widget build(BuildContext context) {
    final translation = widget.translation;

    final book = _bookId == null ? null : translation.book(_bookId!);

    final groups = <BibleTestament, List<BibleBookInfo>>{};

    for (final b in translation.books) {
      final testament =
          BibleBooks.byId(b.id)?.testament ?? BibleTestament.apocrypha;

      groups.putIfAbsent(testament, () => []).add(b);
    }

    const titles = {
      BibleTestament.old: "Altes Testament",
      BibleTestament.apocrypha: "Apokryphen / Spätschriften",
      BibleTestament.newTestament: "Neues Testament",
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Stelle wählen")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TextField(
                key: const ValueKey("bible-reference-input"),
                controller: _input,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: "Stelle eingeben",
                  hintText: "z. B. Mk 4,35–41",
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: "Öffnen",
                    onPressed: _submit,
                  ),
                ),
              ),

              if (book != null) ...[
                const SizedBox(height: 20),

                Text(
                  "${book.name} – Kapitel",
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (int c = 1; c <= book.chapterCount; c++)
                      _ChapterButton(
                        chapter: c,
                        current:
                            book.id == widget.currentBookId &&
                            c == widget.currentChapter,
                        onPressed: () => Navigator.pop(
                          context,
                          BibleReference.chapter(book.id, c),
                        ),
                      ),
                  ],
                ),
              ],

              for (final testament in BibleTestament.values)
                if (groups[testament] != null) ...[
                  const SizedBox(height: 24),

                  Text(
                    titles[testament]!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final b in groups[testament]!)
                        ChoiceChip(
                          key: ValueKey("bible-book-${b.id}"),
                          label: Text(b.name),
                          selected: b.id == _bookId,
                          onSelected: (_) {
                            // Bücher mit nur einem Kapitel direkt öffnen.
                            if (b.chapterCount == 1) {
                              Navigator.pop(
                                context,
                                BibleReference.chapter(b.id, 1),
                              );

                              return;
                            }

                            setState(() => _bookId = b.id);
                          },
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
}

class _ChapterButton extends StatelessWidget {
  final int chapter;
  final bool current;
  final VoidCallback onPressed;

  const _ChapterButton({
    required this.chapter,
    required this.current,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 48,
      height: 44,
      child: Material(
        color: current ? colors.primary : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: InkWell(
          key: ValueKey("bible-chapter-$chapter"),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          onTap: onPressed,
          child: Center(
            child: Text(
              "$chapter",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: current ? colors.onPrimary : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
