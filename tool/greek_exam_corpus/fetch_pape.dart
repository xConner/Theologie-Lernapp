// Lädt zu den Grundformen der Klausurkorpora die Einträge aus Pape,
// Griechisch-deutsches Handwörterbuch (3. Aufl. 1914), über die
// Schnittstelle des Classical Language Dictionary der BBAW (siehe
// sources.json, docs/greek-exam-sources.md).
//
//   dart run tool/greek_exam_corpus/fetch_pape.dart
//
// Einmaliger Import mit Zwischenspeicher: jede Grundform wird genau einmal
// abgefragt, nacheinander und mit Pause (Vorgabe des Dienstes); ein
// abgebrochener Lauf setzt beim nächsten Start fort. Die App selbst fragt den
// Dienst nie ab.
import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/services/greek/exam/greek_form_key.dart';

const Duration pause = Duration(milliseconds: 150);

Future<void> main(List<String> args) async {
  final sources =
      jsonDecode(File('tool/greek_exam_corpus/sources.json').readAsStringSync())
          as Map<String, dynamic>;
  final pape = sources['pape'] as Map<String, dynamic>;
  final cache = File('${sources['cacheDir']}/${pape['file']}')
    ..createSync(recursive: true);

  // Eine beim Abbruch nur halb geschriebene letzte Zeile wird verworfen.
  final complete = [
    for (final line in cache.readAsLinesSync())
      if (line.trim().endsWith('}')) line,
  ];
  cache.writeAsStringSync(complete.map((l) => '$l\n').join());

  final done = <String>{
    for (final line in complete) (jsonDecode(line) as Map)['lemma'] as String,
  };

  // Häufige Grundformen zuerst (Zahl der Verse mit der Grundform), damit ein
  // unterbrochener Lauf schon die wichtigsten Wörter enthält.
  final frequency = <String, int>{};

  for (final corpus in ['nt', 'lxx']) {
    final index =
        jsonDecode(
              File('assets/greek_corpus/$corpus/index.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final names = List<String>.from(index['lemmas'] as List);

    for (final name in names) {
      frequency.putIfAbsent(name, () => 0);
    }

    for (final book in index['books'] as List) {
      for (final chapter in (book as Map)['chapters'] as List) {
        for (final verse in chapter as List) {
          for (final group in ((verse as List)[6] as String).split('|')) {
            for (final id in group.split('.')) {
              if (id.isEmpty) continue;
              final lemma = names[int.parse(id, radix: 36)];
              frequency[lemma] = frequency[lemma]! + 1;
            }
          }
        }
      }
    }
  }

  final lemmas =
      frequency.keys
          .where((l) => !startsUpperCase(l) && !done.contains(l))
          .toList()
        ..sort((a, b) {
          final byCount = frequency[b]!.compareTo(frequency[a]!);
          return byCount != 0 ? byCount : a.compareTo(b);
        });

  stdout.writeln('${done.length} im Zwischenspeicher, ${lemmas.length} offen.');

  final client = HttpClient()..userAgent = 'Theologie-Lernapp Import (einmalig)';
  final sink = cache.openWrite(mode: FileMode.append);
  var found = 0;

  try {
    for (final (i, lemma) in lemmas.indexed) {
      String? query;
      List<String> entries = const [];

      // Koine-Schreibung zuerst, dann die attische des Wörterbuchs.
      for (final variant in {lemma, ...atticSpellings(lemma)}) {
        entries = await _fetch(client, pape['url'] as String, variant);
        await Future<void>.delayed(pause);

        if (entries.isNotEmpty) {
          query = variant;
          break;
        }
      }

      if (entries.isNotEmpty) found++;

      sink.writeln(
        jsonEncode({'lemma': lemma, 'query': query, 'pape': entries}),
      );

      if ((i + 1) % 100 == 0) {
        await sink.flush();
        stdout.writeln('${i + 1}/${lemmas.length} ($found mit Eintrag)');
      }
    }
  } finally {
    await sink.close();
    client.close();
  }

  stdout.writeln('Fertig: $found von ${lemmas.length} mit Eintrag.');
}

bool startsUpperCase(String lemma) =>
    RegExp(r'^\p{Lu}', unicode: true).hasMatch(lemma);

/// Attische Schreibungen einer Koine-Grundform (γίνομαι → γίγνομαι,
/// θάλασσα → θάλαττα).
Set<String> atticSpellings(String lemma) => {
  lemma.replaceAll('γιν', 'γιγν').replaceAll('γίν', 'γίγν'),
  lemma.replaceAll('σσ', 'ττ'),
}..remove(lemma);

/// Die Pape-Einträge zur Grundform (mehrere bei Homonymen).
Future<List<String>> _fetch(HttpClient client, String url, String lemma) async {
  final uri = Uri.parse(url.replaceAll('{lemma}', Uri.encodeComponent(lemma)));

  for (var attempt = 0; ; attempt++) {
    final HttpClientResponse response;
    final String body;

    try {
      final request = await client.getUrl(uri);
      response = await request.close();
      body = await response.transform(utf8.decoder).join();
    } on IOException {
      // Verbindungsfehler: warten und erneut versuchen.
      if (attempt >= 5) rethrow;
      await Future<void>.delayed(Duration(seconds: 20 * (attempt + 1)));
      continue;
    }

    if (response.statusCode == 429 || response.statusCode >= 500) {
      if (attempt >= 5) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      await Future<void>.delayed(Duration(seconds: 20 * (attempt + 1)));
      continue;
    }

    if (response.statusCode != 200) return const [];

    final data = (jsonDecode(body) as Map)['data'];
    if (data is! List) return const [];

    return [
      for (final entry in data)
        // Nur exakt diese Grundform (Akzente und Spiritus eingeschlossen).
        if (entry is Map && greekFormKey('${entry['lemma']}') == greekFormKey(lemma))
          for (final d in (entry['descriptions'] as List?) ?? const [])
            if (d is Map && d['dictionary'] == 'Pape' && d['description'] is String)
              d['description'] as String,
    ];
  }
}
