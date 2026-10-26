"""Freie Textsammlungen für „Kirchenväter & Schriften“ lesen.

Drei Sammlungen, alle als Git-Archive von GitHub (Angaben je Werk in
curation/open_texts.json):

  hcf      HistoricalChristianFaith/Writings-Database: englische
           Übersetzungen als HTML, je Homilie, Buch oder Brief eine Datei.
           Die Sammlung enthält auch Übertragungen „using ChatGPT“; die
           werden nie übernommen (open_texts.json nennt nur geprüfte
           Dateien, read_hcf bricht bei einem solchen Vermerk ab).
  csel     OpenGreekAndLatin/csel-dev: lateinische Originaltexte aus dem
           Corpus Scriptorum Ecclesiasticorum Latinorum (EpiDoc/TEI).
  perseus  PerseusDL/canonical-greekLit: griechische Originaltexte
           (EpiDoc/TEI).

Jeder Leser liefert Abschnitte im Format von import_bkv.write_texts:
  {"t": Titel, "path": [übergeordnete Titel], "p": [Absätze],
   "notes": [Anmerkungen], "marks": {Absatz: [Anmerkung, …]}, "ref": …}
Anmerkungszeichen stehen im Absatz als „[n]“ (n = Stelle in "notes" + 1).

Dazu Leser für Bibelstellen in englischer Schreibweise („Matt. xii. 25“,
„Rom. 5:3“) und in den lateinischen Fußnoten des CSEL („II Cor. 12, 2“).
"""

from __future__ import annotations

import html
import re
import unicodedata
from pathlib import Path

from bs4 import BeautifulSoup, NavigableString
from lxml import etree

from bible_refs import Ref, vulgate_psalm
from common import Versification

TEI = {"t": "http://www.tei-c.org/ns/1.0"}

# Größe eines Abschnitts (Zeichen), ab der ein Text an seinen
# Zwischenüberschriften geteilt wird bzw. Paragraphen gruppiert werden.
SECTION_CHARS = 40_000


def clean(text: str) -> str:
    text = text.replace("\xa0", " ").replace("​", "")
    return re.sub(r"\s+", " ", text).strip()


# ------------------------------------------------------------ Beta-Code

# Die NPNF-Digitalisate geben Griechisch in einer Spielart des Beta-Codes
# wieder („e0ra=te“, „h9mw=n“, „Kai\ ga/r“): 0 = Spiritus lenis,
# 9 = Spiritus asper, / \ = Akzente, | Iota subscriptum, + Trema.
_BETA_LETTERS = {
    "a": "α", "b": "β", "g": "γ", "d": "δ", "e": "ε", "z": "ζ", "h": "η",
    "q": "θ", "i": "ι", "k": "κ", "l": "λ", "m": "μ", "n": "ν", "c": "ξ",
    "o": "ο", "p": "π", "r": "ρ", "s": "σ", "t": "τ", "u": "υ", "f": "φ",
    "x": "χ", "y": "ψ", "w": "ω", "v": "ϝ", "j": "ς",
}
_BETA_MARKS = {
    "0": "\u0313", ")": "\u0313", "'": "\u0313", "9": "\u0314", "(": "\u0314",
    "/": "\u0301", "\\": "\u0300", "=": "\u0342", "|": "\u0345", "+": "\u0308",
}
_VOWELS = set("aehiouwr")
_BETA_WORD = re.compile(r"(?<![\w/\\=|+'])([A-Za-z][A-Za-z0-9/\\=|+']*)(?![\w/\\=|+])")


def _is_beta(word: str) -> bool:
    """Nur Wörter, deren Zeichen hinter Vokalen (oder ρ) stehen und die
    mindestens ein Zeichen tragen – „and/or“ oder „A1“ bleiben, wie sie sind."""
    if not re.search(r"[0-9/\\=|+]", word) or re.search(r"[0-9/\\=|+]{4}", word):
        return False
    if re.fullmatch(r"[A-Za-z]+\d+", word):
        return False
    prev = ""
    for ch in word:
        if ch in _BETA_MARKS:
            if prev.lower() not in _VOWELS and prev not in _BETA_MARKS:
                return False
        elif ch.lower() not in _BETA_LETTERS:
            return False
        prev = ch if ch not in _BETA_MARKS else prev
    return True


