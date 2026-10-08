# -*- coding: utf-8 -*-
"""Quelltexte -> Blöcke -> Abschnittstexte in den Konventionen von
``assets/confessions.json``.

Konventionen (wie bei den schon vorhandenen, am Faksimile geprüften Texten):
Absatzzähler ("12]") und Herausgeberzusätze in eckigen Klammern entfallen,
Überschriften stehen als eigene Zeile vor dem folgenden Absatz, Absätze sind
durch eine Leerzeile getrennt.
"""
import collections
import re

from bs4 import BeautifulSoup, NavigableString

from common import cache
from patches import apply_patches
from spec import BOOKS

# --------------------------------------------------------------------------
# Deutsch/Lateinisch: Layout-Text der elektronischen Triglotta
# --------------------------------------------------------------------------

FOOT_START = re.compile(r'^\s*\d*Lutheran Church\. Missouri')
NUM = re.compile(r'^\d+\]')


def layout_blocks(path):
    """Liefert [[art, text]] mit art 'H' (zentrierte Überschrift) oder 'P' (Absatz)."""
    blocks = []
    for page in open(path, encoding='utf-8').read().split('\f'):
        clean = []
        skip = False
        for line in page.split('\n'):
            # Zitierhinweis der elektronischen Ausgabe am Seitenfuß
            if FOOT_START.match(line):
                skip = True
            if skip:
                if 'House.' in line:
                    skip = False
                continue
            if re.match(r'^\s*\d{1,2}\s*$', line):
                continue
            if re.match(r'^\s*[—–-]{3,}\s*$', line):
                clean.append('')
                continue
            clean.append(re.sub(r'\s*[—–]{3,}\s*$', '', line).rstrip())
        # linker Rand der Seite = kleinster häufig vorkommender Einzug langer Zeilen
        longs = [len(l) - len(l.lstrip()) for l in clean if len(l.strip()) >= 88]
        count = collections.Counter(longs)
        base = count.most_common(1)[0][0] if longs else 0
        # Seiten mit vielen kurzen Absätzen: die eingerückten Anfangszeilen überwiegen
        if longs and count.get(base - 4, 0) >= max(2, 0.25 * count[base]):
            base -= 4
        prev_blank = True
        for line in clean:
            s = line.strip()
            if not s:
                prev_blank = True
                continue
            rel = (len(line) - len(line.lstrip())) - base
            numbered = bool(NUM.match(s))
            if rel >= 8 or (rel in (1, 2, 3, 5, 6, 7) and not numbered):
                blocks.append(['H', s])
            else:
                last = blocks[-1] if blocks else None
                # "… [Matth. 10, 22; 24,\n13]: …" – Zeilenanfang mitten in einer Klammer
                open_bracket = (last is not None and last[0] == 'P' and not prev_blank
                                and last[1].count('[') > last[1].count(']') and re.match(r'^\d+\][^ ]', s))
                if last is not None and last[0] == 'P' and ((rel == 0 and not numbered) or open_bracket):
                    last[1] += ' ' + s
                else:
                    blocks.append(['P', s])
            prev_blank = False
    return blocks


# --------------------------------------------------------------------------
# Englisch: bookofconcord.org
# --------------------------------------------------------------------------

