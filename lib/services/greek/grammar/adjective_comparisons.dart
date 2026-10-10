import '../../../models/greek/grammar/adjective_comparison.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../utils/greek_accents.dart';
import 'greek_declension.dart';

/// Eine Tabellenform der Steigerung (Nominativ Sg. Maskulinum bzw. das
/// Adverb) mit ihrer Stufe und – soweit sie sich deklinieren lässt – allen
/// ihren Formen.
typedef ComparisonBase = ({
  String text,
  String degree,
  String? note,
  DeclensionParadigm? paradigm,
});

/// Eine grammatisch mögliche Bestimmung einer Form der Steigerung. Kasus,
/// Numerus ("Sg") und Genus sind `null` bei Formen ohne Deklination
/// (ἥκιστα).
typedef ComparisonAnalysis = ({
  int adjectiveId,
  String degree,
  String base,
  String? grammaticalCase,
  String? number,
  String? gender,
});

/// Lernstoff der Adjektivsteigerung (Griechisch I). Anders als Nomen und
/// Verben kommen die Formen nicht vom Backend, sondern stehen hier fest.
///
/// Gewicht = inhaltliche Priorität: Die unregelmäßigen Steigerungen kommen
/// deutlich häufiger als die regelmäßigen; der Lernbedarf aus
/// `GrammarLearning` wird zusätzlich eingerechnet.
class AdjectiveComparisons {
  AdjectiveComparisons._();

  /// Wortart im Grammatiktrainer.
  static const String type = "comparison";

  static const String positive = "Positiv";
  static const String comparative = "Komparativ";
  static const String superlative = "Superlativ";

  static const List<String> degrees = [positive, comparative, superlative];

