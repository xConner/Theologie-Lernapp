import 'package:flutter/material.dart';

import '../algorithms/review_state.dart';
import '../theme/app_theme.dart';

/// Verteilung der Lernstände eines Umfangs ([ReviewState]); gemeinsam für
/// Kirchengeschichte, Altes Testament und den Latein-Lernplan.
class ProgressSummaryTile extends StatelessWidget {
  final String title;
  final ProgressSummary summary;
  final VoidCallback? onReset;

  const ProgressSummaryTile({
    super.key,
    required this.title,
    required this.summary,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color colorOf(ReviewState s) => switch (s) {
      ReviewState.fresh => colors.divider,
      ReviewState.due => colors.accent,
      ReviewState.stable => colors.success,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (onReset != null)
                  IconButton(
                    tooltip: "Zurücksetzen",
                    icon: const Icon(Icons.restart_alt_rounded),
                    onPressed: onReset,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (summary.total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    for (final s in ReviewState.values)
                      if (summary.count(s) > 0)
                        Expanded(
                          flex: summary.count(s),
                          child: Container(height: 8, color: colorOf(s)),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                for (final s in ReviewState.values)
                  Text(
                    "${s.label}: ${summary.count(s)}",
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
