import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/utils/word_type_labels.dart';
import 'package:theologie_lernapp/widgets/settings_access.dart';
import 'package:theologie_lernapp/widgets/settings_selection.dart';

const allSteps = [1, 2, 3, 4, 5, 6, 7];

/// Schrittauswahl mit denselben Handlern wie in den Trainern.
Widget stepSection(List<int> enabledSteps, StateSetter setState) {
  return MultiSelectSection<int>(
    title: "Schritte",
    options: allSteps,
    isSelected: enabledSteps.contains,
    labelOf: (step) => "Schritt $step",
    emptyError: "Mindestens ein Schritt muss ausgewählt sein.",
    onToggleAll: () {
      setState(() {
        if (enabledSteps.length == 7) {
          enabledSteps.clear();
        } else {
          enabledSteps
            ..clear()
            ..addAll(allSteps);
        }
      });
    },
    onChanged: (step, value) {
      setState(() {
        if (value) {
          if (!enabledSteps.contains(step)) {
            enabledSteps.add(step);
          }
        } else {
          enabledSteps.remove(step);
        }
      });
    },
  );
}

Widget app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

bool chipSelected(WidgetTester tester, String label) {
  return tester
      .widget<SelectionChip>(find.widgetWithText(SelectionChip, label))
      .selected;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;
  });

  testWidgets("Schrittauswahl: Standard zeigt alle Schritte als ausgewählt", (
    tester,
  ) async {
    final steps = List<int>.from(allSteps);

    await tester.pumpWidget(
      app(
        StatefulBuilder(builder: (_, setState) => stepSection(steps, setState)),
      ),
    );

    for (final step in allSteps) {
      expect(chipSelected(tester, "Schritt $step"), isTrue);
    }

    expect(find.text("7 von 7 ausgewählt"), findsOneWidget);
    expect(find.text("Alle abwählen"), findsOneWidget);
  });

  testWidgets("Schrittauswahl: einzelner Schritt, mehrere Schritte und "
      "Abwahl ergeben genau die angezeigte Auswahl", (tester) async {
    final steps = List<int>.from(allSteps);

    await tester.pumpWidget(
      app(
        StatefulBuilder(builder: (_, setState) => stepSection(steps, setState)),
      ),
    );

    // Alle abwählen → Fehlerhinweis statt Zähler.
    await tester.tap(find.text("Alle abwählen"));
    await tester.pump();

    expect(steps, isEmpty);
    expect(
      find.text("Mindestens ein Schritt muss ausgewählt sein."),
      findsOneWidget,
    );
    expect(find.text("Alle auswählen"), findsOneWidget);

    // Einzelner Schritt.
    await tester.tap(find.text("Schritt 2"));
    await tester.pump();

    expect(steps, [2]);
    expect(find.text("1 von 7 ausgewählt"), findsOneWidget);

    // Mehrere Schritte.
    await tester.tap(find.text("Schritt 4"));
    await tester.pump();
    await tester.tap(find.text("Schritt 6"));
    await tester.pump();

    expect(steps, [2, 4, 6]);
    expect(find.text("3 von 7 ausgewählt"), findsOneWidget);

    for (final step in allSteps) {
      expect(chipSelected(tester, "Schritt $step"), steps.contains(step));
    }

    // Abwahl.
    await tester.tap(find.text("Schritt 4"));
    await tester.pump();

    expect(steps, [2, 6]);
    expect(chipSelected(tester, "Schritt 4"), isFalse);

    // Alle auswählen.
    await tester.tap(find.text("Alle auswählen"));
    await tester.pump();

    expect(steps, allSteps);
  });

  testWidgets("Einzelauswahl: genau eine Option ist ausgewählt, nach der "
      "Auswertung gesperrt", (tester) async {
    String? value;
    var answered = false;
    late StateSetter rebuild;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;

            return SingleSelectChips(
              label: "Kasus",
              options: const ["Nominativ", "Genitiv", "Dativ", "Akkusativ"],
              value: value,
              correct: answered ? value == "Dativ" : null,
              onChanged: answered
                  ? null
                  : (v) => setState(() {
                      value = v;
                    }),
            );
          },
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNWidgets(4));

    await tester.tap(find.text("Genitiv"));
    await tester.pump();
    await tester.tap(find.text("Dativ"));
    await tester.pump();

    expect(value, "Dativ");
    expect(chipSelected(tester, "Dativ"), isTrue);
    expect(chipSelected(tester, "Genitiv"), isFalse);

    rebuild(() {
      answered = true;
    });
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text("Akkusativ"));
    await tester.pump();

    expect(value, "Dativ");
  });

  test("Wortarten werden deutsch beschriftet, Schlüssel bleiben erhalten", () {
    expect(wordTypeFilterLabel("noun"), "Nomen");
    expect(wordTypeFilterLabel("question_word"), "Fragewörter");
    expect(wordTypeFilterLabel("numeral"), "Zahlwörter");
    expect(wordTypeFilterLabel("unbekannt"), "unbekannt");
  });

  for (final size in const [Size(320, 568), Size(820, 1180), Size(1600, 900)]) {
    testWidgets("Einstellungsdialog ohne Overflow bei ${size.width.round()} px "
        "Breite", (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final steps = [2, 4, 6];
      const types = [
        "noun",
        "verb",
        "adjective",
        "adverb",
        "pronoun",
        "preposition",
        "conjunction",
        "particle",
        "question_word",
        "numeral",
        "phrase",
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ModuleSettingsDialog(
                title: const Text("Einstellungen"),
                moduleLabel: "Vokabeltrainer",
                moduleSettings: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stepSection(steps, setState),

                      MultiSelectSection<String>(
                        title: "Wortarten",
                        options: types,
                        isSelected: (_) => true,
                        labelOf: wordTypeFilterLabel,
                        emptyError: "",
                        onToggleAll: () {},
                        onChanged: (_, _) {},
                      ),

                      SettingsSection(
                        title: "Abfrage",
                        hint: "Legt fest, was zusätzlich eingegeben wird.",
                        child: SettingsSwitchGroup(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                "Eine richtige Übersetzung reicht (empfohlen)",
                              ),
                              subtitle: const Text(
                                "Sonst müssen alle Übersetzungen genannt "
                                "werden.",
                              ),
                              value: true,
                              onChanged: (_) {},
                            ),
                          ],
                        ),
                      ),

                      const SingleSelectChips(
                        label: "Person / Numerus",
                        options: [
                          "1. Sg.",
                          "2. Sg.",
                          "3. Sg.",
                          "1. Pl.",
                          "2. Pl.",
                          "3. Pl.",
                        ],
                        value: "3. Pl.",
                        onChanged: null,
                        correct: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text("3 von 7 ausgewählt"), findsOneWidget);
    });
  }
}
