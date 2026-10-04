import 'package:flutter/material.dart';

import '../services/statistics/learning_statistics.dart';
import '../services/statistics/statistics_service.dart';
import '../theme/app_theme.dart';

/// Statistik-Icon für die AppBar eines Trainers; öffnet die Statistik des
/// Trainers als Bottom Sheet (wie die Streak-Detailansicht).
class StatisticsButton extends StatelessWidget {
  final String? uid;
  final StatisticsTrainer trainer;

  /// Nur für Tests; sonst [LearningStatisticsService.instance].
  final LearningStatisticsService? service;

  const StatisticsButton({
    super.key,
    required this.uid,
    required this.trainer,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bar_chart),
      tooltip: "Statistik",
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: StatisticsView(uid: uid, trainer: trainer, service: service),
          ),
        ),
      ),
    );
  }
}

/// Statistik eines Trainers: heute und die letzten sieben Kalendertage.
/// "Heute" ist immer der letzte Eintrag der 7-Tage-Übersicht.
class StatisticsView extends StatefulWidget {
  final String? uid;
  final StatisticsTrainer trainer;
  final LearningStatisticsService? service;

  const StatisticsView({
    super.key,
    required this.uid,
    required this.trainer,
    this.service,
  });

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  late final LearningStatisticsService service =
      widget.service ?? LearningStatisticsService.instance;

  late Future<void> loading;

  @override
  void initState() {
    super.initState();

    // Neu laden, um Antworten von anderen Geräten zu übernehmen.
    loading = service.load(widget.uid, refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder<void>(
            future: loading,
            builder: (context, snapshot) {
              return ListenableBuilder(
                listenable: service,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "${widget.trainer.label} – Statistik",
                      style: textTheme.titleLarge,
                    ),

                    const SizedBox(height: 16),

                    ..._content(context, snapshot),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, AsyncSnapshot<void> snapshot) {
    if (!service.isLoadedFor(widget.uid)) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }

      return [
        Text(
          "Die Statistik konnte nicht geladen werden.",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
      ];
    }

    final days = service.lastSevenDays(widget.uid, widget.trainer);

    return [
      StatisticsTodayCard(today: days.last),
      const SizedBox(height: 16),
      StatisticsWeekCard(days: days),
    ];
  }
}

/// Abschnitt "Heute".
class StatisticsTodayCard extends StatelessWidget {
  final DailyStatistics today;

  const StatisticsTodayCard({super.key, required this.today});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final tiles = [
      _StatTile(value: "${today.answered}", label: "Fragen"),
      _StatTile(
        value: "${today.correct}",
        label: "richtig",
        color: context.colors.success,
      ),
      _StatTile(
        value: "${today.wrong}",
        label: "falsch",
        color: context.colors.error,
      ),
      _StatTile(
        value: StatisticsCalculator.formatAccuracy(
          today.correct,
          today.answered,
        ),
        label: "Richtigquote",
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Heute", style: textTheme.titleMedium),

            const Divider(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                // Schmal: 2 × 2 statt vier Kacheln nebeneinander.
                if (constraints.maxWidth >= 360) {
                  return Row(
                    children: [for (final tile in tiles) Expanded(child: tile)],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: tiles[1]),
                        Expanded(child: tiles[2]),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatTile({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: textTheme.headlineSmall?.copyWith(color: color),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Abschnitt "Letzte 7 Tage": kleiner Verlauf der Fragenzahl und Tabelle
/// (auf schmalen Displays als kompakte Liste).
class StatisticsWeekCard extends StatelessWidget {
  /// Ältester Tag zuerst, der letzte Eintrag ist heute.
  final List<DailyStatistics> days;

  const StatisticsWeekCard({super.key, required this.days});

  /// Ab dieser Inhaltsbreite wird die Tabelle angezeigt.
  static const double tableMinWidth = 360;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Letzte 7 Tage", style: textTheme.titleMedium),

            const Divider(height: 20),

            ExcludeSemantics(child: _WeekBars(days: days)),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= tableMinWidth) {
                  return _table(context);
                }

                return _compactList(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _dayLabel(DailyStatistics day) {
    final date = StatisticsCalculator.parseDateKey(day.date);

    return "${StatisticsCalculator.weekdayLabel(date)} "
        "${StatisticsCalculator.shortDate(date)}";
  }

  Widget _table(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final header = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    Widget cell(String text, TextStyle? style, {int flex = 2}) {
      return Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: flex == 2 ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            cell("Tag", header, flex: 3),
            cell("Fragen", header),
            cell("Richtig", header),
            cell("Falsch", header),
            cell("Quote", header),
          ],
        ),

        const SizedBox(height: 4),

        for (final (i, day) in days.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Builder(
              builder: (context) {
                final style = i == days.length - 1
                    ? textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )
                    : textTheme.bodyMedium;

                return Row(
                  children: [
                    cell(_dayLabel(day), style, flex: 3),
                    cell("${day.answered}", style),
                    cell("${day.correct}", style),
                    cell("${day.wrong}", style),
                    cell(
                      StatisticsCalculator.formatAccuracy(
                        day.correct,
                        day.answered,
                      ),
                      style,
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _compactList(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final secondary = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, day) in days.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(day),
                        style: i == days.length - 1
                            ? textTheme.titleSmall
                            : textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      StatisticsCalculator.formatAccuracy(
                        day.correct,
                        day.answered,
                      ),
                      style: textTheme.titleSmall,
                    ),
                  ],
                ),
                Text(
                  "${day.answered} Fragen · ${day.correct} richtig · "
                  "${day.wrong} falsch",
                  style: secondary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kleiner Verlauf der täglichen Fragenzahl (ohne Bewertung).
class _WeekBars extends StatelessWidget {
  final List<DailyStatistics> days;

  const _WeekBars({required this.days});

  static const double _maxHeight = 40;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(0, (m, d) => d.answered > m ? d.answered : m);

    final label = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Column(
              children: [
                Container(
                  height: max == 0
                      ? 2
                      : (day.answered / max * _maxHeight).clamp(2, _maxHeight),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: day.answered == 0
                        ? context.colors.divider
                        : context.colors.primaryLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  StatisticsCalculator.weekdayLabel(
                    StatisticsCalculator.parseDateKey(day.date),
                  ),
                  style: label,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
