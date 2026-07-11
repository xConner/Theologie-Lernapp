class LiturgicalDay {
  final DateTime date;
  final String title;
  final String? variant;
  final String type;
  final String color;
  final String? info;

  final BibleVerse spruch;

  final String psalm;

  final List<String> songs;

  final Readings readings;

  const LiturgicalDay({
    required this.date,
    required this.title,
    this.variant,
    required this.type,
    required this.color,
    this.info,
    required this.spruch,
    required this.psalm,
    required this.songs,
    required this.readings,
  });

  factory LiturgicalDay.fromJson(Map<String, dynamic> json) {
    return LiturgicalDay(
      date: DateTime.parse(json["date"]),
      title: json["title"],
      variant: json["variant"],
      type: json["type"],
      color: json["color"],
      info: json["info"],
      spruch: BibleVerse.fromJson(json["spruch"]),
      psalm: json["psalm"],
      songs: List<String>.from(json["songs"]),
      readings: Readings.fromJson(json["readings"]),
    );
  }

  String get displayTitle {
    return title;
  }
}

class BibleVerse {
  final String text;
  final String reference;

  const BibleVerse({required this.text, required this.reference});

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(text: json["text"], reference: json["reference"]);
  }
}

class Readings {
  final String oldTestament;
  final String epistle;
  final String? hallelujah;
  final String gospel;
  final String sermon;

  const Readings({
    required this.oldTestament,
    required this.epistle,
    required this.hallelujah,
    required this.gospel,
    required this.sermon,
  });

  factory Readings.fromJson(Map<String, dynamic> json) {
    return Readings(
      oldTestament: json["oldTestament"],
      epistle: json["epistle"],
      hallelujah: json["hallelujah"],
      gospel: json["gospel"],
      sermon: json["sermon"],
    );
  }
}
