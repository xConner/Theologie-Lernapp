import 'dart:math';

import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/exam/greek_exam.dart';
import 'grammar_phenomena.dart';
import 'phenomenon_detection.dart';

/// Erkennt ein Phänomen im Text eines Abschnitts, versweise wie im
/// Korpusindex. Ergebnis: Indizes in [ExamPassage.tokens].
List<int> detectInPassage(
  ExamPassage passage,
  GrammarPhenomenon phenomenon,
  DetectionMode mode,
  DetectionContext context,
) {
  final detector = phenomenon.detector;
  if (detector == null) return const [];

  final hits = <int>{};

  for (final (v, verse) in passage.verses.indexed) {
    final offset = passage.verseOffsets[v];

    for (final i in detector.detect(
      DetectionView(verse.tokens, mode, context: context),
    )) {
      hits.add(offset + i);
    }
  }

  return hits.toList()..sort();
}

/// Was eine Aufgabenart zum Erzeugen braucht.
class ExamTaskContext {
  final ExamPassage passage;
  final DetectionContext detection;

  /// Anzahl der Formen (Aufgabe 2: Verben).
  final int count;

  const ExamTaskContext({
    required this.passage,
    required this.detection,
    this.count = 4,
  });
}

/// Eine Aufgabenart. Jede Art erzeugt ihre Aufgabe aus dem Text; mit
/// [previous] eine andere als die bisherige. `null`, wenn der Text keine
/// (weitere) Aufgabe dieser Art hergibt.
abstract class ExamTaskType {
  const ExamTaskType();

  String get id;
  String get label;
  String get description;

  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous});
}

/// Zentrale Liste der Aufgabenarten. Aufgaben 3 und 4 sind austauschbar;
/// weitere Arten (z. B. nach den Griechisch-I-Abschlussklausuren) kommen
/// hier hinzu und erscheinen dann in der Auswahl.
class ExamTaskTypes {
  ExamTaskTypes._();

  static const ExamTaskType verbParsing = VerbParsingTaskType();

  /// Wählbar für Aufgabe 3 und 4.
  static const List<ExamTaskType> extra = [
    FindFormsTaskType(),
    NounParsingTaskType(),
  ];

