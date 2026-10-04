import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/memorization/memorization_text.dart';
import '../../models/prayer.dart';
import '../../services/memorization/hint_generator.dart';
import '../../services/memorization/memorization_repository.dart';
import '../../services/memorization/memorization_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import '../../widgets/memorization_widgets.dart';
import 'memorization_practice_screen.dart';

/// Ein Lerntext: Fortschritt, was heute ansteht, und alle Abschnitte.
///
/// Von hier aus bleibt eine Lernrunde bei diesem Text; ein einzelner
/// Abschnitt lässt sich gezielt üben. Die Sprachfassungen des Werks sind
/// getrennte Lerntexte mit eigenem Lernstand.
class MemorizationTextScreen extends StatefulWidget {
  final MemorizationWork work;
  final String languageCode;

  /// Vom zentralen Menü übergeben; sonst wird der Lernstand hier geladen.
  final MemorizationRepository? repository;

  const MemorizationTextScreen({
    super.key,
    required this.work,
    required this.languageCode,
    this.repository,
  });

  @override
  State<MemorizationTextScreen> createState() => _MemorizationTextScreenState();
}

class _MemorizationTextScreenState extends State<MemorizationTextScreen> {
  late final MemorizationRepository repository =
      widget.repository ?? MemorizationRepository.forCurrentUser();

  final MemorizationScheduler scheduler = MemorizationScheduler();