def page_blocks(name, start=None, stop=None):
    soup = BeautifulSoup(open(cache('boc', name + '.html'), encoding='utf-8').read(), 'lxml')
    main = soup.find('main')
    for d in main.find_all(class_='next-previous-box'):
        d.decompose()
    for d in main.find_all('h5'):       # redaktionelle Anmerkungen der Website
        d.decompose()
    for a in main.find_all(class_='bocanchor-content'):
        a.replace_with(NavigableString(' ' + a.get_text().strip() + '] '))
    out = [['H', '@@PAGE ' + name]]
    first_heading = True
    on = start is None
    for e in main.find_all(['h1', 'h2', 'h3', 'h4', 'p', 'li', 'blockquote']):
        if e.name in ('p', 'li') and e.find_parent(['li', 'blockquote']):
            continue
        if e.name == 'blockquote' and e.find('p'):
            continue
        t = re.sub(r'\s+', ' ', e.get_text()).strip()
        # Zutaten der Website: Querverweise, Markdown-Reste
        t = re.sub(r'\(see \[AP [^()]*\(http[^()]*\)[^()]*\(http[^()]*\)\)', '', t)
        t = re.sub(r'\[ (\d+[a-z]?)\] ', r'[\1]', t)     # "[9]" ist hier kein Absatzzähler
        t = t.replace('**', '')
        t = re.sub(r'(?<![A-Za-z])_([^_]+)_(?![A-Za-z])', r'\1', t)
        t = re.sub(r'\s+', ' ', t).strip()
        if not t:
            continue
        if e.name in ('h1', 'h2', 'h3', 'h4'):
            t = re.sub(r'^\d+[a-z]?\]\s*', '', t)
            if not on and start and re.search(start, t):
                on = True
            if stop and on and re.search(stop, t):
                break
            if not on:
                continue
            if first_heading and e.name == 'h2' and len(out) == 1 and start is None:
                first_heading = False     # Seitentitel = Abschnittstitel
                continue
            first_heading = False
            out.append(['H', t])
        elif on:
            out.append(['P', t])
    return out


# --------------------------------------------------------------------------
# Abschnitte ausschneiden
# --------------------------------------------------------------------------

def streams():
    en = []
    for b in BOOKS:
        for pg in b['en_pages']:
            en += page_blocks(*pg)
    return dict(de=layout_blocks(cache('de_layout.txt')), la=layout_blocks(cache('la_layout.txt')), en=en)


def slice_all():
    """{konfession: {abschnitt: {sprache: bloecke}}}"""
    st = streams()
    res = {}
    for li, lang in enumerate(('de', 'la', 'en')):
        bl = st[lang]
        pos = 0
        marks = []
        for b in BOOKS:
            for sec in b['sections']:
                a = sec[2 + li]
                if a is None:
                    continue
                keep = a.startswith('+')
                rx = re.compile(a.lstrip('+'))
                j = next((i for i in range(pos, len(bl)) if rx.search(bl[i][1])), None)
                if j is None:
                    raise SystemExit('Anker nicht gefunden: %s %s %s %s' % (lang, b['id'], sec[0], a))
                marks.append((j, keep, b['id'], sec[0]))
                pos = j + 1
        for n, (j, keep, cid, sid) in enumerate(marks):
            if sid is None:
                continue
            end = marks[n + 1][0] if n + 1 < len(marks) else len(bl)
            blocks = bl[j if (keep or bl[j][0] == 'P') else j + 1:end]
            # Titelzeilen des folgenden Teils: Überschriften und kurze Zeilen ohne Satzende
            while blocks and (blocks[-1][0] == 'H' or (
                    len(blocks[-1][1]) < 60 and not NUM.match(blocks[-1][1])
                    and not re.search(r'[.!?:;”"\')\]]$', blocks[-1][1]))):
                blocks = blocks[:-1]
            blocks = [x for x in blocks if not x[1].startswith('@@PAGE')]
            res.setdefault(cid, {}).setdefault(sid, {})[lang] = blocks
    return res


# --------------------------------------------------------------------------
# Klammern, Zähler, Bereinigung
# --------------------------------------------------------------------------

MARK = re.compile(r'(?<![\w\[])(\d{1,3}[a-z]?|\*|I|l)\] ?')
MARKEND = re.compile(r'(?:^|[^\w\[])(\d{1,3}[a-z]?|\*|I|l)$')
DROP_H = [
    re.compile(r'^\(?(More )?[Ss]ignatures'),
    re.compile(r'^(Antwort|Responsio|Answer)[.:]?$'),
    re.compile(r'^(I|II|III|IV|V|VI|VII)\.$'),
]


