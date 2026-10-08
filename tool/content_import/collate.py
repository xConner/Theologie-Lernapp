# -*- coding: utf-8 -*-
"""Wort-für-Wort-Abgleich eines Basistextes mit Texterkennungen des Drucks.

Der Basistext (elektronische Ausgabe bzw. bookofconcord.org) liefert Gliederung
und Interpunktion. Einzelne Wörter werden nach dem Druck berichtigt, wenn die
Texterkennungen übereinstimmend etwas anderes lesen. Die Regeln sind bewusst
zurückhaltend: im Zweifel bleibt die Basis stehen und der Fall kommt ins
Protokoll.
"""
import bisect
import collections
import difflib
import os
import re

from common import cache

WORD = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)?")
UMLAUT = str.maketrans('äöüÄÖÜ', 'aouAOU')


def norm_word(w, lang):
    w = w.replace('ſ', 's').replace('ꝛ', 'r').replace('’', "'")
    if lang == 'de':
        # HErr, JEsus, GOtt -> Herr, Jesus, Gott
        m = re.match(r'^([A-ZÄÖÜ])([A-ZÄÖÜ])([a-zäöüß].*)$', w)
        if m:
            w = m.group(1) + m.group(2).lower() + m.group(3)
    if lang == 'la':
        w = w.replace('æ', 'ae').replace('œ', 'oe').replace('Æ', 'Ae').replace('Œ', 'Oe')
    return w


def clean_ocr(text):
    """OCR-Text -> Fließtext: Silbentrennung auflösen, Randverweise, Zähler und
    Klammerzusätze entfernen (wie im Basistext)."""
    t = text.replace('⸗', '-').replace('¬', '-')
    t = re.sub(r'\[?\b[RMW]\. ?\d+[\d., ]*\]?', ' ', t)          # Seitenkonkordanz am Rand
    t = re.sub(r'([^\W\d_])[-=]\s*\n\s*([^\W\d_])',
               lambda m: m.group(1) + m.group(2) if (m.group(2).islower() or m.group(2) == 'ſ')
               else m.group(1) + '-' + m.group(2), t)
    t = re.sub(r'\b\d{1,3}\]', ' ', t)
    t = re.sub(r'\[[^\[\]]{0,300}\]', ' ', t)
    return t.replace('[', ' ').replace(']', ' ')


def tokens(text, lang):
    return [norm_word(m.group(0), lang) for m in WORD.finditer(text)]


def base_tokens(text, lang):
    return [(m.start(), m.end(), norm_word(m.group(0), lang)) for m in WORD.finditer(text)]


def fold(w):
    return w.casefold().replace('ß', 'ss')


# --------------------------------------------------------------------------
# Zeugen
# --------------------------------------------------------------------------

def leaf_stream(item, model, lang, lo, hi, step):
    parts = []
    for n in range(lo, hi, step):
        f = cache('ocr', item, 'n%d.%s.txt' % (n, model))
        if os.path.exists(f):
            parts.append(clean_ocr(open(f, encoding='utf-8').read()))
    return tokens('\n'.join(parts), lang)


def file_stream(path, lang):
    return tokens(clean_ocr(open(path, encoding='utf-8', errors='replace').read()), lang)


# --------------------------------------------------------------------------
# Ausrichtung
# --------------------------------------------------------------------------

def lis(pairs):
    """Längste nach j aufsteigende Teilfolge (pairs nach i sortiert)."""
    tails = []
    tails_idx = []
    prev = [-1] * len(pairs)
    for n, (_, j) in enumerate(pairs):
        k = bisect.bisect_left(tails, j)
        if k == len(tails):
            tails.append(j)
            tails_idx.append(n)
        else:
            tails[k] = j
            tails_idx[k] = n
        prev[n] = tails_idx[k - 1] if k > 0 else -1
    out = []
    n = tails_idx[-1] if tails_idx else -1
    while n >= 0:
        out.append(pairs[n])
        n = prev[n]
    return out[::-1]


