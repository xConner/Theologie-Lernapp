import '../../../utils/latin_normalization.dart';

/// Antwortprüfung des lateinischen Grammatiktrainers, ohne UI.
///
/// Lateinspezifische Regeln für die Grundform-Eingabe: Groß- und
/// Kleinschreibung sowie Längenzeichen zählen nicht, j gilt als i
/// (adjuvō = adiuvō).

/// Vereinheitlicht eine Eingabe: Längenzeichen zusammengesetzt, klein,
/// j → i, Leerraum zusammengefasst.
String normalizeLatinInput(String input) {
  return composeLatinMacrons(
    input,
  ).trim().toLowerCase().replaceAll('j', 'i').replaceAll(RegExp(r'\s+'), ' ');
}

/// Grundform-Eingabe: Längenzeichen, Groß-/Kleinschreibung und „?“/„!“
/// zählen nicht. Bei Verben gilt der Infinitiv oder die 1. Sg. Präsens.
bool lemmaMatches(String input, List<String> lemmas) {
  final answer = latinSearchKey(normalizeLatinInput(input));

  if (answer.isEmpty) return false;

  return lemmas.any((lemma) => latinSearchKey(lemma) == answer);
}

/// Ergebnis einer Bestimmungsaufgabe. [fields]: Feld → richtig? (nur
/// abgefragte Felder). [reference]: die Bestimmung, an der gemessen wurde.
class IdentifyResult<A> {
  final bool correct;
  final Map<String, bool> fields;
  final A reference;

  const IdentifyResult({
    required this.correct,
    required this.fields,
    required this.reference,
  });
}

/// Prüft eine Bestimmung gegen alle für die Form möglichen Bestimmungen
/// ([analyses]). Richtig ist die Antwort nur, wenn sie eine davon
/// vollständig trifft – eine Mischung zweier Bestimmungen bleibt falsch.
/// Die Einzelwertung richtet sich nach der Bestimmung mit den meisten
/// Übereinstimmungen, bei Gleichstand nach [target].
///
/// [fieldsOf] liefert die Felder einer Bestimmung; Felder mit Wert null
/// gehören nicht zu dieser Bestimmung (Person beim Infinitiv) und werden
/// nicht gewertet.
IdentifyResult<A> checkIdentification<A>({
  required A target,
  required List<A> analyses,
  required Map<String, String?> answer,
  required Map<String, String?> Function(A analysis) fieldsOf,
}) {
  final candidates = analyses.contains(target)
      ? [target, ...analyses.where((a) => a != target)]
      : [target, ...analyses];

  Map<String, bool> compare(A analysis) {
    final fields = fieldsOf(analysis);

    return {
      for (final entry in fields.entries)
        if (entry.value != null) entry.key: answer[entry.key] == entry.value,
    };
  }

  A? best;
  Map<String, bool>? bestFields;
  var bestScore = -1;

  for (final analysis in candidates) {
    final fields = compare(analysis);
    final score = fields.values.where((ok) => ok).length;

    if (fields.values.every((ok) => ok)) {
      return IdentifyResult(correct: true, fields: fields, reference: analysis);
    }

    if (score > bestScore) {
      best = analysis;
      bestFields = fields;
      bestScore = score;
    }
  }

  return IdentifyResult(
    correct: false,
    fields: bestFields!,
    reference: best as A,
  );
}
