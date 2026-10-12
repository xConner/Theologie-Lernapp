import 'package:flutter/material.dart';

import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/exam/greek_exam.dart';
import '../../../models/greek/exam/passage_ref.dart';
import '../../../models/greek/exam/text_corpus.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/bible/bible_books.dart';
import '../../../services/greek/exam/exam_generator.dart';
import '../../../services/greek/exam/exam_store.dart';
import '../../../services/greek/exam/exam_task_types.dart';
import '../../../services/greek/exam/grammar_phenomena.dart';
import '../../../theme/app_theme.dart';
import 'exam_diagnosis_view.dart';
import 'exam_task_widgets.dart';

/// Anzeigename eines Abschnitts ("Johannes 1,1–5 · NT").
String passageTitle(PassageRef ref, TextCorpus? corpus) {
  final book = BibleBooks.nameOf(ref.bookId);
  final suffix = corpus == null ? "" : " · ${corpus.shortName}";
  return "$book ${ref.verseLabel}$suffix";
}

/// Eine generierte Klausur: Text mit Vokabelhilfen, Verbbestimmung und die
/// Aufgaben 3 und 4. Jede Aufgabe lässt sich einzeln austauschen; als
/// bearbeitet markiert wird der Text nur über die Schaltfläche am Ende.
class GreekExamScreen extends StatefulWidget {
  final GreekExam exam;
  final ExamGenerator generator;
  final ExamStore store;
  final List<GreekVocabularyEntry> vocabulary;

  const GreekExamScreen({
    super.key,
    required this.exam,
    required this.generator,
    required this.store,
    required this.vocabulary,
  });

  @override
  State<GreekExamScreen> createState() => _GreekExamScreenState();
}

class _GreekExamScreenState extends State<GreekExamScreen> {
  late GreekExam exam = widget.exam;

  Map<PassageRef, DateTime> done = {};
  bool busy = false;

  /// Zähler je Aufgabe: ein neuer Wert setzt die Eingaben der Aufgabe zurück.
  int verbsVersion = 0;
  final List<int> extraVersions = [0, 0];
  int textVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  Future<void> _loadDone() async {
    try {
      final loaded = await widget.store.loadDone();
      if (mounted) setState(() => done = loaded);
    } catch (_) {
      // Ohne gespeicherte Markierungen bleibt die Klausur nutzbar.
    }
  }

