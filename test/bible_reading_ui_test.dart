import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/bible/bible_home_screen.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/bible/reading_plan_detail_screen.dart';
import 'package:theologie_lernapp/screens/bible/reading_plan_import_screen.dart';
import 'package:theologie_lernapp/screens/bible/reading_plans_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

// Ein einziger Ablauf: Die gemeinsamen Dienste (StreakService.instance)
// behalten ihren Zustand über den Test hinweg.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Bibel als Gast: Lesen bestätigen, Streak, Leseplan beginnen, "
      "abhaken, pausieren und importieren", (tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bundle = FileAssetBundle();

    final repository = BibleRepository(
      source: AssetBibleTextSource(bundle: bundle),
    );

    final service = BibleReadingService(
      bundle: bundle,
      translations: repository.translations,
    );

    await tester.runAsync(
      () => StreakService.instance.load(null, refresh: true),
    );

    StreakSnapshot streak() =>
        StreakService.instance.snapshotFor(null, StreakTrack.bible);

    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await settle();
    }

    // Der Reader lädt die Perikopenüberschriften aus dem Bundle der App;
    // das braucht echte Zeit, solange dreht sich die Ladeanzeige.
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Das Abhaken rollt die Lesung nach oben; zurück zum Kopf des Plans.
    Future<void> toTop() async {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await settle();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BibleHomeScreen(
          uid: null,
          service: service,
          repository: repository,
        ),
      ),
    );
    await settle();
    await settle();

    expect(find.text("Noch keine aktive Streak"), findsOneWidget);
    expect(find.text("Noch offen"), findsOneWidget);
    expect(find.text("Noch keine bestätigte Lesung."), findsOneWidget);
    expect(find.textContaining("noch keinem Leseplan"), findsOneWidget);

    // ---- Reader: Aufschlagen und Blättern zählt nicht.
    await tester.tap(key("bible-open-reader"));
    await waitFor(find.text("1. Mose 1"));

    await settle();

    expect(find.byType(BibleReaderScreen), findsOneWidget);
    expect(find.text("1. Mose 1"), findsOneWidget);

    await tapVisible(key("bible-next-chapter"));
    await settle();

    expect(find.text("1. Mose 2"), findsOneWidget);
    expect(streak().completedToday, isFalse);
    expect(service.readingDayCount(null), 0);

    // ---- Ausdrücklich bestätigen; die Stelle ist vorgeschlagen.
    await tapVisible(key("bible-mark-read"));

    expect(
      tester.widget<TextField>(key("bible-reading-text")).controller!.text,
      "Gen 2",
    );

    // Abbrechen zählt nicht.
    await tapVisible(find.text("Abbrechen"));

    expect(streak().completedToday, isFalse);

    await tapVisible(key("bible-mark-read"));
    await tapVisible(key("bible-reading-confirm"));

    expect(streak().completedToday, isTrue);
    expect(streak().currentStreak, 1);
    expect(find.text("🔥 Bibellesen-Streak gestartet!"), findsOneWidget);
    expect(service.entriesOn(null, service.today).single.text, "Gen 2");

    await tester.pageBack();
    await settle();

    expect(find.text("1 Tag Streak"), findsOneWidget);
    expect(find.text("Tagesziel erreicht"), findsOneWidget);
    expect(find.text("Bisher 1 Lesetag."), findsOneWidget);
    expect(find.text("Heute"), findsNWidgets(2));
    expect(find.text("Gen 2"), findsOneWidget);

    // ---- Lesung ohne Reader eintragen: zweiter Eintrag, derselbe Lesetag.
    await tapVisible(key("bible-confirm-reading"));
    await tester.enterText(key("bible-reading-text"), "Ps 23");
    await tapVisible(key("bible-reading-confirm"));

    expect(find.text("Gen 2 · Ps 23"), findsOneWidget);
    expect(find.text("Bisher 1 Lesetag."), findsOneWidget);
    expect(streak().currentStreak, 1);

    // ---- Lesepläne: Übersicht mit Dauer und Umfang.
    await tapVisible(key("bible-open-plans"));
    await settle();

    expect(find.byType(ReadingPlansScreen), findsOneWidget);

    for (final name in [
      "Die ganze Bibel in einem Jahr",
      "Die ganze Bibel in sechs Monaten",
      "Die ganze Bibel in 90 Tagen",
      "Das Neue Testament in 90 Tagen",
      "Die Evangelien in 30 Tagen",
      "Bibel-Marathon in 30 Tagen",
    ]) {
      expect(find.text(name, skipOffstage: false), findsOneWidget);
    }

    expect(find.textContaining("365 Tage · Ø 3,3 Kapitel"), findsOneWidget);
    expect(find.text("Extrem", skipOffstage: false), findsOneWidget);

    // ---- Extremer Plan: Warnung vor dem Start, Abbrechen beginnt nichts.
    await tapVisible(key("plan-bible-marathon-30-days"));
    await settle();

    expect(find.byType(ReadingPlanDetailScreen), findsOneWidget);
    expect(key("plan-intensity-warning"), findsOneWidget);
    expect(
      find.textContaining("Extremer Plan: täglich rund 40 Kapitel"),
      findsOneWidget,
    );

    await tapVisible(key("plan-start"));

    expect(find.text("Diesen Plan beginnen?"), findsOneWidget);

    await tapVisible(find.text("Abbrechen"));

    expect(service.startedPlans(null), isEmpty);

    await tester.pageBack();
    await settle();

    // ---- Evangelienplan beginnen und eine Lesung abhaken.
    await tapVisible(key("plan-gospels-30-days"));
    await settle();

    expect(key("plan-intensity-warning"), findsNothing);
    expect(find.text("Tag 1"), findsOneWidget);
    expect(find.text("Mt 1–5"), findsOneWidget);

    // Vor dem Start lässt sich nichts abhaken.
    expect(
      tester
          .widget<Checkbox>(key("plan-reading-gospels-30-days-1-0"))
          .onChanged,
      isNull,
    );

    await tapVisible(key("plan-start"));

    expect(find.textContaining("Aktuell: Tag 1 von 30"), findsOneWidget);
    expect(find.textContaining("0 von 30 Tagen · 0 von "), findsOneWidget);

    // Zuerst Tag 2, dann Tag 1: keine feste Reihenfolge.
    await tapVisible(key("plan-reading-gospels-30-days-2-0"));

    expect(find.text("Lesung erledigt."), findsOneWidget);

    await toTop();

    expect(find.textContaining("Aktuell: Tag 1 von 30"), findsOneWidget);
    await tapVisible(key("plan-reading-gospels-30-days-1-0"));
    await toTop();

    expect(find.textContaining("Aktuell: Tag 3 von 30"), findsOneWidget);
    expect(find.textContaining("2 von 30 Tagen · 2 von "), findsOneWidget);
    expect(streak().currentStreak, 1, reason: "derselbe Lesetag");
    expect(service.entriesOn(null, service.today), hasLength(4));

    // ---- Aus dem Plan in den Reader springen und dort erledigen.
    await tester.tap(find.text("Lesen").at(2));
    await waitFor(find.text("Matthäus 9"));
    await settle();

    expect(find.byType(BibleReaderScreen), findsOneWidget);
    expect(find.text("Die Evangelien in 30 Tagen · Tag 3"), findsOneWidget);
    expect(find.text("Matthäus 9"), findsOneWidget);
    expect(key("bible-mark-read"), findsNothing);

    await tapVisible(key("bible-plan-mark-read"));

    expect(key("bible-plan-reading-done"), findsOneWidget);

    await tester.pageBack();
    await settle();

    expect(find.textContaining("3 von 30 Tagen · 3 von "), findsOneWidget);

    // ---- Pausieren sperrt das Abhaken, Fortsetzen gibt es wieder frei.
    await tapVisible(key("plan-pause"));

    expect(find.textContaining("pausiert"), findsOneWidget);
    expect(find.text("Fortsetzen"), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(key("plan-reading-gospels-30-days-4-0"))
          .onChanged,
      isNull,
    );

    await tapVisible(key("plan-pause"));

    expect(find.textContaining("Aktuell: Tag 4 von 30"), findsOneWidget);

    await tester.pageBack();
    await settle();

    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await settle();

    expect(find.text("Meine Pläne"), findsOneWidget);

    // ---- Import: ungültige Datei mit Meldungen, dann eine gültige.
    await tapVisible(key("plans-menu"));
    await tapVisible(find.text("Plan aus Datei importieren"));

    expect(find.byType(ReadingPlanImportScreen), findsOneWidget);

    await tester.enterText(
      key("plan-import-json"),
      '{"id": "mein-plan", "name": "Mein Plan", "days": [["GEN 51"]]}',
    );
    await tapVisible(key("plan-import-submit"));

    expect(key("plan-problems"), findsOneWidget);
    expect(find.textContaining("kein Kapitel 51"), findsOneWidget);

    await tester.enterText(
      key("plan-import-json"),
      '{"id": "mein-plan", "name": "Mein Plan", "days": [["MRK 1", "PSA 1"]]}',
    );
    await tapVisible(key("plan-import-submit"));
    await settle();

    // Der importierte Plan öffnet sich.
    expect(find.byType(ReadingPlanImportScreen), findsNothing);
    expect(find.text("Mein Plan"), findsOneWidget);
    expect(find.text("Mk 1"), findsOneWidget);
    expect(find.text("Ps 1"), findsOneWidget);

    // ---- Alles liegt dauerhaft im lokalen Speicher, Plan und Streak
    // getrennt.
    final reading = await tester.runAsync(
      LocalBibleReadingRepository().loadAll,
    );

    expect(reading!.keys, {
      "log_${service.today.substring(0, 4)}",
      "plan_gospels-30-days",
      "custom_mein-plan",
    });

    final streaks = await tester.runAsync(LocalStreakRepository().loadAll);

    expect(streaks!["bible"]!.currentStreak, 1);
    expect(streaks["bible"]!.lastCompletedDate, service.today);
  });
}
