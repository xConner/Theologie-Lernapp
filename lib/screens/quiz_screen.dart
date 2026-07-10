import 'package:flutter/material.dart';

import '../services/learning_service.dart';
import '../services/settings_service.dart';

import '../models/perikope.dart';
import '../models/learning_card.dart';

import '../quiz/quiz_engine.dart';

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

  final controller = TextEditingController();

  String? validationHint;

  String? feedback;

  bool checked = false;

  bool isValid = false;

  late QuizSettings settings;

  bool loaded = false;

  final Map<String, LearningCard> learningCards = {};

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

    _rebuildEngine();

    setState(() {
      loaded = true;
    });
  }

  List<Perikope> _filtered() {
    return widget.perikopen
        .where((p) => p.required)
        .where((p) => settings.selectedBooks.contains(p.book))
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

  Perikope? get current => engine.current;

  String _correctReference(Perikope p) {
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

  void validate(String input) {
    final text = input.trim();

    final c = current;

    if (c == null) return;

    if (text.isEmpty) {
      setState(() {
        validationHint = null;

        isValid = false;
      });

      return;
    }

    final bookError = BibleReferenceValidator.validateBook(text);

    if (bookError != null) {
      setState(() {
        validationHint = "✘ $bookError";

        isValid = false;
      });

      return;
    }

    final valid = BibleReferenceValidator.isValid(text, c.precision);

    setState(() {
      isValid = valid;

      validationHint = valid ? null : _formatHint(c);
    });
  }

  String _formatHint(Perikope c) {
    final base = c.precision == "chapter"
        ? "Kapitelgenauigkeit erforderlich."
        : "Versgenauigkeit erforderlich.";

    final example = c.precision == "chapter"
        ? "Beispiel: Mk 8 oder Mk 8-10"
        : "Beispiel: Mk 8,34 oder Mk 8,34-38";

    return "$base\n$example";
  }

  Future<void> handleButton() async {
    final c = current;

    if (c == null) return;

    if (!checked) {
      final parsed = controller.text.trim();

      final syntaxOk = BibleReferenceValidator.isValid(parsed, c.precision);

      final ok = syntaxOk && BibleReferenceValidator.matchesPerikope(parsed, c);

      await engine.answer(ok);

      setState(() {
        checked = true;

        if (ok) {
          feedback = "✔ Richtig";
        } else {
          feedback =
              "✘ Falsch\n"
              "Richtig wäre: ${c.book} ${_correctReference(c)}";
        }
      });

      return;
    }

    setState(() {
      engine.next();

      controller.clear();

      checked = false;

      feedback = null;

      validationHint = null;

      isValid = false;
    });
  }

  Future<void> _openSettings() async {
    final oldBooks = {...settings.selectedBooks};

    final result = await showDialog<Set<String>>(
      context: context,

      barrierDismissible: false,

      builder: (_) => QuizSettingsSheet(
        selected: settings.selectedBooks,

        onChanged: (v) {},
      ),
    );

    if (result == null) return;

    final oldCurrent = current;

    setState(() {
      settings.selectedBooks = result;

      final newItems = _filtered();

      final currentStillAllowed =
          oldCurrent != null && newItems.any((p) => p.id == oldCurrent.id);

      engine.updateItems(newItems);

      if (!currentStillAllowed) {
        engine.next();
        controller.clear();
        checked = false;
        feedback = null;
        validationHint = null;
        isValid = false;
      }
    });

    await service.saveBooks(widget.uid, settings.selectedBooks);
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
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    c.title,

                    style: const TextStyle(
                      fontSize: 20,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(c.precision == "chapter" ? "Kapitelgenau" : "Versgenau"),

                  const SizedBox(height: 12),

                  TextField(
                    controller: controller,

                    onChanged: validate,

                    decoration: InputDecoration(errorText: validationHint),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: handleButton,

                    child: Text(checked ? "Weiter" : "Prüfen"),
                  ),

                  if (feedback != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),

                      child: Text(feedback!),
                    ),
                ],
              ),
      ),
    );
  }
}