# Zahl am Klammerende, die zu einer Stellenangabe gehört ("[Matth. 10, 22; 24, 13]",
# "[Röm. 7 und 8]", "[Ps. 119]") – im Unterschied zu einem Absatzzähler.
REF_BEFORE = re.compile(
    r'(?:\d\s*[,.;:]|\b(?:und|et|and|u\.|sq\.|sqq\.|v\.|V\.|Kap\.|Cap\.|cap\.)'
    r'|\b(?:Ps|Matth|Matt|Marc|Mark|Luc|Luk|Joh|Ioh|Act|Apg|Röm|Rom|Kor|Cor|Gal|Eph|Phil|Kol|Col|Thess|Tim|Tit'
    r'|Petr|Pet|Hebr|Ebr|Jak|Iac|Mos|Gen|Exod|Jes|Esa|Jer|Dan|Offenb|Apoc)\.)\s*$')
KEEP_STAR_FROM = 400


def strip_brackets(t, log=None, tag=''):
    """Entfernt [..] samt Inhalt (auch verschachtelt und über Absätze hinweg).

    * "(..]" gilt als Druck-/Tippfehler für "[..]".
    * Ein Absatzzähler innerhalb einer Klammer ("[… so wäre 20] E.K.M. …]")
      schließt die Klammer nicht.
    * Mit "[*" gekennzeichnete längere Ergänzungen (Text, der im Konkordienbuch
      von 1580 fehlt und aus den Erstdrucken ergänzt ist) bleiben stehen.
    Auffälligkeiten kommen ins Protokoll."""
    out = []
    stack = []  # (zeichen, position in out)
    for ch in t:
        if ch in '[(':
            stack.append((ch, len(out)))
            out.append(ch)
        elif ch == ']':
            tail = ''.join(out[-8:])
            m = MARKEND.search(tail)
            inside = any(c == '[' for c, _ in stack)
            if m and not inside:
                out.append(ch)          # Absatzzähler "12]"
            elif m and inside and m.group(1).isdigit() and not REF_BEFORE.search(
                    re.sub(r'\x00[HP] ', ' ', ''.join(out[-40:]))[:-len(m.group(1))]):
                del out[len(out) - len(m.group(1)):]     # Zähler in der Klammer
            elif stack and stack[-1][0] == '[':
                _, i = stack.pop()
                span = ''.join(out[i:])
                if span.startswith('[*') and len(span) >= KEEP_STAR_FROM:
                    out[i:] = list(span[2:].lstrip())
                    if log is not None:
                        log.append((tag, 'ERGÄNZUNG BEHALTEN', span[:100] + ' … ' + span[-60:]))
                else:
                    if log is not None and len(span) > 1500:
                        log.append((tag, 'LANG', span[:120] + ' … ' + span[-120:]))
                    del out[i:]
            elif stack and stack[-1][0] == '(' and not inside:
                _, i = stack.pop()
                if log is not None:
                    log.append((tag, 'RUNDE KLAMMER', ''.join(out[max(0, i - 60):i]) + ' >>' + ''.join(out[i:]) + ']'))
                del out[i:]
            elif log is not None:
                log.append((tag, 'EINZELNE ]', ''.join(out[-200:])))
        elif ch == ')':
            if stack and stack[-1][0] == '(':
                stack.pop()
                out.append(ch)
            elif (stack and stack[-1][0] == '[' and len(out) - stack[-1][1] <= 400
                  and not re.search(r'(?:^|\s)[0-9a-z]$', ''.join(out[-2:]))):
                # "[..)" – Tippfehler für "[..]"
                _, i = stack.pop()
                if log is not None:
                    log.append((tag, 'RUNDE KLAMMER', ''.join(out[max(0, i - 60):i]) + ' >>' + ''.join(out[i:]) + ')'))
                del out[i:]
            else:
                out.append(ch)
        else:
            out.append(ch)
    for c, i in stack:
        if c == '[' and log is not None:
            log.append((tag, 'OFFENE [', ''.join(out[max(0, i - 100):i + 200])))
    return ''.join(out)


