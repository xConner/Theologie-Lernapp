"""Texte aus PDF-Drucken einer Webseite lesen (z. B. „1. Homilie über Genesis“).

Die Drucke (Vivliostyle) haben ein festes Schriftbild, nach dem sich die
Teile unterscheiden lassen:

  27 pt fett    Titel                   14 pt     Autor
  16,6 pt fett  Zwischenüberschrift     11,1 pt   Text
  8,8 pt fett   Absatznummer (Rand)     6,9 pt    Anmerkungszeichen (hochgestellt)
  8 pt          Seitenzahl              21 pt     „Bibelstellen“, darunter die
                                                  Liste der Anmerkungen (10,2 pt)

Die Anmerkungen sind Bibelstellen in englischer Schreibweise („Römer 2:13“).
Wer die Zwischenüberschriften verfasst hat, sagen die Drucke nicht.
"""

from __future__ import annotations

import re
from pathlib import Path

import pdfplumber

# Buchnamen der Drucke → USFM.
BOOKS = {
    "Genesis": "GEN", "Exodus": "EXO", "Levitikus": "LEV", "Numeri": "NUM",
    "Deuteronomium": "DEU", "Josua": "JOS", "Richter": "JDG", "Rut": "RUT",
    "1. Samuel": "1SA", "2. Samuel": "2SA", "1. Könige": "1KI", "2. Könige": "2KI",
    "1. Chronik": "1CH", "2. Chronik": "2CH", "Esra": "EZR", "Nehemia": "NEH",
    "Ester": "EST", "Hiob": "JOB", "Ijob": "JOB", "Psalm": "PSA", "Psalmen": "PSA",
    "Sprüche": "PRO", "Prediger": "ECC", "Kohelet": "ECC", "Hoheslied": "SNG",
    "Jesaja": "ISA", "Jeremia": "JER", "Klagelieder": "LAM", "Hesekiel": "EZK",
    "Ezechiel": "EZK", "Daniel": "DAN", "Hosea": "HOS", "Joel": "JOL", "Amos": "AMO",
    "Obadja": "OBA", "Jona": "JON", "Micha": "MIC", "Nahum": "NAM", "Habakuk": "HAB",
    "Zefanja": "ZEP", "Haggai": "HAG", "Sacharja": "ZEC", "Maleachi": "MAL",
    "Tobit": "TOB", "Judit": "JDT", "Weisheit": "WIS", "Weisheit von Salomo": "WIS",
    "Jesus Sirach": "SIR", "Sirach": "SIR", "Baruch": "BAR",
    "Matthäus": "MAT", "Markus": "MRK", "Lukas": "LUK", "Johannes": "JHN",
    "Apostelgeschichte": "ACT", "Römer": "ROM", "1. Korinther": "1CO",
    "2. Korinther": "2CO", "Galater": "GAL", "Epheser": "EPH", "Philipper": "PHP",
    "Kolosser": "COL", "1. Thessalonicher": "1TH", "2. Thessalonicher": "2TH",
    "1. Timotheus": "1TI", "2. Timotheus": "2TI", "Titus": "TIT", "Philemon": "PHM",
    "Hebräer": "HEB", "Jakobus": "JAS", "1. Petrus": "1PE", "2. Petrus": "2PE",
    "1. Johannes": "1JN", "2. Johannes": "2JN", "3. Johannes": "3JN", "Judas": "JUD",
    "Offenbarung": "REV",
}

NOTE = re.compile(r"^(?P<book>.+?)\s+(?P<c>\d+):(?P<v>\d+)(?:-(?P<ev>\d+))?$")


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _size(w) -> float:
    return round(w["size"], 1)


def _bold(w) -> bool:
    return "Bold" in w["fontname"]


def parse_note(text: str):
    """„Römer 2:13“ → („ROM“, 2, 13, 13) oder None."""
    m = NOTE.match(clean(text))
    if not m or m["book"] not in BOOKS:
        return None
    v = int(m["v"])
    return BOOKS[m["book"]], int(m["c"]), v, int(m["ev"] or v)


