import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'greek_declension.dart';
import 'greek_mi_verbs.dart';
import 'subjunctive_exercises.dart';

/// Aufgaben des Themas „Verben auf -μι“ im Grammatiktrainer, ausschließlich
/// aus der Folie „Sprachkurs Griechisch 2 – Die athematische Konjugation“
/// ([GreekMiVerbs]):
///   * Formen bestimmen: die vier Verben der Folie als Verbaufgaben – der
///     Trainer legt eine Form vor, Modus, Tempus, Genus Verbi und Person
///     (beim Partizip Kasus, Numerus, Genus) werden bestimmt,
///   * Formen bilden: jede Form der Folientabellen und der Partizipien,
///   * Sätze: die Sätze der Folie – Grundform und Tempus der μι-Form.
///
/// Die IDs sind stabil (Lernstand `lemma.<id>`) und dürfen nie neu vergeben
/// werden: 11401–11404 die Verben zum Bestimmen, 11411–11499 Sätze,
/// 11500–11899 Formen bilden (Verb × 100 + Tabelle × 10 + Zelle).
class MiVerbExercises {
  MiVerbExercises._();

  /// Wortart-Schlüssel des Themas in `enabledTypes`.
  static const String type = "mi_verbs";

  static const String identify = "identify";
  static const String build = "build";
  static const String usage = "usage";

  /// Aufgabenarten, einzeln wählbar.
  static const List<String> kinds = [identify, build, usage];

  static String kindLabel(String kind) {
    return switch (kind) {
      identify => "Formen bestimmen",
      build => "Formen bilden",
      _ => "Sätze",
    };
  }

  // ---------------------------------------------------------------------------
  // FORMEN BESTIMMEN
  // ---------------------------------------------------------------------------

  static const int _firstVerbId = 11401;

  /// Die vier Verben als Verbaufgaben. Sie hängen an keinem Schritt der
  /// Vokabelliste; ἵημι und ἵστημι stehen dort gar nicht.
  static final List<GreekVocabularyEntry> verbEntries = [
    for (var v = 0; v < GreekMiVerbs.verbs.length; v++)
      GreekVocabularyEntry(
        id: _firstVerbId + v,
        step: 0,
        type: "verb",
        lemma: GreekMiVerbs.verbs[v].lemma,
        aorist: GreekMiVerbs.verbs[v].tables[4].forms.first,
        translations: [
          for (final meaning in GreekMiVerbs.verbs[v].meaning.split(","))
            meaning.trim(),
        ],
      ),
  ];

  /// Ob [entry] eine Verbaufgabe dieses Themas ist (und nicht das Wort der
  /// Vokabelliste).
  static bool isVerbEntry(GreekVocabularyEntry entry) {
    return entry.type == "verb" &&
        entry.id >= _firstVerbId &&
        entry.id < _firstVerbId + GreekMiVerbs.verbs.length;
  }

  // ---------------------------------------------------------------------------
  // FORMEN BILDEN
  // ---------------------------------------------------------------------------

  static const List<String> _persons = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  static final List<MiVerbBuildTask> buildTasks = [
    for (var v = 0; v < GreekMiVerbs.verbs.length; v++)
      ..._buildTasksOf(GreekMiVerbs.verbs[v], 11500 + v * 100),
  ];

  static List<MiVerbBuildTask> _buildTasksOf(MiVerb verb, int base) {
    final tasks = <MiVerbBuildTask>[];

    for (var t = 0; t < verb.tables.length; t++) {
      final table = verb.tables[t];
      final row = [...table.forms, ?table.infinitive];

      for (var i = 0; i < table.forms.length; i++) {
        final form = table.forms[i];

        tasks.add(
          MiVerbBuildTask(
            id: base + t * 10 + i,
            lemma: verb.lemma,
            description:
                "${_persons[i]} ${table.tense} Indikativ ${table.voice}",
            hint: table.kind,
            answer: form,
            // 3. Sg. Aorist auf -εν: Das ν ist beweglich (ἔδωκε / ἔδωκεν).
            movableNu: table.tense == "Aorist" && i == 2 && form.endsWith("εν"),
            tense: table.tense,
            voice: table.voice,
            slideTitle: table.slideTitle,
            row: row,
          ),
        );
      }

      final infinitive = table.infinitive;

      if (infinitive != null) {
        tasks.add(
          MiVerbBuildTask(
            id: base + t * 10 + 6,
            lemma: verb.lemma,
            description: "Infinitiv ${table.tense} ${table.voice}",
            hint: table.kind,
            answer: infinitive,
            tense: table.tense,
            voice: table.voice,
            slideTitle: table.slideTitle,
            row: row,
          ),
        );
      }
    }

    for (var p = 0; p < verb.participles.length; p++) {
      final participle = verb.participles[p];
      final row = [...participle.nominative, ...participle.genitive];

      for (var c = 0; c < 6; c++) {
        final grammaticalCase = c < 3 ? "Nominativ" : "Genitiv";
        final gender = declensionGenders[c % 3];

        tasks.add(
          MiVerbBuildTask(
            id: base + (verb.tables.length + p) * 10 + c,
            lemma: verb.lemma,
            description:
                "Partizip ${participle.tense} Aktiv · $grammaticalCase Sg. "
                "$gender",
            hint: participle.kind,
            answer: row[c],
            tense: participle.tense,
            voice: "Aktiv",
            slideTitle: "Partizipien ${participle.tense}",
            row: row,
          ),
        );
      }
    }

    return tasks;
  }

