import 'package:flutter/material.dart';

import '../../../info/app_info.dart';
import '../../../services/latin/grammar/latin_grammar_words.dart';
import '../../../services/latin/grammar/latin_morphology.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/grammar_overview_widgets.dart';

/// Bausteine der lateinischen Grammatikübersicht. Die Tabellen werden aus
/// denselben Paradigmen erzeugt, die der Grammatiktrainer abfragt; Übersicht
/// und Trainer können deshalb nicht auseinanderlaufen.

LatinNoun latinNoun(String id) =>
    LatinGrammarWords.nouns.firstWhere((noun) => noun.id == id);

LatinAdjective latinAdjective(String id) =>
    LatinGrammarWords.adjectives.firstWhere((adj) => adj.id == id);

LatinPronoun latinPronoun(String id) =>
    LatinGrammarWords.pronouns.firstWhere((pronoun) => pronoun.id == id);

LatinVerb latinVerb(String id) =>
    LatinGrammarWords.verbs.firstWhere((verb) => verb.id == id);

/// Themenseite der lateinischen Grammatikübersicht.
class LatinTopicScaffold extends StatelessWidget {
  final String title;

  /// Wo das Thema im Lehrgang steht (z. B. „Wortschatz ab Lektion 1“).
  final String stage;

  final List<Widget> children;

