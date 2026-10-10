import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/quiz_engine.dart';
import 'package:theologie_lernapp/quiz/quiz_question.dart';
import 'package:theologie_lernapp/screens/bible/bible_reader_screen.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/quiz_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/bible/liturgical_reference_parser.dart';
import 'package:theologie_lernapp/services/bible/pericope_headings.dart';
import 'package:theologie_lernapp/services/learning_service.dart';
import 'package:theologie_lernapp/services/settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

class FakeSettingsService implements SettingsService {
  final Set<String> books;

  Set<String>? saved;

  FakeSettingsService(this.books);

  @override
  Future<Set<String>> loadBooks(String? uid) async => {...books};

  @override
  Future<void> saveBooks(String? uid, Set<String> books) async {
    saved = {...books};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLearningService implements LearningService {
  @override
  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) async => {};

  @override
  Future<void> savePerikopeCard(String? uid, LearningCard card) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = AssetBibleTextSource(bundle: FileAssetBundle());

  late List<Perikope> list;

  // Mt 14,13–21 | Mk 6,30–44 | Lk 9,10–17 unter einer ID.
  List<Perikope> feeding() =>
      list.where((p) => p.id == "speisung5000").toList();

  List<Perikope> cana() =>
      list.where((p) => p.id == "die_hochzeit_in_kana_als_zeichen").toList();

  setUpAll(() {
    list = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];
  });

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

  group("Buchauswahl und gemeinsame ID", () {
    test("Die Testperikope hat Parallelen in drei Evangelien", () {
      expect(feeding().map((p) => p.book), ["Mt", "Mk", "Lk"]);
      expect(cana().map((p) => p.book), ["Joh"]);
    });

    test("Jede Auswahl von Evangelien: Keine Frage behält eine Stelle aus "
        "einem nicht gewählten Buch", () {
      final questions = QuizQuestion.fromPerikopen(list);

      const gospels = ["Mt", "Mk", "Lk", "Joh"];

      // Alle nicht leeren Teilmengen der vier Evangelien.
      for (int mask = 1; mask < 1 << gospels.length; mask++) {
        final books = {
          for (int i = 0; i < gospels.length; i++)
            if (mask & (1 << i) != 0) gospels[i],
        };

        final filtered = QuizQuestion.forBooks(questions, books);

        for (final q in filtered) {
          expect(q.variants, isNotEmpty, reason: q.id);
          expect(
            books.containsAll(q.variants.map((p) => p.book)),
            isTrue,
            reason: "${q.id} bei $books",
          );
        }

        // Jede Stelle der gewählten Bücher bleibt abgefragt – unter ihrer
        // bisherigen ID und in der Reihenfolge der Liste.
        expect(
          [
            for (final q in filtered)
              for (final p in q.variants) "${q.id}|${p.book}|${p.startChapter}",
          ]..sort(),
          [
            for (final p in list)
              if (books.contains(p.book)) "${p.id}|${p.book}|${p.startChapter}",
          ]..sort(),
          reason: "$books",
        );
      }
    });

    test("Eine synoptische Frage folgt der Auswahl, ihre ID bleibt", () {
      final questions = QuizQuestion.fromPerikopen(feeding());

      String shown(Set<String> books) => QuizQuestion.forBooks(
        questions,
        books,
      ).expand((q) => q.variants).map((p) => p.book).join(" ");

      expect(shown({"Mk"}), "Mk");
      expect(shown({"Mt"}), "Mt");
      expect(shown({"Lk"}), "Lk");
      expect(shown({"Mt", "Lk"}), "Mt Lk");
      expect(shown({"Mt", "Mk", "Lk"}), "Mt Mk Lk");
      expect(shown({"Mt", "Mk", "Lk", "Joh", "Gen"}), "Mt Mk Lk");

      // Kein gewähltes Buch: Die Frage entfällt, statt leer zu bleiben.
      expect(QuizQuestion.forBooks(questions, {"Joh"}), isEmpty);

      expect(
        QuizQuestion.forBooks(questions, {"Mk"}).single.id,
        "speisung5000",
      );

      // Der Titel ist der der gewählten Stelle.
      expect(
        QuizQuestion.forBooks(questions, {"Mk"}).single.title,
        "Die Rückkehr der Jünger und die Speisung der Fünftausend",
      );
    });

    test("Eine Perikope ohne Parallelen bleibt unverändert", () {
      final questions = QuizQuestion.fromPerikopen(cana());

      final filtered = QuizQuestion.forBooks(questions, {"Joh", "Mk"});

      expect(filtered.single.id, questions.single.id);
      expect(filtered.single.variants, questions.single.variants);
    });

    test("Geänderte Auswahl gilt sofort für die laufende Frage", () {
      final questions = QuizQuestion.fromPerikopen(feeding());

      final engine = QuizEngine(
        QuizQuestion.forBooks(questions, {"Mt", "Mk", "Lk"}),
        {},
        uid: null,
        learningService: FakeLearningService(),
        perikopen: true,
      )..start();

      expect(engine.current!.variants, hasLength(3));

      engine.updateItems(QuizQuestion.forBooks(questions, {"Mk"}));

      expect(engine.current!.id, "speisung5000");
      expect(engine.current!.variants.map((p) => p.book), ["Mk"]);
    });
  });

