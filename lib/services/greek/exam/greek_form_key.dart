/// Vergleichsschlüssel griechischer Wortformen für die Formenindizes des
/// Klausurerstellers (Import und App verwenden dieselbe Funktion).
///
/// Anders als `normalizeGreekForComparison` bleiben Akzente, Spiritus und
/// Iota subscriptum erhalten, weil sie Formen unterscheiden (ἡ / ἥ / ἤ).
/// Vereinheitlicht wird nur, was keine Form unterscheidet:
///
/// * Groß-/Kleinschreibung, Schluss-Sigma,
/// * Gravis → Akut (Satzakzent: θεὸς = θεός),
/// * Oxia → Tonos (zwei Unicode-Schreibungen desselben Zeichens),
/// * ein zweiter Akzent durch ein folgendes Enklitikon (ἄνθρωπός τις),
/// * Längen- und Kürzezeichen (λῡ́ω), Apostroph-Varianten der Elision,
/// * Satzzeichen und textkritische Zeichen.
library;

const Map<int, int> _toTonos = {
  // Oxia → Tonos
  0x1F71: 0x03AC, 0x1F73: 0x03AD, 0x1F75: 0x03AE, 0x1F77: 0x03AF,
  0x1F79: 0x03CC, 0x1F7B: 0x03CD, 0x1F7D: 0x03CE, 0x1FD3: 0x0390,
  0x1FE3: 0x03B0, 0x1FBB: 0x0386, 0x1FC9: 0x0388, 0x1FCB: 0x0389,
  0x1FDB: 0x038A, 0x1FF9: 0x038C, 0x1FEB: 0x038E, 0x1FFB: 0x038F,
  // Gravis → Akut (Tonos)
  0x1F70: 0x03AC, 0x1F72: 0x03AD, 0x1F74: 0x03AE, 0x1F76: 0x03AF,
  0x1F78: 0x03CC, 0x1F7A: 0x03CD, 0x1F7C: 0x03CE, 0x1FB2: 0x1FB4,
  0x1FC2: 0x1FC4, 0x1FF2: 0x1FF4, 0x1FD2: 0x0390, 0x1FE2: 0x03B0,
  0x1FBA: 0x0386, 0x1FC8: 0x0388, 0x1FCA: 0x0389, 0x1FDA: 0x038A,
  0x1FF8: 0x038C, 0x1FEA: 0x038E, 0x1FFA: 0x038F,
  // Längen- und Kürzezeichen
  0x1FB0: 0x03B1, 0x1FB1: 0x03B1, 0x1FD0: 0x03B9, 0x1FD1: 0x03B9,
  0x1FE0: 0x03C5, 0x1FE1: 0x03C5,
  // Varianten
  0x03C2: 0x03C3, // ς → σ (wird am Wortende wieder gesetzt)
  0x03D0: 0x03B2, 0x03D1: 0x03B8, 0x03D5: 0x03C6, 0x03D6: 0x03C0,
};

// Zeichen mit Akut, Gravis oder Zirkumflex (für das Enklitikon).
bool _isAccented(int rune) {
  if ((rune >= 0x1F00 && rune <= 0x1F6F) ||
      (rune >= 0x1F80 && rune <= 0x1FAF)) {
    return (rune & 0x7) >= 2;
  }

  return const {
    0x03AC, 0x03AD, 0x03AE, 0x03AF, 0x03CC, 0x03CD, 0x03CE, 0x0390,
    0x03B0, 0x1FB4, 0x1FC4, 0x1FF4, 0x1FB6, 0x1FC6, 0x1FD6, 0x1FE6,
    0x1FF6, 0x1FB7, 0x1FC7, 0x1FF7, 0x1FD7, 0x1FE7,
  }.contains(rune);
}

