# -*- coding: utf-8 -*-
"""Erzeugt ``lib/services/bible/search_folding_table.dart``.

Die Tabelle bildet Buchstaben mit Akzenten, Spiritus und anderen Zusätzen
auf ihren Grundbuchstaben in Kleinschreibung ab (Unicode-Zerlegung NFD ohne
die kombinierenden Zeichen) und Satzzeichen auf nichts. Sie dient nur der
Suche; der angezeigte Bibeltext bleibt unverändert.
"""
import os
import unicodedata

from common import REPO

# Lateinisch mit Zusätzen, Griechisch, Griechisch erweitert, Satzzeichen.
RANGES = [(0x00A0, 0x024F), (0x02B0, 0x02FF), (0x0370, 0x03FF), (0x1E00, 0x1FFF),
          (0x2000, 0x206F), (0x2E00, 0x2E7F)]
SPECIAL = {'ß': 'ss', 'ẞ': 'ss', 'æ': 'ae', 'Æ': 'ae', 'œ': 'oe', 'Œ': 'oe', 'ς': 'σ',
           'ϐ': 'β', 'ϑ': 'θ', 'ϕ': 'φ', 'ϖ': 'π', 'ϰ': 'κ', 'ϱ': 'ρ', 'ϲ': 'σ', 'Ϲ': 'σ',
           'ø': 'o', 'Ø': 'o', 'đ': 'd', 'Đ': 'd', 'ł': 'l', 'Ł': 'l'}


def fold(char):
    if char in SPECIAL:
        return SPECIAL[char]
    category = unicodedata.category(char)
    if category[0] == 'Z':
        return ' '
    # Auch Apostroph und Spiritus als eigene Zeichen (ʼ, ᾿) zählen nicht.
    if category[0] not in 'LN' or category == 'Lm':
        return ''
    base = ''.join(c for c in unicodedata.normalize('NFD', char)
                   if unicodedata.category(c)[0] != 'M')
    return ''.join(SPECIAL.get(c, c) for c in base.lower())


def main():
    entries = []
    for start, end in RANGES:
        for code in range(start, end + 1):
            char = chr(code)
            if unicodedata.category(char) == 'Cn':
                continue
            folded = fold(char)
            if folded != char:
                entries.append((code, folded))

    path = os.path.join(REPO, 'lib', 'services', 'bible', 'search_folding_table.dart')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('// Erzeugt von tool/bible_import/build_search_folding.py – nicht von Hand\n'
                '// bearbeiten.\n\n'
                '/// Zeichen → Schreibweise für den Suchvergleich (Grundbuchstabe, klein).\n'
                '/// Ein leerer Wert bedeutet: Das Zeichen zählt bei der Suche nicht.\n'
                'const Map<int, String> searchFoldingTable = {\n')
        for code, folded in entries:
            f.write("  0x%04X: '%s',\n" % (code, folded))
        f.write('};\n')
    print(len(entries), 'Einträge')


if __name__ == '__main__':
    main()