  const LatinTopicScaffold({
    super.key,
    required this.title,
    required this.stage,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GrammarTopicScaffold(
      title: title,
      module: AppModules.latinGrammarOverview,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(Icons.menu_book_rounded, size: 18),
              label: Text(stage),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

enum _CalloutKind { rule, exception, tip }

/// Hervorgehobene Regel, Ausnahme oder Merkhilfe.
class LatinCallout extends StatelessWidget {
  final String text;
  final _CalloutKind _kind;

  const LatinCallout.rule(this.text, {super.key}) : _kind = _CalloutKind.rule;

  const LatinCallout.exception(this.text, {super.key})
    : _kind = _CalloutKind.exception;

  const LatinCallout.tip(this.text, {super.key}) : _kind = _CalloutKind.tip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (label, icon, color) = switch (_kind) {
      _CalloutKind.rule => ("Regel", Icons.rule_rounded, colors.primary),
      _CalloutKind.exception => (
        "Ausnahme",
        Icons.error_outline_rounded,
        colors.error,
      ),
      _CalloutKind.tip => ("Merkhilfe", Icons.lightbulb_outline, colors.accent),
    };

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lateinisches Beispiel mit Übersetzung.
class LatinExample extends StatelessWidget {
  final String latin;
  final String german;
  final String? note;

  const LatinExample(this.latin, this.german, {super.key, this.note});

  @override
  Widget build(BuildContext context) {
    final note = this.note;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latin,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Text(
            german,
            style: TextStyle(fontSize: 15, color: context.colors.textSecondary),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mehrere Beispiele unter einer Überschrift „Beispiele“.
class LatinExamples extends StatelessWidget {
  final List<LatinExample> examples;

  const LatinExamples(this.examples, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            examples.length == 1 ? "Beispiel" : "Beispiele",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ...examples,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TABELLEN
// ---------------------------------------------------------------------------

/// Kasus-Tabelle mehrerer Substantive (eine Spalte je Wort).
class LatinNounTable extends StatelessWidget {
  final List<LatinNoun> nouns;
  final bool vocative;

  const LatinNounTable(this.nouns, {super.key, this.vocative = false});

  @override
  Widget build(BuildContext context) {
    final paradigms = [for (final noun in nouns) noun.paradigm()];
    final cases = vocative ? LatinCases.all : LatinCases.withoutVocative;

    final rows = <List<Widget>>[];
    final headerRows = <int>{};

    for (final number in LatinNumbers.all) {
      headerRows.add(rows.length);
      rows.add([
        GrammarCell.header(number),
        for (final noun in nouns)
          GrammarCell.header(
            number == LatinNumbers.singular ? noun.dictionaryForm : "",
          ),
      ]);

      for (final c in cases) {
        rows.add([
          GrammarCell.label(LatinCases.short[c]!),
          for (final paradigm in paradigms)
            GrammarCell.form(
              paradigm.formsOf(NominalAnalysis(c, number)).join(" / "),
            ),
        ]);
      }
    }

    return GrammarTable(rows: rows, headerRows: headerRows);
  }
}

/// Dreigeschlechtige Tabelle (Adjektiv bzw. Pronomen mit Genus).
class LatinGenderTable extends StatelessWidget {
  final Paradigm<NominalAnalysis> paradigm;

  const LatinGenderTable(this.paradigm, {super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[];
    final headerRows = <int>{};

    for (final number in LatinNumbers.all) {
      headerRows.add(rows.length);
      rows.add([
        GrammarCell.header(number),
        for (final g in LatinGenders.all)
          GrammarCell.header(LatinGenders.short[g]!),
      ]);

      for (final c in LatinCases.withoutVocative) {
        rows.add([
          GrammarCell.label(LatinCases.short[c]!),
          for (final g in LatinGenders.all)
            GrammarCell.form(
              _orDash(paradigm.formsOf(NominalAnalysis(c, number, g))),
            ),
        ]);
      }
    }

    return GrammarTable(rows: rows, headerRows: headerRows);
  }
}

/// Pronomen ohne Genus (ego, tū, sē): Singular und Plural nebeneinander.
class LatinPersonalPronounTable extends StatelessWidget {
  final List<LatinPronoun> pronouns;

  const LatinPersonalPronounTable(this.pronouns, {super.key});

  @override
  Widget build(BuildContext context) {
    final paradigms = [for (final p in pronouns) p.paradigm()];

    return GrammarTable(
      rows: [
        [
          const GrammarCell.header(""),
          for (final p in pronouns) ...[
            GrammarCell.header("${p.label} Sg."),
            GrammarCell.header("Pl."),
          ],
        ],
        for (final c in LatinCases.withoutVocative)
          [
            GrammarCell.label(LatinCases.short[c]!),
            for (final paradigm in paradigms) ...[
              GrammarCell.form(
                _orDash(
                  paradigm.formsOf(NominalAnalysis(c, LatinNumbers.singular)),
                ),
              ),
              GrammarCell.form(
                _orDash(
                  paradigm.formsOf(NominalAnalysis(c, LatinNumbers.plural)),
                ),
              ),
            ],
          ],
      ],
    );
  }
}

/// Personalformen mehrerer Verben in einem Tempus/Modus/Genus verbi.
class LatinVerbTable extends StatelessWidget {
  final List<LatinVerb> verbs;
  final String mood;
  final String tense;
  final String voice;

  /// Spaltenüberschrift: Konjugation statt Infinitiv.
  final bool showConjugation;

  const LatinVerbTable({
    super.key,
    required this.verbs,
    this.mood = LatinMoods.indicative,
    required this.tense,
    this.voice = LatinVoices.active,
    this.showConjugation = false,
  });

  @override
  Widget build(BuildContext context) {
    final paradigms = [for (final verb in verbs) verb.paradigm()];
    final persons = mood == LatinMoods.imperative
        ? LatinPersons.imperative
        : LatinPersons.all;

    return GrammarTable(
      rows: [
        [
          const GrammarCell.header(""),
          for (final verb in verbs)
            GrammarCell.header(
              showConjugation
                  ? "${verb.infinitive}\n(${verb.conjugation.label})"
                  : verb.infinitive,
            ),
        ],
        for (final person in persons)
          [
            GrammarCell.label(person),
            for (final paradigm in paradigms)
              GrammarCell.form(
                _orDash(
                  paradigm.formsOf(VerbAnalysis(mood, tense, voice, person)),
                ),
              ),
          ],
      ],
    );
  }
}

/// Infinitive mehrerer Verben (Präsens/Perfekt, Aktiv/Passiv).
class LatinInfinitiveTable extends StatelessWidget {
  final List<LatinVerb> verbs;

  const LatinInfinitiveTable(this.verbs, {super.key});

  @override
  Widget build(BuildContext context) {
    final paradigms = [for (final verb in verbs) verb.paradigm()];

    const rows = [
      ("Präsens Aktiv", LatinTenses.present, LatinVoices.active),
      ("Präsens Passiv", LatinTenses.present, LatinVoices.passive),
      ("Perfekt Aktiv", LatinTenses.perfect, LatinVoices.active),
    ];

    return GrammarTable(
      rows: [
        [
          const GrammarCell.header("Infinitiv"),
          for (final verb in verbs) GrammarCell.header(verb.infinitive),
        ],
        for (final (label, tense, voice) in rows)
          [
            GrammarCell.label(label),
            for (final paradigm in paradigms)
              GrammarCell.form(
                _orDash(
                  paradigm.formsOf(
                    VerbAnalysis(LatinMoods.infinitive, tense, voice),
                  ),
                ),
              ),
          ],
      ],
    );
  }
}

/// Einfache Tabelle aus Texten; erste Zeile = Überschrift. Spalten mit
/// lateinischen Formen werden über [formColumns] hervorgehoben.
class LatinTextTable extends StatelessWidget {
  final List<List<String>> rows;
  final Set<int> formColumns;

  const LatinTextTable(this.rows, {super.key, this.formColumns = const {}});

  @override
  Widget build(BuildContext context) {
    return GrammarTable(
      rows: [
        [for (final cell in rows.first) GrammarCell.header(cell)],
        for (final row in rows.skip(1))
          [
            for (var i = 0; i < row.length; i++)
              if (formColumns.contains(i))
                GrammarCell.form(row[i])
              else if (i == 0)
                GrammarCell.label(row[i])
              else
                GrammarCell.text(row[i]),
          ],
      ],
    );
  }
}

String _orDash(List<String> forms) => forms.isEmpty ? "–" : forms.join(" / ");
