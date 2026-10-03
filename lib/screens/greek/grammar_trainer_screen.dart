import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../algorithms/grammar_learning.dart';
import '../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../services/greek/grammar/wiktionary_inflection_service.dart';
import '../../services/learning_service.dart';
import '../../services/local_learning_store.dart';
import '../../services/quiz_sound_player.dart';
import '../../services/quiz_sound_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/greek_keyboard.dart';
import '../../widgets/sound_volume_button.dart';
import '../../widgets/streak_widgets.dart';
import '../../services/streak/streak_track.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../services/statistics/statistics_service.dart';
import '../../widgets/statistics_widgets.dart';

import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../widgets/settings_access.dart';
import '../../widgets/settings_selection.dart';
import '../../info/app_info.dart';
import '../../widgets/info_report.dart';

class GreekGrammarTrainerScreen extends StatefulWidget {
  const GreekGrammarTrainerScreen({super.key});

  @override
  State<GreekGrammarTrainerScreen> createState() =>
      _GreekGrammarTrainerScreenState();
}

class _GreekGrammarTrainerScreenState extends State<GreekGrammarTrainerScreen> {
  final GreekVocabularyLoader loader = GreekVocabularyLoader();

  final WiktionaryInflectionService wiktionaryService =
      WiktionaryInflectionService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController answerController = TextEditingController();

  final Random _random = Random();

  final LearningService learningService = LearningService();

  // Lernstand je grammatischer Bestimmung und Grundform.
  late GrammarLearning grammar = GrammarLearning(random: _random);

  late final web.EventListener _keyListener;

  List<GreekVocabularyEntry> entries = [];

  GreekVocabularyEntry? question;

  bool loading = true;
  bool loadingForm = false;
  bool answered = false;
  bool correct = false;

  String? formError;
  String? correctForm;

  // ---------------------------------------------------------------------------
  // PRELOADING
  // ---------------------------------------------------------------------------

  GreekVocabularyEntry? _preloadedQuestion;
  String? _preloadedForm;
  String? _preloadedCase;
  String? _preloadedNumber;
  String? _preloadedGender;
  String? _preloadedPerson;
  String? _preloadedNumberVerb;
  String? _preloadedTense;
  String? _preloadedVoice;

  // Wird bei jedem Fragenwechsel erhöht. Eine noch laufende Formabfrage
  // erkennt daran, dass ihre Frage inzwischen ersetzt wurde, und darf ihr
  // Ergebnis dann nicht mehr in die neuere Frage schreiben.
  int _questionToken = 0;

  // Wird bei jedem neuen Preload erhöht. Ein überholter Preload darf einen
  // neueren weder überschreiben noch verwerfen.
  int _preloadToken = 0;

  // ---------------------------------------------------------------------------
  // AUSWERTUNG
  // ---------------------------------------------------------------------------

  bool? caseCorrect;
  bool? numberCorrect;
  bool? genderCorrect;
  bool? personCorrect;
  bool? tenseCorrect;
  bool? voiceCorrect;
  bool? lemmaCorrect;

  // ---------------------------------------------------------------------------
  // EINSTELLUNGEN
  // ---------------------------------------------------------------------------

  List<int> enabledSteps = [1, 2, 3, 4, 5, 6, 7];

  List<String> enabledTypes = ["noun", "verb"];

  static const List<String> allTypes = ["noun", "verb"];

  // Grundform-Felder anzeigen?
  bool showLemmaFieldNoun = true;
  bool showLemmaFieldVerb = true;

  // ---------------------------------------------------------------------------
  // NOMEN
  // ---------------------------------------------------------------------------

  String? selectedCase;
  String? selectedNumber;
  String? selectedGender;

  String? userCase;
  String? userNumber;
  String? userGender;

  static const List<String> cases = [
    "Nominativ",
    "Genitiv",
    "Dativ",
    "Akkusativ",
  ];

  static const List<String> numbers = ["Sg.", "Pl."];

  static const List<String> genders = ["m", "f", "n"];

  // ---------------------------------------------------------------------------
  // VERBEN
  // ---------------------------------------------------------------------------

  String? selectedPerson;
  String? selectedNumberVerb;
  String? selectedTense;
  String? selectedVoice;

  String? userPersonNumber;
  String? userTense;
  String? userVoice;

  static const List<String> personNumbers = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  // Person und Numerus so, wie die Fragegenerierung sie verwendet.
  static const List<String> verbPersonNumbers = [
    "1. Sg",
    "2. Sg",
    "3. Sg",
    "1. Pl",
    "2. Pl",
    "3. Pl",
  ];

  static const List<String> tenses = ["Präsens", "Imperfekt", "Aorist"];

  static const List<String> voices = ["Aktiv", "Medium/Passiv", "Deponent"];

  // ---------------------------------------------------------------------------
  // BLACKLIST
  // ---------------------------------------------------------------------------

  static const Set<String> grammarBlacklist = {
    "οἶδα",
    "εὐαγγελίζομαι",
    "ἐγείρομαι",
    "ἄρχομαι",
    "πείθομαι",
    "θησαυρίζω",
    "ἐκκόπτω",
    "φοβέομαι",
    "πειράομαι",
    "ἐκπορεύομαι",
    "οἶμαι",
    "καθαρίζομαι",
    "ἐκπλήσσομαι",
    "πορεύομαι",
    "μεταπέμπομαι",
    "σής",
    "βλαβή",
  };

  static const Set<String> activeOnlyVerbs = {
    "εἰμί",
    "ἀσθενέω",
    "μένω",
    "ἐπερωτάω",
    "ἐπιτιμάω",
    "θέλω",
  };

  static const Set<String> presentOnlyVerbs = {"προσεύχομαι"};

  static const Set<String> noAorist = {
    "τάττω",
    "εἰμί",
    "ἄπειμι",
    "σύνειμι",
    "ὑποπτεύω",
  };

  static const Set<String> noImperfect = {"ἐμβαίνω"};

