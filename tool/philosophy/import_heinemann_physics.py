#!/usr/bin/env python3
"""Erzeugt aus der eigenen Kopie von Heinemanns Ausgabe der Physikvorlesung
(Aristoteles, Physikvorlesung, Teilband 1: Bücher I–IV, Griechisch–Deutsch,
Felix Meiner Verlag 2021, PhB, ISBN 978-3-7873-3870-2) eine private
Lesedatei für den Lesebereich „Aristoteles – Physik“.

Die Ausgabe ist urheberrechtlich geschützt. Weder die Textdatei noch das
Ergebnis gehören ins Repository oder in die App-Assets: Das Ergebnis wird in
der App über „Eigene Ausgabe importieren“ geladen und nur im eigenen Konto
bzw. auf dem eigenen Gerät gespeichert (docs/philosophy-reader.md).

Eingabe: Textebene des E-Books (pdftotext o. Ä.), wie sie die Bibliothek
liefert. Aufruf:

    python3 tool/philosophy/import_heinemann_physics.py EINGABE.txt AUSGABE.json

Das Skript verändert keinen Wortlaut. Es setzt nur getrennte Zeilen wieder
zusammen, ordnet griechische Sätze den Zeilen der Bekker-Ausgabe zu (aus
Seitenkopf, Zeilenzahl und Randmarken der Ausgabe) und bildet Abschnitte an
den Zeilenmarken, die Heinemann in die Übersetzung setzt („a12“). Wo die
Zuordnung nur ungefähr möglich ist, steht das im Ergebnis (`fit`).
"""

import json
import re
import sys
import unicodedata
from statistics import median

WORK = "aristotle.physics"
EDITION = "heinemann-2021"

GREEK_RE = re.compile(r"[Ͱ-Ͽἀ-῿]")
LATIN_RE = re.compile(r"[A-Za-zÄÖÜäöüß]")
GREEK_HEADER = re.compile(
    r"^(\d+) ([ABΓ∆Δ]) [\d|]+ · (\d+)([ab]) (\d+) –(\d+)([ab]) (\d+)$"
)
GERMAN_HEADER = re.compile(r"^Buch ([IV]+) · Kapitel [\d–]+ (\d+)$")
NOTES_HEADER = re.compile(
    r"^(?:(\d+) Anmerkungen · Buch [IV]+ · Kapitel [\d–]+|Anmerkungen · Buch [IV]+ · Kapitel [\d–]+ (\d+))$"
)
MARGIN = re.compile(r"^(?:\d{3}[ab])?\d{0,2}$|^[ab]?\d{1,2}(?:,[ab]?\d{1,2})+$")
WATERMARK = ("FOR PRIVATE USE ONLY", "Generated for ", "DOI https://doi.org/")
BOOK_LETTERS = {"A": 1, "B": 2, "Γ": 3, "∆": 4, "Δ": 4}
ROMAN = {"I": 1, "II": 2, "III": 3, "IV": 4}


# ---------------------------------------------------------------------------
# Bekker-Stellen
# ---------------------------------------------------------------------------


class Ref:
    """Bekker-Stelle: Seite, Spalte, Zeile (z. B. 184a10)."""

    __slots__ = ("page", "col", "line")

    def __init__(self, page, col, line):
        self.page, self.col, self.line = int(page), col, int(line)

    def __str__(self):
        return f"{self.page}{self.col}{self.line}"

    def key(self):
        return (self.page, 0 if self.col == "a" else 1, self.line)

    def next_line(self):
        return Ref(self.page, self.col, self.line + 1)


def parse_ref(text):
    m = re.fullmatch(r"(\d{3})([ab])(\d{1,2})", text)
    return Ref(*m.groups()) if m else None


def ref_key(text):
    return parse_ref(text).key()


# ---------------------------------------------------------------------------
# Einlesen
# ---------------------------------------------------------------------------


def read_lines(path):
    with open(path, encoding="utf-8") as f:
        raw = f.read().split("\n")
    # \x02 steht in der Textebene für eine aufgelöste Silbentrennung.
    lines = [unicodedata.normalize("NFC", l.replace("\x02", "")) for l in raw]
    # Das Wasserzeichen steht meist auf eigenen Zeilen, manchmal mitten im
    # Wort („KalFOR PRIVATE USE ONLY | … GEBRAUCHtem“).
    lines = [l.replace("FOR PRIVATE USE ONLY | AUSSCHLIESSLICH ZUM PRIVATEN GEBRAUCH", "") for l in lines]
    return [l for l in lines if not l.startswith(WATERMARK) and l.strip() != ""
            or l == ""]


def find(lines, predicate, start=0):
    for i in range(start, len(lines)):
        if predicate(lines[i]):
            return i
    raise ValueError("nicht gefunden")


def join_lines(lines):
    """Setzt Zeilen wieder zusammen. Die Textebene trennt Wörter ohne
    Trennstrich: Endet eine Zeile mit einem Buchstaben ohne Leerzeichen, geht
    das Wort in der nächsten Zeile weiter."""
    out = ""
    for line in lines:
        if not out:
            out = line
        elif out.endswith((" ", "-", "–", "—")) or not out[-1].isalpha():
            if out.endswith((" ",)) or not out[-1].isalpha():
                out = out.rstrip() + " " + line.lstrip()
            else:
                out += line
        else:
            out += line
    return re.sub(r"\s+", " ", out).strip()


def greek_ratio(line):
    g = len(GREEK_RE.findall(line))
    l = len(LATIN_RE.findall(line))
    return g / (g + l) if g + l else 0.0


# ---------------------------------------------------------------------------
# Textteil: Seiten trennen
# ---------------------------------------------------------------------------


