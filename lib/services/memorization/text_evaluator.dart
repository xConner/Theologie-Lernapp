import 'dart:math' as math;

import 'text_tokens.dart';

enum AlignmentType { match, missing, extra, substitution }

/// Ein Schritt der Wort-für-Wort-Zuordnung von Eingabe und Zieltext.
class WordAlignment {
  final AlignmentType type;

  /// Wort des Zieltextes (fehlt bei [AlignmentType.extra]).
  final String? expected;

  /// Wort der Eingabe (fehlt bei [AlignmentType.missing]).
  final String? actual;

  /// Position im Zieltext; bei zusätzlichen Wörtern die des vorangehenden
  /// Zielworts (−1 vor dem ersten).
  final int targetIndex;

  /// Ersetzung, die nur eine kleine Schreib-/Hörabweichung ist
  /// („geschehen“ statt „geschehe“).
  final bool minor;

  /// Teil zweier vertauschter Nachbarwörter.
  final bool swapped;

  const WordAlignment({
    required this.type,
    required this.targetIndex,
    this.expected,
    this.actual,
    this.minor = false,
    this.swapped = false,
  });

  /// Zählt als Fehler (kleine Abweichungen nicht).
  bool get isError => type != AlignmentType.match && !minor;
}

enum RecallOutcome {
  /// Wortgetreu, höchstens kleine Schreibabweichungen.
  correct,

  /// Einzelne Wörter fehlen, sind zu viel oder falsch.
  almost,

  incorrect,
}

class EvaluationResult {
  final List<WordAlignment> alignment;
  final int targetCount;
  final int inputCount;
  final RecallOutcome outcome;

  const EvaluationResult({
    required this.alignment,
    required this.targetCount,
    required this.inputCount,
    required this.outcome,
  });

  int _count(bool Function(WordAlignment a) test) =>
      alignment.where(test).length;

  int get matched => _count((a) => a.type == AlignmentType.match);
  int get missing => _count((a) => a.type == AlignmentType.missing);
  int get extra => _count((a) => a.type == AlignmentType.extra);
  int get minor => _count((a) => a.minor);
  int get swappedPairs => _count((a) => a.swapped) ~/ 2;
  int get wrong => _count(
    (a) => a.type == AlignmentType.substitution && !a.minor && !a.swapped,
  );

  /// Anzahl der Abweichungen; ein vertauschtes Wortpaar zählt einmal.
  int get errors => missing + extra + wrong + swappedPairs;

  bool get isEmptyInput => inputCount == 0;

  /// Positionen im Zieltext, an denen etwas nicht stimmte. Zusätzliche
  /// Wörter zählen zur Stelle, an der sie eingefügt wurden.
  Set<int> get errorTargetIndices {
    return {
      for (final a in alignment)
        if (a.isError) math.max(0, a.targetIndex),
    };
  }

  /// Verständliche Rückmeldung, eine Zeile je Abweichung.
  List<String> messages({bool spoken = false}) {
    if (isEmptyInput) {
      return [spoken ? "Es wurde nichts erkannt." : "Keine Eingabe."];
    }

    final lines = <String>[];

    final missingNorms = <String, String>{};
    final extraNorms = <String, String>{};

    for (final a in alignment) {
      if (a.type == AlignmentType.missing) {
        missingNorms[MemorizationNormalizer.word(a.expected!)] = a.expected!;
      } else if (a.type == AlignmentType.extra) {
        extraNorms[MemorizationNormalizer.word(a.actual!)] = a.actual!;
      }
    }

    // Dasselbe Wort fehlt an einer Stelle und steht an einer anderen.
    final moved = missingNorms.keys.where(extraNorms.containsKey).toSet();

    for (final norm in moved) {
      lines.add("An der falschen Stelle: ${_quote(missingNorms[norm]!)}");
    }

    var i = 0;

    while (i < alignment.length) {
      final a = alignment[i];

      if (a.swapped) {
        lines.add("Vertauscht: ${_quote(a.expected!)} und ${_quote(a.actual!)}");
        i += 2;
        continue;
      }

      if (a.type == AlignmentType.substitution) {
        final text = "${_quote(a.actual!)} statt ${_quote(a.expected!)}";
        lines.add(a.minor ? "Kleine Abweichung: $text" : "Anderes Wort: $text");
        i++;
        continue;
      }

      if (a.type == AlignmentType.missing || a.type == AlignmentType.extra) {
        final words = <String>[];
        final type = a.type;

        while (i < alignment.length && alignment[i].type == type) {
          final word = type == AlignmentType.missing
              ? alignment[i].expected!
              : alignment[i].actual!;

          if (!moved.contains(MemorizationNormalizer.word(word))) {
            words.add(_clean(word));
          }
          i++;
        }

        if (words.isNotEmpty) {
          final label = type == AlignmentType.missing
              ? (words.length == 1 ? "Es fehlt" : "Es fehlen")
              : "Zu viel";

          lines.add("$label: „${words.join(" ")}“");
        }
        continue;
      }

      i++;
    }

    return lines;
  }

