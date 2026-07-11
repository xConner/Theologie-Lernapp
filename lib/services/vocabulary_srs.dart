import 'dart:math';

import '../models/greek_vocabulary_entry.dart';

class VocabularySrs {
  static GreekVocabularyEntry chooseNext({
    required List<GreekVocabularyEntry> entries,

    required Map<String, Map<String, dynamic>> progress,
  }) {
    if (entries.isEmpty) {
      throw Exception("Keine Vokabeln vorhanden");
    }

    final now = DateTime.now();

    final scored = entries.map((entry) {
      final data =
          progress[entry.id] ??
          {"stability": 1.0, "difficulty": 1.0, "lastAnswered": null};

      final stability = (data["stability"] ?? 1.0).toDouble();

      final difficulty = (data["difficulty"] ?? 1.0).toDouble();

      DateTime? lastAnswered;

      if (data["lastAnswered"] != null) {
        lastAnswered = DateTime.tryParse(data["lastAnswered"]);
      }

      double daysSince = 999;

      if (lastAnswered != null) {
        daysSince = now.difference(lastAnswered).inMinutes / 1440;
      }

      /*
            Priorität:

            - lange nicht gelernt = höher
            - geringe Stabilität = höher
            - hohe Schwierigkeit = höher

          */

      final forgetting = daysSince / max(stability, 0.1);

      final priority = forgetting * difficulty;

      return _ScoredEntry(entry, priority);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    /*
      Nicht immer exakt die höchste nehmen.

      Dadurch bleibt der Trainer abwechslungsreicher.
    */

    final top = scored.take(min(5, scored.length)).toList();

    return top[Random().nextInt(top.length)].entry;
  }
}

class _ScoredEntry {
  final GreekVocabularyEntry entry;

  final double score;

  _ScoredEntry(this.entry, this.score);
}
