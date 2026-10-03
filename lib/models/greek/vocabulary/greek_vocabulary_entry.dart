class GreekVocabularyEntry {
  final int id;
  final int step;
  final String type;
  final String lemma;

  final String? genitive;
  final String? article;
  final String? aorist;

  final bool deponent;

  final List<String> translations;

  final String? note;
  final String? mnemonic;

  /// Inhaltliche Priorität (optionales JSON-Feld `weight`, Standard 1):
  /// Ein Wort mit Gewicht 2 wird bei gleichem Lernstand doppelt so oft
  /// gefragt.
  final double weight;

  const GreekVocabularyEntry({
    required this.id,
    required this.step,
    required this.type,
    required this.lemma,
    this.genitive,
    this.article,
    this.aorist,
    this.deponent = false,
    required this.translations,
    this.note,
    this.mnemonic,
    this.weight = 1.0,
  });

  factory GreekVocabularyEntry.fromJson(Map<String, dynamic> json) {
    return GreekVocabularyEntry(
      id: json["id"],
      step: int.parse(json["step"].toString()),
      type: json["type"],
      lemma: json["lemma"],
      genitive: json["genitive"],
      article: json["article"],
      aorist: json["aorist"],
      deponent: json["deponent"] == true,
      note: json["note"],
      mnemonic: json["mnemonic"],
      weight: _parseWeight(json["weight"]),
      translations: List<String>.from(json["translations"]),
    );
  }

  static double _parseWeight(Object? value) {
    return value is num && value.isFinite && value > 0 ? value.toDouble() : 1.0;
  }
}
