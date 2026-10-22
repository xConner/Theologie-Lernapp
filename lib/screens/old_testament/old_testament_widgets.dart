import 'package:flutter/material.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/old_testament/old_testament.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/old_testament/old_testament_loader.dart';
import '../../theme/app_theme.dart';
import '../bible/bible_reader_screen.dart';
import '../church_history/church_history_widgets.dart';

/// Gemeinsame Bausteine des Bereichs Altes Testament. Seitengerüst,
/// Überschriften, Ergänzungskasten und Zitat stammen aus der
/// Kirchengeschichte, damit beide Bereiche gleich aussehen.
export '../church_history/church_history_widgets.dart'
    show
        ChurchHistoryBody,
        ChurchHistoryPage,
        EmptyHint,
        LectureQuote,
        SectionTitle,
        SupplementBox,
        Tag;

/// Lädt die Inhalte und zeigt Lade- und Fehlerzustand.
class OldTestamentDataBuilder extends StatefulWidget {
  final String title;
  final Widget Function(BuildContext context, OldTestamentData data) builder;

  /// Nur für Tests: Daten ohne Laden aus den Assets.
  final OldTestamentData? data;

  const OldTestamentDataBuilder({
    super.key,
    required this.title,
    required this.builder,
    this.data,
  });

  @override
  State<OldTestamentDataBuilder> createState() =>
      _OldTestamentDataBuilderState();
}

class _OldTestamentDataBuilderState extends State<OldTestamentDataBuilder> {
  late Future<OldTestamentData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<OldTestamentData> _load() {
    final data = widget.data;
    return data != null ? Future.value(data) : OldTestamentLoader.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OldTestamentData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;

        if (data != null) return widget.builder(context, data);

        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Die Inhalte zum Alten Testament konnten nicht "
                          "geladen werden.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() => _future = _load()),
                          child: const Text("Erneut versuchen"),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Bibelstelle der Folie als Stelle für den Bibel-Reader; null, wenn sich
/// die Angabe nicht aufschlagen lässt.
BiblePassage? biblePassageOf(PassageRef passage) {
  final reference = BibleReferenceParser.parse(passage.openText);
  if (reference == null) return null;
  return BiblePassage(label: passage.label, reference: reference);
}

/// Öffnet die Stelle im vorhandenen Bibel-Reader (hervorgehoben).
void openBiblePassage(BuildContext context, PassageRef passage) {
  final bible = biblePassageOf(passage);
  if (bible == null) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          BibleReaderScreen(passages: [bible], passageTitle: passage.label),
    ),
  );
}

/// Bibelstelle mit Kontext und Knopf zum Aufschlagen.
class PassageTile extends StatelessWidget {
  final PassageRef passage;
  final String source;

  const PassageTile({super.key, required this.passage, required this.source});

  @override
  Widget build(BuildContext context) {
    final canOpen = biblePassageOf(passage) != null;
    final secondary = TextStyle(color: context.colors.textSecondary);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: ValueKey("passage-${passage.id}"),
        leading: Icon(Icons.menu_book_rounded, color: context.colors.primary),
        title: Text(passage.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(passage.context),
            Text(source, style: secondary.copyWith(fontSize: 12)),
          ],
        ),
        trailing: canOpen
            ? IconButton(
                key: ValueKey("open-${passage.id}"),
                tooltip: "In der Bibel lesen",
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => openBiblePassage(context, passage),
              )
            : null,
        onTap: canOpen ? () => openBiblePassage(context, passage) : null,
      ),
    );
  }
}

/// Hinweis auf eine Stelle, die die Folie nicht eindeutig macht.
class UnclearBox extends StatelessWidget {
  final Ambiguity unclear;

  const UnclearBox(this.unclear, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: context.colors.accent, width: 3),
        ),
        color: context.colors.accent.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: context.colors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text("Nicht eindeutig: ${unclear.text}")),
        ],
      ),
    );
  }
}

/// Fachbegriff mit Erklärung und Herkunft.
class TermCard extends StatelessWidget {
  final OldTestamentData data;
  final Term term;

  /// Was die Einheit über den Begriff sagt (in der Einheitenansicht).
  final TermMention? mention;
  final String? source;

  const TermCard({
    super.key,
    required this.data,
    required this.term,
    this.mention,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final units = data.unitsOfTerm(term.id);

    return Card(
      key: ValueKey("term-${term.id}"),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(term.name, style: Theme.of(context).textTheme.titleMedium),
            if (term.hebrew != null || term.transliteration != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [?term.hebrew, ?term.transliteration].join(" · "),
                  style: secondary.copyWith(fontStyle: FontStyle.italic),
                  textDirection: TextDirection.ltr,
                ),
              ),
            const SizedBox(height: 6),
            if (mention?.text != null && source != null)
              LectureQuote(text: mention!.text!, source: source!),
            if (term.fromSlides)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(term.definition),
              )
            else
              SupplementBox(
                term.definition,
                label: "Erklärung – Ergänzung, nicht von den Folien",
              ),
            if (term.supplement != null) SupplementBox(term.supplement!),
            if (mention == null && units.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final u in units)
                      Tag(
                        data.sourceLabel(u.id, u.mentionOf(term.id)!.slides),
                        color: context.colors.primary,
                        icon: Icons.school_outlined,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
