/// Ein Abschnitt nach dem Abtrennen der Überschriften.
class TitledPart {
  /// Position in der ursprünglichen Zerlegung – daraus entsteht die ID des
  /// Abschnitts, damit gespeicherte Lernstände ihren Text behalten.
  final int index;

  final String text;

  final String? title;

  const TitledPart(this.index, this.text, this.title);
}

/// Trennt in ausgewählten Texten die Überschriften vom Lerntext.
///
/// „Das erste Gebot.“, „Was ist das?“ oder „Danach das Vaterunser und dies
/// folgende Gebet:“ dienen der Orientierung; aufgesagt wird der Wortlaut
/// darunter. Solche Zeilen werden zum Titel der folgenden Abschnitte und
/// sind selbst keine Lernaufgabe.
///
/// Die Regeln gelten nur für die in [forWork] genannten Texte, deren Aufbau
/// geprüft ist – nicht pauschal für alle Bekenntnisschriften.
class SegmentHeadings {
  /// Überschriften und Fragen am Anfang eines mehrzeiligen Absatzes.
  final bool headings;

  /// Einzeilige Absätze, die mit Doppelpunkt enden (Anweisungen).
  final bool rubrics;

  const SegmentHeadings._({this.headings = false, this.rubrics = false});

  static const SegmentHeadings _catechism = SegmentHeadings._(headings: true);
  static const SegmentHeadings _rubrics = SegmentHeadings._(rubrics: true);

  static const Map<String, SegmentHeadings> _works = {
    "prayer.zehn_gebote": _catechism,
    "confession.kleiner_katechismus.hauptstueck_1": _catechism,
    "confession.kleiner_katechismus.hauptstueck_2": _catechism,
    "confession.kleiner_katechismus.hauptstueck_3": _catechism,
    "confession.kleiner_katechismus.hauptstueck_4": _catechism,
    "confession.kleiner_katechismus.hauptstueck_5": _catechism,
    "confession.kleiner_katechismus.hauptstueck_6": _catechism,
    "prayer.tischgebet_benedicite": _rubrics,
    "prayer.tischgebet_gratias": _rubrics,
  };

  /// Die Regeln für ein Werk; `null`, wenn es keine Überschriften abtrennt.
  static SegmentHeadings? forWork(String workId) => _works[workId];

  static final RegExp _paragraphBreak = RegExp(r"\n\s*\n");
  static final RegExp _whitespace = RegExp(r"\s+");
  static final RegExp _letterEnd = RegExp(r"\p{L}$", unicode: true);

  // Eine Überschrift wie „Der erste Artikel.“ hat höchstens so viele Wörter.
  static const int _maxHeadingWords = 4;

  // Kurze Fragen („Was ist das?“) beziehen sich auf die Überschrift davor,
  // längere nennen ihren Gegenstand selbst.
  static const int _maxFollowUpWords = 5;

  // Bis zu dieser Länge bleibt der Absatz unter einer Überschrift ganz –
  // ein Gebot oder eine kurze Antwort wird als Einheit gelernt.
  static const int _maxWholeWords = 40;