  late MemorizationText text = widget.work.versions.firstWhere(
    (v) => v.languageCode == widget.languageCode,
    orElse: () => widget.work.versions.first,
  );

  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failed = false;
    });

    try {
      await repository.load();

      if (!mounted) return;

      setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  void _showSaveError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Die Änderung konnte nicht gespeichert werden."),
      ),
    );
  }

  Future<void> _toggleLibrary() async {
    try {
      if (repository.contains(text.id)) {
        await repository.removeText(text.id);
      } else {
        await repository.addText(text.id);
      }
    } catch (_) {
      _showSaveError();
    }
  }

  Future<void> _practice(List<PracticeUnit> units) async {
    if (units.isEmpty) return;

    // Wer einen Text übt, lernt ihn: Er erscheint unter „Meine Texte“.
    repository.addText(text.id).catchError((Object _) {});

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemorizationPracticeScreen(repository: repository, units: units),
      ),
    );
  }

  Widget _buildLanguages() {
    final versions = widget.work.versions;

    if (versions.length < 2) {
      return Text(
        PrayerLanguages.name(text.languageCode),
        style: TextStyle(color: context.colors.textSecondary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final version in versions)
          ChoiceChip(
            key: Key("memorize_language_${version.languageCode}"),
            label: Text(PrayerLanguages.name(version.languageCode)),
            selected: version.id == text.id,
            onSelected: (_) => setState(() => text = version),
          ),
      ],
    );
  }

  Widget _buildProgress(TextProgress progress) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);

    final details = [
      for (final status in SegmentStatus.values)
        if (progress.count(status) > 0)
          "${status.label}: ${progress.count(status)}",
    ].join(" · ");

    final last = progress.lastFullRecitation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${progress.learned} / ${progress.total} Abschnitte gelernt",
          key: const Key("memorize_progress"),
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 8,
            backgroundColor: context.colors.divider,
            semanticsLabel: "Lernfortschritt",
          ),
        ),

        const SizedBox(height: 8),

        Text(details, style: secondary),

        if (progress.total > 1) ...[
          const SizedBox(height: 4),
          Text(
            last == null
                ? "Noch nicht vollständig aufgesagt"
                : "Zuletzt vollständig aufgesagt: "
                      "${relativeDay(last, scheduler.clock())}",
            style: secondary,
          ),
        ],
      ],
    );
  }

  Widget _buildToday(TextPlan plan, TextProgress progress) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);

    final parts = [
      if (plan.newSegments > 0)
        plan.newSegments == 1
            ? "1 neuer Abschnitt"
            : "${plan.newSegments} neue Abschnitte",
      if (plan.reviewSegments > 0)
        plan.reviewSegments == 1
            ? "1 Wiederholung"
            : "${plan.reviewSegments} Wiederholungen",
      if (plan.fullDue) "ganzer Text",
    ];

    final hasFresh = progress.count(SegmentStatus.fresh) > 0;
    final weak = scheduler.weakUnits(text, repository.cards);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Heute üben", style: Theme.of(context).textTheme.titleMedium),

        const SizedBox(height: 4),

        Text(
          parts.isEmpty ? "Für heute ist hier alles getan." : parts.join(" · "),
          key: const Key("memorize_today"),
          style: secondary,
        ),

        const SizedBox(height: 12),

        if (!plan.isEmpty)
          ElevatedButton(
            key: const Key("memorize_continue"),
            onPressed: () => _practice(plan.units),
            child: Text(
              progress.learned == 0 && plan.reviewSegments == 0
                  ? "Lernen beginnen"
                  : "Weiterlernen",
            ),
          )
        else if (hasFresh)
          OutlinedButton(
            key: const Key("memorize_more"),
            onPressed: () => _practice(
              scheduler
                  .planFor(
                    text,
                    repository.cards,
                    extraNew: MemorizationScheduler.dailyNew,
                  )
                  .units,
            ),
            child: const Text("Weitere Abschnitte lernen"),
          ),

        if (weak.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key("memorize_weak"),
            icon: const Icon(Icons.fitness_center_rounded),
            label: Text("Schwachstellen üben (${weak.length})"),
            onPressed: () => _practice(weak),
          ),
        ],

        const SizedBox(height: 8),

        OutlinedButton.icon(
          key: const Key("memorize_full"),
          icon: const Icon(Icons.record_voice_over_rounded),
          label: const Text("Ganzen Text aufsagen"),
          onPressed: () => _practice([scheduler.fullUnit(text)]),
        ),
      ],
    );
  }

  Widget _buildSegment(int index) {
    final segment = text.segments[index];
    final card = repository.cards[segment.id];
    final status = scheduler.status(card);

    // Begonnene Abschnitte auf ihrer Hilfestufe, neue beim Mitlesen.
    final level = HintLevel.values[card?.level ?? 0];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: Key("memorize_segment_$index"),
        leading: SegmentStatusIcon(status),
        title: Text(segment.text),
        subtitle: Text(segmentStatusLine(scheduler, card)),
        onTap: () => _practice([PracticeUnit.segment(text, index, level)]),
      ),
    );
  }

  Widget _buildContent() {
    final progress = scheduler.progress(text, repository.cards);
    final plan = scheduler.planFor(text, repository.cards);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.title, style: Theme.of(context).textTheme.headlineSmall),

        const SizedBox(height: 4),

        Text(
          widget.work.type.label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),

        const SizedBox(height: 16),

        _buildLanguages(),

        const Divider(height: 32),

        _buildProgress(progress),

        const Divider(height: 32),

        _buildToday(plan, progress),

        const Divider(height: 32),

        Text("Abschnitte", style: Theme.of(context).textTheme.titleMedium),

        const SizedBox(height: 4),

        Text(
          "Tippe einen Abschnitt an, um genau diese Stelle zu üben. Jede "
          "Übung zählt für den Lernstand; der Abstand bis zur nächsten "
          "Wiederholung wächst aber nur über mehrere Tage.",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),

        const SizedBox(height: 8),

        for (var i = 0; i < text.segments.length; i++) _buildSegment(i),
      ],
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Der Lernstand konnte nicht geladen werden.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: const Text("Erneut versuchen"),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.work.title),
        actions: [
          if (!loading && !failed)
            ListenableBuilder(
              listenable: repository,
              builder: (context, _) {
                final saved = repository.contains(text.id);

                return IconButton(
                  key: const Key("memorize_library_toggle"),
                  icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                  tooltip: saved
                      ? "Aus „Meine Texte“ entfernen"
                      : "Zu „Meine Texte“ hinzufügen",
                  onPressed: _toggleLibrary,
                );
              },
            ),
          InfoButton(
            module: AppModules.memorization,
            reportDetails: () => {
              "Text": "${widget.work.title} (${text.id})",
              "Sprache": PrayerLanguages.name(text.languageCode),
            },
          ),
        ],
      ),

      body: _buildBody(),
    );
  }
}
