import '../../../models/greek/grammar/adjective_comparison.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';

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

  /// Alle Adjektive, zu denen die gesteigerte Form [form] gehört.
  /// ἐλάττων / ἐλάχιστος: μικρός und ὀλίγος. Verglichen wird die exakte
  /// Schreibung der Daten.
  static List<AdjectiveComparison> ownersOf(String form) {
    return [
      for (final comparison in all)
        if (comparison.gradedForms.contains(form)) comparison,
    ];
  }
}
