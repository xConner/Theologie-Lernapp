import 'package:flutter/material.dart';

import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_learning_status.dart';
import '../../../quiz/books/book_outline.dart';
import '../../../quiz/books/book_plan.dart';
import '../../../quiz/books/book_study_session.dart';
import '../../../quiz/books/knowledge.dart';
import '../../../quiz/pericope_reference.dart';
import '../../../services/bible/bible_reference_parser.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';
import 'bible_passage.dart';
import 'book_dialogs.dart';
import 'book_settings.dart';
import 'book_study_screen.dart';
import 'book_widgets.dart';
import 'knowledge_widgets.dart';
import 'precision_dialog.dart';
import 'review_overview_screen.dart';

/// Ein Buch: Fortschritt, Lernplan, die Abschnitte der Gliederung, weitere
/// Lernmodi und eine kompakte Kapitelübersicht.
///
/// Bewusst ohne Liste aller Perikopen: Gelernt wird nach Umfang (Abschnitt,
/// Kapitel, Bereich, ganzes Buch). Einzelne Perikopen – zum Üben oder für
/// eine Verspräzisierung – sind über ihren Abschnitt erreichbar.
class BookDetailScreen extends StatefulWidget {
  final BookLearningController controller;
  final String book;

  const BookDetailScreen({
    super.key,
    required this.controller,
    required this.book,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  BookLearningController get controller => widget.controller;

  BookLearningState get state => controller.state;

  String get book => widget.book;

  List<BookPericope> get pericopes => state.catalog.pericopesOf(book);

  List<int> get chapters => state.catalog.chaptersOf(book);

  late final BookOutline outline = controller.outlineFor(book);

  Future<void> _study(
    StudySession session, {
    String? title,
    List<StudyFollowUp> Function()? followUps,
  }) {
    return startStudy(
      context,
      controller: controller,
      session: session,
      title: title,
      followUps: followUps,
    );
  }

  String _rangeText((int, int) range) =>
      range.$1 == range.$2 ? "${range.$1}" : "${range.$1}–${range.$2}";

  // ---------- Abschnitte ----------

  /// Anschluss nach einer Einheit: denselben Abschnitt weiterlernen, solange
  /// er neue Perikopen hat, und der nächste Abschnitt der Gliederung.
  List<StudyFollowUp> _sectionFollowUps(OutlineSection section) {
    final result = <StudyFollowUp>[];

    if (state.progressOfSection(section).fresh > 0) {
      result.add(_sectionFollowUp(section, "Abschnitt weiterlernen"));
    }

    final next = state.sectionAfter(outline, section);

    if (next != null) {
      result.add(_sectionFollowUp(next, "Weiter: ${next.title}"));
    }

    return result;
  }

  StudySession _sectionSession(OutlineSection section) {
    return controller.scopeSession(
      StudyMode.section,
      pericopesOfSection(state.catalog, section),
      knowledge: controller.knowledgeOfSection(section),
    );
  }

  StudyFollowUp _sectionFollowUp(OutlineSection section, String label) {
    return StudyFollowUp(
      label: label,
      title: section.title,
      session: () => _sectionSession(section),
      followUps: () => _sectionFollowUps(section),
    );
  }

  Future<void> _learnSection(OutlineSection section) {
    return _study(
      _sectionSession(section),
      title: section.title,
      followUps: () => _sectionFollowUps(section),
    );
  }

  Future<void> _openSection(OutlineSection section) async {
    final action = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SectionSheet(
        state: state,
        book: book,
        section: section,
        knowledge: state.active(controller.knowledgeOfSection(section)),
      ),
    );

    if (!mounted || action == null) return;

    final members = pericopesOfSection(state.catalog, section);

    switch (action) {
      case "learn":
        await _learnSection(section);
      case "order":
        await _study(
          controller.fixedSession(
            StudyMode.order,
            controller.planner().order(members),
          ),
          title: section.title,
        );
      case "exam":
        await _study(
          controller.fixedSession(
            StudyMode.exam,
            controller.planner().exam(members),
          ),
          title: section.title,
        );
      case "read":
        final passage = passageOfSection(section);

        if (passage != null) {
          await openPassage(context, controller, passage, title: section.title);
        }
      case "knowledge":
        await _study(
          controller.knowledgeSession(controller.knowledgeOfSection(section)),
          title: "Wissensfragen: ${section.title}",
        );
      case BookPericope p:
        await _openPericope(p);
    }
  }

  // ---------- Weitere Lernmöglichkeiten ----------

  /// Lerneinheit über das ganze Buch: fortlaufend ausgewählt nach
  /// Lernbedarf und Fälligkeit, neue Perikopen nach Lernplan.
  Future<void> _learnBook() {
    return _study(
      controller.bookSession(book),
      title: "${BookCatalog.nameOf(book)} lernen",
    );
  }

  Future<void> _chapterTraining({int? chapter}) async {
    final range = chapter != null
        ? (chapter, chapter)
        : await showChapterRangeDialog(
            context,
            title: "Kapitel oder Bereich lernen",
            chapters: chapters,
          );

    if (range == null || !mounted) return;

    await _study(
      controller.scopeSession(
        StudyMode.chapter,
        state.catalog.inChapters(book, range.$1, range.$2),
        knowledge: controller.knowledgeOfChapters(book, range.$1, range.$2),
      ),
      title: "$book ${_rangeText(range)}",
    );
  }

  Future<void> _order() async {
    final range = await showChapterRangeDialog(
      context,
      title: "Reihenfolge lernen",
      chapters: chapters,
      wholeBook: true,
    );

    if (range == null || !mounted) return;

    await _study(
      controller.fixedSession(
        StudyMode.order,
        controller.planner().order(
          state.catalog.inChapters(book, range.$1, range.$2),
        ),
      ),
    );
  }

  Future<void> _exam() async {
    final range = await showChapterRangeDialog(
      context,
      title: "Prüfung",
      chapters: chapters,
      wholeBook: true,
    );

    if (range == null || !mounted) return;

    final whole = range.$1 == chapters.first && range.$2 == chapters.last;

    await _study(
      controller.fixedSession(
        StudyMode.exam,
        controller.planner().exam(
          state.catalog.inChapters(book, range.$1, range.$2),
        ),
      ),
      title: whole ? BookCatalog.nameOf(book) : "$book ${_rangeText(range)}",
    );
  }

  // ---------- Lernplan ----------

  Future<void> _editPlan() async {
    final progress = state.progressOf(pericopes);

    final result = await showPlanDialog(
      context,
      book: book,
      bookName: BookCatalog.nameOf(book),
      current: state.planOf(book),
      remainingNew: progress.fresh,
      now: state.now,
    );

    if (result == null) return;

    await controller.setPlan(book, result.remove ? null : result.plan);
  }

  Future<void> _togglePause(BookPlan plan) {
    return controller.setPlan(book, plan.copyWith(paused: !plan.paused));
  }

  // ---------- Einzelne Perikope ----------

  Future<void> _editPrecision(BookPericope p) async {
    final counter = await controller.verseCounter(p.book);

    if (!mounted) return;

    final result = await showPrecisionDialog(
      context,
      pericope: p,
      current: state.precisionOf(p),
      verseCount: counter,
    );

    if (result == null) return;

    await controller.setPrecision(p, result.reset ? null : result.precision);
  }

  Future<void> _openPericope(BookPericope p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PericopeSheet(state: state, pericope: p),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case "study":
        await _study(
          controller.fixedSession(
            StudyMode.selection,
            controller.planner().single(p),
          ),
          title: p.title,
        );
      case "compare":
        await _study(
          controller.fixedSession(StudyMode.selection, [
            controller.planner().compareOrRecall(p),
          ]),
          title: p.title,
        );
      case "read":
        final passage = passageOfPericope(controller, p);

        if (passage != null) {
          await openPassage(context, controller, passage, title: p.title);
        }
      case "precision":
        await _editPrecision(p);
      case "reset":
        await controller.setPrecision(p, null);
    }
  }

