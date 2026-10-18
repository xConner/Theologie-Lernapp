import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_card.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_favorites_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_home_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_text_screen.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

/// Favoriten in „Texte auswendig lernen“: Markieren, Speichern, eigene
/// Ansicht und Filter – ohne Einfluss auf den Lernstand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorizationCatalog catalog;

  // Erst im Test selbst anlegen: Futures aus setUp gehören nicht zum
  // Fake-Async des Widget-Tests und würden dort nie fortgesetzt.
  MemorizationRepository? created;

  MemorizationRepository ensureRepository() {
    return MemorizationRepository.debugOverride = created ??=
        MemorizationRepository(null);
  }

  setUpAll(() async {
    catalog = await MemorizationCatalog.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    created = null;
  });

  tearDown(() {
    MemorizationRepository.debugOverride = null;
  });

  const vaterunser = "prayer.vaterunser";
  const apostolicum = "confession.apostolicum.full";

  MemorizationCard learnedCard(String id) {
    return MemorizationCard(
      id: id,
      stability: 72,
      lastReviewed: DateTime(2026, 3, 1),
      level: MemorizationCard.maxLevel,
      attempts: 4,
      successes: 3,
      streak: 2,
      learned: true,
      startedAt: DateTime(2026, 2, 1),
    );
  }

  group("Speicherung", () {
    test("hinzufügen und entfernen, ohne doppelte Einträge", () async {
      final repository = MemorizationRepository(null);
      await repository.load();

      expect(repository.favoriteIds, isEmpty);

      await repository.setFavorite(vaterunser, true);
      await repository.setFavorite(vaterunser, true);
      await repository.toggleFavorite(apostolicum);

      expect(repository.favoriteIds, [vaterunser, apostolicum]);
      expect(repository.isFavorite(vaterunser), isTrue);

      await repository.toggleFavorite(vaterunser);

      expect(repository.favoriteIds, [apostolicum]);
      expect(repository.isFavorite(vaterunser), isFalse);
    });

    test("bleibt nach einem Neustart erhalten", () async {
      final repository = MemorizationRepository(null);
      await repository.load();
      await repository.setFavorite(vaterunser, true);
      await repository.setFavorite(apostolicum, true);
      await repository.setFavorite(apostolicum, false);

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      expect(reloaded.favoriteIds, [vaterunser]);
    });

    test("doppelte gespeicherte Einträge werden zusammengefasst", () async {
      await LocalLearningStore.instance.saveSettingsGroup(
        "memorization_settings",
        {
          "favorites": [vaterunser, apostolicum, vaterunser],
        },
      );

      final repository = MemorizationRepository(null);
      await repository.load();

      expect(repository.favoriteIds, [vaterunser, apostolicum]);
    });

    test("Zuordnung über stabile Werk-IDs, nicht über Titel", () async {
      final repository = MemorizationRepository(null);
      await repository.load();
      await repository.setFavorite(vaterunser, true);

      final work = catalog.work(vaterunser)!;

      // Alle Sprachfassungen gehören zum selben Werk und damit zum Favoriten.
      expect(work.versions.length, greaterThan(1));
      for (final text in work.versions) {
        expect(repository.isFavorite(text.workId), isTrue);
      }

      // Ein anderes Werk mit ähnlichem Titel ist nicht betroffen.
      expect(repository.isFavorite(work.title), isFalse);
      expect(catalog.work(work.title), isNull);
    });

    test("Lernstand, „Meine Texte“ und Pausen bleiben unverändert", () async {
      final repository = MemorizationRepository(null);
      await repository.load();

      await repository.addText("$vaterunser.de");
      await repository.addText("$vaterunser.la");
      await repository.setActive("$vaterunser.la", false);
      await repository.saveCards([
        learnedCard("$vaterunser.de.s0"),
        learnedCard("$vaterunser.de.full"),
      ]);

      final before = {
        for (final entry in repository.cards.entries)
          entry.key: entry.value.toJson(),
      };

      await repository.setFavorite(vaterunser, true);
      await repository.setFavorite(vaterunser, false);
      await repository.setFavorite(vaterunser, true);

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      for (final r in [repository, reloaded]) {
        expect(r.textIds, ["$vaterunser.de", "$vaterunser.la"]);
        expect(r.isActive("$vaterunser.de"), isTrue);
        expect(r.isActive("$vaterunser.la"), isFalse);
        expect({
          for (final entry in r.cards.entries) entry.key: entry.value.toJson(),
        }, before);
      }

      expect(reloaded.favoriteIds, [vaterunser]);
    });
    test("Gastdaten: Favoriten werden übernommen, Lernstand-Reset "
        "behält sie", () async {
      final repository = MemorizationRepository(null);
      await repository.load();
      await repository.setFavorite(vaterunser, true);
      await repository.saveCards([learnedCard("$vaterunser.de.s0")]);

      // So liest die Übernahme in ein Konto die Einstellungen.
      final settings = await LocalLearningStore.instance.loadSettingsGroup(
        "memorization_settings",
      );
      expect(settings["favorites"], [vaterunser]);

      await LocalLearningStore.instance.resetCollection(
        LocalLearningStore.memorization,
      );

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      expect(reloaded.cards, isEmpty);
      expect(reloaded.favoriteIds, [vaterunser]);
    });
  });

  group("Ansichten", () {
    Widget app(Widget home) {
      ensureRepository();

      return MaterialApp(theme: AppTheme.light, home: home);
    }

    /// Wartet auf [future]; im Fake-Async der Widget-Tests laufen Speicher-
    /// zugriffe nur weiter, wenn gepumpt wird.
    Future<void> drive(WidgetTester tester, Future<void> future) async {
      var done = false;

      future.whenComplete(() => done = true);

      for (var i = 0; i < 100 && !done; i++) {
        await tester.pump();
      }

      expect(done, isTrue, reason: "Speicherzugriff nicht abgeschlossen");
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> pumpHome(WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          MemorizationHomeScreen(
            repository: ensureRepository(),
            catalog: Future.value(catalog),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpFavorites(WidgetTester tester) async {
      await drive(tester, ensureRepository().load());

      await tester.pumpWidget(
        app(
          MemorizationFavoritesScreen(
            catalog: catalog,
            repository: ensureRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder star(String workId) => find.byKey(Key("memorize_favorite_$workId"));

    testWidgets("leere Favoritenliste zeigt einen Hinweis", (tester) async {
      await pumpHome(tester);

      expect(find.text("Favoriten"), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key("memorize_favorites")));

      expect(find.byType(MemorizationFavoritesScreen), findsOneWidget);
      expect(find.byKey(const Key("memorize_favorites_empty")), findsOneWidget);
    });

    testWidgets("nur Favoriten, nach Kategorien, direkt zu öffnen", (
      tester,
    ) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().setFavorite(apostolicum, true));
      await drive(tester, ensureRepository().setFavorite(vaterunser, true));
      // Unbekannte IDs (z. B. entfernte Texte) erscheinen nicht.
      await drive(
        tester,
        ensureRepository().setFavorite("prayer.gibt_es_nicht", true),
      );

      await pumpFavorites(tester);

      expect(find.byKey(const Key("memorize_favorites_empty")), findsNothing);
      expect(find.text("Gebete"), findsOneWidget);
      expect(find.text("Altkirchliche Bekenntnisse"), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(
        find.byKey(const Key("memorize_favorite_entry_$vaterunser")),
        findsOneWidget,
      );

      // Gebete stehen wie in der Textauswahl vor den Bekenntnissen.
      expect(
        tester.getTopLeft(find.text("Gebete")).dy,
        lessThan(tester.getTopLeft(find.text("Altkirchliche Bekenntnisse")).dy),
      );

      await tapVisible(
        tester,
        find.byKey(const Key("memorize_favorite_entry_$vaterunser")),
      );

      expect(find.byType(MemorizationTextScreen), findsOneWidget);
      expect(find.text("Lernen beginnen"), findsOneWidget);

      // Auch in der Textansicht als Favorit angezeigt.
      final textStar = tester.widget<IconButton>(star(vaterunser));
      expect(textStar.isSelected, isTrue);
    });

    testWidgets("Entfernen nimmt den Eintrag sofort aus der Liste", (
      tester,
    ) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().setFavorite(vaterunser, true));
      await drive(tester, ensureRepository().setFavorite(apostolicum, true));

      await pumpFavorites(tester);

      await tapVisible(tester, star(vaterunser));

      expect(
        find.byKey(const Key("memorize_favorite_entry_$vaterunser")),
        findsNothing,
      );
      expect(find.text("Gebete"), findsNothing);
      expect(ensureRepository().favoriteIds, [apostolicum]);

      await tapVisible(tester, star(apostolicum));

      expect(find.byKey(const Key("memorize_favorites_empty")), findsOneWidget);
      expect(ensureRepository().favoriteIds, isEmpty);
    });

    testWidgets("Stern in der Textansicht, gleicher Stand in allen Ansichten", (
      tester,
    ) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().addText("$vaterunser.de"));
      await drive(tester, ensureRepository().addText("$vaterunser.la"));

      await pumpHome(tester);

      // Öffnen über „Meine Texte“, markieren in der Textansicht.
      await tapVisible(
        tester,
        find.byKey(const Key("memorize_text_$vaterunser.de")),
      );
      await tapVisible(tester, star(vaterunser));

      expect(ensureRepository().favoriteIds, [vaterunser]);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Beide Sprachfassungen unter „Meine Texte“ zeigen den Stern gefüllt.
      final stars = tester.widgetList<IconButton>(star(vaterunser)).toList();
      expect(stars, hasLength(2));
      expect(stars.every((button) => button.isSelected == true), isTrue);
      expect(find.text("Favoriten (1)"), findsOneWidget);

      // Entfernen unter „Meine Texte“ nimmt nur die Markierung weg.
      await tapVisible(tester, star(vaterunser).first);

      expect(ensureRepository().favoriteIds, isEmpty);
      expect(ensureRepository().textIds, ["$vaterunser.de", "$vaterunser.la"]);
      expect(find.text("Favoriten"), findsOneWidget);
    });

    testWidgets("Filter „Nur Favoriten“ in der Textauswahl", (tester) async {
      await pumpHome(tester);

      await tapVisible(tester, find.byKey(const Key("memorize_add")));

      final pick = find.byKey(const Key("memorize_pick_$vaterunser.de"));
      expect(pick, findsOneWidget);

      await tapVisible(
        tester,
        find.byKey(const Key("memorize_filter_favorites")),
      );

      // Noch keine Favoriten: Hinweis statt Texte.
      expect(find.byKey(const Key("memorize_favorites_empty")), findsOneWidget);
      expect(pick, findsNothing);

      // Ein neuer Favorit erscheint sofort in der gefilterten Auswahl.
      await drive(tester, ensureRepository().setFavorite(vaterunser, true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("memorize_favorites_empty")), findsNothing);
      expect(pick, findsOneWidget);
      expect(find.text("Gebete"), findsOneWidget);
      expect(find.text("Altkirchliche Bekenntnisse"), findsNothing);

      // Favoriten bleiben in der gefilterten Auswahl normal lernbar.
      await tapVisible(tester, pick);
      expect(ensureRepository().textIds, ["$vaterunser.de"]);

      // Entfernen der Markierung blendet den Text sofort aus.
      await tapVisible(tester, star(vaterunser));
      expect(pick, findsNothing);
      expect(ensureRepository().textIds, ["$vaterunser.de"]);
    });
  });
}
