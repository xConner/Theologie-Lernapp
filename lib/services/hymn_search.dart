import '../models/hymn.dart';

/// Ein Suchtreffer mit Rang und – bei Treffern im Liedtext – der Stelle.
class HymnSearchHit {
  final Hymn hymn;
  final int score;

  /// Fundstelle, z. B. „Str. 3: und ist ein Licht in seiner Hand“; `null`,
  /// wenn Titel, Nummer oder Angaben getroffen haben.
  final String? snippet;

  const HymnSearchHit(this.hymn, this.score, [this.snippet]);
}

/// Suche über Lieder beliebiger Sammlungen.
///
/// Gesucht wird in Nummer, Titel, Liedanfang, Liedtext, Text- und
/// Melodieangabe, Schlagworten und Bibelstellen – ohne Rücksicht auf Groß-
/// und Kleinschreibung, Umlaute (ä = a = ae) und Satzzeichen. Mehrere Wörter
/// müssen alle vorkommen, gleich in welchem Feld. Jede Fassung eines Liedes
/// bleibt ein eigener Treffer.
class HymnSearchIndex {
  final List<_Entry> _entries;

  /// Rang einer Sammlung bei gleichwertigen Treffern (kleiner zuerst).
  final Map<String, int> order;

  HymnSearchIndex(List<Hymn> hymns, {this.order = const {}})
    : _entries = [for (final hymn in hymns) _Entry(hymn)];

  // Nummer mit optionalem Vorsatz: „23“, „EG 23“, „EG.E 10“, „786.5“.
  static final RegExp _numberQuery = RegExp(
    r"^(?:([a-z]+(?:\.[a-z]+)?)\s*)?(\d+(?:[.,]\d+)?)$",
  );

  /// Treffer, bestbewertete zuerst; ein leerer Suchbegriff ergibt keine.
  /// [where] grenzt die Suche auf bestimmte Lieder ein (z. B. eine Sammlung).
  List<HymnSearchHit> search(String query, {bool Function(Hymn)? where}) {
    final raw = query.trim().toLowerCase();
    final folded = fold(raw);
    if (folded.isEmpty) return const [];

    final tokens = folded.split(' ');
    final numberMatch = _numberQuery.firstMatch(raw.replaceAll(',', '.'));
    final prefix = numberMatch?.group(1);
    final number = numberMatch?.group(2);

    final hits = <HymnSearchHit>[];

    for (final entry in _entries) {
      if (where != null && !where(entry.hymn)) continue;

      final hit = number != null
          ? entry.matchNumber(prefix, number) ?? entry.matchText(folded, tokens)
          : entry.matchText(folded, tokens);

      if (hit != null) hits.add(hit);
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byCollection = (order[a.hymn.collectionId] ?? 1 << 20).compareTo(
        order[b.hymn.collectionId] ?? 1 << 20,
      );
      if (byCollection != 0) return byCollection;
      return compareNumbers(a.hymn.number, b.hymn.number);
    });

    return hits;
  }

  /// Ordnet „2“ vor „10“ und „786“ vor „786.5“.
  static int compareNumbers(String a, String b) {
    final x = double.tryParse(a);
    final y = double.tryParse(b);
    if (x != null && y != null) return x.compareTo(y);
    if (x != null) return -1;
    if (y != null) return 1;
    return a.compareTo(b);
  }

  static const Map<String, String> _letters = {
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ô': 'o',
    'ú': 'u',
    'û': 'u',
    'ç': 'c',
    'ñ': 'n',
    'å': 'a',
    'ø': 'o',
    'æ': 'ae',
    'œ': 'oe',
  };

  static final RegExp _separators = RegExp(r"[^a-z0-9]+");

  /// Vergleichsform: klein, ohne Umlaute und Satzzeichen. „ae“, „oe“, „ue“
  /// werden wie „a“, „o“, „u“ behandelt, damit „fuer“ „für“ findet.
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      buffer.write(_letters[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(_separators, ' ')
        .replaceAllMapped(RegExp(r"([aou])e"), (m) => m.group(1)!)
        .trim();
  }
}

class _Entry {
  final Hymn hymn;
  final String title;
  final String firstLine;
  final String credits;
  final String metadata;
  final List<(String, String, String)> lines;

  _Entry(this.hymn)
    : title = HymnSearchIndex.fold(hymn.title),
      firstLine = HymnSearchIndex.fold(hymn.firstLine),
      credits = HymnSearchIndex.fold('${hymn.author} ${hymn.melody}'),
      metadata = HymnSearchIndex.fold(
        '${hymn.tags.join(' ')} ${hymn.bibleReferences.join(' ')}',
      ),
      lines = [
        for (final verse in hymn.lyrics)
          for (final line in verse.text.split('\n'))
            if (line.trim().isNotEmpty)
              (
                verse.stanza.toString(),
                line.trim(),
                HymnSearchIndex.fold(line),
              ),
      ];

  /// Alle Felder zusammen, für Suchen mit mehreren Wörtern.
  late final String all = [
    title,
    firstLine,
    credits,
    metadata,
    HymnSearchIndex.fold(hymn.displayNumber),
    for (final line in lines) line.$3,
  ].join(' ');

  HymnSearchHit? matchNumber(String? prefix, String number) {
    if (prefix != null &&
        HymnSearchIndex.fold(hymn.numberPrefix) !=
            HymnSearchIndex.fold(prefix)) {
      return null;
    }
    if (hymn.number == number) return HymnSearchHit(hymn, 1000);
    if (hymn.number.startsWith(number)) return HymnSearchHit(hymn, 300);
    if (hymn.number.contains(number)) return HymnSearchHit(hymn, 200);
    return null;
  }

  HymnSearchHit? matchText(String phrase, List<String> tokens) {
    if (title == phrase) return HymnSearchHit(hymn, 900);
    if (title.startsWith(phrase)) return HymnSearchHit(hymn, 800);
    if (title.contains(phrase)) return HymnSearchHit(hymn, 700);
    if (firstLine.contains(phrase)) return HymnSearchHit(hymn, 600);
    if (credits.contains(phrase)) return HymnSearchHit(hymn, 500);
    if (metadata.contains(phrase)) return HymnSearchHit(hymn, 400);

    for (final (stanza, line, folded) in lines) {
      if (folded.contains(phrase)) {
        return HymnSearchHit(hymn, 300, _snippet(stanza, line));
      }
    }

    if (tokens.length > 1 && tokens.every(all.contains)) {
      // Fundstelle: die Zeile mit den meisten Suchwörtern.
      String? snippet;
      var best = 0;
      for (final (stanza, line, folded) in lines) {
        final count = tokens.where(folded.contains).length;
        if (count > best) {
          best = count;
          snippet = _snippet(stanza, line);
        }
      }
      return HymnSearchHit(hymn, 100, snippet);
    }

    return null;
  }

  static String _snippet(String stanza, String line) =>
      stanza == 'Ref' ? 'Refrain: $line' : 'Str. $stanza: $line';
}