def split_pages(lines):
    """Liefert (griechische Seiten, deutsche Seiten) als Listen von Dicts."""
    start = find(lines, lambda l: GREEK_HEADER.match(l))
    end = find(lines, lambda l: l == "ANMERKUNGEN DES HERAUSGEBERS", start)
    greek, german = [], []
    current = None
    for line in lines[start:end]:
        gm = GREEK_HEADER.match(line)
        dm = GERMAN_HEADER.match(line)
        if gm:
            num, letter, sp, sc, sl, ep, ec, el = gm.groups()
            current = {
                "kind": "grc",
                "page": int(num),
                "book": BOOK_LETTERS[letter],
                "start": Ref(sp, sc, sl),
                "end": Ref(ep, ec, el),
                "lines": [],
            }
            greek.append(current)
        elif dm:
            current = {
                "kind": "de",
                "page": int(dm.group(2)),
                "lines": [],
            }
            german.append(current)
        elif current is not None:
            current["lines"].append(line)
    return greek, german


# ---------------------------------------------------------------------------
# Griechische Seiten: Zeilen, Fußnoten, Zeilenzählung
# ---------------------------------------------------------------------------

FOOTNOTE_START = re.compile(r"(?:^|(?<=[\sͰ-Ͽἀ-῿]))(\d{1,2}(?:–\d{1,2})?) (?=Ross|Text|Mit |Der |Die |Mss|Bekker|Hier|Ich |Zu |Gegen|Statt|Vgl|Wie |Nach |Mit\b|Ohne|Überl|Die )")


def clean_greek_page(page):
    """Trennt Text, Randmarken und Fußnoten einer griechischen Seite."""
    text, notes = [], []
    in_notes = False
    for line in page["lines"]:
        s = line.strip()
        if not s:
            continue
        if MARGIN.match(s):
            continue
        if s.startswith("ΦΥΣΙΚΗΣ ΑΚΡΟΑΣΕΩΣ") or re.fullmatch(r"[ΑΒΓΔ∆]\.", s):
            page["book_start"] = True
            continue
        if not in_notes:
            m = FOOTNOTE_START.search(s)
            if m:
                head = s[: m.start()].rstrip()
                if head:
                    text.append(head)
                notes.append(s[m.start():])
                in_notes = True
                continue
            if greek_ratio(s) < 0.4 and LATIN_RE.search(s):
                notes.append(s)
                in_notes = True
                continue
            # Randmarke an das Zeilenende geklebt („γεω20“).
            s = re.sub(r"(?<=[Ͱ-Ͽἀ-῿’])\d{1,2}$", "", s)
            text.append(s)
        else:
            notes.append(s)
    page["text"] = text
    page["notes"] = notes


def physical_lines(page):
    """Zeilen der Seite als (Text, zählt_als_neue_Zeile). Eine kurze Zeile am
    Absatzanfang (z. B. „τὸ μὲν“) steht in der Ausgabe auf derselben
    Bekker-Zeile wie die folgende; zu lang geratene Zeilen (zwei Druckzeilen in
    einer Zeile der Textebene) werden an Wortgrenzen geteilt."""
    lines = page["text"]
    lengths = [len(l) for l in lines if len(l) > 25]
    typical = median(lengths) if lengths else 58
    result = []
    for i, line in enumerate(lines):
        if len(line) < 22 and i + 1 < len(lines):
            result.append((line, False))
            continue
        parts = max(1, round(len(line) / typical))
        if parts == 1:
            result.append((line, True))
            continue
        words = line.split(" ")
        chunk, chunks = [], []
        target = len(line) / parts
        for w in words:
            chunk.append(w)
            if len(" ".join(chunk)) >= target and len(chunks) < parts - 1:
                chunks.append(" ".join(chunk))
                chunk = []
        if chunk:
            chunks.append(" ".join(chunk))
        for c in chunks:
            result.append((c, True))
    return result, typical


def assign_lines(page):
    """Ordnet jeder Zeile der Seite eine Bekker-Stelle zu; Ergebnis
    page["refs"] parallel zu page["phys"]. `exact` ist False, wenn die
    Zeilenzahl der Seite nicht zum Seitenkopf passt."""
    phys, _ = physical_lines(page)
    counting = [i for i, (_, inc) in enumerate(phys) if inc]
    s, e = page["start"], page["end"]
    n = len(counting)
    if (s.page, s.col) == (e.page, e.col):
        expected = e.line - s.line + 1
        col_break = None
    else:
        # Neue Spalte: Zeilen 1..e.line (bzw. ab 10 am Werkanfang, ohne
        # Bedeutung hier, weil das nur 184a/b betrifft).
        second = e.line if e.line < 40 else 0
        first_col_start = 10 if (e.page, e.col) == (184, "b") else 1
        second = e.line - first_col_start + 1
        col_break = n - second
        expected = n
    exact = n == expected
    refs = [None] * len(phys)
    current = None
    k = 0
    for i, (_, inc) in enumerate(phys):
        if inc:
            if col_break is not None and k >= col_break:
                first_col_start = 10 if (e.page, e.col) == (184, "b") else 1
                current = Ref(e.page, e.col, first_col_start + (k - col_break))
            else:
                current = Ref(s.page, s.col, s.line + k)
            k += 1
        refs[i] = current if current is not None else s
    # Kurze Absatzzeilen gehören zur folgenden Zeile.
    for i in range(len(phys) - 2, -1, -1):
        if not phys[i][1]:
            refs[i] = refs[i + 1]
    page["phys"] = [t for t, _ in phys]
    page["refs"] = refs
    page["exact"] = exact and (col_break is None or col_break >= 0)


def page_line_ref(page, number):
    """Seitenbezogene Zeilenzahl einer Fußnote → Bekker-Stelle."""
    s, e = page["start"], page["end"]
    if (s.page, s.col) == (e.page, e.col):
        return Ref(s.page, s.col, number), True
    if number >= s.line:
        ambiguous = number <= e.line
        return Ref(s.page, s.col, number), not ambiguous
    return Ref(e.page, e.col, number), True


