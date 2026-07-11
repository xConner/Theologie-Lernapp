class GreekVocabularyEntry {
  final int id;
  final int step;
  final String type;
  final String lemma;

  final String? genitive;
  final String? article;
  final String? aorist;

  final List<String> translations;

  final String? note;

  const GreekVocabularyEntry({
    required this.id,
    required this.step,
    required this.type,
    required this.lemma,
    this.genitive,
    this.article,
    this.aorist,
    required this.translations,
    this.note,
  });

  factory GreekVocabularyEntry.fromJson(Map<String, dynamic> json) {
    return GreekVocabularyEntry(
      id: json["id"],
      step: json["step"],
      type: json["type"],
      lemma: json["lemma"],
      genitive: json["genitive"],
      article: json["article"],
      aorist: json["aorist"],
      note: json["note"],
      translations: List<String>.from(json["translations"]),
    );
  }
}
