import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bible_reading.dart';
import '../../models/bible/bible_translation.dart';
import '../../models/bible/reading_plan.dart';
import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/bible_repository.dart';
import '../../services/bible/reading_plan_codec.dart';
import '../../theme/app_theme.dart';
import '../../utils/text_file.dart';
import '../../widgets/bible/bible_reading_widgets.dart';

/// Ein Leseplan: Dauer und Inhalt, Beginnen, Pausieren, Fortsetzen und
/// Beenden, der aktuelle Tag und alle Tage mit ihren Lesungen.
class ReadingPlanDetailScreen extends StatefulWidget {
  /// null = Gast.
  final String? uid;

  final String planId;

  // Nur für Tests ersetzbar.
  final BibleReadingService? service;
  final BibleRepository? repository;

  const ReadingPlanDetailScreen({
    super.key,
    required this.uid,
    required this.planId,
    this.service,
    this.repository,
  });

  @override
  State<ReadingPlanDetailScreen> createState() =>
      _ReadingPlanDetailScreenState();
}

class _ReadingPlanDetailScreenState extends State<ReadingPlanDetailScreen> {
  late final BibleReadingService service =
      widget.service ?? BibleReadingService.instance;

  List<BibleTranslation> translations = const [];

  String? get uid => widget.uid;

  @override
  void initState() {
    super.initState();

    service.load(uid);

    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    try {
      final loaded = await (widget.repository ?? BibleRepository.instance)
          .translations();

      if (mounted) setState(() => translations = loaded);
    } catch (_) {
      // Ohne die Ausgaben fehlt nur die Angabe des täglichen Umfangs.
    }
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            key: const ValueKey("plan-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _start(ReadingPlan plan) async {
    final extent = plan.extentIn(translations);

    final extreme =
        extent.isExtreme || plan.difficulty == ReadingPlanDifficulty.extreme;

    final intensive =
        extreme ||
        extent.isIntensive ||
        plan.difficulty == ReadingPlanDifficulty.intensive;

    // Vor sehr intensiven Plänen den täglichen Umfang ausdrücklich nennen.
    if (intensive &&
        !await _confirm(
          title: "Diesen Plan beginnen?",
          text: translations.isEmpty
              ? "Dieser Plan ist sehr intensiv."
              : PlanFacts.intensityWarning(extent, extreme: extreme),
          action: "Trotzdem beginnen",
        )) {
      return;
    }

    await service.startPlan(uid, plan.id);
  }

  Future<void> _end(ReadingPlan plan) async {
    if (!await _confirm(
      title: "Plan beenden?",
      text:
          "Dein Fortschritt in „${plan.name}“ wird gelöscht. Leseverlauf "
          "und Bibellese-Streak bleiben erhalten.",
      action: "Beenden",
    )) {
      return;
    }

    await service.endPlan(uid, plan.id);
  }

  Future<void> _delete(ReadingPlan plan) async {
    if (!await _confirm(
      title: "Plan löschen?",
      text:
          "„${plan.name}“ und dein Fortschritt darin werden gelöscht. "
          "Exportiere den Plan vorher, wenn du ihn behalten möchtest.",
      action: "Löschen",
    )) {
      return;
    }

    await service.deletePlan(uid, plan.id);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _export(ReadingPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final content = ReadingPlanCodec.encode(plan);

    if (textFilesSupported) {
      saveTextFile("${plan.id}.json", content);

      return;
    }

    await Clipboard.setData(ClipboardData(text: content));

    messenger.showSnackBar(
      const SnackBar(
        content: Text("Der Plan wurde als JSON in die Zwischenablage kopiert."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final plan = service.plan(widget.planId);

        return Scaffold(
          appBar: AppBar(
            title: Text(plan?.name ?? "Leseplan"),
            actions: [
              if (plan != null)
                PopupMenuButton<String>(
                  key: const ValueKey("plan-menu"),
                  tooltip: "Mehr",
                  onSelected: (value) {
                    switch (value) {
                      case "export":
                        _export(plan);
                      case "delete":
                        _delete(plan);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: "export",
                      child: Text("Als JSON exportieren"),
                    ),
                    if (!plan.builtIn)
                      const PopupMenuItem(
                        value: "delete",
                        child: Text("Plan löschen"),
                      ),
                  ],
                ),
            ],
          ),
          body: plan == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("Dieser Leseplan ist nicht verfügbar."),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _content(context, plan),
                  ),
                ),
        );
      },
    );
  }

  Widget _content(BuildContext context, ReadingPlan plan) {
    final progress = service.progressOf(uid, plan.id);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(child: _header(context, plan, progress)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.builder(
            itemCount: plan.dayCount,
            itemBuilder: (context, index) =>
                _day(context, plan, progress, index + 1),
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    ReadingPlan plan,
    ReadingPlanProgress? progress,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );

    final day = progress?.currentDay(plan);

    final source = [
      ?plan.sourceName,
      ?plan.sourceUrl,
      ?plan.sourceNote,
    ].join(" · ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.description.isNotEmpty) ...[
          Text(plan.description, style: textTheme.bodyLarge),
          const SizedBox(height: 10),
        ],

        PlanFacts(plan: plan, translations: translations, detailed: true),

        if (source.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text("Quelle: $source", style: secondary),
        ],

        if (plan.license != null) ...[
          const SizedBox(height: 4),
          Text("Lizenz: ${plan.license}", style: secondary),
        ],

        const SizedBox(height: 16),

        if (!service.isLoaded(uid))
          Text(
            "Dein Fortschritt konnte nicht geladen werden.",
            style: TextStyle(color: context.colors.textSecondary),
          )
        else if (progress == null)
          FilledButton.icon(
            key: const ValueKey("plan-start"),
            onPressed: () => _start(plan),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text("Plan beginnen"),
          )
        else ...[
          PlanProgressBar(plan: plan, progress: progress),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (day != null)
                OutlinedButton.icon(
                  key: const ValueKey("plan-pause"),
                  onPressed: () =>
                      service.setPaused(uid, plan.id, !progress.paused),
                  icon: Icon(
                    progress.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  label: Text(progress.paused ? "Fortsetzen" : "Pausieren"),
                ),
              OutlinedButton.icon(
                key: const ValueKey("plan-end"),
                onPressed: () => _end(plan),
                icon: const Icon(Icons.stop_rounded),
                label: const Text("Beenden"),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            progress.paused
                ? "Der Plan ist pausiert. Dein Fortschritt bleibt erhalten; "
                      "nach dem Fortsetzen geht es bei Tag ${day ?? 1} weiter."
                : day == null
                ? "Du hast alle Lesungen dieses Plans erledigt."
                : "Aktuell: Tag $day von ${plan.dayCount}. Die Reihenfolge "
                      "der Lesungen ist frei.",
            key: const ValueKey("plan-status"),
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],

        const Divider(height: 32),
      ],
    );
  }

  Widget _day(
    BuildContext context,
    ReadingPlan plan,
    ReadingPlanProgress? progress,
    int day,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final complete = progress?.isDayComplete(plan, day) ?? false;
    final current = progress != null && progress.currentDay(plan) == day;

    final title = plan.days[day - 1].title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ["Tag $day", ?title, if (current) "aktuell"].join(" · "),
                  style: current
                      ? textTheme.titleSmall?.copyWith(
                          color: context.colors.accent,
                        )
                      : textTheme.titleSmall,
                ),
              ),
              if (complete)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: context.colors.success,
                ),
            ],
          ),
          PlanDayReadings(
            uid: uid,
            plan: plan,
            day: day,
            service: service,
            repository: widget.repository,
          ),
        ],
      ),
    );
  }
}