def parse_textcrit(page):
    text = join_lines(page["notes"])
    if not text:
        return []
    parts = re.split(r"(?:^|(?<=[.)\]»\s]))\s*(?=(?:\d{1,2}(?:–\d{1,2})?) (?:Ross|Text|Mit |Der |Die |Mss|Bekker|Hier|Ich |Zu |Gegen|Statt|Vgl|Wie |Nach |Ohne|Überl))", text)
    out = []
    for part in parts:
        part = part.strip()
        m = re.match(r"(\d{1,2})(?:–(\d{1,2}))? (.*)", part, re.S)
        if not m:
            if out:
                out[-1]["text"] += " " + part
            continue
        a, b, body = m.groups()
        start, sure = page_line_ref(page, int(a))
        end = page_line_ref(page, int(b))[0] if b else start
        if b and end.key() < start.key():
            end = Ref(start.page, start.col, int(b))
        out.append({
            "id": f"tc.{start}",
            "from": str(start),
            "to": str(end),
            "lines": f"{a}–{b}" if b else a,
            "text": body.strip(),
            "page": page["page"],
            "fit": "exact" if sure else "approx",
        })
    # Doppelte IDs (zwei Fußnoten zur selben Zeile) unterscheiden.
    seen = {}
    for item in out:
        n = seen.get(item["id"], 0)
        seen[item["id"]] = n + 1
        if n:
            item["id"] += f".{n + 1}"
    return out


# ---------------------------------------------------------------------------
# Griechischer Text eines Buchs → Sätze mit Zeilen
# ---------------------------------------------------------------------------

SENTENCE_END = re.compile(r"[.;;··](?:[)\]〉]*)$")


PROCLITICS = {"ὁ", "ἡ", "οἱ", "αἱ", "ἐν", "εἰς", "ἐς", "ἐκ", "ἐξ", "οὐ", "οὐκ", "οὐχ", "ὡς", "εἰ"}
ACCENTS = {"\u0301", "\u0300", "\u0342"}


def is_fragment(token):
    """Ein Wortanfang ohne Akzent am Zeilenende ist abgetrennt (die
    Textebene setzt keinen Trennstrich); Proklitika tragen keinen Akzent."""
    word = re.sub(r"[^\w\u0370-\u03FF\u1F00-\u1FFF]", "", token)
    if not word or not GREEK_RE.match(token[-1]):
        return False
    if word in PROCLITICS:
        return False
    decomposed = unicodedata.normalize("NFD", word)
    return not any(ch in ACCENTS for ch in decomposed)


def greek_words(pages):
    """Liefert alle Wörter eines Buchs mit Bekker-Stelle und Seite."""
    words = []
    join_next = False
    for page in pages:
        for text, ref in zip(page["phys"], page["refs"]):
            tokens = []
            for tok in text.split():
                if tok == "|":
                    # Spaltenwechsel innerhalb der Zeile (Randmarke „a35,b1“).
                    continue
                # Kapitelzahl ohne Leerzeichen an das Satzende geklebt
                # („του.6.“).
                m = re.fullmatch(r"(.+?[.;·\u0387])(\d{1,2}\.)", tok)
                tokens.extend(m.groups() if m else [tok])
            for j, tok in enumerate(tokens):
                if join_next and j == 0 and words:
                    words[-1]["t"] += tok
                    join_next = False
                    continue
                words.append({"t": tok, "r": ref, "p": page["page"]})
            join_next = bool(tokens) and is_fragment(tokens[-1])
    return words


def split_chapters_greek(words, book):
    """Teilt die Wortliste an den Kapitelzahlen („2. Ἀνάγκη“)."""
    chapters = [[]]
    expected = 2
    for i, w in enumerate(words):
        if w["t"] == f"{expected}." and i + 1 < len(words) and GREEK_RE.match(words[i + 1]["t"][0]):
            chapters.append([])
            expected += 1
            continue
        if w["t"] == "1." and not chapters[0] and i == 0:
            continue
        chapters[-1].append(w)
    return chapters


def greek_sentences(words):
    sentences, current = [], []
    for w in words:
        current.append(w)
        if SENTENCE_END.search(w["t"]):
            sentences.append(current)
            current = []
    if current:
        sentences.append(current)
    return sentences


# ---------------------------------------------------------------------------
# Deutsche Übersetzung
# ---------------------------------------------------------------------------

GERMAN_MARK = re.compile(r"(?<![\w\[(–-])([ab])(\d{1,2})(?![\w–-])")


def clean_german_page(page):
    text, notes = [], []
    in_notes = False
    for line in page["lines"]:
        s = line.rstrip("\n")
        st = s.strip()
        if not st:
            continue
        if not in_notes and (re.fullmatch(r"\d{3}[ab]\d{1,2}", st) or MARGIN.match(st)):
            continue
        if not in_notes and re.fullmatch(r"[IV]+", st):
            page["book_start"] = ROMAN[st]
            continue
        if not in_notes and re.match(r"^1 [A-ZÄÖÜ»„(]", st) and text:
            in_notes = True
            notes.append(st)
            continue
        if not in_notes:
            m = re.search(r"(?<=[a-zäöüß])1 (?=[A-ZÄÖÜ»])", s)
            if m and re.search(r"[a-zäöüß]1 [a-zäöü]", " ".join(text) + " " + s[: m.start()]):
                text.append(s[: m.start() + 0] + "")
                notes.append(s[m.start() + 0:].lstrip("1 ").strip() and "1 " + s[m.end():])
                in_notes = True
                continue
            text.append(s)
        else:
            notes.append(st)
    page["text"] = text
    page["notes"] = notes


