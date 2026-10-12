// Erzeugt nur assets/greek_corpus/lexicon.json neu (deutsche Vokabelhilfen),
// ohne die Korpora neu zu bestimmen – nach Änderungen an
// german_glosses.json, an der Kürzung oder nach fetch_pape.dart.
//
//   dart run tool/greek_exam_corpus/build_lexicon.dart
//   dart run tool/greek_exam_corpus/build_lexicon.dart --report   # Übersicht
//
// Grundformen und Deklinationsklassen stammen aus den vorhandenen Assets
// (Index bzw. bisheriges Lexikon); build_corpus.dart erzeugt beides neu.
import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/services/greek/exam/vocabulary_help.dart';

import 'german_lexicon.dart';

void main(List<String> args) {
  final sources =
      jsonDecode(File('tool/greek_exam_corpus/sources.json').readAsStringSync())
          as Map<String, dynamic>;

  final frequency = lemmaFrequency();

  final previous =
      (jsonDecode(File(outputFile).readAsStringSync()) as Map)['entries']
          as Map<String, dynamic>;

  final german = GermanLexicon.load(sources);

  final result = writeGermanLexicon(
    lemmas: frequency.keys,
    german: german,
    declensionOf: (lemma) => ((previous[lemma] as Map?)?['decl'] as num?)?.toInt(),
  );

  stdout.writeln(describeResult(frequency, result.bySource, result.unresolved));

  if (args.contains('--report')) {
    final byFrequency = frequency.keys.toList()
      ..sort((a, b) => frequency[b]!.compareTo(frequency[a]!));

    // Nur Grundformen, die eine Hilfe brauchen können: nicht in der
    // Vokabelliste und nicht vorausgesetzt.
    final knowledge = VocabularyKnowledge(
      VocabularyMatcher([
        for (final entry
            in jsonDecode(
                  File('assets/greek_vocabulary.json').readAsStringSync(),
                )
                as List)
          GreekVocabularyEntry.fromJson(entry as Map<String, dynamic>),
      ]),
      const [1, 2, 3, 4, 5, 6, 7, 8],
    );

    final report = StringBuffer();
    for (final lemma in byFrequency) {
      if (knowledge.isKnown(lemma)) continue;
      final gloss = german[lemma];
      report.writeln(
        '${frequency[lemma]}\t$lemma\t${gloss?.source ?? '-'}\t'
        '${gloss?.glosses.join(', ') ?? ''}',
      );
    }

    final target = File('${sources['cacheDir']}/lexicon_report.tsv')
      ..writeAsStringSync(report.toString());
    stdout.writeln('Übersicht: ${target.path}');
  }
}

/// Grundformen beider Korpora mit der Zahl der Verse, in denen sie stehen.
Map<String, int> lemmaFrequency() {
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

  return frequency;
}

String describeResult(
  Map<String, int> frequency,
  Map<String, int> bySource,
  List<String> unresolved,
) {
  bool capitalized(String lemma) =>
      RegExp(r'^\p{Lu}', unicode: true).hasMatch(lemma);

  final names = unresolved.where(capitalized).length;
  final total = frequency.values.fold(0, (a, b) => a + b);
  final open = unresolved
      .where((l) => !capitalized(l))
      .fold(0, (a, l) => a + frequency[l]!);

  return 'Lexikon: ${frequency.length} Grundformen – '
      '${bySource['e'] ?? 0} redaktionell, ${bySource['w'] ?? 0} Wiktionary, '
      '${bySource['p'] ?? 0} Pape; ungelöst ${unresolved.length - names} '
      '(${(100 * open / total).toStringAsFixed(1)} % der Belege) sowie '
      '$names großgeschriebene Grundformen (Eigennamen).';
}
