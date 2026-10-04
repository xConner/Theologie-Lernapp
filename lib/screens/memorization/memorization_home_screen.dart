import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/memorization/memorization_text.dart';
import '../../models/prayer.dart';
import '../../services/memorization/memorization_catalog.dart';
import '../../services/memorization/memorization_daily_goal.dart';
import '../../services/memorization/memorization_repository.dart';
import '../../services/memorization/memorization_scheduler.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import '../../widgets/memorization_widgets.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/streak_widgets.dart';
import 'memorization_practice_screen.dart';
import 'memorization_text_screen.dart';

/// Zentrales Menü „Texte auswendig lernen“: was heute zur Wiederholung ansteht
/// und die eigenen Lerntexte.
class MemorizationHomeScreen extends StatefulWidget {
  /// Für Tests austauschbar.
  final MemorizationRepository? repository;
  final Future<MemorizationCatalog>? catalog;

  const MemorizationHomeScreen({super.key, this.repository, this.catalog});

  @override
  State<MemorizationHomeScreen> createState() => _MemorizationHomeScreenState();
}

class _MemorizationHomeScreenState extends State<MemorizationHomeScreen> {
  late final MemorizationRepository repository =
      widget.repository ?? MemorizationRepository.forCurrentUser();

  final MemorizationScheduler scheduler = MemorizationScheduler();

  MemorizationCatalog? catalog;

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
      final results = await Future.wait([
        widget.catalog ?? MemorizationCatalog.load(),
        repository.load(),
      ]);

      if (!mounted) return;

      setState(() {
        catalog = results[0] as MemorizationCatalog;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  /// „Meine Texte“, soweit sie in den Daten der App (noch) vorhanden sind.
  List<MemorizationText> get _myTexts {
    return [
      for (final id in repository.textIds)
        if (catalog!.text(id) != null) catalog!.text(id)!,
    ];
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Die Änderung konnte nicht gespeichert werden."),
        ),
      );
    }
  }

  void _openText(MemorizationText text) {
    final work = catalog!.workOf(text);

    if (work == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemorizationTextScreen(
          work: work,
          languageCode: text.languageCode,
          repository: repository,
        ),
      ),
    );
  }

  void _practice(List<PracticeUnit> units) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemorizationPracticeScreen(repository: repository, units: units),
      ),
    );
  }

  void _addTexts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemorizationAddTextScreen(
          catalog: catalog!,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _remove(MemorizationText text) async {
    await _guard(() => repository.removeText(text.id));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "„${text.workTitle}“ entfernt. Der Lernstand bleibt erhalten.",
        ),
      ),
    );
  }

  TextStyle? get _secondary => Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);

  Widget _buildToday(List<TextPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Heute", style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 4),

        Text(
          plans.isEmpty
              ? "Für heute ist alles wiederholt."
              : plans.length == 1
              ? "1 Text zur Wiederholung"
              : "${plans.length} Texte zur Wiederholung",
          key: const Key("memorize_today_summary"),
          style: _secondary,
        ),

        if (plans.isNotEmpty) ...[
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                for (final plan in plans)
                  ListTile(
                    key: Key("memorize_today_${plan.text.id}"),
                    title: Text(plan.text.workTitle),
                    subtitle: Text(
                      PrayerLanguages.name(plan.text.languageCode),
                    ),
                    trailing: Text(
                      plan.segmentCount > 0
                          ? segmentCountLabel(plan.segmentCount)
                          : "Ganzer Text",
                    ),
                    onTap: () => _openText(plan.text),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          ElevatedButton(
            key: const Key("memorize_today_start"),
            onPressed: () =>
                _practice([for (final plan in plans) ...plan.units]),
            child: const Text("Heute lernen"),
          ),
        ],
      ],
    );
  }

  Widget _buildText(MemorizationText text) {
    final progress = scheduler.progress(text, repository.cards);
    final active = repository.isActive(text.id);

    return Card(
      child: ListTile(
        key: Key("memorize_text_${text.id}"),
        title: Text(text.workTitle),
        subtitle: Text(
          "${PrayerLanguages.name(text.languageCode)} · "
          "${progress.learned} / ${progress.total} Abschnitte gelernt"
          "${active ? "" : " · pausiert"}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: "Wiederholung aktiv",
              child: Switch(
                value: active,
                onChanged: (value) =>
                    _guard(() => repository.setActive(text.id, value)),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: "Weitere Aktionen",
              onSelected: (_) => _remove(text),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "remove",
                  child: Text("Aus „Meine Texte“ entfernen"),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _openText(text),
      ),
    );
  }

  Widget _buildContent() {
    final texts = _myTexts;

    final plans = [
      for (final text in texts)
        if (repository.isActive(text.id))
          scheduler.planFor(text, repository.cards),
    ].where((plan) => !plan.isEmpty).toList();

    final goal = MemorizationDailyGoal.forRepository(
      scheduler,
      catalog!,
      repository,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (texts.isEmpty) ...[
          Text(
            "Lerne Gebete und Bekenntnisse Schritt für Schritt auswendig: "
            "vom Mitlesen über Lücken und Anfangsbuchstaben bis zum freien "
            "Aufsagen.",
            style: Theme.of(context).textTheme.bodyLarge,
          ),

          const SizedBox(height: 8),

          Text(
            "Wähle zuerst einen Text aus. Er wird in Abschnitte geteilt, die "
            "du einzeln lernst, verbindest und in wachsenden Abständen "
            "wiederholst.",
            style: _secondary,
          ),
        ] else ...[
          StreakDetailCard(
            uid: repository.uid,
            track: StreakTrack.memorization,
            todayDone: goal.done,
            todayGoal: goal.total,
          ),

          const SizedBox(height: 24),

          _buildToday(plans),

          const Divider(height: 40),

          Text("Meine Texte", style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 4),

          Text(
            "Nur eingeschaltete Texte erscheinen unter „Heute“.",
            style: _secondary,
          ),

          const SizedBox(height: 4),

          for (final text in texts) _buildText(text),
        ],

        const SizedBox(height: 16),

        OutlinedButton.icon(
          key: const Key("memorize_add"),
          icon: const Icon(Icons.add_rounded),
          label: const Text("Text hinzufügen"),
          onPressed: _addTexts,
        ),
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
                "Die Lerntexte konnten nicht geladen werden.",
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
        // Der Titel ist länger als der Platz neben den Aktionen auf schmalen
        // Geräten; verkleinern statt abschneiden.
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("Texte auswendig lernen"),
        ),
        actions: const [
          InfoButton(module: AppModules.memorization),
          SettingsButton(),
        ],
      ),

      body: _buildBody(),
    );
  }
}

