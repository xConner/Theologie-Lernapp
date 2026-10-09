import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Im Browser lassen sich Textdateien direkt wählen und herunterladen.
const bool textFilesSupported = true;

/// Öffnet die Dateiauswahl des Browsers und liefert den Inhalt der gewählten
/// JSON-Datei; `null`, wenn nichts gewählt wurde oder die Datei zu groß ist.
Future<String?> pickTextFile({int maxLength = 500000}) {
  final completer = Completer<String?>();

  void complete(String? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json,text/plain';

  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);

      // Vier Bytes je Zeichen sind die Obergrenze von UTF-8.
      if (file == null || file.size > maxLength * 4) {
        complete(null);
        return;
      }

      file.text().toDart.then(
        (text) => complete(text.toDart),
        onError: (Object _) => complete(null),
      );
    }).toJS,
  );

  input.addEventListener('cancel', ((web.Event _) => complete(null)).toJS);

  input.click();

  return completer.future;
}

/// Bietet [content] als Datei [name] zum Herunterladen an.
void saveTextFile(String name, String content) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );

  final url = web.URL.createObjectURL(blob);

  web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..click();

  web.URL.revokeObjectURL(url);
}
