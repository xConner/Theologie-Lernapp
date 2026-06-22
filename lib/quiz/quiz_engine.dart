import '../models/perikope.dart';

enum QuizStatus { correct, partial, wrong }

class QuizResult {
  final QuizStatus status;
  final int correctCount;
  final int totalRequired;
  final List<FieldResult> fieldResults;

  QuizResult({
    required this.status,
    required this.correctCount,
    required this.totalRequired,
    required this.fieldResults,
  });
}

class FieldResult {
  final String input;
  final String expected;
  final bool isCorrect;

  FieldResult({
    required this.input,
    required this.expected,
    required this.isCorrect,
  });
}

class QuizEngine {
  static QuizResult evaluate(Perikope p, List<String> inputs) {
    final required = p.occurrences.where((o) => o.required).toList();

    final used = <int>{};
    final results = <FieldResult>[];

    int correct = 0;

    for (final occ in required) {
      bool matched = false;

      final expected = _parse("${occ.book} ${occ.ref}");
      if (expected == null) {
        results.add(
          FieldResult(
            input: "",
            expected: "${occ.book} ${occ.ref}",
            isCorrect: false,
          ),
        );
        continue;
      }

      for (int i = 0; i < inputs.length; i++) {
        if (used.contains(i)) continue;

        final input = _parse(inputs[i]);

        // ❗ WICHTIG: wenn Syntax kaputt → sofort falsch
        if (input == null) continue;

        if (_compare(input, expected, occ.precision)) {
          used.add(i);
          correct++;

          results.add(
            FieldResult(
              input: inputs[i],
              expected: "${occ.book} ${occ.ref}",
              isCorrect: true,
            ),
          );

          matched = true;
          break;
        }
      }

      if (!matched) {
        for (final occ in required) {
          final expected = "${occ.book} ${occ.ref}";

          final alreadyAdded = results.any((r) => r.expected == expected);
          if (!alreadyAdded) {
            results.add(
              FieldResult(input: "", expected: expected, isCorrect: false),
            );
          }
        }
      }
    }

    final status = correct == required.length
        ? QuizStatus.correct
        : (correct > 0 ? QuizStatus.partial : QuizStatus.wrong);

    return QuizResult(
      status: status,
      correctCount: correct,
      totalRequired: required.length,
      fieldResults: results,
    );
  }

  // ----------------------------
  // HARD PARSER (entscheidend!)
  // ----------------------------
  static _Ref? _parse(String input) {
    final cleaned = input
        .toLowerCase()
        .trim()
        .replaceAll("–", "-")
        .replaceAll("—", "-");

    final parts = cleaned.split(" ");
    if (parts.length != 2) return null;

    final book = parts[0];

    final refParts = parts[1].split(",");
    if (refParts.isEmpty) return null;

    final chapter = int.tryParse(refParts[0]);
    if (chapter == null) return null;

    int? verse;
    if (refParts.length > 1) {
      final versePart = refParts[1].split("-").first;

      verse = int.tryParse(versePart);

      if (verse == null) return null;
    }

    return _Ref(book, chapter, verse);
  }

  static bool _compare(_Ref a, _Ref b, String precision) {
    if (a.book != b.book) return false;

    if (precision == "chapter") {
      return a.chapter == b.chapter;
    }

    return a.chapter == b.chapter && a.verse == b.verse;
  }
}

class _Ref {
  final String book;
  final int chapter;
  final int? verse;

  _Ref(this.book, this.chapter, this.verse);
}