def german_fixes(t):
    """Systematische Fehler der elektronischen Ausgabe: ue->ü, HErr->Her, JEsus->Jeus."""
    t = re.sub(r'([aeäAEÄ])ü', r'\1ue', t)
    t = re.sub(r'([qQ])ü', r'\1ue', t)
    t = t.replace('Ë', 'Ä')
    t = re.sub(r'\bJeus\b', 'Jesus', t)
    t = re.sub(r'\bJeum\b', 'Jesum', t)
    t = re.sub(r'\bJeu\b', 'Jesu', t)
    t = re.sub(r'\bHern\b', 'Herrn', t)
    t = re.sub(r'\bHer\b', 'Herr', t)
    t = re.sub(r'\bH[EE]rr', 'Herr', t)
    t = re.sub(r'\bHERR', 'Herr', t)
    t = re.sub(r'\bJE([sS])', r'Je\1', t)
    return t


def tidy(t, lang):
    t = t.replace(' ', ' ')
    t = re.sub(r'\s+', ' ', t)
    t = re.sub(r' +([,.;:!?])', r'\1', t)
    t = re.sub(r'\( +', '(', t)
    t = re.sub(r' +\)', ')', t)
    t = t.replace('()', '')
    # fehlendes Leerzeichen nach Satzzeichen ("ist.Danach", "sagen:Das")
    t = re.sub(r'([a-zäöüß][.:;!?])([A-ZÄÖÜ][a-zäöü])', r'\1 \2', t)
    t = re.sub(r'([a-zäöüß],)([A-Za-zÄÖÜäöü])', r'\1 \2', t)
    t = re.sub(r'\s+', ' ', t).strip()
    t = t.replace('’', "'").replace('‘', "'")
    t = re.sub(r'(?<=[a-z])—(?=[a-z])', ' ', t)      # "apud—nos"
    if lang == 'de':
        t = german_fixes(t)
        # Anführungszeichen wie im übrigen Datenbestand: „ … “
        t = t.replace('“', '„').replace('”', '“')
    if lang == 'en':
        # Bibelstellen in der Schreibweise des Drucks ("Rom. 3, 28")
        t = re.sub(r'(\d+):(\d+)', r'\1, \2', t)
    return t


def render(blocks, lang, log=None, tag='', drop_headings=False):
    sep = chr(0)
    # Zähler mitten im getrennten Wort ("matrimo81] nialia")
    blocks = [(k, re.sub(r'(?<=[a-zäöü])\d{1,3}\] (?=[a-zäöü])', '', t)) for k, t in blocks]
    blocks = apply_patches(blocks, lang, tag)
    joined = strip_brackets(sep.join(k + ' ' + t for k, t in blocks), log, tag)
    blocks = [(x[0], x[2:]) for x in joined.split(sep) if x[2:].strip()]
    paras = []
    heads = []
    for kind, text in blocks:
        if kind == 'H':
            if drop_headings:
                continue
            h = MARK.sub('', text)
            h = re.sub(r'\s*[—–-]\s*(Antwort|Responsio|Answer)[.:]?$', '', h)
            h = tidy(h, lang)
            if h and not any(r.search(h) for r in DROP_H):
                heads.append(h)
            continue
        # Absatz an Zählern teilen, vor denen ein Satz endet
        pieces = []
        last = 0
        for m in MARK.finditer(text):
            before = text[:m.start()].rstrip()
            if before and before[-1] in '.?!”"' and m.start() > last:
                pieces.append(text[last:m.start()])
                last = m.start()
        pieces.append(text[last:])
        for p in pieces:
            p = tidy(MARK.sub('', p), lang)
            if not p:
                continue
            if heads:
                p = '\n'.join(heads) + '\n' + p
                heads = []
            paras.append(p)
    if heads:
        paras.append('\n'.join(heads))
    return '\n\n'.join(paras)
