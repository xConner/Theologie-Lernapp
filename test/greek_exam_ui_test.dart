import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/exam/exam_config.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/screens/greek/exam/exam_builder_screen.dart';
import 'package:theologie_lernapp/screens/greek/exam/exam_screen.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_corpus_source.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_store.dart';
import 'package:theologie_lernapp/services/greek/exam/grammar_phenomena.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/settings_selection.dart';

import 'test_asset_bundle.dart';

void main() {
  final vocabulary = [
    for (final e in jsonDecode(
      File("assets/greek_vocabulary.json").readAsStringSync(),
    ) as List)
      GreekVocabularyEntry.fromJson(e as Map<String, dynamic>),
  ];

  Future<void> open(WidgetTester tester, ExamStore store) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GreekExamBuilderScreen(
          source: AssetExamCorpusSource(bundle: FileAssetBundle()),
          store: store,
          loadVocabulary: () async => vocabulary,
          random: Random(4),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets("Phänomene kommen aus dem Katalog; heuristische nicht ausschließbar", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalExamStore();
    await open(tester, store);

    expect(find.text("Klausurersteller"), findsOneWidget);
    for (final category in GrammarPhenomena.categories.take(3)) {
      expect(find.text(category.label), findsOneWidget);
    }

    await tapVisible(tester, find.text("Partizipialkonstruktionen"));

    final excluded = find.byKey(
      const ValueKey("syntax.genitive_absolute-excluded"),
    );
    expect(tester.widget<SelectionChip>(excluded).onSelected, isNull);

    await tapVisible(
      tester,
      find.byKey(const ValueKey("syntax.genitive_absolute-required")),
    );

    // Die Konfiguration wird gespeichert.
    await tester.pump(const Duration(seconds: 1));
    final saved = await LocalExamStore().loadConfig();
    expect(
      saved.requirementOf("syntax.genitive_absolute"),
      PhenomenonRequirement.required,
    );
  });

  testWidgets("Klausur erstellen, Aufgaben austauschen, Text markieren", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalExamStore();
    await store.saveConfig(
      const ExamConfig(
        minWords: 50,
        maxWords: 90,
      ).withRequirement("verb.mood.participle", PhenomenonRequirement.required),
    );

    await open(tester, store);
    await tapVisible(tester, find.byKey(const ValueKey("generate-exam")));

    expect(find.byType(GreekExamScreen), findsOneWidget);
    expect(find.textContaining("Aufgabe 1: Übersetzen"), findsOneWidget);
    expect(find.textContaining("✓ Partizip"), findsOneWidget);
    expect(find.text("Vokabelhilfen"), findsOneWidget);

    await tapVisible(tester, find.text("Andere Verben"));
    expect(find.textContaining("Aufgabe 2"), findsOneWidget);

    // Eine Verbform prüfen: ohne Eingabe ist sie falsch.
    final check = find.byWidgetPredicate(
      (w) => w.key is ValueKey && "${(w.key as ValueKey).value}".startsWith("check-"),
    );
    await tapVisible(tester, check.first);
    expect(find.text("Nicht ganz."), findsWidgets);

    // Erst die ausdrückliche Markierung setzt den Status.
    expect(await store.loadDone(), isEmpty);
    await tapVisible(tester, find.byKey(const ValueKey("mark-done")));
    expect((await store.loadDone()).length, 1);
    expect(find.byKey(const ValueKey("unmark-done")), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey("unmark-done")));
    expect(await store.loadDone(), isEmpty);
  });

  testWidgets("Widersprüchliche Kriterien werden erklärt", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalExamStore();
    await store.saveConfig(
      const ExamConfig()
          .withRequirement("syntax.genitive_absolute", PhenomenonRequirement.required)
          .withRequirement("verb.mood.participle", PhenomenonRequirement.excluded),
    );

    await open(tester, store);
    await tapVisible(tester, find.byKey(const ValueKey("generate-exam")));

    expect(find.text("Kein passender Text gefunden"), findsOneWidget);
    expect(find.text("Widersprüchliche Kriterien"), findsOneWidget);
  });
}