  static const List<AdjectiveComparison> all = [
    // -------------------------------------------------------------------------
    // UNREGELMÄSSIG
    // -------------------------------------------------------------------------
    AdjectiveComparison(
      id: 10001,
      positive: "ἀγαθός",
      translations: ["gut"],
      irregular: true,
      weight: 6,
      comparatives: [
        ComparisonForm("ἀμείνων", neuter: "ἄμεινον"),
        ComparisonForm("βελτίων", neuter: "βέλτιον"),
        ComparisonForm("κρείττων", neuter: "κρεῖττον"),
      ],
      superlatives: [
        ComparisonForm("ἄριστος"),
        ComparisonForm("βέλτιστος"),
        ComparisonForm("κράτιστος"),
      ],
    ),
    AdjectiveComparison(
      id: 10002,
      positive: "κακός",
      translations: ["schlecht", "feige"],
      irregular: true,
      weight: 6,
      comparatives: [
        ComparisonForm("κακίων", neuter: "κάκιον"),
        ComparisonForm("χείρων", neuter: "χεῖρον"),
        ComparisonForm("ἥττων", neuter: "ἧττον"),
      ],
      superlatives: [
        ComparisonForm("κάκιστος"),
        ComparisonForm("χείριστος"),
        ComparisonForm("ἥκιστα", note: "Adv."),
      ],
    ),
    AdjectiveComparison(
      id: 10003,
      positive: "μέγας",
      translations: ["groß"],
      irregular: true,
      weight: 4,
      comparatives: [ComparisonForm("μείζων", neuter: "μεῖζον")],
      superlatives: [ComparisonForm("μέγιστος")],
    ),
    AdjectiveComparison(
      id: 10004,
      positive: "μικρός",
      translations: ["klein"],
      irregular: true,
      weight: 4,
      comparatives: [
        ComparisonForm("μικρότερος"),
        ComparisonForm("μείων", neuter: "μεῖον"),
        ComparisonForm("ἐλάττων", neuter: "ἔλαττον"),
      ],
      superlatives: [ComparisonForm("μικρότατος"), ComparisonForm("ἐλάχιστος")],
    ),
    AdjectiveComparison(
      id: 10005,
      positive: "πολύς",
      translations: ["viel"],
      irregular: true,
      weight: 3.5,
      comparatives: [ComparisonForm("πλείων", neuter: "πλέον")],
      superlatives: [ComparisonForm("πλεῖστος")],
      comparativeGenitives: ["πλείονος", "πλέονος"],
    ),
    AdjectiveComparison(
      id: 10006,
      positive: "ὀλίγος",
      translations: ["wenig", "klein", "gering"],
      irregular: true,
      weight: 3,
      comparatives: [
        ComparisonForm("ὀλείζων", rare: true),
        ComparisonForm("ἐλάττων", neuter: "ἔλαττον"),
      ],
      superlatives: [
        ComparisonForm("ὀλίγιστος", rare: true),
        ComparisonForm("ἐλάχιστος"),
      ],
    ),

    // -------------------------------------------------------------------------
    // -ίων / -ιστος
    // -------------------------------------------------------------------------
    AdjectiveComparison(
      id: 10007,
      positive: "καλός",
      translations: ["schön", "gut"],
      irregular: true,
      weight: 2.5,
      comparatives: [ComparisonForm("καλλίων", neuter: "κάλλιον")],
      superlatives: [ComparisonForm("κάλλιστος")],
    ),
    AdjectiveComparison(
      id: 10008,
      positive: "ταχύς",
      translations: ["schnell"],
      irregular: true,
      weight: 2.5,
      comparatives: [ComparisonForm("θάττων", neuter: "θᾶττον")],
      superlatives: [ComparisonForm("τάχιστος")],
    ),

    // -------------------------------------------------------------------------
    // REGELMÄSSIG: -τερος / -τατος
    // -------------------------------------------------------------------------
    AdjectiveComparison(
      id: 10009,
      positive: "βέβαιος",
      translations: ["feststehend", "fest", "zuverlässig", "sicher"],
      irregular: false,
      weight: 1,
      comparatives: [ComparisonForm("βεβαιότερος")],
      superlatives: [ComparisonForm("βεβαιότατος")],
    ),
    AdjectiveComparison(
      id: 10010,
      positive: "πονηρός",
      translations: ["schlecht", "untauglich", "niederträchtig"],
      irregular: false,
      weight: 1,
      comparatives: [ComparisonForm("πονηρότερος")],
      superlatives: [ComparisonForm("πονηρότατος")],
    ),
    AdjectiveComparison(
      id: 10011,
      positive: "σοφός",
      translations: ["geschickt", "klug", "weise"],
      irregular: false,
      weight: 1,
      comparatives: [ComparisonForm("σοφώτερος")],
      superlatives: [ComparisonForm("σοφώτατος")],
    ),
    AdjectiveComparison(
      id: 10012,
      positive: "ἄξιος",
      translations: ["wert", "würdig"],
      irregular: false,
      weight: 1,
      comparatives: [ComparisonForm("ἀξιώτερος")],
      superlatives: [ComparisonForm("ἀξιώτατος")],
    ),

    // -------------------------------------------------------------------------
    // REGELMÄSSIG MIT -εσ-
    // -------------------------------------------------------------------------
    AdjectiveComparison(
      id: 10013,
      positive: "σώφρων",
      translations: ["besonnen", "maßvoll"],
      irregular: false,
      weight: 1,
      comparatives: [ComparisonForm("σωφρονέστερος")],
      superlatives: [ComparisonForm("σωφρονέστατος")],
    ),
    AdjectiveComparison(
      id: 10014,
      positive: "εὐδαίμων",
      translations: ["glücklich", "wohlhabend"],
      irregular: false,
      weight: 1,
      comparatives: [ComparisonForm("εὐδαιμονέστερος")],
      superlatives: [ComparisonForm("εὐδαιμονέστατος")],
    ),
  ];

  /// Die Adjektive als Einträge des Grammatiktrainers (Wortart [type], ohne
  /// Schritt).
  static final List<GreekVocabularyEntry> entries = [
    for (final comparison in all)
      GreekVocabularyEntry(
        id: comparison.id,
        step: 0,
        type: type,
        lemma: comparison.positive,
        translations: comparison.translations,
        weight: comparison.weight,
      ),
  ];

  static AdjectiveComparison? byId(int id) {
    for (final comparison in all) {
      if (comparison.id == id) return comparison;
    }

    return null;
  }

