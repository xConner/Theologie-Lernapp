import '../models/greek/perikope.dart';

class QuizQuestion {
  final String id;

  final List<Perikope> variants;

  QuizQuestion({required this.id, required this.variants});

  String get title {
    if (variants.isEmpty) {
      return "";
    }

    return variants.first.title;
  }

  /// Erstellt Quizfragen aus einer flachen Perikopenliste.
  /// Alle Perikopen mit gleicher ID werden zusammengefasst.
  static List<QuizQuestion> fromPerikopen(List<Perikope> perikopen) {
    final Map<String, List<Perikope>> grouped = {};

    for (final p in perikopen) {
      grouped.putIfAbsent(p.id, () => []);
      grouped[p.id]!.add(p);
    }

    return grouped.entries
        .map((e) => QuizQuestion(id: e.key, variants: e.value))
        .toList();
  }
}