def _beta_word(word: str) -> str:
    out = []
    for ch in word:
        if ch in _BETA_MARKS:
            out.append(_BETA_MARKS[ch])
        elif ch == "j":
            out.append("ς")
        else:
            letter = _BETA_LETTERS[ch.lower()]
            out.append(letter.upper() if ch.isupper() else letter)
    text = "".join(out)
    if text.endswith("σ"):
        text = text[:-1] + "ς"
    return unicodedata.normalize("NFC", text)


def beta_to_greek(text: str) -> str:
    """Setzt Beta-Code-Wörter in griechische Schrift um; anderer Text bleibt."""
    def repl(m: re.Match) -> str:
        word = m.group(1)
        return _beta_word(word) if _is_beta(word) else word

    return _BETA_WORD.sub(repl, text)


# ------------------------------------------------------- Bibelstellen

ROMAN = {"i": 1, "v": 5, "x": 10, "l": 50, "c": 100}


def roman(text: str) -> int | None:
    text = text.lower()
    if not re.fullmatch(r"[ivxlc]+", text):
        return None
    total, prev = 0, 0
    for ch in reversed(text):
        value = ROMAN[ch]
        total += -value if value < prev else value
        prev = max(prev, value)
    return total


ENGLISH_BOOKS = {
    "Gen": "GEN", "Genesis": "GEN", "Ex": "EXO", "Exod": "EXO", "Exodus": "EXO",
    "Lev": "LEV", "Levit": "LEV", "Leviticus": "LEV", "Num": "NUM", "Numb": "NUM",
    "Numbers": "NUM", "Deut": "DEU", "Deuteronomy": "DEU", "Josh": "JOS",
    "Joshua": "JOS", "Judg": "JDG", "Judges": "JDG", "Ruth": "RUT",
    "1 Sam": "1SA", "2 Sam": "2SA", "1 Samuel": "1SA", "2 Samuel": "2SA",
    "1 Kings": "1KI", "2 Kings": "2KI", "1 Kgs": "1KI", "2 Kgs": "2KI",
    "1 Chron": "1CH", "2 Chron": "2CH", "1 Chr": "1CH", "2 Chr": "2CH",
    "Ezra": "EZR", "Neh": "NEH", "Nehemiah": "NEH", "Esth": "EST", "Esther": "EST",
    "Job": "JOB", "Ps": "PSA", "Psa": "PSA", "Psalm": "PSA", "Psalms": "PSA",
    "Prov": "PRO", "Proverbs": "PRO", "Eccl": "ECC", "Eccles": "ECC",
    "Ecclesiastes": "ECC", "Cant": "SNG", "Song": "SNG", "Song of Sol": "SNG",
    "Isa": "ISA", "Is": "ISA", "Isaiah": "ISA", "Jer": "JER", "Jeremiah": "JER",
    "Lam": "LAM", "Lamentations": "LAM", "Ezek": "EZK", "Ezekiel": "EZK",
    "Dan": "DAN", "Daniel": "DAN", "Hos": "HOS", "Hosea": "HOS", "Joel": "JOL",
    "Amos": "AMO", "Obad": "OBA", "Jonah": "JON", "Mic": "MIC", "Micah": "MIC",
    "Nah": "NAM", "Nahum": "NAM", "Hab": "HAB", "Habakkuk": "HAB", "Zeph": "ZEP",
    "Hag": "HAG", "Haggai": "HAG", "Zech": "ZEC", "Zechariah": "ZEC",
    "Mal": "MAL", "Malachi": "MAL", "Tob": "TOB", "Tobit": "TOB", "Judith": "JDT",
    "Wisd": "WIS", "Wis": "WIS", "Ecclus": "SIR", "Sirach": "SIR", "Bar": "BAR",
    "Baruch": "BAR", "1 Macc": "1MA", "2 Macc": "2MA",
    "Matt": "MAT", "Mat": "MAT", "Matthew": "MAT", "Mark": "MRK", "Mk": "MRK",
    "Luke": "LUK", "Lk": "LUK", "John": "JHN", "Jn": "JHN", "Acts": "ACT",
    "Rom": "ROM", "Romans": "ROM", "1 Cor": "1CO", "2 Cor": "2CO",
    "Gal": "GAL", "Galatians": "GAL", "Eph": "EPH", "Ephes": "EPH",
    "Ephesians": "EPH", "Phil": "PHP", "Philippians": "PHP", "Col": "COL",
    "Colossians": "COL", "1 Thess": "1TH", "2 Thess": "2TH", "1 Tim": "1TI",
    "2 Tim": "2TI", "Tit": "TIT", "Titus": "TIT", "Philem": "PHM",
    "Philemon": "PHM", "Heb": "HEB", "Hebr": "HEB", "Hebrews": "HEB",
    "Jas": "JAS", "James": "JAS", "1 Pet": "1PE", "2 Pet": "2PE",
    "1 Peter": "1PE", "2 Peter": "2PE", "1 John": "1JN", "2 John": "2JN",
    "3 John": "3JN", "Jude": "JUD", "Rev": "REV", "Revelation": "REV",
    "Apoc": "REV",
}

