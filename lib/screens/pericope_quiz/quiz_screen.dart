import 'package:flutter/material.dart';

import '../../services/learning_service.dart';
import '../../services/settings_service.dart';

import '../../models/greek/perikope.dart';
import '../../models/greek/vocabulary/learning_card.dart';

import '../../quiz/bible_structure.dart';
import '../../quiz/pericope_reference.dart';
import '../../quiz/quiz_engine.dart';
import '../../quiz/quiz_question.dart';

import '../../services/quiz_sound_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sound_volume_button.dart';
import '../../widgets/streak_widgets.dart';
import '../../services/streak/streak_track.dart';
import '../../services/statistics/learning_statistics.dart';
import '../../widgets/statistics_widgets.dart';
import '../../info/app_info.dart';
import '../../widgets/info_report.dart';

import '../../utils/bible_reference_validator.dart';

import '../../settings/quiz_settings.dart';

import '../../widgets/self_assessment.dart';
import '../../widgets/trainer_widgets.dart';

import 'quick_entry_panel.dart';
import 'quiz_settings_sheet.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizScreen extends StatefulWidget {
  final List<Perikope> perikopen;
  // null = Gastmodus (lokale Speicherung).
  final String? uid;

  // Nur für Tests ersetzbar; standardmäßig die echten Dienste.
  final SettingsService? settingsService;
  final LearningService? learningService;

  const QuizScreen({
    super.key,
    required this.perikopen,
    required this.uid,
    this.settingsService,
    this.learningService,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late QuizEngine engine;

  late final SettingsService service =
      widget.settingsService ?? SettingsService();

  late final LearningService learningService =
      widget.learningService ?? LearningService();

  final List<TextEditingController> controllers = [TextEditingController()];

  final List<String?> validationHints = [null];

  String? feedback;

  bool checked = false;

  late QuizSettings settings;

  bool loaded = false;

  final Map<String, LearningCard> learningCards = {};

  final TextEditingController mnemonicController = TextEditingController();

  bool editingMnemonic = false;

  List<QuizQuestion> questions = [];

  final List<bool?> inputResults = [null];

  final FocusNode firstInputFocusNode = FocusNode();
  final FocusNode quizFocusNode = FocusNode();

  static const String _quickEntryKey = 'pericope_quiz_quick_entry';

  // Schnelleingabe: schreibt in das Eingabefeld [activeInput].
  bool quickEntry = false;

  int activeInput = 0;

  // Eintippen oder Selbsteinschätzung („Im Kopf“).
  AnswerMethod method = AnswerMethod.typing;

  // Selbsteinschätzung: Stellen der aktuellen Frage aufgedeckt.
  bool revealed = false;

  final GlobalKey<SelfAssessmentPanelState> _assessmentKey = GlobalKey();

  late BibleStructure structure;

  final List<String> recentBooks = [];

  // Hält den Zustand des Inhalts, wenn er zwischen scrollbarer und fester
  // Anordnung wechselt.
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _init();
  }

  Future<void> _init() async {
    final books = await service.loadBooks(widget.uid);

    final cards = await learningService.loadPerikopeCards(widget.uid);

    learningCards.clear();
    learningCards.addAll(cards);

    final prefs = await SharedPreferences.getInstance();

    quickEntry = prefs.getBool(_quickEntryKey) ?? false;

    method = await AnswerMethodPreference.load(
      AnswerMethodPreference.pericopeQuiz,
    );

    settings = QuizSettings(
      selectedBooks: books.isEmpty ? {...QuizSettings.allBooks} : books,
    );

    if (!mounted) return;

    _prepareQuestions();

    _rebuildEngine();

    setState(() {
      loaded = true;
    });
  }

  void _prepareQuestions() {
    questions = QuizQuestion.fromPerikopen(widget.perikopen);

    structure = BibleStructure.fromPerikopen(widget.perikopen);
  }

  List<QuizQuestion> _filtered() {
    return questions
        .where((q) {
          return q.variants.any(
            (p) => p.required && settings.selectedBooks.contains(p.book),
          );
        })
        .map((q) {
          return QuizQuestion(
            id: q.id,
            variants: q.variants
                .where(
                  (p) => p.required && settings.selectedBooks.contains(p.book),
                )
                .toList(),
          );
        })
        .toList();
  }

  void _rebuildEngine() {
    engine = QuizEngine(
      _filtered(),
      learningCards,
      uid: widget.uid,
      learningService: learningService,
      perikopen: true,
    );

    engine.start();
  }

  QuizQuestion? get current => engine.current;

  LearningCard? get currentCard {
    final c = current;
    if (c == null) return null;
    return learningCards[c.id];
  }

  String? get currentMnemonic => currentCard?.mnemonic;

  void addInput() {
    if (controllers.length >= 4) {
      return;
    }

    setState(() {
      controllers.add(TextEditingController());
      validationHints.add(null);
      inputResults.add(null);

      activeInput = controllers.length - 1;
    });
  }

  void removeInput(int index) {
    if (controllers.length <= 1) {
      return;
    }

    setState(() {
      controllers[index].dispose();

      controllers.removeAt(index);
      validationHints.removeAt(index);
      inputResults.removeAt(index);

      if (activeInput > index || activeInput >= controllers.length) {
        activeInput--;
      }
    });
  }

  bool get _touchPlatform {
    final platform = Theme.of(context).platform;

    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  Future<void> _toggleQuickEntry() async {
    setState(() {
      quickEntry = !quickEntry;
    });

    // Auf Touch-Geräten die Bildschirmtastatur schließen, damit die
    // Schnelleingabe Platz hat.
    if (quickEntry && _touchPlatform) {
      quizFocusNode.requestFocus();
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_quickEntryKey, quickEntry);
  }

  /// In der Schnelleingabe auswählbare Bücher: die in den Einstellungen
  /// aktivierten, soweit Perikopen dazu geladen sind.
  List<String> _quickBooks() {
    return QuizSettings.allBooks
        .where(
          (b) => settings.selectedBooks.contains(b) && structure.hasBook(b),
        )
        .toList();
  }

  /// Inhalt des aktiven Eingabefelds als Auswahl der Schnelleingabe. Was
  /// sich dort nicht auswählen ließe, zählt als leer.
  PericopeReference _quickValue(List<String> books) {
    final parsed = PericopeReference.parse(controllers[activeInput].text);

    if (parsed == null || !structure.allows(parsed, books)) {
      return PericopeReference.empty;
    }

    return parsed;
  }

  void _applyQuickReference(PericopeReference reference) {
    if (current == null || checked) {
      return;
    }

    final text = reference.text;

    controllers[activeInput].value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    final book = reference.book;

    if (book != null) {
      recentBooks
        ..remove(book)
        ..insert(0, book);

      if (recentBooks.length > 4) {
        recentBooks.removeLast();
      }
    }

    // Die Auswahl kann nur gültige Stellen ergeben, Zwischenschritte sind
    // noch kein Formatfehler.
    setState(() {
      validationHints[activeInput] = null;
    });
  }

  String _reference(Perikope p) {
    return PericopeReference.formatRange(
      precision: p.precision,
      startChapter: p.startChapter,
      startVerse: p.startVerse,
      endChapter: p.endChapter,
      endVerse: p.endVerse,
    );
  }

  String _fullAnswer(Perikope p) {
    return "${p.book} ${_reference(p)}";
  }

  void validateInput(int index, String value) {
    final c = current;

    if (c == null) {
      return;
    }

    final text = value.trim();

    if (text.isEmpty) {
      setState(() {
        validationHints[index] = null;
      });

      return;
    }

    final bookError = BibleReferenceValidator.validateBook(text);

    if (bookError != null) {
      setState(() {
        validationHints[index] = "✘ $bookError";
      });

      return;
    }

    final validSyntax = c.variants.any(
      (p) => BibleReferenceValidator.isValid(text, p.precision),
    );

    setState(() {
      validationHints[index] = validSyntax ? null : "✘ Ungültiges Format";
    });
  }

  Set<String> _expectedAnswers() {
    final c = current;

    if (c == null) {
      return {};
    }

    return c.variants.map(_fullAnswer).toSet();
  }

  Set<String> _userAnswers() {
    final result = <String>{};

    for (final controller in controllers) {
      final text = controller.text.trim();

      if (text.isNotEmpty) {
        result.add(text);
      }
    }

    return result;
  }

  /// Kontext für „Fehler melden“. Die hinterlegte Stelle erst nach dem
  /// Prüfen bzw. Aufdecken, damit das Formular die Lösung nicht verrät.
  Map<String, String> _reportDetails() {
    final c = current;

    if (c == null) {
      return {};
    }

    return {
      "Perikope": "${c.title} (${c.id})",
      if (checked || revealed)
        "Hinterlegte Stelle": _expectedAnswers().join("; "),
      if (method == AnswerMethod.typing) "Eingabe": _userAnswers().join("; "),
    };
  }

  String _normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _setMethod(AnswerMethod value) {
    if (checked || revealed || value == method) {
      return;
    }

    setState(() {
      method = value;
    });

    // Im Kopf wird nichts getippt: Bildschirmtastatur schließen; Enter
    // erreicht das Quiz weiterhin.
    if (value == AnswerMethod.recall) {
      quizFocusNode.requestFocus();
    } else if (!(quickEntry && _touchPlatform)) {
      firstInputFocusNode.requestFocus();
    }

    AnswerMethodPreference.save(AnswerMethodPreference.pericopeQuiz, value);
  }

  /// Selbsteinschätzung nach dem Aufdecken: zählt wie eine richtige bzw.
  /// falsche Antwort und führt direkt zur nächsten Frage.
  void _assess(SelfAssessment assessment) {
    // Je aufgedeckter Lösung nur eine Bewertung.
    if (current == null || !revealed || checked) {
      return;
    }

    revealed = false;

    // Verbucht den Lernstand sofort; gespeichert wird im Hintergrund.
    engine.answer(assessment.knew);

    _reportAnswer(assessment.knew, firstEvaluation: true);

    _showNext();
  }

  /// Sound, Tagesstatistik und Streak einer bewerteten Antwort – für
  /// geprüfte Eingaben und Selbsteinschätzungen dieselbe Zählstelle.
  void _reportAnswer(bool correct, {required bool firstEvaluation}) {
    reportTrainerAnswer(
      context,
      uid: widget.uid,
      correct: correct,
      firstEvaluation: firstEvaluation,
      sound: SoundModule.pericopeQuiz,
      trainer: StatisticsTrainer.perikopenQuiz,
      track: StreakTrack.perikope,
      source: StreakSource.perikopenQuiz,
    );
  }

  Future<void> handleButton() async {
    final c = current;

    if (c == null) {
      return;
    }

    // Im Kopf gibt es keine Eingabe zu prüfen.
    if (!checked && method == AnswerMethod.recall) {
      return;
    }

    if (!checked) {
      final expected = _expectedAnswers();

      final given = _userAnswers().map(_normalize).toSet();

      final normalizedExpected = expected.map(_normalize).toSet();

      final correct =
          given.length == normalizedExpected.length &&
          given.containsAll(normalizedExpected);

      await engine.answer(correct);

      if (!mounted) return;

      // Streak nur einmal je Frage zählen (auch bei doppeltem Enter).
      final firstEvaluation = !checked;

      final missing = normalizedExpected.difference(given);

      // Leere Eingabefelder entfernen
      for (int i = controllers.length - 1; i >= 0; i--) {
        if (controllers[i].text.trim().isEmpty && controllers.length > 1) {
          controllers[i].dispose();
          controllers.removeAt(i);
          validationHints.removeAt(i);
          inputResults.removeAt(i);
        }
      }

      final results = controllers.map((controller) {
        final answer = _normalize(controller.text);

        return normalizedExpected.contains(answer);
      }).toList();

      setState(() {
        checked = true;

        activeInput = 0;

        inputResults.clear();
        inputResults.addAll(results);

        final buffer = StringBuffer();

        if (correct) {
          buffer.writeln("✔ Richtig\n");
        } else {
          buffer.writeln("✘ Falsch\n");
        }

        buffer.writeln("Deine Eingaben:");

        for (final answer in given) {
          if (normalizedExpected.contains(answer)) {
            buffer.writeln("✓ $answer");
          } else {
            buffer.writeln("✗ $answer");
          }
        }

        if (missing.isNotEmpty) {
          buffer.writeln("\nFehlt noch:");

          for (final answer in missing) {
            buffer.writeln("• $answer");
          }
        }

        feedback = buffer.toString();
      });

      _reportAnswer(correct, firstEvaluation: firstEvaluation);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          quizFocusNode.requestFocus();
        }
      });

      return;
    }

    _showNext();
  }

  void _showNext() {
    setState(() {
      engine.next();

      for (final controller in controllers) {
        controller.clear();
      }

      checked = false;
      revealed = false;

      activeInput = 0;

      feedback = null;

      editingMnemonic = false;
      mnemonicController.clear();

      inputResults.clear();
      inputResults.addAll(List.filled(controllers.length, null));

      for (int i = 0; i < validationHints.length; i++) {
        validationHints[i] = null;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (method == AnswerMethod.recall) {
        quizFocusNode.requestFocus();
      } else if (!(quickEntry && _touchPlatform)) {
        // Mit Schnelleingabe auf Touch-Geräten nicht die Tastatur öffnen.
        firstInputFocusNode.requestFocus();
      }
    });
  }

  Future<void> _openSettings() async {
    final result = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuizSettingsSheet(
        selected: settings.selectedBooks,
        onChanged: (_) {},
      ),
    );

    if (result == null) {
      return;
    }

    final oldCurrent = current;

    setState(() {
      settings.selectedBooks = result;

      final newItems = _filtered();

      final stillAvailable =
          oldCurrent != null && newItems.any((q) => q.id == oldCurrent.id);

      engine.updateItems(newItems);

      if (!stillAvailable) {
        engine.next();

        for (final controller in controllers) {
          controller.clear();
        }

        checked = false;
        revealed = false;
        feedback = null;
        activeInput = 0;
      } else if (!checked) {
        // Die laufende Frage erwartet keine Stellen aus abgewählten Büchern
        // mehr; solche Eingaben nicht stehen lassen.
        for (int i = 0; i < controllers.length; i++) {
          final book = PericopeReference.parse(controllers[i].text)?.book;

          if (QuizSettings.allBooks.contains(book) && !result.contains(book)) {
            controllers[i].clear();
            validationHints[i] = null;
          }
        }
      }
    });

    await service.saveBooks(widget.uid, settings.selectedBooks);
  }

  /// Die erwarteten Stellen für die Selbsteinschätzung.
  Widget _buildSolution() {
    return Column(
      children: [
        for (final answer in _expectedAnswers())
          SelectableText(
            answer,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    quizFocusNode.dispose();
    firstInputFocusNode.dispose();
    mnemonicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final c = current;

    final recall = method == AnswerMethod.recall;

    final showQuickEntry = quickEntry && !checked && !recall;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz"),
        actions: [
          StreakAppBarButton(uid: widget.uid, track: StreakTrack.perikope),
          StatisticsButton(
            uid: widget.uid,
            trainer: StatisticsTrainer.perikopenQuiz,
          ),
          const SoundVolumeButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),

      body: Focus(
        focusNode: quizFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (recall && !checked) {
              return _assessmentKey.currentState?.handleEnter() ?? false
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            }

            // Mit Schnelleingabe gibt Enter auch ohne Fokus im Textfeld ab.
            if (checked ||
                (quickEntry &&
                    node.hasPrimaryFocus &&
                    _userAnswers().isNotEmpty)) {
              handleButton();
              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: c == null
              ? const Center(child: Text("Keine Perikopen verfügbar"))
              : _QuizContent(
                  // Die Schnelleingabe füllt den freien Platz und scrollt
                  // selbst; ohne sie scrollt der ganze Inhalt.
                  scrollable: !showQuickEntry,
                  columnKey: _contentKey,

                  children: [
                    Center(
                      child: SelectableText(
                        c.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          c.variants.first.precision == "chapter"
                              ? "Kapitelgenau"
                              : "Versgenau",
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    AnswerMethodSelector(
                      method: method,
                      onChanged: checked || revealed ? null : _setMethod,
                    ),

                    const SizedBox(height: 16),

                    if (recall)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: SelfAssessmentPanel(
                          key: _assessmentKey,
                          revealed: revealed,
                          onReveal: () => setState(() => revealed = true),
                          onAssess: _assess,
                          solutionBuilder: (_) => _buildSolution(),
                          hint: c.variants.length > 1
                              ? "Rufe alle ${c.variants.length} Stellen im "
                                    "Kopf ab und decke dann die Lösung auf."
                              : "Rufe die Stelle im Kopf ab und decke dann "
                                    "die Lösung auf.",
                        ),
                      ),

                    if (!recall)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controllers.length,
                        itemBuilder: (_, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controllers[index],
                                      focusNode: index == 0
                                          ? firstInputFocusNode
                                          : null,

                                      mouseCursor: SystemMouseCursors.text,
                                      showCursor: true,

                                      enabled: !checked,

                                      onTap: () {
                                        if (activeInput != index) {
                                          setState(() {
                                            activeInput = index;
                                          });
                                        }
                                      },

                                      onChanged: (v) {
                                        activeInput = index;
                                        validateInput(index, v);
                                      },

                                      onSubmitted: (_) {
                                        if (!checked) {
                                          handleButton();
                                        }
                                      },

                                      decoration: InputDecoration(
                                        hintText:
                                            c.variants.first.precision ==
                                                "chapter"
                                            ? "z.B. Mk 8 oder Mk 8-10"
                                            : "z.B. Mk 1,9-11",

                                        errorText: validationHints[index],

                                        // Ziel der Schnelleingabe markieren.
                                        prefixIcon:
                                            quickEntry &&
                                                !checked &&
                                                controllers.length > 1 &&
                                                index == activeInput
                                            ? const Icon(Icons.bolt)
                                            : null,

                                        enabledBorder:
                                            checked &&
                                                inputResults[index] == true
                                            ? OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: context.colors.success,
                                                  width: 2,
                                                ),
                                              )
                                            : checked &&
                                                  inputResults[index] == false
                                            ? OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: context.colors.error,
                                                  width: 2,
                                                ),
                                              )
                                            : null,

                                        disabledBorder:
                                            checked &&
                                                inputResults[index] == true
                                            ? OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: context.colors.success,
                                                  width: 2,
                                                ),
                                              )
                                            : checked &&
                                                  inputResults[index] == false
                                            ? OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: context.colors.error,
                                                  width: 2,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),

                                  if (controllers.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle),
                                      onPressed: checked
                                          ? null
                                          : () => removeInput(index),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    if (!recall)
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            if (controllers.length < 4)
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text("Weitere Eingabe"),
                                onPressed: checked ? null : addInput,
                              ),

                            // Nach dem Prüfen ist die Eingabe gesperrt.
                            if (!checked)
                              Semantics(
                                toggled: quickEntry,
                                child: TextButton.icon(
                                  key: const ValueKey("quick-entry-toggle"),
                                  icon: Icon(
                                    quickEntry
                                        ? Icons.keyboard_arrow_up
                                        : Icons.bolt,
                                  ),
                                  label: const Text("Schnelleingabe"),
                                  style: quickEntry
                                      ? TextButton.styleFrom(
                                          backgroundColor:
                                              context.colors.surfaceMuted,
                                        )
                                      : null,
                                  onPressed: _toggleQuickEntry,
                                ),
                              ),
                          ],
                        ),
                      ),

                    if (showQuickEntry)
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: Builder(
                              builder: (_) {
                                final books = _quickBooks();

                                return QuickEntryPanel(
                                  books: books,
                                  recentBooks: recentBooks,
                                  structure: structure,
                                  precision: c.variants.first.precision,
                                  value: _quickValue(books),
                                  onChanged: _applyQuickReference,
                                  label: controllers.length > 1
                                      ? "Stelle ${activeInput + 1} von "
                                            "${controllers.length}"
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    if (!recall)
                      Center(
                        child: ElevatedButton(
                          onPressed: handleButton,
                          child: Text(checked ? "Weiter" : "Prüfen"),
                        ),
                      ),

                    if (feedback != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: feedback!.startsWith("✔")
                                    ? context.colors.successBackground
                                    : context.colors.errorBackground,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                                border: Border.all(
                                  color:
                                      (feedback!.startsWith("✔")
                                              ? context.colors.success
                                              : context.colors.error)
                                          .withValues(alpha: 0.35),
                                ),
                              ),
                              child: SelectableText(
                                feedback!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Die Merkhilfe gehört zur Lösung: nach dem Prüfen bzw.
                    // Aufdecken.
                    if (checked || revealed) ...[
                      const SizedBox(height: 16),

                      if (editingMnemonic)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: mnemonicController,
                                      decoration: const InputDecoration(
                                        labelText: "Merkhilfe",
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: null,
                                    ),

                                    const SizedBox(height: 10),

                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.save),
                                      label: const Text("Speichern"),
                                      onPressed: () async {
                                        final c = current;
                                        if (c == null) return;

                                        final card =
                                            learningCards[c.id] ??
                                            LearningCard(id: c.id);

                                        card.mnemonic =
                                            mnemonicController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : mnemonicController.text.trim();

                                        learningCards[c.id] = card;

                                        await learningService.savePerikopeCard(
                                          widget.uid,
                                          card,
                                        );

                                        if (!mounted) return;

                                        setState(() {
                                          editingMnemonic = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (currentMnemonic != null &&
                          currentMnemonic!.isNotEmpty)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            "Merkhilfe",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          SelectableText(
                                            currentMnemonic!,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),

                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        mnemonicController.text =
                                            currentMnemonic!;

                                        setState(() {
                                          editingMnemonic = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Merkhilfe hinzufügen"),
                          onPressed: () {
                            mnemonicController.clear();

                            setState(() {
                              editingMnemonic = true;
                            });
                          },
                        ),
                    ],

                    // Die Schnelleingabe braucht den ganzen freien Platz.
                    if (!showQuickEntry)
                      InfoReportFooter(
                        module: AppModules.pericopeQuiz,
                        reportDetails: _reportDetails,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Inhalt des Quiz als zentrierte Spalte, bei Bedarf scrollbar.
class _QuizContent extends StatelessWidget {
  final bool scrollable;
  final Key columnKey;
  final List<Widget> children;

  const _QuizContent({
    required this.scrollable,
    required this.columnKey,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      key: columnKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );

    return scrollable ? SingleChildScrollView(child: column) : column;
  }
}
