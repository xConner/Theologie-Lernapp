import '../../utils/greek_normalization.dart';

/// Ein Wort eines Lerntextes mit seiner Vergleichsform.
class TextToken {
  /// Wie im Text, einschließlich anhängender Satzzeichen.
  final String raw;

  /// Vergleichsform (siehe [MemorizationNormalizer.word]); leer bei reinen
  /// Satzzeichen wie „–“.
  final String norm;

  /// Folgt im Text ein Zeilenumbruch?
  final bool breakAfter;

  /// Index des Abschnitts, aus dem das Wort stammt (bei verbundenen
  /// Abschnitten).
  final int segment;

  const TextToken({
    required this.raw,
    required this.norm,
    this.breakAfter = false,
    this.segment = 0,
  });

  bool get isWord => norm.isNotEmpty;

  /// Satzzeichen vor dem Wort, z. B. „(“.
  String get prefix => raw.substring(0, _coreStart);

  /// Das Wort ohne umgebende Satzzeichen.
  String get core => raw.substring(_coreStart, _coreEnd);

  /// Satzzeichen nach dem Wort, z. B. „,“.
  String get suffix => raw.substring(_coreEnd);

  int get _coreStart {
    final match = MemorizationNormalizer.letter.firstMatch(raw);
    return match?.start ?? raw.length;
  }

  int get _coreEnd {
    final matches = MemorizationNormalizer.letter.allMatches(raw);
    return matches.isEmpty ? raw.length : matches.last.end;
  }
}

/// Normalisierung für den Wortvergleich beim Auswendiglernen.
///
/// Ignoriert werden Groß-/Kleinschreibung, Satzzeichen, Leerraum sowie
/// Akzente; ä/ö/ü/ß gelten wie ae/oe/ue/ss (alte und neue Rechtschreibung,
/// Tastaturen ohne Umlaute). Griechisch wird ohne Akzente und Spiritus
/// verglichen. Der Wortlaut selbst wird nicht angetastet – Synonyme sind
/// Abweichungen.
class MemorizationNormalizer {
  MemorizationNormalizer._();

  static final RegExp letter = RegExp(r"[\p{L}\p{N}]", unicode: true);
  static final RegExp _nonLetter = RegExp(r"[^\p{L}\p{N}]", unicode: true);
  static final RegExp _whitespace = RegExp(r"\s+");

  static const Map<String, String> _latin = {
    "ä": "ae",
    "ö": "oe",
    "ü": "ue",
    "ß": "ss",
    "æ": "ae",
    "œ": "oe",
    "à": "a",
    "á": "a",
    "â": "a",
    "ā": "a",
    "è": "e",
    "é": "e",
    "ê": "e",
    "ë": "e",
    "ē": "e",
    "ì": "i",
    "í": "i",
    "î": "i",
    "ï": "i",
    "ī": "i",
    "ò": "o",
    "ó": "o",
    "ô": "o",
    "ō": "o",
    "ù": "u",
    "ú": "u",
    "û": "u",
    "ū": "u",
    "ç": "c",
  };

  static String word(String raw) {
    final lower = normalizeGreekForComparison(raw.toLowerCase());

    final buffer = StringBuffer();

    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_latin[char] ?? char);
    }

    return buffer.toString().replaceAll(_nonLetter, "");
  }

  /// Zerlegt [text] an Leerraum; Zeilenumbrüche bleiben als
  /// [TextToken.breakAfter] erhalten.
  static List<TextToken> tokenize(String text, {int segment = 0}) {
    final tokens = <TextToken>[];

    final lines = text
        .split("\n")
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var l = 0; l < lines.length; l++) {
      final words = lines[l].split(_whitespace);

      for (var w = 0; w < words.length; w++) {
        tokens.add(
          TextToken(
            raw: words[w],
            norm: word(words[w]),
            breakAfter: w == words.length - 1 && l < lines.length - 1,
            segment: segment,
          ),
        );
      }
    }

    return tokens;
  }

  static int wordCount(String text) {
    return tokenize(text).where((t) => t.isWord).length;
  }
}
