import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/reading_plan_codec.dart';
import '../../services/bible/reading_plan_text.dart';
import '../../theme/app_theme.dart';
import 'reading_plan_import_screen.dart';

/// Erstellt einen eigenen Leseplan aus einer einfachen Texteingabe: ein Tag
/// je Zeile. Der Plan durchläuft dieselbe Prüfung wie ein importierter und
/// lässt sich danach als JSON exportieren. Liefert beim Schließen den Plan.
class ReadingPlanEditorScreen extends StatefulWidget {
  /// null = Gast.
  final String? uid;

  final BibleReadingService service;

  const ReadingPlanEditorScreen({
    super.key,
    required this.uid,
    required this.service,
  });

  @override
  State<ReadingPlanEditorScreen> createState() =>
      _ReadingPlanEditorScreenState();
}

class _ReadingPlanEditorScreenState extends State<ReadingPlanEditorScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _days = TextEditingController();

  List<String> problems = const [];

  bool busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;

    final name = _name.text.trim();

    final built = ReadingPlanText.build(
      id: ReadingPlanText.newId(name, DateTime.now()),
      name: name,
      description: _description.text.trim(),
      days: _days.text,
    );

    if (built.problems.isNotEmpty) {
      setState(() => problems = built.problems);

      return;
    }

    setState(() {
      busy = true;
      problems = const [];
    });

    try {
      final plan = await widget.service.importPlan(
        widget.uid,
        jsonEncode(built.json),
      );

      if (mounted) Navigator.pop(context, plan);
    } on ReadingPlanFormatException catch (e) {
      if (mounted) setState(() => problems = e.problems);
    } catch (_) {
      if (mounted) {
        setState(
          () => problems = const ["Der Plan konnte nicht gespeichert werden."],
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Eigener Leseplan")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const ValueKey("plan-editor-name"),
                controller: _name,
                maxLength: ReadingPlanCodec.maxNameLength,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _description,
                maxLength: ReadingPlanCodec.maxDescriptionLength,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Beschreibung (optional)",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                key: const ValueKey("plan-editor-days"),
                controller: _days,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: "Lesungen – ein Tag je Zeile",
                  hintText: "Mk 1-2; Ps 1\nMk 3-4\nJoel",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Mehrere Lesungen eines Tages mit Semikolon trennen. Möglich "
                "sind Kapitel („Mk 4“, „Gen 1-3“), Verse („Joh 3,16-21“) und "
                "ganze Bücher („Joel“).",
                style: TextStyle(color: context.colors.textSecondary),
              ),

              const SizedBox(height: 16),

              FilledButton(
                key: const ValueKey("plan-editor-save"),
                onPressed: busy ? null : _save,
                child: const Text("Plan speichern"),
              ),

              if (problems.isNotEmpty) PlanProblems(problems: problems),
            ],
          ),
        ),
      ),
    );
  }
}
