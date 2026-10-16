import 'package:flutter/material.dart';

import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_learning_status.dart';
import '../../../quiz/books/book_plan.dart';
import '../../../quiz/pericope_reference.dart';
import '../../../theme/app_theme.dart';
import 'book_dialogs.dart';
import 'book_study_screen.dart';
import 'book_widgets.dart';
import 'precision_dialog.dart';

/// Ein Buch: Fortschritt, Lernplan, Lernmodi und die Fortschrittskarte aller
/// Perikopen nach Kapiteln.
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

enum _LevelFilter { all, fresh, learning, secure }

class _BookDetailScreenState extends State<BookDetailScreen> {
  BookLearningController get controller => widget.controller;

  BookLearningState get state => controller.state;

  String get book => widget.book;

  int? chapterFilter;

  _LevelFilter levelFilter = _LevelFilter.all;

  bool dueOnly = false;

  bool selecting = false;

  final Set<BookPericope> selected = {};

  List<BookPericope> get pericopes => state.catalog.pericopesOf(book);

  List<int> get chapters => state.catalog.chaptersOf(book);

  bool _matches(BookPericope p) {
    if (chapterFilter != null && p.chapter != chapterFilter) return false;

    final status = state.statusOf(p);

    if (dueOnly && !status.due) return false;

    switch (levelFilter) {
      case _LevelFilter.all:
        return true;
      case _LevelFilter.fresh:
        return status.level == LearningLevel.fresh;
      case _LevelFilter.learning:
        return status.level == LearningLevel.learning;
      case _LevelFilter.secure:
        return status.level == LearningLevel.secure;
    }
  }

  Future<void> _study(StudyMode mode, List<StudyTask> tasks, {String? title}) {
    return startStudy(
      context,
      controller: controller,
      mode: mode,
      tasks: tasks,
      title: title,
    );
  }

  // ---------- Lernmodi ----------

  Future<void> _learnBook() {
    return _study(
      StudyMode.learnBook,
      controller.planner().learnBook(book),
      title: "${BookCatalog.nameOf(book)} lernen",
    );
  }

  Future<void> _chapterTraining({int? chapter}) async {
    final range = chapter != null
        ? (chapter, chapter)
        : await showChapterRangeDialog(
            context,
            title: "Kapiteltraining",
            chapters: chapters,
            initial: chapterFilter == null
                ? null
                : (chapterFilter!, chapterFilter!),
          );

    if (range == null || !mounted) return;

    await _study(
      StudyMode.chapter,
      controller.planner().chapter(book, range.$1, range.$2),
      title: "$book ${_rangeText(range)}",
    );
  }

  String _rangeText((int, int) range) =>
      range.$1 == range.$2 ? "${range.$1}" : "${range.$1}–${range.$2}";

