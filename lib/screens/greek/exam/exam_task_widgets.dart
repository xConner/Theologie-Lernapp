import 'package:flutter/material.dart';

import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/exam/greek_exam.dart';
import '../../../models/greek/exam/greek_morph_analysis.dart';
import '../../../services/greek/exam/exam_answer_check.dart';
import '../../../services/greek/exam/grammar_phenomena.dart';
import '../../../services/greek/exam/vocabulary_help.dart';
import '../../../services/greek/grammar/grammar_question_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/greek_keyboard.dart';
import '../../../widgets/settings_selection.dart';
import '../../../widgets/trainer_widgets.dart';

/// Griechischer Text eines Abschnitts mit Versnummern. Mit [onTapWord]
/// sind die Wörter antippbar (Aufgabe „Formen finden“); [wordColor] färbt
/// einzelne Wörter (Index in `ExamPassage.tokens`).
class ExamPassageText extends StatelessWidget {
  final ExamPassage passage;
  final void Function(int index)? onTapWord;
  final Set<int> selected;
  final Color? Function(int index)? wordColor;

  const ExamPassageText({
    super.key,
    required this.passage,
    this.onTapWord,
    this.selected = const {},
    this.wordColor,
  });

  static const double fontSize = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: 1.6,
      color: colors.textPrimary,
    );
    final verseStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    );

    if (onTapWord == null && wordColor == null) {
      return SelectableText.rich(
        TextSpan(
          children: [
            for (final verse in passage.verses) ...[
              TextSpan(text: "${verse.label} ", style: verseStyle),
              TextSpan(
                text: "${verse.tokens.map((t) => t.surface).join(" ")} ",
                style: textStyle,
              ),
            ],
          ],
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        for (final (v, verse) in passage.verses.indexed) ...[
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(verse.label, style: verseStyle),
          ),
          for (final (i, token) in verse.tokens.indexed)
            _word(
              context,
              passage.verseOffsets[v] + i,
              token,
              textStyle,
            ),
        ],
      ],
    );
  }

  Widget _word(
    BuildContext context,
    int index,
    CorpusToken token,
    TextStyle style,
  ) {
    final colors = context.colors;
    final isSelected = selected.contains(index);
    final color = wordColor?.call(index);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        key: ValueKey("exam-word-$index"),
        borderRadius: BorderRadius.circular(6),
        onTap: onTapWord == null ? null : () => onTapWord!(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color:
                color?.withValues(alpha: 0.18) ??
                (isSelected ? colors.primary.withValues(alpha: 0.15) : null),
            border: Border.all(
              color: color ?? (isSelected ? colors.primary : Colors.transparent),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(token.surface, style: style),
        ),
      ),
    );
  }
}

/// Vokabelhilfen unter dem Text.
class VocabularyHintList extends StatelessWidget {
  final List<VocabularyHint> hints;

  const VocabularyHintList({super.key, required this.hints});

  static String sourceLabel(HintLemma lemma) => switch (lemma.source) {
    MeaningSource.vocabulary => "Vokabelliste, Schritt ${lemma.step}",
    MeaningSource.wiktionaryGerman => "Wiktionary (de)",
    MeaningSource.wiktionaryEnglish => "Wiktionary (en), keine deutsche Angabe",
    MeaningSource.none => "keine Bedeutung in den Datenquellen",
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (hints.isEmpty) {
      return Text(
        "Keine Vokabelhilfen: Alle Wörter gehören zu den gewählten "
        "Lernschritten.",
        style: TextStyle(color: colors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final hint in hints) _hint(context, hint)],
    );
  }

  Widget _hint(BuildContext context, VocabularyHint hint) {
    final colors = context.colors;
    final secondary = TextStyle(color: colors.textSecondary, fontSize: 13);
    final forms = hint.forms.join(", ");

    final List<Widget> lines;

    if (hint.unanalyzed) {
      lines = [
        Text(forms, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          "Form in den Datenquellen nicht bestimmbar – Grundform bitte im "
          "Wörterbuch nachschlagen.",
          style: secondary,
        ),
      ];
    } else if (hint.properNameGuess) {
      lines = [
        Text(forms, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text("vermutlich Eigenname (nicht bestimmt)", style: secondary),
      ];
    } else {
      lines = [
        if (hint.ambiguous)
          Text(
            "$forms – mehrdeutig, mögliche Grundformen:",
            style: secondary,
          ),
        for (final lemma in hint.lemmas) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: lemma.headword,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (lemma.meanings.isNotEmpty)
                  TextSpan(text: " – ${lemma.meanings.join("; ")}")
                else if (lemma.properName)
                  const TextSpan(text: " – Eigenname"),
              ],
            ),
          ),
          Text(
            [
              if (!hint.ambiguous && forms != lemma.lemma) "im Text: $forms",
              if (lemma.meanings.length > 1) "Bedeutung nach Kontext wählen",
              sourceLabel(lemma),
            ].join(" · "),
            style: secondary,
          ),
        ],
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }
}