  static const Set<String> aoristSheet = {
    "βλέπω",
    "γράφω",
    "πέμπω",
    "νομίζω",
    "πείθω",
    "σῴζω",
    "ἄρχω",
    "πράττω", //Aorist anderes Lemma nehmen
    "τάττω",
    "φυλάττω", //Aorist anderes Lemma nehmen
    "ἀγγέλλω",
    "κρίνω",
    "μένω",
    "ἄγω",
    "βάλλω",
    "γίγνομαι",
    "ἔρχομαι",
    "εὑρίσκω", //Zweite Aorist Tabelle
    "ἔχω",
    "λαμβάνω",
    "λέγω",
    "λείπω", //Normaler statt Koine Aorist
    "μανθάνω",
    "ὁράω",
    "φεύγω",
    "φέρω", //Zweite Aorist Tabelle
    "βαίνω",
    "γιγνώσκω",
  };
  //static const Set<String> aoristSheet = {"ἔρχομαι"};

  // ---------------------------------------------------------------------------
  // INIT / DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    load();

    _keyListener = ((web.Event event) {
      final keyboardEvent = event as web.KeyboardEvent;

      // Enter gehört einem geöffneten Info-Blatt bzw. Meldeformular.
      if (infoReportOverlayOpen) return;

      if (keyboardEvent.key == 'Enter') {
        if (answered) {
          nextQuestion();
        } else if (!loadingForm && correctForm != null) {
          check();
        }

        keyboardEvent.preventDefault();
      }
    }).toJS;

