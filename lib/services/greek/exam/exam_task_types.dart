import 'dart:math';

import '../../../models/greek/exam/corpus_token.dart';
import '../../../models/greek/exam/greek_exam.dart';
import 'grammar_phenomena.dart';
import 'phenomenon_detection.dart';
import 'greek_form_key.dart';
import 'syntax_rules.dart';
import 'vocabulary_help.dart';

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

/// Zentrale Liste der Aufgabenarten. Aufgaben 3 und 4 sind austauschbar.
///
/// Die Formate folgen den Übungstexten und Eingangsklausuren des Kurses
/// (Aufgabe 3/4 dort: Genitivus absolutus bzw. PC im Text kennzeichnen,
/// „Nennen Sie den Namen der Konstruktion nach …“, Kasusfunktion nach
/// Präposition, Steigerungsformen). Aufgaben, die eine frei formulierte
/// Erklärung verlangen (Akzentsetzung, Kongruenz), lassen sich nicht
/// automatisch prüfen und fehlen deshalb. Eine weitere Art braucht nur
/// einen Eintrag in [extra].
class ExamTaskTypes {
  ExamTaskTypes._();

  static const ExamTaskType verbParsing = VerbParsingTaskType();

  /// Wählbar für Aufgabe 3 und 4.
  static const List<ExamTaskType> extra = [
    ConstructionMarkingTaskType(),
    ConstructionNamingTaskType(),
    PrepositionCaseTaskType(),
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
          !VocabularyHelpBuilder.isCapitalized(token.readings.first.lemma))
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

// -----------------------------------------------------------------------------
// KONSTRUKTIONEN (AUFGABE 3/4 DER KURSKLAUSUREN)
// -----------------------------------------------------------------------------

/// Eine Satzkonstruktion, wie sie die Klausuren des Kurses abfragen. Die
/// Regel des Phänomens liefert alle beteiligten Formen; gefragt wird nach
/// der Kernform ([isCore]: das Partizip bzw. der Infinitiv), die übrigen
/// (Bezugswort, Artikel, regierendes Verb) gehören zur Auflösung.
class ExamConstruction {
  final String phenomenonId;

  /// Name der Konstruktion (Antwort der Aufgabe „Konstruktion benennen“).
  final String name;

  /// Arbeitsanweisung der Aufgabe „Konstruktion im Text markieren“.
  final String marking;

  /// Was die übrigen Belegformen sind.
  final String companions;

  final bool Function(LemmaAnalysis) isCore;

  /// Eigene Regel für Konstruktionen, die kein Filter des Katalogs sind
  /// (AcP); sonst gilt die Regel des Phänomens [phenomenonId].
  final List<int> Function(DetectionView)? rule;

  /// Wie viele der nächststehenden übrigen Belegformen die Auflösung nennt.
  final int relatedCount;

  const ExamConstruction({
    required this.phenomenonId,
    required this.name,
    required this.marking,
    required this.companions,
    required this.isCore,
    this.rule,
    this.relatedCount = 1,
  });

  static bool _participle(LemmaAnalysis a) => a.analysis.isParticiple;
  static bool _infinitive(LemmaAnalysis a) => a.analysis.isInfinitive;

