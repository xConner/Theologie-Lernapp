import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../algorithms/grammar_learning.dart';
import '../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../services/greek/grammar/grammar_answer_check.dart';
import '../../services/greek/grammar/grammar_question_picker.dart';
import '../../services/greek/grammar/grammar_settings_service.dart';
import '../../services/greek/grammar/wiktionary_inflection_service.dart';
import '../../services/learning_service.dart';
import '../../services/quiz_sound_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/greek_keyboard.dart';
import '../../widgets/sound_volume_button.dart';
import '../../services/streak/streak_track.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../widgets/statistics_widgets.dart';

import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../widgets/settings_access.dart';
import '../../widgets/settings_selection.dart';
import '../../info/app_info.dart';
import '../../widgets/info_report.dart';
import '../../widgets/trainer_widgets.dart';
import '../../utils/greek_normalization.dart';

class GreekGrammarTrainerScreen extends StatefulWidget {
  const GreekGrammarTrainerScreen({super.key});

  @override
  State<GreekGrammarTrainerScreen> createState() =>
      _GreekGrammarTrainerScreenState();
}

class _GreekGrammarTrainerScreenState extends State<GreekGrammarTrainerScreen> {
  final WiktionaryInflectionService wiktionaryService =
      WiktionaryInflectionService();

  final GrammarSettingsService settingsService = GrammarSettingsService();
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

  static const List<String> allTypes = GrammarQuestionPicker.types;

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
  // EINSTELLUNGEN LADEN / SPEICHERN
  // ---------------------------------------------------------------------------

  Future<void> loadGrammarSettings() async {
    final settings = await settingsService.load(_auth.currentUser?.uid);

    enabledSteps = settings.enabledSteps;
    enabledTypes = settings.enabledTypes;
    showLemmaFieldNoun = settings.showLemmaFieldNoun;
    showLemmaFieldVerb = settings.showLemmaFieldVerb;
  }

  Future<void> saveGrammarSettings() {
    return settingsService.save(
      _auth.currentUser?.uid,
      GrammarTrainerSettings(
        enabledSteps: enabledSteps,
        enabledTypes: enabledTypes,
        showLemmaFieldNoun: showLemmaFieldNoun,
        showLemmaFieldVerb: showLemmaFieldVerb,
      ),
    );
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
        !GrammarQuestionPicker.blacklist.contains(entry.lemma);
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
      if (!mounted) {
        return;
      }

      _usePreloadedQuestion();

      _preloadNextQuestion(available);

      return;
    }

    final newQuestion = GrammarQuestionPicker.pickEntry(grammar, available);

    answerController.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      question = newQuestion;

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

      _resetAnswerState();
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
      _usePreloadedQuestion();

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