def german_stream(pages):
    """Verbindet die deutschen Seiten eines Buchs zu einem Text und merkt sich
    die Seitenanfänge."""
    joined = ""
    offsets = []
    footnotes = []
    for page in pages:
        offsets.append((len(joined), page["page"]))
        part = join_lines(page["text"])
        if joined and part:
            last = joined[-1]
            if last.isalpha() and part[0].islower() and not joined.endswith(" "):
                # Wort über den Seitenwechsel getrennt.
                prev_line = page_prev_line_end(pages, page)
                if prev_line:
                    joined += part
                else:
                    joined += " " + part
            else:
                joined += " " + part
        else:
            joined += part
        if page["notes"]:
            footnotes.append({"page": page["page"], "text": join_lines(page["notes"])})
    return joined, offsets, footnotes


def page_prev_line_end(pages, page):
    i = pages.index(page)
    if i == 0:
        return False
    lines = [l for l in pages[i - 1]["text"] if l.strip()]
    return bool(lines) and not lines[-1].endswith(" ") and lines[-1][-1].isalpha()


def page_at(offsets, pos):
    page = offsets[0][1]
    for off, p in offsets:
        if off <= pos:
            page = p
    return page


def split_chapters_german(text, chapter_count):
    """Teilt den deutschen Text an „2. “, „3. “ … (Kapitelanfänge)."""
    starts = [0]
    pos = 0
    for n in range(2, chapter_count + 1):
        m = re.compile(rf"(?:^|(?<=[\s.»!?]))({n})\. (?=[A-ZÄÖÜ»\[(„])").search(text, pos)
        if not m:
            raise ValueError(f"Kapitel {n} im deutschen Text nicht gefunden")
        starts.append(m.start())
        pos = m.end()
    starts.append(len(text))
    return [(starts[i], starts[i + 1]) for i in range(len(starts) - 1)]


def german_segments(text, base, start_ref):
    """Teilt einen Kapiteltext an Heinemanns Zeilenmarken. Liefert Liste von
    (Bekker-Stelle, Text, Offset)."""
    segments = []
    current_ref = start_ref
    last = 0
    marks = list(GERMAN_MARK.finditer(text))
    for m in marks:
        col, line = m.group(1), int(m.group(2))
        # Neue Stelle bestimmen: Marken laufen vorwärts, höchstens einige
        # Zeilen weit (eine Spalte hat gut 35 Zeilen). Zeilenangaben im
        # Fließtext („oben b21–22“) passen nicht dazu und bleiben Text.
        page = current_ref.page
        if col == current_ref.col:
            distance = line - current_ref.line
        elif col == "b":
            distance = line + 37 - current_ref.line
        else:
            page += 1
            distance = line + 37 - current_ref.line
        if not 0 <= distance <= 25 or (col == current_ref.col and distance > 25):
            continue
        seg = text[last:m.start()].strip()
        if seg:
            segments.append((current_ref, seg, base + last))
        current_ref = Ref(page, col, line)
        last = m.end()
    seg = text[last:].strip()
    if seg:
        segments.append((current_ref, seg, base + last))
    return segments


# ---------------------------------------------------------------------------
# Abschnitte: deutsche Segmente ↔ griechische Sätze
# ---------------------------------------------------------------------------


def build_units(sentences, segments, line_index):
    """Bildet Abschnitte. Jede Marke der Übersetzung beginnt einen neuen
    Abschnitt, wenn ein griechischer Satz auf (oder höchstens zwei Zeilen
    neben) derselben Zeile beginnt; sonst gehört das Segment zum vorigen
    Abschnitt."""

    def idx(ref):
        k = ref.key()
        if k in line_index:
            return line_index[k]
        # Nächstliegende bekannte Zeile.
        best = min(line_index, key=lambda x: (abs(x[0] - k[0]) * 1000 + abs(x[1] - k[1]) * 100 + abs(x[2] - k[2])))
        return line_index[best]

    starts = [idx(s[0]["r"]) for s in sentences]
    targets = [idx(seg[0]) for seg in segments]
    # Monotone Zuordnung mit minimalen Kosten (dynamische Programmierung):
    # Eine Marke beginnt einen Abschnitt bei einem Satz, der höchstens eine
    # Zeile daneben beginnt (Kosten = Abstand), oder bleibt ohne eigenen
    # Abschnitt (Kosten SKIP).
    SKIP = 1.5
    inf = float("inf")
    n = len(sentences)
    best = {0: (0.0, None)}  # letzter Satz → (Kosten, Rückverweis)
    history = []
    for si in range(1, len(segments)):
        nxt = {}
        for j, (cost, _) in best.items():
            # ohne eigenen Abschnitt
            c = cost + SKIP
            if c < nxt.get(j, (inf,))[0]:
                nxt[j] = (c, (j, None))
            for k in range(j + 1, n):
                d = abs(starts[k] - targets[si])
                if starts[k] > targets[si] + 1:
                    break
                if d <= 1:
                    c = cost + d
                    if c < nxt.get(k, (inf,))[0]:
                        nxt[k] = (c, (j, (k, si, d)))
        history.append(nxt)
        best = nxt
    # Rückverfolgung
    j = min(best, key=lambda x: best[x][0])
    chosen = []
    for step in range(len(history) - 1, -1, -1):
        prev, match = history[step][j][1]
        if match:
            chosen.append(match)
        j = prev
    boundaries = [(0, 0, 0)] + list(reversed(chosen))
    units = []
    for b, (sent_i, seg_i, dist) in enumerate(boundaries):
        sent_end = boundaries[b + 1][0] if b + 1 < len(boundaries) else len(sentences)
        seg_end = boundaries[b + 1][1] if b + 1 < len(boundaries) else len(segments)
        units.append({
            "sentences": sentences[sent_i:sent_end],
            "segments": segments[seg_i:seg_end],
            "dist": dist,
        })
    return units


