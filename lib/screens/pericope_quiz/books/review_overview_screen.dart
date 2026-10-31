import 'package:flutter/material.dart';

import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_learning_status.dart';
import '../../../quiz/books/knowledge.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';
import 'bible_passage.dart';
import 'book_settings.dart';
import 'book_study_screen.dart';
import 'book_widgets.dart';

/// Anstehende Wiederholungen aller Bücher (oder eines Buchs): überfällig,
/// heute fällig, kürzlich falsch und auf Wunsch bald fällig. Starten lässt
/// sich jede Gruppe gemischt, kapitelweise oder einzeln.
class ReviewOverviewScreen extends StatefulWidget {
  final BookLearningController controller;

  /// Nur dieses Buch; `null` = alle Bücher (buchübergreifend).
  final String? book;

  const ReviewOverviewScreen({super.key, required this.controller, this.book});

  @override
  State<ReviewOverviewScreen> createState() => _ReviewOverviewScreenState();
}

class _ReviewOverviewScreenState extends State<ReviewOverviewScreen> {
  BookLearningController get controller => widget.controller;

  bool showSoon = false;

  Iterable<BookPericope> get _scope {
    final book = widget.book;

    // „Perikopen und Gliederung“ ausgeschaltet: nur Wissensfragen.
    if (!controller.state.pericopesEnabled) return const [];

    return book == null
        ? controller.catalog.all
        : controller.catalog.pericopesOf(book);
  }

  /// Eingeschaltete Wissensfragen im Umfang (ausgeschaltet: keine).
  List<KnowledgeQuestion> get _knowledge {
    final bank = controller.state.knowledge;
    final book = widget.book;

    return controller.state.active(
      book == null ? bank.questions : bank.ofBook(book),
    );
  }

