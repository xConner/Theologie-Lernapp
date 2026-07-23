class Lyric {
  final dynamic stanza;
  final String text;

  Lyric({required this.stanza, required this.text});

  factory Lyric.fromJson(Map<String, dynamic> json) {
    return Lyric(stanza: json['stanza'], text: json['text'] ?? '');
  }
}