def sentence_text(words):
    return " ".join(w["t"] for w in words)


def make_book(book, gpages, dpages, chapter_titles):
    for p in gpages:
        clean_greek_page(p)
        assign_lines(p)
    for p in dpages:
        clean_german_page(p)
    words = greek_words(gpages)
    gchapters = split_chapters_greek(words, book)
    gtext, offsets, translator_notes = german_stream(dpages)
    if gtext.startswith("1. "):
        gtext = gtext[3:]
    titles = chapter_titles[book]
    dranges = split_chapters_german(gtext, len(gchapters))
    if len(dranges) != len(titles):
        print(f"Warnung: Buch {book}: {len(dranges)} Kapitel, Inhaltsübersicht nennt {len(titles)}", file=sys.stderr)

    line_index = {}
    for p in gpages:
        for r in p["refs"]:
            if r is not None and r.key() not in line_index:
                line_index[r.key()] = len(line_index)

    chapters = []
    stats = {"units": 0, "approx": 0, "sentences": 0}
    for ci, (gwords, (ds, de)) in enumerate(zip(gchapters, dranges)):
        if not gwords:
            continue
        sentences = greek_sentences(gwords)
        ctext = gtext[ds:de]
        ctext = re.sub(rf"^{ci + 1}\. ", "", ctext.strip()) if ci else ctext.strip()
        segments = german_segments(ctext, ds, gwords[0]["r"])
        units = build_units(sentences, segments, line_index)
        out_units = []
        used = {}
        for u in units:
            gs = []
            for s in u["sentences"]:
                rid = str(s[0]["r"])
                n = used.get(rid, 0)
                used[rid] = n + 1
                sid = rid if n == 0 else f"{rid}.{n + 1}"
                gs.append({
                    "id": sid,
                    "r": rid,
                    "to": str(s[-1]["r"]),
                    "t": sentence_text(s),
                })
            ds_ = [{"r": str(seg[0]), "t": seg[1]} for seg in u["segments"]]
            fit = "exact" if u["dist"] == 0 and all(p["exact"] for p in gpages if p["page"] == u["sentences"][0][0]["p"]) else "approx"
            unit = {
                "id": gs[0]["id"],
                "g": gs,
                "d": ds_,
                "fit": fit,
                "pg": u["sentences"][0][0]["p"],
                "pd": page_at(offsets, u["segments"][0][2]) if u["segments"] else None,
            }
            out_units.append(unit)
            stats["units"] += 1
            stats["sentences"] += len(gs)
            if fit != "exact":
                stats["approx"] += 1
        chapters.append({
            "n": ci + 1,
            "title": titles[ci] if ci < len(titles) else None,
            "from": out_units[0]["g"][0]["r"],
            "to": out_units[-1]["g"][-1]["to"],
            "units": out_units,
        })

    textcrit = []
    for p in gpages:
        textcrit.extend(parse_textcrit(p))

    # Übersetzerfußnoten der Seite dem ersten Abschnitt der Seite zuordnen.
    tnotes = []
    for fn in translator_notes:
        anchor = None
        for c in chapters:
            for u in c["units"]:
                if u["pd"] == fn["page"] and anchor is None:
                    anchor = u["id"]
        text = re.sub(r"^1 ", "", fn["text"])
        tnotes.append({"id": f"fn.{fn['page']}", "page": fn["page"], "unit": anchor, "text": text})
    return {"n": book, "chapters": chapters, "textcrit": textcrit, "translatorNotes": tnotes}, stats


# ---------------------------------------------------------------------------
# Anmerkungen des Herausgebers
# ---------------------------------------------------------------------------

NOTE_START = re.compile(r"^(\d{3}[ab]\d{1,2}(?:[–-](?:\d{3}[ab])?\d{1,2}|[–-]\d{3}[ab]\d{1,2})?)(?: (?=\S)|$)")
INTRO_LINK = re.compile(r"(?:Einleitung|Einl\.)\s+(\d(?:\.\d+)+)")
NOTE_LINK = re.compile(r"Anm\. zu (\d{3}[ab]\d{1,2}(?:[–-](?:\d{3}[ab])?\d{1,2})?)")


def expand_range(text):
    m = re.fullmatch(r"(\d{3})([ab])(\d{1,2})(?:[–-](?:(\d{3})([ab]))?(?:([ab]))?(\d{1,2}))?", text)
    if not m:
        return text, text
    p, c, l, p2, c2, c3, l2 = m.groups()
    start = f"{p}{c}{l}"
    if not l2:
        return start, start
    if p2:
        return start, f"{p2}{c2}{l2}"
    if c3:
        return start, f"{p}{c3}{l2}" if not (c == "b" and c3 == "a") else f"{int(p) + 1}{c3}{l2}"
    return start, f"{p}{c}{l2}"


def parse_notes(lines):
    start = find(lines, lambda l: l == "ANMERKUNGEN DES HERAUSGEBERS") + 1
    book = 0
    page = 203
    notes = []
    buf = []
    current = None

    def flush():
        nonlocal current, buf
        if current is not None:
            current["text"] = clean_note_text(join_lines(buf))
            notes.append(current)
        current, buf = None, []

    for line in lines[start:]:
        st = line.strip()
        if not st:
            continue
        hm = NOTES_HEADER.match(st)
        if hm:
            page = int(hm.group(1) or hm.group(2))
            if current is not None and current.get("page_end") is None:
                pass
            if current is not None:
                current["pageEnd"] = page
            continue
        bm = re.fullmatch(r"Buch ([IV]+)", st)
        if bm:
            flush()
            book = ROMAN[bm.group(1)]
            continue
        m = NOTE_START.match(st)
        if m and book:
            flush()
            a, b = expand_range(m.group(1).replace("-", "–"))
            current = {"book": book, "ref": m.group(1).replace("-", "–"), "from": a, "to": b, "page": page}
            buf = [line.lstrip()[m.end():]]
            continue
        if current is not None:
            buf.append(line)
    flush()
    seen = {}
    for n in notes:
        nid = f"n.{n['from']}" + (f"-{n['to']}" if n["to"] != n["from"] else "")
        k = seen.get(nid, 0)
        seen[nid] = k + 1
        n["id"] = nid if k == 0 else f"{nid}.{k + 1}"
        n["intro"] = sorted(set(INTRO_LINK.findall(n["text"])))
        n["notes"] = sorted({expand_range(x)[0] for x in NOTE_LINK.findall(n["text"])})
        n.pop("pageEnd", None)
    return notes


