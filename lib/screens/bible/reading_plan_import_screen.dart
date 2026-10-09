import 'package:flutter/material.dart';

import '../../services/bible/bible_reading_service.dart';
import '../../services/bible/reading_plan_codec.dart';
import '../../theme/app_theme.dart';
import '../../utils/text_file.dart';

/// Import eines eigenen Leseplans aus einer JSON-Datei im Format von
/// theologie.app (`docs/reading-plans.md`). Liefert beim Schließen den
/// importierten Plan.
class ReadingPlanImportScreen extends StatefulWidget {
  /// null = Gast.
  final String? uid;

  final BibleReadingService service;

  const ReadingPlanImportScreen({
    super.key,
    required this.uid,
    required this.service,
  });

  @override
  State<ReadingPlanImportScreen> createState() =>
      _ReadingPlanImportScreenState();
}

class _ReadingPlanImportScreenState extends State<ReadingPlanImportScreen> {
  final TextEditingController _json = TextEditingController();

  List<String> problems = const [];

  bool busy = false;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final content = await pickTextFile(
      maxLength: ReadingPlanCodec.maxFileLength,
    );

    if (!mounted) return;

    if (content == null) {
      setState(
        () => problems = const [
          "Es wurde keine Datei gewählt oder sie ist zu groß.",
        ],
      );

      return;
    }

    _json.text = content;

    await _import();
  }

  Future<void> _import() async {
    if (busy) return;

    setState(() {
      busy = true;
      problems = const [];
    });

    try {
      final plan = await widget.service.importPlan(widget.uid, _json.text);

      if (mounted) Navigator.pop(context, plan);
    } on ReadingPlanFormatException catch (e) {
      if (mounted) setState(() => problems = e.problems);
    } catch (_) {
      if (mounted) {
        setState(
          () => problems = const ["Der Plan konnte nicht importiert werden."],
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);

    return Scaffold(
      appBar: AppBar(title: const Text("Plan importieren")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Importiere einen Leseplan als JSON-Datei. Jede Bibelstelle "
                "wird geprüft; ein Plan mit bereits vorhandener Kennung wird "
                "nicht erneut importiert.",
                style: secondary,
              ),

              const SizedBox(height: 8),

              Text(
                "Beispiel:\n"
                "{\"id\": \"mein-plan\", \"name\": \"Mein Plan\",\n"
                " \"days\": [[\"MRK 1-2\", \"PSA 1\"], [\"MRK 3-4\"]]}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: "monospace",
                  color: context.colors.textSecondary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Importiere nur Pläne, die du selbst erstellt hast oder "
                "deren Lizenz die Nutzung erlaubt.",
                style: secondary,
              ),

              const SizedBox(height: 16),

              if (textFilesSupported) ...[
                OutlinedButton.icon(
                  onPressed: busy ? null : _pick,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text("JSON-Datei wählen"),
                ),

                const SizedBox(height: 16),
              ],

              TextField(
                key: const ValueKey("plan-import-json"),
                controller: _json,
                minLines: 6,
                maxLines: 14,
                style: const TextStyle(fontFamily: "monospace", fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Inhalt der Plandatei (JSON)",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              FilledButton(
                key: const ValueKey("plan-import-submit"),
                onPressed: busy ? null : _import,
                child: const Text("Importieren"),
              ),

              if (problems.isNotEmpty) PlanProblems(problems: problems),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die Gründe, aus denen ein Plan nicht angenommen wurde.
class PlanProblems extends StatelessWidget {
  final List<String> problems;

  const PlanProblems({super.key, required this.problems});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey("plan-problems"),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final problem in problems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                problem,
                style: TextStyle(color: context.colors.error),
              ),
            ),
        ],
      ),
    );
  }
}