LATIN_BOOKS = {
    "Gen": "GEN", "Ex": "EXO", "Exod": "EXO", "Leu": "LEV", "Lev": "LEV",
    "Num": "NUM", "Deut": "DEU", "Ios": "JOS", "Iud": "JDG", "Iudic": "JDG",
    "Ruth": "RUT", "I Reg": "1SA", "II Reg": "2SA", "III Reg": "1KI",
    "IV Reg": "2KI", "I Par": "1CH", "II Par": "2CH", "Esdr": "EZR",
    "Tob": "TOB", "Iudith": "JDT", "Esth": "EST", "Iob": "JOB", "Ps": "PSA",
    "Prou": "PRO", "Prov": "PRO", "Eccle": "ECC", "Eccl": "ECC", "Cant": "SNG",
    "Sap": "WIS", "Eccli": "SIR", "Sir": "SIR", "Es": "ISA", "Esai": "ISA",
    "Is": "ISA", "Hier": "JER", "Ier": "JER", "Thren": "LAM", "Bar": "BAR",
    "Ezech": "EZK", "Hiez": "EZK", "Dan": "DAN", "Os": "HOS", "Ioel": "JOL",
    "Am": "AMO", "Abd": "OBA", "Ion": "JON", "Mich": "MIC", "Nah": "NAM",
    "Hab": "HAB", "Soph": "ZEP", "Agg": "HAG", "Zach": "ZEC", "Mal": "MAL",
    "I Macc": "1MA", "II Macc": "2MA", "Matth": "MAT", "Mt": "MAT",
    "Marc": "MRK", "Mc": "MRK", "Luc": "LUK", "Lc": "LUK", "Ioh": "JHN",
    "Io": "JHN", "Act": "ACT", "Rom": "ROM", "I Cor": "1CO", "II Cor": "2CO",
    "Gal": "GAL", "Eph": "EPH", "Ephes": "EPH", "Phil": "PHP", "Col": "COL",
    "I Thess": "1TH", "II Thess": "2TH", "I Tim": "1TI", "II Tim": "2TI",
    "Tit": "TIT", "Philem": "PHM", "Hebr": "HEB", "Iac": "JAS",
    "I Petr": "1PE", "II Petr": "2PE", "I Ioh": "1JN", "II Ioh": "2JN",
    "III Ioh": "3JN", "Apoc": "REV",
}


def _book_regex(books: dict[str, str]) -> str:
    names = sorted(books, key=len, reverse=True)
    return "|".join(re.escape(b).replace(r"\ ", r"\s*") for b in names)


def _lookup(books: dict[str, str], name: str) -> str | None:
    key = re.sub(r"\s+", " ", name.strip().rstrip("."))
    if key in books:
        return books[key]
    compact = key.replace(" ", "")
    for k, v in books.items():
        if k.replace(" ", "") == compact:
            return v
    return None


_EN_NUM = re.compile(r"\b(I{1,3}|[123])\.?\s+(?=[A-Z][a-z])")