/// Bestimmung einer Form (Verb oder Nominalform) mit eigener Prüfung.
class ParsingItemCard extends StatefulWidget {
  final ParsingItem item;
  final bool verb;

  const ParsingItemCard({super.key, required this.item, required this.verb});

  @override
  State<ParsingItemCard> createState() => _ParsingItemCardState();
}

class _ParsingItemCardState extends State<ParsingItemCard> {
  final TextEditingController lemmaController = TextEditingController();

  String? mood;
  String? tense;
  String? voice;
  String? personNumber;
  String? grammaticalCase;
  String? number;
  String? gender;

  ParsingResult? result;

  static final List<String> moods = [
    for (final code in ["I", "S", "O", "D", "N", "P"])
      GreekMorphAnalysis.moodLabels[code]!,
  ];

  static final List<String> tenses = GreekMorphAnalysis.tenseLabels.values
      .toList();

  static const List<String> cases = [
    "Nominativ",
    "Genitiv",
    "Dativ",
    "Akkusativ",
    "Vokativ",
  ];

  @override
  void dispose() {
    lemmaController.dispose();
    super.dispose();
  }

  bool get answered => result != null;

  bool get _finite =>
      mood != null &&
      mood != GreekMorphAnalysis.moodLabels["N"] &&
      mood != GreekMorphAnalysis.moodLabels["P"];

  bool get _participle => mood == GreekMorphAnalysis.moodLabels["P"];

  void check() {
    final answer = ParsingAnswer(
      lemma: lemmaController.text,
      mood: mood,
      tense: tense,
      voice: voice,
      personNumber: personNumber,
      grammaticalCase: grammaticalCase,
      number: number,
      gender: gender,
    );

    setState(() {
      result = widget.verb
          ? ExamAnswerCheck.checkVerb(widget.item, answer)
          : ExamAnswerCheck.checkNominal(widget.item, answer);
    });
  }

  void reset() {
    setState(() {
      result = null;
      lemmaController.clear();
      mood = tense = voice = personNumber = null;
      grammaticalCase = number = gender = null;
    });
  }

  bool? _field(ParsingField field) => result?.fields[field];

  Widget _choice(
    String label,
    List<String> options,
    String? value,
    ValueChanged<String> onChanged,
    ParsingField field,
  ) {
    return SingleSelectChips(
      key: ValueKey("${widget.item.tokenIndex}-${field.name}"),
      label: label,
      options: options,
      value: value,
      correct: _field(field),
      onChanged: answered ? null : (v) => setState(() => onChanged(v)),
    );
  }

  void openKeyboard() {
    showModalBottomSheet(
      context: context,
      builder: (_) =>
          GreekKeyboard(controller: lemmaController, onChanged: () {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;

    final choices = <Widget>[
      if (widget.verb) ...[
        _choice("Modus / Form", moods, mood, (v) {
          mood = v;
          if (!_finite) personNumber = null;
          if (!_participle) grammaticalCase = number = gender = null;
        }, ParsingField.mood),
        _choice("Tempus", tenses, tense, (v) => tense = v, ParsingField.tense),
        _choice(
          "Genus Verbi",
          GrammarQuestionPicker.voices,
          voice,
          (v) => voice = v,
          ParsingField.voice,
        ),
        if (_finite)
          _choice(
            "Person / Numerus",
            mood == GreekMorphAnalysis.moodLabels["D"]
                ? GrammarQuestionPicker.imperativePersonNumbers
                : GrammarQuestionPicker.personNumbers,
            personNumber,
            (v) => personNumber = v,
            ParsingField.personNumber,
          ),
      ],
      if (!widget.verb || _participle) ...[
        _choice(
          "Kasus",
          cases,
          grammaticalCase,
          (v) => grammaticalCase = v,
          ParsingField.grammaticalCase,
        ),
        _choice(
          "Numerus",
          GrammarQuestionPicker.numbers,
          number,
          (v) => number = v,
          ParsingField.number,
        ),
        _choice(
          "Genus",
          GrammarQuestionPicker.genders,
          gender,
          (v) => gender = v,
          ParsingField.gender,
        ),
      ],
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.token.word,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey("lemma-${item.tokenIndex}"),
              controller: lemmaController,
              enabled: !answered,
              decoration: InputDecoration(
                labelText: "Grundform",
                border: const OutlineInputBorder(),
                enabledBorder: answerResultBorder(
                  context,
                  _field(ParsingField.lemma),
                ),
                disabledBorder: answerResultBorder(
                  context,
                  _field(ParsingField.lemma),
                ),
                suffixIcon: IconButton(
                  tooltip: "Griechische Tastatur",
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  onPressed: answered ? null : openKeyboard,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 24, runSpacing: 8, children: choices),
            const SizedBox(height: 8),
            if (result == null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: ValueKey("check-${item.tokenIndex}"),
                  onPressed: check,
                  child: const Text("Prüfen"),
                ),
              )
            else
              _feedback(context, result!),
          ],
        ),
      ),
    );
  }

