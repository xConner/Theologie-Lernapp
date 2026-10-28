import '../../../utils/greek_accents.dart';
import '../../../utils/greek_normalization.dart';
import 'greek_declension.dart';
import 'verb_paradigm.dart';

/// Futur I nach den Folien „Sprachkurs Griechisch 2 – Futur“ (Kiel).
///
/// Die Folien geben keine Regel „Präsensstamm + σ“ für alle Verben, sondern
/// Gruppen mit eigener Stammveränderung (Vokalstamm παύ-σ-ω, Kontrakta
/// ποιή-σω / τιμή-σω, Labial βλέψω, Dental πείσω, Guttural ἄξω, Liquida
/// ἀγγελῶ), ein mediales Futur (ἀκούσομαι), Futura mit Stammwechsel
/// (γενήσομαι, λήψομαι, ὄψομαι …) und das Futur von εἰμί. Deshalb steht
/// der Futurstamm jedes Verbs ausdrücklich in [GreekFuture.verbs]; gebildet
/// werden daraus nur die Endungen, und zwar genau nach dem Paradigma der
/// Folien (παύσω / παύσομαι / παυθήσομαι). Ein Verb ohne Eintrag hat im
/// Trainer kein Futur – es wird nichts geraten.
///
/// Der Tempusname im Trainer ist "Futur" (= Futur I); ein Futur II
/// (Futurum exactum) kennt der Lernstoff nicht.
class GreekFuture {
  GreekFuture._();

  static const String tense = "Futur";

