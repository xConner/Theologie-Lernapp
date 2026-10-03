import 'text_tokens.dart';

/// Zerlegt einen Text in lernbare Abschnitte.
///
/// Genutzt wird die Struktur, die die Daten schon mitbringen:
///   * Leerzeilen (Absätze) trennen immer.
///   * Zeilen werden zusammengefasst, bis ein Satz endet oder der Abschnitt
///     [maxWords] Wörter erreicht – so bleibt z. B. „Dein Wille geschehe, /
///     wie im Himmel, so auf Erden.“ ein Abschnitt.
///   * Lange Prosazeilen werden an Satzenden, dann an Kommas geteilt.
///   * Sehr kurze Reste („Amen.“) hängen am vorigen Abschnitt.
class TextSegmenter {
  final int maxWords;
  final int minWords;

  const TextSegmenter({this.maxWords = 12, this.minWords = 3});

  static final RegExp _paragraphBreak = RegExp(r"\n\s*\n");
  static final RegExp _whitespace = RegExp(r"\s+");

  // Satzende: . ! ? ; : sowie griechischer Hochpunkt und Fragezeichen.
  static const String _sentenceEnd = ".!?;:··;";
  static const String _closing = "\"'»«“”‘’)]";

  List<String> segment(String text) {
    final segments = <String>[];

    for (final paragraph in text.split(_paragraphBreak)) {
      segments.addAll(_segmentParagraph(paragraph));
    }

    return _mergeTiny(segments);
  }

  List<String> _segmentParagraph(String paragraph) {
    final result = <String>[];

    var current = StringBuffer();
    var words = 0;

    void flush() {
      if (current.isNotEmpty) {
        result.add(current.toString());
      }
      current = StringBuffer();
      words = 0;
    }

    final lines = paragraph
        .split("\n")
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in lines) {
      var firstOfLine = true;

      for (final piece in _pieces(line)) {
        final count = MemorizationNormalizer.wordCount(piece);

        // Ein winziger Rest darf den Abschnitt leicht überziehen, statt
        // allein zu stehen.
        if (words >= minWords && words + count > maxWords && count >= minWords) {
          flush();
        }

        if (current.isNotEmpty) {
          current.write(firstOfLine ? "\n" : " ");
        }

        current.write(piece);
        words += count;
        firstOfLine = false;

        if (_endsSentence(piece) && words >= minWords) {
          flush();
        }
      }
    }

    flush();

    return result;
  }

  /// Teilt eine Zeile in Sätze; zu lange Sätze an Kommas, notfalls hart.
  List<String> _pieces(String line) {
    final pieces = <String>[];

    for (final sentence in _split(line, _endsSentence)) {
      if (MemorizationNormalizer.wordCount(sentence) <= maxWords) {
        pieces.add(sentence);
        continue;
      }

      for (final clause in _split(sentence, (w) => _stripClosing(w).endsWith(","))) {
        pieces.addAll(_hardSplit(clause));
      }
    }

    return pieces;
  }

  List<String> _split(String text, bool Function(String word) endsPiece) {
    final pieces = <String>[];
    final current = <String>[];

    for (final word in text.split(_whitespace)) {
      if (word.isEmpty) continue;

      current.add(word);

      if (endsPiece(word)) {
        pieces.add(current.join(" "));
        current.clear();
      }
    }

    if (current.isNotEmpty) {
      pieces.add(current.join(" "));
    }

    return pieces;
  }

  /// Teilt einen Teilsatz ohne Satzzeichen in etwa gleich große Stücke.
  List<String> _hardSplit(String clause) {
    final words = clause.split(_whitespace);

    if (words.length <= maxWords) {
      return [clause];
    }

    final parts = (words.length / maxWords).ceil();
    final size = (words.length / parts).ceil();

    return [
      for (var start = 0; start < words.length; start += size)
        words.skip(start).take(size).join(" "),
    ];
  }

  static String _stripClosing(String word) {
    var end = word.length;

    while (end > 0 && _closing.contains(word[end - 1])) {
      end--;
    }

    return word.substring(0, end);
  }

  static bool _endsSentence(String text) {
    final stripped = _stripClosing(text.trimRight());

    if (stripped.isEmpty || !_sentenceEnd.contains(stripped[stripped.length - 1])) {
      return false;
    }

    if (!stripped.endsWith(".")) {
      return true;
    }

    // Abkürzungen und Ordnungszahlen („z. B.“, „1. Mose“) beenden keinen Satz.
    final lastWord = stripped.split(_whitespace).last;
    final core = lastWord.substring(0, lastWord.length - 1);

    return !(core.length <= 1 || int.tryParse(core) != null);
  }

  List<String> _mergeTiny(List<String> segments) {
    final result = <String>[];

    for (final segment in segments) {
      final tiny = MemorizationNormalizer.wordCount(segment) < minWords;

      if (tiny && result.isNotEmpty) {
        result[result.length - 1] = "${result.last}\n$segment";
      } else {
        result.add(segment);
      }
    }

    // Ein winziger erster Abschnitt gehört zum folgenden.
    if (result.length > 1 &&
        MemorizationNormalizer.wordCount(result.first) < minWords) {
      final first = result.removeAt(0);
      result[0] = "$first\n${result.first}";
    }

    return result;
  }
}
