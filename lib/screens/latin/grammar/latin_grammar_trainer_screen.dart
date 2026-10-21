import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../algorithms/grammar_learning.dart';
import '../../../info/app_info.dart';
import '../../../services/latin/grammar/latin_grammar_answer_check.dart';
import '../../../services/latin/grammar/latin_grammar_store.dart';
import '../../../services/latin/grammar/latin_grammar_trainer.dart';
import '../../../services/latin/grammar/latin_grammar_words.dart';
import '../../../services/latin/grammar/latin_morphology.dart';
import '../../../services/latin/vocabulary/latin_vocabulary_loader.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../services/quiz_sound_settings.dart';
import '../../../services/statistics/learning_statistics.dart';
import '../../../services/streak/streak_track.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/answer_feedback_badge.dart';
import '../../../widgets/info_report.dart';
import '../../../widgets/settings_access.dart';
import '../../../widgets/settings_selection.dart';
import '../../../widgets/sound_volume_button.dart';
import '../../../widgets/statistics_widgets.dart';
import '../../../widgets/trainer_widgets.dart';

/// Grammatiktrainer Latein: Formen bestimmen, Präpositionen und
/// Satzkonstruktionen erkennen. Aufbau wie der Altgriechisch-Trainer
/// (Auswahl nach Lektionen), aber mit eigenen Formen, eigener
/// Antwortprüfung und eigenem Lernstand.
class LatinGrammarTrainerScreen extends StatefulWidget {
  /// Nur für Tests: Speicher (sonst nach Anmeldung) und Zufall.
  final LatinGrammarStore? store;
  final Random? random;

  /// Nur für Tests: Vokabelliste (sonst aus den Assets). Aus ihr stammen
  /// die Lektionen der Wörter.
  final Future<List<LatinVocabularyEntry>>? vocabulary;

  const LatinGrammarTrainerScreen({
    super.key,
    this.store,
    this.random,
    this.vocabulary,
  });

  @override
  State<LatinGrammarTrainerScreen> createState() =>
      _LatinGrammarTrainerScreenState();
}

class _LatinGrammarTrainerScreenState extends State<LatinGrammarTrainerScreen> {
  String? uid;
  late final LatinGrammarStore store;

  bool loading = true;
  String? loadError;

  LatinGrammarSettings settings = const LatinGrammarSettings();
  Map<String, LatinTopicProgress> topics = {};

  late GrammarLearning learning;
  late LatinGrammarTaskGenerator generator;

  /// Lektion je Vokabel-ID und die Lektionen der Vokabelliste.
  Map<int, int> lessonOf = {};
  List<int> lessons = [];

  LatinGrammarTask? task;
  bool answered = false;
  bool correct = false;

  // Eingaben beim Bestimmen
  String? selectedCase;
  String? selectedNumber;
  String? selectedGender;
  String? selectedMood;
  String? selectedTense;
  String? selectedVoice;
  String? selectedPerson;
  String? selectedChoice;

  final TextEditingController lemmaController = TextEditingController();
  final FocusNode lemmaFocusNode = FocusNode();
  final FocusNode keyboardFocusNode = FocusNode();

  // Ergebnisse
  IdentifyResult<Object>? identifyResult;
  bool? lemmaCorrect;

  @override
  void initState() {
    super.initState();

    if (widget.store != null) {
      store = widget.store!;
    } else {
      // uid == null: Gastmodus, gespeichert wird dann lokal.
      uid = FirebaseAuth.instance.currentUser?.uid;
      store = LatinGrammarStore.forUser(uid);
    }

    _load();
  }