  // ---------------------------------------------------------------------------
  // SÄTZE
  // ---------------------------------------------------------------------------

  /// Tempora der μι-Formen in den Sätzen.
  static const List<String> usageTenses = ["Präsens", "Imperfekt", "Aorist"];

  /// Die Sätze der Folie, ohne Stelle und Übersetzung auf der Folie: beides
  /// ist ergänzt und in der App als Ergänzung markiert.
  static const List<MiVerbUsageTask> usageTasks = [
    MiVerbUsageTask(
      id: 11411,
      sentence: "ἐγὼ τίθημι τὴν ψυχήν μου.",
      form: "τίθημι",
      verb: "τίθημι",
      tense: "Präsens",
      analysis: "1. Sg. Präsens Indikativ Aktiv",
      translation: "Ich gebe mein Leben hin.",
      reference: "Joh 10,17",
    ),
    MiVerbUsageTask(
      id: 11412,
      sentence: "τίς οὗτός ἐστιν ὃς καὶ ἁμαρτίας ἀφίησιν;",
      form: "ἀφίησιν",
      verb: "ἵημι",
      compound: "ἀφίημι (ἀπό + ἵημι): loslassen, erlassen, vergeben",
      tense: "Präsens",
      analysis: "3. Sg. Präsens Indikativ Aktiv von ἀφίημι",
      translation: "Wer ist dieser, der sogar Sünden vergibt?",
      reference: "Lk 7,49",
    ),
    MiVerbUsageTask(
      id: 11413,
      sentence: "εἰρήνην τὴν ἐμὴν δίδωμι ὑμῖν, οὐ καθὼς ὁ κόσμος δίδωσιν.",
      form: "δίδωμι",
      verb: "δίδωμι",
      tense: "Präsens",
      analysis:
          "1. Sg. Präsens Indikativ Aktiv; δίδωσιν: 3. Sg. Präsens "
          "Indikativ Aktiv",
      translation: "Meinen Frieden gebe ich euch, nicht wie die Welt gibt.",
      reference: "Joh 14,27",
    ),
    MiVerbUsageTask(
      id: 11414,
      sentence: "ἔκλασεν τοὺς ἄρτους καὶ ἐδίδου τοῖς μαθηταῖς.",
      form: "ἐδίδου",
      verb: "δίδωμι",
      tense: "Imperfekt",
      analysis:
          "3. Sg. Imperfekt Indikativ Aktiv (Augment + Reduplikation); "
          "ἔκλασεν davor ist Aorist: er brach – und gab nach und nach aus",
      translation: "Er brach die Brote und gab sie den Jüngern.",
      reference: "vgl. Mk 8,6; Mt 15,36",
    ),
    MiVerbUsageTask(
      id: 11415,
      sentence: "καὶ εὐθὺς ἀνέστη τὸ κοράσιον καὶ περιεπάτει.",
      form: "ἀνέστη",
      verb: "ἵστημι",
      compound: "ἀνίστημι (ἀνά + ἵστημι): aufstehen, auferstehen",
      tense: "Aorist",
      analysis:
          "3. Sg. Aorist Indikativ Aktiv von ἀνίστημι – Wurzelaorist ἔστη, "
          "intransitiv",
      translation: "Und sogleich stand das Mädchen auf und ging umher.",
      reference: "Mk 5,42",
    ),
    MiVerbUsageTask(
      id: 11416,
      sentence: "τίς σοι ἔδωκεν τὴν ἐξουσίαν ταύτην;",
      form: "ἔδωκεν",
      verb: "δίδωμι",
      tense: "Aorist",
      analysis: "3. Sg. Aorist Indikativ Aktiv (κ-Aorist ἔδωκα)",
      translation: "Wer hat dir diese Vollmacht gegeben?",
      reference: "Mt 21,23; Mk 11,28",
    ),
    MiVerbUsageTask(
      id: 11417,
      sentence: "ἴδε ὁ τόπος ὅπου ἔθηκαν αὐτόν.",
      form: "ἔθηκαν",
      verb: "τίθημι",
      tense: "Aorist",
      analysis:
          "3. Pl. Aorist Indikativ Aktiv – im Neuen Testament mit κ auch im "
          "Plural (Paradigma der Folie: ἔθεσαν)",
      translation: "Siehe, der Ort, wo sie ihn hingelegt haben.",
      reference: "Mk 16,6",
    ),
  ];

