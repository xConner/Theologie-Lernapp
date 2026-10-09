# -*- coding: utf-8 -*-
"""Liest ein USFM-Buch in die Struktur des Readers.

Der Wortlaut wird nicht verändert: Übernommen werden die Zeichen der
Quelle, lediglich Formatmarken entfallen und Leerraum wird wie in USFM
vorgesehen zu einem Leerzeichen zusammengefasst. Unbekannte Marken brechen
den Import ab, damit eine neue Quelle nicht stillschweigend falsch gelesen
wird.

Ergebnis je Kapitel ist eine Liste von Einträgen:

* ``{"h": Text, "l": Ebene}`` – Zwischenüberschrift
* ``{"d": Text}`` – Überschrift eines Psalms außerhalb der Verszählung
* ``{"v": Nummer, "t": Text, ...}`` – Vers; optional ``"l"`` (Bezeichnung
  der Quelle, wenn sie keine reine Zahl ist, z. B. ``22a``), ``"c"``
  (Fortsetzung desselben Verses nach einer Zwischenüberschrift), ``"b"``
  (Umbruch vor dem Vers: 1 Absatz, 2 Zeile, 3 eingerückte Zeile), ``"g"``
  (Leerzeile davor) und ``"f"`` (Anmerkungen als ``[Position, Text]``).

Im Verstext steht ``\\n`` für einen Zeilenumbruch der Quelle, ``\\n\\t`` für
eine eingerückte Zeile.
"""
import re

# Absatzmarken, deren Inhalt nicht zum Bibeltext gehört.
SKIP = {
    'id', 'ide', 'h', 'toc1', 'toc2', 'toc3', 'mt1', 'mt2', 'mt3', 'mt4',
    'ip', 'is1', 'im', 'imi', 'ib', 'ili', 'tr', 'tc1', 'tc2', 'tc3', 'cl',
    'rem', 'sts',
}

# Überschriften: Marke → Ebene.
# ``qc`` (zentrierte Zeile) steht in den Quellen für die Buchstaben-
# überschriften von Psalm 119.
HEADINGS = {'ms1': 1, 's1': 1, 's2': 2, 'sp': 2, 'qc': 2}

# Umbruch vor dem folgenden Text: 0 keiner, 1 Absatz, 2 Zeile, 3 eingerückt.
BODY = {
    'p': 1, 'm': 1, 'pi1': 1, 'mi': 1, 'pc': 1, 'li1': 1, 'd': 1,
    'nb': 0, 'q1': 2, 'q2': 3, 'q3': 3,
}

# Zeichenformate: Die Auszeichnung entfällt, der Text bleibt stehen.
CHARACTER = {
    'w', 'nd', 'add', 'em', 'wj', 'it', 'bd', 'sc', 'sup', 'qs', 'k', 'bk',
    'wh',
}

NOTE_TEXT = {'ft', 'fk', 'fq', 'fqa'}

_MARKER = re.compile(r'\\(\+?)([a-z]+[0-9]*)(\*?)')
_ATTRIBUTES = re.compile(r'\|\s*(?:[a-z-]+="[^"]*"\s*)+(?=\\)')
_SPACE = re.compile(r'[ \t\r\n]+')
_VERSE = re.compile(r'\s*(\d+)(\S*)\s?')


class UsfmError(Exception):
    pass


class _Verse:
    """Sammelt Text, Umbrüche und Anmerkungen eines Verses."""

    def __init__(self, number, label, brk, gap, continued=False):
        self.number = number
        self.label = label
        self.continued = continued
        self.brk = brk
        self.gap = gap
        self.text = ''
        self.notes = []

    def add(self, chunk):
        chunk = _SPACE.sub(' ', chunk)
        if not self.text or self.text[-1] in ' \n\t':
            chunk = chunk.lstrip(' ')
        self.text += chunk

    def line_break(self, kind, gap):
        if not self.text.strip():
            # Umbruch unmittelbar nach der Versnummer gehört vor den Vers.
            self.text = ''
            if kind > 1 or not self.brk:
                self.brk = kind
            self.gap = self.gap or gap
            return
        if kind == 0:
            return
        self.text = self.text.rstrip(' ')
        self.text += '\n\n' if gap else '\n'
        if kind == 3:
            self.text += '\t'

    def note(self, text):
        text = _SPACE.sub(' ', text).strip()
        if text:
            self.notes.append([len(self.text), text])

    def item(self):
        text = self.text.rstrip(' \n\t')
        item = {'v': self.number, 't': text}
        if self.label:
            item['l'] = self.label
        if self.continued:
            item['c'] = 1
        if self.brk:
            item['b'] = self.brk
        if self.gap:
            item['g'] = 1
        if self.notes:
            item['f'] = [[min(pos, len(text)), note] for pos, note in self.notes]
        return item


