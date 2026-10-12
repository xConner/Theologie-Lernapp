// Fügt redaktionelle Angaben aus einer Datei mit Zeilen der Form
//   "λέμμα": ["Bedeutung", …],
// in german_glosses.json ein (vorhandene Einträge werden ersetzt).
//
//   dart run tool/greek_exam_corpus/merge_glosses.dart <Datei>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final target = File('tool/greek_exam_corpus/german_glosses.json');
  final data = jsonDecode(target.readAsStringSync()) as Map<String, dynamic>;
  final entries = data['entries'] as Map<String, dynamic>;

  final lines = File(args.single)
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => l.endsWith(',') ? l.substring(0, l.length - 1) : l);

  final added = jsonDecode('{${lines.join(',')}}') as Map<String, dynamic>;

  for (final MapEntry(:key, :value) in added.entries) {
    entries[key.trim()] = value;
  }

  final buffer = StringBuffer('{\n  "comment": ${jsonEncode(data['comment'])},\n')
    ..writeln('  "entries": {');

  final keys = entries.keys.toList();
  for (final (i, key) in keys.indexed) {
    buffer.writeln(
      '    ${jsonEncode(key)}: ${jsonEncode(entries[key]).replaceAll('","', '", "')}'
      '${i == keys.length - 1 ? '' : ','}',
    );
  }

  buffer.writeln('  }\n}');
  target.writeAsStringSync(buffer.toString());

  stdout.writeln('${added.length} Angaben eingefügt, ${entries.length} gesamt.');
}
