import '../../../utils/latin_normalization.dart';

/// Antwortprüfung des lateinischen Grammatiktrainers, ohne UI.
///
/// Lateinspezifische Regeln:
///   * Groß-/Kleinschreibung zählt nicht (Formen werden klein geschrieben),
///     j gilt als i (adjuvō = adiuvō).
///   * Längenzeichen sind standardmäßig freiwillig: „amas“ ist für „amās“
///     richtig. Wer Längenzeichen setzt, muss aber die gefragte Form treffen:
///     „vēnit“ (Perfekt) ist für „venit“ (Präsens) falsch, weil sich die
///     beiden Formen nur in der Länge unterscheiden. Mit „Längenzeichen
///     verlangen“ zählen nur exakt geschriebene Formen.
///   * Nebenformen einer Zelle (amāris/amāre, eīs/iīs) sind gleichwertig.

/// Vereinheitlicht eine Eingabe: Längenzeichen zusammengesetzt, klein,
/// j → i, Leerraum zusammengefasst.
String normalizeLatinInput(String input) {
  return composeLatinMacrons(
    input,
  ).trim().toLowerCase().replaceAll('j', 'i').replaceAll(RegExp(r'\s+'), ' ');
}

class FormCheckResult {
  final bool correct;

  /// Die erwartete Hauptform.
  final String expected;

  /// Richtig, aber die gesetzten Längenzeichen weichen ab (nur ohne
  /// „Längenzeichen verlangen“) – bzw. falsch, weil sie verlangt sind.
  final bool macronMismatch;

  /// Die Eingabe ist eine andere Form desselben Paradigmas: deren
  /// Bestimmung (z. B. „3. Sg. Präsens Indikativ Aktiv“).
  final String? otherAnalysis;

  /// Die Eingabe weicht nur um einen Buchstaben ab und ist keine andere
  /// Form des Paradigmas – vermutlich ein Tippfehler.
  final bool likelyTypo;

  const FormCheckResult({
    required this.correct,
    required this.expected,
    this.macronMismatch = false,
    this.otherAnalysis,
    this.likelyTypo = false,
  });
}

/// Prüft eine gebildete Form.
///
/// [accepted]: alle richtigen Formen (Hauptform zuerst). [otherForms]: die
/// übrigen Formen des Paradigmas mit ihrer Bestimmung, um grammatisch
/// falsche Formen von Tippfehlern zu unterscheiden.
FormCheckResult checkFormAnswer({
  required String input,
  required List<String> accepted,
  required Map<String, String> otherForms,
  bool requireMacrons = false,
}) {
  final answer = normalizeLatinInput(input);
  final expected = accepted.first;
  final acceptedNormalized = [for (final a in accepted) normalizeLatinInput(a)];

  if (answer.isEmpty) {
    return FormCheckResult(correct: false, expected: expected);
  }

  if (acceptedNormalized.contains(answer)) {
    return FormCheckResult(correct: true, expected: expected);
  }

  final plainAnswer = stripLatinMacrons(answer);
  final plainMatch = acceptedNormalized.any(
    (a) => stripLatinMacrons(a) == plainAnswer,
  );

  // Exakt eine andere Form des Paradigmas (mit Längenzeichen): grammatisch
  // falsch, auch wenn sie ohne Längen gleich aussähe (vēnit – venit).
  String? exactOther;

  for (final entry in otherForms.entries) {
    if (normalizeLatinInput(entry.key) == answer) {
      exactOther = entry.value;
      break;
    }
  }

  if (plainMatch) {
    if (exactOther != null && hasLatinMacrons(answer)) {
      return FormCheckResult(
        correct: false,
        expected: expected,
        otherAnalysis: exactOther,
      );
    }

    if (requireMacrons) {
      return FormCheckResult(
        correct: false,
        expected: expected,
        macronMismatch: true,
      );
    }

    // Ohne Längen geschrieben: richtig. Mit falsch gesetzten Längen:
    // ebenfalls richtig, aber mit Hinweis.
    return FormCheckResult(
      correct: true,
      expected: expected,
      macronMismatch: hasLatinMacrons(answer),
    );
  }

  // Eine andere Form des Paradigmas, ggf. ohne Längenzeichen geschrieben.
  if (exactOther == null) {
    for (final entry in otherForms.entries) {
      final other = normalizeLatinInput(entry.key);

      if (other == answer ||
          (!hasLatinMacrons(answer) && stripLatinMacrons(other) == answer)) {
        exactOther = entry.value;
        break;
      }
    }
  }

  if (exactOther != null) {
    return FormCheckResult(
      correct: false,
      expected: expected,
      otherAnalysis: exactOther,
    );
  }

  final typo = acceptedNormalized.any(
    (a) =>
        a.length >= 4 && _editDistance(stripLatinMacrons(a), plainAnswer) == 1,
  );

  return FormCheckResult(correct: false, expected: expected, likelyTypo: typo);
}

/// Grundform-Eingabe: Längenzeichen, Groß-/Kleinschreibung und „?“/„!“
/// zählen nicht. Bei Verben gilt der Infinitiv oder die 1. Sg. Präsens.
bool lemmaMatches(String input, List<String> lemmas) {
  final answer = latinSearchKey(normalizeLatinInput(input));

  if (answer.isEmpty) return false;

  return lemmas.any((lemma) => latinSearchKey(lemma) == answer);
}

/// Levenshtein-Abstand (für die Tippfehler-Erkennung).
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);

  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;

    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;

      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }

    previous = current;
  }

  return previous[b.length];
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
