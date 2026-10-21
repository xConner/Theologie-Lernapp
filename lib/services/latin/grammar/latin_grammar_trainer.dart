import 'dart:math';

import '../../../algorithms/grammar_learning.dart';
import '../../../algorithms/learning_selector.dart';
import 'latin_grammar_answer_check.dart';
import 'latin_grammar_words.dart';
import 'latin_morphology.dart';

// ---------------------------------------------------------------------------
// THEMEN
// ---------------------------------------------------------------------------

class LatinTrainerTopic {
  final String id;
  final String title;
  final String description;

  /// Formen bestimmen; sonst Auswahlaufgabe.
  final bool morphology;

  const LatinTrainerTopic({
    required this.id,
    required this.title,
    required this.description,
    this.morphology = true,
  });
}

/// Themen des Trainers in der Reihenfolge des Lehrgangs.
class LatinTrainerTopics {
  LatinTrainerTopics._();

  static const String nounsAO = "nouns_ao";
  static const String nouns3 = "nouns_3";
  static const String nounsUE = "nouns_ue";
  static const String adjectives = "adjectives";
  static const String pronouns = "pronouns";
  static const String verbsPresent = "verbs_present";
  static const String verbsImperfectFuture = "verbs_imperfect_future";
  static const String verbsPerfect = "verbs_perfect";
  static const String verbsPassive = "verbs_passive";
  static const String verbsSubjunctive = "verbs_subjunctive";
  static const String prepositions = "prepositions";
  static const String syntax = "syntax";

  static const List<LatinTrainerTopic> all = [
    LatinTrainerTopic(
      id: nounsAO,
      title: "a- und o-Deklination",
      description: "domina, dominus, forum …",
    ),
    LatinTrainerTopic(
      id: nouns3,
      title: "3. Deklination",
      description: "victor, nōmen, urbs …",
    ),
    LatinTrainerTopic(
      id: verbsPresent,
      title: "Präsens, Imperativ, Infinitiv",
      description: "alle Konjugationen; esse, posse, īre, velle",
    ),
    LatinTrainerTopic(
      id: pronouns,
      title: "Pronomen",
      description: "ego, tū, sē, is, hic, ille, quī",
    ),
    LatinTrainerTopic(
      id: prepositions,
      title: "Präpositionen",
      description: "Welcher Kasus folgt?",
      morphology: false,
    ),
    LatinTrainerTopic(
      id: adjectives,
      title: "Adjektive und KNG-Kongruenz",
      description: "bonus, pulcher, fortis, fēlīx",
    ),
    LatinTrainerTopic(
      id: verbsImperfectFuture,
      title: "Imperfekt und Futur I",
      description: "Indikativ Aktiv",
    ),
    LatinTrainerTopic(
      id: verbsPerfect,
      title: "Perfekt, Plusquamperfekt, Futur II",
      description: "Indikativ Aktiv, Infinitiv Perfekt",
    ),
    LatinTrainerTopic(
      id: verbsPassive,
      title: "Passiv",
      description: "Präsens, Imperfekt, Futur I; Infinitiv Präsens Passiv",
    ),
    LatinTrainerTopic(
      id: verbsSubjunctive,
      title: "Konjunktiv",
      description: "Präsens, Imperfekt, Perfekt, Plusquamperfekt",
    ),
    LatinTrainerTopic(
      id: nounsUE,
      title: "u- und e-Deklination",
      description: "senātus, manus, rēs, diēs",
    ),
    LatinTrainerTopic(
      id: syntax,
      title: "Satzkonstruktionen erkennen",
      description: "AcI, Ablativus absolutus, Nebensätze …",
      morphology: false,
    ),
  ];

  static List<String> get ids => [for (final topic in all) topic.id];

  /// Voreinstellung: Stoff, den der Wortschatz der Lektionen 1–3 bereits
  /// voraussetzt (Nominativ/Akkusativ der a-, o- und 3. Deklination,
  /// Präsens mit esse und Imperativ, Personalpronomen, Präpositionen mit
  /// Akkusativ).
  static const List<String> defaults = [
    nounsAO,
    nouns3,
    verbsPresent,
    pronouns,
    prepositions,
  ];

  static LatinTrainerTopic byId(String id) =>
      all.firstWhere((topic) => topic.id == id);
}

