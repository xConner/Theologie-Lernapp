import 'package:flutter/material.dart';

import '../../models/old_testament/old_testament.dart';
import '../../services/old_testament/old_testament_quiz.dart';
import '../../services/old_testament/old_testament_store.dart';
import '../../theme/app_theme.dart';
import 'old_testament_quiz_screen.dart';
import 'old_testament_widgets.dart';

/// Eine Vorlesungseinheit in drei Tabs:
/// * Überblick: Kernpunkte, Gliederung, Zusammenhänge, Merklisten,
///   Literatur – jeweils mit Folienangabe
/// * Begriffe und Stellen: Fachbegriffe und Bibelstellen (aufschlagbar)
/// * Originalfolien: Folienbilder und vollständige Abschrift
///
/// Tabs ohne Inhalt entfallen.
class UnitDetailScreen extends StatefulWidget {
  final OldTestamentData data;
  final String unitId;

  /// Öffnet direkt die Originalfolien an dieser Folie.
  final int? initialSlide;

  /// Nur für Tests: Speicher für den Lernmodus.
  final OldTestamentStore? store;

  const UnitDetailScreen({
    super.key,
    required this.data,
    required this.unitId,
    this.initialSlide,
    this.store,
  });

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  final Map<int, GlobalKey> _slideKeys = {};

  OldTestamentData get data => widget.data;

