import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/info/app_info.dart';
import 'package:theologie_lernapp/models/history/history_course.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/screens/church_history/church_history_home_screen.dart';
import 'package:theologie_lernapp/screens/history/history_hub_screen.dart';
import 'package:theologie_lernapp/screens/history/history_widgets.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_home_screen.dart';
import 'package:theologie_lernapp/services/church_history/church_history_store.dart';
import 'package:theologie_lernapp/services/history/history_cards.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';
import 'package:theologie_lernapp/services/quiz_sound_settings.dart';
import 'package:theologie_lernapp/services/statistics/learning_statistics.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import '../church_history/church_history_test_data.dart';
import '../lecture_materials_test_support.dart';
import '../old_testament/old_testament_test_data.dart';
import 'history_test_support.dart';

const _area = HistoryArea(
  title: "Kirchengeschichte",
  trainer: StatisticsTrainer.churchHistory,
  track: StreakTrack.churchHistory,
  sound: SoundModule.churchHistory,
  module: AppModules.churchHistory,
);

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Beantwortet die aktuelle Aufgabe (Auswahl: erste Möglichkeit) und geht
/// weiter. false, wenn keine Aufgabe zu sehen ist.
Future<bool> _answer(WidgetTester tester) async {
  if (_key("history-option-0").evaluate().isNotEmpty) {
    await _tap(tester, _key("history-option-0"));
  } else if (_key("history-order-check").evaluate().isNotEmpty) {
    await _tap(tester, _key("history-order-check"));
  } else if (_key("history-year-input").evaluate().isNotEmpty) {
    await tester.enterText(_key("history-year-input"), "1");
    await _tap(tester, _key("history-year-check"));
  } else if (find
      .byKey(const Key("self_assessment_reveal"))
      .evaluate()
      .isNotEmpty) {
    await _tap(tester, find.byKey(const Key("self_assessment_reveal")));
    await _tap(tester, find.byKey(const Key("self_assessment_knew")));
  } else {
    return false;
  }
  if (_key("history-next").evaluate().isNotEmpty) {
    await _tap(tester, _key("history-next"));
  }
  return true;
}

void main() {
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials("Geschichte Schritt für Schritt (Oberfläche)");
    return;
  }

  final course = churchHistoryCourse();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget hub(MemoryCardStore memory, {HistoryCourse? course_}) => MaterialApp(
    theme: AppTheme.light,
    home: HistoryHubScreen(
      area: _area,
      loadCourse: () async => course_ ?? course,
      store: memory.store,
      random: Random(2),
    ),
  );

  testWidgets("Start: Weiter, Lernpfad, Übungsmodi, Zeitstrahl", (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(hub(MemoryCardStore()));
    await tester.pumpAndSettle();

    expect(_key("history-continue"), findsOneWidget);
    expect(find.text("Ersten Lernschritt starten"), findsOneWidget);
    expect(
      find.textContaining("0 von ${course.items.length} Inhalten eingeführt"),
      findsOneWidget,
    );
    for (final lesson in course.lessons) {
      expect(_key("history-lesson-${lesson.id}"), findsOneWidget);
    }
    for (final mode in [
      "people",
      "dates",
      "chronology",
      "connections",
      "mixed",
    ]) {
      expect(_key("history-mode-$mode"), findsOneWidget);
    }
    expect(_key("history-open-timeline"), findsOneWidget);
    // Ohne Eingeführtes keine Wiederholung.
    expect(_key("history-review"), findsNothing);
  });

  testWidgets("Lernschritt durcharbeiten, speichern, weiter üben", (
    tester,
  ) async {
    _largeView(tester);
    final memory = MemoryCardStore();
    await tester.pumpWidget(hub(memory));
    await tester.pumpAndSettle();

    await _tap(tester, _key("history-continue"));

    // Erst die Einführung, dann die Frage.
    expect(_key("history-intro-next"), findsOneWidget);
    expect(_key("history-option-0"), findsNothing);

    for (var i = 0; i < 80; i++) {
      if (_key("history-lesson-summary").evaluate().isNotEmpty) break;
      if (_key("history-intro-next").evaluate().isNotEmpty) {
        await _tap(tester, _key("history-intro-next"));
        continue;
      }
      expect(await _answer(tester), isTrue);
    }
    expect(_key("history-lesson-summary"), findsOneWidget);
    expect(_key("history-lesson-next"), findsOneWidget);
    expect(memory.writes, isNotEmpty);
    for (final w in memory.writes) {
      for (final id in w) {
        expect(HistoryCardBook.isHistoryCard(id), isTrue);
      }
    }

    await _tap(tester, _key("history-lesson-close"));
    final first = course.itemsOfLesson(course.lessons.first);
    expect(
      find.textContaining(
        "${first.length} von ${course.items.length} Inhalten eingeführt",
      ),
      findsOneWidget,
    );
    expect(find.text("Nächsten Lernschritt starten"), findsOneWidget);
    expect(_key("history-review"), findsOneWidget);

    // Gemischte Wiederholung: Aufgaben aus dem Eingeführten.
    await _tap(tester, _key("history-review"));
    expect(_key("history-prompt"), findsOneWidget);
    expect(await _answer(tester), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Zeitstrahl öffnet sich mit dem Eingeführten.
    await _tap(tester, _key("history-open-timeline"));
    expect(_key("timeline-only-introduced"), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Zurücksetzen nur nach Rückfrage, nur Karten des Lernpfads.
    await _tap(tester, _key("history-menu"));
    await _tap(tester, _key("history-reset"));
    await _tap(tester, _key("history-reset-confirm"));
    expect(memory.saved, isEmpty);
    expect(memory.resets.single, isNotEmpty);
    expect(
      find.textContaining("0 von ${course.items.length} Inhalten eingeführt"),
      findsOneWidget,
    );
  });

  testWidgets("Übungsmodus ohne Eingeführtes: Hinweis statt Sperre", (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(hub(MemoryCardStore()));
    await tester.pumpAndSettle();

    await _tap(tester, _key("history-mode-chronology"));
    // Nichts eingeführt: „Alle Inhalte“ ist gleich gewählt.
    expect(_key("history-prompt"), findsOneWidget);
    expect(find.textContaining("Alle Inhalte"), findsWidgets);
    expect(find.textContaining("Stufe 1 von 4"), findsOneWidget);
  });

  testWidgets("AT-Bibelkunde: eigener Lernpfad aus den Folien der Übung", (
    tester,
  ) async {
    _largeView(tester);
    final bk = oldTestamentCourse(OtCourseId.bibelkunde);
    await tester.pumpWidget(hub(MemoryCardStore(), course_: bk));
    await tester.pumpAndSettle();
    for (final lesson in bk.lessons) {
      expect(_key("history-lesson-${lesson.id}"), findsOneWidget);
    }
    await _tap(tester, _key("history-continue"));
    expect(_key("history-intro-next"), findsOneWidget);
  });

  testWidgets("Einstiege in Kirchengeschichte und Altes Testament", (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChurchHistoryHomeScreen(
          data: loadChurchHistory(),
          store: LocalChurchHistoryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key("church-history-history"), findsOneWidget);
    expect(_key("church-history-quiz"), findsOneWidget);
    expect(_key("church-history-chronology"), findsOneWidget);

    for (final c in OtCourseId.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OldTestamentHomeScreen(
            key: ValueKey(c),
            course: c,
            data: loadOldTestament().forCourse(c),
            store: LocalOldTestamentStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key("old-testament-history"), findsOneWidget);
    }
  });
}