  /// Futurstämme der Vokabelliste. Reihenfolge und Gruppen wie auf den
  /// Folien; danach Verben der Vokabelliste, deren Futur genau nach einer
  /// Folienregel gebildet wird ([FutureSource.rule]).
  ///
  /// Bewusst ohne Eintrag (Bildung weicht von den Folienregeln ab oder ist
  /// durch die Folien nicht gedeckt): καλέω (καλέσω), ἐάω (ἐάσω, α nach ε
  /// bleibt), δοκέω (δόξω), θαυμάζω (θαυμάσομαι), τρέφω (θρέψω), κλέπτω,
  /// διδάσκω, βαίνω, γιγνώσκω, φεύγω, μανθάνω, βάλλω u. a.
  static const List<FutureVerb> verbs = [
    // Paradigma der Folien (παύω steht nicht in der Vokabelliste).
    FutureVerb(
      lemma: "παύω",
      group: FutureGroup.vowelStem,
      active: ["παύσω"],
      longStemVowel: true,
      passive: "παυθήσομαι",
    ),

    FutureVerb(
      lemma: "ποιέω",
      group: FutureGroup.epsilonContract,
      active: ["ποιήσω"],
      // Folien: τὰ ὄργανα … οὐ ποιηθήσεται.
      passive: "ποιηθήσομαι",
    ),
    FutureVerb(
      lemma: "τιμάω",
      group: FutureGroup.alphaContract,
      active: ["τιμήσω"],
      aoristPassiveInfinitive: "τιμηθῆναι",
    ),

    FutureVerb(
      lemma: "βλέπω",
      group: FutureGroup.labial,
      active: ["βλέψω"],
      aoristPassiveInfinitive: "βλεφθῆναι",
    ),
    FutureVerb(
      lemma: "γράφω",
      group: FutureGroup.labial,
      active: ["γράψω"],
      longStemVowel: false,
      aoristPassiveInfinitive: "γραφῆναι",
    ),
    FutureVerb(
      lemma: "πέμπω",
      group: FutureGroup.labial,
      active: ["πέμψω"],
      aoristPassiveInfinitive: "πεμφθῆναι",
    ),

    FutureVerb(
      lemma: "πείθω",
      group: FutureGroup.dental,
      active: ["πείσω"],
      aoristPassiveInfinitive: "πεισθῆναι",
    ),
    FutureVerb(
      lemma: "νομίζω",
      group: FutureGroup.dental,
      active: ["νομίσω"],
      longStemVowel: false,
      aoristPassiveInfinitive: "νομισθῆναι",
    ),
    FutureVerb(
      lemma: "σῴζω",
      group: FutureGroup.dental,
      active: ["σώσω"],
      aoristPassiveInfinitive: "σωθῆναι",
    ),

    FutureVerb(
      lemma: "ἄγω",
      group: FutureGroup.guttural,
      active: ["ἄξω"],
      longStemVowel: false,
    ),
    FutureVerb(
      lemma: "ἄρχω",
      group: FutureGroup.guttural,
      active: ["ἄρξω"],
      longStemVowel: false,
      aoristPassiveInfinitive: "ἀρχθῆναι",
    ),
    FutureVerb(
      lemma: "λέγω",
      group: FutureGroup.guttural,
      // Folien: λέξω (Gutturalstämme), ἐρῶ oder λέξω (Stammwechsel).
      active: ["λέξω", "ἐρῶ"],
      middle: [],
    ),

    FutureVerb(
      lemma: "ἀγγέλλω",
      group: FutureGroup.liquid,
      active: ["ἀγγελῶ"],
      aoristPassiveInfinitive: "ἀγγελθῆναι",
    ),
    FutureVerb(
      lemma: "μένω",
      group: FutureGroup.liquid,
      active: ["μενῶ"],
      middle: [],
    ),
    FutureVerb(
      lemma: "κρίνω",
      group: FutureGroup.liquid,
      active: ["κρινῶ"],
      aoristPassiveInfinitive: "κριθῆναι",
    ),

    FutureVerb(
      lemma: "ἀκούω",
      group: FutureGroup.middleFuture,
      active: [],
      middle: ["ἀκούσομαι"],
    ),

    FutureVerb(
      lemma: "γίγνομαι",
      group: FutureGroup.stemChange,
      active: [],
      middle: ["γενήσομαι"],
    ),
    FutureVerb(
      lemma: "ἔχω",
      group: FutureGroup.stemChange,
      active: ["σχήσω", "ἕξω"],
      middle: [],
    ),
    FutureVerb(
      lemma: "ἔρχομαι",
      group: FutureGroup.stemChange,
      active: [],
      // εἶμι („ich werde gehen“) hat Präsensformen und wird deshalb nicht
      // als Futur abgefragt.
      middle: ["ἐλεύσομαι"],
    ),
    FutureVerb(
      lemma: "λαμβάνω",
      group: FutureGroup.stemChange,
      active: [],
      middle: ["λήψομαι"],
      aoristPassiveInfinitive: "ληφθῆναι",
    ),
    FutureVerb(
      lemma: "ὁράω",
      group: FutureGroup.stemChange,
      active: [],
      middle: ["ὄψομαι"],
      aoristPassiveInfinitive: "ὀφθῆναι",
    ),
    FutureVerb(
      lemma: "πάσχω",
      group: FutureGroup.stemChange,
      active: [],
      middle: ["πείσομαι"],
    ),
    FutureVerb(
      lemma: "φέρω",
      group: FutureGroup.stemChange,
      active: ["οἴσω"],
      longStemVowel: true,
      middle: [],
    ),

    FutureVerb(
      lemma: "εἰμί",
      group: FutureGroup.eimi,
      active: [],
      middle: ["ἔσομαι"],
    ),

    // ---------------------------------------------------------------------
    // Weitere Verben der Vokabelliste nach den Regeln der Folien.
    // ---------------------------------------------------------------------
    FutureVerb(
      lemma: "παιδεύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["παιδεύσω"],
    ),
    FutureVerb(
      lemma: "κελεύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["κελεύσω"],
    ),
    FutureVerb(
      lemma: "στρατεύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["στρατεύσω"],
    ),
    FutureVerb(
      lemma: "ἐπιβουλεύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["ἐπιβουλεύσω"],
    ),
    FutureVerb(
      lemma: "ὑποπτεύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["ὑποπτεύσω"],
    ),
    FutureVerb(
      lemma: "ἀπολύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["ἀπολύσω"],
      longStemVowel: true,
    ),
    FutureVerb(
      lemma: "καταλύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["καταλύσω"],
      longStemVowel: true,
    ),
    FutureVerb(
      lemma: "κωλύω",
      group: FutureGroup.vowelStem,
      source: FutureSource.rule,
      active: ["κωλύσω"],
      longStemVowel: true,
    ),

    FutureVerb(
      lemma: "ἀκολουθέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["ἀκολουθήσω"],
    ),
    FutureVerb(
      lemma: "λαλέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["λαλήσω"],
    ),
    FutureVerb(
      lemma: "ἀσθενέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["ἀσθενήσω"],
      middle: [],
    ),
    FutureVerb(
      lemma: "εὐχαριστέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["εὐχαριστήσω"],
    ),
    FutureVerb(
      lemma: "κατανοέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["κατανοήσω"],
    ),
    FutureVerb(
      lemma: "περιπατέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["περιπατήσω"],
    ),
    FutureVerb(
      lemma: "προσφωνέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["προσφωνήσω"],
    ),
    FutureVerb(
      lemma: "τηρέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["τηρήσω"],
    ),
    FutureVerb(
      lemma: "ὑμνέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["ὑμνήσω"],
    ),
    FutureVerb(
      lemma: "εὐλογέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["εὐλογήσω"],
    ),
    FutureVerb(
      lemma: "φιλέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["φιλήσω"],
    ),
    FutureVerb(
      lemma: "μετρέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["μετρήσω"],
    ),
    FutureVerb(
      lemma: "πολεμέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["πολεμήσω"],
    ),
    FutureVerb(
      lemma: "πονέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["πονήσω"],
    ),
    FutureVerb(
      lemma: "ὁμολογέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["ὁμολογήσω"],
    ),
    FutureVerb(
      lemma: "αἰτέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["αἰτήσω"],
    ),
    FutureVerb(
      lemma: "ῥαθυμέω",
      group: FutureGroup.epsilonContract,
      source: FutureSource.rule,
      active: ["ῥαθυμήσω"],
    ),

    FutureVerb(
      lemma: "ἀγαπάω",
      group: FutureGroup.alphaContract,
      source: FutureSource.rule,
      active: ["ἀγαπήσω"],
    ),
    FutureVerb(
      lemma: "τελευτάω",
      group: FutureGroup.alphaContract,
      source: FutureSource.rule,
      active: ["τελευτήσω"],
    ),
    FutureVerb(
      lemma: "καταντάω",
      group: FutureGroup.alphaContract,
      source: FutureSource.rule,
      active: ["καταντήσω"],
    ),
    FutureVerb(
      lemma: "γεννάω",
      group: FutureGroup.alphaContract,
      source: FutureSource.rule,
      active: ["γεννήσω"],
    ),
    FutureVerb(
      lemma: "ἐπερωτάω",
      group: FutureGroup.alphaContract,
      source: FutureSource.rule,
      active: ["ἐπερωτήσω"],
      middle: [],
    ),
    FutureVerb(
      lemma: "ἐπιτιμάω",
      group: FutureGroup.alphaContract,
      source: FutureSource.rule,
      active: ["ἐπιτιμήσω"],
      middle: [],
    ),

    FutureVerb(
      lemma: "ἀναβλέπω",
      group: FutureGroup.labial,
      source: FutureSource.rule,
      active: ["ἀναβλέψω"],
    ),

    FutureVerb(
      lemma: "βαπτίζω",
      group: FutureGroup.dental,
      source: FutureSource.rule,
      active: ["βαπτίσω"],
      longStemVowel: false,
    ),
    FutureVerb(
      lemma: "ἀτιμάζω",
      group: FutureGroup.dental,
      source: FutureSource.rule,
      active: ["ἀτιμάσω"],
      longStemVowel: false,
    ),
    FutureVerb(
      lemma: "πειράζω",
      group: FutureGroup.dental,
      source: FutureSource.rule,
      active: ["πειράσω"],
      longStemVowel: false,
    ),
    FutureVerb(
      lemma: "φράζω",
      group: FutureGroup.dental,
      source: FutureSource.rule,
      active: ["φράσω"],
      longStemVowel: false,
    ),

    // Das Aoristblatt führt die ττ-Verben als Gutturalstämme.
    FutureVerb(
      lemma: "πράττω",
      group: FutureGroup.guttural,
      source: FutureSource.rule,
      active: ["πράξω"],
      longStemVowel: true,
      aoristPassiveInfinitive: "πραχθῆναι",
    ),
    FutureVerb(
      lemma: "τάττω",
      group: FutureGroup.guttural,
      source: FutureSource.rule,
      active: ["τάξω"],
      longStemVowel: false,
      aoristPassiveInfinitive: "ταχθῆναι",
    ),
    FutureVerb(
      lemma: "φυλάττω",
      group: FutureGroup.guttural,
      source: FutureSource.rule,
      active: ["φυλάξω"],
      longStemVowel: false,
      aoristPassiveInfinitive: "φυλαχθῆναι",
    ),

    FutureVerb(
      lemma: "παραγγέλλω",
      group: FutureGroup.liquid,
      source: FutureSource.rule,
      active: ["παραγγελῶ"],
    ),

    // Komposita der Folienverben mit Stammwechsel.
    FutureVerb(
      lemma: "συλλαμβάνω",
      group: FutureGroup.stemChange,
      source: FutureSource.rule,
      active: [],
      middle: ["συλλήψομαι"],
    ),
    FutureVerb(
      lemma: "παρέρχομαι",
      group: FutureGroup.stemChange,
      source: FutureSource.rule,
      active: [],
      middle: ["παρελεύσομαι"],
    ),
    FutureVerb(
      lemma: "παραγίγνομαι",
      group: FutureGroup.stemChange,
      source: FutureSource.rule,
      active: [],
      middle: ["παραγενήσομαι"],
    ),
  ];

