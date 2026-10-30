import 'package:flutter/material.dart';

import '../../../models/bible/bible_reference.dart';
import '../../../quiz/books/book_catalog.dart';
import '../../../quiz/books/book_learning.dart';
import '../../../quiz/books/book_learning_controller.dart';
import '../../../quiz/books/book_learning_status.dart';
import '../../../quiz/books/book_outline.dart';
import '../../../quiz/books/knowledge.dart';
import '../../../services/bible/bible_reference_parser.dart';
import '../../../theme/app_theme.dart';
import 'bible_passage.dart';
import 'book_study_screen.dart';
import 'book_widgets.dart';

/// Wissensfragen in „Bücher systematisch lernen“: die Aufgabe in einer
/// Lerneinheit, die Karte in der Buchansicht und die Musterantworten.

/// Eine Belegstelle („Gen 32,23-33“) für den Reader; `null`, wenn sie sich
/// nicht lesen lässt.
BiblePassage? passageOfRef(String ref) {
  final reference = BibleReferenceParser.parse(ref);

  return reference == null
      ? null
      : BiblePassage(label: ref, reference: reference);
}

/// Knöpfe zu den Belegstellen einer Frage bzw. Aufgabe.
class KnowledgeRefButtons extends StatelessWidget {
  final BookLearningController? controller;
  final List<String> refs;

  const KnowledgeRefButtons({
    super.key,
    required this.controller,
    required this.refs,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (refs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final ref in refs)
          if (c != null && passageOfRef(ref) != null)
            ActionChip(
              key: ValueKey("knowledge-ref-$ref"),
              avatar: const Icon(Icons.auto_stories_rounded, size: 16),
              label: Text(ref),
              onPressed: () =>
                  openPassage(context, c, passageOfRef(ref)!, title: ref),
            )
          else
            Chip(label: Text(ref)),
      ],
    );
  }
}

/// Kopfzeile einer Wissensfrage: Art, Buchbereich, Grundlage. Ergänzungen
/// der App sind als solche gekennzeichnet – nichts wird als Vorlesungsstoff
/// ausgegeben, was nicht aus der Vorlesung stammt.
String knowledgeCaption(KnowledgeQuestion q) => [
  q.isStructure ? "Gliederung" : "Wissensfrage",
  if (!q.isStructure) q.topic.label,
  q.scopeLabel,
  q.basis.label,
  if (q.relevance == KnowledgeRelevance.focus) "Schwerpunkt",
].join(" · ");

/// Woher der Inhalt stammt, für die Anzeige nach der Antwort.
String knowledgeOriginText(KnowledgeQuestion q) {
  if (!q.fromLecture) {
    return "Ergänzung der App, nicht aus der Vorlesung "
        "(${q.relevance.label}).";
  }

  final where = q.origin.isEmpty ? q.basis.label : q.origin.join("; ");

  return "$where · ${q.relevance.label}";
}

/// Eine Wissensfrage in der Lerneinheit. Hält nur den Zustand der Eingabe;
/// verbucht wird über [onAnswer] (genau einmal), weiter geht es mit
/// [onNext]. Bei „Aufdecken“ führt die Selbsteinschätzung direkt weiter.
class KnowledgeTaskView extends StatefulWidget {
  final KnowledgeTask task;
  final BookLearningController controller;
  final Future<void> Function(bool correct, String given) onAnswer;
  final VoidCallback onNext;

