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

  /// Eingabewörter vor bzw. hinter dem abgefragten Bereich, die zu den
  /// Nachbarabschnitten gehören und daher nicht bewertet wurden (siehe
  /// [MemorizationTextEvaluator.evaluateWords]). Sie sind in [alignment]
  /// und [inputCount] nicht enthalten.
  final int ignoredBefore;
  final int ignoredAfter;

  const EvaluationResult({
    required this.alignment,
    required this.targetCount,
    required this.inputCount,
    required this.outcome,
    this.ignoredBefore = 0,
    this.ignoredAfter = 0,
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

  /// Wurde Text außerhalb des abgefragten Bereichs mit eingegeben?
  bool get hasIgnoredContext => ignoredBefore + ignoredAfter > 0;

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

    // Die Abweichungen beziehen sich nur auf den abgefragten Bereich.
    if (hasIgnoredContext && outcome != RecallOutcome.correct) {
      lines.add(
        "Text vor oder nach den abgefragten Abschnitten wurde nicht bewertet.",
      );
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

  /// Wie [evaluate], mit dem Zieltext als Wortliste.
  ///
  /// [before] und [after] sind die Wörter der Abschnitte unmittelbar vor
  /// bzw. hinter dem abgefragten Bereich (siehe [neighbourWords]). Wer die
  /// Abschnittsgrenzen nicht genau kennt und davor oder danach weiteren
  /// Text des Werks eingibt, wird dafür nicht bestraft: Eingabewörter, die
  /// sich zuverlässig diesen Nachbarabschnitten zuordnen lassen, werden
  /// abgetrennt, bewertet wird nur der abgefragte Bereich. Fehler darin
  /// zählen unverändert.
  EvaluationResult evaluateWords({
    required List<String> target,
    required String input,
    bool spoken = false,
    List<String> before = const [],
    List<String> after = const [],
  }) {
    final t = _significant(target);
    final tn = t.map(MemorizationNormalizer.word).toList();

    final words = _words(input);
    final whole = _evaluate(t, tn, words, spoken);

    if (before.isEmpty && after.isEmpty) return whole;

    final b = _significant(before);
    final a = _significant(after);
    final bn = b.map(MemorizationNormalizer.word).toList();
    final an = a.map(MemorizationNormalizer.word).toList();

    final u = spoken ? _withoutFillers(words, {...tn, ...bn, ...an}) : words;

    final range = _locate(
      bn,
      tn,
      an,
      u.map(MemorizationNormalizer.word).toList(),
      spoken,
    );

    if (range == null) return whole;

    final (:lead, :start, :end, :trail) = range;

    final core = _evaluate(t, tn, u.sublist(start, end), spoken);

    // Wörter am äußeren Rand, die zu keinem Nachbarabschnitt passen, bleiben
    // zusätzliche Wörter vor bzw. hinter dem Zielbereich.
    final alignment = [
      for (final word in u.take(lead))
        WordAlignment(type: AlignmentType.extra, targetIndex: -1, actual: word),
      ...core.alignment,
      for (final word in u.skip(trail))
        WordAlignment(
          type: AlignmentType.extra,
          targetIndex: t.length - 1,
          actual: word,
        ),
    ];

    final inputCount = core.inputCount + lead + (u.length - trail);

    final draft = EvaluationResult(
      alignment: alignment,
      targetCount: t.length,
      inputCount: inputCount,
      outcome: RecallOutcome.incorrect,
    );

    final trimmed = EvaluationResult(
      alignment: alignment,
      targetCount: t.length,
      inputCount: inputCount,
      outcome: _outcome(draft),
      ignoredBefore: start - lead,
      ignoredAfter: trail - end,
    );

    // Das Abtrennen darf die Bewertung nie verschlechtern.
    return _rank(trimmed) > _rank(whole) ? trimmed : whole;
  }

  /// Wörter der Abschnitte vor [from] und nach [to] (je einschließlich) aus
  /// [segments], den Texten aller Abschnitte eines Lerntextes. Je Seite
  /// werden ganze Abschnitte genommen, bis mindestens [limit] Wörter
  /// beisammen sind – mehr kann eine Eingabe dieser Länge nicht abdecken.
  static ({List<String> before, List<String> after}) neighbourWords(
    List<String> segments,
    int from,
    int to, {
    required int limit,
  }) {
    List<String> wordsOf(int index) => _words(segments[index]);

    final before = <String>[];
    for (var i = from - 1; i >= 0 && before.length < limit; i--) {
      before.insertAll(0, wordsOf(i));
    }

    final after = <String>[];
    for (var i = to + 1; i < segments.length && after.length < limit; i++) {
      after.addAll(wordsOf(i));
    }

    return (before: before, after: after);
  }

  EvaluationResult _evaluate(
    List<String> t,
    List<String> tn,
    List<String> words,
    bool spoken,
  ) {
    final u = spoken ? _withoutFillers(words, tn.toSet()) : words;
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

  static List<String> _significant(List<String> words) => [
    for (final word in words)
      if (MemorizationNormalizer.word(word).isNotEmpty) word,
  ];

  static List<String> _withoutFillers(List<String> words, Set<String> keep) {
    return words.where((word) {
      final norm = MemorizationNormalizer.word(word);
      return !_fillers.contains(norm) || keep.contains(norm);
    }).toList();
  }

  /// Rangfolge zweier Bewertungen derselben Aufgabe: besseres Ergebnis,
  /// dann weniger Abweichungen.
  static int _rank(EvaluationResult r) {
    final outcome = switch (r.outcome) {
      RecallOutcome.correct => 2,
      RecallOutcome.almost => 1,
      RecallOutcome.incorrect => 0,
    };

    return outcome * 1000000 - r.errors * 1000 - r.minor;
  }

  /// Ordnet die Eingabe [un] dem fortlaufenden Text Vorabschnitte [bn] +
  /// Zielbereich [tn] + Folgeabschnitte [an] zu – oder null, wenn nichts
  /// zuverlässig abzutrennen ist. Die Eingabe zerfällt in
  ///
  /// * `[0, lead)`: fremde Wörter vor dem Vortext,
  /// * `[lead, start)`: Text der Vorabschnitte (wird nicht bewertet),
  /// * `[start, end)`: der Zielbereich,
  /// * `[end, trail)`: Text der Folgeabschnitte (wird nicht bewertet),
  /// * `[trail, m)`: fremde Wörter hinter dem Folgetext.
  ///
  /// Wortvergleich wie in [_align], aber die Eingabe darf an beliebiger
  /// Stelle der Vorabschnitte beginnen und der Folgeabschnitte enden
  /// (übersprungener Text davor und danach kostet nichts). Ein Treffer im
  /// Zielbereich ist minimal billiger als einer in den Nachbarabschnitten:
  /// Bei gleich guten Zuordnungen, etwa bei wiederkehrenden Formulierungen,
  /// wird die Eingabe dem Zielbereich zugeschlagen und nicht abgetrennt.
  ///
  /// Abgetrennt wird ein Rand der Eingabe nur, wenn er dem Nachbartext
  /// überwiegend entspricht (mindestens so viele Treffer wie Abweichungen),
  /// und nur bis zum äußersten Treffer: Wörter davor bzw. dahinter, die zu
  /// keinem Nachbarwort passen, bleiben als „Zu viel“ in der Bewertung.
  static ({int lead, int start, int end, int trail})? _locate(
    List<String> bn,
    List<String> tn,
    List<String> an,
    List<String> un,
    bool spoken,
  ) {
    final e = [...bn, ...tn, ...an];
    final b = bn.length;
    final targetEnd = b + tn.length;
    final n = e.length;
    final m = un.length;

    if (m == 0 || tn.isEmpty) return null;

    // −1 = vor dem Zielbereich, 0 = Zielbereich, 1 = danach.
    int region(int i) => i < b ? -1 : (i >= targetEnd ? 1 : 0);

    const contextMatch = 1;

    int substitution(int i, int j) {
      if (_equal(e[i], un[j], spoken)) {
        return region(i) == 0 ? 0 : contextMatch;
      }
      return isMinorDeviation(e[i], un[j]) ? _minorCost : _edit;
    }

    bool swap(int i, int j) {
      return i > 1 &&
          j > 1 &&
          e[i - 1] != e[i - 2] &&
          e[i - 1] == un[j - 2] &&
          e[i - 2] == un[j - 1];
    }

    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (var i = 1; i <= n; i++) {
      d[i][0] = i <= b ? 0 : d[i - 1][0] + _edit;
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

    // Ende frühestens hinter dem Zielbereich; die übrigen Folgewörter
    // dürfen fehlen.
    var i = targetEnd;
    for (var k = targetEnd + 1; k <= n; k++) {
      if (d[k][m] < d[i][m]) i = k;
    }

    final owner = List<int>.filled(m, 0);
    final hit = List<bool>.filled(m, false);

    // Ausgelassene Wörter der Nachbarabschnitte (innerhalb der Eingabe).
    final gaps = {-1: 0, 1: 0};
    var targetHit = false;

    void assign(int j, int r, {bool matched = false}) {
      owner[j] = r;
      hit[j] = matched;
      if (r == 0 && matched) targetHit = true;
    }

    var j = m;

    while (j > 0) {
      if (i > 0) {
        if (swap(i, j) && d[i][j] == d[i - 2][j - 2] + _edit) {
          assign(j - 1, region(i - 1));
          assign(j - 2, region(i - 2));
          i -= 2;
          j -= 2;
          continue;
        }

        final cost = substitution(i - 1, j - 1);

        if (d[i][j] == d[i - 1][j - 1] + cost) {
          assign(j - 1, region(i - 1), matched: cost < _edit);
          i--;
          j--;
          continue;
        }

        if (d[i][j] == d[i - 1][j] + _edit) {
          final r = region(i - 1);
          if (r != 0) gaps[r] = gaps[r]! + 1;
          i--;
          continue;
        }
      }

      // Zusätzliches Wort zwischen e[i − 1] und e[i]; an der Grenze zum
      // Zielbereich zählt es zum Zielbereich.
      assign(j - 1, i < b ? -1 : (i > targetEnd ? 1 : 0));
      j--;
    }

    if (!targetHit) return null;

    var start = 0;
    while (start < m && owner[start] == -1) {
      start++;
    }

    var end = m;
    while (end > start && owner[end - 1] == 1) {
      end--;
    }

    // Die Zuordnung ist monoton; alles dazwischen gehört zum Zielbereich.
    for (var k = start; k < end; k++) {
      if (owner[k] != 0) return null;
    }

    // Abgetrennt wird nur bis zum äußersten Treffer im Nachbartext.
    var lead = 0;
    while (lead < start && !hit[lead]) {
      lead++;
    }

    var trail = m;
    while (trail > end && !hit[trail - 1]) {
      trail--;
    }

    bool reliable(int from, int to, int side) {
      final matched = hit.sublist(from, to).where((h) => h).length;
      return matched > 0 && matched >= (to - from - matched) + gaps[side]!;
    }

    if (!reliable(lead, start, -1)) lead = start = 0;
    if (!reliable(end, trail, 1)) end = trail = m;

    if (start == 0 && end == m) return null;

    return (lead: lead, start: start, end: end, trail: trail);
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
