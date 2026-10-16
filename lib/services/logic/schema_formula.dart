import 'formula.dart';
import 'formula_parser.dart';

/// Satzformen mit Metavariablen wie „A → B“ (z. B. für die Wahrheitstafel
/// der Implikation in Lektion 3). Zur Berechnung stehen A, B, C, D, E für
/// p, q, r, s, t; [names] übersetzt für die Anzeige zurück.
class SchemaFormula {
  final Formula formula;

  /// Satzbuchstabe → angezeigter Name (leer bei gewöhnlichen Sätzen).
  final Map<String, String> names;

  const SchemaFormula(this.formula, this.names);

  static const String _meta = "ABCDE";
  static const String _letters = "pqrst";

  static SchemaFormula? parse(String text) {
    final isSchema = text.split("").any(_meta.contains) &&
        !text.split("").any((c) =>
            LogicAlphabet.sentenceLetters.contains(c) ||
            c == "∀" ||
            c == "∃");

    if (!isSchema) {
      final r = FormulaParser.parse(
        text,
        language: FormulaParser.guessLanguage(text),
      );
      return r.ok ? SchemaFormula(r.formula!, const {}) : null;
    }

    final mapped = text.split("").map((c) {
      final i = _meta.indexOf(c);
      return i >= 0 ? _letters[i] : c;
    }).join();

    final r = FormulaParser.parse(mapped);
    if (!r.ok) return null;

    return SchemaFormula(r.formula!, {
      for (var i = 0; i < _meta.length; i++) _letters[i]: _meta[i],
    });
  }

  /// Anzeige eines (Teil-)Satzes mit den Metavariablen.
  String show(Formula f, {bool top = true}) {
    final s = f.show(top: top);
    if (names.isEmpty) return s;
    return s.split("").map((c) => names[c] ?? c).join();
  }

  String name(String letter) => names[letter] ?? letter;
}