    web.window.addEventListener('keydown', _keyListener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('keydown', _keyListener);
    answerController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FIREBASE SETTINGS
  // ---------------------------------------------------------------------------

  Future<void> loadGrammarSettings() async {
    final user = _auth.currentUser;

    final Map<String, dynamic>? data;

    if (user == null) {
      // Gastmodus: lokal gespeicherte Einstellungen (gleiche Struktur).
      data = {
        'greek_grammar_settings': await LocalLearningStore.instance
            .loadSettingsGroup('greek_grammar_settings'),
      };
    } else {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      data = doc.data();
    }

    if (data == null) {
      return;
    }

    final settings = data['greek_grammar_settings'];

    if (settings is! Map<String, dynamic>) {
      return;
    }

    final savedSteps = settings['enabledSteps'];
    final savedTypes = settings['enabledTypes'];
    final savedShowLemmaFieldNoun = settings['showLemmaFieldNoun'];
    final savedShowLemmaFieldVerb = settings['showLemmaFieldVerb'];

    if (savedShowLemmaFieldNoun is bool) {
      showLemmaFieldNoun = savedShowLemmaFieldNoun;
    }

    if (savedShowLemmaFieldVerb is bool) {
      showLemmaFieldVerb = savedShowLemmaFieldVerb;
    }

    if (savedSteps is List) {
      enabledSteps = savedSteps
          .whereType<num>()
          .map((step) => step.toInt())
          .where((step) => step >= 1 && step <= 7)
          .toList();

      enabledSteps.sort();
    }

    if (savedTypes is List) {
      enabledTypes = savedTypes
          .whereType<String>()
          .where((type) => allTypes.contains(type))
          .toList();
    }
  }

  Future<void> saveGrammarSettings() async {
    final user = _auth.currentUser;

    final settings = {
      'enabledSteps': enabledSteps,
      'enabledTypes': enabledTypes,
      'showLemmaFieldNoun': showLemmaFieldNoun,
      'showLemmaFieldVerb': showLemmaFieldVerb,
    };

    if (user == null) {
      // Gastmodus: lokal speichern.
      await LocalLearningStore.instance.saveSettingsGroup(
        'greek_grammar_settings',
        settings,
      );

      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'greek_grammar_settings': settings,
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    try {
      // Vokabeln und Einstellungen sind voneinander unabhängig und werden
      // deshalb gleichzeitig statt nacheinander geladen.
      final results = await Future.wait<Object?>([
        GreekVocabularyLoader.load(),
        loadGrammarSettings(),
        _loadGrammarCards(),
      ]);

      entries = results[0] as List<GreekVocabularyEntry>;

      grammar = GrammarLearning(
        cards: results[2] as Map<String, LearningCard>,
        random: _random,
      );

      await nextQuestion();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        // Keine rohen Firebase-/Laufzeitfehler anzeigen.
        debugPrint("Grammatiktrainer konnte nicht geladen werden: $e");
        formError =
            "Der Trainer konnte nicht geladen werden. Bitte prüfe deine "
            "Internetverbindung und versuche es erneut.";
      });

      return;
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // Ohne Lernstand läuft der Trainer mit neutralen Gewichten weiter.
  Future<Map<String, LearningCard>> _loadGrammarCards() async {
    try {
      return await learningService.loadGrammarCards(_auth.currentUser?.uid);
    } catch (e) {
      debugPrint("Grammatik-Lernstand konnte nicht geladen werden: $e");

      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // FRAGE
  // ---------------------------------------------------------------------------

  bool isNoun() {
    return question?.type == "noun";
  }

  bool isVerb() {
    return question?.type == "verb";
  }

  // Prüft ausschließlich, ob ein Wort zu den aktuellen Filtern gehört.
  bool _isEntryAvailable(GreekVocabularyEntry entry) {
    return enabledSteps.contains(entry.step) &&
        enabledTypes.contains(entry.type) &&
        !grammarBlacklist.contains(entry.lemma);
  }

  List<GreekVocabularyEntry> _getAvailableEntries() {
    return entries.where(_isEntryAvailable).toList();
  }

  // ---------------------------------------------------------------------------
  // NÄCHSTE FRAGE
  // ---------------------------------------------------------------------------

  Future<void> nextQuestion() async {
    final available = _getAvailableEntries();

    final token = ++_questionToken;

    if (available.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        question = null;
        correctForm = null;
        formError = null;
        answered = false;
        loadingForm = false;
      });

      return;
    }

    // Vorgeladene Frage verwenden, wenn sie noch gültig ist.
    if (_preloadedQuestion != null &&
        _preloadedForm != null &&
        _isEntryAvailable(_preloadedQuestion!) &&
        _preloadedQuestion != question) {
      final newQuestion = _preloadedQuestion!;

      answerController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        question = newQuestion;

        answered = false;
        correct = false;
        loadingForm = false;

        correctForm = _preloadedForm;
        formError = null;

        selectedCase = _preloadedCase;
        selectedNumber = _preloadedNumber;
        selectedGender = _preloadedGender;

        selectedPerson = _preloadedPerson;
        selectedNumberVerb = _preloadedNumberVerb;
        selectedTense = _preloadedTense;
        selectedVoice = _preloadedVoice;

        userCase = null;
        userNumber = null;
        userGender = null;

        userPersonNumber = null;
        userTense = null;
        userVoice = null;

        caseCorrect = null;
        numberCorrect = null;
        genderCorrect = null;
        personCorrect = null;
        tenseCorrect = null;
        voiceCorrect = null;
        lemmaCorrect = null;
      });

      _clearPreloaded();

      _preloadNextQuestion(available);

      return;
    }

    final newQuestion = _getThreeOptionRandomEntry(available);

    answerController.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      question = newQuestion;

      answered = false;
      correct = false;
      loadingForm = true;

      correctForm = null;
      formError = null;

      selectedCase = null;
      selectedNumber = null;
      selectedGender = null;

      selectedPerson = null;
      selectedNumberVerb = null;
      selectedTense = null;
      selectedVoice = null;

      userCase = null;
      userNumber = null;
      userGender = null;

      userPersonNumber = null;
      userTense = null;
      userVoice = null;

      caseCorrect = null;
      numberCorrect = null;
      genderCorrect = null;
      personCorrect = null;
      tenseCorrect = null;
      voiceCorrect = null;
      lemmaCorrect = null;
    });

    _clearPreloaded();

    if (newQuestion.type == "noun") {
      await generateNounQuestion(newQuestion);
    } else if (newQuestion.type == "verb") {
      await generateVerbQuestion(newQuestion);
    }

    // Screen inzwischen geschlossen oder Frage bereits ersetzt:
    // dann keinen (doppelten) Preload mehr starten.
    if (!mounted || token != _questionToken) {
      return;
    }

    _preloadNextQuestion(available);
  }

  // ---------------------------------------------------------------------------
  // EINSTELLUNGEN ANGEWENDET
  // ---------------------------------------------------------------------------

  Future<void> _applySettingsAfterDialog() async {
    final currentQuestion = question;

    // Wenn überhaupt keine gültigen Filter vorhanden sind,
    // gibt es auch keine gültige aktuelle Frage.
    final available = _getAvailableEntries();

    if (available.isEmpty) {
      _clearPreloaded();

      if (!mounted) {
        return;
      }

      _questionToken++;

      setState(() {
        question = null;
        correctForm = null;
        formError = null;
        answered = false;
        loadingForm = false;
      });

      return;
    }

    // WICHTIG:
    // Die aktuelle Frage bleibt bestehen, wenn sie weiterhin
    // den neuen Einstellungen entspricht.
    if (currentQuestion != null && _isEntryAvailable(currentQuestion)) {
      // Eine eventuell vorgeladene Frage muss ebenfalls zu den
      // neuen Einstellungen passen.
      if (_preloadedQuestion != null &&
          !_isEntryAvailable(_preloadedQuestion!)) {
        _clearPreloaded();
      }

      // Falls keine gültige Preload-Frage vorhanden ist,
      // im Hintergrund eine neue vorbereiten.
      if (_preloadedQuestion == null || _preloadedForm == null) {
        _preloadNextQuestion(available);
      }

      return;
    }

    // Die aktuelle Frage ist durch die neuen Einstellungen
    // nicht mehr erlaubt.
    //
    // Deshalb zuerst versuchen, die vorgeladene Frage zu verwenden.
    if (_preloadedQuestion != null &&
        _preloadedForm != null &&
        _isEntryAvailable(_preloadedQuestion!)) {
      await _usePreloadedQuestion();

      final newAvailable = _getAvailableEntries();

      if (newAvailable.isNotEmpty) {
        _preloadNextQuestion(newAvailable);
      }

      return;
    }

    // Keine passende Preload-Frage vorhanden:
    // eine neue Frage laden.
    await nextQuestion();
  }

  // ---------------------------------------------------------------------------
  // VORGELADENE FRAGE VERWENDEN
  // ---------------------------------------------------------------------------

  Future<void> _usePreloadedQuestion() async {
    final preloadedQuestion = _preloadedQuestion;
    final preloadedForm = _preloadedForm;

    if (preloadedQuestion == null || preloadedForm == null) {
      return;
    }

    answerController.clear();

    if (!mounted) {
      return;
    }

    _questionToken++;

    setState(() {
      question = preloadedQuestion;

      answered = false;
      correct = false;
      loadingForm = false;

      correctForm = preloadedForm;
      formError = null;

      selectedCase = _preloadedCase;
      selectedNumber = _preloadedNumber;
      selectedGender = _preloadedGender;

      selectedPerson = _preloadedPerson;
      selectedNumberVerb = _preloadedNumberVerb;
      selectedTense = _preloadedTense;
      selectedVoice = _preloadedVoice;

      userCase = null;
      userNumber = null;
      userGender = null;

      userPersonNumber = null;
      userTense = null;
      userVoice = null;

      caseCorrect = null;
      numberCorrect = null;
      genderCorrect = null;
      personCorrect = null;
      tenseCorrect = null;
      voiceCorrect = null;
      lemmaCorrect = null;
    });

    _clearPreloaded();
  }

  // ---------------------------------------------------------------------------
  // PRELOAD
  // ---------------------------------------------------------------------------

  Future<void> _preloadNextQuestion(
    List<GreekVocabularyEntry> available,
  ) async {
    if (available.isEmpty) {
      return;
    }

    final candidates = available.where((entry) {
      return entry != question;
    }).toList();

    if (candidates.isEmpty) {
      return;
    }

    final next = _getThreeOptionRandomEntry(candidates);

    if (next.type == "noun") {
      await _preloadNounQuestion(next);
    } else if (next.type == "verb") {
      await _preloadVerbQuestion(next);
    }
  }

  void _clearPreloaded() {
    _preloadedQuestion = null;
    _preloadedForm = null;
    _preloadedCase = null;
    _preloadedNumber = null;
    _preloadedGender = null;
    _preloadedPerson = null;
    _preloadedNumberVerb = null;
    _preloadedTense = null;
    _preloadedVoice = null;
  }

  // Ein Preload-Ergebnis wird nur übernommen, wenn der Screen noch lebt, die
  // Frage nicht ohnehin gerade angezeigt wird und kein neuerer Preload
  // überschrieben würde. Ein überholter Preload darf lediglich einen leeren
  // Platz füllen.
  bool _mayStorePreloaded(int token, GreekVocabularyEntry entry) {
    if (!mounted || entry == question) {
      return false;
    }

    return token == _preloadToken || _preloadedQuestion == null;
  }

  // ---------------------------------------------------------------------------
  // ANTWORT PRÜFEN
  // ---------------------------------------------------------------------------

  void check() {
    final q = question;
    if (q == null) return;

    // Streak nur einmal je Frage zählen.
    final firstEvaluation = !answered;

    setState(() {
      answered = true;

      // Grundform nur prüfen, wenn das Grundform-Feld aktiviert ist.
      final showLemmaField = q.type == "noun"
          ? showLemmaFieldNoun
          : showLemmaFieldVerb;

      if (showLemmaField) {
        final userLemma = normalizeGreekForComparison(
          answerController.text.trim(),
        );

        final correctLemma = normalizeGreekForComparison(q.lemma.trim());

        lemmaCorrect = userLemma.toLowerCase() == correctLemma.toLowerCase();
      } else {
        lemmaCorrect = true;
      }

      if (q.type == "noun") {
        caseCorrect = userCase == selectedCase;
        numberCorrect = userNumber == selectedNumber;
        genderCorrect = userGender == selectedGender;

        correct =
            lemmaCorrect! &&
            (caseCorrect ?? false) &&
            (numberCorrect ?? false) &&
            (genderCorrect ?? false);
      } else if (q.type == "verb") {
        final correctPersonNumber = "$selectedPerson $selectedNumberVerb.";

        personCorrect = userPersonNumber == correctPersonNumber;

        tenseCorrect = userTense == selectedTense;
        voiceCorrect = userVoice == selectedVoice;

        correct =
            lemmaCorrect! &&
            (personCorrect ?? false) &&
            (tenseCorrect ?? false) &&
            (voiceCorrect ?? false);
      }
    });

    if (correct) {
      QuizSoundPlayer.instance.playCorrect(SoundModule.greekGrammar);
    } else {
      QuizSoundPlayer.instance.playIncorrect(SoundModule.greekGrammar);
    }

    if (firstEvaluation) {
      _recordLearning(q);

      LearningStatisticsService.instance.recordAnswer(
        uid: _auth.currentUser?.uid,
        trainer: StatisticsTrainer.greekGrammar,
        correct: correct,
      );
    }

    if (correct && firstEvaluation) {
      recordStreakAnswer(
        context,
        uid: _auth.currentUser?.uid,
        track: StreakTrack.greek,
        source: StreakSource.grammar,
      );
    }
  }

  // Verbucht jede Bestimmung einzeln, damit ein Fehler gezielt die
  // betroffene Kategorie (z. B. Aorist) stärker gewichtet.
  void _recordLearning(GreekVocabularyEntry q) {
    final results = <String, bool>{};

    final lemmaAsked = q.type == "noun"
        ? showLemmaFieldNoun
        : showLemmaFieldVerb;

    final lemmaId = GrammarLearning.lemmaId(q.id);

    if (q.type == "noun") {
      results[GrammarLearning.dimensionId("noun", "case", selectedCase!)] =
          caseCorrect ?? false;
      results[GrammarLearning.dimensionId("noun", "number", selectedNumber!)] =
          numberCorrect ?? false;

      // Das Genus hängt am Wort, nicht an der Form.
      results[lemmaId] =
          (genderCorrect ?? false) && (!lemmaAsked || lemmaCorrect == true);
    } else if (q.type == "verb") {
      results[GrammarLearning.dimensionId(
            "verb",
            "person",
            "$selectedPerson $selectedNumberVerb",
          )] =
          personCorrect ?? false;
      results[GrammarLearning.dimensionId("verb", "tense", selectedTense!)] =
          tenseCorrect ?? false;
      results[GrammarLearning.dimensionId("verb", "voice", selectedVoice!)] =
          voiceCorrect ?? false;

      if (lemmaAsked) {
        results[lemmaId] = lemmaCorrect == true;
      }
    }

    // Nicht auf den Server warten; ein Speicherfehler darf den Trainer nicht
    // beeinflussen.
    learningService
        .saveGrammarCards(_auth.currentUser?.uid, grammar.record(results))
        .catchError((Object e) {
          debugPrint("Grammatik-Lernstand konnte nicht gespeichert werden: $e");
        });
  }

  // ---------------------------------------------------------------------------
  // NOMEN-FRAGE GENERIEREN
  // ---------------------------------------------------------------------------

  Future<void> generateNounQuestion(GreekVocabularyEntry entry) async {
    final token = _questionToken;

    final grammaticalCase = grammar.pickValue("noun", "case", cases);

    final number = grammar.pickValue("noun", "number", numbers);

    // Genus aus dem Artikel bestimmen
    String gender = "m";

    if (entry.article == "ὁ") {
      gender = "m";
    } else if (entry.article == "ἡ") {
      gender = "f";
    } else if (entry.article == "τό" || entry.article == "το") {
      gender = "n";
    }

    if (mounted) {
      setState(() {
        selectedCase = grammaticalCase;
        selectedNumber = number;
        selectedGender = gender;
      });
    }

    try {
      final form = await wiktionaryService.getNounForm(
        lemma: entry.lemma,
        grammaticalCase: grammaticalCase,
        number: number == "Sg." ? "Sg" : "Pl",
      );

      if (!mounted || token != _questionToken) {
        return;
      }

      setState(() {
        loadingForm = false;

        correctForm = form == null ? null : normalizeGreekForDisplay(form);

        if (form == null || form.isEmpty) {
          formError =
              'Keine passende Nominalform gefunden.\n\n'
              'Grundform: ${entry.lemma}';
        }
      });
    } catch (e) {
      if (!mounted || token != _questionToken) {
        return;
      }

      setState(() {
        loadingForm = false;
        correctForm = null;

        formError =
            'Fehler beim Laden der Nominalform\n\n'
            'Grundform: ${entry.lemma}\n\n'
            'Fehler: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // VERB-FRAGE GENERIEREN
  // ---------------------------------------------------------------------------

  Future<void> generateVerbQuestion(GreekVocabularyEntry entry) async {
    final token = _questionToken;

    final personNumber = grammar
        .pickValue("verb", "person", verbPersonNumbers)
        .split(" ");

    final person = personNumber[0];

    final number = personNumber[1];

    // Erst die für das Verb zulässigen Werte bestimmen, dann gewichten.
    String tense;

    if (presentOnlyVerbs.contains(entry.lemma)) {
      tense = "Präsens";
    } else if (noAorist.contains(entry.lemma)) {
      tense = grammar.pickValue("verb", "tense", const [
        "Präsens",
        "Imperfekt",
      ]);
    } else if (noImperfect.contains(entry.lemma)) {
      tense = grammar.pickValue("verb", "tense", const ["Präsens", "Aorist"]);
    } else {
      tense = grammar.pickValue("verb", "tense", tenses);
    }

    String voice;

    if (activeOnlyVerbs.contains(entry.lemma)) {
      voice = "Aktiv";
    } else if (entry.deponent) {
      voice = "Medium/Passiv";
    } else {
      voice = grammar.pickValue("verb", "voice", const [
        "Aktiv",
        "Medium/Passiv",
      ]);
    }

    if (mounted) {
      setState(() {
        selectedPerson = person;
        selectedNumberVerb = number;
        selectedTense = tense;
        selectedVoice = voice;
      });
    }

    final parsedPerson = _parsePerson(person);

    if (parsedPerson == null) {
      if (!mounted || token != _questionToken) {
        return;
      }

      setState(() {
        loadingForm = false;

        formError =
            'Fehler bei Verbform\n'
            'Grundform: ${entry.lemma}\n'
            'Form: $person $number · $tense · $voice\n'
            'Ungültige Personenangabe.';
      });

      return;
    }

    try {
      final form = await wiktionaryService.getVerbForm(
        lemma: entry.lemma,
        tense: tense,
        voice: voice,
        number: number,
        person: parsedPerson,
      );

      if (!mounted || token != _questionToken) {
        return;
      }

      if (form == null || form.isEmpty) {
        setState(() {
          loadingForm = false;
          correctForm = null;

          formError =
              'Verbform nicht gefunden\n\n'
              'Grundform: ${entry.lemma}\n\n'
              'Gesucht: $person $number · '
              '$tense · $voice';
        });

        return;
      }

      setState(() {
        loadingForm = false;

        correctForm = normalizeGreekForDisplay(form);

        formError = null;
      });
    } catch (e) {
      if (!mounted || token != _questionToken) {
        return;
      }

      setState(() {
        loadingForm = false;
        correctForm = null;

        formError =
            'Fehler beim Laden der Verbform\n\n'
            'Grundform: ${entry.lemma}\n\n'
            'Gesucht: $person $number · '
            '$tense · $voice\n\n'
            'Fehler: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // PRELOAD NOMEN
  // ---------------------------------------------------------------------------

  Future<void> _preloadNounQuestion(GreekVocabularyEntry entry) async {
    final token = ++_preloadToken;

    final grammaticalCase = grammar.pickValue("noun", "case", cases);

    final number = grammar.pickValue("noun", "number", numbers);

    String gender = "m";

    if (entry.article == "ὁ") {
      gender = "m";
    } else if (entry.article == "ἡ") {
      gender = "f";
    } else if (entry.article == "τό" || entry.article == "το") {
      gender = "n";
    }

    try {
      final form = await wiktionaryService.getNounForm(
        lemma: entry.lemma,
        grammaticalCase: grammaticalCase,
        number: number == "Sg." ? "Sg" : "Pl",
      );

      if (form != null && form.isNotEmpty) {
        if (!_mayStorePreloaded(token, entry)) {
          return;
        }

        _preloadedQuestion = entry;
        _preloadedForm = normalizeGreekForDisplay(form);

        _preloadedCase = grammaticalCase;
        _preloadedNumber = number;
        _preloadedGender = gender;

        _preloadedPerson = null;
        _preloadedNumberVerb = null;
        _preloadedTense = null;
        _preloadedVoice = null;
      } else if (token == _preloadToken) {
        _clearPreloaded();
      }
    } catch (e) {
      if (token == _preloadToken) {
        _clearPreloaded();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PRELOAD VERB
  // ---------------------------------------------------------------------------

  Future<void> _preloadVerbQuestion(GreekVocabularyEntry entry) async {
    final token = ++_preloadToken;

    final personNumber = grammar
        .pickValue("verb", "person", verbPersonNumbers)
        .split(" ");

    final person = personNumber[0];

    final number = personNumber[1];

    // Erst die für das Verb zulässigen Werte bestimmen, dann gewichten.
    String tense;

    if (presentOnlyVerbs.contains(entry.lemma)) {
      tense = "Präsens";
    } else if (noAorist.contains(entry.lemma)) {
      tense = grammar.pickValue("verb", "tense", const [
        "Präsens",
        "Imperfekt",
      ]);
    } else if (noImperfect.contains(entry.lemma)) {
      tense = grammar.pickValue("verb", "tense", const ["Präsens", "Aorist"]);
    } else {
      tense = grammar.pickValue("verb", "tense", tenses);
    }

    String voice;

    if (activeOnlyVerbs.contains(entry.lemma)) {
      voice = "Aktiv";
    } else if (entry.deponent) {
      voice = "Medium/Passiv";
    } else {
      voice = grammar.pickValue("verb", "voice", const [
        "Aktiv",
        "Medium/Passiv",
      ]);
    }

    final parsedPerson = _parsePerson(person);

    if (parsedPerson == null) {
      _clearPreloaded();
      return;
    }

    try {
      final form = await wiktionaryService.getVerbForm(
        lemma: entry.lemma,
        tense: tense,
        voice: voice,
        number: number,
        person: parsedPerson,
      );

      if (form != null && form.isNotEmpty) {
        if (!_mayStorePreloaded(token, entry)) {
          return;
        }

        _preloadedQuestion = entry;

        _preloadedForm = normalizeGreekForDisplay(form);

        _preloadedCase = null;
        _preloadedNumber = null;
        _preloadedGender = null;

        _preloadedPerson = person;
        _preloadedNumberVerb = number;
        _preloadedTense = tense;
        _preloadedVoice = voice;
      } else if (token == _preloadToken) {
        _clearPreloaded();
      }
    } catch (e) {
      if (token == _preloadToken) {
        _clearPreloaded();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PERSON PARSEN
  // ---------------------------------------------------------------------------

  int? _parsePerson(String? value) {
    switch (value) {
      case "1.":
        return 1;

      case "2.":
        return 2;

      case "3.":
        return 3;

      default:
        return null;
    }
  }

  GreekVocabularyEntry _getThreeOptionRandomEntry(
    List<GreekVocabularyEntry> available,
  ) {
    // Build the aoristSheet verbs list from available
    List<GreekVocabularyEntry> aoristSheetVerbs = available.where((entry) {
      return entry.type == "verb" && aoristSheet.contains(entry.lemma);
    }).toList();

    // Check for εἰ mí
    bool eimaiAvailable = available.any((entry) => entry.lemma == "εἰμί");
    GreekVocabularyEntry? eimaiEntry = eimaiAvailable
        ? available.firstWhere((entry) => entry.lemma == "εἰμί")
        : null;

    // Build the list of option lists
    List<List<GreekVocabularyEntry>> optionLists = [
      available, // option1: vocabulary
    ];
    if (aoristSheetVerbs.isNotEmpty) {
      optionLists.add(aoristSheetVerbs);
    }
    if (eimaiAvailable) {
      optionLists.add([eimaiEntry!]);
    }

    // Jede Liste hat dasselbe Grundgewicht; der Lernbedarf verschiebt die
    // Auswahl zwischen den Listen und innerhalb der gewählten Liste.
    return grammar.pickFromGroups(
      optionLists,
      (entry) => GrammarLearning.lemmaId(entry.id),
    );
  }

  // ---------------------------------------------------------------------------
  // RESULT BORDER
  // ---------------------------------------------------------------------------

  OutlineInputBorder resultBorder(bool? value) {
    if (value == null) {
      return const OutlineInputBorder();
    }

    return OutlineInputBorder(
      borderSide: BorderSide(
        color: value ? AppColors.success : AppColors.error,
        width: 2,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AUSWAHL (EINE OPTION JE BESTIMMUNG)
  // ---------------------------------------------------------------------------

  Widget _choice({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String> onChanged,
    bool? isCorrect,
  }) {
    return SingleSelectChips(
      label: label,
      options: items,
      value: value,
      correct: isCorrect,
      onChanged: answered ? null : onChanged,
    );
  }

  // Die Gruppen stehen nebeneinander, solange der Platz reicht, und
  // brechen auf schmalen Bildschirmen untereinander um.
  Widget _choiceGroups(List<Widget> groups) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(spacing: 24, runSpacing: 8, children: groups),
    );
  }

  // ---------------------------------------------------------------------------
  // GRIECHISCHE TASTATUR
  // ---------------------------------------------------------------------------

  void openGreekKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (context) {
        return GreekKeyboard(
          controller: answerController,
          // Das Textfeld aktualisiert sich über den Controller selbst;
          // ein Rebuild des gesamten Screens pro Tastendruck ist unnötig.
          onChanged: () {},
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EINSTELLUNGEN
  // ---------------------------------------------------------------------------

  void openSettings() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ModuleSettingsDialog(
              moduleLabel: "Grammatiktrainer",
              title: Row(
                children: [
                  const Expanded(child: Text("Einstellungen")),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      if (enabledSteps.isEmpty || enabledTypes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Mindestens ein Schritt und "
                              "eine Wortart müssen ausgewählt sein.",
                            ),
                          ),
                        );

                        return;
                      }

                      await saveGrammarSettings();

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(context);

                      // Hauptscreen sofort aktualisieren, damit das Lemma-Feld
                      // direkt nach dem Schließen des Einstellungsdialogs
                      // erscheint bzw. verschwindet.
                      if (mounted) {
                        setState(() {});
                      }

                      await _applySettingsAfterDialog();
                    },
                  ),
                ],
              ),
              moduleSettings: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // -------------------------------------------------------
                      // SCHRITTE
                      // -------------------------------------------------------
                      MultiSelectSection<int>(
                        title: "Schritte",
                        hint:
                            "Abgefragt werden nur Wörter aus den "
                            "ausgewählten Schritten. Mehrere Schritte können "
                            "gleichzeitig ausgewählt sein.",
                        options: const [1, 2, 3, 4, 5, 6, 7],
                        isSelected: enabledSteps.contains,
                        labelOf: (step) => "Schritt $step",
                        emptyError:
                            "Mindestens ein Schritt muss ausgewählt sein.",
                        onToggleAll: () {
                          setDialogState(() {
                            if (enabledSteps.length == 7) {
                              enabledSteps.clear();
                            } else {
                              enabledSteps = [1, 2, 3, 4, 5, 6, 7];
                            }
                          });
                        },
                        onChanged: (step, value) {
                          setDialogState(() {
                            if (value) {
                              if (!enabledSteps.contains(step)) {
                                enabledSteps.add(step);
                              }
                            } else {
                              enabledSteps.remove(step);
                            }
                          });
                        },
                      ),

                      // -------------------------------------------------------
                      // WORTARTEN
                      // -------------------------------------------------------
                      MultiSelectSection<String>(
                        title: "Wortarten",
                        hint:
                            "Abgefragt werden nur Formen der ausgewählten "
                            "Wortarten.",
                        options: allTypes,
                        isSelected: enabledTypes.contains,
                        labelOf: (type) => type == "noun" ? "Nomen" : "Verben",
                        emptyError:
                            "Mindestens eine Wortart muss ausgewählt sein.",
                        onToggleAll: () {
                          setDialogState(() {
                            if (enabledTypes.length == allTypes.length) {
                              enabledTypes.clear();
                            } else {
                              enabledTypes = List.from(allTypes);
                            }
                          });
                        },
                        onChanged: (type, value) {
                          setDialogState(() {
                            if (value) {
                              if (!enabledTypes.contains(type)) {
                                enabledTypes.add(type);
                              }
                            } else {
                              enabledTypes.remove(type);
                            }
                          });
                        },
                      ),

                      // -------------------------------------------------------
                      // GRUNDFORM
                      // -------------------------------------------------------
                      SettingsSection(
                        title: "Grundform abfragen",
                        hint:
                            "Wenn deaktiviert, wird die Grundform nicht "
                            "abgefragt, sondern nach der Antwort angezeigt.",
                        child: SettingsSwitchGroup(
                          children: [
                            SwitchListTile(
                              title: const Text("Bei Nomen"),
                              value: showLemmaFieldNoun,
                              onChanged: (value) {
                                setDialogState(() {
                                  showLemmaFieldNoun = value;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Bei Verben"),
                              value: showLemmaFieldVerb,
                              onChanged: (value) {
                                setDialogState(() {
                                  showLemmaFieldVerb = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // -------------------------------------------------------
                      // SOUNDS
                      // -------------------------------------------------------
                      SettingsSection(
                        title: "Sounds",
                        child: SettingsSwitchGroup(
                          children: [
                            SwitchListTile(
                              title: const Text("Sound bei richtiger Antwort"),
                              value: QuizSoundSettings.instance
                                  .isCorrectSoundEnabled(
                                    SoundModule.greekGrammar,
                                  ),
                              onChanged: (value) {
                                setDialogState(() {
                                  QuizSoundSettings.instance
                                      .setCorrectSoundEnabled(
                                        SoundModule.greekGrammar,
                                        value,
                                      );
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Sound bei falscher Antwort"),
                              value: QuizSoundSettings.instance
                                  .isWrongSoundEnabled(
                                    SoundModule.greekGrammar,
                                  ),
                              onChanged: (value) {
                                setDialogState(() {
                                  QuizSoundSettings.instance
                                      .setWrongSoundEnabled(
                                        SoundModule.greekGrammar,
                                        value,
                                      );
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FEHLER MELDEN
  // ---------------------------------------------------------------------------

  /// Kontext für „Fehler melden“. Die Bestimmung erst nach dem Prüfen, damit
  /// das Formular die Lösung nicht verrät.
  Map<String, String> _reportDetails() {
    final q = question;

    if (q == null) {
      return {};
    }

    return {
      "Angezeigte Form": correctForm ?? "",
      "Fehler beim Laden": formError ?? "",
      if (answered || formError != null) ...{
        "Grundform": "${q.lemma} (ID ${q.id})",
        if (isNoun())
          "Bestimmung": "$selectedCase $selectedNumber"
        else if (isVerb())
          "Bestimmung":
              "$selectedPerson $selectedNumberVerb, $selectedTense, "
              "$selectedVoice",
      },
    };
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = question;

    if (q == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Grammatiktrainer"),
          actions: [
            StatisticsButton(
              uid: _auth.currentUser?.uid,
              trainer: StatisticsTrainer.greekGrammar,
            ),
            const SoundVolumeButton(),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: openSettings,
            ),
          ],
        ),
        body: Center(
          child: Text(
            formError ??
                "Mit den aktuellen Filtern sind "
                    "keine Vokabeln verfügbar.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Grammatiktrainer"),
        actions: [
          StatisticsButton(
            uid: _auth.currentUser?.uid,
            trainer: StatisticsTrainer.greekGrammar,
          ),
          const SoundVolumeButton(),
          IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // -------------------------------------------------------------
                // DEKLINIERTE / KONJUGIERTE FORM
                // -------------------------------------------------------------
                if (loadingForm)
                  const CircularProgressIndicator()
                else if (correctForm != null)
                  SelectableText(
                    correctForm!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (formError != null)
                  SelectableText(
                    formError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  )
                else
                  const Text(
                    "Form wird geladen...",
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // GRAMMATIK-EINGABEN
                // -------------------------------------------------------------
                if (isVerb())
                  _buildVerbInputs()
                else if (isNoun())
                  _buildNounInputs(),

                const SizedBox(height: 16),

                // -------------------------------------------------------------
                // LEMMA EINGABE
                // -------------------------------------------------------------
                if ((isNoun() && showLemmaFieldNoun) ||
                    (isVerb() && showLemmaFieldVerb)) ...[
                  TextField(
                    controller: answerController,
                    enabled: !answered && !loadingForm && correctForm != null,
                    decoration: InputDecoration(
                      labelText: "Grundform",
                      enabledBorder: resultBorder(lemmaCorrect),
                      focusedBorder: resultBorder(lemmaCorrect),
                      disabledBorder: resultBorder(lemmaCorrect),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: "Griechische Tastatur",
                        icon: const Icon(Icons.keyboard_alt_outlined),
                        onPressed:
                            answered || loadingForm || correctForm == null
                            ? null
                            : openGreekKeyboard,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                  ),

                  const SizedBox(height: 24),
                ],

                // -------------------------------------------------------------
                // FEEDBACK
                // -------------------------------------------------------------
                if (answered)
                  Column(
                    children: [
                      AnswerFeedbackBadge(
                        correct: correct,
                        label: correct ? "Richtig" : "Falsch",
                      ),

                      const SizedBox(height: 12),

                      if (!(isNoun() && showLemmaFieldNoun) &&
                          !(isVerb() && showLemmaFieldVerb)) ...[
                        Text(
                          "Grundform: ${question!.lemma}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                      ],

                      if (question?.translations.isNotEmpty ?? false)
                        Text(
                          "Übersetzung: ${question!.translations.join(', ')}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),

                      const SizedBox(height: 12),

                      if (!correct)
                        Column(
                          children: [
                            const Text(
                              "Korrekte Antworten:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 8),

                            if (((isNoun() && showLemmaFieldNoun) ||
                                    (isVerb() && showLemmaFieldVerb)) &&
                                lemmaCorrect == false)
                              Text("Grundform: ${question?.lemma ?? ''}"),

                            if (isNoun()) ...[
                              if (caseCorrect == false)
                                Text("Kasus: $selectedCase"),
                              if (numberCorrect == false)
                                Text("Numerus: $selectedNumber"),
                              if (genderCorrect == false)
                                Text("Genus: $selectedGender"),
                            ],

                            if (isVerb()) ...[
                              if (personCorrect == false)
                                Text(
                                  "Person / Numerus: "
                                  "$selectedPerson $selectedNumberVerb.",
                                ),
                              if (tenseCorrect == false)
                                Text("Tempus: $selectedTense"),
                              if (voiceCorrect == false)
                                Text("Genus Verbi: $selectedVoice"),
                            ],
                          ],
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                // -------------------------------------------------------------
                // FEHLER
                // -------------------------------------------------------------
                if (formError != null && !loadingForm)
                  Text(
                    formError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),

                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // BUTTON
                // -------------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loadingForm
                        ? null
                        : () async {
                            if (answered || formError != null) {
                              await nextQuestion();
                            } else {
                              check();
                            }
                          },
                    child: Text(
                      loadingForm
                          ? "Lädt..."
                          : (answered || formError != null)
                          ? "Weiter"
                          : "Prüfen",
                    ),
                  ),
                ),

                InfoReportFooter(
                  module: AppModules.greekGrammarTrainer,
                  reportDetails: _reportDetails,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOMEN-EINGABEN
  // ---------------------------------------------------------------------------

  Widget _buildNounInputs() {
    return _choiceGroups([
      _choice(
        value: userCase,
        label: "Kasus",
        items: cases,
        isCorrect: caseCorrect,
        onChanged: (value) {
          setState(() {
            userCase = value;
          });
        },
      ),

      _choice(
        value: userNumber,
        label: "Numerus",
        items: numbers,
        isCorrect: numberCorrect,
        onChanged: (value) {
          setState(() {
            userNumber = value;
          });
        },
      ),

      _choice(
        value: userGender,
        label: "Genus",
        items: genders,
        isCorrect: genderCorrect,
        onChanged: (value) {
          setState(() {
            userGender = value;
          });
        },
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // VERB-EINGABEN
  // ---------------------------------------------------------------------------

  Widget _buildVerbInputs() {
    return _choiceGroups([
      _choice(
        value: userPersonNumber,
        label: "Person / Numerus",
        items: personNumbers,
        isCorrect: personCorrect,
        onChanged: (value) {
          setState(() {
            userPersonNumber = value;
          });
        },
      ),

      _choice(
        value: userTense,
        label: "Tempus",
        items: tenses,
        isCorrect: tenseCorrect,
        onChanged: (value) {
          setState(() {
            userTense = value;
          });
        },
      ),

      _choice(
        value: userVoice,
        label: "Genus Verbi",
        items: voices,
        isCorrect: voiceCorrect,
        onChanged: (value) {
          setState(() {
            userVoice = value;
          });
        },
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// GRIECHISCH NORMALISIEREN – DISPLAY
// -----------------------------------------------------------------------------

String normalizeGreekForDisplay(String text) {
  return text
      .replaceAll('ᾰ', 'α')
      .replaceAll('ᾱ', 'α')
      .replaceAll('ῐ', 'ι')
      .replaceAll('ῑ', 'ι')
      .replaceAll('ῠ', 'υ')
      .replaceAll('ῡ', 'υ');
}

// -----------------------------------------------------------------------------
// GRIECHISCH NORMALISIEREN – VERGLEICH
// -----------------------------------------------------------------------------

String normalizeGreekForComparison(String text) {
  String normalized = normalizeGreekForDisplay(text);

  const Map<String, String> greekNormalization = {
    "ά": "α",
    "ὰ": "α",
    "ᾶ": "α",
    "ἀ": "α",
    "ἁ": "α",
    "ἂ": "α",
    "ἃ": "α",
    "ἄ": "α",
    "ἅ": "α",
    "ἆ": "α",
    "ἇ": "α",
    "ᾀ": "α",
    "ᾁ": "α",
    "ᾂ": "α",
    "ᾃ": "α",
    "ᾄ": "α",
    "ᾅ": "α",
    "ᾆ": "α",
    "ᾇ": "α",
    "ᾲ": "α",
    "ᾳ": "α",
    "ᾴ": "α",
    "ᾷ": "α",

    "έ": "ε",
    "ὲ": "ε",
    "ἐ": "ε",
    "ἑ": "ε",
    "ἒ": "ε",
    "ἓ": "ε",
    "ἔ": "ε",
    "ἕ": "ε",

    "ή": "η",
    "ὴ": "η",
    "ῆ": "η",
    "ἠ": "η",
    "ἡ": "η",
    "ἢ": "η",
    "ἣ": "η",
    "ἤ": "η",
    "ἥ": "η",
    "ἦ": "η",
    "ἧ": "η",
    "ᾐ": "η",
    "ᾑ": "η",
    "ᾒ": "η",
    "ᾓ": "η",
    "ᾔ": "η",
    "ᾕ": "η",
    "ᾖ": "η",
    "ᾗ": "η",
    "ῂ": "η",
    "ῃ": "η",
    "ῄ": "η",
    "ῇ": "η",

    "ί": "ι",
    "ὶ": "ι",
    "ῖ": "ι",
    "ἰ": "ι",
    "ἱ": "ι",
    "ἲ": "ι",
    "ἳ": "ι",
    "ἴ": "ι",
    "ἵ": "ι",
    "ἶ": "ι",
    "ἷ": "ι",
    "ϊ": "ι",
    "ΐ": "ι",
    "ῒ": "ι",
    "ῗ": "ι",

    "ό": "ο",
    "ὸ": "ο",
    "ὀ": "ο",
    "ὁ": "ο",
    "ὂ": "ο",
    "ὃ": "ο",
    "ὄ": "ο",
    "ὅ": "ο",

    "ύ": "υ",
    "ὺ": "υ",
    "ῦ": "υ",
    "ὐ": "υ",
    "ὑ": "υ",
    "ὒ": "υ",
    "ὓ": "υ",
    "ὔ": "υ",
    "ὕ": "υ",
    "ὖ": "υ",
    "ὗ": "υ",
    "ϋ": "υ",
    "ΰ": "υ",
    "ῢ": "υ",
    "ῧ": "υ",

    "ώ": "ω",
    "ὼ": "ω",
    "ῶ": "ω",
    "ὠ": "ω",
    "ὡ": "ω",
    "ὢ": "ω",
    "ὣ": "ω",
    "ὤ": "ω",
    "ὥ": "ω",
    "ὦ": "ω",
    "ὧ": "ω",
    "ᾠ": "ω",
    "ᾡ": "ω",
    "ᾢ": "ω",
    "ᾣ": "ω",
    "ᾤ": "ω",
    "ᾥ": "ω",
    "ᾦ": "ω",
    "ᾧ": "ω",
    "ῲ": "ω",
    "ῳ": "ω",
    "ῴ": "ω",
    "ῷ": "ω",

    "ῤ": "ρ",
    "ῥ": "ρ",

    "ϐ": "β",
    "ϑ": "θ",
    "ϕ": "φ",
    "ϖ": "π",
  };

  normalized = normalized
      .toLowerCase()
      .trim()
      .split("")
      .map((char) => greekNormalization[char] ?? char)
      .join();

  normalized = normalized.replaceAll(RegExp(r'[̀-ͯ᾽-῿]'), '');

  return normalized.replaceAll('ς', 'σ');
}
