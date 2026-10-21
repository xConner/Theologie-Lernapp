import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/latin/vocabulary/latin_vocabulary_entry.dart';
import 'package:theologie_lernapp/screens/latin/grammar/latin_grammar_overview_screen.dart';
import 'package:theologie_lernapp/screens/latin/grammar/latin_grammar_trainer_screen.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_store.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_trainer.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_words.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Future<List<LatinVocabularyEntry>> _vocabulary() async => [
  for (final item in jsonDecode(
    File("assets/latin_vocabulary.json").readAsStringSync(),
  ))
    LatinVocabularyEntry.fromJson(item),
];

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
        _app(
          LatinGrammarTrainerScreen(
            store: store,
            random: Random(4),
            vocabulary: _vocabulary(),
          ),
        ),
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

    testWidgets("nur Bestimmen, mit Wörtern der gewählten Lektion", (
      tester,
    ) async {
      _largeView(tester);

      final vocabulary = await _vocabulary();
      final lessonOf = {for (final e in vocabulary) e.id: e.lesson};

      final store = await storeWith(
        LatinGrammarSettings(
          enabledTopics: const [LatinTrainerTopics.nounsAO],
          disabledLessons: [
            for (var lesson = 1; lesson <= 13; lesson++)
              if (lesson != 4) lesson,
          ],
        ),
      );

      await tester.pumpWidget(
        _app(
          LatinGrammarTrainerScreen(
            store: store,
            random: Random(2),
            vocabulary: Future.value(vocabulary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kein Eingabefeld zum Bilden, sondern Merkmale zum Bestimmen.
      expect(find.byKey(const ValueKey("latin-grammar-form")), findsNothing);
      expect(find.text("Kasus"), findsOneWidget);

      final form = _bigText(tester);
      final nouns = LatinGrammarWords.nouns.where(
        (n) => n.paradigm().allForms.contains(form),
      );

      expect(
        nouns.any((n) => lessonOf[n.vocabularyId] == 4),
        isTrue,
        reason: form,
      );
    });

    testWidgets("ohne mögliche Aufgabe erscheint ein Hinweis", (tester) async {
      final store = await storeWith(
        const LatinGrammarSettings(
          enabledTopics: [LatinTrainerTopics.adjectives],
          // Adjektive kommen erst ab Lektion 10 vor.
          disabledLessons: [10, 11, 12, 13],
        ),
      );

      await tester.pumpWidget(
        _app(
          LatinGrammarTrainerScreen(store: store, vocabulary: _vocabulary()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("keine Aufgaben verfügbar"), findsOneWidget);
    });
  });
}
