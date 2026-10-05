/// Gleicht das Transkript einer lateinischen Spracherkennung lautlich mit dem
/// Zieltext ab, bevor der gewöhnliche Wortvergleich
/// (`MemorizationTextEvaluator`) läuft.
///
/// Warum: Für Latein gibt es keine Erkennung mit verlässlicher
/// Rechtschreibung. Das verwendete Modell schreibt nach Gehör – „celi“ oder
/// „tselis“ für „caelis“, „etterre“ für „et terrae“, „grazia“ für „gratia“ –
/// und setzt Wortgrenzen anders. Ein Vergleich Wort für Wort würde ein
/// richtig aufgesagtes Gebet deshalb als falsch werten.
///
/// Wie: Zieltext und Transkript werden in eine Lautschrift überführt, die
/// klassische, kirchenlateinische und deutsche Schulaussprache auf dieselbe
/// Form bringt, und ohne Rücksicht auf Wortgrenzen Zeichen für Zeichen
/// zugeordnet. Ein Zielwort gilt als gesprochen, wenn sein Abschnitt lautlich
/// passt; dann steht im Ergebnis das Zielwort selbst. Alles andere bleibt
/// stehen, wie es erkannt wurde, und wird vom Wortvergleich als Abweichung
/// gemeldet.
///
/// Der Abgleich ist deterministisch und kennt keine Bedeutung: „Mater“ ist
/// nicht „Pater“, „tuam“ nicht „tuum“. Geduldet werden nur wenige, typische
/// Hörfehler im Wortinneren (e/i, o/u, d/t, b/p, g/k, m/n); Anlaut und
/// Endung müssen stimmen, weil im Lateinischen die Endung den Wortlaut
/// ausmacht.
class LatinSpeechMatcher {
  LatinSpeechMatcher._();

  static const String _vowels = "aeiou";

  /// Laute, die die Erkennung häufig verwechselt.
  static const List<String> _similar = ["ei", "ou", "dt", "bp", "gk", "mn", "bu"];

  /// Am Wortende austauschbar („communionen“ für „communionem“).
  static const List<String> _similarAtEnd = ["mn", "dt"];

  // Zuordnungskosten: gleich 0, ähnlich 2, sonst 3 (wie Einfügen/Auslassen).
  static const int _costSimilar = 2;
  static const int _costOther = 3;

  static final RegExp _combining = RegExp("[̀-ͯ]");
  static final RegExp _nonLetter = RegExp("[^a-z]");
  static final RegExp _whitespace = RegExp(r"\s+");

  static const Map<String, String> _plain = {
    "æ": "ae", "œ": "oe", "ǽ": "ae", "ß": "ss",
    "ā": "a", "á": "a", "à": "a", "â": "a", "ă": "a", "ä": "a", "ã": "a",
    "ē": "e", "é": "e", "è": "e", "ê": "e", "ĕ": "e", "ë": "e",
    "ī": "i", "í": "i", "ì": "i", "î": "i", "ĭ": "i", "ï": "i",
    "ō": "o", "ó": "o", "ò": "o", "ô": "o", "ŏ": "o", "ö": "o", "õ": "o",
    "ū": "u", "ú": "u", "ù": "u", "û": "u", "ŭ": "u", "ü": "u",
    "ȳ": "y", "ý": "y", "ÿ": "y",
    "ç": "c", "č": "c", "ć": "c", "ñ": "n", "ń": "n",
    "š": "s", "ś": "s", "ș": "s", "ş": "s", "ț": "t", "ţ": "t",
    "ž": "z", "ź": "z", "ż": "z",
    "ą": "a", "å": "a", "ę": "e", "ě": "e", "ǫ": "o", "ő": "o", "ů": "u",
    "ű": "u", "ŵ": "w", "ŷ": "y", "ď": "d", "ň": "n", "ř": "r", "ť": "t",
  };

  /// Lautschrift eines Wortes: Kleinbuchstaben a–z, unabhängig von der
  /// Aussprachetradition. „caelis“, „cēlīs“, „tselis“ und „chelis“ ergeben
  /// dieselbe Form.
  static String phoneticKey(String word) {
    final buffer = StringBuffer();

    for (final rune in word.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_plain[char] ?? char);
    }

    var w = buffer
        .toString()
        .replaceAll(_combining, "")
        .replaceAll(_nonLetter, "");