  group("Vom Quiz in den Bibel-Reader", () {
    Future<FakeSettingsService> pumpQuiz(
      WidgetTester tester,
      List<Perikope> perikopen,
      Set<String> books,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final settings = FakeSettingsService(books);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuizScreen(
            perikopen: perikopen,
            uid: null,
            settingsService: settings,
            learningService: FakeLearningService(),
            bibleRepository: BibleRepository(source: source),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return settings;
    }

    /// Deckt die Lösung auf und öffnet den Reader.
    Future<void> openReader(WidgetTester tester) async {
      await tester.tap(find.text("Im Kopf"));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("self_assessment_reveal")));
      await tester.pumpAndSettle();

      await tester.ensureVisible(key("read-passage"));
      await tester.tap(key("read-passage"));
      await tester.pumpAndSettle();

      expect(find.byType(BibleReaderScreen), findsOneWidget);
    }

    /// Die Stellen, die die Leiste des Readers zur Wahl stellt.
    List<String> offered(WidgetTester tester) {
      return [
        for (final chip in tester.widgetList<ChoiceChip>(
          find.byType(ChoiceChip),
        ))
          (chip.label as Text).data!,
      ];
    }

    testWidgets("Nur Markus gewählt: nur die Markus-Stelle", (tester) async {
      await pumpQuiz(tester, feeding(), {"Mk"});

      await openReader(tester);

      expect(offered(tester), ["Mk 6,30-44"]);
      expect(find.text("Markus 6"), findsOneWidget);
      expect(find.textContaining("Mt 14"), findsNothing);
      expect(find.textContaining("Lk 9"), findsNothing);
    });

    testWidgets("Nur Matthäus gewählt: keine Markus- oder Lukas-Stelle", (
      tester,
    ) async {
      await pumpQuiz(tester, feeding(), {"Mt"});

      // Auch das Quiz selbst nennt und erwartet nur diese Stelle.
      await tester.tap(find.text("Im Kopf"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("self_assessment_reveal")));
      await tester.pumpAndSettle();

      expect(find.text("Mt 14"), findsOneWidget);
      expect(find.text("Mk 6"), findsNothing);
      expect(find.text("Lk 9"), findsNothing);
      expect(find.text("Bibelstelle lesen"), findsOneWidget);

      await tester.ensureVisible(key("read-passage"));
      await tester.tap(key("read-passage"));
      await tester.pumpAndSettle();

      expect(offered(tester), ["Mt 14,13-21"]);
      expect(find.text("Matthäus 14"), findsOneWidget);
    });

    testWidgets("Zwei Evangelien gewählt: genau deren Stellen", (tester) async {
      await pumpQuiz(tester, feeding(), {"Mt", "Lk", "Joh"});

      await openReader(tester);

      expect(offered(tester), ["Mt 14,13-21", "Lk 9,10-17"]);

      await tester.tap(key("bible-passage-1"));
      await tester.pumpAndSettle();

      expect(find.text("Lukas 9"), findsOneWidget);
    });

    testWidgets("Alle drei Synoptiker gewählt: alle Parallelstellen, jede "
        "aufschlagbar", (tester) async {
      await pumpQuiz(tester, feeding(), {"Mt", "Mk", "Lk"});

      await openReader(tester);

      expect(offered(tester), ["Mt 14,13-21", "Mk 6,30-44", "Lk 9,10-17"]);
      expect(find.text("Matthäus 14"), findsOneWidget);

      await tester.tap(key("bible-passage-1"));
      await tester.pumpAndSettle();

      expect(find.text("Markus 6"), findsOneWidget);

      await tester.tap(key("bible-passage-2"));
      await tester.pumpAndSettle();

      expect(find.text("Lukas 9"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Perikope ohne Parallelstellen: eine Stelle", (tester) async {
      await pumpQuiz(tester, cana(), {"Mt", "Mk", "Lk", "Joh"});

      await openReader(tester);

      expect(offered(tester), ["Joh 2,1-12"]);
      expect(find.text("Johannes 2"), findsOneWidget);
    });

    testWidgets("Evangelien während einer laufenden Frage abgewählt: Der "
        "Reader bietet nur noch die verbliebene Stelle", (tester) async {
      final settings = await pumpQuiz(tester, feeding(), {"Mt", "Mk", "Lk"});

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      for (final book in ["Mt", "Lk"]) {
        await tester.tap(
          find.descendant(
            of: find
                .ancestor(of: find.text(book), matching: find.byType(Row))
                .first,
            matching: find.byType(Checkbox),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(settings.saved, {"Mk"});

      await openReader(tester);

      expect(offered(tester), ["Mk 6,30-44"]);
    });
  });

  group("Andere Wege in den Reader", () {
    Future<void> pumpReader(WidgetTester tester, {String? reference}) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BibleReaderScreen(
            passages: reference == null
                ? const []
                : LiturgicalReferenceParser.parse(reference),
            repository: BibleRepository(source: source),
            pericopeHeadings: PericopeHeadings.empty,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("Der Kalender übergibt mehrere Stellen: alle bleiben "
        "erreichbar, unabhängig von der Buchauswahl des Quiz", (tester) async {
      // Im Quiz ist nur Markus gewählt (lokal gespeichert).
      SharedPreferences.setMockInitialValues({
        "guest.v1.quiz_settings.perikopen": jsonEncode({
          "selectedBooks": ["Mk"],
        }),
      });

      await pumpReader(
        tester,
        reference: "Mt 14,13-21; Mk 6,30-44; Lk 9,10-17",
      );

      expect(key("bible-passage-0"), findsOneWidget);
      expect(key("bible-passage-1"), findsOneWidget);
      expect(key("bible-passage-2"), findsOneWidget);
      expect(find.text("Matthäus 14"), findsOneWidget);

      await tester.tap(key("bible-passage-2"));
      await tester.pumpAndSettle();

      expect(find.text("Lukas 9"), findsOneWidget);
    });

    testWidgets("Freies Lesen: keine Leiste mit Stellen", (tester) async {
      SharedPreferences.setMockInitialValues({"bible_position": "MRK|6|0"});

      await pumpReader(tester);

      expect(find.text("Markus 6"), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });
}
