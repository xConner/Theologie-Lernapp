import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/confession.dart';
import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/models/prayer.dart';
import 'package:theologie_lernapp/screens/confession_detail_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_home_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_practice_screen.dart';
import 'package:theologie_lernapp/screens/memorization/memorization_text_screen.dart';
import 'package:theologie_lernapp/screens/prayer_detail_screen.dart';
import 'package:theologie_lernapp/services/confession_service.dart';
import 'package:theologie_lernapp/services/memorization/hint_generator.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/memorization/memorization_scheduler.dart';
import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/services/prayer_service.dart';
import 'package:theologie_lernapp/services/speech/speech_recognition_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

/// Liefert vorgegebene Transkripte statt echter Spracherkennung.
class FakeSpeech implements SpeechRecognitionService {
  final List<String> transcripts;
  final bool available;
  final Set<String> languages;

  int listens = 0;
  bool cancelled = false;
  String? lastLanguage;

  FakeSpeech(
    this.transcripts, {
    this.available = true,
    this.languages = const {"de", "en"},
  });

  @override
  bool isListening = false;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<bool> supportsLanguage(String languageCode) async =>
      languages.contains(languageCode);

  @override
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  }) async {
    lastLanguage = languageCode;

    final text = transcripts[listens++];
    onPartial?.call(text);
    return text;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

/// Erkennung mit eigenem Sprachmodell (wie Latein): Das Modell muss erst
/// geladen werden, das Zuhören endet erst mit [stop].
class FakeLocalSpeech
    implements SpeechRecognitionService, LocalModelSpeechRecognition {
  final String transcript;
  final bool failPrepare;

  /// Fehler, mit dem das Zuhören endet.
  final Object? listenError;

  int pendingBytes;
  int prepared = 0;
  int listens = 0;

  Completer<String>? _listening;

  final ValueNotifier<bool> _processing = ValueNotifier(false);

  FakeLocalSpeech(
    this.transcript, {
    this.pendingBytes = 375 * 1000 * 1000,
    this.failPrepare = false,
    this.listenError,
  });

  @override
  bool get isListening => _listening != null;

  @override
  ValueListenable<bool> get isProcessing => _processing;

  @override
  Future<bool> initialize() async => true;

  @override
  bool usesLocalModel(String languageCode) => languageCode == "la";

  @override
  Future<bool> supportsLanguage(String languageCode) async =>
      languageCode == "la";

  @override
  Future<int> pendingDownloadBytes(String languageCode) async => pendingBytes;

  @override
  Future<void> prepareModel(
    String languageCode, {
    void Function(double fraction)? onProgress,
  }) async {
    if (failPrepare) throw StateError("latin-speech-model");

    onProgress?.call(0.5);
    onProgress?.call(1);

    prepared++;
    pendingBytes = 0;
  }

  @override
  Future<String> listen({
    required String languageCode,
    void Function(String text)? onPartial,
  }) {
    listens++;

    if (listenError != null) return Future.error(listenError!);

    return (_listening = Completer<String>()).future;
  }

  @override
  Future<void> stop() async {
    _processing.value = true;
    _processing.value = false;

    _listening?.complete(transcript);
    _listening = null;
  }

  @override
  Future<void> cancel() async {
    final listening = _listening;

    _listening = null;

    if (listening != null && !listening.isCompleted) listening.complete("");
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Prayer> prayers;
  late List<Confession> confessions;
  late MemorizationCatalog catalog;

  // Erst im Test selbst anlegen: Futures aus setUp gehören nicht zum
  // Fake-Async des Widget-Tests und würden dort nie fortgesetzt.
  MemorizationRepository? created;

  MemorizationRepository ensureRepository() {
    return MemorizationRepository.debugOverride = created ??=
        MemorizationRepository(null);
  }

  setUpAll(() async {
    prayers = await PrayerService().loadPrayers();
    confessions = await ConfessionService().loadConfessions();
    catalog = await MemorizationCatalog.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    created = null;
  });

  tearDown(() {
    MemorizationRepository.debugOverride = null;
  });

  Widget app(Widget home) {
    ensureRepository();

    return MaterialApp(theme: AppTheme.light, home: home);
  }

  MemorizationText vaterunser() => catalog.text("prayer.vaterunser.de")!;

  /// Wartet auf [future]; im Fake-Async der Widget-Tests laufen Speicher-
  /// zugriffe nur weiter, wenn gepumpt wird.
  Future<void> drive(WidgetTester tester, Future<void> future) async {
    var done = false;
    Object? failure;

    future.then(
      (_) => done = true,
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );

    for (var i = 0; i < 100 && !done; i++) {
      await tester.pump();
    }

    expect(done, isTrue, reason: "Speicherzugriff nicht abgeschlossen");
    expect(failure, isNull);
  }

  Future<void> pumpPractice(
    WidgetTester tester,
    List<PracticeUnit> units, {
    SpeechRecognitionService? speech,
  }) async {
    await drive(tester, ensureRepository().load());

    await tester.pumpWidget(
      app(
        MemorizationPracticeScreen(
          repository: ensureRepository(),
          units: units,
          speech: speech ?? FakeSpeech(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group("Einstieg aus bestehenden Ansichten", () {
    testWidgets("Gebet: Ansicht bleibt, „Auswendig lernen“ öffnet den Text", (
      tester,
    ) async {
      final prayer = prayers.firstWhere((p) => p.id == "vaterunser");

      await tester.pumpWidget(app(PrayerDetailScreen(prayer: prayer)));

      // Die bestehende Ansicht ist unverändert vorhanden.
      expect(find.byKey(const Key("prayer_text")), findsOneWidget);
      expect(find.byKey(const Key("prayer_language_la")), findsOneWidget);

      // Die lateinische Fassung wird als eigener Lerntext geöffnet.
      await tester.tap(find.byKey(const Key("prayer_language_la")));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key("prayer_memorize")));

      expect(find.byType(MemorizationTextScreen), findsOneWidget);
      expect(find.text("Pater noster"), findsOneWidget);
      expect(find.text("0 / 8 Abschnitte gelernt"), findsOneWidget);
      expect(find.text("2 neue Abschnitte"), findsOneWidget);
      expect(find.text("Lernen beginnen"), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(PrayerDetailScreen), findsOneWidget);
      expect(find.byKey(const Key("prayer_text")), findsOneWidget);
    });

    testWidgets("Bekenntnis: „Auswendig lernen“ öffnet den Text", (
      tester,
    ) async {
      final creed = confessions.firstWhere((c) => c.id == "apostolicum");

      await tester.pumpWidget(app(ConfessionDetailScreen(confession: creed)));

      expect(
        find.textContaining("Ich glaube an Gott", findRichText: true),
        findsOneWidget,
      );

      await tapVisible(tester, find.byKey(const Key("confession_memorize")));

      expect(find.byType(MemorizationTextScreen), findsOneWidget);
      expect(find.text("0 / 12 Abschnitte gelernt"), findsOneWidget);
      expect(find.byKey(const Key("memorize_language_la")), findsOneWidget);
    });

    testWidgets("Bekenntnis ohne Text in der Sprache bietet nichts an", (
      tester,
    ) async {
      final ca = Confession.fromJson({
        "id": "test",
        "category": "lutherische_symbole",
        "title": {"de": "Testbekenntnis"},
        "languages": ["de", "en"],
        "sections": [
          {
            "id": "full",
            "title": {"de": "Gesamter Text"},
            "texts": {"de": "Erstlich wird gelehrt und gehalten.", "en": ""},
          },
        ],
      });

      await tester.pumpWidget(app(ConfessionDetailScreen(confession: ca)));

      expect(find.byKey(const Key("confession_memorize")), findsOneWidget);

      // Die englische Fassung ist angelegt, aber leer.
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Englisch").last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("confession_memorize")), findsNothing);
    });

    test("Deep Link /memorize ist registriert", () {
      expect(AppDeepLink.parse("/memorize")?.path, AppDeepLink.memorize);
    });
  });

  group("Lerntext", () {
    testWidgets("Abschnitt gezielt üben, Fortschritt wird gespeichert", (
      tester,
    ) async {
      final work = catalog.workOf(vaterunser())!;

      await tester.pumpWidget(
        app(MemorizationTextScreen(work: work, languageCode: "de")),
      );
      await tester.pumpAndSettle();

      expect(find.text("0 / 8 Abschnitte gelernt"), findsOneWidget);
      expect(find.text("Dein Reich komme."), findsOneWidget);

      // „Diese Stelle lernen“
      await tapVisible(tester, find.byKey(const Key("memorize_segment_2")));

      expect(find.byType(MemorizationPracticeScreen), findsOneWidget);
      expect(find.text("Abschnitt 3 von 8 · Deutsch"), findsOneWidget);

      // Direkt frei wiedergeben.
      await tapVisible(tester, find.byKey(const Key("memorize_level_free")));
      expect(find.byKey(const Key("memorize_prompt")), findsNothing);

      await tester.enterText(
        find.byKey(const Key("memorize_input")),
        "dein reich komme",
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Wortgetreu"), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key("memorize_next")));
      expect(find.byKey(const Key("memorize_summary")), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key("memorize_done")));

      expect(find.byType(MemorizationTextScreen), findsOneWidget);
      expect(find.text("1 / 8 Abschnitte gelernt"), findsOneWidget);

      // Der Text steht jetzt unter „Meine Texte“, der Lernstand ist lokal
      // gespeichert.
      expect(ensureRepository().contains("prayer.vaterunser.de"), isTrue);

      final reloaded = MemorizationRepository(null);
      await drive(tester, reloaded.load());

      expect(reloaded.cards["prayer.vaterunser.de.s2"]!.learned, isTrue);
      expect(reloaded.textIds, ["prayer.vaterunser.de"]);
    });

    testWidgets("Sprachfassungen haben getrennten Lernstand", (tester) async {
      final work = catalog.workOf(vaterunser())!;

      await drive(tester, ensureRepository().load());
      await drive(
        tester,
        ensureRepository().saveCards([
          MemorizationScheduler()
              .apply(
                unit: PracticeUnit.segment(vaterunser(), 0, HintLevel.free),
                practiced: HintLevel.free,
                outcome: RecallOutcome.correct,
                cards: ensureRepository().cards,
              )
              .single,
        ]),
      );

      await tester.pumpWidget(
        app(MemorizationTextScreen(work: work, languageCode: "de")),
      );
      await tester.pumpAndSettle();

      expect(find.text("1 / 8 Abschnitte gelernt"), findsOneWidget);

      await tester.tap(find.byKey(const Key("memorize_language_la")));
      await tester.pumpAndSettle();

      expect(find.text("Pater noster"), findsOneWidget);
      expect(find.text("0 / 8 Abschnitte gelernt"), findsOneWidget);
    });
  });

  group("Abschnittstitel", () {
    MemorizationText commandments() => catalog.text("prayer.zehn_gebote.de")!;

    testWidgets("Textansicht: Titel zur Orientierung, das Gebot als "
        "Abschnitt", (tester) async {
      final work = catalog.workOf(commandments())!;

      await tester.pumpWidget(
        app(MemorizationTextScreen(work: work, languageCode: "de")),
      );
      await tester.pumpAndSettle();

      expect(find.text("0 / 10 Abschnitte gelernt"), findsOneWidget);
      expect(find.text("Das erste Gebot"), findsOneWidget);
      expect(find.text("Du sollst nicht andere Götter haben."), findsOneWidget);

      // Die Überschrift ist kein eigener Abschnitt.
      expect(find.text("Das erste Gebot."), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_segment_4")));

      expect(find.byType(MemorizationPracticeScreen), findsOneWidget);
      expect(find.text("Abschnitt 5 von 10 · Deutsch"), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key("memorize_heading"))).data,
        "Das fünfte Gebot",
      );
      expect(
        tester.widget<Text>(find.byKey(const Key("memorize_prompt"))).data,
        "Du sollst nicht töten.",
      );
    });

    testWidgets("Übung: gefragt ist nur der Wortlaut des Gebots", (
      tester,
    ) async {
      await pumpPractice(tester, [
        PracticeUnit.segment(commandments(), 4, HintLevel.free),
      ]);

      // Frei wiedergeben: Der Titel sagt, welches Gebot gemeint ist.
      expect(find.text("Das fünfte Gebot"), findsOneWidget);
      expect(find.byKey(const Key("memorize_prompt")), findsNothing);

      await tester.enterText(
        find.byKey(const Key("memorize_input")),
        "Du sollst nicht töten",
      );
      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      final card = ensureRepository().cards["prayer.zehn_gebote.de.s9"]!;

      expect(card.learned, isTrue);
    });

    testWidgets("Texte ohne Überschriften zeigen keinen Titel", (tester) async {
      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 3, HintLevel.read),
      ]);

      expect(find.byKey(const Key("memorize_heading")), findsNothing);
    });
  });

  group("Übung", () {
    testWidgets("Mitlesen, dann Lücken tippen", (tester) async {
      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 3, HintLevel.read),
      ]);

      expect(
        tester.widget<Text>(find.byKey(const Key("memorize_prompt"))).data,
        "Dein Wille geschehe,\nwie im Himmel, so auf Erden.",
      );
      expect(find.byKey(const Key("memorize_input")), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_read_done")));

      // Derselbe Abschnitt kommt mit Lücken wieder.
      final prompt = tester
          .widget<Text>(find.byKey(const Key("memorize_prompt")))
          .data!;

      expect(prompt, contains(HintGenerator.gap));
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key("memorize_level_fewGaps")))
            .selected,
        isTrue,
      );

      // Die fehlenden Wörter sind die, die im Lückentext nicht mehr stehen.
      final shown = prompt.replaceAll(RegExp(r"[,.\n]"), " ").split(" ");
      final missing = [
        for (final word
            in "Dein Wille geschehe wie im Himmel so auf Erden".split(" "))
          if (!shown.contains(word)) word,
      ];

      await tester.enterText(
        find.byKey(const Key("memorize_input")),
        missing.join(" "),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Wortgetreu"), findsOneWidget);
      expect(
        ensureRepository().cards[vaterunser().segments[3].id]!.level,
        HintLevel.manyGaps.index,
      );
    });

    testWidgets("Abweichungen werden benannt", (tester) async {
      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 4, HintLevel.free),
      ]);

      expect(find.textContaining("Zuvor:"), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key("memorize_input")),
        "Unser tägliches Brot gib uns",
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Fast – kleine Abweichungen"), findsOneWidget);
      expect(find.text("Es fehlt: „heute“"), findsOneWidget);

      final card = ensureRepository().cards[vaterunser().segments[4].id]!;

      expect(card.learned, isFalse);
      expect(card.failures, 1);

      // Der Abschnitt bleibt in der Runde.
      await tapVisible(tester, find.byKey(const Key("memorize_next")));
      expect(find.byKey(const Key("memorize_summary")), findsNothing);
      expect(find.text("Abschnitt 5 von 8 · Deutsch"), findsOneWidget);
    });

    testWidgets("Sprechen: Hinweis, Transkript, lokaler Vergleich", (
      tester,
    ) async {
      final speech = FakeSpeech([
        "dein Wille geschehe",
        "wie im Himmel auf Erden",
      ]);

      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 3, HintLevel.free),
      ], speech: speech);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();

      // Vor der ersten Nutzung wird auf den Plattformdienst hingewiesen.
      expect(find.text("Aufsagen mit Spracherkennung"), findsOneWidget);
      await tester.tap(find.text("Einverstanden"));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key("memorize_mic")));
      await tapVisible(tester, find.byKey(const Key("memorize_mic")));

      // Nach einer Sprechpause wird weitergesprochen.
      expect(
        tester.widget<Text>(find.byKey(const Key("memorize_transcript"))).data,
        "dein Wille geschehe wie im Himmel auf Erden",
      );

      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Es fehlt: „so“"), findsOneWidget);
      expect(speech.listens, 2);
    });

    testWidgets("Sprechen: ohne Zustimmung bleibt es beim Tippen", (
      tester,
    ) async {
      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 3, HintLevel.free),
      ]);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Abbrechen"));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("memorize_mic")), findsNothing);
      expect(find.byKey(const Key("memorize_input")), findsOneWidget);
    });

    testWidgets("Sprechen: nicht verfügbar → verständlicher Hinweis", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 3, HintLevel.free),
      ], speech: FakeSpeech(const [], available: false));

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("memorize_mic")), findsNothing);
      expect(find.textContaining("nicht verfügbar"), findsOneWidget);
    });

    testWidgets("Sprechen: Dienst ohne Erkennung für die Sprache", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      await pumpPractice(tester, [
        PracticeUnit.segment(
          catalog.text("prayer.vaterunser.la")!,
          0,
          HintLevel.free,
        ),
      ]);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key("memorize_mic")));

      expect(find.textContaining("Für Latein"), findsOneWidget);
      expect(find.byKey(const Key("memorize_transcript")), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Sprechen: Latein mit eigenem Modell – Laden, Zuhören, "
        "lautlicher Abgleich", (tester) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      final text = catalog.text("prayer.vaterunser.la")!;

      // So schreibt das Modell nach Gehör.
      final speech = FakeLocalSpeech("Pater noster kui es in chelis");

      await pumpPractice(tester, [
        PracticeUnit.segment(text, 0, HintLevel.free),
      ], speech: speech);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key("memorize_mic")));

      // Vor dem einmaligen Herunterladen wird gefragt.
      expect(find.text("Sprachmodell für Latein laden"), findsOneWidget);
      expect(find.textContaining("375 MB"), findsOneWidget);
      expect(speech.prepared, 0);

      await tester.tap(find.byKey(const Key("memorize_model_download")));
      await tester.pumpAndSettle();

      // Nach dem Herunterladen wird nicht unvermittelt zugehört.
      expect(speech.prepared, 1);
      expect(speech.listens, 0);
      expect(find.byKey(const Key("memorize_speech_progress")), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_mic")));

      expect(speech.listens, 1);
      expect(find.textContaining("Tippe auf Stopp"), findsOneWidget);
      expect(find.text("Sprachmodell für Latein laden"), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_mic")));

      // Angezeigt wird, was erkannt wurde.
      expect(
        tester.widget<Text>(find.byKey(const Key("memorize_transcript"))).data,
        "Pater noster kui es in chelis",
      );

      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Wortgetreu"), findsOneWidget);
    });

    testWidgets("Sprechen: Latein – falsches Wort bleibt eine Abweichung", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      final speech = FakeLocalSpeech(
        "Mater noster kui es in chelis",
        pendingBytes: 0,
      );

      await pumpPractice(tester, [
        PracticeUnit.segment(
          catalog.text("prayer.vaterunser.la")!,
          0,
          HintLevel.free,
        ),
      ], speech: speech);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();

      // Modell liegt vor: keine Rückfrage, es wird sofort zugehört.
      await tapVisible(tester, find.byKey(const Key("memorize_mic")));
      expect(find.text("Sprachmodell für Latein laden"), findsNothing);
      expect(speech.listens, 1);

      await tapVisible(tester, find.byKey(const Key("memorize_mic")));
      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Wortgetreu"), findsNothing);
      expect(find.text("Anderes Wort: „Mater“ statt „Pater“"), findsOneWidget);
    });

    testWidgets("Sprechen: Latein – Download abgelehnt oder fehlgeschlagen", (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      final speech = FakeLocalSpeech("", failPrepare: true);

      await pumpPractice(tester, [
        PracticeUnit.segment(
          catalog.text("prayer.vaterunser.la")!,
          0,
          HintLevel.free,
        ),
      ], speech: speech);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key("memorize_mic")));
      await tester.tap(find.text("Abbrechen"));
      await tester.pumpAndSettle();

      expect(speech.listens, 0);
      expect(find.byKey(const Key("memorize_mic")), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key("memorize_mic")));
      await tester.tap(find.byKey(const Key("memorize_model_download")));
      await tester.pumpAndSettle();

      expect(speech.listens, 0);
      expect(
        find.textContaining("konnte nicht geladen werden"),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("Sprechen: Latein – Fehler nennen die Ursache", (tester) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      const cases = {
        SpeechRecognitionException(SpeechFailure.microphonePermission):
            "nicht freigegeben",
        SpeechRecognitionException(
          SpeechFailure.microphone,
          "NotReadableError: Could not start audio source",
        ): "Mikrofon konnte nicht gestartet werden",
        SpeechRecognitionException(SpeechFailure.recognition, "worker failed"):
            "konnte nicht ausgewertet werden",
      };

      for (final entry in cases.entries) {
        final speech = FakeLocalSpeech(
          "",
          pendingBytes: 0,
          listenError: entry.key,
        );

        await pumpPractice(tester, [
          PracticeUnit.segment(
            catalog.text("prayer.vaterunser.la")!,
            0,
            HintLevel.free,
          ),
        ], speech: speech);

        await tester.tap(find.text("Sprechen"));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key("memorize_mic")));

        expect(find.textContaining(entry.value), findsOneWidget);

        // Die Ursache der Plattform steht dabei, das Mikrofon bleibt bedienbar.
        final cause = entry.key.cause;

        if (cause != null) {
          expect(find.textContaining("$cause"), findsOneWidget);
        }

        expect(find.textContaining("Ich höre zu"), findsNothing);
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key("memorize_mic")))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);

        // Nächster Fall mit frischem Bildschirm.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets("Sprechen: Latein, exaktes Transkript", (tester) async {
      SharedPreferences.setMockInitialValues({
        "memorization.speechNoticeAccepted": true,
      });

      final text = catalog.text("prayer.vaterunser.la")!;

      // So, wie eine Erkennung es liefert: klein, ohne Satzzeichen.
      final speech = FakeSpeech(
        [text.segments[0].text.toLowerCase().replaceAll(RegExp(r"[,.:;]"), "")],
        languages: const {"de", "en", "la"},
      );

      await pumpPractice(tester, [
        PracticeUnit.segment(text, 0, HintLevel.free),
      ], speech: speech);

      await tester.tap(find.text("Sprechen"));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key("memorize_mic")));

      expect(speech.lastLanguage, "la");
      expect(find.textContaining("Für Latein"), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_check")));

      expect(find.text("Wortgetreu"), findsOneWidget);
    });

    testWidgets("Im Kopf: aufdecken und selbst einschätzen", (tester) async {
      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 2, HintLevel.free),
      ]);

      await tester.tap(find.text("Im Kopf"));
      await tester.pumpAndSettle();

      expect(find.text("Dein Reich komme."), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_reveal")));
      expect(find.text("Dein Reich komme."), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key("memorize_knew")));

      expect(find.byKey(const Key("memorize_summary")), findsOneWidget);
      expect(
        ensureRepository().cards[vaterunser().segments[2].id]!.learned,
        isTrue,
      );
    });

    testWidgets("schmale Bildschirme: kein Überlauf", (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPractice(tester, [
        PracticeUnit.segment(vaterunser(), 3, HintLevel.firstLetters),
      ]);

      expect(
        tester.widget<Text>(find.byKey(const Key("memorize_prompt"))).data,
        "D W g,\nw i H, s a E.",
      );

      await tapVisible(tester, find.text("Sprechen"));
      await tester.tap(find.text("Einverstanden"));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        app(
          MemorizationTextScreen(
            work: catalog.workOf(vaterunser())!,
            languageCode: "de",
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group("Zentrales Menü", () {
    Future<void> pumpHome(WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          MemorizationHomeScreen(
            repository: ensureRepository(),
            catalog: Future.value(catalog),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("Texte hinzufügen, mehrere Texte und Sprachen, pausieren", (
      tester,
    ) async {
      await pumpHome(tester);

      // Leerer Zustand.
      expect(find.text("Meine Texte"), findsNothing);

      await tapVisible(tester, find.byKey(const Key("memorize_add")));

      await tapVisible(
        tester,
        find.byKey(const Key("memorize_pick_prayer.vaterunser.de")),
      );
      await tapVisible(
        tester,
        find.byKey(const Key("memorize_pick_prayer.vaterunser.la")),
      );

      final creed = find.byKey(
        const Key("memorize_pick_confession.apostolicum.full.de"),
      );
      await tester.scrollUntilVisible(
        creed,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, creed);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text("Meine Texte"), findsOneWidget);
      expect(find.text("3 Texte zur Wiederholung"), findsOneWidget);
      expect(
        find.byKey(const Key("memorize_today_prayer.vaterunser.la")),
        findsOneWidget,
      );
      expect(find.text("2 Abschnitte"), findsNWidgets(3));
      expect(find.text("Deutsch · 0 / 8 Abschnitte gelernt"), findsOneWidget);
      expect(find.text("Latein · 0 / 8 Abschnitte gelernt"), findsOneWidget);

      // Pausierte Texte fallen aus der automatischen Wiederholung.
      final latin = find.descendant(
        of: find.byKey(const Key("memorize_text_prayer.vaterunser.la")),
        matching: find.byType(Switch),
      );
      await tapVisible(tester, latin);

      expect(find.text("2 Texte zur Wiederholung"), findsOneWidget);
      expect(
        find.text("Latein · 0 / 8 Abschnitte gelernt · pausiert"),
        findsOneWidget,
      );

      // Auswahl bleibt gespeichert.
      final reloaded = MemorizationRepository(null);
      await drive(tester, reloaded.load());

      expect(reloaded.textIds, [
        "prayer.vaterunser.de",
        "prayer.vaterunser.la",
        "confession.apostolicum.full.de",
      ]);
      expect(reloaded.isActive("prayer.vaterunser.la"), isFalse);
    });

    testWidgets("„Heute lernen“ führt durch mehrere Texte", (tester) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().addText("prayer.vaterunser.de"));
      await drive(tester, ensureRepository().addText("prayer.kyrie.de"));

      await pumpHome(tester);

      expect(find.text("2 Texte zur Wiederholung"), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key("memorize_today_start")));

      expect(find.byType(MemorizationPracticeScreen), findsOneWidget);
      expect(find.text("Abschnitt 1 von 8 · Deutsch"), findsOneWidget);

      // Vaterunser überspringen (zwei neue Abschnitte), dann folgt das Kyrie.
      await tapVisible(tester, find.text("Überspringen"));
      await tapVisible(tester, find.text("Überspringen"));

      expect(find.text("Abschnitt 1 von 3 · Deutsch"), findsOneWidget);
    });

    testWidgets("Text öffnen und entfernen", (tester) async {
      await drive(tester, ensureRepository().load());
      await drive(tester, ensureRepository().addText("prayer.vaterunser.de"));

      await pumpHome(tester);

      await tapVisible(
        tester,
        find.byKey(const Key("memorize_text_prayer.vaterunser.de")),
      );
      expect(find.byType(MemorizationTextScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byType(PopupMenuButton<String>));
      await tapVisible(tester, find.text("Aus „Meine Texte“ entfernen"));

      expect(find.text("Meine Texte"), findsNothing);
      expect(ensureRepository().textIds, isEmpty);
    });
  });
}