// ---------------------------------------------------------------------------
// EINSTELLUNGEN
// ---------------------------------------------------------------------------

class LatinGrammarSettings {
  final List<String> enabledTopics;

  /// Abgewählte Lektionen. Abgefragt werden nur Wörter der übrigen
  /// Lektionen; gespeichert wird die Abwahl, damit später ergänzte
  /// Lektionen ohne weiteres Zutun aktiv sind. Pronomen und
  /// Satzkonstruktionen gehören zu keiner Lektion.
  final List<int> disabledLessons;

  /// Beim Bestimmen zusätzlich die Grundform eingeben.
  final bool askLemma;

  /// Vokativ als Kasus abfragen.
  final bool includeVocative;

  const LatinGrammarSettings({
    this.enabledTopics = LatinTrainerTopics.defaults,
    this.disabledLessons = const [],
    this.askLemma = false,
    this.includeVocative = false,
  });

  /// Liest gespeicherte Einstellungen; unbekannte Werte werden verworfen,
  /// fehlende gelten mit ihrem Default. Die Listen sind veränderbare
  /// Kopien.
  factory LatinGrammarSettings.fromMap(Object? data) {
    if (data is! Map) {
      return LatinGrammarSettings(
        enabledTopics: List.of(LatinTrainerTopics.defaults),
        disabledLessons: [],
      );
    }

    final topics = data["enabledTopics"];
    final lessons = data["disabledLessons"];

    bool flag(String key, bool fallback) {
      final value = data[key];
      return value is bool ? value : fallback;
    }

    return LatinGrammarSettings(
      enabledTopics: topics is List
          ? [
              for (final id in LatinTrainerTopics.ids)
                if (topics.contains(id)) id,
            ]
          : List.of(LatinTrainerTopics.defaults),
      disabledLessons: lessons is List
          ? (lessons.whereType<num>().map((n) => n.toInt()).toSet().toList()
              ..sort())
          : [],
      askLemma: flag("askLemma", false),
      includeVocative: flag("includeVocative", false),
    );
  }

  Map<String, dynamic> toMap() => {
    "enabledTopics": enabledTopics,
    "disabledLessons": disabledLessons,
    "askLemma": askLemma,
    "includeVocative": includeVocative,
  };

  LatinGrammarSettings copyWith({
    List<String>? enabledTopics,
    List<int>? disabledLessons,
    bool? askLemma,
    bool? includeVocative,
  }) {
    return LatinGrammarSettings(
      enabledTopics: enabledTopics ?? this.enabledTopics,
      disabledLessons: disabledLessons ?? this.disabledLessons,
      askLemma: askLemma ?? this.askLemma,
      includeVocative: includeVocative ?? this.includeVocative,
    );
  }

