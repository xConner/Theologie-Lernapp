import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../theme/app_theme.dart';
import 'church_history_quiz_screen.dart';
import 'church_history_widgets.dart';
import 'lecture_detail_screen.dart';

/// Vorlesungen mit Folien und die Gliederung der Vorlesung. Themen der
/// Gliederung ohne Folien sind als solche gekennzeichnet.
class LecturesScreen extends StatelessWidget {
  final ChurchHistoryData data;

  const LecturesScreen({super.key, required this.data});

  void _open(BuildContext context, String lectureId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LectureDetailScreen(data: data, lectureId: lectureId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = TextStyle(color: context.colors.textSecondary);

    return ChurchHistoryPage(
      title: "Vorlesungen",
      children: [
        Text(data.course.title, style: textTheme.titleLarge),
        Text(data.course.lecturer, style: secondary),

        const SectionTitle("Vorlesungen mit Folien"),
        if (data.lectures.isEmpty)
          const EmptyHint("Noch keine Vorlesungsfolien hinterlegt."),
        for (final l in data.lectures)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              key: ValueKey("lecture-${l.id}"),
              leading: CircleAvatar(child: Text("${l.number}")),
              title: Text(l.title),
              subtitle: Text(
                "${l.slides.length} Folien · ${l.entryIds.length} Einträge · "
                "${l.questions.length + l.lists.length} Lernaufgaben",
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(context, l.id),
            ),
          ),
        if (data.lectures.length > 1) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey("learn-all-lectures"),
            icon: const Icon(Icons.replay_rounded),
            label: const Text("Alle bisherigen Vorlesungen wiederholen"),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChurchHistoryQuizScreen(
                  data: data,
                  mode: QuizMode.knowledge,
                  scope: LearningScope.allLectures,
                ),
              ),
            ),
          ),
        ],

        const SectionTitle("Gliederung der Vorlesung"),
        Text(
          "Nach den Folien 6 und 7. Themen mit Folien lassen sich öffnen; "
          "für die übrigen sind noch keine Folien hinterlegt.",
          style: secondary,
        ),
        for (final part in data.course.outline) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              "${part.part}. ${part.title}",
              style: textTheme.titleMedium,
            ),
          ),
          for (final topic in part.topics)
            ListTile(
              dense: true,
              leading: Text(
                "${topic.number}.",
                style: textTheme.bodyLarge?.copyWith(
                  color: topic.lectureId == null
                      ? context.colors.textSecondary
                      : null,
                ),
              ),
              title: Text(
                topic.title,
                style: topic.lectureId == null ? secondary : null,
              ),
              subtitle: topic.lectureId == null
                  ? const Text("noch keine Folien")
                  : Text(data.lecture(topic.lectureId!)!.label),
              trailing: topic.lectureId == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: topic.lectureId == null
                  ? null
                  : () => _open(context, topic.lectureId!),
            ),
        ],
      ],
    );
  }
}
