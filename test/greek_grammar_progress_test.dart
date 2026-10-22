import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/greek_grammar_progress_view.dart';

void main() {
  final now = DateTime(2026, 10, 22);

  GrammarLearning learning(Map<String, double> difficulties) => GrammarLearning(
    cards: {
      for (final e in difficulties.entries)
        e.key: LearningCard(id: e.key)
          ..difficulty = e.value
          ..lastReviewed = now,
    },
    clock: () => now,
  );

  group("Bezeichnungen", () {
    test("Merkmalskarten werden lesbar, andere übergangen", () {
      final aorist = GrammarLearning.dimensionId("verb", "tense", "Aorist");
      final person = GrammarLearning.dimensionId("verb", "person", "2. Sg");
      final participle = GrammarLearning.dimensionId(
        "participle",
        "case",
        "Dativ",
      );

      expect(GreekGrammarProgressView.label(aorist), "Verben – Tempus: Aorist");
      expect(GreekGrammarProgressView.label(person), "Verben – Person: 2. Sg");
      expect(
        GreekGrammarProgressView.label(participle),
        "Partizipien – Kasus: Dativ",
      );
      expect(
        GreekGrammarProgressView.label(GrammarLearning.lemmaId(5)),
        isNull,
      );
      expect(
        GreekGrammarProgressView.label(
          GrammarLearning.dimensionId("comparison", "form", "σοφός"),
        ),
        isNull,
      );
    });

    test("Einstufung folgt dem Lernbedarf", () {
      expect(GreekGrammarProgressView.needLabel(2), "viel zu üben");
      expect(GreekGrammarProgressView.needLabel(1), "im Aufbau");
      expect(GreekGrammarProgressView.needLabel(0.6), "sicher");
    });
  });

  testWidgets("zeigt geübte Merkmale je Wortart und die Schwachstellen", (
    tester,
  ) async {
    final grammar = learning({
      GrammarLearning.dimensionId("verb", "tense", "Aorist"): 8,
      GrammarLearning.dimensionId("verb", "tense", "Präsens"): 3,
      GrammarLearning.dimensionId("noun", "case", "Dativ"): 5,
      GrammarLearning.lemmaId(1): 9,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: GreekGrammarProgressView(learning: grammar)),
      ),
    );

    expect(find.text("• Verben – Tempus: Aorist"), findsOneWidget);
    expect(find.text("Verben"), findsOneWidget);
    expect(find.text("Substantive"), findsOneWidget);
    expect(find.text("Pronomen"), findsNothing);
    expect(find.text("Aorist"), findsOneWidget);
    expect(find.text("Präsens"), findsOneWidget);
    expect(find.text("viel zu üben"), findsOneWidget);
    expect(find.text("sicher"), findsOneWidget);
    expect(find.text("im Aufbau"), findsOneWidget);
  });

  testWidgets("ohne Übung: Hinweise statt leerer Liste", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: GreekGrammarProgressView(learning: learning({}))),
      ),
    );

    expect(find.byKey(const ValueKey("greek-grammar-no-weak")), findsOneWidget);
    expect(find.text("Noch nichts geübt."), findsOneWidget);
  });
}
