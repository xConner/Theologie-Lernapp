import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../utils/greek_normalization.dart';
import 'greek_subjunctive.dart';

/// Aufgaben des Themas „Konjunktiv“ im Grammatiktrainer, ausschließlich aus
/// der Folie „Sprachkurs Griechisch 2 – Konjunktiv“:
///   * Formen bilden: jede Zelle der Folienparadigmen (παύω, ἔλθω, εἰμί)
///     und jede Konjunktivform der Beispielsätze aus ihrer Grundform,
///   * Gebrauch im Satz: die Beispielsätze der Folie – Tempus des
///     Konjunktivs und Verwendung bestimmen.
///
/// Das Bestimmen vorgelegter Konjunktivformen läuft über die Wortart Verb
/// (Modus Konjunktiv), mit allen Verben der Vokabelliste.
///
/// Die IDs sind stabil (Lernstand `lemma.<id>`) und dürfen nie neu vergeben
/// werden: 11010–11076 Folienparadigmen, 11101–11199 Formen der
/// Beispielsätze, 11201–11299 Sätze.
class SubjunctiveExercises {
  SubjunctiveExercises._();

  /// Wortart-Schlüssel des Themas in `enabledTypes`.
  static const String type = "subjunctive";

  static const String build = "build";
  static const String usage = "usage";

  /// Aufgabenarten, einzeln wählbar.
  static const List<String> kinds = [build, usage];

  static String kindLabel(String kind) {
    return kind == build ? "Formen bilden" : "Gebrauch im Satz";
  }

  // ---------------------------------------------------------------------------
  // FORMEN BILDEN
  // ---------------------------------------------------------------------------

