/// Eine konkrete Pronominalform. [variant] benennt eine Formvariante
/// derselben Bestimmung ("betont", "enklitisch", "mit beweglichem ν").
class PronounForm {
  final String text;
  final String? variant;

  const PronounForm({required this.text, this.variant});
}

/// Eine Zelle des Paradigmas. Kasus und Numerus in der Schreibweise der
/// Backend-Anfragen ("Nominativ", "Sg"); [gender] ist `null` bei Pronomen
/// ohne Genus (ἐγώ, σύ).
class PronounCell {
  final String grammaticalCase;
  final String number;
  final String? gender;
  final List<PronounForm> forms;

  /// Deutsche Wiedergabe dieser Form ("euer" für ὑμῶν).
  final String? translation;

  const PronounCell({
    required this.grammaticalCase,
    required this.number,
    required this.gender,
    required this.forms,
    this.translation,
  });
}

class PronounExample {
  final String greek;
  final String german;

  const PronounExample({required this.greek, required this.german});
}

/// Vollständiges Paradigma eines Pronomens aus
/// `assets/greek_pronoun_forms.json`. [id] ist die ID des zugehörigen
/// Eintrags der Vokabelliste.
class PronounParadigm {
  final int id;
  final String lemma;

  /// Beschriftung in der Auswahl; unterscheidet τίς und τις.
  final String label;

  /// Pronomenart: personal, possessive, demonstrative, relative,
  /// interrogative, indefinite.
  final String kind;

  final List<String> usage;
  final List<PronounExample> examples;

  /// Ähnlich aussehende Wörter außerhalb der Pronomen (z. B. der Artikel),
  /// je Form.
  final Map<String, List<String>> lookalikes;

  final List<PronounCell> cells;

  const PronounParadigm({
    required this.id,
    required this.lemma,
    required this.label,
    required this.kind,
    required this.usage,
    required this.examples,
    required this.lookalikes,
    required this.cells,
  });

  factory PronounParadigm.fromJson(Map<String, dynamic> json) {
    return PronounParadigm(
      id: json["id"],
      lemma: json["lemma"],
      label: json["label"] ?? json["lemma"],
      kind: json["kind"],
      usage: List<String>.from(json["usage"] ?? const []),
      examples: [
        for (final example in json["examples"] ?? const [])
          PronounExample(greek: example["greek"], german: example["german"]),
      ],
      lookalikes: {
        for (final entry in ((json["lookalikes"] ?? const {}) as Map).entries)
          entry.key as String: List<String>.from(entry.value),
      },
      cells: [
        for (final cell in json["cells"])
          PronounCell(
            grammaticalCase: cell["case"],
            number: cell["number"],
            gender: cell["gender"],
            translation: cell["translation"],
            forms: [
              for (final form in cell["forms"])
                PronounForm(text: form["text"], variant: form["variant"]),
            ],
          ),
      ],
    );
  }

  /// Genera des Paradigmas in der Reihenfolge der Daten; leer bei ἐγώ und σύ.
  List<String> get genders {
    final result = <String>[];

    for (final cell in cells) {
      final gender = cell.gender;

      if (gender != null && !result.contains(gender)) {
        result.add(gender);
      }
    }

    return result;
  }

  PronounCell? cell(String grammaticalCase, String number, String? gender) {
    for (final cell in cells) {
      if (cell.grammaticalCase == grammaticalCase &&
          cell.number == number &&
          cell.gender == gender) {
        return cell;
      }
    }

    return null;
  }

  /// Deutsche Bezeichnung der Pronomenart.
  String get kindLabel => kindLabelOf(kind);

  static String kindLabelOf(String kind) {
    switch (kind) {
      case "personal":
        return "Personalpronomen";

      case "possessive":
        return "Possessivpronomen";

      case "demonstrative":
        return "Demonstrativpronomen";

      case "relative":
        return "Relativpronomen";

      case "interrogative":
        return "Interrogativpronomen";

      case "indefinite":
        return "Indefinitpronomen";

      default:
        return "Pronomen";
    }
  }
}
