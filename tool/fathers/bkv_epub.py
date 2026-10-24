"""EPUB-Exporte der BKV (bkv.unifr.ch, „Download EPUB“) lesen.

Die Exporte sind mit pandoc erzeugt: ch001.xhtml enthält die Angaben zu Werk
und Fassung („Titel Werk: … Autor: … Identifier: CPL 123 …“, „Titel Version:
… Bibliographie: …“), die übrigen Kapiteldateien den Text als verschachtelte
<section class="levelN"> mit Überschrift, Seitenmarken (Links auf
/works/<w>/versions/<v>/scans/…) und Anmerkungen (pandoc-Fußnoten).

Ein Abschnitt der App ist die kleinste Einheit mit eigener Überschrift.
Bestehen die Unterabschnitte einer Einheit nur aus Absatznummern („1.“,
„2.“), wird die Einheit ein Abschnitt und die Nummern stehen vor den
Absätzen – so liest sich ein Kapitel am Stück.
"""

from __future__ import annotations

import re
import zipfile
from pathlib import Path

from bs4 import BeautifulSoup, NavigableString, Tag

LABELS = ["Titel Werk", "Autor", "Identifier", "Tag", "Time", "Titel Version",
          "Sprache", "Bibliographie", "Unter der Mitarbeit von"]
_LABEL = re.compile(r"(?:^|\s)(" + "|".join(map(re.escape, LABELS)) + r"):\s*")
FORTS = re.compile(r"^\[Forts\. v\.\s*(?:S\.\s*\d+)?\s*\]\s*")
NUMBER = re.compile(r"^\d+[a-z]?\.?$")


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\xa0", " ")).strip()


def metadata(text: str) -> dict[str, list[str]]:
    """„Titel Werk: X Autor: Y Tag: A Tag: B“ → {Titel Werk: [X], Tag: [A, B], …}."""
    out: dict[str, list[str]] = {}
    parts = _LABEL.split(clean(text))
    for label, value in zip(parts[1::2], parts[2::2]):
        out.setdefault(label, []).append(value.strip())
    return out


class Node:
    def __init__(self, title: str, level: int):
        self.title = title
        self.level = level
        self.blocks: list[Tag] = []
        self.children: list[Node] = []


def _tree(section: Tag, level: int) -> Node:
    heading = section.find(re.compile(r"^h[1-6]$"), recursive=False)
    node = Node(clean(heading.get_text(" ")) if heading else "", level)
    for child in section.children:
        if not isinstance(child, Tag) or child is heading:
            continue
        if child.name == "section" and "footnotes" not in (child.get("class") or []):
            node.children.append(_tree(child, level + 1))
        elif child.name in ("p", "blockquote", "ol", "ul", "div"):
            node.blocks.append(child)
    return node


