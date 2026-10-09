/// Außerhalb des Browsers wählt und speichert die App keine Dateien selbst;
/// dort wird der Inhalt über die Zwischenablage eingefügt bzw. kopiert.
const bool textFilesSupported = false;

Future<String?> pickTextFile({int maxLength = 500000}) async => null;

void saveTextFile(String name, String content) {}
