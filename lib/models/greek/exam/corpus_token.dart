import 'greek_morph_analysis.dart';

/// Woher die Bestimmungen einer Wortform stammen und wie belastbar sie sind.
enum AnalysisReliability {
  /// Im Kontext bestimmt (MorphGNT): die erste Bestimmung ist die des Textes.
  contextual,

  /// Aus einem Formenindex: alle bekannten Bestimmungen der Form, ohne
  /// Prüfung im Kontext. Mehrdeutigkeit bleibt erhalten.
  formal,

  /// Unbekannte Form, nach Schreibweise vermutlich ein Eigenname
  /// (großgeschrieben mitten im Satz). Ohne Bestimmung im engeren Sinn.
  properNameGuess,

  /// Keine Bestimmung bekannt.
  unanalyzed,
}

/// Grundform samt Bestimmung.
class LemmaAnalysis {
  final String lemma;
  final GreekMorphAnalysis analysis;

  const LemmaAnalysis(this.lemma, this.analysis);

  @override
  bool operator ==(Object other) =>
      other is LemmaAnalysis &&
      other.lemma == lemma &&
      other.analysis == analysis;

  @override
  int get hashCode => Object.hash(lemma, analysis);

  @override
  String toString() => "$lemma $analysis";
}

/// Eine Wortform eines Textes mit allen bekannten Bestimmungen.
class CorpusToken {
  /// Form wie im Text, mit anhängenden Satzzeichen.
  final String surface;

  /// Bei [AnalysisReliability.contextual] steht die Bestimmung des Kontexts
  /// zuerst, danach weitere formal mögliche Bestimmungen derselben Form.
  final List<LemmaAnalysis> analyses;

  final AnalysisReliability reliability;

  const CorpusToken(this.surface, this.analyses, this.reliability);

  bool get isAnalyzed =>
      analyses.isNotEmpty && reliability != AnalysisReliability.unanalyzed;

  /// Die im Kontext gesicherte Bestimmung (nur NT).
  LemmaAnalysis? get contextual =>
      reliability == AnalysisReliability.contextual && analyses.isNotEmpty
      ? analyses.first
      : null;

  /// Die Bestimmungen, die für den Text in Frage kommen: im Kontext
  /// bestimmt nur die eine, sonst alle formal möglichen.
  List<LemmaAnalysis> get readings {
    final ctx = contextual;
    return ctx == null ? analyses : [ctx];
  }

  /// Alle Grundformen, die für die Form in Frage kommen.
  Set<String> get candidateLemmas => {for (final a in readings) a.lemma};

  /// Die Grundform, wenn sie eindeutig ist.
  String? get certainLemma {
    final lemmas = candidateLemmas;
    return lemmas.length == 1 && isAnalyzed ? lemmas.first : null;
  }

  /// Form ohne Satzzeichen (für Anzeige und Auswahl).
  String get word {
    return surface.replaceAll(
      RegExp(r'^[^\p{L}]+|[^\p{L}’ʼ᾽]+$', unicode: true),
      '',
    );
  }
}