  @override
  void initState() {
    super.initState();

    final slide = widget.initialSlide;
    if (slide != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(slide));
    }
  }

  void _scrollTo(int slide) {
    final context = _slideKeys[slide]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  void _showSlide(BuildContext context, int tab, int slide) {
    DefaultTabController.of(context).animateTo(tab);
    // Erst nach dem Tabwechsel ist die Folienliste aufgebaut.
    Future.delayed(const Duration(milliseconds: 400), () => _scrollTo(slide));
  }

  void _learn(LectureUnit unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OldTestamentQuizScreen(
          data: data,
          scope: OtScope.unit(unit.id),
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = data.unit(widget.unitId);

    if (unit == null) {
      return const ChurchHistoryPage(
        title: "Einheit",
        children: [EmptyHint("Diese Einheit ist nicht vorhanden.")],
      );
    }

    final hasReference = unit.terms.isNotEmpty || unit.passages.isNotEmpty;
    final hasSlides = unit.slides.isNotEmpty;
    final slideTab = hasReference ? 2 : 1;

    return DefaultTabController(
      length: 1 + (hasReference ? 1 : 0) + (hasSlides ? 1 : 0),
      initialIndex: hasSlides && widget.initialSlide != null ? slideTab : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${unit.label}: ${unit.title}"),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: "Überblick"),
              if (hasReference) const Tab(text: "Begriffe und Stellen"),
              if (hasSlides) const Tab(text: "Originalfolien"),
            ],
          ),
        ),
        floatingActionButton: unit.hasLearningContent
            ? FloatingActionButton.extended(
                key: const ValueKey("unit-learn"),
                onPressed: () => _learn(unit),
                icon: const Icon(Icons.quiz_rounded),
                label: const Text("Einheit lernen"),
              )
            : null,
        body: TabBarView(
          children: [
            Builder(builder: (context) => _overview(context, unit, slideTab)),
            if (hasReference) _reference(context, unit),
            if (hasSlides) _slides(context, unit),
          ],
        ),
      ),
    );
  }

  Widget _slideButton(BuildContext context, List<int> slides, int slideTab) {
    if (slides.isEmpty) return const SizedBox.shrink();
    return TextButton(
      onPressed: data.unit(widget.unitId)!.slides.isEmpty
          ? null
          : () => _showSlide(context, slideTab, slides.first),
      child: Text(slidesLabel(slides)),
    );
  }

  Widget _overview(BuildContext context, LectureUnit unit, int slideTab) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = TextStyle(color: context.colors.textSecondary);
    final related = data.relatedUnitsOf(unit.id);

    return ChurchHistoryBody(
      children: [
        Text([data.course.subtitle, ?unit.scope].join(" · "), style: secondary),
        const SizedBox(height: 4),
        Text(
          "Kernpunkte und Gliederung fassen die Folien zusammen und nennen "
          "ihre Fundstelle. Blau umrandet: Wortlaut der Folie. Grau "
          "hinterlegt: Ergänzungen der App. Orange: Stellen, die die Folie "
          "nicht eindeutig macht.",
          style: secondary.copyWith(fontSize: 13),
        ),

        if (unit.keyPoints.isNotEmpty) ...[
          const SectionTitle("Kernpunkte"),
          for (final k in unit.keyPoints)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 8),
                    child: Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: context.colors.primary,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(k.text, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  _slideButton(context, k.slides, slideTab),
                ],
              ),
            ),
        ],

        if (unit.sections.isNotEmpty) const SectionTitle("Gliederung"),
        for (final section in unit.sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(section.title, style: textTheme.titleMedium),
                ),
                _slideButton(context, section.slides, slideTab),
              ],
            ),
          ),
          for (final point in section.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text("• $point", style: const TextStyle(fontSize: 16)),
            ),
          if (section.unclear != null) UnclearBox(section.unclear!),
          if (section.supplement != null) SupplementBox(section.supplement!),
        ],

        if (unit.connections.isNotEmpty) ...[
          const SectionTitle("Zusammenhänge"),
          for (final c in unit.connections)
            c.supplement
                ? SupplementBox(c.text)
                : LectureQuote(
                    text: c.text,
                    source: data.sourceLabel(unit.id, c.slides),
                  ),
        ],

        if (unit.lists.isNotEmpty) ...[
          const SectionTitle("Merklisten"),
          Text(
            "Diese Aufzählungen fragt der Lernmodus zum Abrufen aus dem "
            "Gedächtnis ab.",
            style: secondary,
          ),
          for (final list in unit.lists)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                key: ValueKey("list-${list.id}"),
                title: Text(list.title),
                subtitle: Text(
                  "${list.items.length} Punkte · ${slidesLabel(list.slides)}",
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < list.items.length; i++)
                    Text(
                      list.ordered
                          ? "${i + 1}. ${list.full(i)}"
                          : "• ${list.full(i)}",
                    ),
                ],
              ),
            ),
        ],

        if (unit.literature.isNotEmpty) ...[
          const SectionTitle("Quellen und Literatur"),
          Text("Angaben wie auf den Folien.", style: secondary),
          for (final l in unit.literature)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SelectableText(l.text)),
                  _slideButton(context, l.slides, slideTab),
                ],
              ),
            ),
        ],

        if (related.isNotEmpty) ...[
          const SectionTitle("Verwandte Einheiten"),
          for (final r in related)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_rounded),
              title: Text("${r.label}: ${r.title}"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UnitDetailScreen(
                    data: data,
                    unitId: r.id,
                    store: widget.store,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _reference(BuildContext context, LectureUnit unit) {
    final secondary = TextStyle(color: context.colors.textSecondary);

    return ChurchHistoryBody(
      children: [
        if (unit.terms.isNotEmpty) ...[
          const SectionTitle("Fachbegriffe"),
          for (final m in unit.terms)
            if (data.term(m.termId) != null)
              TermCard(
                data: data,
                term: data.term(m.termId)!,
                mention: m,
                source: data.sourceLabel(unit.id, m.slides),
              ),
        ],
        if (unit.passages.isNotEmpty) ...[
          const SectionTitle("Bibelstellen"),
          Text(
            "Antippen öffnet die Stelle in der Bibel der App.",
            style: secondary,
          ),
          for (final p in unit.passages)
            PassageTile(
              passage: p,
              source: data.sourceLabel(unit.id, p.slides),
            ),
        ],
      ],
    );
  }

  Widget _slides(BuildContext context, LectureUnit unit) {
    return ChurchHistoryBody(
      children: [
        if (unit.file != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Originaldatei: ${unit.file} · Bild antippen zum Vergrößern",
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        for (final slide in unit.slides)
          Card(
            key: _slideKeys.putIfAbsent(slide.number, GlobalKey.new),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Folie ${slide.number} · ${slide.title}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (slide.image != null) ...[
                    const SizedBox(height: 8),
                    _SlideImage(slide: slide),
                  ],
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: ValueKey("slide-text-${slide.number}"),
                    tilePadding: EdgeInsets.zero,
                    title: const Text("Abschrift"),
                    initiallyExpanded: slide.image == null,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(slide.text),
                      if (slide.figure != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Abbildung: ${slide.figure}",
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (slide.highlights.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Hervorgehoben: "
                          "${slide.highlights.map((h) => "„$h“").join(", ")}",
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SlideImage extends StatelessWidget {
  final UnitSlide slide;

  const _SlideImage({required this.slide});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      slide.image!,
      fit: BoxFit.contain,
      semanticLabel: "Folie ${slide.number}: ${slide.title}",
      errorBuilder: (_, _, _) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Das Folienbild konnte nicht geladen werden."),
      ),
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text("Folie ${slide.number}")),
            backgroundColor: Colors.black,
            body: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.asset(slide.image!)),
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: ColoredBox(color: Colors.white, child: image),
      ),
    );
  }
}
