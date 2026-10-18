import 'package:flutter/material.dart';

import '../models/prayer.dart';
import '../services/memorization/favorite_ids.dart';
import '../services/memorization/memorization_repository.dart';
import '../services/prayer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';
import '../widgets/memorization_widgets.dart';
import 'prayer_detail_screen.dart';

class PrayersScreen extends StatefulWidget {
  /// Ermöglicht Widget-Tests mit eigenem Asset-Bundle.
  final PrayerService? service;

  /// Favoriten (gemeinsam mit „Texte auswendig lernen“); für Tests
  /// austauschbar.
  final MemorizationRepository? repository;

  const PrayersScreen({super.key, this.service, this.repository});

  /// Tag-Filter über der Liste (null = „Alle“).
  static const List<String?> filterTags = [
    null,
    "biblisch",
    "altkirchlich",
    "lutherisch",
    "liturgie",
    "abendmahl",
    "taufe",
    "beichte",
    "segen",
    "kirchenjahr",
    "morgen",
    "abend",
    "tischgebet",
    "fuerbitte",
  ];

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  late final PrayerService service = widget.service ?? PrayerService();

  late final MemorizationRepository favorites =
      widget.repository ?? MemorizationRepository.forCurrentUser();

  final TextEditingController searchController = TextEditingController();

  List<Prayer> prayers = [];

  String query = "";

  String? selectedTag;

  bool onlyFavorites = false;

  bool loading = true;

  bool failed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    // Ohne Favoriten bleibt das Menü nutzbar; die Sterne erscheinen erst
    // nach dem Laden.
    favorites.load().catchError((Object _) {});

    try {
      final data = await service.loadPrayers();

      if (!mounted) return;

      setState(() {
        prayers = data;
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

  List<Prayer> get filtered => PrayerSearch.filter(
    prayers,
    query: query,
    tag: selectedTag,
  ).where((p) => !onlyFavorites || isFavorite(p)).toList();

  bool isFavorite(Prayer prayer) =>
      favorites.isFavorite(FavoriteIds.prayer(prayer));

  Widget buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),

      child: Row(
        children: [
          // Unabhängig vom Tag: zeigt nur die favorisierten Gebete.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: const Key("prayer_filter_favorites"),
              avatar: const Icon(Icons.star_rounded, size: 18),
              label: const Text("Favoriten"),
              selected: onlyFavorites,
              onSelected: (value) => setState(() => onlyFavorites = value),
            ),
          ),

          ...PrayersScreen.filterTags.map((tag) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),

              child: ChoiceChip(
                key: Key("prayer_filter_${tag ?? "alle"}"),
                label: Text(tag == null ? "Alle" : PrayerTags.label(tag)),
                selected: selectedTag == tag,
                onSelected: (_) {
                  setState(() {
                    selectedTag = tag;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildTile(Prayer prayer) {
    return Card(
      child: ListTile(
        title: Text(prayer.displayTitle),

        subtitle: Text(prayer.tags.map(PrayerTags.label).join(" · ")),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prayer.languages.map((l) => l.toUpperCase()).join(" "),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            FavoriteButton(
              repository: favorites,
              workId: FavoriteIds.prayer(prayer),
            ),
          ],
        ),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PrayerDetailScreen(prayer: prayer, repository: favorites),
            ),
          );
        },
      ),
    );
  }

  /// Ohne Suche und Filter steht die Sammlung nach Rubriken gegliedert;
  /// Suchergebnisse bleiben eine einfache Liste in Datenreihenfolge.
  Widget buildList(List<Prayer> results) {
    final grouped = query.trim().isEmpty && selectedTag == null;

    final items = <Object>[
      if (!grouped)
        ...results
      else
        for (final category in PrayerCategories.order)
          if (results.any((p) => p.category == category)) ...[
            category,
            ...results.where((p) => p.category == category),
          ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is Prayer) return buildTile(item);

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Text(
            PrayerCategories.label(item as String),
            key: Key("prayer_category_$item"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }

  Widget buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Die Gebete konnten nicht geladen werden.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) => buildContent(filtered),
    );
  }

  Widget buildContent(List<Prayer> results) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),

        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),

              child: TextField(
                controller: searchController,

                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Suche nach Gebet oder Tag …",
                ),

                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
              ),
            ),

            buildFilterChips(),

            const SizedBox(height: 8),

            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: onlyFavorites && !prayers.any(isFavorite)
                            ? const FavoritesEmptyHint(items: "Gebete")
                            : const Text(
                                "Keine passenden Gebete gefunden.",
                                textAlign: TextAlign.center,
                              ),
                      ),
                    )
                  : buildList(results),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gebete"),
        actions: const [
          InfoButton(module: AppModules.prayers),
          SettingsButton(),
        ],
      ),

      body: buildBody(),
    );
  }
}
