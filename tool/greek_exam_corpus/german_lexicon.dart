// Deutsche Bedeutungen der Grundformen für die Vokabelhilfen des
// Klausurerstellers (assets/greek_corpus/lexicon.json). Quellen in dieser
// Reihenfolge:
//
//   1. german_glosses.json – redaktionelle Angaben (Korrekturen und
//      Ergänzungen, v. a. Bedeutungen des biblischen Griechisch);
//   2. deutsches Wiktionary – die dort eingetragenen Übersetzungen, sonst
//      die Bedeutungsangaben;
//   3. Pape, Griechisch-deutsches Handwörterbuch (1914) – die
//      hervorgehobenen Übersetzungen am Anfang des Artikels.
//
// Englische Angaben werden nicht übernommen. Eine Grundform ohne deutsche
// Quelle bleibt ohne Eintrag und gilt in der App als ungelöst.
import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/services/greek/exam/gloss_shortener.dart';
import 'package:theologie_lernapp/services/greek/exam/greek_form_key.dart';
import 'package:theologie_lernapp/utils/greek_normalization.dart';

const String outputFile = 'assets/greek_corpus/lexicon.json';
const String editorialFile = 'tool/greek_exam_corpus/german_glosses.json';

class GermanGloss {
  final List<String> glosses;

  /// "e" redaktionell, "w" Wiktionary, "p" Pape (`LexiconEntry.sourceCodes`).
  final String source;

  const GermanGloss(this.glosses, this.source);
}

class GermanLexicon {
  final Map<String, List<String>> editorial = {};
  final Map<String, List<String>> wiktionary = {};
  final Map<String, List<String>> pape = {};

  /// Grundformen mit mehreren Pape-Artikeln (Homonyme).
  final Set<String> papeHomonyms = {};

  static GermanLexicon load(Map<String, dynamic> sources) {
    final cache = sources['cacheDir'] as String;
    final lexicon = GermanLexicon();

    final editorialSource = File(editorialFile);
    if (editorialSource.existsSync()) {
      final entries =
          (jsonDecode(editorialSource.readAsStringSync()) as Map)['entries']
              as Map;

      for (final MapEntry(:key, :value) in entries.entries) {
        lexicon.editorial[greekFormKey(key as String)] = List<String>.from(
          value as List,
        );
      }
    }

    final german = File(
      '$cache/${(sources['wiktionaryGerman'] as Map)['file']}',
    );
    for (final line in german.readAsLinesSync()) {
      if (line.isEmpty) continue;
      lexicon._readWiktionary(jsonDecode(line) as Map<String, dynamic>);
    }

    final papeCache = File('$cache/${(sources['pape'] as Map)['file']}');
    if (papeCache.existsSync()) {
      for (final line in papeCache.readAsLinesSync()) {
        if (!line.trim().endsWith('}')) continue;

        final entry = jsonDecode(line) as Map<String, dynamic>;
        final articles = List<String>.from(entry['pape'] as List);
        final key = greekFormKey(entry['lemma'] as String);

        if (articles.length > 1) lexicon.papeHomonyms.add(key);

        // Bei Homonymen die Grundbedeutung jedes Artikels, damit keine
        // Bedeutung dem falschen Wort zugeschrieben wird.
        final glosses = articles.length == 1
            ? papeGlosses(articles.single)
            : [
                for (final article in articles) ...papeGlosses(article).take(1),
              ];

        if (glosses.isNotEmpty) lexicon.pape[key] = glosses;
      }
    }

    return lexicon;
  }

  void _readWiktionary(Map<String, dynamic> entry) {
    final word = entry['word'] as String?;
    if (word == null || entry['pos'] == 'character') return;

    // Flektierte Formen haben eigene Einträge ohne eigene Bedeutung.
    final senses = (entry['senses'] as List?) ?? const [];
    final isForm = senses.isNotEmpty &&
        senses.every((s) => (s as Map).containsKey('form_of'));
    if (isForm) return;

    final translations = [
      for (final t in (entry['translations'] as List?) ?? const [])
        if ((t as Map)['lang_code'] == 'de' && t['word'] is String)
          (t['word'] as String).trim(),
    ];

    final glosses = translations.isNotEmpty
        ? translations
        : [
            for (final s in senses)
              for (final g in ((s as Map)['glosses'] as List?) ?? const [])
                (g as String).trim(),
          ];

    final key = greekFormKey(
      composeGreek(normalizeGreekForDisplay(word)).replaceAll(RegExp('[̄̆]'), ''),
    );

    if (glosses.isNotEmpty) wiktionary.putIfAbsent(key, () => []).addAll(glosses);
  }

  /// Die Vokabelhilfe zur Grundform; `null` = ungelöst.
  GermanGloss? operator [](String lemma) {
    final key = greekFormKey(lemma);

    for (final (source, code) in [
      (editorial, 'e'),
      (wiktionary, 'w'),
      (pape, 'p'),
    ]) {
      // Redaktionelle Angaben sind bereits Vokabelhilfen und gelten wörtlich.
      final glosses = code == 'e'
          ? (source[key] ?? const <String>[]).take(maxGlossesPerHint).toList()
          : shortGlosses(source[key] ?? const []);
      if (glosses.isNotEmpty) return GermanGloss(glosses, code);
    }

    return null;
  }
}