def clean_note_text(text):
    # Randziffern der Kapitel am Absatzende („…). 1“, „…). 1–2“) entfernen.
    return re.sub(r"(?<=[.)»!?]) (\d{1,2}(?:–\d{1,2})?)(?= [A-ZÄÖÜ»(„]|$)", "", text)


# ---------------------------------------------------------------------------
# Vorwort, Einleitung, Glossar, Siglen, Literatur
# ---------------------------------------------------------------------------

INTRO_PAGE_HEADER = re.compile(r"^(?:([CLXVI]+) Gottfried Heinemann|Einleitung ([CLXVI]+)|([CLXVI]+) Vorwort des Herausgebers|Vorwort des Herausgebers ([CLXVI]+)|Siglenverzeichnis ([CLXVI]+)|([CLXVI]+) Siglenverzeichnis|Literaturverzeichnis ([CLXVI]+)|([CLXVI]+) Literaturverzeichnis)$")


def toc_headings(lines):
    """Abschnittsnummern und Titel aus dem Inhaltsverzeichnis."""
    start = find(lines, lambda l: l == "INHALT")
    end = find(lines, lambda l: l.startswith("Siglenverzeichnis"), start)
    text = " ".join(l.strip() for l in lines[start + 1:end])
    text = re.sub(r"(?: ?\.){2,}", " ", text)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r" (?:[CLXVI]+ Inhalt|Inhalt [CLXVI]+)(?= )", "", text)
    items = []
    pattern = re.compile(r"(?:^|(?<=\s))(\d(?:\.\d+){0,2})\.? (.+?) ([CLXVI]+)(?=\s*(?:—|\d|Siglen|$))")
    pos = 0
    while True:
        m = pattern.search(text, pos)
        if not m:
            break
        num, title, page = m.groups()
        if roman_to_int(page) < 9:
            # Römische Zahl im Titel („APo I 2“): weiter suchen.
            m2 = None
            probe = m.end()
            while True:
                m2 = re.compile(r" ([CLXVI]+)(?=\s*(?:—|\d|Siglen|$))").search(text, probe)
                if not m2 or roman_to_int(m2.group(1)) >= 9:
                    break
                probe = m2.end()
            if not m2:
                break
            title = text[m.start(2):m2.start()]
            page = m2.group(1)
            pos = m2.end()
        else:
            pos = m.end()
        items.append((num, title.strip(" .—"), page))
    return items


def roman_to_int(r):
    vals = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}
    total = 0
    for i, ch in enumerate(r):
        v = vals[ch]
        if i + 1 < len(r) and vals[r[i + 1]] > v:
            total -= v
        else:
            total += v
    return total