EN_REF = re.compile(
    rf"(?<![\w])(?P<book>{_book_regex(ENGLISH_BOOKS)})\.?\s+"
    r"(?P<chapter>[ivxlcIVXLC]+|\d{1,3})\s*[.:,]\s*(?P<verse>\d{1,3})"
    r"(?:\s*[-–]\s*(?P<endverse>\d{1,3})(?![.:]\s*\d))?"
)


# Schreibweise mancher HCF-Dateien: „(Psalms chapter 43, verse 4)“.
EN_LONG_REF = re.compile(
    rf"(?<![\w])(?P<book>{_book_regex(ENGLISH_BOOKS)})\s+chapter\s+(?P<chapter>\d{{1,3}})\s*,\s*"
    r"verses?\s+(?P<verse>\d{1,3})(?:\s*[-–]\s*(?P<endverse>\d{1,3}))?", re.I)


class EnglishRefReader:
    """Stellenangaben englischer Ausgaben (Zählung der King James Version),
    umgerechnet in die deutsche Zählung der App."""

    def __init__(self) -> None:
        self.v11n = Versification()
        self.unconverted: list[str] = []

    def read(self, text: str) -> list[Ref]:
        text = _EN_NUM.sub(lambda m: f"{ {'I': 1, 'II': 2, 'III': 3}.get(m[1], m[1]) } ", text)
        refs = []
        matches = list(EN_REF.finditer(text)) + list(EN_LONG_REF.finditer(text))
        for m in matches:
            book = _lookup(ENGLISH_BOOKS, m["book"]) or _lookup(
                {k.lower(): v for k, v in ENGLISH_BOOKS.items()}, m["book"].lower())
            chapter = roman(m["chapter"]) if not m["chapter"].isdigit() else int(m["chapter"])
            if book is None or not chapter:
                continue
            verse = int(m["verse"])
            end = int(m["endverse"]) if m["endverse"] else verse
            if end < verse:
                end = verse
            start_de = self.v11n.english_to_german(book, chapter, verse)
            end_de = self.v11n.english_to_german(book, chapter, end)
            cited = m.group(0).strip()
            if book not in self.v11n.german:
                refs.append(Ref(book, chapter, verse, chapter, end, "low", cited,
                                "Stellenangabe der Ausgabe (englische Zählung, nicht prüfbar)"))
                continue
            if start_de is None or end_de is None:
                self.unconverted.append(cited)
                continue
            changed = start_de != (chapter, verse) or end_de != (chapter, end)
            refs.append(Ref(
                book, start_de[0], start_de[1], end_de[0], end_de[1],
                "medium" if changed or book == "PSA" else "high", cited,
                "Stellenangabe der Ausgabe (englische Zählung, umgerechnet)" if changed
                else None,
            ))
        return refs


LA_REF = re.compile(
    rf"(?<![\w])(?P<book>{_book_regex(LATIN_BOOKS)})\.?\s*"
    r"(?P<chapter>\d{1,3})\s*,\s*(?P<verse>\d{1,3})(?:\s*[-–]\s*(?P<endverse>\d{1,3}))?"
)


class LatinRefReader:
    """Fußnoten des CSEL („1 Gen. 2, 8  5 II Cor. 12, 2“): vorangestellte
    Zeilenzahlen fallen weg; Psalmen zählen nach der Vulgata."""

    def read(self, text: str) -> list[Ref]:
        refs = []
        for m in LA_REF.finditer(text):
            book = _lookup(LATIN_BOOKS, m["book"])
            if book is None:
                continue
            chapter, verse = int(m["chapter"]), int(m["verse"])
            end = int(m["endverse"]) if m["endverse"] else verse
            if end < verse:
                end = verse
            confidence, note = "medium", "Stellenangabe im Apparat der Ausgabe (Seite; Absatz ungefähr)"
            if book == "PSA":
                hebrew, sure = vulgate_psalm(chapter)
                if hebrew is None:
                    continue
                chapter = hebrew
                note = "Psalm nach Vulgata-Zählung umgerechnet; " + note
            refs.append(Ref(book, chapter, verse, chapter, end, confidence,
                            m.group(0).strip(), note))
        return refs