  Future<void> _start(
    List<BookPericope> list,
    String title, {
    List<KnowledgeQuestion> knowledge = const [],
  }) {
    // Jede Perikope der Liste einmal, gewichtet nach Lernbedarf und
    // Fälligkeit mit Zufall gereiht (wie im Perikopenquiz); fällige
    // Wissensfragen gleichmäßig dazwischen.
    final planner = controller.planner();

    return startStudy(
      context,
      controller: controller,
      session: controller.fixedSession(
        StudyMode.review,
        interleaveTasks(
          planner.review(list),
          planner.knowledgeReview(knowledge),
        ),
      ),
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final buckets = ReviewBuckets.of(controller.state, _scope);

        final dueNow = [
          for (final p in [...buckets.overdue, ...buckets.dueToday])
            if (controller.state.statusOf(p).due) p,
        ];

        final knowledge = _knowledge;
        final dueKnowledge = controller.state.dueKnowledge(knowledge);
        final total = dueNow.length + dueKnowledge.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.book == null
                  ? "Wiederholungen"
                  : "Wiederholungen: ${widget.book}",
            ),
            actions: [BookLearningSettingsButton(controller: controller)],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        total == 0
                            ? "Gerade ist nichts fällig."
                            : "$total Wiederholungen jetzt fällig",
                        key: const ValueKey("review-due-count"),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (knowledge.isNotEmpty)
                        Text(
                          "davon ${dueKnowledge.length} Wissensfragen",
                          key: const ValueKey("review-knowledge-count"),
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            key: const ValueKey("review-start-all"),
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text("Alle fälligen gemischt"),
                            onPressed: total == 0
                                ? null
                                : () => _start(
                                    dueNow,
                                    "Gemischte Wiederholung",
                                    knowledge: dueKnowledge,
                                  ),
                          ),
                          if (dueKnowledge.isNotEmpty)
                            OutlinedButton.icon(
                              key: const ValueKey("review-start-knowledge"),
                              icon: const Icon(Icons.quiz_outlined),
                              label: Text(
                                "Nur Wissensfragen (${dueKnowledge.length})",
                              ),
                              onPressed: () => _start(
                                const [],
                                "Wissensfragen wiederholen",
                                knowledge: dueKnowledge,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _Section(
                title: "Überfällig",
                keyName: "overdue",
                list: buckets.overdue,
                controller: controller,
                onStart: _start,
              ),
              _Section(
                title: "Heute fällig",
                keyName: "today",
                list: buckets.dueToday,
                controller: controller,
                onStart: _start,
              ),
              _Section(
                title: "Kürzlich falsch beantwortet",
                keyName: "wrong",
                list: buckets.recentlyWrong,
                controller: controller,
                onStart: _start,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey("review-show-soon"),
                contentPadding: EdgeInsets.zero,
                title: const Text("Bald fällige anzeigen"),
                subtitle: const Text("Die nächsten drei Tage"),
                value: showSoon,
                onChanged: (v) => setState(() => showSoon = v),
              ),
              if (showSoon)
                _Section(
                  title: "Bald fällig",
                  keyName: "soon",
                  list: buckets.soon,
                  controller: controller,
                  onStart: _start,
                  showDate: true,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String keyName;
  final List<BookPericope> list;
  final BookLearningController controller;
  final Future<void> Function(List<BookPericope>, String title) onStart;
  final bool showDate;

  const _Section({
    required this.title,
    required this.keyName,
    required this.list,
    required this.controller,
    required this.onStart,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    // Nach Buch und Kapitel, in Buchreihenfolge.
    final groups = <String, List<BookPericope>>{};

    final ordered = [...list]
      ..sort((a, b) {
        final books = controller.catalog.books;
        final byBook = books.indexOf(a.book).compareTo(books.indexOf(b.book));
        return byBook != 0 ? byBook : a.index.compareTo(b.index);
      });

    for (final p in ordered) {
      groups.putIfAbsent("${p.book} ${p.chapter}", () => []).add(p);
    }

    return Column(
      key: ValueKey("review-section-$keyName"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          "$title (${list.length})",
          trailing: list.isEmpty
              ? null
              : TextButton(
                  key: ValueKey("review-start-$keyName"),
                  onPressed: () => onStart(list, title),
                  child: const Text("Starten"),
                ),
        ),
        if (list.isEmpty)
          Text("—", style: TextStyle(color: context.colors.textSecondary)),
        for (final entry in groups.entries) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: ValueKey("review-chapter-$keyName-${entry.key}"),
                tooltip: "${entry.key} wiederholen",
                icon: const Icon(Icons.play_circle_outline_rounded),
                onPressed: () => onStart(entry.value, entry.key),
              ),
            ],
          ),
          for (final p in entry.value)
            _ReviewTile(
              pericope: p,
              controller: controller,
              showDate: showDate,
              onTap: () => onStart([p], p.title),
            ),
        ],
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final BookPericope pericope;
  final BookLearningController controller;
  final bool showDate;
  final VoidCallback onTap;

  const _ReviewTile({
    required this.pericope,
    required this.controller,
    required this.showDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    final status = state.statusOf(pericope);

    final dueAt = status.dueAt;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(
          levelIcon(status.level),
          color: levelColor(context, status.level),
        ),
        title: Text(pericope.title),
        subtitle: Text(
          [
            state.expectedOf(pericope).text,
            status.level.label,
            if (showDate && dueAt != null) "fällig ${formatDate(dueAt)}",
            if (status.wrongCount > 0) "${status.wrongCount}× falsch",
          ].join(" · "),
        ),
        trailing: IconButton(
          key: ValueKey("review-read-${pericope.key}"),
          tooltip: "Bibelstelle lesen",
          icon: const Icon(Icons.auto_stories_rounded),
          onPressed: () {
            final passage = passageOfPericope(controller, pericope);

            if (passage != null) {
              openPassage(context, controller, passage, title: pericope.title);
            }
          },
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Zahlen eines Buchs in einer Zeile, für die Bücherübersicht.
String bookSummary(BookLearningController controller, String book) {
  final progress = controller.state.progressOf(
    controller.catalog.pericopesOf(book),
  );

  final state = controller.state;
  final structure = state.knowledgeProgressOf(controller.structureOf(book));
  final knowledge = state.knowledgeProgressOf(
    controller.contentKnowledgeOf(book),
  );

  return [
    "${progress.total} Perikopen · ${progress.secure} sicher"
        "${progress.learning > 0 ? " · ${progress.learning} in Bearbeitung" : ""}"
        "${progress.due > 0 ? " · ${progress.due} fällig" : ""}",
    // Die anderen Lernbereiche des Buchs, nur wenn es sie gibt.
    if (structure.total > 0)
      "Gliederung ${structure.secure}/${structure.total} sicher",
    if (knowledge.total > 0)
      "Wissensfragen ${knowledge.secure}/${knowledge.total} sicher",
  ].join("\n");
}

String bookName(String book) => BookCatalog.nameOf(book);