  /// In der Reihenfolge des Vorrangs: Eine Form zählt zur ersten
  /// Konstruktion, deren Regel sie trifft (δεῖ αὐτὸν παθεῖν ist AcI, nicht
  /// bloß Infinitiv als Ergänzung).
  static const List<ExamConstruction> all = [
    ExamConstruction(
      phenomenonId: "syntax.genitive_absolute",
      name: "Genitivus absolutus",
      marking:
          "Markieren Sie das Partizip jedes Genitivus absolutus im Text.",
      companions: "Bezugswort im Genitiv",
      isCore: _participle,
    ),
    ExamConstruction(
      phenomenonId: "syntax.periphrastic",
      name: "Umschreibung mit εἰμί",
      marking:
          "Markieren Sie die Partizipien, die mit einer Form von εἰμί eine "
          "Umschreibung bilden.",
      companions: "Form von εἰμί",
      isCore: _participle,
    ),
    ExamConstruction(
      phenomenonId: "syntax.articular_participle",
      name: "Partizip mit Artikel (attributiv/substantiviert)",
      marking:
          "Markieren Sie alle Partizipien mit Artikel (attributiv oder "
          "substantiviert gebraucht).",
      companions: "Artikel",
      isCore: _participle,
    ),
    ExamConstruction(
      phenomenonId: "syntax.acp",
      name: "AcP (Akkusativ mit Partizip)",
      marking:
          "Markieren Sie die Partizipien, die zu einem AcP gehören (nach "
          "einem Verb der Wahrnehmung oder des Findens).",
      companions: "Akkusativ und auslösendes Verb",
      isCore: _participle,
      rule: SyntaxRules.accusativeWithParticiple,
      relatedCount: 2,
    ),
    ExamConstruction(
      phenomenonId: "syntax.participium_coniunctum",
      name: "Participium coniunctum",
      marking:
          "Markieren Sie alle Participia coniuncta (adverbial gebrauchte "
          "Partizipien mit Bezugswort im Satz).",
      companions: "Bezugswort bzw. Prädikat",
      isCore: _participle,
    ),
    ExamConstruction(
      phenomenonId: "syntax.aci",
      name: "AcI",
      marking: "Markieren Sie die Infinitive, die zu einem AcI gehören.",
      companions: "Subjektsakkusativ und regierendes Verb",
      isCore: _infinitive,
      relatedCount: 2,
    ),
    ExamConstruction(
      phenomenonId: "syntax.articular_infinitive",
      name: "Substantivierter Infinitiv",
      marking:
          "Markieren Sie alle substantivierten Infinitive (Infinitiv mit "
          "Artikel).",
      companions: "Artikel",
      isCore: _infinitive,
    ),
    ExamConstruction(
      phenomenonId: "syntax.complementary_infinitive",
      name: "Infinitiv als Ergänzung (ohne eigenes Subjekt)",
      marking:
          "Markieren Sie die Infinitive, die ein Verb wie δύναμαι, θέλω "
          "oder μέλλω ergänzen.",
      companions: "regierendes Verb",
      isCore: _infinitive,
    ),
  ];

  static List<String> get names => [for (final c in all) c.name];
}

/// Die Belege einer Konstruktion im Text.
class _ConstructionHits {
  final ExamConstruction construction;

  /// Kernformen (sicher erkannt), ohne Formen einer vorrangigen Konstruktion.
  final List<int> cores;

  /// Übrige Belegformen (sicher erkannt).
  final Set<int> companions;

  /// Formen, die nur nach einer anderen möglichen Bestimmung dazugehören.
  final Set<int> possible;

  const _ConstructionHits(
    this.construction,
    this.cores,
    this.companions,
    this.possible,
  );
}

List<_ConstructionHits> _constructionsIn(ExamTaskContext context) {
  final passage = context.passage;
  final result = <_ConstructionHits>[];
  final taken = <int>{};

  List<int> detect(PhenomenonDetector detector, DetectionMode mode) {
    final hits = <int>{};

    for (final (v, verse) in passage.verses.indexed) {
      for (final i in detector.detect(
        DetectionView(verse.tokens, mode, context: context.detection),
      )) {
        hits.add(passage.verseOffsets[v] + i);
      }
    }

    return hits.toList()..sort();
  }

  for (final construction in ExamConstruction.all) {
    final rule = construction.rule;
    final detector = rule != null
        ? RuleDetector(rule)
        : GrammarPhenomena.byId(construction.phenomenonId)?.detector;
    if (detector == null) continue;

    final certain = detect(detector, DetectionMode.certain);

    final cores = [
      for (final i in certain)
        if (!taken.contains(i) &&
            passage.tokens[i].readings.every(construction.isCore))
          i,
    ];

    if (cores.isEmpty) continue;

    final possible = detect(detector, DetectionMode.possible);

    taken.addAll(cores);

    result.add(
      _ConstructionHits(
        construction,
        cores,
        certain.toSet().difference(cores.toSet()),
        possible.toSet().difference(certain.toSet()),
      ),
    );
  }

  return result;
}

/// Aufgabe „Konstruktion im Text markieren“ (Klausuren: „Zum einzigen im
/// Text enthaltenen Gen. abs.: Unterstreichen Sie das Partizip …“,
/// „Klammern Sie die PCs ein“).
class ConstructionMarkingTaskType extends ExamTaskType {
  const ConstructionMarkingTaskType();