  /// Fehlermeldung, wenn mit dieser Auswahl keine Aufgabe möglich ist.
  /// [lessons] sind die Lektionen der Vokabelliste.
  String? validate(List<int> lessons) {
    if (enabledTopics.isEmpty) {
      return "Mindestens ein Thema muss ausgewählt sein.";
    }

    if (lessons.isNotEmpty && lessons.every(disabledLessons.contains)) {
      return "Mindestens eine Lektion muss ausgewählt sein.";
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// AUFGABEN
// ---------------------------------------------------------------------------

/// Eine Aufgabe des Trainers.
sealed class LatinGrammarTask {
  final String topic;

  const LatinGrammarTask(this.topic);
}

/// Wortart der nominalen Aufgaben (für Lernkarten und Anzeige).
enum NominalWordType { noun, adjective, pronoun }

/// Kasus/Numerus/Genus einer nominalen Form bestimmen.
class NominalIdentifyTask extends LatinGrammarTask {
  final NominalWordType wordType;
  final String wordId;

  /// Grundform zur Anzeige nach der Auswertung („dominus, dominī m.“).
  final String dictionaryForm;

  /// Mögliche Eingaben für die Grundform.
  final List<String> lemmas;

  final String form;
  final NominalAnalysis target;

  /// Alle für [form] möglichen Bestimmungen (mit Genus).
  final List<NominalAnalysis> analyses;

  /// Wird das Genus gefragt? (nicht bei ego, tū, sē)
  final bool askGender;

  final List<String> cases;

  /// Hinweis zur Aufgabe (bei Pronomen: welches Pronomen).
  final String? hint;

  final String explanation;

  const NominalIdentifyTask({
    required String topic,
    required this.wordType,
    required this.wordId,
    required this.dictionaryForm,
    required this.lemmas,
    required this.form,
    required this.target,
    required this.analyses,
    required this.askGender,
    required this.cases,
    this.hint,
    required this.explanation,
  }) : super(topic);
}

class VerbIdentifyTask extends LatinGrammarTask {
  final LatinVerb verb;
  final String form;
  final VerbAnalysis target;
  final List<VerbAnalysis> analyses;
  final String explanation;

  const VerbIdentifyTask({
    required String topic,
    required this.verb,
    required this.form,
    required this.target,
    required this.analyses,
    required this.explanation,
  }) : super(topic);
}

/// Auswahlaufgabe (Präposition → Kasus, Satz → Konstruktion).
class ChoiceTask extends LatinGrammarTask {
  /// Kennung für die Lernkarte (Präposition bzw. Konstruktion).
  final String itemId;
  final String prompt;
  final String question;
  final String? translation;
  final List<String> options;
  final String answer;
  final String explanation;

  const ChoiceTask({
    required String topic,
    required this.itemId,
    required this.prompt,
    required this.question,
    this.translation,
    required this.options,
    required this.answer,
    required this.explanation,
  }) : super(topic);
}

// ---------------------------------------------------------------------------
// AUFGABEN ERZEUGEN
// ---------------------------------------------------------------------------

/// Erzeugt Aufgaben nach Lernbedarf.
///
/// Gewichtet wird wie im Altgriechisch-Grammatiktrainer mit
/// [GrammarLearning]: je Thema, Wort und grammatischem Wert (Kasus Ablativ,
/// Tempus Imperfekt, 2. Pl. …) eine Karte. Schwache Werte kommen häufiger,
/// sichere seltener; Filter (Themen, Lektionen) gehen vor.
///
/// Abgefragt werden wie im Altgriechisch-Trainer nur Wörter der gewählten
/// Lektionen: Wörter mit [LatinNoun.vocabularyId] usw., deren Lektion
/// [lessonOf] nennt. Musterwörter ohne Vokabel erscheinen nur in der
/// Grammatikübersicht; Pronomen und Satzkonstruktionen gehören zu keiner
/// Lektion.
class LatinGrammarTaskGenerator {
  final GrammarLearning learning;
  final Random random;

  /// Lektion je Vokabel-ID (aus `assets/latin_vocabulary.json`).
  final Map<int, int> lessonOf;

  LatinGrammarTaskGenerator({
    required this.learning,
    Random? random,
    this.lessonOf = const {},
  }) : random = random ?? Random();

  bool _inLessons(int? vocabularyId, LatinGrammarSettings settings) {
    final lesson = vocabularyId == null ? null : lessonOf[vocabularyId];

    return lesson != null && !settings.disabledLessons.contains(lesson);
  }

  /// Karten-ID eines Worts.
  static String wordCardId(String type, String id) => "word.$type.$id";

  /// Karten-ID eines Themas.
  static String topicCardId(String topic) =>
      GrammarLearning.dimensionId("topic", "id", topic);

  /// Karten aus [ids], die allein zu [topic] gehören und beim
  /// Zurücksetzen des Themas entfernt werden: die Themenkarte, die
  /// Aufgabenarten des Themas und die Wörter, die nur in diesem Thema
  /// vorkommen. Grammatische Werte (Ablativ, 2. Pl. …) und Verben gelten
  /// themenübergreifend und bleiben.
  static Set<String> cardsOfTopic(String topic, Iterable<String> ids) {
    // Aufgabenarten: GrammarLearning.dimensionId("kind", topic, art).
    final prefixes = <String>["dim.kind.$topic."];

    final declensions = _nounDeclensions(topic);

    final wordIds = <String>{
      topicCardId(topic),
      if (declensions != null)
        for (final noun in LatinGrammarWords.nouns)
          if (declensions.contains(noun.declension))
            wordCardId("noun", noun.id),
    };

    switch (topic) {
      case LatinTrainerTopics.adjectives:
        prefixes.add(wordCardId("adjective", ""));
      case LatinTrainerTopics.pronouns:
        prefixes.add(wordCardId("pronoun", ""));
      case LatinTrainerTopics.prepositions:
        prefixes.add(wordCardId("preposition", ""));
      case LatinTrainerTopics.syntax:
        prefixes.add("syntax.");
    }

    return {
      for (final id in ids)
        if (wordIds.contains(id) || prefixes.any(id.startsWith)) id,
    };
  }

  /// Themen, für die mit den Einstellungen eine Aufgabe möglich ist.
  List<String> availableTopics(LatinGrammarSettings settings) {
    return [
      for (final id in settings.enabledTopics)
        if (_isAvailable(id, settings)) id,
    ];
  }

  bool _isAvailable(String topic, LatinGrammarSettings settings) {
    switch (topic) {
      case LatinTrainerTopics.prepositions:
        return _prepositions(settings).isNotEmpty;
      case LatinTrainerTopics.syntax:
        return LatinGrammarWords.syntaxExamples.isNotEmpty;
      case LatinTrainerTopics.adjectives:
        return _adjectives(settings).isNotEmpty;
      case LatinTrainerTopics.pronouns:
        return LatinGrammarWords.pronouns.isNotEmpty;
    }

    if (_nounDeclensions(topic) case final declensions?) {
      return _nouns(settings, declensions).isNotEmpty;
    }

    return _verbCandidates(topic, settings).isNotEmpty;
  }

  /// Nächste Aufgabe; null, wenn mit den Einstellungen nichts möglich ist.
  LatinGrammarTask? next(LatinGrammarSettings settings) {
    final topics = availableTopics(settings);

    if (topics.isEmpty) return null;

    final topic = learning.pickValue("topic", "id", topics);

    switch (topic) {
      case LatinTrainerTopics.prepositions:
        return _prepositionTask(settings);
      case LatinTrainerTopics.syntax:
        return _syntaxTask();
      case LatinTrainerTopics.adjectives:
        return _adjectiveTask(settings);
      case LatinTrainerTopics.pronouns:
        return _pronounTask(settings);
    }

    if (_nounDeclensions(topic) case final declensions?) {
      return _nounTask(topic, declensions, settings);
    }

    return _verbTask(topic, settings);
  }

  List<String> _cases(LatinGrammarSettings settings) {
    return settings.includeVocative
        ? LatinCases.all
        : LatinCases.withoutVocative;
  }

  // -- Substantive ------------------------------------------------------------

  static Set<LatinDeclension>? _nounDeclensions(String topic) {
    switch (topic) {
      case LatinTrainerTopics.nounsAO:
        return {LatinDeclension.a, LatinDeclension.o};
      case LatinTrainerTopics.nouns3:
        return {LatinDeclension.third};
      case LatinTrainerTopics.nounsUE:
        return {LatinDeclension.u, LatinDeclension.e};
    }

    return null;
  }

  List<LatinNoun> _nouns(
    LatinGrammarSettings settings,
    Set<LatinDeclension>? declensions,
  ) {
    return [
      for (final noun in LatinGrammarWords.nouns)
        if ((declensions == null || declensions.contains(noun.declension)) &&
            _inLessons(noun.vocabularyId, settings))
          noun,
    ];
  }

  /// Gruppen gleicher Deklination und gleichen Genus: Jede Gruppe kommt
  /// gleich oft vor, auch wenn sie wenige Wörter hat.
  List<List<T>> _groups<T>(List<T> items, Object Function(T) keyOf) {
    final groups = <Object, List<T>>{};

    for (final item in items) {
      groups.putIfAbsent(keyOf(item), () => []).add(item);
    }

    return groups.values.toList();
  }

  NominalAnalysis _pickNominalCell(String type, List<NominalAnalysis> cells) {
    return pickWeighted(cells, (cell) {
      final caseNeed = learning.need(
        GrammarLearning.dimensionId(type, "case", cell.grammaticalCase),
      );
      final numberNeed = learning.need(
        GrammarLearning.dimensionId(type, "number", cell.number),
      );
      final genderNeed = cell.gender == null
          ? 1.0
          : learning.need(
              GrammarLearning.dimensionId(type, "gender", cell.gender!),
            );

      return caseNeed * numberNeed * genderNeed;
    }, random);
  }

  LatinGrammarTask _nounTask(
    String topic,
    Set<LatinDeclension> declensions,
    LatinGrammarSettings settings,
  ) {
    final noun = learning.pickFromGroups(
      _groups(
        _nouns(settings, declensions),
        (n) => "${n.declension.name}-${n.genderCode}",
      ),
      (n) => wordCardId("noun", n.id),
    );

    final paradigm = noun.paradigm();
    final cases = _cases(settings);

    final cells = [
      for (final cell in paradigm.cells.keys)
        if (cases.contains(cell.grammaticalCase)) cell,
    ];

    final target = _pickNominalCell("noun", cells);

    final explanation = explainNounForm(noun, target);

    final form = paradigm.mainForm(target)!;

    return NominalIdentifyTask(
      topic: topic,
      wordType: NominalWordType.noun,
      wordId: noun.id,
      dictionaryForm: noun.dictionaryForm,
      lemmas: [noun.lemma],
      form: form,
      target: NominalAnalysis(
        target.grammaticalCase,
        target.number,
        noun.gender,
      ),
      analyses: [
        for (final a in paradigm.analysesOf(form))
          if (cases.contains(a.grammaticalCase))
            NominalAnalysis(a.grammaticalCase, a.number, noun.gender),
      ],
      askGender: true,
      cases: cases,
      explanation: explanation,
    );
  }

  // -- Adjektive --------------------------------------------------------------

  List<LatinAdjective> _adjectives(LatinGrammarSettings settings) {
    return [
      for (final adjective in LatinGrammarWords.adjectives)
        if (_inLessons(adjective.vocabularyId, settings)) adjective,
    ];
  }

  LatinGrammarTask _adjectiveTask(LatinGrammarSettings settings) {
    const topic = LatinTrainerTopics.adjectives;

    final adjective = learning.pickFromGroups(
      _groups(_adjectives(settings), (a) => a.adjectiveClass),
      (a) => wordCardId("adjective", a.id),
    );

    final paradigm = adjective.paradigm();
    final cases = _cases(settings);

    final cells = [
      for (final cell in paradigm.cells.keys)
        if (cases.contains(cell.grammaticalCase)) cell,
    ];

    final target = _pickNominalCell("adjective", cells);
    final form = paradigm.mainForm(target)!;

    return NominalIdentifyTask(
      topic: topic,
      wordType: NominalWordType.adjective,
      wordId: adjective.id,
      dictionaryForm: adjective.dictionaryForm,
      lemmas: [adjective.lemma],
      form: form,
      target: target,
      analyses: [
        for (final a in paradigm.analysesOf(form))
          if (cases.contains(a.grammaticalCase)) a,
      ],
      askGender: true,
      cases: cases,
      explanation:
          "${adjective.dictionaryForm}: "
          "${adjective.adjectiveClass == LatinAdjectiveClass.ao ? "Maskulinum und Neutrum nach der o-, Femininum nach der a-Deklination" : "3. Deklination mit Ablativ Sg. -ī, Neutrum Pl. -ia und Genitiv Pl. -ium"}.",
    );
  }

  // -- Pronomen ---------------------------------------------------------------

  LatinGrammarTask _pronounTask(LatinGrammarSettings settings) {
    const topic = LatinTrainerTopics.pronouns;

    final pronoun = learning.pickFromGroups(
      _groups(LatinGrammarWords.pronouns, (p) => p.kind),
      (p) => wordCardId("pronoun", p.id),
    );

    final paradigm = pronoun.paradigm();
    final target = _pickNominalCell("pronoun", paradigm.cells.keys.toList());

    final explanation =
        "${pronoun.label} (${pronoun.kind}): "
        "${target.describe()} = ${paradigm.formsOf(target).join(" / ")}.";

    final form = paradigm.mainForm(target)!;

    return NominalIdentifyTask(
      topic: topic,
      wordType: NominalWordType.pronoun,
      wordId: pronoun.id,
      dictionaryForm: pronoun.label,
      lemmas: pronoun.label
          .split(RegExp(r"[,–]"))
          .map((s) => s.trim())
          .toList(),
      form: form,
      target: target,
      analyses: paradigm.analysesOf(form),
      askGender: pronoun.hasGender,
      cases: LatinCases.withoutVocative,
      hint: "Form von ${pronoun.label}",
      explanation: explanation,
    );
  }

  // -- Verben -----------------------------------------------------------------

  /// Ob eine Bestimmung zum Thema gehört.
  static bool topicContains(String topic, VerbAnalysis a) {
    const active = LatinVoices.active;
    const passive = LatinVoices.passive;

    switch (topic) {
      case LatinTrainerTopics.verbsPresent:
        return a.voice == active &&
            a.tense == LatinTenses.present &&
            a.mood != LatinMoods.subjunctive;
      case LatinTrainerTopics.verbsImperfectFuture:
        return a.voice == active &&
            a.mood == LatinMoods.indicative &&
            (a.tense == LatinTenses.imperfect || a.tense == LatinTenses.future);
      case LatinTrainerTopics.verbsPerfect:
        return a.voice == active &&
            (a.mood == LatinMoods.indicative ||
                a.mood == LatinMoods.infinitive) &&
            (a.tense == LatinTenses.perfect ||
                a.tense == LatinTenses.pluperfect ||
                a.tense == LatinTenses.futurePerfect);
      case LatinTrainerTopics.verbsPassive:
        return a.voice == passive &&
            (a.mood == LatinMoods.indicative ||
                a.mood == LatinMoods.infinitive);
      case LatinTrainerTopics.verbsSubjunctive:
        return a.mood == LatinMoods.subjunctive;
    }

    return false;
  }

  List<LatinVerb> _verbCandidates(String topic, LatinGrammarSettings settings) {
    return [
      for (final verb in LatinGrammarWords.verbs)
        if (_inLessons(verb.vocabularyId, settings) &&
            verb.paradigm().cells.keys.any((a) => topicContains(topic, a)))
          verb,
    ];
  }

  LatinGrammarTask _verbTask(String topic, LatinGrammarSettings settings) {
    final verb = learning.pickFromGroups(
      _groups(_verbCandidates(topic, settings), (v) => v.conjugation),
      (v) => wordCardId("verb", v.id),
    );

    final paradigm = verb.paradigm();

    final cells = [
      for (final cell in paradigm.cells.keys)
        if (topicContains(topic, cell)) cell,
    ];

    final target = pickWeighted(cells, (cell) {
      double need(String dimension, String? value) => value == null
          ? 1.0
          : learning.need(
              GrammarLearning.dimensionId("verb", dimension, value),
            );

      return need("mood", cell.mood) *
          need("tense", cell.tense) *
          need("voice", cell.voice) *
          need("person", cell.person);
    }, random);

    final explanation = explainVerbForm(verb, target);

    final form = paradigm.mainForm(target)!;

    return VerbIdentifyTask(
      topic: topic,
      verb: verb,
      form: form,
      target: target,
      analyses: paradigm.analysesOf(form),
      explanation: explanation,
    );
  }

  // -- Auswahlaufgaben --------------------------------------------------------

  static const List<String> prepositionOptions = [
    LatinCases.accusative,
    LatinCases.ablative,
    "${LatinCases.accusative} und ${LatinCases.ablative}",
  ];

  List<LatinPreposition> _prepositions(LatinGrammarSettings settings) {
    return [
      for (final p in LatinGrammarWords.prepositions)
        if (_inLessons(p.vocabularyId, settings)) p,
    ];
  }

  LatinGrammarTask _prepositionTask(LatinGrammarSettings settings) {
    final preposition = learning.pickFromGroups(
      _groups(_prepositions(settings), (p) => p.caseAnswer),
      (p) => wordCardId("preposition", p.lemma),
    );

    return ChoiceTask(
      topic: LatinTrainerTopics.prepositions,
      itemId: wordCardId("preposition", preposition.lemma),
      prompt: preposition.lemma,
      question: "Mit welchem Kasus steht die Präposition?",
      options: prepositionOptions,
      answer: preposition.caseAnswer,
      explanation:
          "${preposition.lemma} + ${preposition.cases.map((c) => LatinCases.short[c]).join(" / ")}: "
          "${preposition.meaning}.",
    );
  }

  LatinGrammarTask _syntaxTask() {
    final example = learning.pickFromGroups(
      _groups(LatinGrammarWords.syntaxExamples, (e) => e.construction),
      (e) => "syntax.${e.id}",
    );

    final distractors =
        LatinConstructions.all.where((c) => c != example.construction).toList()
          ..shuffle(random);

    final options = [example.construction, ...distractors.take(3)]
      ..shuffle(random);

    return ChoiceTask(
      topic: LatinTrainerTopics.syntax,
      itemId: "syntax.${example.id}",
      prompt: example.sentence,
      question: "Welche Konstruktion enthält der Satz?",
      translation: example.translation,
      options: options,
      answer: example.construction,
      explanation: example.explanation,
    );
  }
}

// ---------------------------------------------------------------------------
// LERNSTAND VERBUCHEN
// ---------------------------------------------------------------------------

/// Lernkarten einer ausgewerteten Aufgabe (Karten-ID → richtig?).
///
/// Beim Bestimmen zählt jedes Feld einzeln (ein falscher Kasus erhöht den
/// Lernbedarf dieses Kasus). Bei Auswahlaufgaben zählt das Gesamtergebnis.
Map<String, bool> learningResults({
  required LatinGrammarTask task,
  required bool correct,
  Map<String, bool> fields = const {},
}) {
  final results = <String, bool>{
    LatinGrammarTaskGenerator.topicCardId(task.topic): correct,
  };

  void nominal(String type, NominalAnalysis target, {bool split = false}) {
    void add(String dimension, String? value, String field) {
      if (value == null) return;

      results[GrammarLearning.dimensionId(type, dimension, value)] = split
          ? (fields[field] ?? correct)
          : correct;
    }

    add("case", target.grammaticalCase, "case");
    add("number", target.number, "number");
    add("gender", target.gender, "gender");
  }

  void verb(VerbAnalysis target, {bool split = false}) {
    void add(String dimension, String? value) {
      if (value == null) return;

      results[GrammarLearning.dimensionId("verb", dimension, value)] = split
          ? (fields[dimension] ?? correct)
          : correct;
    }

    add("mood", target.mood);
    add("tense", target.tense);
    add("voice", target.voice);
    add("person", target.person);
  }

  switch (task) {
    case NominalIdentifyTask():
      results[LatinGrammarTaskGenerator.wordCardId(
            task.wordType.name,
            task.wordId,
          )] =
          correct;
      nominal(task.wordType.name, task.target, split: true);

    case VerbIdentifyTask():
      results[LatinGrammarTaskGenerator.wordCardId("verb", task.verb.id)] =
          correct;
      verb(task.target, split: true);

    case ChoiceTask():
      results[task.itemId] = correct;
  }

  results[GrammarLearning.dimensionId("kind", task.topic, switch (task) {
        NominalIdentifyTask() || VerbIdentifyTask() => "identify",
        ChoiceTask() => "choice",
      })] =
      correct;

  return results;
}

// ---------------------------------------------------------------------------
// AUSWERTUNG
// ---------------------------------------------------------------------------

Map<String, String?> nominalFields(NominalAnalysis a, {required bool gender}) {
  return {
    "case": a.grammaticalCase,
    "number": a.number,
    if (gender) "gender": a.gender,
  };
}

Map<String, String?> verbFields(VerbAnalysis a) {
  return {
    "mood": a.mood,
    "tense": a.tense,
    "voice": a.voice,
    "person": a.person,
  };
}

/// Prüft eine nominale Bestimmung.
IdentifyResult<NominalAnalysis> checkNominalIdentification(
  NominalIdentifyTask task, {
  required String? grammaticalCase,
  required String? number,
  required String? gender,
}) {
  return checkIdentification(
    target: task.target,
    analyses: task.analyses,
    answer: {"case": grammaticalCase, "number": number, "gender": gender},
    fieldsOf: (a) => nominalFields(a, gender: task.askGender),
  );
}

/// Prüft eine Verbbestimmung. Beim Infinitiv zählt die Person nicht.
IdentifyResult<VerbAnalysis> checkVerbIdentification(
  VerbIdentifyTask task, {
  required String? mood,
  required String? tense,
  required String? voice,
  required String? person,
}) {
  return checkIdentification(
    target: task.target,
    analyses: task.analyses,
    answer: {"mood": mood, "tense": tense, "voice": voice, "person": person},
    fieldsOf: verbFields,
  );
}

/// Grundformen, die beim Bestimmen eines Verbs gelten.
List<String> verbLemmas(LatinVerb verb) => [verb.infinitive, verb.present];