def int_to_roman(n):
    out = ""
    for v, s in ((100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")):
        while n >= v:
            out += s
            n -= v
    return out


def front_pages(lines, start_marker, end_marker, first_page):
    """Liefert die Zeilen zwischen zwei Marken, aufgeteilt in Text und
    Fußnoten je Druckseite."""
    start = find(lines, lambda l: l.strip() == start_marker) + 1
    end = find(lines, lambda l: l.strip() == end_marker, start)
    pages = [{"page": first_page, "lines": []}]
    for line in lines[start:end]:
        st = line.strip()
        hm = INTRO_PAGE_HEADER.match(st)
        if hm:
            num = next(g for g in hm.groups() if g)
            pages.append({"page": num, "lines": []})
            continue
        pages[-1]["lines"].append(line)
    return pages


def split_footnotes(pages, first_fn=1):
    """Trennt Fußnoten (fortlaufend nummeriert) vom Haupttext. Liefert
    (Liste von (Zeile, Seite)), Fußnoten)."""
    body, notes = [], {}
    expected = first_fn
    for page in pages:
        in_note = None
        for line in page["lines"]:
            st = line
            if in_note is None:
                m = re.match(rf"^{expected} (?=\S)", st.strip())
                g = re.search(rf"(?<=[A-Za-zäöüß\-])({expected}) (?=[A-ZÄÖÜ»(„]|Vgl|vgl|s\.)", st)
                if m:
                    in_note = expected
                    notes[in_note] = [st.strip()[m.end():]]
                    expected += 1
                    continue
                if g and expected > first_fn:
                    body.append((st[: g.start()], page["page"]))
                    in_note = expected
                    notes[in_note] = [st[g.end():]]
                    expected += 1
                    continue
                body.append((st, page["page"]))
            else:
                m = re.match(rf"^{expected} (?=\S)", st.strip())
                if m:
                    in_note = expected
                    notes[in_note] = [st.strip()[m.end():]]
                    expected += 1
                    continue
                notes[in_note].append(st)
    return body, {k: join_lines(v) for k, v in notes.items()}


def build_intro(lines):
    headings = [h for h in toc_headings(lines) if h[0][0] in "123"]
    pages = front_pages(lines, "EINLEITUNG", "SIGLENVERZEICHNIS", "XI")
    body, footnotes = split_footnotes(pages)
    heading_titles = {num: title for num, title, _ in headings}
    sections = []
    current = None
    para = []
    para_page = None

    def flush_para():
        nonlocal para, para_page
        if para and current is not None:
            text = join_lines(para)
            if text:
                block = {"text": text, "page": para_page}
                m = re.match(r"^(\d(?:\.\d+){3,})\s+", text)
                if m:
                    block["n"] = m.group(1)
                current["blocks"].append(block)
        para, para_page = [], None

    remaining = [h[0] for h in headings]
    for line, page in body:
        st = line.strip()
        if not st:
            continue
        hm = re.match(r"^(\d(?:\.\d+){0,2})\.? (.+)$", st)
        if hm and remaining and hm.group(1) == remaining[0] and similar(hm.group(2), heading_titles[hm.group(1)]):
            flush_para()
            num = remaining.pop(0)
            current = {"id": num, "title": heading_titles[num], "page": page, "blocks": []}
            sections.append(current)
            continue
        if current is None:
            continue
        current.setdefault("_lines", []).append(line)
        if re.match(r"^\d(?:\.\d+){3,}\s", st):
            flush_para()
        if para_page is None:
            para_page = page
        para.append(line)
        # Absatzende: kurze Zeile mit Satzende.
        if len(st) < 45 and st.endswith((".", ":", "?", "!", "«")):
            flush_para()
    flush_para()

    # Fußnoten den Abschnitten zuordnen (über die Fußnotenzeichen im Text).
    fn_refs = re.compile(r"(?<=[A-Za-zäöüß.,;:)»«’?!\]])(\d{1,3})(?=[\s.,;:)]|$)")
    numbers = sorted(footnotes)
    assigned = set()
    for sec in sections:
        sec["footnotes"] = []
        for block in sec["blocks"]:
            for m in fn_refs.finditer(block["text"]):
                n = int(m.group(1))
                if n in footnotes and n not in assigned:
                    assigned.add(n)
                    sec["footnotes"].append({"n": n, "text": footnotes[n]})
        # Fußnotenzeichen als „[n]“ kenntlich machen.
        wanted = {f["n"] for f in sec["footnotes"]}
        for block in sec["blocks"]:
            def mark(m):
                n = int(m.group(1))
                if n in wanted:
                    wanted.discard(n)
                    return f"[{n}]"
                return m.group(0)
            block["text"] = fn_refs.sub(mark, block["text"])
    return sections, len(footnotes), len(assigned)


def similar(a, b):
    na = re.sub(r"\W", "", a.lower())[:12]
    nb = re.sub(r"\W", "", b.lower())[:12]
    return na[:8] == nb[:8]


def build_preface(lines):
    pages = front_pages(lines, "VORWORT DES HERAUSGEBERS", "EINLEITUNG", "IX")
    text_lines = [l for p in pages for l in p["lines"]]
    paragraphs, para = [], []
    for line in text_lines:
        para.append(line)
        if len(line.strip()) < 45 and line.strip().endswith("."):
            paragraphs.append(join_lines(para))
            para = []
    if para:
        paragraphs.append(join_lines(para))
    return {"pages": "IX–X", "paragraphs": [p for p in paragraphs if p]}


GLOSS_HEAD = r"(?:[a-zêôâîûïë’]+)(?: [a-zêôâîûïë’/]+){0,5}"
GLOSS_START = re.compile(rf"^({GLOSS_HEAD})((?: \([^)]*\))*)(?::\s|\s(?=»|[a-zäöü]))")


def build_glossary(intro_sections):
    """Zerlegt den Abschnitt 3.2.3 (Glossar) zeilenweise in Einträge. Ein
    Eintrag beginnt mit dem transliterierten Stichwort am Zeilenanfang."""
    sec = next((s for s in intro_sections if s["id"] == "3.2.3"), None)
    if not sec:
        return []
    lines = sec.pop("_lines", [])
    start = next((i for i, l in enumerate(lines) if l.lstrip().startswith("aei ê hôs epi to poly")), None)
    if start is None:
        return []
    entries = []
    current = None
    parent = None
    for raw in lines[start:]:
        line = raw.lstrip()
        m = GLOSS_START.match(line)
        if m and len(m.group(0)) <= 60:
            if current:
                entries.append(current)
            head = m.group(1)
            current = {"term": head, "gram": m.group(2).strip(), "lines": [line[m.end():]], "parent": None}
            if parent and current["lines"]:
                pass
            continue
        if current:
            current["lines"].append(raw)
    if current:
        entries.append(current)
    out = []
    seen = {}
    for e in entries:
        text = join_lines(e["lines"]).strip()
        gid = "g." + re.sub(r"[^a-z0-9êôâîûïë]+", "_", e["term"])
        n = seen.get(gid, 0)
        seen[gid] = n + 1
        if n:
            gid += f".{n + 1}"
        gram = e["gram"].strip("() ").replace(") (", "; ")
        renderings = re.findall(r"»([^«]+)«", text)
        item = {
            "id": gid,
            "term": e["term"],
            "gram": gram or None,
            "de": renderings[:4],
            "text": text,
            "tt": "t.t." in gram,
            "intro": sorted(set(re.findall(r"(?:s\.\s?o\.|oben|vgl\.|und|Einl\.)\s+(\d\.\d(?:\.\d+)*)", text))),
            "notes": sorted({expand_range(x.replace(" ", ""))[0] for x in re.findall(r"Anm\. zu (\d{3} ?[ab]\d{1,2}(?:[–-](?:\d{3}[ab])?\d{1,2})?)", text)}),
        }
        out.append(item)
    return out


def build_simple_list(lines, start_marker, end_marker, first_page):
    pages = front_pages(lines, start_marker, end_marker, first_page)
    items = []
    for p in pages:
        for line in p["lines"]:
            if not line.strip():
                continue
            items.append(line)
    return items


def build_bibliography(lines):
    raw = build_simple_list(lines, "LITERATURVERZEICHNIS", "INHALTSÜBERSICHT", "CLXXXIX")
    entries, cur = [], []
    for st in raw:
        st = st.lstrip()
        if re.match(r"^[A-ZÄÖÜ][^\s,]+(?: [^\s,]+)?, [A-ZÄÖÜ]", st) and re.search(r"\[\d{4}|\d{4}[a-z]?\]?:", st) and cur:
            entries.append(join_lines(cur))
            cur = []
        cur.append(st)
    if cur:
        entries.append(join_lines(cur))
    return entries


def build_sigla(lines):
    raw = build_simple_list(lines, "SIGLENVERZEICHNIS", "LITERATURVERZEICHNIS", "CLXXXV")
    return [join_lines([l]) for l in raw]


def strip_private_glyphs(text):
    """Die Ausgabe markiert das Zahlwort „en/enes“ mit einem Zeichen aus dem
    privaten Unicode-Bereich (U+F644), das die Textebene nicht auflöst; es
    wird weggelassen (dokumentiert im Bericht)."""
    return text.replace("\uf644", "")


def chapter_titles(lines):
    start = find(lines, lambda l: l.startswith("INHALTSÜBERSICHT"))
    end = find(lines, lambda l: l == "ARISTOTELES", start)
    titles = {1: [], 2: [], 3: [], 4: []}
    book_titles = {}
    book = 0
    buf = None
    expect_book_title = False
    for line in lines[start + 2:end]:
        st = line.strip()
        if not st or st.startswith("Inhaltsübersicht nach") or re.match(r"^C+[CLXVI]* Inhaltsübersicht", st):
            continue
        bm = re.fullmatch(r"Buch ([IV]+)", st)
        if bm:
            if buf:
                titles[book].append(join_lines(buf))
                buf = None
            book = ROMAN[bm.group(1)]
            expect_book_title = True
            continue
        if expect_book_title:
            book_titles[book] = st
            expect_book_title = False
            continue
        m = re.match(r"^(\d{1,2})\. (.*)$", st)
        if m and int(m.group(1)) == len(titles[book]) + 1 + (1 if buf else 0):
            if buf:
                titles[book].append(join_lines(buf))
            buf = [m.group(2)]
        elif buf is not None:
            buf.append(line)
    if buf:
        titles[book].append(join_lines(buf))
    return titles, book_titles


# ---------------------------------------------------------------------------
# Verknüpfungen Einleitung → Textstellen
# ---------------------------------------------------------------------------

PHYS_CITE = re.compile(r"Phys\.\s+([IV]+)\s+(\d{1,2}),\s*(\d{3}[ab]\d{1,2}(?:[–-](?:\d{3}[ab])?\d{1,2})?)")


def intro_citations(sections):
    """Stellen der Physik (Bücher I–IV), die die Einleitung ausdrücklich
    zitiert: „Phys. I 1, 184a14–16“."""
    out = []
    for sec in sections:
        texts = [(b["text"], b.get("page")) for b in sec["blocks"]]
        texts += [(f["text"], None) for f in sec.get("footnotes", [])]
        for text, page in texts:
            for m in PHYS_CITE.finditer(text):
                book = ROMAN.get(m.group(1))
                if not book:
                    continue
                a, b = expand_range(m.group(3).replace("-", "–"))
                out.append({"section": sec["id"], "book": book, "from": a, "to": b, "page": page})
    uniq = {}
    for c in out:
        uniq[(c["section"], c["from"], c["to"])] = c
    return list(uniq.values())


# ---------------------------------------------------------------------------


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    lines = read_lines(sys.argv[1])
    gpages, dpages = split_pages(lines)
    titles, book_titles = chapter_titles(lines)
    books = []
    report = {}
    for book in (1, 2, 3, 4):
        gp = [p for p in gpages if p["book"] == book]
        first, last = gp[0]["page"], gp[-1]["page"]
        dp = [p for p in dpages if first < p["page"] <= last + 1]
        data, stats = make_book(book, gp, dp, titles)
        data["title"] = book_titles.get(book)
        books.append(data)
        report[book] = stats
    notes = parse_notes(lines)
    for b in books:
        b["notes"] = [dict(n) for n in notes if n["book"] == b["n"]]
        for n in b["notes"]:
            n.pop("book", None)
    intro, fn_total, fn_assigned = build_intro(lines)
    glossary = build_glossary(intro)
    for sec in intro:
        sec.pop("_lines", None)
    out = {
        "format": "theologie.app/philosophy-edition",
        "version": 1,
        "work": WORK,
        "edition": EDITION,
        "title": "Aristoteles, Physikvorlesung. Teilband 1: Bücher I–IV. Griechisch–Deutsch",
        "editor": "Gottfried Heinemann",
        "publisher": "Felix Meiner Verlag, Hamburg 2021 (Philosophische Bibliothek)",
        "isbn": "978-3-7873-3870-2",
        "ebookIsbn": "978-3-7873-3801-6",
        "doi": "10.28937/978-3-7873-3801-6",
        "rights": "Urheberrechtlich geschützt (© Felix Meiner Verlag 2021). Private Lesedatei aus der eigenen Kopie – nicht weitergeben und nicht veröffentlichen.",
        "preface": build_preface(lines),
        "intro": intro,
        "introCitations": intro_citations(intro),
        "glossary": glossary,
        "sigla": build_sigla(lines),
        "bibliography": build_bibliography(lines),
        "books": books,
    }
    encoded = strip_private_glyphs(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(encoded)
    summary = {
        "books": report,
        "notes": len(notes),
        "textcrit": sum(len(b["textcrit"]) for b in books),
        "translatorNotes": sum(len(b["translatorNotes"]) for b in books),
        "introSections": len(intro),
        "introFootnotes": [fn_total, fn_assigned],
        "glossary": len(glossary),
        "introCitations": len(out["introCitations"]),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
