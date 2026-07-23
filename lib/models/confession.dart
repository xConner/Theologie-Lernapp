class Confession {
  final String id;
  final String category;
  final Map<String, String> title;
  final List<String> languages;
  final List<ConfessionSection> sections;

  Confession({
    required this.id,
    required this.category,
    required this.title,
    required this.languages,
    required this.sections,
  });

  factory Confession.fromJson(Map<String, dynamic> json) {
    return Confession(
      id: json["id"],
      category: json["category"],
      title: Map<String, String>.from(json["title"]),

      languages: List<String>.from(json["languages"]),

      sections: (json["sections"] as List)
          .map((s) => ConfessionSection.fromJson(s))
          .toList(),
    );
  }
}

class ConfessionSection {
  final String id;
  final Map<String, String> title;
  final Map<String, String> texts;

  ConfessionSection({
    required this.id,
    required this.title,
    required this.texts,
  });

  factory ConfessionSection.fromJson(Map<String, dynamic> json) {
    return ConfessionSection(
      id: json["id"],
      title: Map<String, String>.from(json["title"]),
      texts: Map<String, String>.from(json["texts"]),
    );
  }
}