  static final Map<String, FutureVerb> _byLemma = {
    for (final verb in verbs) verb.lemma: verb,
  };

  /// Der Eintrag des Verbs; `null`, wenn sein Futur nicht hinterlegt ist.
  static FutureVerb? of(String lemma) => _byLemma[lemma];

  /// Ob der Trainer das Futur des Verbs kennt.
  static bool supports(String lemma) => _byLemma.containsKey(lemma);

  // Endungen der Folien (παύ-σ-ω …, παύ-σ-ομαι …), an den Futurstamm
  // einschließlich σ (ψ, ξ) gehängt. Bei -όμεθα und im Partizip Medium
  // trägt die Endung den Akzent, sonst die letzte Silbe des Stammes.
  static const List<String> _activeEndings = [
    "ω",
    "εις",
    "ει",
    "ομεν",
    "ετε",
    "ουσι(ν)",
  ];

  static const List<String> _middleEndings = [
    "ομαι",
    "ῃ",
    "εται",
    "όμεθα",
    "εσθε",
    "ονται",
  ];

  // Liquida (ἀγγελῶ) und ἐρῶ: kontrahierte Endungen wie bei den
  // ε-Kontrakta (ποιῶ). Die Folien nennen nur die 1. Sg.; die übrigen
  // Formen folgen der ε-Kontraktion.
  static const List<String> _contractActiveEndings = [
    "ῶ",
    "εῖς",
    "εῖ",
    "οῦμεν",
    "εῖτε",
    "οῦσι(ν)",
  ];