  Widget _feedback(BuildContext context, ParsingResult r) {
    final colors = context.colors;
    final reference = r.reference;
    final context_ = widget.item.context;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.correct ? "Richtig." : "Nicht ganz.",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: r.correct ? colors.success : colors.error,
          ),
        ),
        if (!r.correct)
          Text("Lösung: ${reference.lemma} · ${reference.analysis.describe()}"),
        if (r.onlyFormallyPossible && context_ != null)
          Text(
            "Deine Bestimmung ist formal möglich; im Kontext: "
            "${context_.analysis.describe()}",
          ),
        if (context_ == null)
          Text(
            "Bestimmung ohne Kontextprüfung (Formenindex)"
            "${widget.item.accepted.length > 1 ? "; die Form ist mehrdeutig" : ""}.",
            style: TextStyle(color: colors.textSecondary),
          ),
        if (r.alsoPossible.isNotEmpty)
          Text(
            "Auch möglich: ${r.alsoPossible.map((a) => "${a.lemma} · ${a.analysis.describe()}").join("; ")}",
            style: TextStyle(color: colors.textSecondary),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: reset, child: const Text("Nochmal")),
        ),
      ],
    );
  }
}

/// Aufgabe „Formen im Text finden“.
class FindFormsView extends StatefulWidget {
  final ExamPassage passage;
  final FindFormsTask task;

  const FindFormsView({super.key, required this.passage, required this.task});

  @override
  State<FindFormsView> createState() => _FindFormsViewState();
}

class _FindFormsViewState extends State<FindFormsView> {
  final Set<int> selected = {};
  ({Set<int> found, Set<int> missed, Set<int> wrong})? result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phenomenon = GrammarPhenomena.byId(widget.task.phenomenonId);
    final r = result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Markieren Sie im Text alle Formen: ${phenomenon?.label}.",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ExamPassageText(
          passage: widget.passage,
          selected: selected,
          onTapWord: r != null
              ? null
              : (i) => setState(() {
                  if (!selected.remove(i)) selected.add(i);
                }),
          wordColor: r == null
              ? null
              : (i) => r.found.contains(i)
                    ? colors.success
                    : r.wrong.contains(i) || r.missed.contains(i)
                    ? colors.error
                    : null,
        ),
        const SizedBox(height: 8),
        if (r == null)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey("check-find-forms"),
              onPressed: () => setState(() {
                result = ExamAnswerCheck.checkFindForms(widget.task, selected);
              }),
              child: const Text("Prüfen"),
            ),
          )
        else ...[
          Text(
            "Gefunden: ${r.found.length} von ${widget.task.targets.length}"
            "${r.wrong.isEmpty ? "" : " · falsch markiert: ${r.wrong.length}"}",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: r.missed.isEmpty && r.wrong.isEmpty
                  ? colors.success
                  : colors.error,
            ),
          ),
          if (r.missed.isNotEmpty)
            Text(
              "Übersehen: ${r.missed.map((i) => widget.passage.tokens[i].word).join(", ")}",
            ),
          if (widget.task.tolerated.isNotEmpty)
            Text(
              "Nicht gewertet (nur nach einer anderen möglichen Bestimmung "
              "dazugehörig): "
              "${widget.task.tolerated.map((i) => widget.passage.tokens[i].word).join(", ")}",
              style: TextStyle(color: colors.textSecondary),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                result = null;
                selected.clear();
              }),
              child: const Text("Nochmal"),
            ),
          ),
        ],
      ],
    );
  }
}