  static String _quote(String word) => "„${_clean(word)}“";

  static String _clean(String word) {
    final token = TextToken(raw: word, norm: MemorizationNormalizer.word(word));
    return token.isWord ? token.core : word;
  }
}

/// Lokaler, deterministischer Vergleich einer getippten oder gesprochenen
/// Wiedergabe mit dem Zieltext. Kommt ohne Netzwerk und ohne KI aus.
///
/// Verglichen wird Wort für Wort (Damerau-Levenshtein auf Wortebene):
/// fehlende, zusätzliche, ersetzte und vertauschte Wörter werden einzeln
/// ausgewiesen statt in einem Prozentwert zu verschwinden.
class MemorizationTextEvaluator {
  const MemorizationTextEvaluator();

  // Kosten ×10, damit kleine Abweichungen günstiger sind als fremde Wörter.
  static const int _edit = 10;
  static const int _minorCost = 6;

  /// Füllwörter, die die Spracherkennung mitschreibt.
  static const Set<String> _fillers = {
    "aeh",
    "aehm",
    "eh",
    "ehm",
    "hm",
    "hmm",
    "mhm",
    "oeh",
    "oehm",
    "uh",
    "uhm",
    "um",
  };

  /// Zahlwörter, die die Spracherkennung als Ziffer ausgibt
  /// („am 3. Tage“): Ziffer → Wortanfänge.
  static const Map<String, List<String>> _numberWords = {
    "1": ["ein", "erst", "one", "first"],
    "2": ["zwei", "zweit", "two", "second"],
    "3": ["drei", "dritt", "three", "third"],
    "4": ["vier", "four"],
    "5": ["fuenf", "five", "fif"],
    "6": ["sechs", "six"],
    "7": ["sieb", "seven"],
    "8": ["acht", "eight"],
    "9": ["neun", "nine", "nin"],
    "10": ["zehn", "ten"],
    "12": ["zwoelf", "twel"],
  };

  /// [target] ist der Zieltext (oder nur die abgefragten Wörter), [input]
  /// die Wiedergabe. [spoken] aktiviert die Toleranzen für Spracherkennung
  /// (Füllwörter, Ziffern statt Zahlwörter).
  EvaluationResult evaluate({
    required String target,
    required String input,
    bool spoken = false,
  }) {
    return evaluateWords(
      target: _words(target),
      input: input,
      spoken: spoken,
    );
  }

  EvaluationResult evaluateWords({
    required List<String> target,
    required String input,
    bool spoken = false,
  }) {
    final t = [
      for (final word in target)
        if (MemorizationNormalizer.word(word).isNotEmpty) word,
    ];
    final tn = t.map(MemorizationNormalizer.word).toList();

    var u = _words(input);

    if (spoken) {
      final targetNorms = tn.toSet();

      u = u.where((word) {
        final norm = MemorizationNormalizer.word(word);
        return !_fillers.contains(norm) || targetNorms.contains(norm);
      }).toList();
    }

    final un = u.map(MemorizationNormalizer.word).toList();

    final alignment = _align(t, tn, u, un, spoken);

    final result = EvaluationResult(
      alignment: alignment,
      targetCount: t.length,
      inputCount: u.length,
      outcome: RecallOutcome.incorrect,
    );

    return EvaluationResult(
      alignment: alignment,
      targetCount: t.length,
      inputCount: u.length,
      outcome: _outcome(result),
    );
  }

  static List<String> _words(String text) {
    return [
      for (final token in MemorizationNormalizer.tokenize(text))
        if (token.isWord) token.raw,
    ];
  }