  @override
  String get id => "construction_marking";

  @override
  String get label => "Konstruktion im Text markieren";

  @override
  String get description =>
      "Genitivus absolutus, Participium coniunctum, AcI oder einen "
      "substantivierten Infinitiv im Text kennzeichnen (regelbasiert "
      "erkannt; Bezugswörter nennt die Auswertung).";

  @override
  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous}) {
    final options = [
      for (final hits in _constructionsIn(context))
        if (hits.cores.length <= 8 &&
            !(previous is FindFormsTask &&
                previous.phenomenonId == hits.construction.phenomenonId))
          hits,
    ];

    if (options.isEmpty) return null;

    final chosen = options[random.nextInt(options.length)];

    return FindFormsTask(
      typeId: id,
      phenomenonId: chosen.construction.phenomenonId,
      targets: chosen.cores.toSet(),
      tolerated: {...chosen.companions, ...chosen.possible},
      instruction: chosen.construction.marking,
      toleratedNote: chosen.companions.isEmpty
          ? null
          : "Dazu gehören (${chosen.construction.companions}, nicht gewertet)",
    );
  }
}

/// Aufgabe „Konstruktion benennen“ (Klausuren: „Nennen Sie den Namen der
/// Konstruktion nach δεῖ in Zeile 6.“).
class ConstructionNamingTaskType extends ExamTaskType {
  const ConstructionNamingTaskType();

  static const int itemCount = 4;

  @override
  String get id => "construction_naming";

  @override
  String get label => "Konstruktion benennen";

  @override
  String get description =>
      "Zu ausgewählten Partizipien und Infinitiven des Textes die "
      "Konstruktion nennen (Genitivus absolutus, PC, AcI, substantivierter "
      "Infinitiv …).";

