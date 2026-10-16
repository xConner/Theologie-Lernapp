import 'hymn_score.dart';
import 'lyric.dart';

/// Ein Lied in einer Sammlung (siehe `Hymnal`).
///
/// Im Stammteil (`assets/eg_lieder.json`) ist [id] die EG-Nummer. Lieder
/// anderer Sammlungen tragen ihre Nummer in `number`; dort kann sie auch
/// „786.5“ lauten. Eindeutig über alle Sammlungen ist nur [key].
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

  /// Kennung der Sammlung, `eg` für den Stammteil.
  final String collectionId;

  /// Nummer innerhalb der Sammlung.
  final String number;

  /// Vorsatz der Nummer, z. B. „EG“ oder „EG.E“.
  final String numberPrefix;

  /// Gemeinsame Kennung aller Fassungen desselben Liedes in verschiedenen
  /// Sammlungen; leer, wenn keine Fassung sicher zugeordnet ist.
  final String workId;

  /// Warum kein Text angezeigt wird; leer für den Hinweis der Sammlung.
  final String lyricsNote;

  /// Herkunft der Angaben zu diesem Lied; `null`, wenn die Sammlung sie
  /// insgesamt nennt.
  final HymnScoreSource? source;

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
    this.collectionId = 'eg',
    String? number,
    this.numberPrefix = 'EG',
    this.workId = '',
    this.lyricsNote = '',
    this.source,
  }) : number = number ?? id.toString();

  /// Eindeutig über alle Sammlungen, z. B. `eg:1`.
  String get key => '$collectionId:$number';

  /// Nummer mit Vorsatz, z. B. „EG 1“ oder „EG.E 10“.
  String get displayNumber =>
      numberPrefix.isEmpty ? number : '$numberPrefix $number';

  /// Erste Zeile der ersten Strophe; leer ohne Text.
  String get firstLine =>
      lyrics.isEmpty ? '' : lyrics.first.text.split('\n').first.trim();

  factory Hymn.fromJson(
    Map<String, dynamic> json, {
    String collectionId = 'eg',
    String numberPrefix = 'EG',
  }) {
    final number = json['number']?.toString();
    final source = json['source'];

    return Hymn(
      id: json['id'] ?? int.tryParse(number ?? '') ?? 0,

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

      collectionId: collectionId,

      number: number,

      numberPrefix: numberPrefix,

      workId: json['workId'] ?? '',

      lyricsNote: json['lyricsNote'] ?? '',

      source: source is Map<String, dynamic>
          ? HymnScoreSource.fromJson(source)
          : null,
    );
  }
}
