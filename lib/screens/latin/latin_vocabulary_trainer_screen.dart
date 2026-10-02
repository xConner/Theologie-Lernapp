import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../models/latin/vocabulary/latin_vocabulary_question.dart';
import '../../models/greek/vocabulary/learning_card.dart';

import '../../algorithms/spaced_repetition.dart';

import '../../services/latin/vocabulary/latin_vocabulary_loader.dart';
import '../../services/latin/vocabulary/latin_vocabulary_answer_checker.dart';
import '../../services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import '../../services/learning_service.dart';
import '../../services/quiz_sound_player.dart';
import '../../services/quiz_sound_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/sound_volume_button.dart';
import '../../widgets/streak_widgets.dart';
import '../../services/streak/streak_track.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../services/statistics/statistics_service.dart';
import '../../widgets/statistics_widgets.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/settings_selection.dart';
import '../../utils/word_type_labels.dart';
import '../../info/app_info.dart';
import '../../widgets/info_report.dart';

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

  final SpacedRepetition algorithm = SpacedRepetition();

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

  List<String> enabledTypes = [
    "noun",
    "verb",
    "adjective",
    "adverb",
    "pronoun",
    "preposition",
    "conjunction",
    "particle",
    "question_word",
    "phrase",
  ];

  final List<String> allTypes = [
    "noun",
    "verb",
    "adjective",
    "adverb",
    "pronoun",
    "preposition",
    "conjunction",
    "particle",
    "question_word",
    "phrase",
  ];

  final mnemonicController = TextEditingController();

  bool editingMnemonic = false;

  bool? translationCorrect;
  bool translationComplete = true;

  bool? formCorrect;
  bool? genderCorrect;

  final translationController = TextEditingController();
  final formController = TextEditingController();
  final genderController = TextEditingController();

  String? uid;

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
    mnemonicController.dispose();

    super.dispose();
  }

  Future<void> load() async {
    // uid == null: Gastmodus, die Services speichern dann lokal.
    uid = FirebaseAuth.instance.currentUser?.uid;

    includeVerbForm = await settingsService.getIncludeVerbForm(uid);

    includeNounForm = await settingsService.getIncludeNounForm(uid);

    includeGender = await settingsService.getIncludeGender(uid);

    includeAdjectiveForms = await settingsService.getIncludeAdjectiveForms(
      uid,
    );

    requireOnlyOneTranslation = await settingsService
        .getRequireOnlyOneTranslation(uid);

    entries = await LatinVocabularyLoader.load();

    final savedSubsteps = await settingsService.getEnabledSubsteps(uid);

    // Schritte ohne gespeicherte Auswahl (Standard, neue Lektionen) sind
    // vollständig aktiviert.
    enabledSubsteps = {
      for (final entry in _availableSubsteps().entries)
        entry.key:
            savedSubsteps[entry.key]
                ?.where(entry.value.contains)
                .toSet()
                .toList() ??
            List<int>.from(entry.value),
    };

    enabledTypes = await settingsService.getEnabledTypes(uid);

    cards = await learningService.loadLatinCards(uid);

    nextQuestion();

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

    double total = 0;

    final Map<LatinVocabularyEntry, double> scores = {};

    for (final entry in availableEntries) {
      final card =
          cards[entry.id.toString()] ?? LearningCard(id: entry.id.toString());

      final score = algorithm.selectionScore(card);

      scores[entry] = score;

      total += score;
    }

    LatinVocabularyEntry next;

    if (total <= 0) {
      next = availableEntries[Random().nextInt(availableEntries.length)];
    } else {
      double random = Random().nextDouble() * total;

      next = availableEntries.last;

      for (final entry in availableEntries) {
        random -= scores[entry]!;

        if (random <= 0) {
          next = entry;
          break;
        }
      }
    }

    question = LatinVocabularyQuestion(entry: next);

    translationController.clear();
    formController.clear();
    genderController.clear();

    answered = false;
    correct = false;

    translationCorrect = null;
    translationComplete = true;

    formCorrect = null;
    genderCorrect = null;

    editingMnemonic = false;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusFirstInputField();
      }
    });
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

  Future<void> check() async {
    final q = question;

    if (q == null) {
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

    final card =
        cards[q.entry.id.toString()] ?? LearningCard(id: q.entry.id.toString());

    algorithm.answer(card, result.correct);

    cards[q.entry.id.toString()] = card;

    await learningService.saveLatinCard(uid, card);

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

    if (result.correct) {
      QuizSoundPlayer.instance.playCorrect(SoundModule.latinVocabulary);
    } else {
      QuizSoundPlayer.instance.playIncorrect(SoundModule.latinVocabulary);
    }

    if (firstEvaluation) {
      LearningStatisticsService.instance.recordAnswer(
        uid: uid,
        trainer: StatisticsTrainer.latinVocabulary,
        correct: result.correct,
      );
    }

    if (result.correct && firstEvaluation && mounted) {
      recordStreakAnswer(
        context,
        uid: uid,
        track: StreakTrack.latin,
        source: StreakSource.vocabulary,
      );
    }
  }

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

                      SettingsSection(
                        title: "Sounds",
                        child: SettingsSwitchGroup(
                          children: [
                            SwitchListTile(
                              title: const Text("Sound bei richtiger Antwort"),
                              value: QuizSoundSettings.instance
                                  .isCorrectSoundEnabled(
                                    SoundModule.latinVocabulary,
                                  ),
                              onChanged: (value) {
                                setDialogState(() {
                                  QuizSoundSettings.instance
                                      .setCorrectSoundEnabled(
                                        SoundModule.latinVocabulary,
                                        value,
                                      );
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Sound bei falscher Antwort"),
                              value: QuizSoundSettings.instance
                                  .isWrongSoundEnabled(
                                    SoundModule.latinVocabulary,
                                  ),
                              onChanged: (value) {
                                setDialogState(() {
                                  QuizSoundSettings.instance
                                      .setWrongSoundEnabled(
                                        SoundModule.latinVocabulary,
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
                          style: const TextStyle(
                            color: AppColors.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = question;

    if (q == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Latein – Vokabeltrainer"),
          actions: [
            StatisticsButton(
              uid: uid,
              trainer: StatisticsTrainer.latinVocabulary,
            ),
            const SoundVolumeButton(),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: openSettings,
            ),
          ],
        ),
        body: const Center(
          child: Text(
            "Mit den aktuellen Filtern sind keine Vokabeln verfügbar.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final card =
        cards[q.entry.id.toString()] ?? LearningCard(id: q.entry.id.toString());

    final currentMnemonic = card.mnemonic;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Latein – Vokabeltrainer"),
        actions: [
          StatisticsButton(
            uid: uid,
            trainer: StatisticsTrainer.latinVocabulary,
          ),
          const SoundVolumeButton(),
          IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
        ],
      ),

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

                  const SizedBox(height: 20),

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
                        enabledBorder: resultBorder(formCorrect),
                        focusedBorder: resultBorder(formCorrect),
                        disabledBorder: resultBorder(formCorrect),
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
                        enabledBorder: resultBorder(genderCorrect),
                        focusedBorder: resultBorder(genderCorrect),
                        disabledBorder: resultBorder(genderCorrect),
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
                      enabledBorder: resultBorder(translationCorrect),
                      focusedBorder: resultBorder(translationCorrect),
                      disabledBorder: resultBorder(translationCorrect),
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

                        if (editingMnemonic)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: mnemonicController,
                                    decoration: const InputDecoration(
                                      labelText: "Lernhilfe",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.save),
                                    label: const Text("Speichern"),
                                    onPressed: () async {
                                      card.mnemonic =
                                          mnemonicController.text.trim().isEmpty
                                          ? null
                                          : mnemonicController.text.trim();

                                      cards[q.entry.id.toString()] = card;

                                      await learningService.saveLatinCard(
                                        uid,
                                        card,
                                      );

                                      setState(() {
                                        editingMnemonic = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (currentMnemonic != null &&
                            currentMnemonic.isNotEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Text(
                                          "Lernhilfe",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        Text(
                                          currentMnemonic,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      mnemonicController.text = currentMnemonic;

                                      setState(() {
                                        editingMnemonic = true;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Lernhilfe hinzufügen"),
                            onPressed: () {
                              mnemonicController.clear();

                              setState(() {
                                editingMnemonic = true;
                              });
                            },
                          ),
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

                  InfoReportFooter(
                    module: AppModules.latinVocabulary,
                    reportDetails: () => {
                      "Eintrag": "${q.entry.lemma} (ID ${q.entry.id})",
                      "Schritt": "${q.entry.step}.${q.entry.substep}",
                      "Wortart": q.entry.type,
                      // Lösung erst nach dem Prüfen, damit das Formular sie
                      // nicht verrät.
                      if (answered) ...{
                        "Hinterlegte Übersetzung": q.entry.translations.join(
                          ", ",
                        ),
                        "Eingabe": translationController.text,
                      },
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
