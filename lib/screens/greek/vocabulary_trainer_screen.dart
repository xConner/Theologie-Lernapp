import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../models/greek/vocabulary/greek_vocabulary_question.dart';
import '../../models/greek/vocabulary/learning_card.dart';

import '../../algorithms/learning_selector.dart';

import '../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../services/greek/vocabulary/vocabulary_answer_checker.dart';
import '../../services/greek/vocabulary/vocabulary_settings_service.dart';
import '../../services/learning_service.dart';
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
import '../../utils/word_type_labels.dart';
import '../../info/app_info.dart';
import '../../widgets/info_report.dart';

class VocabularyTrainerScreen extends StatefulWidget {
  const VocabularyTrainerScreen({super.key});

  @override
  State<VocabularyTrainerScreen> createState() =>
      _VocabularyTrainerScreenState();
}

class SubmitIntent extends Intent {
  const SubmitIntent();
}

class _VocabularyTrainerScreenState extends State<VocabularyTrainerScreen> {
  List<GreekVocabularyEntry> entries = [];

  final LearningService learningService = LearningService();
  final VocabularySettingsService settingsService = VocabularySettingsService();

  final LearningSelector selector = LearningSelector();

  late final web.EventListener _keyListener;
  final FocusNode translationFocusNode = FocusNode();
  Map<String, LearningCard> cards = {};

  VocabularyQuestion? question;

  bool loading = true;

  bool answered = false;

  bool correct = false;

  bool includeArticle = true;

  bool includeGenitive = true;

  bool includeAorist = true;

  bool requireOnlyOneTranslation = true;