  const KnowledgeTaskView({
    super.key,
    required this.task,
    required this.controller,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  State<KnowledgeTaskView> createState() => _KnowledgeTaskViewState();
}

class _KnowledgeTaskViewState extends State<KnowledgeTaskView> {
  KnowledgeQuestion get q => widget.task.question;

  List<String> get options => widget.task.options;

  bool answered = false;
  bool? correct;
  bool revealed = false;
  bool busy = false;

  int? chosen;
  final Set<int> selected = {};
  final List<String> arranged = [];
  late final List<String?> matched = List.filled(q.pairs.length, null);

  /// Freie Eingabe ([KnowledgeFormat.input]).
  final TextEditingController input = TextEditingController();

  /// Die Eingabe wurde nicht sicher erkannt: Selbsteinschätzung nach dem
  /// Vergleich mit der Lösung.
  bool unrecognized = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _checkInput() {
    final text = input.text.trim();

    if (text.isEmpty) return;

    if (KnowledgeAnswerMatcher.matches(q, text)) {
      _answer(true, text);
    } else {
      setState(() => unrecognized = true);
    }
  }

  Future<void> _answer(bool value, String given) async {
    if (answered || busy) return;

    busy = true;

    await widget.onAnswer(value, given);

    busy = false;

    if (!mounted) return;

    setState(() {
      answered = true;
      correct = value;
    });
  }

  Future<void> _assess(bool knew) async {
    if (answered || busy) return;

    busy = true;

    await widget.onAnswer(knew, knew ? "gewusst" : "nicht gewusst");

    busy = false;

    if (mounted) widget.onNext();
  }

  void _checkMulti() {
    final right = {...q.correct};
    final picked = {for (final i in selected) options[i]};

    _answer(
      picked.length == right.length && picked.containsAll(right),
      picked.join(" · "),
    );
  }

  void _checkMatch() {
    var ok = true;

    for (int i = 0; i < q.pairs.length; i++) {
      if (matched[i] != q.pairs[i].right) ok = false;
    }

    _answer(
      ok,
      [
        for (int i = 0; i < q.pairs.length; i++)
          "${q.pairs[i].left} – ${matched[i] ?? "?"}",
      ].join("\n"),
    );
  }

  void _checkOrder() {
    var ok = arranged.length == q.items.length;

    for (int i = 0; ok && i < arranged.length; i++) {
      if (arranged[i] != q.items[i]) ok = false;
    }

    _answer(ok, arranged.join(" → "));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          knowledgeCaption(q),
          key: const ValueKey("knowledge-caption"),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          q.prompt,
          key: const ValueKey("knowledge-prompt"),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium,
        ),
        if (q.format == KnowledgeFormat.multi && !answered)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Mehrere Antworten sind richtig.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        const SizedBox(height: 16),
        ..._body(context),
        if (answered) ..._solution(context),
      ],
    );
  }

  List<Widget> _body(BuildContext context) {
    switch (q.format) {
      case KnowledgeFormat.choice:
        return [
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KnowledgeOptionButton(
                key: ValueKey("knowledge-option-$i"),
                label: options[i],
                state: !answered
                    ? null
                    : options[i] == q.correct.single
                    ? true
                    : i == chosen
                    ? false
                    : null,
                onPressed: answered
                    ? null
                    : () {
                        chosen = i;
                        _answer(options[i] == q.correct.single, options[i]);
                      },
              ),
            ),
        ];

      case KnowledgeFormat.multi:
        return [
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: answered
                  ? KnowledgeOptionButton(
                      key: ValueKey("knowledge-option-$i"),
                      label: options[i],
                      state: q.correct.contains(options[i])
                          ? true
                          : selected.contains(i)
                          ? false
                          : null,
                      onPressed: null,
                    )
                  : CheckboxListTile(
                      key: ValueKey("knowledge-option-$i"),
                      value: selected.contains(i),
                      title: Text(options[i]),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(
                        () => v == true ? selected.add(i) : selected.remove(i),
                      ),
                    ),
            ),
          if (!answered)
            Center(
              child: ElevatedButton(
                key: const ValueKey("knowledge-check"),
                onPressed: selected.isEmpty ? null : _checkMulti,
                child: const Text("Prüfen"),
              ),
            ),
        ];

      case KnowledgeFormat.match:
        return [
          for (int i = 0; i < q.pairs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      q.pairs[i].left,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: answered
                        ? Text(
                            matched[i] == q.pairs[i].right
                                ? "✔ ${q.pairs[i].right}"
                                : "✘ ${matched[i] ?? "–"}\n→ ${q.pairs[i].right}",
                            style: TextStyle(
                              color: matched[i] == q.pairs[i].right
                                  ? context.colors.success
                                  : context.colors.error,
                            ),
                          )
                        : DropdownButton<String>(
                            key: ValueKey("knowledge-match-$i"),
                            isExpanded: true,
                            value: matched[i],
                            hint: const Text("zuordnen …"),
                            items: [
                              for (final o in options)
                                DropdownMenuItem(
                                  value: o,
                                  child: Text(o, softWrap: true),
                                ),
                            ],
                            onChanged: (v) => setState(() => matched[i] = v),
                          ),
                  ),
                ],
              ),
            ),
          if (!answered)
            Center(
              child: ElevatedButton(
                key: const ValueKey("knowledge-check"),
                onPressed: matched.contains(null) ? null : _checkMatch,
                child: const Text("Prüfen"),
              ),
            ),
        ];

      case KnowledgeFormat.order:
        final remaining = [
          for (final o in options)
            if (!arranged.contains(o)) o,
        ];

        return [
          Text(
            "Tippe die Einträge in der richtigen Reihenfolge an.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < arranged.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: KnowledgeOptionButton(
                key: ValueKey("knowledge-arranged-$i"),
                label: "${i + 1}. ${arranged[i]}",
                state: answered ? arranged[i] == q.items[i] : null,
                onPressed: answered
                    ? null
                    : () => setState(
                        () => arranged.removeRange(i, arranged.length),
                      ),
              ),
            ),
          if (remaining.isNotEmpty) ...[
            if (arranged.isNotEmpty) const Divider(height: 24),
            for (final o in remaining)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  key: ValueKey("knowledge-order-${options.indexOf(o)}"),
                  onPressed: () => setState(() => arranged.add(o)),
                  child: Text(o, textAlign: TextAlign.center),
                ),
              ),
          ],
          if (!answered)
            Center(
              child: ElevatedButton(
                key: const ValueKey("knowledge-check"),
                onPressed: remaining.isEmpty ? _checkOrder : null,
                child: const Text("Prüfen"),
              ),
            ),
        ];

      case KnowledgeFormat.input:
        if (answered) {
          return [
            Text(
              "Deine Antwort: ${input.text.trim().isEmpty ? "–" : input.text.trim()}",
              key: const ValueKey("knowledge-input-given"),
              textAlign: TextAlign.center,
            ),
          ];
        }

        if (unrecognized) {
          return [
            Text(
              "Deine Antwort: ${input.text.trim()}",
              key: const ValueKey("knowledge-input-given"),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            KnowledgeAnswerBox(title: "Lösung", text: q.solutionText),
            if (q.explanation != null) KnowledgeNote(text: q.explanation!),
            const SizedBox(height: 12),
            Text(
              "Nicht automatisch erkannt. Stimmt deine Antwort inhaltlich "
              "mit der Lösung überein?",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey("knowledge-input-wrong"),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text("Nein, falsch"),
                  onPressed: () => _answer(false, input.text.trim()),
                ),
                ElevatedButton.icon(
                  key: const ValueKey("knowledge-input-right"),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text("Ja, richtig"),
                  onPressed: () =>
                      _answer(true, "${input.text.trim()} (selbst bewertet)"),
                ),
              ],
            ),
          ];
        }

        return [
          TextField(
            key: const ValueKey("knowledge-input"),
            controller: input,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: "Antwort eingeben"),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _checkInput(),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const ValueKey("knowledge-input-unknown"),
                onPressed: () => _answer(false, "weiß ich nicht"),
                child: const Text("Weiß ich nicht"),
              ),
              ElevatedButton(
                key: const ValueKey("knowledge-check"),
                onPressed: input.text.trim().isEmpty ? null : _checkInput,
                child: const Text("Prüfen"),
              ),
            ],
          ),
        ];

      case KnowledgeFormat.reveal:
        if (!revealed) {
          return [
            Text(
              "Überlege dir zuerst deine Antwort.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                key: const ValueKey("knowledge-reveal"),
                icon: const Icon(Icons.visibility_rounded),
                label: Text(
                  q.source == KnowledgeSource.modelAnswer
                      ? "Musterantwort aufdecken"
                      : "Antwort aufdecken",
                ),
                onPressed: () => setState(() => revealed = true),
              ),
            ),
          ];
        }

        return [
          KnowledgeAnswerBox(
            title: q.source == KnowledgeSource.modelAnswer
                ? "Musterantwort"
                : "Antwort",
            text: q.answer ?? "",
          ),
          if (q.explanation != null)
            KnowledgeNote(text: q.explanation!, title: "Erläuterung"),
          KnowledgeNote(
            key: const ValueKey("knowledge-origin"),
            title: "Quelle",
            text: knowledgeOriginText(q),
          ),
          const SizedBox(height: 8),
          KnowledgeRefButtons(controller: widget.controller, refs: q.refs),
          if (q.memoryVerse != null)
            KnowledgeNote(
              text:
                  "Merkvers: ${q.memoryVerse} (unter „Texte auswendig "
                  "lernen“)",
            ),
          const SizedBox(height: 12),
          Text(
            "Wusstest du die Antwort im Wesentlichen?",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey("knowledge-unknown"),
                icon: const Icon(Icons.close_rounded),
                label: const Text("Nicht gewusst"),
                onPressed: () => _assess(false),
              ),
              ElevatedButton.icon(
                key: const ValueKey("knowledge-knew"),
                icon: const Icon(Icons.check_rounded),
                label: const Text("Gewusst"),
                onPressed: () => _assess(true),
              ),
            ],
          ),
        ];
    }
  }

  /// Nach der Auswertung: Rückmeldung, Erklärung, Stellen, „Weiter“.
  List<Widget> _solution(BuildContext context) {
    final ok = correct ?? false;

    final color = ok ? context.colors.success : context.colors.error;

    return [
      Container(
        key: const ValueKey("knowledge-feedback"),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ok
              ? context.colors.successBackground
              : context.colors.errorBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: SelectableText(
          ok
              ? "✔ Richtig${q.answer != null ? "\n${q.answer}" : ""}"
              : "✘ Richtig ist:\n${q.solutionText}",
          textAlign: TextAlign.center,
        ),
      ),
      if (q.explanation != null && !unrecognized)
        KnowledgeNote(text: q.explanation!),
      KnowledgeNote(
        key: const ValueKey("knowledge-origin"),
        title: "Quelle",
        text: knowledgeOriginText(q),
      ),
      const SizedBox(height: 8),
      KnowledgeRefButtons(controller: widget.controller, refs: q.refs),
      if (q.memoryVerse != null)
        KnowledgeNote(
          text: "Merkvers: ${q.memoryVerse} (unter „Texte auswendig lernen“)",
        ),
      const SizedBox(height: 12),
      Center(
        child: ElevatedButton(
          key: const ValueKey("knowledge-next"),
          onPressed: widget.onNext,
          child: const Text("Weiter"),
        ),
      ),
    ];
  }
}