# ------------------------------------------------------------- HCF (HTML)

CHATGPT = re.compile(r"ChatGPT|GPT-4|using GPT", re.I)


def _hcf_soup(path: Path) -> BeautifulSoup:
    raw = path.read_text(encoding="utf-8", errors="replace")
    if CHATGPT.search(raw):
        raise ValueError(f"{path.name}: maschinelle Übertragung (ChatGPT) – nicht übernommen")
    return BeautifulSoup(raw, "lxml")


_MARK = re.compile(r"⟦(\d+)⟧")
_HEAD = re.compile(r"⟪(.*?)⟫", re.S)


def _hcf_paragraphs(path: Path, bold_heads: bool):
    """Absätze einer HCF-Datei als Folge von ("h", Titel) und ("p", Text,
    [Anmerkungsnummern der Datei]); dazu die Anmerkungen der Datei."""
    page = _hcf_soup(path)
    article = page.find("article") or page.body or page
    notes: dict[int, str] = {}
    for box in article.find_all("section"):
        for span in box.find_all("span", id=re.compile(r"^fn\d+$")):
            for a in span.find_all("a", href=re.compile(r"^#r\d+")):
                a.decompose()
            notes[int(span["id"][2:])] = clean(span.get_text(" "))
        box.decompose()
    for script in article.find_all(["script", "style"]):
        script.decompose()
    h1 = article.find("h1")
    title = clean(h1.get_text(" ")) if h1 else path.stem
    if h1:
        h1.decompose()
    for sup in article.find_all("sup"):
        a = sup.find("a", href=re.compile(r"^#fn\d+"))
        if a is not None:
            sup.replace_with(NavigableString(f"⟦{a['href'][3:]}⟧"))
    for br in article.find_all("br"):
        br.replace_with(NavigableString("\n"))
    for h in article.find_all(["h2", "h3", "h4"]):
        h.replace_with(NavigableString(f"\n\n⟪{clean(h.get_text(' '))}⟫\n\n"))
    if bold_heads:
        for b in article.find_all("b"):
            text = clean(b.get_text(" "))
            if re.match(r"^(?:LETTER|EPISTLE)\b", text) or re.match(r"^THE PROCEEDINGS", text):
                b.replace_with(NavigableString(f"\n\n⟪{text.rstrip(' [')}⟫\n"))
    for p in article.find_all(["p", "div", "blockquote"]):
        p.insert_before(NavigableString("\n\n"))
        p.insert_after(NavigableString("\n\n"))

    items = []
    text = html.unescape(article.get_text(""))
    for block in re.split(r"\n\s*\n", text):
        for part in re.split(r"(⟪.*?⟫)", block, flags=re.S):
            head = _HEAD.fullmatch(part.strip())
            if head:
                if clean(head[1]):
                    items.append(("h", clean(head[1]).strip(" -–"),
                                  [int(n) for n in _MARK.findall(head[1])]))
                continue
            body = clean(part)
            if not body or body in ("[", "]"):
                continue
            items.append(("p", body, [int(n) for n in _MARK.findall(body)]))
    return title, items, notes


def _finish(section: dict, raw_notes: dict[int, str]) -> dict:
    """Anmerkungszeichen fortlaufend je Abschnitt nummerieren."""
    notes: list[str] = []
    marks: dict[int, list[int]] = {}
    paragraphs = []
    for i, (text, numbers) in enumerate(section.pop("raw")):
        def repl(m):
            n = int(m[1])
            if not raw_notes.get(n):
                return ""
            notes.append(beta_to_greek(raw_notes[n]))
            marks.setdefault(i, []).append(len(notes) - 1)
            return f"[{len(notes)}]"
        paragraphs.append(clean(beta_to_greek(_MARK.sub(repl, text))))
    section.update({"p": paragraphs, "notes": notes, "marks": marks})
    return section


_PLAIN = re.compile(r"\[(\d+)\]")