def read(path: Path) -> dict:
    """Titel, Autor, Absätze und Anmerkungen eines Drucks."""
    title = author = None
    sections: list[dict] = []
    notes: dict[int, str] = {}
    current = None          # Abschnitt
    paragraph: list[str] = []
    heading: list[str] = []
    in_notes = False
    note_items: list[tuple[float, float, int]] = []   # (rechter Rand, top, Nummer)
    note_words: list[tuple[float, float, str]] = []
    marks: list[int] = []

    def flush_paragraph():
        nonlocal paragraph
        if paragraph and current is not None:
            current["p"].append(clean(" ".join(paragraph)))
            if marks:
                current["marks"][len(current["p"]) - 1] = list(marks)
        paragraph = []
        marks.clear()

    def flush_heading():
        nonlocal heading, current
        if heading:
            flush_paragraph()
            current = {"t": clean(" ".join(heading)), "p": [], "marks": {}}
            sections.append(current)
            heading = []

    with pdfplumber.open(path) as pdf:
        for page_no, page in enumerate(pdf.pages):
            words = page.extract_words(extra_attrs=["size", "fontname"])
            words.sort(key=lambda w: (round(w["top"]), w["x0"]))
            for w in words:
                size, bold, text = _size(w), _bold(w), w["text"]
                if size == 21.0 and text == "Bibelstellen":
                    flush_heading()
                    flush_paragraph()
                    in_notes = True
                    continue
                if in_notes:
                    if size == 10.2 and bold and re.fullmatch(r"\d+\.", text):
                        note_items.append((w["x1"], w["top"] + page_no * 10_000, int(text[:-1])))
                    elif size == 10.2:
                        note_words.append((w["x0"], w["top"] + page_no * 10_000, text))
                    continue
                if size == 27.0:
                    title = clean(f"{title or ''} {text}")
                elif size == 14.2:
                    author = clean(f"{author or ''} {text}")
                elif size == 16.6 and bold:
                    flush_paragraph()
                    heading.append(text)
                elif size == 8.8 and bold:
                    # Absatznummer: neuer Absatz.
                    flush_heading()
                    flush_paragraph()
                    paragraph.append(f"{text}.")
                elif size == 6.9 and bold and text.isdigit():
                    if paragraph:
                        paragraph[-1] += f"[{text}]"
                    marks.append(int(text))
                elif size == 11.1:
                    flush_heading()
                    if paragraph and paragraph[-1].endswith("-") and text[:1].islower() \
                            and not paragraph[-1].endswith(" -"):
                        paragraph[-1] = paragraph[-1][:-1] + text
                    else:
                        paragraph.append(text)
                # 8 pt: Seitenzahl – entfällt.
        flush_heading()
        flush_paragraph()

    # Liste der Anmerkungen: Raster aus Spalten (Nummern rechtsbündig); ein
    # Wort gehört zur letzten Nummer seiner Spalte, die nicht unter ihm steht.
    columns = sorted({round(x) for x, _, _ in note_items})
    for x, top, text in note_words:
        col = max((c for c in columns if c <= x), default=None)
        owner = None
        for ix, itop, n in note_items:
            if round(ix) == col and itop <= top + 2:
                if owner is None or itop >= owner[0]:
                    owner = (itop, n)
        if owner:
            notes[owner[1]] = clean(f"{notes.get(owner[1], '')} {text}")

    # Ein Abschnitt je Druck (eine Homilie). Die Zwischenüberschriften
    # stammen nicht sicher vom Autor und entfallen; Anmerkungszeichen zählen
    # wie im Druck durch.
    paragraphs, marks_out = [], {}
    for sec in sections:
        for i, text in enumerate(sec["p"]):
            if i in sec["marks"]:
                marks_out[len(paragraphs)] = [n - 1 for n in sec["marks"][i]]
            paragraphs.append(text)
    count = max(notes, default=0)
    return {"title": title, "author": author,
            "headings": [sec["t"] for sec in sections],
            "p": paragraphs, "notes": [notes.get(n, "") for n in range(1, count + 1)],
            "marks": marks_out}