  /// IDs der Adjektive der gewählten Steigerungsarten ("irregular",
  /// "regular").
  static Set<int> idsOfKinds(List<String> kinds) {
    return {
      for (final comparison in all)
        if (kinds.contains(comparison.kind)) comparison.id,
    };
  }

  /// Alle Adjektive, zu denen die Form [form] gehört – als Tabellenform
  /// oder als eine ihrer flektierten Formen. ἐλάττων / ἐλάχιστος: μικρός
  /// und ὀλίγος. Verglichen wird die exakte Schreibung der Daten.
  static List<AdjectiveComparison> ownersOf(String form) {
    final ids = {for (final analysis in analysesOf(form)) analysis.adjectiveId};

    return [
      for (final comparison in all)
        if (comparison.gradedForms.contains(form) ||
            ids.contains(comparison.id))
          comparison,
    ];
  }

  // ---------------------------------------------------------------------------
  // FLEKTIERTE FORMEN
  // ---------------------------------------------------------------------------

  // Positive der a-/o-Deklination mit zurückgezogenem Akzent und ihr Stamm
  // vor langer Endsilbe (βέβαιος, aber βεβαίου). Endbetonte Positive
  // (σοφός) brauchen die Angabe nicht.
  static const Map<String, String> _recessivePositives = {
    "βέβαιος": "βεβαί",
    "ἄξιος": "ἀξί",
    "ὀλίγος": "ὀλίγ",
  };

  // Nach ε, ι und ρ endet das Femininum auf -α statt -η.
  static bool _alphaFeminine(String stem) {
    return stem.endsWith("ε") || stem.endsWith("ι") || stem.endsWith("ρ");
  }

  // Der Positiv wird nur nach der a-/o-Deklination gebildet; μέγας, πολύς,
  // ταχύς, σώφρων und εὐδαίμων bleiben ohne flektierten Positiv.
  static DeclensionParadigm? _positiveParadigm(String positive) {
    if (positive.endsWith("ός")) {
      final stem = positive.substring(0, positive.length - 2);

      return declineOxytone(stem: stem, alphaFeminine: _alphaFeminine(stem));
    }

    final long = _recessivePositives[positive];

    if (long == null) {
      return null;
    }

    final short = positive.substring(0, positive.length - 2);

    return declineRecessive(
      short: short,
      long: long,
      alphaFeminine: _alphaFeminine(short),
    );
  }

  // -τερος, -α, -ον / -τατος, -η, -ον / -ιστος, -η, -ον nach der
  // a-/o-Deklination, -(ί)ων, -(ι)ον nach der 3. Deklination.
  static DeclensionParadigm? _gradedParadigm(ComparisonForm form) {
    final text = form.text;

    // Zweisilbig: Der Akzent wandert nicht, er wechselt nur die Art.
    if (text == "πλεῖστος") {
      return declineRecessive(
        short: "πλεῖστ",
        long: "πλείστ",
        alphaFeminine: false,
      );
    }

    for (final (suffix, accented, alphaFeminine) in const [
      ("τερος", "τέρ", true),
      ("τατος", "τάτ", false),
      ("ιστος", "ίστ", false),
    ]) {
      if (!text.endsWith(suffix)) continue;

      final prefix = text.substring(0, text.length - suffix.length);

      if (!hasGreekAccent(prefix)) {
        return null;
      }

      return declineRecessive(
        short: text.substring(0, text.length - 2),
        long: "${stripGreekAccent(prefix)}$accented",
        alphaFeminine: alphaFeminine,
      );
    }

    final neuter = form.neuter;

    if (neuter == null) {
      return null;
    }

    // πλείων bildet das Neutrum vom kürzeren Stamm: πλέον.
    if (text == "πλείων" && neuter == "πλέον") {
      return declineComparative(
        masculine: text,
        neuter: "πλεῖον",
      )?.replacing("πλεῖον", neuter);
    }

    return declineComparative(masculine: text, neuter: neuter);
  }