/// Auswahl der Texte für „Meine Texte“, je Sprachfassung einzeln.
class MemorizationAddTextScreen extends StatelessWidget {
  final MemorizationCatalog catalog;
  final MemorizationRepository repository;

  const MemorizationAddTextScreen({
    super.key,
    required this.catalog,
    required this.repository,
  });

  static const Map<MemorizationTextType, String> _headings = {
    MemorizationTextType.prayer: "Gebete",
    MemorizationTextType.creed: "Altkirchliche Bekenntnisse",
    MemorizationTextType.confession: "Bekenntnisschriften",
    MemorizationTextType.bible: "Bibeltexte",
    MemorizationTextType.other: "Weitere Texte",
  };

  Future<void> _toggle(BuildContext context, MemorizationText text) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (repository.contains(text.id)) {
        await repository.removeText(text.id);
      } else {
        await repository.addText(text.id);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Die Änderung konnte nicht gespeichert werden."),
        ),
      );
    }
  }

  Widget _buildWork(BuildContext context, MemorizationWork work) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(work.title, style: Theme.of(context).textTheme.titleSmall),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final text in work.versions)
                  FilterChip(
                    key: Key("memorize_pick_${text.id}"),
                    label: Text(PrayerLanguages.name(text.languageCode)),
                    selected: repository.contains(text.id),
                    onSelected: (_) => _toggle(context, text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final type in MemorizationTextType.values)
        (type, catalog.works.where((w) => w.type == type).toList()),
    ].where((group) => group.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Text hinzufügen")),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListenableBuilder(
            listenable: repository,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "Wähle die Sprachfassungen, die du auswendig lernen "
                  "möchtest. Jede Sprache wird getrennt gelernt.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),

                for (final (type, works) in groups) ...[
                  const SizedBox(height: 20),

                  Text(
                    _headings[type]!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 4),

                  for (final work in works) _buildWork(context, work),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