  @override
  void dispose() {
    lemmaController.dispose();
    lemmaFocusNode.dispose();
    keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loadedSettings = await store.loadSettings();
      final progress = await store.load();
      final vocabulary =
          await (widget.vocabulary ?? LatinVocabularyLoader.load());

      if (!mounted) return;

      settings = loadedSettings;
      topics = Map.of(progress.topics);
      lessonOf = {for (final entry in vocabulary) entry.id: entry.lesson};
      lessons = lessonOf.values.toSet().toList()..sort();
      learning = GrammarLearning(
        cards: Map.of(progress.cards),
        random: widget.random,
      );
    } catch (error) {
      loadError = "Der Lernstand konnte nicht geladen werden.";
      learning = GrammarLearning(random: widget.random);
    }

    generator = LatinGrammarTaskGenerator(
      learning: learning,
      random: widget.random,
      lessonOf: lessonOf,
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    nextTask();
  }

  // ==========================
  // ABLAUF
  // ==========================

  void nextTask() {
    setState(() {
      task = generator.next(settings);
      answered = false;
      correct = false;

      selectedCase = null;
      selectedNumber = null;
      selectedGender = null;
      selectedMood = null;
      selectedTense = null;
      selectedVoice = null;
      selectedPerson = null;
      selectedChoice = null;

      lemmaController.clear();

      identifyResult = null;
      lemmaCorrect = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      switch (task) {
        case NominalIdentifyTask() || VerbIdentifyTask() when settings.askLemma:
          lemmaFocusNode.requestFocus();
        default:
          keyboardFocusNode.requestFocus();
      }
    });
  }

  /// Enter: prüfen bzw. weiter.
  void primaryAction() {
    if (task == null) return;

    if (answered) {
      nextTask();
    } else {
      check();
    }
  }

