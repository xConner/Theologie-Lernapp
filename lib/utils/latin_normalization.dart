/// Schreibweisen lateinischer Wörter vergleichbar machen.
///
/// Längenzeichen (ā) und Kürzezeichen (ă) sind Lesehilfen; für Suche und
/// Sortierung zählen sie nicht. Für die Antwortprüfung des Grammatiktrainers
/// gelten eigene Regeln (`latin_grammar_answer_check.dart`), weil dort
/// Längen grammatisch unterscheiden können (venit – vēnit).
library;

const Map<String, String> _plainVowels = {
  'ā': 'a',
  'ē': 'e',
  'ī': 'i',
  'ō': 'o',
  'ū': 'u',
  'ȳ': 'y',
  'ă': 'a',
  'ĕ': 'e',
  'ĭ': 'i',
  'ŏ': 'o',
  'ŭ': 'u',
  'Ā': 'A',
  'Ē': 'E',
  'Ī': 'I',
  'Ō': 'O',
  'Ū': 'U',
  'Ȳ': 'Y',
};

/// Vorkomponierte Vokale mit Längenzeichen, falls die Eingabe sie zerlegt
/// liefert (Vokal + U+0304).
const Map<String, String> _composedMacrons = {
  'a': 'ā',
  'e': 'ē',
  'i': 'ī',
  'o': 'ō',
  'u': 'ū',
  'y': 'ȳ',
  'A': 'Ā',
  'E': 'Ē',
  'I': 'Ī',
  'O': 'Ō',
  'U': 'Ū',
  'Y': 'Ȳ',
};

/// Setzt zerlegte Längenzeichen (Vokal + U+0304) zu den vorkomponierten
/// Zeichen zusammen und entfernt Kürzezeichen (Breve, U+0306 bzw. ă …).
String composeLatinMacrons(String text) {
  final composed = text.replaceAllMapped(
    RegExp('([aeiouyAEIOUY])\u0304'),
    (m) => _composedMacrons[m.group(1)!]!,
  );

  return composed
      .replaceAll('\u0306', '')
      .replaceAllMapped(RegExp('[ăĕĭŏŭ]'), (m) => _plainVowels[m.group(0)!]!);
}

/// Entfernt Längen- und Kürzezeichen: „cōgitāre“ → „cogitare“.
String stripLatinMacrons(String text) {
  return composeLatinMacrons(text).replaceAllMapped(
    RegExp('[āēīōūȳĀĒĪŌŪȲ]'),
    (m) => _plainVowels[m.group(0)!]!,
  );
}

/// Ob der Text Längenzeichen enthält.
bool hasLatinMacrons(String text) {
  return RegExp('[āēīōūȳĀĒĪŌŪȲ]').hasMatch(composeLatinMacrons(text));
}

/// Schlüssel für Suche und alphabetische Sortierung: ohne Längenzeichen,
/// klein geschrieben, ohne Satzzeichen wie „?“ und „!“.
String latinSearchKey(String text) {
  return stripLatinMacrons(text)
      .toLowerCase()
      .replaceAll(RegExp(r'[?!.,;:()…]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
