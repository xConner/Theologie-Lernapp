import 'search_folding_table.dart';

/// Vergleichsform eines Textes für die Suche samt Zuordnung zurück zum
/// Original, damit Treffer im unveränderten Text markiert werden können.
class FoldedText {
  final String text;

  /// Zu jedem Zeichen von [text] die Position im Original.
  final List<int> offsets;

  const FoldedText(this.text, this.offsets);
}

/// Vergleichsform für die Suche: Kleinschreibung, ohne Akzente, Spiritus,
/// Iota subscriptum, Satz- und textkritische Zeichen; Leerraum wird zu einem
/// Leerzeichen. Griechisch und Latein werden damit unabhängig von der
/// Unicode-Schreibweise (zusammengesetzt oder zerlegt) gefunden.
///
/// Mit [keepUmlauts] bleiben ä, ö und ü eigene Buchstaben (deutsche Texte),
/// sonst zählen sie wie a, o und u. Der angezeigte Text wird nie verändert.
String foldForSearch(String text, {required bool keepUmlauts}) {
  return _fold(text, keepUmlauts, null);
}

FoldedText foldWithOffsets(String text, {required bool keepUmlauts}) {
  final offsets = <int>[];

  return FoldedText(_fold(text, keepUmlauts, offsets), offsets);
}

String _fold(String text, bool keepUmlauts, List<int>? offsets) {
  final out = StringBuffer();

  bool pendingSpace = false;
  int pendingSpaceAt = 0;
  bool any = false;

  void emit(String value, int at) {
    if (pendingSpace && any) {
      out.write(" ");
      offsets?.add(pendingSpaceAt);
    }

    pendingSpace = false;
    any = true;

    out.write(value);

    if (offsets != null) {
      for (int i = 0; i < value.length; i++) {
        offsets.add(at);
      }
    }
  }

  for (int i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);

    if (c < 0x80) {
      if (c >= 0x61 && c <= 0x7A || c >= 0x30 && c <= 0x39) {
        emit(String.fromCharCode(c), i);
      } else if (c >= 0x41 && c <= 0x5A) {
        emit(String.fromCharCode(c + 0x20), i);
      } else if (c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D) {
        if (!pendingSpace) pendingSpaceAt = i;
        pendingSpace = true;
      }

      continue;
    }

    // Kombinierende Akzente und Spiritus (zerlegte Schreibweise).
    if (c >= 0x0300 && c <= 0x036F) continue;

    if (keepUmlauts) {
      final umlaut = _umlauts[c];

      if (umlaut != null) {
        emit(umlaut, i);
        continue;
      }
    }

    final folded = searchFoldingTable[c];

    if (folded == null) {
      emit(String.fromCharCode(c), i);
    } else if (folded == " ") {
      if (!pendingSpace) pendingSpaceAt = i;
      pendingSpace = true;
    } else if (folded.isNotEmpty) {
      emit(folded, i);
    }
  }

  return out.toString();
}

const Map<int, String> _umlauts = {
  0xE4: "ä",
  0xF6: "ö",
  0xFC: "ü",
  0xC4: "ä",
  0xD6: "ö",
  0xDC: "ü",
};
