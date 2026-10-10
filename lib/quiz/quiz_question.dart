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

  /// Die Fragen für die Buchauswahl [books]: Jede Frage behält nur ihre
  /// Stellen aus den gewählten Büchern, Fragen ohne solche Stelle entfallen.
  ///
  /// Die gemeinsame ID fasst zusammengehörige Stellen (z. B. synoptische
  /// Parallelen) zu einer Frage zusammen. Welche davon abgefragt und im
  /// Bibel-Reader angeboten werden, bestimmt allein diese Auswahl.
  static List<QuizQuestion> forBooks(
    List<QuizQuestion> questions,
    Set<String> books,
  ) {
    final result = <QuizQuestion>[];

    for (final q in questions) {
      final variants = q.variants
          .where((p) => p.required && books.contains(p.book))
          .toList();

      if (variants.isNotEmpty) {
        result.add(QuizQuestion(id: q.id, variants: variants));
      }
    }

    return result;
  }
}