class Witness:
    """Wortliste eines Zeugen mit Index seiner eindeutigen Vierwortfolgen."""

    K = 4

    def __init__(self, words):
        self.words = words
        self.folded = [fold(w) for w in words]
        self.vocab = collections.Counter(words)
        grams = collections.defaultdict(list)
        f = self.folded
        for i in range(len(f) - self.K + 1):
            g = (f[i], f[i + 1], f[i + 2], f[i + 3])
            lst = grams[g]
            if len(lst) < 2:
                lst.append(i)
        self.unique = {g: v[0] for g, v in grams.items() if len(v) == 1}

    def align(self, base):
        """Operationen (art, i1, i2, j1, j2) in sicher verankerten Bereichen."""
        k = self.K
        fb = [fold(w) for w in base]
        fw = self.folded
        seen = collections.Counter(tuple(fb[i:i + k]) for i in range(len(fb) - k + 1))
        pairs = []
        for i in range(len(fb) - k + 1):
            g = tuple(fb[i:i + k])
            if seen[g] == 1 and g in self.unique:
                pairs.append((i, self.unique[g]))
        blocks = []
        for i, j in lis(pairs):
            if blocks and (i < blocks[-1][0] + blocks[-1][2] or j < blocks[-1][1] + blocks[-1][2]):
                continue
            # Ausreißer: Anker weit weg vom bisherigen Verlauf
            if blocks and j - (blocks[-1][1] + blocks[-1][2]) > 4000 + 3 * (i - blocks[-1][0]):
                continue
            a, b = i, j
            lo_i = blocks[-1][0] + blocks[-1][2] if blocks else 0
            lo_j = blocks[-1][1] + blocks[-1][2] if blocks else 0
            while a > lo_i and b > lo_j and fb[a - 1] == fw[b - 1]:
                a -= 1
                b -= 1
            n = (i - a) + k
            while a + n < len(fb) and b + n < len(fw) and fb[a + n] == fw[b + n]:
                n += 1
            blocks.append((a, b, n))
        ops = []
        pi = pj = None
        for a, b, n in blocks:
            if pi is not None and (a > pi or b > pj):
                if a - pi <= 40 and b - pj <= 60:
                    sm = difflib.SequenceMatcher(None, fb[pi:a], fw[pj:b], autojunk=False)
                    for tag, i1, i2, j1, j2 in sm.get_opcodes():
                        t = {'equal': 'eq', 'replace': 'sub', 'insert': 'ins', 'delete': 'del'}[tag]
                        ops.append((t, pi + i1, pi + i2, pj + j1, pj + j2))
            ops.append(('eq', a, a + n, b, b + n))
            pi, pj = a + n, b + n
        return ops

    def readings(self, base):
        """Je Basiswort: Wort des Zeugen | '' (fehlt dort) | ('JOIN', n, wörter) | None
        (nicht verankert); dazu {i: [im Zeugen vor Basiswort i zusätzlich stehende Wörter]}."""
        r = [None] * len(base)
        ins = {}
        w = self.words
        for tag, i1, i2, j1, j2 in self.align(base):
            if tag == 'eq' or (tag == 'sub' and i2 - i1 == j2 - j1):
                for n in range(i2 - i1):
                    r[i1 + n] = w[j1 + n]
            elif tag == 'sub':
                r[i1] = ('JOIN', i2 - i1, w[j1:j2])
            elif tag == 'ins':
                ins[i1] = w[j1:j2]
            elif tag == 'del':
                for n in range(i1, i2):
                    r[n] = ''
        return r, ins


