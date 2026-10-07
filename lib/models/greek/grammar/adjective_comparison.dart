/// Eine Steigerungsform (Nominativ Sg. Maskulinum bzw. das Adverb).
/// [neuter] ist die Neutrumform, wo sie zum Lernstoff gehört (ἄμεινον).
/// Seltene Formen ([rare], in der Tabelle eingeklammert) gelten als richtige
/// Antwort, werden aber nie selbst zur Bestimmung vorgelegt.
class ComparisonForm {
  final String text;
  final String? neuter;
  final bool rare;

  /// Hinweis zur Form, z. B. "Adverb" bei ἥκιστα.
  final String? note;

  const ComparisonForm(this.text, {this.neuter, this.rare = false, this.note});

  /// Maskulinum und Neutrum.
  List<String> get texts => [text, ?neuter];
}

/// Positiv, Komparativ(e) und Superlativ(e) eines Adjektivs.
class AdjectiveComparison {
  /// Eigener Nummernkreis, getrennt von den IDs der Vokabelliste; die
  /// Lernkarte der Grundform heißt `lemma.<id>`.
  final int id;
  final String positive;
  final List<String> translations;

  /// Unregelmäßige Steigerung (einschließlich -ίων / -ιστος).
  final bool irregular;

  /// Inhaltliche Priorität bei der Auswahl.
  final double weight;

  final List<ComparisonForm> comparatives;
  final List<ComparisonForm> superlatives;

  /// Genitiv Sg. des Komparativs, wo er eigens gelernt wird (πολύς).
  final List<String> comparativeGenitives;

  const AdjectiveComparison({
    required this.id,
    required this.positive,
    required this.translations,
    required this.irregular,
    required this.weight,
    required this.comparatives,
    required this.superlatives,
    this.comparativeGenitives = const [],
  });

  String get kind => irregular ? "irregular" : "regular";

  /// Alle Formen eines Grads (Komparativ oder Superlativ) einschließlich
  /// Neutra und seltener Formen.
  static List<String> allTexts(List<ComparisonForm> forms) {
    return [for (final form in forms) ...form.texts];
  }

  /// Alle gesteigerten Formen: Komparative, Superlative (jeweils mit Neutra
  /// und seltenen Formen) und der Genitiv des Komparativs.
  List<String> get gradedForms => [
    ...allTexts(comparatives),
    ...allTexts(superlatives),
    ...comparativeGenitives,
  ];

  /// Die gesteigerten Formen, die als Aufgabe vorgelegt werden (keine
  /// seltenen), mit einem Hinweis zur Form ("Neutrum", "Adv.", "Gen. Sg.").
  /// Der Grad selbst wird nicht verraten.
  List<({String text, String? note})> get shownForms => [
    for (final form in [...comparatives, ...superlatives])
      if (!form.rare) ...[
        (text: form.text, note: form.note),
        if (form.neuter != null) (text: form.neuter!, note: "Neutrum"),
      ],
    for (final genitive in comparativeGenitives)
      (text: genitive, note: "Gen. Sg."),
  ];

  /// "ἀμείνων (ἄμεινον) / βελτίων (βέλτιον)", seltene Formen eingeklammert:
  /// "(ὀλείζων) / ἐλάττων (ἔλαττον)".
  static String describe(List<ComparisonForm> forms) {
    return forms
        .map((form) {
          var text = form.neuter == null
              ? form.text
              : "${form.text} (${form.neuter})";

          if (form.note != null) {
            text = "$text (${form.note})";
          }

          return form.rare ? "($text)" : text;
        })
        .join(" / ");
  }

  /// Die vollständige Reihe: "ἀγαθός → ἀμείνων (ἄμεινον) / … → ἄριστος / …".
  String get row {
    return "$positive → ${describe(comparatives)} → ${describe(superlatives)}";
  }
}