  /// Ordnet den Abschnitten [parts] der Zerlegung von [content] ihre Titel
  /// zu und lässt Abschnitte weg, die nur aus Überschriften bestehen. Ein
  /// kurzer Absatz unter einer Überschrift bleibt ein einziger Abschnitt.
  ///
  /// Passen Text und Zerlegung nicht zusammen, bleibt alles unverändert.
  List<TitledPart> apply(String content, List<String> parts) {
    final lines = _lines(content);

    final result = <TitledPart>[];

    // Absatz, in dem der letzte Abschnitt beginnt, und die Zeile, mit der
    // er bisher endet.
    var lastParagraph = -1;
    var lastLine = -1;

    var line = 0;
    var used = 0;

    for (var i = 0; i < parts.length; i++) {
      final kept = StringBuffer();
      _Line? first;
      var joinsPrevious = false;

      // Jede Zeile eines Abschnitts stammt aus genau einer Zeile des Textes.
      for (final chunk in parts[i].split("\n")) {
        final count = _wordCount(chunk);

        if (count == 0) continue;

        if (line >= lines.length || used + count > lines[line].words) {
          return _unchanged(parts);
        }

        final current = lines[line];

        if (!current.heading) {
          if (first == null) {
            first = current;
            joinsPrevious = current.whole && current.paragraph == lastParagraph;
          }

          if (kept.isNotEmpty || joinsPrevious) {
            kept.write(line == lastLine ? " " : "\n");
          }

          kept.write(chunk);
          lastLine = line;
        }

        used += count;

        if (used == current.words) {
          line++;
          used = 0;
        }
      }

      if (first == null) continue;

      if (joinsPrevious) {
        final previous = result.removeLast();

        result.add(
          TitledPart(previous.index, "${previous.text}$kept", previous.title),
        );
      } else {
        result.add(TitledPart(i, kept.toString(), first.title));
        lastParagraph = first.paragraph;
      }
    }

    return result.isEmpty ? _unchanged(parts) : result;
  }

  static List<TitledPart> _unchanged(List<String> parts) => [
    for (var i = 0; i < parts.length; i++) TitledPart(i, parts[i], null),
  ];

  List<_Line> _lines(String content) {
    final result = <_Line>[];

    // Überschrift, die über ihren Absatz hinaus gilt („Das erste Gebot“).
    String? section;

    // Anweisung vor dem nächsten Absatz.
    String? rubric;

    var paragraph = 0;

    for (final block in content.split(_paragraphBreak)) {
      final lines = block
          .split("\n")
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) continue;

      if (rubrics && lines.length == 1 && lines.first.endsWith(":")) {
        rubric = _strip(lines.first);
        result.add(
          _Line(_wordCount(lines.first), paragraph: paragraph++, heading: true),
        );
        continue;
      }

      // Die letzte Zeile ist immer Lerntext.
      var count = 0;

      if (headings) {
        while (count < lines.length - 1 && _isHeading(lines[count])) {
          count++;
        }
      }

      String? title;

      if (count == 0) {
        section = null;
        title = rubric;
      } else {
        final named = [
          for (final line in lines.take(count))
            if (!line.endsWith("?")) _strip(line),
        ];

        final question = lines
            .take(count)
            .where((line) => line.endsWith("?"))
            .lastOrNull;

        if (named.isNotEmpty) {
          section = named.join(": ");
        } else if (_wordCount(question!) > _maxFollowUpWords) {
          section = null;
        }

        title = [?section, ?question].join(" – ");
      }

      rubric = null;

      final body = lines
          .skip(count)
          .fold<int>(0, (sum, line) => sum + _wordCount(line));

      for (var i = 0; i < lines.length; i++) {
        result.add(
          _Line(
            _wordCount(lines[i]),
            paragraph: paragraph,
            heading: i < count,
            title: title,
            whole: count > 0 && body <= _maxWholeWords,
          ),
        );
      }

      paragraph++;
    }

    return result;
  }

  static bool _isHeading(String line) {
    if (line.endsWith("?")) return true;

    // Auch ohne Schlusspunkt („Of Sanctification“).
    return (line.endsWith(".") || _letterEnd.hasMatch(line)) &&
        _wordCount(line) <= _maxHeadingWords;
  }

  /// Ohne den abschließenden Punkt bzw. Doppelpunkt.
  static String _strip(String line) {
    return line.endsWith(".") || line.endsWith(":")
        ? line.substring(0, line.length - 1)
        : line;
  }

  static int _wordCount(String text) {
    return text.split(_whitespace).where((word) => word.isNotEmpty).length;
  }
}

class _Line {
  final int words;

  /// Laufende Nummer des Absatzes.
  final int paragraph;

  final bool heading;
  final String? title;

  /// Der Lerntext des Absatzes bleibt ein Abschnitt.
  final bool whole;

  const _Line(
    this.words, {
    required this.paragraph,
    required this.heading,
    this.title,
    this.whole = false,
  });
}
