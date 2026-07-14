import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/greek_vocabulary_entry.dart';
import '../../models/vocabulary_question.dart';
import '../../models/learning_card.dart';

import '../../algorithms/spaced_repetition.dart';

import '../../services/greek_vocabulary_loader.dart';
import '../../services/vocabulary_answer_checker.dart';
import '../../services/vocabulary_settings_service.dart';
import '../../services/learning_service.dart';

import '../../widgets/greek_keyboard.dart';

class VocabularyTrainerScreen extends StatefulWidget {
  const VocabularyTrainerScreen({super.key});

  @override
  State<VocabularyTrainerScreen> createState() =>
      _VocabularyTrainerScreenState();
}

class _VocabularyTrainerScreenState extends State<VocabularyTrainerScreen> {
  List<GreekVocabularyEntry> entries = [];

  final LearningService learningService = LearningService();
  final VocabularySettingsService settingsService = VocabularySettingsService();

  final SpacedRepetition algorithm = SpacedRepetition();

  Map<String, LearningCard> cards = {};

  VocabularyQuestion? question;

  bool loading = true;

  bool answered = false;

  bool correct = false;

  bool includeArticle = true;

  bool includeGenitive = true;

  bool includeAorist = true;

  bool requireOnlyOneTranslation = false;

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
  }

  @override
  void dispose() {
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
    uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    includeArticle = await settingsService.getIncludeArticle(uid!);

    includeGenitive = await settingsService.getIncludeGenitive(uid!);

    includeAorist = await settingsService.getIncludeAorist(uid!);

    requireOnlyOneTranslation = await settingsService
        .getRequireOnlyOneTranslation(uid!);

    enabledSteps = await settingsService.getEnabledSteps(uid!);

    enabledTypes = await settingsService.getEnabledTypes(uid!);

    entries = await GreekVocabularyLoader.load();

    for (final e in entries) {
      if (e.mnemonic != null) {
        print("${e.lemma}: ${e.mnemonic}");
      }
    }

    cards = await learningService.loadCards(uid!);

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

    double total = 0;

    final Map<GreekVocabularyEntry, double> scores = {};

    for (final entry in availableEntries) {
      final card =
          cards[entry.id.toString()] ?? LearningCard(id: entry.id.toString());

      final score = algorithm.selectionScore(card);

      scores[entry] = score;

      total += score;
    }

    GreekVocabularyEntry next;

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
  }

  Future<void> check() async {
    final q = question;

    if (q == null || uid == null) {
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

    algorithm.answer(card, result.correct);

    cards[q.entry.id.toString()] = card;

    await learningService.saveCard(uid!, card);

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
        color: value ? Colors.green : Colors.red,

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
            return AlertDialog(
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
                        uid: uid!,

                        includeArticle: includeArticle,

                        includeGenitive: includeGenitive,

                        includeAorist: includeAorist,

                        requireOnlyOneTranslation: requireOnlyOneTranslation,

                        enabledSteps: enabledSteps,

                        enabledTypes: enabledTypes,
                      );

                      Navigator.pop(context);

                      setState(() {});

                      if (!hadAnswered && !currentQuestionMatchesFilters()) {
                        nextQuestion();
                      }
                    },
                  ),
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,

                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text("Genitiv"),

                        value: includeGenitive,

                        onChanged: (v) {
                          setDialogState(() {
                            includeGenitive = v ?? false;
                          });
                        },
                      ),

                      CheckboxListTile(
                        title: const Text("Artikel"),

                        value: includeArticle,

                        onChanged: (v) {
                          setDialogState(() {
                            includeArticle = v ?? false;
                          });
                        },
                      ),

                      CheckboxListTile(
                        title: const Text("Aorist"),

                        value: includeAorist,

                        onChanged: (v) {
                          setDialogState(() {
                            includeAorist = v ?? false;
                          });
                        },
                      ),

                      CheckboxListTile(
                        title: const Text("Eine richtige Übersetzung reicht"),

                        value: requireOnlyOneTranslation,

                        onChanged: (v) {
                          setDialogState(() {
                            requireOnlyOneTranslation = v ?? false;
                          });
                        },
                      ),
                      ExpansionTile(
                        title: const Text("Schritte"),

                        children: [
                          CheckboxListTile(
                            title: const Text("Alle Schritte"),

                            tristate: true,

                            value: enabledSteps.length == 7
                                ? true
                                : enabledSteps.isEmpty
                                ? false
                                : null,

                            onChanged: (_) {
                              setDialogState(() {
                                if (enabledSteps.length == 7) {
                                  enabledSteps.clear();
                                } else {
                                  enabledSteps = [1, 2, 3, 4, 5, 6, 7];
                                }
                              });
                            },
                          ),

                          ...List.generate(7, (index) {
                            final step = index + 1;

                            return CheckboxListTile(
                              title: Text("Schritt $step"),

                              value: enabledSteps.contains(step),

                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    enabledSteps.add(step);
                                  } else {
                                    enabledSteps.remove(step);
                                  }
                                });
                              },
                            );
                          }),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text("Wortarten"),

                        children: [
                          CheckboxListTile(
                            title: const Text("Alle Wortarten"),

                            tristate: true,

                            value: enabledTypes.length == allTypes.length
                                ? true
                                : enabledTypes.isEmpty
                                ? false
                                : null,

                            onChanged: (_) {
                              setDialogState(() {
                                if (enabledTypes.length == allTypes.length) {
                                  enabledTypes.clear();
                                } else {
                                  enabledTypes = List.from(allTypes);
                                }
                              });
                            },
                          ),

                          ...allTypes.map((type) {
                            return CheckboxListTile(
                              title: Text(type),

                              value: enabledTypes.contains(type),

                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    enabledTypes.add(type);
                                  } else {
                                    enabledTypes.remove(type);
                                  }
                                });
                              },
                            );
                          }),
                        ],
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

                      onTap: closeKeyboard,

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
                          Text(
                            correct ? "Richtig" : "Falsch",

                            style: TextStyle(
                              fontSize: 22,

                              fontWeight: FontWeight.bold,

                              color: correct ? Colors.green : Colors.red,
                            ),
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
                                            uid!,
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
