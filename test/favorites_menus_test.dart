import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_card.dart';
import 'package:theologie_lernapp/screens/confession_detail_screen.dart';
import 'package:theologie_lernapp/screens/confessions_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_favorites_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_text_screen.dart';
import 'package:theologie_lernapp/screens/prayer_detail_screen.dart';
import 'package:theologie_lernapp/screens/prayers_screen.dart';
import 'package:theologie_lernapp/services/confession_service.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/prayer_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

/// Favoriten in den Menüs Gebete und Bekenntnisse: derselbe Bestand wie in
/// „Texte auswendig lernen“, kontextgerecht gefiltert.
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
    catalog = await MemorizationCatalog.load(
      prayers: PrayerService(bundle: FileAssetBundle()),
      confessions: ConfessionService(bundle: FileAssetBundle()),
    );
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
  const ca = "confession.augsburger_konfession";
  const caArt4 = "confession.augsburger_konfession.art_4";

  group("Gemeinsamer Bestand", () {
    test("IDs der Menüs sind die Werk-IDs von „Texte auswendig lernen“", () {
      expect(catalog.work(vaterunser), isNotNull);
      expect(catalog.work(apostolicum), isNotNull);
      expect(catalog.work(caArt4), isNotNull);

      // Die Augsburgische Konfession als Ganzes: ihre Artikel.
      expect(catalog.work(ca), isNull);
      expect(catalog.worksInGroup(ca), hasLength(31));
      expect(catalog.hasFavorite(ca), isTrue);
      expect(catalog.hasFavorite("confession.gibt_es_nicht"), isFalse);
    });

    test("Änderung in einer Instanz ist in allen sofort sichtbar", () async {
      final menu = MemorizationRepository(null);
      final memorization = MemorizationRepository(null);
      await menu.load();
      await memorization.load();

      var notified = 0;
      memorization.addListener(() => notified++);

      await menu.setFavorite(vaterunser, true);

      expect(memorization.isFavorite(vaterunser), isTrue);
      expect(notified, 1);

      await memorization.setFavorite(vaterunser, false);
      await memorization.setFavorite(ca, true);

      expect(menu.favoriteIds, [ca]);
    });

    test("ältere Instanz überschreibt beim Markieren nichts", () async {
      final menu = MemorizationRepository(null);
      final memorization = MemorizationRepository(null);
      await menu.load();
      await memorization.load();

      // Gelernt wird über „Texte auswendig lernen“ …
      await memorization.addText("$vaterunser.de");
      await memorization.saveCards([
        MemorizationCard(id: "$vaterunser.de.s0", level: 3, attempts: 2),
      ]);

      // … markiert im Menü, das schon vorher geöffnet war.
      await menu.setFavorite(vaterunser, true);

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      expect(reloaded.textIds, ["$vaterunser.de"]);
      expect(reloaded.favoriteIds, [vaterunser]);
      expect(reloaded.cards["$vaterunser.de.s0"]!.level, 3);
      expect(reloaded.cards["$vaterunser.de.s0"]!.attempts, 2);
    });
  });

  group("Menüs", () {
    Widget app(Widget home) {
      ensureRepository();

      return MaterialApp(theme: AppTheme.light, home: home);
    }

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

    Finder star(String id) => find.byKey(Key("memorize_favorite_$id"));

    bool selected(WidgetTester tester, String id) =>
        tester.widget<IconButton>(star(id)).isSelected == true;

    Future<void> pumpPrayers(WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          PrayersScreen(
            service: PrayerService(bundle: FileAssetBundle()),
            repository: ensureRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpConfessions(WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          ConfessionsScreen(
            service: ConfessionService(bundle: FileAssetBundle()),
            repository: ensureRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("Gebete: markieren, Favoriten zeigen, entfernen", (
      tester,
    ) async {
      await pumpPrayers(tester);

      final favorites = find.byKey(const Key("prayer_filter_favorites"));

      // Leere Liste: Hinweis.
      await tapVisible(tester, favorites);
      expect(find.byKey(const Key("memorize_favorites_empty")), findsOneWidget);
      expect(find.text("Vaterunser"), findsNothing);

      await tapVisible(tester, favorites);
      await tapVisible(tester, star(vaterunser));

      expect(selected(tester, vaterunser), isTrue);
      expect(ensureRepository().favoriteIds, [vaterunser]);

      await tapVisible(tester, favorites);

      // Nur die Favoriten, in ihrer Rubrik.
      expect(find.text("Vaterunser"), findsOneWidget);
      expect(find.text("Jesusgebet"), findsNothing);
      expect(find.byKey(const Key("prayer_category_grundtexte")), findsOne);
      expect(find.byType(ListTile), findsOneWidget);

      // Direkt öffnen; die Detailansicht zeigt denselben Stand.
      await tapVisible(tester, find.text("Vaterunser"));
      expect(find.byType(PrayerDetailScreen), findsOneWidget);
      expect(selected(tester, vaterunser), isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Entfernen nimmt den Eintrag sofort aus der Liste.
      await tapVisible(tester, star(vaterunser));
      expect(find.text("Vaterunser"), findsNothing);
      expect(find.byKey(const Key("memorize_favorites_empty")), findsOneWidget);

      final reloaded = MemorizationRepository(null);
      await drive(tester, reloaded.load());
      expect(reloaded.favoriteIds, isEmpty);
    });

    testWidgets("Gebete: Favoriten bleiben nach einem Neustart", (
      tester,
    ) async {
      await pumpPrayers(tester);
      await tapVisible(tester, star(vaterunser));

      // Neuer Start: neue Instanz, gleicher gespeicherter Stand.
      created = null;
      await tester.pumpWidget(const SizedBox());
      await pumpPrayers(tester);

      expect(selected(tester, vaterunser), isTrue);
      expect(ensureRepository().favoriteIds, [vaterunser]);
    });

    testWidgets("Bekenntnisse: Bekenntnis und ganze Bekenntnisschrift", (
      tester,
    ) async {
      await pumpConfessions(tester);

      final favorites = find.byKey(const Key("confession_filter_favorites"));

      await tapVisible(tester, favorites);
      expect(find.byKey(const Key("memorize_favorites_empty")), findsOneWidget);
      await tapVisible(tester, favorites);

      await tapVisible(tester, star(apostolicum));
      await tapVisible(tester, star(ca));

      expect(ensureRepository().favoriteIds, [apostolicum, ca]);

      await tapVisible(tester, favorites);

      expect(find.text("Apostolisches Glaubensbekenntnis"), findsOneWidget);
      expect(find.text("Augsburgische Konfession"), findsOneWidget);
      expect(find.text("Nicänisches Glaubensbekenntnis"), findsNothing);
      expect(find.text("Altkirchliche Symbole"), findsOneWidget);
      expect(find.text("Lutherische Symbole"), findsOneWidget);

      // Öffnen; der Stern der Detailansicht gilt derselben ID.
      await tapVisible(tester, find.text("Augsburgische Konfession"));
      expect(find.byType(ConfessionDetailScreen), findsOneWidget);
      expect(selected(tester, ca), isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tapVisible(tester, star(apostolicum));

      expect(find.text("Apostolisches Glaubensbekenntnis"), findsNothing);
      expect(find.text("Altkirchliche Symbole"), findsNothing);
      expect(ensureRepository().favoriteIds, [ca]);
    });

    testWidgets("Bekenntnisse: einzeln favorisierter Artikel öffnet die "
        "Schrift bei diesem Artikel", (tester) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().setFavorite(caArt4, true));

      await pumpConfessions(tester);
      await tapVisible(
        tester,
        find.byKey(const Key("confession_filter_favorites")),
      );

      final entry = find.byKey(const Key("confession_section_$caArt4"));
      expect(entry, findsOneWidget);
      expect(find.text("Artikel IV: Von der Rechtfertigung"), findsOneWidget);

      await tapVisible(tester, entry);

      final detail = tester.widget<ConfessionDetailScreen>(
        find.byType(ConfessionDetailScreen),
      );
      expect(detail.initialSectionIndex, 4);
      expect(find.text("Artikel IV: Von der Rechtfertigung"), findsWidgets);
    });

    testWidgets("Im Menü markiert, in „Texte auswendig lernen“ sichtbar", (
      tester,
    ) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().setFavorite(vaterunser, true));
      await drive(tester, ensureRepository().setFavorite(ca, true));

      await tester.pumpWidget(
        app(
          MemorizationFavoritesScreen(
            catalog: catalog,
            repository: ensureRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Globale Ansicht: alle Textarten.
      expect(find.text("Gebete"), findsOneWidget);
      expect(find.text("Bekenntnisschriften"), findsOneWidget);
      expect(find.text("Augsburgische Konfession"), findsOneWidget);
      expect(find.text("31 Abschnitte"), findsOneWidget);

      // Die Artikel der Schrift sind von hier aus lernbar.
      await tapVisible(tester, find.text("Augsburgische Konfession"));
      await tapVisible(
        tester,
        find.byKey(const Key("memorize_favorite_part_$caArt4")),
      );
      expect(find.byType(MemorizationTextScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Entfernen hier wirkt auch im Menü (gleicher Bestand).
      await tapVisible(tester, star(ca));
      expect(find.text("Augsburgische Konfession"), findsNothing);
      expect(ensureRepository().favoriteIds, [vaterunser]);
    });

    testWidgets("Gebet in „Texte auswendig lernen“ markiert: Stern im Menü", (
      tester,
    ) async {
      final memorization = MemorizationRepository(null);

      await pumpPrayers(tester);
      expect(selected(tester, vaterunser), isFalse);

      // Eine zweite, eigene Instanz wie in „Texte auswendig lernen“.
      await drive(tester, memorization.load());
      await drive(tester, memorization.setFavorite(vaterunser, true));
      await tester.pumpAndSettle();

      expect(selected(tester, vaterunser), isTrue);
    });
  });
}