def _plain_notes(items, notes: dict[int, str]):
    """Dateien mit Anmerkungen als Text („…Sermon.[1]“, am Ende Absätze
    „[1] This translation …“, „[2] …“): Anmerkungen lesen, Zeichen im Text
    zu Anmerkungszeichen machen. Andere Zahlen in [ ] sind Spaltenangaben
    der Patrologia Graeca und werden als „[Sp. n]“ gekennzeichnet."""
    block = None
    for k, it in enumerate(items):
        if k > 0 and it[0] == "p" and it[1].startswith("[1]"):
            block = k
    body_items, tail = (items, []) if block is None else (items[:block], items[block:])
    rest = []
    for it in tail:
        m = re.match(r"^\[(\d+)\]\s*(.*)$", it[1]) if it[0] == "p" else None
        if m and not rest:
            notes.setdefault(int(m[1]), clean(m[2]))
        else:
            rest.append(it)
    out = []
    for it in body_items + rest:
        text = _PLAIN.sub(lambda m: f"⟦{m[1]}⟧" if int(m[1]) in notes else f"[Sp. {m[1]}]", it[1])
        out.append((it[0], text, [int(n) for n in _MARK.findall(text)]))
    return out


def read_hcf(files: list[Path], *, split: str = "auto", titles: list[str] | None = None,
             bold_heads: bool = False, skip_paragraphs: int = 0,
             plain_notes: bool = False) -> list[dict]:
    """Abschnitte aus HCF-Dateien in der angegebenen Reihenfolge.

    split: "file" – ein Abschnitt je Datei; "heading" – je Zwischenüberschrift;
    "auto" – je Datei, bei langen Dateien je Zwischenüberschrift.
    """
    sections = []
    for i, path in enumerate(files):
        file_title, items, notes = _hcf_paragraphs(path, bold_heads)
        if plain_notes:
            items = _plain_notes(items, notes)
        else:
            # „[7] And besides“: Abschnittszahl der Ausgabe ohne Punkt
            # (sonst „[7.]“), nicht mit einem Anmerkungszeichen verwechseln.
            items = [("p", re.sub(r"^\[(\d+)\]", r"[\1.]", it[1]), it[2]) if it[0] == "p" else it
                     for it in items]
        if titles:
            file_title = titles[i]
        if skip_paragraphs and i == 0:
            kept, dropped = [], 0
            for it in items:
                if it[0] == "p" and dropped < skip_paragraphs:
                    dropped += 1
                    continue
                kept.append(it)
            items = kept
        size = sum(len(it[1]) for it in items)
        by_heading = split == "heading" or (split == "auto" and size > SECTION_CHARS)
        heads = [it for it in items if it[0] == "h"]
        if not by_heading or not heads:
            raw = [(it[1], it[2]) for it in items]
            sections.append(_finish({"t": file_title, "path": [], "raw": raw}, notes))
            continue
        current = None
        for it in items:
            if it[0] == "h":
                if current is not None and not current["raw"]:
                    # Zwei Überschriften hintereinander: zusammenfassen.
                    current["t"] = f"{current['t']} – {it[1]}"
                    continue
                # Anmerkungen an der Überschrift gehen an den ersten Absatz.
                current = {"t": clean(_MARK.sub("", it[1])), "path": [file_title], "raw": [],
                           "head_marks": "".join(f"⟦{n}⟧" for n in it[2])}
                sections.append(current)
            else:
                if current is None:
                    current = {"t": file_title, "path": [], "raw": []}
                    sections.append(current)
                current["raw"].append((current.pop("head_marks", "") + it[1], it[2]))
        for s in sections:
            s.pop("head_marks", None)
            if "raw" in s:
                _finish(s, notes)
    return [s for s in sections if s["p"]]


# ---------------------------------------------------------- TEI (CSEL, Perseus)


