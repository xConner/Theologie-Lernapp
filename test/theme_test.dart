import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/quiz_sound_settings.dart';
import 'package:theologie_lernapp/services/theme_settings.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/answer_feedback_badge.dart';
import 'package:theologie_lernapp/widgets/button_progress_indicator.dart';
import 'package:theologie_lernapp/widgets/settings_selection.dart';

const _themeModeKey = 'app_theme_mode';

/// Kontrastverhältnis nach WCAG 2.x (1–21).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Die App so, wie `MyApp` sie aufbaut, nur mit den Einstellungen als
/// Startseite (ohne Firebase).
Widget _app() {
  return ListenableBuilder(
    listenable: ThemeSettings.instance,
    builder: (context, _) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeSettings.instance.themeMode,
      home: const SettingsScreen(),
    ),
  );
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(GeneralSettingsView))).brightness;

RawChip _chip(WidgetTester tester, String label) => tester.widget<RawChip>(
  find.ancestor(of: find.text(label), matching: find.byType(RawChip)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = ThemeSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;
    await settings.load();
  });

  group("ThemeSettings", () {
    test("Ohne gespeicherten Wert gilt das System-Theme", () {
      expect(settings.themeMode, ThemeMode.system);
    });

    test("Gespeicherte Auswahl wird geladen", () async {
      for (final mode in ThemeMode.values) {
        SharedPreferences.setMockInitialValues({_themeModeKey: mode.name});
        await settings.load();

        expect(settings.themeMode, mode);
      }
    });

    test("Auswahl wird gespeichert und übersteht einen Neustart", () async {
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await settings.setThemeMode(mode);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_themeModeKey), mode.name);

        // „Neustart“: der gespeicherte Stand wird frisch eingelesen.
        await settings.load();
        expect(settings.themeMode, mode);
      }
    });

    test("Ungültiger gespeicherter Wert fällt auf das System-Theme "
        "zurück", () async {
      SharedPreferences.setMockInitialValues({_themeModeKey: "sepia"});
      await settings.load();

      expect(settings.themeMode, ThemeMode.system);
      expect(ThemeSettings.parseThemeMode(null), ThemeMode.system);
      expect(ThemeSettings.parseThemeMode(""), ThemeMode.system);
    });

    test("Listener werden nur bei einer Änderung benachrichtigt", () async {
      var notified = 0;
      void listener() => notified++;

      settings.addListener(listener);
      addTearDown(() => settings.removeListener(listener));

      await settings.setThemeMode(ThemeMode.dark);
      await settings.setThemeMode(ThemeMode.dark);

      expect(notified, 1);
    });

    test("Andere Einstellungen bleiben erhalten", () async {
      SharedPreferences.setMockInitialValues({
        'quiz_sound_volume': 0.25,
        'quiz_sound_correct_enabled_greekGrammar': false,
      });
      await QuizSoundSettings.instance.load();
      await settings.load();

      await settings.setThemeMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('quiz_sound_volume'), 0.25);
      expect(prefs.getBool('quiz_sound_correct_enabled_greekGrammar'), false);

      await QuizSoundSettings.instance.load();
      expect(QuizSoundSettings.instance.volume, 0.25);
      expect(
        QuizSoundSettings.instance.isCorrectSoundEnabled(
          SoundModule.greekGrammar,
        ),
        false,
      );
    });
  });

  group("AppTheme", () {
    test("Helles und dunkles Theme bringen ihre Palette mit", () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);

      expect(AppTheme.light.extension<AppColors>(), AppColors.light);
      expect(AppTheme.dark.extension<AppColors>(), AppColors.dark);

      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.dark.background);
      expect(AppTheme.dark.colorScheme.onSurface, AppColors.dark.textPrimary);
    });

    test("Paletten blenden beim Theme-Wechsel ineinander über", () {
      expect(
        AppColors.light.lerp(AppColors.dark, 0).primary,
        AppColors.light.primary,
      );
      expect(
        AppColors.light.lerp(AppColors.dark, 1).primary,
        AppColors.dark.primary,
      );
      expect(
        AppColors.light.copyWith(primary: Colors.pink).primary,
        Colors.pink,
      );
    });

    for (final (name, c) in [
      ("hell", AppColors.light),
      ("dunkel", AppColors.dark),
    ]) {
      test("Kontraste im Theme „$name“", () {
        // Fließtext und Beschriftungen: mindestens 4,5 : 1 (WCAG AA).
        final text = <String, (Color, Color)>{
          "Text auf Hintergrund": (c.textPrimary, c.background),
          "Text auf Karte": (c.textPrimary, c.surface),
          "Text auf gedeckter Fläche": (c.textPrimary, c.surfaceMuted),
          "Sekundärtext auf Hintergrund": (c.textSecondary, c.background),
          "Sekundärtext auf Karte": (c.textSecondary, c.surface),
          "Sekundärtext auf gedeckter Fläche": (
            c.textSecondary,
            c.surfaceMuted,
          ),
          "Hauptfarbe auf Hintergrund": (c.primary, c.background),
          "Hauptfarbe auf Karte": (c.primary, c.surface),
          "Text auf Hauptfarbe": (c.onPrimary, c.primary),
          "Richtig auf Karte": (c.success, c.surface),
          "Text auf Richtig": (c.onSuccess, c.success),
          "Falsch auf Karte": (c.error, c.surface),
          "Falsch auf Fehlerhintergrund": (c.error, c.errorBackground),
          "Text auf Falsch": (c.onError, c.error),
          "Snackbar": (c.onInverseSurface, c.inverseSurface),
        };

        // Icons, Markierungen und große Flächen: mindestens 3 : 1.
        final graphics = <String, (Color, Color)>{
          "Richtig auf Erfolgshintergrund": (c.success, c.successBackground),
          "Akzent auf Karte": (c.accent, c.surface),
          "Text auf Akzent": (c.onAccent, c.accent),
        };

        text.forEach((label, pair) {
          expect(
            _contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: label,
          );
        });

        graphics.forEach((label, pair) {
          expect(
            _contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(3),
            reason: label,
          );
        });

        // „Richtig“ (grün) und „Falsch“ (rot) bleiben klar unterscheidbar.
        final hueDistance =
            (HSLColor.fromColor(c.success).hue -
                    HSLColor.fromColor(c.error).hue)
                .abs();

        expect(hueDistance, greaterThan(90));
      });
    }
  });

  group("Erscheinungsbild in den allgemeinen Einstellungen", () {
    // Hoch genug, damit die ganze Einstellungsseite ohne Scrollen passt.
    void useTallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets("Auswahl wirkt sofort und wird gespeichert", (tester) async {
      useTallScreen(tester);

      await settings.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text("Erscheinungsbild"), findsOneWidget);
      expect(find.text("Hell"), findsOneWidget);
      expect(find.text("Dunkel"), findsOneWidget);
      expect(find.text("System"), findsOneWidget);
      expect(_brightness(tester), Brightness.light);
      expect(_chip(tester, "Hell").selected, isTrue);

      await tester.tap(find.text("Dunkel"));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);
      expect(_brightness(tester), Brightness.dark);
      expect(_chip(tester, "Dunkel").selected, isTrue);
      expect(_chip(tester, "Hell").selected, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_themeModeKey), "dark");

      await tester.tap(find.text("Hell"));
      await tester.pumpAndSettle();

      expect(_brightness(tester), Brightness.light);
      expect(prefs.getString(_themeModeKey), "light");

      // Die übrigen Einstellungen sind weiterhin vorhanden.
      expect(find.text("Antwort-Sounds"), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets("„System“ folgt dem Betriebssystem ohne Neustart", (
      tester,
    ) async {
      useTallScreen(tester);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.system);
      expect(_brightness(tester), Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(_brightness(tester), Brightness.dark);

      // Eine feste Auswahl hat Vorrang vor dem Betriebssystem.
      await tester.tap(find.text("Hell"));
      await tester.pumpAndSettle();

      expect(_brightness(tester), Brightness.light);
    });

    testWidgets("Einstellungen lassen sich im dunklen Theme vollständig "
        "durchscrollen", (tester) async {
      await settings.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text("Fehler melden"),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text("Lernfortschritte zurücksetzen"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("Widgets im dunklen Theme", () {
    Widget host(Widget child) {
      return MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: Center(child: child)),
      );
    }

    testWidgets("Chips zeigen ausgewählt, richtig und falsch mit lesbarer "
        "Beschriftung", (tester) async {
      const c = AppColors.dark;

      await tester.pumpWidget(
        host(
          Wrap(
            children: [
              SelectionChip(label: "aus", selected: false, onSelected: (_) {}),
              SelectionChip(label: "an", selected: true, onSelected: (_) {}),
              const SelectionChip(
                label: "richtig",
                selected: true,
                correct: true,
                onSelected: null,
              ),
              const SelectionChip(
                label: "falsch",
                selected: true,
                correct: false,
                onSelected: null,
              ),
            ],
          ),
        ),
      );

      Color background(String label) =>
          _chip(tester, label).color!.resolve({})!;

      expect(background("aus"), c.surfaceMuted);
      expect(background("an"), c.primary);
      expect(background("richtig"), c.success);
      expect(background("falsch"), c.error);

      for (final label in ["aus", "an", "richtig", "falsch"]) {
        expect(
          _contrast(_chip(tester, label).labelStyle!.color!, background(label)),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }
    });

    testWidgets("Ladeanzeige übernimmt die Schriftfarbe des Buttons, auch "
        "wenn er gesperrt ist", (tester) async {
      Color indicatorColor() => tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color!;

      await tester.pumpWidget(
        host(
          ElevatedButton(
            onPressed: () {},
            child: const ButtonProgressIndicator(),
          ),
        ),
      );
      expect(indicatorColor(), AppColors.dark.onPrimary);

      await tester.pumpWidget(
        host(
          const ElevatedButton(
            onPressed: null,
            child: ButtonProgressIndicator(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(indicatorColor(), AppColors.dark.onDisabled);
    });

    testWidgets("Feedback zu richtig und falsch nutzt die Farben des "
        "Themes", (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnswerFeedbackBadge(correct: true, label: "Richtig"),
              AnswerFeedbackBadge(correct: false, label: "Falsch"),
            ],
          ),
        ),
      );

      final colors = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((icon) => icon.color)
          .toSet();

      expect(colors, {AppColors.dark.success, AppColors.dark.error});
    });
  });
}
