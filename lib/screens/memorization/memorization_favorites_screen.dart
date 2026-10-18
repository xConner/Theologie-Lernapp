import 'package:flutter/material.dart';

import '../../models/memorization/memorization_text.dart';
import '../../models/prayer.dart';
import '../../services/memorization/memorization_catalog.dart';
import '../../services/memorization/memorization_repository.dart';
import '../../widgets/memorization_widgets.dart';
import 'memorization_text_screen.dart';

/// Alle als Favorit markierten Texte (auch die in den Menüs Gebete und
/// Bekenntnisse markierten), nach denselben Kategorien wie die Textauswahl.
/// Die Einträge verweisen auf die Texte des Katalogs; geöffnet wird die
/// gewohnte Textansicht mit Lernstand und Übungen. Eine ganze
/// Bekenntnisschrift steht aufklappbar mit ihren Artikeln da.
class MemorizationFavoritesScreen extends StatelessWidget {
  final MemorizationCatalog catalog;
  final MemorizationRepository repository;

  const MemorizationFavoritesScreen({
    super.key,
    required this.catalog,
    required this.repository,
  });

  /// Bevorzugt die Sprachfassung, die schon unter „Meine Texte“ gelernt wird.
  void _open(BuildContext context, MemorizationWork work) {
    final version = work.versions.firstWhere(
      (text) => repository.contains(text.id),
      orElse: () => work.versions.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemorizationTextScreen(
          work: work,
          languageCode: version.languageCode,
          repository: repository,
        ),
      ),
    );
  }

  Widget _buildWork(BuildContext context, MemorizationWork work) {
    return Card(
      child: ListTile(
        key: Key("memorize_favorite_entry_${work.id}"),
        title: Text(work.title),
        subtitle: Text(
          [
            for (final text in work.versions)
              PrayerLanguages.name(text.languageCode),
          ].join(" · "),
        ),
        trailing: FavoriteButton(repository: repository, workId: work.id),
        onTap: () => _open(context, work),
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    String groupId,
    List<MemorizationWork> works,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey("memorize_favorite_entry_$groupId"),
        title: Row(
          children: [
            Expanded(child: Text(works.first.group ?? groupId)),
            FavoriteButton(repository: repository, workId: groupId),
          ],
        ),
        subtitle: Text(
          works.length == 1 ? "1 Abschnitt" : "${works.length} Abschnitte",
        ),
        shape: const Border(),
        children: [
          for (final work in works)
            ListTile(
              key: Key("memorize_favorite_part_${work.id}"),
              title: Text(work.shortTitle ?? work.title),
              onTap: () => _open(context, work),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favoriten")),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListenableBuilder(
            listenable: repository,
            builder: (context, _) {
              final works = [
                for (final id in repository.favoriteIds)
                  if (catalog.work(id) != null) catalog.work(id)!,
              ];

              final groups = {
                for (final id in repository.favoriteIds)
                  if (catalog.worksInGroup(id).isNotEmpty)
                    id: catalog.worksInGroup(id),
              };

              final types = [
                for (final work in works) work.type,
                for (final group in groups.values) group.first.type,
              ];

              if (types.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: FavoritesEmptyHint(),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final type in MemorizationTextType.values)
                    if (types.contains(type)) ...[
                      Text(
                        type.heading,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),

                      const SizedBox(height: 4),

                      for (final work in works)
                        if (work.type == type) _buildWork(context, work),

                      for (final entry in groups.entries)
                        if (entry.value.first.type == type)
                          _buildGroup(context, entry.key, entry.value),

                      const SizedBox(height: 20),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