  @override
  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous}) {
    final passage = context.passage;
    final nameOf = <int, _ConstructionHits>{};

    for (final hits in _constructionsIn(context)) {
      for (final i in hits.cores) {
        nameOf[i] = hits;
      }
    }

    final before = previous is ChoiceTask
        ? {for (final item in previous.items) item.tokenIndex}
        : <int>{};

    if (nameOf.isEmpty) return null;
    if (before.isNotEmpty && nameOf.keys.every(before.contains)) return null;

    final chosen = _sample(
      nameOf.keys.toList()..sort(),
      itemCount,
      random,
      (i) => nameOf[i]!.construction.name,
      avoid: before,
    );

    return ChoiceTask(
      typeId: id,
      instruction:
          "Nennen Sie die Konstruktion, zu der die markierte Form gehört.",
      items: [
        for (final i in chosen)
          ChoiceItem(
            tokenIndex: i,
            question:
                "Welche Konstruktion liegt bei ${passage.tokens[i].word} vor?",
            options: ExamConstruction.names,
            answer: nameOf[i]!.construction.name,
            // Die nächststehenden übrigen Belegformen der Konstruktion.
            related:
                ((nameOf[i]!.companions.where((k) => (k - i).abs() <= 8).toList()
                      ..sort((a, b) => (a - i).abs().compareTo((b - i).abs())))
                    .take(nameOf[i]!.construction.relatedCount)
                    .toList()
                  ..sort()),
            explanation: nameOf[i]!.construction.companions,
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// KASUS NACH PRÄPOSITION
// -----------------------------------------------------------------------------

/// Aufgabe „Kasus nach Präposition“ (Klausuren: „Um welche Kasusfunktion
/// handelt es sich bei ὑπὸ ταύτης τῆς θυσίας?“ – Genitivus auctoris).
class PrepositionCaseTaskType extends ExamTaskType {
  const PrepositionCaseTaskType();

  static const int itemCount = 4;

  static const Map<String, String> cases = {
    "G": "Genitiv",
    "D": "Dativ",
    "A": "Akkusativ",
  };

  @override
  String get id => "preposition_case";

  @override
  String get label => "Kasus nach Präposition";

  @override
  String get description =>
      "Zu Präpositionen des Textes den regierten Kasus bestimmen; bei ὑπό "
      "mit Genitiv beim Passiv nennt die Auflösung den Genitivus auctoris.";

  static final LemmaSet _multiCase = LemmaSet(const [
    "διά", "κατά", "μετά", "περί", "ὑπέρ", "ὑπό", "παρά", "ἐπί", "πρός",
  ]);

  static bool _isPassive(LemmaAnalysis a) =>
      a.analysis.isVerb &&
      (a.analysis.voice == "P" || a.analysis.voice == "E");

  @override
  ExamTask? create(ExamTaskContext context, Random random, {ExamTask? previous}) {
    final passage = context.passage;
    final items = <int, ChoiceItem>{};

    for (final (v, verse) in passage.verses.indexed) {
      final offset = passage.verseOffsets[v];
      final view = DetectionView(
        verse.tokens,
        DetectionMode.certain,
        context: context.detection,
      );

      for (final MapEntry(key: code, value: name) in cases.entries) {
        final hits = SyntaxRules.prepositionWithCase(code)(view);

        // Die Regel liefert Paare (Präposition, regierte Form).
        for (var h = 0; h + 1 < hits.length; h += 2) {
          final preposition = verse.tokens[hits[h]];
          final lemma = preposition.certainLemma;
          if (lemma == null) continue;

          final (start, end) = view.sentenceOf(hits[h]);
          final agent =
              greekFormKey(lemma) == greekFormKey("ὑπό") &&
              code == "G" &&
              [
                for (var k = start; k <= end; k++) k,
              ].any((k) => view.holds(k, _isPassive));

          items[offset + hits[h]] = ChoiceItem(
            tokenIndex: offset + hits[h],
            question: "Welchen Kasus regiert ${preposition.word} hier?",
            options: cases.values.toList(),
            answer: name,
            related: [offset + hits[h + 1]],
            explanation: agent
                ? "ὑπό mit Genitiv beim Passiv: Urheber der Handlung "
                      "(Genitivus auctoris)"
                : "$lemma mit $name",
          );
        }
      }
    }

    final before = previous is ChoiceTask
        ? {for (final item in previous.items) item.tokenIndex}
        : <int>{};

    if (items.isEmpty) return null;
    if (before.isNotEmpty && items.keys.every(before.contains)) return null;

    bool multiCase(int i) =>
        _multiCase.contains(passage.tokens[i].certainLemma ?? "");

    // Präpositionen mit mehreren Kasus zuerst: nur dort ist der Kasus eine
    // echte Frage.
    final preferred = items.keys.where(multiCase).toList()..sort();
    final fresh = preferred.where((i) => !before.contains(i)).length;

    final chosen = _sample(
      fresh >= 2 ? preferred : (items.keys.toList()..sort()),
      itemCount,
      random,
      (i) => passage.tokens[i].certainLemma ?? "",
      avoid: before,
    );

    return ChoiceTask(
      typeId: id,
      instruction:
          "Bestimmen Sie den Kasus, den die markierte Präposition regiert.",
      items: [for (final i in chosen) items[i]!],
    );
  }
}