  static final List<SubjunctiveBuildTask> buildTasks = [
    ..._table(11010, "παύω", "Präsens", "Aktiv", null, null),
    ..._table(11020, "παύω", "Präsens", "Medium/Passiv", null, null),
    ..._table(11030, "παύω", "Aorist", "Aktiv", "Aoriststamm παυσ-", null),
    ..._table(11040, "παύω", "Aorist", "Medium", "Aoriststamm παυσ-", null),
    ..._table(
      11050,
      "παύω",
      "Aorist",
      "Passiv",
      "Aorist-Passiv-Stamm παυθ-",
      null,
    ),
    ..._table(
      11060,
      "ἔρχομαι",
      "Aorist",
      "Aktiv",
      "starker Aorist ἦλθον",
      GreekSubjunctive.strongAorist,
    ),
    ..._table(11070, "εἰμί", "Präsens", "Aktiv", null, GreekSubjunctive.eimi),

    // Konjunktivformen der Beispielsätze.
    const SubjunctiveBuildTask(
      id: 11101,
      lemma: "φονεύω",
      tense: "Präsens",
      voice: "Aktiv",
      person: 2,
      number: "Sg",
      answer: "φονεύῃς",
      source: "μὴ φονεύῃς.",
    ),
    const SubjunctiveBuildTask(
      id: 11102,
      lemma: "εὔχομαι",
      tense: "Präsens",
      voice: "Medium/Passiv",
      person: 1,
      number: "Pl",
      answer: "εὐχώμεθα",
      source: "εὐχώμεθα.",
    ),
    const SubjunctiveBuildTask(
      id: 11103,
      lemma: "ποιέω",
      hint: "Aorist ἐποίησα",
      tense: "Aorist",
      voice: "Aktiv",
      person: 1,
      number: "Pl",
      answer: "ποιήσωμεν",
      source: "ποιήσωμεν ἀνθρώπους.",
    ),
    const SubjunctiveBuildTask(
      id: 11104,
      lemma: "ἐσθίω",
      tense: "Präsens",
      voice: "Aktiv",
      person: 1,
      number: "Pl",
      answer: "ἐσθίωμεν",
      source: "τί ἐσθίωμεν;",
    ),
    const SubjunctiveBuildTask(
      id: 11105,
      lemma: "πίπτω",
      tense: "Präsens",
      voice: "Aktiv",
      person: 3,
      number: "Sg",
      answer: "πίπτῃ",
      source: "φοβοῦμαι, μὴ ὑετὸς πίπτῃ.",
    ),
    const SubjunctiveBuildTask(
      id: 11106,
      lemma: "βιοτεύω",
      tense: "Präsens",
      voice: "Aktiv",
      person: 1,
      number: "Pl",
      answer: "βιοτεύωμεν",
      source: "ἐσθίομεν, ἵνα βιοτεύωμεν.",
    ),
    const SubjunctiveBuildTask(
      id: 11107,
      lemma: "θέλω",
      tense: "Präsens",
      voice: "Aktiv",
      person: 2,
      number: "Sg",
      answer: "θέλῃς",
      source: "ἔλθε, ἐὰν θέλῃς.",
    ),
    const SubjunctiveBuildTask(
      id: 11108,
      lemma: "λαμβάνω",
      hint: "starker Aorist ἔλαβον",
      tense: "Aorist",
      voice: "Aktiv",
      person: 1,
      number: "Sg",
      answer: "λάβω",
      source: "ἵνα πάλιν λάβω αὐτήν (Joh 10,17)",
    ),
    const SubjunctiveBuildTask(
      id: 11109,
      lemma: "λύω",
      hint: "Aorist ἔλυσα",
      tense: "Aorist",
      voice: "Aktiv",
      person: 1,
      number: "Sg",
      answer: "λύσω",
      source: "ἵνα λύσω αὐτοῦ τὸν ἱμάντα (Joh 1,27)",
    ),
    const SubjunctiveBuildTask(
      id: 11110,
      lemma: "νομίζω",
      hint: "Aorist ἐνόμισα",
      tense: "Aorist",
      voice: "Aktiv",
      person: 2,
      number: "Pl",
      answer: "νομίσητε",
      source: "μὴ νομίσητε (Mt 5,17)",
    ),
    const SubjunctiveBuildTask(
      id: 11111,
      lemma: "κρίνω",
      hint: "Aorist Passiv ἐκρίθην",
      tense: "Aorist",
      voice: "Passiv",
      person: 2,
      number: "Pl",
      answer: "κριθῆτε",
      source: "ἵνα μὴ κριθῆτε (Mt 7,1)",
    ),
    const SubjunctiveBuildTask(
      id: 11112,
      lemma: "μεριμνάω",
      hint: "Aorist ἐμερίμνησα",
      tense: "Aorist",
      voice: "Aktiv",
      person: 2,
      number: "Pl",
      answer: "μεριμνήσητε",
      source: "μὴ οὖν μεριμνήσητε (Mt 6,31)",
    ),
    const SubjunctiveBuildTask(
      id: 11113,
      lemma: "ἐσθίω",
      hint: "starker Aorist ἔφαγον",
      tense: "Aorist",
      voice: "Aktiv",
      person: 1,
      number: "Pl",
      answer: "φάγωμεν",
      source: "τί φάγωμεν; (Mt 6,31)",
    ),
    const SubjunctiveBuildTask(
      id: 11114,
      lemma: "πίνω",
      hint: "starker Aorist ἔπιον",
      tense: "Aorist",
      voice: "Aktiv",
      person: 1,
      number: "Pl",
      answer: "πίωμεν",
      source: "τί πίωμεν; (Mt 6,31)",
    ),
    const SubjunctiveBuildTask(
      id: 11115,
      lemma: "περιβάλλω",
      hint: "Aorist Medium περιεβαλόμην",
      tense: "Aorist",
      voice: "Medium",
      person: 1,
      number: "Pl",
      answer: "περιβαλώμεθα",
      source: "τί περιβαλώμεθα; (Mt 6,31)",
    ),
  ];

