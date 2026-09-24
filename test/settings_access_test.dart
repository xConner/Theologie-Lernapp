import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/pericope_quiz/quiz_settings_sheet.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/quiz_sound_settings.dart';
import 'package:theologie_lernapp/widgets/settings_access.dart';

/// Öffnet [dialog] über einen Button, wie es die Trainer tun.
Widget host<T>(
  Widget Function(BuildContext) dialog, {
  void Function(T?)? onResult,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await showDialog<T>(
              context: context,
              barrierDismissible: false,
              builder: dialog,
            );
            onResult?.call(result);
          },
          child: const Text("öffnen"),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;
  });

  testWidgets("Screen ohne eigene Einstellungen: Zahnrad öffnet direkt die "
      "globalen Einstellungen ohne Tabs", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [SettingsButton()])),
      ),
    );

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text("Antwort-Sounds"), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);

    // Zurück schließt die Einstellungen wieder.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets("Trainer-Dialog: zwei Tabs, Modul-Tab vorausgewählt, "
      "Allgemein zeigt die globalen Einstellungen", (tester) async {
    await tester.pumpWidget(
      host<void>(
        (context) => ModuleSettingsDialog(
          title: const Text("Einstellungen"),
          moduleLabel: "Vokabeltrainer",
          moduleSettings: const Text("Modul-Inhalt"),
        ),
      ),
    );

    await tester.tap(find.text("öffnen"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, "Allgemein"), findsOneWidget);
    expect(find.widgetWithText(Tab, "Vokabeltrainer"), findsOneWidget);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, SettingsTabs.moduleTab);
    expect(find.text("Modul-Inhalt"), findsOneWidget);
    expect(find.text("Antwort-Sounds"), findsNothing);

    await tester.tap(find.text("Allgemein"));
    await tester.pumpAndSettle();

    expect(find.text("Antwort-Sounds"), findsOneWidget);
    expect(find.text("Modul-Inhalt"), findsNothing);

    // Zurücksetzen ist aus einem Trainer heraus deaktiviert.
    final reset = tester.widget<ListTile>(
      find.widgetWithText(ListTile, "Lernfortschritte zurücksetzen"),
    );
    expect(reset.enabled, isFalse);
  });

  testWidgets("Globale Einstellung aus einem Trainer-Dialog wirkt global", (
    tester,
  ) async {
    await QuizSoundSettings.instance.setVolume(QuizSoundSettings.defaultVolume);

    await tester.pumpWidget(
      host<void>(
        (context) => ModuleSettingsDialog(
          title: const Text("Einstellungen"),
          moduleLabel: "Grammatiktrainer",
          moduleSettings: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.text("öffnen"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Allgemein"));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();

    expect(QuizSoundSettings.instance.volume, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('quiz_sound_volume'), 0);
  });

  testWidgets("Perikopenquiz: Änderungen im Modul-Tab überstehen einen "
      "Tabwechsel und werden beim Bestätigen übernommen", (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Set<String>? result;

    await tester.pumpWidget(
      host<Set<String>>(
        (context) =>
            QuizSettingsSheet(selected: const {"Mt"}, onChanged: (_) {}),
        onResult: (r) => result = r,
      ),
    );

    await tester.tap(find.text("öffnen"));
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, SettingsTabs.moduleTab);
    expect(find.widgetWithText(Tab, "Perikopenquiz"), findsOneWidget);

    await tester.tap(find.text("Alle auswählen"));
    await tester.pump();

    await tester.tap(find.text("Allgemein"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Perikopenquiz"));
    await tester.pumpAndSettle();

    final all = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, "Alle auswählen"),
    );
    expect(all.value, isTrue);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, 39 + 27);
  });

  testWidgets("Kleine Bildschirmbreite: kein Overflow im Einstellungsdialog", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host<void>(
        (context) => ModuleSettingsDialog(
          title: const Text("Einstellungen"),
          moduleLabel: "Grammatiktrainer",
          moduleSettings: const SingleChildScrollView(
            child: Column(children: [SizedBox(height: 2000)]),
          ),
        ),
      ),
    );

    await tester.tap(find.text("öffnen"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("Allgemein"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
