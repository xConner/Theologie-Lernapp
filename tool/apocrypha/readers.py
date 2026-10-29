"""Leser der Quellsammlungen für „Apokryphen & außerkanonische Schriften“.

Jeder Leser liefert eine Liste von Einheiten (Kapitel, Logion, Brief …):

    {"id": "3", "label": "Kapitel 3", "path": ["Visionen"], "title": None,
     "blocks": [["1", "Text"], ["2", "Text"]], "notes": ["…"]}

`blocks` sind nummerierte Abschnitte (Vers, Unterabschnitt) oder Absätze
ohne Nummer ("" als Nummer). Anmerkungszeichen stehen im Text als „[n]“
(n = Stelle in "notes" + 1). Die Einheitenkennungen sind je Werk
einheitlich gewählt (siehe curation/sources.py), damit Fassungen in der
Parallelansicht zueinander finden.

Keine Quelle wird verändert außer in Leerraum, Zeilentrennung und
Anmerkungsnummern; Textkritik und Lückenergänzungen der Ausgaben bleiben,
wie sie sind.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

from lxml import etree

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "fathers"))
from open_texts import _hcf_paragraphs, roman  # noqa: E402

TEI = {"t": "http://www.tei-c.org/ns/1.0"}


def clean(text: str) -> str:
    text = unicodedata.normalize("NFC", text.replace("\xa0", " ").replace("​", ""))
    return re.sub(r"\s+", " ", text).strip()


def unit(uid, label, blocks, *, path=None, title=None, notes=None):
    return {"id": str(uid), "label": label, "path": path or [], "title": title,
            "blocks": blocks, "notes": notes or []}


# ------------------------------------------------------- Bibelausgaben


def scrollmapper(path: Path, book: str, *, chapters=None, ids=None, label="Kapitel"):
    """Ein Buch aus scrollmapper/bible_databases (formats/json/<X>.json)."""
    data = json.loads(path.read_text(encoding="utf-8"))
    for b in data["books"]:
        if b["name"] == book:
            break
    else:
        raise ValueError(f"{path.name}: Buch {book} fehlt")
    out = []
    for ch in b["chapters"]:
        n = ch["chapter"]
        if chapters and n not in chapters:
            continue
        blocks = [[str(v["verse"]), clean(v["text"])] for v in ch["verses"] if clean(v["text"])]
        if not blocks:
            continue
        uid = (ids or {}).get(n, n)
        lab = (ids or {}).get(("label", n), f"{label} {n}")
        out.append(unit(uid, lab, blocks))
    return out


_VREF: dict[str, list[str]] = {}


def ebible_corpus(path: Path, vref: Path, book: str, *, ids=None, label="Kapitel"):
    """Ein Buch aus dem eBible-Korpus (BibleNLP/ebible, eine Zeile je Vers
    nach metadata/vref.txt)."""
    if str(vref) not in _VREF:
        _VREF[str(vref)] = vref.read_text(encoding="utf-8").split("\n")
    refs = _VREF[str(vref)]
    lines = path.read_text(encoding="utf-8").split("\n")
    chapters: dict[int, list] = {}
    for ref, line in zip(refs, lines):
        if not ref.startswith(book + " ") or not line.strip():
            continue
        c, v = ref.split()[1].split(":")
        chapters.setdefault(int(c), []).append([v, clean(line)])
    return [unit((ids or {}).get(c, c), f"{label} {c}", blocks)
            for c, blocks in sorted(chapters.items())]


def bible_asset(app_root: Path, translation: str, book: str, *, chapters=None,
                verses=None, uid=None, label=None):
    """Verweis auf einen Text, der schon unter assets/bible/ liegt (keine
    Kopie): die Einheiten tragen statt Text die Fundstelle `src`
    [Übersetzung, Buch, Kapitel, erster Vers, letzter Vers]."""
    data = json.loads((app_root / "assets" / "bible" / translation / f"{book}.json").read_text(encoding="utf-8"))
    out = []
    for i, verses_of_chapter in enumerate(data["chapters"], start=1):
        if chapters and i not in chapters:
            continue
        nums = [v["v"] for v in verses_of_chapter if "v" in v]
        if not nums:
            continue
        first, last = (verses if verses else (min(nums), max(nums)))
        count = len([n for n in nums if first <= n <= last])
        u = unit(uid or i, label or f"Kapitel {i}", [])
        u["src"] = [translation, book, i, first, last]
        u["count"] = count
        out.append(u)
    return out


# --------------------------------------------------- Open Apostolic Fathers


def openaf(path: Path, *, mapping=None, label="Kapitel", zero_label="Zuschrift"):
    """Text von jtauber/apostolic-fathers: „Kapitel.Vers Text“ je Zeile
    (Hirt des Hermas: „Buch.Kapitel.Vers“). `mapping` ordnet der ersten
    Zahl Kennung und Bezeichnung zu (Hermas: Visionen, Gebote, Gleichnisse)."""
    units: dict[str, dict] = {}
    order = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        ref, text = line.split(" ", 1)
        parts = ref.split(".")
        if mapping:
            uid, lab, path_ = mapping(int(parts[0]))
            sub = ".".join(parts[1:])
            if sub in ("0.0", "0"):
                units.setdefault(uid, unit(uid, lab, [], path=path_))
                if uid not in order:
                    order.append(uid)
                units[uid]["title"] = clean(text)
                continue
            num = sub
        else:
            c, num = parts[0], parts[1]
            uid = c
            lab = {"0": zero_label, "SB": "Unterschrift", "EP": "Epilog (Moskauer Handschrift)"}.get(c, f"{label} {c}")
            path_ = []
        if uid not in units:
            units[uid] = unit(uid, lab, [], path=path_)
            order.append(uid)
        units[uid]["blocks"].append([num, clean(text)])
    return [units[u] for u in order]


# ------------------------------------------------------------ EpiDoc / CTS


def _tei_plain(el) -> str:
    parts = []

    def walk(node):
        if not isinstance(node.tag, str):
            # Kommentar oder Verarbeitungsanweisung: nur der folgende Text zählt.
            if node.tail and node is not el:
                parts.append(node.tail)
            return
        tag = etree.QName(node).localname
        if tag in ("note", "pb", "milestone", "head", "label", "bibl", "del"):
            if node.tail:
                parts.append(node.tail)
            return
        if tag == "lb":
            parts.append("⁣")
            if node.tail:
                parts.append(node.tail)
            return
        if tag == "gap":
            parts.append(" … ")
            if node.tail:
                parts.append(node.tail)
            return
        if node.text:
            parts.append(node.text)
        for child in node:
            walk(child)
        if node.tail and node is not el:
            parts.append(node.tail)

    walk(el)
    text = "".join(parts)
    # Silbentrennung am Zeilenende („heraus- ⁣ kamen“) zusammenziehen.
    text = re.sub(r"(\w)[-¬]\s*⁣?\s*\n\s*(\w)", r"\1\2", text)
    text = re.sub(r"(\w)[-¬]\s*⁣\s*(\w)", r"\1\2", text)
    text = text.replace("⁣", " ")
    return clean(text)


def tei_header(path: Path) -> dict:
    tree = etree.parse(str(path))

    def first(xpath):
        el = tree.find(xpath, TEI)
        return clean("".join(el.itertext())) if el is not None else None

    return {"title": first(".//t:titleStmt/t:title"),
            "editor": first(".//t:sourceDesc//t:editor"),
            "date": first(".//t:sourceDesc//t:imprint/t:date") or first(".//t:sourceDesc//t:date"),
            "licence": first(".//t:availability/t:licence")}


SPECIAL_LABELS = {"praef": "Vorrede", "pr": "Vorrede", "prol": "Prolog", "0": "Einleitung"}


def cts(path: Path, *, label="Kapitel", unit_ids=None, top_label=None, level_labels=None,
        prefix=""):
    """EpiDoc-Edition (First1KGreek): die oberste Gliederung wird zur
    Einheit, die unterste zu nummerierten Abschnitten. Bei drei Ebenen
    (Buch/Kapitel/Vers) ist die Einheit das Buch, Abschnitte heißen
    „Kapitel,Vers“."""
    tree = etree.parse(str(path))
    body = tree.find(".//t:body", TEI)
    root = body.find("t:div", TEI)
    tops = root.findall("t:div", TEI)
    out = []
    if not tops:
        # Ohne Gliederung: Absätze.
        blocks = [["", _tei_plain(p)] for p in root.iter("{%s}p" % TEI["t"]) if _tei_plain(p)]
        return [unit("1", top_label or "Text", blocks)]
    for top in tops:
        n = top.get("n") or str(len(out) + 1)
        blocks = []

        def collect(div, trail):
            kids = div.findall("t:div", TEI)
            if not kids:
                text = _tei_plain(div)
                if text:
                    blocks.append([",".join(trail) if trail else "", text])
                return
            loose = [c for c in div if isinstance(c.tag, str) and etree.QName(c).localname in ("p", "l", "lg", "ab")]
            for c in loose:
                text = _tei_plain(c)
                if text:
                    blocks.append([",".join(trail) if trail else "", text])
            for k in kids:
                collect(k, trail + [k.get("n") or ""])

        kids = top.findall("t:div", TEI)
        if kids:
            collect(top, [])
        else:
            for c in top:
                if isinstance(c.tag, str) and etree.QName(c).localname in ("p", "l", "lg", "ab"):
                    text = _tei_plain(c)
                    if text:
                        blocks.append(["", text])
        if not blocks:
            continue
        uid = (unit_ids or {}).get(n, prefix + n)
        lab = (SPECIAL_LABELS[n] if n in SPECIAL_LABELS else f"{label} {n}") if label else n
        if level_labels and n in level_labels:
            lab = level_labels[n]
        out.append(unit(uid, lab, blocks))
    return out


# --------------------------------------------------------- Coptic SCRIPTORIUM


def coptic_scriptorium(path: Path, *, label="Logion"):
    """Koptischer Text (TEI von Coptic SCRIPTORIUM): je `div1` eine Einheit;
    `phr` sind gebundene Gruppen (ein Schriftwort), `w`/`m` deren Teile."""
    tree = etree.parse(str(path))
    out = []
    for div in tree.iter("{%s}div1" % TEI["t"]):
        n = div.get("n")
        words = []
        for phr in div.iter("{%s}phr" % TEI["t"]):
            words.append("".join(t.strip() for t in phr.itertext()))
        text = clean(" ".join(w for w in words if w))
        if not text:
            continue
        if n == "0":
            out.append(unit("0", "Prolog", [["", text]]))
        elif n == "subtitle":
            out.append(unit("subscriptio", "Schlusstitel", [["", text]]))
        else:
            out.append(unit(n, f"{label} {n}", [["", text]]))
    return out


# --------------------------------------------------------- Beta maṣāḥǝft


def betamasaheft(path: Path, edition: str, *, label="Kapitel"):
    """Ge'ez-Text einer Edition (`div type="edition" xml:id=…`) aus
    BetaMasaheft/Works: Kapitel mit Versen `l n=…` oder Abschnitte `ab`."""
    tree = etree.parse(str(path))
    ed = None
    for div in tree.iter("{%s}div" % TEI["t"]):
        if div.get("type") == "edition" and (div.get("{http://www.w3.org/XML/1998/namespace}id") == edition
                                             or edition == "*"):
            ed = div
            break
    if ed is None:
        raise ValueError(f"{path.name}: Edition {edition} fehlt")
    out = []
    for i, part in enumerate(ed.findall("t:div", TEI), start=1):
        lab_el = part.find("t:label", TEI)
        lab = clean("".join(lab_el.itertext())) if lab_el is not None else None
        n = part.get("n")
        if n is None and lab:
            m = re.search(r"(\d+)", lab)
            n = m.group(1) if m else ("0" if "Introduction" in lab else str(i))
        n = n or str(i)
        blocks = []
        lines = part.findall(".//t:l", TEI)
        if lines:
            for line in lines:
                text = _tei_plain(line)
                if text:
                    blocks.append([line.get("n") or "", text])
        else:
            for ab in part.findall(".//t:ab", TEI):
                text = _tei_plain(ab)
                if text:
                    blocks.append(["", text])
        if blocks:
            out.append(unit(n, "Einleitung" if n == "0" else f"{label} {n}", blocks))
    return out


# --------------------------------------------------------- HCF (ANF, HTML)

# Angaben der Sammlung, kein Text der Ausgabe.
_BOILERPLATE = re.compile(r"^(?:Date:|Alternative Sources:|Sources?:|Translated by\b)", re.I)

_CHAPTER = re.compile(r"^Chapter\s+([IVXLC]+)\b\.?\s*[-–—.]?\s*(.*)$", re.I)


def renumber_notes(blocks, notes):
    """Absätze, die nur aus Anmerkungszeichen bestehen (Zeichen an einer
    entfallenen Überschrift), entfallen; die Anmerkungen werden in der
    Reihenfolge ihrer Zeichen neu nummeriert, unbenutzte entfallen."""
    kept = [b for b in blocks if re.sub(r"\[\d+\]", "", b[1]).strip()]
    new_notes: list[str] = []

    def repl(m):
        i = int(m.group(1)) - 1
        if i >= len(notes):
            return m.group(0)
        new_notes.append(notes[i])
        return f"[{len(new_notes)}]"

    return [[n, re.sub(r"\[(\d+)\]", repl, t)] for n, t in kept], new_notes


def hcf(files: list[Path], *, mode="chapters", labels=None, ids=None, skip_heads=(),
        label="Kapitel", group=None):
    """Englische Übersetzungen (v. a. ANF) aus HistoricalChristianFaith.

    mode: "chapters" – Einheiten an „Chapter I.“-Überschriften (Text davor
          als Einheit 0, außer unter Überschriften aus `skip_heads`);
          "numbered" – Einheiten an Absätzen, die mit „12.“ beginnen;
          "file" – eine Einheit je Datei (`ids`/`labels` je Datei);
          "groups" – Absätze ohne Gliederung in Gruppen von `group`.
    """
    out = []
    for fi, path in enumerate(files):
        _title, items, raw = _hcf_paragraphs(path, False)
        cur = None
        skipping = False

        def start(uid, lab, title=None):
            nonlocal cur
            cur = {"id": str(uid), "label": lab, "path": [], "title": title, "raw": []}
            out.append(cur)

        if mode == "file":
            start(ids[fi], labels[fi])
        for kind, text, _marks in items:
            if kind == "h":
                head = re.sub(r"⟦\d+⟧", "", text).strip()
                if any(re.match(s, head, re.I) for s in skip_heads):
                    skipping = True
                    continue
                m = _CHAPTER.match(head)
                r = re.match(r"^([IVXLC]+)\.$", head)
                if mode == "roman" and r:
                    n = roman(r.group(1))
                    start(n, f"{label} {n}")
                    continue
                if mode == "chapters" and m:
                    skipping = False
                    n = roman(m.group(1))
                    start(n, f"{label} {n}", clean(m.group(2)).strip(" .-–") or None)
                    continue
                if mode == "file" and m and cur is not None:
                    # Kapitelzählung innerhalb der Datei als Abschnittsnummer
                    cur.setdefault("pending", str(roman(m.group(1))))
                    continue
                if cur is not None and not cur["raw"] and not cur["title"]:
                    cur["title"] = head.strip(" .")
                continue
            if skipping or _BOILERPLATE.match(text):
                continue
            if mode == "numbered":
                m = re.match(r"^(\d+)\.\s+(.*)$", text, re.S)
                if m:
                    start(m.group(1), f"{label} {m.group(1)}")
                    text = m.group(2)
            if cur is None:
                if mode == "groups":
                    start(1, f"{label} 1")
                else:
                    start(0, "Einleitung")
            if mode == "groups" and len(cur["raw"]) >= group:
                n = int(cur["id"]) + 1
                start(n, f"{label} {n}")
            num = cur.pop("pending", "") if mode == "file" else ""
            cur["raw"].append([num, text, raw])
    result = []
    for u in out:
        notes: list[str] = []
        blocks = []
        for num, text, rn in u.pop("raw"):
            def repl(m, rn=rn):
                n = int(m.group(1))
                if not rn.get(n):
                    return ""
                notes.append(clean(rn[n]))
                return f"[{len(notes)}]"
            t = clean(re.sub(r"⟦(\d+)⟧", repl, text))
            if t:
                blocks.append([num, t])
        u["blocks"], u["notes"] = renumber_notes(blocks, notes)
        if u["blocks"]:
            result.append(unit(u["id"], u["label"], u["blocks"], title=u.get("title"), notes=u["notes"]))
    return result
