import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/statistics/statistics_repository.dart';
import 'package:theologie_lernapp/services/statistics/statistics_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/self_assessment.dart';

Finder key(String value) => find.byKey(Key(value));

/// Hält `revealed` wie ein Trainer und sammelt die gemeldeten Bewertungen.
class PanelHost extends StatefulWidget {
  final List<SelfAssessmentPart> parts;
  final bool withTextField;

  const PanelHost({
    super.key,
    this.parts = const [],
    this.withTextField = false,
  });

  @override
  State<PanelHost> createState() => PanelHostState();
}

class PanelHostState extends State<PanelHost> {
  final GlobalKey<SelfAssessmentPanelState> panel = GlobalKey();

  final List<SelfAssessment> assessments = [];

  bool revealed = false;

  void nextQuestion() => setState(() => revealed = false);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.withTextField) const TextField(key: Key("other_input")),
        SelfAssessmentPanel(
          key: panel,
          revealed: revealed,
          onReveal: () => setState(() => revealed = true),
          onAssess: assessments.add,
          parts: widget.parts,
          solutionBuilder: (_) => const Text("die Lösung"),
        ),
      ],
    );
  }
}

class FakeSettingsService implements SettingsService {
  @override
  Future<Set<String>> loadBooks(String? uid) async => {"Mt", "Mk", "Lk"};