def _tei_text(el, *, drop_notes: bool, footnotes: list[str] | None) -> str:
    """Text eines TEI-Elements; Seiten- und Randangaben entfallen,
    Silbentrennung am Zeilenende wird zusammengezogen."""
    parts: list[str] = []

    def walk(node):
        tag = etree.QName(node).localname if isinstance(node.tag, str) else None
        if tag == "note":
            if not drop_notes and footnotes is not None and node.get("type") == "footnote" \
                    and node.get("rend") != "script":
                raw = clean("".join(node.itertext()))
                # „1 Gen. 2, 8 5 II Cor. 12, 2“: Zeilenzahlen der Seite
                # entfallen, die Stellen bleiben.
                # Fußnoten ohne Stellenangabe gehören zum Apparat.
                refs = [m.group(0) for m in LA_REF.finditer(raw)]
                if refs:
                    footnotes.append("; ".join(refs))
            if node.tail:
                parts.append(node.tail)
            return
        if tag in ("pb", "milestone", "head"):
            if node.tail:
                parts.append(node.tail)
            return
        if tag == "lb":
            parts.append("⁣")  # Zeilenende
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
    # „uide- ⁣ tur“ → „uidetur“; sonst ist das Zeilenende ein Leerzeichen.
    text = re.sub(r"(\w)[-¬]\s*⁣\s*(\w)", r"\1\2", text)
    text = text.replace("⁣", " ")
    return clean(text)


def tei_header(path: Path) -> dict:
    tree = etree.parse(str(path))
    def first(xpath):
        el = tree.find(xpath, TEI)
        return clean("".join(el.itertext())) if el is not None else None
    return {
        "title": first(".//t:titleStmt/t:title"),
        "editor": first(".//t:sourceDesc//t:editor") or first(".//t:titleStmt/t:editor"),
        "date": first(".//t:sourceDesc//t:imprint/t:date") or first(".//t:sourceDesc//t:date"),
        "licence": first(".//t:availability/t:licence"),
        "scan": (tree.find(".//t:sourceDesc//t:ref", TEI).get("target")
                 if tree.find(".//t:sourceDesc//t:ref", TEI) is not None else None),
    }


def read_tei(path: Path, *, keep_footnotes: bool, book_label: str = "Buch") -> list[dict]:
    """Abschnitte aus einer EpiDoc-Edition.

    Ebenen oberhalb der untersten Gliederung (Buch, Kapitel) werden zu
    Überschriften; die unterste (Paragraph/§ bzw. Brief) zu Absätzen mit
    vorangestellter Nummer. Lange Ebenen werden in Gruppen von Absätzen
    geteilt („§ 1–14“). Der textkritische Apparat entfällt; im CSEL bleiben
    die Bibelstellen-Fußnoten als Anmerkungen.
    """
    tree = etree.parse(str(path))
    edition = tree.find(".//t:div[@type='edition']", TEI)
    if edition is None:
        raise ValueError(f"{path.name}: keine Edition")
    sections: list[dict] = []

    def collect(div):
        kids = div.findall("t:div", TEI)
        loose = [(None, p) for p in div.findall("t:p", TEI)]
        if kids and any(k.findall("t:div", TEI) for k in kids):
            # Bücher (bzw. Psalmen, Predigten): je Buch die Einheiten der
            # nächsten Ebene als Absätze; tiefere Ebenen gehören zum Absatz.
            if loose:
                emit([], loose)
            for k in kids:
                n = k.get("n") or ""
                if n in ("0", "pr", "praef", "prol"):
                    title = "Vorrede"
                else:
                    title = f"{book_label} {n}".strip()
                units = [(None, p) for p in k.findall("t:p", TEI)]
                units += [(u.get("n"), u) for u in k.findall("t:div", TEI)]
                subtypes = {u.get("subtype") for u in k.findall("t:div", TEI)}
                emit([title], units, subtypes.pop() if len(subtypes) == 1 else None)
            return
        emit([], loose + [(k.get("n"), k) for k in kids],
             kids[0].get("subtype") if kids else None)

    def emit(path_titles, units, unit_type=None):
        items = []
        for n, el in units:
            footnotes: list[str] = [] if keep_footnotes else None
            heads = [clean("".join(h.itertext())) for h in el.findall("t:head", TEI)]
            text = _tei_text(el, drop_notes=not keep_footnotes, footnotes=footnotes)
            if not text:
                continue
            if heads and n is not None:
                text = f"{' '.join(heads)}. {text}"
            items.append((n, text, footnotes or []))
        if not items:
            return
        groups, current, size = [], [], 0
        for item in items:
            if current and size + len(item[1]) > SECTION_CHARS // 2:
                groups.append(current)
                current, size = [], 0
            current.append(item)
            size += len(item[1])
        if current:
            groups.append(current)
        base = path_titles[-1] if path_titles else None
        for g in groups:
            numbers = [n for n, _, _ in g if n]
            span = None
            if numbers:
                word = {"letter": ("Brief", "Briefe")}.get(unit_type, ("§", "§"))
                span = (f"{word[0]} {numbers[0]}" if len(numbers) == 1
                        else f"{word[1]} {numbers[0]}–{numbers[-1]}")
            if len(groups) == 1 and base:
                title = base
            elif base and span:
                title = f"{base}, {span}"
            elif span:
                title = span
            else:
                title = base or "Text"
            paragraphs, notes, marks = [], [], {}
            for n, text, fns in g:
                if fns:
                    marks[len(paragraphs)] = []
                    for fn in fns:
                        notes.append(fn)
                        marks[len(paragraphs)].append(len(notes) - 1)
                    text = text + "".join(f" [{i + 1}]" for i in marks[len(paragraphs)])
                paragraphs.append(f"{n}. {text}" if n and n.isdigit() else text)
            sections.append({"t": title, "path": path_titles[:-1] if len(groups) == 1 and base
                             else path_titles, "p": paragraphs, "notes": notes, "marks": marks})

    collect(edition)
    return sections


