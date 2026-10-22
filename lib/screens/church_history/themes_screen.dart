import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../theme/app_theme.dart';
import 'church_history_quiz_screen.dart';
import 'church_history_widgets.dart';
import 'lecture_detail_screen.dart';
import 'timeline_view.dart';

/// Thematische Zugänge quer zur Chronologie. Es erscheinen nur Themen, zu
/// denen es Einträge gibt.
class ThemesScreen extends StatelessWidget {
  final ChurchHistoryData data;

  const ThemesScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final themes = data.usedThemes;

    return ContentPage(
      title: "Themen",
      children: [
        if (themes.isEmpty) const EmptyHint("Noch keine Themen mit Inhalten."),
        for (final theme in themes)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              key: ValueKey("theme-${theme.id}"),
              leading: Icon(Icons.hub_outlined, color: context.colors.primary),
              title: Text(theme.title),
              subtitle: Text(
                "${theme.description}\n"
                "${data.entriesOfTheme(theme.id).length} Einträge",
              ),
              isThreeLine: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ThemeDetailScreen(data: data, themeId: theme.id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ThemeDetailScreen extends StatelessWidget {
  final ChurchHistoryData data;
  final String themeId;

  const ThemeDetailScreen({
    super.key,
    required this.data,
    required this.themeId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = data.theme(themeId);

    if (theme == null) {
      return const ContentPage(
        title: "Thema",
        children: [EmptyHint("Dieses Thema ist nicht vorhanden.")],
      );
    }

    final entries = data.entriesOfTheme(theme.id);
    final lectures = [
      for (final l in data.units)
        if (l.themeIds.contains(theme.id)) l,
    ];

    return ContentPage(
      title: theme.title,
      children: [
        Text(theme.description),
        const SizedBox(height: 12),
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
                    appBar: AppBar(title: Text("Zeitleiste: ${theme.title}")),
                    body: TimelineView(data: data, themeId: theme.id),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.quiz_rounded),
              label: const Text("Thema lernen"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChurchHistoryQuizScreen(
                    data: data,
                    mode: QuizMode.knowledge,
                    scope: LearningScope.theme(theme.id),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (lectures.isNotEmpty) ...[
          const ContentSectionTitle("In den Veranstaltungen"),
          for (final l in lectures)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text("${l.label}: ${l.title}"),
              subtitle: Text(l.kind.label),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LectureDetailScreen(data: data, lectureId: l.id),
                ),
              ),
            ),
        ],
        for (final type in EntryType.values)
          if (entries.any((e) => e.type == type)) ...[
            ContentSectionTitle(type.plural),
            for (final e in entries.where((e) => e.type == type))
              EntryTile(data: data, entry: e),
          ],
      ],
    );
  }
}
