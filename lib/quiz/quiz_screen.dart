import 'dart:math';
import 'package:flutter/material.dart';

import '../models/perikope.dart';
import '../models/occurrence.dart';
import '../utils/bible_input_validator.dart';
import 'quiz_engine.dart';

class QuizScreen extends StatefulWidget {
  final List<Perikope> perikopen;

  const QuizScreen({super.key, required this.perikopen});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<Perikope> questions;
  int index = 0;

  final List<TextEditingController> controllers = [TextEditingController()];
  final List<bool> validStates = [false];

  QuizResult? result;
  bool locked = false;

  @override
  void initState() {
    super.initState();
    questions =
        widget.perikopen
            .where((p) => p.occurrences.any((o) => o.required))
            .toList()
          ..shuffle(Random());
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

  void check() {
    final inputs = controllers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      result = QuizEngine.evaluate(questions[index], inputs);
      locked = true;
    });
  }

  void next() {
    setState(() {
      index++;
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

  bool get isLast => index >= questions.length - 1;

  @override
  Widget build(BuildContext context) {
    final p = questions[index];
    final requiredOccs = p.occurrences.where((o) => o.required).toList();

    if (requiredOccs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(p.title)),
        body: const Center(child: Text("Keine Pflichtangaben für diese Frage")),
      );
    }

    final precision = requiredOccs.first.precision;

    return Scaffold(
      appBar: AppBar(title: Text("${index + 1} / ${questions.length}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              p.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(precision == "chapter" ? "Kapitelgenau" : "Versgenau"),

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
                    ? "✅ Richtig"
                    : result!.status == QuizStatus.partial
                    ? "🟡 Teilweise richtig"
                    : "❌ Falsch",
                style: const TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 10),

              ...result!.fieldResults.map(
                (r) => Text(
                  r.isCorrect ? "✔ ${r.expected}" : "❌ fehlt: ${r.expected}",
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: next,
                child: Text(isLast ? "Fertig" : "Weiter"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
