#!/usr/bin/env python3
"""Erzeugt den frei verfügbaren griechischen Text der Physik (Bücher I–IV)
für den Lesebereich aus der TEI-Datei von First1KGreek:

    W. D. Ross (Hg.), Aristotelis Physica, Oxford: Clarendon 1950 (Nachdruck
    1960), digitalisiert von Harvard College Library / Open Greek and Latin
    (First1KGreek), CC BY-SA 4.0,
    https://github.com/OpenGreekAndLatin/First1KGreek
    (data/tlg0086/tlg031/tlg0086.tlg031.1st1K-grc1.xml)

Aufruf:

    curl -sO https://raw.githubusercontent.com/OpenGreekAndLatin/First1KGreek/master/data/tlg0086/tlg031/tlg0086.tlg031.1st1K-grc1.xml
    python3 tool/philosophy/build_ross_physics.py tlg0086.tlg031.1st1K-grc1.xml assets/philosophy/aristotle_physics/ross

Der Wortlaut bleibt unverändert, auch erkennbare Lesefehler der
Digitalisierung (z. B. „Ἐπειθὴ“ statt „Ἐπειδὴ“ am Anfang). Getilgtes
(<del>) erscheint in eckigen, Ergänztes (<add>) in spitzen Klammern wie in
der Druckausgabe. Die Digitalisierung nennt nur jede fünfte Bekker-Zeile;
die Zeilen dazwischen sind nach Wortzahl geschätzt (`fit: approx`).
"""

import json
import os
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET

TEI = "{http://www.tei-c.org/ns/1.0}"
BEKKER_START = {1: (184, "a", 10), 2: (192, "b", 8), 3: (200, "b", 12), 4: (208, "a", 27)}
SENTENCE_END = re.compile(r"[.;;··](?:[)\]〉]*)$")


def tokens_of(chapter_div):
    """Liefert Wörter und Marken (Zeile, Spalte) eines Kapitels in
    Lesereihenfolge."""
    out = []

    def text(t):
        if t:
            for w in t.split():
                out.append(("w", unicodedata.normalize("NFC", w)))

    def walk(el):
        tag = el.tag.replace(TEI, "")
        if tag == "lb":
            out.append(("lb", int(el.get("n"))))
        elif tag == "note" and el.get("type") == "marginal":
            m = re.fullmatch(r"(\d{3})([ab])", (el.text or "").strip())
            if m:
                out.append(("col", (int(m.group(1)), m.group(2))))
        elif tag == "del":
            inner = "".join(el.itertext()).split()
            if inner:
                inner[0] = "[" + inner[0]
                inner[-1] = inner[-1] + "]"
                for w in inner:
                    out.append(("w", unicodedata.normalize("NFC", w)))
        elif tag == "add":
            inner = "".join(el.itertext()).split()
            if inner:
                inner[0] = "〈" + inner[0]
                inner[-1] = inner[-1] + "〉"
                for w in inner:
                    out.append(("w", unicodedata.normalize("NFC", w)))
        elif tag == "gap":
            out.append(("w", "…"))
        elif tag in ("head", "pb"):
            pass
        else:
            text(el.text)
            for child in el:
                walk(child)
                text(child.tail)
            return
        # Bei übersprungenen Elementen trotzdem den Text danach lesen.
    for child in chapter_div:
        walk(child)
        if child.tail:
            text(child.tail)
    return out


def assign_refs(items, start, prev_state):
    """Ordnet jedem Wort eine geschätzte Bekker-Stelle zu."""
    page, col, line = prev_state or start
    anchors = []  # (Wortindex, page, col, line)
    words = []
    for kind, value in items:
        if kind == "w":
            words.append(value)
        elif kind == "lb":
            if anchors and anchors[-1][3] == value and anchors[-1][2] == col:
                continue
            anchors.append((len(words), page, col, value))
        elif kind == "col":
            page, col = value
            # Die Spalte beginnt mit Zeile 1 (bzw. 10 unter dem Titel).
            line_start = 10 if (page, col) == (184, "b") else 1
            anchors.append((len(words), page, col, line_start))
    anchors = [(0, *(prev_state or start))] + anchors
    refs = []
    for i in range(len(words)):
        # letzter Anker davor, nächster danach
        before = max((a for a in anchors if a[0] <= i), key=lambda a: a[0])
        after = next((a for a in anchors if a[0] > i), None)
        p, c, l = before[1], before[2], before[3]
        if after and (after[1], after[2]) == (p, c) and after[3] > l:
            span = after[0] - before[0]
            frac = (i - before[0]) / span if span else 0
            l = l + int(frac * (after[3] - l))
        refs.append((p, c, l))
    last = refs[-1] if refs else (prev_state or start)
    return words, refs, last


def order(ref):
    page, col, line = ref
    return page * 200 + (0 if col == "a" else 100) + line


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    root = ET.parse(sys.argv[1]).getroot()
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    books = root.iter(TEI + "div")
    for book_div in [d for d in root.iter(TEI + "div") if d.get("subtype") == "book"]:
        n = int(book_div.get("n"))
        if n > 4:
            continue
        state = BEKKER_START[n]
        chapters = []
        # Kennungen sind je Buch eindeutig; geschätzte Stellen laufen nie
        # rückwärts (Zeilenmarken der Digitalisierung sind nicht immer
        # aufsteigend).
        used, last = {}, None
        for chap_div in [d for d in book_div if d.get("subtype") == "chapter"]:
            cn = int(chap_div.get("n"))
            items = tokens_of(chap_div)
            words, refs, state = assign_refs(items, BEKKER_START[n], state)
            # Kapitelzahl am Anfang des Kapitels entfernen.
            if words and re.fullmatch(r"\d+\.", words[0]):
                words, refs = words[1:], refs[1:]
            sentences, cur, cur_refs = [], [], []
            for w, r in zip(words, refs):
                cur.append(w)
                cur_refs.append(r)
                if SENTENCE_END.search(w):
                    sentences.append((cur, cur_refs))
                    cur, cur_refs = [], []
            if cur:
                sentences.append((cur, cur_refs))
            units = []
            for ws, rs in sentences:
                first = rs[0]
                if last is not None and order(first) < order(last):
                    first = last
                end = rs[-1] if order(rs[-1]) >= order(first) else first
                last = first
                rid = "%d%s%d" % first
                k = used.get(rid, 0)
                used[rid] = k + 1
                sid = rid if k == 0 else f"{rid}.{k + 1}"
                units.append({
                    "id": sid,
                    "g": [{"id": sid, "r": rid, "to": "%d%s%d" % end, "t": " ".join(ws)}],
                    "d": [],
                    "fit": "approx",
                })
            chapters.append({
                "n": cn,
                "title": None,
                "from": units[0]["g"][0]["r"],
                "to": units[-1]["g"][-1]["to"],
                "units": units,
            })
        data = {
            "format": "theologie.app/philosophy-book",
            "version": 1,
            "work": "aristotle.physics",
            "edition": "ross-first1k",
            "n": n,
            "chapters": chapters,
            "textcrit": [],
            "notes": [],
            "translatorNotes": [],
        }
        with open(os.path.join(out_dir, f"book-{n}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        print(n, len(chapters), sum(len(c["units"]) for c in chapters))


if __name__ == "__main__":
    main()