  static RecallOutcome _outcome(EvaluationResult r) {
    final n = r.targetCount;

    if (r.isEmptyInput || n == 0) {
      return RecallOutcome.incorrect;
    }

    if (r.errors == 0) {
      // Viele „kleine“ Abweichungen sind zusammen keine wortgetreue
      // Wiedergabe mehr.
      return r.minor <= math.max(1, n ~/ 5)
          ? RecallOutcome.correct
          : RecallOutcome.almost;
    }

    final tolerated = math.max(1, (n * 0.15).floor());

    return n >= 4 && r.errors <= tolerated
        ? RecallOutcome.almost
        : RecallOutcome.incorrect;
  }

  static bool _equal(String target, String input, bool spoken) {
    if (target == input) return true;

    if (spoken) {
      final stems = _numberWords[input];
      return stems != null && stems.any(target.startsWith);
    }

    return false;
  }

  /// Kleine Abweichung: gleicher Anfangsbuchstabe und höchstens ein
  /// abweichender Buchstabe (bei langen Wörtern zwei). Kurze Wörter wie
  /// „dem/den“ und Paare wie „dein/mein“ gelten als anderes Wort.
  static bool isMinorDeviation(String a, String b) {
    if (a.isEmpty || b.isEmpty || a[0] != b[0]) return false;

    final length = math.max(a.length, b.length);

    if (length < 5) return false;

    final distance = _letterDistance(a, b);

    return distance <= 1 || (length >= 10 && distance <= 2);
  }

  static int _letterDistance(String a, String b) {
    if ((a.length - b.length).abs() > 2) return 3;

    final d = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        var best = math.min(
          math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );

        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          best = math.min(best, d[i - 2][j - 2] + 1);
        }

        d[i][j] = best;
      }
    }

    return d[a.length][b.length];
  }

  static List<WordAlignment> _align(
    List<String> t,
    List<String> tn,
    List<String> u,
    List<String> un,
    bool spoken,
  ) {
    final n = t.length;
    final m = u.length;

    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    int substitution(int i, int j) {
      if (_equal(tn[i], un[j], spoken)) return 0;
      return isMinorDeviation(tn[i], un[j]) ? _minorCost : _edit;
    }

    bool swap(int i, int j) {
      return i > 1 &&
          j > 1 &&
          tn[i - 1] != tn[i - 2] &&
          tn[i - 1] == un[j - 2] &&
          tn[i - 2] == un[j - 1];
    }

    for (var i = 1; i <= n; i++) {
      d[i][0] = i * _edit;
    }
    for (var j = 1; j <= m; j++) {
      d[0][j] = j * _edit;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        var best = math.min(
          math.min(d[i - 1][j] + _edit, d[i][j - 1] + _edit),
          d[i - 1][j - 1] + substitution(i - 1, j - 1),
        );

        if (swap(i, j)) {
          best = math.min(best, d[i - 2][j - 2] + _edit);
        }

        d[i][j] = best;
      }
    }

    // Rückverfolgung vom Ende; Vertauschung vor Ersetzung, damit zwei
    // vertauschte Wörter nicht als zwei falsche Wörter erscheinen.
    final reversed = <WordAlignment>[];

    var i = n;
    var j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        if (swap(i, j) && d[i][j] == d[i - 2][j - 2] + _edit) {
          reversed
            ..add(
              WordAlignment(
                type: AlignmentType.substitution,
                targetIndex: i - 1,
                expected: t[i - 1],
                actual: u[j - 1],
                swapped: true,
              ),
            )
            ..add(
              WordAlignment(
                type: AlignmentType.substitution,
                targetIndex: i - 2,
                expected: t[i - 2],
                actual: u[j - 2],
                swapped: true,
              ),
            );
          i -= 2;
          j -= 2;
          continue;
        }
        final cost = substitution(i - 1, j - 1);

        if (d[i][j] == d[i - 1][j - 1] + cost) {
          reversed.add(
            WordAlignment(
              type: cost == 0
                  ? AlignmentType.match
                  : AlignmentType.substitution,
              targetIndex: i - 1,
              expected: t[i - 1],
              actual: u[j - 1],
              minor: cost == _minorCost,
            ),
          );
          i--;
          j--;
          continue;
        }
      }

      if (i > 0 && d[i][j] == d[i - 1][j] + _edit) {
        reversed.add(
          WordAlignment(
            type: AlignmentType.missing,
            targetIndex: i - 1,
            expected: t[i - 1],
          ),
        );
        i--;
        continue;
      }

      reversed.add(
        WordAlignment(
          type: AlignmentType.extra,
          targetIndex: i - 1,
          actual: u[j - 1],
        ),
      );
      j--;
    }

    return reversed.reversed.toList();
  }
}