// -----------------------------------------------------------------------------
// PAPE
// -----------------------------------------------------------------------------

final RegExp _italic = RegExp(r'<i>(.*?)</i>', dotAll: true);
final RegExp _tag = RegExp(r'<[^>]*>');

/// Rechtschreibung von 1914 → heutige Schreibung, soweit eindeutig.
const Map<String, String> _spelling = {
  'Theil': 'Teil', 'theil': 'teil', 'Thier': 'Tier', 'thier': 'tier',
  'Thür': 'Tür', 'Thor': 'Tor', 'Thal': 'Tal', 'That': 'Tat',
  'thät': 'tät', 'thun': 'tun', 'Thun': 'Tun', 'thum': 'tum',
  'Muth': 'Mut', 'muth': 'mut', 'Rath': 'Rat', 'rath': 'rat',
  'Noth': 'Not', 'noth': 'not', 'Werth': 'Wert', 'werth': 'wert',
  'roth': 'rot', 'Wirth': 'Wirt', 'Thau': 'Tau', 'Thon': 'Ton',
  'Thräne': 'Träne', 'Athem': 'Atem', 'athm': 'atm', 'niß': 'nis',
  'giebt': 'gibt', 'Hülfe': 'Hilfe', 'hülf': 'hilf', 'Waare': 'Ware',
  'Heerde': 'Herde', 'todt': 'tot', 'Todt': 'Tot', 'tödt': 'töt',
  'Loos': 'Los', 'Maaß': 'Maß', 'Schooß': 'Schoß', 'Erndte': 'Ernte',
  'ächt': 'echt', 'daß': 'dass', 'Uebe': 'Übe', 'Aeltest': 'Ältest', 'Ae': 'Ä', 'Oe': 'Ö', 'Ue': 'Ü',
};

final RegExp _iren = RegExp(r'([a-zäöü]{3,})iren\b');

String modernizeGerman(String text) {
  var result = text;
  for (final MapEntry(:key, :value) in _spelling.entries) {
    result = result.replaceAll(key, value);
  }
  return result.replaceAllMapped(_iren, (m) => '${m[1]}ieren');
}

/// Ob ein kursiver Abschnitt ein Werktitel ist (Belegstelle: „<i>Il</i>.
/// 2.210“, „Soph. <i>O.R</i>. 913“, „Lobeck <i>zu Phryn</i>. p. 732“) oder
/// ein lateinisches Vergleichswort – und keine Übersetzung.
bool _isCitation(String text, String before, String following) {
  if (RegExp(r'^\.?\s*(\d|[IVXL]+\b|p\.|§)').hasMatch(following)) return true;
  if (text.contains('.')) return true;
  // Autor davor: „Xen. “, „Plut. “ oder ein ausgeschriebener Name.
  if (RegExp(r'([A-Z][a-zäöü]{1,7}\.|</font>)\s*$').hasMatch(before)) {
    return true;
  }
  if (RegExp(r'(lat\.|Latein\.|vgl\.|s\.)\s*$').hasMatch(before)) return true;
  // Abgekürzter Titel: kurzes Wort mit folgendem Punkt (Od., Tox., Eccl.).
  return following.startsWith('.') && text.length <= 6 && !text.contains(' ');
}

final RegExp _greek = RegExp(r'[Ͱ-Ͽἀ-῿]');
final RegExp _parenthesis = RegExp(r'\([^()]*\)');

/// Kursive Angaben, die keine Übersetzung sind.
final RegExp _notAGloss = RegExp(
  r'^(LXX|NT|N\.T|K\.S|VLL|Sp|i\.e|u\.s\.w|etc)\b|'
  r'^(adv|med|pass|act|intr|trans|impf|aor|perf|fut|praes|sc|dor|ion|ep|'
  r'att|poet|plur|sing|masc|fem|neutr|comp|compar|superl|gen|dat|acc|bes|'
  r'od|u|c|absol|impers|partic|inf|conj|opt|imper)$',
);

/// Lateinische Entsprechungen, die Pape neben die Übersetzung setzt
/// („Unterkleid, Rock, tunica“; „Lamm, agnus“): kleingeschriebene Wörter
/// mit lateinischer Endung.
final RegExp _latin = RegExp(
  r'^[a-z]{2,}(us|um|is|ae|ix|ex|ica|ula|ura|ia|or|sto|res)( [a-z]+)?$',
);

const Set<String> _germanLookalikes = {
  'bis', 'aus', 'haus', 'voraus', 'hinaus', 'heraus', 'daraus', 'vor',
  'hervor', 'empor', 'zuvor', 'bevor', 'darum', 'herum', 'warum',
  'wiederum', 'ringsum', 'gewiss', 'anders', 'besonders',
};

