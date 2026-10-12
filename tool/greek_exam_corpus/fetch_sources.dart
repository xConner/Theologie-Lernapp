// Lädt die Quellen der Klausurkorpora in den nicht versionierten Ordner
// build/content_import/greek_exam (siehe sources.json und README.md).
//
//   dart run tool/greek_exam_corpus/fetch_sources.dart          # fehlende laden
//   dart run tool/greek_exam_corpus/fetch_sources.dart --force  # alles neu laden
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final sources =
      jsonDecode(File('tool/greek_exam_corpus/sources.json').readAsStringSync())
          as Map<String, dynamic>;

  final cache = Directory(sources['cacheDir'] as String)
    ..createSync(recursive: true);

  final morphgnt = sources['morphgnt'] as Map<String, dynamic>;
  final commit = morphgnt['commit'] as String;
  final morphDir = Directory('${cache.path}/morphgnt-$commit')
    ..createSync(recursive: true);

  for (final file in (morphgnt['files'] as Map).values.cast<String>()) {
    final url = (morphgnt['url'] as String)
        .replaceAll('{commit}', commit)
        .replaceAll('{file}', file);
    await _download(url, File('${morphDir.path}/$file'), force);
  }

  for (final key in ['wiktionaryEnglish', 'wiktionaryGerman']) {
    final source = sources[key] as Map<String, dynamic>;
    await _download(
      source['url'] as String,
      File('${cache.path}/${source['file']}'),
      force,
    );
  }

  stdout.writeln('Quellen liegen in ${cache.path}.');
}

Future<void> _download(String url, File target, bool force) async {
  if (!force && target.existsSync() && target.lengthSync() > 0) return;

  stdout.writeln('Lade $url');

  final client = HttpClient();

  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }

    final expected = response.contentLength;
    final partial = File('${target.path}.part');
    await response.pipe(partial.openWrite());

    if (expected > 0 && partial.lengthSync() != expected) {
      throw StateError(
        'Unvollständiger Download: ${partial.lengthSync()} von $expected Bytes '
        '($url). Bitte erneut ausführen.',
      );
    }

    partial.renameSync(target.path);
  } finally {
    client.close();
  }
}