  // ---------- Aufbau ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final progress = state.progressOf(pericopes);

        return Scaffold(
          appBar: AppBar(
            title: Text(BookCatalog.nameOf(book)),
            actions: [
              IconButton(
                key: const ValueKey("book-read"),
                tooltip: "Im Bibel-Reader lesen",
                icon: const Icon(Icons.auto_stories_rounded),
                onPressed: () {
                  final passage = passageOfBook(book);

                  if (passage != null) {
                    openPassage(
                      context,
                      controller,
                      passage,
                      title: BookCatalog.nameOf(book),
                    );
                  }
                },
              ),
              BookLearningSettingsButton(controller: controller),
            ],
          ),
          body: ListView(
            key: const ValueKey("book-detail-list"),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LearningProgressSummary(progress: progress),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                          ),
                          label: const Text("Wie entsteht der Status?"),
                          onPressed: () => showStatusRulesDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildPlanCard(context, state.planOf(book), progress),
              if (state.knowledge.ofBook(book).isNotEmpty)
                KnowledgeBookCard(controller: controller, book: book),
              ..._buildSections(context),
              const SectionTitle("Weitere Lernmöglichkeiten"),
              _buildModes(context),
              const SectionTitle("Kapitel"),
              _buildChapterGrid(context),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final current = state.currentSection(outline);

    final String? note = outline.automatic
        ? "Für dieses Buch ist noch keine Gliederung hinterlegt; die "
              "Abschnitte sind automatisch nach Kapiteln gebildet."
        : outline.provisional
        ? (outline.note ?? "Vorläufige Gliederung.")
        : outline.note;

    return [
      SectionTitle(
        "Abschnitte",
        trailing: outline.provisional
            ? StatusPill(
                key: const ValueKey("outline-provisional"),
                label: "vorläufig",
                color: context.colors.accent,
              )
            : null,
      ),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            note,
            key: const ValueKey("outline-note"),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ),
      for (final section in outline.sections)
        _SectionCard(
          key: ValueKey("section-${section.id}"),
          section: section,
          progress: state.progressOfSection(section),
          knowledge: state.knowledgeProgressOf(
            state.active(controller.knowledgeOfSection(section)),
          ),
          current: section.id == current?.id,
          onTap: () => _openSection(section),
          onLearn: () => _learnSection(section),
        ),
    ];
  }

  /// Weitere, klar verschiedene Lernmöglichkeiten. Gemischtes Wiederholen
  /// und schwierige Perikopen braucht es nicht als eigene Modi: Jede
  /// Lerneinheit wählt nach Lernbedarf und Fälligkeit, gezielt Fälliges und
  /// kürzlich Falsches gibt es unter „Wiederholungen“.
  Widget _buildModes(BuildContext context) {
    final due =
        state.progressOf(pericopes).due +
        state.dueKnowledge(state.active(state.knowledge.ofBook(book))).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey("mode-chapter"),
          icon: const Icon(Icons.view_agenda_outlined),
          label: const Text("Kapitel oder Bereich"),
          onPressed: _chapterTraining,
        ),
        OutlinedButton.icon(
          key: const ValueKey("mode-review"),
          icon: const Icon(Icons.schedule_rounded),
          label: Text(
            due > 0 ? "Wiederholungen ($due fällig)" : "Wiederholungen",
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReviewOverviewScreen(controller: controller, book: book),
            ),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey("mode-order"),
          icon: const Icon(Icons.format_list_numbered_rounded),
          label: const Text("Reihenfolge lernen"),
          onPressed: _order,
        ),
        OutlinedButton.icon(
          key: const ValueKey("mode-exam"),
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text("Prüfung"),
          onPressed: _exam,
        ),
      ],
    );
  }

  /// Ein kleines Feld je Kapitel: Farbe nach Fortschritt, Antippen lernt
  /// das Kapitel.
  Widget _buildChapterGrid(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in chapters)
          Builder(
            builder: (context) {
              final progress = state.progressOf(
                state.catalog.inChapters(book, c, c),
              );

              final color =
                  progress.total > 0 && progress.secure == progress.total
                  ? context.colors.success
                  : progress.fresh < progress.total
                  ? context.colors.primary
                  : context.colors.textSecondary;

              return Tooltip(
                message:
                    "Kapitel $c: ${progress.secure}/${progress.total} sicher"
                    "${progress.due > 0 ? ", ${progress.due} fällig" : ""}"
                    "${knowledgeCountText(state.knowledgeProgressOf(state.active(controller.knowledgeOfChapters(book, c, c))))}",
                child: InkWell(
                  key: ValueKey("chapter-$c"),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  onTap: () => _chapterTraining(chapter: c),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: progress.due > 0
                            ? context.colors.accent
                            : color.withValues(alpha: 0.5),
                        width: progress.due > 0 ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      "$c",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    BookPlan? plan,
    LearningProgress progress,
  ) {
    final now = state.now;

    final suggested = controller.planner().newToday(book);

    final String summary;

    if (plan == null) {
      summary =
          "Kein Lernplan. Eine Lerneinheit bringt die fälligen "
          "Wiederholungen und bis zu ${BookPlan.defaultDailyNew} neue "
          "Perikopen am Tag.";
    } else {
      final target = plan.targetDate;

      final required = plan.requiredPerDay(progress.fresh, now);

      summary = [
        if (plan.paused)
          "Pausiert – es werden keine neuen Perikopen vorgeschlagen.",
        "${plan.dailyNew} neue Perikopen pro Tag",
        if (target != null)
          "Ziel: ${formatDate(target)}"
              "${required != null && required > plan.dailyNew ? " (nötig: $required pro Tag)" : ""}",
      ].join("\n");
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  plan?.paused == true
                      ? Icons.pause_circle_outline_rounded
                      : Icons.flag_outlined,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Lernplan",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  key: const ValueKey("plan-edit"),
                  onPressed: _editPlan,
                  child: Text(plan == null ? "Anlegen" : "Bearbeiten"),
                ),
              ],
            ),
            Text(summary, key: const ValueKey("plan-summary")),
            const SizedBox(height: 8),
            Text(
              "Heute: ${progress.due} fällige Wiederholungen, "
              "$suggested neue Perikopen",
              key: const ValueKey("plan-today"),
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  key: const ValueKey("learn-book"),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("Lerneinheit starten"),
                  onPressed: _learnBook,
                ),
                if (plan != null)
                  OutlinedButton.icon(
                    key: const ValueKey("plan-pause"),
                    icon: Icon(
                      plan.paused
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                    ),
                    label: Text(plan.paused ? "Fortsetzen" : "Pausieren"),
                    onPressed: () => _togglePause(plan),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Abschnitt der Gliederung mit Fortschritt.
class _SectionCard extends StatelessWidget {
  final OutlineSection section;
  final LearningProgress progress;

  /// Eingeschaltete Wissensfragen des Abschnitts.
  final LearningProgress knowledge;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onLearn;

  const _SectionCard({
    super.key,
    required this.section,
    required this.progress,
    required this.knowledge,
    required this.current,
    required this.onTap,
    required this.onLearn,
  });

  @override
  Widget build(BuildContext context) {
    final done = progress.total > 0 && progress.secure == progress.total;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: current ? context.colors.primary : context.colors.divider,
          width: current ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "${section.book} ${section.rangeText}",
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (current)
                    StatusPill(
                      label: "Hier weiter",
                      color: context.colors.primary,
                    )
                  else if (done)
                    StatusPill(
                      label: "sicher",
                      color: context.colors.success,
                      icon: Icons.check_rounded,
                    ),
                  IconButton(
                    key: ValueKey("section-learn-${section.id}"),
                    tooltip: "Abschnitt lernen",
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    onPressed: onLearn,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "${progress.total} Perikopen · ${progress.secure} sicher"
                "${progress.learning > 0 ? " · ${progress.learning} in Bearbeitung" : ""}"
                "${progress.due > 0 ? " · ${progress.due} fällig" : ""}"
                "${knowledgeCountText(knowledge)}",
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              LearningProgressBar(progress: progress, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aktionen eines Abschnitts; die einzelnen Perikopen stehen eingeklappt
/// darunter (zum gezielten Üben und für Verspräzisierungen).
class _SectionSheet extends StatelessWidget {
  final BookLearningState state;
  final String book;
  final OutlineSection section;

  /// Eingeschaltete Wissensfragen des Abschnitts.
  final List<KnowledgeQuestion> knowledge;

  const _SectionSheet({
    required this.state,
    required this.book,
    required this.section,
    required this.knowledge,
  });

  @override
  Widget build(BuildContext context) {
    final members = pericopesOfSection(state.catalog, section);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            Text(
              "$book ${section.rangeText} · ${members.length} Perikopen",
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey("section-sheet-learn"),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text("Abschnitt lernen"),
              subtitle: const Text(
                "Fällige zuerst, dann die nächsten neuen Perikopen",
              ),
              onTap: () => Navigator.pop(context, "learn"),
            ),
            if (knowledge.isNotEmpty)
              ListTile(
                key: const ValueKey("section-sheet-knowledge"),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.quiz_outlined),
                title: Text("Wissensfragen zum Abschnitt (${knowledge.length})"),
                subtitle: const Text(
                  "Personen, Ereignisse, Begriffe – mit Wiederholung",
                ),
                onTap: () => Navigator.pop(context, "knowledge"),
              ),
            ListTile(
              key: const ValueKey("section-sheet-order"),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_list_numbered_rounded),
              title: const Text("Reihenfolge im Abschnitt"),
              onTap: () => Navigator.pop(context, "order"),
            ),
            ListTile(
              key: const ValueKey("section-sheet-exam"),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_turned_in_outlined),
              title: const Text("Abschnitt prüfen"),
              onTap: () => Navigator.pop(context, "exam"),
            ),
            if (passageOfSection(section) != null)
              ListTile(
                key: const ValueKey("section-sheet-read"),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_stories_rounded),
                title: const Text("Abschnitt in der Bibel lesen"),
                onTap: () => Navigator.pop(context, "read"),
              ),
            ExpansionTile(
              key: const ValueKey("section-sheet-pericopes"),
              tilePadding: EdgeInsets.zero,
              title: Text("Einzelne Perikopen (${members.length})"),
              subtitle: const Text("Gezielt üben oder versgenau festlegen"),
              children: [
                for (final p in members)
                  ListTile(
                    key: ValueKey("section-pericope-${p.key}"),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      levelIcon(state.statusOf(p).level),
                      color: levelColor(context, state.statusOf(p).level),
                      size: 20,
                    ),
                    title: Text(p.title),
                    subtitle: Text(
                      [
                        state.expectedOf(p).text,
                        if (state.isPrecise(p)) "versgenau",
                      ].join(" · "),
                    ),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Details und Aktionen einer Perikope.
class _PericopeSheet extends StatelessWidget {
  final BookLearningState state;
  final BookPericope pericope;

  const _PericopeSheet({required this.state, required this.pericope});

  @override
  Widget build(BuildContext context) {
    final p = pericope;

    final status = state.statusOf(p);

    final expected = state.expectedOf(p);

    final card = state.cardOf(p);

    final precise = state.isPrecise(p);

    final dueAt = status.dueAt;

    final listText = PericopeReference.of(p.perikope).text;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              precise
                  ? "${expected.text} (eigene Präzisierung von $listText)"
                  : expected.text,
              key: const ValueKey("sheet-reference"),
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 10),
            PericopeStatusPills(status: status, precise: precise),
            const SizedBox(height: 10),
            if (dueAt != null)
              Text(
                status.due
                    ? "Wiederholung fällig seit ${formatDate(dueAt)}"
                    : "Nächste Wiederholung: ${formatDate(dueAt)}",
              ),
            if (card != null && card.correctCount + card.wrongCount > 0)
              Text(
                "Richtig: ${card.correctCount} · Falsch: ${card.wrongCount}",
              ),
            if (status.fromEndlessQuiz)
              Text(
                "Lernstand aus dem Endlos-Quiz übernommen.",
                style: TextStyle(color: context.colors.textSecondary),
              ),
            const SizedBox(height: 12),
            if (BibleReferenceParser.passageOf(p.perikope) != null)
              ListTile(
                key: const ValueKey("sheet-read"),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_stories_rounded),
                title: const Text("Bibelstelle lesen"),
                subtitle: Text(expected.text),
                onTap: () => Navigator.pop(context, "read"),
              ),
            ListTile(
              key: const ValueKey("sheet-study"),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_rounded),
              title: Text(
                status.level == LearningLevel.fresh
                    ? "Lernen und abfragen"
                    : "Jetzt abfragen",
              ),
              onTap: () => Navigator.pop(context, "study"),
            ),
            if (status.level != LearningLevel.fresh)
              ListTile(
                key: const ValueKey("sheet-compare"),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.compare_arrows_rounded),
                title: const Text("Mit Nachbarperikopen vergleichen"),
                onTap: () => Navigator.pop(context, "compare"),
              ),
            ListTile(
              key: const ValueKey("sheet-precision"),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten_rounded),
              title: Text(
                precise ? "Präzisierung bearbeiten" : "Versgenau festlegen",
              ),
              subtitle: precise
                  ? null
                  : const Text("Optional: nur für dich, z. B. Mk 1,14-20"),
              onTap: () => Navigator.pop(context, "precision"),
            ),
            if (precise)
              ListTile(
                key: const ValueKey("sheet-reset"),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text("Präzisierung entfernen"),
                subtitle: Text("Wieder $listText abfragen"),
                onTap: () => Navigator.pop(context, "reset"),
              ),
          ],
        ),
      ),
    );
  }
}