  static const List<String> _contractMiddleEndings = [
    "οῦμαι",
    "ῇ",
    "εῖται",
    "ούμεθα",
    "εῖσθε",
    "οῦνται",
  ];

  /// Alle Futurformen eines Verbs je Genus Verbi ("Aktiv", "Medium",
  /// "Passiv"), bei zwei Futura (σχήσω / ἕξω) beide. Leer, wenn das Futur
  /// des Verbs nicht hinterlegt ist.
  static Map<String, List<FutureVoiceForms>> conjugate(String lemma) {
    final verb = of(lemma);

    if (verb == null) {
      return const {};
    }

    return {
      if (verb.active.isNotEmpty)
        "Aktiv": [
          for (final form in verb.active) _active(form, verb.longStemVowel),
        ],
      if (verb.middleForms.isNotEmpty)
        "Medium": [
          for (final form in verb.middleForms)
            verb.lemma == "εἰμί" ? _eimi : _middle(form),
        ],
      if (verb.passiveForm != null) "Passiv": [_middle(verb.passiveForm!)],
    };
  }

  /// Die Futurformen als Formen des Trainers: Indikativ, Infinitiv und
  /// Partizip (dekliniert wie im übrigen Trainer). Einen Imperativ Futur
  /// gibt es nicht.
  static List<VerbForm> formsOf(String lemma) {
    final result = <VerbForm>[];

    for (final MapEntry(key: voice, value: variants) in conjugate(
      lemma,
    ).entries) {
      for (final variant in variants) {
        for (var i = 0; i < variant.finite.length; i++) {
          result.add((
            form: variant.finite[i],
            analysis: (
              mood: VerbMood.indicative,
              tense: tense,
              voice: voice,
              person: i % 3 + 1,
              number: i < 3 ? "Sg" : "Pl",
              grammaticalCase: null,
              gender: null,
            ),
          ));
        }

        result.add((
          form: variant.infinitive,
          analysis: (
            mood: VerbMood.infinitive,
            tense: tense,
            voice: voice,
            person: null,
            number: null,
            grammaticalCase: null,
            gender: null,
          ),
        ));

        final participle = variant.participle;

        if (participle == null) continue;

        for (final cell in participle.forms) {
          result.add((
            form: cell.form,
            analysis: (
              mood: VerbMood.participle,
              tense: tense,
              voice: voice,
              person: null,
              number: cell.number,
              grammaticalCase: cell.grammaticalCase,
              gender: cell.gender,
            ),
          ));
        }
      }
    }

    return result;
  }

