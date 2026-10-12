/// Kürzt Wörterbuchangaben auf Vokabelhilfen: ein bis drei kurze deutsche
/// Bedeutungen ("nehmen, erhalten"), ohne Erläuterungen, Belegstellen und
/// seltene Nebenbedeutungen. Import (`tool/greek_exam_corpus`) und App
/// verwenden dieselbe Funktion.
library;

/// Höchstzahl der Bedeutungen einer Vokabelhilfe.
const int maxGlossesPerHint = 3;

/// Längere Angaben sind Erklärungen, keine Übersetzungen.
const int maxGlossLength = 34;

/// Eine Erklärung bleibt nur als letzte Möglichkeit und nur bis zu dieser
/// Länge; darüber ist sie keine Vokabelhilfe mehr.
const int maxExplanationLength = 60;

final RegExp _brackets = RegExp(r'\([^()]*\)|\[[^\[\]]*\]');

/// Gebrauchshinweise am Anfang einer Wiktionary-Bedeutung ("übertragen:",
/// "transitiv, mit Akkusativ:").
final RegExp _usageLabel = RegExp(r'^[^:]{1,40}:\s*');

String _clean(String gloss) {
  var text = gloss;

  // Verschachtelte Klammern von innen nach außen.
  for (var i = 0; i < 3 && _brackets.hasMatch(text); i++) {
    text = text.replaceAll(_brackets, ' ');
  }

  return text
      .replaceAll(RegExp(r'[„“”"«»]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,;:.\-–]+|[\s,;:.\-–]+$'), '')
      .trim();
}

/// Die kurzen Bedeutungen aus [raw] (Reihenfolge der Quelle, also die
/// Grundbedeutung zuerst). Jede Angabe wird an Semikolon und Komma zerlegt;
/// Klammerzusätze fallen weg, ebenso Erklärungen in Satzlänge, solange es
/// kurze Bedeutungen gibt. Bleibt nur eine Erklärung, wird sie beibehalten,
/// solange sie überschaubar ist ([maxExplanationLength]); sonst gibt es
/// keine Angabe aus dieser Quelle.
List<String> shortGlosses(Iterable<String> raw, {int max = maxGlossesPerHint}) {
  final short = <String>[];
  final long = <String>[];
  final seen = <String>{};

  for (final entry in raw) {
    final withoutLabel = entry.replaceFirst(_usageLabel, '');

    // Erst die Klammern entfernen: Kommas darin trennen keine Bedeutungen.
    var text = withoutLabel;
    for (var i = 0; i < 3 && _brackets.hasMatch(text); i++) {
      text = text.replaceAll(_brackets, ' ');
    }

    final parts = [
      for (final part in text.split(RegExp(r'[;,]')))
        // „ab-, weg-, zurückwenden“: Die Vorsilben allein sind keine Bedeutung.
        if (!part.trim().endsWith('-')) _clean(part),
    ].where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) continue;

    // Beginnt die Angabe mit einer Erklärung in Satzlänge, ist das Komma
    // Teil des Satzes und trennt keine Bedeutungen.
    if (parts.first.length > maxGlossLength) {
      final whole = _clean(text);
      if (seen.add(whole.toLowerCase())) long.add(whole);
      continue;
    }

    for (final gloss in parts) {
      if (!seen.add(gloss.toLowerCase())) continue;
      (gloss.length <= maxGlossLength ? short : long).add(gloss);
    }
  }

  if (short.isNotEmpty) return short.take(max).toList();

  return long.where((g) => g.length <= maxExplanationLength).take(1).toList();
}