  bool get isDone => done.containsKey(exam.passage.ref);

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);

    try {
      await action();
    } catch (e) {
      _message("Das hat nicht geklappt: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> replaceText() => _run(() async {
    final outcome = await widget.generator.replaceText(
      exam,
      done: done.keys.toSet(),
      vocabulary: widget.vocabulary,
    );

    if (!mounted) return;

    switch (outcome) {
      case ExamCreated(:final exam):
        setState(() {
          this.exam = exam;
          textVersion++;
          verbsVersion++;
          extraVersions[0]++;
          extraVersions[1]++;
        });
        _message("Neuer Text. Die Aufgaben 2–4 beziehen sich auf ihn.");
      case final ExamNotPossible notPossible:
        if (notPossible.noAlternative) {
          _message("Es gibt keinen anderen Text, der die Kriterien erfüllt.");
        } else {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Kein anderer Text"),
              content: SingleChildScrollView(
                child: ExamDiagnosisView(outcome: notPossible),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
    }
  });

  Future<void> replaceVerbs() => _run(() async {
    final next = await widget.generator.replaceVerbs(exam);

    if (!mounted) return;

    if (next == null) {
      _message("Der Text enthält keine weiteren bestimmbaren Verbformen.");
      return;
    }

    setState(() {
      exam = next;
      verbsVersion++;
    });
  });

  Future<void> replaceExtra(int slot, {String? typeId}) => _run(() async {
    final next = await widget.generator.replaceExtraTask(
      exam,
      slot,
      typeId: typeId,
    );

    if (!mounted) return;

    if (next == null) {
      _message(
        "Der Text gibt keine andere Aufgabe dieser Art her. Andere "
        "Aufgabenart wählen oder den Text austauschen.",
      );
      return;
    }

    setState(() {
      exam = next;
      extraVersions[slot]++;
    });
  });

  Future<void> toggleDone() => _run(() async {
    final ref = exam.passage.ref;

    if (isDone) {
      await widget.store.unmarkDone(ref);
    } else {
      await widget.store.markDone(ref);
    }

    await _loadDone();

    if (mounted) {
      _message(
        isDone
            ? "${passageTitle(ref, exam.passage.corpus)} ist als bearbeitet "
                  "markiert."
            : "Markierung entfernt.",
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final passage = exam.passage;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Übungsklausur"),
        actions: [
          IconButton(
            tooltip: "Anderen Text wählen",
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: busy ? null : replaceText,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              _header(context),
              const SizedBox(height: 16),
              _section(
                context,
                number: 1,
                title: "Übersetzen Sie den Text.",
                action: TextButton.icon(
                  onPressed: busy ? null : replaceText,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text("Anderer Text"),
                ),
                children: [
                  ExamPassageText(
                    key: ValueKey("text-$textVersion"),
                    passage: passage,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Vokabelhilfen",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  VocabularyHintList(hints: exam.translation.hints),
                ],
              ),
              _section(
                context,
                number: 2,
                title: "Bestimmen Sie die folgenden Verbformen.",
                action: TextButton.icon(
                  onPressed: busy ? null : replaceVerbs,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Andere Verben"),
                ),
                children: [_task(context, exam.verbs, "verbs-$verbsVersion")],
              ),
              for (final slot in [0, 1])
                _section(
                  context,
                  number: slot + 3,
                  title:
                      ExamTaskTypes.byId(exam.extra[slot].typeId)?.label ??
                      "Aufgabe",
                  action: _extraMenu(slot),
                  children: [
                    _task(
                      context,
                      exam.extra[slot],
                      "extra-$slot-${extraVersions[slot]}",
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: isDone
                    ? OutlinedButton.icon(
                        key: const ValueKey("unmark-done"),
                        onPressed: busy ? null : toggleDone,
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text("Markierung „bearbeitet“ entfernen"),
                      )
                    : ElevatedButton.icon(
                        key: const ValueKey("mark-done"),
                        onPressed: busy ? null : toggleDone,
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text("Text als bearbeitet markieren"),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                "Markiert wird nur ${passageTitle(passage.ref, passage.corpus)}. "
                "Bearbeitete Texte lassen sich in den Einstellungen des "
                "Klausurerstellers wieder zulassen.",
                style: TextStyle(color: context.colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extraMenu(int slot) {
    final current = exam.extra[slot].typeId;

    return PopupMenuButton<String>(
      tooltip: "Aufgabe austauschen",
      enabled: !busy,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) => value == current
          ? replaceExtra(slot)
          : replaceExtra(slot, typeId: value),
      itemBuilder: (_) => [
        PopupMenuItem(value: current, child: const Text("Neue Aufgabe dieser Art")),
        for (final type in ExamTaskTypes.extra)
          if (type.id != current)
            PopupMenuItem(value: type.id, child: Text("Stattdessen: ${type.label}")),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final colors = context.colors;
    final passage = exam.passage;
    final selection = exam.selection;
    final secondary = TextStyle(color: colors.textSecondary);

    String words(List<int> indices) => indices
        .take(6)
        .map((i) => passage.tokens[i].word)
        .join(", ");

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              passageTitle(passage.ref, passage.corpus),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              "${passage.wordCount} Wörter · ${passage.corpus.edition}"
              "${passage.corpus.id == "lxx" ? " · Zählung der Septuaginta" : ""}",
              style: secondary,
            ),
            if (isDone)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Bereits als bearbeitet markiert.",
                  style: TextStyle(color: colors.success),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              selection.fixed
                  ? "Konkret gewählte Stelle; sie erfüllt alle Kriterien."
                  : "Zufällig gewählt aus ${selection.matchCount} passenden "
                        "Abschnitten (${selection.startCount} verschiedene "
                        "Anfangsverse).",
              style: secondary,
            ),
            for (final evidence in selection.required)
              Text(
                "✓ ${GrammarPhenomena.byId(evidence.phenomenonId)?.label}: "
                "${evidence.tokens.isEmpty ? "belegt" : words(evidence.tokens)}",
              ),
            if (selection.excluded.isNotEmpty)
              Text(
                "✓ geprüft, nicht enthalten: "
                "${selection.excluded.map((id) => GrammarPhenomena.byId(id)?.label).join(", ")}",
              ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text("Text, Analyse und Quellen"),
                children: [_sources(context)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sources(BuildContext context) {
    final corpus = exam.passage.corpus;
    final secondary = TextStyle(color: context.colors.textSecondary);
    final tokens = exam.passage.tokens;
    final unanalyzed = tokens
        .where((t) => t.reliability == AnalysisReliability.unanalyzed)
        .length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(corpus.analysisNote),
          if (unanalyzed > 0)
            Text(
              "$unanalyzed Wörter dieses Textes sind nicht bestimmt.",
              style: secondary,
            ),
          const SizedBox(height: 8),
          Text(
            "Text: ${corpus.text.name} (${corpus.text.license})"
            "${corpus.text.copyright == null ? "" : ", ${corpus.text.copyright}"}",
            style: secondary,
          ),
          for (final source in corpus.sources)
            Text(
              "${source.name} (${source.license})"
              "${source.copyright == null ? "" : ", ${source.copyright}"}",
              style: secondary,
            ),
          Text(
            "Bedeutungen: Vokabelliste der App, sonst deutsches bzw. "
            "englisches Wiktionary (CC BY-SA 4.0).",
            style: secondary,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required int number,
    required String title,
    required Widget action,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Aufgabe $number: $title",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                action,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _task(BuildContext context, ExamTask task, String version) {
    return switch (task) {
      VerbParsingTask(:final items) => Column(
        key: ValueKey(version),
        children: [
          for (final item in items)
            ParsingItemCard(
              key: ValueKey("$version-${item.tokenIndex}"),
              item: item,
              verb: true,
            ),
        ],
      ),
      NounParsingTask(:final items) => Column(
        key: ValueKey(version),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Bestimmen Sie Grundform, Kasus, Numerus und Genus."),
          for (final item in items)
            ParsingItemCard(
              key: ValueKey("$version-${item.tokenIndex}"),
              item: item,
              verb: false,
            ),
        ],
      ),
      FindFormsTask() => FindFormsView(
        key: ValueKey(version),
        passage: exam.passage,
        task: task,
      ),
      UnavailableTask(:final reason) => Text(
        reason,
        key: ValueKey(version),
        style: TextStyle(color: context.colors.textSecondary),
      ),
      TranslationTask() => const SizedBox.shrink(),
    };
  }
}
