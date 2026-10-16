/// Argumente (Schlussregeln) des Kurses und ihre Verfügbarkeit je Lektion.
library;

enum ProofRule {
  assumption("A", "Annahme", 0),
  andIntro("+K", "Einführung der Konjunktion", 2),
  andElim("-K", "Beseitigung der Konjunktion", 1),
  orIntro("+A", "Einführung der Adjunktion", 1),
  orElim("-A", "Beseitigung der Adjunktion", 2),
  impIntro("+I", "Einführung der Implikation", 2),
  impElim("-I", "Beseitigung der Implikation (modus ponens)", 2),
  iffIntro("+Ä", "Einführung der Äquivalenz", 2),
  iffElim("-Ä", "Beseitigung der Äquivalenz", 1),
  dnIntro("+DN", "Einführung der doppelten Negation", 1),
  dnElim("-DN", "Beseitigung der doppelten Negation", 1),
  tautology("T", "Tautologie", 0),
  raa("RAA", "reductio ad absurdum", 3),
  efq("EFQ", "ex falso quodlibet", 1),
  veq("VEQ", "verum ex quodlibet", 1),
  orElimCases("-A", "Beseitigung der Adjunktion durch Fallunterscheidung", 3),
  contraposition("KP", "Kontraposition", 1),
  transitivity("TI", "Transitivität der Implikation", 2),
  nkIntro("+NK", "Einführung der negierten Konjunktion", 1),
  nkElim("-NK", "Beseitigung der negierten Konjunktion", 1),
  naIntro("+NA", "Einführung der negierten Adjunktion", 1),
  naElim("-NA", "Beseitigung der negierten Adjunktion", 1),
  allElim("-∀", "Beseitigung des Allquantors", 1),
  allIntro("+∀", "Einführung des Allquantors", 1),
  existsElim("-∃", "Beseitigung des Existenzquantors", 3),
  existsIntro("+∃", "Einführung des Existenzquantors", 1),
  nAllElim("-N∀", "Beseitigung des negierten Allquantors", 1),
  nAllIntro("+N∀", "Einführung des negierten Allquantors", 1),
  nExistsElim("-N∃", "Beseitigung des negierten Existenzquantors", 1),
  nExistsIntro("+N∃", "Einführung des negierten Existenzquantors", 1);

  /// Bezeichner, wie er in der Argumentspalte steht.
  final String symbol;

  final String title;

  /// Anzahl der Zeilenverweise (T: 0 oder 1).
  final int arity;

  const ProofRule(this.symbol, this.title, this.arity);

  /// Schreibweise mit Verweisen, z. B. „+K(1, 2)“.
  String format(List<String> refs) =>
      refs.isEmpty ? symbol : "$symbol(${refs.join(", ")})";

  /// Erkennt einen Bezeichner. `-A` mit drei Verweisen ist die
  /// Fallunterscheidung.
  static ProofRule? parse(String symbol, {int refCount = 2}) {
    var s = symbol.trim().toUpperCase().replaceAll(" ", "");
    s = s.replaceAll("–", "-").replaceAll("−", "-");
    s = s.replaceAll("AE", "Ä").replaceAll("ALL", "∀").replaceAll("EX", "∃");

    // Die Kursunterlagen schreiben die abgeleiteten Argumente teils mit „+“.
    if (s == "+EFQ" || s == "+VEQ" || s == "+KP" || s == "+TI") {
      s = s.substring(1);
    }

    if (s == "-A") {
      return refCount == 3 ? ProofRule.orElimCases : ProofRule.orElim;
    }

    for (final r in ProofRule.values) {
      if (r.symbol.toUpperCase() == s) return r;
    }

    return null;
  }
}

/// Welche Argumente in einem Beweis zur Verfügung stehen.
class ProofSystem {
  final String id;
  final String title;
  final Set<ProofRule> rules;

  /// Doppelte Negationen dürfen implizit hinzugefügt oder gestrichen werden
  /// (Argumente 6.2).
  final bool implicitDoubleNegation;

  const ProofSystem({
    required this.id,
    required this.title,
    required this.rules,
    required this.implicitDoubleNegation,
  });

  static const Set<ProofRule> _lesson4 = {
    ProofRule.assumption,
    ProofRule.andIntro,
    ProofRule.andElim,
    ProofRule.orIntro,
    ProofRule.orElim,
    ProofRule.impElim,
    ProofRule.iffIntro,
    ProofRule.iffElim,
    ProofRule.dnIntro,
    ProofRule.dnElim,
    ProofRule.tautology,
  };

  static const Set<ProofRule> _lesson5 = {
    ..._lesson4,
    ProofRule.impIntro,
    ProofRule.raa,
  };

  static const Set<ProofRule> _derived = {
    ProofRule.efq,
    ProofRule.veq,
    ProofRule.orElimCases,
    ProofRule.contraposition,
    ProofRule.transitivity,
    ProofRule.nkIntro,
    ProofRule.nkElim,
    ProofRule.naIntro,
    ProofRule.naElim,
  };

