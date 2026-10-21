import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/screens/church_history/church_history_home_screen.dart';
import 'package:theologie_lernapp/screens/church_history/church_history_progress_screen.dart';
import 'package:theologie_lernapp/screens/church_history/church_history_quiz_screen.dart';
import 'package:theologie_lernapp/screens/church_history/entries_screen.dart';
import 'package:theologie_lernapp/screens/church_history/entry_detail_screen.dart';
import 'package:theologie_lernapp/screens/church_history/epochs_screen.dart';
import 'package:theologie_lernapp/screens/church_history/lecture_detail_screen.dart';
import 'package:theologie_lernapp/screens/church_history/lectures_screen.dart';
import 'package:theologie_lernapp/screens/church_history/timeline_view.dart';
import 'package:theologie_lernapp/services/church_history/church_history_quiz.dart';
import 'package:theologie_lernapp/services/church_history/church_history_store.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'church_history_test_data.dart';

Widget _app(Widget home, {ThemeData? theme, Key? key}) =>
    MaterialApp(key: key, theme: theme ?? AppTheme.light, home: home);

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final data = loadChurchHistory();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LocalChurchHistoryStore> storeWith(
    ChurchHistorySettings settings,
  ) async {
    final store = LocalChurchHistoryStore();
    await store.saveSettings(settings);
    return store;
  }

  group("Navigation", () {
    testWidgets("Start → Vorlesungen → Vorlesung mit Folien", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(
          ChurchHistoryHomeScreen(data: data, store: LocalChurchHistoryStore()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("church-history-quiz")), findsOneWidget);
      expect(
        find.byKey(const ValueKey("church-history-chronology")),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey("church-history-lectures")));
      await tester.pumpAndSettle();

      expect(find.textContaining(data.course.title), findsWidgets);
      expect(find.byKey(const ValueKey("learn-all-lectures")), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("lecture-lecture.02")));
      await tester.pumpAndSettle();

      expect(find.text("Überblick"), findsOneWidget);
      expect(find.byKey(const ValueKey("lecture-learn")), findsOneWidget);

      await tester.tap(find.text("Folien"));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsWidgets);
      expect(find.byKey(const ValueKey("slide-text-8")), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("jeder Bereich der Startseite öffnet ohne Fehler", (
      tester,
    ) async {
      _largeView(tester);

      for (final key in [
        "church-history-epochs",
        "church-history-entries",
        "church-history-themes",
        "church-history-progress",
        "church-history-open-search",
      ]) {
        await tester.pumpWidget(
          _app(
            ChurchHistoryHomeScreen(
              data: data,
              store: LocalChurchHistoryStore(),
            ),
            // Neue App je Bereich, damit kein Navigationsstapel bleibt.
            key: ValueKey("app-$key"),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: key);
        expect(
          find.byKey(const ValueKey("church-history-quiz")),
          findsNothing,
          reason: key,
        );
      }
    });

    testWidgets("Veranstaltungen → Proseminar → Sitzung ohne Folien", (
      tester,
    ) async {
      _largeView(tester);

      await tester.pumpWidget(_app(LecturesScreen(data: data)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("lecture-lecture.01")), findsOneWidget);
      expect(find.textContaining("Verwandter Stoff im Thema"), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey("course-tab-course.cassian_seminar")),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(data.seminar!.title), findsWidgets);
      expect(find.byKey(const ValueKey("learn-seminar")), findsOneWidget);
      expect(
        find.byKey(const ValueKey("material-material.schwartz")),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey("lecture-seminar.02")));
      await tester.pumpAndSettle();

      expect(find.text("Überblick"), findsOneWidget);
      expect(find.text("Folien"), findsNothing);
      expect(find.text("Sitzung lernen"), findsOneWidget);
      expect(find.text("Seminarplan, S. 1"), findsWidgets);

      await tester.tap(find.text("Einträge"));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("entry-person.germanus")),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("Sitzung ohne Lernstoff bietet kein Lernen an", (tester) async {
      await tester.pumpWidget(
        _app(LectureDetailScreen(data: data, lectureId: "seminar.13")),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("lecture-learn")), findsNothing);
      expect(find.textContaining("2027"), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Vorlesung öffnet an einer bestimmten Folie", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(
          LectureDetailScreen(
            data: data,
            lectureId: "lecture.02",
            initialSlide: 14,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byKey(const ValueKey("slide-text-14")), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Dunkles Design", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(
          LectureDetailScreen(data: data, lectureId: "lecture.01"),
          theme: AppTheme.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group("Einträge", () {
    testWidgets("Ereignis zeigt Vorlesungsbezug und Verknüpfungen", (
      tester,
    ) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(
          EntryDetailScreen(data: data, entryId: "event.decian_persecution"),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Decische Verfolgung"), findsWidgets);
      expect(find.text("In den Veranstaltungen"), findsOneWidget);
      expect(find.text("Vorlesung · VL 2"), findsWidgets);
      expect(find.text("Decius"), findsWidgets);

      await tester.tap(find.text("Decius").last);
      await tester.pumpAndSettle();

      expect(find.text("Römischer Kaiser"), findsWidgets);
    });

    testWidgets("Ergänzung ohne Vorlesungsbezug ist gekennzeichnet", (
      tester,
    ) async {
      _largeView(tester);

      final supplement = data.entries.firstWhere(
        (e) => !data.isFromLecture(e.id),
      );

      await tester.pumpWidget(
        _app(EntryDetailScreen(data: data, entryId: supplement.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text("Ergänzung"), findsWidgets);
      expect(find.text("In den Veranstaltungen"), findsNothing);
    });

    testWidgets("Proseminar-Eintrag zeigt Sitzung, Fundstelle und Forschung", (
      tester,
    ) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(EntryDetailScreen(data: data, entryId: "person.cassian")),
      );
      await tester.pumpAndSettle();

      expect(find.text("Proseminar · Sitzung 1"), findsWidgets);
      expect(
        find.text("Proseminar, Sitzung 1 · Seminarplan, S. 1"),
        findsOneWidget,
      );
      expect(find.text("Ergänzung zum Proseminar"), findsOneWidget);
      expect(
        find.text("Forschungsdiskussion · Schwartz 1939, S. 1"),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("gemeinsamer Eintrag ist als „Beide“ gekennzeichnet", (
      tester,
    ) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(EntryDetailScreen(data: data, entryId: "term.periodization")),
      );
      await tester.pumpAndSettle();

      expect(find.text("Beide · VL 1 · Sitzung 1"), findsOneWidget);
      expect(find.textContaining("Vorlesung 1, Folie"), findsWidgets);
      expect(find.textContaining("Proseminar, Sitzung 1"), findsOneWidget);
    });

    testWidgets("Filter nach Veranstaltung", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(_app(EntriesScreen(data: data)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("entries-origin-seminar")));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("entry-person.cassian")),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey("entry-person.decius")), findsNothing);
      expect(
        find.byKey(const ValueKey("entry-term.periodization")),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey("entries-origin-both")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("entry-person.cassian")), findsNothing);
      expect(
        find.byKey(const ValueKey("entry-term.periodization")),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey("entries-origin-lecture")));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("entry-person.cassian")), findsNothing);
      expect(find.byKey(const ValueKey("entry-person.decius")), findsOneWidget);
    });

    testWidgets("unbekannte ID zeigt einen Hinweis statt eines Fehlers", (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(EntryDetailScreen(data: data, entryId: "person.unknown")),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group("Suche und Zeitleiste", () {
    testWidgets("Suche findet und öffnet einen Eintrag", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(
        _app(
          ChurchHistoryHomeScreen(data: data, store: LocalChurchHistoryStore()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey("church-history-open-search")),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey("church-history-search")),
        "Plinius",
      );
      await tester.pumpAndSettle();

      expect(find.text("Plinius der Jüngere"), findsOneWidget);

      await tester.tap(find.text("Plinius der Jüngere"));
      await tester.pumpAndSettle();

      expect(find.byType(EntryDetailScreen), findsOneWidget);
    });

    testWidgets("Zeitleiste zeigt Ereignisse chronologisch", (tester) async {
      _largeView(tester);

      await tester.pumpWidget(_app(EpochsScreen(data: data, initialTab: 1)));
      await tester.pumpAndSettle();

      final nero = find.byKey(const ValueKey("timeline-event.nero_64"));
      final decius = find.byKey(
        const ValueKey("timeline-event.decian_persecution"),
      );

      await tester.scrollUntilVisible(
        decius,
        300,
        scrollable: find
            .descendant(
              of: find.byType(TimelineView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        nero.evaluate().isEmpty ||
            tester.getTopLeft(nero).dy < tester.getTopLeft(decius).dy,
        isTrue,
      );

      // Personen sind zunächst ausgeblendet und lassen sich zuschalten.
      expect(
        find.byKey(const ValueKey("timeline-person.decius")),
        findsNothing,
      );
    });
  });

  group("Quiz", () {
    testWidgets("Wissensquiz: Antwort wird gewertet und gespeichert", (
      tester,
    ) async {
      _largeView(tester);

      final store = await storeWith(
        ChurchHistorySettings(
          scope: "lecture:lecture.02",
          kinds: {QuizKind.lecture},
        ),
      );

      await tester.pumpWidget(
        _app(
          ChurchHistoryQuizScreen(
            data: data,
            mode: QuizMode.knowledge,
            store: store,
            random: Random(2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("option-0")), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("option-0")));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("quiz-explanation")), findsOneWidget);
      expect(find.textContaining("Folie"), findsWidgets);

      final cards = await store.loadCards();
      expect(cards, hasLength(1));
      expect(cards.keys.single, startsWith("q.l02."));

      await tester.tap(find.byKey(const ValueKey("quiz-next")));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("quiz-explanation")), findsNothing);
    });

    testWidgets("Wissensquiz zum Proseminar zeigt die Fundstelle", (
      tester,
    ) async {
      _largeView(tester);

      final store = await storeWith(
        ChurchHistorySettings(
          scope: LearningScope.seminar.key,
          kinds: {QuizKind.lecture},
        ),
      );

      await tester.pumpWidget(
        _app(
          ChurchHistoryQuizScreen(
            data: data,
            mode: QuizMode.knowledge,
            store: store,
            random: Random(4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("option-0")));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("quiz-explanation")), findsOneWidget);
      expect(find.textContaining("Proseminar, Sitzung"), findsOneWidget);
      expect((await store.loadCards()).keys.single, startsWith("q.ps"));
    });

    testWidgets("Chronologie: Reihenfolge prüfen", (tester) async {
      _largeView(tester);

      final store = await storeWith(
        ChurchHistorySettings(kinds: {QuizKind.order}),
      );

      await tester.pumpWidget(
        _app(
          ChurchHistoryQuizScreen(
            data: data,
            mode: QuizMode.chronology,
            store: store,
            random: Random(5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("order-check")));
      await tester.pumpAndSettle();

      // Nie schon richtig vorgelegt: ungeordnet geprüft ist falsch.
      expect(find.byKey(const ValueKey("quiz-explanation")), findsOneWidget);
      expect((await store.loadCards()).length, greaterThanOrEqualTo(3));
    });

    testWidgets("„Nur schwierige“ ohne schwierige Inhalte: Hinweis", (
      tester,
    ) async {
      _largeView(tester);

      final store = await storeWith(ChurchHistorySettings(onlyDifficult: true));

      await tester.pumpWidget(
        _app(
          ChurchHistoryQuizScreen(
            data: data,
            mode: QuizMode.knowledge,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("keine schwierigen Inhalte"), findsOneWidget);
      expect(find.text("Einstellungen ändern"), findsOneWidget);
    });

    testWidgets("Fortschritt zeigt Vorlesungen und setzt zurück", (
      tester,
    ) async {
      _largeView(tester);

      final store = LocalChurchHistoryStore();
      final quiz = ChurchHistoryQuiz(data: data);
      final q = quiz.next(const LearningScope.lecture("lecture.01"), {
        QuizKind.lecture,
      })!;
      await store.saveCards(quiz.record(q, {q.cardIds.single: false}));

      await tester.pumpWidget(
        _app(ChurchHistoryProgressScreen(data: data, store: store)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("progress-lecture.01")), findsOneWidget);
      expect(
        find.byKey(const ValueKey("progress-course:seminar")),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey("progress-seminar.02")), findsOneWidget);
      expect(find.text("Schwierige Inhalte"), findsOneWidget);
      expect(find.text(q.prompt), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey("progress-lecture.01")),
          matching: find.byTooltip("Zurücksetzen"),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, "Zurücksetzen"));
      await tester.pumpAndSettle();

      expect(await store.loadCards(), isEmpty);
      expect(find.text("Zurzeit keine."), findsOneWidget);
    });
  });
}