  static List<SubjunctiveBuildTask> _table(
    int firstId,
    String lemma,
    String tense,
    String voice,
    String? hint,
    List<String>? forms,
  ) {
    final cells = forms ?? GreekSubjunctive.pauo[tense]![voice]!;

    return [
      for (var i = 0; i < cells.length; i++)
        SubjunctiveBuildTask(
          id: firstId + i,
          lemma: lemma,
          hint: hint,
          tense: tense,
          voice: voice,
          person: GreekSubjunctive.persons[i].$1,
          number: GreekSubjunctive.persons[i].$2,
          answer: cells[i],
          source: "Paradigma der Folie",
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // GEBRAUCH IM SATZ
  // ---------------------------------------------------------------------------

  /// Die Beispielsätze der Folie. Übersetzungen ohne Stellenangabe stehen so
  /// auf der Folie; zu den Sätzen aus dem Neuen Testament gibt die Folie
  /// keine Übersetzung – sie ist ergänzt und als solche markiert.
  static const List<SubjunctiveUsageTask> usageTasks = [
    SubjunctiveUsageTask(
      id: 11201,
      sentence: "μὴ φονεύῃς.",
      form: "φονεύῃς",
      lemma: "φονεύω",
      tense: "Präsens",
      analysis: "2. Sg. Konjunktiv Präsens Aktiv",
      use: SubjunctiveUse.prohibitive,
      translation: "Töte nicht!",
    ),
    SubjunctiveUsageTask(
      id: 11202,
      sentence: "εὐχώμεθα.",
      form: "εὐχώμεθα",
      lemma: "εὔχομαι",
      tense: "Präsens",
      analysis: "1. Pl. Konjunktiv Präsens Medium/Passiv (Deponens)",
      use: SubjunctiveUse.hortative,
      translation: "Lasst uns beten!",
    ),
    SubjunctiveUsageTask(
      id: 11203,
      sentence: "ποιήσωμεν ἀνθρώπους.",
      form: "ποιήσωμεν",
      lemma: "ποιέω",
      tense: "Aorist",
      analysis: "1. Pl. Konjunktiv Aorist Aktiv",
      use: SubjunctiveUse.hortative,
      translation: "Lasst uns Menschen machen!",
    ),
    SubjunctiveUsageTask(
      id: 11204,
      sentence: "τί ποιῶμεν;",
      form: "ποιῶμεν",
      lemma: "ποιέω",
      tense: "Präsens",
      analysis:
          "1. Pl. Konjunktiv Präsens Aktiv (kontrahiert aus ποιέ-ωμεν – "
          "Ergänzung, auf der Folie nicht als Paradigma)",
      use: SubjunctiveUse.deliberative,
      translation: "Was sollen wir tun?",
    ),
    SubjunctiveUsageTask(
      id: 11205,
      // Folie: „έσθίωμεν“ (Tonos statt Spiritus lenis) – hier berichtigt.
      sentence: "τί ἐσθίωμεν;",
      form: "ἐσθίωμεν",
      lemma: "ἐσθίω",
      tense: "Präsens",
      analysis: "1. Pl. Konjunktiv Präsens Aktiv",
      use: SubjunctiveUse.deliberative,
      translation: "Was sollen wir essen?",
    ),
    SubjunctiveUsageTask(
      id: 11206,
      sentence: "φοβοῦμαι, μὴ ὑετὸς πίπτῃ.",
      form: "πίπτῃ",
      lemma: "πίπτω",
      tense: "Präsens",
      analysis: "3. Sg. Konjunktiv Präsens Aktiv",
      use: SubjunctiveUse.fear,
      translation: "Ich fürchte, dass Regen fällt.",
    ),
    SubjunctiveUsageTask(
      id: 11207,
      sentence: "ἐσθίομεν, ἵνα βιοτεύωμεν.",
      form: "βιοτεύωμεν",
      lemma: "βιοτεύω",
      tense: "Präsens",
      analysis: "1. Pl. Konjunktiv Präsens Aktiv",
      use: SubjunctiveUse.purpose,
      translation: "Wir essen, um zu leben / damit wir leben.",
    ),
    SubjunctiveUsageTask(
      id: 11208,
      sentence: "ἔλθε, ἐὰν θέλῃς.",
      form: "θέλῃς",
      lemma: "θέλω",
      tense: "Präsens",
      analysis: "2. Sg. Konjunktiv Präsens Aktiv",
      use: SubjunctiveUse.generalCondition,
      translation: "Komm, wenn / wann immer du willst!",
    ),
    SubjunctiveUsageTask(
      id: 11209,
      sentence: "Ἐγὼ τίθημι τὴν ψυχήν μου, ἵνα πάλιν λάβω αὐτήν.",
      form: "λάβω",
      lemma: "λαμβάνω",
      tense: "Aorist",
      analysis: "1. Sg. Konjunktiv Aorist Aktiv (starker Aorist ἔλαβον)",
      use: SubjunctiveUse.purpose,
      translation: "Ich gebe mein Leben hin, damit ich es wieder nehme.",
      reference: "Joh 10,17",
    ),
    SubjunctiveUsageTask(
      id: 11210,
      sentence: "Μὴ νομίσητε, ὅτι ἦλθον καταλῦσαι τὸν νόμον ἢ τοὺς προφήτας.",
      form: "νομίσητε",
      lemma: "νομίζω",
      tense: "Aorist",
      analysis: "2. Pl. Konjunktiv Aorist Aktiv",
      use: SubjunctiveUse.prohibitive,
      translation:
          "Meint nicht, dass ich gekommen bin, das Gesetz oder die "
          "Propheten aufzulösen.",
      reference: "Mt 5,17",
    ),
    SubjunctiveUsageTask(
      id: 11211,
      sentence: "Μὴ κρίνετε, ἵνα μὴ κριθῆτε.",
      form: "κριθῆτε",
      lemma: "κρίνω",
      tense: "Aorist",
      analysis:
          "2. Pl. Konjunktiv Aorist Passiv (κρίνετε davor ist Imperativ "
          "Präsens)",
      use: SubjunctiveUse.purpose,
      translation: "Richtet nicht, damit ihr nicht gerichtet werdet!",
      reference: "Mt 7,1",
    ),
    SubjunctiveUsageTask(
      id: 11212,
      sentence: "Μὴ οὖν μεριμνήσητε λέγοντες …",
      form: "μεριμνήσητε",
      lemma: "μεριμνάω",
      tense: "Aorist",
      analysis: "2. Pl. Konjunktiv Aorist Aktiv",
      use: SubjunctiveUse.prohibitive,
      translation: "Sorgt euch also nicht, indem ihr sagt: …",
      reference: "Mt 6,31",
    ),
    SubjunctiveUsageTask(
      id: 11213,
      sentence: "„Τί φάγωμεν;“",
      form: "φάγωμεν",
      lemma: "ἐσθίω",
      tense: "Aorist",
      analysis: "1. Pl. Konjunktiv Aorist Aktiv (starker Aorist ἔφαγον)",
      use: SubjunctiveUse.deliberative,
      translation: "„Was sollen wir essen?“",
      reference: "Mt 6,31",
    ),
    SubjunctiveUsageTask(
      id: 11214,
      sentence: "„Τί πίωμεν;“",
      form: "πίωμεν",
      lemma: "πίνω",
      tense: "Aorist",
      analysis: "1. Pl. Konjunktiv Aorist Aktiv (starker Aorist ἔπιον)",
      use: SubjunctiveUse.deliberative,
      translation: "„Was sollen wir trinken?“",
      reference: "Mt 6,31",
    ),
    SubjunctiveUsageTask(
      id: 11215,
      sentence: "„Τί περιβαλώμεθα;“",
      form: "περιβαλώμεθα",
      lemma: "περιβάλλω",
      tense: "Aorist",
      analysis: "1. Pl. Konjunktiv Aorist Medium (περιεβαλόμην)",
      use: SubjunctiveUse.deliberative,
      translation: "„Was sollen wir anziehen?“",
      reference: "Mt 6,31",
    ),
  ];

  /// Joh 1,27 steht auf der Folie ohne Einordnung. ἵνα + Konjunktiv nach
  /// ἄξιος ist kein Finalsatz, sondern ersetzt einen Infinitiv; diese
  /// Verwendung ordnet die Folie keiner ihrer Gruppen zu. Der Satz steht
  /// deshalb nur in der Übersicht, nicht in den Aufgaben.
  static const SubjunctiveUsageTask john127 = SubjunctiveUsageTask(
    id: 11299,
    sentence: "Οὐκ εἰμὶ ἄξιος, ἵνα λύσω αὐτοῦ τὸν ἱμάντα τοῦ ὑποδήματος.",
    form: "λύσω",
    lemma: "λύω",
    tense: "Aorist",
    analysis:
        "1. Sg. Konjunktiv Aorist Aktiv – formgleich mit dem Indikativ "
        "Futur; nach ἵνα nur Konjunktiv",
    use: null,
    translation:
        "Ich bin nicht würdig, ihm den Riemen seiner Sandale zu lösen.",
    reference: "Joh 1,27",
  );

  // ---------------------------------------------------------------------------
  // EINTRÄGE DES TRAINERS
  // ---------------------------------------------------------------------------

  static final List<GreekVocabularyEntry> entries = [
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
        lemma: task.lemma,
        translations: const [],
      ),
  ];

  static SubjunctiveBuildTask? buildTask(int id) {
    for (final task in buildTasks) {
      if (task.id == id) return task;
    }

    return null;
  }

  static SubjunctiveUsageTask? usageTask(int id) {
    for (final task in usageTasks) {
      if (task.id == id) return task;
    }

    return null;
  }

  /// IDs der Aufgaben der gewählten Aufgabenarten.
  static Set<int> idsOfKinds(List<String> enabledKinds) {
    return {
      if (enabledKinds.contains(build))
        for (final task in buildTasks) task.id,
      if (enabledKinds.contains(usage))
        for (final task in usageTasks) task.id,
    };
  }

  // ---------------------------------------------------------------------------
  // ANTWORTPRÜFUNG
  // ---------------------------------------------------------------------------

  /// Prüft eine gebildete Form.
  ///
  /// Streng geprüft werden die Buchstaben und das Iota subscriptum – daran
  /// hängt der Konjunktiv (παύῃς, παύῃ). Akzente und Spiritus dürfen
  /// fehlen; wer sie setzt, muss sie richtig setzen (Gravis gilt als Akut).
  /// Das bewegliche ν ist freigestellt: παύωσι(ν) = παύωσι = παύωσιν.
  static SubjunctiveFormResult checkForm(String input, String answer) {
    final user = _letters(input.trim().replaceAll(RegExp(r'[.,;·?!]'), ""));

    if (user.isEmpty) {
      return (correct: false, diacriticsMissing: false);
    }

    final variants = answer.endsWith("(ν)")
        ? [
            answer.substring(0, answer.length - 3),
            "${answer.substring(0, answer.length - 3)}ν",
          ]
        : [answer];

    final diacritics = user.any((letter) => letter.accent || letter.breathing);

    for (final variant in variants) {
      final expected = _letters(variant);

      if (expected.length != user.length) continue;

      var lettersMatch = true;
      var diacriticsMatch = true;

      for (var i = 0; i < expected.length; i++) {
        final a = expected[i];
        final b = user[i];

        if (a.base != b.base || a.iota != b.iota) {
          lettersMatch = false;
          break;
        }

        if (a.accentKind != b.accentKind ||
            a.breathingKind != b.breathingKind) {
          diacriticsMatch = false;
        }
      }

      if (!lettersMatch) continue;

      if (!diacritics) {
        return (correct: true, diacriticsMissing: true);
      }

      return (correct: diacriticsMatch, diacriticsMissing: false);
    }

    return (correct: false, diacriticsMissing: false);
  }

  /// Hinweise zu einer falsch gebildeten Form: fehlendes Iota subscriptum,
  /// Augment, kurzer statt langer Themavokal, eine andere Form desselben
  /// Paradigmas, falsche Akzente – und immer die Bildung der gefragten
  /// Form.
  static List<String> explainBuild(SubjunctiveBuildTask task, String input) {
    final hints = <String>[];

    final answer = task.answer.replaceAll("(ν)", "");
    final user = _letters(input.trim());
    final expected = _letters(answer);

    String plain(List<_Letter> letters, {bool iota = false}) {
      return letters
          .map(
            (letter) => iota && letter.iota ? "${letter.base}ι" : letter.base,
          )
          .join();
    }

    final userPlain = plain(user).replaceAll(RegExp(r'ν$'), "");
    final answerPlain = plain(expected).replaceAll(RegExp(r'ν$'), "");

    if (userPlain == answerPlain &&
        plain(user, iota: true) != plain(expected, iota: true)) {
      hints.add(
        "Iota subscriptum beachten: Die 2. und 3. Sg. enden auf ῃς / ῃ "
        "(Medium 2. Sg. ῃ).",
      );
    } else if (userPlain == answerPlain) {
      hints.add("Buchstaben richtig – Akzent oder Spiritus stimmen nicht.");
    }

    if (userPlain.length > answerPlain.length &&
        (userPlain.startsWith("ε") || userPlain.startsWith("η")) &&
        !answerPlain.startsWith("ε")) {
      hints.add("Kein Augment: Der Konjunktiv hat auch im Aorist keines.");
    }

    final shortened = answerPlain
        .replaceFirst(RegExp(r'ω(?=[^ω]*$)'), "ο")
        .replaceFirst(RegExp(r'η(?=[^η]*$)'), "ε");

    if (userPlain != answerPlain &&
        (userPlain == shortened ||
            const [
              "ομεν",
              "ετε",
              "ομαι",
              "εται",
              "ουσι",
              "εισ",
              "ει",
            ].any(userPlain.endsWith))) {
      hints.add(
        "Konjunktiv: langer Themavokal ω/η statt ο/ε (παύομεν → παύωμεν, "
        "παύεις → παύῃς).",
      );
    }

    for (final other in buildTasks) {
      if (other.lemma != task.lemma ||
          other.tense != task.tense ||
          other.voice != task.voice ||
          other.id == task.id) {
        continue;
      }

      if (plain(_letters(other.answer.replaceAll("(ν)", ""))) == userPlain) {
        hints.add(
          "${_strip(input)} ist die ${other.person}. ${other.number}. – "
          "gefragt ist die ${task.person}. ${task.number}.",
        );
        break;
      }
    }

    final index = GreekSubjunctive.persons.indexOf((task.person, task.number));
    final ending = GreekSubjunctive.endingsOf(task.tense, task.voice)[index];

    hints.add(
      "Bildung: ${_stemNote(task)} + Endung -$ending "
      "(${task.person}. ${task.number}. ${task.voice}).",
    );

    return hints;
  }

  static String _strip(String input) => input.trim();

  static String _stemNote(SubjunctiveBuildTask task) {
    if (task.lemma == "εἰμί") {
      return "εἰμί: nur die Endungen, mit Spiritus lenis (ὦ, ᾖς, ἦτε)";
    }

    if (task.tense == "Präsens") {
      return "Präsensstamm";
    }

    if (task.voice == "Passiv") {
      return "Aorist-Passiv-Stamm ohne Augment";
    }

    return "Aoriststamm ohne Augment";
  }

  // Zerlegt eine Eingabe in Buchstaben mit ihren Zeichen (vorkomponiert wie
  // vom Systemtastenfeld oder als Grundbuchstabe + kombinierende Zeichen wie
  // von der griechischen Tastatur der App).
  static List<_Letter> _letters(String text) {
    final result = <_Letter>[];

    for (final rune in normalizeGreekForDisplay(text).toLowerCase().runes) {
      final char = String.fromCharCode(rune);

      switch (rune) {
        case 0x0301 || 0x0300 || 0x0341 || 0x0340:
          if (result.isNotEmpty) result.last.accentKind = "acute";
          continue;

        case 0x0342:
          if (result.isNotEmpty) result.last.accentKind = "circumflex";
          continue;

        case 0x0313 || 0x0343:
          if (result.isNotEmpty) result.last.breathingKind = "lenis";
          continue;

        case 0x0314:
          if (result.isNotEmpty) result.last.breathingKind = "asper";
          continue;

        case 0x0345:
          if (result.isNotEmpty) result.last.iota = true;
          continue;

        case 0x0308:
          continue;
      }

      if (char.trim().isEmpty) continue;

      final base = normalizeGreekForComparison(char);

      if (base.isEmpty) continue;

      result.add(
        _Letter(base)
          ..accentKind = _accentOf(rune)
          ..breathingKind = _breathingOf(rune)
          ..iota = _hasIota(rune),
      );
    }

    return result;
  }

  static String? _accentOf(int rune) {
    if ((rune >= 0x1F00 && rune <= 0x1F6F) ||
        (rune >= 0x1F80 && rune <= 0x1FAF)) {
      return switch ((rune & 0x7) >> 1) {
        1 || 2 => "acute",
        3 => "circumflex",
        _ => null,
      };
    }

    if (rune >= 0x1F70 && rune <= 0x1F7D) {
      return "acute";
    }

    if (const {
          0x1FB6,
          0x1FB7,
          0x1FC6,
          0x1FC7,
          0x1FD6,
          0x1FD7,
          0x1FE6,
        }.contains(rune) ||
        const {0x1FE7, 0x1FF6, 0x1FF7}.contains(rune)) {
      return "circumflex";
    }

    if (const {
      0x03AC, 0x03AD, 0x03AE, 0x03AF, 0x03CC, 0x03CD, 0x03CE, 0x0390, //
      0x03B0, 0x1FB2, 0x1FB4, 0x1FC2, 0x1FC4, 0x1FD2, 0x1FD3, 0x1FE2,
      0x1FE3, 0x1FF2, 0x1FF4,
    }.contains(rune)) {
      return "acute";
    }

    return null;
  }

  static String? _breathingOf(int rune) {
    if ((rune >= 0x1F00 && rune <= 0x1F6F) ||
        (rune >= 0x1F80 && rune <= 0x1FAF)) {
      return rune & 0x1 == 0 ? "lenis" : "asper";
    }

    if (rune == 0x1FE4) return "lenis";
    if (rune == 0x1FE5) return "asper";

    return null;
  }

  static bool _hasIota(int rune) {
    return (rune >= 0x1F80 && rune <= 0x1FAF) ||
        const {
          0x1FB2, 0x1FB3, 0x1FB4, 0x1FB7, 0x1FC2, 0x1FC3, 0x1FC4, 0x1FC7, //
          0x1FF2, 0x1FF3, 0x1FF4, 0x1FF7,
        }.contains(rune);
  }
}

class _Letter {
  final String base;
  String? accentKind;
  String? breathingKind;
  bool iota = false;

  _Letter(this.base);

  bool get accent => accentKind != null;
  bool get breathing => breathingKind != null;
}

/// Ergebnis von [SubjunctiveExercises.checkForm]: [diacriticsMissing], wenn
/// die Buchstaben stimmen, Akzente und Spiritus aber ganz fehlen.
typedef SubjunctiveFormResult = ({bool correct, bool diacriticsMissing});

/// Eine Form, die aus ihrer Grundform zu bilden ist.
class SubjunctiveBuildTask {
  final int id;
  final String lemma;

  /// Stammangabe für den Aorist ("Aoriststamm παυσ-", "starker Aorist
  /// ἦλθον").
  final String? hint;

  final String tense;
  final String voice;
  final int person;

  /// "Sg" oder "Pl" (wie in [VerbAnalysis]).
  final String number;

  /// Die Form der Folie, bewegliches ν als "(ν)".
  final String answer;

  /// Herkunft: Paradigma der Folie oder der Beispielsatz.
  final String source;

  const SubjunctiveBuildTask({
    required this.id,
    required this.lemma,
    this.hint,
    required this.tense,
    required this.voice,
    required this.person,
    required this.number,
    required this.answer,
    required this.source,
  });

  /// "2. Sg. Konjunktiv Aorist Passiv".
  String get description {
    return "$person. $number. Konjunktiv $tense $voice";
  }
}

/// Verwendungsweisen des Konjunktivs auf der Folie.
enum SubjunctiveUse {
  prohibitive(
    "Prohibitiv",
    "Hauptsatz",
    "μή + Konjunktiv: Verbot",
    "„Töte nicht!“",
  ),
  hortative(
    "Adhortativ",
    "Hauptsatz",
    "Konjunktiv der 1. Person Plural: Aufforderung an die eigene Gruppe",
    "„Lasst uns …!“",
  ),
  deliberative(
    "Dubitativ",
    "Hauptsatz",
    "Konjunktiv in der (Selbst-)Frage: Überlegung, was zu tun ist",
    "„Was sollen wir …?“",
  ),
  fear(
    "Befürchtungssatz",
    "Nebensatz",
    "μή nach einem Verb des Fürchtens",
    "„dass …“",
  ),
  purpose(
    "Finalsatz",
    "Nebensatz",
    "ἵνα + Konjunktiv, verneint ἵνα μή",
    "„damit … / um zu …“",
  ),
  generalCondition(
    "verallgemeinernder Konditionalsatz",
    "Nebensatz",
    "ἐάν + Konjunktiv",
    "„wenn / wann immer …“",
  );

  final String label;

  /// "Hauptsatz" oder "Nebensatz", wie auf der Folie gegliedert.
  final String clause;

  /// Signal im Satz.
  final String rule;

  /// Übersetzungsmuster.
  final String translation;

  const SubjunctiveUse(this.label, this.clause, this.rule, this.translation);

  static List<String> get labels => [for (final use in values) use.label];
}

/// Ein Beispielsatz der Folie mit der Konjunktivform [form].
class SubjunctiveUsageTask {
  final int id;
  final String sentence;
  final String form;
  final String lemma;

  /// "Präsens" oder "Aorist".
  final String tense;

  /// Vollständige Bestimmung der Form.
  final String analysis;

  /// `null` nur bei Joh 1,27 (siehe [SubjunctiveExercises.john127]).
  final SubjunctiveUse? use;

  final String translation;

  /// Bibelstelle; die Folie nennt sie nicht. Mit Stelle ist auch die
  /// Übersetzung ergänzt.
  final String? reference;

  const SubjunctiveUsageTask({
    required this.id,
    required this.sentence,
    required this.form,
    required this.lemma,
    required this.tense,
    required this.analysis,
    required this.use,
    required this.translation,
    this.reference,
  });

  /// Ob die Übersetzung von der Folie stammt.
  bool get translationFromSlide => reference == null;
}
