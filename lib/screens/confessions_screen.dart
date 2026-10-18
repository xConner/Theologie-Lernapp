import 'package:flutter/material.dart';

import '../models/confession.dart';
import '../services/confession_service.dart';
import '../services/memorization/favorite_ids.dart';
import '../services/memorization/memorization_repository.dart';
import 'confession_detail_screen.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';
import '../widgets/memorization_widgets.dart';

class ConfessionsScreen extends StatefulWidget {
  /// Ermöglicht Widget-Tests mit eigenem Asset-Bundle.
  final ConfessionService? service;

  /// Favoriten (gemeinsam mit „Texte auswendig lernen“); für Tests
  /// austauschbar.
  final MemorizationRepository? repository;

  const ConfessionsScreen({super.key, this.service, this.repository});

  @override
  State<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends State<ConfessionsScreen> {
  late final ConfessionService service = widget.service ?? ConfessionService();

  late final MemorizationRepository favorites =
      widget.repository ?? MemorizationRepository.forCurrentUser();

  List<Confession> confessions = [];

  bool onlyFavorites = false;

  bool loading = true;

  bool failed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    // Ohne Favoriten bleibt das Menü nutzbar; die Sterne erscheinen erst
    // nach dem Laden.
    favorites.load().catchError((Object _) {});

    try {
      final data = await service.loadConfessions();

      if (!mounted) return;

      setState(() {
        confessions = data;
        failed = false;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        failed = true;
        loading = false;
      });
    }
  }

  List<Confession> getByCategory(String category) {
    return confessions.where((c) => c.category == category).toList();
  }

  void open(Confession confession, [int section = 0]) {
    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => ConfessionDetailScreen(
          confession: confession,
          initialSectionIndex: section,
          repository: favorites,
        ),
      ),
    );
  }

  Widget buildButton(Confession confession) {
    return Card(
      child: ListTile(
        key: Key("confession_${confession.id}"),
        title: Text(confession.title["de"] ?? confession.id),

        trailing: FavoriteButton(
          repository: favorites,
          workId: FavoriteIds.confession(confession),
        ),

        onTap: () => open(confession),
      ),
    );
  }

  /// Einzeln favorisierter Artikel einer Bekenntnisschrift (markiert in
  /// „Texte auswendig lernen“); öffnet die Schrift bei diesem Artikel.
  Widget buildSection(Confession confession, int index) {
    final section = confession.sections[index];
    final id = FavoriteIds.confessionSection(confession, section);

    return Card(
      child: ListTile(
        key: Key("confession_section_$id"),
        title: Text(section.title["de"] ?? section.id),
        subtitle: Text(confession.title["de"] ?? confession.id),
        trailing: FavoriteButton(repository: favorites, workId: id),
        onTap: () => open(confession, index),
      ),
    );
  }

  /// Einträge einer Kategorie; mit [onlyFavorites] nur die favorisierten
  /// Bekenntnisse und Artikel.
  List<Widget> buildEntries(List<Confession> list) {
    if (!onlyFavorites) return list.map(buildButton).toList();

    return [
      for (final confession in list) ...[
        if (favorites.isFavorite(FavoriteIds.confession(confession)))
          buildButton(confession),
        if (confession.sections.length > 1)
          for (var i = 0; i < confession.sections.length; i++)
            if (favorites.isFavorite(
              FavoriteIds.confessionSection(confession, confession.sections[i]),
            ))
              buildSection(confession, i),
      ],
    ];
  }

  Widget buildCategory(String title, List<Confession> list) {
    final entries = buildEntries(list);

    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          ...entries,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Bekenntnisse"),
          actions: const [
            InfoButton(module: AppModules.confessions),
            SettingsButton(),
          ],
        ),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (failed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Bekenntnisse"),
          actions: const [
            InfoButton(module: AppModules.confessions),
            SettingsButton(),
          ],
        ),

        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Die Bekenntnisse konnten nicht geladen werden.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final altkirchlich = getByCategory("altkirchliche_symbole");

    final lutherisch = getByCategory("lutherische_symbole");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bekenntnisse"),
        actions: const [
          InfoButton(module: AppModules.confessions),
          SettingsButton(),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: ListenableBuilder(
            listenable: favorites,
            builder: (context, _) {
              final categories = [
                buildCategory("Altkirchliche Symbole", altkirchlich),
                buildCategory("Lutherische Symbole", lutherisch),
              ];

              final empty =
                  onlyFavorites &&
                  categories.every((widget) => widget is SizedBox);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    FilterChip(
                      key: const Key("confession_filter_favorites"),
                      avatar: const Icon(Icons.star_rounded, size: 18),
                      label: const Text("Favoriten"),
                      selected: onlyFavorites,
                      onSelected: (value) =>
                          setState(() => onlyFavorites = value),
                    ),

                    const SizedBox(height: 16),

                    if (empty)
                      const FavoritesEmptyHint(items: "Bekenntnisse")
                    else
                      ...categories,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
