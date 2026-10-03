import 'dart:math' as math;

import 'text_tokens.dart';

/// Hilfestufen vom Erkennen zum freien Erinnern. Die Reihenfolge ist die
/// Lernprogression; der Index wird im Lernstand gespeichert.
enum HintLevel { read, fewGaps, manyGaps, firstLetters, minimal, free }

extension HintLevelLabel on HintLevel {
  String get label {
    switch (this) {
      case HintLevel.read:
        return "Mitlesen";
      case HintLevel.fewGaps:
        return "Lücken";
      case HintLevel.manyGaps:
        return "Viele Lücken";
      case HintLevel.firstLetters:
        return "Anfangsbuchstaben";
      case HintLevel.minimal:
        return "Kaum Hinweise";
      case HintLevel.free:
        return "Frei";
    }
  }

  bool get hasGaps => this == HintLevel.fewGaps || this == HintLevel.manyGaps;
}

/// Was auf einer Hilfestufe vom Text zu sehen ist.
class HintPrompt {
  final HintLevel level;

  /// Der angezeigte Text mit Lücken bzw. Anfangsbuchstaben; leer bei
  /// [HintLevel.free].
  final String display;

  /// Alle Wörter des Zieltextes in Reihenfolge.
  final List<TextToken> words;

  /// Indizes der ausgeblendeten Wörter in [words] (nur Lückenstufen).
  final List<int> hidden;

  const HintPrompt({
    required this.level,
    required this.display,
    required this.words,
    required this.hidden,
  });

  List<String> get hiddenWords => [for (final i in hidden) words[i].raw];
}

/// Erzeugt die Hilfen lokal aus dem Text: Lücken, Anfangsbuchstaben,
/// Abschnittsanfänge.
class HintGenerator {
  const HintGenerator();

  static const String gap = "_____";

  /// [segments] sind die Texte der (verbundenen) Abschnitte. [variant]
  /// wechselt die Auswahl der Lücken von Versuch zu Versuch; bei gleichem
  /// Wert entsteht dieselbe Aufgabe.
  HintPrompt build(
    List<String> segments,
    HintLevel level, {
    int variant = 0,
  }) {
    final tokens = <TextToken>[
      for (var s = 0; s < segments.length; s++)
        ...MemorizationNormalizer.tokenize(segments[s], segment: s),
    ];

    final words = tokens.where((t) => t.isWord).toList();

    final hidden = level.hasGaps
        ? _chooseGaps(words, level, _seed(segments, variant))
        : <int>[];

    return HintPrompt(
      level: level,
      display: _display(tokens, level, hidden.toSet()),
      words: words,
      hidden: hidden,
    );
  }

  String _display(List<TextToken> tokens, HintLevel level, Set<int> hidden) {
    if (level == HintLevel.free) {
      return "";
    }

    final buffer = StringBuffer();

    var wordIndex = 0;
    var segmentStart = true;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final lastOfSegment =
          i == tokens.length - 1 || tokens[i + 1].segment != token.segment;

      if (level == HintLevel.minimal) {
        // Nur der Einstieg in jeden Abschnitt.
        if (segmentStart && token.isWord) {
          buffer.write("${token.prefix}${token.core} …");
          segmentStart = false;
        }

        if (lastOfSegment) {
          if (i < tokens.length - 1) buffer.write("\n");
          segmentStart = true;
        }

        continue;
      }

      buffer.write(_render(token, level, hidden.contains(wordIndex)));

      if (token.isWord) wordIndex++;

      if (i < tokens.length - 1) {
        buffer.write(token.breakAfter || lastOfSegment ? "\n" : " ");
      }
    }

    return buffer.toString();
  }

  String _render(TextToken token, HintLevel level, bool hidden) {
    if (!token.isWord) {
      return token.raw;
    }

    if (level == HintLevel.firstLetters) {
      final first = String.fromCharCode(token.core.runes.first);
      return "${token.prefix}$first${token.suffix}";
    }

    if (hidden) {
      return "${token.prefix}$gap${token.suffix}";
    }

    return token.raw;
  }

  /// Wenige Lücken sind immer eine Teilmenge der vielen; längere Wörter
  /// (meist die inhaltstragenden) werden bevorzugt ausgeblendet.
  List<int> _chooseGaps(List<TextToken> words, HintLevel level, int seed) {
    final n = words.length;

    if (n == 0) return [];

    final random = math.Random(seed);

    final long = [
      for (var i = 0; i < n; i++)
        if (words[i].norm.length >= 4) i,
    ]..shuffle(random);

    final short = [
      for (var i = 0; i < n; i++)
        if (words[i].norm.length < 4) i,
    ]..shuffle(random);

    // Meist ein langes Wort, gelegentlich ein kurzes – so wechseln die
    // Lücken von Versuch zu Versuch, auch wenn fast alle Wörter lang sind.
    final order = <int>[];

    while (long.isNotEmpty || short.isNotEmpty) {
      final preferLong = random.nextDouble() < 0.75;

      final pool = short.isEmpty || (preferLong && long.isNotEmpty)
          ? long
          : short;

      order.add(pool.removeLast());
    }

    final few = math.max(1, (n * 0.25).round());
    final many = math.min(n, math.max(few + 1, (n * 0.6).round()));

    final count = level == HintLevel.fewGaps ? few : many;

    return order.take(count).toList()..sort();
  }

  // Eigener Hash: String.hashCode ist nicht über Läufe hinweg stabil.
  static int _seed(List<String> segments, int variant) {
    var hash = 17 + variant;

    for (final segment in segments) {
      for (final unit in segment.codeUnits) {
        hash = (hash * 31 + unit) & 0x3fffffff;
      }
    }

    return hash;
  }
}
