import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../theme/app_theme.dart';
import 'church_history_quiz_screen.dart';
import 'church_history_widgets.dart';
import 'lecture_detail_screen.dart';
import 'timeline_view.dart';

/// Epochen der Vorlesung und die Zeitleiste aller datierten Einträge.
class EpochsScreen extends StatelessWidget {
  final ChurchHistoryData data;
  final int initialTab;

  const EpochsScreen({super.key, required this.data, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Epochen und Zeitleiste"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Epochen"),
              Tab(text: "Zeitleiste"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _EpochList(data: data),
            TimelineView(data: data),
          ],
        ),
      ),
    );
  }
}

class _EpochList extends StatelessWidget {
  final ChurchHistoryData data;

  const _EpochList({required this.data});

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ChurchHistoryPage.maxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Periodisierung nach der Vorlesung (Folie 4)",
                  style: secondary,
                ),
                for (final epoch in data.epochs)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      key: ValueKey("epoch-${epoch.id}"),
                      title: Text(epoch.title),
                      subtitle: Text(
                        "${epoch.dating.label}\n${epoch.characterization}",
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        "${data.entriesOfEpoch(epoch.id).length}",
                        style: secondary,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EpochDetailScreen(data: data, epochId: epoch.id),
                        ),
                      ),
                    ),
                  ),
                if (data.epochNote != null) SupplementBox(data.epochNote!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EpochDetailScreen extends StatelessWidget {
  final ChurchHistoryData data;
  final String epochId;

  const EpochDetailScreen({
    super.key,
    required this.data,
    required this.epochId,
  });

  @override
  Widget build(BuildContext context) {
    final epoch = data.epoch(epochId);

    if (epoch == null) {
      return const ChurchHistoryPage(
        title: "Epoche",
        children: [EmptyHint("Diese Epoche ist nicht vorhanden.")],
      );
    }

    final entries = data.entriesOfEpoch(epoch.id);
    final parts = data.course.outline.where((p) => p.epochId == epoch.id);
    final lecture = data.lectures
        .where(
          (l) => l.slides.any((s) => epoch.lectureSlides.contains(s.number)),
        )
        .firstOrNull;

    return ChurchHistoryPage(
      title: epoch.title,
      children: [
        Text(epoch.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        DatingText(epoch.dating),
        LectureQuote(
          text: "${epoch.dating.label}: ${epoch.characterization}",
          source: lecture == null
              ? "Vorlesung"
              : "${lecture.label}, ${slidesLabel(epoch.lectureSlides)}",
          onTap: lecture == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LectureDetailScreen(
                      data: data,
                      lectureId: lecture.id,
                      initialSlide: epoch.lectureSlides.first,
                    ),
                  ),
                ),
        ),
        SupplementBox(epoch.summary),

        for (final part in parts) ...[
          SectionTitle("Themen der Vorlesung (Teil ${part.part})"),
          for (final topic in part.topics)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                "${topic.number}. ${topic.title}"
                "${topic.lectureId == null ? "" : " – ${data.lecture(topic.lectureId!)!.label}"}",
                style: topic.lectureId == null
                    ? TextStyle(color: context.colors.textSecondary)
                    : null,
              ),
            ),
        ],

        const SectionTitle("Einträge"),
        if (entries.isEmpty)
          const EmptyHint(
            "Zu dieser Epoche gibt es noch keine Einträge. Sie kommen mit "
            "den Vorlesungen hinzu.",
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.timeline_rounded),
                label: const Text("Zeitleiste"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text("Zeitleiste: ${epoch.title}")),
                      body: TimelineView(data: data, epochId: epoch.id),
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.quiz_rounded),
                label: const Text("Epoche lernen"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChurchHistoryQuizScreen(
                      data: data,
                      mode: QuizMode.knowledge,
                      scope: LearningScope.epoch(epoch.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (final e in entries) EntryTile(data: data, entry: e),
        ],
      ],
    );
  }
}