  static const Set<ProofRule> _quantifiers = {
    ProofRule.allElim,
    ProofRule.allIntro,
    ProofRule.existsElim,
    ProofRule.existsIntro,
  };

  static const Set<ProofRule> _negatedQuantifiers = {
    ProofRule.nAllElim,
    ProofRule.nAllIntro,
    ProofRule.nExistsElim,
    ProofRule.nExistsIntro,
  };

  static const ProofSystem lesson4 = ProofSystem(
    id: "l4",
    title: "Argumente aus Lektion 4",
    rules: _lesson4,
    implicitDoubleNegation: false,
  );

  static const ProofSystem lesson5 = ProofSystem(
    id: "l5",
    title: "Argumente aus Lektion 4 und 5",
    rules: _lesson5,
    implicitDoubleNegation: false,
  );

  /// Lektion 5 ohne +DN (Übung: q ⊢ ¬¬q ohne +DN).
  static const ProofSystem lesson5WithoutDnIntro = ProofSystem(
    id: "l5noDnIntro",
    title: "Argumente aus Lektion 4 und 5 ohne +DN",
    rules: {
      ProofRule.assumption,
      ProofRule.andIntro,
      ProofRule.andElim,
      ProofRule.orIntro,
      ProofRule.orElim,
      ProofRule.impElim,
      ProofRule.iffIntro,
      ProofRule.iffElim,
      ProofRule.dnElim,
      ProofRule.tautology,
      ProofRule.impIntro,
      ProofRule.raa,
    },
    implicitDoubleNegation: false,
  );

  /// Lektion 5 ohne -DN (Übung: ¬¬q ⊢ q ohne -DN).
  static const ProofSystem lesson5WithoutDnElim = ProofSystem(
    id: "l5noDnElim",
    title: "Argumente aus Lektion 4 und 5 ohne -DN",
    rules: {
      ProofRule.assumption,
      ProofRule.andIntro,
      ProofRule.andElim,
      ProofRule.orIntro,
      ProofRule.orElim,
      ProofRule.impElim,
      ProofRule.iffIntro,
      ProofRule.iffElim,
      ProofRule.dnIntro,
      ProofRule.tautology,
      ProofRule.impIntro,
      ProofRule.raa,
    },
    implicitDoubleNegation: false,
  );

  /// Grundargumente 6.1 und 6.2 (zum Beweisen der Argumente 6.3).
  static const ProofSystem lesson6Basic = ProofSystem(
    id: "l6basic",
    title: "Grundargumente 6.1 und 6.2",
    rules: _lesson5,
    implicitDoubleNegation: true,
  );

  static const ProofSystem lesson6 = ProofSystem(
    id: "l6",
    title: "Argumente 6.1 bis 6.3",
    rules: {..._lesson5, ..._derived},
    implicitDoubleNegation: true,
  );

  static const ProofSystem lesson8 = ProofSystem(
    id: "l8",
    title: "Aussagenlogische Argumente und Quantorenargumente",
    rules: {..._lesson5, ..._derived, ..._quantifiers},
    implicitDoubleNegation: true,
  );

  /// Alle Argumente – entspricht dem Regelblatt der Klausur.
  static const ProofSystem full = ProofSystem(
    id: "full",
    title: "Alle Argumente (Regelblatt der Klausur)",
    rules: {..._lesson5, ..._derived, ..._quantifiers, ..._negatedQuantifiers},
    implicitDoubleNegation: true,
  );

  static const List<ProofSystem> all = [
    lesson4,
    lesson5,
    lesson5WithoutDnIntro,
    lesson5WithoutDnElim,
    lesson6Basic,
    lesson6,
    lesson8,
    full,
  ];

  static ProofSystem byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => full);

  /// Für die Auswahl im Editor (ohne doppelten Eintrag für -A).
  List<ProofRule> get selectableRules => [
    for (final r in ProofRule.values)
      if (rules.contains(r)) r,
  ];
}

/// Bezeichner von Annahmezeilen: griechische Buchstaben.
class ProofLabels {
  ProofLabels._();

  static const List<String> greek = [
    "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ", //
    "ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω",
  ];

  static const Map<String, String> _latin = {
    "alpha": "α",
    "beta": "β",
    "gamma": "γ",
    "delta": "δ",
    "epsilon": "ε",
    "zeta": "ζ",
    "eta": "η",
    "theta": "θ",
    "a": "α",
    "b": "β",
    "g": "γ",
    "c": "γ",
    "d": "δ",
    "e": "ε",
    "z": "ζ",
    "h": "η",
  };

  static bool isAssumptionLabel(String label) => greek.contains(label);

  /// Liest eine Liste von Verweisen bzw. Abhängigkeiten, z. B. „α, 1“ oder
  /// „a,b“ (lateinische Umschrift).
  static List<String> parseList(String text) {
    final parts = text
        .replaceAll("(", " ")
        .replaceAll(")", " ")
        .split(RegExp(r"[,;\s]+"))
        .where((p) => p.isNotEmpty);

    return [for (final p in parts) normalize(p)];
  }

  static String normalize(String label) {
    final l = label.trim();
    return _latin[l.toLowerCase()] ?? l;
  }
}