# ------------------------------------------------- ausgelegter Abschnitt

_CH_VERSE = re.compile(r"ch\w*ter\s+(\d+)\s*,\s*verses?\s+(\d+)(?:\s*[-–]\s*(\d+))?", re.I)
_CHAPTER_VERSES = re.compile(r"^Chapter\s+([IVXLC]+)\.?\s*Verses?\s+(\d+)(?:\s*[-–]\s*(\d+))?", re.I)
_ROMAN_VERSES = re.compile(
    r"^(?:[1-3I]{1,3}\s*)?[A-Za-z]+\.?\s+([ivxlcIVXLC]+)\.\s*(\d+)((?:\s*(?:[-–,]|and)\s*\d+)*)")


def passage_from_start(text: str, book: str, v11n: Versification):
    """Ausgelegter Abschnitt einer Homilie, wie ihn die Ausgabe am Anfang
    nennt („Matthew Chapter 1, Verse 1“, „ROM. I. 8.-“, „Hebrews ix. 24-26.-“,
    „Chapter I. Verses 11-14.-“). Nur Angaben zum Buch der Reihe zählen."""
    head = text[:200]
    chapter = verse = end = None
    found = _CH_VERSE.findall(head)
    if found:
        chapter, verse = int(found[0][0]), int(found[0][1])
        last = found[-1]
        if int(last[0]) == chapter:
            end = int(last[2] or last[1])
    else:
        m = _CHAPTER_VERSES.match(head) or _ROMAN_VERSES.match(head)
        if m:
            chapter = roman(m[1])
            verse = int(m[2])
            rest = re.findall(r"\d+", m[3] or "")
            end = int(rest[-1]) if rest else verse
    if not chapter or not verse:
        return None
    end = end if end and end >= verse else verse
    start = v11n.english_to_german(book, chapter, verse)
    stop = v11n.english_to_german(book, chapter, end)
    if start is None or stop is None:
        return None
    cited = clean(head.split('"')[0].split("“")[0])[:80].rstrip(".-– ")
    return Ref(book, start[0], start[1], stop[0], stop[1], "high", cited)


def passage_from_chapter_heading(title: str, book: str, v11n: Versification):
    """„Chapter I.“ eines fortlaufenden Kommentars: das ganze Kapitel."""
    m = re.match(r"^Chapter\s+([IVXLC]+)\b", title, re.I)
    if not m:
        return None
    chapter = roman(m[1])
    counts = v11n.german.get(book)
    if not counts or not chapter or chapter > len(counts):
        return None
    return Ref(book, chapter, 1, chapter, counts[chapter - 1], "high", title,
               "Kapitelüberschrift des Kommentars")
