import 'hymn_score.dart';
import 'lyric.dart';

class Hymn {
  final int id;
  final String title;
  final String author;
  final String melody;
  final List<Lyric> lyrics;
  final List<String> tags;
  final List<String> bibleReferences;
  final String explanation;

  /// Notenbilder zum Lied; leer, wenn (noch) keine hinterlegt sind.
  final List<HymnScore> scores;

  Hymn({
    required this.id,
    required this.title,
    required this.author,
    required this.melody,
    required this.lyrics,
    required this.tags,
    required this.bibleReferences,
    required this.explanation,
    this.scores = const [],
  });

  factory Hymn.fromJson(Map<String, dynamic> json) {
    return Hymn(
      id: json['id'] ?? 0,

      title: json['title'] ?? '',

      // dein JSON nutzt aktuell "text" für den Autor
      author: json['text'] ?? '',

      melody: json['melody'] ?? '',

      lyrics: (json['lyrics'] as List<dynamic>? ?? [])
          .map((e) => Lyric.fromJson(e))
          .toList(),

      tags: List<String>.from(json['tags'] ?? []),

      bibleReferences: List<String>.from(json['bibleReferences'] ?? []),

      explanation: json['explanation'] ?? '',

      scores: HymnScore.listFromJson(json['scores']),
    );
  }
}
