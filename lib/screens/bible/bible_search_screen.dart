import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/bible/bible_translation.dart';
import '../../services/bible/bible_books.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/bible/bible_search.dart';
import '../../theme/app_theme.dart';
import '../../widgets/greek_keyboard.dart';

/// Suche in der gewählten Ausgabe: Eine eingegebene Stelle („Mk 4,35–41“)
/// wird direkt angeboten, alles andere im Text gesucht. Schließt mit der
/// Stelle, die geöffnet werden soll.
class BibleSearchScreen extends StatefulWidget {
  final BibleRepository repository;
  final BibleTranslation translation;

  /// Aufgeschlagenes Buch, für die Einschränkung „in diesem Buch“.
  final String? currentBookId;

  const BibleSearchScreen({
    super.key,
    required this.repository,
    required this.translation,
    this.currentBookId,
  });

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  BibleSearchIndex? _index;
  double _progress = 0;
  bool _failed = false;

  BibleSearchScope _scope = BibleSearchScope.all;

  BibleSearchQuery _query = const BibleSearchQuery([]);
  BibleSearchResult _result = BibleSearchResult.empty;
  BibleReference? _reference;

  bool _greekKeyboard = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _loadIndex();
  }

  Future<void> _loadIndex() async {
    try {
      final index = await widget.repository.searchIndex(
        widget.translation,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );

      if (!mounted) return;

      setState(() => _index = index);

      _search();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  void _search() {
    if (!mounted) return;

    final text = _input.text.trim();

    final index = _index;

    setState(() {
      _reference = text.isEmpty
          ? null
          : BibleReferenceParser.parse(text, translation: widget.translation);

      if (index == null) return;

      _query = index.parse(text);

      // Ein einzelner Buchstabe trifft fast jeden Vers.
      final tooShort = _query.terms.every((t) => t.length < 2);

      _result = tooShort
          ? BibleSearchResult.empty
          : index.search(_query, scope: _scope, bookId: widget.currentBookId);
    });
  }

  void _toggleGreekKeyboard() {
    setState(() => _greekKeyboard = !_greekKeyboard);

    // Die eigene Tastatur ersetzt die des Systems.
    if (_greekKeyboard) {
      _focus.unfocus();
    } else {
      _focus.requestFocus();
    }
  }

  String _bookName(String id) {
    return widget.translation.book(id)?.name ?? BibleBooks.nameOf(id);
  }

  @override
  Widget build(BuildContext context) {
    final translation = widget.translation;

    final reference = _reference;

    final text = _input.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text("Suche · ${translation.shortName}")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        key: const ValueKey("bible-search-input"),
                        controller: _input,
                        focusNode: _focus,
                        autofocus: true,
                        readOnly: _greekKeyboard,
                        showCursor: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => _onChanged(),
                        onSubmitted: (_) {
                          _debounce?.cancel();
                          _search();
                        },
                        decoration: InputDecoration(
                          hintText: translation.isGreek
                              ? "Stelle oder Wort, z. B. Mk 4,35 oder ἀγάπη"
                              : "Stelle oder Wort, z. B. Mk 4,35–41",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (translation.isGreek)
                                IconButton(
                                  key: const ValueKey("bible-greek-keyboard"),
                                  icon: Icon(
                                    _greekKeyboard
                                        ? Icons.keyboard_hide
                                        : Icons.keyboard,
                                  ),
                                  tooltip: "Griechische Tastatur",
                                  onPressed: _toggleGreekKeyboard,
                                ),
                              if (_input.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: "Leeren",
                                  onPressed: () {
                                    _input.clear();
                                    _search();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final scope in BibleSearchScope.values)
                              if (scope != BibleSearchScope.book ||
                                  widget.currentBookId != null)
                                ChoiceChip(
                                  label: Text(_scopeLabel(scope)),
                                  selected: _scope == scope,
                                  onSelected: (_) {
                                    _scope = scope;
                                    _search();
                                  },
                                ),
                          ],
                        ),
                      ),
                    ),

                    if (_index == null && !_failed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(value: _progress),
                            const SizedBox(height: 6),
                            Text(
                              "Text wird für die Suche vorbereitet …",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                    if (_failed)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          "Der Text dieser Ausgabe konnte nicht geladen "
                          "werden.",
                        ),
                      ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                        children: [
                          if (reference != null)
                            Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                key: const ValueKey("bible-open-reference"),
                                leading: const Icon(Icons.menu_book_rounded),
                                title: Text(
                                  "${_bookName(reference.bookId)} "
                                  "${reference.rangeText}",
                                ),
                                subtitle: const Text("Stelle öffnen"),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context, reference),
                              ),
                            ),

                          if (_index != null && !_query.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                              child: Text(
                                _summary(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.colors.textSecondary,
                                    ),
                              ),
                            ),

                          for (final hit in _result.hits)
                            ListTile(
                              dense: true,
                              title: Text(
                                "${_bookName(hit.bookId)} "
                                "${hit.chapter},${hit.verseLabel}",
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              subtitle: Text.rich(
                                _snippet(hit),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              onTap: () =>
                                  Navigator.pop(context, hit.reference),
                            ),

                          if (text.isEmpty && reference == null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                "Gib eine Stelle ein, um sie zu öffnen, oder "
                                "Wörter, um im Text von "
                                "„${translation.name}“ zu suchen. Mehrere "
                                "Wörter müssen im selben Vers stehen; ein "
                                "Ausdruck in Anführungszeichen wird "
                                "zusammenhängend gesucht. Groß- und "
                                "Kleinschreibung"
                                "${translation.language == "de" ? "" : ", Akzente und Spiritus"}"
                                " spielen keine Rolle.",
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_greekKeyboard)
            GreekKeyboard(controller: _input, onChanged: _onChanged),
        ],
      ),
    );
  }

  String _scopeLabel(BibleSearchScope scope) {
    switch (scope) {
      case BibleSearchScope.all:
        return "Ganze Ausgabe";
      case BibleSearchScope.oldTestament:
        return "AT";
      case BibleSearchScope.newTestament:
        return "NT";
      case BibleSearchScope.book:
        return _bookName(widget.currentBookId!);
    }
  }

  String _summary() {
    final total = _result.total;

    if (_query.terms.every((t) => t.length < 2)) {
      return "Bitte mindestens zwei Buchstaben eingeben.";
    }

    if (total == 0) return "Keine Treffer im Text.";

    if (total > _result.hits.length) {
      return "$total Verse gefunden – die ersten ${_result.hits.length} "
          "werden angezeigt.";
    }

    return total == 1 ? "1 Vers gefunden" : "$total Verse gefunden";
  }

  /// Der unveränderte Verstext mit hervorgehobenen Treffern.
  TextSpan _snippet(BibleSearchHit hit) {
    final index = _index!;

    final text = hit.text.replaceAll(RegExp(r'\s+'), ' ');

    final spans = <TextSpan>[];

    int position = 0;

    for (final range in index.matchRanges(text, _query)) {
      spans.add(TextSpan(text: text.substring(position, range.start)));

      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            backgroundColor: context.colors.accent.withValues(alpha: 0.24),
          ),
        ),
      );

      position = range.end;
    }

    spans.add(TextSpan(text: text.substring(position)));

    return TextSpan(children: spans);
  }
}