  void _usePreloadedQuestion() {
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

      _resetAnswerState();
    });

    _clearPreloaded();
  }

  // Setzt Eingaben und Auswertung der vorherigen Frage zurück (innerhalb
  // von setState aufrufen).
  void _resetAnswerState() {
    answered = false;
    correct = false;

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

    final next = GrammarQuestionPicker.pickEntry(grammar, candidates);

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

      lemmaCorrect =
          !showLemmaField || lemmaAnswerMatches(answerController.text, q.lemma);

      if (q.type == "noun") {
        final result = checkNounAnswer(
          targetCase: selectedCase,
          targetNumber: selectedNumber,
          targetGender: selectedGender,
          analyses: wiktionaryService.nounFormAnalyses(
            lemma: q.lemma,
            grammaticalCase: selectedCase ?? "",
            number: GrammarQuestionPicker.nounRequestNumber(selectedNumber),
          ),
          userCase: userCase,
          userNumber: userNumber,
          userGender: userGender,
        );

        caseCorrect = result.caseCorrect;
        numberCorrect = result.numberCorrect;
        genderCorrect = result.genderCorrect;

        correct =
            lemmaCorrect! &&
            result.caseCorrect &&
            result.numberCorrect &&
            result.genderCorrect;
      } else if (q.type == "verb") {
        final parsedPerson = GrammarQuestionPicker.parsePerson(selectedPerson);

        final result = checkVerbAnswer(
          targetPerson: selectedPerson,
          targetNumber: selectedNumberVerb,
          targetTense: selectedTense,
          targetVoice: selectedVoice,
          deponent: q.deponent,
          analyses: parsedPerson == null
              ? const []
              : wiktionaryService.verbFormAnalyses(
                  lemma: q.lemma,
                  tense: selectedTense ?? "",
                  voice: selectedVoice ?? "",
                  number: selectedNumberVerb ?? "",
                  person: parsedPerson,
                ),
          userPersonNumber: userPersonNumber,
          userTense: userTense,
          userVoice: userVoice,
        );

        personCorrect = result.personCorrect;
        tenseCorrect = result.tenseCorrect;
        voiceCorrect = result.voiceCorrect;

        correct =
            lemmaCorrect! &&
            result.personCorrect &&
            result.tenseCorrect &&
            result.voiceCorrect;
      }
    });

    if (firstEvaluation) {
      _recordLearning(q);
    }

    reportTrainerAnswer(
      context,
      uid: _auth.currentUser?.uid,
      correct: correct,
      firstEvaluation: firstEvaluation,
      sound: SoundModule.greekGrammar,
      trainer: StatisticsTrainer.greekGrammar,
      track: StreakTrack.greek,
      source: StreakSource.grammar,
    );
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

    final (:grammaticalCase, :number, :gender) =
        GrammarQuestionPicker.pickNounTarget(grammar, entry);

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
        number: GrammarQuestionPicker.nounRequestNumber(number),
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

    final (:person, :number, :tense, :voice) =
        GrammarQuestionPicker.pickVerbTarget(grammar, entry);

    if (mounted) {
      setState(() {
        selectedPerson = person;
        selectedNumberVerb = number;
        selectedTense = tense;
        selectedVoice = voice;
      });
    }

    final parsedPerson = GrammarQuestionPicker.parsePerson(person);

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

    final (:grammaticalCase, :number, :gender) =
        GrammarQuestionPicker.pickNounTarget(grammar, entry);

    try {
      final form = await wiktionaryService.getNounForm(
        lemma: entry.lemma,
        grammaticalCase: grammaticalCase,
        number: GrammarQuestionPicker.nounRequestNumber(number),
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

    final (:person, :number, :tense, :voice) =
        GrammarQuestionPicker.pickVerbTarget(grammar, entry);

    final parsedPerson = GrammarQuestionPicker.parsePerson(person);

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

                      const SoundSettingsSection(
                        module: SoundModule.greekGrammar,
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

    final appBar = AppBar(
      title: const Text("Grammatiktrainer"),
      actions: [
        StatisticsButton(
          uid: _auth.currentUser?.uid,
          trainer: StatisticsTrainer.greekGrammar,
        ),
        const SoundVolumeButton(),
        IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
      ],
    );

    if (q == null) {
      return Scaffold(
        appBar: appBar,
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
      appBar: appBar,
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
                      enabledBorder: answerResultBorder(lemmaCorrect),
                      focusedBorder: answerResultBorder(lemmaCorrect),
                      disabledBorder: answerResultBorder(lemmaCorrect),
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

                      // Bei falscher Grundform steht sie unten bei den
                      // korrekten Antworten.
                      if (lemmaCorrect != false ||
                          (!(isNoun() && showLemmaFieldNoun) &&
                              !(isVerb() && showLemmaFieldVerb))) ...[
                        SelectableText(
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
                              SelectableText(
                                "Grundform: ${question?.lemma ?? ''}",
                              ),

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
        items: GrammarQuestionPicker.cases,
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
        items: GrammarQuestionPicker.numbers,
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
        items: GrammarQuestionPicker.genders,
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
        items: GrammarQuestionPicker.personNumbers,
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
        items: GrammarQuestionPicker.tenses,
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
        items: GrammarQuestionPicker.voices,
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
