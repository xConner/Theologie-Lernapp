// lib/models/perikope.dart
class Perikope {
  final String id;
  final String title;
  final String book;

  final int startChapter;
  final int startVerse;
  final int endChapter;
  final int endVerse;

  final bool required;
  final String precision;

  Perikope({
    required this.id,
    required this.title,
    required this.book,
    required this.startChapter,
    required this.startVerse,
    required this.endChapter,
    required this.endVerse,
    required this.required,
    required this.precision,
  });

  factory Perikope.fromJson(Map<String, dynamic> json) {
    return Perikope(
      id: json["id"],
      title: json["title"],
      book: json["book"],
      startChapter: json["startChapter"],
      startVerse: json["startVerse"],
      endChapter: json["endChapter"],
      endVerse: json["endVerse"],
      required: json["required"],
      precision: json["precision"],
    );
  }
}