    w = w
        .replaceAll("ae", "e")
        .replaceAll("oe", "e")
        .replaceAll("y", "i")
        .replaceAll("j", "i")
        .replaceAll("ph", "f")
        .replaceAll("th", "t")
        .replaceAll("rh", "r")
        .replaceAll("tsch", "c")
        .replaceAll("sch", "sc")
        .replaceAll("sh", "sc")
        // „ch“ vor e/i wie das kirchenlateinische c („chelis“), sonst k.
        .replaceAll(RegExp("ch(?=[ei])"), "c")
        .replaceAll("ch", "k")
        .replaceAll("h", "")
        .replaceAll("qu", "ku")
        .replaceAll("q", "k")
        .replaceAll("x", "ks")
        .replaceAll("w", "u")
        .replaceAll("v", "u")
        // „regnum“ kirchenlateinisch „renjum“.
        .replaceAll("gn", "ni")
        .replaceAll(RegExp("t[sz]"), "z")
        // „gratia“ = „grazia“ = „gratsia“.
        .replaceAll(RegExp("(?<![st])ti(?=[aeou])"), "zi")
        // c vor e/i: k, ts oder tsch je nach Tradition.
        .replaceAll(RegExp("s?c+(?=[ei])"), "z")
        .replaceAll("c", "k")
        .replaceAll("z", "s");

