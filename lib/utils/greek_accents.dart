/// Akzente griechischer Wörter für die Formenbildung im Grammatiktrainer.
///
/// Anders als `normalizeGreekForComparison` bleiben Spiritus, Iota
/// subscriptum und Trema erhalten: Aus παύ- wird παυ-, aus ἄγ- wird ἀγ-.
library;

// Einzelzeichen mit Akzent (Tonos-, Oxia- und Gravis-/Zirkumflexformen) und
// ihr Gegenstück ohne Akzent.
const Map<int, int> _unaccented = {
  0x03AC: 0x03B1, // ά → α
  0x03AD: 0x03B5, // έ → ε
  0x03AE: 0x03B7, // ή → η
  0x03AF: 0x03B9, // ί → ι
  0x03CC: 0x03BF, // ό → ο
  0x03CD: 0x03C5, // ύ → υ
  0x03CE: 0x03C9, // ώ → ω
  0x0390: 0x03CA, // ΐ → ϊ
  0x03B0: 0x03CB, // ΰ → ϋ
  0x1F70: 0x03B1, // ὰ
  0x1F71: 0x03B1, // ά
  0x1F72: 0x03B5, // ὲ
  0x1F73: 0x03B5, // έ
  0x1F74: 0x03B7, // ὴ
  0x1F75: 0x03B7, // ή
  0x1F76: 0x03B9, // ὶ
  0x1F77: 0x03B9, // ί
  0x1F78: 0x03BF, // ὸ
  0x1F79: 0x03BF, // ό
  0x1F7A: 0x03C5, // ὺ
  0x1F7B: 0x03C5, // ύ
  0x1F7C: 0x03C9, // ὼ
  0x1F7D: 0x03C9, // ώ
  0x1FB6: 0x03B1, // ᾶ → α
  0x1FC6: 0x03B7, // ῆ → η
  0x1FD6: 0x03B9, // ῖ → ι
  0x1FE6: 0x03C5, // ῦ → υ
  0x1FF6: 0x03C9, // ῶ → ω
  0x1FB2: 0x1FB3, // ᾲ → ᾳ
  0x1FB4: 0x1FB3, // ᾴ → ᾳ
  0x1FB7: 0x1FB3, // ᾷ → ᾳ
  0x1FC2: 0x1FC3, // ῂ → ῃ
  0x1FC4: 0x1FC3, // ῄ → ῃ
  0x1FC7: 0x1FC3, // ῇ → ῃ
  0x1FF2: 0x1FF3, // ῲ → ῳ
  0x1FF4: 0x1FF3, // ῴ → ῳ
  0x1FF7: 0x1FF3, // ῷ → ῳ
  0x1FD2: 0x03CA, // ῒ → ϊ
  0x1FD3: 0x03CA, // ΐ → ϊ
  0x1FD7: 0x03CA, // ῗ → ϊ
  0x1FE2: 0x03CB, // ῢ → ϋ
  0x1FE3: 0x03CB, // ΰ → ϋ
  0x1FE7: 0x03CB, // ῧ → ϋ
};

int _withoutAccent(int rune) {
  // Vokale mit Spiritus (U+1F00–U+1F6F, mit Iota subscriptum
  // U+1F80–U+1FAF): je Achterblock Spiritus lenis und asper, danach
  // dieselben beiden mit Gravis, Akut und Zirkumflex.
  if ((rune >= 0x1F00 && rune <= 0x1F6F) ||
      (rune >= 0x1F80 && rune <= 0x1FAF)) {
    return (rune & ~0x7) | (rune & 0x1);
  }

  return _unaccented[rune] ?? rune;
}

/// Entfernt Akut, Gravis und Zirkumflex; alles andere bleibt stehen.
String stripGreekAccent(String text) {
  return String.fromCharCodes(text.runes.map(_withoutAccent));
}

/// Ob [text] einen Akut, Gravis oder Zirkumflex trägt.
bool hasGreekAccent(String text) {
  return stripGreekAccent(text) != text;
}