/// Antwortknopf; [state] true/false färbt ihn nach der Auswertung.
class KnowledgeOptionButton extends StatelessWidget {
  final String label;
  final bool? state;
  final VoidCallback? onPressed;

  const KnowledgeOptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = state == null
        ? null
        : state!
        ? context.colors.success
        : context.colors.error;

    return OutlinedButton(
      style: color == null
          ? null
          : OutlinedButton.styleFrom(
              side: BorderSide(color: color, width: 2),
              backgroundColor: state!
                  ? context.colors.successBackground
                  : context.colors.errorBackground,
              disabledForegroundColor: context.colors.textPrimary,
            ),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (state != null) ...[
              Icon(
                state! ? Icons.check_rounded : Icons.close_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// Die aufgedeckte (Muster-)Antwort, vollständig und auswählbar.
class KnowledgeAnswerBox extends StatelessWidget {
  final String title;
  final String text;

  const KnowledgeAnswerBox({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey("knowledge-answer"),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(text),
        ],
      ),
    );
  }
}

/// Erläuterung der App, sichtbar getrennt von der Antwort.
class KnowledgeNote extends StatelessWidget {
  final String text;
  final String? title;

  const KnowledgeNote({super.key, required this.text, this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        TextSpan(
          children: [
            if (title != null)
              TextSpan(
                text: "$title: ",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            TextSpan(text: text),
          ],
        ),
        style: TextStyle(color: context.colors.textSecondary, fontSize: 13.5),
      ),
    );
  }
}

/// Karte „Wissensfragen“ in der Buchansicht: Schalter, Fortschritt,
/// Lernen und Musterantworten. Nur für Bücher mit Wissensfragen.
class KnowledgeBookCard extends StatelessWidget {
  final BookLearningController controller;
  final String book;

  const KnowledgeBookCard({
    super.key,
    required this.controller,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    final questions = controller.contentKnowledgeOf(book);
    final tasks = state.knowledge.tasksOf(book);
    final enabled = state.knowledgeEnabled;

    final progress = state.knowledgeProgressOf(questions);

    return Card(
      key: const ValueKey("knowledge-card"),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const ValueKey("knowledge-enabled"),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.quiz_outlined,
                color: context.colors.primary,
              ),
              title: Text(
                "Wissensfragen",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                enabled
                    ? "Personen, Ereignisse, Begriffe und Aufbau – in "
                          "Lerneinheiten und Wiederholungen"
                    : "Ausgeschaltet: nur Perikopen. Dein Fortschritt "
                          "bleibt gespeichert.",
              ),
              value: enabled,
              onChanged: controller.setKnowledgeEnabled,
            ),
            Text(
              "${progress.total} Fragen · ${progress.secure} sicher"
              "${progress.learning > 0 ? " · ${progress.learning} in Bearbeitung" : ""}"
              "${progress.due > 0 ? " · ${progress.due} fällig" : ""}",
              key: const ValueKey("knowledge-summary"),
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 6),
            LearningProgressBar(progress: progress, height: 6),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (enabled)
                  ElevatedButton.icon(
                    key: const ValueKey("knowledge-learn"),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      progress.due > 0
                          ? "Wissensfragen lernen (${progress.due} fällig)"
                          : "Wissensfragen lernen",
                    ),
                    onPressed: () => startStudy(
                      context,
                      controller: controller,
                      session: controller.knowledgeSession(questions),
                      title: "Wissensfragen: ${BookCatalog.nameOf(book)}",
                    ),
                  ),
                if (tasks.isNotEmpty)
                  OutlinedButton.icon(
                    key: const ValueKey("knowledge-model-answers"),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text("Musterantworten (${tasks.length})"),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModelAnswersScreen(
                          controller: controller,
                          book: book,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aufgaben der Übung mit den Musterantworten der Dozentin: zum Nachlesen
/// (vollständig und wörtlich) und – solange die Wissensfragen
/// eingeschaltet sind – zum Üben der daraus gebildeten Lernfragen.
class ModelAnswersScreen extends StatelessWidget {
  final BookLearningController controller;
  final String book;

  const ModelAnswersScreen({
    super.key,
    required this.controller,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bank = controller.state.knowledge;
        final tasks = bank.tasksOf(book);
        final enabled = controller.state.knowledgeEnabled;

        final all = [for (final t in tasks) ...bank.questionsOfTask(t)];

        return Scaffold(
          appBar: AppBar(
            title: Text("Musterantworten: ${BookCatalog.nameOf(book)}"),
          ),
          body: ListView(
            key: const ValueKey("model-answers-list"),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                "Die Musterantworten bilden ab, was als Antwort erwartet "
                "wird. Sie stehen hier unverändert; die Lernfragen darunter "
                "zerlegen sie zum Wiederholen in kleinere Teile.",
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (enabled && all.isNotEmpty)
                ElevatedButton.icon(
                  key: const ValueKey("model-answers-learn-all"),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("Alle Lernfragen wiederholen"),
                  onPressed: () => startStudy(
                    context,
                    controller: controller,
                    session: controller.knowledgeSession(all),
                    title: "Musterantworten",
                  ),
                ),
              if (!enabled)
                Text(
                  "Die Wissensfragen sind ausgeschaltet; die Musterantworten "
                  "bleiben zum Nachlesen da.",
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              for (final t in tasks)
                _ModelAnswerTile(controller: controller, task: t),
            ],
          ),
        );
      },
    );
  }
}

class _ModelAnswerTile extends StatelessWidget {
  final BookLearningController controller;
  final ModelAnswerTask task;

  const _ModelAnswerTile({required this.controller, required this.task});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final bank = state.knowledge;
    final questions = bank.questionsOfTask(task);
    final progress = state.knowledgeProgressOf(questions);
    final session = bank.sessionTitles[task.sessionId] ?? task.sessionId;

    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        key: ValueKey("model-answer-${task.id}"),
        title: Text(
          "${task.number}. ${task.prompt}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            session,
            if (task.range != null) "${task.book} ${task.range!.text}",
            "${questions.length} Lernfragen, ${progress.secure} sicher",
          ].join(" · "),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KnowledgeAnswerBox(title: "Musterantwort", text: task.answer),
          if (task.note != null)
            KnowledgeNote(text: task.note!, title: "Erläuterung der App"),
          const SizedBox(height: 8),
          KnowledgeRefButtons(controller: controller, refs: task.refs),
          if (state.knowledgeEnabled && questions.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final q in questions)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  levelIcon(state.knowledgeStatusOf(q).level),
                  color: levelColor(context, state.knowledgeStatusOf(q).level),
                  size: 20,
                ),
                title: Text(q.prompt),
                subtitle: Text(
                  "${q.format.label} · ${state.knowledgeStatusOf(q).label}",
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: ValueKey("model-answer-learn-${task.id}"),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Diese Aufgabe üben"),
                onPressed: () => startStudy(
                  context,
                  controller: controller,
                  session: controller.fixedSession(
                    StudyMode.knowledge,
                    controller.planner().knowledgeInOrder(questions),
                  ),
                  title: "Aufgabe ${task.number}",
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zeile „n Wissensfragen“ für Abschnitte und Kapitel.
String knowledgeCountText(LearningProgress progress) => progress.total == 0
    ? ""
    : " · ${progress.total} Wissensfragen"
          "${progress.due > 0 ? " (${progress.due} fällig)" : ""}";

/// Karte „Grobgliederung“ in der Buchansicht (Ebene A): die
/// Hauptabschnitte nach der Vorlesung mit ihren Unterpunkten, dem
/// Fortschritt ihrer Perikopen (Ebene B) und den Gliederungsaufgaben.
/// Nur für Bücher mit hinterlegter Grobgliederung.
class OutlinePartsCard extends StatelessWidget {
  final BookLearningController controller;
  final BookOutline outline;

  const OutlinePartsCard({
    super.key,
    required this.controller,
    required this.outline,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final book = outline.book;
    final questions = controller.structureOf(book);
    final progress = state.knowledgeProgressOf(questions);
    final enabled = state.pericopesEnabled;

    return Card(
      key: const ValueKey("outline-parts-card"),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Grobgliederung",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final part in outline.parts)
              Builder(
                builder: (context) {
                  final pericopes = [
                    for (final s in part.sections)
                      ...pericopesOfSection(state.catalog, s),
                  ];
                  final p = state.progressOf(pericopes);

                  return Padding(
                    key: ValueKey("outline-part-${part.id}"),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "${part.label}  ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: part.title),
                            ],
                          ),
                        ),
                        for (final s in part.sections)
                          if (s.learn)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                "${s.shortRange}: ${s.title}",
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            "${pericopes.length} Perikopen, ${p.secure} sicher",
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 4),
            Text(
              "${progress.total} Gliederungsaufgaben · ${progress.secure} sicher"
              "${progress.due > 0 ? " · ${progress.due} fällig" : ""}",
              key: const ValueKey("outline-parts-summary"),
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 6),
            LearningProgressBar(progress: progress, height: 6),
            const SizedBox(height: 12),
            if (enabled)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  key: const ValueKey("outline-parts-learn"),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("Gliederung lernen"),
                  onPressed: () => startStudy(
                    context,
                    controller: controller,
                    session: controller.knowledgeSession(questions),
                    title: "Gliederung: ${BookCatalog.nameOf(book)}",
                  ),
                ),
              )
            else
              Text(
                "„Perikopen und Gliederung“ ist ausgeschaltet; die "
                "Gliederung bleibt zum Nachlesen da.",
                style: TextStyle(color: context.colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Die beiden Schalter des gemeinsamen Lernmodus. Mindestens einer bleibt
/// an; gelten für alle Lerneinheiten, Wiederholungen und den Lernpfad.
class StudyContentSwitches extends StatelessWidget {
  final BookLearningController controller;

  const StudyContentSwitches({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          key: const ValueKey("study-content-knowledge"),
          avatar: const Icon(Icons.quiz_outlined, size: 18),
          label: const Text("Wissensfragen"),
          selected: state.knowledgeEnabled,
          onSelected: (v) => controller.setKnowledgeEnabled(v),
        ),
        FilterChip(
          key: const ValueKey("study-content-pericopes"),
          avatar: const Icon(Icons.format_list_numbered_rounded, size: 18),
          label: const Text("Perikopen und Gliederung"),
          selected: state.pericopesEnabled,
          onSelected: (v) => controller.setPericopesEnabled(v),
        ),
      ],
    );
  }
}