// Entfernt den Akut eines Zeichens (nur für den zweiten Akzent).
int _withoutAcute(int rune) {
  if ((rune >= 0x1F00 && rune <= 0x1F6F) ||
      (rune >= 0x1F80 && rune <= 0x1FAF)) {
    final offset = rune & 0x7;
    return offset == 4 || offset == 5 ? rune - 4 : rune;
  }

  return const {
        0x03AC: 0x03B1, 0x03AD: 0x03B5, 0x03AE: 0x03B7, 0x03AF: 0x03B9,
        0x03CC: 0x03BF, 0x03CD: 0x03C5, 0x03CE: 0x03C9, 0x0390: 0x03CA,
        0x03B0: 0x03CB, 0x1FB4: 0x1FB3, 0x1FC4: 0x1FC3, 0x1FF4: 0x1FF3,
      }[rune] ??
      rune;
}

bool _isGreekLetter(int rune) {
  return (rune >= 0x0386 && rune <= 0x03FF && rune != 0x0387) ||
      (rune >= 0x1F00 && rune <= 0x1FFF && !_isGreekPunctuation(rune));
}

bool _isGreekPunctuation(int rune) {
  // Koronis, Psili, Perispomeni usw. als Einzelzeichen.
  return rune == 0x1FBD ||
      rune == 0x1FBF ||
      rune == 0x1FC0 ||
      rune == 0x1FC1 ||
      (rune >= 0x1FCD && rune <= 0x1FCF) ||
      (rune >= 0x1FDD && rune <= 0x1FDF) ||
      (rune >= 0x1FED && rune <= 0x1FEF) ||
      rune == 0x1FFD ||
      rune == 0x1FFE;
}

const int _apostrophe = 0x2019;

bool _isElisionMark(int rune) {
  return rune == 0x2019 ||
      rune == 0x02BC ||
      rune == 0x1FBD ||
      rune == 0x0027 ||
      rune == 0x1FBF;
}

// -----------------------------------------------------------------------------
// ZUSAMMENSETZEN KOMBINIERENDER ZEICHEN (NFC für griechische Vokale)
// -----------------------------------------------------------------------------

// Merkmale eines Vokalzeichens: Grundbuchstabe, Spiritus (0 keiner,
// 1 lenis, 2 asper), Akzent (0 keiner, 1 Gravis, 2 Akut, 3 Zirkumflex),
// Iota subscriptum, Trema.
typedef _Vowel = ({int base, int breathing, int accent, bool iota, bool trema});

final Map<int, _Vowel> _vowelOf = _buildVowels();
// Bei mehreren Schreibungen gewinnt die zuerst eingetragene (Tonos vor Oxia).
final Map<_Vowel, int> _composed = () {
  final result = <_Vowel, int>{};
  for (final e in _vowelOf.entries) {
    result.putIfAbsent(e.value, () => e.key);
  }
  return result;
}();

