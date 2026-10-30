import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_learning.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_controller.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/quiz/books/knowledge.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/books/knowledge_widgets.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

Finder key(String value) => find.byKey(ValueKey(value));

class FakeSettingsService implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Gen"};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLearningService implements LearningService {
  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> readJson(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 2, 8);

  late KnowledgeBank bank;
  late List<Perikope> perikopen;
  late BookOutlines outlines;

  setUpAll(() {
    bank = KnowledgeBank.merge([
      KnowledgeBank.parse(readJson("${KnowledgeBank.root}/gen.json")),
      KnowledgeBank.parse(
        readJson("assets/old_testament/model_answers/bk02-genesis.json"),
      ),
    ]);

    perikopen = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        if (entry["book"] == "Gen")
          Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];

    outlines = BookOutlines.fromJson(readJson(BookOutlines.asset));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<BookLearningController> load() async {
    final controller = await BookLearningController.load(
      perikopen: perikopen,
      uid: null,
      storage: LocalBookLearningStorage(),
      learningService: FakeLearningService(),
      settingsService: FakeSettingsService(),
      outlines: outlines,
      clock: () => now,
      loadKnowledge: (_) async => bank,
    );
    await controller.knowledgeReady;
    return controller;
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("Buchkarte: Schalter blendet das Lernen aus, Stand bleibt", (
    tester,
  ) async {
    final controller = (await tester.runAsync(load))!;

    await pump(
      tester,
      ListenableBuilder(
        listenable: controller,
        builder: (_, _) =>
            KnowledgeBookCard(controller: controller, book: "Gen"),
      ),
    );

    expect(key("knowledge-learn"), findsOneWidget);
    expect(key("knowledge-model-answers"), findsOneWidget);
    expect(find.text("Musterantworten (10)"), findsOneWidget);
    expect(
      find.textContaining("${bank.ofBook("Gen").length} Fragen"),
      findsOneWidget,
    );

    await tester.tap(key("knowledge-enabled"));
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(controller.state.knowledgeEnabled, isFalse);
    expect(key("knowledge-learn"), findsNothing);
    // Musterantworten zum Nachlesen bleiben.
    expect(key("knowledge-model-answers"), findsOneWidget);
    expect(find.textContaining("bleibt gespeichert"), findsOneWidget);

    await tester.tap(key("knowledge-enabled"));
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(key("knowledge-learn"), findsOneWidget);
  });

  testWidgets("Musterantworten: vollständiger Text und Lernfragen", (
    tester,
  ) async {
    final controller = (await tester.runAsync(load))!;
    final task = bank.tasksOf("Gen").first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ModelAnswersScreen(controller: controller, book: "Gen"),
      ),
    );
    await tester.pumpAndSettle();

    expect(key("model-answers-list"), findsOneWidget);

    await tester.tap(key("model-answer-${task.id}"));
    await tester.pumpAndSettle();

    final firstLine = task.answer.split("\n").first.trim();
    expect(find.textContaining(firstLine), findsWidgets);
    expect(key("model-answer-learn-${task.id}"), findsOneWidget);
  });

  testWidgets("Aufdecken mit Selbsteinschätzung", (tester) async {
    final controller = (await tester.runAsync(load))!;
    final q = bank.questions.firstWhere(
      (q) => q.format == KnowledgeFormat.reveal,
    );

    final answers = <bool>[];
    var next = 0;

    await pump(
      tester,
      KnowledgeTaskView(
        task: KnowledgeTask(q, const []),
        controller: controller,
        onAnswer: (correct, _) async => answers.add(correct),
        onNext: () => next++,
      ),
    );

    expect(key("knowledge-knew"), findsNothing);

    await tester.tap(key("knowledge-reveal"));
    await tester.pumpAndSettle();

    expect(find.textContaining(q.answer!.split("\n").first), findsWidgets);

    await tester.tap(key("knowledge-knew"));
    await tester.pumpAndSettle();

    expect(answers, [true]);
    // Die Selbsteinschätzung geht direkt weiter.
    expect(next, 1);
  });

  testWidgets("Auswahl: falsche Antwort zeigt die Lösung", (tester) async {
    final controller = (await tester.runAsync(load))!;
    final q = bank.questions.firstWhere(
      (q) => q.format == KnowledgeFormat.choice,
    );
    final options = [...q.distractors, ...q.correct];

    final answers = <bool>[];

    await pump(
      tester,
      KnowledgeTaskView(
        task: KnowledgeTask(q, options),
        controller: controller,
        onAnswer: (correct, _) async => answers.add(correct),
        onNext: () {},
      ),
    );

    await tester.tap(key("knowledge-option-0"));
    await tester.pumpAndSettle();

    expect(answers, [false]);
    expect(key("knowledge-feedback"), findsOneWidget);
    expect(find.textContaining(q.correct.single), findsWidgets);
    expect(key("knowledge-next"), findsOneWidget);
  });
}
