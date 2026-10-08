# -*- coding: utf-8 -*-
"""Griechische Wörter und Zitate.

In der elektronischen Triglotta ist Griechisch fehlerhaft kodiert: akzentuierte
Vokale stehen als verdoppelter Buchstabe mit Leerzeichen ("εε πιειί κειαν" für
ἐπιείκειαν), Spiritus und Akut sind dabei nicht unterscheidbar und Wortgrenzen
gehen verloren. Eine mechanische Rückführung ist deshalb nicht möglich;
``greek_table.py`` enthält die richtige Schreibung aller vorkommenden Stellen.
Zugeordnet wird über die Folge der Grundbuchstaben; was sich nicht eindeutig
zuordnen lässt, wird gemeldet und bleibt unverändert.
"""
import re
import unicodedata

from greek_table import ENGLISH, TABLE

GREEK = r'Ͱ-Ͽἀ-῿'
MARKS = r'̀-ͯʰ-˿'
SPAN = re.compile("[%s%s][%s%s ,;·'’]*[%s%s]|[%s]" % (GREEK, MARKS, GREEK, MARKS, GREEK, MARKS, GREEK))

UNKNOWN = []


def skeleton(s):
    """Grundbuchstaben ohne Zeichen, Wortgrenzen und Vokalverdopplung."""
    s = unicodedata.normalize('NFD', s)
    letters = [c for c in s.lower() if 'α' <= c <= 'ω']
    out = []
    for c in letters:
        c = 'σ' if c == 'ς' else c
        if out and out[-1] == c and c in 'αεηιουω':
            continue
        out.append(c)
    return ''.join(out)


def distance(a, b):
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[-1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


KEYS = [(skeleton(t), t) for t in TABLE]


def lookup(mangled):
    """Tabelleneintrag mit denselben Grundbuchstaben (kleine Abweichungen durch
    Kodierungsreste und Druckfehler der Vorlage zugelassen)."""
    key = skeleton(mangled)
    exact = [t for k, t in KEYS if k == key]
    if exact:
        # Groß-/Kleinschreibung des Anfangs wie in der Vorlage
        upper = unicodedata.normalize('NFD', mangled.lstrip('ʼ̓ '))[:1].isupper()
        for t in exact:
            if unicodedata.normalize('NFD', t)[:1].isupper() == upper:
                return t
        return exact[0]
    scored = sorted((distance(key, k), t) for k, t in KEYS if abs(len(k) - len(key)) <= 3)
    if scored and scored[0][0] <= max(1, len(key) // 12) and (len(scored) == 1 or scored[1][0] > scored[0][0]):
        return scored[0][1]
    return None


def spans(text):
    return [m for m in SPAN.finditer(text) if re.search('[%s]' % GREEK, m.group(0))]


def restore_greek(text, tag):
    if tag.endswith('/en'):
        todo = list(ENGLISH.get(tag, []))
        while '((greek' in text:
            m = re.search(r'\(\(greek\)\)?', text)
            if todo:
                text = text[:m.start()] + todo.pop(0) + text[m.end():]
            else:
                UNKNOWN.append((tag, text[max(0, m.start() - 60):m.end() + 20]))
                text = text[:m.start()] + text[m.end():]
        if todo:
            UNKNOWN.append((tag, 'nicht verbraucht: %r' % todo))
        return text
    out = []
    pos = 0
    for m in spans(text):
        fixed = lookup(m.group(0))
        if fixed is None:
            UNKNOWN.append((tag, m.group(0)))
            continue
        out.append(text[pos:m.start()])
        out.append(fixed)
        pos = m.end()
    out.append(text[pos:])
    return ''.join(out)