  void _missingInput(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void check() {
    final task = this.task;

    if (task == null || answered) return;

    var fields = <String, bool>{};
    bool ok;

    switch (task) {
      case NominalIdentifyTask():
        if (selectedCase == null ||
            selectedNumber == null ||
            (task.askGender && selectedGender == null)) {
          _missingInput("Bitte alle Merkmale auswählen.");
          return;
        }

        final result = checkNominalIdentification(
          task,
          grammaticalCase: selectedCase,
          number: selectedNumber,
          gender: selectedGender,
        );

        identifyResult = IdentifyResult<Object>(
          correct: result.correct,
          fields: result.fields,
          reference: result.reference,
        );
        fields = Map.of(result.fields);
        ok = result.correct;

        if (settings.askLemma) {
          lemmaCorrect = lemmaMatches(lemmaController.text, task.lemmas);
          fields["lemma"] = lemmaCorrect!;
          ok = ok && lemmaCorrect!;
        }

      case VerbIdentifyTask():
        final needsPerson = selectedMood != LatinMoods.infinitive;

        if (selectedMood == null ||
            selectedTense == null ||
            selectedVoice == null ||
            (needsPerson && selectedPerson == null)) {
          _missingInput("Bitte alle Merkmale auswählen.");
          return;
        }

        final result = checkVerbIdentification(
          task,
          mood: selectedMood,
          tense: selectedTense,
          voice: selectedVoice,
          person: needsPerson ? selectedPerson : null,
        );

        identifyResult = IdentifyResult<Object>(
          correct: result.correct,
          fields: result.fields,
          reference: result.reference,
        );
        fields = Map.of(result.fields);
        ok = result.correct;

        if (settings.askLemma) {
          lemmaCorrect = lemmaMatches(
            lemmaController.text,
            verbLemmas(task.verb),
          );
          fields["lemma"] = lemmaCorrect!;
          ok = ok && lemmaCorrect!;
        }

      case ChoiceTask():
        if (selectedChoice == null) {
          _missingInput("Bitte eine Antwort auswählen.");
          return;
        }

        ok = selectedChoice == task.answer;
    }

    setState(() {
      answered = true;
      correct = ok;
    });

    _record(task, ok, fields);

    reportTrainerAnswer(
      context,
      uid: uid,
      correct: ok,
      firstEvaluation: true,
      sound: SoundModule.latinGrammar,
      trainer: StatisticsTrainer.latinGrammar,
      track: StreakTrack.latin,
      source: StreakSource.grammar,
    );

    keyboardFocusNode.requestFocus();
  }

  Future<void> _record(
    LatinGrammarTask task,
    bool ok,
    Map<String, bool> fields,
  ) async {
    final changed = learning.record(
      learningResults(task: task, correct: ok, fields: fields),
    );

    topics[task.topic] = (topics[task.topic] ?? const LatinTopicProgress())
        .record(ok, DateTime.now());

    try {
      await store.record(task.topic, ok, changed);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Der Lernstand konnte nicht gespeichert werden."),
        ),
      );
    }
  }

  Future<void> _reloadProgress() async {
    final progress = await store.load();

    if (!mounted) return;

    setState(() {
      topics = Map.of(progress.topics);
      learning.cards
        ..clear()
        ..addAll(progress.cards);
    });
  }

  // ==========================
  // EINSTELLUNGEN
  // ==========================

  void openSettings() {
    var draft = settings.copyWith(
      enabledTopics: List.of(settings.enabledTopics),
    );

    // Ausgewählte Lektionen; gespeichert wird die Abwahl.
    final enabledLessons = [
      for (final lesson in lessons)
        if (!settings.disabledLessons.contains(lesson)) lesson,
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void toggle(List<String> list, String id, bool value) {
              setDialogState(() {
                if (value) {
                  if (!list.contains(id)) list.add(id);
                } else {
                  list.remove(id);
                }
              });
            }

            return ModuleSettingsDialog(
              moduleLabel: "Grammatiktrainer",
              onProgressReset: _reloadProgress,
              title: Row(
                children: [
                  const Expanded(child: Text("Einstellungen")),
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: "Speichern",
                    onPressed: () async {
                      draft = draft.copyWith(
                        disabledLessons: [
                          for (final lesson in lessons)
                            if (!enabledLessons.contains(lesson)) lesson,
                        ],
                      );

                      final error =
                          draft.validate(lessons) ??
                          (generator.availableTopics(draft).isEmpty
                              ? "Mit dieser Auswahl gibt es keine Aufgaben. "
                                    "Adjektive kommen z. B. erst ab "
                                    "Lektion 10 vor."
                              : null);

                      if (error != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }

                      // Einstellungen in der Reihenfolge des Lehrgangs.
                      final saved = LatinGrammarSettings.fromMap(draft.toMap());

                      try {
                        await store.saveSettings(saved);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Die Einstellungen konnten nicht gespeichert "
                                "werden.",
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      if (!context.mounted) return;

                      Navigator.pop(context);

                      settings = saved;
                      nextTask();
                    },
                  ),
                ],
              ),
              moduleSettings: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MultiSelectSection<int>(
                      title: "Lektionen",
                      hint:
                          "Abgefragt werden nur Wörter aus den ausgewählten "
                          "Lektionen. Mehrere Lektionen können gleichzeitig "
                          "ausgewählt sein. Pronomen und Satzkonstruktionen "
                          "gehören zu keiner Lektion und werden nur über "
                          "die Themen ein- oder ausgeschaltet.",
                      options: lessons,
                      isSelected: enabledLessons.contains,
                      labelOf: (lesson) => "Lektion $lesson",
                      emptyError:
                          "Mindestens eine Lektion muss ausgewählt sein.",
                      onToggleAll: () {
                        setDialogState(() {
                          if (enabledLessons.length == lessons.length) {
                            enabledLessons.clear();
                          } else {
                            enabledLessons
                              ..clear()
                              ..addAll(lessons);
                          }
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
                    ),

                    MultiSelectSection<LatinTrainerTopic>(
                      title: "Themen",
                      hint:
                          "In der Reihenfolge des Lehrgangs. Voreingestellt "
                          "ist der Stoff der Lektionen 1–3.",
                      options: LatinTrainerTopics.all,
                      isSelected: (topic) =>
                          draft.enabledTopics.contains(topic.id),
                      labelOf: (topic) => topic.title,
                      emptyError: "Mindestens ein Thema muss ausgewählt sein.",
                      onToggleAll: () {
                        setDialogState(() {
                          if (draft.enabledTopics.length ==
                              LatinTrainerTopics.all.length) {
                            draft.enabledTopics.clear();
                          } else {
                            draft.enabledTopics
                              ..clear()
                              ..addAll(LatinTrainerTopics.ids);
                          }
                        });
                      },
                      onChanged: (topic, value) =>
                          toggle(draft.enabledTopics, topic.id, value),
                    ),

                    SettingsSection(
                      title: "Umfang und Schwierigkeit",
                      child: SettingsSwitchGroup(
                        children: [
                          SwitchListTile(
                            title: const Text("Grundform abfragen"),
                            subtitle: const Text("Beim Bestimmen"),
                            value: draft.askLemma,
                            onChanged: (value) => setDialogState(() {
                              draft = draft.copyWith(askLemma: value);
                            }),
                          ),
                          SwitchListTile(
                            title: const Text("Vokativ abfragen"),
                            value: draft.includeVocative,
                            onChanged: (value) => setDialogState(() {
                              draft = draft.copyWith(includeVocative: value);
                            }),
                          ),
                        ],
                      ),
                    ),

                    const SoundSettingsSection(
                      module: SoundModule.latinGrammar,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================
  // FORTSCHRITT
  // ==========================

  void openProgress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder: (context, controller) {
                return LatinGrammarProgressView(
                  controller: controller,
                  topics: topics,
                  learning: learning,
                  onResetTopic: (topic) async {
                    final confirmed = await _confirmTopicReset(topic);

                    if (!confirmed) return;

                    final ids = LatinGrammarTaskGenerator.cardsOfTopic(
                      topic.id,
                      learning.cards.keys,
                    );

                    try {
                      await store.resetTopic(topic.id, ids);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Das Thema konnte nicht zurückgesetzt werden.",
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    topics.remove(topic.id);
                    learning.cards.removeWhere((id, _) => ids.contains(id));

                    setSheetState(() {});
                    if (mounted) setState(() {});
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmTopicReset(LatinTrainerTopic topic) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("„${topic.title}“ zurücksetzen?"),
        content: const Text(
          "Gelöscht werden die Antworten zu diesem Thema und der Lernstand "
          "seiner Wörter. Der Lernstand einzelner Merkmale (z. B. Ablativ, "
          "2. Pl.) gilt themenübergreifend und bleibt erhalten. Alles "
          "zurücksetzen lässt sich in den Einstellungen unter „Allgemein“.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Zurücksetzen"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ==========================
  // OBERFLÄCHE
  // ==========================

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text("Latein – Grammatiktrainer"),
      actions: [
        IconButton(
          icon: const Icon(Icons.insights_rounded),
          tooltip: "Fortschritt",
          onPressed: loading ? null : openProgress,
        ),
        StatisticsButton(uid: uid, trainer: StatisticsTrainer.latinGrammar),
        const SoundVolumeButton(),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: "Einstellungen",
          onPressed: loading ? null : openSettings,
        ),
      ],
    );

    if (loading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final task = this.task;

    if (task == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              loadError ??
                  "Mit den aktuellen Einstellungen sind keine Aufgaben "
                      "verfügbar.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final topic = LatinTrainerTopics.byId(task.topic);

    return Scaffold(
      appBar: appBar,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): primaryAction,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): primaryAction,
        },
        child: Focus(
          focusNode: keyboardFocusNode,
          autofocus: true,
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loadError != null) ...[
                        Text(
                          loadError!,
                          style: TextStyle(color: context.colors.error),
                        ),
                        const SizedBox(height: 8),
                      ],

                      Text(
                        "${topic.title} · ${_kindLabel(task)}",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),

                      const SizedBox(height: 12),

                      ..._buildTask(task),

                      if (answered) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: AnswerFeedbackBadge(
                            correct: correct,
                            label: correct ? "Richtig" : "Falsch",
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeedback(task),
                      ],

                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: answered ? nextTask : check,
                        child: Text(answered ? "Weiter" : "Prüfen"),
                      ),

                      InfoReportFooter(
                        module: AppModules.latinGrammarTrainer,
                        reportDetails: () => {
                          "Thema": topic.title,
                          "Aufgabe": _reportDescription(task),
                          if (answered) "Eingabe": _inputDescription(task),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(LatinGrammarTask task) {
    return switch (task) {
      NominalIdentifyTask() || VerbIdentifyTask() => "Formen bestimmen",
      ChoiceTask() => "Auswahl",
    };
  }

  List<String> _translationsOf(NominalWordType type, String id) {
    switch (type) {
      case NominalWordType.noun:
        return LatinGrammarWords.nouns
            .firstWhere((n) => n.id == id)
            .translations;
      case NominalWordType.adjective:
        return LatinGrammarWords.adjectives
            .firstWhere((a) => a.id == id)
            .translations;
      case NominalWordType.pronoun:
        return LatinGrammarWords.pronouns
            .firstWhere((p) => p.id == id)
            .translations;
    }
  }

  Widget _bigForm(String text) {
    return SelectableText(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: context.colors.textSecondary),
      ),
    );
  }

  List<Widget> _buildTask(LatinGrammarTask task) {
    final fields = identifyResult?.fields;

    switch (task) {
      case NominalIdentifyTask():
        return [
          _bigForm(task.form),
          _hint(
            task.hint ??
                "Bedeutung: ${_translationsOf(task.wordType, task.wordId).join(", ")}",
          ),
          const SizedBox(height: 20),
          SingleSelectChips(
            label: "Kasus",
            options: task.cases,
            value: selectedCase,
            correct: fields?["case"],
            onChanged: answered
                ? null
                : (v) => setState(() => selectedCase = v),
          ),
          const SizedBox(height: 12),
          SingleSelectChips(
            label: "Numerus",
            options: LatinNumbers.all,
            value: selectedNumber,
            correct: fields?["number"],
            onChanged: answered
                ? null
                : (v) => setState(() => selectedNumber = v),
          ),
          if (task.askGender) ...[
            const SizedBox(height: 12),
            SingleSelectChips(
              label: "Genus",
              options: LatinGenders.all,
              value: selectedGender,
              correct: fields?["gender"],
              onChanged: answered
                  ? null
                  : (v) => setState(() => selectedGender = v),
            ),
          ],
          if (settings.askLemma) ...[const SizedBox(height: 16), _lemmaField()],
        ];

      case VerbIdentifyTask():
        final infinitive = selectedMood == LatinMoods.infinitive;

        return [
          _bigForm(task.form),
          _hint("Bedeutung: ${task.verb.translations.join(", ")}"),
          const SizedBox(height: 20),
          SingleSelectChips(
            label: "Modus",
            options: LatinMoods.all,
            value: selectedMood,
            correct: fields?["mood"],
            onChanged: answered
                ? null
                : (v) => setState(() {
                    selectedMood = v;
                    if (!_personsFor(v).contains(selectedPerson)) {
                      selectedPerson = null;
                    }
                  }),
          ),
          const SizedBox(height: 12),
          SingleSelectChips(
            label: "Tempus",
            options: LatinTenses.all,
            value: selectedTense,
            correct: fields?["tense"],
            onChanged: answered
                ? null
                : (v) => setState(() => selectedTense = v),
          ),
          const SizedBox(height: 12),
          SingleSelectChips(
            label: "Genus verbi",
            options: LatinVoices.all,
            value: selectedVoice,
            correct: fields?["voice"],
            onChanged: answered
                ? null
                : (v) => setState(() => selectedVoice = v),
          ),
          if (!infinitive) ...[
            const SizedBox(height: 12),
            SingleSelectChips(
              label: "Person",
              options: _personsFor(selectedMood),
              value: selectedPerson,
              correct: fields?["person"],
              onChanged: answered
                  ? null
                  : (v) => setState(() => selectedPerson = v),
            ),
          ],
          if (settings.askLemma) ...[const SizedBox(height: 16), _lemmaField()],
        ];

      case ChoiceTask():
        return [
          _bigForm(task.prompt),
          _hint(task.question),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in task.options)
                SelectionChip(
                  label: option,
                  selected:
                      selectedChoice == option ||
                      (answered && option == task.answer),
                  showCheckmark: false,
                  correct: !answered
                      ? null
                      : option == task.answer
                      ? true
                      : option == selectedChoice
                      ? false
                      : null,
                  onSelected: answered
                      ? null
                      : (_) => setState(() => selectedChoice = option),
                ),
            ],
          ),
        ];
    }
  }

  /// Wählbare Personen je Modus (Infinitiv: keine).
  static List<String> _personsFor(String? mood) {
    return switch (mood) {
      LatinMoods.infinitive => const [],
      LatinMoods.imperative => LatinPersons.imperative,
      _ => LatinPersons.all,
    };
  }

  Widget _lemmaField() {
    return TextField(
      controller: lemmaController,
      focusNode: lemmaFocusNode,
      enabled: !answered,
      onSubmitted: (_) => primaryAction(),
      decoration: InputDecoration(
        labelText: "Grundform",
        hintText: "z. B. dominus bzw. amāre",
        border: const OutlineInputBorder(),
        enabledBorder: answerResultBorder(context, lemmaCorrect),
        focusedBorder: answerResultBorder(context, lemmaCorrect),
        disabledBorder: answerResultBorder(context, lemmaCorrect),
      ),
    );
  }

  Widget _buildFeedback(LatinGrammarTask task) {
    final lines = <Widget>[];

    void line(String text, {bool strong = false}) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: strong ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    switch (task) {
      case NominalIdentifyTask():
        final reference = identifyResult!.reference as NominalAnalysis;
        line("${task.form}: ${reference.describe()}", strong: true);

        final others = [
          for (final a in task.analyses)
            if (a != reference) a.describe(),
        ];

        if (others.isNotEmpty) {
          line("Ebenso möglich: ${others.join("; ")}");
        }

        line("Grundform: ${task.dictionaryForm}");

      case VerbIdentifyTask():
        final reference = identifyResult!.reference as VerbAnalysis;
        line("${task.form}: ${reference.describe()}", strong: true);

        final others = [
          for (final a in task.analyses)
            if (a != reference) a.describe(),
        ];

        if (others.isNotEmpty) {
          line("Ebenso möglich: ${others.join("; ")}");
        }

        line("Grundform: ${task.verb.principalParts}");

      case ChoiceTask():
        line("Richtig: ${task.answer}", strong: true);

        if (task.translation != null) {
          line("Übersetzung: ${task.translation}");
        }
    }

    final explanation = switch (task) {
      NominalIdentifyTask(:final explanation) ||
      VerbIdentifyTask(:final explanation) ||
      ChoiceTask(:final explanation) => explanation,
    };

    if (explanation.isNotEmpty) {
      lines.add(const SizedBox(height: 4));
      lines.add(
        Text(
          explanation,
          style: TextStyle(fontSize: 15, color: context.colors.textSecondary),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines,
        ),
      ),
    );
  }

  String _reportDescription(LatinGrammarTask task) {
    return switch (task) {
      NominalIdentifyTask() => "${task.form} (${task.dictionaryForm})",
      VerbIdentifyTask() => "${task.form} (${task.verb.infinitive})",
      ChoiceTask() => task.prompt,
    };
  }

  String _inputDescription(LatinGrammarTask task) {
    return switch (task) {
      NominalIdentifyTask() => [
        ?selectedCase,
        ?selectedNumber,
        ?selectedGender,
        if (settings.askLemma) lemmaController.text,
      ].join(" "),
      VerbIdentifyTask() => [
        ?selectedPerson,
        ?selectedTense,
        ?selectedMood,
        ?selectedVoice,
        if (settings.askLemma) lemmaController.text,
      ].join(" "),
      ChoiceTask() => selectedChoice ?? "",
    };
  }
}

/// Fortschritt je Thema und die Merkmale mit dem größten Lernbedarf.
class LatinGrammarProgressView extends StatelessWidget {
  final ScrollController? controller;
  final Map<String, LatinTopicProgress> topics;
  final GrammarLearning learning;
  final Future<void> Function(LatinTrainerTopic topic) onResetTopic;

  const LatinGrammarProgressView({
    super.key,
    this.controller,
    required this.topics,
    required this.learning,
    required this.onResetTopic,
  });

  static const Map<String, String> _typeLabels = {
    "noun": "Substantive",
    "adjective": "Adjektive",
    "pronoun": "Pronomen",
    "verb": "Verben",
  };

  static const Map<String, String> _dimensionLabels = {
    "case": "Kasus",
    "number": "Numerus",
    "gender": "Genus",
    "mood": "Modus",
    "tense": "Tempus",
    "voice": "Genus verbi",
    "person": "Person",
  };

  /// Lesbare Bezeichnung einer Merkmalskarte („dim.noun.case.Ablativ“ →
  /// „Substantive – Kasus: Ablativ“); null für andere Karten.
  static String? dimensionLabel(String id) {
    final parts = id.split(".");

    if (parts.length != 4 || parts[0] != "dim") return null;

    final type = _typeLabels[parts[1]];
    final dimension = _dimensionLabels[parts[2]];

    if (type == null || dimension == null) return null;

    // Personen sind als „1-Sg“ gespeichert.
    final value = parts[2] == "person"
        ? "${parts[3].replaceFirst("-", ". ")}."
        : parts[3].replaceAll("-", " ");

    return "$type – $dimension: $value";
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final weak = [
      for (final card in learning.cards.values)
        if (dimensionLabel(card.id) != null && card.difficulty > 5)
          (card.id, learning.need(card.id)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text("Fortschritt", style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "Richtige Antworten je Thema. Schwache Themen und Merkmale kommen "
          "im Trainer häufiger dran.",
          style: TextStyle(color: context.colors.textSecondary),
        ),
        const SizedBox(height: 12),

        for (final topic in LatinTrainerTopics.all)
          _TopicProgressTile(
            topic: topic,
            progress: topics[topic.id] ?? const LatinTopicProgress(),
            onReset: () => onResetTopic(topic),
          ),

        const SizedBox(height: 16),
        Text("Am meisten zu üben", style: textTheme.titleMedium),
        const SizedBox(height: 6),

        if (weak.isEmpty)
          Text(
            "Noch keine Schwachstellen erkannt.",
            style: TextStyle(color: context.colors.textSecondary),
          )
        else
          for (final (id, _) in weak.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text("• ${dimensionLabel(id)}"),
            ),
      ],
    );
  }
}

class _TopicProgressTile extends StatelessWidget {
  final LatinTrainerTopic topic;
  final LatinTopicProgress progress;
  final VoidCallback onReset;

  const _TopicProgressTile({
    required this.topic,
    required this.progress,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final rate = progress.rate;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: rate ?? 0,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rate == null
                        ? "Noch nicht geübt"
                        : "${progress.correct} von ${progress.attempts} "
                              "richtig (${(rate * 100).round()} %)",
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: "Thema zurücksetzen",
              onPressed: progress.attempts == 0 ? null : onReset,
            ),
          ],
        ),
      ),
    );
  }
}
