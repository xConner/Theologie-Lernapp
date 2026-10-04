import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/greek/vocabulary/vocabulary_settings_service.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/quiz_sound_settings.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/statistics/statistics_repository.dart';
import 'package:theologie_lernapp/services/statistics/statistics_service.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/trainer_widgets.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  group("Einstellungen Griechisch-Vokabeln", () {
    test("Defaults ohne gespeicherte Werte", () {
      final settings = VocabularySettings.fromMap({});

      expect(settings.includeArticle, isTrue);
      expect(settings.includeGenitive, isTrue);
      expect(settings.includeAorist, isTrue);
      expect(settings.requireOnlyOneTranslation, isFalse);
      expect(settings.enabledSteps, [1, 2, 3, 4, 5, 6, 7]);
      expect(settings.enabledTypes, VocabularySettings.allTypes);
      expect(settings.enabledTypes, contains("numeral"));
    });

    test("Listen sind eigene, veränderbare Kopien", () {
      final settings = VocabularySettings.fromMap({});

      settings.enabledSteps.clear();
      settings.enabledTypes.remove("noun");

      expect(VocabularySettings.allSteps.length, 7);
      expect(VocabularySettings.allTypes.length, 11);
    });

    test("Gast: speichern und mit einem Zugriff wieder laden", () async {
      final service = VocabularySettingsService();

      await service.saveSettings(
        uid: null,
        includeArticle: false,
        includeGenitive: true,
        includeAorist: false,
        requireOnlyOneTranslation: true,
        enabledSteps: [2, 4],
        enabledTypes: ["verb"],
      );

      final settings = await service.load(null);

      expect(settings.includeArticle, isFalse);
      expect(settings.includeGenitive, isTrue);
      expect(settings.includeAorist, isFalse);
      expect(settings.requireOnlyOneTranslation, isTrue);
      expect(settings.enabledSteps, [2, 4]);
      expect(settings.enabledTypes, ["verb"]);
    });
  });

  group("Einstellungen Latein-Vokabeln", () {
    test("Defaults ohne gespeicherte Werte", () {
      final settings = LatinVocabularySettings.fromMap({});

      expect(settings.includeVerbForm, isTrue);
      expect(settings.includeNounForm, isTrue);
      expect(settings.includeGender, isTrue);
      expect(settings.includeAdjectiveForms, isTrue);
      expect(settings.requireOnlyOneTranslation, isTrue);
      expect(settings.enabledSubsteps, isEmpty);
      expect(settings.enabledTypes, LatinVocabularySettings.allTypes);
      expect(settings.enabledTypes, isNot(contains("numeral")));
    });

    test(
      "Gast: Unter-Schritte bleiben beim Speichern und Laden erhalten",
      () async {
        final service = LatinVocabularySettingsService();

        await service.saveSettings(
          uid: null,
          includeVerbForm: false,
          includeNounForm: true,
          includeGender: false,
          includeAdjectiveForms: true,
          requireOnlyOneTranslation: false,
          enabledSteps: [1, 3],
          enabledSubsteps: {
            1: [1, 2],
            2: [],
            3: [4],
          },
          enabledTypes: ["noun", "verb"],
        );

        final settings = await service.load(null);

        expect(settings.includeVerbForm, isFalse);
        expect(settings.includeGender, isFalse);
        expect(settings.requireOnlyOneTranslation, isFalse);
        expect(settings.enabledSubsteps, {
          1: [1, 2],
          2: [],
          3: [4],
        });
        expect(settings.enabledTypes, ["noun", "verb"]);
      },
    );
  });

  group("Lernstände im Gastmodus", () {
    test("jeder Trainer hat seine eigene Collection", () async {
      final service = LearningService();

      await service.saveCard(null, LearningCard(id: "1", difficulty: 6));
      await service.saveLatinCard(null, LearningCard(id: "1", difficulty: 7));
      await service.savePerikopeCard(
        null,
        LearningCard(id: "p", difficulty: 8),
      );
      await service.saveGrammarCards(null, [
        LearningCard(id: "lemma.1", difficulty: 9),
        LearningCard(id: "dim.verb.tense.Aorist", difficulty: 3),
      ]);

      expect((await service.loadCards(null))["1"]!.difficulty, 6);
      expect((await service.loadLatinCards(null))["1"]!.difficulty, 7);
      expect((await service.loadPerikopeCards(null)).keys, ["p"]);
      expect((await service.loadGrammarCards(null)).keys.toSet(), {
        "lemma.1",
        "dim.verb.tense.Aorist",
      });

      final store = LocalLearningStore.instance;

      expect(
        (await store.loadCards(LocalLearningStore.greekVocabulary)).length,
        1,
      );
      expect(
        (await store.loadCards(LocalLearningStore.greekGrammar)).length,
        2,
      );
    });

    test("Speichern behält eine vorhandene Lernhilfe", () async {
      final service = LearningService();

      await service.saveCard(null, LearningCard(id: "1", mnemonic: "Brücke"));
      await service.saveCard(null, LearningCard(id: "1", difficulty: 2));

      final card = (await service.loadCards(null))["1"]!;

      expect(card.mnemonic, "Brücke");
      expect(card.difficulty, 2);
    });
  });

  group("Antwort verbuchen", () {
    final now = DateTime.now();

    Future<DailyStatistics> today() async {
      await LocalStatisticsRepository.pendingWrites;

      final fresh = LearningStatisticsService(clock: () => now);

      await fresh.load(null);

      return fresh.lastSevenDays(null, StatisticsTrainer.latinVocabulary).last;
    }

    Future<void> report(
      WidgetTester tester, {
      required bool correct,
      required bool firstEvaluation,
    }) async {
      await tester.pumpWidget(_host(const SizedBox()));

      reportTrainerAnswer(
        tester.element(find.byType(SizedBox).first),
        uid: null,
        correct: correct,
        firstEvaluation: firstEvaluation,
        sound: SoundModule.latinVocabulary,
        trainer: StatisticsTrainer.latinVocabulary,
        track: StreakTrack.latin,
        source: StreakSource.vocabulary,
      );

      // Die Zählung läuft bewusst im Hintergrund.
      await LearningStatisticsService.instance.load(null);
      await tester.pump();
    }

    // Ein Test für beide Fälle: Statistik- und Sound-Dienst sind Singletons,
    // deren Warteschlangen nicht über Testgrenzen hinweg weiterlaufen.
    testWidgets("nur die erste Auswertung zählt in der Statistik", (
      tester,
    ) async {
      final before = await today();

      await report(tester, correct: false, firstEvaluation: true);

      final counted = await today();

      expect(counted.answered, before.answered + 1);
      expect(counted.wrong, before.wrong + 1);
      expect(counted.correct, before.correct);

      await report(tester, correct: true, firstEvaluation: false);

      final repeated = await today();

      expect(repeated.answered, counted.answered);
      expect(repeated.correct, counted.correct);
    });
  });

  group("Gemeinsame Trainer-Widgets", () {
    testWidgets("Rahmen der Eingabefelder nach der Auswertung", (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        late BuildContext context;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final colors = theme.extension<AppColors>()!;

        expect(
          answerResultBorder(context, null).borderSide.color,
          colors.textPrimary,
        );
        expect(
          answerResultBorder(context, true).borderSide.color,
          colors.success,
        );
        expect(
          answerResultBorder(context, false).borderSide.color,
          colors.error,
        );
        expect(answerResultBorder(context, true).borderSide.width, 2);
      }
    });

    testWidgets("Sound-Schalter wirken je Modul und sofort", (tester) async {
      final settings = QuizSoundSettings.instance;

      await settings.load();

      await tester.pumpWidget(
        _host(const SoundSettingsSection(module: SoundModule.greekGrammar)),
      );

      expect(find.text("Sounds"), findsOneWidget);
      expect(settings.isWrongSoundEnabled(SoundModule.greekGrammar), isTrue);

      await tester.tap(find.text("Sound bei falscher Antwort"));
      await tester.pump();

      expect(settings.isWrongSoundEnabled(SoundModule.greekGrammar), isFalse);
      expect(settings.isCorrectSoundEnabled(SoundModule.greekGrammar), isTrue);
      expect(settings.isWrongSoundEnabled(SoundModule.greekVocabulary), isTrue);

      final tiles = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );

      expect(tiles.map((tile) => tile.value), [true, false]);

      await tester.tap(find.text("Sound bei falscher Antwort"));
      await tester.pump();

      expect(settings.isWrongSoundEnabled(SoundModule.greekGrammar), isTrue);
    });

    testWidgets("Lernhilfe anlegen, anzeigen, bearbeiten, entfernen", (
      tester,
    ) async {
      String? stored;
      final saved = <String?>[];

      late StateSetter rebuild;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;

              return MnemonicSection(
                mnemonic: stored,
                onSave: (mnemonic) async {
                  saved.add(mnemonic);
                  rebuild(() => stored = mnemonic);
                },
              );
            },
          ),
        ),
      );

      expect(find.text("Lernhilfe hinzufügen"), findsOneWidget);

      await tester.tap(find.text("Lernhilfe hinzufügen"));
      await tester.pump();
      await tester.enterText(find.byType(TextField), "  Eselsbrücke  ");
      await tester.tap(find.text("Speichern"));
      await tester.pump();

      expect(saved, ["Eselsbrücke"]);
      expect(find.byType(TextField), findsNothing);
      expect(find.text("Eselsbrücke"), findsOneWidget);

      // Bearbeiten startet mit dem gespeicherten Text.
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        "Eselsbrücke",
      );

      // Leerer Text entfernt die Lernhilfe.
      await tester.enterText(find.byType(TextField), "   ");
      await tester.tap(find.text("Speichern"));
      await tester.pump();

      expect(saved, ["Eselsbrücke", null]);
      expect(find.text("Lernhilfe hinzufügen"), findsOneWidget);
    });
  });
}
