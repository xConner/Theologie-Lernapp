import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/latin/grammar/latin_grammar_overview_screen.dart';
import 'package:theologie_lernapp/screens/latin/grammar/latin_grammar_trainer_screen.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_store.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_trainer.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_words.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_morphology.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/utils/latin_normalization.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Text der großen Aufgabenzeile (Form, Grundform bzw. Präposition).
String _bigText(WidgetTester tester) {
  return tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .first
      .data!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("Grammatikübersicht", () {
    testWidgets("listet alle Themen", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(_app(const LatinGrammarOverviewScreen()));

      for (final group in LatinGrammarTopics.groups) {
        expect(find.text(group.title), findsOneWidget);

        for (final topic in group.topics) {
          expect(find.text(topic.title), findsOneWidget);
        }
      }
    });

    testWidgets("jede Themenseite lässt sich ohne Fehler anzeigen", (
      tester,
    ) async {
      _largeView(tester);

      for (final group in LatinGrammarTopics.groups) {
        for (final topic in group.topics) {
          await tester.pumpWidget(_app(Builder(builder: topic.builder)));
          await tester.pump();

          expect(tester.takeException(), isNull, reason: topic.id);
          expect(find.byType(Scaffold), findsOneWidget, reason: topic.id);
        }
      }
    });

    testWidgets("Tabellen zeigen die Formen des Trainers", (tester) async {
      _largeView(tester);

      final aoTopic = LatinGrammarTopics.groups
          .expand((g) => g.topics)
          .firstWhere((t) => t.id == "declension_ao");

      await tester.pumpWidget(_app(Builder(builder: aoTopic.builder)));

      final dominus = LatinGrammarWords.nouns.firstWhere(
        (n) => n.id == "dominus",
      );

      for (final form in dominus.paradigm().allForms.toSet()) {
        expect(find.text(form), findsWidgets, reason: form);
      }
    });

    testWidgets("Satzlehre zeigt jede Konstruktion mit Beispiel", (
      tester,
    ) async {
      _largeView(tester);

      final syntax = LatinGrammarTopics.groups
          .expand((g) => g.topics)
          .firstWhere((t) => t.id == "syntax");

      await tester.pumpWidget(_app(Builder(builder: syntax.builder)));

      for (final construction in LatinConstructions.all) {
        expect(find.text(construction), findsOneWidget, reason: construction);
      }

      for (final example in LatinGrammarWords.syntaxExamples) {
        expect(find.text(example.sentence), findsOneWidget);
      }
    });
  });

  group("Grammatiktrainer", () {
    Future<LocalLatinGrammarStore> storeWith(
      LatinGrammarSettings settings,
    ) async {
      final store = LocalLatinGrammarStore();
      await store.saveSettings(settings);
      return store;
    }

    testWidgets("Präposition: richtige Auswahl wird gewertet und gespeichert", (
      tester,
    ) async {
      _largeView(tester);

      final store = await storeWith(
        const LatinGrammarSettings(
          enabledTopics: [LatinTrainerTopics.prepositions],
        ),
      );

      await tester.pumpWidget(
        _app(LatinGrammarTrainerScreen(store: store, random: Random(4))),
      );
      await tester.pumpAndSettle();

      final lemma = _bigText(tester);
      final preposition = LatinGrammarWords.prepositions.firstWhere(
        (p) => p.lemma == lemma,
      );

      await tester.tap(find.text(preposition.caseAnswer));
      await tester.pump();
      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.text("Richtig"), findsOneWidget);
      expect(find.text("Weiter"), findsOneWidget);

      final progress = await store.load();
      expect(progress.topic(LatinTrainerTopics.prepositions).correct, 1);
    });

    testWidgets("Form bilden: Eingabe ohne Längen ist richtig", (tester) async {
      _largeView(tester);

      final store = await storeWith(
        const LatinGrammarSettings(
          enabledTopics: [LatinTrainerTopics.nounsAO],
          enabledKinds: [LatinGrammarKinds.build],
        ),
      );

      await tester.pumpWidget(
        _app(LatinGrammarTrainerScreen(store: store, random: Random(9))),
      );
      await tester.pumpAndSettle();

      final dictionaryForm = _bigText(tester);
      final noun = LatinGrammarWords.nouns.firstWhere(
        (n) => n.dictionaryForm == dictionaryForm,
      );

      final hint = tester
          .widgetList<Text>(find.textContaining("Bilde: "))
          .first
          .data!
          .substring("Bilde: ".length)
          .split(" ");

      final form = noun
          .paradigm()
          .formsOf(NominalAnalysis(hint[0], hint[1]))
          .first;

      await tester.enterText(
        find.byKey(const ValueKey("latin-grammar-form")),
        stripLatinMacrons(form),
      );
      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.text("Richtig"), findsOneWidget);
    });

    testWidgets("ohne mögliche Aufgabe erscheint ein Hinweis", (tester) async {
      final store = await storeWith(
        const LatinGrammarSettings(
          enabledTopics: [LatinTrainerTopics.adjectives],
          vocabularyOnly: true,
        ),
      );

      await tester.pumpWidget(_app(LatinGrammarTrainerScreen(store: store)));
      await tester.pumpAndSettle();

      expect(find.textContaining("keine Aufgaben verfügbar"), findsOneWidget);
    });
  });
}
