import 'package:flutter/material.dart';

import '../../models/bible/bible_translation.dart';
import '../../models/bible/reading_plan.dart';
import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/bible_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bible/bible_reading_widgets.dart';
import 'reading_plan_detail_screen.dart';
import 'reading_plan_editor_screen.dart';
import 'reading_plan_import_screen.dart';

/// Übersicht der Lesepläne: begonnene, integrierte und eigene Pläne;
/// außerdem Import und Erstellung eigener Pläne.
class ReadingPlansScreen extends StatefulWidget {
  /// null = Gast.
  final String? uid;

  // Nur für Tests ersetzbar.
  final BibleReadingService? service;
  final BibleRepository? repository;

  const ReadingPlansScreen({
    super.key,
    required this.uid,
    this.service,
    this.repository,
  });

  @override
  State<ReadingPlansScreen> createState() => _ReadingPlansScreenState();
}

class _ReadingPlansScreenState extends State<ReadingPlansScreen> {
  late final BibleReadingService service =
      widget.service ?? BibleReadingService.instance;

  // Für die Angabe des täglichen Umfangs; ohne sie fehlt nur diese Angabe.
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
      // Bleibt leer.
    }
  }

  Future<void> _open(String planId) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPlanDetailScreen(
          uid: uid,
          planId: planId,
          service: service,
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _add(Widget screen) async {
    final plan = await Navigator.push<ReadingPlan>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    if (plan != null && mounted) _open(plan.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lesepläne"),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey("plans-menu"),
            tooltip: "Eigener Plan",
            icon: const Icon(Icons.add),
            onSelected: (value) {
              switch (value) {
                case "create":
                  _add(ReadingPlanEditorScreen(uid: uid, service: service));
                case "import":
                  _add(ReadingPlanImportScreen(uid: uid, service: service));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: "create",
                child: Text("Eigenen Plan erstellen"),
              ),
              PopupMenuItem(
                value: "import",
                child: Text("Plan aus Datei importieren"),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListenableBuilder(
            listenable: service,
            builder: (context, _) => _list(context),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final plans = service.plans;

    final started = [for (final (plan, _) in service.startedPlans(uid)) plan];

    final available = plans.where((p) => !started.contains(p)).toList();

    Widget heading(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: textTheme.titleLarge),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!service.isLoaded(uid))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Dein Fortschritt und eigene Pläne konnten nicht geladen "
              "werden.",
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),

        if (started.isNotEmpty) ...[
          heading("Meine Pläne"),
          for (final plan in started) _tile(context, plan),
          const SizedBox(height: 16),
        ],

        heading("Verfügbare Pläne"),

        if (available.isEmpty)
          Text(
            plans.isEmpty
                ? "Die Lesepläne konnten nicht geladen werden."
                : "Du hast alle Pläne begonnen.",
            style: TextStyle(color: context.colors.textSecondary),
          ),

        for (final plan in available) _tile(context, plan),

        const SizedBox(height: 12),

        Text(
          "Lesepläne enthalten nur Stellenangaben, keinen Bibeltext. Gelesen "
          "wird in der Ausgabe, die du im Reader gewählt hast.",
          style: textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, ReadingPlan plan) {
    final textTheme = Theme.of(context).textTheme;
    final progress = service.progressOf(uid, plan.id);

    return Card(
      key: ValueKey("plan-${plan.id}"),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(plan.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(plan.name, style: textTheme.titleMedium),

              const SizedBox(height: 4),

              PlanFacts(plan: plan, translations: translations),

              if (progress != null) ...[
                const SizedBox(height: 10),
                if (progress.paused)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text("Pausiert", style: textTheme.labelLarge),
                  ),
                PlanProgressBar(plan: plan, progress: progress),
              ] else if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(plan.description),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