  /// [paradigm] samt den Futurformen des Verbs; unverändert, wenn sein
  /// Futur nicht hinterlegt ist.
  static VerbParadigm extend(String lemma, VerbParadigm paradigm) {
    final future = formsOf(lemma);

    if (future.isEmpty) {
      return paradigm;
    }

    return VerbParadigm([
      for (final form in paradigm.forms)
        if (form.analysis.tense != tense) form,
      ...future,
    ]);
  }

  /// Futur Passiv aus dem Infinitiv Aorist Passiv: Aorist-Passiv-Stamm
  /// (παυθη-) + σ + mediale Endungen (παυθήσομαι), wie auf den Folien
  /// gegliedert (παυ-θή-σ-ομαι). `null` bei einem anderen Infinitiv.
  static String? passiveFromAoristInfinitive(String infinitive) {
    if (!infinitive.endsWith("ῆναι")) {
      return null;
    }

    return "${infinitive.substring(0, infinitive.length - 4)}ήσομαι";
  }

  static FutureVoiceForms _active(String firstSingular, bool? longStemVowel) {
    if (firstSingular.endsWith("ῶ")) {
      final stem = firstSingular.substring(0, firstSingular.length - 1);

      return _contracted(stem, _contractActiveEndings, "εῖν", (
        masculine: "$stemῶν",
        feminine: "$stemοῦσα",
        neuter: "$stemοῦν",
      ));
    }

    final stem = firstSingular.substring(0, firstSingular.length - 1);
    final neuter = _neuterStem(stem, longStemVowel);

    return (
      finite: [for (final ending in _activeEndings) "$stem$ending"],
      infinitive: "$stemειν",
      participle: neuter == null
          ? null
          : declineParticiple(
              masculine: "$stemων",
              feminine: "$stemουσα",
              neuter: "$neuterον",
            ),
    );
  }

  static FutureVoiceForms _middle(String firstSingular) {
    if (firstSingular.endsWith("οῦμαι")) {
      final stem = firstSingular.substring(0, firstSingular.length - 5);

      return _contracted(stem, _contractMiddleEndings, "εῖσθαι", (
        masculine: "$stemούμενος",
        feminine: "$stemουμένη",
        neuter: "$stemούμενον",
      ));
    }

    final stem = firstSingular.substring(0, firstSingular.length - 4);
    final plain = stripGreekAccent(stem);

    return (
      finite: [
        for (final ending in _middleEndings)
          ending == "όμεθα" ? "$plain$ending" : "$stem$ending",
      ],
      infinitive: "$stemεσθαι",
      participle: declineParticiple(
        masculine: "$plainόμενος",
        feminine: "$plainομένη",
        neuter: "$plainόμενον",
      ),
    );
  }