  Future<void> _mixed() {
    return _study(StudyMode.mixed, controller.planner().mixed(pericopes));
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
      StudyMode.order,
      controller.planner().order(
        state.catalog.inChapters(book, range.$1, range.$2),
      ),
    );
  }

  Future<void> _difficult() {
    return _study(
      StudyMode.difficult,
      controller.planner().difficult(pericopes),
    );
  }

  Future<void> _exam() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Prüfung"),
        children: [
          SimpleDialogOption(
            key: const ValueKey("exam-book"),
            onPressed: () => Navigator.pop(context, "book"),
            child: Text("Ganzes Buch (${pericopes.length} Perikopen)"),
          ),
          SimpleDialogOption(
            key: const ValueKey("exam-chapters"),
            onPressed: () => Navigator.pop(context, "chapters"),
            child: const Text("Kapitel oder Kapitelbereich"),
          ),
          SimpleDialogOption(
            key: const ValueKey("exam-selection"),
            onPressed: () => Navigator.pop(context, "selection"),
            child: const Text("Perikopen selbst auswählen"),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case "book":
        await _study(
          StudyMode.exam,
          controller.planner().exam(pericopes),
          title: BookCatalog.nameOf(book),
        );
      case "chapters":
        final range = await showChapterRangeDialog(
          context,
          title: "Prüfung: Kapitel",
          chapters: chapters,
        );

        if (range == null || !mounted) return;

        await _study(
          StudyMode.exam,
          controller.planner().exam(
            state.catalog.inChapters(book, range.$1, range.$2),
          ),
          title: "$book ${_rangeText(range)}",
        );
      case "selection":
        setState(() => selecting = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Wähle die Perikopen aus und tippe dann auf „Prüfen“.",
            ),
          ),
        );
    }
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
          StudyMode.selection,
          controller.planner().selection([p]),
          title: p.title,
        );
      case "compare":
        await _study(StudyMode.selection, [
          controller.planner().compareOrRecall(p),
        ], title: p.title);
      case "precision":
        await _editPrecision(p);
      case "reset":
        await controller.setPrecision(p, null);
    }
  }

  void _toggleSelected(BookPericope p) {
    setState(() {
      if (!selected.remove(p)) selected.add(p);
    });
  }

  List<BookPericope> get _selectedInOrder => [
    for (final p in pericopes)
      if (selected.contains(p)) p,
  ];

  // ---------- Aufbau ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = pericopes.where(_matches).toList();

        final rows = <Object>[];

        int? lastChapter;

        for (final p in visible) {
          if (p.chapter != lastChapter) {
            rows.add(p.chapter);
            lastChapter = p.chapter;
          }

          rows.add(p);
        }

        final header = _buildHeader(context, visible.length);

        return Scaffold(
          appBar: AppBar(
            title: Text(BookCatalog.nameOf(book)),
            actions: [
              IconButton(
                tooltip: selecting ? "Auswahl beenden" : "Perikopen auswählen",
                icon: Icon(
                  selecting ? Icons.close_rounded : Icons.checklist_rounded,
                ),
                onPressed: () => setState(() {
                  selecting = !selecting;
                  selected.clear();
                }),
              ),
            ],
          ),
          body: ListView.builder(
            key: const ValueKey("book-detail-list"),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: header.length + rows.length + (rows.isEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              if (i < header.length) return header[i];

              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "Keine Perikopen für diesen Filter.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                );
              }

              final row = rows[i - header.length];

              if (row is int) return _buildChapterHeader(context, row);

              return _buildPericope(context, row as BookPericope);
            },
          ),
          bottomNavigationBar: selecting ? _buildSelectionBar(context) : null,
        );
      },
    );
  }

  List<Widget> _buildHeader(BuildContext context, int visibleCount) {
    final progress = state.progressOf(pericopes);

    final plan = state.planOf(book);

    final difficultCount = pericopes.where((p) {
      final s = state.statusOf(p);
      return s.difficult || s.recentlyWrong;
    }).length;

    return [
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
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text("Wie entsteht der Status?"),
                  onPressed: () => showStatusRulesDialog(context),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildPlanCard(context, plan, progress),
      SectionTitle("Lernmodi"),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const ValueKey("mode-chapter"),
            icon: const Icon(Icons.view_agenda_outlined),
            label: const Text("Kapiteltraining"),
            onPressed: _chapterTraining,
          ),
          OutlinedButton.icon(
            key: const ValueKey("mode-mixed"),
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text("Gemischte Wiederholung"),
            onPressed: _mixed,
          ),
          OutlinedButton.icon(
            key: const ValueKey("mode-order"),
            icon: const Icon(Icons.format_list_numbered_rounded),
            label: const Text("Reihenfolge lernen"),
            onPressed: _order,
          ),
          OutlinedButton.icon(
            key: const ValueKey("mode-difficult"),
            icon: const Icon(Icons.priority_high_rounded),
            label: Text("Schwierige Perikopen ($difficultCount)"),
            onPressed: difficultCount == 0 ? null : _difficult,
          ),
          OutlinedButton.icon(
            key: const ValueKey("mode-exam"),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text("Prüfung"),
            onPressed: _exam,
          ),
        ],
      ),
      SectionTitle("Perikopen ($visibleCount)"),
      _buildFilters(context),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildPlanCard(
    BuildContext context,
    BookPlan? plan,
    LearningProgress progress,
  ) {
    final now = state.now;

    final suggested = controller.planner().suggestedNew(book).length;

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

  Widget _buildFilters(BuildContext context) {
    ChoiceChip level(String label, _LevelFilter value) {
      return ChoiceChip(
        key: ValueKey("filter-${value.name}"),
        label: Text(label),
        selected: levelFilter == value,
        onSelected: (_) => setState(() => levelFilter = value),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: const InputDecoration(labelText: "Kapitel"),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              key: const ValueKey("filter-chapter"),
              value: chapterFilter,
              isExpanded: true,
              isDense: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("Alle Kapitel"),
                ),
                for (final c in chapters)
                  DropdownMenuItem<int?>(value: c, child: Text("Kapitel $c")),
              ],
              onChanged: (v) => setState(() => chapterFilter = v),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            level("Alle", _LevelFilter.all),
            level("Neu", _LevelFilter.fresh),
            level("In Bearbeitung", _LevelFilter.learning),
            level("Sicher", _LevelFilter.secure),
            FilterChip(
              key: const ValueKey("filter-due"),
              label: const Text("Nur fällige"),
              selected: dueOnly,
              onSelected: (v) => setState(() => dueOnly = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChapterHeader(BuildContext context, int chapter) {
    final inChapter = [
      for (final p in pericopes)
        if (p.chapter == chapter) p,
    ];

    final progress = state.progressOf(inChapter);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kapitel $chapter",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${progress.secure}/${progress.total} sicher"
                  "${progress.due > 0 ? " · ${progress.due} fällig" : ""}",
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                LearningProgressBar(progress: progress, height: 5),
              ],
            ),
          ),
          IconButton(
            key: ValueKey("chapter-train-$chapter"),
            tooltip: "Kapitel $chapter trainieren",
            icon: const Icon(Icons.play_circle_outline_rounded),
            onPressed: () => _chapterTraining(chapter: chapter),
          ),
        ],
      ),
    );
  }

  Widget _buildPericope(BuildContext context, BookPericope p) {
    final status = state.statusOf(p);

    final expected = state.expectedOf(p);

    final precise = state.isPrecise(p);

    final color = levelColor(context, status.level);

    return Card(
      key: ValueKey("pericope-${p.key}"),
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        side: BorderSide(
          color: status.due
              ? context.colors.accent.withValues(alpha: 0.7)
              : context.colors.divider,
          width: status.due ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        onTap: selecting ? () => _toggleSelected(p) : () => _openPericope(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selecting)
                Checkbox(
                  value: selected.contains(p),
                  onChanged: (_) => _toggleSelected(p),
                )
              else
                Icon(levelIcon(status.level), color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expected.text,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    PericopeStatusPills(status: status, precise: precise),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final list = _selectedInOrder;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "${list.length} ausgewählt",
                key: const ValueKey("selection-count"),
              ),
            ),
            TextButton(
              key: const ValueKey("selection-learn"),
              onPressed: list.isEmpty
                  ? null
                  : () => _study(
                      StudyMode.selection,
                      controller.planner().selection(list),
                    ),
              child: const Text("Lernen"),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              key: const ValueKey("selection-exam"),
              onPressed: list.isEmpty
                  ? null
                  : () => _study(
                      StudyMode.exam,
                      controller.planner().exam(list),
                      title: "Auswahl",
                    ),
              child: const Text("Prüfen"),
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
