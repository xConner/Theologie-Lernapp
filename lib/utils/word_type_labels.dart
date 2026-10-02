/// Deutsche Bezeichnung einer Wortart für Filter in den Vokabeltrainern.
/// Die gespeicherten Werte (`enabledTypes`) bleiben die englischen Schlüssel.
String wordTypeFilterLabel(String type) {
  switch (type) {
    case "noun":
      return "Nomen";

    case "verb":
      return "Verben";

    case "adjective":
      return "Adjektive";

    case "adverb":
      return "Adverbien";

    case "pronoun":
      return "Pronomen";

    case "preposition":
      return "Präpositionen";

    case "conjunction":
      return "Konjunktionen";

    case "particle":
      return "Partikeln";

    case "question_word":
      return "Fragewörter";

    case "numeral":
      return "Zahlwörter";

    case "phrase":
      return "Redewendungen";

    default:
      return type;
  }
}