  static FutureVoiceForms _contracted(
    String stem,
    List<String> endings,
    String infinitive,
    ({String masculine, String feminine, String neuter}) participle,
  ) {
    return (
      finite: [for (final ending in endings) "$stem$ending"],
      infinitive: "$stem$infinitive",
      participle: declineParticiple(
        masculine: participle.masculine,
        feminine: participle.feminine,
        neuter: participle.neuter,
      ),
    );
  }

  /// Futur von εἰμί, wie auf den Folien: ἔσται statt *ἔσεται.
  static final FutureVoiceForms _eimi = (
    finite: const ["ἔσομαι", "ἔσῃ", "ἔσται", "ἐσόμεθα", "ἔσεσθε", "ἔσονται"],
    infinitive: "ἔσεσθαι",
    participle: declineParticiple(
      masculine: "ἐσόμενος",
      feminine: "ἐσομένη",
      neuter: "ἐσόμενον",
    ),
  );

  /// Stamm des Neutrums παῦσον: Steht der Akzent auf einem von Natur
  /// langen Vokal, wird der Akut zum Zirkumflex (παύσων – παῦσον, aber
  /// γράψων – γράψον). Bei α, ι, υ entscheidet [longStemVowel]; ohne
  /// Angabe `null` (das Partizip wird dann nicht gebildet).
  static String? _neuterStem(String stem, bool? longStemVowel) {
    final runes = stem.runes.toList();

    final index = runes.lastIndexWhere((rune) {
      return hasGreekAccent(String.fromCharCode(rune));
    });

    if (index < 0) {
      return null;
    }

    final vowel = _plain(runes[index]);
    final previous = index > 0 ? _plain(runes[index - 1]) : "";

    final bool long;

    if (vowel == "η" || vowel == "ω") {
      long = true;
    } else if (vowel == "ε" || vowel == "ο") {
      long = false;
    } else if ((vowel == "ι" || vowel == "υ") &&
        const {"α", "ε", "ο", "υ"}.contains(previous)) {
      long = true;
    } else if (longStemVowel != null) {
      long = longStemVowel;
    } else {
      return null;
    }

    if (!long) {
      return stem;
    }

    final circumflex = _circumflexOf(runes[index]);

    if (circumflex == null) {
      return null;
    }

    runes[index] = circumflex;

    return String.fromCharCodes(runes);
  }

  static String _plain(int rune) {
    return normalizeGreekForComparison(
      stripGreekAccent(String.fromCharCode(rune)),
    );
  }

  static const Map<int, int> _circumflex = {
    0x03AC: 0x1FB6, // ά → ᾶ
    0x1F71: 0x1FB6,
    0x03AE: 0x1FC6, // ή → ῆ
    0x1F75: 0x1FC6,
    0x03AF: 0x1FD6, // ί → ῖ
    0x1F77: 0x1FD6,
    0x03CD: 0x1FE6, // ύ → ῦ
    0x1F7B: 0x1FE6,
    0x03CE: 0x1FF6, // ώ → ῶ
    0x1F7D: 0x1FF6,
    0x1FB4: 0x1FB7, // ᾴ → ᾷ
    0x1FC4: 0x1FC7, // ῄ → ῇ
    0x1FF4: 0x1FF7, // ῴ → ῷ
  };

  // Akut → Zirkumflex. Vokale mit Spiritus: im Achterblock folgt der
  // Zirkumflex zwei Stellen nach dem Akut (ἄ → ἆ); ε und ο haben keinen.
  static int? _circumflexOf(int rune) {
    if ((rune >= 0x1F00 && rune <= 0x1F6F) ||
        (rune >= 0x1F80 && rune <= 0x1FAF)) {
      final block = rune & 0xFFF0;
      final offset = rune & 0x7;

      if (block == 0x1F10 || block == 0x1F40 || (offset != 4 && offset != 5)) {
        return null;
      }

      return rune + 2;
    }

    return _circumflex[rune];
  }
}

