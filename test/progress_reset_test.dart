import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_learning_status.dart';
import 'package:theologie_lernapp/quiz/books/book_plan.dart';
import 'package:theologie_lernapp/quiz/books/verse_precision.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/book_learning_storage.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

Finder key(String value) => find.byKey(ValueKey(value));

/// Gelernte Karte (Werte ≠ Defaults).
LearningCard learned(String id, {String? mnemonic}) => LearningCard(
  id: id,
  stability: 50,
  difficulty: 3,
  lastReviewed: DateTime(2026, 9, 1),
  mnemonic: mnemonic,
);

class FailingProgressService extends ProgressDataService {
  @override
  Future<void> resetArea(String? uid, ProgressArea area) async {
    throw Exception("Speicher nicht erreichbar");
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = LocalLearningStore.instance;
  final service = ProgressDataService();

  late List<Perikope> perikopen;
  late BookCatalog catalog;

  setUpAll(() {
    perikopen = [
      for (final entry
          in jsonDecode(File("assets/perikopen.json").readAsStringSync())
              as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ];

    catalog = BookCatalog.fromPerikopen(perikopen);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Lernstände in allen Bereichen plus Einstellungen.
  Future<void> seedAll() async {
    await store.saveCard(LocalLearningStore.greekVocabulary, learned("g1"));
    await store.saveCard(
      LocalLearningStore.greekVocabulary,
      learned("g2", mnemonic: "Eselsbrücke"),
    );
    await store.saveCard(LocalLearningStore.greekGrammar, learned("gr1"));
    await store.saveCard(LocalLearningStore.latinVocabulary, learned("l1"));
    await store.saveCard(
      LocalLearningStore.latinVocabulary,
      learned("l2", mnemonic: "Merkhilfe"),
    );
    await store.saveCard(LocalLearningStore.memorization, learned("m1"));
    await store.saveCard(LocalLearningStore.perikopen, learned("q1"));

    await store.saveSettingsGroup("vocabulary_settings", {
      "enabledSteps": [2, 3],
      "includeArticle": true,
    });
    await store.saveSettingsGroup("latin_vocabulary_settings", {
      "enabledTypes": ["noun"],
    });
    await store.saveSelectedBooks({"Mk", "Gen"});
  }

  Future<Map<String, LearningCard>> cards(String collection) =>
      store.loadCards(collection);

  void expectUntouched(LearningCard? card) {
    expect(card, isNotNull);
    expect(card!.stability, 50);
    expect(card.difficulty, 3);
    expect(card.lastReviewed, DateTime(2026, 9, 1));
  }

  Future<void> expectSettingsKept() async {
    expect(await store.loadSettingsGroup("vocabulary_settings"), {
      "includeArticle": true,
      "enabledSteps": [2, 3],
    });
    expect(await store.loadSettingsGroup("latin_vocabulary_settings"), {
      "enabledTypes": ["noun"],
    });
    expect(await store.loadSelectedBooks(), {"Mk", "Gen"});
  }

  group("Lernbereiche einzeln", () {
    test("„Alle zurücksetzen“ umfasst genau die Bereiche", () {
      expect(LocalLearningStore.progressDocuments.toSet(), {
        for (final area in ProgressArea.values) ...area.documents,
      });

      expect(LocalLearningStore.cardCollections.toSet(), {
        for (final area in ProgressArea.values) ?area.collection,
      });

      // Fortschrittsdokumente werden auch bei der Übernahme von Gastdaten
      // kopiert.
      for (final name in LocalLearningStore.progressDocuments) {
        expect(LocalLearningStore.quizDocuments, contains(name));
      }
    });

    test("Latein-Vokabeln: Griechisch bleibt unverändert", () async {
      await seedAll();

      await service.resetArea(null, ProgressArea.latinVocabulary);

      final latin = await cards(LocalLearningStore.latinVocabulary);

      // Nur die Eselsbrücke bleibt, ohne Lernstand.
      expect(latin.keys, ["l2"]);
      expect(latin["l2"]!.mnemonic, "Merkhilfe");
      expect(latin["l2"]!.lastReviewed, isNull);

      expectUntouched((await cards(LocalLearningStore.greekVocabulary))["g1"]);
      expectUntouched((await cards(LocalLearningStore.greekGrammar))["gr1"]);
      expectUntouched((await cards(LocalLearningStore.perikopen))["q1"]);
      expectUntouched((await cards(LocalLearningStore.memorization))["m1"]);

      await expectSettingsKept();
    });

    test("Altgriechisch-Vokabeln: Latein bleibt unverändert", () async {
      await seedAll();

      await service.resetArea(null, ProgressArea.greekVocabulary);

      final greek = await cards(LocalLearningStore.greekVocabulary);

      expect(greek.keys, ["g2"]);
      expect(greek["g2"]!.mnemonic, "Eselsbrücke");

      expectUntouched((await cards(LocalLearningStore.latinVocabulary))["l1"]);
      expectUntouched((await cards(LocalLearningStore.greekGrammar))["gr1"]);

      await expectSettingsKept();
    });

    test("Grammatik: Vokabelkenntnisse bleiben", () async {
      await seedAll();

      await service.resetArea(null, ProgressArea.greekGrammar);

      expect(await cards(LocalLearningStore.greekGrammar), isEmpty);
      expectUntouched((await cards(LocalLearningStore.greekVocabulary))["g1"]);
      expectUntouched((await cards(LocalLearningStore.latinVocabulary))["l1"]);
    });

    test("Texte auswendig lernen: nur dieser Bereich", () async {
      await seedAll();

      await service.resetArea(null, ProgressArea.memorization);

      expect(await cards(LocalLearningStore.memorization), isEmpty);
      expectUntouched((await cards(LocalLearningStore.perikopen))["q1"]);
    });

    test("Perikopen: Quiz und Buchlernen, Präzisierungen bleiben", () async {
      await seedAll();

      final books = LocalBookLearningStorage();
      final p = catalog.pericopesOf("Mk").first;

      await books.saveCards([
        BookCard(id: p.key, lastReviewed: DateTime(2026)),
      ]);
      await books.savePrecision(
        p.key,
        const VersePrecision(
          startChapter: 1,
          startVerse: 1,
          endChapter: 1,
          endVerse: 4,
        ),
      );
      await books.savePlan(
        "Mk",
        BookPlan(book: "Mk", dailyNew: 2, createdAt: DateTime(2026)),
      );

      await service.resetArea(null, ProgressArea.pericopes);

      expect(await cards(LocalLearningStore.perikopen), isEmpty);

      final data = await books.load();

      expect(data.cards, isEmpty);
      expect(data.precisions, hasLength(1));
      expect(data.plans, hasLength(1));

      expectUntouched((await cards(LocalLearningStore.latinVocabulary))["l1"]);
      await expectSettingsKept();
    });
  });

  group("Perikopenkenntnisse eines Bibelbuchs", () {
    // Exklusiv in Genesis bzw. Markus; „speisung5000“ steht in Mt, Mk, Lk.
    String exclusiveId(String book) {
      final ids = {
        for (final p in perikopen)
          if (p.book != book) p.id,
      };

      return perikopen
          .firstWhere((p) => p.book == book && !ids.contains(p.id))
          .id;
    }

    test("Genesis zurücksetzen lässt andere Bücher unverändert", () async {
      final gen = exclusiveId("Gen");
      final mk = exclusiveId("Mk");

      await store.saveCard(LocalLearningStore.perikopen, learned(gen));
      await store.saveCard(
        LocalLearningStore.perikopen,
        learned(mk, mnemonic: "Mk-Hilfe"),
      );

      final genEntry = catalog.pericopesOf("Gen").first;
      final mkEntry = catalog.pericopesOf("Mk").first;

      final books = LocalBookLearningStorage();

      await books.saveCards([
        BookCard(
          id: genEntry.key,
          lastReviewed: DateTime(2026),
          spacedStreak: 2,
        ),
        BookCard(
          id: mkEntry.key,
          lastReviewed: DateTime(2026),
          spacedStreak: 2,
        ),
      ]);

      final plan = await service.resetPericopeBook(null, "Gen", perikopen);

      expect(plan.exclusiveIds, contains(gen));
      expect(plan.exclusiveIds, isNot(contains(mk)));

      final quiz = await cards(LocalLearningStore.perikopen);

      expect(quiz.containsKey(gen), isFalse);
      expectUntouched(quiz[mk]);
      expect(quiz[mk]!.mnemonic, "Mk-Hilfe");

      final data = await books.load();

      expect(data.cards.containsKey(genEntry.key), isFalse);
      expect(data.cards[mkEntry.key]!.spacedStreak, 2);
    });

    test("Eselsbrücken bleiben auch beim Buch erhalten", () async {
      final gen = exclusiveId("Gen");

      await store.saveCard(
        LocalLearningStore.perikopen,
        learned(gen, mnemonic: "Schöpfung"),
      );

      await service.resetPericopeBook(null, "Gen", perikopen);

      final card = (await cards(LocalLearningStore.perikopen))[gen]!;

      expect(card.mnemonic, "Schöpfung");
      expect(card.lastReviewed, isNull);
    });

    test("gemeinsame Karten: bleiben, aber nicht mehr als Startwert", () async {
      await store.saveCard(
        LocalLearningStore.perikopen,
        learned("speisung5000"),
      );

      final plan = await service.planPericopeBookReset(null, "Mk", perikopen);

      expect(plan.sharedIds["speisung5000"], {"Mt", "Lk"});
      expect(plan.resetIds.containsKey("speisung5000"), isFalse);

      await service.resetPericopeBook(null, "Mk", perikopen);

      // Für Mt und Lk im Perikopenquiz unverändert …
      final legacy = (await cards(
        LocalLearningStore.perikopen,
      ))["speisung5000"];
      expectUntouched(legacy);

      final data = await LocalBookLearningStorage().load();

      final mkFeeding = catalog
          .pericopesOf("Mk")
          .firstWhere((p) => p.id == "speisung5000");
      final mtFeeding = catalog
          .pericopesOf("Mt")
          .firstWhere((p) => p.id == "speisung5000");

      final now = DateTime(2026, 9, 2);

      // … beim Buchlernen beginnt Mk neu, Mt übernimmt weiter den Stand.
      expect(
        BookLearningRules.statusOf(
          data.cards[mkFeeding.key],
          legacy,
          now,
        ).level,
        LearningLevel.fresh,
      );
      expect(
        BookLearningRules.statusOf(
          data.cards[mtFeeding.key],
          legacy,
          now,
        ).fromEndlessQuiz,
        isTrue,
      );
    });

    test("gemeinsame Karten auf Wunsch mit zurücksetzen", () async {
      await store.saveCard(
        LocalLearningStore.perikopen,
        learned("speisung5000"),
      );

      final plan = await service.resetPericopeBook(
        null,
        "Mk",
        perikopen,
        includeShared: true,
      );

      expect(plan.resetIds.containsKey("speisung5000"), isTrue);
      expect(await cards(LocalLearningStore.perikopen), isEmpty);
    });

    test("Markierte Perikopen übernehmen später keinen alten Stand", () async {
      final marker = BookCard.fromJson(
        "k",
        PericopeBookResetPlan.markerJson("k"),
      );

      expect(marker.ignoreEndlessQuiz, isTrue);
      expect(marker.lastReviewed, isNull);

      // Weiterlernen behält die Markierung.
      marker.lastReviewed = DateTime(2026);
      expect(BookCard.fromJson("k", marker.toJson()).ignoreEndlessQuiz, isTrue);
    });

    test("nichts gelernt: nichts zu tun", () async {
      final plan = await service.resetPericopeBook(null, "Gen", perikopen);

      expect(plan.isEmpty, isTrue);
    });

    test("Perikopendaten bleiben unverändert", () async {
      final before = jsonEncode([
        for (final p in perikopen) [p.id, p.book, p.startChapter, p.precision],
      ]);

      await store.saveCard(
        LocalLearningStore.perikopen,
        learned("speisung5000"),
      );
      await service.resetPericopeBook(
        null,
        "Mk",
        perikopen,
        includeShared: true,
      );

      expect(
        jsonEncode([
          for (final p in perikopen)
            [p.id, p.book, p.startChapter, p.precision],
        ]),
        before,
      );
    });
  });

  group("Gesamtzurücksetzung und Sicherheit", () {
    test("alle Bereiche werden weiterhin zurückgesetzt", () async {
      await seedAll();

      await LocalBookLearningStorage().saveCards([
        BookCard(id: "Mk|x|1,1", lastReviewed: DateTime(2026)),
      ]);

      await service.resetProgress(null);

      expect(await cards(LocalLearningStore.greekGrammar), isEmpty);
      expect(await cards(LocalLearningStore.perikopen), isEmpty);
      expect(await cards(LocalLearningStore.memorization), isEmpty);
      expect((await cards(LocalLearningStore.greekVocabulary)).keys, ["g2"]);
      expect((await cards(LocalLearningStore.latinVocabulary)).keys, ["l2"]);
      expect((await LocalBookLearningStorage().load()).cards, isEmpty);

      await expectSettingsKept();
    });

    test("nur ein Zurücksetzen zur Zeit", () async {
      await seedAll();

      final first = service.resetArea(null, ProgressArea.latinVocabulary);

      expect(ProgressDataService.isResetRunning, isTrue);
      expect(
        () => service.resetArea(null, ProgressArea.greekVocabulary),
        throwsStateError,
      );

      await first;

      expect(ProgressDataService.isResetRunning, isFalse);
      // Der abgewiesene Vorgang hat nichts gelöscht.
      expectUntouched((await cards(LocalLearningStore.greekVocabulary))["g1"]);
    });

    test("Fehler geben die Sperre wieder frei", () async {
      await expectLater(
        FailingProgressService().resetArea(null, ProgressArea.pericopes),
        throwsException,
      );

      expect(ProgressDataService.isResetRunning, isFalse);
    });
  });

  group("Einstellungen: Oberfläche", () {
    late ProgressDataService Function() originalService;
    late Future<List<Perikope>> Function() originalLoader;

    setUp(() {
      originalService = GeneralSettingsView.progressService;
      originalLoader = GeneralSettingsView.loadPerikopen;

      GeneralSettingsView.currentUser = () => null;
      GeneralSettingsView.loadPerikopen = () async => perikopen;

      for (final name in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
      }
    });

    tearDown(() {
      GeneralSettingsView.progressService = originalService;
      GeneralSettingsView.loadPerikopen = originalLoader;
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: GeneralSettingsView()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        key("reset-area"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> chooseArea(WidgetTester tester, ProgressArea area) async {
      await tester.tap(key("reset-area"));
      await tester.pumpAndSettle();
      await tester.tap(key("reset-area-${area.name}"));
      await tester.pumpAndSettle();
    }

    testWidgets("Abbrechen löscht nichts", (tester) async {
      await tester.runAsync(seedAll);

      await pumpSettings(tester);
      await chooseArea(tester, ProgressArea.latinVocabulary);

      // Die Bestätigung nennt den konkreten Bereich.
      expect(
        find.text("Latein-Vokabelfortschritt zurücksetzen?"),
        findsOneWidget,
      );
      expect(find.textContaining("Alle Lernfortschritte"), findsOneWidget);

      await tester.tap(key("reset-cancel"));
      await tester.pumpAndSettle();

      final latin = await tester.runAsync(
        () => cards(LocalLearningStore.latinVocabulary),
      );

      expectUntouched(latin!["l1"]);
    });

    testWidgets("Latein zurücksetzen mit eindeutiger Meldung", (tester) async {
      await tester.runAsync(seedAll);

      await pumpSettings(tester);
      await chooseArea(tester, ProgressArea.latinVocabulary);

      await tester.tap(key("reset-confirm"));
      await tester.pumpAndSettle();

      expect(
        find.text("Latein-Vokabeln: Lernfortschritt wurde zurückgesetzt."),
        findsOneWidget,
      );

      final latin = await tester.runAsync(
        () => cards(LocalLearningStore.latinVocabulary),
      );
      final greek = await tester.runAsync(
        () => cards(LocalLearningStore.greekVocabulary),
      );

      expect(latin!.containsKey("l1"), isFalse);
      expectUntouched(greek!["g1"]);
    });

    testWidgets("Perikopen eines Bibelbuchs über die Auswahl", (tester) async {
      final others = {
        for (final p in perikopen)
          if (p.book != "Mk") p.id,
      };
      final mk = perikopen
          .firstWhere((p) => p.book == "Mk" && !others.contains(p.id))
          .id;

      await tester.runAsync(() async {
        await store.saveCard(LocalLearningStore.perikopen, learned(mk));
        await store.saveCard(
          LocalLearningStore.perikopen,
          learned("speisung5000"),
        );
      });

      await pumpSettings(tester);
      await chooseArea(tester, ProgressArea.pericopes);

      // Weiter erst nach Wahl eines Buchs.
      expect(
        tester.widget<ElevatedButton>(key("pericope-scope-next")).onPressed,
        isNull,
      );

      await tester.tap(key("pericope-scope-dropdown"));
      await tester.pumpAndSettle();

      // Das Menü ist lang und scrollt; Markus liegt weiter unten.
      final item = find.text(BookCatalog.nameOf("Mk"));

      await tester.scrollUntilVisible(
        item,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
      await tester.tap(key("pericope-scope-next"));
      await tester.pumpAndSettle();

      final name = BookCatalog.nameOf("Mk");

      expect(
        find.text("Perikopenkenntnisse für $name zurücksetzen?"),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(key("book-reset-summary")).data,
        contains("Perikopenquiz: 1 Lernstände werden gelöscht"),
      );
      expect(key("book-reset-shared"), findsOneWidget);

      await tester.tap(key("reset-confirm"));
      await tester.pumpAndSettle();

      expect(
        find.text("Perikopenkenntnisse für $name wurden zurückgesetzt."),
        findsOneWidget,
      );

      final quiz = await tester.runAsync(
        () => cards(LocalLearningStore.perikopen),
      );

      expect(quiz!.containsKey(mk), isFalse);
      expectUntouched(quiz["speisung5000"]);
    });

    testWidgets(
      "Fehler beim Speichern: verständliche Meldung, keine Erfolgsmeldung",
      (tester) async {
        GeneralSettingsView.progressService = FailingProgressService.new;

        await tester.runAsync(seedAll);

        await pumpSettings(tester);
        await chooseArea(tester, ProgressArea.pericopes);

        await tester.tap(key("pericope-scope-all"));
        await tester.pumpAndSettle();
        await tester.tap(key("pericope-scope-next"));
        await tester.pumpAndSettle();

        expect(find.text("Perikopenkenntnisse zurücksetzen?"), findsOneWidget);

        await tester.tap(key("reset-confirm"));
        await tester.pumpAndSettle();

        expect(
          find.textContaining("konnten nicht zurückgesetzt werden"),
          findsOneWidget,
        );
        expect(find.textContaining("wurden zurückgesetzt"), findsNothing);

        // Wieder bedienbar, Daten unverändert.
        expect(tester.widget<ListTile>(key("reset-area")).enabled, isTrue);

        final quiz = await tester.runAsync(
          () => cards(LocalLearningStore.perikopen),
        );

        expectUntouched(quiz!["q1"]);
      },
    );
  });
}
