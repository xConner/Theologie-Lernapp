import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/philosophy/reading_search.dart';
import '../../../theme/app_theme.dart';
import 'edition_screens.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';

/// Suche in Text, Übersetzung, Anmerkungen, Einleitung und Glossar. Gibt
/// beim Antippen eines Treffers im Text die Satzkennung zurück.
class ReadingSearchScreen extends StatefulWidget {
  final ReadingSession session;

  const ReadingSearchScreen({super.key, required this.session});

  @override
  State<ReadingSearchScreen> createState() => _ReadingSearchScreenState();
}

class _ReadingSearchScreenState extends State<ReadingSearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<ReadingHit> _hits = const [];
  ReadingHitKind? _kind;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _hits = ReadingSearch.search(widget.session.text!, value));
    });
  }

  void _open(ReadingHit hit) {
    final session = widget.session;
    void jump(String id) => Navigator.pop(context, id);
    switch (hit.kind) {
      case ReadingHitKind.greek:
      case ReadingHitKind.german:
        if (hit.sentenceId != null) jump(hit.sentenceId!);
      case ReadingHitKind.note:
        final note = session.text!.note(hit.noteId!);
        if (note != null) showEditionNote(context, session, note, onJump: jump);
      case ReadingHitKind.intro:
        openIntroSection(context, session, hit.introSection!, onJump: jump);
      case ReadingHitKind.glossary:
        final entry = session.text!.front.glossary.firstWhere(
          (g) => g.id == hit.glossaryId,
        );
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: SingleChildScrollView(child: GlossaryCard(entry)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = {for (final h in _hits) h.kind};
    final shown = [
      for (final h in _hits)
        if (_kind == null || h.kind == _kind) h,
    ];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey("reading-search-field"),
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Griechisch (ohne Akzente) oder Deutsch",
            border: InputBorder.none,
          ),
          onChanged: _changed,
          onSubmitted: _changed,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            itemCount: shown.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                if (_hits.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.text.trim().length < 2
                          ? "Mindestens zwei Zeichen eingeben. Griechisch wird "
                                "ohne Akzente und Hauchzeichen verglichen."
                          : "Nichts gefunden.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  );
                }
                return Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text("Alle (${_hits.length})"),
                      selected: _kind == null,
                      onSelected: (_) => setState(() => _kind = null),
                    ),
                    for (final k in ReadingHitKind.values)
                      if (kinds.contains(k))
                        ChoiceChip(
                          label: Text(
                            "${k.label} (${_hits.where((h) => h.kind == k).length})",
                          ),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                  ],
                );
              }
              final hit = shown[i - 1];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "${hit.kind.label} · ${hit.title}",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
                subtitle: Text(
                  hit.snippet,
                  style: hit.kind == ReadingHitKind.greek
                      ? greekStyle(context, scale: 0.85)
                      : null,
                ),
                onTap: () => _open(hit),
              );
            },
          ),
        ),
      ),
    );
  }
}
