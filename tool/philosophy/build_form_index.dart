// Erzeugt den Formenindex des Lesebereichs „Aristoteles – Physik“:
// assets/philosophy/aristotle_physics/forms.json.
//
//   dart run tool/philosophy/build_form_index.dart [private-ausgabe.json …]
//
// Quelle der Bestimmungen sind ausschließlich die vorhandenen Korpora des
// Klausurerstellers (assets/greek_corpus/nt und lxx: MorphGNT, CC BY-SA 3.0,
// und die formale LXX-Bestimmung aus Wiktionary-Tabellen, CC BY-SA 4.0). Eine
// Wortform der Physik erhält alle Bestimmungen, die dieselbe Form dort hat –
// ohne Prüfung im Kontext der Physik. Die App zeigt sie deshalb immer als
// „mögliche Bestimmungen“, nie als gesicherte.
//
// Wortformen werden aus dem freien Text (assets/philosophy/…/ross) und aus
// den als Argument übergebenen privaten Ausgaben gesammelt; gespeichert
// werden nur die Formen mit ihren Bestimmungen, kein Text.
import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/greek/exam/corpus_token.dart';
import 'package:theologie_lernapp/services/greek/exam/corpus_codec.dart';
import 'package:theologie_lernapp/services/greek/exam/greek_form_key.dart';

const String corpusRoot = 'assets/greek_corpus';
const String workRoot = 'assets/philosophy/aristotle_physics';

void main(List<String> args) {
  final forms = <String, Set<LemmaAnalysis>>{};

  for (final corpus in ['nt', 'lxx']) {
    final dir = Directory('$corpusRoot/$corpus');
    final index =
        jsonDecode(File('${dir.path}/index.json').readAsStringSync())
            as Map<String, dynamic>;
    final lemmas = List<String>.from(index['lemmas'] as List);

    for (final file in dir.listSync().whereType<File>()) {
      if (file.path.endsWith('index.json')) continue;
      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final book = CorpusBook.fromJson(json, lemmas);

      for (final chapter in book.chapters) {
        for (final verse in chapter) {
          for (final token in verse.tokens) {
            if (!token.isAnalyzed ||
                token.reliability == AnalysisReliability.properNameGuess) {
              continue;
            }
            forms
                .putIfAbsent(greekFormKey(token.word), () => {})
                .addAll(token.analyses);
          }
        }
      }
    }
  }

  // Wortformen der Physik.
  final keys = <String>{};
  var words = 0;

  void collect(Map<String, dynamic> book) {
    for (final chapter in book['chapters'] as List) {
      for (final unit in (chapter as Map)['units'] as List) {
        for (final sentence in (unit as Map)['g'] as List) {
          for (final word in splitGreekWords((sentence as Map)['t'] as String)) {
            final key = greekFormKey(word);
            if (key.isEmpty) continue;
            keys.add(key);
            words++;
          }
        }
      }
    }
  }

  for (final file in Directory('$workRoot/ross').listSync().whereType<File>()) {
    collect(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  for (final path in args) {
    final edition = jsonDecode(File(path).readAsStringSync()) as Map;
    for (final book in edition['books'] as List) {
      collect(book as Map<String, dynamic>);
    }
  }

  final lemmaIds = <String, int>{};
  final codeIds = <String, int>{};
  final out = <String, String>{};
  var analyzedWords = 0;

  for (final key in (keys.toList()..sort())) {
    final analyses = forms[key];
    if (analyses == null || analyses.isEmpty) continue;

    final pairs = [
      for (final a in analyses)
        (
          lemmaIds.putIfAbsent(a.lemma, () => lemmaIds.length),
          codeIds.putIfAbsent(a.analysis.code, () => codeIds.length),
        ),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);

    out[key] = CorpusCodec.encodeSet(AnalysisReliability.formal, pairs);
  }

  analyzedWords = keys.where(out.containsKey).length;

  final result = {
    'version': 1,
    'source':
        'Bestimmungen aus den Korpora des Klausurerstellers: MorphGNT SBLGNT '
        '(CC BY-SA 3.0) und formale Septuaginta-Bestimmung nach '
        'Wiktionary-Flexionstabellen (CC BY-SA 4.0). Ohne Prüfung im Kontext '
        'der Physik.',
    'lemmas': lemmaIds.keys.toList(),
    'codes': codeIds.keys.toList(),
    'forms': out,
  };

  File('$workRoot/forms.json').writeAsStringSync(jsonEncode(result));

  stdout.writeln(
    'Formen: ${keys.length}, davon bestimmt: $analyzedWords '
    '(${(100 * analyzedWords / keys.length).toStringAsFixed(1)} %); '
    'Wörter: $words; Grundformen: ${lemmaIds.length}',
  );
}