  // ---------------------------------------------------------------------------
  // EINTRÄGE DES TRAINERS
  // ---------------------------------------------------------------------------

  /// Alle Einträge des Themas: die Verbaufgaben (Wortart Verb) und die
  /// Aufgaben zum Bilden und zu den Sätzen (Wortart [type]).
  static final List<GreekVocabularyEntry> entries = [
    ...verbEntries,
    for (final task in buildTasks)
      GreekVocabularyEntry(
        id: task.id,
        step: 0,
        type: type,
        lemma: task.lemma,
        translations: const [],
      ),
    for (final task in usageTasks)
      GreekVocabularyEntry(
        id: task.id,
        step: 0,
        type: type,
        lemma: task.verb,
        translations: const [],
      ),
  ];

  static MiVerbBuildTask? buildTask(int id) {
    for (final task in buildTasks) {
      if (task.id == id) return task;
    }

    return null;
  }

  static MiVerbUsageTask? usageTask(int id) {
    for (final task in usageTasks) {
      if (task.id == id) return task;
    }

    return null;
  }

  /// IDs der Aufgaben der gewählten Aufgabenarten.
  static Set<int> idsOfKinds(List<String> enabledKinds) {
    return {
      if (enabledKinds.contains(identify))
        for (final entry in verbEntries) entry.id,
      if (enabledKinds.contains(build))
        for (final task in buildTasks) task.id,
      if (enabledKinds.contains(usage))
        for (final task in usageTasks) task.id,
    };
  }

  /// Ob [entry] zum Thema gehört (Verbaufgabe, Bilden oder Satz).
  static bool owns(GreekVocabularyEntry entry) {
    return entry.type == type || isVerbEntry(entry);
  }

  // ---------------------------------------------------------------------------
  // ANTWORTPRÜFUNG
  // ---------------------------------------------------------------------------

  /// Prüft eine gebildete Form wie beim Konjunktiv: Buchstaben und Iota
  /// subscriptum streng, Akzente und Spiritus dürfen fehlen, gesetzte müssen
  /// stimmen; das bewegliche ν ist freigestellt.
  static SubjunctiveFormResult checkForm(String input, MiVerbBuildTask task) {
    return SubjunctiveExercises.checkForm(input, task.checkAnswer);
  }

