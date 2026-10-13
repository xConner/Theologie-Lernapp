import 'package:flutter/material.dart';

import 'grammar_topics/grammar_topics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/grammar_overview_widgets.dart';

class GrammarOverviewScreen extends StatelessWidget {
  const GrammarOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GrammarTopicScaffold(
      title: "Grammatikübersicht",
      children: [
        for (final group in GrammarTopics.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(group.title, style: textTheme.titleLarge),
          ),

          for (final topic in group.topics)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(topic.title, style: textTheme.titleMedium),
                subtitle: Text(
                  topic.subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: topic.builder),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