/// Die Angabe ohne lateinische Vergleichswörter, Siglen und Teile mit
/// Ziffern („ein Verein von 16–60 Bürgern“).
String _withoutLatin(String gloss) {
  final parts = gloss
      .split(',')
      .map((part) => part.trim())
      .where(
        (part) =>
            part.isNotEmpty &&
            !RegExp(r'\d').hasMatch(part) &&
            !_notAGloss.hasMatch(part) &&
            (_germanLookalikes.contains(part) || !_latin.hasMatch(part)),
      )
      .toList();

  // „mit, zugleich, zusammen endigen“ zählt Vorsilben desselben Verbs auf
  // (mit-, zugleich-, zusammenendigen): nur die vollständige Angabe bleibt.
  while (parts.length > 1 && _prefixes.contains(parts.first)) {
    parts.removeAt(0);
  }

  return parts.join(', ');
}

/// Vorsilben und Adverbien, die Pape einer Übersetzung aufzählend voranstellt.
const Set<String> _prefixes = {
  'ab', 'an', 'auf', 'aus', 'bei', 'dabei', 'dadurch', 'dagegen', 'daneben',
  'daran', 'darauf', 'darin', 'darüber', 'darunter', 'davon', 'davor', 'dazu',
  'durch', 'ein', 'empor', 'entgegen', 'fort', 'heran', 'herab', 'herauf',
  'heraus', 'herbei', 'herein', 'herum', 'herunter', 'hervor', 'hin', 'hinab',
  'hinan', 'hinauf', 'hinaus', 'hindurch', 'hinein', 'hinüber', 'hinunter',
  'hinzu', 'los', 'mit', 'nach', 'nieder', 'über', 'um', 'unter', 'vor',
  'voran', 'voraus', 'vorbei', 'vorher', 'weg', 'weiter', 'wieder', 'zu',
  'zugleich', 'zurück', 'zusammen',
};

/// Höchstabstand zweier Übersetzungen im Artikelkopf; was später kursiv
/// steht, übersetzt ein Beispiel oder eine Sonderbedeutung.
const int _headDistance = 80;

/// Die Übersetzungen am Anfang eines Pape-Artikels. Pape setzt deutsche
/// Übersetzungen kursiv; ausgewertet werden die ersten kursiven Abschnitte
/// (die Grundbedeutung und ihre nächsten Synonyme), ohne Werktitel der
/// Belegstellen, ohne etymologische Klammern und ohne die Übersetzungen
/// der Beispiele.
List<String> papeGlosses(String article) {
  final glosses = <String>[];

  // Klammern enthalten Etymologie und Vergleichswörter (heil, vgl. salvus).
  var text = article;
  for (var i = 0; i < 3 && _parenthesis.hasMatch(text); i++) {
    text = text.replaceAll(_parenthesis, ' ');
  }

  var lastEnd = -1;

  for (final match in _italic.allMatches(text)) {
    if (glosses.length >= 3) break;
    if (lastEnd >= 0 && match.start - lastEnd > _headDistance) break;

    final gloss = match[1]!.replaceAll(_tag, '').trim();
    final before = text
        .substring((match.start - 24).clamp(0, text.length), match.start)
        .replaceAll(RegExp(r'<(?!/font)[^>]*>'), '');
    final following = text
        .substring(match.end, (match.end + 12).clamp(0, text.length))
        .replaceAll(_tag, '');

    if (gloss.isEmpty || _greek.hasMatch(gloss)) continue;
    if (_notAGloss.hasMatch(gloss)) continue;
    if (_isCitation(gloss, before, following)) continue;

    final german = _withoutLatin(gloss);
    if (german.isEmpty) continue;

    glosses.add(modernizeGerman(german));
    lastEnd = match.end;
  }

  return glosses;
}

// -----------------------------------------------------------------------------
// AUSGABE
// -----------------------------------------------------------------------------

/// Schreibt das Lexikon: deutsche Vokabelhilfe und Deklinationsklasse je
/// Grundform. Ergebnis: Zahl der Grundformen je Quelle und die ungelösten.
({Map<String, int> bySource, List<String> unresolved}) writeGermanLexicon({
  required Iterable<String> lemmas,
  required GermanLexicon german,
  required int? Function(String lemma) declensionOf,
}) {
  final entries = <String, dynamic>{};
  final bySource = <String, int>{};
  final unresolved = <String>[];

  for (final lemma in lemmas.toList()..sort()) {
    final gloss = german[lemma];
    final decl = declensionOf(lemma);

    if (gloss == null) {
      unresolved.add(lemma);
    } else {
      bySource[gloss.source] = (bySource[gloss.source] ?? 0) + 1;
    }

    if (gloss == null && decl == null) continue;

    entries[lemma] = {
      if (gloss != null) 'de': gloss.glosses,
      if (gloss != null) 'src': gloss.source,
      'decl': ?decl,
    };
  }

  File(outputFile).writeAsStringSync(
    jsonEncode({'version': 2, 'entries': entries}),
  );

  return (bySource: bySource, unresolved: unresolved);
}