    return w;
  }

  /// Ersetzt im [transcript] alles, was lautlich einem Wort aus [target]
  /// entspricht, durch dieses Wort. Das Ergebnis geht anstelle des
  /// Transkripts in den Wortvergleich.
  static String reconcile({
    required List<String> target,
    required String transcript,
  }) {
    final heard = [
      for (final word in transcript.trim().split(_whitespace))
        if (phoneticKey(word).isNotEmpty) word,
    ];

    if (heard.isEmpty) return "";

    final match = _match(target, heard);

    // Zeichen der Eingabe, die durch ein erkanntes Zielwort erklärt sind.
    final explained = <int>{
      for (var w = 0; w < target.length; w++)
        if (match.accepted[w]) ...match.covered[w],
    };

    final total = List<int>.filled(heard.length, 0);
    final matched = List<int>.filled(heard.length, 0);
    final firstIndex = List<int>.filled(heard.length, -1);

    for (var j = 0; j < match.heardOwner.length; j++) {
      final word = match.heardOwner[j];

      total[word]++;
      if (explained.contains(j)) matched[word]++;
      if (firstIndex[word] < 0) firstIndex[word] = j;
    }

    // Gehörte Wörter, die überwiegend zu keinem erkannten Zielwort gehören,
    // bleiben als Abweichung stehen.
    final leftover = [
      for (var h = 0; h < heard.length; h++)
        if (total[h] > 0 && matched[h] * 2 < total[h]) h,
    ];

    final words = <String>[];
    var next = 0;

    for (var w = 0; w < target.length; w++) {
      if (!match.accepted[w]) continue;

      if (match.covered[w].isNotEmpty) {
        final position = match.covered[w].reduce((a, b) => a < b ? a : b);

        while (next < leftover.length && firstIndex[leftover[next]] < position) {
          words.add(heard[leftover[next++]]);
        }
      }

      words.add(target[w]);
    }

    while (next < leftover.length) {
      words.add(heard[leftover[next++]]);
    }

    return words.join(" ");
  }

  /// Welche Wörter aus [target] im [transcript] lautlich wiederzufinden
  /// sind (für Tests und Auswertungen).
  static List<bool> recognized({
    required List<String> target,
    required String transcript,
  }) {
    final heard = [
      for (final word in transcript.trim().split(_whitespace))
        if (phoneticKey(word).isNotEmpty) word,
    ];

    return _match(target, heard).accepted;
  }

  static bool _isVowel(String char) => _vowels.contains(char);

  static bool _inSameGroup(List<String> groups, String a, String b) {
    for (final group in groups) {
      if (group.contains(a) && group.contains(b)) return true;
    }

    return false;
  }

  /// So viele Abweichungen duldet ein Wort der Länge [length] insgesamt …
  static int _tolerated(int length) {
    if (length <= 2) return 0;
    if (length <= 5) return 1;
    if (length <= 9) return 2;
    return 3;
  }

  /// … und so viele davon dürfen fremde Laute sein.
  static int _toleratedForeign(int length) {
    if (length < 9) return 0;
    if (length < 14) return 1;
    return 2;
  }

  static _MatchResult _match(List<String> target, List<String> heard) {
    final a = _Stream(target);
    final b = _Stream(heard);

    final n = a.chars.length;
    final m = b.chars.length;

    int cost(String x, String y) {
      if (x == y) return 0;
      return _inSameGroup(_similar, x, y) ? _costSimilar : _costOther;
    }

    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (var i = 1; i <= n; i++) {
      d[i][0] = i * _costOther;
    }
    for (var j = 1; j <= m; j++) {
      d[0][j] = j * _costOther;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final substitute = d[i - 1][j - 1] + cost(a.chars[i - 1], b.chars[j - 1]);
        final omit = d[i - 1][j] + _costOther;
        final insert = d[i][j - 1] + _costOther;

        var best = substitute;
        if (omit < best) best = omit;
        if (insert < best) best = insert;

        d[i][j] = best;
      }
    }

    final words = target.length;

    final similar = List<int>.filled(words, 0);
    final foreign = List<int>.filled(words, 0);
    final length = List<int>.filled(words, 0);
    final start = List<int>.filled(words, -1);
    final end = List<int>.filled(words, -1);
    final onsetOk = List<bool>.filled(words, false);
    final endingBroken = List<bool>.filled(words, false);
    final covered = List.generate(words, (_) => <int>[]);

    for (var i = 0; i < n; i++) {
      final word = a.owner[i];

      length[word]++;
      if (start[word] < 0) start[word] = i;
      end[word] = i;
    }

    // Endung: vom letzten Vokal des Wortes an.
    final ending = List<int>.filled(words, -1);

    for (var w = 0; w < words; w++) {
      if (start[w] < 0) continue;

      ending[w] = start[w];

      for (var i = end[w]; i >= start[w]; i--) {
        if (_isVowel(a.chars[i])) {
          ending[w] = i;
          break;
        }
      }
    }

    // Rückverfolgung vom Ende; dieselbe Reihenfolge der Prüfungen wie beim
    // Aufbau, damit das Ergebnis eindeutig ist.
    var i = n;
    var j = m;

    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          d[i][j] == d[i - 1][j - 1] + cost(a.chars[i - 1], b.chars[j - 1])) {
        final x = a.chars[i - 1];
        final y = b.chars[j - 1];
        final word = a.owner[i - 1];

        covered[word].add(j - 1);

        if (x != y) {
          final isSimilar = _inSameGroup(_similar, x, y);

          if (isSimilar) {
            similar[word]++;
          } else {
            foreign[word]++;
          }

          if (i - 1 >= ending[word] && !_inSameGroup(_similarAtEnd, x, y)) {
            endingBroken[word] = true;
          }

          if (i - 1 == start[word]) onsetOk[word] = isSimilar;
        } else if (i - 1 == start[word]) {
          onsetOk[word] = true;
        }

        i--;
        j--;
      } else if (i > 0 && d[i][j] == d[i - 1][j] + _costOther) {
        // Laut des Zielworts fehlt.
        final x = a.chars[i - 1];
        final word = a.owner[i - 1];

        final inHiatus =
            _isVowel(x) &&
            ((i - 2 >= 0 && _isVowel(a.chars[i - 2])) ||
                (i < n && _isVowel(a.chars[i])));

        if (inHiatus) {
          similar[word]++;
        } else {
          foreign[word]++;
        }

        if (i - 1 >= ending[word]) endingBroken[word] = true;

        i--;
      } else {
        // Zusätzlicher Laut vor a[i]; zählt nur im Wortinneren.
        if (i < n && i > 0 && a.owner[i] == a.owner[i - 1]) {
          final y = b.chars[j - 1];
          final word = a.owner[i];

          final inHiatus =
              _isVowel(y) &&
              (_isVowel(a.chars[i]) || _isVowel(a.chars[i - 1]));

          if (inHiatus) {
            similar[word]++;
          } else {
            foreign[word]++;
          }

          covered[word].add(j - 1);

          if (i > ending[word]) endingBroken[word] = true;
        }

        j--;
      }
    }

    final accepted = List<bool>.filled(words, false);

    for (var w = 0; w < words; w++) {
      // Reine Satzzeichen oder ein Wort, das in einem Doppellaut aufgeht.
      if (length[w] == 0) {
        accepted[w] = phoneticKey(target[w]).isNotEmpty;
        continue;
      }

      final deviations = similar[w] + foreign[w];

      accepted[w] =
          deviations == 0 ||
          (foreign[w] <= _toleratedForeign(length[w]) &&
              deviations <= _tolerated(length[w]) &&
              onsetOk[w] &&
              !endingBroken[w]);
    }

    return _MatchResult(accepted, covered, b.owner);
  }
}

/// Lautschrift einer Wortfolge als Zeichenkette ohne Wortgrenzen. Gleiche
/// Laute hintereinander – auch über eine Wortgrenze hinweg („et terra“) –
/// zählen einmal, weil die Erkennung sie nicht trennt.
class _Stream {
  final List<String> chars = [];

  /// Index des Wortes, aus dem das Zeichen stammt.
  final List<int> owner = [];

  _Stream(List<String> words) {
    for (var w = 0; w < words.length; w++) {
      final key = LatinSpeechMatcher.phoneticKey(words[w]);

      for (var c = 0; c < key.length; c++) {
        if (chars.isNotEmpty && chars.last == key[c]) continue;

        chars.add(key[c]);
        owner.add(w);
      }
    }
  }
}

class _MatchResult {
  final List<bool> accepted;

  /// Je Zielwort die Zeichen der Eingabe, die ihm zugeordnet wurden.
  final List<List<int>> covered;

  /// Je Zeichen der Eingabe der Index des gehörten Wortes.
  final List<int> heardOwner;

  const _MatchResult(this.accepted, this.covered, this.heardOwner);
}