  @override
  Future<void> saveBooks(String? uid, Set<String> books) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Merkt sich jeden gespeicherten Lernstand (Schwierigkeit zum Zeitpunkt des
/// Speicherns).
class RecordingLearningService implements LearningService {
  final List<double> savedDifficulties = [];

  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {};

  @override
  Future<void> savePerikopeCard(String? uid, LearningCard card) async {
    savedDifficulties.add(card.difficulty);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Perikope perikope(String book, int startChapter, int endChapter) {
  return Perikope(
    id: "frage",
    title: "Titel frage",
    book: book,
    startChapter: startChapter,
    startVerse: 1,
    endChapter: endChapter,
    endVerse: 1,
    required: true,
    precision: "chapter",
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeneralSettingsView.currentUser = () => null;

    // Antwort-Sounds haben im Test kein Audio-Backend.
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  group("Antwortmethode merken", () {
    test("Standard ist Tippen, die Wahl gilt je Trainer", () async {
      expect(
        await AnswerMethodPreference.load(AnswerMethodPreference.pericopeQuiz),
        AnswerMethod.typing,
      );

      await AnswerMethodPreference.save(
        AnswerMethodPreference.pericopeQuiz,
        AnswerMethod.recall,
      );

      expect(
        await AnswerMethodPreference.load(AnswerMethodPreference.pericopeQuiz),
        AnswerMethod.recall,
      );
      expect(
        await AnswerMethodPreference.load(
          AnswerMethodPreference.greekVocabulary,
        ),
        AnswerMethod.typing,
      );
    });
  });

  group("Panel", () {
    const parts = [
      SelfAssessmentPart(id: "case", label: "Kasus", value: "Dativ"),
      SelfAssessmentPart(id: "number", label: "Numerus", value: "Sg."),
    ];

    Future<PanelHostState> pumpPanel(
      WidgetTester tester, {
      List<SelfAssessmentPart> parts = const [],
      bool withTextField = false,
      Size size = const Size(800, 600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PanelHost(parts: parts, withTextField: withTextField),
            ),
          ),
        ),
      );

      return tester.state<PanelHostState>(find.byType(PanelHost));
    }

    testWidgets("Lösung und Bewertung erst nach dem Aufdecken", (tester) async {
      final host = await pumpPanel(tester);

      expect(find.text("die Lösung"), findsNothing);
      expect(key("self_assessment_knew"), findsNothing);
      expect(key("self_assessment_missed"), findsNothing);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pump();

      expect(find.text("die Lösung"), findsOneWidget);
      expect(key("self_assessment_reveal"), findsNothing);
      expect(host.assessments, isEmpty);

      await tester.tap(key("self_assessment_knew"));
      await tester.pump();

      expect(host.assessments.single.knew, isTrue);
      expect(host.assessments.single.missed, isEmpty);
    });

    testWidgets("Eine aufgedeckte Lösung wird nur einmal bewertet", (
      tester,
    ) async {
      final host = await pumpPanel(tester);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pump();

      // Der Trainer wechselt hier bewusst nicht die Frage.
      await tester.tap(key("self_assessment_missed"));
      await tester.tap(key("self_assessment_knew"));
      await tester.tap(key("self_assessment_missed"));
      expect(host.panel.currentState!.handleEnter(), isTrue);
      await tester.pump();

      expect(host.assessments, hasLength(1));
      expect(host.assessments.single.knew, isFalse);

      // Nächste Frage: wieder verdeckt und erneut bewertbar.
      host.nextQuestion();
      await tester.pump();

      expect(find.text("die Lösung"), findsNothing);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pump();
      await tester.tap(key("self_assessment_knew"));

      expect(host.assessments, hasLength(2));
      expect(host.assessments.last.knew, isTrue);
    });

    testWidgets("Einzelne Teile als nicht gewusst markieren", (tester) async {
      final host = await pumpPanel(tester, parts: parts);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pump();

      expect(find.text("Kasus: Dativ"), findsOneWidget);
      expect(find.text("Gewusst"), findsOneWidget);

      await tester.tap(key("self_assessment_part_case"));
      await tester.pump();

      expect(find.text("Teilweise gewusst"), findsOneWidget);

      await tester.tap(key("self_assessment_knew"));

      expect(host.assessments.single.knew, isFalse);
      expect(host.assessments.single.missed, {"case"});

      // Die Markierung gilt nicht für die nächste Frage.
      host.nextQuestion();
      await tester.pump();
      await tester.tap(key("self_assessment_reveal"));
      await tester.pump();

      expect(find.text("Gewusst"), findsOneWidget);

      await tester.tap(key("self_assessment_missed"));

      expect(host.assessments.last.knew, isFalse);
      expect(host.assessments.last.missed, {"case", "number"});
    });

    testWidgets("Eingabetaste deckt auf und bewertet als gewusst", (
      tester,
    ) async {
      final host = await pumpPanel(tester);
      final panel = host.panel.currentState!;

      expect(panel.handleEnter(), isTrue);
      await tester.pump();

      expect(find.text("die Lösung"), findsOneWidget);
      expect(host.assessments, isEmpty);

      expect(panel.handleEnter(), isTrue);

      expect(host.assessments.single.knew, isTrue);
    });

    testWidgets("Eingabetaste gehört einem fokussierten Eingabefeld", (
      tester,
    ) async {
      final host = await pumpPanel(tester, withTextField: true);
      final panel = host.panel.currentState!;

      await tester.tap(key("other_input"));
      await tester.pump();

      expect(panel.handleEnter(), isFalse);
      await tester.pump();

      expect(find.text("die Lösung"), findsNothing);
    });

    testWidgets("Kleines Display ohne Overflow", (tester) async {
      await pumpPanel(tester, parts: parts, size: const Size(280, 500));

      await tester.tap(key("self_assessment_reveal"));
      await tester.pump();
      await tester.tap(key("self_assessment_part_number"));
      await tester.pump();

      expect(find.text("Teilweise gewusst"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("Perikopenquiz", () {
    // Eine einzige Frage mit zwei erwarteten Stellen.
    final perikopen = [perikope("Mk", 8, 10), perikope("Lk", 9, 9)];

    Future<RecordingLearningService> pumpQuiz(
      WidgetTester tester, {
      Size size = const Size(1000, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final learning = RecordingLearningService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuizScreen(
            perikopen: perikopen,
            uid: null,
            settingsService: FakeSettingsService(),
            learningService: learning,
          ),
        ),
      );
      await tester.pumpAndSettle();

      return learning;
    }

    Future<void> useRecall(WidgetTester tester) async {
      await tester.tap(find.text("Im Kopf"));
      await tester.pumpAndSettle();
    }

    Future<DailyStatistics> today() async {
      await LocalStatisticsRepository.pendingWrites;

      final fresh = LearningStatisticsService();

      await fresh.load(null);

      return fresh.lastSevenDays(null, StatisticsTrainer.perikopenQuiz).last;
    }

    testWidgets("Im Kopf: Stellen erst nach dem Aufdecken; „Gewusst“ zählt "
        "wie eine richtige, „Nicht gewusst“ wie eine falsche Antwort", (
      tester,
    ) async {
      final learning = await pumpQuiz(tester);
      final before = await today();

      await useRecall(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.text("Prüfen"), findsNothing);
      expect(find.text("Mk 8-10"), findsNothing);
      expect(find.text("Merkhilfe hinzufügen"), findsNothing);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pumpAndSettle();

      expect(find.text("Mk 8-10"), findsOneWidget);
      expect(find.text("Lk 9"), findsOneWidget);
      expect(find.text("Merkhilfe hinzufügen"), findsOneWidget);
      expect(learning.savedDifficulties, isEmpty);

      await tester.tap(key("self_assessment_knew"));
      await tester.pumpAndSettle();

      // Wie eine richtige Antwort: Lernbedarf sinkt, einmal gespeichert.
      expect(learning.savedDifficulties, hasLength(1));
      expect(learning.savedDifficulties.single, lessThan(5));

      // Direkt die nächste Frage, wieder verdeckt.
      expect(find.text("Mk 8-10"), findsNothing);
      expect(key("self_assessment_reveal"), findsOneWidget);

      await LearningStatisticsService.instance.load(null);

      final known = await today();

      expect(known.answered, before.answered + 1);
      expect(known.correct, before.correct + 1);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pumpAndSettle();
      await tester.tap(key("self_assessment_missed"));
      await tester.pumpAndSettle();

      // Wie eine falsche Antwort: Lernbedarf steigt.
      expect(learning.savedDifficulties, hasLength(2));
      expect(
        learning.savedDifficulties.last,
        greaterThan(learning.savedDifficulties.first),
      );

      await LearningStatisticsService.instance.load(null);

      final missed = await today();

      expect(missed.answered, before.answered + 2);
      expect(missed.wrong, before.wrong + 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Eine Frage wird auch bei mehrfacher Bewertung nur einmal "
        "verbucht", (tester) async {
      final learning = await pumpQuiz(tester);

      await useRecall(tester);
      await tester.tap(key("self_assessment_reveal"));
      await tester.pumpAndSettle();

      final panel = tester.widget<SelfAssessmentPanel>(
        find.byType(SelfAssessmentPanel),
      );

      // Zwei Bewertungen derselben aufgedeckten Lösung, am Panel vorbei.
      panel.onAssess(const SelfAssessment(knew: true));
      panel.onAssess(const SelfAssessment(knew: false));
      await tester.pumpAndSettle();

      expect(learning.savedDifficulties, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets("Eingabetaste deckt auf und bewertet", (tester) async {
      final learning = await pumpQuiz(tester);

      await useRecall(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text("Mk 8-10"), findsOneWidget);
      expect(learning.savedDifficulties, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(learning.savedDifficulties, hasLength(1));
      expect(learning.savedDifficulties.single, lessThan(5));
      expect(find.text("Mk 8-10"), findsNothing);
    });

    testWidgets("Moduswechsel: gemerkt, nach dem Aufdecken gesperrt, "
        "Eintippen funktioniert danach unverändert", (tester) async {
      final learning = await pumpQuiz(tester);

      await useRecall(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString("answer_method.pericope_quiz"), "recall");

      await tester.tap(key("self_assessment_reveal"));
      await tester.pumpAndSettle();

      // Aufgedeckt: kein Wechsel zum Eintippen der gesehenen Lösung.
      await tester.tap(find.text("Tippen"));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text("Mk 8-10"), findsOneWidget);

      await tester.tap(key("self_assessment_knew"));
      await tester.pumpAndSettle();

      expect(learning.savedDifficulties, hasLength(1));

      await tester.tap(find.text("Tippen"));
      await tester.pumpAndSettle();

      expect(prefs.getString("answer_method.pericope_quiz"), "typing");
      expect(key("self_assessment_reveal"), findsNothing);

      await tester.enterText(find.byType(TextField).first, "Mk 8-10");
      await tester.tap(find.text("Weitere Eingabe"));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), "Lk 9");
      await tester.pump();
      await tester.tap(find.text("Prüfen"));
      await tester.pumpAndSettle();

      expect(find.textContaining("✔ Richtig"), findsOneWidget);
      expect(learning.savedDifficulties, hasLength(2));

      // Ausgewertet: der Wechsel ist bis zur nächsten Frage gesperrt.
      await tester.tap(find.text("Im Kopf"));
      await tester.pumpAndSettle();

      expect(key("self_assessment_reveal"), findsNothing);
      expect(learning.savedDifficulties, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets("Gemerkte Selbsteinschätzung gilt beim nächsten Öffnen, "
        "kleines Display ohne Overflow", (tester) async {
      SharedPreferences.setMockInitialValues({
        "answer_method.pericope_quiz": "recall",
        "pericope_quiz_quick_entry": true,
      });

      final learning = await pumpQuiz(tester, size: const Size(320, 568));

      expect(key("self_assessment_reveal"), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(learning.savedDifficulties, isEmpty);

      await tester.tap(key("self_assessment_reveal"));
      await tester.pumpAndSettle();

      expect(find.text("Lk 9"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