def edit_distance(a, b):
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[-1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


# --------------------------------------------------------------------------
# Entscheidung
# --------------------------------------------------------------------------

def collate(text, lang, witnesses, independent=0, stats=None, log=None, tag='', lexicon=None):
    """Berichtigt ``text`` nach den Zeugen (beste zuerst).

    ``independent``: Zahl der ersten Zeugen, die auf verschiedenen Scans beruhen.
    ``lexicon``: Wortzählung des gesamten Basistextes; schützt davor, einen
    Druckfehler (z. B. "unkown") zu übernehmen, den beide Scans gleich zeigen.

    Ein Basiswort wird nur ersetzt, wenn kein Zeuge es bestätigt und
      * mindestens zwei Zeugen dieselbe andere Lesart haben, die im Druck auch
        sonst vorkommt, oder
      * ein einzelner Zeuge ein im Druck geläufiges Wort liest, während das
        Basiswort im Druck nirgends vorkommt, oder
      * nur ss/ß betroffen ist.
    Ein im Zeugen fehlender Umlaut gilt nie als Berichtigung (typischer
    Lesefehler). Ganze Wörter werden nur eingefügt, wenn zwei Zeugen dasselbe
    geläufige Einzelwort zwischen bestätigten Nachbarn lesen; gestrichen wird
    nichts."""
    bt = base_tokens(text, lang)
    base = [w for _, _, w in bt]
    rs = [w.readings(base) for w in witnesses]
    v0 = witnesses[0].vocab
    total = collections.Counter()
    for w in witnesses:
        total.update(w.vocab)

    def trusted(w):
        return v0[w] >= 2 or sum(1 for x in witnesses if x.vocab[w] >= 2) >= 2

    def known(w):
        return lexicon is None or lexicon[w] >= 1

    def spelling_variant(b):
        """Deutsch: systematische Schreibfehler der elektronischen Ausgabe
        (ss für ß, ü für ue, ß für sz). Liefert die Schreibung des Drucks,
        wenn das Basiswort dort nie vorkommt und genau eine Variante belegt ist."""
        if lang != 'de' or total[b] > 0:
            return None
        found = set()
        for old, new in (('ss', 'ß'), ('ü', 'ue'), ('ß', 'sz'), ('ß', 'ss')):
            parts = b.split(old)
            if len(parts) == 1 or len(parts) > 4:
                continue
            for mask in range(1, 2 ** (len(parts) - 1)):
                v = parts[0]
                for k in range(1, len(parts)):
                    v += (new if mask >> (k - 1) & 1 else old) + parts[k]
                if total[v] >= 2:
                    found.add(v)
        return found.pop() if len(found) == 1 else None

    st = stats if stats is not None else collections.Counter()
    edits = []
    for i, (s, e, b) in enumerate(bt):
        raw = text[s:e]
        cands = [r[0][i] for r in rs]
        words = [c for c in cands if isinstance(c, str) and c != '']
        if b not in words:
            v = spelling_variant(b)
            if v is not None and (not words or v in words or len(set(words)) > 1):
                edits.append((s, e, v))
                st['schreibvariante'] += 1
                if log is not None:
                    log.append((tag, raw, v, 'schreibvariante'))
                continue
        if not words:
            st['unverankert' if all(c is None for c in cands) else 'unklar'] += 1
            # "eig entlich" -> "eigentlich"
            joins = [c for c in cands if isinstance(c, tuple)]
            if joins and len(joins) == len([c for c in cands if c is not None]):
                n, ws = joins[0][1], joins[0][2]
                if all(j[1] == n and j[2] == ws for j in joins) and len(ws) == 1 and i + n <= len(bt):
                    joined = ''.join(x[2] for x in bt[i:i + n])
                    if fold(joined) == fold(ws[0]) and trusted(ws[0]):
                        edits.append((s, bt[i + n - 1][1], ws[0]))
                        st['zusammengezogen'] += 1
                        if log is not None:
                            log.append((tag, text[s:bt[i + n - 1][1]], ws[0], 'zusammengezogen'))
                    continue
            # Mehrere verdorbene Wörter ("Sicut tui. sit me" für "Sicut misit me"):
            # zwei Scans lesen an derselben Stelle dieselbe andere Wortfolge.
            if independent >= 2:
                ind = [c for c in cands[:independent] if isinstance(c, tuple)]
                if len(ind) >= 2 and all(c[1] == ind[0][1] and c[2] == ind[0][2] for c in ind):
                    n, ws = ind[0][1], ind[0][2]
                    old = [x[2] for x in bt[i:i + n]]
                    if (1 <= len(ws) <= 4 and n <= 4 and i + n <= len(bt) and all(known(w) for w in ws)
                            and any(total[o] == 0 for o in old)
                            and edit_distance(fold(''.join(old)), fold(''.join(ws))) <= max(3, len(''.join(ws)) // 2)):
                        edits.append((s, bt[i + n - 1][1], ' '.join(ws)))
                        st['wortfolge'] += 1
                        if log is not None:
                            log.append((tag, text[s:bt[i + n - 1][1]], ' '.join(ws), 'wortfolge'))
            continue
        if b in words:
            st['bestaetigt'] += 1
            continue
        cnt = collections.Counter(words)
        w, n = cnt.most_common(1)[0]
        if len(cnt) > 1 and n == 1:
            good = [x for x in cnt if trusted(x)]
            if len(good) == 1:
                w = good[0]
            else:
                st['zeugen_uneins'] += 1
                if log is not None:
                    log.append((tag, raw, '/'.join(words), 'UNEINS'))
                continue
        d = edit_distance(fold(b), fold(w))
        size = max(len(b), len(w))
        close = d <= max(2, int(0.4 * size))
        indep = independent >= 2 and sum(1 for k in range(min(independent, len(cands))) if cands[k] == w) >= 2
        if indep:
            close = d <= max(3, int(0.6 * size))
        if lang == 'de' and b.translate(UMLAUT) == w.translate(UMLAUT) and \
                sum(c in 'äöüÄÖÜ' for c in b) > sum(c in 'äöüÄÖÜ' for c in w):
            close = False
        case_only = b.casefold() == w.casefold()
        eszett = not case_only and fold(b) == fold(w)
        kind = None
        if case_only:
            if n >= 2 or (total[b] == 0 and trusted(w)):
                kind = 'grossschreibung'
        elif eszett:
            if trusted(w) or n >= 2 or total[b] == 0:
                kind = 'eszett'
        elif close and n >= 2 and (
                # das Basiswort kommt im Druck überhaupt nicht vor
                (total[b] == 0 and total[w] >= 2)
                # oder die Lesart ist ein Wort, das auch der Basistext kennt
                or (known(w) and (trusted(w) or indep))):
            kind = 'wort'
        elif close and n == 1 and total[b] == 0 and trusted(w) and (known(w) or (lang == 'de' and d <= 2)):
            kind = 'wort_ein_zeuge'
        if kind:
            edits.append((s, e, w))
            st[kind] += 1
            if log is not None:
                log.append((tag, raw, w, kind))
        else:
            st['offen'] += 1
            if log is not None:
                log.append((tag, raw, '/'.join(words), 'OFFEN n=%d basis=%d lesart=%d' % (n, total[b], total[w])))
    if len(rs) >= 2:
        seen = set()
        for r in rs:
            for i, ws in r[1].items():
                if i in seen or len(ws) != 1 or i >= len(bt) or i == 0:
                    continue
                w = ws[0]
                if sum(1 for q in rs if q[1].get(i) == ws) < 2 or not (v0[w] >= 20 and w[0].islower()):
                    continue
                solid = sum(1 for q in rs if isinstance(q[0][i], str) and q[0][i]
                            and isinstance(q[0][i - 1], str) and q[0][i - 1])
                if solid >= 2:
                    seen.add(i)
                    edits.append((bt[i][0], bt[i][0], w + ' '))
                    st['eingefuegt'] += 1
                    if log is not None:
                        log.append((tag, '', w, 'EINGEFUEGT vor ' + bt[i][2]))
    for i, (s, e, b) in enumerate(bt):
        if sum(1 for r in rs if r[0][i] == '') >= 2:
            st['nur_in_basis'] += 1
            if log is not None:
                log.append((tag, text[s:e], '', 'NUR IN BASIS'))
    out = []
    pos = 0
    for s, e, rep in sorted(edits):
        if s < pos:
            continue
        out.append(text[pos:s])
        out.append(rep)
        pos = e
    out.append(text[pos:])
    return ''.join(out)
