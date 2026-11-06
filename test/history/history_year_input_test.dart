import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/info/app_info.dart';
import 'package:theologie_lernapp/screens/history/history_widgets.dart';
import 'package:theologie_lernapp/services/history/history_trainer.dart';
import 'package:theologie_lernapp/services/quiz_sound_settings.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'history_test_support.dart';

const _area = HistoryArea(
  title: "Kirchengeschichte",
  trainer: StatisticsTrainer.churchHistory,
  track: StreakTrack.churchHistory,
  sound: SoundModule.churchHistory,
  module: AppModules.churchHistory,
);

/// Regressionstest: Die Ziffern 1–4 waren als Tastenkürzel für
/// Auswahlaufgaben gebunden und kamen bei der Jahreszahl-Eingabe (am Handy)
/// nicht im Textfeld an.
void main() {
  final course = churchHistoryCourse();
  final item = course.items.firstWhere((i) => i.dating != null);

  Future<void> pumpTask(
    WidgetTester tester,
    HistoryTask task,
    void Function(Map<String, bool>, bool) onAnswered,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HistoryTaskView(
            course: course,
            area: _area,
            task: task,
            onAnswered: onAnswered,
            onNext: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("Jahreszahl-Feld fängt keine Ziffern als Tastenkürzel ab", (
    tester,
  ) async {
    var answered = false;
    await pumpTask(
      tester,
      HistoryYearTask(
        item: item,
        prompt: "Wann?",
        min: 1234,
        max: 1234,
        beforeChrist: false,
        explanation: "",
      ),
      (_, _) => answered = true,
    );

    // Das Feld hat den Fokus; keine Ziffer darf vom Rahmen verschluckt
    // werden, sonst erreicht sie das Textfeld nicht.
    for (final key in [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit9,
    ]) {
      final handled = await tester.sendKeyEvent(key);
      expect(handled, isFalse, reason: "$key wurde abgefangen");
    }
    expect(answered, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey("history-year-input")),
      "1234",
    );
    expect(find.text("1234"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("history-year-check")));
    await tester.pumpAndSettle();
    expect(answered, isTrue);
    expect(find.text("Richtig"), findsOneWidget);
  });

  testWidgets("Ziffern wählen bei Auswahlaufgaben weiter eine Möglichkeit", (
    tester,
  ) async {
    bool? result;
    await pumpTask(
      tester,
      HistoryChoiceTask(
        skill: HistorySkill.recall,
        prompt: "Wann?",
        options: const ["100", "200", "300"],
        correctIndex: 1,
        cardIds: [HistoryTrainer.cardId(item.id, HistorySkill.recall)],
        explanation: "",
      ),
      (_, ok) => result = ok,
    );

    // Ziffer 4 gehört zu keiner Möglichkeit.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.digit4), isFalse);
    expect(result, isNull);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.digit2), isTrue);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
