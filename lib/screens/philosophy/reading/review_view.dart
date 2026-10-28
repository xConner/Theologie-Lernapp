import 'package:flutter/material.dart';

import '../../../models/greek/vocabulary/learning_card.dart';
import '../../../services/philosophy/reading_review.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/content_page.dart';
import 'reader_screen.dart';
import 'reading_session.dart';
import 'reading_widgets.dart';

/// Lernen: Wiederholung mit aktivem Erinnern statt Auswahlantworten.
/// Erst selbst übersetzen bzw. erklären, dann mit der Ausgabe vergleichen
/// und ehrlich einschätzen.
class ReviewView extends StatefulWidget {
  final ReadingSession session;
  final ReadingReviewStore? store;

  const ReviewView({super.key, required this.session, this.store});

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  late final ReadingReviewStore _store =
      widget.store ?? ReadingReviewStore.forUser(widget.session.uid);
  Map<String, LearningCard>? _state;
  Set<ReviewKind> _kinds = {...ReviewKind.values};
  ReviewItem? _current;
  bool _revealed = false;
  final Set<String> _done = {};
  int _known = 0;

  @override
  void initState() {
    super.initState();
    _store.load().then((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  List<ReviewItem> get _items =>
      ReadingReviewStore.items(widget.session.text!, widget.session.user, kinds: _kinds);

  void _start() {
    setState(() {
      _done.clear();
      _known = 0;
      _current = _store.next(_items, _state!);
      _revealed = false;
    });
  }

  Future<void> _answer(bool known) async {
    final item = _current!;
    await _store.answer(item, _state!, known);
    setState(() {
      _done.add(item.id);
      if (known) _known++;
      _current = _store.next(_items, _state!, exclude: _done);
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const Center(child: CircularProgressIndicator());
    final items = _items;
    final available = ReadingReviewStore.items(
      widget.session.text!,
      widget.session.user,
    );
    final counts = {
      for (final k in ReviewKind.values)
        k: available.where((i) => i.kind == k).length,
    };

    if (_current != null) return _card(_current!);

    return ContentBody(
      children: [
        Text(
          "Karten entstehen aus dem Glossar der Ausgabe, aus der eigenen "
          "Wortliste, aus Sätzen mit Lesezeichen und aus den textkritischen "
          "Fußnoten. Erst selbst antworten, dann aufdecken und einschätzen.",
          style: TextStyle(color: context.colors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final k in ReviewKind.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _kinds.contains(k),
            title: Text(k.label),
            subtitle: Text(
              counts[k] == 0 ? _emptyHint(k) : "${counts[k]} Karten",
            ),
            onChanged: counts[k] == 0
                ? null
                : (v) => setState(() {
                    _kinds = {..._kinds};
                    v == true ? _kinds.add(k) : _kinds.remove(k);
                  }),
          ),
        const SizedBox(height: 8),
        if (_done.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text("Runde beendet: $_known von ${_done.length} gewusst."),
          ),
        FilledButton.icon(
          key: const ValueKey("review-start"),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text("Wiederholen (${items.length} Karten)"),
          onPressed: items.isEmpty ? null : _start,
        ),
        const SizedBox(height: 8),
        Text(
          "Schon wiederholt: ${ReadingReviewStore.reviewedCount(available, state)} "
          "von ${available.length}. Lernstände sind von der Leseposition "
          "getrennt gespeichert.",
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
      ],
    );
  }

  String _emptyHint(ReviewKind k) => switch (k) {
    ReviewKind.term => "Die gewählte Ausgabe hat kein Glossar.",
    ReviewKind.word => "Wortliste ist leer.",
    ReviewKind.sentence => "Noch keine Lesezeichen.",
    ReviewKind.textCritical => "Die gewählte Ausgabe hat keine Textkritik.",
  };

  Widget _card(ReviewItem item) {
    final text = widget.session.text!;
    final sentence = item.sentence;
    final unit = sentence == null ? null : text.unitOfSentence(sentence.id);

    final (String task, List<Widget> front, List<Widget> back) = switch (item.kind) {
      ReviewKind.term => (
        "Was bedeutet der Begriff, und wie gibt die Ausgabe ihn wieder?",
        [
          Text(item.glossary!.term, style: Theme.of(context).textTheme.headlineSmall),
          if (item.glossary!.grammar != null) Text(item.glossary!.grammar!),
        ],
        [GlossaryCard(item.glossary!)],
      ),
      ReviewKind.word => (
        "Bestimme die Form und nenne die Bedeutung.",
        [
          Text(item.word!.form, style: greekStyle(context, scale: 1.4)),
          if (sentence != null)
            Text(sentence.text, style: greekStyle(context, scale: 0.85)),
        ],
        [
          if (item.word!.lemma != null)
            Text("Grundform: ${item.word!.lemma}", style: greekStyle(context)),
          FutureBuilder(
            future: widget.session.analyzer(),
            builder: (context, snap) {
              final a = snap.data?.analyze(item.word!.form);
              if (a == null) return const SizedBox.shrink();
              if (!a.isAnalyzed) return const Text("Keine Bestimmung im Formenindex.");
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in a.candidates) ...[
                    Text(c.lemma, style: greekStyle(context, scale: 0.9)),
                    for (final m in c.analyses) Text("• ${m.describe()} (möglich)"),
                    if (c.lexicon != null && c.lexicon!.german.isNotEmpty)
                      Text(c.lexicon!.german.join("; ")),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      ReviewKind.sentence => (
        "Übersetze den Satz bzw. gib seinen Gedanken wieder.",
        [Text(sentence!.text, style: greekStyle(context))],
        [
          if (unit != null && unit.hasGerman) ...[
            if (!unit.oneToOne || !unit.exact) ApproxHint(unit),
            Text(unit.german.map((d) => d.text).join(" "), style: germanStyle(context)),
          ] else
            const Text("Diese Ausgabe hat keine Übersetzung."),
          if ((widget.session.user.marks["s:${sentence.id}"]?.note ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Meine Notiz: ${widget.session.user.marks["s:${sentence.id}"]!.note}",
              ),
            ),
        ],
      ),
      ReviewKind.textCritical => (
        "Was ist an dieser Stelle textkritisch strittig, und wie entscheidet "
            "die Ausgabe?",
        [
          RefLabel(item.note!.refLabel),
          Text(sentence!.text, style: greekStyle(context)),
        ],
        [Text(item.note!.text)],
      ),
    };

    return ContentBody(
      children: [
        Row(
          children: [
            Tag(item.kind.label),
            const Spacer(),
            Text("${_done.length + 1}. Karte"),
            IconButton(
              tooltip: "Runde beenden",
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _current = null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(task, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...front,
        const SizedBox(height: 16),
        if (!_revealed)
          FilledButton(
            key: const ValueKey("review-reveal"),
            onPressed: () => setState(() => _revealed = true),
            child: const Text("Aufdecken"),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: back,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey("review-unknown"),
                  onPressed: () => _answer(false),
                  child: const Text("Noch nicht"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey("review-known"),
                  onPressed: () => _answer(true),
                  child: const Text("Gewusst"),
                ),
              ),
            ],
          ),
          if (sentence != null)
            TextButton(
              onPressed: () =>
                  openReader(context, widget.session, sentenceId: sentence.id),
              child: const Text("Stelle im Text öffnen"),
            ),
        ],
      ],
    );
  }
}