  static ExamTaskType? byId(String id) {
    if (id == verbParsing.id) return verbParsing;
    for (final type in extra) {
      if (type.id == id) return type;
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// HILFEN
// -----------------------------------------------------------------------------

/// Bestimmungen einer Form, die für die Aufgabe gelten: im Kontext bestimmt
/// die Kontextbestimmung zuerst, dazu alle formal möglichen Bestimmungen
/// derselben Form, die [keep] erfüllen.
List<LemmaAnalysis> _accepted(
  CorpusToken token,
  bool Function(LemmaAnalysis) keep,
) {
  final context = token.contextual;

  return [
    ?context,
    for (final a in token.analyses)
      if (a != context && keep(a)) a,
  ];
}

/// Zieht bis zu [count] Formen aus [candidates], bevorzugt verschiedene
/// Grundformen und Formen außerhalb von [avoid]; Ergebnis in Textfolge.
List<int> _sample(
  List<int> candidates,
  int count,
  Random random,
  String Function(int) lemmaOf, {
  Set<int> avoid = const {},
}) {
  final fresh = candidates.where((i) => !avoid.contains(i)).toList()
    ..shuffle(random);
  final old = candidates.where(avoid.contains).toList()..shuffle(random);

  final chosen = <int>[];
  final lemmas = <String>{};

  // Erst neue Formen mit neuen Grundformen, dann neue Formen, dann alte.
  for (final pass in [
    (List<int> list) => list.where((i) => !lemmas.contains(lemmaOf(i))),
    (List<int> list) => list,
  ]) {
    for (final pool in [fresh, old]) {
      for (final i in pass(pool).toList()) {
        if (chosen.length >= count) break;
        if (chosen.contains(i)) continue;
        chosen.add(i);
        lemmas.add(lemmaOf(i));
      }
    }
  }

  return chosen..sort();
}

// -----------------------------------------------------------------------------
// AUFGABE 2: VERBFORMEN BESTIMMEN
// -----------------------------------------------------------------------------

class VerbParsingTaskType extends ExamTaskType {
  const VerbParsingTaskType();

  @override
  String get id => "verb_parsing";

  @override
  String get label => "Verbformen bestimmen";

  @override
  String get description =>
      "Grundform, Modus bzw. Formtyp, Tempus, Genus Verbi sowie Person und "
      "Numerus bzw. Kasus, Numerus und Genus ausgewählter Verbformen.";

  static bool _isVerb(LemmaAnalysis a) => a.analysis.isVerb;

  /// Formen, deren mögliche Bestimmungen alle Verbformen sind.
  static List<int> candidates(ExamPassage passage) => [
    for (final (i, token) in passage.tokens.indexed)
      if (token.isAnalyzed &&
          token.reliability != AnalysisReliability.properNameGuess &&
          token.readings.isNotEmpty &&
          token.readings.every(_isVerb))
        i,
  ];

  @override
  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous}) {
    final passage = context.passage;
    final all = candidates(passage);
    final before = previous is VerbParsingTask
        ? {for (final item in previous.items) item.tokenIndex}
        : <int>{};

    if (all.isEmpty) return null;
    if (before.isNotEmpty && all.every(before.contains)) return null;

    final chosen = _sample(
      all,
      context.count,
      random,
      (i) => passage.tokens[i].readings.first.lemma,
      avoid: before,
    );

    return VerbParsingTask([
      for (final i in chosen)
        ParsingItem(
          tokenIndex: i,
          token: passage.tokens[i],
          context: passage.tokens[i].contextual,
          accepted: _accepted(passage.tokens[i], _isVerb),
        ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// FORMEN IM TEXT FINDEN
// -----------------------------------------------------------------------------

class FindFormsTaskType extends ExamTaskType {
  const FindFormsTaskType();

  @override
  String get id => "find_forms";

  @override
  String get label => "Formen im Text finden";

  @override
  String get description =>
      "Alle Formen einer grammatischen Kategorie im Text markieren (z. B. "
      "alle Partizipien, alle Aoristformen, alle Relativpronomen). Nur "
      "Kategorien, die sicher aus der Bestimmung hervorgehen.";

  /// Kategorien, die sich als Suchaufgabe eignen (nicht zu allgemein wie
  /// „Indikativ“ oder „3. Person“).
  static const List<String> phenomena = [
    "verb.mood.subjunctive",
    "verb.mood.optative",
    "verb.mood.imperative",
    "verb.mood.infinitive",
    "verb.mood.participle",
    "verb.tense.imperfect",
    "verb.tense.future",
    "verb.tense.aorist",
    "verb.tense.perfect",
    "verb.tense.pluperfect",
    "verb.voice.passive",
    "verb.aorist.passive",
    "verb.lemma.eimi",
    "verb.class.mi",
    "verb.class.contract",
    "adjective.comparative",
    "adjective.superlative",
    "numeral",
    "pronoun.personal",
    "pronoun.demonstrative",
    "pronoun.relative",
    "pronoun.interrogative",
    "pronoun.indefinite",
    "pronoun.reflexive",
    "pronoun.possessive",
    "case.vocative",
  ];

  @override
  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous}) {
    final options = <FindFormsTask>[];

    for (final id in phenomena) {
      if (previous is FindFormsTask && previous.phenomenonId == id) continue;

      final phenomenon = GrammarPhenomena.byId(id);
      if (phenomenon == null ||
          phenomenon.status != PhenomenonStatus.reliable ||
          !phenomenon.findable) {
        continue;
      }

      final certain = detectInPassage(
        context.passage,
        phenomenon,
        DetectionMode.certain,
        context.detection,
      ).toSet();

      if (certain.isEmpty || certain.length > 12) continue;

      final possible = detectInPassage(
        context.passage,
        phenomenon,
        DetectionMode.possible,
        context.detection,
      ).toSet();

      options.add(
        FindFormsTask(
          phenomenonId: id,
          targets: certain,
          tolerated: possible.difference(certain),
        ),
      );
    }

    if (options.isEmpty) return null;

    // Kategorien mit zwei bis acht Belegen bevorzugen.
    final preferred = options
        .where((o) => o.targets.length >= 2 && o.targets.length <= 8)
        .toList();
    final pool = preferred.isNotEmpty ? preferred : options;

    return pool[random.nextInt(pool.length)];
  }
}

// -----------------------------------------------------------------------------
// NOMINALFORMEN BESTIMMEN
// -----------------------------------------------------------------------------

class NounParsingTaskType extends ExamTaskType {
  const NounParsingTaskType();

  static const int itemCount = 4;

  @override
  String get id => "noun_parsing";

  @override
  String get label => "Nominalformen bestimmen";

  @override
  String get description =>
      "Grundform, Kasus, Numerus und Genus ausgewählter Nomen, Adjektive und "
      "Pronomen (wie im Grammatiktrainer).";

  static bool _isNominal(LemmaAnalysis a) =>
      const {"N-", "A-", "RP", "RD", "RR", "RI"}.contains(a.analysis.pos) &&
      a.analysis.grammaticalCase != "-" &&
      a.analysis.number != "-";

  static List<int> candidates(ExamPassage passage) => [
    for (final (i, token) in passage.tokens.indexed)
      if (token.isAnalyzed &&
          token.reliability != AnalysisReliability.properNameGuess &&
          token.readings.isNotEmpty &&
          token.readings.every(_isNominal) &&
          // Eigennamen (oft indeklinabel) nicht abfragen.
          !RegExp(r'^\p{Lu}', unicode: true)
              .hasMatch(token.readings.first.lemma))
        i,
  ];

  @override
  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous}) {
    final passage = context.passage;
    final all = candidates(passage);
    final before = previous is NounParsingTask
        ? {for (final item in previous.items) item.tokenIndex}
        : <int>{};

    if (all.isEmpty) return null;
    if (before.isNotEmpty && all.every(before.contains)) return null;

    // Nomen vor Pronomen und Adjektiven.
    final nouns = all
        .where((i) => passage.tokens[i].readings.first.analysis.pos == "N-")
        .toList();

    final freshNouns = nouns.where((i) => !before.contains(i)).length;

    final chosen = _sample(
      freshNouns >= itemCount ? nouns : all,
      itemCount,
      random,
      (i) => passage.tokens[i].readings.first.lemma,
      avoid: before,
    );

    return NounParsingTask([
      for (final i in chosen)
        ParsingItem(
          tokenIndex: i,
          token: passage.tokens[i],
          context: passage.tokens[i].contextual,
          accepted: _accepted(passage.tokens[i], _isNominal),
        ),
    ]);
  }
}