  /// Hinweise zu einer falsch gebildeten Form: eine andere Form der Folie
  /// (welche?), Reduplikation, Augment, κ im Aorist, θη im Aorist Passiv.
  static List<String> explainBuild(MiVerbBuildTask task, String input) {
    final hints = <String>[];
    final verb = GreekMiVerbs.byLemma(task.lemma)!;

    final user = miVerbComparable(input.trim());
    final expected = miVerbComparable(task.answer);

    if (user.isEmpty) {
      return hints;
    }

    if (user == expected) {
      return ["Buchstaben richtig – Akzent oder Spiritus stimmen nicht."];
    }

    final same = [
      for (final other in buildTasks)
        if (other.id != task.id && miVerbComparable(other.answer) == user)
          other,
    ];

    final sameVerb = same.where((other) => other.lemma == task.lemma);

    if (sameVerb.isNotEmpty) {
      hints.add(
        "${input.trim()} ist ${sameVerb.map((o) => o.description).join(' '
        'oder ')} – gefragt ist ${task.description}.",
      );
    } else if (same.isNotEmpty) {
      hints.add(
        "${input.trim()} gehört zu ${same.first.lemma} "
        "(${same.first.description}).",
      );
    }

    final reduplicated = verb.lemma != GreekMiVerbs.hiemi.lemma
        ? user.startsWith(verb.reduplication) ||
              user.startsWith("ε${verb.reduplication}")
        : null;

    if ((task.tense == "Präsens" || task.tense == "Imperfekt") &&
        reduplicated == false) {
      hints.add(
        "Präsens und Imperfekt haben die Reduplikation: ${verb.presentStem}",
      );
    }

    if (task.tense == "Aorist" && reduplicated == true) {
      hints.add(
        "Der Aorist hat keine Präsensreduplikation (${verb.aoristStem}).",
      );
    }

    if (task.tense == "Imperfekt" &&
        (verb == GreekMiVerbs.didomi || verb == GreekMiVerbs.tithemi) &&
        !user.startsWith("ε")) {
      hints.add("Imperfekt: Augment ἐ- vor der Reduplikation (ἐ-δίδουν).");
    }

    final finite = task.description.contains("Indikativ");
    final index = task.row.indexOf(task.answer);

    if (task.tense == "Aorist" &&
        task.voice == "Aktiv" &&
        finite &&
        task.hint == null &&
        verb != GreekMiVerbs.histemi) {
      if (index < 3 && !user.contains("κ")) {
        hints.add("Im Sg. Aktiv hat der Aorist ein κ (ἔδωκα, ἔθηκα, ἧκα).");
      } else if (index >= 3 && user.contains("κ")) {
        hints.add(
          "Im Plural nach der Folie ohne κ (ἔδομεν, ἔθεμεν, εἷμεν). Im "
          "Neuen Testament dringt das κ auch in den Plural (ἔθηκαν, "
          "ἔδωκαν) – Ergänzung, nicht auf der Folie.",
        );
      }
    }

    if (task.tense == "Aorist" &&
        task.voice == "Passiv" &&
        !user.contains("θη")) {
      hints.add(
        "Aorist Passiv: kurzer Stamm + θη (ἐδόθην, ἐτέθην, εἵθην, "
        "ἐστάθην).",
      );
    }

    return hints;
  }
}

/// Eine Form der Folie, die aus der Grundform zu bilden ist.
class MiVerbBuildTask {
  final int id;
  final String lemma;

  /// "3. Pl. Imperfekt Indikativ Aktiv", "Infinitiv Aorist Passiv",
  /// "Partizip Präsens Aktiv · Genitiv Sg. f".
  final String description;

  /// Art des Aorists, wo das Verb zwei hat (ἵστημι).
  final String? hint;

  /// Die Form der Folie.
  final String answer;

  /// Ob das ν am Ende beweglich ist (ἔδωκεν / ἔδωκε).
  final bool movableNu;

  final String tense;
  final String voice;

  /// Die Tabelle der Folie, aus der die Form stammt ("Aorist aktiv").
  final String slideTitle;

  /// Alle Formen dieser Tabelle (mit Infinitiv) bzw. des Partizips
  /// (Nominativ, Genitiv) – für die Rückmeldung.
  final List<String> row;

  const MiVerbBuildTask({
    required this.id,
    required this.lemma,
    required this.description,
    this.hint,
    required this.answer,
    this.movableNu = false,
    required this.tense,
    required this.voice,
    required this.slideTitle,
    required this.row,
  });

  /// Die Form, an der die Eingabe gemessen wird (bewegliches ν als "(ν)").
  String get checkAnswer {
    return movableNu ? "${answer.substring(0, answer.length - 1)}(ν)" : answer;
  }
}

/// Ein Satz der Folie mit der μι-Form [form].
class MiVerbUsageTask {
  final int id;
  final String sentence;
  final String form;

  /// Das Verb der Folie, zu dem die Form gehört (beim Kompositum das
  /// Simplex: ἀφίησιν → ἵημι).
  final String verb;

  /// Kompositum mit Bedeutung, wo die Form zu einem gehört.
  final String? compound;

  /// "Präsens", "Imperfekt" oder "Aorist".
  final String tense;

  /// Vollständige Bestimmung der Form.
  final String analysis;

  /// Übersetzung und Stelle sind ergänzt (nicht auf der Folie).
  final String translation;
  final String reference;

  const MiVerbUsageTask({
    required this.id,
    required this.sentence,
    required this.form,
    required this.verb,
    this.compound,
    required this.tense,
    required this.analysis,
    required this.translation,
    required this.reference,
  });
}