Map<int, _Vowel> _buildVowels() {
  final result = <int, _Vowel>{};

  void add(int rune, int base, int breathing, int accent, bool iota,
      [bool trema = false]) {
    result.putIfAbsent(rune, () => (
          base: base,
          breathing: breathing,
          accent: accent,
          iota: iota,
          trema: trema,
        ));
  }

  const vowels = [0x03B1, 0x03B5, 0x03B7, 0x03B9, 0x03BF, 0x03C5, 0x03C9];

  for (final v in vowels) {
    add(v, v, 0, 0, false);
  }

  // Tonos (Akut ohne Spiritus)
  const tonos = {
    0x03B1: 0x03AC, 0x03B5: 0x03AD, 0x03B7: 0x03AE, 0x03B9: 0x03AF,
    0x03BF: 0x03CC, 0x03C5: 0x03CD, 0x03C9: 0x03CE,
  };
  tonos.forEach((base, rune) => add(rune, base, 0, 2, false));

  // Oxia (gleichwertige Schreibung des Akuts)
  const oxia = {
    0x03B1: 0x1F71, 0x03B5: 0x1F73, 0x03B7: 0x1F75, 0x03B9: 0x1F77,
    0x03BF: 0x1F79, 0x03C5: 0x1F7B, 0x03C9: 0x1F7D,
  };
  oxia.forEach((base, rune) => add(rune, base, 0, 2, false));

  // Gravis ohne Spiritus
  const grave = {
    0x03B1: 0x1F70, 0x03B5: 0x1F72, 0x03B7: 0x1F74, 0x03B9: 0x1F76,
    0x03BF: 0x1F78, 0x03C5: 0x1F7A, 0x03C9: 0x1F7C,
  };
  grave.forEach((base, rune) => add(rune, base, 0, 1, false));

  // Zirkumflex ohne Spiritus
  const circumflex = {
    0x03B1: 0x1FB6, 0x03B7: 0x1FC6, 0x03B9: 0x1FD6, 0x03C5: 0x1FE6,
    0x03C9: 0x1FF6,
  };
  circumflex.forEach((base, rune) => add(rune, base, 0, 3, false));

  // Spiritus (+ Akzent): je Vokal ein Block zu 8 Zeichen.
  const blocks = {
    0x03B1: 0x1F00, 0x03B5: 0x1F10, 0x03B7: 0x1F20, 0x03B9: 0x1F30,
    0x03BF: 0x1F40, 0x03C5: 0x1F50, 0x03C9: 0x1F60,
  };
  blocks.forEach((base, start) {
    for (var offset = 0; offset < 8; offset++) {
      if ((base == 0x03B5 || base == 0x03BF) && offset >= 6) continue;
      add(start + offset, base, 1 + (offset & 1), const [0, 0, 1, 1, 2, 2, 3, 3][offset],
          false);
    }
  });

  // Iota subscriptum
  const iota = {0x03B1: 0x1FB3, 0x03B7: 0x1FC3, 0x03C9: 0x1FF3};
  iota.forEach((base, rune) {
    add(rune, base, 0, 0, true);
    add(rune - 1, base, 0, 1, true); // ᾲ
    add(rune + 1, base, 0, 2, true); // ᾴ
    add(rune + 4, base, 0, 3, true); // ᾷ
  });
  const iotaBlocks = {0x03B1: 0x1F80, 0x03B7: 0x1F90, 0x03C9: 0x1FA0};
  iotaBlocks.forEach((base, start) {
    for (var offset = 0; offset < 8; offset++) {
      add(start + offset, base, 1 + (offset & 1), const [0, 0, 1, 1, 2, 2, 3, 3][offset],
          true);
    }
  });

  // Trema
  add(0x03CA, 0x03B9, 0, 0, false, true);
  add(0x03CB, 0x03C5, 0, 0, false, true);
  add(0x0390, 0x03B9, 0, 2, false, true);
  add(0x03B0, 0x03C5, 0, 2, false, true);
  add(0x1FD2, 0x03B9, 0, 1, false, true);
  add(0x1FE2, 0x03C5, 0, 1, false, true);
  add(0x1FD7, 0x03B9, 0, 3, false, true);
  add(0x1FE7, 0x03C5, 0, 3, false, true);

  // Rho mit Spiritus
  add(0x1FE4, 0x03C1, 1, 0, false);
  add(0x1FE5, 0x03C1, 2, 0, false);
  add(0x03C1, 0x03C1, 0, 0, false);

  return result;
}

/// Setzt Grundbuchstaben und folgende kombinierende Zeichen (Akzente,
/// Spiritus, Iota subscriptum, Trema) zu einem Zeichen zusammen, wie es
/// Unicode-NFC täte. Wörterbuchformen mit Längenzeichen schreiben z. B.
/// λῡ́ω als ῡ + kombinierender Akut; ohne Längenzeichen wird daraus ύ.
String composeGreek(String text) {
  final out = <int>[];

  for (final rune in text.runes) {
    final previous = out.isEmpty ? null : _vowelOf[out.last];

    int? breathing;
    int? accent;
    bool? iota;
    bool? trema;

    switch (rune) {
      case 0x0313 || 0x0343:
        breathing = 1;
      case 0x0314:
        breathing = 2;
      case 0x0300:
        accent = 1;
      case 0x0301 || 0x0341:
        accent = 2;
      case 0x0342:
        accent = 3;
      case 0x0345:
        iota = true;
      case 0x0308:
        trema = true;
      default:
        out.add(rune);
        continue;
    }

    if (previous == null) {
      // Kombinierendes Zeichen ohne passenden Grundbuchstaben: weglassen.
      continue;
    }

    final combined = (
      base: previous.base,
      breathing: breathing ?? previous.breathing,
      accent: accent ?? previous.accent,
      iota: iota ?? previous.iota,
      trema: trema ?? previous.trema,
    );

    final composed = _composed[combined];
    if (composed != null) out[out.length - 1] = composed;
  }

  return String.fromCharCodes(out);
}