  static final Map<int, List<ComparisonBase>> _bases = {
    for (final comparison in all)
      comparison.id: [
        if (_positiveParadigm(comparison.positive) case final paradigm?)
          (
            text: comparison.positive,
            degree: positive,
            note: null,
            paradigm: paradigm,
          ),
        for (final (degree, forms) in [
          (comparative, comparison.comparatives),
          (superlative, comparison.superlatives),
        ])
          for (final form in forms)
            if (!form.rare)
              (
                text: form.text,
                degree: degree,
                note: form.note,
                paradigm: _gradedParadigm(form),
              ),
      ],
  };

  /// Die Tabellenformen des Adjektivs, die flektiert vorgelegt werden: der
  /// Positiv (nur a-/o-Deklination), Komparative und Superlative – keine
  /// seltenen Formen.
  static List<ComparisonBase> basesOf(AdjectiveComparison comparison) {
    return _bases[comparison.id] ?? const [];
  }

  /// Steigerungsstufe einer Tabellenform des Adjektivs (Neutrum und Genitiv
  /// des Komparativs eingeschlossen).
  static String degreeOf(AdjectiveComparison comparison, String form) {
    if (form == comparison.positive) {
      return positive;
    }

    return AdjectiveComparison.allTexts(
              comparison.comparatives,
            ).contains(form) ||
            comparison.comparativeGenitives.contains(form)
        ? comparative
        : superlative;
  }

  static final Map<String, List<ComparisonAnalysis>> _analyses = () {
    final index = <String, List<ComparisonAnalysis>>{};

    void add(String form, ComparisonAnalysis analysis) {
      final known = index.putIfAbsent(form, () => []);

      if (!known.contains(analysis)) {
        known.add(analysis);
      }
    }

    for (final comparison in all) {
      for (final base in basesOf(comparison)) {
        final paradigm = base.paradigm;

        if (paradigm == null) {
          add(base.text, (
            adjectiveId: comparison.id,
            degree: base.degree,
            base: base.text,
            grammaticalCase: null,
            number: null,
            gender: null,
          ));

          continue;
        }

        for (final cell in paradigm.forms) {
          add(cell.form, (
            adjectiveId: comparison.id,
            degree: base.degree,
            base: base.text,
            grammaticalCase: cell.grammaticalCase,
            number: cell.number,
            gender: cell.gender,
          ));
        }
      }

      // Eigens gelernte Nebenform des Genitivs (πλέονος neben πλείονος).
      for (final genitive in comparison.comparativeGenitives) {
        for (final gender in declensionGenders) {
          add(genitive, (
            adjectiveId: comparison.id,
            degree: comparative,
            base: comparison.comparatives.first.text,
            grammaticalCase: "Genitiv",
            number: "Sg",
            gender: gender,
          ));
        }
      }
    }

    return index;
  }();

  /// Die möglichen Bestimmungen der Form [form] in Worten, Genera
  /// zusammengefasst: "Komparativ · Genitiv Sg. m/n". Mit [degree] steht die
  /// Steigerungsstufe dabei, mit [form] Kasus, Numerus und Genus.
  static List<String> describeForm(
    String shown, {
    bool degree = true,
    bool form = true,
  }) {
    final genders = <String, List<String>>{};

    for (final analysis in analysesOf(shown)) {
      final declined = form && analysis.grammaticalCase != null;

      final label = [
        if (degree) analysis.degree,
        if (declined) "${analysis.grammaticalCase} ${analysis.number}.",
      ].join(" · ");

      final known = genders.putIfAbsent(label, () => []);
      final gender = analysis.gender;

      if (declined && gender != null && !known.contains(gender)) {
        known.add(gender);
      }
    }

    return [
      for (final MapEntry(key: label, value: genders) in genders.entries)
        if (label.isNotEmpty)
          genders.isEmpty ? label : "$label ${genders.join('/')}",
    ];
  }

  /// Alle Bestimmungen, die für die Form [form] möglich sind – auch über
  /// Adjektive hinweg (ἐλάττονος: μικρός und ὀλίγος) und über die Genera
  /// (σοφωτέρου: Maskulinum und Neutrum).
  static List<ComparisonAnalysis> analysesOf(String form) {
    return _analyses[form] ?? const [];
  }
}
