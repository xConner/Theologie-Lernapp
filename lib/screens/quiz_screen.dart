import 'dart:math';

import 'package:flutter/material.dart';

import '../services/learning_service.dart';
import '../services/settings_service.dart';

import '../models/perikope.dart';
import '../models/learning_card.dart';

import '../quiz/quiz_engine.dart';
import '../quiz/quiz_question.dart';

import '../utils/bible_reference_validator.dart';

import '../settings/quiz_settings.dart';

import 'quiz_settings_sheet.dart';

class QuizScreen extends StatefulWidget {
  final List<Perikope> perikopen;
  final String uid;

  const QuizScreen({super.key, required this.perikopen, required this.uid});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late QuizEngine engine;

  final SettingsService service = SettingsService();

  final LearningService learningService = LearningService();

  final List<TextEditingController> controllers = [TextEditingController()];

  final List<String?> validationHints = [null];

  String? feedback;

  bool checked = false;

  late QuizSettings settings;

  bool loaded = false;

  final Map<String, LearningCard> learningCards = {};

  List<QuizQuestion> questions = [];

  final List<bool?> inputResults = [null];

  @override
  void initState() {
    super.initState();

    _init();
  }

  Future<void> _init() async {
    final books = await service.loadBooks(widget.uid);

    settings = QuizSettings(
      selectedBooks: books.isEmpty ? {...QuizSettings.allBooks} : books,
    );

    _prepareQuestions();

    _rebuildEngine();

    setState(() {
      loaded = true;
    });
  }

  void _prepareQuestions() {
    questions = QuizQuestion.fromPerikopen(widget.perikopen);
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
    );

    engine.start();
  }

  QuizQuestion? get current => engine.current;

  void addInput() {
    if (controllers.length >= 4) {
      return;
    }

    setState(() {
      controllers.add(TextEditingController());
      validationHints.add(null);
      inputResults.add(null);
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
    });
  }

  String _reference(Perikope p) {
    if (p.precision == "chapter") {
      if (p.startChapter == p.endChapter) {
        return "${p.startChapter}";
      }

      return "${p.startChapter}-${p.endChapter}";
    }

    if (p.startChapter == p.endChapter) {
      if (p.startVerse == p.endVerse) {
        return "${p.startChapter},${p.startVerse}";
      }

      return "${p.startChapter},${p.startVerse}-${p.endVerse}";
    }

    return "${p.startChapter},${p.startVerse}-${p.endChapter},${p.endVerse}";
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

  String _normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> handleButton() async {
    final c = current;

    if (c == null) {
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

      final correctGiven = given.intersection(normalizedExpected);

      final missing = normalizedExpected.difference(given);

      final wrong = given.difference(normalizedExpected);

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

      return;
    }

    setState(() {
      engine.next();

      for (final controller in controllers) {
        controller.clear();
      }

      checked = false;

      feedback = null;

      inputResults.clear();
      inputResults.addAll(List.filled(controllers.length, null));

      for (int i = 0; i < validationHints.length; i++) {
        validationHints[i] = null;
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
        feedback = null;
      }
    });

    await service.saveBooks(widget.uid, settings.selectedBooks);
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final c = current;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: c == null
            ? const Center(child: Text("Keine Perikopen verfügbar"))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  Center(
                    child: Text(
                      c.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Center(
                    child: Text(
                      c.variants.first.precision == "chapter"
                          ? "Kapitelgenau"
                          : "Versgenau",
                    ),
                  ),

                  const SizedBox(height: 16),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controllers.length,
                    itemBuilder: (_, index) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers[index],

                              mouseCursor: SystemMouseCursors.text,
                              showCursor: true,

                              enabled: !checked,

                              onChanged: (v) => validateInput(index, v),

                              decoration: InputDecoration(
                                hintText:
                                    c.variants.first.precision == "chapter"
                                    ? "z.B. Mk 8 oder Mk 8-10"
                                    : "z.B. Mk 1,9-11",

                                errorText: validationHints[index],

                                enabledBorder:
                                    checked && inputResults[index] == true
                                    ? const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      )
                                    : checked && inputResults[index] == false
                                    ? const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                      )
                                    : null,

                                disabledBorder:
                                    checked && inputResults[index] == true
                                    ? const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      )
                                    : checked && inputResults[index] == false
                                    ? const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
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
                      );
                    },
                  ),

                  if (controllers.length < 4)
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Weitere Eingabe"),
                        onPressed: checked ? null : addInput,
                      ),
                    ),

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
                        child: Text(feedback!, textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