/// Schlüssel einer einzelnen Wortform (siehe Bibliotheksbeschreibung).
/// Leer, wenn [word] keine griechischen Buchstaben enthält.
String greekFormKey(String word) {
  final runes = <int>[];

  // Längen-/Kürzezeichen entfernen, bevor kombinierende Akzente
  // zusammengesetzt werden (ῡ́ → ύ).
  final plain = word
      .toLowerCase()
      .replaceAll(RegExp('[̄̆]'), '')
      .replaceAllMapped(
        RegExp('[ᾰᾱῐῑῠῡ]'),
        (m) => const {
          'ᾰ': 'α',
          'ᾱ': 'α',
          'ῐ': 'ι',
          'ῑ': 'ι',
          'ῠ': 'υ',
          'ῡ': 'υ',
        }[m[0]]!,
      );

  for (final rune in composeGreek(plain).runes) {
    final mapped = _toTonos[rune] ?? rune;

    if (_isGreekLetter(mapped)) {
      runes.add(mapped);
    } else if (_isElisionMark(mapped) && runes.isNotEmpty) {
      runes.add(_apostrophe);
    }
  }

  // Apostroph nur am Wortende (Elision); sonst ist es ein Anführungszeichen.
  while (runes.isNotEmpty && runes.first == _apostrophe) {
    runes.removeAt(0);
  }

  for (var i = runes.length - 2; i >= 0; i--) {
    if (runes[i] == _apostrophe) runes.removeAt(i);
  }

  // Zweiter Akzent durch ein folgendes Enklitikon: der letzte Akut fällt weg.
  final accented = [
    for (var i = 0; i < runes.length; i++)
      if (_isAccented(runes[i])) i,
  ];

  if (accented.length >= 2) {
    final last = accented.last;
    runes[last] = _withoutAcute(runes[last]);
  }

  if (runes.isEmpty) return "";

  final elided = runes.last == _apostrophe;
  final letters = elided ? runes.length - 1 : runes.length;

  if (letters > 0 && runes[letters - 1] == 0x03C3) {
    runes[letters - 1] = 0x03C2;
  }

  return String.fromCharCodes(runes);
}

/// Zerlegt einen Vers in Wortformen: an Leerraum, Satzzeichen bleiben an der
/// Form (für die Anzeige), der Schlüssel ignoriert sie. Bestandteile ohne
/// griechische Buchstaben (textkritische Zeichen, Gedankenstriche) zählen
/// nicht als Wort.
List<String> splitGreekWords(String text) {
  return [
    for (final part in text.split(RegExp(r'\s+')))
      if (greekFormKey(part).isNotEmpty) part,
  ];
}

/// Ob die Wortform [surface] einen Satz bzw. Satzteil abschließt (Punkt,
/// Hochpunkt, griechisches Fragezeichen).
bool endsGreekSentence(String surface) {
  final trimmed = surface.trimRight();

  if (trimmed.isEmpty) return false;

  const closers = {'.', ';', ';', '·', '·', '!'};

  // Schließende Anführungszeichen und Klammern nach dem Satzzeichen.
  var end = trimmed.length - 1;

  while (end > 0 && '’”»)]⸃⸅'.contains(trimmed[end])) {
    end--;
  }

  return closers.contains(trimmed[end]);
}
