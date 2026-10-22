import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/exam/corpus_token.dart';
import 'package:theologie_lernapp/models/greek/exam/exam_config.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_exam.dart';
import 'package:theologie_lernapp/models/greek/exam/greek_morph_analysis.dart';
import 'package:theologie_lernapp/models/greek/exam/passage_ref.dart';
import 'package:theologie_lernapp/models/greek/exam/text_corpus.dart';
import 'package:theologie_lernapp/screens/greek/exam/exam_screen.dart';
import 'package:theologie_lernapp/screens/greek/exam/exam_task_widgets.dart';
import 'package:theologie_lernapp/services/greek/exam/corpus_codec.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_corpus_source.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_generator.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_store.dart';
import 'package:theologie_lernapp/services/greek/exam/exam_task_types.dart';
import 'package:theologie_lernapp/services/greek/exam/phenomenon_detection.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

/// Streak-Erfassung im Klausurersteller: Die erste Prüfung einer Aufgabe
/// zählt bei richtiger Antwort für den Track Altgriechisch (Quelle
/// „Klausurersteller“); erneutes Prüfen, „Nochmal“, Austauschen, Markieren
/// und bloßes Öffnen zählen nicht.

CorpusToken ctx(String surface, String lemma, String code) => CorpusToken(
  surface,
  [LemmaAnalysis(lemma, GreekMorphAnalysis(code))],
  AnalysisReliability.contextual,
);

const TextCorpus corpus = TextCorpus(
  id: "nt",
  name: "NT",
  shortName: "NT",
  edition: "",
  bibleTranslation: null,
  analysis: CorpusAnalysisKind.contextual,
  analysisNote: "",
  text: CorpusSource(name: "", license: ""),
  sources: [],
  books: ["JHN"],
  analyzedShare: 1,
);

void main() {
  final passage = ExamPassage(
    ref: PassageRef.tryParse("nt:JHN.1.1-1")!,
    corpus: corpus,
    verses: [
      CorpusVerse("1", "", [
        ctx("ἐβαπτίσθη", "βαπτίζω", "V-3API-S--"),
        ctx("ὑπὸ", "ὑπό", "P---------"),
        ctx("Ἰωάννου.", "Ἰωάννης", "N-----GSM-"),
      ]),
    ],
  );

  final choice =
      const PrepositionCaseTaskType().create(
            ExamTaskContext(
              passage: passage,
              detection: const DetectionContext(),
            ),
            Random(1),
          )
          as ChoiceTask;

  GreekExam exam() => GreekExam(
    config: const ExamConfig(),
    passage: passage,
    selection: const PassageSelection(
      matchCount: 1,
      startCount: 1,
      fixed: true,
      required: [],
      excluded: [],
    ),
    translation: const TranslationTask([]),
    verbs: const UnavailableTask("verbs", "Keine Verbformen."),
    extra: [choice, const UnavailableTask("none", "Keine weitere Aufgabe.")],
  );

  int todayExam() =>
      StreakService.instance
          .snapshotFor(null, StreakTrack.greek)
          .todaySources[StreakSource.exam] ??
      0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakService.instance.resetForTesting();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpExam(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(
      () => StreakService.instance.load(null, refresh: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GreekExamScreen(
          uid: null,
          exam: exam(),
          generator: ExamGenerator(
            source: AssetExamCorpusSource(bundle: FileAssetBundle()),
          ),
          store: LocalExamStore(),
          vocabulary: const [],
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  final check = find.byKey(const ValueKey("check-choice-1"));

  testWidgets("Öffnen zählt nicht, die erste richtige Prüfung zählt einmal", (
    tester,
  ) async {
    await pumpExam(tester);
    expect(todayExam(), 0);

    await tapVisible(tester, find.text("Genitiv"));
    await tapVisible(tester, check);
    expect(find.text("Richtig."), findsOneWidget);
    expect(todayExam(), 1);

    // „Nochmal“ und erneut richtig prüfen: dieselbe Aufgabe zählt nicht
    // noch einmal.
    await tapVisible(tester, find.text("Nochmal"));
    await tapVisible(tester, find.text("Genitiv"));
    await tapVisible(tester, check);
    expect(todayExam(), 1);

    // Als bearbeitet markieren zählt nicht.
    await tapVisible(tester, find.byKey(const ValueKey("mark-done")));
    expect(todayExam(), 1);
    expect(
      StreakService.instance
          .snapshotFor(null, StreakTrack.greek)
          .todayCorrectAnswers,
      1,
    );
  });

  testWidgets("falsche erste Prüfung zählt nicht, auch nicht nach Korrektur", (
    tester,
  ) async {
    await pumpExam(tester);

    await tapVisible(tester, find.text("Dativ"));
    await tapVisible(tester, check);
    expect(find.text("Nicht ganz. Lösung: Genitiv"), findsOneWidget);
    expect(todayExam(), 0);

    await tapVisible(tester, find.text("Nochmal"));
    await tapVisible(tester, find.text("Genitiv"));
    await tapVisible(tester, check);
    expect(find.text("Richtig."), findsOneWidget);
    expect(todayExam(), 0);
  });

  testWidgets("Aufgaben melden jede Prüfung an den Klausurbildschirm", (
    tester,
  ) async {
    final results = <(int, bool)>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChoiceTaskView(
              passage: passage,
              task: choice,
              onChecked: (token, ok) => results.add((token, ok)),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Dativ"));
    await tester.pump();
    await tester.tap(check);
    await tester.pump();
    await tester.tap(find.text("Nochmal"));
    await tester.pump();
    await tester.tap(find.text("Genitiv"));
    await tester.pump();
    await tester.tap(check);
    await tester.pump();

    expect(results, [(1, false), (1, true)]);
  });
}
