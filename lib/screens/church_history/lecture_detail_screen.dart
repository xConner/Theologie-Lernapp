import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../theme/app_theme.dart';
import 'church_history_quiz_screen.dart';
import 'church_history_widgets.dart';
import 'timeline_view.dart';

/// Eine Vorlesung: strukturierte Zusammenfassung, Originalfolien mit
/// Abschrift und die behandelten Einträge.
class LectureDetailScreen extends StatefulWidget {
  final ChurchHistoryData data;
  final String lectureId;

  /// Öffnet direkt die Folienansicht an dieser Folie.
  final int? initialSlide;

  const LectureDetailScreen({
    super.key,
    required this.data,
    required this.lectureId,
    this.initialSlide,
  });

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> {
  final Map<int, GlobalKey> _slideKeys = {};

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

  void _learn(Lecture lecture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChurchHistoryQuizScreen(
          data: widget.data,
          mode: QuizMode.knowledge,
          scope: LearningScope.lecture(lecture.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final lecture = data.lecture(widget.lectureId);

    if (lecture == null) {
      return const ChurchHistoryPage(
        title: "Vorlesung",
        children: [EmptyHint("Diese Vorlesung ist nicht vorhanden.")],
      );
    }

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialSlide != null ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${lecture.label}: ${lecture.title}"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Überblick"),
              Tab(text: "Folien"),
              Tab(text: "Einträge"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey("lecture-learn"),
          onPressed: () => _learn(lecture),
          icon: const Icon(Icons.quiz_rounded),
          label: const Text("Vorlesung lernen"),
        ),
        body: TabBarView(
          children: [
            _overview(context, lecture),
            _slides(context, lecture),
            _entries(context, lecture),
          ],
        ),
      ),
    );
  }

  Widget _frame(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ChurchHistoryPage.maxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _overview(BuildContext context, Lecture lecture) {
    final data = widget.data;
    final textTheme = Theme.of(context).textTheme;

    return _frame([
      Text(
        "${data.course.title} · ${data.course.lecturer}",
        style: TextStyle(color: context.colors.textSecondary),
      ),
      const SizedBox(height: 4),
      Text(
        "Die Stichpunkte geben den Inhalt der Folien wieder. Grau "
        "hinterlegte Kästen sind Ergänzungen der App.",
        style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
      ),

      for (final section in lecture.sections) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(section.title, style: textTheme.titleLarge)),
              TextButton(
                onPressed: () {
                  DefaultTabController.of(context).animateTo(1);
                  // Erst nach dem Tabwechsel ist die Folienliste aufgebaut.
                  Future.delayed(
                    const Duration(milliseconds: 400),
                    () => _scrollTo(section.slides.first),
                  );
                },
                child: Text(slidesLabel(section.slides)),
              ),
            ],
          ),
        ),
        for (final point in section.points)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Text("• $point", style: const TextStyle(fontSize: 16)),
          ),
        if (section.supplement != null) SupplementBox(section.supplement!),
      ],

      if (lecture.lists.isNotEmpty) ...[
        const SectionTitle("Merklisten"),
        Text(
          "Diese Aufzählungen fragt das Wissensquiz zum Abrufen aus dem "
          "Gedächtnis ab.",
          style: TextStyle(color: context.colors.textSecondary),
        ),
        for (final list in lecture.lists)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ExpansionTile(
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
                        ? "${i + 1}. ${list.items[i]}"
                        : "• ${list.items[i]}",
                  ),
              ],
            ),
          ),
      ],

      const SectionTitle("Zeitliche Einordnung"),
      OutlinedButton.icon(
        icon: const Icon(Icons.timeline_rounded),
        label: const Text("Auf der Zeitleiste anzeigen"),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text("Zeitleiste: ${lecture.label}")),
              body: TimelineView(data: data, lectureId: lecture.id),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _slides(BuildContext context, Lecture lecture) {
    if (lecture.slides.isEmpty) {
      return const EmptyHint(
        "Zu dieser Vorlesung sind keine Folien hinterlegt.",
      );
    }

    return _frame([
      if (lecture.file != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            "Originaldatei: ${lecture.file} · Bild antippen zum Vergrößern",
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ),
      for (final slide in lecture.slides)
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
                    if (slide.highlights.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Farbig hervorgehoben: "
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
    ]);
  }

  Widget _entries(BuildContext context, Lecture lecture) {
    final data = widget.data;
    final entries = data.entriesOfLecture(lecture.id);

    if (entries.isEmpty) {
      return const EmptyHint(
        "Diese Vorlesung verweist noch auf keine Einträge.",
      );
    }

    String? mentionOf(String id) {
      for (final m in lecture.mentions) {
        if (m.entryId == id) return m.text;
      }
      return null;
    }

    return _frame([
      for (final type in EntryType.values)
        if (entries.any((e) => e.type == type)) ...[
          SectionTitle(type.plural),
          for (final e in entries.where((e) => e.type == type))
            EntryTile(data: data, entry: e, detail: mentionOf(e.id)),
        ],
    ]);
  }
}

class _SlideImage extends StatelessWidget {
  final Slide slide;

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