def parse_book(source, keep_notes):
    """Gibt ``(Kopfangaben, Kapitel)`` zurück; Kapitel ist ``{Nummer: Einträge}``."""
    source = source.lstrip('\ufeff')
    source = _ATTRIBUTES.sub('', source)

    head = {}
    chapters = {}
    items = None  # Einträge des laufenden Kapitels

    mode = 'skip'  # skip | head:<Marke> | heading | body
    heading = None
    verse = None
    last = None  # (Nummer, Bezeichnung) des letzten Verses im Kapitel
    pending = None  # Umbruch, der vor dem nächsten Text steht
    gap = False
    descriptive = False  # im \d-Absatz vor dem ersten Vers
    loose = ''  # Text im Kapitel außerhalb eines Verses
    note = None  # Text der laufenden Anmerkung
    note_text = False
    in_xref = False

    def close_verse():
        nonlocal verse
        if verse is not None:
            items.append(verse.item())
            verse = None

    def close_loose():
        nonlocal loose, descriptive
        text = _SPACE.sub(' ', loose).strip()
        if text:
            if items is None:
                raise UsfmError('Text vor dem ersten Kapitel: ' + text[:60])
            if not descriptive:
                raise UsfmError('Text außerhalb eines Verses: ' + text[:60])
            items.append({'d': text})
        loose = ''

    def close_heading():
        nonlocal heading
        if heading is not None:
            text = _SPACE.sub(' ', heading[1]).strip()
            if text and items is not None:
                items.append({'h': text, 'l': heading[0]})
            heading = None

    def text(chunk):
        nonlocal loose, pending, gap, note, verse
        if not chunk:
            return
        if in_xref:
            return
        if note is not None:
            if note_text:
                note += chunk
            return
        if mode == 'skip':
            return
        if mode.startswith('head:'):
            key = mode[5:]
            head[key] = (head.get(key, '') + chunk)
            return
        if mode == 'heading':
            heading[1] += chunk
            return
        if verse is None and (descriptive or last is None or loose):
            loose += chunk
            return
        if not chunk.strip():
            if verse is not None and pending is None:
                verse.add(chunk)
            return
        if verse is None:
            # Der Vers geht nach einer Zwischenüberschrift weiter.
            verse = _Verse(last[0], last[1], pending, gap, continued=True)
            pending = None
            gap = False
        if pending is not None:
            verse.line_break(pending, gap)
            pending = None
            gap = False
        verse.add(chunk)

    pos = 0
    for match in _MARKER.finditer(source):
        text(source[pos:match.start()])
        pos = match.end()

        nested, name, closing = match.groups()

        if closing:
            if name == 'f':
                if keep_notes and verse is not None and note is not None:
                    verse.note(note)
                note = None
            elif name == 'x':
                in_xref = False
            elif name not in CHARACTER and name not in NOTE_TEXT and name != 'fr':
                raise UsfmError('Unbekannte Endmarke \\%s*' % name)
            continue

        # Das Leerzeichen nach einer öffnenden Marke gehört zur Marke.
        if pos < len(source) and source[pos] in ' \n\r\t':
            pos += 1

        if name == 'f':
            note = ''
            note_text = False
            # Aufrufzeichen („+“, „-“) überspringen.
            caller = re.compile(r'\S+\s?').match(source, pos)
            if caller:
                pos = caller.end()
            continue
        if name == 'x':
            in_xref = True
            continue
        if note is not None:
            if name == 'fr':
                note_text = False
            elif name in NOTE_TEXT:
                note_text = True
            elif name not in CHARACTER:
                raise UsfmError('Unbekannte Marke in Anmerkung: \\' + name)
            continue
        if in_xref:
            continue
        if name in CHARACTER:
            continue
        if nested:
            raise UsfmError('Unbekannte Zeichenmarke \\+' + name)

        if name == 'v':
            number = _VERSE.match(source, pos)
            if number is None or items is None:
                raise UsfmError('Vers ohne Nummer oder Kapitel bei %d' % pos)
            pos = number.end()
            close_loose()
            close_heading()
            close_verse()
            descriptive = False
            mode = 'body'
            last = (int(number.group(1)),
                    number.group(1) + number.group(2) if number.group(2) else None)
            verse = _Verse(last[0], last[1], pending, gap)
            pending = None
            gap = False
            continue

        # Alle übrigen Marken beginnen einen neuen Absatz.
        close_loose()
        close_heading()

        if name == 'c':
            number = re.compile(r'\s*(\d+)').match(source, pos)
            if number is None:
                raise UsfmError('Kapitel ohne Nummer')
            pos = number.end()
            close_verse()
            items = chapters.setdefault(int(number.group(1)), [])
            last = None
            mode = 'skip'
            pending = None
            gap = False
            descriptive = False
        elif name in ('h', 'toc1', 'toc2', 'toc3'):
            mode = 'head:' + name
        elif name in SKIP:
            mode = 'skip'
        elif name in HEADINGS:
            close_verse()
            heading = [HEADINGS[name], '']
            mode = 'heading'
        elif name == 'b':
            gap = True
        elif name in BODY:
            mode = 'body'
            descriptive = name == 'd' and verse is None
            pending = BODY[name]
        else:
            raise UsfmError('Unbekannte Marke \\' + name)

    text(source[pos:])
    close_loose()
    close_heading()
    if items is not None:
        close_verse()

    return {k: _SPACE.sub(' ', v).strip() for k, v in head.items()}, chapters
