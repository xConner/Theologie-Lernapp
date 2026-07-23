class GrammarCard {
  final String id;

  double stability;
  double difficulty;
  DateTime? lastSeen;

  GrammarCard({
    required this.id,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.lastSeen,
  });
}