  List<int> enabledSteps = [1, 2, 3, 4, 5, 6, 7];

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
    "numeral",
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
    "numeral",
    "phrase",
  ];

  bool editingMnemonic = false;

  final mnemonicController = TextEditingController();

  bool? translationCorrect;

  bool translationComplete = true;

  bool? articleCorrect;

  bool? genitiveCorrect;

  bool? aoristCorrect;

  final translationController = TextEditingController();

  final articleController = TextEditingController();

  final genitiveController = TextEditingController();

  final aoristController = TextEditingController();

  bool showKeyboard = false;

  TextEditingController? activeController;

  String? uid;

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
        } else {
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
    translationFocusNode.dispose();
    mnemonicController.dispose();
    super.dispose();
  }

  bool currentQuestionMatchesFilters() {
    final q = question;

    if (q == null) {
      return true;
    }

    return enabledSteps.contains(q.entry.step) &&
        enabledTypes.contains(q.entry.type);
  }

  Future<void> load() async {
    // uid == null: Gastmodus, die Services speichern dann lokal.
    uid = FirebaseAuth.instance.currentUser?.uid;

    includeArticle = await settingsService.getIncludeArticle(uid);

    includeGenitive = await settingsService.getIncludeGenitive(uid);

    includeAorist = await settingsService.getIncludeAorist(uid);

    requireOnlyOneTranslation = await settingsService
        .getRequireOnlyOneTranslation(uid);

    enabledSteps = await settingsService.getEnabledSteps(uid);

    enabledTypes = await settingsService.getEnabledTypes(uid);

    entries = await GreekVocabularyLoader.load();

    cards = await learningService.loadCards(uid);

    nextQuestion();

    setState(() {
      loading = false;
    });
  }

  void nextQuestion() {
    if (enabledSteps.isEmpty || enabledTypes.isEmpty) {
      return;
    }

    final availableEntries = entries.where((entry) {
      return enabledSteps.contains(entry.step) &&
          enabledTypes.contains(entry.type);
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

    question = VocabularyQuestion(entry: next);

    translationController.clear();

    articleController.clear();

    genitiveController.clear();

    aoristController.clear();

    answered = false;

    correct = false;

    translationCorrect = null;

    translationComplete = true;

    articleCorrect = null;

    genitiveCorrect = null;

    aoristCorrect = null;

    showKeyboard = false;

    activeController = null;

    setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () {
      translationFocusNode.requestFocus();
    });
  }

  Future<void> check() async {
    final q = question;

    if (q == null) {
      return;
    }

    final result = VocabularyAnswerChecker.check(
      entry: q.entry,

      translationInput: translationController.text,

      articleInput: articleController.text,

      genitiveInput: genitiveController.text,

      aoristInput: aoristController.text,

      checkArticle: q.checkArticle && includeArticle,

      checkGenitive: q.checkGenitive && includeGenitive,

      checkAorist: q.checkAorist && includeAorist,

      requireOnlyOneTranslation: requireOnlyOneTranslation,
    );

    final card =
        cards[q.entry.id.toString()] ?? LearningCard(id: q.entry.id.toString());

    selector.algorithm.answer(card, result.correct);

    cards[q.entry.id.toString()] = card;

    // Nicht auf den Server warten: Firestore bestätigt offline erst später,
    // die Auswertung soll trotzdem sofort erscheinen.
    learningService.saveCard(uid, card).catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });

    // Streak nur einmal je Frage zählen (auch bei doppeltem Enter).
    final firstEvaluation = !answered;

    setState(() {
      answered = true;

      correct = result.correct;

      translationCorrect = result.translationCorrect;

      translationComplete = result.translationComplete;

      articleCorrect = result.articleCorrect;

      genitiveCorrect = result.genitiveCorrect;

      aoristCorrect = result.aoristCorrect;

      showKeyboard = false;

      activeController = null;
    });

    if (result.correct) {
      QuizSoundPlayer.instance.playCorrect(SoundModule.greekVocabulary);
    } else {
      QuizSoundPlayer.instance.playIncorrect(SoundModule.greekVocabulary);
    }

    if (firstEvaluation) {
      LearningStatisticsService.instance.recordAnswer(
        uid: uid,
        trainer: StatisticsTrainer.greekVocabulary,
        correct: result.correct,
      );
    }

    if (result.correct && firstEvaluation && mounted) {
      recordStreakAnswer(
        context,
        uid: uid,
        track: StreakTrack.greek,
        source: StreakSource.vocabulary,
      );
    }
  }

  void openKeyboard(TextEditingController controller) {
    setState(() {
      activeController = controller;

      showKeyboard = true;
    });
  }

  void toggleKeyboard() {
    setState(() {
      if (showKeyboard) {
        showKeyboard = false;

        activeController = null;
      } else {
        showKeyboard = true;
      }
    });
  }

  void closeKeyboard() {
    setState(() {
      showKeyboard = false;

      activeController = null;
    });
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

                      final hadAnswered = answered;

                      await settingsService.saveSettings(
                        uid: uid,

                        includeArticle: includeArticle,

                        includeGenitive: includeGenitive,

                        includeAorist: includeAorist,

                        requireOnlyOneTranslation: requireOnlyOneTranslation,

                        enabledSteps: enabledSteps,

                        enabledTypes: enabledTypes,
                      );

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(context);

                      setState(() {});

                      if (!hadAnswered && !currentQuestionMatchesFilters()) {
                        nextQuestion();
                      }
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
                      MultiSelectSection<int>(
                        title: "Schritte",
                        hint:
                            "Abgefragt werden nur Vokabeln aus den "
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
                              title: const Text("Genitiv abfragen"),
                              subtitle: const Text("Bei Nomen"),
                              value: includeGenitive,
                              onChanged: (v) {
                                setDialogState(() {
                                  includeGenitive = v;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Artikel abfragen"),
                              subtitle: const Text("Bei Nomen"),
                              value: includeArticle,
                              onChanged: (v) {
                                setDialogState(() {
                                  includeArticle = v;
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Aorist abfragen"),
                              subtitle: const Text("Bei Verben"),
                              value: includeAorist,
                              onChanged: (v) {
                                setDialogState(() {
                                  includeAorist = v;
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
                              onChanged: (v) {
                                setDialogState(() {
                                  requireOnlyOneTranslation = v;
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
                                    SoundModule.greekVocabulary,
                                  ),
                              onChanged: (v) {
                                setDialogState(() {
                                  QuizSoundSettings.instance
                                      .setCorrectSoundEnabled(
                                        SoundModule.greekVocabulary,
                                        v,
                                      );
                                });
                              },
                            ),

                            SwitchListTile(
                              title: const Text("Sound bei falscher Antwort"),
                              value: QuizSoundSettings.instance
                                  .isWrongSoundEnabled(
                                    SoundModule.greekVocabulary,
                                  ),
                              onChanged: (v) {
                                setDialogState(() {
                                  QuizSoundSettings.instance
                                      .setWrongSoundEnabled(
                                        SoundModule.greekVocabulary,
                                        v,
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = question;

    if (q == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Vokabeltrainer"),
          actions: [
            StatisticsButton(
              uid: uid,
              trainer: StatisticsTrainer.greekVocabulary,
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
    final hasAdditionalInfo =
        (q.entry.article != null && !includeArticle) ||
        (q.entry.genitive != null && !includeGenitive) ||
        (q.entry.aorist != null && !includeAorist);
    final card =
        cards[q.entry.id.toString()] ?? LearningCard(id: q.entry.id.toString());

    final currentMnemonic = card.mnemonic;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vokabeltrainer"),
        actions: [
          StatisticsButton(
            uid: uid,
            trainer: StatisticsTrainer.greekVocabulary,
          ),
          const SoundVolumeButton(),
          IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
        ],
      ),

      body: GestureDetector(
        behavior: HitTestBehavior.translucent,

        onTap: closeKeyboard,

        child: Center(
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

                    if (q.hasArticleField || q.hasGenitiveField)
                      Row(
                        children: [
                          if (q.hasGenitiveField && includeGenitive)
                            Expanded(
                              child: greekField(
                                "Genitiv",
                                genitiveController,
                                genitiveCorrect,
                              ),
                            ),

                          if (q.hasArticleField &&
                              q.hasGenitiveField &&
                              includeArticle &&
                              includeGenitive)
                            const SizedBox(width: 10),

                          if (q.hasArticleField && includeArticle)
                            Expanded(
                              child: greekField(
                                "Artikel",
                                articleController,
                                articleCorrect,
                              ),
                            ),
                        ],
                      ),

                    if (q.hasAoristField && includeAorist)
                      greekField("Aorist", aoristController, aoristCorrect),

                    const SizedBox(height: 15),

                    TextField(
                      controller: translationController,

                      enabled: !answered,

                      focusNode: translationFocusNode,

                      //onTap: closeKeyboard,
                      decoration: InputDecoration(
                        labelText: "Übersetzung",

                        enabledBorder: resultBorder(translationCorrect),

                        focusedBorder: resultBorder(translationCorrect),

                        disabledBorder: resultBorder(translationCorrect),

                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (showKeyboard && activeController != null)
                      GreekKeyboard(
                        controller: activeController!,

                        onChanged: () {
                          setState(() {});
                        },
                      ),

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
                              (q.entry.article != null && !includeArticle) ||
                              (q.entry.genitive != null && !includeGenitive) ||
                              (q.entry.aorist != null && !includeAorist))
                            Column(
                              children: [
                                Text(
                                  correct &&
                                          translationComplete &&
                                          hasAdditionalInfo
                                      ? "Zusätzliche Informationen:"
                                      : "Korrekte Antworten:",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                if (q.entry.article != null &&
                                    (articleCorrect == false ||
                                        !includeArticle))
                                  Text("Artikel: ${q.entry.article}"),

                                if (q.entry.genitive != null &&
                                    (genitiveCorrect == false ||
                                        !includeGenitive))
                                  Text("Genitiv: ${q.entry.genitive}"),

                                if (q.entry.aorist != null &&
                                    (aoristCorrect == false || !includeAorist))
                                  Text("Aorist: ${q.entry.aorist}"),

                                if (translationCorrect == false ||
                                    !translationComplete)
                                  Text(
                                    "Übersetzung: ${q.entry.translations.join(", ")}",
                                  ),
                              ],
                            ),
                          if (answered) ...[
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
                                              mnemonicController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : mnemonicController.text.trim();

                                          cards[q.entry.id.toString()] = card;

                                          await learningService.saveCard(
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
                                          mnemonicController.text =
                                              currentMnemonic;

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
                      module: AppModules.greekVocabulary,
                      reportDetails: () => {
                        "Eintrag": "${q.entry.lemma} (ID ${q.entry.id})",
                        "Schritt": "${q.entry.step}",
                        "Wortart": q.entry.type,
                        // Lösung erst nach dem Prüfen, damit das Formular
                        // sie nicht verrät.
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
      ),
    );
  }

  Widget greekField(
    String label,

    TextEditingController controller,

    bool? correct,
  ) {
    return TextField(
      controller: controller,

      readOnly: true,

      enabled: !answered,

      onTap: () {
        if (!answered) {
          openKeyboard(controller);
        }
      },

      decoration: InputDecoration(
        labelText: label,

        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard),

          onPressed: answered ? null : toggleKeyboard,
        ),

        enabledBorder: resultBorder(correct),

        focusedBorder: resultBorder(correct),

        disabledBorder: resultBorder(correct),

        border: const OutlineInputBorder(),
      ),
    );
  }
}
