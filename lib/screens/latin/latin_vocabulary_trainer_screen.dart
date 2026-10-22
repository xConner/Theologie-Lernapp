import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../models/greek/vocabulary/learning_card.dart';

import '../../algorithms/learning_selector.dart';
import '../../algorithms/review_state.dart';

import '../../services/latin/vocabulary/latin_vocabulary_loader.dart';
import '../../services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import '../../services/learning_service.dart';
import '../../services/quiz_sound_settings.dart';
import '../../widgets/sound_volume_button.dart';
import '../../services/streak/streak_track.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../widgets/statistics_widgets.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/settings_selection.dart';
import '../../utils/word_type_labels.dart';
import '../../widgets/self_assessment.dart';
import '../../widgets/trainer_widgets.dart';
import 'latin_vocabulary_answer_view.dart';

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

  Map<String, LearningCard> cards = {};

  LatinVocabularyEntry? current;

  /// Zählt die gestellten Fragen: Jede Frage bekommt eine eigene Abfrage,
  /// auch wenn dieselbe Vokabel erneut gewählt wird.
  int questionNumber = 0;

  bool loading = true;

  LatinVocabularySettings settings = const LatinVocabularySettings();

  /// Ausgewählte Lektionen.
  List<int> enabledLessons = [];

  List<String> enabledTypes = List.of(LatinVocabularySettings.allTypes);

  static const List<String> allTypes = LatinVocabularySettings.allTypes;

  // Gesetzt, wenn Vokabeln, Einstellungen oder Lernstand nicht ladbar waren.
  String? loadError;

  String? uid;

  // Eintippen oder Selbsteinschätzung („Im Kopf“).
  AnswerMethod method = AnswerMethod.typing;

  @override
  void initState() {
    super.initState();

    load();
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

      settings = results[0] as LatinVocabularySettings;
      enabledTypes = List.of(settings.enabledTypes);

      entries = results[1] as List<LatinVocabularyEntry>;

      // Gespeichert ist nur die Abwahl: Neu ergänzte Lektionen sind aktiv.
      enabledLessons = [
        for (final lesson in _availableLessons())
          if (!settings.disabledLessons.contains(lesson)) lesson,
      ];

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

  bool _matchesFilters(LatinVocabularyEntry entry) {
    return enabledLessons.contains(entry.lesson) &&
        enabledTypes.contains(entry.type) &&
        (!settings.onlyDifficult ||
            isDifficultCard(cards[entry.id.toString()]));
  }

  void nextQuestion() {
    final availableEntries = entries.where(_matchesFilters).toList();

    if (availableEntries.isEmpty) {
      setState(() => current = null);

      return;
    }

    // Die Filter stehen fest; gewichtet wird nur innerhalb des Pools.
    final next = selector.select(
      candidates: availableEntries,
      idOf: (entry) => entry.id.toString(),
      cards: cards,
      baseWeightOf: (entry) => entry.weight,
    )!;

    setState(() {
      current = next;
      questionNumber++;
    });
  }

  void setMethod(AnswerMethod value) {
    if (value == method) {
      return;
    }

    setState(() {
      method = value;
    });

    AnswerMethodPreference.save(AnswerMethodPreference.latinVocabulary, value);
  }

  LearningCard _cardOf(LatinVocabularyEntry entry) {
    final id = entry.id.toString();

    return cards[id] ?? LearningCard(id: id);
  }

  /// Verbucht eine Antwort im Lernstand – gleich, ob die Eingabe geprüft
  /// oder das eigene Wissen eingeschätzt wurde – und meldet Sound,
  /// Tagesstatistik und Streak.
  void _evaluated(
    LatinVocabularyEntry entry,
    bool correct, {
    required bool firstEvaluation,
  }) {
    final card = _cardOf(entry);

    selector.algorithm.answer(card, correct);

    cards[card.id] = card;

    // Nicht auf den Server warten: Firestore bestätigt offline erst später,
    // die Auswertung soll trotzdem sofort erscheinen.
    learningService.saveLatinCard(uid, card).catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });

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

  Future<void> _saveMnemonic(
    LatinVocabularyEntry entry,
    String? mnemonic,
  ) async {
    final card = _cardOf(entry);

    card.mnemonic = mnemonic;

    cards[card.id] = card;

    await learningService.saveLatinCard(uid, card);

    if (mounted) {
      setState(() {});
    }
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
                      if (enabledLessons.isEmpty || enabledTypes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Mindestens eine Lektion und eine Wortart müssen ausgewählt sein.",
                            ),
                          ),
                        );

                        return;
                      }

                      settings = settings.copyWith(
                        disabledLessons: [
                          for (final lesson in _availableLessons())
                            if (!enabledLessons.contains(lesson)) lesson,
                        ],
                        enabledTypes: List.of(enabledTypes),
                      );

                      await settingsService.save(uid, settings);

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(context);

                      setState(() {});

                      final entry = current;

                      if (entry == null || !_matchesFilters(entry)) {
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
                      _buildLessonSelection(setDialogState),

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

                      LatinQuerySettingsSection(
                        settings: settings,
                        onChanged: (value) {
                          setDialogState(() => settings = value);
                        },
                      ),

                      OnlyDifficultSettingsSection(
                        noun: "Vokabeln",
                        value: settings.onlyDifficult,
                        onChanged: (v) {
                          setDialogState(
                            () =>
                                settings = settings.copyWith(onlyDifficult: v),
                          );
                        },
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

  /// Lektionsauswahl wie im Altgriechisch-Trainer.
  Widget _buildLessonSelection(StateSetter setDialogState) {
    final available = _availableLessons();

    return MultiSelectSection<int>(
      title: "Lektionen",
      hint:
          "Abgefragt werden nur Vokabeln aus den ausgewählten Lektionen. "
          "Mehrere Lektionen können gleichzeitig ausgewählt sein.",
      options: available,
      isSelected: enabledLessons.contains,
      labelOf: (lesson) => "Lektion $lesson",
      emptyError: "Mindestens eine Lektion muss ausgewählt sein.",
      onToggleAll: () {
        setDialogState(() {
          enabledLessons = enabledLessons.length == available.length
              ? []
              : List.of(available);
        });
      },
      onChanged: (lesson, value) {
        setDialogState(() {
          if (value) {
            if (!enabledLessons.contains(lesson)) {
              enabledLessons.add(lesson);
            }
          } else {
            enabledLessons.remove(lesson);
          }
        });
      },
    );
  }

  List<int> _availableLessons() {
    return entries.map((entry) => entry.lesson).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entry = current;

    final appBar = AppBar(
      title: const Text("Latein – Vokabeltrainer"),
      actions: [
        StatisticsButton(uid: uid, trainer: StatisticsTrainer.latinVocabulary),
        const SoundVolumeButton(),
        IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
      ],
    );

    if (entry == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text(
            loadError ??
                (settings.onlyDifficult
                    ? onlyDifficultEmptyMessage("Vokabeln")
                    : "Mit den aktuellen Filtern sind keine Vokabeln "
                          "verfügbar."),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,

      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LatinVocabularyAnswerView(
                key: ValueKey("question-$questionNumber"),
                entry: entry,
                settings: settings,
                method: method,
                onMethodChanged: setMethod,
                onEvaluated: (correct, {required firstEvaluation}) =>
                    _evaluated(
                      entry,
                      correct,
                      firstEvaluation: firstEvaluation,
                    ),
                onNext: nextQuestion,
                mnemonic: _cardOf(entry).mnemonic,
                onSaveMnemonic: (mnemonic) => _saveMnemonic(entry, mnemonic),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
