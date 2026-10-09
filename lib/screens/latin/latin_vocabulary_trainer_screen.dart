import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../models/latin/vocabulary/latin_vocabulary_question.dart';
import '../../models/greek/vocabulary/learning_card.dart';

import '../../algorithms/learning_selector.dart';

import '../../services/latin/vocabulary/latin_vocabulary_loader.dart';
import '../../services/latin/vocabulary/latin_vocabulary_answer_checker.dart';
import '../../services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import '../../services/learning_service.dart';
import '../../services/quiz_sound_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/sound_volume_button.dart';
import '../../services/streak/streak_track.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../widgets/statistics_widgets.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/settings_selection.dart';
import '../../utils/word_type_labels.dart';
import '../../info/app_info.dart';
import '../../widgets/info_report.dart';
import '../../widgets/self_assessment.dart';
import '../../widgets/trainer_widgets.dart';

class LatinVocabularyTrainerScreen extends StatefulWidget {
  const LatinVocabularyTrainerScreen({super.key});

  @override
  State<LatinVocabularyTrainerScreen> createState() =>
      _LatinVocabularyTrainerScreenState();
}

class _LatinVocabularyTrainerScreenState
    extends State<LatinVocabularyTrainerScreen> {
  List<LatinVocabularyEntry> entries = [];

  final LearningService learningService = LearningService();
  final LatinVocabularySettingsService settingsService =
      LatinVocabularySettingsService();

  final LearningSelector selector = LearningSelector();

  final FocusNode translationFocusNode = FocusNode();
  final FocusNode formFocusNode = FocusNode();
  final FocusNode genderFocusNode = FocusNode();

  Map<String, LearningCard> cards = {};

  LatinVocabularyQuestion? question;

  bool loading = true;

  bool answered = false;
  bool correct = false;

  bool includeVerbForm = true;
  bool includeNounForm = true;
  bool includeGender = true;
  bool includeAdjectiveForms = true;

  bool requireOnlyOneTranslation = false;

  /// Je verfügbarem Schritt die ausgewählten Unter-Schritte.
  /// Leere Liste = Schritt abgewählt.
  Map<int, List<int>> enabledSubsteps = {};

  List<int> get enabledSteps => [
    for (final entry in enabledSubsteps.entries)
      if (entry.value.isNotEmpty) entry.key,
  ]..sort();

  List<String> enabledTypes = List.of(LatinVocabularySettings.allTypes);

  static const List<String> allTypes = LatinVocabularySettings.allTypes;

  // Gesetzt, wenn Vokabeln, Einstellungen oder Lernstand nicht ladbar waren.
  String? loadError;

  bool? translationCorrect;
  bool translationComplete = true;

  bool? formCorrect;
  bool? genderCorrect;

  final translationController = TextEditingController();
  final formController = TextEditingController();
  final genderController = TextEditingController();

  String? uid;

  // Eintippen oder Selbsteinschätzung („Im Kopf“).
  AnswerMethod method = AnswerMethod.typing;

  // Selbsteinschätzung: Lösung der aktuellen Frage aufgedeckt.
  bool revealed = false;

  final GlobalKey<SelfAssessmentPanelState> _assessmentKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    load();

    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _isTextFieldFocused() {
    return translationFocusNode.hasFocus ||
        FocusManager.instance.primaryFocus != null &&
            FocusManager.instance.primaryFocus!.context?.widget is EditableText;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return false;
    }

    // Enter gehört einem geöffneten Info-Blatt bzw. Meldeformular.
    if (infoReportOverlayOpen) {
      return false;
    }

    if (method == AnswerMethod.recall && !answered) {
      return _assessmentKey.currentState?.handleEnter() ?? false;
    }

    // Enter gehört dem aktuell fokussierten Eingabefeld.
    if (_isTextFieldFocused()) {
      return false;
    }

    if (answered) {
      nextQuestion();
    } else {
      check();
    }

    return true;
  }

  void _handleTextFieldSubmitted(String _) {
    if (answered) {
      nextQuestion();
    } else {
      check();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);

    translationFocusNode.dispose();

    formFocusNode.dispose();
    genderFocusNode.dispose();

    translationController.dispose();
    formController.dispose();
    genderController.dispose();

    super.dispose();
  }

  Future<void> load() async {
    // uid == null: Gastmodus, die Services speichern dann lokal.
    uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      // Einstellungen, Vokabeln und Lernstand sind voneinander unabhängig.
      final results = await Future.wait<Object>([
        settingsService.load(uid),
        LatinVocabularyLoader.load(),
        learningService.loadLatinCards(uid),
        AnswerMethodPreference.load(AnswerMethodPreference.latinVocabulary),
      ]);

      method = results[3] as AnswerMethod;

      final settings = results[0] as LatinVocabularySettings;

      includeVerbForm = settings.includeVerbForm;
      includeNounForm = settings.includeNounForm;
      includeGender = settings.includeGender;
      includeAdjectiveForms = settings.includeAdjectiveForms;
      requireOnlyOneTranslation = settings.requireOnlyOneTranslation;
      enabledTypes = settings.enabledTypes;

      entries = results[1] as List<LatinVocabularyEntry>;

      // Schritte ohne gespeicherte Auswahl (Standard, neue Lektionen) sind
      // vollständig aktiviert.
      enabledSubsteps = {
        for (final entry in _availableSubsteps().entries)
          entry.key:
              settings.enabledSubsteps[entry.key]
                  ?.where(entry.value.contains)
                  .toSet()
                  .toList() ??
              List<int>.from(entry.value),
      };

      cards = results[2] as Map<String, LearningCard>;
    } catch (e) {
      // Keine rohen Firebase-/Laufzeitfehler anzeigen.
      debugPrint("Vokabeltrainer konnte nicht geladen werden: $e");

      loadError =
          "Der Trainer konnte nicht geladen werden. Bitte prüfe deine "
          "Internetverbindung und versuche es erneut.";
    }

    if (!mounted) {
      return;
    }

    if (loadError == null) {
      nextQuestion();
    }

    setState(() {
      loading = false;
    });
  }

  bool _substepEnabled(LatinVocabularyEntry entry) {
    return enabledSubsteps[entry.step]?.contains(entry.substep) ?? false;
  }

  bool _currentQuestionMatchesFilters() {
    final q = question;

    if (q == null) {
      return false;
    }

    return _substepEnabled(q.entry) && enabledTypes.contains(q.entry.type);
  }

  void nextQuestion() {
    final availableEntries = entries.where((entry) {
      return _substepEnabled(entry) && enabledTypes.contains(entry.type);
    }).toList();

    if (availableEntries.isEmpty) {
      question = null;

      setState(() {});

      return;
    }

    // Die Filter stehen fest; gewichtet wird nur innerhalb des Pools.
    final next = selector.select(
      candidates: availableEntries,
      idOf: (entry) => entry.id.toString(),
      cards: cards,
      baseWeightOf: (entry) => entry.weight,
    )!;

    question = LatinVocabularyQuestion(entry: next);

    translationController.clear();
    formController.clear();
    genderController.clear();

    answered = false;
    revealed = false;
    correct = false;

    translationCorrect = null;
    translationComplete = true;

    formCorrect = null;
    genderCorrect = null;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Im Kopf wird nichts getippt: keine Bildschirmtastatur öffnen.
      if (mounted && method == AnswerMethod.typing) {
        _focusFirstInputField();
      }
    });
  }

  void setMethod(AnswerMethod value) {
    if (answered || revealed || value == method) {
      return;
    }

    setState(() {
      method = value;
    });

    if (value == AnswerMethod.typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusFirstInputField();
        }
      });
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    AnswerMethodPreference.save(AnswerMethodPreference.latinVocabulary, value);
  }

  /// Verbucht eine Antwort im Lernstand – gleich, ob die Eingabe geprüft
  /// oder das eigene Wissen eingeschätzt wurde.
  void _recordAnswer(LatinVocabularyQuestion q, bool correct) {
    final card =
        cards[q.entry.id.toString()] ?? LearningCard(id: q.entry.id.toString());

    selector.algorithm.answer(card, correct);

    cards[q.entry.id.toString()] = card;

    // Nicht auf den Server warten: Firestore bestätigt offline erst später,
    // die Auswertung soll trotzdem sofort erscheinen.
    learningService.saveLatinCard(uid, card).catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });
  }

  /// Selbsteinschätzung nach dem Aufdecken: zählt wie eine richtige bzw.
  /// falsche Antwort und führt direkt zur nächsten Frage.
  void assess(SelfAssessment assessment) {
    final q = question;

    // Je aufgedeckter Lösung nur eine Bewertung.
    if (q == null || !revealed || answered) {
      return;
    }

    revealed = false;

    _recordAnswer(q, assessment.knew);

    _reportAnswer(assessment.knew, firstEvaluation: true);

    nextQuestion();
  }

  void _focusFirstInputField() {
    final q = question;

    if (q == null) {
      return;
    }

    final formFieldShown =
        (q.hasVerbFormField && includeVerbForm) ||
        (q.hasNounFormField && includeNounForm) ||
        (q.hasAdjectiveFormsField && includeAdjectiveForms);

    if (formFieldShown) {
      formFocusNode.requestFocus();
      return;
    }

    if (q.hasGenderField && includeGender) {
      genderFocusNode.requestFocus();
      return;
    }

    translationFocusNode.requestFocus();
  }

  /// Sound, Tagesstatistik und Streak einer bewerteten Antwort – für
  /// geprüfte Eingaben und Selbsteinschätzungen dieselbe Zählstelle.
  void _reportAnswer(bool correct, {required bool firstEvaluation}) {
    reportTrainerAnswer(
      context,
      uid: uid,
      correct: correct,
      firstEvaluation: firstEvaluation,
      sound: SoundModule.latinVocabulary,
      trainer: StatisticsTrainer.latinVocabulary,
      track: StreakTrack.latin,
      source: StreakSource.vocabulary,
    );
  }

  Future<void> check() async {
    final q = question;

    if (q == null || method != AnswerMethod.typing) {
      return;
    }

    final result = LatinVocabularyAnswerChecker.check(
      entry: q.entry,
      translationInput: translationController.text,
      formInput: formController.text,
      genderInput: genderController.text,
      checkVerbForm: q.hasVerbFormField && includeVerbForm,
      checkNounForm: q.hasNounFormField && includeNounForm,
      checkGender: q.hasGenderField && includeGender,
      checkAdjectiveForms: q.hasAdjectiveFormsField && includeAdjectiveForms,
      requireOnlyOneTranslation: requireOnlyOneTranslation,
    );

    _recordAnswer(q, result.correct);

    // Streak nur einmal je Frage zählen (auch bei doppeltem Enter).
    final firstEvaluation = !answered;

    setState(() {
      answered = true;

      correct = result.correct;

      translationCorrect = result.translationCorrect;

      translationComplete = result.translationComplete;

      formCorrect = result.formCorrect;

      genderCorrect = result.genderCorrect;
    });

    _reportAnswer(result.correct, firstEvaluation: firstEvaluation);
  }

  void openSettings() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ModuleSettingsDialog(
              moduleLabel: "Vokabeltrainer",
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Einstellungen"),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      if (enabledSteps.isEmpty || enabledTypes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Mindestens ein Schritt und eine Wortart müssen ausgewählt sein.",
                            ),
                          ),
                        );

                        return;
                      }

                      await settingsService.saveSettings(
                        uid: uid,
                        includeVerbForm: includeVerbForm,
                        includeNounForm: includeNounForm,
                        includeGender: includeGender,
                        includeAdjectiveForms: includeAdjectiveForms,
                        requireOnlyOneTranslation: requireOnlyOneTranslation,
                        enabledSteps: enabledSteps,
                        enabledSubsteps: enabledSubsteps,
                        enabledTypes: enabledTypes,
                      );

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(context);

                      setState(() {});

                      if (!_currentQuestionMatchesFilters()) {
                        nextQuestion();
                      }
                    },
                  ),
                ],
              ),
              moduleSettings: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.65,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStepSelection(setDialogState),

                      MultiSelectSection<String>(
                        title: "Wortarten",
                        hint:
                            "Abgefragt werden nur Vokabeln der ausgewählten "
                            "Wortarten.",
                        options: allTypes,
                        isSelected: enabledTypes.contains,
                        labelOf: wordTypeFilterLabel,
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

                      SettingsSection(
                        title: "Abfrage",
                        hint:
                            "Legt fest, was zusätzlich zur Übersetzung "
                            "eingegeben werden muss.",
                        child: SettingsSwitchGroup(
                          children: [
                            SwitchListTile(
                              title: const Text("Verbform abfragen"),
                              subtitle: const Text("Bei Verben"),
                              value: includeVerbForm,
                              onChanged: (value) {
                                setDialogState(() {
                                  includeVerbForm = value;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Nomenform abfragen"),
                              subtitle: const Text("Bei Nomen"),
                              value: includeNounForm,
                              onChanged: (value) {
                                setDialogState(() {
                                  includeNounForm = value;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Genus abfragen"),
                              subtitle: const Text("Bei Nomen"),
                              value: includeGender,
                              onChanged: (value) {
                                setDialogState(() {
                                  includeGender = value;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Adjektivformen abfragen"),
                              subtitle: const Text("Bei Adjektiven"),
                              value: includeAdjectiveForms,
                              onChanged: (value) {
                                setDialogState(() {
                                  includeAdjectiveForms = value;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text(
                                "Eine richtige Übersetzung reicht (empfohlen)",
                              ),
                              subtitle: const Text(
                                "Sonst müssen alle Übersetzungen genannt "
                                "werden.",
                              ),
                              value: requireOnlyOneTranslation,
                              onChanged: (value) {
                                setDialogState(() {
                                  requireOnlyOneTranslation = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SoundSettingsSection(
                        module: SoundModule.latinVocabulary,
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

  /// Schrittauswahl: je Schritt eine Karte mit seinen Unter-Schritten als
  /// direkt antippbare Chips.
  Widget _buildStepSelection(StateSetter setDialogState) {
    final available = _availableSubsteps();

    int total = 0;
    int selected = 0;

    for (final entry in available.entries) {
      total += entry.value.length;
      selected += enabledSubsteps[entry.key]?.length ?? 0;
    }

    return SettingsSection(
      title: "Schritte",
      hint:
          "Abgefragt werden nur Vokabeln aus den ausgewählten "
          "Unter-Schritten. Mehrere können gleichzeitig ausgewählt sein.",
      action: TextButton(
        onPressed: () {
          setDialogState(_toggleAllSteps);
        },
        child: Text(
          _allStepsCheckboxValue() == true ? "Alle abwählen" : "Alle auswählen",
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in available.entries)
            _buildStepGroup(entry.key, entry.value, setDialogState),

          SelectionStatus(
            selectedCount: selected,
            totalCount: total,
            emptyError: "Mindestens ein Schritt muss ausgewählt sein.",
          ),
        ],
      ),
    );
  }

  Widget _buildStepGroup(
    int step,
    List<int> substeps,
    StateSetter setDialogState,
  ) {
    final selectedSubsteps = enabledSubsteps[step] ?? [];

    final allSelected =
        selectedSubsteps.length == substeps.length && substeps.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: "Schritt $step",
                      style: Theme.of(context).textTheme.titleSmall,
                      children: [
                        TextSpan(
                          text:
                              "  ${selectedSubsteps.length} von "
                              "${substeps.length}",
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _toggleStep(step, substeps);
                    });
                  },
                  child: Text(allSelected ? "Abwählen" : "Alle"),
                ),
              ],
            ),

            Wrap(
              spacing: 8,
              children: [
                for (final substep in substeps)
                  SelectionChip(
                    label: "$step.$substep",
                    selected: selectedSubsteps.contains(substep),
                    onSelected: (value) {
                      setDialogState(() {
                        enabledSubsteps.putIfAbsent(step, () => []);

                        if (value) {
                          if (!enabledSubsteps[step]!.contains(substep)) {
                            enabledSubsteps[step]!.add(substep);
                          }
                        } else {
                          enabledSubsteps[step]!.remove(substep);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<int, List<int>> _availableSubsteps() {
    final result = <int, List<int>>{};

    for (final entry in entries) {
      result.putIfAbsent(entry.step, () => []);

      if (!result[entry.step]!.contains(entry.substep)) {
        result[entry.step]!.add(entry.substep);
      }
    }

    for (final list in result.values) {
      list.sort();
    }

    return result;
  }

  bool? _allStepsCheckboxValue() {
    final available = _availableSubsteps();

    if (available.isEmpty) {
      return false;
    }

    int total = 0;
    int selected = 0;

    for (final entry in available.entries) {
      final substeps = entry.value;
      total += substeps.length;
      selected += enabledSubsteps[entry.key]?.length ?? 0;
    }

    if (selected == 0) {
      return false;
    }

    if (selected == total) {
      return true;
    }

    return null;
  }

  void _toggleAllSteps() {
    final available = _availableSubsteps();

    final allSelected = _allStepsCheckboxValue() == true;

    enabledSubsteps = {
      for (final entry in available.entries)
        entry.key: allSelected ? [] : List<int>.from(entry.value),
    };
  }

  void _toggleStep(int step, List<int> substeps) {
    final current = enabledSubsteps[step] ?? [];

    final allSelected =
        current.length == substeps.length && substeps.isNotEmpty;

    enabledSubsteps[step] = allSelected ? [] : List<int>.from(substeps);
  }

  /// Vollständige Lösung für die Selbsteinschätzung.
  Widget _buildSolution(LatinVocabularyQuestion q) {
    final entry = q.entry;

    return Column(
      children: [
        SelectableText(
          entry.translations.join(", "),
          key: const Key("vocabulary_translation_text"),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),

        if (entry.form != null || entry.gender != null)
          const SizedBox(height: 8),

        if (entry.form != null) Text("Form: ${entry.form}"),

        if (entry.gender != null) Text("Genus: ${entry.gender}"),
      ],
    );
  }

  Widget _buildMnemonic(LatinVocabularyQuestion q, LearningCard card) {
    return MnemonicSection(
      key: ValueKey(q.entry.id),
      mnemonic: card.mnemonic,
      onSave: (mnemonic) async {
        card.mnemonic = mnemonic;

        cards[q.entry.id.toString()] = card;

        await learningService.saveLatinCard(uid, card);

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = question;

    final appBar = AppBar(
      title: const Text("Latein – Vokabeltrainer"),
      actions: [
        StatisticsButton(uid: uid, trainer: StatisticsTrainer.latinVocabulary),
        const SoundVolumeButton(),
        IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
      ],
    );

    if (q == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text(
            loadError ??
                "Mit den aktuellen Filtern sind keine Vokabeln verfügbar.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final card =
        cards[q.entry.id.toString()] ?? LearningCard(id: q.entry.id.toString());

    return Scaffold(
      appBar: appBar,

      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    q.entry.lemma,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  AnswerMethodSelector(
                    method: method,
                    onChanged: answered || revealed ? null : setMethod,
                  ),

                  const SizedBox(height: 20),

                  if (method == AnswerMethod.recall) ...[
                    SelfAssessmentPanel(
                      key: _assessmentKey,
                      revealed: revealed,
                      onReveal: () => setState(() => revealed = true),
                      onAssess: assess,
                      solutionBuilder: (_) => _buildSolution(q),
                    ),

                    if (revealed) ...[
                      const SizedBox(height: 16),

                      _buildMnemonic(q, card),
                    ],
                  ] else ...[
                    if ((q.hasVerbFormField && includeVerbForm) ||
                        (q.hasNounFormField && includeNounForm) ||
                        (q.hasAdjectiveFormsField && includeAdjectiveForms))
                      TextField(
                        controller: formController,
                        focusNode: formFocusNode,
                        key: ValueKey('form-${q.entry.id}'),
                        onSubmitted: _handleTextFieldSubmitted,
                        enabled:
                            !answered &&
                            ((q.entry.type == "verb" && includeVerbForm) ||
                                (q.entry.type == "noun" && includeNounForm) ||
                                (q.entry.type == "adjective" &&
                                    includeAdjectiveForms)),
                        decoration: InputDecoration(
                          labelText: q.entry.type == "verb"
                              ? "Form"
                              : q.entry.type == "noun"
                              ? "Zusatzform"
                              : "Formen",
                          enabledBorder: answerResultBorder(
                            context,
                            formCorrect,
                          ),
                          focusedBorder: answerResultBorder(
                            context,
                            formCorrect,
                          ),
                          disabledBorder: answerResultBorder(
                            context,
                            formCorrect,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),

                    if (q.hasGenderField && includeGender) ...[
                      const SizedBox(height: 12),

                      TextField(
                        controller: genderController,
                        focusNode: genderFocusNode,
                        key: ValueKey('gender-${q.entry.id}'),
                        onSubmitted: _handleTextFieldSubmitted,
                        enabled: !answered,
                        decoration: InputDecoration(
                          labelText: "Genus",
                          hintText: "z. B. m, f, n",
                          enabledBorder: answerResultBorder(
                            context,
                            genderCorrect,
                          ),
                          focusedBorder: answerResultBorder(
                            context,
                            genderCorrect,
                          ),
                          disabledBorder: answerResultBorder(
                            context,
                            genderCorrect,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),

                    TextField(
                      controller: translationController,
                      key: ValueKey('translation-${q.entry.id}'),
                      onSubmitted: _handleTextFieldSubmitted,
                      enabled: !answered,
                      focusNode: translationFocusNode,
                      decoration: InputDecoration(
                        labelText: "Übersetzung",
                        hintText: "Mehrere Übersetzungen mit Komma trennen",
                        enabledBorder: answerResultBorder(
                          context,
                          translationCorrect,
                        ),
                        focusedBorder: answerResultBorder(
                          context,
                          translationCorrect,
                        ),
                        disabledBorder: answerResultBorder(
                          context,
                          translationCorrect,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (answered)
                      Column(
                        children: [
                          AnswerFeedbackBadge(
                            correct: correct,
                            label: correct ? "Richtig" : "Falsch",
                          ),

                          const SizedBox(height: 12),

                          if (!correct ||
                              !translationComplete ||
                              !includeVerbForm ||
                              !includeNounForm ||
                              !includeGender ||
                              !includeAdjectiveForms)
                            Column(
                              children: [
                                const Text(
                                  "Korrekte Antworten:",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),

                                const SizedBox(height: 8),

                                if (q.entry.form != null &&
                                    (formCorrect == false ||
                                        (q.entry.type == "verb" &&
                                            !includeVerbForm) ||
                                        (q.entry.type == "noun" &&
                                            !includeNounForm) ||
                                        (q.entry.type == "adjective" &&
                                            !includeAdjectiveForms)))
                                  Text("Form: ${q.entry.form}"),

                                if (q.entry.gender != null &&
                                    (genderCorrect == false || !includeGender))
                                  Text("Genus: ${q.entry.gender}"),

                                if (translationCorrect == false ||
                                    !translationComplete)
                                  Text(
                                    "Übersetzung: "
                                    "${q.entry.translations.join(", ")}",
                                  ),
                              ],
                            ),

                          const SizedBox(height: 16),

                          _buildMnemonic(q, card),
                        ],
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: answered ? nextQuestion : check,
                        child: Text(answered ? "Weiter" : "Prüfen"),
                      ),
                    ),
                  ],

                  InfoReportFooter(
                    module: AppModules.latinVocabulary,
                    reportDetails: () => {
                      "Eintrag": "${q.entry.lemma} (ID ${q.entry.id})",
                      "Schritt": "${q.entry.step}.${q.entry.substep}",
                      "Wortart": q.entry.type,
                      // Lösung erst nach dem Prüfen bzw. Aufdecken, damit das
                      // Formular sie nicht verrät.
                      if (answered || revealed)
                        "Hinterlegte Übersetzung": q.entry.translations.join(
                          ", ",
                        ),
                      if (answered) "Eingabe": translationController.text,
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