/// Gruppen der Folien.
enum FutureGroup {
  vowelStem("Vokalstämme", "Stamm + σ + Endung (παύ-σ-ω)"),
  epsilonContract("ε-Kontrakta", "ε wird vor σ zu η gedehnt (ποιέω → ποιήσω)"),
  alphaContract("α-Kontrakta", "α wird vor σ zu η gedehnt (τιμάω → τιμήσω)"),
  labial("Labialstämme", "π, β, φ + σ → ψ (βλέπω → βλέψω)"),
  dental("Dentalstämme", "τ, δ, θ, ζ fallen vor σ aus (πείθω → πείσω)"),
  guttural("Gutturalstämme", "κ, γ, χ + σ → ξ (ἄγω → ἄξω)"),
  liquid(
    "Liquidstämme",
    "λ, μ, ν, ρ: kein σ, kontrahierte Endungen (ἀγγέλλω → ἀγγελῶ)",
  ),
  middleFuture(
    "Mediales Futur",
    "aktive Bedeutung, mediale Form (ἀκούω → ἀκούσομαι)",
  ),
  stemChange(
    "Futur mit Stammwechsel",
    "eigener Futurstamm (λαμβάνω → λήψομαι)",
  ),
  eimi("Futur von εἰμί", "mediale Formen, 3. Sg. ἔσται");

  final String label;
  final String rule;

  const FutureGroup(this.label, this.rule);
}

/// Herkunft eines Eintrags: auf den Folien genannt oder ein Verb der
/// Vokabelliste, dessen Futur nach der Regel seiner Foliengruppe gebildet
/// wird.
enum FutureSource { slides, rule }

/// Futur eines Verbs: die 1. Sg. Indikativ je Genus Verbi.
class FutureVerb {
  final String lemma;
  final FutureGroup group;
  final FutureSource source;

  /// 1. Sg. Futur Aktiv; zwei Einträge bei zwei Futura (σχήσω / ἕξω).
  /// Leer bei medialem Futur.
  final List<String> active;

  /// 1. Sg. Futur Medium. `null`: regelmäßig vom Aktiv gebildet
  /// (παύσω → παύσομαι); leer: kein Medium im Lernstoff.
  final List<String>? middle;

  /// 1. Sg. Futur Passiv, wenn die Folien sie nennen (παυθήσομαι).
  final String? passive;

  /// Infinitiv Aorist Passiv, aus dem das Futur Passiv gebildet wird
  /// (dieselbe Form wie im Aorist des Trainers).
  final String? aoristPassiveInfinitive;

  /// Ob der betonte Stammvokal α, ι oder υ von Natur lang ist (für das
  /// Neutrum des Partizips: παῦσον, aber γράψον).
  final bool? longStemVowel;

  const FutureVerb({
    required this.lemma,
    required this.group,
    required this.active,
    this.source = FutureSource.slides,
    this.middle,
    this.passive,
    this.aoristPassiveInfinitive,
    this.longStemVowel,
  });

  /// 1. Sg. Futur Medium (παύσομαι, ἀγγελοῦμαι, ἀκούσομαι).
  List<String> get middleForms {
    return middle ??
        [
          for (final form in active)
            form.endsWith("ῶ")
                ? "${form.substring(0, form.length - 1)}οῦμαι"
                : "${form.substring(0, form.length - 1)}ομαι",
        ];
  }

  /// 1. Sg. Futur Passiv; `null`, wenn sie sich nicht zuverlässig bilden
  /// lässt.
  String? get passiveForm {
    return passive ??
        (aoristPassiveInfinitive == null
            ? null
            : GreekFuture.passiveFromAoristInfinitive(
                aoristPassiveInfinitive!,
              ));
  }
}

/// Formen eines Genus Verbi im Futur: Indikativ (1.–3. Sg., 1.–3. Pl.),
/// Infinitiv und das deklinierte Partizip (`null`, wenn es sich nicht
/// zuverlässig bilden lässt).
typedef FutureVoiceForms = ({
  List<String> finite,
  String infinitive,
  DeclensionParadigm? participle,
});