def read(path: Path) -> dict:
    """Werk, Fassung und Abschnitte eines EPUB-Exports.

    Abschnitte: {n, t, path, p, notes, marks, ref, heads: [Überschriften mit
    ihrem Vorgänger-Pfad]} – Bibelstellen liest erst der Import.
    """
    with zipfile.ZipFile(path) as z:
        names = sorted(n for n in z.namelist() if re.search(r"text/ch\d+\.xhtml$", n))
        pages = {n: BeautifulSoup(z.read(n).decode("utf-8"), "lxml") for n in names}

    head = pages.pop(names[0])
    meta: dict[str, list[str]] = {}
    for p in head.find_all("p"):
        meta.update(metadata(p.get_text(" ")))

    notes: dict[str, str] = {}
    roots: list[Node] = []
    work_no = version_no = None
    for page in pages.values():
        for box in page.find_all("section", class_="footnotes"):
            for li in box.find_all("li", id=True):
                for back in li.find_all("a", class_="footnote-back"):
                    back.decompose()
                notes[li["id"]] = clean(li.get_text(" "))
            box.decompose()
        for a in page.find_all("a", href=re.compile(r"/works/\d+/versions/\d+/scans/")):
            m = re.search(r"/works/(\d+)/versions/(\d+)/", a["href"])
            work_no, version_no = m[1], m[2]
            break
        body = page.find("body")
        for section in body.find_all("section", recursive=False):
            roots.append(_tree(section, 1))

    if version_no is None:
        m = re.search(r"_(\d+)(?:\.epub)?$", path.stem)
        version_no = m[1] if m else None

    sections: list[dict] = []

    def paragraphs(node_blocks, prefix=None):
        out, shown, marks, seen_pages = [], [], {}, []
        for block in node_blocks:
            items = [block] if block.name == "p" else (block.find_all(["p", "li"]) or [block])
            for item in items:
                refs_here = []
                for a in item.find_all("a"):
                    href = a.get("href", "")
                    if "/scans/" in href:
                        seen_pages.append(clean(a.get_text()))
                        a.replace_with(NavigableString(""))
                    elif href.startswith("#fn") and href[1:] in notes:
                        shown.append(notes[href[1:]])
                        refs_here.append(len(shown) - 1)
                        a.replace_with(NavigableString(f"[{len(shown)}]"))
                text = FORTS.sub("", clean(item.get_text(""))).strip()
                if not text:
                    continue
                if prefix and not out:
                    text = f"{prefix} {text}"
                out.append(text)
                if refs_here:
                    marks[len(out) - 1] = refs_here
        return out, shown, marks, seen_pages

    def emit(title, path_titles, parts, heads):
        p_all, notes_all, marks_all, pages_all = [], [], {}, []
        for blocks, prefix in parts:
            p, n, m, pg = paragraphs(blocks, prefix)
            offset, note_offset = len(p_all), len(notes_all)
            # Anmerkungszeichen fortlaufend je Abschnitt.
            p = [re.sub(r"\[(\d+)\]", lambda x: f"[{int(x[1]) + note_offset}]", t) for t in p]
            p_all += p
            notes_all += n
            for i, ks in m.items():
                marks_all[offset + i] = [k + note_offset for k in ks]
            pages_all += pg
        if not p_all:
            return False
        ref = None
        if pages_all:
            first, last = pages_all[0].replace("S. ", ""), pages_all[-1].replace("S. ", "")
            ref = f"S. {first}" if first == last else f"S. {first}–{last}"
        sections.append({"n": len(sections) + 1, "t": title, "path": path_titles,
                         "p": p_all, "notes": notes_all, "marks": marks_all,
                         "ref": ref, "heads": heads})
        return True

    def walk(node: Node, path_titles: list[str], pending: list[str]):
        """pending: Überschriften, die mit dem nächsten Abschnitt beginnen."""
        kids = node.children
        numbered = sum(1 for c in kids if NUMBER.match(c.title))
        flat = kids and all(not c.children for c in kids) and numbered * 2 >= len(kids)
        heads = pending + [node.title]
        if flat or not kids:
            parts = [(node.blocks, None)]
            for c in kids:
                prefix = c.title if NUMBER.match(c.title) else f"{c.title}:"
                parts.append((c.blocks, prefix if c.title else None))
            if not emit(node.title, path_titles, parts, heads):
                return heads
            return []
        if node.blocks and emit(node.title, path_titles, [(node.blocks, None)], heads):
            heads = []
        for c in kids:
            heads = walk(c, path_titles + [node.title], heads)
        return heads

    for root in roots:
        # Die oberste Ebene ist der Werktitel; sie zählt nicht zum Pfad.
        if root.children:
            pending: list[str] = []
            if root.blocks and emit(root.title, [], [(root.blocks, None)], []):
                pass
            for c in root.children:
                pending = walk(c, [], pending)
        else:
            walk(root, [], [])

    return {"meta": meta, "workNo": work_no, "versionNo": version_no,
            "sections": sections}
