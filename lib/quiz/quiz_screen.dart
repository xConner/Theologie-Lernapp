import 'package:flutter/material.dart';

import '../models/perikope.dart';
import '../utils/bible_input_validator.dart';

import '../services/progress_service.dart';
import 'quiz_engine.dart';
import 'quiz_scheduler.dart';

class QuizScreen extends StatefulWidget {
  final List<Perikope> perikopen;

  const QuizScreen({super.key, required this.perikopen});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late ProgressService progressService;
  late QuizScheduler scheduler;

  Perikope? current;

  final List<TextEditingController> controllers = [TextEditingController()];
  final List<bool> validStates = [false];

  QuizResult? result;
  bool locked = false;

  Map<String, dynamic> progress = {};

  @override
  void initState() {
    super.initState();
    progressService = ProgressService();

    _init();
  }

  Future<void> _init() async {
    // ✅ FIX 1: nur required Perikopen
    final filtered = widget.perikopen
        .where((p) => p.occurrences.any((o) => o.required))
        .toList();

    final ids = filtered.map((e) => e.id).toList();

    await progressService.initIfMissing(ids);
    await progressService.syncWithPerikopen(ids);

    progress = await progressService.loadAllProgress();

    scheduler = QuizScheduler(perikopen: filtered, progress: progress);

    setState(() {
      current = scheduler.next();
    });
  }

  void addField() {
    setState(() {
      controllers.add(TextEditingController());
      validStates.add(false);
    });
  }

  void removeField(int i) {
    if (controllers.length == 1) return;

    setState(() {
      controllers[i].dispose();
      controllers.removeAt(i);
      validStates.removeAt(i);
    });
  }

  Future<void> check() async {
    final inputs = controllers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final p = current!;
    final result = QuizEngine.evaluate(p, inputs);

    setState(() {
      this.result = result;
      locked = true;
    });

    final correct = result.status == QuizStatus.correct;

    await progressService.updateProgress(p.id, correct);
  }

  void next() {
    setState(() {
      current = scheduler.next();

      locked = false;
      result = null;

      for (final c in controllers) {
        c.dispose();
      }

      controllers
        ..clear()
        ..add(TextEditingController());

      validStates
        ..clear()
        ..add(false);
    });
  }

  bool get canSubmit => validStates.every((v) => v == true) && !locked;

  bool isValid(String value, String precision) {
    final v = value.trim();
    if (v.isEmpty) return false;

    final parts = v.split(" ");
    if (parts.length != 2) return false;

    final ref = parts[1];

    if (!ref.contains(",")) {
      return precision == "chapter" && RegExp(r'^\d+$').hasMatch(ref);
    }

    final split = ref.split(",");

    if (split.length > 2) return false;

    if (!RegExp(r'^\d+$').hasMatch(split[0])) return false;

    if (split.length == 2 && !RegExp(r'^\d+(-\d+)?$').hasMatch(split[1])) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = current;

    if (p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final requiredOccs = p.occurrences.where((o) => o.required).toList();

    final precision = requiredOccs.first.precision;

    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              p.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // ✅ FIX 2: Precision Hinweis
            Text(
              precision == "chapter"
                  ? "Kapitelgenaue Angabe"
                  : "Versgenaue Angabe",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            ...controllers.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;

              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c,
                      enabled: !locked,
                      onChanged: (value) {
                        setState(() {
                          validStates[i] = isValid(value, precision);
                        });
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: BibleInputValidator.hintText("", precision),
                        suffixIcon: Icon(
                          validStates[i]
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: validStates[i] ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: locked ? null : () => removeField(i),
                    icon: const Icon(Icons.close),
                  ),
                ],
              );
            }),

            const SizedBox(height: 10),

            if (!locked)
              Row(
                children: [
                  ElevatedButton(onPressed: addField, child: const Text("+")),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: canSubmit ? check : null,
                    child: const Text("Prüfen"),
                  ),
                ],
              ),

            if (result != null) ...[
              const SizedBox(height: 20),

              Text(
                result!.status == QuizStatus.correct
                    ? "Richtig"
                    : result!.status == QuizStatus.partial
                    ? "Teilweise richtig"
                    : "Falsch",
                style: const TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 10),

              ...result!.fieldResults.map(
                (r) => Text(
                  r.isCorrect ? "✔ ${r.expected}" : "✘ fehlt: ${r.expected}",
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(onPressed: next, child: const Text("Weiter")),
            ],
          ],
        ),
      ),
    );
  }
}
