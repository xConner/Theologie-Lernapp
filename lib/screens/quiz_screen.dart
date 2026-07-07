import 'package:flutter/material.dart';

import '../models/perikope.dart';
import '../quiz/simple_quiz_engine.dart';
import '../utils/bible_reference_validator.dart';
import '../settings/quiz_settings.dart';
import 'quiz_settings_sheet.dart';
import '../services/settings_service.dart';

class QuizScreen extends StatefulWidget {
  final List<Perikope> perikopen;
  final String uid;

  const QuizScreen({super.key, required this.perikopen, required this.uid});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late SimpleQuizEngine engine;
  final SettingsService service = SettingsService();

  final controller = TextEditingController();

  String? validationHint;
  String? feedback;

  bool checked = false;
  bool isValid = false;

  late QuizSettings settings;
  bool loaded = false;

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

    setState(() => loaded = true);
  }

  List<Perikope> _filtered() {
    return widget.perikopen
        .where((p) => p.required == true)
        .where((p) => settings.selectedBooks.contains(p.book))
        .toList();
  }

  void _rebuildEngine() {
    engine = SimpleQuizEngine(_filtered());
  }

  Perikope? get current => engine.current;

  // ---------------- VALIDIERUNG ----------------

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

    // 1. Buchprüfung
    final bookError = BibleReferenceValidator.validateBook(text);
    if (bookError != null) {
      setState(() {
        validationHint = "✘ $bookError";
        isValid = false;
      });
      return;
    }

    // 2. Genauigkeitsprüfung
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

  // ---------------- QUIZ FLOW ----------------

  void handleButton() {
    final c = current;
    if (c == null) return;

    if (!checked) {
      final parsed = controller.text.trim();
      final ok = BibleReferenceValidator.isValid(parsed, c.precision);

      setState(() {
        checked = true;
        feedback = ok ? "✔ Richtig" : "✘ Falsch";
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

  // ---------------- SETTINGS ----------------

  Future<void> _openSettings() async {
    final result = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false, // 🔴 WICHTIG: kein Klick außerhalb mehr
      builder: (_) => QuizSettingsSheet(
        selected: settings.selectedBooks,
        onChanged: (v) {},
      ),
    );

    if (result == null) return;

    setState(() {
      settings.selectedBooks = result;
      _rebuildEngine();
    });

    await service.saveBooks(widget.uid, settings.selectedBooks);
  }

  // ---------------- UI ----------------

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

                  if (feedback != null) ...[
                    const SizedBox(height: 12),
                    Text(feedback!),
                  ],
                ],
              ),
      ),
    );
  }
}
